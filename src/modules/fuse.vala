using Valhalla;

class MountCommand : Object, Module.Preference {
    public string? @default {get {
        return "sshfs example.com:/var/www/shared $f -C -o sshfs_sync";}}
    public string? pretty_name {get {return "Mount command";}}
    public string? help_text {get {
        return "Command to mount the filesystem\n" +
            "Use '$f' to indicate mount point";}}
    public string? @value {set; get;}
}

class ServeURL : Object, Module.Preference {
    public string? @default {get {return "https://shared.example.com";}}
    public string? pretty_name {get {return "Serve URL";}}
    public string? help_text {get {
        return "The base URL at which files will appear";}}
    public string? @value {set; get;}
}

interface MountData : Object {
    public abstract string path {construct; get;}
}

class MountMan : Object {
    [CCode (has_target = false)]
    private delegate void DestroyCallback(MountMan parent, string umount_cmd,
                                          string path);

    private class Mount : Object, MountData {
        public string path {construct; get;}
        public string umount_cmd {construct; get;}

        public MountMan parent;
        public DestroyCallback destroy_callback;

        ~Mount() {
            destroy_callback(parent, umount_cmd, path);
        }
    }

    private int mounts = 0;
    // this has to be set to true before touching counters and should
    // only be set to true via wait_on_mount
    private bool mount_in_progress = false;

    private async void wait_on_mount() {
        while (mount_in_progress) {
            Idle.add(wait_on_mount.callback);
            yield;
        }
        mount_in_progress = true;
    }

    private async void destroy_mount(string umount_cmd,
                                     string path) throws GLib.Error {
        yield wait_on_mount();
        if (AtomicInt.dec_and_test(ref mounts)) // we're the last out, unmount
            yield new Subprocess.newv({"/bin/sh", "-c",
                @"sleep 1 && $(umount_cmd)"},
                SubprocessFlags.INHERIT_FDS).wait_check_async();
        mount_in_progress = false;
    }

    public async MountData create(string? mount_command) throws Module.Error {
        var path = Path.build_filename(Environment.get_tmp_dir(),
            "valhalla_mount");
        DirUtils.create(path, 0700);

        if (mount_command == null)
            throw new Module.Error.GENERIC_ERROR(
                "Please set a mount command in the preferences panel");

        var umount_cmd = "fusermount -u %s".printf(Shell.quote(path));
        var mount_cmd = ((!) mount_command).replace("$f", Shell.quote(path));

        yield wait_on_mount();
        AtomicInt.add(ref mounts, 1);
        if (AtomicInt.get(ref mounts) == 1) { // we're the first in, mount
            string mounts;
            try {
                FileUtils.get_contents("/proc/mounts", out mounts);
                assert (!(path in mounts)); // something has gone wrong if this
                                            // is false
            } catch (FileError e) {
                ; // assume we're good to go
            }
            Subprocess p;
            try {
                p = new Subprocess.newv({"/bin/sh", "-c", mount_cmd},
                    SubprocessFlags.STDOUT_PIPE|SubprocessFlags.STDERR_PIPE);
            } catch (Error e) {
                throw new Module.Error.GENERIC_ERROR(e.message);
            }
            try {
                yield p.wait_check_async(null);
            } catch (GLib.Error e) {
                var stream = p.get_stderr_pipe();
                var stderr_data = "";
                uint8 buffer[1024];
                int read;
                try {
                    while ((read = (int) stream.read(buffer, null)) > 0)
                        stderr_data += (string) buffer[0:read];
                } catch (IOError ioe) {
                    if (stderr_data.length == 0)
                        stderr_data = e.message;
                }
                throw new Module.Error.GENERIC_ERROR(stderr_data);
            }
        }
        mount_in_progress = false;

        var mount = (Mount) Object.new(typeof(Mount), path: path,
            umount_cmd: umount_cmd);
        mount.parent = this;
        mount.destroy_callback = (us, ucm, p) => {
            us.destroy_mount.begin(ucm, p);
        };

        return mount;
    }
}

public class Fuse : Module.Uploader {
    public override string pretty_name {get {return "FuseFS";}}
    public override string description {get {
        return "Mounts and copies to a\nfuse filesystem";}}

    private MountMan mounter = new MountMan();
    private Module.Preference mount_command;
    private Module.Preference serve_url;

    public override bool implements_delete {get {return true;}}
    public override async void @delete(string remote_path) throws Module.Error {
        if (!remote_path.has_prefix((!) serve_url.value))
            throw new Module.Error.GENERIC_ERROR("Invalid remote path");
        var filename =
            remote_path[((!) serve_url.value).length:remote_path.length];
        filename = filename.replace("/", "");
        var mount = yield mounter.create(mount_command.value);
        var path = Path.build_filename(mount.path, filename);
        if (FileUtils.test(path, FileTest.EXISTS)) {
            var file = File.new_for_path(path);
            file.delete_async.begin();
        }
    }

    public override async void upload(Data.Transfer transfer)
        throws Module.Error
    {
        var file = transfer.file;
        var dest_filename = @"$((!) file.crc32)$(file.guess_extension())";

        try {
            transfer.set_remote_path(Path.build_filename((!) serve_url.value,
                dest_filename));
        } catch {
            return;
        }

        var mount = yield mounter.create(mount_command.value);

        var dest_file = File.new_for_path(Path.build_filename(mount.path,
            dest_filename));
        FileIOStream stream;
        try {
            stream = yield dest_file.replace_readwrite_async(null, false,
                FileCreateFlags.REPLACE_DESTINATION);
        } catch (Error e) {
            throw new Module.Error.GENERIC_ERROR(e.message);
        }
        bool success = true;
        for (var i = 0; i <= file.file_contents.length/1024; i++) {
            var offset = i*1024;
            var frame_length = file.file_contents.length - offset;
            if (frame_length > 1024)
                frame_length = 1024;
            try {
                yield stream.output_stream.write_async(
                    file.file_contents[offset:offset+frame_length]);
            } catch (IOError e) {
                throw new Module.Error.GENERIC_ERROR(e.message);
            }
            transfer.progress(offset+frame_length);
            if (transfer.cancellable.is_cancelled()) {
                success = false;
                break;
            }
        }

        try {
            yield stream.close_async();
        } catch (IOError e) {} // it should be safe to ignore this

        if (success)
            transfer.completed();
        else
            try {
                yield dest_file.delete_async();
            } catch (GLib.Error e) {
                throw new Module.Error.GENERIC_ERROR(
                    "Failed to cancel upload: %s", e.message);
            }
    }

    construct {
        mount_command = this.register_preference(typeof(MountCommand));
        serve_url = this.register_preference(typeof(ServeURL));
    }
}

public Type register_uploader() {
    return typeof(Fuse);
}

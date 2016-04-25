using Valhalla;

class BaseEntry : Gtk.Entry {
    public string read() {
        return this.text;
    }
    public void write(string val) {
        this.text = val;
    }
}

class Command : BaseEntry, Config.Preference {
    public string key {get {return "mount-command";}}
    public string? @default {get {
        return "sshfs example.com:/var/www/shared $f -C -o sshfs_sync";}}
    public string? label {get {return "Mount command";}}
    public string? help {get {
        return "Command to mount the filesystem\n" +
            "Use '$f' to indicate mount point";}}
    construct {
        this.placeholder_text = (!) @default;
        this.changed.connect(() => {this.change_notify();});
    }
}

class Serve : BaseEntry, Config.Preference {
    public string key {get {return "serve-url";}}
    public string? @default {get {return "https://shared.example.com";}}
    public string? label {get {return "Serve URL";}}
    public string? help {get {
        return "The base URL at which files will appear";}}
    construct {
        this.placeholder_text = (!) @default;
        this.changed.connect(() => {this.change_notify();});
    }
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

    public async MountData create(Config.Settings settings)
            throws Valhalla.Error {
        var path = Path.build_filename(Environment.get_tmp_dir(),
            "valhalla_mount");
        DirUtils.create(path, 0700);

        var umount_cmd = "fusermount -u %s".printf(Shell.quote(path));
        var mount_cmd = ((!) (settings["mount-command"] ?? ""))
            .replace("$f", Shell.quote(path));

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
            } catch (GLib.Error e) {
                throw new Valhalla.Error.MODULE_ERROR(e.message);
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
                throw new Valhalla.Error.MODULE_ERROR(stderr_data);
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

public class Fuse : Object, Modules.BaseModule {
    public string name {get {return "fuse";}}
    public string pretty_name {get {return "FuseFS";}}
    public string description {get {
        return "Mounts and copies to a\nfuse filesystem";}}
    public Config.Settings settings {set; get;}

    private MountMan mounter = new MountMan();

    public Config.Preference[] build_panel() {
        Config.Preference[] result = {};
        result += new Command();
        result += new Serve();
        return result;
    }

    public bool implements_delete {get {return true;}}
    public async void @delete(string remote_path) throws Valhalla.Error {
        if (!remote_path.has_prefix((!) settings["serve-url"]))
            throw new Valhalla.Error.MODULE_ERROR("Invalid remote path");
        var filename = remote_path[
            ((!) settings["serve-url"]).length:remote_path.length];
        filename = filename.replace("/", "");
        var mount = yield mounter.create(settings);
        var path = Path.build_filename(mount.path, filename);
        if (FileUtils.test(path, FileTest.EXISTS)) {
            var file = File.new_for_path(path);
            file.delete_async.begin();
        }
    }

    public async void upload(Transfer file) throws Valhalla.Error {
        var dest_filename = @"$(file.crc32)$(file.guess_extension())";
        file.set_remote_path(Path.build_filename((!) settings["serve-url"],
            dest_filename));

        var mount = yield mounter.create(settings);

        var dest_file = File.new_for_path(Path.build_filename(mount.path,
            dest_filename));
        FileIOStream stream;
        try {
            stream = yield dest_file.replace_readwrite_async(null, false,
                FileCreateFlags.REPLACE_DESTINATION);
        } catch (GLib.Error e) {
            throw new Valhalla.Error.MODULE_ERROR(e.message);
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
                throw new Valhalla.Error.MODULE_ERROR(e.message);
            }
            file.progress(offset+frame_length);
            if (file.cancellable.is_cancelled()) {
                success = false;
                break;
            }
        }

        try {
            yield stream.close_async();
        } catch (IOError e) {} // it should be safe to ignore this

        if (success)
            file.completed();
        else
            try {
                yield dest_file.delete_async();
            } catch (GLib.Error e) {
                throw new Valhalla.Error.MODULE_ERROR(
                    @"Failed to cancel upload: $(e.message)");
            }
    }
}

public Type[] register_module() {
    return {typeof(Fuse)};
}

class MountCommand : Object, Valhalla.Preference {
    public string? @default {get {
        return "sshfs example.com:/var/www/shared $f -C -o sshfs_sync";}}
    public string? pretty_name {get {return "Mount command";}}
    public string? help_text {get {
        return "Command to mount the filesystem\n" +
            "Use '$f' to indicate mount point";}}
    public string? @value {set; get;}
}

class ServeURL : Object, Valhalla.Preference {
    public string? @default {get {return "https://shared.example.com";}}
    public string? pretty_name {get {return "Serve URL";}}
    public string? help_text {get {
        return "The base URL at which files will appear";}}
    public string? @value {set; get;}
}

class MountMan : Object {
    public string? mount_command {set; get; default=null;}

    public string path;
    string unmount_command;
    int mounts;

    public async void exit() {
        mounts--;
        if (mounts == 0) {
            try {
                var p = new Subprocess.newv({"/bin/sh", "-c",
                    @"sleep 1 && $(unmount_command)"},
                    SubprocessFlags.INHERIT_FDS);

                yield p.wait_check_async();
            } catch (Error e) {
                warning("Unmount failed: %s", e.message);
                return;
            }

            if (DirUtils.remove(path) == -1)
                warning("Failed to remove temp mount: %s", strerror(errno));
        }
    }

    public async void enter() throws Error {
        if (mount_command == null)
            throw new IOError.FAILED(
                "Please set a mount command in the preferences panel");

        var mount_cmd = ((!) mount_command).replace("$f", Shell.quote(path));

        mounts++;
        if (mounts == 1) { // we're the first in, mount
            DirUtils.create(path, 0700);
            var p = new Subprocess.newv({"/bin/sh", "-c", mount_cmd},
                SubprocessFlags.STDOUT_PIPE|SubprocessFlags.STDERR_PIPE);

            try {
                yield p.wait_check_async(null);
            } catch (Error e) {
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
                throw new IOError.FAILED(stderr_data);
            }
        }
    }

    construct {
        path = Path.build_filename(Environment.get_tmp_dir(), "valhalla-mount");
        unmount_command = "fusermount -u %s".printf(Shell.quote(path));
        mounts = 0;
    }
}

public class Fuse : Valhalla.Uploader, Valhalla.Deleter {
    public override string pretty_name {get {return "FuseFS";}}
    public override string description {get {
        return "Mounts and copies to a\nfuse filesystem";}}

    private MountMan mounter = new MountMan();
    private Valhalla.Preference mount_command;
    private Valhalla.Preference serve_url;

    public async void @delete(Valhalla.File file) throws Error {
        yield mounter.enter();

        var filename = @"$(file.crc32)$(file.guess_extension())";
        var path = Path.build_filename(mounter.path, filename);

        if (!FileUtils.test(path, FileTest.EXISTS))
            throw new IOError.NOT_FOUND("File doesn't exist: %s", path);

        yield File.new_for_path(path).delete_async();

        yield mounter.exit();
    }

    public override async void upload(Valhalla.Transfer transfer) throws Error {
        var file = transfer.file;
        var dest_filename = @"$(file.crc32)$(file.guess_extension())";

        file.remote_path =
            Path.build_filename((!) serve_url.value, dest_filename);

        yield mounter.enter();

        var dest_file =
            File.new_for_path(Path.build_filename(mounter.path, dest_filename));

        yield file.file.copy_async(dest_file, FileCopyFlags.OVERWRITE,
            Priority.DEFAULT, transfer.cancellable,
            (uploaded) => transfer.bytes_uploaded = uploaded);

        FileUtils.chmod((!) dest_file.get_path(), 0544);

        transfer.completed();

        yield mounter.exit();
    }

    construct {
        mount_command = this.register_preference(typeof(MountCommand));
        mount_command.bind_property("value", mounter, "mount-command");
        serve_url = this.register_preference(typeof(ServeURL));
    }
}

public Type register_uploader() {
    return typeof(Fuse);
}

const string _id = "so.bob131.valhalla";
Settings settings;
utils.Database* database;
utils.Mount* mount;
bool _mount_instantiated = false;


class valhalla : Application {
    private void _init_settings() {
        var _be = utils.config.settings_backend_new("/%s/".printf(_id).replace(".", "/"));
        settings = new GLib.Settings.with_backend(_id, _be);
        database = new utils.Database();
    }

    private valhalla() {
        Object(flags: ApplicationFlags.HANDLES_OPEN|ApplicationFlags.HANDLES_COMMAND_LINE|ApplicationFlags.NON_UNIQUE);
        _init_settings();
    }

    ~valhalla() {
        delete database;
        if (_mount_instantiated) {
            delete mount;
        }
    }


    public override void open(File[] files, string hint) {
        foreach (var file in files) {
            if (file.query_exists()) {
                var url = utils.upload_file(file);
                if (url != null) {
                    stdout.printf("%s\n", url);
                }
            } else {
                stderr.printf(@"File '$(file.get_basename())' not found\n");
            }
        }
    }


    public override int command_line(ApplicationCommandLine command_line) {
        var args = command_line.get_arguments();
        args = args[1:args.length];

        // TODO: Actually implement proper argument parsing
        if (args[0] == "--screenshot" || args[0] == "-s") {
            unowned string[]? _ = null;
            Gtk.init(ref _);
            var file = utils.files.make_temp("png");
            var pixbuf = utils.screenshot.take_interactive();
            if (pixbuf != null) {
                try {
                    pixbuf.save(file.get_path(), "png");
                } catch (Error e) {
                    stderr.printf(@"Error capturing screenshot: $(e.message)\n");
                    return 1;
                }
                open({file}, ""); //upload file
                try {
                    file.delete();
                } catch (Error e) {} // hopefully the system will clean up
            }
        } else if (args[0] == "--find" || args[0] == "-f") {
            args = args[1:args.length]; // remove the switch
            foreach (string? arg in args) {
                arg = utils.checksum_from_arg(arg);
                if (arg == null) {
                    stderr.printf(@"File '$(arg)' not found\n");
                    return 1;
                }
                var r = database->exec("SELECT * FROM Files WHERE checksum = $CS", {arg});
                if (r == null) {
                    stderr.printf(@"No files matching checksum 0x$(arg)\n");
                    continue;
                }
                utils.cli.overwrite_prompt(@"Match for 0x$(arg)!", r);
            }
        } else if (args[0] == "--delete" || args[0] == "-d") {
            args = args[1:args.length]; // remove the switch
            foreach (string? arg in args) {
                arg = utils.checksum_from_arg(arg);
                if (arg == null) {
                    stderr.printf(@"File '$(arg)' not found\n");
                    return 1;
                }
                var r = database->exec("SELECT * FROM Files WHERE checksum = $CS", {arg});
                if (r == null) {
                    stderr.printf(@"No files matching checksum 0x$(arg)\n");
                    continue;
                }
                mount = new utils.Mount();
                string[] rnames = {};
                foreach (var entry in r) {
                    var name = entry.get("remote_filename");
                    GLib.File.new_for_path(GLib.Path.build_filename(mount->location, name)).delete();
                    rnames += name;
                }
                stderr.printf("Deleted: %s\n", string.joinv(", ", rnames));
                return 0;
            }
        } else if (args[0] == "--help" || args[0] == "-h") {
            stderr.printf("usage: valhalla [-f] [FILES]\n");
            stderr.printf("       valhalla -s\n");
            stderr.printf("\n");
            stderr.printf("Commandline Empyrean client\n");
            stderr.printf("\n");
            stderr.printf("commands:\n");
            stderr.printf("  -h, --help\t\tShow this help message and exit\n");
            stderr.printf("  -s, --screenshot\tCapture screenshot for upload\n");
            stderr.printf("  -f, --find\t\tFind files by hash\n");
            stderr.printf("  -d, --delete\t\tDelete files by hash\n");
            stderr.printf("\n");
            stderr.printf("FILES may be - for stdin (launches EDITOR if no input) or a list of space-\n");
            stderr.printf("separated files\n");
        } else { // no known switches given; assume we've been given a list of files
            if (args[0] == "-" || args.length == 0) {
                if (utils.cli.isatty()) {
                    var file = utils.files.make_temp("txt");
                    var editor = Environment.get_variable("EDITOR");
                    if (editor == null) {
                        editor = "vim"; // choose a sane default :^)
                    }
                    Subprocess proc;
                    try {
                        proc = new Subprocess.newv({editor, file.get_path()}, SubprocessFlags.STDIN_INHERIT);
                        proc.wait();
                    } catch (Error e) {
                        stderr.printf(@"Error starting editor: $(e.message)\n");
                        return 1;
                    }
                    if (file.query_exists()) {
                        open({file}, "");
                        try {
                            file.delete();
                        } catch (Error e) {}
                    } else {
                        stderr.printf("File creation aborted\n");
                    }
                } else {
                    var input = command_line.get_stdin();
                    var file = utils.files.make_temp();
                    FileOutputStream output;
                    try {
                        output = file.replace(null, false, FileCreateFlags.REPLACE_DESTINATION);
                        output.splice(input, OutputStreamSpliceFlags.NONE);
                        output.flush();
                    } catch (Error e) {
                        stderr.printf(@"Error: $(e.message)\n");
                        return 1;
                    }
                    file = File.new_for_path(file.get_path());
                    open({file}, "");
                    try {
                        file.delete();
                    } catch (Error e) {}
                }
            } else {
                Array<GLib.File> files = new Array<GLib.File>();
                foreach (var str in args) {
                    files.append_val(command_line.create_file_for_arg(str));
                }
                open(files.data, "");
            }
        }

        return 0;
    }


    public override void startup() {
        base.startup();
    }


    public override void activate() {
        base.activate();
    }


    public static int main(string[] args) {
        valhalla app = new valhalla();
        return app.run(args);
    }
}

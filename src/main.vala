const string _id = "so.bob131.valhalla";
const string _path = "/so/bob131/valhalla/";
Settings settings;
string? settings_section;
utils.Database* database;
utils.Mount* mount;
bool _mount_instantiated = false;


void init_stuff() {
    if (settings_section == null)
        settings_section = "default";
    settings = new GLib.Settings.with_backend(
        _id, utils.config.settings_backend_new(_path, (!) settings_section));
    database = new utils.Database();
}

void deinit_stuff() {
    delete database;
    if (_mount_instantiated) {
        delete mount;
    }
}



[GtkTemplate (ui = "/so/bob131/valhalla/ui/main.ui")]
class MainWindow : Gtk.ApplicationWindow {
    [GtkChild]
    private Gtk.Notebook notebook;
    [GtkChild]
    private Gtk.Image preview;
    [GtkChild]
    private Gtk.HeaderBar headerbar;
    [GtkChild]
    private Gtk.Button continue_button;
    [GtkChild]
    private Gtk.ProgressBar progress;
    [GtkChild]
    private Gtk.Revealer cancel_reveal;
    [GtkChild]
    private Gtk.LinkButton link;
    [GtkChild]
    private Gtk.Revealer save_reveal;

    public Gdk.Pixbuf screenshot {get; construct;}

    [GtkCallback]
    private void cancel(Gtk.Button _) {
        this.close();
    }

    [GtkCallback]
    private void @continue(Gtk.Button _) {
        if (notebook.page == (notebook.get_n_pages()-1)) {
            this.close();
        }
        notebook.next_page();
    }

    [GtkCallback]
    private void save_and_quit(Gtk.Button _) {
        var dialog = new Gtk.FileChooserDialog("Save as", this, Gtk.FileChooserAction.SAVE,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Save", Gtk.ResponseType.ACCEPT);

        var now = Time.local(time_t());
        dialog.set_current_name(now.format(settings.get_string("temp-names") + ".png"));

        var filter = new Gtk.FileFilter();
        filter.add_mime_type("image/png");
        dialog.set_filter(filter);

        if (dialog.run() == Gtk.ResponseType.ACCEPT) {
            screenshot.save((!) dialog.get_file().get_path(), "png");
            this.close();
        }

        dialog.close();
    }

    public MainWindow(Gdk.Pixbuf buf) {
        Object(screenshot: buf);
    }

    construct {
        Gdk.Rectangle screen_size;
        var screen = this.get_screen();
        screen.get_monitor_geometry(screen.get_monitor_at_window((!)screen.get_active_window()), out screen_size);

        var x = screenshot.width;
        var y = screenshot.height;
        while (true) {
            var keep_going = true;
            for (var i=0;i<2;i++) {
                if (x/(float) screen_size.width > 0.75 || y/(float) screen_size.height > 0.75) {
                    x = (int) Math.floor(x*0.75);
                    y = (int) Math.floor(y*0.75);
                } else
                    keep_going = false;
            }
            if (!keep_going)
                break;
        }
        if (x != screen_size.width || y != screen_size.height) {
            preview.set_from_pixbuf(screenshot.scale_simple(x, y, Gdk.InterpType.BILINEAR));
        } else {
            preview.set_from_pixbuf(screenshot);
        }
        preview.visible = true;
        this.show_all();

        notebook.switch_page.connect((page, num) => {
            var name = page.get_name();
            if (name == "transfer") {
                headerbar.subtitle = "Uploading file";
                continue_button.sensitive = false;
                save_reveal.set_reveal_child(false);
                progress.show_text = true;
                progress.pulse();
                var file = utils.files.make_temp("png");
                screenshot.save((!)file.get_path(), "png");
                utils.upload_file_async.begin(file,
                    (obj, res) => {
                        link.uri = (!) utils.upload_file_async.end(res);
                        link.label = link.uri;
                        continue_button.sensitive = true;
                        cancel_reveal.set_reveal_child(false);
                        headerbar.subtitle = "";
                    });
            } else if (name == "link") {
                continue_button.label = "Done";
            }
        });
    }
}



class gvalhalla : Gtk.Application {
    private MainWindow window;
    public bool interactive {get; construct;}

    public gvalhalla(bool @int = true) {
        Object(application_id: _id,
            flags: ApplicationFlags.NON_UNIQUE, interactive: @int);
        init_stuff();
    }

    ~gvalhalla() {
        deinit_stuff();
    }

    protected override void activate() {
        unowned string[]? _ = null;
        Gtk.init(ref _);
        Gdk.Pixbuf? pixbuf;
        if (interactive)
            pixbuf = utils.screenshot.take_interactive();
        else
            pixbuf = utils.screenshot.take();
        if (pixbuf != null) {
            window = new MainWindow((!) pixbuf);
            this.add_window(window);
        }
    }
}



class valhalla : Application {
    public valhalla() {
        Object(flags: ApplicationFlags.HANDLES_OPEN
                      |ApplicationFlags.HANDLES_COMMAND_LINE
                      |ApplicationFlags.NON_UNIQUE);
        init_stuff();
    }

    ~valhalla() {
        deinit_stuff();
    }


    public override void open(File[] files, string hint) {
        foreach (var file in files) {
            if (file.query_exists()) {
                var url = utils.upload_file(file);
                if (url != null) {
                    stdout.printf("%s\n", (!) url);
                }
            } else {
                stderr.printf(@"File '$((!)file.get_basename())' not found\n");
            }
        }
    }


    public override int command_line(ApplicationCommandLine command_line) {
        var args = command_line.get_arguments();
        args = args[1:args.length];

        if (settings.get_string("serve-url") == "") {
            stderr.printf("Invalid config detected!\n");
            if (utils.ui.confirm("Download previously sync'd config?", true)) {
                var url = utils.ui.prompt("URL of service: ");

                if (!/^https?:/i.match(url)) {
                    url = "http://" + url;
                }
                if (!/_valhalla.conf$/.match(url)) {
                    if (url[url.length] != '/') {
                        url += "/";
                    }
                    url += "_valhalla.conf";
                }

                stderr.printf("Fetching config...\r");
                var ss = new Soup.Session();
                var msg = new Soup.Message("GET", url);
                ss.send_message(msg);
                if (msg.status_code != 200) {
                    stderr.printf("\n");
                    stderr.printf(@"$(msg.reason_phrase) ($(msg.status_code))\n");
                    return 1;
                }

                var f = File.new_for_path(utils.config.path("valhalla.conf"));
                f.create_readwrite(FileCreateFlags.REPLACE_DESTINATION).output_stream.write(msg.response_body.flatten().data);
                settings = new GLib.Settings.with_backend(
                        _id, utils.config.settings_backend_new(_path, (!) settings_section));
            } else {
                stderr.printf("Please configure valhalla before invoking\n");
                return 1;
            }
        }

        // TODO: Actually implement proper argument parsing
        if (args[0] == "--screenshot" || args[0] == "-s") {
            unowned string[]? _ = null;
            Gtk.init(ref _);
            var file = utils.files.make_temp("png");
            var pixbuf = utils.screenshot.take_interactive();
            if (pixbuf != null) {
                try {
                    ((!)pixbuf).save((!) file.get_path(), "png");
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
            foreach (var arg in args) {
                var checksum = utils.checksum_from_arg(arg);
                if (checksum == null) {
                    stderr.printf(@"File '$(arg)' not found\n");
                    return 1;
                }
                var r = database->exec("SELECT * FROM Files WHERE checksum = $CS", {checksum});
                if (r == null) {
                    stderr.printf(@"No files matching checksum 0x$((!) checksum)\n");
                    continue;
                }
                utils.ui.overwrite_prompt(@"Match for 0x$((!) checksum)!", r);
            }
        } else if (args[0] == "--delete" || args[0] == "-d") {
            args = args[1:args.length]; // remove the switch
            foreach (var arg in args) {
                var checksum = utils.checksum_from_arg(arg);
                if (checksum == null) {
                    if (database->contains(arg)) {
                        utils.delete_file(arg);
                        stdout.printf("Deleted: %s\n", arg);
                        continue;
                    }
                    stderr.printf(@"File '$(arg)' not found\n");
                    return 1;
                }
                var r = database->exec("SELECT * FROM Files WHERE checksum = $CS", {checksum});
                if (r == null) {
                    stderr.printf(@"No files matching checksum 0x$((!)checksum)\n");
                    continue;
                }
                string?[] rnames = {};
                foreach (var entry in r) {
                    var name = entry.get("remote_filename");
                    utils.delete_file(name);
                    rnames += name;
                }
                stdout.printf("Deleted: %s\n", string.joinv(", ", rnames));
                return 0;
            }
        } else if (args[0] == "--list" || args[0] == "-l") {
            foreach (var entry in database->exec("SELECT * FROM Files")) {
                stdout.printf(@"$(entry.get("remote_filename"))\n");
            }
        } else if (args[0] == "--sync") {
            mount = new utils.Mount();
            stderr.printf("Synchronising configuration file... ");
            var file = File.new_for_path(utils.config.path("valhalla.conf"));
            file.copy(GLib.File.new_for_path(GLib.Path.build_filename(mount->location, "_valhalla.conf")),
                GLib.FileCopyFlags.OVERWRITE|GLib.FileCopyFlags.NOFOLLOW_SYMLINKS);
            stderr.printf("DONE!\n");
            return 0;
        } else if (args[0] == "--help" || args[0] == "-h") {
            stderr.printf("usage: valhalla [FILES]\n");
            stderr.printf("       valhalla [-f | -d] [FILE or HASH]...\n");
            stderr.printf("       valhalla -s\n");
            stderr.printf("       valhalla -l\n");
            stderr.printf("       valhalla --sync\n");
            stderr.printf("\n");
            stderr.printf("Commandline file sharer\n");
            stderr.printf("\n");
            stderr.printf("commands:\n");
            stderr.printf("  -h, --help\t\tShow this help message and exit\n");
            stderr.printf("  -s, --screenshot\tCapture screenshot for upload\n");
            stderr.printf("  -f, --find\t\tFind files by hash\n");
            stderr.printf("  -d, --delete\t\tDelete files by hash\n");
            stderr.printf("  -l  --list\t\tList all indexed remote filenames\n");
            stderr.printf("      --sync\t\tUpload config file for later setups\n");
            stderr.printf("\n");
            stderr.printf("options:\n");
            stderr.printf("  -c  --config\t\tSelect configuration profile\n");
            stderr.printf("\n");
            stderr.printf("FILES may be - for stdin (launches EDITOR if no input) or a list of space-\n");
            stderr.printf("separated files\n");
        } else { // no known switches given; assume we've been given a list of files
            if (args[0] == "-" || args.length == 0) {
                if (utils.ui.isatty()) {
                    var file = utils.files.make_temp("txt");
                    var editor = Environment.get_variable("EDITOR");
                    if (editor == null) {
                        editor = "vim"; // choose a sane default :^)
                    }
                    Subprocess proc;
                    try {
                        proc = new Subprocess.newv({(!) editor, (!) file.get_path()}, SubprocessFlags.STDIN_INHERIT);
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
}



int main(string[] args) {
    var exec_path = args[0].split("/");
    var exec_name = exec_path[exec_path.length-1];

    if (exec_name == "gvalhalla") {
        var app = new gvalhalla(!("--" in args));
        return app.run(args);
    }
    else {
        var mutable_args = new Array<string>();
        mutable_args.data = args;

        for (var i=0;i<args.length;i++) {
            if (args[i] == "-c" || args[i] == "--config") {
                if (i != args.length-1) {
                    settings_section = args[i+1];
                    mutable_args.remove_range(i, 2);
                    args = mutable_args.data;
                    break;
                } else {
                    stderr.printf("Argument required for --config\n");
                    return 1;
                }
            }
        }
        var app = new valhalla();
        return app.run(args);
    }
}

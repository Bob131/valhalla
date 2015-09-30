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
            screenshot.save(dialog.get_file().get_path(), "png");
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
        screen.get_monitor_geometry(screen.get_monitor_at_window(screen.get_active_window()), out screen_size);

        var x = screenshot.width;
        var y = screenshot.height;
        for (var i=0;i<2;i++) {
            if (x/(float) screen_size.width > 0.75 || y/(float) screen_size.height > 0.75) {
                x = (int) Math.floor(x*0.75);
                y = (int) Math.floor(y*0.75);
            }
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
                screenshot.save(file.get_path(), "png");
                utils.upload_file_async.begin(file,
                    (obj, res) => {
                        link.uri = utils.upload_file_async.end(res);
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

    private gvalhalla() {
        Object(application_id: _id,
            flags: ApplicationFlags.NON_UNIQUE);
        init_stuff();
    }

    ~gvalhalla() {
        deinit_stuff();
    }

    protected override void activate() {
        unowned string[]? _ = null;
        Gtk.init(ref _);
        var pixbuf = utils.screenshot.take_interactive();
        if (pixbuf != null) {
            window = new MainWindow(pixbuf);
            this.add_window(window);
        }
    }

    public static int main(string[] args) {
        gvalhalla app = new gvalhalla();
        return app.run(args);
    }
}

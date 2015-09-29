[GtkTemplate (ui = "/so/bob131/valhalla/ui/main.ui")]
class MainWindow : Gtk.ApplicationWindow {
    [GtkChild]
    private Gtk.Notebook notebook;
    [GtkChild]
    private Gtk.ScrolledWindow previewport;
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

    public MainWindow(string preview_path) {
        previewport.set_size_request(400, 300);
        preview.set_from_file(preview_path);
        preview.visible = true;
        headerbar.subtitle = "Screenshot preview";

        notebook.switch_page.connect((page, num) => {
            var name = page.get_name();
            if (name == "transfer") {
                headerbar.subtitle = "Uploading file";
                continue_button.sensitive = false;
                progress.show_text = true;
                progress.pulse();
                utils.upload_file_async.begin(File.new_for_path(preview_path),
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
        var file = utils.files.make_temp("png");
        var pixbuf = utils.screenshot.take_interactive();
        if (pixbuf != null) {
            try {
                pixbuf.save(file.get_path(), "png");
            } catch (Error e) {
                stderr.printf(@"Error capturing screenshot: $(e.message)\n");
            }
            window = new MainWindow(file.get_path());
            this.add_window(window);
        }
    }

    public static int main(string[] args) {
        gvalhalla app = new gvalhalla();
        return app.run(args);
    }
}

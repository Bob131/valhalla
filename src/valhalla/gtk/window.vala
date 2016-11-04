valhalla get_app() {
    return (valhalla) Application.get_default();
}

Window get_main_window() {
    var window = get_app().window;
    assert (window != null);
    return (!) window;
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/window.ui")]
class Window : Gtk.ApplicationWindow {
    public new valhalla application {set; get;}

    [GtkChild]
    public ListDetailStack file_window;
    [GtkChild]
    TransferList transfers;
    [GtkChild]
    Gtk.InfoBar error_bar;
    [GtkChild]
    Gtk.Label error_text;
    [GtkChild]
    Gtk.Overlay stack_overlay;
    [GtkChild]
    Gtk.Stack main_window_stack;
    [GtkChild]
    Gtk.Revealer back_reveal;
    [GtkChild]
    Gtk.Revealer transfers_clear_revealer;

    public void display_error(string text) {
        error_text.label = text.strip();
        error_bar.get_action_area().show_all();
        error_bar.get_content_area().show_all();
        error_bar.visible = true;
    }

    public void stack_notify(string message) {
        var notification = new Gd.Notification();
        notification.timeout = 2;
        var msg = new Gtk.Label(message);
        msg.margin = 6;
        notification.add(msg);
        notification.show_all();
        stack_overlay.add_overlay(notification);
    }

    [GtkCallback]
    void dismiss_error() {
        error_bar.visible = false;
    }

    [GtkCallback]
    void back_button_clicked() {
        file_window.display_list();
    }

    void transfer_event() {
        if (!(main_window_stack.visible_child is TransferList))
            main_window_stack.child_set(transfers, "needs-attention", true);
    }

    public async void kickoff_upload(File file, bool switch_view = true) {
        // allow any pending Gtk events (like dialog destruction) to
        // complete before we continue
        Idle.add(kickoff_upload.callback);
        yield;

        TransferWidget transfer;
        try {
            transfer = new TransferWidget(file);
        } catch (Error e) {
            display_error(e.message);
            return;
        }

        if (transfer.cancellable.is_cancelled())
            return;

        transfer.completed.connect(() => transfer_event());
        transfer.failed.connect(() => transfer_event());

        if (switch_view)
            main_window_stack.visible_child = transfers;
        else
            transfer_event();

        transfers.add(transfer);

        var module = this.application.loader.get_active();
        if (module == null) {
            display_error("Please configure a module in the preferences panel");
            return;
        }

        try {
            yield ((!) module).upload(transfer);
        } catch (Error e) {
            if (e is IOError.CANCELLED
                    && transfer.status == TransferStatus.CANCELLED)
                return;

            transfer.failed();
            display_error(e.message);
        }
    }

    [GtkCallback]
    async void upload_clicked() {
        var dialog = new Gtk.FileChooserDialog("File Upload", this,
            Gtk.FileChooserAction.OPEN, "_Cancel", Gtk.ResponseType.CANCEL,
            "_Open", Gtk.ResponseType.ACCEPT);
        dialog.select_multiple = true;
        var response = dialog.run();
        dialog.close();
        if (response == Gtk.ResponseType.ACCEPT)
            dialog.get_uris().foreach(
                (uri) => kickoff_upload.begin(File.new_for_uri(uri), true));
    }

    [GtkCallback]
    public async void capture_screenshot() {
        this.visible = false;

        var screenshot = yield Screenshot.take_interactive();

        this.visible = true;

        if (screenshot != null) {
            var preview = new ScreenshotPreview((!) screenshot);

            var response = int.MAX;
            preview.response.connect((resp) => response = resp);
            while (response == int.MAX) {
                Idle.add(capture_screenshot.callback);
                yield;
            }

            preview.close();

            if (response != Gtk.ResponseType.OK)
                return;

            File file;

            try {
                FileIOStream streams;
                file = GLib.File.new_tmp("valhalla_XXXXXX.png", out streams);
                ((!) screenshot).save_to_stream(streams.output_stream,
                    "png");
                streams.close();
            } catch (Error e) {
                new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                    "Failed to save screenshot: %s", e.message).run();
                return;
            }

            yield kickoff_upload(file, true);

            try {
                file.delete();
            } catch {}
        }
    }

    [GtkCallback]
    void transfers_clear() {
        transfers.clear();
    }

    public Window(valhalla application) {
        Object(application: application);
    }

    construct {
        main_window_stack.notify["visible-child"].connect(() => {
            main_window_stack.child_set(main_window_stack.visible_child,
                "needs-attention", false);
        });

        main_window_stack.bind_property("visible-child", back_reveal,
            "reveal-child", BindingFlags.DEFAULT,
            (binding, src, ref target) => {
                target = src.get_object() is ListDetailStack &&
                    file_window.visible_child is DetailsStack;
                return true;
            });

        main_window_stack.bind_property("visible-child",
            transfers_clear_revealer, "reveal-child", BindingFlags.DEFAULT,
            (binding, src, ref target) => {
                target = src.get_object() is TransferList;
                return true;
            });

        file_window.bind_property("visible-child", back_reveal,
            "reveal-child", BindingFlags.DEFAULT,
            (binding, src, ref target) => {
                target = src.get_object() is DetailsStack;
                return true;
            });

        this.show_all();
    }
}

namespace Valhalla.Widgets {
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
        public FileWindow file_window;
        [GtkChild]
        private Transfers transfers;
        [GtkChild]
        private Gtk.InfoBar error_bar;
        [GtkChild]
        private Gtk.Label error_text;
        [GtkChild]
        private Gtk.Overlay stack_overlay;
        [GtkChild]
        public Gtk.Stack main_window_stack;
        [GtkChild]
        private Gtk.Revealer back_reveal;
        [GtkChild]
        private Gtk.Revealer transfers_clear_revealer;

        public bool one_shot = false; // this is true if we've just been
                                      // launched for the purpose of capturing a
                                      // screenshot. If the user cancels a
                                      // capture when this is true, we want to
                                      // outright exit instead of (re)displaying
                                      // `this`

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
        private void dismiss_error() {
            error_bar.visible = false;
        }

        [GtkCallback]
        private void back_button_clicked() {
            file_window.back_button_clicked();
        }

        public async void kickoff_upload(string path, bool switch_view = true) {
            // allow any pending Gtk events (like dialog destruction) to
            // complete before we continue
            Idle.add(kickoff_upload.callback);
            yield;
            TransferWidget transfer;
            try {
                transfer = new TransferWidget.from_path(path);
            } catch (GLib.Error e) {
                display_error(e.message);
                return;
            }
            if (transfer.cancellable.is_cancelled())
                return;
            var module = this.application.loader.get_active();
            transfer.completed.connect(() => {
                if (!(main_window_stack.visible_child is Transfers))
                    main_window_stack.child_set(transfers, "needs-attention",
                        true);
            });
            transfer.failed.connect(() => {
                if (!(main_window_stack.visible_child is Transfers))
                    main_window_stack.child_set(transfers, "needs-attention",
                        true);
            });
            if (switch_view)
                main_window_stack.visible_child = transfers;
            else if (!(main_window_stack.visible_child is Transfers))
                main_window_stack.child_set(transfers, "needs-attention", true);
            transfers.add(transfer);
            try {
                yield ((!) module).upload(transfer);
            } catch (Module.Error e) {
                transfer.failed();
                display_error(e.message);
            }
        }

        [GtkCallback]
        private async void upload_clicked(Gtk.Button _) {
            var dialog = new Gtk.FileChooserDialog("File Upload", this,
                Gtk.FileChooserAction.OPEN, "_Cancel", Gtk.ResponseType.CANCEL,
                "_Open", Gtk.ResponseType.ACCEPT);
            dialog.select_multiple = true;
            var response = dialog.run();
            dialog.close();
            if (response == Gtk.ResponseType.ACCEPT)
                dialog.get_uris().foreach((file) => {
                    kickoff_upload.begin(file, true);
                });
        }

        [GtkCallback]
        public async void capture_screenshot() {
            var module = this.application.loader.get_active();
            if (module == null) {
                display_error(
                    "Please configure a module in the preferences panel");
                return;
            }
            SourceFunc fail = () => {
                if (this.one_shot && !this.visible)
                    this.close();
                else
                    this.visible = true;
                return false;
            };
            this.visible = false;
            var screenshot = yield Screenshot.take_interactive();
            if (screenshot != null) {
                var dialog = new Gtk.Dialog.with_buttons("Screenshot Preview",
                    this, Gtk.DialogFlags.USE_HEADER_BAR, "_Cancel",
                    Gtk.ResponseType.CANCEL, "_Upload", Gtk.ResponseType.OK);

                var headerbar = (Gtk.HeaderBar) dialog.get_header_bar();
                var sep = new Gtk.Separator(Gtk.Orientation.VERTICAL);
                headerbar.add(sep);
                headerbar.child_set_property(sep, "pack-type",
                    Gtk.PackType.END);
                var save_button = new Gtk.Button.from_icon_name(
                    "document-save-as-symbolic");
                save_button.clicked.connect(() => {
                    var fchooser = new Gtk.FileChooserDialog(null, dialog,
                        Gtk.FileChooserAction.SAVE, "_Cancel",
                        Gtk.ResponseType.CANCEL, "_Save",
                        Gtk.ResponseType.ACCEPT);
                    var filter = new Gtk.FileFilter();
                    filter.add_pixbuf_formats();
                    fchooser.filter = filter;
                    fchooser.set_current_name(
                        @"Screenshot from $(Time.local(time_t())).png");
                    var response = fchooser.run();
                    fchooser.close();
                    if (response == Gtk.ResponseType.ACCEPT) {
                        var path = (!) fchooser.get_file().get_path();
                        FileUtils.unlink(path);
                        var format = "png";
                        var extension = path.reverse().split(".")[0].reverse();
                        var formats = Gdk.Pixbuf.get_formats();
                        foreach (var pixbuf_format in formats)
                            if (extension in pixbuf_format.get_extensions()) {
                                format = pixbuf_format.get_name();
                                break;
                            }
                        try {
                            ((!) screenshot).save(path, format);
                            dialog.response(Gtk.ResponseType.CANCEL);
                        } catch (GLib.Error e) {
                            new Gtk.MessageDialog(fchooser,
                                Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR,
                                Gtk.ButtonsType.CLOSE,
                                "Failed to save screenshot: %s",
                                e.message).run();
                        }
                    }
                    fchooser.destroy();
                });
                headerbar.add(save_button);
                headerbar.child_set_property(save_button, "pack-type",
                    Gtk.PackType.END);
                headerbar.show_all();

                var inner = dialog.get_content_area();
                inner.border_width = 0;
                inner.add(new Gtk.Image.from_pixbuf(
                    Screenshot.scale_for_preview((!) screenshot,
                    this.get_screen())));
                inner.show_all();

                dialog.response.connect((response) => {
                    if (response == Gtk.ResponseType.OK) {
                        FileIOStream streams;
                        File file;
                        try {
                            file = File.new_tmp("valhalla_XXXXXX.png", out streams);
                            ((!) screenshot).save_to_stream(streams.output_stream,
                                "png");
                            this.visible = true;
                            dialog.close();
                            kickoff_upload.begin((!) file.get_path(), true,
                                    (obj, res) => {
                                kickoff_upload.end(res);
                                try {
                                    file.delete();
                                } catch {}
                            });
                        } catch (GLib.Error e) {
                            new Gtk.MessageDialog(dialog, Gtk.DialogFlags.MODAL,
                                Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                                "Failed to save screenshot: %s", e.message).run();
                        }
                    } else if (response != Gtk.ResponseType.DELETE_EVENT)
                        dialog.close();
                });
                dialog.close.connect(() => {
                    fail();
                });
                dialog.show_all();
            } else
                fail();
        }

        [GtkCallback]
        private void transfers_clear(Gtk.Button _) {
            transfers.clear();
        }

        public Window(valhalla application) {
            Object(application: application);
        }

        construct {
            main_window_stack.notify["visible-child"].connect((_) => {
                main_window_stack.child_set(main_window_stack.visible_child,
                    "needs-attention", false);
            });

            main_window_stack.bind_property("visible-child", back_reveal,
                "reveal-child", BindingFlags.DEFAULT,
                (binding, src, ref target) => {
                    target = src.get_object() is FileWindow &&
                        file_window.visible_child is DisplayFile;
                    return true;
                });
            main_window_stack.bind_property("visible-child",
                transfers_clear_revealer, "reveal-child", BindingFlags.DEFAULT,
                (binding, src, ref target) => {
                    target = src.get_object() is Transfers;
                    return true;
                });

            file_window.bind_property("visible-child", back_reveal,
                "reveal-child", BindingFlags.DEFAULT,
                (binding, src, ref target) => {
                    target = src.get_object() is DisplayFile;
                    return true;
                });

            this.show_all();
        }
    }
}

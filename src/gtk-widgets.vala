namespace Valhalla.Widgets {
    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/prefs.ui")]
    class Preferences : Gtk.Box {
        [GtkTemplate (ui = "/so/bob131/valhalla/gtk/prefs-list.ui")]
        private class ListModule : Gtk.Box {
            public Modules.BaseModule module {construct; get;}

            [GtkChild]
            private Gtk.Label module_name;
            [GtkChild]
            private Gtk.Label module_description;

            public ListModule(Modules.BaseModule module) {
                Object(module: module);
                module_name.label = module.pretty_name;
                module_description.label = @"<small>$(module.description)</small>";
            }
        }

        [GtkChild]
        private Gtk.ListBox modules;
        [GtkChild]
        private Gtk.Box controls;

        [GtkCallback]
        private void module_selected(Gtk.ListBoxRow? row) {
            if (row == null)
                return;
            var module = (row.get_child() as ListModule).module;
            Config.settings["module"] = module.name;
            foreach (var child in controls.get_children())
                child.destroy();
            if (!module.implements_delete) {
                var caution = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                caution.halign = Gtk.Align.CENTER;
                caution.add(new Gtk.Image.from_icon_name("dialog-warning", Gtk.IconSize.LARGE_TOOLBAR));
                caution.add(new Gtk.Label("This module does not support file deletion"));
                controls.add(caution);
            }
            var size_group = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
            foreach (var pref in module.build_panel()) {
                var indent = 0;
                if (pref.label != null) {
                    var label = new Gtk.Label(pref.label);
                    label.halign = Gtk.Align.START;
                    controls.add(label);
                    indent = 12;
                }
                pref.margin_left = indent;
                pref.hexpand = true;
                size_group.add_widget(pref);
                if (pref.help != null) {
                    var help_popover = new Gtk.Popover(pref);
                    var help_label = new Gtk.Label(pref.help);
                    help_label.margin = 6;
                    help_label.visible = true;
                    help_popover.add(help_label);
                    help_popover.modal = false;
                    help_popover.position = Gtk.PositionType.BOTTOM;
                    pref.event.connect((e) => {
                        if (e.type == Gdk.EventType.ENTER_NOTIFY)
                            help_popover.show();
                        else if (e.type == Gdk.EventType.LEAVE_NOTIFY)
                            help_popover.hide();
                        return false;
                    });
                }
                if (module.settings[pref.key] != null)
                    pref.write(module.settings[pref.key]);
                if (pref.default != null)
                    (module.settings as Config.MutableSettings).set_default(pref.key, pref.default);
                pref.change_notify.connect(() => {
                    (module.settings as Config.MutableSettings)[pref.key] = pref.read();
                });
                controls.add(pref);
            }
            controls.show_all();
        }

        construct {
            var i = 0;
            foreach (var module in Modules.get_modules()) {
                modules.add(new ListModule(module));
                if (module.name == Config.settings["module"]) {
                    modules.select_row(modules.get_row_at_index(i));
                }
                i++;
            }
        }
    }

    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/transfers.ui")]
    public class TransferWidget : Gtk.Box, Transfer {
        private string _remote_path;

        public Time timestamp {protected set; get;}
        public string crc32 {protected set; get;}
        public string file_name {protected set; get;}
        public uint8[] file_contents {protected set; get;}
        public string file_type {protected set; get;}

        public string local_filename {set; get;}
        public string remote_path {get {return _remote_path;}}
        public string module_name {set; get;}

        public Cancellable cancellable {protected set; get;}
        public string status {private set; get;}

        private Database.Database db;

        [GtkChild]
        private Gtk.Label file_name_label;
        [GtkChild]
        private Gtk.Button copy_button;
        [GtkChild]
        private Gtk.Button cancel_button;
        [GtkChild]
        private Gtk.ProgressBar progress_bar;

        public signal void failed();

        public void set_remote_path(string path) throws Valhalla.Error {
            if (Uri.parse_scheme(path) == null)
                throw new Valhalla.Error.INVALID_REMOTE_PATH(@"URL $(path) is invalid");
            if (!db.unique_hash(crc32)) {
                var msg = new Gtk.MessageDialog((Application.get_default() as valhalla).window,
                    Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                    "A file with hash %s appears to have already been uploaded. Continue, potentially overwriting the existing file?",
                    crc32);
                var result = msg.run();
                msg.destroy();
                if (result != Gtk.ResponseType.YES)
                    throw new Valhalla.Error.CANCELLED("");
            } else if (!db.unique_url(path)) {
                var msg = new Gtk.MessageDialog((Application.get_default() as valhalla).window,
                    Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                    "A file with the URL %s already exists. Continue and overwrite the existing file?",
                    path);
                var result = msg.run();
                msg.destroy();
                if (result != Gtk.ResponseType.YES)
                    throw new Valhalla.Error.CANCELLED("");
            }
            _remote_path = path;

            // generate thumbnail now
            var dummy = new Database.RemoteFile();
            dummy.remote_path = path;
            dummy.file_type = this.file_type;
            dummy.local_filename = this.local_filename;
            dummy.crc32 = this.crc32;
            Thumbnailer.get_thumbnail.begin(dummy, (obj, res) => {
                Thumbnailer.get_thumbnail.end(res);
            });
        }

        public TransferWidget.from_path(string path) {
            Object();

            this.db = (Application.get_default() as valhalla).database;
            this.completed.connect(() => {
                db.commit_transfer(this);
            });

            this.init_for_path(path);
            crc32 = "%08x".printf((uint) ZLib.Utility.adler32(1, file_contents));
            local_filename = path;
            module_name = Config.settings["module"];

            file_name_label.label = file_name;
            this.bind_property("status", progress_bar, "text");
            status = "Initializing...";
            progress_bar.pulse();

            copy_button.clicked.connect(() => {
                var clipboard = Gtk.Clipboard.get_default(Gdk.Display.get_default());
                clipboard.set_text(remote_path, remote_path.length);
                (Application.get_default() as valhalla).window.stack_notify("URL copied to clipboard");
            });
            cancel_button.clicked.connect(() => {
                if (status == "Upload failed" || status == "Cancelled" || status == "Done!")
                    this.destroy();
                else
                    this.cancellable.cancel();
            });

            var pulse = true;
            Timeout.add(500, () => {
                if (pulse)
                    progress_bar.pulse();
                else
                    cancel_button.sensitive = true;
                return pulse;
            });
            this.progress.connect((bytes) => {
                pulse = false;
                if (this.cancellable.is_cancelled())
                    return;
                double fraction = (double) bytes / file_contents.length;
                status = @"$(Math.floor(fraction*100))%";
                progress_bar.fraction = fraction;
            });
            this.failed.connect(() => {
                pulse = false;
                status = "Upload failed";
                progress_bar.fraction = 0;
                new Notify.Notification("Upload failed",
                    Path.get_basename(local_filename), "document-send-symbolic").show();
            });
            this.cancellable.connect((_) => {
                pulse = false;
                status = "Cancelled";
                progress_bar.fraction = 0;
            });
            this.completed.connect(() => {
                pulse = false;
                copy_button.sensitive = true;
                status = "Done!";
                progress_bar.fraction = 1;
                new Notify.Notification("Upload complete",
                    remote_path, "document-send-symbolic").show();
            });

            this.show_all();
        }
    }

    class Transfers : Gtk.Box {
        private Gtk.ListBox listbox;

        public override void add(Gtk.Widget widget) {
            if (!(widget is Gtk.ListBoxRow)) {
                var entry = new Gtk.ListBoxRow();
                widget.destroy.connect(() => {
                    entry.destroy();
                });
                entry.add(widget);
                entry.show_all();
                listbox.add(entry);
            } else
                listbox.add(widget);
        }

        public void clear() {
            listbox.foreach((row) => {
                var transfer = (row as Gtk.ListBoxRow).get_child() as TransferWidget;
                if (transfer.status == "Done!" || transfer.status == "Upload failed"
                        || transfer.status == "Cancelled")
                    transfer.destroy();
            });
        }

        construct {
            listbox = new Gtk.ListBox();
            listbox.row_activated.connect((row) => {
                var transfer = row.get_child() as TransferWidget;
                if (transfer.status == "Done!")
                    AppInfo.launch_default_for_uri(transfer.remote_path, null);
            });
            listbox.selection_mode = Gtk.SelectionMode.NONE;
            listbox.activate_on_single_click = true;

            var placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            placeholder.add(new Gtk.Image.from_icon_name("network-idle-symbolic",
                Gtk.IconSize.DIALOG));
            placeholder.add(new Gtk.Label("No transfers pending"));
            placeholder.halign = Gtk.Align.CENTER;
            placeholder.valign = Gtk.Align.CENTER;
            placeholder.sensitive = false;
            placeholder.show_all();
            listbox.set_placeholder(placeholder);

            var list_window = new Gtk.ScrolledWindow(null, null);
            list_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            list_window.expand = true;
            list_window.add(listbox);
            base.add(list_window);
            this.show_all();
        }
    }

    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/files.ui")]
    class DisplayFile : Gtk.Box {
        public Database.RemoteFile file {construct; get;}

        [GtkChild]
        private Gtk.Grid info_grid;
        private int grid_row_counter = 2;

        [GtkChild]
        private Gtk.Label title;
        [GtkChild]
        private Gtk.Stack thumbnail_window;
        [GtkChild]
        private Gtk.LinkButton link;
        [GtkChild]
        private Gtk.Button forget_button;
        [GtkChild]
        private Gtk.Button delete_button;
        [GtkChild]
        private Gtk.Revealer delete_spinner_reveal;

        // allow signal callbacks to fire before we've actually been destroyed
        public signal void start_destroy();

        private void build_row(string name, string? val = null) {
            var label = new Gtk.Label(name);
            if (val == null)
                info_grid.attach(label, 1, grid_row_counter, 2);
            else {
                label.justify = Gtk.Justification.RIGHT;
                label.halign = Gtk.Align.END;
                info_grid.attach(label, 1, grid_row_counter);
                var val_label = new Gtk.Label(val);
                val_label.halign = Gtk.Align.START;
                info_grid.attach(val_label, 2, grid_row_counter);
            }
            grid_row_counter++;
        }

        public DisplayFile(Database.RemoteFile file) {
            Object(file: file);
        }

        construct {
            file.remove_from_database.connect(() => {
                this.start_destroy();
            });

            title.label = @"<b>$(Path.get_basename(file.local_filename))</b>";

            Thumbnailer.get_thumbnail.begin(file, (obj, res) => {
                var thumbnail_pixbuf = Thumbnailer.get_thumbnail.end(res);
                Gtk.Image thumbnail;
                if (thumbnail_pixbuf == null)
                    thumbnail = new Gtk.Image.from_gicon(ContentType.get_icon(file.file_type), Gtk.IconSize.DIALOG);
                else
                    thumbnail = new Gtk.Image.from_pixbuf(thumbnail_pixbuf);
                thumbnail.show();
                thumbnail_window.add_named(thumbnail, "thumb");
                thumbnail_window.visible_child_name = "thumb";
            });

            link.uri = file.remote_path;
            link.label = file.remote_path;
            build_row("Uploaded at:", file.timestamp.to_string());
            build_row("Checksum:", file.crc32);
            build_row("File type:", file.file_type);

            forget_button.clicked.connect((_) => {
                var msg = new Gtk.MessageDialog((Application.get_default() as valhalla).window,
                    Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, "%s",
                    "This will remove the file from the files pane, but the file will remain available via the link. This action cannot be undone. Are you sure?");
                if (msg.run() == Gtk.ResponseType.YES)
                    file.remove_from_database();
                msg.destroy();
            });

            if (file.module == null || !file.module.implements_delete)
                delete_button.sensitive = false;
            delete_button.clicked.connect((_) => {
                var msg = new Gtk.MessageDialog((Application.get_default() as valhalla).window,
                    Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, "%s",
                    "Are you sure you want to delete this file? This action cannot be undone");
                if (msg.run() == Gtk.ResponseType.YES) {
                    forget_button.sensitive = false;
                    delete_button.sensitive = false;
                    delete_spinner_reveal.reveal_child = true;
                    file.module.delete.begin(file.remote_path, (obj, res) => {
                        try {
                            file.module.delete.end(res);
                            file.remove_from_database();
                            (Application.get_default() as valhalla).window.stack_notify("File deleted");
                        } catch (Valhalla.Error e) {
                            (Application.get_default() as valhalla).window.display_error(e.message);
                        }
                        forget_button.sensitive = true;
                        delete_button.sensitive = true;
                        delete_spinner_reveal.reveal_child = false;
                    });
                }
                msg.destroy();
            });

            this.show_all();
        }
    }

    class ListFile : Gtk.ListBoxRow {
        public Database.RemoteFile file {construct; get;}
        public bool select_mode {set; get; default = false;}

        public signal void select_me_pls();
        public signal void unselect_me_pls();

        public override bool button_press_event(Gdk.EventButton ev) {
            if (ev.type == Gdk.EventType.BUTTON_PRESS) {
                if (!select_mode) {
                    if (ev.button == 1)
                        this.activate();
                    else if (ev.button == 3 && this.selectable) {
                        (Application.get_default() as valhalla).window.select_button.active = true;
                        select_me_pls();
                    }
                } else {
                    if (this.is_selected())
                        unselect_me_pls();
                    else
                        select_me_pls();
                }
                return true;
            }
            return false;
        }

        public ListFile(Database.RemoteFile file) {
            Object(file: file);
        }

        construct {
            var inner = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            inner.margin = 12;

            var icon = ContentType.get_icon(file.file_type);
            inner.add(new Gtk.Image.from_gicon(icon, Gtk.IconSize.MENU));

            var label = new Gtk.Label(Path.get_basename(file.local_filename));
            label.hexpand = true;
            label.halign = Gtk.Align.START;
            inner.add(label);

            if (file.module == null || !file.module.implements_delete) {
                this.selectable = false;
                var warning_reveal = new Gtk.Revealer();
                warning_reveal.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
                warning_reveal.reveal_child = false;
                warning_reveal.add(new Gtk.Image.from_icon_name("dialog-warning", Gtk.IconSize.BUTTON));
                this.bind_property("select-mode", warning_reveal, "reveal-child");
                inner.add(warning_reveal);
            }

            var date = new Gtk.Label(file.timestamp.to_string());
            date.halign = Gtk.Align.END;
            inner.add(date);

            var evbox = new Gtk.EventBox();
            evbox.add(inner);
            this.add(evbox);
            this.set_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            this.show_all();
        }
    }

    class Files : Gtk.ListBox {
        private Database.Database db;
        private Gtk.Button delete_button;

        private void populate() {
            this.foreach((row) => {
                row.destroy();
            });
            foreach (var file in db.get_files()) {
                var lf = new ListFile(file);
                lf.select_me_pls.connect(() => {
                    this.select_row(lf);
                });
                lf.unselect_me_pls.connect(() => {
                    this.unselect_row(lf);
                });
                this.add(lf);
            }
        }

        public void toggle_select_mode(bool select) {
            foreach (var row in this.get_children())
                (row as ListFile).select_mode = select;
            if (select)
                this.selection_mode = Gtk.SelectionMode.MULTIPLE;
            else
                this.selection_mode = Gtk.SelectionMode.NONE;
        }

        private new Database.RemoteFile[] get_selected_rows() {
            var rows = base.get_selected_rows();
            Database.RemoteFile[] files = {};
            foreach (var row in rows) {
                var file = (row as ListFile).file;
                assert (file.module != null && file.module.implements_delete);
                files += file;
            }
            return files;
        }

        public override void drag_data_received(Gdk.DragContext context, int _,
                int __, Gtk.SelectionData data, uint ___, uint time) {
            Gtk.drag_finish(context, true, false, time);
            foreach (var path in data.get_uris()) {
                assert (path.has_prefix("file://"));
                path = path[7:path.length];
                (Application.get_default() as valhalla).window.kickoff_upload.begin(path);
            }
        }

        construct {
            var app = Application.get_default() as valhalla;
            db = app.database;

            this.selected_rows_changed.connect(() => {
                // app.window is null when we get constructed, so set this now
                if (delete_button == null) {
                    delete_button = app.window.delete_button;
                    delete_button.clicked.connect(() => {
                        var selected = this.get_selected_rows();
                        var msg = new Gtk.MessageDialog((Application.get_default() as valhalla).window,
                            Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                            "You are about to delete %s file(s). This action cannot be undone. Are you sure?",
                            selected.length.to_string());
                        var response = msg.run();
                        msg.destroy();
                        if (response != Gtk.ResponseType.YES)
                            return;
                        foreach (var file in selected) {
                            file.module.delete.begin(file.remote_path, (obj, res) => {
                                try {
                                    file.module.delete.end(res);
                                    file.remove_from_database();
                                    app.window.deselect_button.active = false;
                                } catch (Valhalla.Error e) {
                                    app.window.display_error(e.message);
                                }
                            });
                        }
                    });
                }
                var selected = this.get_selected_rows();
                var selection_indicator = app.window.selection_indicator;
                selection_indicator.label = @"$(selected.length) files selected";
                if (selected.length > 0)
                    delete_button.sensitive = true;
                else
                    delete_button.sensitive = false;
            });

            this.selection_mode = Gtk.SelectionMode.NONE;

            var placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            placeholder.add(new Gtk.Image.from_icon_name("view-grid-symbolic",
                Gtk.IconSize.DIALOG));
            placeholder.add(new Gtk.Label("You haven't uploaded any files yet"));
            placeholder.halign = Gtk.Align.CENTER;
            placeholder.valign = Gtk.Align.CENTER;
            placeholder.sensitive = false;
            placeholder.show_all();
            this.set_placeholder(placeholder);

            Gtk.drag_dest_set(this, Gtk.DestDefaults.ALL, {
                Gtk.TargetEntry () {target = "text/uri-list", flags = 0, info = 0}
                }, Gdk.DragAction.COPY);

            populate();
            db.committed.connect_after((_) => {
                populate();
            });
        }
    }

    class FileWindow : Gtk.Stack {
        public Database.Database db {construct; private get;}
        private bool select = false;

        public virtual signal void toggle_selection_mode(bool select) {
            this.select = select;
        }

        public virtual signal void back_button_clicked() {
            assert (this.visible_child is DisplayFile);
            (this.visible_child as DisplayFile).start_destroy();
        }

        public FileWindow() {
            var app = Application.get_default() as valhalla;
            Object(db: app.database);
        }

        construct {
            var files = new Files();
            toggle_selection_mode.connect((b) => {
                files.toggle_select_mode(b);
            });
            files.row_activated.connect((row) => {
                if (select)
                    return;
                var file = (row as ListFile).file;
                var pot_module = Modules.get_module(file.module_name);
                var displayfile = new DisplayFile(file);
                displayfile.start_destroy.connect(() => {
                    this.set_visible_child_full("files", Gtk.StackTransitionType.SLIDE_RIGHT);
                    Timeout.add(this.get_transition_duration(), () => {
                        displayfile.destroy();
                        return false;
                    });
                });
                this.add_named(displayfile, "filedisplay");
                this.set_visible_child_full("filedisplay", Gtk.StackTransitionType.SLIDE_LEFT);
            });
            var list_window = new Gtk.ScrolledWindow(null, null);
            list_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            list_window.add(files);
            this.add_named(list_window, "files");

            this.show_all();
        }
    }

    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/main.ui")]
    class MainWindow : Gtk.ApplicationWindow {
        [GtkChild]
        private FileWindow file_window;
        [GtkChild]
        private Transfers transfers;
        [GtkChild]
        private Gtk.Stack headerbar_stack;
        [GtkChild]
        private Gtk.HeaderBar main_headerbar;
        [GtkChild]
        private Gtk.HeaderBar selection_headerbar;
        [GtkChild]
        private Gtk.InfoBar error_bar;
        [GtkChild]
        private Gtk.Label error_text;
        [GtkChild]
        private Gtk.Overlay stack_overlay;
        [GtkChild]
        private Gtk.Stack main_window_stack;
        [GtkChild]
        public Gtk.Revealer back_reveal;
        [GtkChild]
        public Gtk.Revealer select_reveal;
        [GtkChild]
        public Gtk.ToggleButton select_button;
        [GtkChild]
        public Gtk.ToggleButton deselect_button;
        [GtkChild]
        private Gtk.Revealer transfers_clear_reveal;
        [GtkChild]
        private Gtk.Button transfers_clear_button;
        [GtkChild]
        public Gtk.Button delete_button;
        [GtkChild]
        public Gtk.Label selection_indicator;

        public bool one_shot = false; // this is true if we've just been launched
                                      // for the purpose of capturing a screenshot.
                                      // If the user cancels a capture when this
                                      // is true, we want to outright exit instead
                                      // of (re)displaying `this`

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

        private delegate void SignalCallback();

        public async void kickoff_upload(string path, bool switch_view = true) {
            // allow any pending Gtk events (like dialog destruction) to complete
            // before we continue
            Idle.add(kickoff_upload.callback);
            yield;
            var transfer = new TransferWidget.from_path(path);
            var module = Modules.get_active_module();
            if (module == null) {
                display_error("Please configure a module in the preferences panel");
                return;
            }
            transfer.completed.connect(() => {
                if (!(main_window_stack.visible_child is Transfers))
                    main_window_stack.child_set(transfers, "needs-attention", true);
            });
            transfer.failed.connect(() => {
                if (!(main_window_stack.visible_child is Transfers))
                    main_window_stack.child_set(transfers, "needs-attention", true);
            });
            if (switch_view)
                main_window_stack.visible_child = transfers;
            else if (!(main_window_stack.visible_child is Transfers))
                main_window_stack.child_set(transfers, "needs-attention", true);
            transfers.add(transfer);
            try {
                yield module.upload(transfer);
            } catch (Valhalla.Error e) {
                if (e is Valhalla.Error.CANCELLED)
                    transfer.cancellable.cancel();
                else {
                    transfer.failed();
                    display_error(e.message);
                }
            }
        }

        [GtkCallback]
        private async void upload_clicked(Gtk.Button _) {
            var dialog = new Gtk.FileChooserDialog("File Upload", this,
                Gtk.FileChooserAction.OPEN, "_Cancel", Gtk.ResponseType.CANCEL,
                "_Open", Gtk.ResponseType.ACCEPT);
            var response = dialog.run();
            dialog.close();
            if (response == Gtk.ResponseType.ACCEPT) {
                kickoff_upload.begin(dialog.get_filename(), true, (obj, res) => {
                    kickoff_upload.end(res);
                });
            }
        }

        [GtkCallback]
        public async void capture_screenshot() {
            var module = Modules.get_active_module();
            if (module == null) {
                display_error("Please configure a module in the preferences panel");
                return;
            }
            this.visible = false;
            var screenshot = yield Screenshot.take_interactive();
            if (screenshot != null) {
                var dialog = new Gtk.Dialog.with_buttons("New screenshot", this,
                    Gtk.DialogFlags.USE_HEADER_BAR, "_Cancel", Gtk.ResponseType.CANCEL,
                    "_Upload", Gtk.ResponseType.OK);
                var inner = dialog.get_content_area();
                inner.border_width = 0;
                inner.add(new Gtk.Image.from_pixbuf(
                    Screenshot.scale_for_preview(screenshot, this.get_screen())));
                inner.show_all();
                var response = dialog.run();
                dialog.close();
                if (response == Gtk.ResponseType.OK) {
                    FileIOStream streams;
                    var file = File.new_tmp("valhalla_XXXXXX.png", out streams);
                    screenshot.save_to_stream(streams.output_stream, "png");
                    kickoff_upload.begin(file.get_path(), true, (obj, res) => {
                        kickoff_upload.end(res);
                        file.delete();
                    });
                }
            } else if (this.one_shot)
                this.close();
            this.visible = true;
        }

        [GtkCallback]
        private void select_toggle_on(Gtk.ToggleButton button) {
            if (!button.active)
                return;
            file_window.toggle_selection_mode(true);
            headerbar_stack.visible_child = selection_headerbar;
            Timeout.add(headerbar_stack.get_transition_duration(), () => {
                button.active = !button.active;
                return false;
            });
        }

        [GtkCallback]
        private void select_toggle_off(Gtk.ToggleButton button) {
            if (button.active)
                return;
            file_window.toggle_selection_mode(false);
            headerbar_stack.visible_child = main_headerbar;
            Timeout.add(headerbar_stack.get_transition_duration(), () => {
                button.active = !button.active;
                return false;
            });
        }

        construct {
            Notify.init("Valhalla");

            transfers_clear_button.clicked.connect((_) => {
                transfers.clear();
            });

            main_window_stack.notify["visible-child"].connect((_) => {
                main_window_stack.child_set(main_window_stack.visible_child,
                    "needs-attention", false);
            });

            main_window_stack.bind_property("visible-child", back_reveal, "reveal-child",
                BindingFlags.DEFAULT, (binding, src, ref target) => {
                    if (src.get_object() is FileWindow && file_window.visible_child is DisplayFile)
                        target = true;
                    else
                        target = false;
                    return true;
                });
            main_window_stack.bind_property("visible-child", select_reveal, "reveal-child",
                BindingFlags.DEFAULT, (binding, src, ref target) => {
                    if (src.get_object() is FileWindow && file_window.visible_child is Files)
                        target = true;
                    else
                        target = false;
                    return true;
                });
            main_window_stack.bind_property("visible-child", transfers_clear_reveal, "reveal-child",
                BindingFlags.DEFAULT, (binding, src, ref target) => {
                    if (src.get_object() is Transfers)
                        target = true;
                    else
                        target = false;
                    return true;
                });

            file_window.bind_property("visible-child", back_reveal, "reveal-child",
                BindingFlags.DEFAULT, (binding, src, ref target) => {
                    if (src.get_object() is DisplayFile)
                        target = true;
                    else
                        target = false;
                    return true;
                });
            file_window.bind_property("visible-child", select_reveal, "reveal-child",
                BindingFlags.DEFAULT, (binding, src, ref target) => {
                    if (src.get_object() is Files)
                        target = true;
                    else
                        target = false;
                    return true;
                });

            this.show_all();
        }
    }
}

namespace Valhalla.Widgets {
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

        [GtkChild]
        private Gtk.Button prev_button;
        [GtkChild]
        private Gtk.Button next_button;

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

        private void change_display(Database.RemoteFile file,
                                    Gtk.StackTransitionType direction) {
            var new_display = new DisplayFile(file);
            var parent = (FileWindow) this.parent;
            var new_name = parent.visible_child_name + "_";
            parent.add_named(new_display, new_name);
            parent.set_visible_child_full(new_name, direction);
            Timeout.add(parent.get_transition_duration(), () => {
                this.destroy();
                return false;
            });
        }

        public DisplayFile(Database.RemoteFile file) {
            Object(file: file);
        }

        construct {
            file.remove_from_database.connect(() => {
                this.start_destroy();
            });

            title.label = @"<b>$(file.display_name)</b>";

            get_app().thumbnailer.get_thumbnail.begin(file, (obj, res) => {
                var thumbnail_pixbuf = get_app().thumbnailer.get_thumbnail.end(
                    res);
                Gtk.Image thumbnail;
                if (thumbnail_pixbuf == null)
                    thumbnail = new Gtk.Image.from_gicon(
                        ContentType.get_icon(file.file_type),
                        Gtk.IconSize.DIALOG);
                else
                    thumbnail = new Gtk.Image.from_pixbuf((!) thumbnail_pixbuf);
                thumbnail.show();
                thumbnail_window.add_named(thumbnail, "thumb");
                thumbnail_window.visible_child_name = "thumb";
            });

            link.uri = file.remote_path;
            link.label = file.remote_path;
            if (file.timestamp != null)
                build_row("Uploaded at:", ((!) file.timestamp).to_string());
            build_row("Checksum:", file.crc32);
            build_row("File type:", file.file_type);
            if (file.file_size != null)
                build_row("File size:", format_size(((!) file.file_size),
                    FormatSizeFlags.IEC_UNITS));

            forget_button.clicked.connect((_) => {
                var msg = new Gtk.MessageDialog(
                    get_main_window(), Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                    "This will remove the file from the files pane, but %s %s",
                    "the file will remain available via the link. This action",
                    "cannot be undone. Are you sure?");
                if (msg.run() == Gtk.ResponseType.YES)
                    file.remove_from_database();
                msg.destroy();
            });

            if (file.module == null || !((!) file.module).implements_delete)
                delete_button.sensitive = false;
            delete_button.clicked.connect((_) => {
                assert (file.module != null);
                var msg = new Gtk.MessageDialog(
                    get_main_window(), Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
                    "Are you sure you want to delete this file? This action %s",
                    "cannot be undone");
                if (msg.run() == Gtk.ResponseType.YES) {
                    forget_button.sensitive = false;
                    delete_button.sensitive = false;
                    delete_spinner_reveal.reveal_child = true;
                    ((!) file.module).delete.begin(file.remote_path,
                            (obj, res) => {
                        try {
                            ((!) file.module).delete.end(res);
                            file.remove_from_database();
                            get_main_window().stack_notify("File deleted");
                        } catch (Module.Error e) {
                            get_main_window().display_error(e.message);
                        }
                        forget_button.sensitive = true;
                        delete_button.sensitive = true;
                        delete_spinner_reveal.reveal_child = false;
                    });
                }
                msg.destroy();
            });

            if (file.prev == null)
                prev_button.sensitive = false;
            else
                prev_button.clicked.connect(() => {
                    change_display((!) file.prev,
                        Gtk.StackTransitionType.SLIDE_RIGHT);
                });
            if (file.next == null)
                next_button.sensitive = false;
            else
                next_button.clicked.connect(() => {
                    change_display((!) file.next,
                        Gtk.StackTransitionType.SLIDE_LEFT);
                });

            this.start_destroy.connect(() => {
                var parent = (FileWindow) this.parent;
                parent.set_visible_child_full("files",
                    Gtk.StackTransitionType.SLIDE_RIGHT);
                Timeout.add(parent.get_transition_duration(), () => {
                    this.destroy();
                    return false;
                });
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
                        var context_button =
                            (Gtk.ToggleButton) get_main_window()
                            .context_revealer.get_child();
                        context_button.active = true;
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

            var label = new Gtk.Label(file.display_name);
            label.hexpand = true;
            label.halign = Gtk.Align.START;
            inner.add(label);

            if (file.module == null || !((!) file.module).implements_delete) {
                this.selectable = false;
                var warning_reveal = new Gtk.Revealer();
                warning_reveal.transition_type =
                    Gtk.RevealerTransitionType.SLIDE_LEFT;
                warning_reveal.reveal_child = false;
                warning_reveal.add(new Gtk.Image.from_icon_name(
                    "dialog-warning", Gtk.IconSize.BUTTON));
                this.bind_property("select-mode", warning_reveal,
                    "reveal-child");
                inner.add(warning_reveal);
            }

            if (file.timestamp != null) {
                var date = new Gtk.Label(((!) file.timestamp).to_string());
                date.halign = Gtk.Align.END;
                inner.add(date);
            }

            var evbox = new Gtk.EventBox();
            evbox.add(inner);
            this.add(evbox);
            this.set_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            this.show_all();
        }
    }


    class Files : Gtk.ListBox {
        private Database.Database db;
        private Gtk.Button? delete_button = null;

        private void populate() {
            this.foreach((row) => {
                row.destroy();
            });
            foreach (var file in db.files) {
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
                ((ListFile) row).select_mode = select;
            if (select)
                this.selection_mode = Gtk.SelectionMode.MULTIPLE;
            else
                this.selection_mode = Gtk.SelectionMode.NONE;
        }

        private new Database.RemoteFile[] get_selected_rows() {
            var rows = base.get_selected_rows();
            Database.RemoteFile[] files = {};
            foreach (var row in rows) {
                var file = ((ListFile) row).file;
                assert (file.module != null &&
                    ((!) file.module).implements_delete);
                files += file;
            }
            return files;
        }

        public override void drag_data_received(Gdk.DragContext context, int _,
                                                int __, Gtk.SelectionData data,
                                                uint ___, uint time) {
            Gtk.drag_finish(context, true, false, time);
            foreach (var path in data.get_uris()) {
                assert (path.has_prefix("file://"));
                path = path[7:path.length];
                get_main_window().kickoff_upload.begin(path);
            }
        }

        private async void delete_selected() {
            get_main_window().delete_progress_reveal.reveal_child = true;
            try {
                foreach (var file in get_selected_rows()) {
                    assert (file.module != null);
                    yield ((!) file.module).delete(file.remote_path);
                    file.remove_from_database();
                }
            } catch (Module.Error e) {
                get_main_window().display_error(e.message);
            }
            get_main_window().delete_progress_reveal.reveal_child = false;
            get_main_window().deselect_button.active = false;
        }

        construct {
            db = get_app().database;

            this.selected_rows_changed.connect(() => {
                // app.window is null when we get constructed, so set this now
                if (delete_button == null) {
                    delete_button = get_main_window().delete_button;
                    ((!) delete_button).clicked.connect(() => {
                        var selected = this.get_selected_rows();
                        var msg = new Gtk.MessageDialog(get_main_window(),
                            Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION,
                            Gtk.ButtonsType.YES_NO,
                            "You are about to delete %s file(s). This %s",
                            selected.length.to_string(),
                            "action cannot be undone. Are you sure?");
                        var response = msg.run();
                        msg.destroy();
                        if (response == Gtk.ResponseType.YES)
                            delete_selected.begin();
                    });
                }
                var selected = this.get_selected_rows();
                var selection_indicator = get_main_window().selection_indicator;
                selection_indicator.label =
                    @"$(selected.length) files selected";
                if (selected.length > 0)
                    ((!) delete_button).sensitive = true;
                else
                    ((!) delete_button).sensitive = false;
            });

            this.selection_mode = Gtk.SelectionMode.NONE;

            var placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            placeholder.add(new Gtk.Image.from_icon_name("view-grid-symbolic",
                Gtk.IconSize.DIALOG));
            placeholder.add(
                new Gtk.Label("You haven't uploaded any files yet"));
            placeholder.halign = Gtk.Align.CENTER;
            placeholder.valign = Gtk.Align.CENTER;
            placeholder.sensitive = false;
            placeholder.show_all();
            this.set_placeholder(placeholder);

            var drop_targets = new Gtk.TargetList(null);
            drop_targets.add_uri_targets(0);
            Gtk.drag_dest_set(this, Gtk.DestDefaults.ALL, {},
                Gdk.DragAction.COPY);
            Gtk.drag_dest_set_target_list(this, drop_targets);

            populate();
            db.committed.connect_after((_) => {
                populate();
            });
        }
    }


    class FileWindow : Gtk.Stack {
        private Database.Database db;
        private bool select = false;

        public virtual signal void toggle_selection_mode(bool select) {
            this.select = select;
        }

        public virtual signal void back_button_clicked() {
            var child = this.visible_child as DisplayFile;
            assert (child != null); // assert it's a DisplayFile
            ((!) child).start_destroy();
        }

        public void display_file(Database.RemoteFile file) {
            var displayfile = new DisplayFile(file);
            this.add_named(displayfile, "filedisplay");
            this.set_visible_child_full("filedisplay",
                Gtk.StackTransitionType.SLIDE_LEFT);
            get_main_window().main_window_stack.visible_child = this;
        }

        construct {
            db = get_app().database;
            var files = new Files();
            toggle_selection_mode.connect((b) => {
                files.toggle_select_mode(b);
            });
            files.row_activated.connect((row) => {
                if (select)
                    return;
                var file = ((ListFile) row).file;
                display_file(file);
            });
            var list_window = new Gtk.ScrolledWindow(null, null);
            list_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            list_window.add(files);
            this.add_named(list_window, "files");

            this.show_all();
        }
    }
}

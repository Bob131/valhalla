errordomain Valhalla.Preferences.Error {
    KEY_NOT_SET;
}

namespace Valhalla.Data {
    public class RealTransferFile : RemoteFile, TransferFile {
        public string file_name {set; get;}
        public uint8[] file_contents {set; get;}

        public RealTransferFile(owned string path) throws GLib.Error {
            Object();

            if (path.has_prefix("file://"))
                path = path[7:path.length];

            var file = File.new_for_path(path);
            uint8[] tmp;
            file.load_contents(null, out tmp, null);

            file_contents = tmp;
            local_path = path;
            file_size = file_contents.length;
            timestamp = Time.gm(time_t());
            file_name = Path.get_basename(path);
            file_type = ContentType.guess(path, tmp, null);

            crc32 = "%08x".printf(
                (uint) ZLib.Utility.adler32(1, file_contents));

            var _module_name = Widgets.get_app()
                .prefs.app_preferences[typeof(ModulePreference)].value;
            if (_module_name == null)
                throw new Preferences.Error.KEY_NOT_SET("Please configure a %s",
                    "module in the preferences panel");
        }
    }
}

namespace Valhalla.Widgets {
    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/transfers.ui")]
    public class TransferWidget : Data.Transfer, Gtk.Box {
        public Data.TransferFile file {protected set; get;}
        private Data.RealTransferFile real_file {get {
            return (Data.RealTransferFile) file;
        }}

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

        private Database.RemoteFile get_offender() {
            var files = db.query(true, crc32: real_file.crc32);
            if (files.length == 0)
                files = db.query(true, remote_path: real_file.remote_path);
            assert (files.length > 0);
            return files[0];
        }

        private bool overwrite_file(string message) {
            var dialog = new Gtk.MessageDialog(get_main_window(),
                Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.NONE, "%s", message); // avoid failing when
                                                      // compiled with
                                                      // -Wformat-security
            dialog.add_button("Cancel", Gtk.ResponseType.CANCEL);
            dialog.add_button("Display Existing File", Gtk.ResponseType.NO);
            dialog.add_button("Overwrite", Gtk.ResponseType.YES);
            var ret = dialog.run();
            dialog.destroy();
            if (ret == Gtk.ResponseType.YES) {
                get_offender().remove_from_database();
                return true;
            } else if (ret == Gtk.ResponseType.NO) {
                get_main_window().file_window.display_file(get_offender());
            }
            return false;
        }

        public void set_remote_path(string path) throws Data.Error {
            if (Uri.parse_scheme(path) == null)
                throw new Data.Error.INVALID_REMOTE_PATH("URL %s is invalid",
                    path);
            real_file._remote_path = path;
            if (!db.unique_url(path))
                if (!overwrite_file(@"A file with the URL $path already exists")) {
                    this.cancellable.cancel();
                    throw new Data.Error.TRANSFER_CANCELLED("");
                }
            // generate thumbnail now
            get_app().thumbnailer.get_thumbnail.begin(real_file);
        }

        public TransferWidget.from_path(owned string path) throws GLib.Error {
            Object();

            db = get_app().database;
            this.completed.connect(() => {
                db.commit(real_file);
            });

            cancellable = new Cancellable();

            file_name_label.label = file.file_name;
            this.bind_property("status", progress_bar, "text");
            status = "Initializing...";
            progress_bar.pulse();

            copy_button.clicked.connect(() => {
                var display = Gdk.Display.get_default();
                if (display == null) {
                    get_main_window().stack_notify(
                        "Failed to copy URL to clipboard");
                    return;
                }
                var clipboard = Gtk.Clipboard.get_default((!) display);
                clipboard.set_text(real_file.remote_path,
                    real_file.remote_path.length);
                get_main_window().stack_notify("URL copied to clipboard");
            });
            cancel_button.clicked.connect(() => {
                if (status == "Upload failed" || status == "Cancelled" ||
                        status == "Done!")
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
                double fraction = (double) bytes / file.file_contents.length;
                status = @"$(Math.floor(fraction*100))%";
                progress_bar.fraction = fraction;
            });
            this.failed.connect(() => {
                pulse = false;
                status = "Upload failed";
                progress_bar.fraction = 0;
                var notification = new Notification("Upload failed");
                notification.set_icon(new ThemedIcon("document-send-symbolic"));
                notification.set_body(Path.get_basename(
                    (!) real_file.local_path));
                get_app().send_notification("upload-failed", notification);
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
                var notification = new Notification("Upload complete");
                notification.set_icon(new ThemedIcon("document-send-symbolic"));
                notification.set_body(real_file.remote_path);
                get_app().send_notification("upload-complete", notification);
            });

            if (!db.unique_hash((!) file.crc32))
                if (!overwrite_file(@"A file with hash $((!) file.crc32) appears to have already been uploaded"))
                    cancellable.cancel();

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
                var transfer =
                    (TransferWidget) ((Gtk.ListBoxRow) row).get_child();
                if (transfer.status == "Done!" ||
                        transfer.status == "Upload failed" ||
                        transfer.status == "Cancelled")
                    transfer.destroy();
            });
        }

        construct {
            listbox = new Gtk.ListBox();
            listbox.row_activated.connect((row) => {
                var transfer = (TransferWidget) row.get_child();
                if (transfer.status == "Done!")
                    try {
                        AppInfo.launch_default_for_uri(
                            transfer.file.remote_path, null);
                    } catch {}
            });
            listbox.selection_mode = Gtk.SelectionMode.NONE;
            listbox.activate_on_single_click = true;

            var placeholder = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            placeholder.add(new Gtk.Image.from_icon_name(
                "network-idle-symbolic", Gtk.IconSize.DIALOG));
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
}

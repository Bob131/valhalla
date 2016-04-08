namespace Valhalla.Widgets {
    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/transfers.ui")]
    public class TransferWidget : Gtk.Box, Transfer {
        private string _remote_path;

        public Time timestamp {protected set; get;}
        public string crc32 {protected set; get;}
        public string file_name {protected set; get;}
        public uint8[] file_contents {protected set; get;}
        public string file_type {protected set; get;}
        public uint64 file_size {get {
            return file_contents.length;
        }}

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

        private Gtk.ResponseType file_exists(string message) {
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
            if (ret == Gtk.ResponseType.NO) {
                var files = db.query(true, crc32: crc32);
                if (files.length == 0)
                    files = db.query(true, remote_path: _remote_path);
                get_main_window().file_window.display_file(files[0]);
            }
            return (Gtk.ResponseType) ret;
        }

        public void set_remote_path(string path) throws Valhalla.Error {
            if (Uri.parse_scheme(path) == null)
                throw new Valhalla.Error.INVALID_REMOTE_PATH(
                    @"URL $(path) is invalid");
            _remote_path = path;
            if (!db.unique_url(path))
                if (file_exists(@"A file with the URL $path already exists")
                        != Gtk.ResponseType.YES)
                    throw new Valhalla.Error.CANCELLED("");

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

        public TransferWidget.from_path(owned string path) {
            Object();

            db = (Application.get_default() as valhalla).database;
            this.completed.connect(() => {
                db.commit_transfer(this);
            });

            if (path.has_prefix("file://"))
                path = path[7:path.length];

            this.init_for_path(path);
            crc32 = "%08x".printf(
                (uint) ZLib.Utility.adler32(1, file_contents));
            local_filename = path;
            module_name = Config.settings["module"];

            file_name_label.label = file_name;
            this.bind_property("status", progress_bar, "text");
            status = "Initializing...";
            progress_bar.pulse();

            copy_button.clicked.connect(() => {
                var clipboard = Gtk.Clipboard.get_default(
                    Gdk.Display.get_default());
                clipboard.set_text(remote_path, remote_path.length);
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
                double fraction = (double) bytes / file_contents.length;
                status = @"$(Math.floor(fraction*100))%";
                progress_bar.fraction = fraction;
            });
            this.failed.connect(() => {
                pulse = false;
                status = "Upload failed";
                progress_bar.fraction = 0;
                new Notify.Notification("Upload failed",
                    Path.get_basename(local_filename),
                    "document-send-symbolic").show();
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

            if (!db.unique_hash(crc32))
                if (file_exists(@"A file with hash $crc32 appears to have already been uploaded") != Gtk.ResponseType.YES)
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
                var transfer = (row as Gtk.ListBoxRow).get_child()
                    as TransferWidget;
                if (transfer.status == "Done!" ||
                        transfer.status == "Upload failed" ||
                        transfer.status == "Cancelled")
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

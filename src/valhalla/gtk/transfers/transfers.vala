class RealTransferFile : RemoteFile, Valhalla.LocalFile {
    public GLib.File file {set; get;}

    public RealTransferFile(GLib.File file) throws Error
        requires (file.get_path() != null)
    {
        Object(file: file,
            display_name: Path.get_basename((!) file.get_path()));

        uint8[] tmp;
        file.load_contents(null, out tmp, null);

        file_size = tmp.length;
        timestamp = Time.gm(time_t());
        file_type = ContentType.guess((!) file.get_path(), tmp, null);

        crc32 = "%08x".printf((uint) ZLib.Utility.adler32(1, tmp));

        var module = get_app().loader.get_active();
        if (module == null)
            throw new KeyFileError.KEY_NOT_FOUND("Please configure a %s",
                "module in the preferences panel");
        module_name = ((!) module).get_type().name();
    }
}

public enum TransferStatus {
    INIT,
    UPLOADING,
    DONE,
    CANCELLED,
    FAILED
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/transfers/transfer-widget.ui")]
public class TransferWidget : Gtk.ListBoxRow, Valhalla.Transfer {
    public Valhalla.LocalFile file {protected set; get;}

    RealTransferFile real_file {get {
        return (RealTransferFile) file;
    }}

    public Cancellable cancellable {protected set; get;}
    public TransferStatus status {private set; get;}

    public uint64 bytes_uploaded {set; get;}

    Database db;

    [GtkChild]
    Gtk.Label file_name_label;
    [GtkChild]
    Gtk.Button copy_button;
    [GtkChild]
    Gtk.Button cancel_button;
    [GtkChild]
    Gtk.ProgressBar progress_bar;

    public signal void failed();

    RemoteFile get_offender() {
        var files = db.query(true, crc32: real_file.crc32);
        if (files.length == 0)
            files = db.query(true, "remote_path", real_file.remote_path);
        assert (files.length > 0);
        return files[0];
    }

    bool overwrite_file(string message) {
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
        } else if (ret == Gtk.ResponseType.NO)
            get_main_window().file_window.file_activated(get_offender());

        return false;
    }

    void update_progress_bar() {
        switch (status) {
            case TransferStatus.INIT:
                progress_bar.text = "Initializing...";
                break;
            case TransferStatus.UPLOADING:
                if (cancellable.is_cancelled())
                    return;
                double fraction = (double) bytes_uploaded / real_file.file_size;
                progress_bar.fraction = fraction;
                progress_bar.text = @"$(Math.floor(fraction*100))%";
                break;
            case TransferStatus.DONE:
                progress_bar.fraction = 1;
                progress_bar.text = "Done!";
                break;
            default:
                progress_bar.fraction = 0;
                switch (status) {
                    case TransferStatus.CANCELLED:
                        progress_bar.text = "Cancelled";
                        break;
                    case TransferStatus.FAILED:
                        progress_bar.text = "Failed";
                        break;
                    default:
                        assert_not_reached();
                }
                break;
        }
    }

    [GtkCallback]
    void copy() {
        var display = Gdk.Display.get_default();

        if (display == null) {
            get_main_window().stack_notify("Failed to copy URL to clipboard");
            return;
        }

        var clipboard = Gtk.Clipboard.get_default((!) display);
        clipboard.set_text(real_file.remote_path, real_file.remote_path.length);

        get_main_window().stack_notify("URL copied to clipboard");
    }

    [GtkCallback]
    void cancel() {
        if (status >= TransferStatus.DONE)
            this.destroy();
        else
            cancellable.cancel();
    }

    public TransferWidget(GLib.File file) throws Error
        requires (file.get_path() != null)
    {
        Object(file: new RealTransferFile(file),
            cancellable: new Cancellable());

        db = get_app().database;
        this.completed.connect(() => db.commit(real_file));

        this.notify["status"].connect(() => update_progress_bar());

        this.notify["status"].connect(
            () => copy_button.sensitive = status == TransferStatus.DONE);
        this.notify["status"].connect(
            () => cancel_button.sensitive = status != TransferStatus.INIT);

        this.notify["bytes-uploaded"].connect(() => {
            if (status == TransferStatus.INIT && bytes_uploaded > 0)
                status = TransferStatus.UPLOADING;
            else
                update_progress_bar();
        });

        file_name_label.label = Path.get_basename((!) file.get_path());
        status = TransferStatus.INIT;
        progress_bar.pulse();

        Timeout.add(500, () => {
            var ret = status == TransferStatus.INIT;
            if (ret)
                progress_bar.pulse();
            return ret;
        });

        this.failed.connect(() => {
            status = TransferStatus.FAILED;
            var notification = new Notification("Upload failed");
            notification.set_icon(new ThemedIcon("document-send-symbolic"));
            notification.set_body(real_file.display_name);
            get_app().send_notification("upload-failed", notification);
        });

        cancellable.connect(() => status = TransferStatus.CANCELLED);

        this.completed.connect(() => {
            status = TransferStatus.DONE;
            var notification = new Notification("Upload complete");
            notification.set_icon(new ThemedIcon("document-send-symbolic"));
            notification.set_body(real_file.remote_path);
            get_app().send_notification("upload-complete", notification);
        });

        if (!db.unique_hash((!) this.file.crc32))
            if (!overwrite_file(@"A file with hash $((!) this.file.crc32) appears to have already been uploaded"))
                cancellable.cancel();

        this.show_all();
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/transfers/list-placeholder.ui")]
class TransferListPlaceholder : BasePlaceholder {}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/transfers/list.ui")]
class TransferList : Gtk.ScrolledWindow {
    [GtkChild]
    Gtk.ListBox listbox;

    public void clear() {
        listbox.foreach((row) => {
            var transfer = (TransferWidget) row;
            if (transfer.status >= TransferStatus.DONE)
                transfer.destroy();
        });
    }

    public new void add(TransferWidget child) {
        listbox.add(child);
    }

    construct {
        listbox.row_activated.connect((row) => {
            var transfer = (TransferWidget) row;
            if (transfer.status == TransferStatus.DONE)
                try {
                    AppInfo.launch_default_for_uri(
                        transfer.file.remote_path, null);
                } catch {}
        });

        listbox.set_placeholder(new TransferListPlaceholder());

        this.show_all();
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/file-widgets/details.ui")]
class FileDetails : Gtk.Box {
    public RemoteFile file {construct; get;}

    [GtkChild]
    Gtk.Grid info_grid;
    int grid_row_counter = 2;

    [GtkChild]
    Gtk.Label title;
    [GtkChild]
    Gtk.Stack thumbnail_window;
    [GtkChild]
    Gtk.LinkButton link;
    [GtkChild]
    Gtk.Button forget_button;
    [GtkChild]
    Gtk.Button delete_button;
    [GtkChild]
    Gtk.Revealer delete_spinner_reveal;

    [GtkChild]
    Gtk.Button prev_button;
    [GtkChild]
    Gtk.Button next_button;

    void build_row(string name, string? val = null) {
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

    Gtk.ResponseType question_dialog(string message, ...) {
        string?[]? strings = {message};
        var list = va_list();

        for (string? arg = list.arg(); arg != null; arg = list.arg())
            strings += arg;

        var msg = new Gtk.MessageDialog(get_main_window(),
            Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION,
            Gtk.ButtonsType.YES_NO, "%s", string.joinv(" ", strings));

        var ret = msg.run();
        msg.destroy();
        return (Gtk.ResponseType) ret;
    }

    [GtkCallback]
    void forget() {
        var response = question_dialog("This will remove the file from the",
            "files pane, but the file will remain available via the link.",
            "This action cannot be undone. Are you sure?");
        if (response == Gtk.ResponseType.YES)
            file.remove_from_database();
    }

    [GtkCallback]
    async void @delete()
        requires (file.module != null)
        requires ((!) file.module is Valhalla.Deleter)
    {
        var response = question_dialog("Are you sure you want to delete this",
            "file? This action cannot be undone");

        if (response != Gtk.ResponseType.YES)
            return;

        forget_button.sensitive = false;
        delete_button.sensitive = false;
        delete_spinner_reveal.reveal_child = true;

        try {
            yield ((Valhalla.Deleter) file.module).delete(file);
            file.remove_from_database();
            get_main_window().stack_notify("File deleted");
        } catch (Error e) {
            get_main_window().display_error(e.message);
        }

        forget_button.sensitive = true;
        delete_button.sensitive = true;
        delete_spinner_reveal.reveal_child = false;
    }

    [GtkCallback]
    void switch_file(Gtk.Button button)
        requires (button == prev_button || button == next_button)
    {
        ((DetailsStack) this.parent).display_file(
            (!) (button == prev_button ? file.prev : file.next));
    }

    public FileDetails(RemoteFile file) {
        Object(file: file);

        title.label = file.display_name;

        get_app().thumbnailer.get_thumbnail.begin(file, (obj, res) => {
            var thumbnail_pixbuf = get_app().thumbnailer.get_thumbnail.end(res);

            Gtk.Image thumbnail;
            if (thumbnail_pixbuf == null)
                thumbnail = new Gtk.Image.from_gicon(
                    ContentType.get_icon(file.file_type),
                    Gtk.IconSize.DIALOG);
            else
                thumbnail = new Gtk.Image.from_pixbuf((!) thumbnail_pixbuf);

            thumbnail.show();
            thumbnail_window.add(thumbnail);
            thumbnail_window.visible_child = thumbnail;
        });

        link.uri = file.remote_path;
        link.label = file.remote_path;
        build_row("Uploaded at:", ((!) file.timestamp).to_string());
        build_row("Checksum:", file.crc32);
        build_row("File type:", file.file_type);
        if (file.file_size != null)
            build_row("File size:", format_size(((!) file.file_size),
                FormatSizeFlags.IEC_UNITS));

        delete_button.sensitive = file.module != null
            && (!) file.module is Valhalla.Deleter;

        prev_button.sensitive = file.prev != null;
        next_button.sensitive = file.next != null;

        this.show_all();
    }
}

class DetailsStack : Gtk.Stack {
    new FileDetails? get_visible_child() {
        return (FileDetails?) base.get_visible_child();
    }

    public void display_file(RemoteFile file) {
        var details_view =
            (FileDetails) this.get_child_by_name(file.remote_path);

        if ((FileDetails?) details_view == null) {
            details_view = new FileDetails(file);
            this.add_named(details_view, file.remote_path);
        }

        if (get_visible_child() == null)
            this.set_visible_child(details_view);
        else
            this.set_visible_child_full(file.remote_path,
                ((!) get_visible_child()).file.index > file.index ?
                    Gtk.StackTransitionType.SLIDE_LEFT :
                    Gtk.StackTransitionType.SLIDE_RIGHT);
    }
}

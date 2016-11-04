[GtkTemplate (ui = "/so/bob131/valhalla/gtk/file-widgets/list-row.ui")]
class FileListRow : Gtk.ListBoxRow {
    public RemoteFile file {construct; get;}

    [GtkChild]
    Gtk.Image icon;
    [GtkChild]
    Gtk.Label label;
    [GtkChild]
    Gtk.Label date;

    public override bool button_press_event(Gdk.EventButton ev) {
        if (ev.type == Gdk.EventType.BUTTON_PRESS && ev.button == 1) {
            this.activate();
            return true;
        }
        return false;
    }

    public FileListRow(RemoteFile file) {
        Object(file: file);

        icon.gicon = ContentType.get_icon(file.file_type);
        label.label = file.display_name;
        date.label = ((!) file.timestamp).to_string();

        this.show_all();
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/file-widgets/list-placeholder.ui")]
class FileListPlaceholder : BasePlaceholder {}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/file-widgets/list.ui")]
class FileList : Gtk.ScrolledWindow {
    Database db;

    [GtkChild]
    Gtk.ListBox list;

    void populate() {
        list.foreach((row) => row.destroy());
        foreach (var file in db.files)
            list.add(new FileListRow(file));
    }

    public override void drag_data_received(
        Gdk.DragContext context,
        int _,
        int __,
        Gtk.SelectionData data,
        uint ___,
        uint time)
    {
        Gtk.drag_finish(context, true, false, time);
        foreach (var uri in data.get_uris())
            get_main_window().kickoff_upload.begin(File.new_for_uri(uri));
    }

    construct {
        db = get_app().database;

        list.set_placeholder(new FileListPlaceholder());

        list.row_activated.connect(
            (row) => ((ListDetailStack) this.parent).file_activated(
                ((FileListRow) row).file));

        var drop_targets = new Gtk.TargetList(null);
        drop_targets.add_uri_targets(0);
        Gtk.drag_dest_set(this, Gtk.DestDefaults.ALL, {}, Gdk.DragAction.COPY);
        Gtk.drag_dest_set_target_list(this, drop_targets);

        populate();
        db.committed.connect_after(() => populate());
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/base-placeholder.ui")]
class BasePlaceholder : Gtk.Box {
    public string icon {set; get;}
    public string text {set; get;}

    [GtkChild]
    Gtk.Image image;
    [GtkChild]
    Gtk.Label label;

    construct {
        this.bind_property("icon", image, "icon-name",
            BindingFlags.SYNC_CREATE);
        this.bind_property("text", label, "label",
            BindingFlags.SYNC_CREATE);

        image.icon_size = Gtk.IconSize.DIALOG;

        this.show_all();
    }
}

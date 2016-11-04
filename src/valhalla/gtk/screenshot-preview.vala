[GtkTemplate (ui = "/so/bob131/valhalla/gtk/screenshot-preview.ui")]
class ScreenshotPreview : Gtk.Dialog {
    public Gdk.Pixbuf screenshot {construct; get;}

    [GtkChild]
    Gtk.Image image;

    [GtkCallback]
    void save_as() {
        var fchooser = new Gtk.FileChooserDialog(null, this,
            Gtk.FileChooserAction.SAVE,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Save", Gtk.ResponseType.ACCEPT);

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
                this.destroy();
            } catch (Error e) {
                new Gtk.MessageDialog(fchooser,
                    Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.CLOSE,
                    "Failed to save screenshot: %s",
                    e.message).run();
            }
        }
    }

    public ScreenshotPreview(Gdk.Pixbuf screenshot) {
        Object(screenshot: screenshot, transient_for: get_main_window(),
            use_header_bar: (int) true);

        image.pixbuf = Screenshot.scale_for_preview(screenshot,
            this.get_screen());

        this.show_all();
    }
}

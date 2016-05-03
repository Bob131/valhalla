[CCode (cheader_filename = "libgnome-desktop/gnome-desktop-thumbnail.h")]
namespace GnomeDesktop {
    public enum ThumbnailSize {
        NORMAL, LARGE;
    }

    public class ThumbnailFactory : GLib.Object {
        public string? lookup(string uri, time_t mtime);
        public bool can_thumbnail(string uri, string mime_type, time_t mtime);
        public Gdk.Pixbuf? generate_thumbnail(string uri, string mime_type);
        public void save_thumbnail(Gdk.Pixbuf thumbnail, string uri,
                                   time_t mtime);
        public void create_failed_thumbnail(string uri, time_t mtime);
        public ThumbnailFactory(ThumbnailSize size);
    }
}

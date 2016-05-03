class Valhalla.Thumbnailer : Object {
    private GnomeDesktop.ThumbnailFactory thumb_factory;

    // in here we pass `0` for mtime since we mightn't know the real upload
    // timestamp, but we don't want that to impact on our ability to set/get
    // thumbnails

    public void delete_thumbnail(Data.RemoteFile file) {
        var path = thumb_factory.lookup(file.remote_path, 0);
        if (path != null)
            FileUtils.unlink((!) path);
    }

    private async Gdk.Pixbuf? create_thumbnail(Data.RemoteFile file,
                                               string? path = null) {
        try {
            path = Filename.to_uri((!) (path ?? file.local_path));
        } catch {
            return null;
        }
        var ret = thumb_factory.generate_thumbnail((!) path, file.file_type);
        if (ret != null)
            thumb_factory.save_thumbnail((!) ret, file.remote_path, 0);
        else
            thumb_factory.create_failed_thumbnail(file.remote_path, 0);
        return ret;
    }

    public async Gdk.Pixbuf? get_thumbnail(Data.RemoteFile file) {
        var thumbnail_path = thumb_factory.lookup(file.remote_path, 0);
        if (thumbnail_path != null)
            try {
                return new Gdk.Pixbuf.from_file((!) thumbnail_path);
            } catch {
                return null;
            }

        if (!thumb_factory.can_thumbnail(file.remote_path, file.file_type, 0))
            return null;

        if (file.local_path != null &&
                FileUtils.test((!) file.local_path, FileTest.EXISTS))
            return yield create_thumbnail(file);
        else {
            FileIOStream fstream;
            string tmp_path;
            try {
                tmp_path = (!) File.new_tmp(null, out fstream).get_path();
            } catch (GLib.Error e) {
                warning("Creating thumbnail failed: %s", e.message);
                return null;
            }
            var session = new Soup.Session();
            var message = new Soup.Message("GET", file.remote_path);
            try {
                var istream = yield session.send_async(message);
                yield fstream.output_stream.splice_async(istream,
                    OutputStreamSpliceFlags.CLOSE_SOURCE|
                    OutputStreamSpliceFlags.CLOSE_TARGET);
            } catch (GLib.Error e) {
                warning("Creating thumbnail failed: %s", e.message);
                return null;
            }
            var pixbuf = yield create_thumbnail(file, tmp_path);
            FileUtils.unlink(tmp_path);
            return pixbuf;
        }
    }

    construct {
        thumb_factory = new GnomeDesktop.ThumbnailFactory(
            GnomeDesktop.ThumbnailSize.LARGE);
    }
}

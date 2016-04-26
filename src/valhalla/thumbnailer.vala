class Valhalla.Thumbnailer : Object {
    private const string keyfile_group = "Thumbnailer Entry";
    private const string thumbnailer_path = "/usr/share/thumbnailers";
    private Gee.HashMap<string, string> mime_lookup =
        new Gee.HashMap<string, string>();

    private string build_path(Data.RemoteFile file) {
        var path_hash = Checksum.compute_for_string(ChecksumType.MD5,
            file.remote_path);
        var cache_dir = Path.build_filename(Environment.get_user_cache_dir(),
            "valhalla");
        Posix.mkdir(cache_dir, 0700);
        return Path.build_filename(cache_dir, @"$(path_hash).png");
    }

    public void delete_thumbnail(Data.RemoteFile file) {
        var path = build_path(file);
        if (FileUtils.test(path, FileTest.EXISTS))
            FileUtils.unlink(path);
    }

    private async Gdk.Pixbuf? create_thumbnail(Data.RemoteFile file,
                                               string? path = null) {
        if (path == null)
            path = file.local_path;
        var thumbnail_path = build_path(file);
        uint8[] file_contents;
        try {
            FileUtils.get_data((!) path, out file_contents);
        } catch (FileError e) {
            warning("Creating thumbnail failed: %s", e.message);
            return null;
        }
        var crc = ZLib.Utility.adler32(1, file_contents);
        if ("%08x".printf((uint) crc) == file.crc32) {
            if (file.file_type.has_prefix("image/")) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale((!) path,
                        256, 256, true);
                    pixbuf.save(thumbnail_path, "png");
                    return pixbuf;
                } catch {
                    ;
                }
            } else {
                var cmd = mime_lookup[file.file_type];
                cmd = cmd.replace("%%", "%");
                // size in pixels
                cmd = cmd.replace("%s", "256");
                cmd = cmd.replace("%i", Shell.quote((!) path));
                cmd = cmd.replace("%u", Shell.quote(@"file://$((!) path)"));
                cmd = cmd.replace("%o", Shell.quote(thumbnail_path));
                try {
                    var p = new Subprocess.newv({"/bin/sh", "-c", cmd},
                        SubprocessFlags.INHERIT_FDS);;
                    yield p.wait_check_async();
                    return new Gdk.Pixbuf.from_file(thumbnail_path);
                } catch (GLib.Error e) {
                    warning("Creating thumbnail failed: %s", e.message);
                }
            }
        }
        return null;
    }

    public async Gdk.Pixbuf? get_thumbnail(Data.RemoteFile file) {
        var thumbnail_path = build_path(file);
        if (FileUtils.test(thumbnail_path, FileTest.EXISTS))
            try {
                return new Gdk.Pixbuf.from_file(thumbnail_path);
            } catch {}
        if (!mime_lookup.has_key(file.file_type) &&
                !file.file_type.has_prefix("image/"))
            return null;
        else if (file.local_path != null &&
                FileUtils.test((!) file.local_path, FileTest.EXISTS)) {
            return yield create_thumbnail(file);
        } else {
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
        Dir dir;
        try {
            dir = Dir.open(thumbnailer_path);
        } catch (GLib.FileError e) {
            error("Failed to initialize thumbnailer: %s", e.message);
        }

        string? filename;
        while ((filename = dir.read_name()) != null) {
            var path = Path.build_filename(thumbnailer_path, (!) filename);
            var thumbnailer = new KeyFile();
            try {
                thumbnailer.load_from_file(path, 0);
                var cmd = thumbnailer.get_string(keyfile_group, "Exec");
                var mimetypes = thumbnailer.get_string(keyfile_group,
                    "MimeType");
                foreach (var mimetype in mimetypes.split(";"))
                    mime_lookup[mimetype] = cmd;
            } catch (GLib.Error e) {
                // continue
            }
        }
    }
}

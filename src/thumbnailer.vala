namespace Valhalla.Thumbnailer {
    private const string keyfile_group = "Thumbnailer Entry";
    private Gee.HashMap<string, string>? mime_lookup = null;

    private void load() {
        if (mime_lookup == null) {
            mime_lookup = new Gee.HashMap<string, string>();
            var file = File.new_for_path("/usr/share/thumbnailers");
            FileEnumerator enumerator;
            try {
                enumerator = file.enumerate_children("*", 0);
            } catch (GLib.Error e) {
                return;
            }
            FileInfo info;
            while ((info = enumerator.next_file()) != null) {
                var thumbnailer = new KeyFile();
                var path = file.resolve_relative_path(info.get_name()).get_path();
                try {
                    thumbnailer.load_from_file(path, 0);
                    var cmd = thumbnailer.get_string(keyfile_group, "Exec");
                    var mimetypes = thumbnailer.get_string(keyfile_group, "MimeType");
                    foreach (var mimetype in mimetypes.split(";"))
                        mime_lookup[mimetype] = cmd;
                } catch (KeyFileError e) {
                    continue;
                }
            }
        }
    }

    private string? build_path(Database.RemoteFile file) {
        var path_hash = Checksum.compute_for_string(ChecksumType.MD5, file.remote_path);
        var cache_dir = Path.build_filename(Environment.get_user_cache_dir(), "valhalla");
        Posix.mkdir(cache_dir, 0700);
        var thumbnail_path = Path.build_filename(cache_dir, @"$(path_hash).png");
        return thumbnail_path;
    }

    public void delete_thumbnail(Database.RemoteFile file) {
        var path = build_path(file);
        if (FileUtils.test(path, FileTest.EXISTS))
            FileUtils.unlink(path);
    }

    private async Gdk.Pixbuf? create_thumbnail(Database.RemoteFile file, string? path = null) {
        if (path == null)
            path = file.local_filename;
        var thumbnail_path = build_path(file);
        uint8[] file_contents;
        FileUtils.get_data(path, out file_contents);
        var crc = ZLib.Utility.adler32(1, file_contents);
        if ("%08x".printf((uint) crc) == file.crc32) {
            if (file.file_type.has_prefix("image/")) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(path,
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
                cmd = cmd.replace("%i", Shell.quote(path));
                cmd = cmd.replace("%u", Shell.quote("file://" + path));
                cmd = cmd.replace("%o", Shell.quote(thumbnail_path));
                var p = new Subprocess.newv({"/bin/sh", "-c", cmd}, SubprocessFlags.INHERIT_FDS);;
                try {
                    yield p.wait_check_async();
                    return new Gdk.Pixbuf.from_file(thumbnail_path);
                } catch {
                    ;
                }
            }
        }
        return null;
    }

    public async Gdk.Pixbuf? get_thumbnail(Database.RemoteFile file) {
        var thumbnail_path = build_path(file);
        if (FileUtils.test(thumbnail_path, FileTest.EXISTS))
            try {
                return new Gdk.Pixbuf.from_file(thumbnail_path);
            } catch {
                ;
            }
        load();
        if (!mime_lookup.has_key(file.file_type) && !file.file_type.has_prefix("image/"))
            return null;
        else if (FileUtils.test(file.local_filename, FileTest.EXISTS)) {
            return yield create_thumbnail(file);
        } else {
            assert (file.remote_path != null);
            FileIOStream fstream;
            var tmp_path = File.new_tmp(null, out fstream).get_path();
            var session = new Soup.Session();
            var message = new Soup.Message("GET", file.remote_path);
            var istream = yield session.send_async(message);
            yield fstream.output_stream.splice_async(istream,
                OutputStreamSpliceFlags.CLOSE_SOURCE|OutputStreamSpliceFlags.CLOSE_TARGET);
            var pixbuf = yield create_thumbnail(file, tmp_path);
            FileUtils.unlink(tmp_path);
            return pixbuf;
        }
        return null;
    }
}
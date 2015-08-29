namespace utils.config {
    extern GLib.SettingsBackend settings_backend_new(string schema_id);

    public string _config_path() {
        var path = GLib.Path.build_filename(GLib.Environment.get_user_config_dir(), "valhalla");
        if (!GLib.FileUtils.test(path, GLib.FileTest.EXISTS)) {
            GLib.File.new_for_path(path).make_directory_with_parents();
        }
        return path;
    }

    public string path(string file) {
        return GLib.Path.build_filename(_config_path(), file);
    }

    public bool exists(owned string file, bool from_config = true) {
        if (from_config)
            file = path(file);
        return GLib.FileUtils.test(file, GLib.FileTest.EXISTS);
    }

    public int @delete(string file) {
        return GLib.FileUtils.unlink(path(file));
    }
}

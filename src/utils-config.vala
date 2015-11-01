namespace utils.config {
    extern SettingsBackend settings_backend_new(string schema_id, string section);

    public string _config_path() {
        var path = Path.build_filename(Environment.get_user_config_dir(), "valhalla");
        if (!FileUtils.test(path, FileTest.EXISTS)) {
            File.new_for_path(path).make_directory_with_parents();
        }
        return path;
    }

    public string path(string file) {
        return Path.build_filename(_config_path(), file);
    }

    public bool exists(owned string file, bool from_config = true) {
        if (from_config)
            file = path(file);
        return FileUtils.test(file, FileTest.EXISTS);
    }

    public int @delete(string file) {
        return FileUtils.unlink(path(file));
    }
}

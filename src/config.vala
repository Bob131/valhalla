namespace Valhalla.Config {
    public MutableSettings settings;
    private KeyFile keyfile;

    public string config_directory() {
        var dir = Path.build_filename(Environment.get_user_config_dir(), "valhalla");
        if (!FileUtils.test(dir, FileTest.EXISTS))
            DirUtils.create(dir, 0700);
        return dir;
    }

    private string config_path() {
        return Path.build_filename(config_directory(), "valhalla.conf");
    }

    public class MutableSettings : Config.Settings, Object {
        public KeyFile global {construct; private get;}
        public string section {construct; private get;}
        private Gee.HashMap<string, string> defaults;

        public new string? @get(string key) {
            try {
                return global.get_value(section, key);
            } catch (KeyFileError e) {
                if (defaults.has_key(key))
                    return defaults[key];
                return null;
            }
        }

        public new void @set(string key, string val) {
            if (val == "") {
                if (global.has_key(section, key))
                    global.remove_key(section, key);
                else
                    return;
            } else
                global.set_value(section, key, val);
            FileUtils.set_contents(config_path(), global.to_data());
        }

        public void set_default(string key, string val) {
            defaults[key] = val;
        }

        public MutableSettings(KeyFile keyfile, string section) {
            Object(global: keyfile, section: section);
            defaults = new Gee.HashMap<string, string>();
        }
    }

    private void init_keyfile() {
        keyfile = new KeyFile();
        try {
            keyfile.load_from_file(config_path(),
                KeyFileFlags.KEEP_COMMENTS|KeyFileFlags.KEEP_TRANSLATIONS);
        } catch (Error e) {
            FileUtils.set_contents(config_path(), "");
            init_keyfile();
        }
    }

    public void load() {
        if (settings != null)
            return;
        init_keyfile();
        settings = new MutableSettings(keyfile, "valhalla");
        foreach (var module in Modules.get_modules()) {
            module.settings = new MutableSettings(keyfile, module.name);
        }
    }
}

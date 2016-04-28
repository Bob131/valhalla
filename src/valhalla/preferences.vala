namespace Valhalla.Preferences {
    public string config_directory() {
        var dir = Path.build_filename(Environment.get_user_config_dir(),
            "valhalla");
        if (!FileUtils.test(dir, FileTest.EXISTS))
            DirUtils.create(dir, 0700);
        return dir;
    }

    private delegate void Callback();

    public class ModuleContext : Context, Object {
        public KeyFile keyfile {construct; private get;}
        public string section {construct; private get;}

        private Gee.HashMap<Type, Preference> prefs =
            new Gee.HashMap<Type, Preference>();
        public Gee.Collection<Preference> pref_objects {owned get {
            return prefs.values;
        }}

        public signal void value_changed();

        public void register_preference(Type type) {
            assert (type.is_a(typeof(Preference)));

            var pref = (Preference) Object.new(type);
            pref.notify["value"].connect(() => {
                if (pref.value == "")
                    pref.value = null;
                if (pref.value == null && pref.default != null)
                    pref.value = pref.default;

                var key = pref.get_type().name();
                try {
                    if (pref.value == null) {
                        if (keyfile.has_key(section, key))
                            keyfile.remove_key(section, key);
                    } else
                        keyfile.set_value(section, key, (!) pref.value);
                } catch (KeyFileError e) {
                    // bad news
                    error("Failed to set key '%s' with value '%s': %s", key,
                        (!) (pref.value ?? "(null)"), e.message);
                }

                value_changed();
            });
            prefs[type] = pref;
        }

        public new Preference @get(Type type) {
            assert (prefs.has_key(type));
            return prefs[type];
        }
    }

    // have ModuleContext instances share a KeyFile instance. This way, if the
    // file on disk has to be clobbered, we don't have several different sets
    // of data in memory overwriting one another's data on disk
    public class GlobalContext : Object {
        public KeyFile keyfile {construct; private get;}
        public ModuleContext app_preferences {private set; get;}
        private Gee.HashMap<string, ModuleContext> contexts =
            new Gee.HashMap<string, ModuleContext>();

        private void warn(GLib.Error e) {
            warning("Failed operation on valhalla.conf: %s", e.message);
        }

        private string config_path() {
            return Path.build_filename(config_directory(), "valhalla.conf");
        }

        private void write() {
            try {
                FileUtils.set_contents(config_path(), keyfile.to_data());
            } catch (FileError e) {
                warn(e);
            }
        }

        private void load() {
            try {
                keyfile.load_from_file(config_path(),
                    KeyFileFlags.KEEP_COMMENTS|KeyFileFlags.KEEP_TRANSLATIONS);
            } catch (KeyFileError e) {
                warn(e);
            } catch (FileError e) {
                if (e is FileError.NOENT)
                    write();
                else
                    warn(e);
            }
        }

        public new ModuleContext @get(string section) {
            if (contexts.has_key(section))
                return contexts[section];
            var ret = (ModuleContext) Object.new(typeof(ModuleContext),
                keyfile: keyfile, section: section);
            ret.value_changed.connect(() => {write();});
            contexts[section] = ret;
            return ret;
        }

        public GlobalContext() {
            Object(keyfile: new KeyFile());
            load();
            app_preferences = this["valhalla"];
        }
    }
}

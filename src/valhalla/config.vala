namespace Valhalla.Config {
    public string config_directory() {
        var dir = Path.build_filename(Environment.get_user_config_dir(),
            "valhalla");
        if (!FileUtils.test(dir, FileTest.EXISTS))
            DirUtils.create(dir, 0700);
        return dir;
    }

    protected delegate void Callback();

    public abstract class MutableSettings : Config.Settings, Object {
        public KeyFile keyfile {construct; private get;}
        public string section {construct; private get;}
        protected unowned Callback write;
        protected unowned Callback load;
        private Gee.HashMap<string, string> defaults =
            new Gee.HashMap<string, string>();

        public new string? @get(string key) {
            load();
            try {
                return keyfile.get_value(section, key);
            } catch (KeyFileError e) {
                // if SettingsContext.load has done its job properly, this
                // should be okay
                if (!(e is KeyFileError.GROUP_NOT_FOUND ||
                        e is KeyFileError.KEY_NOT_FOUND))
                    error(@"Failed fetching value of '$key': %s", e.message);

                if (defaults.has_key(key))
                    return defaults[key];
                return null;
            }
        }

        public new void @set(string key, string? val) {
            load();
            try {
                if (val == null) {
                    if (keyfile.has_key(section, key))
                        keyfile.remove_key(section, key);
                    else
                        return;
                } else
                    keyfile.set_value(section, key, (!) val);
            } catch (KeyFileError e) {
                // bad news
                error("Failed to set key '%s' with value '%s': %s", key,
                    (!) (val ?? "(null)"), e.message);
            }
            write();
        }

        public void set_default(string key, string val) {
            defaults[key] = val;
        }
    }

    // have MutableSettings instances share a KeyFile instance. This way, if the
    // file on disk has to be clobbered, we don't have several different sets
    // of data in memory overwriting one another's data on disk
    public class SettingsContext : Object {
        public KeyFile keyfile {construct; private get;}
        public MutableSettings app_settings {private set; get;}

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

        private class _MutableSettings : MutableSettings {
            public _MutableSettings(KeyFile kf, string s, Callback w,
                                    Callback l) {
                Object(keyfile: kf, section: s);
                write = w;
                load = l;
            }
        }
        public new MutableSettings @get(string section) {
            return (MutableSettings) new _MutableSettings(keyfile, section,
                write, load);
        }

        public SettingsContext() {
            Object(keyfile: new KeyFile());
            load();
            app_settings = this["valhalla"];
        }
    }
}

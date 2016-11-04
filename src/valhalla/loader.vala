// provided by autotools; typically points to /usr/lib64/valhalla
private extern const string MODULEDIR;

public class UploaderModule : Object {
    public string path {construct; get;}
    public Valhalla.Uploader uploader {private set; get;}

    Module? module;
    KeyFile keyfile;

    [CCode (has_target = false)]
    delegate Type UploaderRegistrar();

    public signal void commit_preferences();

    public bool load() {
        module = Module.open(path, ModuleFlags.BIND_LAZY);
        if (module == null) {
            warning("Could not load %s", Module.error());
            return false;
        }

        void* data;
        ((!) module).symbol("register_uploader", out data);

        var registrar_func = (UploaderRegistrar) data;
        if (registrar_func == null) {
            warning("Could not load %s: %s", ((!) module).name(),
                "Function 'register_uploader' not found");
            return false;
        }

        uploader = (Valhalla.Uploader) Object.new(registrar_func());

        foreach (var pref in uploader.preferences) {
            var section = uploader.get_type().name();
            var key = pref.get_type().name();
            pref.notify["value"].connect(() => {
                if (pref.value == "")
                    pref.value = null;
                if (pref.value == null && pref.default != null)
                    pref.value = pref.default;

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

                commit_preferences();
            });

            try {
                pref.value = keyfile.get_value(section, key);
            } catch {}
        }

        return true;
    }

    public UploaderModule(string path, KeyFile keyfile) {
        Object(path: path);
        this.keyfile = keyfile;
    }
}

class Loader : Object {
    Gee.HashMap<string, Valhalla.Uploader> _modules =
        new Gee.HashMap<string, Valhalla.Uploader>();
    public Gee.Collection<Valhalla.Uploader> modules {owned get {
        return _modules.values;
    }}

    string[] known_filenames = {};
    KeyFile keyfile;

    string[] paths {owned get {
        return {Path.build_filename(Environment.get_user_data_dir(),
            "valhalla"), MODULEDIR};
    }}

    string prefs_path {owned get {
        return Path.build_filename(config_directory(), "valhalla.conf");
    }}

    public Valhalla.Uploader? get_active() {
        string module_name;
        try {
            module_name = keyfile.get_value("Valhalla", "Uploader");
        } catch {
            return null;
        }

        if (!_modules.has_key(module_name))
            error("File upload module '%s' doesn't exist", module_name);

        return _modules[module_name];
    }

    public void set_active(Valhalla.Uploader target) {
        var name = target.get_type().name();
        assert (_modules.has_key(name));
        keyfile.set_value("Valhalla", "Uploader", name);
        write();
    }

    public new Valhalla.Uploader @get(string key) {
        return _modules[key];
    }

    void write() {
        try {
            FileUtils.set_contents(prefs_path, keyfile.to_data());
        } catch (FileError e) {
            warning(e.message);
        }
    }

    public Loader() {
        Object();

        keyfile = new KeyFile();

        try {
            keyfile.load_from_file(prefs_path,
                KeyFileFlags.KEEP_COMMENTS|KeyFileFlags.KEEP_TRANSLATIONS);
        } catch (KeyFileError e) {
            warning(e.message);
        } catch (FileError e) {
            if (e is FileError.NOENT)
                write();
            else
                warning(e.message);
        }

        if (!Module.supported())
            error("Modules aren't supported on this system");

        foreach (var path in paths) {
            Dir dir;
            try {
                dir = Dir.open(path);
            } catch (FileError e) {
                message(e.message);
                continue;
            }

            string? _fname;
            while ((_fname = dir.read_name()) != null) {
                var fname = (!) _fname;

                string module_name;
                if ("." in fname)
                    module_name = fname.reverse().split(".", 2)[1].reverse();
                else
                    module_name = fname;

                if (module_name == "libgd" || module_name in known_filenames)
                    continue;

                var module = new UploaderModule(
                    Path.build_filename(path, fname), keyfile);

                if (!module.load())
                    continue;

                _modules[module.uploader.get_type().name()] = module.uploader;
                module.commit_preferences.connect(() => write());
                known_filenames += module_name;
            }
        }

        if (modules.size == 0)
            error("Failed to locate file upload modules");
    }
}

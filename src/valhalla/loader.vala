namespace Valhalla.Modules {
    // provided by autotools; typically points to /usr/lib64/valhalla
    private extern const string MODULEDIR;

    public class Loader : Object {
        public Preferences.GlobalContext prefs {construct; private get;}
        private Gee.HashMap<string, BaseModule> modules =
            new Gee.HashMap<string, BaseModule>();
        private string[] paths {owned get {
            return {Path.build_filename(Environment.get_user_data_dir(),
                "valhalla"), MODULEDIR};
        }}

        public BaseModule? get_active_module() {
            var module_name =
                prefs.app_preferences[typeof(ModulePreference)].value;
            if (module_name == null)
                return null;
            if (!modules.has_key((!) module_name))
                error("File upload module '%s' doesn't exist", (!) module_name);
            return modules[(!) module_name];
        }

        public new BaseModule @get(string key) {
            return modules[key];
        }

        public Gee.Iterator<BaseModule> iterator() {
            return modules.values.iterator();
        }

        public Loader(Preferences.GlobalContext prefs) {
            Object(prefs: prefs);

            if (!Module.supported())
                error("Modules aren't supported on this system");

            foreach (var path in paths) {
                Dir dir;
                try {
                    dir = Dir.open(path);
                } catch (FileError e) {
                    continue;
                }
                string? _fname;
                while ((_fname = dir.read_name()) != null) {
                    var fname = (!) _fname;
                    string module_name;
                    if ("." in fname)
                        module_name =
                            fname.reverse().split(".", 2)[1].reverse();
                    else
                        module_name = fname;

                    if (modules.has_key(module_name) || module_name == "libgd")
                        continue;

                    var module = Module.open(Path.build_filename(path, fname),
                        ModuleFlags.BIND_LAZY);
                    if (module != null) {
                        void* data;
                        ((!) module).symbol("register_module", out data);
                        var registrar_func = (ModuleRegistrar) data;
                        ((!) module).symbol("register_preferences", out data);
                        var pref_reg_func = (PrefRegistrar) data;
                        if (registrar_func != null && pref_reg_func != null) {
                            var object =
                                (BaseModule) Object.new(registrar_func());
                            modules[object.get_type().name()] = object;
                            foreach (var pref in pref_reg_func())
                                prefs[object.get_type().name()]
                                    .register_preference(pref);
                            ((!) module).make_resident();
                        } else
                            warning("Could not load %s: %s", module_name,
                                "Function 'register_module' not found");
                    } else
                        warning("Could not load %s", Module.error());
                }
            }

            if (modules.size == 0)
                error("Failed to locate file upload modules");
        }
    }
}

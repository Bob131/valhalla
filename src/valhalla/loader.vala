namespace Valhalla.Modules {
    public class Loader : Object {
        private Gee.HashMap<string, BaseModule> modules =
            new Gee.HashMap<string, BaseModule>();
        public Config.SettingsContext settings {construct; private get;}

        public BaseModule? get_active_module() {
            var module_name = settings.app_settings["module"];
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

        public Loader(Config.SettingsContext settings) {
            Object(settings: settings);

            if (!Module.supported())
                error("Modules aren't supported on this system");

            foreach (var path in get_paths()) {
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
                        void* registrar;
                        ((!) module).symbol("register_module", out registrar);
                        var registrar_func = (ModuleRegistrar) registrar;
                        if (registrar_func != null) {
                            var types = registrar_func();
                            ((!) module).make_resident();
                            foreach (var type in types) {
                                assert (type.is_a(typeof(BaseModule)));
                                modules[module_name] =
                                    (BaseModule) Object.new(type);
                                modules[module_name].settings =
                                    settings[module_name];
                            }
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

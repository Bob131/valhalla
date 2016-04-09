namespace Valhalla.Modules {
    private BaseModule[] modules;
    private string[] loaded_names;

    public BaseModule[] get_modules() {
        if (modules == null)
            enumerate_modules();
        return modules;
    }

    public BaseModule? get_module(string module_name) {
        foreach (var module in get_modules())
            if (module.name == module_name)
                return module;
        return null;
    }

    public BaseModule? get_active_module() {
        return get_module(Config.settings["module"]);
    }

    public void enumerate_modules() {
        assert (Module.supported());
        if (loaded_names == null)
            loaded_names = {};
        if (modules == null)
            modules = {};

        foreach (var path in get_paths()) {
            if (!FileUtils.test(path, FileTest.EXISTS))
                continue;
            var file = File.new_for_path(path);
            var children = file.enumerate_children("*", 0);
            FileInfo? info;
            while ((info = children.next_file()) != null) {
                var module_name = info.get_name().split(".")[0];
                if (module_name in loaded_names || module_name == "libgd")
                    continue;
                var module = Module.open(
                    Path.build_filename(path, info.get_name()),
                        ModuleFlags.BIND_LAZY);
                if (module != null) {
                    void* registrar;
                    module.symbol("register_module", out registrar);
                    var registrar_func = (ModuleRegistrar) registrar;
                    if (registrar_func != null) {
                        var types = registrar_func();
                        module.make_resident();
                        foreach (var type in types) {
                            if (!type.is_a(typeof(BaseModule))) {
                                warning(@"Could not load $(module_name): Type '$(type.name()) does not derive from BaseModule'");
                                continue;
                            }
                            modules += (BaseModule) Object.new(type);
                        }
                        loaded_names += module_name;
                    } else
                        warning(@"Could not load $(module_name): Function 'register_module' not found");
                } else
                    warning("Could not load %s".printf(Module.error()));
            }
        }

        if (modules.length == 0) {
            new Gtk.MessageDialog(null, Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, "%s",
                "We weren't able to find any file upload modules").run();
            Posix.exit(1);
        }
    }
}

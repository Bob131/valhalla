namespace Valhalla.Modules {
    private BaseModule[] modules;
    private string[] loaded_names;
    private string arg0;

    public void set_arg0(string arg) {
        if (arg0 == null)
            arg0 = arg;
    }

    public BaseModule[] get_modules() {
        if (modules == null)
            enumerate_modules();
        return modules;
    }

    private string? whereami() {
        if ("_" in Environment.list_variables())
            return Path.get_dirname(Environment.get_variable("_"));
        else if (arg0 != null && "valhalla" in arg0) {
            string us;
            if (Path.is_absolute(arg0))
                us = Path.get_dirname(arg0);
            else
                us = Path.get_dirname(Path.build_filename(Environment.get_current_dir(), arg0));
            if (us.has_suffix(".libs"))
                us = Path.build_filename(us, "..");
            return us;
        }
        try {
            return FileUtils.read_link("/proc/self/exe");
        } catch (FileError e) {
            return null;
        }
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

        string[] paths = {};
        if (whereami() != null)
            paths += Path.build_filename(whereami(), "modules", ".libs");
        paths += MODULEDIR;

        foreach (var path in paths) {
            if (!FileUtils.test(path, FileTest.EXISTS))
                continue;
            var file = File.new_for_path(path);
            var children = file.enumerate_children("*", 0);
            FileInfo? info;
            while ((info = children.next_file()) != null) {
                var module_name = info.get_name().split(".")[0];
                if (module_name in loaded_names)
                    continue;
                var module = Module.open(
                    Path.build_filename(path, info.get_name()), ModuleFlags.BIND_LAZY);
                if (module != null) {
                    void* registrar;
                    module.symbol("register_module", out registrar);
                    var registrar_func = (ModuleRegistrar) registrar;
                    if (registrar_func != null) {
                        var type = registrar_func();
                        if (!type.is_a(typeof(BaseModule))) {
                            warning(@"Could not load $(module_name): Type '$(type.name()) does not derive from BaseModule'");
                            continue;
                        }
                        module.make_resident();
                        modules += (BaseModule) Object.new(type);
                        loaded_names += module_name;
                    } else
                        warning(@"Could not load $(module_name): Function 'register_module' not found");
                } else
                    warning("Could not load %s".printf(Module.error()));
            }
        }
    }
}

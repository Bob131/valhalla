class ValhallaMenuProvider : Nautilus.MenuProvider, Object {
    public virtual List<Nautilus.MenuItem>? get_file_items(Gtk.Widget window, List<Nautilus.FileInfo> files) {
        var gfiles = new List<File>();
        foreach (var file in files) {
            if (file.is_directory())
                return null;
            gfiles.append(file.get_location());
        }

        var list = new List<Nautilus.MenuItem>();
        var item = new Nautilus.MenuItem("valhalla", "Upload with Valhalla", "");
        item.activate.connect(() => {
            var info = AppInfo.create_from_commandline("valhalla", null, 0);
            info.launch(gfiles, null);
        });
        list.append(item);
        return list;
    }

    public virtual List<Nautilus.MenuItem>? get_background_items(Gtk.Widget window, Nautilus.FileInfo current_folder) {
        return null;
    }
}


[ModuleInit]
public void nautilus_module_initialize(TypeModule module) {
    typeof(ValhallaMenuProvider);
}

public void nautilus_module_shutdown() {;}

public void nautilus_module_list_types(out Type[] types) {
    types = {typeof(ValhallaMenuProvider)};
}

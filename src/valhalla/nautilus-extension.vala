class ValhallaMenuProvider : Nautilus.MenuProvider, Object {
    public virtual List<Nautilus.MenuItem>? get_file_items(
            Gtk.Widget window, List<Nautilus.FileInfo> files) {
        var gfiles = new List<File>();
        foreach (var file in files) {
            if (file.is_directory())
                return null;
            gfiles.append(file.get_location());
        }

        var list = new List<Nautilus.MenuItem>();
        var item = new Nautilus.MenuItem("valhalla", "Upload with Valhalla",
            "");
        item.activate.connect(() => {
            var info = new DesktopAppInfo("so.bob131.valhalla.desktop");
            try {
                info.launch(gfiles, null);
            } catch (Error e) {
                new Gtk.MessageDialog(null, 0, Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.CLOSE, "Failed to launch Valhalla: %s",
                    e.message).show();
            }
        });
        list.append(item);
        return list;
    }

    public virtual List<Nautilus.MenuItem>? get_background_items(
            Gtk.Widget window, Nautilus.FileInfo current_folder) {
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

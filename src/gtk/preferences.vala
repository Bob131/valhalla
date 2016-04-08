namespace Valhalla.Widgets {
    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences.ui")]
    class Preferences : Gtk.Box {
        [GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences-list-row.ui")]
        private class ListRow : Gtk.Box {
            public Modules.BaseModule module {construct; get;}

            [GtkChild]
            private Gtk.Label module_name;
            [GtkChild]
            private Gtk.Label module_description;

            public ListRow(Modules.BaseModule module) {
                Object(module: module);
                module_name.label = module.pretty_name;
                module_description.label = @"<small>$(module.description)</small>";
            }
        }

        [GtkChild]
        private Gtk.ListBox modules;
        [GtkChild]
        private Gtk.Box controls;

        [GtkCallback]
        private void module_selected(Gtk.ListBoxRow? row) {
            if (row == null)
                return;
            var module = (row.get_child() as ListRow).module;
            Config.settings["module"] = module.name;
            foreach (var child in controls.get_children())
                child.destroy();
            if (!module.implements_delete) {
                var caution = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                caution.halign = Gtk.Align.CENTER;
                caution.add(new Gtk.Image.from_icon_name("dialog-warning", Gtk.IconSize.LARGE_TOOLBAR));
                caution.add(new Gtk.Label("This module does not support file deletion"));
                controls.add(caution);
            }
            var size_group = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
            foreach (var pref in module.build_panel()) {
                var indent = 0;
                if (pref.label != null) {
                    var label = new Gtk.Label(pref.label);
                    label.halign = Gtk.Align.START;
                    controls.add(label);
                    indent = 12;
                }
                pref.margin_left = indent;
                pref.hexpand = true;
                size_group.add_widget(pref);
                if (pref.help != null) {
                    var help_popover = new Gtk.Popover(pref);
                    var help_label = new Gtk.Label(pref.help);
                    help_label.margin = 6;
                    help_label.visible = true;
                    help_popover.add(help_label);
                    help_popover.modal = false;
                    help_popover.position = Gtk.PositionType.BOTTOM;
                    pref.event.connect((e) => {
                        if (e.type == Gdk.EventType.ENTER_NOTIFY)
                            help_popover.show();
                        else if (e.type == Gdk.EventType.LEAVE_NOTIFY)
                            help_popover.hide();
                        return false;
                    });
                }
                if (module.settings[pref.key] != null)
                    pref.write(module.settings[pref.key]);
                if (pref.default != null)
                    (module.settings as Config.MutableSettings).set_default(pref.key, pref.default);
                pref.change_notify.connect(() => {
                    (module.settings as Config.MutableSettings)[pref.key] = pref.read();
                });
                controls.add(pref);
            }
            controls.show_all();
        }

        construct {
            var i = 0;
            foreach (var module in Modules.get_modules()) {
                modules.add(new ListRow(module));
                if (module.name == Config.settings["module"]) {
                    modules.select_row(modules.get_row_at_index(i));
                }
                i++;
            }
        }
    }
}

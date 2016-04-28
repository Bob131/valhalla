namespace Valhalla.Widgets {
    [GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences.ui")]
    class Preferences : Gtk.Box {
        [GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences-list-row.ui")]
        private class ListRow : Gtk.Box {
            public Module.Uploader uploader {construct; get;}

            [GtkChild]
            private Gtk.Label uploader_name;
            [GtkChild]
            private Gtk.Label description;

            public ListRow(Module.Uploader uploader) {
                Object(uploader: uploader);
                uploader_name.label = uploader.pretty_name;
                description.label =
                    @"<small>$(uploader.description)</small>";
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
            var module = ((ListRow) ((!) row).get_child()).uploader;
            get_app().loader.set_active(module.get_type().name());
            foreach (var child in controls.get_children())
                child.destroy();
            if (!module.implements_delete) {
                var caution = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                caution.halign = Gtk.Align.CENTER;
                caution.add(new Gtk.Image.from_icon_name("dialog-warning",
                    Gtk.IconSize.LARGE_TOOLBAR));
                caution.add(new Gtk.Label(
                    "This module does not support file deletion"));
                controls.add(caution);
            }
            var size_group = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
            foreach (var pref in module.preferences) {
                if (pref is Gtk.Widget)
                    controls.add((Gtk.Widget) pref);
                else {
                    var control = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

                    var label = new Gtk.Label(
                        pref.pretty_name ?? pref.get_type().name());
                    label.halign = Gtk.Align.START;
                    control.add(label);

                    var entry = new Gtk.Entry();
                    entry.margin_left = 12;
                    entry.hexpand = true;
                    size_group.add_widget(entry);
                    if (pref.default != null)
                        entry.placeholder_text = (!) pref.default;
                    pref.bind_property("value", entry, "text",
                        BindingFlags.BIDIRECTIONAL|BindingFlags.SYNC_CREATE);
                    control.add(entry);

                    if (pref.help_text != null) {
                        var help_popover = new Gtk.Popover(entry);
                        var help_label = new Gtk.Label(pref.help_text);
                        help_label.margin = 6;
                        help_label.visible = true;
                        help_popover.add(help_label);
                        help_popover.modal = false;
                        help_popover.position = Gtk.PositionType.BOTTOM;
                        entry.event.connect((e) => {
                            if (e.type == Gdk.EventType.ENTER_NOTIFY)
                                help_popover.show();
                            else if (e.type == Gdk.EventType.LEAVE_NOTIFY)
                                help_popover.hide();
                            return false;
                        });
                    }

                    controls.add(control);
                }
            }
            controls.show_all();
        }

        construct {
            var i = 0;
            foreach (var module in get_app().loader.modules) {
                modules.add(new ListRow(module));
                if (module == get_app().loader.get_active())
                    modules.select_row(modules.get_row_at_index(i));
                else
                    i++;
            }
        }
    }
}

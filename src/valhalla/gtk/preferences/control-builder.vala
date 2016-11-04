[GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences/caution.ui")]
class CautionWidget : Gtk.Box {}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences/help-popover.ui")]
class HelpPopover : Gtk.Popover {
    [GtkChild]
    Gtk.Label label;

    public HelpPopover(Gtk.Entry entry, string text) {
        Object(relative_to: entry);

        label.label = text;

        entry.event.connect((e) => {
            if (e.type == Gdk.EventType.ENTER_NOTIFY)
                this.popup();
            else if (e.type == Gdk.EventType.LEAVE_NOTIFY)
                this.popdown();
            return false;
        });
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences/default-control.ui")]
class DefaultControl : Gtk.Box {
    public Valhalla.Preference preference {construct; get;}

    [GtkChild]
    Gtk.Label label;
    [GtkChild]
    Gtk.Entry entry;

    public DefaultControl(Valhalla.Preference preference) {
        Object(preference: preference);

        label.label =
            (!) (preference.pretty_name ?? preference.get_type().name());

        if (preference.default != null)
            entry.placeholder_text = (!) preference.default;
        preference.bind_property("value", entry, "text",
            BindingFlags.BIDIRECTIONAL|BindingFlags.SYNC_CREATE);

        if (preference.help_text != null)
            new HelpPopover(entry, (!) preference.help_text);
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences/module-row.ui")]
class ModuleListRow : Gtk.ListBoxRow {
    public Valhalla.Uploader uploader {construct; get;}

    [GtkChild]
    Gtk.Label uploader_name;
    [GtkChild]
    Gtk.Label description;

    public ModuleListRow(Valhalla.Uploader uploader) {
        Object(uploader: uploader);
        uploader_name.label = uploader.pretty_name;
        description.label = @"<small>$(uploader.description)</small>";
    }
}

[GtkTemplate (ui = "/so/bob131/valhalla/gtk/preferences/control-builder.ui")]
class ControlBuilder : Gtk.Box {
    [GtkChild]
    Gtk.ListBox modules;
    [GtkChild]
    Gtk.Box controls;

    [GtkCallback]
    void module_selected(Gtk.ListBoxRow? row)
        requires (row == null || (!) row is ModuleListRow)
    {
        if (row == null)
            return;

        var module = ((ModuleListRow) row).uploader;
        get_app().loader.set_active(module);

        foreach (var child in controls.get_children())
            child.destroy();

        if (!(module is Valhalla.Deleter))
            controls.add(new CautionWidget());

        foreach (var pref in module.preferences)
            if (pref is Gtk.Widget)
                controls.add((Gtk.Widget) pref);
            else
                controls.add(new DefaultControl(pref));

        controls.show_all();
    }

    construct {
        var i = 0;
        foreach (var module in get_app().loader.modules) {
            modules.add(new ModuleListRow(module));
            if (module == get_app().loader.get_active())
                modules.select_row(modules.get_row_at_index(i));
            else
                i++;
        }
    }
}

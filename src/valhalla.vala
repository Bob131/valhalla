using Valhalla;

[DBus (name = "so.bob131.valhalla")]
class DBusHooks : Object {
    [DBus (visible = false)]
    public signal void capture_screenshot_signal();

    public void capture_screenshot() {
        capture_screenshot_signal();
    }
}

// TODO:
// * nautilus integration
// * make Modules and Config less garbage
// * module index functionality
// * ShareX JSON parser module
// * about dialog
class valhalla : Gtk.Application {
    public Widgets.MainWindow window;
    public Database.Database database;

    // stub
    protected override void open(File[] files, string _) {
        ;
    }

    protected override void activate() {
        Config.load();
        database = new Database.Database();
        window = new Widgets.MainWindow();
        this.add_window(window);
    }

    protected override bool dbus_register(DBusConnection connection, string object_path) throws GLib.Error {
        base.dbus_register(connection, object_path);

        var hooks = new DBusHooks();
        hooks.capture_screenshot_signal.connect(() => {
            this.activate();
            window.capture_screenshot();
        });

        connection.register_object(object_path, hooks);
        return true;
    }

    protected override void dbus_unregister(DBusConnection connection, string object_path) {
        base.dbus_unregister(connection, object_path);
    }

    public valhalla() {
        Object(application_id: "so.bob131.valhalla",
            flags: ApplicationFlags.HANDLES_OPEN);
    }

    public static int main(string[] args) {
        Modules.set_arg0(args[0]);
        return new valhalla().run(args);
    }
}

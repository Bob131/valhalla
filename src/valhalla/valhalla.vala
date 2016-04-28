using Valhalla;

[DBus (name = "so.bob131.valhalla")]
public class DBusHooks : Object {
    [DBus (visible = false)]
    public signal void capture_screenshot_signal();

    public void capture_screenshot() {
        capture_screenshot_signal();
    }
}

public string config_directory() {
    var dir = Path.build_filename(Environment.get_user_config_dir(),
            "valhalla");
    if (!FileUtils.test(dir, FileTest.EXISTS))
        DirUtils.create(dir, 0700);
    return dir;
}

// TODO:
// * module index functionality
// * about dialog
class valhalla : Gtk.Application {
    public Widgets.Window? window {private set; get; default = null;}
    public Database.Database database {construct; get;}
    public Thumbnailer thumbnailer {construct; get;}
    public Valhalla.Module.Loader loader {construct; get;}

    protected override void open(File[] files, string _) {
        activate();
        foreach (var file in files)
            if (file.get_path() != null)
                ((!) window).kickoff_upload.begin((!) file.get_path());
    }

    protected override void activate() {
        if (window == null) {
            window = new Widgets.Window(this);
            this.add_window((!) window);
        } else
            ((!) window).present();
    }

    protected override bool dbus_register(DBusConnection connection,
                                          string object_path)
                                         throws GLib.Error {
        base.dbus_register(connection, object_path);

        var hooks = new DBusHooks();
        hooks.capture_screenshot_signal.connect(() => {
            if (window == null) {
                activate();
                ((!) window).one_shot = true;
            }
            ((!) window).capture_screenshot.begin();
        });

        connection.register_object(object_path, hooks);
        return true;
    }

    protected override void dbus_unregister(DBusConnection connection,
                                            string object_path) {
        base.dbus_unregister(connection, object_path);
    }

    public valhalla() {
        Object(application_id: "so.bob131.valhalla",
            flags: ApplicationFlags.HANDLES_OPEN,
            database: new Database.Database(),
            thumbnailer: new Thumbnailer(),
            loader: new Valhalla.Module.Loader());
    }

    public static int main(string[] args) {
        return new valhalla().run(args);
    }
}

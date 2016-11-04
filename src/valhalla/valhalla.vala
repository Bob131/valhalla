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
    public Window? window {private set; get;}
    public Database database {construct; get;}
    public Thumbnailer thumbnailer {construct; get;}
    public Loader loader {construct; get;}

    internal override void open(GLib.File[] files, string _) {
        activate();
        foreach (var file in files)
            ((!) window).kickoff_upload.begin(file);
    }

    internal override void activate() {
        if (window == null) {
            window = new Window(this);
            this.add_window((!) window);
        } else
            ((!) window).present();
    }

    internal override bool dbus_register(DBusConnection connection,
        string object_path) throws Error
    {
        var hooks = new DBusHooks();
        hooks.capture_screenshot_signal.connect(() => {
            if (window == null)
                activate();
            ((!) window).capture_screenshot.begin();
        });

        connection.register_object(object_path, hooks);

        return base.dbus_register(connection, object_path);
    }

    public valhalla() {
        Object(application_id: "so.bob131.valhalla",
            flags: ApplicationFlags.HANDLES_OPEN,
            database: new Database(),
            thumbnailer: new Thumbnailer(),
            loader: new Loader());
    }

    public static int main(string[] args) {
        return new valhalla().run(args);
    }
}

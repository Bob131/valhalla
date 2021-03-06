[DBus (name = "so.bob131.valhalla")]
interface DBusHooks : Object {
    public abstract void capture_screenshot() throws IOError;
}

int main(string[] args) {
    try {
        var iface = Bus.get_proxy_sync<DBusHooks>(BusType.SESSION,
            "so.bob131.valhalla", "/so/bob131/valhalla");
        iface.capture_screenshot();
    } catch {}
    return 0;
}

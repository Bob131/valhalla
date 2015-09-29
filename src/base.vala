const string _id = "so.bob131.valhalla";
const string _path = "/so/bob131/valhalla/";
Settings settings;
utils.Database* database;
utils.Mount* mount;
bool _mount_instantiated = false;


void init_stuff() {
    settings = new GLib.Settings.with_backend(_id, utils.config.settings_backend_new(_path));
    database = new utils.Database();
}

void deinit_stuff() {
    delete database;
    if (_mount_instantiated) {
        delete mount;
    }
}

const string _id = "so.bob131.valhalla";
const string _path = "/so/bob131/valhalla/";
Settings settings;
string settings_section;
utils.Database* database;
utils.Mount* mount;
bool _mount_instantiated = false;


void init_stuff() {
    if (settings_section == null) {
        settings_section = "default";
    }
    settings = new GLib.Settings.with_backend(
        _id, utils.config.settings_backend_new(_path, settings_section));
    database = new utils.Database();
}

void deinit_stuff() {
    delete database;
    if (_mount_instantiated) {
        delete mount;
    }
}

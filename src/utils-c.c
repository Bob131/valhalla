#include <stdio.h>
#include <sys/file.h>


#include <sys/ioctl.h>
#include <unistd.h>

int utils_ui_progress_get_width() {
    struct winsize ws;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);
    return ws.ws_col;
}


#include <gio/gio.h>
#define G_SETTINGS_ENABLE_BACKEND
#include <gio/gsettingsbackend.h>

gchar* utils_config_path(const gchar *file);

GSettingsBackend* utils_config_settings_backend_new(const gchar *schema_id,
                                                    const gchar *section) {
    g_return_val_if_fail(schema_id != NULL, NULL);
    g_return_val_if_fail(section != NULL, NULL);
    return g_keyfile_settings_backend_new(
            utils_config_path("valhalla.conf"), schema_id, section);
}

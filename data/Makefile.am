gsettings_SCHEMAS = so.bob131.valhalla.gschema.xml
@GSETTINGS_RULES@

all:
	glib-compile-resources so.bob131.valhalla.gresources.xml --target=so.bob131.valhalla.gresources.c --generate-source
	glib-compile-schemas .

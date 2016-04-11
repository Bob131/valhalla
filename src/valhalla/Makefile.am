bin_PROGRAMS = valhalla valhalla-screenshot


gd.vapi:
	$(AM_V_GEN) cp $(top_srcdir)/libgd/gd-1.0.vapi $(top_srcdir)/vapi/gd-1.0.vapi

resource_files = $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(srcdir) gresources.xml)
gresources.c: gresources.xml $(resource_files)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) --generate-source $<

BUILT_SOURCES = gd.vapi gresources.c


valhalla_SOURCES = \
	gresources.c \
	gtk/files.vala \
	gtk/preferences.vala \
	gtk/transfers.vala \
	gtk/window.vala \
	config.vala \
	database.vala \
	loader.vala \
	screenshot.vala \
	thumbnailer.vala \
	valhalla.vala

valhalla_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg gtk+-3.0 \
	--pkg gmodule-2.0 \
	--pkg zlib \
	--pkg posix \
	--pkg sqlite3 \
	--pkg libsoup-2.4 \
	--pkg gd-1.0 \
	--pkg valhalla \
	--gresources gresources.xml \
	$(valhalla_U_VALAFLAGS)

valhalla_CFLAGS = \
	-DVALHALLA_MODULES_MODULEDIR=\"$(pkglibdir)\" \
	-I $(top_srcdir)/libgd -I $(top_srcdir)/src/libvalhalla \
	$(valhalla_U_CFLAGS)

valhalla_LDADD = \
	-lm \
	$(top_builddir)/libgd/libgd.la \
	$(top_srcdir)/src/libvalhalla/libvalhalla.la \
	$(valhalla_U_LIBS)


valhalla_screenshot_SOURCES = valhalla-screenshot.vala
valhalla_screenshot_VALAFLAGS = --pkg gio-2.0 $(valhalla_U_VALAFLAGS)
valhalla_screenshot_CFLAGS = $(valhalla_CFLAGS)
valhalla_screenshot_LDADD = $(valhalla_U_LIBS)


nautilus_extensiondir = $(NAUTILUS_EXTENSION_DIR)
nautilus_extension_LTLIBRARIES = libnautilus-valhalla.la

libnautilus_valhalla_la_SOURCES = nautilus-extension.c
libnautilus_valhalla_la_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gio-unix-2.0 \
	--pkg gtk+-3.0 \
	--pkg nautilus \
	$(valhalla_U_VALAFLAGS)
libnautilus_valhalla_la_CFLAGS = $(valhalla_U_CFLAGS)
libnautilus_valhalla_la_LDFLAGS = -module -avoid-version
libnautilus_valhalla_la_LIBADD = $(valhalla_U_LIBS)

nautilus-extension.c:
	$(AM_V_VALAC) $(VALAC) $(libnautilus_valhalla_la_VALAFLAGS) -C nautilus-extension.vala && \
	$(SED) -i "s/(GType\*\* types/(const GType\*\* types/" nautilus-extension.c

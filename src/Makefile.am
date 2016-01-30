lib_LTLIBRARIES = libvalhalla.la
bin_PROGRAMS = valhalla valhalla-screenshot

valhallavapidir = $(datadir)/vala/vapi
valhallavapi_DATA = $(top_srcdir)/vapi/valhalla.vapi
valhallaheaderdir = $(includedir)
valhallaheader_DATA = valhalla.h


libvalhalla_la_SOURCES = \
	module-api.vala

libvalhalla_la_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg gtk+-3.0 \
	--library valhalla \
	-H valhalla.h \
	--vapi $(top_srcdir)/vapi/valhalla.vapi \
	--enable-experimental-non-null

libvalhalla_la_CFLAGS = \
	-DVALHALLA_MODULES_MODULEDIR=\"$(pkglibdir)\" \
	$(valhalla_U_CFLAGS)

libvalhalla_la_LIBADD = \
	$(valhalla_U_LIBS)


gd.vapi:
	cp $(top_srcdir)/libgd/gd-1.0.vapi $(top_srcdir)/vapi

BUILT_SOURCES = gd.vapi

valhalla_SOURCES = \
	../data/so.bob131.valhalla.gresources.c \
	config.vala \
	database.vala \
	gtk-widgets.vala \
	modules.vala \
	screenshot.vala \
	thumbnailer.vala \
	valhalla.vala

valhalla_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg gtk+-3.0 \
	--pkg gmodule-2.0 \
	--pkg zlib \
	--pkg libnotify \
	--pkg posix \
	--pkg sqlite3 \
	--pkg libsoup-2.4 \
	--pkg gd-1.0 \
	--pkg valhalla \
	--vapidir $(top_srcdir)/vapi \
	--target-glib $(GLIB_REQUIRED) \
	--gresources $(top_srcdir)/data/so.bob131.valhalla.gresources.xml

valhalla_CFLAGS = \
	-DVALHALLA_MODULES_MODULEDIR=\"$(pkglibdir)\" \
	-I $(top_srcdir)/libgd \
	$(valhalla_U_CFLAGS)

valhalla_LDADD = \
	-lm \
	$(top_builddir)/libgd/libgd.la \
	$(libvalhalla_la_OBJECTS) \
	$(valhalla_U_LIBS)


valhalla_screenshot_SOURCES = valhalla-screenshot.vala
valhalla_screenshot_VALAFLAGS = \
	--pkg gio-2.0 \
	--target-glib $(GLIB_REQUIRED)
valhalla_screenshot_CFLAGS = $(valhalla_CFLAGS)
valhalla_screenshot_LDADD = $(valhalla_U_LIBS)

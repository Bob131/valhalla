bin_PROGRAMS = valhalla gvalhalla

base_sources = \
	base.vala \
	utils.vala \
	utils-config.vala \
	utils-c.c \
	utils-files.vala \
	utils-screenshot.vala \
	utils-ui.vala


valhalla_SOURCES = \
	$(base_sources) \
	valhalla.vala

valhalla_CFLAGS = \
	$(valhalla_U_CFLAGS)

valhalla_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg readline \
	--pkg posix \
	--pkg linux \
	--pkg zlib \
	--pkg libmagic \
	--pkg sqlite3 \
	--pkg gdk-3.0 \
	--pkg gtk+-3.0 \
	--pkg gmodule-2.0 \
	--thread \
	--target-glib $(GLIB_REQUIRED) \
	--gresources $(top_srcdir)/data/so.bob131.valhalla.gresources.xml

valhalla_LDADD = \
	-lm \
	-lmagic \
	$(valhalla_U_LIBS)


gvalhalla_SOURCES = \
	$(base_sources) \
	$(top_srcdir)/data/so.bob131.valhalla.gresources.c \
	gvalhalla.vala

gvalhalla_CFLAGS = \
	$(valhalla_U_CFLAGS)

gvalhalla_VALAFLAGS = \
	$(valhalla_VALAFLAGS)

gvalhalla_LDADD = \
	$(valhalla_LDADD)

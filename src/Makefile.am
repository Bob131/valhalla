bin_PROGRAMS = valhalla gvalhalla


valhalla_SOURCES = \
	utils.vala \
	utils-config.vala \
	utils-c.c \
	utils-files.vala \
	utils-screenshot.vala \
	utils-ui.vala \
	main.vala

valhalla_CFLAGS = \
	$(valhalla_U_CFLAGS)

valhalla_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg readline \
	--pkg posix \
	--pkg linux \
	--pkg zlib \
	--pkg libmagic \
	--pkg gdk-3.0 \
	--pkg gtk+-3.0 \
	--pkg gmodule-2.0 \
	--pkg libsoup-2.4 \
	--pkg sqlite3 \
	--pkg flock \
	--thread \
	--vapidir $(top_srcdir)/vapi \
	--enable-experimental-non-null \
	--target-glib $(GLIB_REQUIRED) \
	--gresources $(top_srcdir)/data/so.bob131.valhalla.gresources.xml

valhalla_LDADD = \
	-lm \
	-lmagic \
	$(valhalla_U_LIBS)


.PHONY: gvalhalla

gvalhalla$(EXEEXT):
	cp valhalla gvalhalla

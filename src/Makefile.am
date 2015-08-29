bin_PROGRAMS = valhalla

valhalla_SOURCES = \
	utils.vala \
	utils-cli.vala \
	utils-config.vala \
	utils-c.c \
	utils-files.vala \
	utils-screenshot.vala \
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
	--pkg sqlite3 \
	--pkg gdk-3.0 \
	--pkg gtk+-3.0 \
	--target-glib $(GLIB_REQUIRED)

valhalla_LDADD = \
	-lreadline -ltermcap \
	-lm \
	-lz \
	-lmagic \
	-lsqlite3 \
	$(valhalla_U_LIBS)

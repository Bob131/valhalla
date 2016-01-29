desktopdir = $(datadir)/applications
desktop_DATA = so.bob131.valhalla.desktop

dbusservicedir = $(datadir)/dbus-1/services
dbusservice_DATA = so.bob131.valhalla.service

# TODO: Use a real icon rather than the send file placeholder
so.bob131.valhalla.desktop: Makefile
	$(AM_V_GEN) (echo '[Desktop Entry]'; \
	             echo 'Type=Application'; \
	             echo 'Name=Valhalla'; \
	             echo 'Exec=valhalla'; \
	             echo 'DBusActivatable=true'; \
	             echo 'Icon=document-send') > $@.tmp && mv $@.tmp $@

so.bob131.valhalla.service: Makefile
	$(AM_V_GEN) (echo '[D-BUS Service]'; \
	             echo 'Name=so.bob131.valhalla'; \
	             echo 'Exec=${bindir}/valhalla --gapplication-service') > $@.tmp && mv $@.tmp $@

all:
	glib-compile-resources so.bob131.valhalla.gresources.xml --target=so.bob131.valhalla.gresources.c --generate-source

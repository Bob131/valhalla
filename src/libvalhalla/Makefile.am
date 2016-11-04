lib_LTLIBRARIES = libvalhalla.la

valhallavapidir = $(datadir)/vala/vapi
valhallavapi_DATA = valhalla.vapi
valhallaheaderdir = $(includedir)
valhallaheader_DATA = valhalla.h

libvalhalla_la_SOURCES = libvalhalla.vala
libvalhalla_la_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--library valhalla \
	-H valhalla.h \
	--vapi valhalla.vapi \
	$(valhalla_U_VALAFLAGS)
libvalhalla_la_CFLAGS = $(valhalla_U_CFLAGS)
libvalhalla_la_LIBADD = $(valhalla_U_LIBS)

dist-hook:
	cd $(distdir); rm -f $(CLEANFILES)

-include $(top_srcdir)/git.mk

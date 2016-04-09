lib_LTLIBRARIES = libvalhalla.la

valhallavapidir = $(datadir)/vala/vapi
valhallavapi_DATA = $(top_srcdir)/vapi/valhalla.vapi
valhallaheaderdir = $(includedir)
valhallaheader_DATA = valhalla.h


libvalhalla_la_SOURCES = \
	libvalhalla.vala

libvalhalla_la_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg gtk+-3.0 \
	--library valhalla \
	-H valhalla.h \
	--vapi $(top_srcdir)/vapi/valhalla.vapi \
	--enable-experimental-non-null \
	$(valhalla_U_VALAFLAGS)

libvalhalla_la_CFLAGS = \
	-DVALHALLA_MODULES_MODULEDIR=\"$(pkglibdir)\" \
	$(valhalla_U_CFLAGS)

libvalhalla_la_LIBADD = \
	$(valhalla_U_LIBS)

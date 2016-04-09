common_valaflags = \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg valhalla \
	--vapidir $(top_srcdir)/vapi \
	$(valhalla_U_VALAFLAGS)

common_cflags = \
	-fPIC \
	-I $(top_srcdir)/src/libvalhalla \
	$(valhalla_U_CFLAGS)

common_libadd = \
	$(top_srcdir)/src/libvalhalla/libvalhalla.la \
	$(valhalla_U_LIBS)

common_ldflags = -module -avoid-version -shared -export-dynamic


pkglib_LTLIBRARIES = \
	fuse.la


fuse_la_SOURCES = fuse.vala
fuse_la_VALAFLAGS = \
	--pkg posix \
	$(common_valaflags)
fuse_la_CFLAGS = $(common_cflags)
fuse_la_LIBADD = $(common_libadd)
fuse_la_LDFLAGS = $(common_ldflags)

AM_MAKEFLAGS = --no-print-directory
ACLOCAL_AMFLAGS=-I m4

SUBDIRS=libgd data src src/modules

EXTRA_DIST = \
	vapi/gee-0.8.vapi \
	vapi/libsoup-2.4.vapi \
	vapi/nautilus.vapi \
	vapi/sqlite3.vapi

dist-hook:
	cd $(distdir)/vapi; rm -f valhalla.vapi

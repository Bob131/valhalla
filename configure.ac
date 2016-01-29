AC_INIT([valhalla],[0.0])

AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIRS([m4])

AM_INIT_AUTOMAKE([foreign subdir-objects])

AM_PROG_VALAC([0.24])
AM_PROG_CC_C_O

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40.0
GOBJ_REQUIRED=2.0.0
GIO_REQUIRED=2.0.0

PKG_CHECK_MODULES(valhalla_U, [
  glib-2.0 >= $GLIB_REQUIRED
  gobject-2.0 >= $GOBJ_REQUIRED
  gio-2.0 >= $GIO_REQUIRED
  gmodule-2.0
  gtk+-3.0
  gee-0.8
  sqlite3
  libnotify
  zlib
  libsoup-2.4
])

AC_SUBST([GLIB_REQUIRED])

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

LT_INIT([dlopen])

AC_CONFIG_FILES([
Makefile
src/Makefile
src/modules/Makefile
data/Makefile
])
AC_OUTPUT

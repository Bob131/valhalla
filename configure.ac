AC_INIT([valhalla],[0.0])

AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])

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
  libnautilus-extension
])

AC_SUBST([GLIB_REQUIRED])
NAUTILUS_EXTENSION_DIR=`$PKG_CONFIG --variable=extensiondir libnautilus-extension`
AC_SUBST(NAUTILUS_EXTENSION_DIR)

LT_INIT([dlopen])

LIBGD_INIT([
	notification
	vapi
])

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
libgd/Makefile
data/Makefile
src/Makefile
src/modules/Makefile
])
AC_OUTPUT

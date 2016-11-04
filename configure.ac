AC_INIT([valhalla], [0.1])

AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([foreign subdir-objects])
AM_SILENT_RULES([yes])

AM_PROG_VALAC([0.28])
AM_PROG_CC_C_O

CFLAGS="$CFLAGS -w"

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40.0
GTK_REQUIRED=3.20
AC_SUBST([GLIB_REQUIRED])

PKG_CHECK_MODULES(valhalla_U, [
  glib-2.0 >= $GLIB_REQUIRED
  gobject-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED
  gio-unix-2.0 >= $GLIB_REQUIRED
  gtk+-3.0 >= $GTK_REQUIRED
  gnome-desktop-3.0
  gmodule-2.0
  gee-0.8
  sqlite3
  zlib
  libsoup-2.4
  libnautilus-extension
])

AC_SUBST([valhalla_U_VALAFLAGS], ["--vapidir=\$(top_srcdir)/vapi \
          --target-glib=$GLIB_REQUIRED \
          --fatal-warnings \
          --enable-experimental-non-null"])

AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)

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
valhalla.spec
libgd/Makefile
data/Makefile
src/Makefile
src/libvalhalla/Makefile
src/modules/Makefile
src/valhalla/Makefile
])
AC_OUTPUT

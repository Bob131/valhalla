Valhalla
===

Valhalla is a utility that makes it super easy to share files and screenshots
over the web. This is achieved through the following features:

* Valhalla is easily extensible to support your favourite services
* Keeps track of all your files
* Convenient screenshot binary: Just map your printscreen key to
  `valhalla-screenshot` and we'll do the rest
* Neat and tidy UI

## Getting started

On RHEL-like systems:

```
dnf copr enable bob131/valhalla
dnf install valhalla
```

## Compiling

```
hub clone Bob131/valhalla
./autogen.sh
make
```

### I just compiled from source, but when I run valhalla it complains of missing modules

Try making a symbolic link from the build folder to your `XDG_DATA_HOME`:

```
ln -s `pwd`/src/modules/.libs ~/.local/share/valhalla
```

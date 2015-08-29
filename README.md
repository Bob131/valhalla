valhalla
===

Valhalla is a vaguely cross-platform (should work on most unices... maybe) CLI
tool for sharing or archiving files.

Features:
* Scriptable, will read input from stdin and write only program-parsable output
  to stdout
* Flexible: configurably takes care of automatically mounting and unmounting
  filesystems to copy to. Use this with a FUSE FS like sshfs or ftpfs to make
  your files accessible to the world!
* Configurable: Most facets of valhalla's operation are configurable to suit
  individual needs.

## Getting started

On RHEL-like systems:

```
dnf copr enable bob131/valhalla
dnf install valhalla
```

Then setup:
```
mkdir -p ~/.config/valhalla
cat > ~/.config/valhalla/valhalla.conf <<EOF
[main]
serve-url = "http://files.example.com"
mount-command = "sshfs example.com:/var/www/files \\$f"
EOF
```
For more config options see data/so.bob131.valhalla.gschema.xml

## Compiling

```
hub clone Bob131/valhalla
./autogen.sh
make
```

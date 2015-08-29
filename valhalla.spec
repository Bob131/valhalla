%global shortcommit %(c=%{commit}; echo ${c:0:7})

Name:		valhalla
Version:	0
Release:	%{date}git%{shortcommit}%{?dist}
Summary:	Command line file upload manager

Group:		Applications/Internet
License:	GPLv3
URL:		https://github.com/Bob131/valhalla
Source0:	%{url}/archive/%{commit}.zip

BuildRequires:	vala vala-tools readline-devel gtk3-devel sqlite-devel file-devel
Requires:       readline gtk3 sqlite file-libs

%description
Command line utility for sharing files


%prep
%autosetup -n %{name}-%{commit}

%build
NOCONFIGURE=1 ./autogen.sh
%configure
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot}

%files
%{_datadir}/glib-2.0/schemas/so.bob131.valhalla.gschema.xml
%{_bindir}/*

%post
/sbin/ldconfig

%postun
/sbin/ldconfig

%posttrans
/usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas > /dev/null 2>&1

%global shortcommit %(c=%{commit}; echo ${c:0:7})

Name:		valhalla
Version:	0
Release:	%{date}git%{shortcommit}%{?dist}
Summary:	Command line file upload manager

Group:		Applications/Internet
License:	GPLv3
URL:		https://github.com/Bob131/valhalla
Source0:	%{url}/archive/%{commit}.zip

BuildRequires:	vala vala-tools gtk3-devel libgee-devel sqlite-devel libnotify-devel zlib-devel libsoup-devel

%description
Utility for sharing files


%prep
%autosetup -n %{name}-%{commit}

%build
NOCONFIGURE=1 ./autogen.sh
%configure
make

%install
make install DESTDIR=%{buildroot}
libtool --finish %{buildroot}%{_libdir}/valhalla

%files
%{_bindir}/*
%{_datadir}/*
%{_libdir}/*
%exclude %{_libdir}/*.a
%exclude %{_libdir}/%{name}/*.la

%post
/sbin/ldconfig

%postun
/sbin/ldconfig

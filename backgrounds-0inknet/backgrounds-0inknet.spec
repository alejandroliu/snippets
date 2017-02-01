Summary: 0INK.NET Desktop backgrounds.
Name: backgrounds-0inknet
Version: 1.1
Release: 1
License: None
Group: Applications/Multimedia
Source0: backgrounds-0inknet.xml
Source1: pearls_pat.png
Source2: pearls_pat_mod.png
BuildRoot: %{_tmppath}/%{name}-%{version}-root
BuildArch: noarch


%description
This package contains additional artwork intended 
to be used as desktop wallpaper.

%prep


%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT%{_datadir}/gnome-background-properties
mkdir -p $RPM_BUILD_ROOT%{_datadir}/backgrounds/tiles


cp -a %{SOURCE0} $RPM_BUILD_ROOT%{_datadir}/gnome-background-properties
cp -a %{SOURCE1} $RPM_BUILD_ROOT%{_datadir}/backgrounds/tiles
cp -a %{SOURCE2} $RPM_BUILD_ROOT%{_datadir}/backgrounds/tiles


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%{_datadir}/backgrounds/tiles/*
%{_datadir}/gnome-background-properties/*


%changelog
* Sun Aug  9 2009 Alejandro Liu Ly <alex@chengdu.0ink.net> - 1.1-1
- Added a new background

* Tue Nov 06 2007 Alejandro Liu <alejandro_liu@hotmail.com> - 1.0-1
- First attempt

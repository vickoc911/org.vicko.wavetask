%undefine _cmake_in_source_build

Name:           wavetask
Version:        6.6.0
Release:        8%{?dist}
Summary:        Reusable Qt6 QML Task Manager Plugin for Plasma 6

License:        GPL-3.0-only
URL:            https://github.com/vickoc911/org.vicko.wavetask
Source0:        %{url}/archive/refs/heads/main.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  fdupes
BuildRequires:  cmake

BuildRequires:  extra-cmake-modules

BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  qt6-qtdeclarative-devel

BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kservice-devel
BuildRequires:  kf6-kwindowsystem-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-kconfigwidgets-devel
BuildRequires:  kf6-knotifications-devel
BuildRequires:  kf6-kio-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-kitemmodels-devel

BuildRequires:  libplasma-devel
BuildRequires:  plasma-activities-devel
BuildRequires:  plasma-activities-stats-devel
BuildRequires:  plasma-workspace-devel

BuildRequires:  libksysguard-devel
BuildRequires:  kwin-devel
BuildRequires:  libepoxy-devel
BuildRequires:  libdrm-devel

BuildRequires:  cmake(LibTaskManager)
BuildRequires:  cmake(LibNotificationManager)

Provides:       qt6qmlimport(org.vicko.wavetask.1) = %{version}
Provides:       qt6qmlimport(org.vicko.wavetask) = %{version}

%description
Plasmoid wavetask Qt6 QML Task Manager plugin for Plasma 6 environments with zoom.

%prep
%autosetup -p1 -n org.vicko.wavetask-main

%build
export CXXFLAGS="%{optflags} -I%{_vpath_builddir}/plugin"

%cmake \
  -DBUILD_TESTING=OFF \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON

%cmake_build

%install
%cmake_install
%fdupes %{buildroot}

%files
%dir %{_libdir}/qt6/qml/org/vicko
%{_libdir}/qt6/qml/org/vicko/wavetask/

%{_datadir}/plasma/plasmoids/org.vicko.wavetask/

%dir %{_datadir}/plasma/layout-templates
%{_datadir}/plasma/layout-templates/org.vicko.wavetask.panel/

%changelog
* Wed Mar 11 2026 Victor Calles - 6.6.0-1
- Initial COPR build

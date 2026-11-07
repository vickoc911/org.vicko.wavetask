# Building and installing WaveTask

This guide covers building from source on KDE Plasma 6 systems. The package
commands below cover Kubuntu/Ubuntu and Fedora. The installed Plasma version
and development libraries must be compatible.

[CHANGELOG.md](CHANGELOG.md) records changes in two sections: a one-line summary
per change and feature details with commit references.

## Kubuntu and Ubuntu

Install the build tools and development dependencies:

```sh
sudo apt update
sudo apt install build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  qml6-module-qtquick-dialogs \
  libkf6coreaddons-dev libkf6i18n-dev libkf6service-dev \
  libkf6windowsystem-dev libkf6config-dev libkf6configwidgets-dev \
  libkf6notifications-dev libkf6kio-dev libkf6bookmarks-dev \
  libkf6globalaccel-dev libkf6xmlgui-dev \
  libplasma-dev libplasmaactivities-dev libplasmaactivitiesstats-dev \
  libksysguard-dev kwin-dev plasma-workspace-dev
```

## Fedora

```sh
sudo dnf install gcc-c++ cmake extra-cmake-modules \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  kf6-kcoreaddons-devel kf6-ki18n-devel kf6-kservice-devel \
  kf6-kwindowsystem-devel kf6-kconfig-devel kf6-kconfigwidgets-devel \
  kf6-knotifications-devel kf6-kio-devel kf6-kglobalaccel-devel \
  kf6-kxmlgui-devel \
  libplasma-devel plasma-activities-devel plasma-activities-stats-devel \
  plasma-workspace-devel libksysguard-devel kwin-devel
```

## Clean and build

From the repository root, optionally remove the previous build directory to
start with a clean configuration. This command deletes only the local `build/`
directory:

```sh
rm -rf build
```

Configure and build in Release mode:

```sh
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
cmake --build build --parallel "$(nproc)"
```

Optionally run the QML lint target:

```sh
cmake --build build --target all_qmllint
```

This target checks only the generated C++/QML module, not the entire applet
interface. To test the editor, handle dragging, entry order, icon displacement
in both orientations, Cairo sizing, and existing widgets, enable and run tests:

```sh
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build --parallel "$(nproc)"
ctest --test-dir build --output-on-failure
```

Tests require Qt Test and Qt 6 `qmltestrunner`. On Kubuntu/Ubuntu, install
`qml6-module-qttest qt6-declarative-dev-tools`. CTest uses the freshly built
plugin and local test packages without requiring installation as root.
The launcher test uses a local file that runs only `/usr/bin/true`.

## Install

Install into the system paths configured by KDE:

```sh
sudo cmake --install build
```

This command also installs the internal `org.vicko.wavetask.widgets` containment,
retained for loading/removing previously embedded widgets. Do not copy only the
plugin library.

After installation, log out and back into the Plasma session to ensure the shell
loads the installed plugin version. Then add the WaveTask panel through Plasma
edit mode if needed. The README contains panel configuration instructions.

## Window filters: desktop, Activity, and monitor

Open **Configure WaveTask → Behavior → Show only tasks** and enable the desired
filters:

- **From the current desktop:** restrict windows to the current virtual desktop.
- **From the current activity:** restrict windows to the active KDE Activity.
- **From the current screen:** restrict windows to the monitor hosting this dock.
- **That are minimized:** restrict the list to minimized windows.

You can combine these options; windows must satisfy every enabled restriction.
Click **Apply** to save. Disable a checkbox to include windows beyond that scope.
For a dock on each monitor, enable **From the current screen** in each instance.
This setting refers to the dock's monitor, not the pointer's monitor.

These filters affect window tasks, not the saved pinned entries. Use **Entries**
to add, remove, or reorder launchers.

## Cairo size

In **Appearance**, **Cairo Penguin size (%)** adjusts Cairo from 25% to 300% while
it is enabled. The default of 100% preserves the previous size: two thirds of
the application icon size. Click **Apply** to save; the control is disabled while
Cairo is turned off.

For larger sizes, increase the panel height if the animation is clipped.
Cairo remains available only on horizontal docks.

## Entry editor: order, spacers, and separators

1. Open WaveTask configuration and select **Entries**, after **Appearance** and
   before **Behavior**. Existing pinned applications are automatically included.
2. Drag a row's visible handle to reorder it. Up/down buttons are also available.
   While dragging, a preview follows the pointer and a line highlights the
   insertion position.
3. Use **Spacer** for empty space or **Separator** for a subtle line. Adjust the
   reserved space from 1 to 256 pixels directly in the row.
4. Use **Manual entry** to enter a name, command, and icon (theme name or image
   path). Commands accept quoted arguments, but not shell operators, pipes, or
   substitutions. The edit button allows changing these values later.
5. Use **Import .desktop** to select one or more files, or drop `.desktop` files
   onto the list. Local paths containing spaces and Unicode are accepted; files
   do not need to be registered in the application catalogue.
6. The trash button removes an entry. Click **Apply** to save.
   Cancelling configuration leaves the dock unchanged.

You can still drag `.desktop` files directly onto the active dock to pin
applications without opening configuration. With a saved layout, new entries
appear at the end of the list and can be reordered in the editor. Only drops
for embedding Plasma widgets have been disabled.

The editor's saved order takes precedence over Behavior sorting and direct
task-button dragging. Unpinned windows appear after the configured entries.
Spacers and separators reserve horizontal/vertical space, including during
zoom, without creating Plasma widgets.

Manual entries are independent launch buttons. For normal window integration,
grouping, and application menus, prefer `.desktop` files.

### Display and legacy launcher data

Launcher rows display the name (or generic description/comment) above a smaller,
italic local `.desktop` path. Click the path to reveal the file in the default
file manager; KIO falls back to opening the parent directory when the standard
`org.freedesktop.FileManager1` interface is unavailable. Path escapes are visual
only. Commands appear below manual entry names; spacers and separators show only
their type. The list adapts to the configuration window's height.

Opening **Entries** refreshes every `.desktop` metadata copy in memory, including
existing entries. The display cache is not written to `entryLayout`.
Activity-prefixed values (`[activity-id]\nfile:///...`) are decoded for metadata
lookup and folder opening without removing their saved activity association.
Both real newlines and literal `\n` separators are supported. Empty launcher values
are ignored; `preferred://...` entries are preserved without file metadata errors.

### Technical information and configuration locations

Open **Under the hood (no magic)** for selectable diagnostic information and
configuration paths. The page reports the operating system, kernel, architecture,
Qt version, display platform, and logging category `org.vicko.wavetask`.
It contains technical information only; author/contributor credits remain in the
package metadata.

The usual locations are:

- `~/.config/plasma-org.kde.plasma.desktop-appletsrc`: dock configuration, in
  `[Containments][<containment-id>][Applets][<applet-id>][Configuration][General]`.
  Find the applet whose `plugin` is `org.vicko.wavetask`; `launchers` contains
  pinned launcher values and `entryLayout` contains the ordered JSON layout.
- `~/.config/plasmashellrc`: Plasma shell configuration.
- `~/.local/share/plasma/plasmoids/org.vicko.wavetask`: user-installed applet
  package, if present. System-wide installations may not have this directory.

The actual paths follow `XDG_CONFIG_HOME` and `XDG_DATA_HOME` through Qt's standard
path APIs. Review local paths before sharing diagnostics. Back up configuration
before editing it, and do not edit it while Plasma is running because the shell
may overwrite your changes. After installing a rebuilt backend, log out and back
in so Plasma loads the new native plugin, rather than only reopening configuration.

## Remove existing widgets

Widget addition menus and embedding drops have been removed, along with the
**Manage embedded widgets...** menu. Existing widgets are not deleted.
To remove one, unlock widgets in Plasma edit mode and right-click the widget
itself, then select **Remove widget**.

## Troubleshooting configuration

If CMake cannot find a library, check that the development packages match the
installed Plasma version. To reconfigure from scratch, remove `build/` and repeat
the build commands above.

Local `.desktop` launchers may reside outside `~/.local/share/applications/`;
the dock reads the file directly. KIO still checks launcher trust and permissions.
Only for files you know and trust, mark the file executable in the file
manager's properties dialog.

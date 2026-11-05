# Changelog

Recent improvements from 2026-11-05. This document does not replace the complete
Git history or assign a new project version.

## 1. Change summary

- Added an entry editor with launchers, manual commands, spacers, and separators.
- Added reordering with visible drag handles, a floating preview, and an insertion marker.
- Ordered the configuration tabs as Appearance, Entries, and Behavior.
- Added multiple `.desktop` file imports and file drops in the editor.
- Preserved `.desktop` drops onto the active dock, prioritizing URLs over widget metadata.
- Fixed launching local `.desktop` files outside the catalogue, including paths with spaces and Unicode.
- Added Cairo Penguin sizing from 25% to 300%, with a default of 100%.
- Removed widget addition/management menus and support for adding new widgets to the dock.
- Preserved loading and removal through each widget's own menu for existing instances.
- Fixed badge and virtual desktop filtering compatibility across Plasma APIs.
- Added tests for the interface, layout, persistence, launching, and Cairo sizing.
- Documented dependencies, cleanup, builds, installation, and the new configuration options.

## 2. Feature details and commits

### Changeset reference

The functional changes above were collected in commit
[`06fae31` — Add WidgetHost and associated tests for WaveTask](https://github.com/vickoc911/org.vicko.wavetask/commit/06fae313c340783a891d419ca2bbf0315424fbde).
Although its title highlights WidgetHost, the diff also includes the entry editor,
drag feedback, launcher fixes, Cairo sizing, and initial documentation.
There are no separate commits for each feature in this changeset.

### Entry editor and visual feedback

- Added the **Entries** tab between **Appearance** and **Behavior**.
- Existing pinned applications are automatically included in the list.
- Drag handles with hand cursors allow reordering; up/down buttons provide an
  alternative.
- While dragging, the original row is dimmed, a preview follows the pointer, and
  a colored line indicates the insertion position.
- The order changes on release; the editor also scrolls automatically at the edges.
- Spacers reserve empty space; separators draw a subtle line. Both support sizes
  from 1 to 256 pixels.
- Manual commands have configurable names, commands, and icons, with subsequent
  editing and removal. Quoted arguments are accepted; shell operators and
  substitutions are not interpreted.
- **Apply** saves the configuration. Cancelling configuration leaves the dock unchanged.
- The saved layout takes precedence over Behavior sorting and direct task-button
  dragging. Unpinned windows appear after the configured entries.
- Manual entries are independent buttons; `.desktop` files remain the way to
  obtain normal window integration and grouping.

### `.desktop` files and the active dock

- The editor imports one or more files through the file picker or drops onto the list.
- Dropping directly onto the active dock still pins applications without opening
  configuration. New launchers appear at the end of the configured layout.
- Drags containing URLs are not rejected merely because they also advertise the
  Plasma widget format; URL drops are explicitly accepted.
- Local launchers are read directly with KService and launched through KIO,
  without requiring registration in the application catalogue.
- Paths with spaces and Unicode are supported. KIO trust and permission checks
  remain in effect.

### Cairo Penguin size

- **Appearance → Cairo Penguin size (%)** allows sizing from 25% to 300%.
- The default of 100% preserves the previous size, equivalent to two thirds of
  the dock's application icon size.
- The control is enabled only while the Cairo Penguin is enabled.
- Sizing follows changes to the configuration and application icon size.
- Support remains limited to horizontal docks; larger sizes may require a taller
  panel to avoid clipping the animation.

### Transition from widgets to native entries

- Removed widget addition menus, the widget picker, and the
  **Manage embedded widgets...** menu.
- Disabled embedding new widgets by dropping them onto WaveTask.
- Preserved existing widgets, their configuration, and the internal containment
  for compatibility; these instances are not automatically deleted.
- In Plasma edit mode, each widget's own right-click menu still allows configuring,
  moving, or removing an existing instance.
- The editor's new spacers and separators are native dock items, not Plasma
  widgets, and participate in spacing and zoom calculations in both orientations.

### Compatibility, tests, and installation

- A local badge avoids depending on `Kirigami.Badge`, which is missing in some versions.
- Bindings select the available virtual desktop filtering properties; actions use
  the desktop API compatible with the installed version.
- Tests cover QML loading, entry order and persistence, drag handles, previews and
  insertion markers, save/cancel behavior, imports, manual commands, Cairo
  dimensions, and actual icon displacement in horizontal and vertical layouts.
- WidgetHost tests retain coverage for existing instances and containment
  restoration. Launch fixtures use `/usr/bin/true`.
- Installation still includes the compiled plugin and QML packages. Log out and
  back in to reload a library already loaded by `plasmashell`; WaveTask is not
  a standalone executable.
- The [installation guide](INSTALL.md) includes Kubuntu/Ubuntu and Fedora
  dependencies, cleanup, builds, optional tests, and installation.
  The [README](README.md) describes usage and limitations.

The build and all three CTest suites passed during implementation. Automated
tests do not replace full visual validation in the user's Plasma session.

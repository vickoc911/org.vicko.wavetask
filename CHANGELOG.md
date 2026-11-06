# Changelog

## 2026-11-06 — Entry display and technical diagnostics

- Added a separate display model with predefined main/secondary labels, icons,
  original launcher targets, and absolute local `.desktop` paths.
- Launcher rows prioritize name, generic description, and comment; manual commands
  appear below their names, while spacers/separators show only their type.
- Made the editor list adapt to available vertical space.
- Added smaller italic path links that reveal files via KIO and the standard
  Linux file-manager interface, with a parent-directory fallback.
- Escaped spaces and special characters for display without changing file targets.
- Refresh `.desktop` metadata in memory whenever Entries loads, independently of
  cached fields in old layouts; keep the display cache out of new layout saves.
- Normalized activity-prefixed launcher values for metadata and folder opening,
  preserving activity associations and avoiding duplicate imports. Support real
  newline and literal `\n` separators.
- Added support for raw absolute local paths containing spaces and Unicode.
- Preserve special `preferred://...` launchers, ignore empty launcher values, and
  surface metadata read errors for expected `.desktop` files.
- Added **Under the hood (no magic)** with copyable system/Qt diagnostics,
  logging category, XDG-aware configuration paths, and configuration editing warnings.
- Added Alan S. Ferreira to package credits, with GitHub and LinkedIn contacts in
  the README; kept the technical diagnostics page free of authorship information.
- Added regression coverage for activity prefixes, legacy metadata reloads,
  special/empty launchers, display labels and paths, resizing, and diagnostics.

## Earlier changes

Recent improvements from 2026-11-05. This document does not replace the complete
Git history or assign a new project version.

## 1. Change summary

- Documented existing window filters by current virtual desktop, KDE Activity, and dock monitor as core features.
- Documented combining window scope filters with the existing minimized-only option.
- Fixed virtual desktop filtering compatibility by selecting the supported Plasma API at runtime.
- Fixed badge compatibility where `Kirigami.Badge` is unavailable.
- Added an entry editor with launchers, manual commands, spacers, and separators.
- Added reordering with visible drag handles, a floating preview, and an insertion marker.
- Ordered the configuration tabs as Appearance, Entries, and Behavior.
- Added multiple `.desktop` file imports and file drops in the editor.
- Preserved `.desktop` drops onto the active dock, prioritizing URLs over widget metadata.
- Fixed launching local `.desktop` files outside the catalogue, including paths with spaces and Unicode.
- Added Cairo Penguin sizing from 25% to 300%, with a default of 100%.
- Removed widget addition/management menus and support for adding new widgets to the dock.
- Preserved loading and removal through each widget's own menu for existing instances.
- Added tests for the interface, layout, persistence, launching, and Cairo sizing.
- Documented dependencies, cleanup, builds, installation, and the new configuration options.

## 2. Feature details and commits

### Changeset reference

The recent functional changes above were collected in commit
[`06fae31` — Add WidgetHost and associated tests for WaveTask](https://github.com/vickoc911/org.vicko.wavetask/commit/06fae313c340783a891d419ca2bbf0315424fbde).
Although its title highlights WidgetHost, the diff also includes the entry editor,
drag feedback, launcher fixes, Cairo sizing, and initial documentation.
There are no separate commits for each feature in this changeset.
Window filters by desktop, Activity, screen, and minimized state already existed
before this commit. The recent changes fix desktop API compatibility and expand
their documentation; they do not introduce these filters for the first time.

### Window filtering by desktop, Activity, and monitor

- **Behavior → Show only tasks** exposes independent restrictions for the current
  virtual desktop, active KDE Activity, and the monitor hosting the dock.
- The screen filter follows the dock's containment screen geometry, not the
  pointer location; separate dock instances can filter their own monitors.
- The Activity filter follows the active KDE Activity.
- Restrictions can be combined, and the minimized-only option can narrow the
  results further. Disabling an option removes that restriction.
- Filtering affects window tasks without removing saved pinned launchers.
- The desktop compatibility fix in `06fae31` selects
  `filterByCurrentVirtualDesktop` when available or `filterByVirtualDesktop`
  otherwise, supplying `virtualDesktop` for models that expose it.
- Desktop actions also support the legacy current-desktop property and newer
  screen-geometry-based desktop lookup.
- These are existing core task-manager features; the documentation now makes
  their configuration and scope explicit in the README and installation guide.

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

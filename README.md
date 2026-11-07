# org.vicko.wavetask

KDE Plasma 6 task manager with macOS-style dock zoom animation, smart launcher badges, and advanced window management features. It's based on the default task manager of KDE.

Since Plasma 6.6 does not allow direct access to org.kde.plasma.private.taskmanager, the plugin has had to be compiled, so the installation is no longer just a matter of copying but requires compilation.

![wavetask](screenshot/wavetask_1280_2.webp?raw=true "wavetask")

## Technical information

The **Under the hood (no magic)** configuration page includes operating system,
kernel, architecture,
Qt version, display platform, and logging category information, together with the
Plasma configuration and user package locations. Paths follow the user's XDG
configuration and data directories. Review local paths before sharing diagnostics.

Dock entries are stored in `plasma-org.kde.plasma.desktop-appletsrc`, under the
WaveTask applet's `Configuration/General` group (`launchers` and `entryLayout`).
Desktop metadata is refreshed in memory when the Entries page loads. Do not edit
Plasma configuration files while Plasma is running, as changes may be overwritten.

Contributor: **Alan S. Ferreira** —
[GitHub](https://github.com/alansferreira) ·
[LinkedIn](https://www.linkedin.com/in/alansferreira/).

## Support for previous Plasma releases

Currently supported versions: 6.6, 6.7

If you need to install it on Plasma 6.5 or lower, I recommend you do it from here: https://github.com/vickoc911/org.kde.plasma.wavetask

## Packages

<details>
  <summary>openSUSE Tumbleweed (maintained by me)</summary>
  <br>
  
  ```sh
  sudo zypper ar https://download.opensuse.org/repositories/home:/vcalles/openSUSE_Tumbleweed/home:vcalles.repo
  sudo zypper refresh
  sudo zypper install wavetask
  ```
</details>
<details>
  <summary>Fedora 44, 43 (copr) (maintained by me)</summary>
  <br>
  
  ```sh
  sudo dnf copr enable vcalles/wavetask 
  sudo dnf install wavetask
  ```
</details>
<details>
  <summary>Arch Linux (AUR) (maintained by https://aur.archlinux.org/account/ioplus)</summary>
  <br>

Using an AUR helper (paru, yay, etc.):

```sh
yay -S wavetask      # stable release (recommended)
yay -S wavetask-git  # bleeding edge version
```

Manual installation:

```sh
# Replace 'wavetask' with 'wavetask-git' for the bleeding edge version
git clone https://aur.archlinux.org/wavetask.git
cd wavetask
makepkg -si
```

</details>
<details>
  <summary>kubuntu 25.10 ppa launchpad  (maintained by https://github.com/Matou1306)</summary>
  <br>
  
  ```sh
sudo add-apt-repository ppa:matou1306/wavetask
sudo apt update
sudo apt install wavetask
  ```
</details>

### after installing the package add the panel for wavetask

- Right-click on your desktop.
- select "Enter edit mode"
- Go to "Layout" tab
- Select "Panel for wavetask" from the dropdown
- Click "Apply"

### After adding the panel, make these modifications

- Adjust the width to "fit to content"
- Adjust alignment to "center"
- If you want to increase the size of the icons above 46px, you need to increase the height of the panel so that the zoom is not cut off.

## Compile from source

See [INSTALL.md](INSTALL.md) for dependency installation, clean build, and
installation commands for Kubuntu/Ubuntu and Fedora.

See [CHANGELOG.md](CHANGELOG.md) for a one-line summary of each recent change,
followed by feature details and the corresponding commits.

## Global keyboard shortcuts

Wave Task Manager registers its shortcuts under the **Wave Task Manager** group to prevent conflicts with Plasma's built-in task manager.
On Plasma 6.8, task-switching shortcuts are handled directly inside the task manager backend rather than the central desktop shell.

After installing the compiled plugin, log out and back in so Plasma loads the new binary:

1. Open **System Settings → Keyboard → Shortcuts** and select **Wave Task Manager**.
2. Assign **Meta+1** through **Meta+9** to **Activate Task Manager Entry 1** through **Activate Task Manager Entry 9**.
3. Assign **Meta+0** to **Activate Task Manager Entry 10** if desired.
4. When prompted that the shortcut conflicts with **plasmashell**, confirm reassigning it to Wave Task Manager, then apply the changes.

Task cycling and moving shortcuts are also available under the **Wave Task Manager** group.

## Features:

- Window filtering by current virtual desktop, KDE Activity, and dock monitor
- Optional minimized-only filtering, combinable with desktop, Activity, and monitor filters
- Entry editor with drag handles, launchers, manual commands, spacers and separators
- It inherits all the features of Plasma's task manager
- Zoom like in macOS
- Icon reflection
- Bouncing icons ( only in landscape mode )
- Basic skin system
- Option to select the icon size
- Option to select the zoom size
- Option to select the amplitude
- Option to disable icon reflection
- blur for default and custom skins
- Cairo Penguin with configurable size (horizontal docks only)

## Window filtering

Open **Configure WaveTask → Behavior → Show only tasks** to choose which windows
appear in each WaveTask instance:

- **From the current desktop:** show windows belonging to the current virtual desktop.
- **From the current activity:** show windows belonging to the active KDE Activity.
- **From the current screen:** show windows on the monitor containing this dock,
  not whichever monitor currently contains the pointer.
- **That are minimized:** show only minimized windows.

The options are independent and can be combined. For example, enabling desktop,
Activity, and screen filtering limits the window list to those matching all three.
Disabling a filter removes that restriction. Pinned application launchers remain
configured separately in **Entries**; these options filter window tasks rather
than deleting pinned entries.

Desktop filtering selects the API supported by the installed Plasma version.
See the [changelog](CHANGELOG.md) for the distinction between existing filtering
features and the recent desktop API compatibility fix.

## Entry editor

Open **Configure WaveTask → Entries**. Existing pinned applications are included
automatically. The tabs are ordered **Appearance → Entries → Behavior**.
The technical information tab, **Under the hood (no magic)**, follows **Behavior**.
Drag the visible handles to reorder entries: a floating preview follows the
pointer and a highlighted line marks the drop position. The up/down buttons
provide an alternative. The list accepts:

- **Spacers:** empty space with an adjustable size (1–256 pixels).
- **Separators:** a subtle line with an adjustable reserved width/height.
- **Manual entries:** a name, executable with arguments, and icon name or path.
- **.desktop launchers:** import one or more files using the file picker or drop
  them onto the list, including local files outside the application catalogue.

Manual commands accept quoted arguments, not shell operators or substitutions.
They are independent launch buttons; use a `.desktop` launcher for normal task
and window integration. Use the edit/remove buttons to change manual entries or
delete entries, and **Apply** to save. Cancelling configuration leaves the dock
unchanged.

Launcher rows show the application name, falling back to its generic description,
comment, and finally its URI. The second line shows the absolute local `.desktop`
path in smaller italic text. Clicking it reveals the file in the default file
manager using `org.freedesktop.FileManager1`; when unsupported, KIO opens the
parent directory instead. No particular Linux distribution or file manager is required.
Spaces and special characters are escaped for display only; the file path and
opening target are not changed. Manual entries show their command below the name;
spacers and separators show only their type, with a separate size control.
The list grows and shrinks with the available window height and scrolls as needed.

All `.desktop` metadata is re-read into a separate in-memory display model when
the Entries page loads. Saved metadata from older layouts does not override the
file's current values, and new layout saves do not include this display cache.
Activity-qualified launcher values such as `[activity-id]\nfile:///...` are
normalized for metadata lookup and folder opening, while their original activity
association is preserved when saving. Both actual newlines and literal `\n`
sequences are recognized. Empty launcher values are ignored, and special URLs
such as `preferred://browser` remain valid without requiring `.desktop` metadata.
Failures to read an expected `.desktop` file are reported in the configuration page.

Once an entry layout is saved, it determines the pinned entries' visual order
instead of the Behavior sorting option or direct task-button dragging. Unpinned
windows follow the configured entries. Spacers and separators reserve space in
both orientations and during zoom; they are not Plasma widgets.

Dragging `.desktop` files directly onto the active dock is still supported.
New launchers are appended to the configured entries and can then be reordered
in the editor. Only Plasma widget embedding drops are disabled; URL drops take
priority even when a drag also advertises widget metadata.

## Cairo Penguin size

Open **Configure WaveTask → Appearance**, enable **Show Cairo Penguin**, and
adjust **Cairo Penguin size (%)** from **25% to 300%**, then click **Apply**.
The default **100%** preserves the previous size: two thirds of the application
icon size. The control is disabled while the penguin is turned off.

The Cairo Penguin remains available only on horizontal docks. Larger sizes may
require increasing the panel height to avoid clipping the animation.

## Previously embedded widgets

Widget-addition menus and widget drops into WaveTask have been removed.
Existing embedded widgets and their settings remain intact. The **Manage embedded
widgets...** menu has also been removed. In Plasma's edit mode, right-click an
existing embedded widget to configure or remove it. The internal containment
package remains installed for this backward compatibility.

Skins:

- Default Plasma: draw the plasma theme
- Big Sur Light
- Big Sur Night
- IVORY glass
- No background
- Vidrio
- Tahoe
- Tahoe Dark
- coffee
- Pine
- Elegantia

What doesn't work:

- The panel has been resized to 86 pixels so that icons aren't cut off when zooming

### ☕ Buy Me a Coffee!

If this code helped you, your support allows me to continue maintenance.

[![Donate with PayPal button](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?business=XSHX7RDT74QN2&no_recurring=0&item_name=Support+my+code%3A+If+it+saved+you+time+or+helped%2C+please+consider+donating.+Your+support+keeps+this+Open+Source+project+alive%21&currency_code=USD)

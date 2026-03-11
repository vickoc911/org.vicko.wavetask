Great 👍 — improving the README is actually **one of the best first contributions**. Maintainers love when someone:

* fixes build instructions
* documents dependencies
* improves clarity

I rewrote the README so it reflects **what we discovered while building it**, especially for **Fedora Linux** and **KDE Plasma** 6.

You can submit this as a **README improvement PR** on **GitHub**.

---

# Improved README

````markdown
# org.kde.plasma.wavetask

Task manager with macOS-style zoom for KDE Plasma.

This widget is based on the default task manager introduced in Plasma 6.6 and provides a dock-like experience similar to macOS.

Because Plasma 6 no longer exposes the task manager library directly, the plugin must be compiled instead of simply copied into the widgets directory.

---

# Supported Plasma Versions

Currently tested with:

- Plasma 6.6+
- Qt 6
- KDE Frameworks 6

Older Plasma versions may require using the legacy repository:

https://github.com/vickoc911/org.kde.plasma.wavetask

---

# Features

- macOS-style zoom animation
- Icon reflection effect
- Configurable icon size
- Configurable zoom factor
- Basic skin system

---

# Current Limitations

- Only works correctly when the panel is placed at the **bottom of the screen**
- The panel height must be around **76px** so icons are not clipped during zoom

---

# Installation

Since the widget needs to be compiled, installation requires building from source.

---

# Build Dependencies

### Fedora

Install the required packages:

```bash
sudo dnf install \
extra-cmake-modules \
qt6-qtbase-devel \
qt6-qtdeclarative-devel \
kf6-kcoreaddons-devel \
kf6-kconfig-devel \
kf6-kconfigwidgets-devel \
kf6-knotifications-devel \
kf6-kio-devel \
kf6-kitemmodels-devel \
libksysguard-devel \
gcc-c++ \
cmake
````

---

# Build Instructions

Clone the repository:

```bash
git clone https://github.com/<repo>/org.kde.plasma.wavetask.git
cd org.kde.plasma.wavetask
```

Create a build directory:

```bash
mkdir build
cd build
```

Configure the project:

```bash
cmake ..
```

Compile:

```bash
make
```

Install:

```bash
sudo make install
```

---

# Using the Widget

After installation:

1. Restart the Plasma shell:

```
kquitapp6 plasmashell
kstart6 plasmashell
```

2. Right-click the panel
3. Select **Add Widgets**
4. Search for **WaveTask**

Add it to the panel and adjust the settings as desired.

---

# Packages

### openSUSE Tumbleweed

```bash
sudo zypper ar https://download.opensuse.org/repositories/home:/vcalles/openSUSE_Tumbleweed/home:vcalles.repo
sudo zypper refresh
sudo zypper install wavetask
```

---

# Screenshot

![wavetask](screenshot/wavetask_1280.webp?raw=true)

---

# Support the Developer

If this project helped you, consider supporting the original developer.

[Donate via PayPal](https://www.paypal.com/donate/?business=XSHX7RDT74QN2)

Your support helps keep this project maintained.

```

---

# What your PR should say

Title:

```

Improve README and add Fedora build instructions

```

Description:

```

This improves the README by:

* adding build instructions
* documenting Fedora dependencies
* clarifying Plasma 6 build requirements
* cleaning duplicate sections

These instructions were tested on Fedora with KDE Plasma 6.

```

---

# Small but important thing

You should **keep the donation section**, because it respects the original author.

---

✅ If you want, I can also help you make **one more VERY good improvement** before submitting the PR:

- fix the **duplicate openSUSE section**
- add **Arch Linux instructions**
- add **automatic install script**

These kinds of changes make maintainers **much more likely to merge your PR**.
```

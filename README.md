# org.kde.plasma.wavetask
KDE Plasma 6 task manager with macOS-style dock zoom animation, smart launcher badges, and advanced window management features. It's based on the default task manager of KDE 6.6.

Since Plasma 6.6 does not allow direct access to org.kde.plasma.private.taskmanager, the plugin has had to be compiled, so the installation is no longer just a matter of copying but requires compilation.

![wavetask](screenshot/wavetask_1280_1.webp?raw=true "wavetask")

## Support for previous Plasma releases

Currently supported versions: 6.6.

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
  <summary>Fedora 43, 42 (copr) (maintained by me)</summary>
  <br>
  
  ```sh
  sudo dnf copr enable vcalles/wavetask 
  sudo dnf install wavetask
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

- Install the development packages.
- Download the code from GitHub.

mkdir build && cd build

cmake .. -DCMAKE_BUILD_TYPE=Release

make -j$(nproc)

sudo make install

## Features:

- It inherits all the features of Plasma's task manager
- Zoom like in macOS
- Icon reflection
- Bouncing icons
- Basic skin system
- Option to select the icon size
- Option to select the zoom size
- Option to select the amplitude
- Option to disable icon reflection
- blur for default and custom skins

Skins:

- Default: draw the plasma theme
- Big Sur Light
- Big Sur Night
- IVORY glass
- No background
- Vidrio
- Tahoe
- Tahoe Dark
- coffee

What doesn't work:
- For now, it only works in the bottom position
- The panel has been resized to 76 pixels so that icons aren't cut off when zooming

### ☕ Buy Me a Coffee!

If this code helped you, your support allows me to continue maintenance.

[![Donate with PayPal button](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?business=XSHX7RDT74QN2&no_recurring=0&item_name=Support+my+code%3A+If+it+saved+you+time+or+helped%2C+please+consider+donating.+Your+support+keeps+this+Open+Source+project+alive%21&currency_code=USD)


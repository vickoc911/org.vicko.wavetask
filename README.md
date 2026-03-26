# org.kde.plasma.wavetask
KDE Plasma 6 task manager with macOS-style dock zoom animation, smart launcher badges, and advanced window management features. It's based on the default task manager of KDE 6.6.

![wavetask](screenshot/wavetask_1280_1.webp?raw=true "wavetask")

## Support for previous Plasma releases

Currently supported versions: 6.6.

If you need to install it on Plasma 6.5 or lower, I recommend you do it from here: https://github.com/vickoc911/org.kde.plasma.wavetask

## Packages

<details>
  <summary>openSUSE Tumbleweed</summary>
  <br>
  
  ```sh
  sudo zypper ar https://download.opensuse.org/repositories/home:/vcalles/openSUSE_Tumbleweed/home:vcalles.repo
  sudo zypper refresh
  sudo zypper install wavetask
  ```
</details>
<details>
  <summary>Fedora 43, 42 (copr)</summary>
  <br>
  
  ```sh
  sudo dnf copr enable vcalles/wavetask 
  sudo dnf install wavetask
  ```
</details>

After installing the package, you just need to add the panel for wavetask

## Features:

- It inherits all the features of Plasma's task manager
- Zoom like in macOS
- Icon reflection
- Basic skin system
- Option to select the icon size
- Option to select the zoom size
- Option to select the amplitude
- Option to disable icon reflection

Skins:

- Default: draw the plasma theme
- Big Sur Light
- Big Sur Night
- IVORY glass
- No background
- Vidrio
- coffee

What doesn't work:
- For now, it only works in the bottom position
- The panel has been resized to 76 pixels so that icons aren't cut off when zooming

### ☕ Buy Me a Coffee!

If this code helped you, your support allows me to continue maintenance.

[![Donate with PayPal button](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?business=XSHX7RDT74QN2&no_recurring=0&item_name=Support+my+code%3A+If+it+saved+you+time+or+helped%2C+please+consider+donating.+Your+support+keeps+this+Open+Source+project+alive%21&currency_code=USD)


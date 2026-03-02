# org.kde.plasma.wavetask
Task manager with OSX-style zoom. It's based on the default task manager of KDE 6.6.
Since Plasma 6.6 does not allow direct access to the task manager library, the plugin has had to be compiled, so the installation is no longer just a matter of copying but requires compilation.

## Support for previous Plasma releases

Currently supported versions: 6.6
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

After installing the package, you just need to add the panel for wavetask

## Features:

- Zoom like in macOS
- Icon mirroring
- Basic skin system
- Option to select the icon size
- option to select the zoom size

What doesn't work:
- For now, it only works in the bottom position
- The panel has been resized to 76 pixels so that icons aren't cut off when zooming

### ☕ Buy Me a Coffee!

If this code helped you, your support allows me to continue maintenance.

[![Donate with PayPal button](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?business=XSHX7RDT74QN2&no_recurring=0&item_name=Support+my+code%3A+If+it+saved+you+time+or+helped%2C+please+consider+donating.+Your+support+keeps+this+Open+Source+project+alive%21&currency_code=USD)

![wavetask](screenshot/wavetask_1280.webp?raw=true "wavetask")

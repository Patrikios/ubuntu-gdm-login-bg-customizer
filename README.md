# Set Login Background & Ubuntu Logo (Ubuntu 24.04+)

Changing the Ubuntu login screen background on Ubuntu 24.04 is more annoying than it should be.  
GNOME no longer uses simple editable CSS files for the greeter — the theme is packed into a compiled `.gresource` file.

This script handles that properly without messy manual tweaks.

## What it does

- Sets a custom **GDM/login background**
- Optionally hides or restores the Ubuntu logo
- Slightly shrinks the login UI for a cleaner look
- Can also set your desktop wallpaper so the lock screen uses GNOME’s default blurred background
- Uses `update-alternatives` instead of overwriting stock files
- Safe to rerun and easy to revert

Tested on Ubuntu 24.04 (GNOME 46).

---

# Installation

Save the script:

```bash
nano ~/gdm-bg.sh
chmod +x ~/gdm-bg.sh
```

Install dependencies if needed:

```bash
sudo apt install libglib2.0-dev-bin
```

---

# Usage

## Set login background

```bash
sudo ~/gdm-bg.sh --login-image /absolute/path/image.png
sudo reboot
```

## Hide Ubuntu logo

```bash
sudo ~/gdm-bg.sh \
  --login-image /absolute/path/image.png \
  --hide-logo
```

## Set login background + wallpaper

This restores GNOME’s blurred lock screen behavior.

```bash
sudo ~/gdm-bg.sh \
  --login-image /absolute/path/login.png \
  --wallpaper /absolute/path/wallpaper.png
```

## Restore Ubuntu logo

```bash
sudo ~/gdm-bg.sh --show-logo
```

---

# Available options

| Option | Description |
|---|---|
| `--login-image` | Login screen background image |
| `--wallpaper` | Desktop wallpaper |
| `--hide-logo` | Hide Ubuntu logo |
| `--show-logo` | Show Ubuntu logo again |
| `--help` | Show help |

Use absolute file paths.

---

# How it works

The script:

1. Extracts the stock Yaru GDM theme
2. Injects a small custom `gdm.css`
3. Rebuilds the `.gresource`
4. Switches GDM to the custom theme using `update-alternatives`

The Ubuntu logo is controlled through a small `dconf` override.

No stock GNOME files are replaced.

---

# Files touched

## Theme resource

```bash
/usr/share/gnome-shell/theme/custom/custom.gresource
```

## Dconf override

```bash
/etc/dconf/db/gdm.d/00-logo-custom
```

## Transparent logo asset

```bash
/usr/share/pixmaps/gdm-transparent.png
```

---

# Rollback

Restore the default Ubuntu login theme:

```bash
sudo update-alternatives --set gdm-theme.gresource \
  /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
```

Restore Ubuntu logo:

```bash
sudo rm -f /etc/dconf/db/gdm.d/00-logo-custom
sudo dconf update
```

Reset wallpaper:

```bash
gsettings reset org.gnome.desktop.background picture-uri
gsettings reset org.gnome.desktop.screensaver picture-uri
```

---

# Troubleshooting

## Missing `gresource` tools

```bash
sudo apt install libglib2.0-dev-bin
```

## Wallpaper command fails from sudo

Run as your normal user:

```bash
gsettings set org.gnome.desktop.background picture-uri 'file:///path/image.png'
```

## Logo still visible

Restart GDM or reboot:

```bash
sudo systemctl restart gdm
```


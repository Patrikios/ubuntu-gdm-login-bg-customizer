# Set Login Background & Ubuntu Logo Control (Ubuntu 24.04+)

---

## 0) Why this effort?

Changing the **login background** on Ubuntu 24.04 sounds simple - until you try it.
GNOME settings don’t expose it, Gnome extensions I tried didn’t work for me, and it seems that the classic “edit a CSS file” trick no longer apply because the greeter loads assets from a **compiled theme resource** (`.gresource`).

**This project exists to make it painless and safe:**
- **One tiny script, one clear job:** set the login background image - no theming rabbit holes.
- **Reversible & idempotent:** switches via `update-alternatives`, never overwrites stock files, safe to rerun.
- **Branding control:** optionally hide or restore the Ubuntu logo with a clean `dconf` override.
- **Polished look by default:** compact ~0.75× UI (avatar + prompt) so the greeter feels tidy and modern.
- **Lock screen sanity:** optional wallpaper set restores GNOME’s default **blurred desktop** on the lock screen.
- **No fluff:** minimal dependencies, no permanent hacks, just a small compiled resource swap.

If you’ve tried extensions and settings and still can’t change the greeter, this is the pragmatic, low-risk path that actually works on Ubuntu 24.04+ (tested only on Ubuntu 24).

---

## 1) What this script does

- Sets the **login (GDM) background image**.
- Scales the **login UI to ~0.75×** (smaller user avatar and prompt field).
- **Optionally** hides or shows the **Ubuntu logo** on the greeter (`--hide-logo` / `--show-logo`).
- **Optionally** sets your **user’s desktop wallpaper**, which makes the **lock screen** return to GNOME’s standard **blurred desktop** background.
- **Idempotent**: safe to re-run; it overwrites the same resource and reuses the same update-alternatives entry - no profile pile-up.

> The script **does not** change the GNOME theme for your user session; it only rebuilds the **GDM** theme resource and optionally sets the **user wallpaper**.

---

## 2) Compatibility & prerequisites

- **Ubuntu 24.04 LTS** (GNOME 46) and later. (May work on newer Ubuntu releases that ship the Yaru theme in the same layout.)
- **Wayland** / **Xorg**: works on both (GDM is Wayland-by-default, but this is theme-level, not display-server-specific).
- **Privileges:** must run with `sudo` (root) to write to `/usr/share/gnome-shell` and set dconf overrides for GDM.
- **Dependencies:** The script installs/uses:
  - `libglib2.0-dev-bin` which provides `gresource` and `glib-compile-resources`
  - standard tools: `install`, `update-alternatives`, `mktemp`, `base64`

---

## 3) Files & system areas touched

- **Theme resource (compiled):**
  - `/usr/share/gnome-shell/theme/custom/custom.gresource` (created/overwritten)
  - `update-alternatives` entry: `gdm-theme.gresource` - points to the custom resource
- **Dconf overrides (logo control):**
  - `/etc/dconf/profile/gdm` (ensures the GDM profile exists)
  - `/etc/dconf/db/gdm.d/00-logo-custom` (logo setting)
  - `dconf update` (rebuilds the dconf databases)
- **Support asset:**
  - `/usr/share/pixmaps/gdm-transparent.png` (1×1 transparent PNG for hiding the logo)
- **User wallpaper (optional):**
  - Uses `gsettings` in the invoking **user session** to set `org.gnome.desktop.background picture-uri` and reset the screensaver image keys so the lock screen returns to blur.

> **No stock files are overwritten**: the script adds a **custom** resource and switches GDM to use it via `update-alternatives`. Revert is one command away.

---

## 4) Installation

1. Save the script:
   ```bash
   nano ~/gdm-bg.sh
   # paste the script contents, save (Ctrl+O, Enter), exit (Ctrl+X)
   chmod +x ~/gdm-bg.sh
   ```

2. (First run only) The script may install `libglib2.0-dev-bin` automatically.
   - No internet? Pre-install:
     ```bash
     sudo apt install libglib2.0-dev-bin
     ```

---

## 5) Usage (common recipes)

### A) Set **login screen only** (keep logo)
```bash
sudo ~/gdm-bg.sh --login-image /usr/share/backgrounds/your_login.png
sudo reboot
```

### B) Login screen **and hide the Ubuntu logo**
```bash
sudo ~/gdm-bg.sh --login-image /usr/share/backgrounds/your_login.png --hide-logo
sudo reboot
```

### C) Login screen + user **wallpaper** (lock screen = blurred desktop)
```bash
sudo ~/gdm-bg.sh --login-image /usr/share/backgrounds/your_login.png \
                 --wallpaper   /usr/share/backgrounds/your_wall.png
sudo reboot
```

### D) Show the Ubuntu logo again (keep your custom login background)
```bash
sudo ~/gdm-bg.sh --show-logo
sudo reboot
```

> **Paths must be absolute.** Prefer images that match your display aspect ratio (e.g., 2560×1440, 3840×2160).

---

## 6) Command-line options

| Option | Required | Argument | Purpose |
|---|---|---|---|
| `--login-image` | **Yes** | absolute path | Sets the background image for the **GDM login**. |
| `--wallpaper` | No | absolute path | Sets the **user desktop** wallpaper so the lock screen returns to **blurred desktop**. |
| `--hide-logo` | No | none | Hides the Ubuntu logo on the greeter (dconf override to a transparent PNG). |
| `--show-logo` | No | none | Removes the override so the Ubuntu logo is visible again. |
| `--help`, `-h` | No | none | Prints the script header/documentation block. |

> Use **either** `--hide-logo` **or** `--show-logo` in a single call (mutually exclusive).

---

## 7) How it works (under the hood)

### a) Rebuilding the **GDM theme resource**
- The stock Yaru resource at:
  - `/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource`
- The script **extracts** that resource into a temporary working directory and appends a small `gdm.css` with:
  - `#lockDialogGroup` background (your image)
  - UI scaling (`.login-dialog` font-size `0.75em`, avatar size ≈ `72px`, narrower prompt layout)
  - CSS fallback to hide the logo (authoritative control is done via dconf)
- The script **compiles** a new resource (`custom.gresource`) and installs it to:
  - `/usr/share/gnome-shell/theme/custom/custom.gresource`
- It uses `update-alternatives` to **switch** GDM to this resource under the logical name `gdm-theme.gresource`.

### b) Hiding/showing the **Ubuntu logo**
- The logo key is **`org.gnome.login-screen logo`** in GDM’s dconf database.
- The script ensures the **GDM dconf profile** exists (`/etc/dconf/profile/gdm`).
- To hide, it points `logo` to a **transparent 1×1 PNG** at `/usr/share/pixmaps/gdm-transparent.png`.
- To show, it removes the override file and runs `dconf update`.

### c) Lock screen → **blurred desktop**
- GNOME’s lock screen typically **blurs the desktop wallpaper** rather than using a separate image.
- With `--wallpaper`, the script sets your **user’s desktop wallpaper** via `gsettings` and **resets** any explicit lock-screen image keys, so GNOME returns to its **default blur** behavior.

---

## 8) Security model & safety

- Changes are **scoped** and **reversible**:
  - GDM theme switch via `update-alternatives` (no stock files overwritten)
  - Logo override is a single dconf file that can be deleted
  - User wallpaper is set via `gsettings` (user-level setting)
- The script runs with `sudo` and quotes parameters to minimize injection risk.
- Temporary directories are created with `mktemp -d` (randomized, race-safe).

---

## 9) Verification (did it take effect?)

### Active theme selection
```bash
sudo update-alternatives --display gdm-theme.gresource
# Expect: link currently points to /usr/share/gnome-shell/theme/custom/custom.gresource
```

### Resource contents
```bash
gresource list /usr/share/gnome-shell/theme/custom/custom.gresource | head
gresource extract /usr/share/gnome-shell/theme/custom/custom.gresource /org/gnome/shell/theme/gdm.css | sed -n '1,120p'
```

### Logo override
```bash
grep -n 'logo=' /etc/dconf/db/gdm.d/00-logo-custom || echo "No override file (logo shown)."
```

### User wallpaper / lock-screen
```bash
gsettings get org.gnome.desktop.background picture-uri
# lock-screen key usually empty (blur) unless set explicitly:
gsettings get org.gnome.desktop.screensaver picture-uri
```

---

## 10) Troubleshooting

**A. “No such key: picture-uri-dark”**
Some schemas (e.g., `org.gnome.desktop.screensaver`) don’t ship a `*-dark` key. Ignore this, the script already guards and resets only what exists.

**B. “Syntax error: else unexpected”**
Ensure you run via Unix line endings. If you copy-pasted on Windows, convert:
```bash
sed -i 's/\r$//' ~/gdm-bg.sh
```

**C. “Missing: gresource” or “glib-compile-resources”**
Install the tools:
```bash
sudo apt install libglib2.0-dev-bin
```

**D. “Could not reach user session bus” (wallpaper)**
Your user session DBus may be unavailable from the root shell. Set wallpaper as your user instead:
```bash
gsettings set org.gnome.desktop.background picture-uri 'file:///abs/path/wallpaper.png'
gsettings reset org.gnome.desktop.screensaver picture-uri
```

**E. Logo didn’t hide**
Restart GDM after `dconf update`:
```bash
sudo systemctl restart gdm
# or just reboot
```

---

## 11) Rollback & uninstall

**Revert to stock GDM theme:**
```bash
sudo update-alternatives --set gdm-theme.gresource \
  /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
sudo reboot
```

**Show the Ubuntu logo again:**
```bash
sudo rm -f /etc/dconf/db/gdm.d/00-logo-custom
sudo dconf update
sudo systemctl restart gdm
```

**Reset your wallpaper/lock-screen (as your user):**
```bash
gsettings reset org.gnome.desktop.background picture-uri
gsettings reset org.gnome.desktop.screensaver picture-uri
```

> After reverting, you can remove `/usr/share/gnome-shell/theme/custom/custom.gresource` if you want. It’s safe to leave in place.

---

## 12) Tips & customization

- **Image sizing**: use the same aspect ratio as your display. For multi-monitor rigs, consider a wide or center-friendly image.
- **Fine-tune scale**: edit the `gdm.css` block in the script: `.login-dialog { font-size: 0.8em; }` and avatar `icon-size` / `width` / `height`.
- **Prompt width**: adjust `.login-dialog-user-list-view` and `.login-dialog-prompt-layout` widths to taste.
- **Solid color**: you could swap the CSS background for a color only, e.g.:
  ```css
  #lockDialogGroup { background-color: #112233; }
  ```

---

## 13) FAQ

**Q: Will this survive updates?**
Yes. `update-alternatives` typically keeps your selection. If a major GNOME/Yaru update changes resource names, re-run the script.

**Q: Is it safe to run multiple times?**
Yes. The script is **idempotent**: it overwrites the same files and resets the same alternatives.

**Q: Can I use a different theme than Yaru?**
This script assumes Yaru is the stock GDM resource path. Porting to other themes requires pointing `THEME_SRC` to the correct resource.

**Q: Can I set a custom lock-screen image (not blurred)?**
GNOME 46+ generally prefers the blurred desktop for lock. Use a shell extension like “Lock screen background” if you need a truly independent lock image.

---

## 14) Appendix: Expected script header (for quick help)

Run:
```bash
sudo ./gdm-bg.sh --help
```
to view the inline usage block inside the script.

#!/bin/sh
# Ubuntu 24.04+ – Minimal GDM login background (+ optional logo & wallpaper)
# Does:
#   - set login (GDM) background image
#   - scale login UI to ~0.75x (smaller avatar + prompt field)
#   - optionally hide/show Ubuntu logo (--hide-logo / --show-logo)
#   - optionally set the user's desktop wallpaper so the lock screen returns to "blurred desktop"
#
# Usage:
#   sudo ./gdm-bg.sh --login-image /abs/path/login.png
#   sudo ./gdm-bg.sh --login-image /abs/path/login.png --hide-logo
#   sudo ./gdm-bg.sh --login-image /abs/path/login.png --wallpaper /abs/path/wall.png
#   sudo ./gdm-bg.sh --show-logo
#
# Idempotent: always overwrites the same resource and reuses the same update-alternatives target.

set -eu

# ---- constants ----
THEME_SRC="/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource"
ALT_NAME="gdm-theme.gresource"
ALT_PATH="/usr/share/gnome-shell/${ALT_NAME}"
TARGET_DIR="/usr/share/gnome-shell/theme/custom"
TARGET_RES="${TARGET_DIR}/custom.gresource"

GDM_DCONF_PROFILE="/etc/dconf/profile/gdm"
GDM_DCONF_DIR="/etc/dconf/db/gdm.d"
GDM_DCONF_FILE="${GDM_DCONF_DIR}/00-logo-custom"
GDM_DEFAULTS="/usr/share/gdm/greeter-dconf-defaults"
TRANSPARENT_PNG="/usr/share/pixmaps/gdm-transparent.png"

# ---- helpers ----
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
msg() { printf '%s\n' "$*" >&2; }
has_key() { gsettings list-keys "$1" 2>/dev/null | grep -qx "$2"; }

[ "$(id -u)" -eq 0 ] || { echo "Please run as root (sudo)." >&2; exit 1; }

# ensure tools
if ! command -v gresource >/dev/null 2>&1 || ! command -v glib-compile-resources >/dev/null 2>&1; then
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y libglib2.0-dev-bin >/dev/null
fi
need_cmd gresource
need_cmd glib-compile-resources
need_cmd update-alternatives
need_cmd install
need_cmd mktemp

# ---- args ----
LOGIN_IMG=""
WALLPAPER=""
HIDE_LOGO="no"
SHOW_LOGO="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --login-image) LOGIN_IMG="${2-}"; [ -z "$LOGIN_IMG" ] && { echo "Path missing for --login-image"; exit 1; }; shift 2 ;;
    --wallpaper)   WALLPAPER="${2-}";  [ -z "$WALLPAPER" ]  && { echo "Path missing for --wallpaper";   exit 1; }; shift 2 ;;
    --hide-logo)   HIDE_LOGO="yes"; shift ;;
    --show-logo)   SHOW_LOGO="yes"; shift ;;
    --help|-h)     sed -n '1,200p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[ -n "$LOGIN_IMG" ] || { echo "Required: --login-image /absolute/path/to/image" >&2; exit 1; }
[ -f "$LOGIN_IMG" ] || { echo "Login image not found: $LOGIN_IMG" >&2; exit 1; }
if [ -n "$WALLPAPER" ]; then
  [ -f "$WALLPAPER" ] || { echo "Wallpaper not found: $WALLPAPER" >&2; exit 1; }
fi
if [ "$HIDE_LOGO" = "yes" ] && [ "$SHOW_LOGO" = "yes" ]; then
  echo "Use only one: --hide-logo OR --show-logo." >&2
  exit 1
fi

# ---- build & apply GDM theme ----
WORKDIR="$(mktemp -d /tmp/gdm-bg.XXXXXX)"
mkdir -p "${WORKDIR}/Yaru" "${WORKDIR}/Yaru-dark" "${WORKDIR}/Yaru-light" \
         "${WORKDIR}/icons/scalable/actions" "${WORKDIR}/icons/scalable/status"

XML="${WORKDIR}/custom.gresource.xml"
cat > "${XML}" <<'EOX'
<?xml version="1.0" encoding="UTF-8"?>
<gresources>
  <gresource prefix="/org/gnome/shell/theme">
EOX

# extract stock Yaru into workdir and list in XML
gresource list "${THEME_SRC}" | while read -r res; do
  out="${WORKDIR}/${res#/org/gnome/shell/theme/}"
  mkdir -p "$(dirname "$out")"
  gresource extract "${THEME_SRC}" "${res}" > "${out}"
  printf '    <file>%s</file>\n' "${res#/org/gnome/shell/theme/}" >> "${XML}"
done

# our background image
FNAME="$(basename "$LOGIN_IMG")"
cp "$LOGIN_IMG" "${WORKDIR}/${FNAME}"
printf '    <file>%s</file>\n' "${FNAME}" >> "${XML}"

CSS="${WORKDIR}/gdm.css"
cat >> "${CSS}" <<EOF
/* Login background */
#lockDialogGroup {
  background: url('resource:///org/gnome/shell/theme/${FNAME}');
  background-repeat: no-repeat;
  background-size: cover;
  background-position: center;
}

/* ~0.75x UI scaling */
.login-dialog { font-size: 0.75em; }
.login-dialog-user-list-view { width: 18.75em; }  /* 25em * 0.75 */
.login-dialog-prompt-layout { width: 17.25em; }   /* ~23em * 0.75 */

/* avatar ~72px instead of ~96px */
.login-dialog .user-icon {
  icon-size: 72px;
  width: 72px;
  height: 72px;
}

/* slightly tighter entry field */
.login-dialog-prompt-entry {
  padding: 6px 10px;
  font-size: 0.95em;
}
EOF

# CSS fallback to hide logo (authoritative control is via dconf below)
if [ "$HIDE_LOGO" = "yes" ]; then
  cat >> "${CSS}" <<'EOF'
.login-dialog-logo {
  background-image: none;
  width: 0; height: 0;
  margin: 0; padding: 0; opacity: 0;
}
EOF
fi

# close XML
cat >> "${XML}" <<'EOY'
  </gresource>
</gresources>
EOY

# compile & install
(
  cd "${WORKDIR}"
  glib-compile-resources --target=custom.gresource --sourcedir="${WORKDIR}" custom.gresource.xml
)
install -d "${TARGET_DIR}"
install -m 0644 "${WORKDIR}/custom.gresource" "${TARGET_RES}"
update-alternatives --quiet --install "${ALT_PATH}" "${ALT_NAME}" "${TARGET_RES}" 0
update-alternatives --quiet --set "${ALT_NAME}" "${TARGET_RES}"

rm -rf "${WORKDIR}"
msg "GDM login background updated (incl. ~0.75x UI)."

# ---- optional: logo control via dconf (authoritative) ----
if [ "$HIDE_LOGO" = "yes" ]; then
  need_cmd base64
  install -d "$(dirname "$GDM_DCONF_PROFILE")" "$GDM_DCONF_DIR"
  printf "user-db:user\nsystem-db:gdm\nfile-db:%s\n" "$GDM_DEFAULTS" > "$GDM_DCONF_PROFILE"
  # 1x1 transparent PNG (if missing)
  if [ ! -f "$TRANSPARENT_PNG" ]; then
    base64 -d > "$TRANSPARENT_PNG" <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=
B64
    chmod 0644 "$TRANSPARENT_PNG"
  fi
  printf "[org/gnome/login-screen]\nlogo='%s'\n" "$TRANSPARENT_PNG" > "$GDM_DCONF_FILE"
  dconf update || true
  msg "Ubuntu logo hidden on the greeter."
elif [ "$SHOW_LOGO" = "yes" ]; then
  if [ -f "$GDM_DCONF_FILE" ]; then rm -f "$GDM_DCONF_FILE"; fi
  dconf update || true
  msg "Ubuntu logo shown on the greeter."
fi

# ---- optional: set user's wallpaper so lock screen uses blurred desktop again ----
if [ -n "$WALLPAPER" ]; then
  U="${SUDO_USER:-root}"
  UID_NUM="$(id -u "$U")"
  BUS="unix:path=/run/user/${UID_NUM}/bus"
  PIC_URI="file://${WALLPAPER}"

  if [ -S "/run/user/${UID_NUM}/bus" ] && command -v gsettings >/dev/null 2>&1; then
    su - "$U" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='${BUS}' gsettings set org.gnome.desktop.background picture-uri '${PIC_URI}'" || true
    if su - "$U" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='${BUS}' gsettings list-keys org.gnome.desktop.background | grep -qx picture-uri-dark"; then
      su - "$U" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='${BUS}' gsettings set org.gnome.desktop.background picture-uri-dark '${PIC_URI}'" || true
    fi
    # ensure lock screen returns to "blurred desktop" (reset any explicit image)
    su - "$U" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='${BUS}' gsettings reset org.gnome.desktop.screensaver picture-uri" || true
    if su - "$U" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='${BUS}' gsettings list-keys org.gnome.desktop.screensaver | grep -qx picture-uri-dark"; then
      su - "$U" -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS='${BUS}' gsettings reset org.gnome.desktop.screensaver picture-uri-dark" || true
    fi
    msg "Wallpaper set for user '${U}'. Lock screen will use blurred desktop wallpaper."
  else
    msg "Could not reach user session bus."
    msg "As your user, run:"
    msg "gsettings set org.gnome.desktop.background picture-uri 'file://${WALLPAPER}'"
    msg "gsettings reset org.gnome.desktop.screensaver picture-uri"
  fi
fi

msg "Done. Reboot to apply login-screen changes."


#!/usr/bin/env bash
# ubuntu-tahoe-theme-sync: keeps the Tahoe GTK, shell, libadwaita and icon themes in step with the
# GNOME light/dark style (Settings > Appearance, or the Dark Style quick toggle).
# Installed by Ubuntu Tahoe's appearance module and run as a systemd user service.
#   --once   apply the current style and exit
set -u
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ubuntu-tahoe"
CONF="$STATE_DIR/theme-sync.conf"
GTK4_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"
IFACE=org.gnome.desktop.interface

set_if_needed(){ # schema key value
  gsettings list-keys "$1" 2>/dev/null | grep -Fxq "$2" || return 0
  [[ "$(gsettings get "$1" "$2")" == "$3" ]] || gsettings set "$1" "$2" "$3"
}

link_gtk4(){ # theme directory containing gtk-4.0/
  local src="$1/gtk-4.0" item
  [[ -d "$src" ]] || return 0
  mkdir -p "$GTK4_DIR"
  for item in gtk.css gtk-dark.css assets windows-assets; do
    [[ -e "$src/$item" ]] || continue
    # Only replace links this tool created; never overwrite a user's own file.
    if [[ -e "$GTK4_DIR/$item" && ! -L "$GTK4_DIR/$item" ]]; then continue; fi
    [[ "$(readlink "$GTK4_DIR/$item" 2>/dev/null)" == "$src/$item" ]] || ln -sfn "$src/$item" "$GTK4_DIR/$item"
  done
}

flatpak_theme(){ # theme name; lets sandboxed Flatpak apps see and use the Tahoe theme
  command -v flatpak >/dev/null 2>&1 || return 0
  flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem="$1":ro --env=GTK_THEME="$2" 2>/dev/null || true
}

snap_theme(){ # themes dir, theme name; snaps get their own $HOME under ~/snap/<app>/current
  local dir dest
  for dir in "$HOME"/snap/*/current; do
    [[ -d "$dir" && -d "$1/$2" ]] || continue
    # Symlinks out of the sandbox are not followed, so copy. Only touch copies this tool made.
    dest="$dir/.themes/$2"
    if [[ ! -e "$dest/.ubuntu-tahoe" ]]; then
      [[ -e "$dest" ]] && continue
      mkdir -p "$dir/.themes" && cp -r "$1/$2" "$dest" && : > "$dest/.ubuntu-tahoe"
    fi
    dest="$dir/.config/gtk-4.0"
    mkdir -p "$dest"
    local item
    for item in gtk.css gtk-dark.css assets windows-assets; do
      [[ -e "$1/$2/gtk-4.0/$item" ]] || continue
      [[ -e "$dest/$item" && ! -e "$dest/.ubuntu-tahoe" ]] && continue
      rm -rf "${dest:?}/$item"; cp -r "$1/$2/gtk-4.0/$item" "$dest/$item"
    done
    : > "$dest/.ubuntu-tahoe"
  done
}

chromium_gtk(){ # switch Chromium-family browsers to the GTK theme so they draw GTK window buttons
  command -v python3 >/dev/null 2>&1 || return 0
  local prefs
  for prefs in "${XDG_CONFIG_HOME:-$HOME/.config}"/{BraveSoftware/Brave-Browser,google-chrome,chromium,microsoft-edge,vivaldi}/*/Preferences \
               "$HOME"/snap/chromium/common/chromium/*/Preferences; do
    [[ -f "$prefs" ]] || continue
    # The browser rewrites Preferences on exit, so only edit it while the browser is closed.
    case "$prefs" in
      *Brave*) pgrep -x brave >/dev/null && continue ;;
      *google-chrome*) pgrep -x chrome >/dev/null && continue ;;
      *edge*) pgrep -f msedge >/dev/null && continue ;;
      *vivaldi*) pgrep -f vivaldi-bin >/dev/null && continue ;;
      *) pgrep -x chromium >/dev/null && continue ;;
    esac
    python3 -I - "$prefs" <<'PY' || true
import json, sys
p = sys.argv[1]
d = json.load(open(p))
t = d.setdefault("extensions", {}).setdefault("theme", {})
if t.get("system_theme") == 1 and not t.get("id"):
    sys.exit(0)
t["system_theme"] = 1  # 1 = GTK (ui/color/system_theme.h)
t.pop("id", None)      # a custom browser theme would override GTK
json.dump(d, open(p, "w"), separators=(",", ":"))
PY
  done
}

apply(){
  [[ -f "$CONF" ]] || return 0
  local GTK_LIGHT="" GTK_DARK="" ICON_LIGHT="" ICON_DARK="" THEMES_DIR="$HOME/.themes" mode gtk icon
  # shellcheck source=/dev/null
  source "$CONF"
  if [[ "$(gsettings get "$IFACE" color-scheme)" == "'prefer-dark'" ]]; then mode=dark; else mode=light; fi
  if [[ $mode == dark ]]; then gtk="$GTK_DARK"; icon="$ICON_DARK"; else gtk="$GTK_LIGHT"; icon="$ICON_LIGHT"; fi
  if [[ -n "$gtk" ]]; then
    set_if_needed "$IFACE" gtk-theme "'$gtk'"
    set_if_needed org.gnome.shell.extensions.user-theme name "'$gtk'"
    link_gtk4 "$THEMES_DIR/$gtk"
    flatpak_theme "$THEMES_DIR" "$gtk"
    snap_theme "$THEMES_DIR" "$gtk"
  fi
  [[ -n "$icon" ]] && set_if_needed "$IFACE" icon-theme "'$icon'"
}

apply
chromium_gtk
[[ "${1:-}" == "--once" ]] && exit 0
# Ubuntu's Appearance panel also rewrites gtk-theme/icon-theme (Yaru accents), so watch those too.
gsettings monitor "$IFACE" | while read -r line; do
  case "$line" in
    color-scheme:*|gtk-theme:*|icon-theme:*) apply ;;
  esac
done

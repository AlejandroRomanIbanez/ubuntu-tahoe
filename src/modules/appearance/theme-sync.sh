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
  fi
  [[ -n "$icon" ]] && set_if_needed "$IFACE" icon-theme "'$icon'"
}

apply
[[ "${1:-}" == "--once" ]] && exit 0
# Ubuntu's Appearance panel also rewrites gtk-theme/icon-theme (Yaru accents), so watch those too.
gsettings monitor "$IFACE" | while read -r line; do
  case "$line" in
    color-scheme:*|gtk-theme:*|icon-theme:*) apply ;;
  esac
done

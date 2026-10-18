#!/usr/bin/env bash
# Resets your desktop's *appearance* to Ubuntu's defaults, after saving a backup you can restore.
# Use it before installing Ubuntu Tahoe on a desktop that already has other themes, extensions or
# tweaks (./install.sh --reset runs it for you).
#
# Usage: ./scripts/reset-appearance.sh [--dry-run]   back up, then reset to Ubuntu defaults
#        ./scripts/reset-appearance.sh --restore     put back the look saved by the last reset
#
# What is reset: theme, icons, cursor, light/dark style, wallpaper, window buttons, Ubuntu Dock
# settings, User Themes / Blur My Shell settings, which GNOME extensions are enabled, and custom
# GTK CSS in ~/.config/gtk-3.0 and ~/.config/gtk-4.0 (moved into the backup, not deleted).
# What is NOT touched: fonts, text size, accessibility, keyboard, mouse, display, apps, files.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=src/core/common.sh
source "$ROOT/src/core/common.sh"

RESET_DIR="$STATE_DIR/reset-backup"
INTERFACE_KEYS=(gtk-theme icon-theme cursor-theme cursor-size color-scheme)
DCONF_DIRS=(/org/gnome/desktop/background/ /org/gnome/desktop/wm/preferences/ /org/gnome/shell/extensions/dash-to-dock/
            /org/gnome/shell/extensions/user-theme/ /org/gnome/shell/extensions/blur-my-shell/)
SHELL_KEYS=(enabled-extensions disabled-extensions disable-user-extensions)
CSS_FILES=(gtk-3.0/gtk.css gtk-3.0/gtk-dark.css gtk-4.0/gtk.css gtk-4.0/gtk-dark.css gtk-4.0/assets gtk-4.0/windows-assets)

action=reset
case "${1:-}" in
  "") ;;
  --dry-run) action=plan ;;
  --restore) action=restore ;;
  -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "Unknown argument: $1 (use --dry-run or --restore)" ;;
esac
[[ $EUID -ne 0 ]] || die "Run as your normal user, not root."
require_command gsettings
require_command dconf

if [[ $action != restore && -s "$INSTALLED" ]]; then
  die "Ubuntu Tahoe is installed. Run ./uninstall.sh --all first, then reset."
fi

case "$action" in
  plan)
    log "DRY RUN: would save a backup to $RESET_DIR, then reset to Ubuntu defaults:"
    for k in "${INTERFACE_KEYS[@]}"; do log "  org.gnome.desktop.interface $k (now $(gsettings get org.gnome.desktop.interface "$k"))"; done
    for d in "${DCONF_DIRS[@]}"; do [[ -z "$(dconf dump "$d")" ]] || log "  all custom settings under $d"; done
    log "  enabled extensions (now $(gsettings get org.gnome.shell enabled-extensions)) -> Ubuntu's defaults"
    for f in "${CSS_FILES[@]}"; do [[ -e "$CONFIG_HOME/$f" || -L "$CONFIG_HOME/$f" ]] && log "  move aside $CONFIG_HOME/$f"; done
    log "No changes made."
    ;;
  reset)
    ensure_state_dirs
    rm -rf "$RESET_DIR"; mkdir -p "$RESET_DIR/config"; chmod 700 "$RESET_DIR"
    for k in "${INTERFACE_KEYS[@]}"; do printf '%s=%s\n' "$k" "$(dconf read "/org/gnome/desktop/interface/$k")"; done > "$RESET_DIR/interface.txt"
    for k in "${SHELL_KEYS[@]}"; do printf '%s=%s\n' "$k" "$(dconf read "/org/gnome/shell/$k")"; done > "$RESET_DIR/shell.txt"
    for d in "${DCONF_DIRS[@]}"; do f="$RESET_DIR/dconf${d//\//_}ini"; dconf dump "$d" > "$f"; done
    for f in "${CSS_FILES[@]}"; do
      if [[ -e "$CONFIG_HOME/$f" || -L "$CONFIG_HOME/$f" ]]; then
        mkdir -p "$(dirname "$RESET_DIR/config/$f")"; mv "$CONFIG_HOME/$f" "$RESET_DIR/config/$f"; log "MOVED aside: $CONFIG_HOME/$f"
      fi
    done
    log "Backup saved: $RESET_DIR"
    for k in "${INTERFACE_KEYS[@]}"; do dconf reset "/org/gnome/desktop/interface/$k"; done
    for k in "${SHELL_KEYS[@]}"; do dconf reset "/org/gnome/shell/$k"; done
    for d in "${DCONF_DIRS[@]}"; do dconf reset -f "$d"; done
    log "Appearance reset to Ubuntu defaults (theme $(gsettings get org.gnome.desktop.interface gtk-theme), extensions: Ubuntu's defaults)."
    log "Restore your previous look any time with: ./scripts/reset-appearance.sh --restore"
    ;;
  restore)
    [[ -d "$RESET_DIR" ]] || die "No reset backup found at $RESET_DIR"
    [[ -s "$INSTALLED" ]] && die "Ubuntu Tahoe is installed. Run ./uninstall.sh --all first, then restore."
    while IFS='=' read -r k v; do if [[ -n "$v" ]]; then dconf write "/org/gnome/desktop/interface/$k" "$v"; else dconf reset "/org/gnome/desktop/interface/$k"; fi; done < "$RESET_DIR/interface.txt"
    while IFS='=' read -r k v; do if [[ -n "$v" ]]; then dconf write "/org/gnome/shell/$k" "$v"; else dconf reset "/org/gnome/shell/$k"; fi; done < "$RESET_DIR/shell.txt"
    for d in "${DCONF_DIRS[@]}"; do f="$RESET_DIR/dconf${d//\//_}ini"; dconf reset -f "$d"; [[ -s "$f" ]] && dconf load "$d" < "$f"; done
    for f in "${CSS_FILES[@]}"; do
      if [[ -e "$RESET_DIR/config/$f" || -L "$RESET_DIR/config/$f" ]]; then
        mkdir -p "$(dirname "$CONFIG_HOME/$f")"; rm -rf "${CONFIG_HOME:?}/$f"; mv "$RESET_DIR/config/$f" "$CONFIG_HOME/$f"; log "RESTORED: $CONFIG_HOME/$f"
      fi
    done
    rm -rf "$RESET_DIR"
    log "Previous appearance restored. Log out and back in to reload extensions."
    ;;
esac

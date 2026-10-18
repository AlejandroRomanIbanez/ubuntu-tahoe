#!/usr/bin/env bash
# Switch the desktop between light and dark (the same as Settings > Appearance or the Dark Style
# button). With Ubuntu Tahoe installed, theme, icons, wallpaper and apps all follow.
# Usage: ./scripts/style.sh light|dark|toggle|status
set -Eeuo pipefail
key=org.gnome.desktop.interface
current="$(gsettings get "$key" color-scheme)"
case "${1:-status}" in
  light) gsettings set "$key" color-scheme default ;;
  dark) gsettings set "$key" color-scheme prefer-dark ;;
  toggle) if [[ "$current" == "'prefer-dark'" ]]; then gsettings set "$key" color-scheme default; else gsettings set "$key" color-scheme prefer-dark; fi ;;
  status) ;;
  *) echo "Usage: $0 light|dark|toggle|status" >&2; exit 2 ;;
esac
if [[ "$(gsettings get "$key" color-scheme)" == "'prefer-dark'" ]]; then echo "Style: dark"; else echo "Style: light"; fi

#!/usr/bin/env bash
# Visual acceptance capture, run ON the test host inside the GNOME session environment.
# Usage: tests/desktop/capture.sh OUTDIR [light|dark|both]
# Captures the desktop, overview, app grid and the apps required by docs/gtk-libadwaita.md.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/desktop/session-env.sh
source "$HERE/session-env.sh"
out="${1:?usage: capture.sh OUTDIR [light|dark|both]}"; modes="${2:-both}"
[[ "$modes" == both ]] && modes="light dark"
mkdir -p "$out"

shot(){ sleep "${2:-1.5}"; import -window root "$out/$1.png"; echo "captured $out/$1.png"; }
# GNOME 46 opens the overview at login; force it closed so every shot starts from the desktop.
overview_off(){ gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.freedesktop.DBus.Properties.Set org.gnome.Shell OverviewActive "<false>" >/dev/null 2>&1 || true; sleep 0.5; }
click(){ xdotool mousemove "$1" "$2" click 1; }
close_all(){ for c in nautilus gnome-text-editor gnome-terminal-server gnome-control-center gnome-calculator zenity; do pkill -f "^(\S*/)?$c( |$)" 2>/dev/null || true; done; sleep 1.5; overview_off; xdotool mousemove 960 600; }
key(){ xdotool key --clearmodifiers "$@"; }
launch(){ setsid "$@" >/dev/null 2>&1 < /dev/null & }

close_all
for mode in $modes; do
  if [[ $mode == dark ]]; then gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  else gsettings set org.gnome.desktop.interface color-scheme default; fi
  sleep 3
  shot "$mode-01-desktop"
  launch nautilus --new-window "$HOME"; shot "$mode-02-nautilus" 4
  launch gnome-text-editor; shot "$mode-03-text-editor-libadwaita" 3
  launch gnome-terminal; shot "$mode-04-terminal-gtk3" 3
  launch gnome-calculator; shot "$mode-05-calculator-gtk4" 3
  close_all
  launch gnome-control-center appearance; shot "$mode-06-settings-appearance" 5
  close_all
  launch zenity --file-selection --title "File chooser"; shot "$mode-07-file-chooser" 3
  close_all
  launch zenity --question --title "Dialog" --text "Standard GTK dialog: keep these changes?"; shot "$mode-08-dialog" 2
  close_all
  launch gnome-terminal; sleep 2; key super+Up; shot "$mode-09-maximized-window-and-dock" 2
  close_all
  key super; shot "$mode-10-overview" 2
  key Escape; sleep 1; key super+a; shot "$mode-11-app-grid" 2
  key Escape; sleep 0.5; key Escape; sleep 1
  click 1890 12; shot "$mode-12-quick-settings" 2
  key Escape; sleep 0.5
  click 960 12; shot "$mode-13-calendar" 2
  key Escape
  close_all
done
gsettings set org.gnome.desktop.interface color-scheme default
# Contact sheets for quick review (ImageMagick montage).
for mode in light dark; do
  ls "$out/$mode-01"*.png >/dev/null 2>&1 || continue
  montage "$out/$mode"-0[1-6]*.png -tile 3x2 -geometry 960x540+4+4 "$out/sheet-$mode-apps.jpg"
  montage "$out/$mode"-0[7-9]*.png "$out/$mode"-1*.png -tile 4x2 -geometry 720x405+4+4 "$out/sheet-$mode-shell.jpg"
done

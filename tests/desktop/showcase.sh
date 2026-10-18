#!/usr/bin/env bash
# Feature showcase capture, run ON the test host inside the GNOME session environment.
# Usage: tests/desktop/showcase.sh OUTDIR [light|dark]
# Produces NN-name.png (full screen) plus *-zoom.png close-ups of individual features.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/desktop/session-env.sh
source "$HERE/session-env.sh"
out="${1:?usage: showcase.sh OUTDIR [light|dark]}"; mode="${2:-light}"
mkdir -p "$out"

key(){ xdotool key --clearmodifiers "$@"; }
click(){ xdotool mousemove "$1" "$2" click "${3:-1}"; }
launch(){ setsid "$@" >/dev/null 2>&1 < /dev/null & }
overview_off(){ gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.freedesktop.DBus.Properties.Set org.gnome.Shell OverviewActive "<false>" >/dev/null 2>&1 || true; sleep 0.5; }
close_all(){ for c in nautilus gnome-text-editor gnome-terminal-server gnome-control-center gnome-calculator zenity; do pkill -f "^(\S*/)?$c( |$)" 2>/dev/null || true; done; sleep 1.5; overview_off; xdotool mousemove 960 700; }
shot(){ sleep "${2:-1.5}"; import -window root "$out/$mode-$1.png"; echo "captured $mode-$1"; }
# Prints X Y W H of the first visible window of a WM class.
geom(){ local id; id="$(xdotool search --sync --onlyvisible --class "$1" | head -n 1)"; xdotool getwindowgeometry --shell "$id" | awk -F= '/^(X|Y|WIDTH|HEIGHT)=/{printf "%s ", $2} END{print ""}'; }
zoom(){ convert "$out/$mode-$1.png" -crop "$2" +repage "$out/$mode-$1-zoom.png"; } # name WxH+X+Y

if [[ $mode == dark ]]; then gsettings set org.gnome.desktop.interface color-scheme prefer-dark
else gsettings set org.gnome.desktop.interface color-scheme default; fi
close_all; sleep 3

shot 01-desktop; zoom 01-desktop 1920x40+0+0; cp "$out/$mode-01-desktop-zoom.png" "$out/$mode-02-top-bar-zoom.png"; rm "$out/$mode-01-desktop-zoom.png"
convert "$out/$mode-01-desktop.png" -crop 700x110+610+970 +repage "$out/$mode-03-dock-zoom.png"

launch nautilus --new-window "$HOME"; shot 04-files 4; zoom 04-files 900x500+510+250
key ctrl+l; sleep 0.5; key Escape
read -r x y w h < <(geom org.gnome.Nautilus); click $((x + w * 2 / 3)) $((y + h * 2 / 3)) 3; shot 05-files-context-menu 1.5; key Escape
close_all
launch gnome-text-editor; shot 06-text-editor 3
read -r x y _ _ < <(geom gnome-text-editor); convert "$out/$mode-06-text-editor.png" -crop "480x110+$x+$y" +repage "$out/$mode-07-window-buttons-zoom.png"
close_all
launch gnome-terminal; shot 08-terminal 3
close_all
launch gnome-calculator; shot 09-calculator 3
close_all
launch gnome-control-center ubuntu; shot 10-settings-dock 5
close_all
launch gnome-control-center background; shot 11-settings-appearance-style 5
close_all
launch zenity --file-selection --title "Open File"; shot 12-file-chooser 3
close_all
launch zenity --question --title "Confirm" --text "Do you want to keep these changes?"; shot 13-dialog 2
close_all
launch gnome-terminal; sleep 2; key super+Up; shot 14-maximized-window-with-dock 2
close_all
click 960 600 3; shot 15-desktop-right-click 1.5; key Escape
notify-send -i dialog-information "Ubuntu Tahoe" "Notifications use the Tahoe style banner."; shot 16-notification 2
sleep 4
launch nautilus --new-window "$HOME"; launch gnome-calculator; launch gnome-text-editor; sleep 4
xdotool keydown alt key Tab; sleep 1.5; import -window root "$out/$mode-17-alt-tab.png"; xdotool keyup alt; echo "captured $mode-17-alt-tab"
key super; shot 18-overview-with-windows 2
xdotool type --delay 120 "term"; shot 19-search 2
key Escape; key Escape; sleep 1; overview_off
close_all
key super+a; shot 20-app-grid 2.5; zoom 20-app-grid 1100x300+60+460
# Open the "Utilities" folder (5th icon in the first row of the stock 24.04 grid at 1920x1080).
click 867 426; shot 21-app-folder 2; key Escape; sleep 0.5; key Escape; overview_off
click 1890 12; shot 22-quick-settings 2; zoom 22-quick-settings 560x400+1360+0; key Escape; sleep 0.5
click 960 12; shot 23-calendar-and-notifications 2; key Escape
click 30 12; shot 24-activities-button 2; key Escape; overview_off
close_all
gsettings set org.gnome.desktop.interface color-scheme default

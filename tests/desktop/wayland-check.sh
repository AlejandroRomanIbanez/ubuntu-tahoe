#!/usr/bin/env bash
# Starts a headless *Wayland* GNOME Shell (Ubuntu's default session type) in a private D-Bus session
# and checks that the Tahoe shell theme and extensions load there without errors.
# Run on the test host after ./install.sh. Usage: tests/desktop/wayland-check.sh
# shellcheck disable=SC2016 # bash -c bodies receive their values as arguments
set -Eeuo pipefail
if [[ "${1:-}" != --inner ]]; then exec dbus-run-session -- "$0" --inner; fi
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=ubuntu:GNOME GNOME_SHELL_SESSION_MODE=ubuntu
unset DISPLAY
log="$(mktemp)"
gnome-shell --headless --wayland --no-x11 --virtual-monitor 1920x1080 --wayland-display=wl-tahoe-check > "$log" 2>&1 &
shell=$!
trap 'kill $shell 2>/dev/null; wait $shell 2>/dev/null; rm -f "$log"' EXIT
sleep 25
fail=0
check(){ if "${@:2}"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
check "GNOME Shell runs on Wayland" kill -0 "$shell"
check "Tahoe shell theme loaded" grep -q "loading user theme: .*/MacTahoe-" "$log"
for e in user-theme@gnome-shell-extensions.gcampax.github.com blur-my-shell@aunetx ubuntu-dock@ubuntu.com; do
  check "$e active on Wayland" bash -c 'gnome-extensions info "$1" | grep -q "State: ACTIVE"' _ "$e"
done
check "no GNOME Shell JS errors" bash -c '! grep -q "JS ERROR" "$1"' _ "$log"
exit "$fail"

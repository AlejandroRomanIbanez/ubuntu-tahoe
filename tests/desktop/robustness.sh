#!/usr/bin/env bash
# Robustness suite for a real GNOME session. DISPOSABLE TEST HOST ONLY (the AWS host from
# infra/aws): it uses sudo to simulate failures (no internet, root user) and changes settings freely.
# Usage (from the repository root, inside the session env): tests/desktop/robustness.sh
# shellcheck disable=SC2016,SC2317 # bash -c bodies get values as arguments; helpers run via check()
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/desktop/session-env.sh
source "$ROOT/tests/desktop/session-env.sh"
[[ -f /var/lib/ubuntu-tahoe/bootstrap-done ]] || { echo "Refusing: not the disposable test host" >&2; exit 2; }
cd "$ROOT"
STATE="$HOME/.local/state/ubuntu-tahoe"
I=org.gnome.desktop.interface
D=org.gnome.shell.extensions.dash-to-dock
pass=0; fail=0
check(){ local name="$1"; shift; if "$@"; then echo "PASS $name"; pass=$((pass + 1)); else echo "FAIL $name"; fail=$((fail + 1)); fi; }
g(){ gsettings get "$@"; }
quiet(){ "$@" > /tmp/rb-last.log 2>&1; }
managed_dump(){ # every key/namespace Ubuntu Tahoe may touch
  for p in /org/gnome/desktop/interface/ /org/gnome/desktop/background/ /org/gnome/desktop/wm/preferences/ \
           /org/gnome/shell/extensions/dash-to-dock/ /org/gnome/shell/extensions/user-theme/ /org/gnome/shell/extensions/blur-my-shell/; do
    echo "[$p]"; dconf dump "$p"
  done
  echo "[enabled-extensions] $(dconf read /org/gnome/shell/enabled-extensions)"
}
our_files(){ ls -d ~/.themes/MacTahoe* ~/.local/share/icons/MacTahoe* ~/.local/share/backgrounds/ubuntu-tahoe \
  ~/.local/share/gnome-shell/extensions/blur-my-shell@aunetx ~/.local/bin/ubuntu-tahoe-theme-sync \
  ~/.config/systemd/user/ubuntu-tahoe-theme-sync.service 2>/dev/null || true; }
mode_ok(){ # theme, shell theme, icons and libadwaita link all match the current style
  local want=Light icon=MacTahoe-light
  [[ "$(g "$I" color-scheme)" == "'prefer-dark'" ]] && { want=Dark; icon=MacTahoe-dark; }
  [[ "$(g "$I" gtk-theme)" == "'MacTahoe-$want'" && "$(g org.gnome.shell.extensions.user-theme name)" == "'MacTahoe-$want'" \
     && "$(g "$I" icon-theme)" == "'$icon'" && "$(readlink ~/.config/gtk-4.0/gtk.css)" == *"/MacTahoe-$want/gtk-4.0/gtk.css" ]]
}
wait_for(){ local _i; for _i in $(seq 1 20); do if "$@"; then return 0; fi; sleep 0.5; done; return 1; }

echo "== Setup: start from a clean desktop"
quiet ./uninstall.sh --all || true
gsettings set $I color-scheme default
mkdir -p ~/.config/gtk-4.0; printf '/* my own css */\n' > ~/.config/gtk-4.0/gtk.css   # a user's pre-existing file
baseline="$(managed_dump)"
orig_icons="$(g "$I" icon-theme)"
sudo touch /var/tmp/ubuntu-tahoe-marker

echo "== Dry run"
quiet ./install.sh --dry-run
check "dry run changes no settings" test "$baseline" == "$(managed_dump)"
check "dry run creates no files" test -z "$(our_files)"

echo "== Safety guards"
check "installer refuses to run as root" bash -c '! sudo -E ./install.sh --module dock >/tmp/rb-root.log 2>&1 && grep -q "not root" /tmp/rb-root.log'
check "unknown module is rejected" bash -c '! ./install.sh --module nope >/dev/null 2>&1'
check "uninstall with nothing installed is harmless" quiet ./uninstall.sh --all

echo "== No internet, empty cache"
rm -rf ~/.cache/ubuntu-tahoe
sudo cp /etc/hosts /var/tmp/hosts.bak
printf '0.0.0.0 github.com codeload.github.com extensions.gnome.org\n' | sudo tee -a /etc/hosts >/dev/null
check "install fails cleanly without internet" bash -c '! ./install.sh >/tmp/rb-offline.log 2>&1 && grep -q "check your internet connection" /tmp/rb-offline.log'
check "failed install rolled back every setting" test "$baseline" == "$(managed_dump)"
check "failed install left no files behind" test -z "$(our_files)"
check "user's own gtk.css untouched after failure" grep -q "my own css" ~/.config/gtk-4.0/gtk.css
sudo cp /var/tmp/hosts.bak /etc/hosts

echo "== Interrupted install (killed mid-build), then recovery"
timeout -s KILL 6 ./install.sh >/dev/null 2>&1 || true
check "re-running after an interrupted install succeeds" quiet ./install.sh
check "uninstall after an interrupted install restores everything" bash -c 'cd "$1" && ./uninstall.sh --all >/dev/null 2>&1' _ "$ROOT"
check "settings identical to before" test "$baseline" == "$(managed_dump)"
check "user's gtk.css restored" grep -q "my own css" ~/.config/gtk-4.0/gtk.css

echo "== Corrupted download cache"
f="$(find ~/.cache/ubuntu-tahoe/downloads -name "*MacTahoe-gtk*" | head -n 1)"; echo garbage > "$f"
check "install recovers from a corrupted cache" quiet ./install.sh
check "corrupted file was replaced" bash -c 'grep -q "re-downloading\|downloading it again" /tmp/rb-last.log'

echo "== Installed state"
check "all theme files present" test "$(our_files | wc -l)" -ge 9
check "user's gtk.css was set aside, not deleted" grep -rq "my own css" "$STATE/displaced"
check "theme-sync service running" systemctl --user is-active --quiet ubuntu-tahoe-theme-sync
check "light mode fully applied" mode_ok
check "dock moved to the bottom" test "$(g $D dock-position)" == "'BOTTOM'"
check "window buttons on the left" test "$(g org.gnome.desktop.wm.preferences button-layout)" == "'close,minimize,maximize:appmenu'"
# Ubuntu's own background services (clock sync, snaps, update checks, apt/dpkg) write here on their own.
system_changes(){ sudo find /etc /usr /opt /var/lib -xdev -newer /var/tmp/ubuntu-tahoe-marker -not -name hosts \
  -not -path "/var/lib/systemd/*" -not -path "/var/lib/apt/*" -not -path "/var/lib/dpkg/*" -not -path "/var/lib/sudo/*" \
  -not -path "/var/lib/chrony*" -not -path "/var/lib/snapd/*" -not -path "/var/lib/PackageKit/*" \
  -not -path "/var/lib/update-notifier/*" -not -path "/var/lib/ubuntu-advantage/*" -not -path "/var/lib/logrotate/*" 2>/dev/null; }
check "nothing outside HOME was modified" test -z "$(system_changes)" || system_changes

echo "== Second install is a no-op"
before="$(managed_dump)"; quiet ./install.sh
check "second install changes no settings" bash -c '! grep -q "\] SET:" /tmp/rb-last.log'
check "second install leaves theme settings identical" test "$(grep -v blur-my-shell <<<"$before")" == "$(managed_dump | grep -v blur-my-shell)"

echo "== Light/dark switching"
for _ in 1 2 3 4 5 6 7 8 9 10; do ./scripts/style.sh toggle >/dev/null; sleep 0.2; done
check "10 rapid toggles end consistent (light)" wait_for mode_ok
./scripts/style.sh dark >/dev/null
check "dark mode applies theme, shell, icons and libadwaita" wait_for mode_ok
check "dark wallpaper set" bash -c '[[ "$(gsettings get org.gnome.desktop.background picture-uri-dark)" == *MacTahoe-night* ]]'
./scripts/style.sh light >/dev/null
check "light mode applies theme, shell, icons and libadwaita" wait_for mode_ok

echo "== Ubuntu Appearance accent click (rewrites gtk-theme to Yaru)"
gsettings set $I gtk-theme Yaru-purple
check "theme is restored to MacTahoe automatically" wait_for mode_ok

echo "== Theme-sync crash recovery"
pkill -KILL -f ubuntu-tahoe-theme-sync || true
check "service restarts after a crash" wait_for systemctl --user is-active --quiet ubuntu-tahoe-theme-sync
sleep 4; ./scripts/style.sh dark >/dev/null
check "switching still works after the crash" wait_for mode_ok
./scripts/style.sh light >/dev/null; wait_for mode_ok || true

echo "== Removing one module leaves the others working"
quiet ./uninstall.sh --module icons
check "icons back to their original theme" test "$(g "$I" icon-theme)" == "$orig_icons"
check "theme still MacTahoe" test "$(g "$I" gtk-theme)" == "'MacTahoe-Light'"
./scripts/style.sh dark >/dev/null; sleep 2
check "sync no longer touches icons after icons removed" test "$(g "$I" icon-theme)" == "$orig_icons"
./scripts/style.sh light >/dev/null
check "icons module reinstalls" quiet ./install.sh --module icons

echo "== The user's own changes are respected"
gsettings set $D dock-position "'LEFT'"
quiet ./uninstall.sh --module dock
check "dock kept on the left (user's choice) after uninstall" test "$(g $D dock-position)" == "'LEFT'"
check "other dock settings restored to Ubuntu defaults" test "$(g $D extend-height)" == "true"
gsettings reset $D dock-position
quiet ./install.sh --module dock

echo "== GNOME Shell health"
check "no GNOME Shell errors from our extensions" bash -c '! journalctl --user -b --since "-30min" --no-pager 2>/dev/null | grep -E "JS ERROR|Extension .* had error" | grep -qiE "user-theme|blur-my-shell|tahoe"'

echo "== Full uninstall"
quiet ./uninstall.sh --all
check "settings identical to the clean baseline" test "$baseline" == "$(managed_dump)" || diff <(echo "$baseline") <(managed_dump) || true
check "no theme files left" test -z "$(our_files)"
check "user's own gtk.css is back" grep -q "my own css" ~/.config/gtk-4.0/gtk.css
check "theme-sync service gone" bash -c '! systemctl --user is-active --quiet ubuntu-tahoe-theme-sync'
rm -f ~/.config/gtk-4.0/gtk.css

echo; echo "Robustness: $pass passed, $fail failed"
exit "$fail"

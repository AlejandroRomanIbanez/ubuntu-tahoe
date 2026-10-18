#!/usr/bin/env bash
# Offline test suite: runs anywhere (CI, WSL, a desktop) without touching the real GNOME settings.
# A fake gsettings backend and a throwaway HOME are used for every behavioural test.
# shellcheck disable=SC2016 # single-quoted bash -c bodies receive their values as arguments
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
pass(){ printf 'PASS %s\n' "$1"; }
check(){ local name="$1"; shift; if "$@"; then pass "$name"; else printf 'FAIL %s\n' "$name"; fail=1; fi; }

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin"
ln -s "$ROOT/tests/fake-gsettings" "$SANDBOX/bin/gsettings"
ln -s "$ROOT/tests/fake-dconf" "$SANDBOX/bin/dconf"
printf '#!/bin/sh\nexit 1\n' > "$SANDBOX/bin/systemctl"
printf '#!/bin/sh\necho "GNOME Shell 46.0"\n' > "$SANDBOX/bin/gnome-shell"
chmod +x "$SANDBOX/bin/"*

# Fresh fake desktop: stock Ubuntu 24.04 values for every key the project manages.
reset_env(){
  export HOME="$SANDBOX/home" FAKE_GSETTINGS_DIR="$SANDBOX/gsettings"
  export PATH="$SANDBOX/bin:$PATH" XDG_CURRENT_DESKTOP=ubuntu:GNOME
  export UBUNTU_TAHOE_SYSTEM_EXTENSIONS_DIR="$SANDBOX/no-system-extensions" # User Themes "not installed"
  unset XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_CONFIG_HOME
  rm -rf "$HOME" "$FAKE_GSETTINGS_DIR"; mkdir -p "$HOME"
  local d="$FAKE_GSETTINGS_DIR"
  mkdir -p "$d/org.gnome.desktop.interface" "$d/org.gnome.shell" "$d/org.gnome.shell.extensions.dash-to-dock" \
    "$d/org.gnome.desktop.background" "$d/org.gnome.desktop.wm.preferences"
  echo "'Yaru'" > "$d/org.gnome.desktop.interface/gtk-theme"
  echo "'Yaru'" > "$d/org.gnome.desktop.interface/icon-theme"
  echo "'Yaru'" > "$d/org.gnome.desktop.interface/cursor-theme"
  echo "24" > "$d/org.gnome.desktop.interface/cursor-size"
  echo "'default'" > "$d/org.gnome.desktop.interface/color-scheme"
  echo "['ding@rastersoft.com', 'ubuntu-dock@ubuntu.com']" > "$d/org.gnome.shell/enabled-extensions"
  echo "'appmenu:minimize,maximize,close'" > "$d/org.gnome.desktop.wm.preferences/button-layout"
  echo "'file:///usr/share/backgrounds/warty-final-ubuntu.png'" > "$d/org.gnome.desktop.background/picture-uri"
  echo "'file:///usr/share/backgrounds/ubuntu-wallpaper-d.png'" > "$d/org.gnome.desktop.background/picture-uri-dark"
  echo "'zoom'" > "$d/org.gnome.desktop.background/picture-options"
  local k
  for k in "dock-position 'LEFT'" "extend-height true" "dock-fixed true" "autohide true" "intellihide true" \
           "dash-max-icon-size 48" "show-apps-at-top false" "show-trash true" "show-mounts true" \
           "running-indicator-style 'DOTS'" "custom-theme-shrink false"; do
    echo "${k#* }" > "$d/org.gnome.shell.extensions.dash-to-dock/${k%% *}"
  done
}
get(){ cat "$FAKE_GSETTINGS_DIR/$1/$2"; }
snapshot(){ find "$FAKE_GSETTINGS_DIR" -type f -printf '%P ' -exec cat {} \; | sort; }

check "scripts are shell-syntax valid" bash -c 'find "$1" -type f \( -name "*.sh" -o -name fake-gsettings \) -print0 | xargs -0 -r -n1 bash -n' _ "$ROOT"
if command -v shellcheck >/dev/null 2>&1; then
  check "ShellCheck" bash -c 'cd "$1" && shellcheck -x install.sh uninstall.sh src/core/*.sh src/modules/*/*.sh scripts/*.sh tests/run.sh tests/fake-gsettings tests/fake-dconf infra/aws/bootstrap/*.sh tests/desktop/*.sh' _ "$ROOT"
else printf 'SKIP ShellCheck not installed\n'; fi

reset_env
check "install --help exits successfully" bash -c '"$1/install.sh" --help >/dev/null' _ "$ROOT"
check "uninstall --help exits successfully" bash -c '"$1/uninstall.sh" --help >/dev/null' _ "$ROOT"
check "module list contains every module" bash -c '[[ "$("$1/install.sh" --list-modules | xargs)" == "appearance icons cursor wallpaper dock blur" ]]' _ "$ROOT"
check "unknown module rejected" bash -c '! "$1/install.sh" --module not-real --dry-run >/dev/null 2>&1' _ "$ROOT"
check "unknown profile rejected" bash -c '! "$1/install.sh" --profile not-real --dry-run >/dev/null 2>&1' _ "$ROOT"
check "profiles parse from config/profiles" bash -c '"$1/install.sh" --profile tahoe --dry-run 2>&1 | grep -q "Modules=appearance icons cursor wallpaper dock blur" && "$1/install.sh" --profile minimal --dry-run 2>&1 | grep -q "Modules=appearance$"' _ "$ROOT"
check "full is an alias of tahoe" bash -c '"$1/install.sh" --profile full --dry-run 2>&1 | grep -q "Modules=appearance icons cursor wallpaper dock blur"' _ "$ROOT"

before="$(snapshot)"
"$ROOT/install.sh" --profile tahoe --dry-run >/dev/null 2>&1
check "dry run changes no settings" test "$before" == "$(snapshot)"
check "dry run creates no state, cache or files" test -z "$(ls -A "$HOME")"
check "dry run reports missing prerequisites" bash -c '"$1/install.sh" --module appearance --dry-run 2>&1 | grep -q "sudo apt install"' _ "$ROOT"

reset_env
"$ROOT/install.sh" --module dock >/dev/null 2>&1
check "dock install applies macOS-style dock" bash -c '[[ "$(cat "$1/dock-position")" == "'"'BOTTOM'"'" && "$(cat "$1/extend-height")" == false ]]' _ "$FAKE_GSETTINGS_DIR/org.gnome.shell.extensions.dash-to-dock"
"$ROOT/install.sh" --module dock >/dev/null 2>&1
check "second install keeps the true originals in the ledger" grep -qP "^dock\torg.gnome.shell.extensions.dash-to-dock\tdock-position\t'LEFT'\t'BOTTOM'$" "$HOME/.local/state/ubuntu-tahoe/ledger.tsv"
check "second install adds no duplicate ledger rows" test "$(grep -c dock-position "$HOME/.local/state/ubuntu-tahoe/ledger.tsv")" -eq 1
echo "false" > "$FAKE_GSETTINGS_DIR/org.gnome.shell.extensions.dash-to-dock/show-trash" # user changes a key
"$ROOT/uninstall.sh" --module dock >/dev/null 2>&1
check "uninstall restores original dock values" bash -c '[[ "$(cat "$1/dock-position")" == "'"'LEFT'"'" && "$(cat "$1/extend-height")" == true && "$(cat "$1/show-mounts")" == true ]]' _ "$FAKE_GSETTINGS_DIR/org.gnome.shell.extensions.dash-to-dock"
check "uninstall keeps a value the user changed afterwards" test "$(get org.gnome.shell.extensions.dash-to-dock show-trash)" == false
reset_env
echo "org.gnome.shell.extensions.dash-to-dock dock-position" > "$FAKE_GSETTINGS_DIR/.defaults"
"$ROOT/install.sh" --module dock >/dev/null 2>&1; "$ROOT/uninstall.sh" --module dock >/dev/null 2>&1
check "keys that were at their default are reset, not rewritten" test "$(get org.gnome.shell.extensions.dash-to-dock dock-position)" == DEFAULT
check "uninstall with nothing installed is a no-op" bash -c '"$1/uninstall.sh" --all 2>&1 | grep -q "Nothing is installed"' _ "$ROOT"

reset_env
before="$(snapshot)"
check "appearance refuses without prerequisites (no sudo)" bash -c '! "$1/install.sh" --module appearance >"$2/out" 2>&1 && grep -q "sudo apt install .*gnome-shell-extensions" "$2/out"' _ "$ROOT" "$SANDBOX"
check "failed install leaves settings untouched" test "$before" == "$(snapshot)"

# --reset on a customised ("not clean") desktop, then uninstall, then restore the old look.
reset_env
iface="$FAKE_GSETTINGS_DIR/org.gnome.desktop.interface"
echo "'Yaru-dark'" > "$iface/gtk-theme"; echo "'Papirus'" > "$iface/icon-theme"
echo "['dash-to-panel@jderose9.github.com']" > "$FAKE_GSETTINGS_DIR/org.gnome.shell/enabled-extensions"
echo "'RIGHT'" > "$FAKE_GSETTINGS_DIR/org.gnome.shell.extensions.dash-to-dock/dock-position"
mkdir -p "$HOME/.config/gtk-3.0"; echo "my css" > "$HOME/.config/gtk-3.0/gtk.css"
before="$(snapshot)"
"$ROOT/install.sh" --reset --module dock --dry-run >/dev/null 2>&1
check "--reset --dry-run changes nothing" test "$before" == "$(snapshot)"
"$ROOT/install.sh" --reset --module dock >/dev/null 2>&1
check "--reset puts theme and icons back to Ubuntu defaults" bash -c '[[ "$(cat "$1/gtk-theme")" == DEFAULT && "$(cat "$1/icon-theme")" == DEFAULT ]]' _ "$iface"
check "--reset disables other extensions (Ubuntu defaults)" test "$(get org.gnome.shell enabled-extensions)" == DEFAULT
check "--reset moves custom GTK CSS into the backup" bash -c '[[ ! -e "$1/.config/gtk-3.0/gtk.css" && -f "$1/.local/state/ubuntu-tahoe/reset-backup/config/gtk-3.0/gtk.css" ]]' _ "$HOME"
check "install continues after reset" test "$(get org.gnome.shell.extensions.dash-to-dock dock-position)" == "'BOTTOM'"
check "reset refuses while Tahoe is installed" bash -c '! "$1/scripts/reset-appearance.sh" >/dev/null 2>&1' _ "$ROOT"
"$ROOT/uninstall.sh" --all >/dev/null 2>&1
check "uninstall after --reset leaves Ubuntu defaults" test "$(get org.gnome.shell.extensions.dash-to-dock dock-position)" == DEFAULT
"$ROOT/scripts/reset-appearance.sh" --restore >/dev/null 2>&1
check "--restore brings back the previous look exactly" test "$before" == "$(snapshot)"
check "--restore brings back custom GTK CSS" grep -q "my css" "$HOME/.config/gtk-3.0/gtk.css"

# Library-level checks: extension list editing, file displacement and checksum verification.
lib(){ bash -c 'set -Eeuo pipefail; ROOT="$1"; code="$2"; shift 2; source "$ROOT/src/core/common.sh"; ensure_state_dirs; eval "$code"' _ "$ROOT" "$@"; }
reset_env
lib 'enable_extension blur x@y; enable_extension blur x@y' 2>/dev/null
check "enable_extension appends once and keeps others" test "$(get org.gnome.shell enabled-extensions)" == "['ding@rastersoft.com', 'ubuntu-dock@ubuntu.com', 'x@y']"
lib 'remove_module_files blur' 2>/dev/null
check "uninstall disables only our extension" test "$(get org.gnome.shell enabled-extensions)" == "['ding@rastersoft.com', 'ubuntu-dock@ubuntu.com']"
mkdir -p "$HOME/.config/gtk-4.0" "$SANDBOX/src"; echo mine > "$HOME/.config/gtk-4.0/gtk.css"; echo ours > "$SANDBOX/src/f"
lib 'displace_path appearance "$HOME/.config/gtk-4.0/gtk.css"; own_path appearance "$HOME/.config/gtk-4.0/gtk.css"; cp "$1/src/f" "$HOME/.config/gtk-4.0/gtk.css"' "$SANDBOX" 2>/dev/null
check "existing user file is moved aside" test "$(cat "$HOME/.config/gtk-4.0/gtk.css")" == ours
lib 'remove_module_files appearance' 2>/dev/null
check "uninstall puts the user's file back" test "$(cat "$HOME/.config/gtk-4.0/gtk.css")" == mine
echo payload > "$SANDBOX/payload"; good="$(sha256sum "$SANDBOX/payload" | cut -d' ' -f1)"
check "verified download is accepted" lib 'fetch_pinned p "file://$1/payload" "$2" >/dev/null' "$SANDBOX" "$good"
echo corrupted > "$HOME/.cache/ubuntu-tahoe/downloads/$good-p"
check "corrupted cache is re-downloaded" lib 'f="$(fetch_pinned p "file://$1/payload" "$2")"; [[ "$(cat "$f")" == payload ]]' "$SANDBOX" "$good"
check "checksum mismatch is refused" bash -c '! "$@" 2>/dev/null' _ lib 'fetch_pinned q "file://$1/payload" 0000000000000000000000000000000000000000000000000000000000000000' "$SANDBOX"
check "theme-sync is a no-op without config" bash -c 'HOME="$2" "$1/src/modules/appearance/theme-sync.sh" --once' _ "$ROOT" "$HOME"
exit "$fail"

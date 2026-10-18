#!/usr/bin/env bash
# Shared functions for the Ubuntu Tahoe installer.
# shellcheck disable=SC2034 # variables are used by sourcing scripts and modules
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ubuntu-tahoe"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ubuntu-tahoe"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SYSTEM_EXTENSIONS_DIR="${UBUNTU_TAHOE_SYSTEM_EXTENSIONS_DIR:-/usr/share/gnome-shell/extensions}" # overridable for tests
LEDGER="$STATE_DIR/ledger.tsv"         # module<TAB>schema<TAB>key<TAB>original<TAB>applied[|alternative...]
FILES_DIR="$STATE_DIR/files"           # <module>.list: one owned path (or "ext:<uuid>") per line
DISPLACED_DIR="$STATE_DIR/displaced"   # pre-existing user files moved aside, restored on uninstall
SYNC_CONF="$STATE_DIR/theme-sync.conf" # light/dark pairs consumed by ubuntu-tahoe-theme-sync
INSTALLED="$STATE_DIR/installed"       # one installed module per line
LOG_FILE="$STATE_DIR/installer.log"
MODULES=(appearance icons cursor wallpaper dock blur)

log(){ printf '[ubuntu-tahoe] %s\n' "$*" >&2; if [[ -w "$LOG_FILE" ]]; then printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG_FILE"; fi; }
die(){ log "ERROR: $*"; exit 1; }
require_command(){ command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
check_session(){
  if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* && "${DESKTOP_SESSION:-}" != *gnome* && "${DESKTOP_SESSION:-}" != ubuntu* ]]; then
    log "WARNING: session does not look like GNOME; GNOME settings may not apply."
  fi
}
valid_module(){ local m; for m in "${MODULES[@]}"; do [[ "$1" == "$m" ]] && return 0; done; return 1; }

# Prints the modules listed in config/profiles/<name>.yaml ("full" is an alias of "tahoe").
profile_modules(){
  local name="$1" file
  [[ "$name" == full ]] && name=tahoe
  file="$ROOT/config/profiles/$name.yaml"
  [[ -f "$file" ]] || return 1
  sed -n 's/^  - \([a-z]*\)[[:space:]]*$/\1/p' "$file"
}
list_profiles(){ local f; for f in "$ROOT"/config/profiles/*.yaml; do basename "$f" .yaml; done; }

# Prints the Ubuntu packages still needed by the given modules (one per line, no duplicates).
missing_packages(){
  local m need=()
  for m in "$@"; do
    case "$m" in
      appearance) need+=(sassc:sassc glib-compile-resources:libglib2.0-dev-bin curl:curl)
        extension_installed user-theme@gnome-shell-extensions.gcampax.github.com || need+=(:gnome-shell-extensions) ;;
      icons) need+=(curl:curl gtk-update-icon-cache:libgtk-3-bin) ;;
      cursor|wallpaper) need+=(curl:curl) ;;
      blur) need+=(curl:curl unzip:unzip) ;;
    esac
  done
  local entry cmd
  for entry in "${need[@]}"; do
    cmd="${entry%%:*}"
    if [[ -z "$cmd" ]] || ! command -v "$cmd" >/dev/null 2>&1; then printf '%s\n' "${entry#*:}"; fi
  done | awk '!seen[$0]++'
}

ensure_state_dirs(){
  mkdir -p "$STATE_DIR/backups" "$FILES_DIR" "$DISPLACED_DIR" "$CACHE_DIR/downloads"
  chmod 700 "$STATE_DIR"
  touch "$LOG_FILE" "$LEDGER" "$INSTALLED"; chmod 600 "$LOG_FILE" "$LEDGER"
}

# Capture before matching: "gsettings ... | grep -q" fails under pipefail when grep exits early.
setting_exists(){ local all; all="$(gsettings list-schemas)"; grep -Fxq "$1" <<<"$all"; }
key_exists(){ local keys; setting_exists "$1" || return 1; keys="$(gsettings list-keys "$1")"; grep -Fxq "$2" <<<"$keys"; }

# Snapshot of every key any module may manage; kept as evidence only, restore uses the ledger.
backup_settings(){
  local dir schema key
  dir="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dir"; chmod 700 "$dir"
  while read -r schema key; do
    key_exists "$schema" "$key" && printf '%s\t%s\t%s\n' "$schema" "$key" "$(gsettings get "$schema" "$key")"
  done > "$dir/settings.tsv" <<'EOF'
org.gnome.desktop.interface gtk-theme
org.gnome.desktop.interface icon-theme
org.gnome.desktop.interface cursor-theme
org.gnome.desktop.interface color-scheme
org.gnome.desktop.background picture-uri
org.gnome.desktop.background picture-uri-dark
org.gnome.desktop.wm.preferences button-layout
org.gnome.shell.extensions.user-theme name
org.gnome.shell enabled-extensions
EOF
  gsettings list-recursively org.gnome.shell.extensions.dash-to-dock >> "$dir/settings.tsv" 2>/dev/null || true
  log "Settings snapshot saved: $dir"
}

ledger_has(){ awk -F'\t' -v m="$1" -v s="$2" -v k="$3" '$1==m && $2==s && $3==k {f=1} END {exit !f}' "$LEDGER"; }
ledger_owner(){ awk -F'\t' -v s="$1" -v k="$2" '$2==s && $3==k {print $1; exit}' "$LEDGER"; }

# set_setting MODULE SCHEMA KEY VALUE [ALTERNATIVE...]
# Records the original value the first time a key is taken over. Alternatives are other values this
# project may legitimately write later (e.g. the dark variant), so uninstall still recognises them.
set_setting(){
  local module="$1" schema="$2" key="$3" value="$4" current applied owner
  shift 4
  applied="$value"; local alt; for alt in "$@"; do applied+="|$alt"; done
  if ! key_exists "$schema" "$key"; then log "SKIP: $schema $key is unavailable on this system"; return 0; fi
  current="$(gsettings get "$schema" "$key")"
  owner="$(ledger_owner "$schema" "$key")"
  if [[ -n "$owner" && "$owner" != "$module" ]]; then die "$schema $key is already owned by module '$owner'"; fi
  if [[ -z "$owner" ]]; then
    # Keys still at their schema default are recorded as @default and reset (not rewritten) on uninstall.
    local original="$current"
    [[ -n "$(dconf read "/${schema//.//}/$key" 2>/dev/null)" ]] || original="@default"
    printf '%s\t%s\t%s\t%s\t%s\n' "$module" "$schema" "$key" "$original" "$applied" >> "$LEDGER"
  else
    awk -F'\t' -v OFS='\t' -v m="$module" -v s="$schema" -v k="$key" -v a="$applied" \
      '$1==m && $2==s && $3==k {$5=a} {print}' "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
  fi
  if [[ "$current" == "$value" ]]; then log "UNCHANGED: $schema $key=$value"; return 0; fi
  log "SET: $schema $key: $current -> $value"
  gsettings set "$schema" "$key" "$value"
}

# Restores keys owned by MODULE, but only where the current value is still one this project wrote.
restore_module_settings(){
  local module="$1" m schema key original applied current
  [[ -s "$LEDGER" ]] || return 0
  while IFS=$'\t' read -r m schema key original applied; do
    [[ "$m" == "$module" ]] || continue
    if ! key_exists "$schema" "$key"; then log "SKIP restore: $schema $key no longer exists"; continue; fi
    current="$(gsettings get "$schema" "$key")"
    if [[ "|$applied|" == *"|$current|"* ]]; then
      if [[ "$original" == "@default" ]]; then
        log "RESET: $schema $key (back to the system default)"
        gsettings reset "$schema" "$key"
      else
        log "RESTORE: $schema $key=$original"
        gsettings set "$schema" "$key" "$original"
      fi
    else
      log "KEEP: $schema $key was changed after install ($current); leaving the user's value"
    fi
  done < "$LEDGER"
  awk -F'\t' -v m="$module" '$1!=m' "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
}

own_path(){ local module="$1" path="$2" list="$FILES_DIR/$1.list"; touch "$list"; grep -Fxq "$path" "$list" || printf '%s\n' "$path" >> "$list"; }
owns_path(){ [[ -f "$FILES_DIR/$1.list" ]] && grep -Fxq "$2" "$FILES_DIR/$1.list"; }

# Moves a pre-existing path we did not create out of the way so uninstall can put it back.
displace_path(){
  local module="$1" path="$2" target
  [[ -e "$path" || -L "$path" ]] || return 0
  owns_path "$module" "$path" && return 0
  target="$DISPLACED_DIR/$module$path"
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  mv "$path" "$target"
  log "DISPLACED existing $path (restored on uninstall)"
}

# Installs a directory tree at DEST owned by MODULE (replacing a previous copy we own).
install_tree(){
  local module="$1" src="$2" dest="$3"
  displace_path "$module" "$dest"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  own_path "$module" "$dest"
}

# Removes paths owned by MODULE, restores displaced files and disables enabled extensions.
remove_module_files(){
  local module="$1" list="$FILES_DIR/$1.list" path
  [[ -f "$list" ]] || return 0
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ "$path" == ext:* ]]; then
      disable_extension "${path#ext:}"
      continue
    fi
    rm -rf "$path"
    log "REMOVED: $path"
    if [[ -e "$DISPLACED_DIR/$module$path" || -L "$DISPLACED_DIR/$module$path" ]]; then
      mkdir -p "$(dirname "$path")"
      mv "$DISPLACED_DIR/$module$path" "$path"
      log "RESTORED original: $path"
    fi
  done < <(tac "$list")
  rm -f "$list"
}

enabled_extensions(){ gsettings get org.gnome.shell enabled-extensions 2>/dev/null; }
extension_installed(){
  [[ -f "$DATA_HOME/gnome-shell/extensions/$1/metadata.json" || -f "$SYSTEM_EXTENSIONS_DIR/$1/metadata.json" ]]
}
# Adds UUID to org.gnome.shell enabled-extensions (works even before the shell has rescanned).
enable_extension(){
  local module="$1" uuid="$2" current
  current="$(enabled_extensions)"
  if [[ "$current" != *"'$uuid'"* ]]; then
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then current="['$uuid']"; else current="${current%]}, '$uuid']"; fi
    gsettings set org.gnome.shell enabled-extensions "$current"
    log "ENABLED extension: $uuid"
    own_path "$module" "ext:$uuid"
  else
    log "UNCHANGED: extension already enabled: $uuid"
  fi
}
disable_extension(){
  local uuid="$1" current
  current="$(enabled_extensions)" || return 0
  [[ "$current" == *"'$uuid'"* ]] || return 0
  current="$(printf '%s' "$current" | sed -e "s/, '$uuid'//; s/'$uuid', //; s/'$uuid'//")"
  [[ "$current" == "[]" ]] && current="@as []"
  # Prefer the system default when it already equals the desired list, so no override is left behind.
  dconf reset /org/gnome/shell/enabled-extensions 2>/dev/null || true
  [[ "$(enabled_extensions)" == "$current" ]] || gsettings set org.gnome.shell enabled-extensions "$current"
  log "DISABLED extension: $uuid"
}

# fetch_pinned NAME URL SHA256 -> prints the path of a verified cached download.
fetch_pinned(){
  local name="$1" url="$2" sha="$3" file
  file="$CACHE_DIR/downloads/$sha-$name"
  local attempt
  for attempt in cached fresh; do
    if [[ ! -f "$file" ]]; then
      attempt=fresh
      require_command curl
      log "DOWNLOAD: $name from $url"
      curl -fsSL --retry 3 --connect-timeout 20 -o "$file.part" "$url" \
        || { rm -f "$file.part"; die "Download failed: $url (check your internet connection and run the installer again)"; }
      mv "$file.part" "$file"
    fi
    if printf '%s  %s\n' "$sha" "$file" | sha256sum -c --status; then printf '%s\n' "$file"; return 0; fi
    rm -f "$file"
    [[ "$attempt" == fresh ]] && die "Checksum mismatch for $name (expected $sha); refusing to install"
    log "Cached $name is corrupted; downloading it again"
  done
}

# extract_pinned NAME URL SHA256 -> prints a fresh directory holding the archive's top-level folder.
extract_pinned(){
  local archive work
  archive="$(fetch_pinned "$@")"
  work="$(mktemp -d "$CACHE_DIR/work.XXXXXX")"
  tar -xzf "$archive" -C "$work"
  find "$work" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

# Values consumed by the light/dark sync service (see src/modules/appearance/theme-sync.sh).
sync_set(){
  local key="$1" value="$2"
  touch "$SYNC_CONF"
  grep -v "^$key=" "$SYNC_CONF" > "$SYNC_CONF.tmp" || true
  printf '%s=%q\n' "$key" "$value" >> "$SYNC_CONF.tmp"
  mv "$SYNC_CONF.tmp" "$SYNC_CONF"
}
sync_unset(){ local k; [[ -f "$SYNC_CONF" ]] || return 0; for k in "$@"; do grep -v "^$k=" "$SYNC_CONF" > "$SYNC_CONF.tmp" || true; mv "$SYNC_CONF.tmp" "$SYNC_CONF"; done; }
is_dark(){ [[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" == "'prefer-dark'" ]]; }

mark_installed(){ grep -Fxq "$1" "$INSTALLED" 2>/dev/null || printf '%s\n' "$1" >> "$INSTALLED"; }
mark_removed(){ [[ -f "$INSTALLED" ]] || return 0; grep -Fxv "$1" "$INSTALLED" > "$INSTALLED.tmp" || true; mv "$INSTALLED.tmp" "$INSTALLED"; }
installed_modules(){ [[ -f "$INSTALLED" ]] && cat "$INSTALLED"; }

run_module(){
  local name="$1" action="$2" file
  file="$ROOT/src/modules/$name/module.sh"
  [[ -f "$file" ]] || die "Module implementation missing: $name"
  # shellcheck source=/dev/null
  source "$file"
  "${name}_module" "$action"
}

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/core/common.sh
source "$ROOT/src/core/common.sh"

profile="tahoe"; module=""; dry_run=0; list_modules=0; assume_yes=0; reset_first=0
usage() { cat <<EOF2
Usage: ./install.sh [--profile NAME] [--module NAME] [--dry-run] [--yes] [--list-modules]

  --yes     install any missing Ubuntu packages without asking (uses sudo apt)
  --reset   first reset the desktop's appearance to Ubuntu defaults (themes, extensions, dock,
            custom GTK CSS), keeping a backup: ./scripts/reset-appearance.sh --restore

Profiles: $(list_profiles | xargs) (default: tahoe; "full" is an alias of tahoe)
Modules:  ${MODULES[*]}
EOF2
}
while (($#)); do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || die "--profile requires a value"; profile="$2"; shift 2 ;;
    --module) [[ $# -ge 2 ]] || die "--module requires a value"; module="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -y|--yes) assume_yes=1; shift ;;
    --reset) reset_first=1; shift ;;
    --list-modules) list_modules=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
if ((list_modules)); then printf '%s\n' "${MODULES[@]}"; exit 0; fi
[[ $EUID -ne 0 ]] || die "Run as your normal user, not root; Ubuntu Tahoe only changes your own account."
if [[ -n "$module" ]]; then
  valid_module "$module" || die "Unknown module: $module"
  modules=("$module")
else
  mapfile -t modules < <(profile_modules "$profile") || true
  ((${#modules[@]})) || die "Unknown or empty profile: $profile (available: $(list_profiles | xargs))"
fi
require_command gsettings
require_command dconf
check_session
mapfile -t missing < <(missing_packages "${modules[@]}")
if ((${#missing[@]})) && ! ((dry_run)); then
  log "These Ubuntu packages are needed first: ${missing[*]}"
  answer=n
  if ((assume_yes)); then answer=y
  elif [[ -t 0 ]]; then read -r -p "[ubuntu-tahoe] Install them now with sudo apt? [Y/n] " answer; answer="${answer:-y}"; fi
  [[ "$answer" == [yY]* ]] || die "Install them with: sudo apt install ${missing[*]}   (then run ./install.sh again)"
  { sudo apt-get update -q && sudo apt-get install -y "${missing[@]}"; } || die "Package installation failed"
fi
if ((reset_first)); then
  if ((dry_run)); then "$ROOT/scripts/reset-appearance.sh" --dry-run; else "$ROOT/scripts/reset-appearance.sh"; fi
fi
if ((dry_run)); then
  ((${#missing[@]} == 0)) || log "Would first ask to install: sudo apt install ${missing[*]}"
  log "DRY RUN: no changes will be made. Profile=$profile Modules=${modules[*]}"
  for m in "${modules[@]}"; do run_module "$m" plan; done
  exit 0
fi
ensure_state_dirs
backup_settings
was_installed="$(installed_modules || true)"
current=""
rollback_on_error() {
  rc=$?
  trap - ERR
  log "Installation failed in module '${current:-?}' (exit $rc); undoing modules installed by this run."
  for m in "${modules[@]}"; do
    grep -Fxq "$m" <<<"$was_installed" && continue
    run_module "$m" remove || log "WARNING: rollback of '$m' was incomplete; see $STATE_DIR"
    mark_removed "$m"
    [[ "$m" == "$current" ]] && break
  done
  exit "$rc"
}
trap rollback_on_error ERR
for m in "${modules[@]}"; do
  current="$m"
  run_module "$m" apply
  mark_installed "$m"
done
trap - ERR
printf '%s\n' "$(date -Is)" > "$STATE_DIR/last-success"
log "Installed: ${modules[*]}. Undo with ./uninstall.sh --all (or --module NAME)."
if [[ " ${modules[*]} " == *" blur "* ]]; then log "Log out and back in once so GNOME Shell loads Blur My Shell."; fi

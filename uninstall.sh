#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/core/common.sh
source "$ROOT/src/core/common.sh"
module=""; restore_all=0; dry_run=0
usage(){ cat <<EOF2
Usage: ./uninstall.sh (--module NAME | --all) [--dry-run]

Removes files installed by Ubuntu Tahoe and restores the original value of every setting it changed,
unless you changed that setting yourself afterwards. It never resets all of dconf.
--restore-backup is accepted as an alias of --all.
Modules: ${MODULES[*]}
EOF2
}
while (($#)); do
 case "$1" in
  --module) [[ $# -ge 2 ]] || die "--module requires a value"; module="$2"; shift 2 ;;
  --all|--restore-backup) restore_all=1; shift ;;
  --dry-run) dry_run=1; shift ;;
  -h|--help) usage; exit 0 ;;
  *) die "Unknown argument: $1" ;;
 esac
done
[[ -n "$module" || $restore_all -eq 1 ]] || { usage; die "Choose --module NAME or --all"; }
if [[ -n "$module" ]]; then valid_module "$module" || die "Unknown module: $module"; targets=("$module")
else mapfile -t targets < <(installed_modules | tac || true); fi
((${#targets[@]})) || { log "Nothing is installed; no changes made."; exit 0; }
if ((dry_run)); then
  log "DRY RUN: would remove ${targets[*]}; no changes made."
  for m in "${targets[@]}"; do
    awk -F'\t' -v m="$m" '$1==m {printf "  restore %s %s -> %s\n", $2, $3, $4}' "$LEDGER" 2>/dev/null >&2 || true
    [[ -f "$FILES_DIR/$m.list" ]] && sed 's/^/  remove /' "$FILES_DIR/$m.list" >&2
  done
  exit 0
fi
ensure_state_dirs
for m in "${targets[@]}"; do
  log "Removing module: $m"
  run_module "$m" remove
  mark_removed "$m"
done
log "Uninstall finished. Log out and back in if the shell theme or extensions still look applied."

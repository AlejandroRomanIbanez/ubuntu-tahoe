#!/usr/bin/env bash
# cursor: MacTahoe cursors (black macOS-style pointer, shipped inside the MacTahoe icon repository).
# shellcheck source=src/core/components.sh
source "$ROOT/src/core/components.sh"

cursor_module(){
  local action="$1" src dest="$DATA_HOME/icons/MacTahoe-cursors"
  case "$action" in
    plan)
      log "cursor: would install MacTahoe-cursors from MacTahoe icon theme $MACTAHOE_ICON_VERSION into $dest and select it (24 px)"
      ;;
    apply)
      src="$(extract_pinned "MacTahoe-icon-theme-$MACTAHOE_ICON_VERSION.tar.gz" "$MACTAHOE_ICON_URL" "$MACTAHOE_ICON_SHA256")"
      [[ -f "$src/cursors/dist/index.theme" ]] || die "MacTahoe cursor assets not found in archive"
      install_tree cursor "$src/cursors/dist" "$dest"
      rm -rf "$(dirname "$src")"
      log "INSTALLED: $dest"
      set_setting cursor org.gnome.desktop.interface cursor-theme "'MacTahoe-cursors'"
      set_setting cursor org.gnome.desktop.interface cursor-size "24"
      ;;
    remove)
      restore_module_settings cursor
      remove_module_files cursor
      ;;
    *) die "Unknown cursor action: $action";;
  esac
}

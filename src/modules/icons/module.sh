#!/usr/bin/env bash
# icons: MacTahoe icon theme. Light style uses MacTahoe-light (dark symbolic icons for the light
# top bar); dark style uses MacTahoe-dark. The appearance sync service switches between them.
# shellcheck source=src/core/components.sh
source "$ROOT/src/core/components.sh"
ICONS_THEMES=(MacTahoe MacTahoe-light MacTahoe-dark)

icons_module(){
  local action="$1" src sandbox theme
  case "$action" in
    plan)
      log "icons: would install MacTahoe icon theme $MACTAHOE_ICON_VERSION (sha256 ${MACTAHOE_ICON_SHA256:0:12}…) into $DATA_HOME/icons/{${ICONS_THEMES[*]// /,}}"
      ;;
    apply)
      require_command gtk-update-icon-cache
      src="$(extract_pinned "MacTahoe-icon-theme-$MACTAHOE_ICON_VERSION.tar.gz" "$MACTAHOE_ICON_URL" "$MACTAHOE_ICON_SHA256")"
      sandbox="$(mktemp -d "$CACHE_DIR/build.XXXXXX")"
      (cd "$src" && HOME="$sandbox" ./install.sh -d "$sandbox/icons" < /dev/null > "$STATE_DIR/mactahoe-icons-build.log" 2>&1) \
        || die "MacTahoe icon install failed; see $STATE_DIR/mactahoe-icons-build.log"
      for theme in "${ICONS_THEMES[@]}"; do
        [[ -f "$sandbox/icons/$theme/index.theme" ]] || die "MacTahoe icon build did not produce $theme"
        install_tree icons "$sandbox/icons/$theme" "$DATA_HOME/icons/$theme"
        gtk-update-icon-cache -q -f "$DATA_HOME/icons/$theme" 2>/dev/null || true
        log "INSTALLED: $DATA_HOME/icons/$theme"
      done
      rm -rf "$sandbox" "$(dirname "$src")"
      if is_dark; then theme=MacTahoe-dark; else theme=MacTahoe-light; fi
      set_setting icons org.gnome.desktop.interface icon-theme "'$theme'" "'MacTahoe-light'" "'MacTahoe-dark'"
      sync_set ICON_LIGHT MacTahoe-light
      sync_set ICON_DARK MacTahoe-dark
      ;;
    remove)
      sync_unset ICON_LIGHT ICON_DARK
      restore_module_settings icons
      remove_module_files icons
      ;;
    *) die "Unknown icons action: $action";;
  esac
}

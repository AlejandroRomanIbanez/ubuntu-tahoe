#!/usr/bin/env bash
# wallpaper: MacTahoe day (light style) and night (dark style) wallpapers. GNOME switches between
# picture-uri and picture-uri-dark by itself when the style changes.
# shellcheck source=src/core/components.sh
source "$ROOT/src/core/components.sh"

wallpaper_module(){
  local action="$1" src dest="$DATA_HOME/backgrounds/ubuntu-tahoe"
  case "$action" in
    plan)
      log "wallpaper: would copy MacTahoe-day/night.jpeg from MacTahoe GTK theme $MACTAHOE_GTK_VERSION into $dest and set light/dark wallpapers"
      ;;
    apply)
      src="$(extract_pinned "MacTahoe-gtk-theme-$MACTAHOE_GTK_VERSION.tar.gz" "$MACTAHOE_GTK_URL" "$MACTAHOE_GTK_SHA256")"
      [[ -f "$src/wallpaper/MacTahoe-day.jpeg" && -f "$src/wallpaper/MacTahoe-night.jpeg" ]] || die "MacTahoe wallpapers not found in archive"
      install_tree wallpaper "$src/wallpaper" "$dest"
      rm -rf "$(dirname "$src")"
      set_setting wallpaper org.gnome.desktop.background picture-uri "'file://$dest/MacTahoe-day.jpeg'"
      set_setting wallpaper org.gnome.desktop.background picture-uri-dark "'file://$dest/MacTahoe-night.jpeg'"
      set_setting wallpaper org.gnome.desktop.background picture-options "'zoom'"
      ;;
    remove)
      restore_module_settings wallpaper
      remove_module_files wallpaper
      ;;
    *) die "Unknown wallpaper action: $action";;
  esac
}

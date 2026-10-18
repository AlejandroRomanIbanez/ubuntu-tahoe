#!/usr/bin/env bash
# blur: Blur My Shell (pinned, checksum-verified) for the translucent Tahoe top bar, overview and dock.
# GNOME Shell loads newly installed extensions only after logging out and in again.
# shellcheck source=src/core/components.sh
source "$ROOT/src/core/components.sh"

blur_module(){
  local action="$1" zip work dest="$DATA_HOME/gnome-shell/extensions/$BLUR_MY_SHELL_UUID"
  case "$action" in
    plan)
      log "blur: would install Blur My Shell v$BLUR_MY_SHELL_VERSION (sha256 ${BLUR_MY_SHELL_SHA256:0:12}…) into $dest and enable it (takes effect after next login)"
      ;;
    apply)
      require_command unzip
      zip="$(fetch_pinned "blur-my-shell-v$BLUR_MY_SHELL_VERSION.zip" "$BLUR_MY_SHELL_URL" "$BLUR_MY_SHELL_SHA256")"
      work="$(mktemp -d "$CACHE_DIR/work.XXXXXX")"
      unzip -q "$zip" -d "$work/$BLUR_MY_SHELL_UUID"
      grep -q "\"$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1)\"" "$work/$BLUR_MY_SHELL_UUID/metadata.json" \
        || die "Blur My Shell v$BLUR_MY_SHELL_VERSION does not declare support for this GNOME Shell; not forcing compatibility"
      if [[ -d "$work/$BLUR_MY_SHELL_UUID/schemas" ]]; then glib-compile-schemas "$work/$BLUR_MY_SHELL_UUID/schemas"; fi
      install_tree blur "$work/$BLUR_MY_SHELL_UUID" "$dest"
      rm -rf "$work"
      log "INSTALLED: $dest"
      blur_configure
      enable_extension blur "$BLUR_MY_SHELL_UUID"
      log "blur: log out and back in to load Blur My Shell (GNOME Shell cannot load new extensions live)."
      ;;
    remove)
      if [[ -d "$dest/schemas" ]]; then GSETTINGS_SCHEMA_DIR="$dest/schemas" restore_module_settings blur; fi
      # Blur My Shell writes its own settings at runtime; clear them only if we installed it fresh.
      if [[ ! -e "$DISPLACED_DIR/blur$dest" ]] && owns_path blur "$dest"; then dconf reset -f /org/gnome/shell/extensions/blur-my-shell/; fi
      remove_module_files blur
      ;;
    *) die "Unknown blur action: $action";;
  esac
}

# MacTahoe's recommended Blur My Shell setup: no panel blur (the theme has its own translucent bar),
# no popup blur (it draws a square grey backdrop behind the theme's rounded light/dark glass), and
# blur pipelines at full brightness so the dock and overview are not tinted grey.
blur_configure(){
  local b=org.gnome.shell.extensions.blur-my-shell pipelines
  export GSETTINGS_SCHEMA_DIR="$DATA_HOME/gnome-shell/extensions/$BLUR_MY_SHELL_UUID/schemas"
  set_setting blur "$b.panel" blur "false"
  set_setting blur "$b.popup" blur "false"
  set_setting blur "$b.overview" style-components "0"
  pipelines="$(gsettings get "$b" pipelines)"
  set_setting blur "$b" pipelines "${pipelines//<0.59999999999999998>/<1.0>}"
  unset GSETTINGS_SCHEMA_DIR
}

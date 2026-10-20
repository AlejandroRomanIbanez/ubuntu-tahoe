#!/usr/bin/env bash
# appearance: MacTahoe GTK 3/4 + GNOME Shell theme (light and dark), libadwaita styling,
# macOS-style window buttons, and the light/dark sync service.
# shellcheck source=src/core/components.sh
source "$ROOT/src/core/components.sh"

APPEARANCE_THEMES=(MacTahoe-Light MacTahoe-Dark)
APPEARANCE_SYNC_BIN="$HOME/.local/bin/ubuntu-tahoe-theme-sync"
APPEARANCE_UNIT="$CONFIG_HOME/systemd/user/ubuntu-tahoe-theme-sync.service"

appearance_missing_prereqs(){
  local missing=()
  command -v sassc >/dev/null 2>&1 || missing+=(sassc)
  command -v glib-compile-resources >/dev/null 2>&1 || missing+=(libglib2.0-dev-bin)
  extension_installed "$USER_THEME_UUID" || missing+=(gnome-shell-extensions)
  printf '%s\n' "${missing[@]}"
}

appearance_module(){
  local action="$1" missing theme
  case "$action" in
    plan)
      log "appearance: would build MacTahoe GTK theme $MACTAHOE_GTK_VERSION (sha256 ${MACTAHOE_GTK_SHA256:0:12}…) into ~/.themes/{${APPEARANCE_THEMES[*]// /,}}"
      log "appearance: would enable the User Themes extension, link ~/.config/gtk-4.0 for libadwaita apps, set macOS-style window buttons, and start ubuntu-tahoe-theme-sync"
      missing="$(appearance_missing_prereqs | xargs)"
      if [[ -n "$missing" ]]; then log "appearance: MISSING prerequisites: sudo apt install $missing"; else log "appearance: prerequisites present"; fi
      ;;
    apply)
      missing="$(appearance_missing_prereqs | xargs)"
      [[ -z "$missing" ]] || die "appearance needs packages that this tool will not install for you. Run: sudo apt install $missing"
      appearance_install_theme
      enable_extension appearance "$USER_THEME_UUID"
      # Record originals before the sync service starts rewriting these keys.
      if is_dark; then theme=MacTahoe-Dark; else theme=MacTahoe-Light; fi
      set_setting appearance org.gnome.desktop.interface gtk-theme "'$theme'" "'MacTahoe-Light'" "'MacTahoe-Dark'"
      set_setting appearance org.gnome.shell.extensions.user-theme name "'$theme'" "'MacTahoe-Light'" "'MacTahoe-Dark'"
      set_setting appearance org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:appmenu'"
      appearance_install_sync
      if is_dark; then log "appearance: dark style active -> MacTahoe-Dark"; else log "appearance: light style active -> MacTahoe-Light"; fi
      ;;
    remove)
      systemctl --user disable --now ubuntu-tahoe-theme-sync.service >/dev/null 2>&1 || true
      sync_unset GTK_LIGHT GTK_DARK THEMES_DIR
      if command -v flatpak >/dev/null 2>&1; then
        flatpak override --user --unset-env=GTK_THEME --nofilesystem=xdg-config/gtk-4.0 --nofilesystem="$HOME/.themes" 2>/dev/null || true
      fi
      # Snap copies made by theme-sync carry a .ubuntu-tahoe marker.
      local marker
      for marker in "$HOME"/snap/*/current/.themes/*/.ubuntu-tahoe "$HOME"/snap/*/current/.config/gtk-4.0/.ubuntu-tahoe; do
        [[ -e "$marker" ]] || continue
        case "$marker" in
          */gtk-4.0/.ubuntu-tahoe) (cd "$(dirname "$marker")" && rm -rf gtk.css gtk-dark.css assets windows-assets .ubuntu-tahoe) ;;
          *) rm -rf "$(dirname "$marker")" ;;
        esac
      done
      restore_module_settings appearance
      remove_module_files appearance
      systemctl --user daemon-reload >/dev/null 2>&1 || true
      ;;
    *) die "Unknown appearance action: $action";;
  esac
}

appearance_install_theme(){
  local src sandbox theme item
  src="$(extract_pinned "MacTahoe-gtk-theme-$MACTAHOE_GTK_VERSION.tar.gz" "$MACTAHOE_GTK_URL" "$MACTAHOE_GTK_SHA256")"
  sandbox="$(mktemp -d "$CACHE_DIR/build.XXXXXX")"
  log "appearance: building MacTahoe for $(gnome-shell --version 2>/dev/null || echo 'unknown GNOME Shell') (takes ~1 min)"
  # Upstream writes helper apps into $HOME; run it against a throwaway HOME and copy only the themes.
  # Upstream's progress animation calls `setterm`, which fails without a terminal and trips its ERR
  # trap; shadow it with a no-op for the build only. Upstream also requires -d to exist already.
  mkdir -p "$sandbox/themes" "$sandbox/bin"
  printf '#!/bin/sh\nexit 0\n' > "$sandbox/bin/setterm"; chmod +x "$sandbox/bin/setterm"
  if ! (cd "$src" && HOME="$sandbox" PATH="$sandbox/bin:$PATH" ./install.sh -d "$sandbox/themes" -c light -c dark -o normal -t default \
        --shell -i ubuntu < /dev/null > "$STATE_DIR/mactahoe-build.log" 2>&1); then
    die "MacTahoe build failed; see $STATE_DIR/mactahoe-build.log"
  fi
  for theme in "${APPEARANCE_THEMES[@]}"; do
    [[ -f "$sandbox/themes/$theme/gnome-shell/gnome-shell.css" && -f "$sandbox/themes/$theme/gtk-4.0/gtk.css" ]] \
      || die "MacTahoe build did not produce $theme; see $STATE_DIR/mactahoe-build.log"
    install_tree appearance "$sandbox/themes/$theme" "$HOME/.themes/$theme"
    log "INSTALLED: ~/.themes/$theme"
  done
  rm -rf "$sandbox" "$(dirname "$src")"
  # libadwaita reads ~/.config/gtk-4.0; move any existing user files aside so we can link ours.
  for item in gtk.css gtk-dark.css assets windows-assets; do
    displace_path appearance "$CONFIG_HOME/gtk-4.0/$item"
    own_path appearance "$CONFIG_HOME/gtk-4.0/$item"
  done
  sync_set THEMES_DIR "$HOME/.themes"
  sync_set GTK_LIGHT MacTahoe-Light
  sync_set GTK_DARK MacTahoe-Dark
}

appearance_install_sync(){
  displace_path appearance "$APPEARANCE_SYNC_BIN"
  mkdir -p "$(dirname "$APPEARANCE_SYNC_BIN")" "$(dirname "$APPEARANCE_UNIT")"
  install -m 755 "$ROOT/src/modules/appearance/theme-sync.sh" "$APPEARANCE_SYNC_BIN"
  own_path appearance "$APPEARANCE_SYNC_BIN"
  displace_path appearance "$APPEARANCE_UNIT"
  cat > "$APPEARANCE_UNIT" <<EOF
[Unit]
Description=Ubuntu Tahoe light/dark theme sync
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=$APPEARANCE_SYNC_BIN
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF
  own_path appearance "$APPEARANCE_UNIT"
  if systemctl --user daemon-reload >/dev/null 2>&1; then
    systemctl --user enable ubuntu-tahoe-theme-sync.service >/dev/null 2>&1 || true
    systemctl --user restart ubuntu-tahoe-theme-sync.service >/dev/null 2>&1 || log "WARNING: could not start ubuntu-tahoe-theme-sync now; it starts at next login"
  else
    log "WARNING: no systemd user session; light/dark sync starts at next login"
  fi
}

#!/usr/bin/env bash
# dock: tunes the existing Ubuntu Dock into a centred, floating, macOS-style dock at the bottom.
# Never installs or enables another dock manager.
DOCK_SCHEMA="org.gnome.shell.extensions.dash-to-dock"

dock_module(){
  local action="$1" s="$DOCK_SCHEMA"
  case "$action" in
    plan)
      if setting_exists "$s"; then log "dock: Ubuntu Dock schema detected; would set a bottom, centred, non-extended dock with 48 px icons, dots and trash"; else log "dock: Ubuntu Dock schema unavailable; nothing would change and no competing dock would be installed."; fi
      ;;
    apply)
      if ! setting_exists "$s"; then log "SKIP dock: Ubuntu Dock schema unavailable."; return 0; fi
      set_setting dock "$s" dock-position "'BOTTOM'"
      set_setting dock "$s" extend-height "false"
      set_setting dock "$s" dock-fixed "true"
      set_setting dock "$s" autohide "false"
      set_setting dock "$s" intellihide "false"
      set_setting dock "$s" dash-max-icon-size "48"
      set_setting dock "$s" show-apps-at-top "false"
      set_setting dock "$s" show-trash "true"
      set_setting dock "$s" show-mounts "false"
      set_setting dock "$s" running-indicator-style "'DOTS'"
      set_setting dock "$s" custom-theme-shrink "true"
      ;;
    remove)
      restore_module_settings dock
      ;;
    *) die "Unknown dock action: $action";;
  esac
}

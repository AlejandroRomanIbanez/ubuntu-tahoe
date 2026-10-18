#!/usr/bin/env bash
set -u
printf '%s\n' '=== Ubuntu Tahoe diagnostics ==='
printf 'Date: '; date -Is
printf 'OS: '; . /etc/os-release 2>/dev/null; printf '%s %s\n' "${PRETTY_NAME:-unknown}" "${VERSION_ID:-}"
printf 'Desktop: %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
if command -v gnome-shell >/dev/null 2>&1; then gnome-shell --version; else echo 'gnome-shell: not found'; fi
if command -v gsettings >/dev/null 2>&1; then
  for key in gtk-theme icon-theme cursor-theme color-scheme; do printf '%s: ' "$key"; gsettings get org.gnome.desktop.interface "$key" 2>/dev/null || echo unavailable; done
  printf 'Enabled extensions: '; gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo unavailable
  if command -v gnome-extensions >/dev/null 2>&1; then gnome-extensions list --enabled 2>/dev/null || true; fi
fi
printf 'State directory: %s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/ubuntu-tahoe"

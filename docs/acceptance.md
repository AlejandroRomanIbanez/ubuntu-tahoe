# Acceptance criteria and evidence

Items are checked only with evidence from the target environment. Latest run: **2026-10-18**, evidence in [test-results/2026-10-18](test-results/2026-10-18/).

**Environment:** AWS EC2 `t3.xlarge`, eu-central-1, Canonical AMI `ami-04de259f26cbf4c1e` (`ubuntu-noble-24.04-amd64-server-20261017`, owner 099720109477), fully updated. `/etc/os-release`: **Ubuntu 24.04.5 LTS**. **GNOME Shell 46.0**, Xorg session, 1920×1080, scale 100 %, llvmpipe (no GPU).

- [x] Fresh Ubuntu 24.04.5 installation succeeds: `install.log`
- [x] Dry run causes no filesystem, settings, package, or extension changes: `dconf dump` identical before and after; no state, cache or files created (`dry-run.log`, offline tests)
- [x] Second install creates no unintended differences: `install-second-run.log` shows 0 settings changed
- [x] Ubuntu Dock is the sole active dock manager: `diagnose-installed.txt` (enabled extensions)
- [x] Light and dark modes visually reviewed: `sheet-light-*.jpg`, `sheet-dark-*.jpg` (26 views)
- [x] No overlapping panel/dock or missing icons in approved screenshots (same sheets, including a maximized window)
- [x] GTK/libadwaita differences documented with application versions: [gtk-libadwaita.md](gtk-libadwaita.md)
- [x] GNOME login and reboot verified: after a reboot the session auto-logged in, all extensions were active, the theme-sync service was running, and the journal had no shell errors
- [x] Lock/unlock: screen locked through logind, Tahoe-styled unlock prompt shown, unlocked with the password, theme intact
- [x] Wayland (Ubuntu's default session): headless Wayland GNOME Shell loads the Tahoe shell theme, User Themes, Blur My Shell and Ubuntu Dock with no JS errors (`wayland-check.log`, 6/6)
- [x] Robustness on the real desktop (`robustness.log`, 42/42, run twice back to back): no internet, interrupted install, corrupted download cache, pre-existing user `gtk.css`, rapid light/dark toggling, Ubuntu accent click, sync service crash, single-module removal, user-changed settings kept, nothing modified outside `$HOME`, installer refuses root
- [x] Fresh-PC packages: with `sassc`, `libglib2.0-dev-bin`, `gnome-shell-extensions` and `curl` removed, the installer lists exactly those four; without consent it stops with the `apt` command, with `--yes` it installs them and completes (`reset-install.log`)
- [x] Customised desktop: purple Yaru dark theme, dock left with autohide, Ubuntu Dock disabled and custom GTK 3 CSS. `./install.sh --reset --yes` produced a clean Tahoe desktop with all extensions active after login; `uninstall.sh --all` + `reset-appearance.sh --restore` brought the customised desktop back exactly (`reset-messy-before-and-after.jpg`)
- [x] Failure injection restores the original managed settings: offline tests "appearance refuses without prerequisites" and "failed install leaves settings untouched"; rollback undoes modules installed in the failing run
- [x] Uninstall preserves unrelated settings: after `uninstall.sh --all`, no Ubuntu Tahoe key remains in dconf and settings changed by the user after install are kept (`uninstall.log`, offline tests)
- [x] Test logs attached: `offline-tests.log` (38/38 on the Ubuntu host and on WSL), `robustness.log`, `wayland-check.log`, `version.txt`

## Visual review notes

- Window controls are macOS-style traffic lights on the left in GTK 3, GTK 4 and libadwaita apps.
- Dark Style switches the GTK, shell, libadwaita, icon theme and wallpaper together, both live and after a reboot.
- Quick settings use MacTahoe's translucent "glass", so their colour depends on what is behind them; this is by design.
- GNOME Terminal keeps Ubuntu's dark terminal profile in light mode (a Terminal profile setting, unchanged).
- The Settings "Network Unavailable" page in the screenshots is the test host (no NetworkManager on EC2), not the theme.

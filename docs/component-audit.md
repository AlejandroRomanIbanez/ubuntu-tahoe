# Component audit

Approved components are pinned in [src/core/components.sh](../src/core/components.sh). Changing a version requires updating the checksum, this file and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md), and re-running the AWS acceptance test.

| Component | Pin | SHA-256 | License | Install method | Uninstall | Status |
|---|---|---|---|---|---|---|
| MacTahoe GTK theme | tag `2026-09-10` (source archive) | `ee7078b798212c2284092f86bc5085d681e846f5e2b9bc8324b948f60e48f3d3` | MIT | Upstream `install.sh -c light -c dark -o normal -t default --shell -i ubuntu`, run with a throwaway `HOME`; only `MacTahoe-Light`/`MacTahoe-Dark` are copied to `~/.themes` | Directories removed from manifest | **Approved**, tested |
| MacTahoe wallpapers | same archive (`wallpaper/`) | same | MIT | Copied to `~/.local/share/backgrounds/ubuntu-tahoe` | Removed from manifest | **Approved**, tested |
| MacTahoe icon theme | tag `2026-09-10` (source archive) | `6330369e9e10a28cfc8da598ebf63a7204be705403519963ff84e1cb84719d35` | GPL-3.0 | Upstream `install.sh -d <sandbox>`; `MacTahoe`, `MacTahoe-light`, `MacTahoe-dark` copied to `~/.local/share/icons` | Removed from manifest | **Approved**, tested |
| MacTahoe cursors | same archive (`cursors/dist`) | same | GPL-3.0 | Prebuilt `dist` copied to `~/.local/share/icons/MacTahoe-cursors` | Removed from manifest | **Approved**, tested |
| Blur My Shell | v75 (`version_tag=76297`) | `0f57037869428558e7d712892e2cdd4c20a61929b936c0b99c938905ec9d0658` | GPL-3.0 | Zip extracted to `~/.local/share/gnome-shell/extensions/blur-my-shell@aunetx`; refused if `metadata.json` does not list the running Shell major | Extension disabled, directory and its settings removed | **Approved**, tested on GNOME 46 |
| User Themes | Ubuntu package `gnome-shell-extensions` | n/a | GPL-2.0+ | Enabled only | Disabled | **Approved** |
| Dock | Ubuntu Dock (pre-installed) | n/a | GPL-2.0+ | Settings only | Settings restored | **Approved** |
| WhiteSur GTK/icons/cursors | — | — | — | — | — | Superseded by MacTahoe (same author; MacTahoe is the Tahoe-specific successor) |
| Open Bar | — | — | — | — | — | Not used |


## Upstream behaviours handled by the installer

- **MacTahoe `install.sh`** writes a `gnome-theme-switcher` app into `$HOME/.local/bin`. It is run with a sandbox `HOME`, so nothing outside the theme directories reaches the user's home.
- **MacTahoe `install.sh`** calls `setterm` for its progress animation. Without a terminal this fails and trips upstream's `ERR` trap. A no-op `setterm` is placed on `PATH` for the build only.
- **MacTahoe `install.sh`** runs `sudo apt install sassc` if `sassc` is missing. Our installer checks prerequisites first and installs missing Ubuntu packages only after the user agrees (or with `--yes`), so upstream never reaches `sudo`.
- **MacTahoe `--silent-mode`** requires root, so it is not used.
- **Prebuilt release tarballs** in the MacTahoe repository target GNOME Shell 48 and are not used. The shell theme is built for the running Shell version.
- **Blur My Shell defaults** (popup blur, panel blur, 0.6 brightness) put a square grey backdrop behind MacTahoe's rounded quick-settings panel and tint the dock. The `blur` module applies MacTahoe's recommended configuration instead: panel and popup blur off, pipelines at brightness 1.0, overview components unstyled.

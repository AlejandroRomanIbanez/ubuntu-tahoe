# GTK and libadwaita compatibility notes

GTK 3 apps follow the selected GTK theme. libadwaita apps (most GNOME 46 core apps) ignore the GTK theme setting and only read user CSS from `~/.config/gtk-4.0/`. Ubuntu Tahoe therefore links the active MacTahoe variant's `gtk.css`, `gtk-dark.css`, `assets/` and `windows-assets/` into that folder. `windows-assets/` holds the traffic-light buttons; without it libadwaita windows show no window controls at all.

The `ubuntu-tahoe-theme-sync` user service relinks these files when the style changes. libadwaita apps that are already open pick up the new CSS when they are reopened.

If you already had your own files in `~/.config/gtk-4.0`, they are moved to `~/.local/state/ubuntu-tahoe/displaced/` and restored on uninstall. The sync service never overwrites a regular (non-link) file it did not create.

## Visual report (2026-10-18, Ubuntu 24.04.5, GNOME 46, 100 % scale)

Toolkits: GTK 3.24.41, GTK 4.14.5, libadwaita 1.5.0, GNOME Shell 46.0.

| App | Toolkit | Package version (noble) | Light | Dark |
|---|---|---|---|---|
| Files (Nautilus) | GTK 4 / libadwaita | 46.4 | Themed, traffic lights | Themed, traffic lights |
| Text Editor | GTK 4 / libadwaita | 46.3 | Themed, traffic lights | Themed, traffic lights |
| Settings | GTK 4 / libadwaita | 46.7 | Themed, traffic lights | Themed, traffic lights |
| Calculator | GTK 4 / libadwaita | 46.3 | Themed, blue accent | Themed, blue accent |
| Terminal | GTK 3 | 3.52.0 | Header bar themed; terminal body uses its own profile | Themed |
| File chooser, dialog (zenity) | GTK 4 / libadwaita | 4.0.1 | Themed | Themed |

Screenshots: [test-results/2026-10-18](test-results/2026-10-18/).

## Known differences

- App-level colour schemes (Terminal profiles, gedit/Text Editor syntax schemes) are app settings, not part of the GTK theme.
- Snap and Flatpak apps use their own runtimes and may not pick up the theme. Firefox (snap) keeps its own look.
- Ubuntu's accent colour picker changes Yaru only; MacTahoe uses its own blue accent.
- No unsupported CSS injection or patching of system app assets is used.

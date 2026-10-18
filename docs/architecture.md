# Architecture

## Runtime flow

`parse CLI -> resolve profile/modules -> check (read-only) -> snapshot settings -> apply each module -> record state`

- **Profiles** are read from `config/profiles/<name>.yaml` (`modules:` list).
- **Modules** live in `src/modules/<name>/module.sh` and implement `plan`, `apply` and `remove`.
- **Pinned components** (URL + SHA-256) live in `src/core/components.sh`. `fetch_pinned` downloads into `~/.cache/ubuntu-tahoe/downloads`, verifies the checksum, and refuses mismatches.

## State (`~/.local/state/ubuntu-tahoe`, mode 700)

| File | Purpose |
|---|---|
| `ledger.tsv` | One row per managed key: `module, schema, key, original, applied values`. The original is recorded only the first time a key is taken over, so reinstalls never overwrite it. Keys that were at their default are recorded as `@default` |
| `files/<module>.list` | Paths (and `ext:<uuid>` entries) the module owns |
| `displaced/<module>/…` | Pre-existing user files moved aside before being replaced |
| `theme-sync.conf` | Light/dark theme pairs for the sync service |
| `installed` | Installed modules, in order |
| `backups/<timestamp>/settings.tsv` | Snapshot of relevant keys before each install (evidence only) |

## Uninstall

For each key owned by the module, the original value is restored only if the current value is still one this tool wrote; otherwise the user's value is kept. `@default` keys are reset rather than rewritten. Owned files are deleted in reverse order, displaced files are moved back, and extensions this tool enabled are disabled.

## Light/dark sync

`ubuntu-tahoe-theme-sync` (a systemd user service bound to `graphical-session.target`) watches `color-scheme`, `gtk-theme` and `icon-theme`. It sets the matching GTK theme, User Themes shell theme and icon theme, and relinks `~/.config/gtk-4.0` for libadwaita. The wallpaper switches through GNOME's own `picture-uri` / `picture-uri-dark`.

## Trust boundaries

- Third-party code runs only from checksum-verified archives. The upstream theme builders run against a throwaway `HOME`.
- Runs as the user. `sudo` is used only to `apt install` missing Ubuntu packages, after the user agrees (or with `--yes`). No system files, no GDM changes.
- Terraform under `infra/aws` is separate and opt-in.

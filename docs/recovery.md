# Recovery guide

1. Run `./scripts/diagnose.sh` and keep the output.
2. From a working GNOME session, run `./uninstall.sh --all` (or `--module NAME` for one part).
3. Log out and back in so GNOME Shell drops the shell theme and Blur My Shell.
4. If GNOME is unusable, switch to a text console (`Ctrl`+`Alt`+`F3`), log in, and run:
   ```bash
   gsettings set org.gnome.shell disable-user-extensions true   # starts GNOME without user extensions
   cd ~/ubuntu-tahoe && ./uninstall.sh --all
   gsettings set org.gnome.shell disable-user-extensions false
   sudo systemctl restart gdm   # or reboot
   ```
5. Do not run broad `dconf reset -f /` commands. They erase all of your settings, not only this project's.

The ledger of original values is `~/.local/state/ubuntu-tahoe/ledger.tsv`, and any of your files that were replaced are under `~/.local/state/ubuntu-tahoe/displaced/`. Keep this directory until you have confirmed recovery.

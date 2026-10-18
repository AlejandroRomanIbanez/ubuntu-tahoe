# AWS desktop test host (opt-in)

Provisions one disposable EC2 instance running stock Ubuntu 24.04 (Canonical's current image, fully updated; 24.04.5 at the time of writing) with the Ubuntu GNOME desktop. The `ubuntu` user is auto-logged into a GNOME Xorg session on a virtual 1920×1080 display. Costs apply while it runs (`t3.xlarge` is about $0.19/hour in eu-central-1).

- **SSH**: open only to `trusted_cidr` (your IP `/32`; `0.0.0.0/0` is rejected).
- **VNC**: listens on the instance's loopback only. Reach it through an SSH tunnel. No remote-desktop port is exposed.
- **Key**: if `key_name` is empty, a disposable key is generated at `./ubuntu-tahoe-test.pem` (gitignored).
- **Bootstrap**: [../bootstrap/desktop.sh](../bootstrap/desktop.sh). It takes about 5 minutes, then the host reboots into the desktop.

```bash
cp terraform.tfvars.example terraform.tfvars   # set trusted_cidr to "$(curl -s https://checkip.amazonaws.com)/32"
terraform init
terraform apply
terraform output                               # ssh and VNC tunnel commands
```

## Run the tests on the host

From the repository root (`HOST` = `terraform output -raw public_ip`, `KEY` = path to the `.pem`; on WSL, copy the key to a Linux path and `chmod 600` it first):

```bash
tests/desktop/remote.sh HOST KEY './tests/run.sh'                      # offline tests on Ubuntu
tests/desktop/remote.sh HOST KEY './install.sh --dry-run'
tests/desktop/remote.sh HOST KEY './install.sh'
ssh -i KEY ubuntu@HOST 'sudo systemctl restart gdm'                     # log in again so Blur My Shell loads
tests/desktop/remote.sh HOST KEY 'tests/desktop/capture.sh ~/shots both' # light + dark screenshots
tests/desktop/remote.sh HOST KEY --pull /home/ubuntu/shots ./shots       # sheet-*.jpg are contact sheets
tests/desktop/remote.sh HOST KEY 'tests/desktop/showcase.sh ~/show light'   # every feature, incl. close-ups
tests/desktop/remote.sh HOST KEY 'tests/desktop/robustness.sh'          # 42 failure/recovery scenarios (test host only)
tests/desktop/remote.sh HOST KEY 'tests/desktop/wayland-check.sh'       # Tahoe under a Wayland session
tests/desktop/remote.sh HOST KEY './uninstall.sh --all'
```

To look at the desktop yourself, run the `vnc_tunnel_command` output and open a VNC viewer on `localhost:5900`.

## Tear down

```bash
terraform destroy
```

Terraform state contains infrastructure metadata. Keep it out of Git (already in `.gitignore`).

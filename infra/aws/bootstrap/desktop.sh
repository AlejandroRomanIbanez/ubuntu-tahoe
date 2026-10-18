#!/usr/bin/env bash
# EC2 user-data for the disposable Ubuntu Tahoe test host.
# Installs the stock Ubuntu GNOME desktop (with Ubuntu Dock), auto-logs the "ubuntu" user into an
# Xorg session on a GPU-less dummy display, and exposes that session over VNC on loopback only
# (reach it through an SSH tunnel). Progress: /var/log/ubuntu-tahoe-bootstrap.log; done marker:
# /var/lib/ubuntu-tahoe/bootstrap-done.
set -Eeuo pipefail
exec > >(tee -a /var/log/ubuntu-tahoe-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y full-upgrade
apt-get install -y --no-install-recommends ubuntu-desktop-minimal
apt-get install -y gnome-shell-extension-manager gnome-tweaks gnome-shell-extensions \
  xserver-xorg-video-dummy x11vnc xdotool imagemagick gnome-screenshot \
  gnome-text-editor gnome-calculator sassc libglib2.0-dev-bin unzip git curl jq shellcheck
apt-get purge -y gnome-initial-setup || true

# Xorg on a dummy 1920x1080 display so GNOME runs without a GPU or physical monitor.
cat > /etc/X11/xorg.conf.d/10-dummy.conf <<'EOF'
Section "Device"
  Identifier "dummy"
  Driver "dummy"
  VideoRam 256000
EndSection
Section "Monitor"
  Identifier "monitor"
  HorizSync 5.0-1000.0
  VertRefresh 5.0-200.0
  Modeline "1920x1080" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync
EndSection
Section "Screen"
  Identifier "screen"
  Device "dummy"
  Monitor "monitor"
  DefaultDepth 24
  SubSection "Display"
    Depth 24
    Modes "1920x1080"
    Virtual 1920 1080
  EndSubSection
EndSection
EOF

# After the desktop packages are installed, systemd-networkd no longer applies cloud-init's netplan
# config on reboot (no IP, host unreachable). Pin DHCP on the EC2 NIC explicitly.
cat > /etc/systemd/network/10-ubuntu-tahoe-ec2.network <<'EOF'
[Match]
Name=en*

[Network]
DHCP=ipv4
EOF

cat > /etc/gdm3/custom.conf <<'EOF'
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=ubuntu
EOF

# Disposable test host only: no screen lock or blanking so screenshots are reliable.
mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/00-test-host <<'EOF'
[org/gnome/desktop/session]
idle-delay=uint32 0
[org/gnome/desktop/screensaver]
lock-enabled=false
[org/gnome/desktop/lockdown]
disable-lock-screen=true
EOF
dconf update

cat > /etc/systemd/system/x11vnc.service <<'EOF'
[Unit]
Description=VNC view of the auto-login GNOME session (loopback only)
After=gdm.service
[Service]
User=ubuntu
ExecStart=/usr/bin/x11vnc -display :0 -auth /run/user/1000/gdm/Xauthority -forever -shared -localhost -nopw -noxdamage -rfbport 5900
Restart=always
RestartSec=5
[Install]
WantedBy=graphical.target
EOF
systemctl daemon-reload
systemctl enable x11vnc.service
systemctl set-default graphical.target

mkdir -p /var/lib/ubuntu-tahoe
date -Is > /var/lib/ubuntu-tahoe/bootstrap-done
systemctl reboot

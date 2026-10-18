#!/usr/bin/env bash
# Source this over SSH to talk to the auto-login GNOME session of the AWS test host (user "ubuntu").
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR DISPLAY=:0 XAUTHORITY="$XDG_RUNTIME_DIR/gdm/Xauthority"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus" XDG_CURRENT_DESKTOP=ubuntu:GNOME DESKTOP_SESSION=ubuntu

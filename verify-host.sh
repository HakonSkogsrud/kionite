#!/usr/bin/env bash
set -euo pipefail

echo 'OS and required host packages'
cat /etc/os-release
rpm -q tailscale syncthing code emacs-pgtk avahi cups git zsh stow nix nix-daemon

if rpm -q firefox >/dev/null 2>&1; then
    echo 'Unexpected RPM Firefox is still installed' >&2
    exit 1
fi
test -f /usr/share/flatpak/remotes.d/flathub.flatpakrepo
test -f /usr/share/flatpak/remotes.d/fedora.flatpakrepo
flatpak remotes --system --columns=name | grep -Fx flathub
flatpak remotes --system --columns=name | grep -Fx fedora
test -f /usr/lib64/qt6/plugins/kwin/effects/plugins/smoothswipe.so
test -f /usr/lib64/qt6/plugins/styles/klassy6.so
test -f /usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so
command -v klassy-settings

echo 'Nix storage and service state'
findmnt --mountpoint /nix
test "$(stat -c %d:%i /nix)" = "$(stat -c %d:%i /var/nix)"
systemctl is-active nix.mount nix-daemon.service tailscaled.service avahi-daemon.service
systemctl is-active cups.socket
getenforce

echo 'Ordinary-user Nix access'
test "$(id -u)" != 0
nix --version
nix run nixpkgs#hello

echo 'Login shell'
getent passwd "$(id -un)"

#!/usr/bin/env bash
# Run only in a disposable, installed test VM, as root.
set -euo pipefail
export SYSTEMD_COLORS=0
nixpkgs_rev="${1:?Pass the pinned nixpkgs revision}"
[[ "$nixpkgs_rev" =~ ^[0-9a-f]{40}$ ]]
[[ $(id -u) == 0 ]]
[[ $(getenforce) == Enforcing ]]
for attempt in {1..60}; do
 state=$(systemctl is-system-running 2>/dev/null || true)
 [[ "$state" != starting && "$state" != initializing ]] && break
 sleep 2
done
systemctl --failed --no-pager
[[ "$state" == running ]]
[[ -z $(systemctl --failed --no-legend --plain) ]]
systemctl is-active nix.mount nix-daemon.service tailscaled.service avahi-daemon.service cups.socket
findmnt --mountpoint /nix
[[ $(stat -c %d:%i /nix) == $(stat -c %d:%i /var/nix) ]]
rpm -q tailscale syncthing code emacs-pgtk avahi cups git zsh stow nix nix-daemon
for package in firefox firefox-langpacks gcc-c++ cmake; do
 if rpm -q "$package" >/dev/null 2>&1; then exit 1; fi
done
/usr/sbin/cupsd -t
flatpak remotes --system --columns=name | grep -Fx fedora
flatpak remotes --system --columns=name | grep -Fx flathub
for file in /usr/bin/klassy-settings \
 /usr/lib64/qt6/plugins/styles/klassy6.so \
 /usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so \
 /usr/lib64/qt6/plugins/kwin/effects/plugins/smoothswipe.so; do
 test -f "$file"
 dependencies=$(ldd "$file")
 if [[ "$dependencies" == *'not found'* ]]; then printf '%s\n' "$dependencies"; exit 1; fi
done
# This account belongs only to the disposable test VM.
useradd --create-home --home-dir /var/home/kionite-smoke --shell /bin/bash kionite-smoke
runuser -u kionite-smoke -- env NIXPKGS_REV="$nixpkgs_rev" /usr/bin/bash -c '
    set -euo pipefail
    nix --version
    nix run "github:NixOS/nixpkgs/$NIXPKGS_REV#hello"
    result=$(nix build --no-link --print-out-paths --impure --option sandbox true \
        --expr "let pkgs = import (builtins.getFlake \"github:NixOS/nixpkgs/$NIXPKGS_REV\").outPath {}; in pkgs.runCommand \"kionite-sandbox-smoke\" {} \"echo sandbox-ok > \$out\"")
    test "$(cat "$result")" = sandbox-ok
    ln -s "$result" "$HOME/sandbox-result"
'
printf 'Installed-system boot and ordinary-user Nix smoke checks passed\n'

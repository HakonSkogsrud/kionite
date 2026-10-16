# Kionite

Personal Fedora Kinoite 44 image with KDE Plasma and Fedora-packaged Nix.
Published at `ghcr.io/hakonskogsrud/kionite:stable`.

The image adds Tailscale, Syncthing, VS Code, Emacs PGTK, Avahi, CUPS, Git,
Zsh, GNU Stow, OpenSSH client and man-page utilities.
Configure Flatpak remotes through Fedora setup or Discover and install apps
manually.

The desktop keeps Dolphin, Konsole, Ark, Spectacle, Discover, System Settings,
System Monitor, Info Center, KDE Wallet, networking/Bluetooth/audio controls,
screen locking, authentication, thumbnailers and printing. KWrite, Plasma Welcome
and Filelight are also retained.

The image removes RPM Firefox, Akonadi, the character picker, KDE help/docs and
debug settings, Google Drive integration, remote-desktop servers, SMB folder
sharing, audio-CD access, the inotify diagnostic tool, KDE Connect, KFind,
Partition Manager, Plasma Vault, camera integration, Baloo file indexing and
extra Plasma widgets. Builds check that the retained desktop packages remain
installed after removal.

## Install and update

Install stock Fedora Kinoite 44, then pin the original deployment and rebase:

```sh
sudo ostree admin pin 0
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/hakonskogsrud/kionite:stable
sudo reboot
```

For subsequent updates:

```sh
sudo bootc status
sudo bootc upgrade
sudo reboot
```

To roll back, run `sudo bootc rollback` and reboot. Rebasing preserves existing
disk encryption and partition layout. Updates and reboots are manual.

## Home Manager

Home Manager supplies eza, ripgrep, zoxide, fzf, fd, bat, lazygit, Neovim, uv,
tmux, direnv/nix-direnv, zsh-autosuggestions and JetBrains Mono Nerd Font.
It manages packages and session integration, not personal shell/editor dotfiles.

Clone this repository as your ordinary user:

```sh
git clone https://github.com/HakonSkogsrud/kionite.git ~/kionite
cd ~/kionite/home
```

The configuration targets user `haaksk` on `x86_64-linux`. For another user,
adjust `home.username` and `home.homeDirectory` in `home/home.nix`, and rename
the `homeConfigurations.haaksk` output in `home/flake.nix`.

Build and activate in one command, without sudo:

```sh
nix run .#homeConfigurations.haaksk.activationPackage
```

After the first activation, the Home Manager CLI is also available:

```sh
home-manager switch --flake ~/kionite/home#haaksk
```

Like `nixos-rebuild switch` for a NixOS `configuration.nix`, this builds and
activates the configuration, but only for your user environment. Edit
`home/home.nix` to change packages, then run either command above. To build
without activating, use `nix build .#homeConfigurations.haaksk.activationPackage`
from `home/`.

Keep the Nix configuration in your Git checkout, not copied into the OS image.
Clone it after installation and pull changes when you want to update your user
environment; rebuilding the OS image is not needed. Inputs are pinned in
`home/flake.lock`, tracking nixpkgs 26.05 and Home Manager release-26.05;
to update them deliberately, run `nix flake update` from
`home/` before rebuilding.

Personal dotfiles live in
[`.dotfiles`](https://github.com/HakonSkogsrud/.dotfiles) and are linked with
GNU Stow. If migrating from the old Home Manager-managed dotfiles, follow
[the migration guide](docs/stow-migration.md) before activation.

Use `/usr/bin/zsh` as the login shell. Your Stow-managed `.zshrc` should load
Home Manager's session variables:

```sh
if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi
```

Shell hooks, aliases and editor configuration belong in your dotfiles.
For VS Code to inherit Nix tools, launch `code .` from the configured shell;
fully exit an existing VS Code instance first if necessary.

Nix uses `/nix/store`, backed by persistent `/var/nix`. The Nix store, Home
Manager profiles, home directories and Flatpak state survive OS updates.
OS rollback does not roll them back; back them up separately.

## Build and publish

On the Linux builder, use rootless Podman as an ordinary user (without sudo).
Build locally and run the disposable installed-VM check:

```sh
bash build.sh
scripts/test-vm.sh localhost/kionite:test
```

`build.sh` only builds; it never publishes. It defaults to
`localhost/kionite:test`; override `IMAGE_REF` to use another local tag.

The helper requires bcvk 0.21, QEMU/virtiofsd, session libvirt, UEFI firmware
and KVM access. It checks boot, DNS and KWin/Plasma startup.

The dedicated builder account runs `scripts/pipeline.sh`: fetch `main`, build,
test, publish to GHCR and promote the verified digest to `stable`. It retains
five registry builds and two local pipeline images. Check freshness with
`scripts/check-status.sh`.

Infrastructure, credentials and the nightly timer are managed in
[`serversetup`](https://github.com/HakonSkogsrud/serversetup), under
`roles/kionite_builder`. Images are currently unsigned.

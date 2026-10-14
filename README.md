# Kionite

Personal Fedora Kinoite image with Fedora-packaged Nix, built in the homelab.
Source: https://github.com/HakonSkogsrud/kionite

## Current setup

- Builder: `haaksk@10.0.0.139`, AlmaLinux 10.2, x86_64, 100 GiB disk,
  4 GiB RAM, and 4 GiB temporary swap.
- Test desktop: `haaksk@10.0.0.59`, now running the custom Fedora 44 Kinoite image.
- Registry: `10.0.0.139:5000`, unauthenticated HTTP on the trusted LAN.
- Update reference: `10.0.0.139:5000/my-kinoite:44-candidate`.
- Image definition and shell environment: this directory; remote copies are at
  `~/kionite` on the builder and `~/kinoite-shell` on the test desktop.

The registry uses the Podman container `kinoite-registry`, persistent data at
`/var/lib/kinoite-registry`, and `podman-restart.service` for restart after reboot.
Temporary swap at `/var/swap-kinoite` is not configured in fstab.
Permanent hosting still needs HTTPS, authentication, signing, and scheduled builds.

Infrastructure plans and Ansible configuration belong in the separate
`HakonSkogsrud/serversetup` repository.

## Image and shell packages

The image contains Tailscale, Syncthing, Microsoft VS Code, Emacs PGTK, Avahi,
CUPS, Git, Zsh, GNU Stow, OpenSSH client, man-page utilities, and Fedora's Nix packages.
Nix sees `/nix/store`; persistent `/var/nix` is bind-mounted onto `/nix` before
package tmpfiles initialization and daemon startup. SELinux remains enforcing.

Home Manager supplies eza, ripgrep, zoxide, fzf, fd, bat, lazygit, Neovim, uv,
tmux, direnv/nix-direnv, zsh-autosuggestions, and JetBrains Mono Nerd Font.
Home Manager manages packages and session integration only. Personal dotfiles
belong in [`.dotfiles`](https://github.com/HakonSkogsrud/.dotfiles) and are linked
with Stow. See [the migration guide](docs/stow-migration.md) before activating the
new configuration on a machine using the prototype's Home Manager dotfile links.
The login shell is `/usr/bin/zsh`, supplied by the image. Nix GPU integration is
disabled because these Nix packages are CLI tools. Inputs are pinned in
`home/flake.lock`.

## Desktop extensions and Flatpak

The image builds [Smooth Swipe](https://github.com/cesp99/smooth-swipe) and
[Klassy](https://github.com/paulmcauley/klassy) from pinned upstream commits in a
separate build stage. Compiler/development packages are not copied into the final
image. Klassy includes the Qt 6 application style, window decorations, settings,
and global theme; its optional Qt 5 style is not built.

Smooth Swipe uses KWin's private plugin ABI. Every image build recompiles it
against that image's KWin headers. The build fails if installing development
packages changes the checked KDE/Qt runtime versions. A future incompatible KWin
API update may require updating the pinned Smooth Swipe source.

After booting the image, choose Smooth Swipe under System Settings -> Desktop
Effects -> Virtual Desktop Switching Animation. Choose Klassy under Colours &
Themes -> Global Theme. Theme/effect selection stays in your personal KDE config.

The RPM Firefox and its language packs are removed. Fedora's stable Flatpak
remote and full Flathub are defined in `/usr/share/flatpak/remotes.d/`.
The Fedora URL follows the [Fedora Developer Portal](https://developer.fedoraproject.org/deployment/flatpak/flatpak-usage.html). No Flatpak apps
are installed automatically. Install Firefox, Obsidian, Brave, Collabora Office,
and other Flatpak apps manually through Discover or `flatpak install`.

```sh
flatpak remotes --system --show-details
flatpak install flathub org.mozilla.firefox
```

The apps you mentioned are available from Flathub:

| App | Flatpak ID |
|---|---|
| [Obsidian](https://flathub.org/en/apps/md.obsidian.Obsidian) | `md.obsidian.Obsidian` |
| [Brave](https://flathub.org/en/apps/com.brave.Browser) | `com.brave.Browser` |
| [Collabora Office](https://flathub.org/en/apps/com.collaboraoffice.Office) | `com.collaboraoffice.Office` |

Use `flatpak install flathub <ID>` for whichever apps you choose.

Your existing Firefox profile is not deleted by the image build; the Flatpak uses
a different profile location, so migrate bookmarks/settings separately if needed.

## Desktop extension build validation on 2026-10-13

The `44-desktop-extensions` image was built on the AlmaLinux builder. Both
extensions compiled from the pinned commits, and their plugins/settings binary
resolved all shared-library dependencies in the runtime image. RPM Firefox,
Firefox language packs, CMake, and the C++ compiler are absent. Fresh-container
checks initialized Fedora and full Flathub with no Flatpak apps installed.
Bootc lint passed 14 checks with 1 skipped and no warnings on the assembled image.
The package-only Home Manager configuration also built successfully.

This revision has not been deployed to the desktop VM. Theme appearance and
actual touchpad gestures still need graphical testing after deployment. Existing
Home Manager activation and dotfiles on the VM have not been changed.

## Prototype validation on 2026-10-13

- Built the Kinoite image on AlmaLinux and published it to the homelab registry.
- Bootc lint: 14 checks passed, 1 skipped, no warnings after runtime/cache cleanup.
- Switched the disposable Silverblue VM to Kinoite without local package layers.
- Verified the requested host RPMs, Nix bind mount, daemon, and service startup.
- Ran a cached Nix package and a local sandboxed derivation as ordinary user
  `haaksk`, with SELinux enforcing.
- Built and activated Home Manager; verified shell tools, aliases, autosuggestion
  binding, and Zoxide navigation.
- CUPS is running and discovered `Brother_HL_L2445DW`; no print job was sent.
- Updated through `bootc upgrade` to a second image digest, rebooted, rolled back
  to the first revision, and returned to the second revision.
- The Nix store/result, Home Manager profile, and nixbld group survived the update
  and rollback. No failed system services remained during those checks.

The second revision changes image version metadata, not RPM contents. This tests
registry update/staging and deployment rollback, but not Nix daemon upgrades
across versions. Physical desktop graphics, suspend, and actual printing still
need user testing. The graphical login unit is `plasmalogin.service` on this base,
not `sddm.service`.

| Revision | Registry digest |
|---|---|
| `44-first-boot` | `sha256:ef7d5755ce43d3f99988119d09c42208660322ca6f502818f73433a7249a9554` |
| `44-experiment-2` | `sha256:cef8e4b2abe00dd6c966215cac67c7de3d8980217196e1626a9902fc77cd586d` |

## Ansible builder and installed-system tests

The permanent builder work lives in `serversetup/roles/kionite_builder` and the
separate provisioning/configuration playbooks. VM 103 now has 4 vCPUs, 12 GiB RAM
and a 150 GiB disk. The dedicated account is `kionite-build`, with source/state
under `/var/lib/kionite-builder`. It uses rootless Podman and session-owned libvirt.
The original rootful registry/store remain available during migration.

For that account, use explicit rootless mode:

```sh
PODMAN_ROOTLESS=1 IMAGE_REF=localhost/kionite:test bash build.sh
scripts/test-vm.sh localhost/kionite:test
```

The test helper uses pinned `/usr/local/bin/bcvk` 0.21; override `BCVK_BIN` only
when deliberately testing another version. Alma sudo's PATH can select EPEL's
older 0.10 binary otherwise. Ansible installs the newer binary from an immutable
upstream OCI artifact digest. Its installer startup fixes are needed for this image.

The helper creates an installed Btrfs VM in `qemu:///session`, runs boot/service,
SELinux, Nix and dependency checks, retains logs, and removes the test domain.
It requires bcvk, QEMU/virtiofsd, session libvirt, UEFI firmware and KVM access.
The pipeline must supply a unique named local build reference. The helper serializes
VM tests and verifies the source tag did not change during the run.
UEFI Secure Boot and TPM are disabled for this initial harness.

On 2026-10-14, a full rootless build and the installed-system smoke helper passed.
The guest had SELinux enforcing and zero failed system units. CUPS configuration,
package/plugin dependencies, Flatpak remotes, a cached Nix package and an ordinary
user's local sandboxed Nix derivation passed. The helper collected logs and removed
the VM successfully. Ansible repeat runs changed zero, including publisher auth.
The token remains outside this repository and no GHCR release has been published.

Ephemeral mode remains useful for quick experiments but adds `selinux=0` and
temporary `/var`, so it cannot pass enforcing/persistence acceptance. Desktop
plugin behavior and actual image update/rollback are manual checks on the disposable
desktop before moving the laptop; they are not automated release gates. GHCR publication and nightly scheduling are handled by the pipeline below.

## Building and publishing

Clone the image repository on the builder:

```sh
git clone https://github.com/HakonSkogsrud/kionite.git ~/kionite
```

For a private repository, configure a read-only deploy key first. A public
repository needs no GitHub credentials for pulls. Build from the checked-out revision:

```sh
cd ~/kionite
git pull --ff-only
git rev-parse HEAD
```

Then:

```sh
bash build.sh
PUBLISH=1 bash build.sh
```

The script pulls the latest Fedora 44 base and disables build cache so third-party
RPM updates are picked up even when the base digest is unchanged. It records image
metadata and uses a timestamped version label by default. Override `IMAGE_REF` and
`IMAGE_VERSION` as needed. Build logs and generated metadata are excluded from Git.
The first build can take several minutes: this builder's kernel causes Podman to
use a slower overlay filesystem diff mode.

Do not overwrite a release tag intended for recovery. A permanent workflow should
publish immutable candidates, validate them, then promote a stable reference.
The current candidate workflow is manual and unsigned.

## Updating, rolling back, and checking the desktop

```sh
sudo bootc status
sudo bootc upgrade
sudo systemctl reboot
```

For a rollback, inspect the target first, then:

```sh
sudo bootc rollback
sudo systemctl reboot
```

The original Silverblue deployment remains pinned. Deployment indexes change;
inspect `sudo ostree admin status` before selecting a pinned deployment. Its old
image lacks Nix and Zsh, so the personalized shell environment is only validated
on the custom Kinoite revisions.

Use `bash verify-host.sh` as an ordinary user for the basic runtime checks.
Nix state under `/var/nix` is shared: an OS rollback does not roll back Nix packages,
profiles, or the database. Back up user configuration separately.

To update the shell environment on the desktop:

```sh
cd ~/kionite/home
nix run .#homeConfigurations.haaksk.activationPackage
```

Inspect existing dotfile conflicts and back up files before activation on another
machine. The prototype used Home Manager links; follow the Stow migration guide before
activating the package-only configuration.

## Migration fix and saved state

Silverblue's old root fstab entry caused `systemd-remount-fs.service` to fail with
`overlay: No changes allowed in reconfigure` after switching to composefs Kinoite.
The root filesystem is already mounted by the initramfs using kernel root flags.
After checking those flags, the obsolete `/` fstab entry was commented out on
this VM, preserving the `/boot`, `/home`, and `/var` entries. The remount service
then succeeded. See [upstream bootc issue 971](https://github.com/bootc-dev/bootc/issues/971).
This is a per-machine migration fix, not a generic fstab replacement in the image.

Desktop evidence and backups are in `~/kinoite-experiment-backup`, including the
original deployment metadata, original fstab, activation logs, and sandbox result.
The registry's precise HTTP exception is in
`/etc/containers/registries.conf.d/90-kinoite-experiment.conf`.

The initial detached build/publish job ran as `kinoite-build-publish.service` on
the builder and completed successfully. Its journal remains available:

```sh
sudo journalctl -u kinoite-build-publish.service --no-pager
```

## Nix integration references

- [Fedora native Nix on bootc experience](https://discussion.fedoraproject.org/t/my-experience-integrating-nix-into-fedora-bootc/190809)
- [Reference implementation](https://github.com/fu5ha/winter), revision
  `0daf5c285eab9a09b2389ec3c71acd307e050e98`.

Fedora's actual Nix tmpfiles, daemon/socket, profile, and sysusers definitions were
inspected from the installed RPM layer. Additional tmpfiles rules recreate the
store directories hidden by the bind mount. Build-user UID/GID stability must be
rechecked when changing the base or package set.

## Nightly pipeline

Run `scripts/pipeline.sh` as `kionite-build`. It locks the account's pipeline,
fetches trusted `main`, archives the exact commit into a unique workspace, builds
without stale RPM caching, runs the disk-backed smoke gate, then publishes the
same image to `ghcr.io/hakonskogsrud/kionite` and promotes its verified digest to
`stable`. The scheduled user service uses the same entry point.

Release tags include Fedora version, UTC timestamp, Git SHA and a random run ID.
Release tags are never overwritten. The script records image/package/base/source
metadata, registry digest, VM logs and a small status report. Graphical behavior,
physical gestures and a real update/rollback are manual checks before laptop use.
No desktop updates or reboots are scheduled by these scripts.

The first GHCR package defaults to private. Make it public in Package settings;
promotion waits for anonymous digest access. Resume the exact already-tested image
without rebuilding:

```sh
scripts/pipeline.sh --resume <build-id>
```

Credentials live in `$HOME/.config/containers/auth.json`, supplied by Ansible from
Vault; publication uses HTTPS and that explicit auth file. No token is embedded in
image layers or the repository. A completed pipeline writes `last-success.json`;
`scripts/check-status.sh` fails for a failed latest run or success older than 48h.

The pipeline recovers stale bcvk resources owned by this dedicated account, prunes
unreferenced VM base disks and retains two pipeline image tags locally. Workspaces
and large logs are retained for 30 days; release metadata and GHCR recovery tags
are retained. It does not prune unrelated prototype image tags or delete GHCR
releases. Monitor free disk space and deliberately review registry retention later.

Ansible owns `kionite-build.service` and a 03:00 Europe/Oslo timer with up to 10
minutes jitter and missed-run catch-up. The timer is enabled only after a successful
manual publication. As `kionite-build`, inspect it with `systemctl --user list-timers kionite-build.timer`;
run manually with `systemctl --user start kionite-build.service`, then inspect
`journalctl --user -u kionite-build.service`. Lingering keeps its user manager
available after logout and reboot. The builder needs connectivity when
fetching/publishing. Failures leave the prior stable release unchanged.

## Basic verification gate

The release gate checks boot reaches running/degraded state, DNS resolves
`ghcr.io`, Klassy and Smooth Swipe files exist, and KWin plus Plasma start.
An unattended guest uses a temporary virtual Wayland session. Nix builds,
SELinux enforcement, printing and a zero-failed-unit requirement are no longer
release gates. Real graphics and gesture behavior remain manual checks.
The previous first scheduled run timed out in the bcvk installer before any
guest checks ran; simplifying the checks does not fix that startup failure.
Missing libvirt domains are now treated as already cleaned up.

### Installer startup permission fix

The pipeline inherited umask 077 into image construction. The resulting OCI
image had mode 0700 on `/usr` and `/usr/lib`, causing installer guest service
execution to fail with Permission denied. The deployed OSTree VM had 0755
permissions, explaining why manual deployment worked. Build and bcvk subprocesses
now use umask 022; final image directory permissions are explicitly normalized.
Pipeline metadata and registry credentials retain their restrictive permissions.

### Success monitoring

Ansible can install a mode-0600 monitor environment file from Vault.
`KIONITE_SUCCESS_PUSH_URL` is called only after successful verified publication.
Failed runs send no success heartbeat. Kuma notification failure logs a warning
without reverting publication. Configure the push monitor interval to cover the
24-hour schedule, jitter, and build duration (for example 26 hours).

### Registry retention

After each successful publication, the builder retains five managed release
versions in GHCR, including the version tagged `stable`. Older managed versions
are deleted through GitHub's package API. Custom recovery tags and untagged
manifests are left untouched. Stable is always protected, even after rollback
to an older build. Cleanup failure warns without failing or reverting publication.

The existing classic publishing PAT also needs `delete:packages` (package read
access comes with `write:packages`). Without it, versions beyond the five-build
limit remain and cleanup logs a warning. Inspect the plan without deleting with:

```sh
python3 scripts/registry-retention.py --keep 5
```

Add `--apply` to execute cleanup. Image releases are identified by the pipeline's
unique dated release tags; sorting uses release time rather than stable-tag
updates. The current image counts toward the five retained builds.

Local storage remains independent of GHCR: keep the latest two pipeline image
references, prune untagged intermediate images before builds and after successful
tests, remove test/base disks, and expire logs/workspaces after 30 days. Tagged
prototype images and the root-owned temporary LAN registry remain untouched.

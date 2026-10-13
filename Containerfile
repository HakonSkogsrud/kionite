ARG FEDORA_VERSION=44
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION} AS runtime

COPY repos/vscode.repo /etc/yum.repos.d/vscode.repo
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    dnf -y install tailscale syncthing code emacs-pgtk avahi avahi-tools \
      cups cups-filters git zsh stow openssh-clients man-db man-pages util-linux \
      nix nix-daemon && \
    dnf -y remove firefox firefox-langpacks && \
    dnf clean all

COPY files/ /
RUN mkdir -p /nix && \
    printf 'd /var/lib/tailscale 0700 root root - -\nd /var/cache/tailscale 0700 root root - -\n' \
      > /usr/lib/tmpfiles.d/kinoite-tailscale.conf && \
    rm -rf /run/dnf /var/cache/libdnf5 /var/lib/dnf/repos && \
    rm -f /var/cache/ldconfig/aux-cache /var/log/dnf5.log && \
    systemctl enable tailscaled.service avahi-daemon.service cups.socket \
      nix.mount nix-daemon.service && \
    mkdir -p /usr/share/flatpak/remotes.d && \
    curl --fail --location --retry 3 \
      https://dl.flathub.org/repo/flathub.flatpakrepo \
      -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo

FROM runtime AS desktop-build
ARG SMOOTH_SWIPE_REV=c0c7ce1b25e81807a9013a373310dc81d4b54a15
ARG KLASSY_REV=9b788b2ea8d40c6a7af3b0130de9e891d41fbb30
COPY scripts/build-desktop-extensions.sh /tmp/build-desktop-extensions.sh
RUN bash /tmp/build-desktop-extensions.sh

FROM runtime
COPY --from=desktop-build /out/usr/ /usr/
COPY flatpak/ /usr/share/flatpak/remotes.d/
RUN bootc container lint

ARG IMAGE_VERSION=44-desktop-extensions
LABEL org.opencontainers.image.title="Haaksk Kinoite" \
      org.opencontainers.image.version="${IMAGE_VERSION}"

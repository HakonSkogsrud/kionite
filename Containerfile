ARG FEDORA_VERSION=44
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION}

COPY repos/vscode.repo /etc/yum.repos.d/vscode.repo
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    dnf -y install tailscale syncthing code emacs-pgtk avahi avahi-tools \
      cups cups-filters git zsh stow openssh-clients man-db man-pages util-linux \
      nix nix-daemon && \
    dnf -y --setopt=clean_requirements_on_remove=False remove \
      firefox firefox-langpacks akonadi-server akonadi-server-mysql \
      kcharselect khelpcenter plasma-desktop-doc kdebugsettings kio-gdrive \
      krdp krfb kdenetwork-filesharing samba-usershares audiocd-kio \
      kde-inotify-survey kde-connect kfind kde-partitionmanager plasma-vault \
      kamera kf6-baloo-file kdeplasma-addons && \
    rpm -q dolphin konsole ark spectacle plasma-discover plasma-systemsettings \
      plasma-systemmonitor kinfocenter kwalletmanager5 pam-kwallet \
      plasma-nm bluedevil plasma-pa kscreen kscreenlocker polkit-kde \
      kdegraphics-thumbnailers ffmpegthumbs plasma-print-manager \
      kwin plasma-desktop plasma-workspace plasma-login-manager \
      kwrite plasma-welcome filelight && \
    dnf clean all

COPY files/ /
RUN mkdir -p /nix && \
    printf 'd /var/lib/tailscale 0700 root root - -\nd /var/cache/tailscale 0700 root root - -\n' \
      > /usr/lib/tmpfiles.d/kinoite-tailscale.conf && \
    rm -rf /run/dnf /var/cache/libdnf5 /var/lib/dnf/repos && \
    rm -f /var/cache/ldconfig/aux-cache /var/log/dnf5.log && \
    systemctl enable tailscaled.service avahi-daemon.service cups.socket \
      nix.mount nix-daemon.service

RUN chmod 0755 /usr /usr/lib /usr/lib64 /usr/share && \
    bootc container lint

ARG IMAGE_VERSION=44
ARG IMAGE_REVISION=unknown
ARG IMAGE_CREATED=unknown
LABEL org.opencontainers.image.source="https://github.com/HakonSkogsrud/kionite" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.title="Haaksk Kinoite" \
      org.opencontainers.image.version="${IMAGE_VERSION}"

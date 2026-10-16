#!/usr/bin/env bash
set -euo pipefail
# Buildah-created image directories must be traversable by service users.
umask 022
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[[ $(id -u) != 0 ]] || { echo 'Run build.sh as an ordinary user with rootless Podman, not sudo.' >&2; exit 1; }
image_ref="${IMAGE_REF:-localhost/kionite:test}"
image_version="${IMAGE_VERSION:-44-$(date -u +%Y%m%dT%H%M%SZ)}"
image_revision="${IMAGE_REVISION:-$(git rev-parse HEAD 2>/dev/null || printf unknown)}"
image_created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
podman build --pull=always --no-cache --build-arg IMAGE_VERSION="$image_version" \
    --build-arg IMAGE_REVISION="$image_revision" --build-arg IMAGE_CREATED="$image_created" \
    -t "$image_ref" . 2>&1 | tee build.log
podman image inspect "$image_ref" > build-image.json

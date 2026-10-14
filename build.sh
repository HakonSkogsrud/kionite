#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
image_ref="${IMAGE_REF:-10.0.0.139:5000/my-kinoite:44-candidate}"
image_version="${IMAGE_VERSION:-44-$(date -u +%Y%m%dT%H%M%SZ)}"
image_revision="${IMAGE_REVISION:-$(git rev-parse HEAD 2>/dev/null || printf unknown)}"
image_created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
case "${PODMAN_ROOTLESS:-0}" in
    0) podman_command=(sudo podman) ;;
    1) podman_command=(podman) ;;
    *) echo 'PODMAN_ROOTLESS must be 0 or 1' >&2; exit 2 ;;
esac
"${podman_command[@]}" build --pull=always --no-cache --build-arg IMAGE_VERSION="$image_version" \
    --build-arg IMAGE_REVISION="$image_revision" --build-arg IMAGE_CREATED="$image_created" \
    -t "$image_ref" . 2>&1 | tee build.log
"${podman_command[@]}" image inspect "$image_ref" > build-image.json

# The temporary LAN registry uses HTTP. Publishing is deliberately explicit.
if [[ "${PUBLISH:-0}" == 1 ]]; then
    "${podman_command[@]}" push --tls-verify=false "$image_ref"
fi

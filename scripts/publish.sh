#!/usr/bin/env bash
set -euo pipefail
image_ref="${1:?Pass tested local image reference}"
release_tag="${2:?Pass unique release tag}"
run_dir="${3:?Pass pipeline report directory}"
registry_repo="${REGISTRY_REPO:-ghcr.io/hakonskogsrud/kionite}"
auth_file="${REGISTRY_AUTH_FILE:-$HOME/.config/containers/auth.json}"
[[ "$release_tag" =~ ^44-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}-[0-9a-f]{8}$ ]]
[[ "$registry_repo" =~ ^ghcr\.io/[a-z0-9_-]+/[a-z0-9_-]+$ ]]
image_id=$(podman image inspect --format '{{.Id}}' "$image_ref")
[[ $(cat "$run_dir/tests-passed") == "$image_id" ]]
release_ref="$registry_repo:$release_tag"

# A saved digest permits resuming this exact tested release after visibility setup.
if [[ -f "$run_dir/registry-digest" ]]; then
    digest=$(cat "$run_dir/registry-digest")
else
    if skopeo inspect --authfile "$auth_file" --raw "docker://$release_ref" \
        > "$run_dir/existing-manifest.json" 2> "$run_dir/release-preflight.log"; then
        echo "Refusing to overwrite existing release: $release_ref" >&2
        exit 1
    fi
    if ! grep -Eiq 'manifest unknown|name unknown|not found|404' "$run_dir/release-preflight.log"; then
        cat "$run_dir/release-preflight.log" >&2
        exit 1
    fi
    podman push --authfile "$auth_file" --digestfile "$run_dir/registry-digest" \
        "$image_ref" "docker://$release_ref"
    digest=$(cat "$run_dir/registry-digest")
fi
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]
skopeo inspect --authfile "$auth_file" --raw "docker://$registry_repo@$digest" \
    > "$run_dir/published-manifest.json"
python3 - "$run_dir/published-manifest.json" "$image_id" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest['config']['digest'].removeprefix('sha256:') == sys.argv[2].removeprefix('sha256:'), 'Published image differs from tested image'
PY
[[ $(skopeo inspect --authfile "$auth_file" --format '{{.Digest}}' "docker://$release_ref") == "$digest" ]]

# Test genuinely anonymous access, without the publisher's default credential search.
public_auth="$run_dir/anonymous-auth.json"
printf '{"auths":{}}\n' > "$public_auth"
if ! skopeo inspect --authfile "$public_auth" --no-creds --format '{{.Digest}}' \
    "docker://$registry_repo@$digest" > "$run_dir/anonymous-digest"; then
    echo 'Release published, but anonymous pulls failed. Make the GHCR package public, then resume this release.' >&2
    exit 1
fi
[[ $(cat "$run_dir/anonymous-digest") == "$digest" ]]
skopeo copy --preserve-digests --authfile "$auth_file" \
    "docker://$registry_repo@$digest" "docker://$registry_repo:stable"
[[ $(skopeo inspect --authfile "$public_auth" --no-creds --format '{{.Digest}}' "docker://$registry_repo:stable") == "$digest" ]]
printf '%s\n' "$registry_repo@$digest" > "$run_dir/published-reference"
printf 'Published %s and promoted stable to %s\n' "$release_ref" "$digest"

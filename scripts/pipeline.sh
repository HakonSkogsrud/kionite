#!/usr/bin/env bash
set -euo pipefail
umask 077
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="${PIPELINE_STATE_DIR:-$HOME}"
mkdir -p "$state_dir"/{work,logs,releases}
if [[ "${1:-}" != --locked && "${1:-}" != --prepared && "${1:-}" != --resume-locked ]]; then
    exec flock --nonblock --conflict-exit-code 75 --close "$state_dir/.pipeline.lock" \
        bash "$0" --locked "$@"
fi
if [[ "${1:-}" == --locked ]]; then
    if [[ "${2:-}" == --resume ]]; then
        build_id="${3:?Pass the published build ID to resume}"
        [[ "$build_id" =~ ^44-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}-[0-9a-f]{8}$ ]]
        source_sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["git_sha"])' "$state_dir/releases/$build_id/status.json")
        exec bash "$state_dir/work/$build_id/scripts/pipeline.sh" --resume-locked "$build_id" "$source_sha"
    fi
    git -C "$repo_dir" fetch --prune origin main
    source_sha=$(git -C "$repo_dir" rev-parse 'origin/main^{commit}')
    build_id="44-$(date -u +%Y%m%dT%H%M%SZ)-${source_sha:0:12}-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
    checkout="$state_dir/work/$build_id"
    mkdir "$checkout"
    git -C "$repo_dir" archive "$source_sha" | tar -xf - -C "$checkout"
    exec bash "$checkout/scripts/pipeline.sh" --prepared "$build_id" "$source_sha"
fi
build_id="${2:?Missing build ID}"
source_sha="${3:?Missing source revision}"
run_dir="$state_dir/releases/$build_id"
log_dir="$state_dir/logs/$build_id"
mkdir -p "$run_dir" "$log_dir"
exec > >(tee -a "$log_dir/pipeline.log") 2>&1
image_ref="localhost/kionite-build:$build_id"
stage=starting
report() {
    python3 - "$run_dir/status.json" "$build_id" "$source_sha" "$stage" "$1" <<'PY'
import datetime, json, os, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = {'build_id': sys.argv[2], 'git_sha': sys.argv[3], 'stage': sys.argv[4],
        'status': sys.argv[5], 'updated_at': datetime.datetime.now(datetime.timezone.utc).isoformat()}
for name in ('registry-digest', 'published-reference'):
    value = path.parent/name
    if value.exists(): data[name.replace('-', '_')] = value.read_text().strip()
temporary = path.with_suffix('.tmp')
temporary.write_text(json.dumps(data, indent=2)+'\n')
os.replace(temporary, path)
PY
    cp "$run_dir/status.json" "$state_dir/latest-run.json"
}
finish() {
    result=$?
    trap - EXIT
    if [[ "$result" == 0 ]]; then
        report success
        if [[ -f "$run_dir/published-reference" ]]; then
            cp "$run_dir/status.json" "$state_dir/last-success.json"
        fi
    elif [[ "$result" == 75 ]]; then
        report skipped
    else
        report failed
        echo "Pipeline failed at $stage (exit $result); logs: $log_dir"
    fi
    exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ "${1:-}" == --resume-locked ]]; then
    stage=publish; report running
    timeout 3600 bash "$repo_dir/scripts/publish.sh" "$image_ref" "$build_id" "$run_dir"
    stage=complete
    exit 0
fi
stage=recovery; report running
bash "$repo_dir/scripts/recover-tests.sh" "$log_dir/recovery"
stage=build; report running
cd "$repo_dir"
PODMAN_ROOTLESS=1 PUBLISH=0 IMAGE_REF="$image_ref" IMAGE_VERSION="$build_id" \
    IMAGE_REVISION="$source_sha" timeout 7200 bash build.sh
cp build-image.json "$run_dir/image.json"
base_digest=$(skopeo inspect --format '{{.Digest}}' containers-storage:quay.io/fedora-ostree-desktops/kinoite:44)
printf '%s\n' "$base_digest" > "$run_dir/base-digest"
podman run --rm --entrypoint /usr/bin/rpm "$image_ref" -qa | sort > "$run_dir/packages.txt"
stage=smoke; report running
TEST_LOG_DIR="$log_dir/vm" timeout 3000 bash scripts/test-vm.sh "$image_ref"
podman image inspect --format '{{.Id}}' "$image_ref" > "$run_dir/tests-passed"
stage=maintenance; report running
bash scripts/cleanup.sh "$image_ref"
if [[ "${PUBLISH:-1}" == 1 ]]; then
    stage=publish; report running
    timeout 3600 bash scripts/publish.sh "$image_ref" "$build_id" "$run_dir"
fi
stage=complete
printf 'Pipeline completed: %s (%s)\n' "$build_id" "$source_sha"

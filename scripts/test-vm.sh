#!/usr/bin/env bash
# Basic installed-system release gate; real plugin behavior remains manual.
set -euo pipefail
# bcvk injects files used by unprivileged guest services.
umask 022
image_ref="${1:?Usage: scripts/test-vm.sh LOCAL_IMAGE_REFERENCE}"
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_name="kionite-smoke-$(date -u +%Y%m%dT%H%M%SZ)-$$"
bcvk_command="${BCVK_BIN:-/usr/local/bin/bcvk}"
connection=qemu:///session
# The pipeline supplies a unique named build tag and holds its build lock.
# bcvk install needs a name rather than a bare image ID. Check for tag changes.
test_image="$image_ref"
mkdir -p "$HOME/tests"
exec 9> "$HOME/tests/.vm-smoke.lock"
flock --nonblock 9 || { echo 'Another VM test is running' >&2; exit 75; }
source_image_id=$(podman image inspect --format '{{.Id}}' "$image_ref")
log_dir="${TEST_LOG_DIR:-$HOME/logs/$test_name}"
mkdir -p "$log_dir"
chmod 700 "$log_dir"
cleanup() {
    result=$?
    trap - EXIT
    if timeout 30 "$bcvk_command" libvirt ssh --connect "$connection" "$test_name" \
        -- journalctl -b --no-pager > "$log_dir/guest-journal.log" 2>&1; then :; fi
    if virsh -c "$connection" dominfo "$test_name" >/dev/null 2>&1 && ! timeout 60 "$bcvk_command" libvirt rm --connect "$connection" --force "$test_name" \
        > "$log_dir/cleanup.log" 2>&1; then
        echo "Cleanup failed; inspect $test_name and $log_dir/cleanup.log" >&2
        result=1
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
podman image inspect "$image_ref" > "$log_dir/image.json"
timeout 1800 "$bcvk_command" libvirt run --connect "$connection" --name "$test_name" \
    --memory 4G --cpus 2 --disk-size 40G --filesystem btrfs \
    --firmware uefi-insecure --disable-tpm \
    --karg systemd.wants=sshd.service --update-from-host --detach --ssh-wait \
    "$test_image" > "$log_dir/launch.log" 2>&1
# bcvk's command mode does not forward stdin; transport trusted test source as base64.
smoke_payload=$(base64 --wrap=0 "$repo_dir/tests/boot-smoke.sh")
smoke_command="printf '%s' '$smoke_payload' | base64 --decode | bash -s"
timeout 900 "$bcvk_command" libvirt ssh --connect "$connection" "$test_name" \
    "$smoke_command" > "$log_dir/smoke.log" 2>&1
[[ "$(podman image inspect --format '{{.Id}}' "$test_image")" == "$source_image_id" ]]
cat "$log_dir/smoke.log"
echo "Logs: $log_dir"

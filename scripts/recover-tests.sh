#!/usr/bin/env bash
# The dedicated account's bcvk test resources are disposable.
set -euo pipefail
log_dir="${1:?Pass recovery log directory}"
bcvk_command="${BCVK_BIN:-/usr/local/bin/bcvk}"
mkdir -p "$HOME/tests" "$log_dir"
exec 9> "$HOME/tests/.vm-smoke.lock"
flock --nonblock 9 || exit 75
while IFS= read -r domain; do
    if [[ "$domain" =~ ^kionite-smoke-[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]]; then
        "$bcvk_command" libvirt rm --connect qemu:///session --force "$domain"
    fi
done < <(virsh -c qemu:///session list --all --name)
mapfile -t containers < <(podman ps --all --quiet --filter label=bcvk.ephemeral=1)
for container in "${containers[@]}"; do
    podman logs "$container" > "$log_dir/$container.log" 2>&1 || true
    podman rm --force "$container"
done
"$bcvk_command" libvirt base-disks prune --connect qemu:///session
if [[ -z $(virsh -c qemu:///session list --all --name) ]]; then
    find "$HOME/.local/share/libvirt/images" -maxdepth 1 -type f \
        -name 'bootc-base-*.tmp.qcow2' -delete
fi

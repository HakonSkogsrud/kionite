#!/usr/bin/env bash
set -euo pipefail
current_ref="${1:?Pass current build reference}"
state_dir="${PIPELINE_STATE_DIR:-$HOME}"
bcvk_command="${BCVK_BIN:-/usr/local/bin/bcvk}"
# bcvk checks disk references before pruning its installed-image cache.
"$bcvk_command" libvirt base-disks prune --connect qemu:///session
podman images --format json --filter 'reference=localhost/kionite-build:*' \
    > "$state_dir/pipeline-images.json"
python3 - "$state_dir/pipeline-images.json" "$current_ref" <<'PY'
import json, subprocess, sys
refs = sorted({name for image in json.load(open(sys.argv[1])) for name in image.get('Names', [])
               if name.startswith('localhost/kionite-build:')}, reverse=True)
keep = set(refs[:2]) | {sys.argv[2]}
for ref in refs:
    if ref not in keep:
        subprocess.run(['podman', 'rmi', ref], check=True)
PY
# Release records stay small and are retained. Bound large logs/workspaces to 30 days.
find "$state_dir/work" "$state_dir/logs" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf -- {} +

# Prune untagged intermediate layers only; preserve all retained/tagged images.
podman image prune --force

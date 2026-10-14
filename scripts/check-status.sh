#!/usr/bin/env bash
set -euo pipefail
python3 - "${PIPELINE_STATE_DIR:-$HOME}" "${MAX_SUCCESS_AGE_SECONDS:-172800}" <<'PY'
import datetime, json, pathlib, sys
state = pathlib.Path(sys.argv[1])
try:
    latest = json.loads((state/'latest-run.json').read_text())
    success = json.loads((state/'last-success.json').read_text())
except FileNotFoundError:
    raise SystemExit('No successful pipeline run recorded')
age = (datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(success['updated_at'])).total_seconds()
if latest['status'] == 'failed': raise SystemExit('Latest pipeline failed at '+latest['stage'])
if age > int(sys.argv[2]): raise SystemExit('Last successful publication is stale')
print('OK: '+success['build_id'])
PY

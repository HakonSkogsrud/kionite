#!/usr/bin/env python3
"""Optional Kuma heartbeat. Never log the endpoint or its embedded credential."""
import json
import os
import sys
import time
import urllib.request

endpoint = os.environ.get('KIONITE_SUCCESS_PUSH_URL')
if not endpoint:
    sys.exit(0)
for attempt in range(3):
    try:
        with urllib.request.urlopen(endpoint, timeout=10) as response:
            payload = json.load(response)
        if payload.get('ok') is not True:
            raise ValueError('Heartbeat rejected')
        print('Kuma success heartbeat accepted')
        sys.exit(0)
    except Exception:
        if attempt < 2:
            time.sleep(2)
print('Kuma success heartbeat failed; endpoint details suppressed', file=sys.stderr)
sys.exit(1)

#!/usr/bin/env bash
# Basic release gate. Run as root only in a disposable test VM.
set -euo pipefail
export SYSTEMD_COLORS=0
[[ $(id -u) == 0 ]]
for attempt in {1..60}; do
    state=$(systemctl is-system-running 2>/dev/null || true)
    [[ "$state" == running || "$state" == degraded ]] && break
    sleep 2
done
[[ "$state" == running || "$state" == degraded ]]
printf 'Boot reached %s\n' "$state"
# DNS resolution requires the guest network, but no package downloads.
getent ahosts ghcr.io
for file in /usr/bin/klassy-settings \
 /usr/lib64/qt6/plugins/styles/klassy6.so \
 /usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so \
 /usr/lib64/qt6/plugins/kwin/effects/plugins/smoothswipe.so; do
    test -f "$file"
    printf 'Present: %s\n' "$file"
done
# An installed desktop may already have a logged-in graphical session.
if pgrep -x kwin_wayland >/dev/null && pgrep -x plasmashell >/dev/null; then
    echo 'KWin and Plasma are running'
else
    # Start a virtual Wayland session only in this disposable guest.
    useradd --create-home --home-dir /var/home/kionite-smoke --shell /bin/bash kionite-smoke
    smoke_uid=$(id -u kionite-smoke)
    runtime=$(mktemp -d /run/kionite-desktop-smoke.XXXXXX)
    chown "$smoke_uid:$smoke_uid" "$runtime"
    chmod 700 "$runtime"
    trap 'pkill -KILL -u "$smoke_uid" 2>/dev/null || true; userdel -r kionite-smoke 2>/dev/null || true; rm -rf "$runtime"' EXIT
    timeout 90 runuser -u kionite-smoke -- env XDG_RUNTIME_DIR="$runtime" \
      QT_QPA_PLATFORM=offscreen dbus-run-session -- bash -c '
        set -euo pipefail
        kwin_wayland --virtual --socket kionite-smoke --no-lockscreen &
        kwin_pid=$!
        plasma_pid=
        trap '\''kill ${plasma_pid:-} "$kwin_pid" 2>/dev/null || true; wait || true'\'' EXIT
        for attempt in {1..30}; do
            kill -0 "$kwin_pid"
            [[ -S "$XDG_RUNTIME_DIR/kionite-smoke" ]] && break
            sleep 1
        done
        test -S "$XDG_RUNTIME_DIR/kionite-smoke"
        WAYLAND_DISPLAY=kionite-smoke QT_QPA_PLATFORM=wayland plasmashell &
        plasma_pid=$!
        sleep 15
        kill -0 "$kwin_pid"
        kill -0 "$plasma_pid"
        echo "Virtual KWin and Plasma started and remained running"
      ' > /tmp/kionite-desktop-smoke.log 2>&1
    echo 'Virtual KWin and Plasma startup passed (details: /tmp/kionite-desktop-smoke.log)'
fi
echo 'Basic boot, desktop startup, DNS and plugin-file checks passed'

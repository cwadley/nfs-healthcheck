#!/bin/sh
# Single-shot check: exit 0 if MOUNT_PATH is an NFS mount, 1 otherwise.
# Docker's HEALTHCHECK directives (interval/retries/start-period) handle the
# waiting, so this script intentionally does not loop.

MOUNT_PATH="${MOUNT_PATH:-/mnt/nfs}"

# Debug logging is opt-in: the probe runs every few seconds, so verbose output
# is silenced by default to avoid flooding `docker inspect` health logs.
# Enable by setting DEBUG to 1/true/yes (case-insensitive).
case "$(echo "${DEBUG:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) DEBUG_ENABLED=1 ;;
    *) DEBUG_ENABLED=0 ;;
esac

debug() {
    [ "$DEBUG_ENABLED" = "1" ] || return 0
    echo "[healthcheck $(date '+%Y-%m-%dT%H:%M:%S%z')] $*" >&2
}

debug "checking MOUNT_PATH=$MOUNT_PATH"

if [ ! -e "$MOUNT_PATH" ]; then
    debug "path does not exist"
elif [ ! -d "$MOUNT_PATH" ]; then
    debug "path exists but is not a directory"
else
    debug "path exists and is a directory"
fi

# stat -f -c %T reports the filesystem type; NFS mounts report "nfs" or "nfs4"
fs_type=$(stat -f -c "%T" "$MOUNT_PATH" 2>/dev/null)
stat_rc=$?
debug "stat -f exit=$stat_rc fs_type=${fs_type:-unknown}"

# Surface any mount-table entries for the path to help diagnose propagation
# issues (e.g. an rslave bind mount that never received the host's NFS mount).
if [ "$DEBUG_ENABLED" = "1" ]; then
    mounts=$(grep -F "$MOUNT_PATH" /proc/mounts 2>/dev/null)
    if [ -n "$mounts" ]; then
        debug "matching /proc/mounts entries:"
        echo "$mounts" | while IFS= read -r line; do debug "  $line"; done
    else
        debug "no /proc/mounts entries reference $MOUNT_PATH"
    fi
fi

case "$fs_type" in
    nfs|nfs4)
        debug "healthy: NFS mount detected at $MOUNT_PATH (type: $fs_type)"
        exit 0
        ;;
esac

echo "NFS not mounted at $MOUNT_PATH (filesystem type: ${fs_type:-unknown})" >&2
exit 1

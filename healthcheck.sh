#!/bin/sh
# Single-shot check: exit 0 if MOUNT_PATH is an NFS mount, 1 otherwise.
# Docker's HEALTHCHECK directives (interval/retries/start-period) handle the
# waiting, so this script intentionally does not loop.

MOUNT_PATH="${MOUNT_PATH:-/mnt/nfs}"

# stat -f -c %T reports the filesystem type; NFS mounts report "nfs" or "nfs4"
fs_type=$(stat -f -c "%T" "$MOUNT_PATH" 2>/dev/null || true)
case "$fs_type" in
    nfs|nfs4) exit 0 ;;
esac

echo "NFS not mounted at $MOUNT_PATH (filesystem type: ${fs_type:-unknown})" >&2
exit 1

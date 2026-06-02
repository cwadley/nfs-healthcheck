# nfs-healthcheck

A lightweight Docker container that reports **healthy only once a host NFS mount
is actually present** — including mounts that appear *after* the container
starts. Use it as a startup gate so dependent services don't come up before
their NFS storage is ready.

## How it works

The container bind-mounts a host path with `rslave` propagation, then runs a
single-shot healthcheck (`healthcheck.sh`) that inspects the filesystem type at
that path via `stat -f -c %T`. It reports healthy only when the type is `nfs`
or `nfs4` — so an empty or not-yet-mounted directory stays unhealthy.

Docker's `HEALTHCHECK` directives (`interval` / `retries` / `start-period`)
drive the polling; the script itself does not loop. The container's main
process is just `tail -f /dev/null`, keeping it alive so Docker can keep probing
and dependent services can gate on its health.

### Why `rslave`?

The main purpose of the healthcheck is to detect a **late** host mount. With Docker's default
`rprivate` bind propagation, an NFS mount that appears on the host *after* the
container starts would never become visible inside it. `rslave` lets the
container receive mount events from the host.

For this to work, the host mount source must be **shared**:

```sh
mount --make-rshared /mnt/nfs
```

(or configure it persistently, e.g. systemd `MountFlags=shared`, or
`mount --make-rshared /` early in boot).

## Usage

```sh
docker compose up -d
```

Check status:

```sh
docker compose ps          # STATUS column shows (healthy) once mounted
docker inspect --format '{{.State.Health.Status}}' <container>
```

### Configuration

Both settings are overridable via environment variable or a `.env` file in the
project root — no rebuild required:

| Variable        | Default                  | Description                                                        |
| --------------- | ------------------------ | ------------------------------------------------------------------ |
| `NFS_HOST_PATH` | `/mnt/nfs`               | Host path of the NFS mount to watch.                               |
| `START_PERIOD`  | `30s`                    | Grace window before failed probes count. Go duration (`s`/`m`/`h`).|
| `DEBUG`         | _(off)_                  | Set to `1`/`true`/`yes` for verbose per-probe diagnostics.          |

```sh
# Inline
NFS_HOST_PATH=/srv/nfs/data START_PERIOD=5m docker compose up -d
```

```ini
# .env
NFS_HOST_PATH=/srv/nfs/data
START_PERIOD=5m
```

> If `NFS_HOST_PATH` contains whitespace, quote it in `.env`
> (e.g. `NFS_HOST_PATH="/mnt/my pool"`) so Compose treats it as a
> single path.

If the NFS mount may take minutes to come up, raise `START_PERIOD` to cover
that window — otherwise the container may briefly report `unhealthy` before it
recovers (it still flips back to `healthy` once the mount appears).

#### Debugging

The probe is quiet by default. Set `DEBUG=1` to log, on every probe, the path
being checked, whether it exists, the detected filesystem type, and any
`/proc/mounts` entries that reference it — useful for diagnosing mount
propagation issues (e.g. an `rslave` bind that never received the host mount):

```sh
DEBUG=1 docker compose up -d
docker inspect --format '{{range .State.Health.Log}}{{.Output}}{{end}}' <container>
```

Turn it back off once you're done, since it logs on every interval.

## Using it as a dependency gate

Other services can wait for the mount before starting:

```yaml
services:
  app:
    image: my-app
    depends_on:
      nfs-healthcheck:
        condition: service_healthy
```

## Files

| File                 | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `Dockerfile`         | Alpine image + `HEALTHCHECK` (static 30s fallback).  |
| `healthcheck.sh`     | Single-shot NFS-mount check.                         |
| `docker-compose.yml` | Bind mount, `rslave` propagation, configurable knobs.|

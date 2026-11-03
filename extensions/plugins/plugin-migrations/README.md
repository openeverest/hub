# Migrations

An OpenEverest generic plugin that moves databases **into** OpenEverest with
minimal downtime, much like AWS DMS. It adds a **Migrations** page to the
sidebar.

**How it works:**
- **Full load**: a per-migration worker copies the existing data from the
  source to the target instance.
- **Change data capture**: the worker keeps the target in sync with ongoing
  changes on the source, with replication lag shown live.
- **Cutover**: stop writes on the source, wait for the lag to reach zero and
  click **Cutover** to finalize the target. Pause and resume are available
  while changes are being replicated.

Migration records are Kubernetes ConfigMaps, so migrations survive plugin
restarts and upgrades; the worker checkpoints its progress in the target.

**Engines:**

| Engine | Source | Target |
| --- | --- | --- |
| Percona ClusterSync for MongoDB | MongoDB replica set or sharded cluster (an OpenEverest instance or an external connection string) | OpenEverest `percona-server-mongodb` instance |

Options include namespace include/exclude filters, pausing once the initial
sync completes, and clone/replication worker tuning.

## Requirements

- A Percona Server for MongoDB provider for the target instance.
- MongoDB sources must be replica sets or sharded clusters (change streams
  are required); external sources must be reachable from the worker pods.
- One migration per target instance at a time.

## Source

- **Plugin repo:** https://github.com/openeverest/plugin-migrations
- **Chart:** `oci://ghcr.io/openeverest/charts/plugin-migrations`

## Install (manual)

```bash
helm upgrade plugin-migrations \
  oci://ghcr.io/openeverest/charts/plugin-migrations \
  --version 0.1.0 \
  --namespace everest-system \
  --install
```

See the [plugin README](https://github.com/openeverest/plugin-migrations#readme)
for worker resources, placement and other values.

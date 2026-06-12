# Plugin Hub

An OpenEverest generic plugin that surfaces the [official extension catalog](https://github.com/openeverest/hub)
directly in the OpenEverest UI, showing which plugins and providers are
available and which are currently installed on your cluster.

**Features:**
- Searchable, filterable table of all catalog entries (plugins and providers)
- Install status, default-channel version, and categories per entry
- Per-entry detail drawer with a copy-pasteable `helm install` command
- Backend-side join of the hub catalog and the live `InstalledExtension` list (one round-trip)
- Stale-tolerant: catalog is cached with a 5-minute TTL; last successful
  response is served with `X-Hub-Stale: true` if the upstream is unreachable

## Source

- **Plugin repo:** https://github.com/openeverest/plugin-hub
- **Chart:** `oci://ghcr.io/openeverest/charts/plugin-hub`

## Install (manual)

```bash
helm install plugin-hub \
  oci://ghcr.io/openeverest/charts/plugin-hub \
  --version 0.1.2 \
  --namespace everest-system
```

Open the OpenEverest UI — **Plugin Hub** appears in the sidebar.

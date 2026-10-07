# Inspector

An OpenEverest generic plugin that adds an **Inspector** tab to database
cluster detail pages.

**Features:**
- See the pods behind an instance as a diagram or a table, with status,
  readiness, restarts and node placement
- Stream or tail container logs
- Describe a pod: containers, conditions and events, similar to `kubectl describe`

Works with any provider. Users only see pods of instances they are allowed to read.

## Source

- **Plugin repo:** https://github.com/openeverest/plugin-inspector
- **Chart:** `oci://ghcr.io/openeverest/charts/plugin-inspector`

## Install (manual)

```bash
helm upgrade plugin-inspector \
  oci://ghcr.io/openeverest/charts/plugin-inspector \
  --version 0.1.0 \
  --namespace everest-system \
  --install
```

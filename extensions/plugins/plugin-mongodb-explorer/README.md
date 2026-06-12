# MongoDB Explorer

An OpenEverest generic plugin that adds a **MongoDB Explorer** tab to PSMDB
cluster detail pages.

**Features:**
- Browse databases and collections in the cluster
- Run `find` queries with filter, projection, limit, and sort
- View results as a table or raw JSON

## Source

- **Plugin repo:** https://github.com/openeverest/plugin-mongodb-explorer
- **Chart:** `oci://ghcr.io/openeverest/charts/plugin-mongodb-explorer`

## Install (manual)

```bash
helm upgrade mongo-explorer \
  oci://ghcr.io/openeverest/charts/plugin-mongodb-explorer \
  --version 0.1.14 \
  --namespace everest-system \
  --install
```

## Known prerequisite

The backend requires the
`GET /v1/namespaces/{ns}/database-clusters/{name}/connection-details` endpoint
to fetch short-lived MongoDB credentials. This endpoint must be available in
the OpenEverest core for the plugin to connect to real clusters.

# TiDB

Distributed, MySQL-compatible [TiDB](https://github.com/pingcap/tidb) clusters
managed by [TiDB Operator v2](https://github.com/pingcap/tidb-operator), wrapped
as an OpenEverest provider.

Provisions the standard distributed `cluster` topology (PD + TiKV + TiDB) with
provisioning, horizontal and vertical scaling, per-component storage, and inline
TOML configuration. A random `root` password is generated and exposed through the
connection secret.

## Source

- **Provider repo:** https://github.com/openeverest/provider-tidb
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-tidb`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-tidb \
  oci://ghcr.io/openeverest/charts/provider-tidb \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

TiDB Operator v2 ships as a bundled Helm subchart and its CRDs are shipped in the
chart, so both are installed automatically with the provider — no separate install
step is required.

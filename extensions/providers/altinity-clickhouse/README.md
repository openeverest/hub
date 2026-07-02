# Altinity ClickHouse

ClickHouse clusters managed by the
[Altinity Kubernetes Operator for ClickHouse](https://github.com/Altinity/clickhouse-operator),
wrapped as an OpenEverest **provider**.

Supports standalone and replicated topologies. The replicated topology
provisions a 3-node ClickHouse Keeper Raft quorum automatically — no
ZooKeeper required.

## Source

- **Provider repo:** https://github.com/openeverest/provider-altinity-clickhouse
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-altinity-clickhouse`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-altinity-clickhouse \
  oci://ghcr.io/openeverest/charts/provider-altinity-clickhouse \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

The Altinity ClickHouse operator ships as a bundled Helm subchart and is
installed automatically with the provider — no separate install step is
required.

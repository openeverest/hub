# Apache Cassandra

Apache Cassandra on Kubernetes, wrapped as an OpenEverest **provider** and
backed by the [k8ssandra-operator](https://github.com/k8ssandra/k8ssandra-operator).

> [!WARNING]
> **Pre-alpha / very early stage.** CRD schemas, chart values and defaults
> change frequently, including in breaking ways, and there is no supported
> upgrade path between versions yet. Not for production use.

## Source

- **Provider repo:** https://github.com/openeverest/provider-cassandra
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-cassandra`

## Supported

- Provisioning (`singleDatacenter` topology)
- Horizontal scaling (`replicas`)
- Vertical scaling (CPU / memory)
- Cassandra version upgrades (`4.1`, `5.0`)
- Persistent storage and storage expansion
- On-demand and scheduled backups, in-place restore (via Medusa, S3-compatible
  storage)

## Not yet supported

- **PITR**
- **Monitoring** — optional Prometheus component; wiring is in progress
- **TLS**
- **Multi-datacenter topologies** — only `singleDatacenter` is available

## Install (manual)

The provider bundles the k8ssandra-operator (cass-operator + Medusa CRDs) and
installs it automatically. The operator's admission webhooks require
[cert-manager](https://cert-manager.io) to be present in the cluster first.

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-cassandra \
  oci://ghcr.io/openeverest/charts/provider-cassandra \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

This provider is **not standalone** — it requires an OpenEverest installation
(core CRDs and controller) in the cluster.

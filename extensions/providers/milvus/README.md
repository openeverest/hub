# Milvus

[Milvus](https://milvus.io) vector database on Kubernetes, wrapped as an
OpenEverest **provider** and backed by the
[Milvus Operator](https://github.com/zilliztech/milvus-operator).

> [!WARNING]
> **Pre-alpha / very early stage.** CRD schemas, chart values and defaults
> change frequently, including in breaking ways, and there is no supported
> upgrade path between versions yet. Not for production use.

## Source

- **Provider repo:** https://github.com/openeverest/provider-milvus
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-milvus`

## Supported

- Provisioning: `standalone` and `cluster` (Milvus 2.6) topologies
- Bundled or external etcd, object storage (MinIO) and Pulsar
- Horizontal and vertical scaling per component
- Milvus version upgrades
- Dependency storage expansion
- Exposure via ClusterIP, NodePort or LoadBalancer
- Per-component pod scheduling policy
- Generated `root` credential published to the connection Secret

## Not yet supported

- **Backups / restores / PITR**
- **TLS**
- **Monitoring**

## Install (manual)

The provider bundles the Milvus Operator and installs it automatically.

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-milvus \
  oci://ghcr.io/openeverest/charts/provider-milvus \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

This provider is **not standalone** — it requires an OpenEverest installation
(core CRDs and controller) in the cluster.

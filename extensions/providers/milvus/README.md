# Milvus

Milvus vector database on Kubernetes, wrapped as an OpenEverest **provider** and
backed by the [Milvus Operator](https://github.com/zilliztech/milvus-operator).

> [!WARNING]
> **Pre-alpha / very early stage.** CRD schemas, chart values and defaults
> change frequently, including in breaking ways, and there is no supported
> upgrade path between versions yet. Not for production use.

## Source

- **Provider repo:** https://github.com/openeverest/provider-milvus
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-milvus`

## Supported

- Provisioning (`standalone` and `cluster` topologies)
- Horizontal scaling (`replicas`)
- Vertical scaling (CPU / memory)
- Milvus version upgrades (`2.6`)
- Persistent storage

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-milvus \
  oci://ghcr.io/openeverest/charts/provider-milvus \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

The `milvus-operator` (and its CRDs) ships as a bundled Helm subchart and is
installed automatically with the provider — no separate install step is
required.

# SeaweedFS

Distributed object storage with an S3-compatible gateway on Kubernetes,
powered by the
[seaweedfs-operator](https://github.com/seaweedfs/seaweedfs-operator),
wrapped as an OpenEverest provider.

Provisions master, volume, filer, and S3 gateway components under a
`standalone` topology. SeaweedFS is object/file storage — not a database.

> This provider is an MVP prototype. Do not use in production.

## Source

- **Provider repo:** https://github.com/openeverest/provider-seaweedfs
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-seaweedfs`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-seaweedfs \
  oci://ghcr.io/openeverest/charts/provider-seaweedfs \
  --version 0.1.1 \
  --namespace everest-system \
  --create-namespace
```

The `seaweedfs-operator` ships as a bundled Helm dependency and is installed
automatically when `seaweedfs-operator.enabled` is `true` (the default).

# Percona Server for MongoDB

Production-ready MongoDB clusters managed by the
[Percona Operator for MongoDB](https://github.com/percona/percona-server-mongodb-operator),
wrapped as an OpenEverest **provider**.

Supports replica-set and sharded-cluster topologies, point-in-time recovery, and
the standard Percona toolset (backups via PBM, monitoring via PMM).

## Source

- **Provider repo:** https://github.com/openeverest/provider-percona-server-mongodb
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-percona-server-mongodb`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-percona-server-mongodb \
  oci://ghcr.io/openeverest/charts/provider-percona-server-mongodb \
  --version 0.7.2 \
  --namespace everest-system \
  --create-namespace
```

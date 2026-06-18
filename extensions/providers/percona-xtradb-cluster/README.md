# Percona XtraDB Cluster

Highly available MySQL clusters managed by the
[Percona Operator for MySQL based on Percona XtraDB Cluster](https://github.com/percona/percona-xtradb-cluster-operator),
wrapped as an OpenEverest **provider**.

## Source

- **Provider repo:** https://github.com/openeverest/provider-percona-xtradb-cluster
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-percona-xtradb-cluster`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-percona-xtradb-cluster \
  oci://ghcr.io/openeverest/charts/provider-percona-xtradb-cluster \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

# MariaDB

MariaDB clusters managed by the
[mariadb-operator](https://github.com/mariadb-operator/mariadb-operator),
wrapped as an OpenEverest provider.

Supports standalone, primary/replica replication and Galera topologies with
TLS, MaxScale routing, scheduled backups to S3 with point-in-time recovery,
horizontal and vertical scaling, version upgrades, custom `my.cnf`
configuration, and optional Prometheus monitoring.

## Source

- **Provider repo:** https://github.com/openeverest/provider-mariadb
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-mariadb`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-mariadb \
  oci://ghcr.io/openeverest/charts/provider-mariadb \
  --version 0.1.2 \
  --namespace everest-system \
  --create-namespace
```

The `mariadb-operator` (and its CRDs) ships as a bundled Helm subchart and is
installed automatically with the provider — no separate install step is
required.

# PMM

Send the metrics and Query Analytics of OpenEverest database instances to a
[Percona Monitoring and Management](https://docs.percona.com/percona-monitoring-and-management/)
(PMM) 3 server. An OpenEverest **integration** (area: monitoring).

## How it fits

- **Class.** The chart installs the `pmm` `MonitoringClass` and its controller.
  The class is **ProviderManaged**: providers that integrate PMM natively
  (`pmm` in `Provider.spec.monitoring.integrations` — Percona XtraDB Cluster,
  Percona Server for MongoDB, Percona PostgreSQL) run pmm-client next to the
  databases themselves.
- **Destination.** A `pmm` `MonitoringDestination` points at a PMM server
  (`parameters.url`) and a Secret holding an Admin service-account token. The
  controller checks the server and token and reports `Ready`.
- **Instance entry.** Listing the destination under
  `spec.monitoring.destinations[]` of an Instance sends its monitoring there.

## Prerequisites

- OpenEverest `2.0.0-dev.5` or later (monitoring API).
- A [PMM 3 server](https://docs.percona.com/percona-monitoring-and-management/3/install-pmm/install-pmm-server/deployment-options/helm/index.html)
  reachable from the cluster.

## Source

- **Repo:** https://github.com/openeverest/monitoring-pmm
- **Chart:** `oci://ghcr.io/openeverest/charts/monitoring-pmm`

## Install (manual)

```bash
helm install monitoring-pmm \
  oci://ghcr.io/openeverest/charts/monitoring-pmm \
  --version 0.1.0 \
  --namespace everest-system
```

See the [repo README](https://github.com/openeverest/monitoring-pmm#readme)
for connecting a PMM server and the chart values.

# Releem

Send the metrics and query statistics of OpenEverest MySQL, MariaDB and PostgreSQL instances
to [Releem](https://releem.com), which recommends configuration and query changes. An
OpenEverest **integration** (area: monitoring).

## How it fits

- **Class.** The chart installs the `releem` `MonitoringClass` and its controller. The class
  is **ExtensionManaged** and requires connections for components of kind `mysql`, `mariadb`
  and `postgresql`: the provider publishes a read-only monitoring user (the `monitor`
  credential profile) and one connection endpoint per database pod.
- **Destination.** A `MonitoringDestination` of the class holds the Releem API key (`APIKey`
  mode, key `apiKey`) and the Releem region (`US` or `EU`).
- **Instance entry.** Listing the destination under `spec.monitoring.destinations[]` of an
  Instance makes the controller run one `releem-agent` per database pod, as Releem
  recommends for clusters, each reporting as a separate server. The database pods are not
  restarted. Releem only recommends: OpenEverest applies no configuration.

## Prerequisites

- OpenEverest `2.0.0-alpha.1` or later.
- A Releem account and API key; query analytics needs a paid plan.
- A provider that publishes the monitoring user and connections (its `Provider` declares
  `connection: Supported`). Support is being added to the CloudNativePG and Percona XtraDB
  Cluster providers.

## Source

- **Repo:** https://github.com/openeverest/monitoring-releem
- **Chart:** `oci://ghcr.io/openeverest/charts/monitoring-releem`

## Install (manual)

```bash
helm install monitoring-releem \
  oci://ghcr.io/openeverest/charts/monitoring-releem \
  --version 0.1.1 \
  --namespace everest-system
```

See the [repo README](https://github.com/openeverest/monitoring-releem#readme) for
destination parameters and chart values.

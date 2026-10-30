# Prometheus

Send the metrics of OpenEverest database instances to a Prometheus run by the
[Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator).
An OpenEverest **integration** (area: monitoring).

## How it fits

- **Class.** The chart installs the `prometheus` `MonitoringClass` and its
  controller. The class is **ExtensionManaged** and requires metrics: providers
  only expose metrics endpoints (natively or through an exporter sidecar).
- **Destination.** A `MonitoringDestination` of the class says how the
  generated PodMonitors are labelled and how often they are scraped.
- **Instance entry.** Listing the destination under
  `spec.monitoring.destinations[]` of an Instance makes the controller render
  one `PodMonitor` per database component, which your Prometheus picks up
  through its `podMonitorSelector`.

## Prerequisites

- OpenEverest `2.0.0-dev.5` or later (monitoring API).
- The Prometheus Operator (`v0.79` or later) and a `Prometheus` that selects
  the generated PodMonitors, e.g. from
  [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

## Source

- **Repo:** https://github.com/openeverest/monitoring-prometheus
- **Chart:** `oci://ghcr.io/openeverest/charts/monitoring-prometheus`

## Install (manual)

```bash
helm install monitoring-prometheus \
  oci://ghcr.io/openeverest/charts/monitoring-prometheus \
  --version 0.1.0 \
  --namespace everest-system
```

See the [repo README](https://github.com/openeverest/monitoring-prometheus#readme)
for destination parameters and chart values.

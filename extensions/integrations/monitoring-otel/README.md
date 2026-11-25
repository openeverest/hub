# OpenTelemetry

Send the metrics of OpenEverest database instances to any
[OTLP](https://opentelemetry.io/docs/specs/otlp/) receiver: Grafana Cloud, Datadog, Elastic,
an OpenTelemetry Collector you run, or Prometheus and VictoriaMetrics through their OTLP
endpoints. An OpenEverest **integration** (area: monitoring).

## How it fits

- **Class.** The chart installs the `opentelemetry` `MonitoringClass` and its controller. The
  class is **ExtensionManaged** and requires metrics: providers only expose metrics endpoints
  (natively or through an exporter sidecar).
- **Destination.** A `MonitoringDestination` of the class holds the OTLP endpoint (gRPC or
  HTTP), extra headers and an authentication mode (`Anonymous`, `BasicAuth`, `BearerToken`
  or `APIKey`). The controller runs one OpenTelemetry Collector per destination.
- **Instance entry.** Listing the destination under `spec.monitoring.destinations[]` of an
  Instance makes the controller render one `PodMonitor` per database component, which the
  destination's collector scrapes and exports over OTLP. Adding or removing Instances does not
  restart the collector.

## Prerequisites

- OpenEverest `2.0.0-alpha.1` or later.
- [cert-manager](https://cert-manager.io).
- The Prometheus Operator CRDs (no Prometheus needed).
- The [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
  (`v0.162` or later), with a collector image such as `otel/opentelemetry-collector-k8s`.

## Source

- **Repo:** https://github.com/openeverest/monitoring-otel
- **Chart:** `oci://ghcr.io/openeverest/charts/monitoring-otel`

## Install (manual)

```bash
helm install monitoring-otel \
  oci://ghcr.io/openeverest/charts/monitoring-otel \
  --version 0.1.1 \
  --namespace everest-system
```

See the [repo README](https://github.com/openeverest/monitoring-otel#readme) for destination
parameters and chart values.

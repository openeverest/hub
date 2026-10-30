# Coroot

Send the databases of OpenEverest instances to [Coroot](https://coroot.com).
An OpenEverest **integration** (area: monitoring).

## How it fits

- **Class.** The chart installs the `coroot` `MonitoringClass` and its
  controller. The class is **ExtensionManaged** and requires connections:
  providers publish native-protocol connection endpoints and accept pod
  annotations.
- **Destination.** A `coroot` `MonitoringDestination` has no parameters —
  coroot-cluster-agent is configured with the Coroot server and API key when
  it is installed.
- **Instance entry.** Listing the destination under
  `spec.monitoring.destinations[]` of an Instance makes the controller request
  `coroot.com/<db>-scrape*` annotations on its pods, through which
  coroot-cluster-agent discovers and connects to each database.

## Prerequisites

- OpenEverest `2.0.0-dev.5` or later with the monitoring connection sources
  API ([openeverest/openeverest#3502](https://github.com/openeverest/openeverest/pull/3502)),
  and a provider that supports connections (e.g. Percona Server for MongoDB).
- [Coroot with coroot-cluster-agent](https://docs.coroot.com/installation/k8s-operator).

## Source

- **Repo:** https://github.com/openeverest/monitoring-coroot
- **Chart:** `oci://ghcr.io/openeverest/charts/monitoring-coroot`

## Install (manual)

```bash
helm install monitoring-coroot \
  oci://ghcr.io/openeverest/charts/monitoring-coroot \
  --version 0.1.0 \
  --namespace everest-system
```

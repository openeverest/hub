# Performance Benchmark

An OpenEverest generic plugin that runs `pgbench` benchmarks against
PostgreSQL clusters managed by OpenEverest.

**Features:**
- Start a benchmark from the cluster detail page
- Each run executes in a temporary Kubernetes Job with a dedicated pgbench runner image
- View TPS, latency, and failed transactions when the run completes

Supported providers: `provider-cloudnative-pg`, `provider-percona-postgresql`.

## Source

- **Plugin repo:** https://github.com/openeverest/plugin-bench
- **Chart:** `oci://ghcr.io/openeverest/charts/plugin-bench`

## Install (manual)

```bash
helm upgrade plugin-bench \
  oci://ghcr.io/openeverest/charts/plugin-bench \
  --version 0.1.0 \
  --namespace everest-system \
  --install
```

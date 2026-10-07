# Performance Benchmark

An OpenEverest generic plugin that benchmarks the performance of database
clusters managed by OpenEverest.

**Features:**
- Start a benchmark from the cluster detail page
- Each run executes in a temporary Kubernetes Job with a dedicated runner image
- View throughput, latency, and failed transactions when the run completes

PostgreSQL is supported today (via `pgbench`, for `provider-cloudnative-pg` and
`provider-percona-postgresql`); more database engines are planned.

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

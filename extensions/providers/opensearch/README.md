# OpenSearch

Run **OpenSearch** clusters managed by the
[OpenSearch Kubernetes Operator](https://github.com/opensearch-project/opensearch-k8s-operator),
wrapped as an OpenEverest **provider**.

Supports the standard topology (every node cluster-manager eligible and holds
data), optional OpenSearch Dashboards, always-on TLS for transport and HTTP,
and on-demand and scheduled snapshot backups/restore to S3-compatible storage.

## Source

- **Provider repo:** https://github.com/openeverest/provider-opensearch
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-opensearch`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-opensearch \
  oci://ghcr.io/openeverest/charts/provider-opensearch \
  --version 0.1.0 \
  --namespace everest-system \
  --create-namespace
```

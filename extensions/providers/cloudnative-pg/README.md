# CloudNativePG

Highly available PostgreSQL clusters managed by
[CloudNativePG](https://cloudnative-pg.io/), wrapped as an OpenEverest
**provider**.

Supports replica-set topologies with bootstrap configuration, managed roles,
and PostgreSQL tuning. The CloudNativePG operator ships as a bundled Helm
subchart and is installed automatically with the provider.

> This provider is in development/testing. Do not use in production.

## Source

- **Provider repo:** https://github.com/openeverest/provider-cloudnative-pg
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-cloudnative-pg`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-cloudnative-pg \
  oci://ghcr.io/openeverest/charts/provider-cloudnative-pg \
  --version 0.4.1 \
  --namespace everest-system \
  --create-namespace
```

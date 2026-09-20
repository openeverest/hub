# KServe

Machine-learning and LLM model serving on Kubernetes powered by
[KServe](https://kserve.github.io/website/), wrapped as an OpenEverest
**provider**.

Supports two topologies: `llm` (generative serving via vLLM, backed by KServe's
`LLMInferenceService`) and `predictor` (predictive model serving via KServe's
`InferenceService`). Ships GPU scheduling, autoscaling, optional TLS on the
shared Envoy AI Gateway, and a curated Hugging Face model catalog surfaced in
the UI.

> This provider is in development/testing. Do not use in production.

## Source

- **Provider repo:** https://github.com/openeverest/provider-kserve
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-kserve`

## Install (manual)

> The OpenEverest CLI install path (`everestctl extension install`) ships in
> Phase 2. Until then, use Helm directly:

```bash
helm install provider-kserve \
  oci://ghcr.io/openeverest/charts/provider-kserve \
  --version 0.1.2 \
  --namespace everest-system \
  --create-namespace
```

The chart bundles the KServe controllers and cert-manager, so a single
`helm install` yields a working stack. When the cluster already runs
cert-manager, install with `--set cert-manager.enabled=false` to use the
existing one. See the [provider README](https://github.com/openeverest/provider-kserve#readme)
for KServe CRD handling, GPU/CPU compute profiles, and gated-model tokens.

# Generic Plugin Template

A working OpenEverest [generic plugin](https://github.com/openeverest/specs/blob/main/specs/003-generic-plugins.md)
that registers:

- A **sidebar entry** in the OpenEverest navigation.
- A **route** at `/plugins/my-plugin` with a hello page and backend connectivity check.
- A **cluster-detail tab** on every database cluster page showing cluster metadata.
- A **backend API** under `/api/...` demonstrating the request flow
  (browser → host proxy → backend) with the `X-Everest-User` JWT.

It is intended as a starting point: install it as-is to see the integration
points light up in the UI, then fork the upstream repo and customize.

## Source

- **Plugin repo:** https://github.com/openeverest/generic-plugin-template
- **Chart:** `oci://ghcr.io/openeverest/charts/my-plugin`

> **Note on naming.** The hub slug is `generic-plugin-template` (matches the
> source repo). The Helm chart is named `my-plugin` and the default release
> name is `my-plugin` — those names come from the template itself and are
> intentionally generic so the template can be cloned without renaming as a
> first step. The two fields are independent in the formula schema.

## Frontend bundle

This plugin **does not** publish a separate OCI frontend artifact. The bundle
(`main.js`) is built into the backend container image and served by the
backend's `GET /main.js` endpoint, which the OpenEverest shell fetches at
startup. That is why the formula has no `spec.artifacts.frontend` block even
though it contributes UI.

## Install (manual)

```bash
helm install my-plugin \
  oci://ghcr.io/openeverest/charts/my-plugin \
  --version 0.1.0 \
  --namespace everest-system
```

Open the OpenEverest UI — "My Plugin" will appear in the sidebar.

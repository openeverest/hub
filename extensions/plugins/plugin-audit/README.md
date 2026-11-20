# Audit

An OpenEverest generic plugin that subscribes to the platform event stream,
stores every event and adds an **Audit** page to the sidebar for browsing the
audit log: who did what, when, to which resource.

**Features:**
- Events over time, stacked by severity, with preset or custom time ranges.
- Filters by engine, kind, event reason, namespace, actor, severity and
  database/object name, plus free-text search. Filters are kept in the URL so
  a view can be shared.
- Export of the matching events as CSV or JSON.

Events are stored in an embedded SQLite database on a persistent volume.

## Requirements

The plugin reads events as an OpenEverest user. Create a Secret with `username`
and `password` keys for a user allowed to read events (the admin role, or a
dedicated read-only auditor role), and pass its name as
`auth.credentialsSecretName`. See the
[plugin README](https://github.com/solanicaio/plugin-audit#readme) for the
RBAC policy of an auditor role.

## Source

- **Plugin repo:** https://github.com/solanicaio/plugin-audit
- **Chart:** `oci://ghcr.io/solanicaio/charts/audit`

## Install (manual)

```bash
helm upgrade audit \
  oci://ghcr.io/solanicaio/charts/audit \
  --version 0.2.0 \
  --namespace everest-system \
  --set image.repository=ghcr.io/solanicaio/plugin-audit \
  --set auth.credentialsSecretName=<secret-name> \
  --install
```

`image.repository` must be set: the chart's default image repository is not
published.

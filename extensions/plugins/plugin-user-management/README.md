# User Management

An OpenEverest generic plugin for managing database users and their roles, so
teams stop sharing the admin account and don't need a database shell to
onboard an application. It adds a **Users** tab to instance detail pages.

**Features:**
- Create, edit and delete database users and their roles from the UI, or
  declare them as `InstanceUser` resources with `kubectl` or GitOps; the
  plugin keeps the database in sync either way
- Generated credentials are stored in a `<name>-credentials` Secret with
  `username`, `password` and `uri` keys that applications can mount; editing
  the password rotates it in the database
- Bring your own password through a Secret reference
- Deleting a user drops it from the database; users are deleted together with
  their instance
- For models served through the Envoy AI Gateway, the same users are API keys:
  one per application, team or person instead of one shared key per model

**Supported providers:**

| Provider | Engine |
| --- | --- |
| `percona-server-mongodb` | Percona Server for MongoDB |
| `provider-cloudnative-pg` | CloudNativePG 1.30+ |
| `provider-kserve` | API keys for models on the Envoy AI Gateway |

Users only see and manage users of instances they are allowed to access.

## Source

- **Plugin repo:** https://github.com/openeverest/plugin-user-management
- **Chart:** `oci://ghcr.io/openeverest/charts/plugin-user-management`

## Install (manual)

```bash
helm upgrade plugin-user-management \
  oci://ghcr.io/openeverest/charts/plugin-user-management \
  --version 0.2.1 \
  --namespace everest-system \
  --install
```

The chart installs the `InstanceUser` CRD. See the
[plugin README](https://github.com/openeverest/plugin-user-management#readme)
for examples and all values.

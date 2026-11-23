# Publishing an extension to the OpenEverest Hub

This guide walks through adding a new **provider**, **generic plugin** or
**integration** to the [OpenEverest Extension Hub](https://github.com/openeverest/hub).

## Extension types

| `metadata.type` | Directory | What it is |
|---|---|---|
| `provider` | `extensions/providers/` | A database operator that OpenEverest manages. |
| `plugin` | `extensions/plugins/` | A UI / CLI / backend extension of OpenEverest itself. |
| `integration` | `extensions/integrations/` | A connection between OpenEverest and an external system. The first area is `monitoring`: charts that install a `MonitoringClass` and its controller (e.g. PMM, Prometheus, Coroot). More areas may be added later. |

## Prerequisites

- Your extension is published to an OCI-compatible registry (GHCR, Docker Hub,
  Quay, etc.) as a Helm chart.
- Your chart declares what it is compatible with in its own `Chart.yaml`, not
  in the formula: the OpenEverest stamp written by the provider SDK and a
  `kubeVersion`. See [Compatibility](#compatibility).
- You have a public source repository (any Git host).
- You're prepared to keep the formula's `version` field in sync with new
  releases (a [GitHub Action template](#automating-version-bumps) is provided
  to do this automatically).

## Submission steps

1. **Fork** [`openeverest/hub`](https://github.com/openeverest/hub) and clone
   your fork.

2. **Copy the template** into the appropriate directory:

   ```bash
   # For a provider:
   cp -R extensions/_template extensions/providers/<your-slug>

   # For a generic plugin:
   cp -R extensions/_template extensions/plugins/<your-slug>

   # For an integration:
   cp -R extensions/_template extensions/integrations/<your-slug>
   ```

   The slug must be lowercase, alphanumeric + hyphens, and globally unique
   across the hub. It must match the directory name and the `metadata.name`
   field in `formula.yaml`.

3. **Fill in `formula.yaml`** — see [the field reference](#field-reference)
   below and [`schemas/formula-v1.json`](../schemas/formula-v1.json) for the
   authoritative schema.

4. **Add a `README.md`** in the same directory. Keep it short — what the
   extension does, where the source lives, and how to install it with `helm`
   directly while the CLI install path is under development.

5. **Add a logo file** (svg/png/jpg/jpeg/webp/gif) and reference it from
   `metadata.icon` (e.g., `./logo.svg`). The build-index workflow expands
   this relative path into a fully-qualified `raw.githubusercontent.com`
   URL in `index.json`.

6. **Open a Pull Request** against `main`. The
   [validate workflow](../.github/workflows/validate.yaml) will run:
   - JSON Schema validation of every `formula.yaml`.
   - Directory-name ↔ `metadata.name` consistency check.
   - Required-files check (`formula.yaml`, `README.md`).
   - A run of the index generator against your chart's registry. It fails
     when a channel's `version` is not a SemVer version, or when that chart
     release was built against an unreleased OpenEverest (see
     [Compatibility](#compatibility)).

7. A hub maintainer reviews for metadata accuracy and naming. There is **no
   code review** — the formula is a pointer, not code. On merge, the
   [build-index workflow](../.github/workflows/build-index.yaml) regenerates
   `index/index.json` and commits it back to `main`. Your extension is then
   live at:

   ```
   https://raw.githubusercontent.com/openeverest/hub/main/index/index.json
   ```

## Field reference

Adapted from [spec 005 §4.3](https://github.com/openeverest/specs/blob/main/specs/005-extension-hub.md).
See [`schemas/formula-v1.json`](../schemas/formula-v1.json) for the full schema.

| Field | Required | Notes |
|---|---|---|
| `metadata.name` | yes | Must match the directory name; globally unique; lowercase alphanumeric + hyphens. |
| `metadata.type` | yes | `provider`, `plugin` or `integration`. Determines which of `spec.provider` / `spec.plugin` / `spec.integration` must be present, and must match the parent directory (`providers/`, `plugins/`, `integrations/`). |
| `metadata.displayName` | yes | Human-readable, max 64 chars. |
| `metadata.description` | yes | Max 500 chars. |
| `metadata.license` | yes | Valid [SPDX identifier](https://spdx.org/licenses/). |
| `metadata.maturity` | optional | Author-declared lifecycle stage: `alpha` \| `beta` \| `stable` \| `deprecated`. Defaults to `alpha` when omitted. Independent of channels (release cadence) and of operational health. |
| `metadata.maintainers` | yes | At least one entry; `github` handle is required. |
| `metadata.sourceRepo` | recommended | Public source repository URL. |
| `metadata.icon` | yes | Relative path to a logo file in this directory (e.g., `./logo.svg` or `./icon.png`). Must be `svg`, `png`, `jpg`, `jpeg`, `webp`, or `gif` and the file must be committed alongside `formula.yaml`. The build-index workflow expands this to a fully-qualified `raw.githubusercontent.com` URL in `index.json`. |
| `spec.provider` / `spec.plugin` / `spec.integration` | yes | Exactly one, matching `metadata.type`. |
| `spec.integration.area` | yes (integrations) | Integration area. Only `monitoring` today; the area selects the area-specific block below. |
| `spec.integration.monitoring.classes` | yes (area `monitoring`) | `MonitoringClass` names the chart installs (DNS-1123 labels, at least one). |
| `spec.integration.monitoring.executionModes` | yes (area `monitoring`) | At least one of `ProviderManaged` (the database provider renders the operator's native integration) or `ExtensionManaged` (the extension's controller does the work). |
| `spec.integration.monitoring.requires` | optional | What a provider's components must expose (ExtensionManaged): `metrics` (metrics endpoints) and/or `connection` (native-protocol connection endpoints and pod annotations), both booleans. |
| `spec.integration.monitoring.nativeIntegration` | optional | For ProviderManaged classes: the operator-native integration the class relies on, matched against `Provider.spec.monitoring.integrations` (e.g. `pmm`). |
| `spec.capabilities` | recommended | Map advertising provider/plugin features. Providers declare the core booleans `ha`, `monitoring`, `backups`, `pitr` and `encryption`, plus optional keys such as `topologies` and `versions`. See [CAPABILITIES.md](CAPABILITIES.md). Emitted verbatim in the index when non-empty. |
| `spec.artifacts.chart` | required for providers and integrations; required for plugins unless they ship only a frontend artifact | OCI chart reference. |
| `spec.artifacts.frontend` | optional | **Only set this if your plugin publishes a SEPARATE OCI frontend bundle.** Plugins that serve `main.js` from their own backend (the common case — see [`generic-plugin-template`](../extensions/plugins/generic-plugin-template/)) do **not** need this block. |
| `spec.artifacts.*.channels.*.digest` | optional in Phase 1, required from Phase 2 | SHA-256 OCI manifest digest. |
| `spec.install.helm.releaseName` | yes | Helm release name. Independent from `metadata.name` (chart authors often have their own conventions). |
| `spec.install.helm.namespace` | yes | See [namespace convention](#namespace-convention) below. |
| `spec.install.prerequisites` | optional | List of companion charts that must be installed before this extension. Integrations usually declare the external system they connect to here. See [install prerequisites](#install-prerequisites). |
| `spec.verification` | optional | Reserved for cosign / SBOM / SLSA metadata (Phase 5). |

## Namespace convention

Providers, plugins and integrations should install into **`everest-system`** — this is
the namespace the live OpenEverest v2 ecosystem uses (the
[`generic-plugin-template`](https://github.com/openeverest/generic-plugin-template)
and the core OpenEverest docs both use it).

> Spec 005 §4.3 mentions `openeverest-system` as the pinned namespace for
> providers. The live ecosystem standardised on `everest-system` instead.
> Both seed formulas in this repo use `everest-system`; the schema is
> intentionally unopinionated and accepts any valid DNS-1123 label.

## Install prerequisites

If your extension requires a companion chart to be installed before it declare it under `spec.install.prerequisites[]`.
Integrations usually declare the external system they connect to (e.g. a PMM
server, the Prometheus Operator or Coroot) here.
The hub displays these to the user with install instructions before they
proceed with the main extension install.

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Display name of the prerequisite. |
| `description` | optional | Why this prerequisite is needed. |
| `installUrl` | optional | Link to official installation docs. |
| `helm.oci` | yes (if `helm` is set) | OCI chart reference (`oci://...`). |
| `helm.namespace` | yes (if `helm` is set) | Namespace to install the prerequisite into. |
| `helm.version` | optional | Pinned chart version. |
| `helm.createNamespace` | optional | Creates the namespace if it does not exist. |
| `helm.defaultValues` | optional | Key-value pairs passed as `--set` flags during install. |

## Channels

Each artifact must declare a `defaultChannel` and at least one channel under
`channels`. The conventional channels are:

- `stable` — production-ready releases.
- `edge` — pre-releases, release candidates, nightly builds.

`defaultChannel` is what the CLI/UI installs unless the user explicitly
overrides with `--channel`.

A channel's `version` is its **head**, the newest release it offers. The
generated index also lists, under the channel's `releases[]` (newest first),
every published release of the chart that belongs to the channel, so an
installer can fall back to an older release when the head is not compatible
with the user's cluster. A release belongs to a channel when its tag in the
chart's OCI repository:

- is a valid [SemVer 2.0.0](https://semver.org) version,
- is not above the head, and
- is a pre-release exactly when the head is one.

A stable head such as `0.6.0` collects `0.5.0`, `0.4.1`, … but never
`0.6.0-rc.1`; an edge head such as `0.7.0-rc.2` collects `0.7.0-rc.1`,
`0.6.0-beta.1`, … but never `0.6.0`. Tags that are not SemVer (`latest`,
`sha-…`) are ignored, and tags above the head stay unlisted until a formula
change moves the head.

## Compatibility

Formulas do not declare which OpenEverest or Kubernetes versions an extension
works with. The hub reads both from the chart, release by release, so a new
OpenEverest release never leaves a formula stale and nobody maintains version
ranges by hand.

### OpenEverest: the contract stamp

OpenEverest core and its extensions share a contract: the CRDs, the HTTP API
and the conventions extensions rely on. Its version is the OpenEverest release
that last changed it, and each OpenEverest release accepts extensions built
against a window of contract versions, from a minimum up to its own.

The [provider SDK](https://github.com/openeverest/provider-sdk) records the
contract version of the OpenEverest a provider is built against in the chart's
`Chart.yaml` when you run `provider-sdk generate`:

```yaml
annotations:
  openeverest.io/contract-version: 2.0.0-alpha.1
```

Do not edit it, and do not write version ranges: the stamp is a single
version, and every installer compares it with the window of the cluster it
installs into. To support a newer OpenEverest, update the OpenEverest
dependency, regenerate and release a new chart.

The build-index workflow reads the stamp of every release in every channel
from the registry (from the chart's OCI config blob, so nothing is downloaded)
and publishes it as `releases[].contractVersion` in `index.json`. Installers
offer the newest release that is compatible with the cluster, and tell users
which OpenEverest version an incompatible release needs.

- A chart without the annotation is listed without `contractVersion`.
  Installers show it as "compatibility not declared" and let users install it
  with a notice. Plugins and integrations, which are not built with the
  provider SDK, are in this situation until their tooling writes the stamp.
- A stamp ending in `dev`, such as `2.0.0-alpha.1.dev` or `2.0.1-dev`, means
  the chart was built against an OpenEverest that is not released yet. Such
  releases are left out of the index, and the validate workflow fails when a
  channel's `version` points at one: rebuild against a released OpenEverest
  first. A stamp that is not a SemVer version is treated the same way.

### Kubernetes: `kubeVersion`

Declare the Kubernetes versions your chart supports with `kubeVersion` in
`Chart.yaml`. Helm enforces it at install time, and the hub copies it into
each release as `releases[].kubeVersion` (the index build warns when a channel
head has none). Use a lower bound only, with the `-0` suffix:

```yaml
kubeVersion: ">=1.32.0-0"
```

- **No upper bound.** A bound such as `<1.35` refuses every cluster released
  after your chart, even when nothing broke, and Helm offers no way to skip
  the check.
- **Keep `-0`.** Managed Kubernetes reports versions such as
  `v1.33.1-gke.100` or `v1.32.3-eks-bc803b4`, which SemVer treats as
  pre-releases. A range without a pre-release part, such as `>=1.32.0`, never
  matches them, so Helm would refuse to install on GKE or EKS.

## Plugin slug vs chart name

`metadata.name` (the hub slug) and `spec.install.helm.releaseName` are
independent. It's common for them to differ — for example, the
`generic-plugin-template` is registered as `generic-plugin-template` in the hub
(matches the source repo) but installs as `my-plugin` (the chart's default
release name). Pick the slug for discoverability; pick the release name to
match the chart's conventions.

## Updating an existing entry

Bumping a version is a normal PR that edits the `version` (and, in Phase 2+,
`digest`) of one or more channels. Maintainers merge it the same way as a new
submission.

### Automating version bumps

If your release CI can open PRs against this repo, you can automate the bump
on every tag. The general shape:

```yaml
# In your extension's release workflow, after publishing the chart:
- uses: actions/checkout@v4
  with:
    repository: openeverest/hub
    token: ${{ secrets.HUB_PR_TOKEN }}
    path: hub-checkout
- name: Bump formula version
  run: |
    yq -i '.spec.artifacts.chart.channels.stable.version = "${{ github.ref_name }}"' \
      hub-checkout/extensions/<type>/<your-slug>/formula.yaml
- uses: peter-evans/create-pull-request@v6
  with:
    path: hub-checkout
    branch: bump/<your-slug>-${{ github.ref_name }}
    title: "Bump <your-slug> to ${{ github.ref_name }}"
```

## Removing an entry

Don't delete a formula — move it to `extensions/_deprecated/` (preserves the
git history and the audit trail). A future healthcheck workflow (Phase 5) will
do this automatically when an entry is consistently broken.

## Questions?

Open an issue on this repo or ping the maintainers (see
[`CODEOWNERS`](../CODEOWNERS)).

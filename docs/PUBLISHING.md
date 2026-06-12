# Publishing an extension to the OpenEverest Hub

This guide walks through adding a new **provider** or **generic plugin** to the
[OpenEverest Extension Hub](https://github.com/openeverest/hub).

## Prerequisites

- Your extension is published to an OCI-compatible registry (GHCR, Docker Hub,
  Quay, etc.) as a Helm chart.
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

5. **Optionally add a `logo.svg`** and reference it from `metadata.icon`. Omit
   both if you don't have a logo yet.

6. **Open a Pull Request** against `main`. The
   [validate workflow](../.github/workflows/validate.yaml) will run:
   - JSON Schema validation of every `formula.yaml`.
   - Directory-name ↔ `metadata.name` consistency check.
   - Required-files check (`formula.yaml`, `README.md`).
   - Dry-run of the index generator to catch generation regressions.

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
| `metadata.type` | yes | `provider` or `plugin`. Determines which of `spec.provider` / `spec.plugin` must be present. |
| `metadata.displayName` | yes | Human-readable, max 64 chars. |
| `metadata.description` | yes | Max 500 chars. |
| `metadata.license` | yes | Valid [SPDX identifier](https://spdx.org/licenses/). |
| `metadata.maturity` | optional | Author-declared lifecycle stage: `alpha` \| `beta` \| `stable` \| `deprecated`. Defaults to `alpha` when omitted. Independent of channels (release cadence) and of operational health. |
| `metadata.maintainers` | yes | At least one entry; `github` handle is required. |
| `metadata.sourceRepo` | recommended | Public source repository URL. |
| `metadata.icon` | optional | Relative path to a logo file in this directory (typically `./logo.svg`). |
| `spec.provider` / `spec.plugin` | yes | Exactly one, matching `metadata.type`. |
| `spec.compatibility.openeverest` | yes | Semver range of compatible OpenEverest core versions, e.g., `">=2.0.0"`. |
| `spec.capabilities` | optional | Free-form map advertising provider/plugin features. Values are scalar (string/bool/number) or arrays of strings. Dot-namespaced keys (e.g., `mongodb.versions`) are a convention for grouping, not enforced. Emitted verbatim in the index when non-empty. |
| `spec.artifacts.chart` | required for providers; required for plugins unless they ship only a frontend artifact | OCI chart reference. |
| `spec.artifacts.frontend` | optional | **Only set this if your plugin publishes a SEPARATE OCI frontend bundle.** Plugins that serve `main.js` from their own backend (the common case — see [`generic-plugin-template`](../extensions/plugins/generic-plugin-template/)) do **not** need this block. |
| `spec.artifacts.*.channels.*.digest` | optional in Phase 1, required from Phase 2 | SHA-256 OCI manifest digest. |
| `spec.install.helm.releaseName` | yes | Helm release name. Independent from `metadata.name` (chart authors often have their own conventions). |
| `spec.install.helm.namespace` | yes | See [namespace convention](#namespace-convention) below. |
| `spec.verification` | optional | Reserved for cosign / SBOM / SLSA metadata (Phase 5). |

## Namespace convention

Both providers and plugins should install into **`everest-system`** — this is
the namespace the live OpenEverest v2 ecosystem uses (the
[`generic-plugin-template`](https://github.com/openeverest/generic-plugin-template)
and the core OpenEverest docs both use it).

> Spec 005 §4.3 mentions `openeverest-system` as the pinned namespace for
> providers. The live ecosystem standardised on `everest-system` instead.
> Both seed formulas in this repo use `everest-system`; the schema is
> intentionally unopinionated and accepts any valid DNS-1123 label.

## Channels

Each artifact must declare a `defaultChannel` and at least one channel under
`channels`. The conventional channels are:

- `stable` — production-ready releases.
- `edge` — pre-releases, release candidates, nightly builds.

`defaultChannel` is what the CLI/UI installs unless the user explicitly
overrides with `--channel`.

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

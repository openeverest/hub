# OpenEverest Extension Hub

The central, community-driven catalog of installable extensions for
[OpenEverest](https://github.com/openeverest/openeverest):

- **Providers** — database operators that OpenEverest manages (see
  [spec 001](https://github.com/openeverest/specs/blob/main/specs/001-plugins-architecture.md)).
- **Generic plugins** — UI / CLI / backend extensions of OpenEverest itself
  (see [spec 003](https://github.com/openeverest/specs/blob/main/specs/003-generic-plugins.md)).

This repository follows the **formula / pointer** model: each entry under
`extensions/` is a small YAML file pointing at an OCI artifact (Helm chart)
hosted in the author's own registry. A CI workflow regenerates the aggregated
`index/index.json` on every merge to `main`.

See [spec 005 — Extension Hub](https://github.com/openeverest/specs/blob/main/specs/005-extension-hub.md)
for the full design.

## Status

**Phase 1 — Developer Preview.** This repo currently provides the formula
catalog, the JSON Schema, PR validation, and a generated `index.json`. The
`everestctl extension` CLI, in-product UI, supply-chain signing, and the
browseable website ship in later phases.

## Consuming the index

The index is published directly from `main` and served by the GitHub raw CDN:

```
https://raw.githubusercontent.com/openeverest/hub/main/index/index.json
```

It is committed to the repo, so you can also `curl` any branch/commit directly.

## Repository layout

```
hub/
├── extensions/
│   ├── providers/
│   │   └── <name>/
│   │       ├── formula.yaml
│   │       ├── README.md
│   │       └── logo.svg          # optional
│   ├── plugins/
│   │   └── <name>/
│   │       ├── formula.yaml
│   │       ├── README.md
│   │       └── logo.svg          # optional
│   └── _template/                # copy this when submitting a new extension
│       └── formula.yaml
├── schemas/
│   └── formula-v1.json           # JSON Schema for formula.yaml
├── index/
│   └── index.json                # auto-generated; do not edit by hand
├── docs/
│   └── PUBLISHING.md             # how to add an extension
└── .github/
    ├── workflows/
    │   ├── validate.yaml         # PR: schema + lint + index dry-run
    │   └── build-index.yaml      # main: regenerate and commit index.json
    └── scripts/
        ├── validate-extensions.sh
        └── build-index.sh
```

## Adding an extension

See [docs/PUBLISHING.md](docs/PUBLISHING.md).

## License

The catalog content (formulas, schemas, scripts) is licensed
[Apache-2.0](LICENSE). Individual extensions retain their own licenses, declared
in `metadata.license` of each formula.

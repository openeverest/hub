# Capability vocabulary

`spec.capabilities` advertises what an extension supports. The Hub UI, the
website and `everestctl extension info` render it as-is: booleans become
chips (a `false` value is shown struck through) and arrays become labelled
rows.

To keep providers comparable, every provider declares the same small set of
**core capabilities**, and adds **common** or **ad-hoc** keys only where
they add information.

## Core capabilities (providers)

Every provider formula declares all five keys as booleans. `false` is
meaningful: it tells users the feature is missing. Omit a key only when the
concept does not apply to the workload at all (for example, `backups` and
`pitr` for a stateless model-serving provider).

| Key          | `true` means |
|--------------|--------------|
| `ha`         | At least one topology runs multiple replicas with automatic failover and no single point of failure. |
| `monitoring` | The provider exposes engine metrics to a monitoring backend (PMM, Prometheus, VictoriaMetrics, …), either through the OpenEverest monitoring contract or by rendering a `PodMonitor`/`VMPodScrape` itself. |
| `backups`    | Backups **and** restores are implemented (a `BackupClass` with working `SyncBackup`/`SyncRestore`). Scheduled backups are expected as part of this. |
| `pitr`       | Point-in-time restore is implemented: the `BackupClass` sets `supportsPITR: true` and restores honour a `PointInTime` data source. Implies `backups: true`. |
| `encryption` | Traffic to the engine can be encrypted with TLS, either on by default or configurable through OpenEverest. |

Declare a capability `true` only when it is implemented in the provider
code that the published chart ships, not when it is planned or only
described in a proposal.

A provider that declares all five core capabilities `true` qualifies for
`metadata.maturity: beta`.

## Common optional keys

Use these names when they apply so the same feature reads the same way
across providers.

| Key                 | Type     | Meaning |
|---------------------|----------|---------|
| `topologies`        | string[] | Topology names exactly as defined in the provider's `definition/topologies/`. |
| `versions`          | string[] | Engine release lines offered (e.g. `["8.0", "8.4"]`, `["16", "17"]`), not individual patch builds. |
| `encryption.atRest` | bool     | Data-at-rest encryption (TDE, keyring, KMS) is configurable through OpenEverest. Declare only when `true`. |
| `sharding`          | bool     | Data can be partitioned across shards. Declare only when `true`. |
| `proxy`             | string[] | Proxies or connection poolers the provider can deploy (e.g. `["haproxy", "proxysql"]`, `["pgbouncer"]`). |

## Ad-hoc keys

Anything else that sets an extension apart (for example `gpu`,
`autoscaling`, `modelSources`, `htap`) can be added freely:

- Use `camelCase`; dot-namespaced keys (`encryption.atRest`) group a detail
  under a broader capability.
- Declare ad-hoc booleans only when `true`. Listing features an extension
  does not have adds noise; the core keys already cover the important gaps.
- Do not advertise baseline platform features every provider gets from
  OpenEverest (scaling, storage expansion, scheduling policies, exposure).

## Example

```yaml
capabilities:
  ha: true
  monitoring: true
  backups: true
  pitr: true
  encryption: true
  topologies: ["replicaSet", "sharded"]
  versions: ["6.0", "7.0", "8.0"]
  sharding: true
```

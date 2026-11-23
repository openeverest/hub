# Neo4j

The [Neo4j](https://neo4j.com/) graph database on Kubernetes, wrapped as an
OpenEverest **provider** and backed by the
[Neo4j Kubernetes Operator](https://github.com/neo4j-partners/neo4j-kubernetes-operator).

> [!WARNING]
> **Alpha.** CRD schemas, chart values and defaults change, and there is no
> supported upgrade path between versions yet.

## Source

- **Provider repo:** https://github.com/openeverest/provider-neo4j
- **Chart:** `oci://ghcr.io/openeverest/charts/provider-neo4j`
- **Page:** https://openeverest.io/for/neo4j/

## Supported

- `standalone` topology (Community, the default, or Enterprise)
- `cluster` topology (Enterprise): primaries, plus optional analytics and read pools
- Horizontal and vertical scaling, storage expansion
- Rolling version upgrades (Neo4j `5.26` and `2026.x` releases)
- TLS by default, with a cert-manager CA or your own Secret or Issuer
- External access through a `ClusterIP`, `NodePort` or `LoadBalancer` Service
- On-demand and scheduled online backups to S3-compatible storage (Enterprise)
- Restore in place, or into a new Instance
- Prometheus metrics (Enterprise)

## Not yet supported

- **PITR**

## Licensing

Community is the default. Clusters, backups and metrics need Neo4j Enterprise:
set `spec.parameters.edition: enterprise` and accept the license with
`spec.parameters.licenseAcceptance: "yes"` (production) or `"eval"`
(evaluation). OpenEverest never supplies or bypasses a Neo4j license.

## Install (manual)

The chart bundles the Neo4j operator and its CRDs. The default TLS setup needs
[cert-manager](https://cert-manager.io) in the cluster.

In `0.1.0` the bundled operator watches only the `default` namespace: an
Instance anywhere else gets no pods and no error. List the namespaces where
your Instances run:

```bash
helm install provider-neo4j \
  oci://ghcr.io/openeverest/charts/provider-neo4j \
  --version 0.1.0 \
  --namespace everest-system \
  --set 'operator.watchNamespaces={default,team-a}'
```

The `neo4j-cluster` preset ships disabled, because only you can accept the
Enterprise license; see the
[provider README](https://github.com/openeverest/provider-neo4j#presets) to
enable it.

This provider is **not standalone**: it requires an OpenEverest installation
(core CRDs and controller) in the cluster.

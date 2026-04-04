# Flux Overview

## Purpose

Flux manages the Kubernetes cluster configuration using GitOps. All cluster add-ons are declared in this repository and Flux continuously reconciles the cluster state to match what is committed in Git.

## How It Works

Flux watches the GitHub repository for changes. When a commit is pushed, the Flux controllers pull the changes and apply them to the cluster. No manual `kubectl apply` is required after bootstrap.

The Flux installation itself lives in `clusters/homelab/flux-system/`. That directory is created and managed by `flux bootstrap` and must not be manually edited.

## Repository Layout

```
clusters/
└── homelab/
    ├── kustomization.yaml          root: loads flux-system and infrastructure
    ├── flux-system/                managed by flux bootstrap, do not edit
    │   ├── gotk-components.yaml
    │   ├── gotk-sync.yaml
    │   └── kustomization.yaml
    └── infrastructure/
        ├── kustomization.yaml      lists all Flux Kustomization CRDs
        ├── sources.yaml            Kustomization for HelmRepository/GitRepository sources
        ├── gateway-api-crds.yaml
        ├── cilium.yaml
        ├── cilium-bgp.yaml
        ├── cert-manager.yaml
        ├── external-secrets.yaml
        ├── 1password-connect.yaml
        ├── cluster-secret-store.yaml
        ├── kubelet-serving-cert-approver.yaml
        ├── metrics-server.yaml
        ├── external-dns.yaml
        ├── sources/                HelmRepository and GitRepository source definitions
        ├── gateway-api-crds/       Gateway API CRDs (upstream, pinned to v1.4.1)
        ├── cilium/                 Cilium CNI + kube-proxy replacement + BGP + Gateway API
        ├── cilium-bgp/             CiliumBGPClusterConfig, CiliumBGPPeerConfig, LB-IPAM pool
        ├── cert-manager/
        ├── external-secrets/
        ├── 1password-connect/
        ├── cluster-secret-store/
        ├── kubelet-serving-cert-approver/
        ├── metrics-server/
        └── external-dns/
```

Each subdirectory under `infrastructure/` contains a `kustomization.yaml` and the manifests for that component. The files in `infrastructure/` (e.g. `cilium.yaml`) are Flux `Kustomization` CRDs that tell Flux to reconcile each component directory.

## Installed Components

| Component | Version | Namespace | Source Type |
| --- | --- | --- | --- |
| gateway-api-crds | v1.4.1 | cluster-wide | upstream URLs (prune: false) |
| cilium | 1.17.3 | kube-system | HelmRepository |
| cilium-bgp | — | cluster-wide | Cilium BGP CRDs |
| cert-manager | 1.20.1 | cert-manager | HelmRepository (jetstack) |
| external-secrets | 2.2.0 | external-secrets | HelmRepository |
| 1password-connect | 2.4.1 | connect | HelmRepository |
| cluster-secret-store | — | cluster-wide | ClusterSecretStore CRD |
| kubelet-serving-cert-approver | v0.10.3 | kubelet-serving-cert-approver | GitRepository |
| metrics-server | 3.13.0 | metrics-server | HelmRepository |
| external-dns | 1.20.0 | external-dns | HelmRepository |

## Dependency Graph

Flux `Kustomization` objects use `dependsOn` to enforce ordering. The chain is:

```
sources
│
gateway-api-crds (no dependsOn, applies CRDs immediately)
│
├── cilium (dependsOn: sources, gateway-api-crds)
│   └── cilium-bgp (dependsOn: cilium, gateway-api-crds)
│
├── cert-manager (dependsOn: sources, external-secrets, cluster-secret-store)
│
├── external-secrets (dependsOn: sources)
│   └── cluster-secret-store (dependsOn: external-secrets, 1password-connect)
│         └── external-dns (dependsOn: sources, external-secrets, cluster-secret-store)
│
├── 1password-connect (dependsOn: sources)
│   └── cluster-secret-store (see above)
│
├── kubelet-serving-cert-approver (dependsOn: sources)
└── metrics-server (dependsOn: sources)
```

`gateway-api-crds` must be ready before Cilium starts because Cilium's Gateway API controller requires those CRDs to be present at startup.

`cilium-bgp` depends on `cilium` (Cilium BGP CRDs are installed by the Cilium HelmRelease) and on `gateway-api-crds` (BGP advertises Gateway LoadBalancer IPs).

`cert-manager` depends on `external-secrets` and `cluster-secret-store` because it contains an `ExternalSecret` and a `ClusterIssuer` that require ESO CRDs and the 1Password-backed ClusterSecretStore to be available.

## Secrets That Flux Does Not Manage

Two secrets must exist in the cluster before Flux can fully reconcile. They are created by OpenTofu during bootstrap and are not managed by Flux:

| Secret | Namespace | Purpose |
| --- | --- | --- |
| `op-credentials` | `connect` | 1Password Connect server credentials JSON |
| `op-token` | `external-secrets` | 1Password Connect API token |

See [Flux Setup](flux-setup.md) for how these are provisioned.

## Multi-Cluster

The structure supports multiple clusters by adding a new directory under `clusters/`. Each cluster gets its own `flux-system/` and `infrastructure/` directories. The `homelab` cluster is the only one currently active.

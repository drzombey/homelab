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
        ├── metallb.yaml
        ├── metallb-config.yaml
        ├── cert-manager.yaml
        ├── external-secrets.yaml
        ├── 1password-connect.yaml
        ├── cluster-secret-store.yaml
        ├── kubelet-serving-cert-approver.yaml
        ├── metrics-server.yaml
        ├── sources/                HelmRepository and GitRepository source definitions
        ├── metallb/
        ├── metallb-config/
        ├── cert-manager/
        ├── external-secrets/
        ├── 1password-connect/
        ├── cluster-secret-store/
        ├── kubelet-serving-cert-approver/
        └── metrics-server/
```

Each subdirectory under `infrastructure/` contains a `kustomization.yaml` and the manifests for that component. The files in `infrastructure/` (e.g. `metallb.yaml`) are Flux `Kustomization` CRDs that tell Flux to reconcile each component directory.

## Installed Components

| Component | Version | Namespace | Source Type |
| --- | --- | --- | --- |
| metallb | 0.15.3 | metallb | HelmRepository |
| cert-manager | 1.20.1 | cert-manager | HelmRepository (jetstack) |
| external-secrets | 2.2.0 | external-secrets | HelmRepository |
| 1password-connect | 2.4.1 | connect | HelmRepository |
| cluster-secret-store | — | cluster-wide | ClusterSecretStore CRD |
| kubelet-serving-cert-approver | v0.10.3 | kubelet-serving-cert-approver | GitRepository |
| metrics-server | 3.13.0 | metrics-server | HelmRepository |

## Dependency Graph

Flux `Kustomization` objects use `dependsOn` to enforce ordering. The chain is:

```
sources
├── metallb
│   └── metallb-config
├── cert-manager
├── external-secrets
│   └── cluster-secret-store
├── 1password-connect (also depends on external-secrets)
│   └── cluster-secret-store
├── kubelet-serving-cert-approver
└── metrics-server
```

`sources` must be ready before anything else because all HelmReleases reference sources defined there.

`external-secrets` and `1password-connect` must both be ready before `cluster-secret-store`, because the store depends on the ESO CRDs and on the 1Password Connect deployment being available.

`metallb-config` depends on `metallb` because the BGP and pool CRDs do not exist until MetalLB installs them.

## Secrets That Flux Does Not Manage

Two secrets must exist in the cluster before Flux can fully reconcile. They are created by OpenTofu during bootstrap and are not managed by Flux:

| Secret | Namespace | Purpose |
| --- | --- | --- |
| `op-credentials` | `connect` | 1Password Connect server credentials JSON |
| `op-token` | `external-secrets` | 1Password Connect API token |

See [Flux Setup](flux-setup.md) for how these are provisioned.

## Multi-Cluster

The structure supports multiple clusters by adding a new directory under `clusters/`. Each cluster gets its own `flux-system/` and `infrastructure/` directories. The `homelab` cluster is the only one currently active.

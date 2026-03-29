# Homelab

This repository contains the infrastructure and cluster configuration for my homelab.

## Repository Structure

| Path | Purpose |
| --- | --- |
| `infrastructure/` | OpenTofu code to provision Talos-based Kubernetes nodes on Proxmox |
| `cluster-infrastructure/` | Post-bootstrap cluster configuration such as MetalLB BGP resources |
| `clusters/` | Flux GitOps configuration for the Kubernetes cluster |

## Documentation

All repository documentation lives under `docs/`.

### Infrastructure

- [Infrastructure Overview](docs/infrastructure-overview.md) architecture, providers, and repo layout
- [Infrastructure Setup](docs/infrastructure-setup.md) initial bootstrap workflow and local config installation
- [Infrastructure Configuration](docs/infrastructure-configuration.md) node schema, defaults, and Talos patching model
- [Networking](docs/networking.md) Proxmox, OPNsense, switch, VLAN, and network ranges
- [Infrastructure Upgrades](docs/infrastructure-upgrades.md) rolling replacement upgrade model and storage guidance
- [Troubleshooting](docs/troubleshooting.md) common OpenTofu, Talos, Proxmox, and networking issues

### Cluster Add-ons

- [Cluster Infrastructure](docs/cluster-infrastructure.md) overview of post-bootstrap cluster configuration
- [MetalLB BGP](docs/metallb-bgp.md) MetalLB FRR mode with OPNsense BGP peering

### Flux GitOps

- [Flux Overview](docs/flux-overview.md) architecture, component list, repo layout, and dependency graph
- [Flux Setup](docs/flux-setup.md) prerequisites, variables, and bootstrap workflow
- [Flux Operations](docs/flux-operations.md) day-2 operations: adding components, reconciling, upgrading
- [Flux Troubleshooting](docs/flux-troubleshooting.md) common issues and fixes

## Network Summary

| Network | Purpose | Notes |
| --- | --- | --- |
| `10.0.30.0/24` | Main LAN | Regular clients, Wi-Fi, and Proxmox management |
| `10.0.40.0/24` | VM and Kubernetes node network | Routed by OPNsense on `VLAN 40` |
| `10.0.50.100-10.0.50.150` | MetalLB service IP pool | Routed over BGP, not bound to a bridge or interface |

## Typical Workflow

1. Provision Talos nodes with the code in `infrastructure/`
2. Export `kubeconfig` and `talosconfig`
3. Flux bootstraps automatically via OpenTofu and begins reconciling `clusters/homelab/`
4. Verify networking, BGP, and workload reachability

## Quick Start

```bash
tofu init
tofu validate
tofu plan
tofu apply
```

For the detailed setup flow, see [Infrastructure Setup](docs/infrastructure-setup.md).

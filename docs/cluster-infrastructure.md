# Cluster Infrastructure

This directory holds cluster-level configuration that is applied after the Talos cluster is up.

## MetalLB With OPNsense BGP

See [MetalLB BGP](metallb-bgp.md) for the current homelab setup:

- Kubernetes nodes live in `10.0.40.0/24`
- OPNsense peers with MetalLB on `10.0.40.1`
- MetalLB advertises service IPs from `10.0.50.100-10.0.50.150`
- FRR mode is enabled in the MetalLB speaker

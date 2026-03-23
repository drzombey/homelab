# Infrastructure Overview

## Purpose

This repo provisions Talos-based Kubernetes nodes on Proxmox and bootstraps the Talos cluster with OpenTofu.

## What It Does

- creates Proxmox VMs for Talos nodes
- downloads Talos ISO images into Proxmox datastores
- applies Talos machine configuration to controlplane and worker nodes
- bootstraps the Talos cluster
- exposes `kubeconfig` and `talosconfig` as outputs

## Providers

- Proxmox: `bpg/proxmox` `0.98.1`
- Talos: `siderolabs/talos` `0.10.0`

## Repository Layout

- `main.tf` root node inventory, module call, and outputs
- `variables.tf` root credentials variables
- `infrastructure/modules/kubernetes/main.tf` provider configuration
- `infrastructure/modules/kubernetes/variables.tf` module input schema and validations
- `infrastructure/modules/kubernetes/node.tf` VM creation, ISO download, rollout logic
- `infrastructure/modules/kubernetes/talos_schema.tf` Talos image factory setup
- `infrastructure/modules/kubernetes/talos_bootstrap.tf` config apply, bootstrap, kubeconfig, health
- `infrastructure/modules/kubernetes/templates/` Talos patch templates

## Important Runtime Behavior

- Proxmox `initialization` is ignored after VM creation to avoid `ide2` media type update failures
- guest agent is disabled because Talos guest-agent data caused slow plans and warnings
- Talos network config is applied through Talos config patches, not through later Proxmox updates
- Talos interface selection uses NIC MAC addresses to avoid unstable device names like `ens18`

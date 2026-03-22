# Homelab Infrastructure

OpenTofu repository to provision Talos-based Kubernetes nodes on Proxmox and bootstrap a Talos Kubernetes cluster.

## Docs

- `docs/overview.md` architecture, repo layout, and important behavior
- `docs/setup.md` initial setup and bootstrap workflow
- `docs/configuration.md` node schema, defaults, validation, and Talos patching model
- `docs/upgrades.md` rolling replacement upgrades and storage guidance
- `docs/troubleshooting.md` known issues and recovery steps
- `terraform.tfvars.example` example root variable file

## Quick Start

1. Copy `terraform.tfvars.example` to your own `terraform.tfvars`
2. Adjust `main.tf` node inventory for your environment
3. Run:

```bash
tofu init
tofu validate
tofu plan
tofu apply
```

## Outputs

```bash
tofu output -raw kubeconfig > kubeconfig
tofu output -raw talosconfig > talosconfig
```

For the standard install paths and shell setup, see `docs/setup.md`.

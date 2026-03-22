# Setup

## Requirements

- OpenTofu installed as `tofu`
- access to a Proxmox API endpoint
- Proxmox API token with permission to create and modify VMs and datastore files
- SSH agent access for the configured Proxmox SSH user if needed by the provider
- network reachability from this machine to the Talos node IPs

## Root Variables

Root variables are defined in `variables.tf`:

- `proxmox_host_endpoint`
- `proxmox_api_token`

Use `terraform.tfvars.example` as a starting point.

## Initial Cluster Setup

Recommended first-time workflow:

1. copy `terraform.tfvars.example` to `terraform.tfvars`
2. adjust `main.tf` and define your nodes in `local.nodes`
3. run `tofu init`
4. run `tofu validate`
5. run `tofu plan`
6. run `tofu apply`

Commands:

```bash
tofu init
tofu validate
tofu plan
tofu apply
```

## Bootstrap Flow

The repo uses this sequence:

1. download Talos ISO into Proxmox
2. create or replace VMs
3. apply Talos machine configuration to all nodes
4. bootstrap the first controlplane node
5. fetch kubeconfig
6. run Talos cluster health checks

## Outputs

After bootstrap, export configs with:

```bash
tofu output -raw kubeconfig > kubeconfig
tofu output -raw talosconfig > talosconfig
```

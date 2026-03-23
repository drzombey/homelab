# Infrastructure Configuration

## Node Model

Each entry in `main.tf` `local.nodes` follows this shape:

```hcl
node01 = {
  type               = "controlplane"
  node_name          = "proxmox"
  cpu                = 2
  memory             = 4096
  disk_size          = 20
  rollout_generation = 0

  network = {
    network_interface = "vmbrLAN"
    vlan_id           = 40
    dns_server        = ["10.0.40.1"]
    ipv4 = {
      address = "10.0.40.10/24"
      gateway = "10.0.40.1"
    }
  }

  talos_config = {
    endpoint       = "10.0.40.10"
    version        = "v1.12.0"
    config_patches = []
  }

  additional_config = {
    cpu_type        = "x86-64-v2-AES"
    disk_datastore  = "local-lvm"
    image_datastore = "local"
  }
}
```

## Validation Rules

- `type` must be `controlplane` or `worker`
- `network.ipv4.address` must be `dhcp` or IPv4 CIDR notation like `10.0.40.10/24`
- if `network.ipv4.address` is static, `network.ipv4.gateway` is required

## Defaults

Important defaults from `infrastructure/modules/kubernetes/node.tf`:

- `cpu = 2`
- `memory = 2048`
- `disk_size = 20`
- `rollout_generation = 0`
- `network.network_interface = "vmbr0"`
- `network.vlan_id = 0`
- `network.dns_server = []`
- `network.ipv4.address = "dhcp"`
- `talos_config.version = var.talos_version`
- `additional_config.cpu_type = "x86-64-v2-AES"`
- `additional_config.disk_datastore = "local-lvm"`
- `additional_config.image_datastore = "local"`

## Talos Patching Model

Talos configuration is assembled from:

1. base patch template
2. install patch template
3. network patch template
4. optional per-node `talos_config.config_patches`

Template files:

- `infrastructure/modules/kubernetes/templates/talos-base-patch.yaml.tftpl`
- `infrastructure/modules/kubernetes/templates/talos-install-patch.yaml.tftpl`
- `infrastructure/modules/kubernetes/templates/talos-network-patch.yaml.tftpl`

## Shared Talos Base Settings

The module exposes `talos_base_config` for cluster-wide defaults.

Supported fields:

- `extra_kernel_args`
- `nameservers`
- `ntp_servers`
- `sysctls`
- `node_labels`
- `node_taints`
- `registries.mirrors`
- `registries.config`

Example:

```hcl
module "kubernetes" {
  source                = "./modules/kubernetes"
  kube_nodes            = local.nodes
  proxmox_api_token     = var.proxmox_api_token
  proxmox_host_endpoint = var.proxmox_host_endpoint
  proxmox_insecure      = true

  talos_base_config = {
    extra_kernel_args = ["console=ttyS0"]
    nameservers       = ["10.0.40.1"]
    ntp_servers       = ["pool.ntp.org"]
    sysctls = {
      "vm.nr_hugepages" = "1024"
    }
    node_labels = {
      "topology.kubernetes.io/zone" = "homelab"
    }
    node_taints = []
    registries = {
      mirrors = {}
      config  = {}
    }
  }
}
```

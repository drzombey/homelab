locals {
  controlplane_nodes = {
    for name, node in local.kube_nodes :
    name => node if node.type == "controlplane"
  }

  worker_nodes = {
    for name, node in local.kube_nodes :
    name => node if node.type == "worker"
  }

  talos_node_endpoints = {
    for name, node in local.kube_nodes :
    name => coalesce(node.talos_config.endpoint, trimsuffix(split("/", node.network.ipv4.address)[0], "/"))
  }

  talos_cluster_endpoint = coalesce(
    var.talos_cluster_endpoint,
    format("https://%s:6443", local.talos_node_endpoints[sort(keys(local.controlplane_nodes))[0]])
  )

  talos_bootstrap_node = coalesce(var.talos_bootstrap_node, sort(keys(local.controlplane_nodes))[0])

  talos_machine_network_patches = {
    for name, node in local.kube_nodes :
    name => join("\n", concat(
      [
        "machine:",
        "  network:",
      ],
      length(node.network.dns_server) > 0 ? concat(
        ["    nameservers:"],
        [for server in node.network.dns_server : format("      - %s", server)]
      ) : [],
      [
        "    interfaces:",
        "      - deviceSelector:",
        format("          hardwareAddr: %s", lower(proxmox_virtual_environment_vm.main[name].network_device[0].mac_address)),
        format("        dhcp: %s", node.network.ipv4.address == "dhcp" ? "true" : "false"),
      ],
      node.network.ipv4.address == "dhcp" ? [] : [
        "        addresses:",
        format("          - %s", node.network.ipv4.address),
        "        routes:",
        "          - network: 0.0.0.0/0",
        format("            gateway: %s", node.network.ipv4.gateway),
      ]
    ))
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.talos_cluster_name
  cluster_endpoint   = local.talos_cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.talos_cluster_name
  cluster_endpoint   = local.talos_cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = local.controlplane_nodes

  client_configuration      = talos_machine_secrets.this.client_configuration
  endpoint                  = local.talos_node_endpoints[each.key]
  node                      = local.talos_node_endpoints[each.key]
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  config_patches = concat(
    [
      yamlencode({
        machine = {
          install = {
            disk = var.talos_install_disk
          }
        }
      }),
      local.talos_machine_network_patches[each.key]
    ],
    each.value.talos_config.config_patches
  )

  depends_on = [
    proxmox_virtual_environment_vm.main
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  endpoint                    = local.talos_node_endpoints[each.key]
  node                        = local.talos_node_endpoints[each.key]
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  config_patches = concat(
    [
      yamlencode({
        machine = {
          install = {
            disk = var.talos_install_disk
          }
        }
      }),
      local.talos_machine_network_patches[each.key]
    ],
    each.value.talos_config.config_patches
  )

  depends_on = [
    proxmox_virtual_environment_vm.main
  ]
}

resource "talos_machine_bootstrap" "this" {
  node                 = local.talos_node_endpoints[local.talos_bootstrap_node]
  endpoint             = local.talos_node_endpoints[local.talos_bootstrap_node]
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  node                 = local.talos_node_endpoints[local.talos_bootstrap_node]
  endpoint             = local.talos_node_endpoints[local.talos_bootstrap_node]
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for name in sort(keys(local.controlplane_nodes)) : local.talos_node_endpoints[name]]
  control_plane_nodes  = [for name in sort(keys(local.controlplane_nodes)) : local.talos_node_endpoints[name]]
  worker_nodes         = [for name in sort(keys(local.worker_nodes)) : local.talos_node_endpoints[name]]

  depends_on = [
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.worker
  ]
}

output "talos_kubeconfig" {
  description = "Rendered kubeconfig for the Talos Kubernetes cluster"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

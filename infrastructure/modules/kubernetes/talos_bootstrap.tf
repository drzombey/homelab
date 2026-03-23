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
    name => templatefile("${path.module}/templates/talos-network-patch.yaml.tftpl", {
      dns_servers   = length(node.network.dns_server) > 0 ? node.network.dns_server : var.talos_base_config.nameservers
      hardware_addr = lower(proxmox_virtual_environment_vm.main[name].network_device[0].mac_address)
      dhcp          = node.network.ipv4.address == "dhcp"
      address       = node.network.ipv4.address
      gateway       = node.network.ipv4.gateway
    })
  }

  talos_hostname_patches = {
    for name, node in local.kube_nodes :
    name => yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = name
      auto       = "off"
    })
  }

  talos_base_patch = templatefile("${path.module}/templates/talos-base-patch.yaml.tftpl", {
    extra_kernel_args = coalesce(try(var.talos_base_config.extra_kernel_args, null), [])
    nameservers       = []
    ntp_servers       = coalesce(try(var.talos_base_config.ntp_servers, null), [])
    sysctls           = coalesce(try(var.talos_base_config.sysctls, null), {})
    node_labels       = coalesce(try(var.talos_base_config.node_labels, null), {})
    node_taints       = coalesce(try(var.talos_base_config.node_taints, null), [])
    kube_proxy_mode   = try(var.talos_base_config.kube_proxy.mode, null)
    kube_proxy_ipvs_strict_arp = try(var.talos_base_config.kube_proxy.ipvs_strict_arp, null)
    registry_mirrors  = coalesce(try(var.talos_base_config.registries.mirrors, null), {})
    registry_configs  = coalesce(try(var.talos_base_config.registries.config, null), {})
  })

  talos_installer_images = {
    for name, node in local.kube_nodes :
    name => format("factory.talos.dev/installer/%s:%s", talos_image_factory_schematic.this.id, node.talos_config.version)
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
      local.talos_base_patch,
      templatefile("${path.module}/templates/talos-install-patch.yaml.tftpl", {
        install_disk  = var.talos_install_disk
        install_image = local.talos_installer_images[each.key]
      }),
      local.talos_hostname_patches[each.key],
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
      local.talos_base_patch,
      templatefile("${path.module}/templates/talos-install-patch.yaml.tftpl", {
        install_disk  = var.talos_install_disk
        install_image = local.talos_installer_images[each.key]
      }),
      local.talos_hostname_patches[each.key],
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

output "talosconfig" {
  description = "Rendered talosconfig for the Talos cluster"
  value = yamlencode({
    context = var.talos_cluster_name
    contexts = {
      (var.talos_cluster_name) = {
        endpoints = [for name in sort(keys(local.controlplane_nodes)) : local.talos_node_endpoints[name]]
        nodes     = [for name in sort(keys(local.kube_nodes)) : local.talos_node_endpoints[name]]
      }
    }
    clusters = {
      (var.talos_cluster_name) = {
        ca = talos_machine_secrets.this.client_configuration.ca_certificate
      }
    }
    auth = {
      (var.talos_cluster_name) = {
        client-certificate = talos_machine_secrets.this.client_configuration.client_certificate
        client-key         = talos_machine_secrets.this.client_configuration.client_key
      }
    }
  })
  sensitive = true
}

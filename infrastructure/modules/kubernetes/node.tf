
locals {
  kube_node_defaults = {
    cpu       = 2
    memory    = 2048
    disk_size = 20
    rollout_generation = 0
    network = {
      network_interface = "vmbr0"
      vlan_id           = 0
      dns_server        = []
      ipv4 = {
        address = "dhcp"
        gateway = null
      }
    }
    talos_config = {
      official_system_extensions = [
        "i915-ucode",
        "intel-ucode",
        "iscsi-tools",
        "mei",
        "qemu-guest-agent",
      ]
      endpoint       = null
      version        = var.talos_version
      config_patches = []
    }
    additional_config = {
      cpu_type        = "x86-64-v2-AES"
      disk_datastore  = "local-lvm"
      image_datastore = "local"
    }
  }

  kube_nodes = {
    for name, node in var.kube_nodes :
    name => {
      type      = node.type
      node_name = node.node_name
      cpu       = coalesce(try(node.cpu, null), local.kube_node_defaults.cpu)
      memory    = coalesce(try(node.memory, null), local.kube_node_defaults.memory)
      disk_size = coalesce(try(node.disk_size, null), local.kube_node_defaults.disk_size)
      rollout_generation = coalesce(try(node.rollout_generation, null), local.kube_node_defaults.rollout_generation)
      network = {
        network_interface = coalesce(
          try(node.network.network_interface, null),
          local.kube_node_defaults.network.network_interface
        )
        vlan_id = coalesce(
          try(node.network.vlan_id, null),
          local.kube_node_defaults.network.vlan_id
        )
        dns_server = coalesce(
          try(node.network.dns_server, null),
          local.kube_node_defaults.network.dns_server
        )
        ipv4 = {
          address = coalesce(
            try(node.network.ipv4.address, null),
            local.kube_node_defaults.network.ipv4.address
          )
          gateway = try(node.network.ipv4.gateway, local.kube_node_defaults.network.ipv4.gateway)
        }
      }
      talos_config = {
        official_system_extensions = coalesce(
          try(node.talos_config.official_system_extensions, null),
          local.kube_node_defaults.talos_config.official_system_extensions
        )
        endpoint = try(node.talos_config.endpoint, local.kube_node_defaults.talos_config.endpoint)
        version = coalesce(
          try(node.talos_config.version, null),
          local.kube_node_defaults.talos_config.version
        )
        config_patches = coalesce(
          try(node.talos_config.config_patches, null),
          local.kube_node_defaults.talos_config.config_patches
        )
      }
      additional_config = {
        cpu_type = coalesce(
          try(node.additional_config.cpu_type, null),
          local.kube_node_defaults.additional_config.cpu_type
        )
        disk_datastore = coalesce(
          try(node.additional_config.disk_datastore, null),
          local.kube_node_defaults.additional_config.disk_datastore
        )
        image_datastore = coalesce(
          try(node.additional_config.image_datastore, null),
          local.kube_node_defaults.additional_config.image_datastore
        )
      }
    }
  }

  talos_image_targets = {
    for name, node in local.kube_nodes :
    name => format(
      "%s::%s::%s",
      node.node_name,
      node.additional_config.image_datastore,
      node.rollout_generation > 0 ? node.talos_config.version : "legacy"
    )
  }

  talos_image_download_keys = distinct(values(local.talos_image_targets))

  talos_image_downloads = {
    for target_key in local.talos_image_download_keys :
    sort([for name, key in local.talos_image_targets : name if key == target_key])[0] => {
      node_name       = split("::", target_key)[0]
      image_datastore = split("::", target_key)[1]
      image_key       = split("::", target_key)[2]
      talos_version   = split("::", target_key)[2] == "legacy" ? var.talos_version : split("::", target_key)[2]
      target_key      = target_key
    }
  }

  talos_image_download_lookup = merge([
    for download_key, download in local.talos_image_downloads : {
      for node_name, target_key in local.talos_image_targets :
      node_name => download_key if target_key == download.target_key
    }
  ]...)
}

resource "proxmox_virtual_environment_vm" "main" {
  for_each = local.kube_nodes
  name = format("%s-%s", each.key, each.value.type)
  node_name = each.value.node_name
  description = "Managed by Terraform running Talos Linux for kubernetes"
  tags        = ["terraform", "talos"]

  lifecycle {
    ignore_changes = [
      initialization,
    ]
    replace_triggered_by = [
      terraform_data.node_rollout[each.key],
    ]
  }
  
  cpu {
    cores = each.value.cpu
    sockets = 1
    type  = each.value.additional_config.cpu_type
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    interface = "virtio0"
    datastore_id = each.value.additional_config.disk_datastore
    file_id = proxmox_virtual_environment_download_file.talos_image[local.talos_image_download_lookup[each.key]].id
    size = each.value.disk_size
    discard = "on"
  }

  bios = "ovmf"
  machine = "q35"

  efi_disk {
    type = "4m"
  }

  agent {
    enabled = true

    wait_for_ip {
      ipv4 = false
      ipv6 = false
    }
  }

  initialization {
    datastore_id = each.value.additional_config.disk_datastore
    interface    = "ide2"
    dynamic "dns" {
      for_each = length(each.value.network.dns_server) > 0 ? [each.value.network.dns_server] : []

      content {
        servers = dns.value
      }
    }
    ip_config {
      ipv4 {
        address = each.value.network.ipv4.address
        gateway = each.value.network.ipv4.address == "dhcp" ? null : each.value.network.ipv4.gateway
      }
    }
  }

  network_device {
    bridge = each.value.network.network_interface
    model = "virtio"
    vlan_id = each.value.network.vlan_id
  }

  operating_system {
    type = "l26"
  }
}

resource "terraform_data" "node_rollout" {
  for_each = local.kube_nodes

  input = {
    talos_version       = each.value.talos_config.version
    rollout_generation  = each.value.rollout_generation
  }
}

resource "proxmox_virtual_environment_download_file" "talos_image" {
  for_each           = local.talos_image_downloads
  content_type       = "iso"
  datastore_id       = each.value.image_datastore
  file_name          = each.value.image_key == "legacy" ? "talos-nocloud-amd64.iso" : format("talos-%s-nocloud-amd64.iso", replace(each.value.talos_version, "v", ""))
  node_name          = each.value.node_name
  overwrite          = false
  overwrite_unmanaged = false
  url                = format("https://factory.talos.dev/image/%s/%s/nocloud-amd64.iso", talos_image_factory_schematic.this.id, each.value.talos_version)
}

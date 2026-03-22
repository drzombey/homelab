locals {
  nodes = {
    "node01" = {
      type      = "controlplane"
      node_name = "proxmox"
      memory = 4096
      network = {
        network_interface = "vmbrLAN"
        vlan_id           = 40
        dns_server = [
          "10.0.40.1"
        ]
        ipv4 = {
          address = "10.0.40.10/24"
          gateway = "10.0.40.1"
        }
      }
    }
    "node02" = {
      type      = "controlplane"
      node_name = "proxmox"
      memory = 4096
      network = {
        network_interface = "vmbrLAN"
        vlan_id           = 40
        dns_server = [
          "10.0.40.1"
        ]
        ipv4 = {
          address = "10.0.40.11/24"
          gateway = "10.0.40.1"
        }
      }
    }
    "node03" = {
      type      = "controlplane"
      node_name = "proxmox"
      memory = 4096
      network = {
        network_interface = "vmbrLAN"
        vlan_id           = 40
        dns_server = [
          "10.0.40.1"
        ]
        ipv4 = {
          address = "10.0.40.12/24"
          gateway = "10.0.40.1"
        }
      }
    }
    "node04" = {
      type      = "worker"
      node_name = "proxmox"
      memory = 4096
      network = {
        network_interface = "vmbrLAN"
        vlan_id           = 40
        dns_server = [
          "10.0.40.1"
        ]
        ipv4 = {
          address = "10.0.40.13/24"
          gateway = "10.0.40.1"
        }
      }
    }
    "node05" = {
      type      = "worker"
      node_name = "proxmox"
      memory = 4096
      network = {
        network_interface = "vmbrLAN"
        vlan_id           = 40
        dns_server = [
          "10.0.40.1"
        ]
        ipv4 = {
          address = "10.0.40.14/24"
          gateway = "10.0.40.1"
        }
      }
    }
    "node06" = {
      type      = "worker"
      node_name = "proxmox"
      memory = 4096
      network = {
        network_interface = "vmbrLAN"
        vlan_id           = 40
        dns_server = [
          "10.0.40.1"
        ]
        ipv4 = {
          address = "10.0.40.15/24"
          gateway = "10.0.40.1"
        }
      }
    }
  }
}


module "kubernetes" {
  source = "./modules/kubernetes"
  kube_nodes = local.nodes
  proxmox_api_token = var.proxmox_api_token
  proxmox_host_endpoint = var.proxmox_host_endpoint
  proxmox_insecure = true
}

output "kubeconfig" {
  description = "Rendered kubeconfig for the Kubernetes cluster"
  value       = module.kubernetes.talos_kubeconfig
  sensitive   = true
}

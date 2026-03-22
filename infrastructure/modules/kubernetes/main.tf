terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.98.1"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_host_endpoint
  api_token = var.proxmox_api_token
  insecure = var.proxmox_insecure
  ssh {
    agent    = var.proxmox_ssh_use_agent
    username = var.proxmox_ssh_user
  }
}

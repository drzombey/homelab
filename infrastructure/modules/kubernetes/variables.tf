# VM
variable "kube_nodes" {
  description = "This is a configuration list to provision kubernetes nodes on talos base os"
  type = map(object({
      type              = string
      node_name = string
      cpu               = optional(number)
      memory            = optional(number)
      disk_size         = optional(number)
      network = optional(object({
        network_interface  = optional(string)
        vlan_id            = optional(number)
        dns_server      = optional(list(string))
        ipv4 = optional(object({
          address = optional(string)
          gateway = optional(string)
        }))
      }))
      talos_config = optional(object({
        official_system_extensions = optional(list(string))
        endpoint                   = optional(string)
        config_patches             = optional(list(string))
      }))
      additional_config = optional(object({
        cpu_type        = optional(string)
        disk_datastore  = optional(string)
        image_datastore = optional(string)
      }))
  }))

  default = {}

  validation {
    condition = alltrue([for k, v in var.kube_nodes : contains(["controlplane", "worker"], v.type)])
    error_message = "Node type needs to be controlplane or worker"
  }

  validation {
    condition = alltrue([
      for k, v in var.kube_nodes : (
        try(v.network.ipv4.address, null) == null ||
        try(v.network.ipv4.address, null) == "dhcp" ||
        (
          length(split("/", try(v.network.ipv4.address, ""))) == 2 &&
          can(cidrhost(try(v.network.ipv4.address, ""), 0))
        )
      )
    ])
    error_message = "network.ipv4.address must be 'dhcp' or a valid IPv4 CIDR like 10.0.40.10/24."
  }

  validation {
    condition = alltrue([
      for k, v in var.kube_nodes : (
        try(v.network.ipv4.address, null) == null ||
        try(v.network.ipv4.address, null) == "dhcp" ||
        try(v.network.ipv4.gateway, null) != null
      )
    ])
    error_message = "network.ipv4.gateway must be set when network.ipv4.address is a static CIDR."
  }
}

# Proxmox provider configs
variable "proxmox_host_endpoint" {
  description = "Host endpoint where the api is available"
  type = string
}

variable "proxmox_api_token" {
  description = "API Token to connect to proxmox host"
  type = string
}

variable "proxmox_insecure" {
  description = "Use insecure connection to host"
  type = bool  
}

variable "proxmox_ssh_user" {
  description = "The user for ssh connection to proxmox node"
  type = string
  default = "root"
}

variable "proxmox_ssh_use_agent" {
    description = "Use ssh agent for connecting to proxmox node"
    default = true
    type = bool
}

variable "talos_cluster_name" {
  description = "Talos cluster name"
  type        = string
  default     = "homelab"
}

variable "talos_cluster_endpoint" {
  description = "Talos cluster endpoint URL, for example https://10.0.30.10:6443"
  type        = string
  default     = null
  nullable    = true
}

variable "talos_bootstrap_node" {
  description = "Node name used for Talos bootstrap; defaults to the first controlplane node"
  type        = string
  default     = null
  nullable    = true
}

variable "talos_install_disk" {
  description = "Target disk used by Talos installer inside the VM"
  type        = string
  default     = "/dev/vda"
}

variable "talos_version" {
  description = "Talos version used for image generation and machine configuration"
  type        = string
  default     = "v1.12.6"
}

variable "kubernetes_version" {
  description = "Optional Kubernetes version for Talos machine configuration"
  type        = string
  default     = null
  nullable    = true
}

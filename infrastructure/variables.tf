variable "proxmox_host_endpoint" {
  description = "Host endpoint where the api is available"
  type        = string
}

variable "proxmox_api_token" {
  description = "API Token to connect to proxmox host"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID für Flux bootstrap"
  type        = number
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID (unter Settings → Developer settings → GitHub Apps → deine App → Install)"
  type        = number
}

variable "github_app_private_key" {
  description = "Inhalt des privaten Schlüssels der GitHub App (PEM-Format)"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub owner (user oder organisation) für das homelab Repository"
  type        = string
  default     = "drzombey"
}

variable "github_repository" {
  description = "GitHub Repository Name"
  type        = string
  default     = "homelab"
}

variable "op_connect_token" {
  description = "1Password Connect API Token für External Secrets Operator (op-token Secret)"
  type        = string
  sensitive   = true
}

variable "op_credentials_json" {
  description = "Inhalt der 1password-credentials.json für den 1Password Connect Server"
  type        = string
  sensitive   = true
}

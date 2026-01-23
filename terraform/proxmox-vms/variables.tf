variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user (e.g., root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox user password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "vm_template_name" {
  description = "Name of VM template (will create from ISO first time)"
  type        = string
  default     = "ubuntu-2404-template"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

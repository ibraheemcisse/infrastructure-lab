# Proxmox VM Provisioning with Terraform

## Setup

1. Copy example config:
```bash
   cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your values

3. Set password:
```bash
   export TF_VAR_proxmox_password='your-password'
```

## Usage
```bash
terraform init
terraform plan
terraform apply
```

## Security

- `terraform.tfvars` is gitignored (contains real IPs/keys)
- `terraform.tfvars.example` is in Git (safe placeholders)
- Password never stored in files

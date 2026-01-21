# VM Creation Guide

## Prerequisites
- Proxmox VE installed and accessible
- ISO uploaded to `/var/lib/vz/template/iso/`
- Network bridges configured (vmbr0 + vmbr1)

## Create VM via Web UI

### 1. General
- VM ID: Auto-increment (100, 101, etc.)
- Name: Descriptive (test-vm, k8s-master-01, etc.)
- Start at boot: Usually unchecked

### 2. OS
- Storage: local
- ISO: Select from dropdown
- Type: Linux
- Version: 6.x - 2.6 Kernel

### 3. System
- Defaults are fine
- Enable Qemu Agent: ✅ (recommended)

### 4. Disks
- Bus/Device: SCSI
- Storage: local (directory-backed)
- Size: According to needs (10-100GB)
- Discard: ✅ (for SSD trim)

### 5. CPU
- Sockets: 1
- Cores: 1-4 depending on workload

### 6. Memory
- Size: 2GB minimum for Linux
- 4GB+ for K8s nodes

### 7. Network
- **Bridge: vmbr1** (for NAT internet access)
- Model: VirtIO (best performance)
- Firewall: Unchecked initially

### 8. Confirm
- Review settings
- Click "Finish"
- VM will auto-start if checkbox was on

## Ubuntu Installation

### Network Configuration (Manual/Static)
```
Subnet: 10.0.0.0/24
Address: 10.0.0.X (increment for each VM)
Gateway: 10.0.0.1
Name servers: 8.8.8.8,8.8.4.4
```

### Storage
- Use entire disk (simplest)
- LVM setup (recommended)

### Profile
- Set username and password
- Server name matches VM name

### SSH
- Install OpenSSH server: ✅
- Import SSH key: Optional (can add later)

### Packages
- Skip featured snaps (minimal install)

## Post-Installation

### 1. Add SSH Key (from Proxmox host)
```bash
# From your laptop
ssh-copy-id ibrahim@10.0.0.X
```

### 2. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Verify Internet
```bash
ping -c 3 8.8.8.8
ping -c 3 google.com
```

### 4. Install Qemu Guest Agent (if not already)
```bash
sudo apt install qemu-guest-agent -y
sudo systemctl enable --now qemu-guest-agent
```

## Troubleshooting

### No Internet in VM
1. Check VM network adapter: Should be vmbr1
2. Check IP config: `ip addr show`
3. Check gateway: `ip route show` (should be 10.0.0.1)
4. Check NAT rules on host: `iptables -t nat -L POSTROUTING`
5. Check DNS: `cat /etc/resolv.conf`

### Can't SSH to VM
1. From Proxmox host: `ssh ibrahim@10.0.0.X` (should work)
2. From laptop: Won't work directly (VM is behind NAT)
3. Solution: SSH through Proxmox host as jump box

## IP Address Allocation

**Reserved:**
- 10.0.0.1: Gateway (Proxmox host vmbr1)

**VMs:**
- 10.0.0.10: test-vm
- 10.0.0.11-13: Future K8s cluster
- 10.0.0.20+: Additional VMs as needed

# Infrastructure Build Log

## Phase 1: Foundation (Jan 20, 2025)

### Objective
Build bare metal Proxmox VE platform with production-like networking.

---

## Architecture Decisions

### Storage Strategy
**RAID1 on 2x NVMe:**
- Mirrored for redundancy
- 476GB → 360GB usable after system partitions
- Layout: 96GB root, 20GB swap, 360GB VM storage

**Rationale:**
- Lab can afford 50% capacity loss
- Demonstrates production patterns
- Easy to rebuild if drive fails

### Network Strategy
**Dual-bridge approach:**

**vmbr0 (Public bridge):**
- Proxmox host management
- Bound to physical NIC
- Public IP: 203.0.113.10/26 (sanitized)

**vmbr1 (NAT bridge):**
- VM internet access
- Private network: 10.0.0.0/24
- NAT/MASQUERADE to vmbr0

**Rationale:**
- Management isolated from VM network
- VMs don't need public IPs
- Mirrors production DMZ patterns

---

## Implementation Notes

### Debian Installation
**Method:** Hetzner installimage with custom config

**Key config changes:**
- Hostname: pve
- LVM volumes: root (96G), swap (8G→20G auto-adjusted), data (all)
- RAID level: 1 (mirroring)

**Issue encountered:**
```
ERROR: Partition size "all" has to be on the last partition
```
**Cause:** data LV not last in definition order  
**Fix:** Reordered LV lines, commented out conflicting PART definitions

### Proxmox Installation
**Method:** Add Proxmox repo to Debian, apt install
```bash
curl -fsSL https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg \
  -o /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-install-repo.list

apt update && apt full-upgrade -y
apt install proxmox-ve postfix open-iscsi chrony -y
reboot
```

**Result:** Proxmox VE 8.4.16, kernel 6.8.12-18-pve

### Network Configuration
**Applied config incrementally:**

1. Brought up vmbr0 (public) first
2. Tested connectivity before proceeding
3. Brought up vmbr1 (NAT) separately
4. Verified iptables NAT rules active

**Lesson from first attempt:**
- Never apply both bridges simultaneously without testing
- Use `ifup --no-act` to validate syntax
- Test one change at a time

**Validation:**
```bash
ip addr show vmbr0  # Shows public IP
ip addr show vmbr1  # Shows 10.0.0.1
iptables -t nat -L POSTROUTING  # Shows MASQUERADE rule
```

---

## Test VM Validation

**Created Ubuntu 24.04 VM:**
- Network: vmbr1 (NAT)
- IP: 10.0.0.10/24
- Gateway: 10.0.0.1

**NAT validation:**
```bash
ibrahim@test-vm:~$ ping -c 1 8.8.8.8
1 packets transmitted, 1 received, 0% packet loss

ibrahim@test-vm:~$ ping -c 1 google.com  
1 packets transmitted, 1 received, 0% packet loss
```

**Result:** NAT networking fully functional ✅

---

## Lessons Learned

### What Worked
- Incremental network config application
- Testing each bridge independently  
- Documenting decisions in real-time
- Version controlling all configs

### What Failed (First Attempt)
- Applying complete network config to live system
- No rollback plan when iptables rules broke connectivity
- Spent 8+ hours trying to recover broken boot

### Key Insight
**Recovery time > Rebuild time**

Lesson: When state is unknown and documentation is solid, rebuild is often faster than archaeology.

---

## Status: Phase 1 Complete

**Functional:**
- ✅ Proxmox VE operational
- ✅ Dual-bridge networking
- ✅ NAT validated with test VM
- ✅ All infrastructure documented

**Security gaps (Phase 2):**
- ⚠️ Management UI exposed on public IP
- ⚠️ No firewall configured
- ⚠️ Root SSH unrestricted

**Next:**
- Firewall configuration (UFW)
- Management access restrictions
- K8s cluster deployment

### Phase 1 Cleanup

**Test VM removed:**
- VM 100 (test-vm) successfully validated NAT networking
- Deleted to free resources for K8s cluster
- NAT functionality confirmed working

**Phase 1 Status: COMPLETE**
- ✅ Infrastructure foundation stable
- ✅ Security hardened (firewall active)
- ✅ Ready for Kubernetes deployment

---

## Phase 2: Infrastructure as Code + Kubernetes

**Starting:** [DATE]
**Goal:** 3-node K8s cluster provisioned via Terraform

## Week 2: Kubernetes Infrastructure (Day 1)

### VMs Created Successfully

**Date:** January 23, 2026

Created 3 VMs through Proxmox UI for Kubernetes cluster:

**k8s-master-01 (VM 101):**
- IP: 10.0.0.11/24
- Resources: 2 vCPU, 12GB RAM, 50GB disk
- Purpose: Kubernetes control plane
- Status: ✅ Running, SSH configured

**k8s-worker-01 (VM 102):**
- IP: 10.0.0.12/24
- Resources: 4 vCPU, 16GB RAM, 100GB disk
- Purpose: Kubernetes worker node
- Status: ✅ Running, SSH configured

**k8s-worker-02 (VM 103):**
- IP: 10.0.0.13/24
- Resources: 4 vCPU, 16GB RAM, 100GB disk
- Purpose: Kubernetes worker node
- Status: ✅ Running, SSH configured

**Network Configuration:**
- All nodes on vmbr1 (NAT bridge)
- Gateway: 10.0.0.1 (Proxmox host)
- DNS: 8.8.8.8, 8.8.4.4
- Internet: ✅ Working via NAT

**SSH Access:**
- SSH keys copied to all nodes
- Accessible via ProxyJump through Proxmox
- Passwordless sudo configured on all nodes
- Command: `ssh -J root@100.121.221.116 ibrahim@10.0.0.1X`

**Ready for:** Kubernetes deployment with Kubespray

**Time to create:** ~2 hours (including parallel installations)

### Kubespray Configuration Complete

**Date:** January 23, 2026

**Configured Kubernetes deployment:**
- Kubespray release-2.25 cloned and configured
- Ansible inventory created for 3-node cluster
- SSH ProxyCommand configured for bastion access
- All nodes responding to Ansible ping

**Architecture:**
- node1: Control plane + etcd
- node2, node3: Worker nodes
- CNI: Calico (default)
- Container runtime: containerd

**Ready for:** Ansible playbook execution to deploy K8s

**Documentation:** kubernetes/KUBESPRAY_SETUP.md

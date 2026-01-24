# Kubernetes Deployment with Kubespray

## Overview

Deployed 3-node Kubernetes cluster using Kubespray (Ansible-based automation).

## Cluster Architecture

**Control Plane:**
- node1 (10.0.0.11): kube-apiserver, etcd, scheduler, controller-manager

**Workers:**
- node2 (10.0.0.12): kubelet, kube-proxy, container runtime
- node3 (10.0.0.13): kubelet, kube-proxy, container runtime

## Deployment Process

### Prerequisites

**Installed on laptop:**
```bash
sudo apt install ansible python3-pip sshpass
```

**SSH access configured:**
- ProxyJump through Proxmox host
- SSH keys copied to all nodes
- Passwordless sudo on all nodes

### Kubespray Setup
```bash
# Clone Kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout release-2.25

# Install dependencies
pip3 install -r requirements.txt --break-system-packages

# Create inventory
cp -rfp inventory/sample inventory/mycluster

# Configure nodes
declare -a IPS=(10.0.0.11 10.0.0.12 10.0.0.13)
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```

### Inventory Configuration

**File:** `kubespray/inventory/mycluster/hosts.yaml`
```yaml
all:
  hosts:
    node1:
      ansible_host: 10.0.0.11
      ansible_user: ibrahim
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q root@100.121.221.116"'
    node2:
      ansible_host: 10.0.0.12
      ansible_user: ibrahim
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q root@100.121.221.116"'
    node3:
      ansible_host: 10.0.0.13
      ansible_user: ibrahim
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q root@100.121.221.116"'
  children:
    kube_control_plane:
      hosts:
        node1:
    kube_node:
      hosts:
        node2:
        node3:
    etcd:
      hosts:
        node1:
```

**Key configuration:**
- ProxyCommand for SSH through Proxmox bastion
- Dedicated control plane (node1 only)
- Dedicated workers (node2, node3)
- Single etcd instance (node1)

### Ansible Configuration

**File:** `kubespray/ansible.cfg`
```ini
[defaults]
host_key_checking = False
timeout = 30

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=30m
pipelining = True
```

### Deployment Command
```bash
ansible-playbook -i inventory/mycluster/hosts.yaml \
  --become --become-user=root \
  cluster.yml \
  --ask-pass --ask-become-pass
```

## Post-Deployment

**Verify cluster:**
```bash
# Copy kubeconfig from master
scp -o ProxyCommand="ssh -W %h:%p root@100.121.221.116" \
  ibrahim@10.0.0.11:~/.kube/config ~/.kube/config

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -A
```

## Network Configuration

**Bastion/Jump Host Pattern:**
```
Laptop → Proxmox (100.121.221.116) → K8s Nodes (10.0.0.0/24)
```

**SSH ProxyCommand allows:**
- Direct Ansible execution to private nodes
- Industry-standard security pattern
- All nodes isolated on NAT network

## Deployment Time

- Setup: 30 minutes
- Ansible playbook: 20-30 minutes
- Total: ~1 hour

## Next Steps

1. Verify cluster health
2. Deploy test application
3. Add monitoring stack (Week 3)
4. Implement CI/CD (Week 4)

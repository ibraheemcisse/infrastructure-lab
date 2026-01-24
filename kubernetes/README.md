# Kubernetes Cluster

## Cluster Information

**Version:** v1.28.6  
**Nodes:** 3 (1 control plane, 2 workers)  
**CNI:** Calico  
**Deployment Method:** Kubespray (Ansible)

## Architecture
```
Control Plane (node1 - 10.0.0.11):
├── kube-apiserver
├── kube-scheduler
├── kube-controller-manager
└── etcd

Worker Nodes:
├── node2 (10.0.0.12): kubelet, kube-proxy, calico
└── node3 (10.0.0.13): kubelet, kube-proxy, calico
```

## Access

**From laptop:**
```bash
# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check specific namespace
kubectl get pods -n kube-system
```

**From master node:**
```bash
# SSH to master
ssh -J root@100.121.221.116 ibrahim@10.0.0.11

# Use admin kubeconfig
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes
```

## Current Status

**Healthy:**
- ✅ All nodes Ready
- ✅ Control plane components running
- ✅ Network plugin operational
- ✅ Node-to-node communication working

**Issues:**
- ⚠️ CoreDNS pods in CrashLoopBackOff
- Needs: DNS troubleshooting and resolution

## Deployment Details

See: `KUBESPRAY_SETUP.md` for full deployment documentation

## Next Steps

1. Fix CoreDNS
2. Deploy test application (nginx)
3. Deploy Healthcare API
4. Add monitoring (Week 3)

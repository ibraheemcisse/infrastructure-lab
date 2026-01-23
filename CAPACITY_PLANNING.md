
## Kubernetes Cluster Resource Allocation

### VM Specifications

**k8s-master-01:**
- CPU: 2 vCores (control plane: apiserver, etcd, scheduler, controller-manager)
- RAM: 12GB (etcd + control plane pods + OS overhead)
- Disk: 50GB (OS, logs, etcd data, images)

**k8s-worker-01:**
- CPU: 4 vCores (application pods + system daemons)
- RAM: 16GB (~12GB available for pods after system reserved)
- Disk: 100GB (OS, container images, logs, ephemeral storage)

**k8s-worker-02:**
- CPU: 4 vCores (application pods + system daemons)
- RAM: 16GB (~12GB available for pods after system reserved)
- Disk: 100GB (OS, container images, logs, ephemeral storage)

### Cluster Capacity

**Total allocated:**
- CPU: 10 vCores (1.25x overcommit on 8 physical threads)
- RAM: 44GB (68% of 64GB total, 20GB buffer)
- Disk: 250GB (69% of 360GB available, 110GB buffer)

**Estimated pod capacity:**
- 15-25 pods total across cluster
- Depends on pod resource requests
- Typical pod: 100m-500m CPU, 512MB-2GB RAM

### Resource Justification

**CPU overcommit (1.25x):**
- Safe for lab workloads (bursty, not sustained 100%)
- K8s workloads typically 20-50% utilization
- Allows scheduling flexibility

**RAM allocation (no overcommit):**
- 31% buffer prevents OOM issues
- Sufficient for monitoring stack + applications
- Room for memory spikes

**Disk allocation:**
- 110GB remaining for growth
- ~5-10 months buffer
- LVM allows expansion if needed

### Comparison to Production

**Lab (current):**
- Single control plane (no HA)
- 2 workers (minimal redundancy)
- Moderate overcommit
- Cost: €36/month

**Production equivalent:**
- 3 control plane nodes (HA)
- 5+ worker nodes (proper redundancy)
- Conservative overcommit
- Load balancers, monitoring, logging
- Cost: €300-500/month

**Lab demonstrates production concepts at 10% of cost.**

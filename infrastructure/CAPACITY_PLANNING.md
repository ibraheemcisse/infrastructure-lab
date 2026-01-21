# Infrastructure Capacity Planning

## Physical Hardware

**Server:** Hetzner Dedicated AX41-NVMe  
**CPU:** Intel Core i7-6700 (Skylake, 2015)
- Physical cores: 4
- Threads (with HT): 8
- Base clock: 3.4 GHz
- Turbo: 4.0 GHz

**Memory:** 64GB DDR4 (4x 16GB sticks)

**Storage:** 
- 2x Samsung NVMe 512GB (MZVLB512HAJQ)
- RAID1 configuration
- Usable capacity: ~476GB mirrored

---

## CPU Allocation Strategy

### Understanding CPU vs Thread vs vCPU

**Physical reality:**
```
1 CPU die
└── 4 physical cores
    └── 8 logical threads (Hyperthreading)
```

**What Proxmox sees:** 8 CPU threads available for allocation

**What to allocate:** vCPUs map to threads, not cores

### Overcommit Philosophy

**Conservative rule:** 1.25-1.5x overcommit safe for mixed workloads

**Why it works:**
- VMs rarely use 100% CPU simultaneously
- K8s control plane is I/O/network bound (not CPU bound)
- Application workloads are bursty (not sustained)
- Proxmox fair scheduler prevents starvation

**When it breaks:**
- All VMs running CPU-intensive workloads simultaneously
- Poor application design (busy-wait loops, inefficient algorithms)
- Insufficient RAM causing swap thrashing → CPU overhead

---

## Planned VM Allocation

### Test VM (Temporary)
```
Purpose: Validate NAT networking
CPU: 1 vCPU
RAM: 2GB
Disk: 10GB
Lifecycle: Delete after validation
```

### Kubernetes Cluster (Production Lab)

**Master Node:**
```
Hostname: k8s-master-01
CPU: 2 vCPU
RAM: 12GB
Disk: 50GB
Network: vmbr1 (10.0.0.10)

Rationale:
- Control plane components (etcd, API server, scheduler, controller)
- 2 vCPU sufficient (mostly I/O and API requests)
- 12GB RAM for etcd data + API server cache + system overhead
```

**Worker Node 1:**
```
Hostname: k8s-worker-01  
CPU: 4 vCPU
RAM: 16GB
Disk: 100GB
Network: vmbr1 (10.0.0.11)

Rationale:
- Runs application pods + system pods (CNI, monitoring agents)
- 4 vCPU for parallel pod execution
- 16GB RAM for Prometheus + application workloads
```

**Worker Node 2:**
```
Hostname: k8s-worker-02
CPU: 4 vCPU
RAM: 16GB  
Disk: 100GB
Network: vmbr1 (10.0.0.12)

Rationale:
- Mirror of worker-01 for redundancy
- Runs Grafana, Alertmanager, backup workloads
```

---

## Resource Budget

### CPU Allocation
```
Total threads available: 8

Allocated:
├── k8s-master:  2 vCPU (25%)
├── k8s-worker1: 4 vCPU (50%)
├── k8s-worker2: 4 vCPU (50%)
└── Proxmox host: ~5-10% overhead

Total vCPU: 10
Physical threads: 8
Overcommit ratio: 1.25x ✅ Conservative

Expected utilization:
- Idle: 5-10% aggregate
- Normal: 20-40% aggregate  
- Peak: 60-80% aggregate
```

### Memory Allocation
```
Total RAM: 64GB

Allocated:
├── k8s-master:  12GB (18.75%)
├── k8s-worker1: 16GB (25%)
├── k8s-worker2: 16GB (25%)
├── Proxmox host: ~2-4GB (6%)
└── Buffer:      18GB (28%) ✅ Healthy buffer

Memory overcommit: NONE (not recommended for production-like workloads)

Rationale: RAM is cheap, OOM kills are expensive
```

### Storage Allocation
```
Total usable (after RAID1): 476GB

LVM layout:
├── root (Proxmox OS):     96GB (20%)
├── swap:                  20GB (4%)  
└── data (/var/lib/vz):   360GB (76%)

VM disk allocation:
├── k8s-master:   50GB  (14% of data)
├── k8s-worker1: 100GB  (28% of data)
├── k8s-worker2: 100GB  (28% of data)
└── Remaining:   110GB  (30% for ISOs, snapshots, backups)

Storage overcommit: NONE (thin provisioning disabled for predictability)
```

---

## Capacity Headroom

### Available for Future Use
```
CPU: ~0-2 vCPU depending on actual utilization
RAM: 18GB (~28% reserve)
Disk: 110GB (30% reserve)
```

### Growth Scenarios

**Scenario 1: Add monitoring/logging VM**
```
Requirements: 2 vCPU, 8GB RAM, 50GB disk
Feasible: ✅ Yes (within budget)
```

**Scenario 2: Add 4th K8s worker**
```
Requirements: 4 vCPU, 16GB RAM, 100GB disk
Feasible: ⚠️ Marginal
- CPU: Would hit 1.75x overcommit (risky)
- RAM: Only 2GB remaining (too tight)
- Disk: Only 10GB remaining (insufficient)
```

**Scenario 3: Increase worker RAM to 20GB each**
```
Feasible: ⚠️ Possible but tight
- Would use 56GB of 64GB
- Only 8GB buffer (12.5% - below recommended 20%)
```

---

## Monitoring & Alerts

### Resource Utilization Targets

**CPU (aggregate across all VMs):**
- Green: <50% average
- Yellow: 50-70% average  
- Red: >70% sustained (review allocation)

**Memory (per VM):**
- Green: <70% used
- Yellow: 70-85% used
- Red: >85% used (risk of OOM)

**Disk (data LVM):**
- Green: <70% used  
- Yellow: 70-85% used
- Red: >85% used (cleanup or expand)

### When to Scale

**Indicators needing more resources:**
- CPU steal time >10% (overcommit too aggressive)
- Frequent OOM kills (insufficient RAM)
- Disk I/O wait >20% (storage bottleneck)
- K8s pods pending due to "insufficient resources"

---

## Rebuild Resource Requirements

**Minimum to replicate this setup:**
- CPU: 4 cores / 8 threads
- RAM: 48GB (can reduce workers to 12GB each)
- Disk: 300GB usable (after RAID)

**Recommended for comfort:**
- CPU: 6+ cores / 12+ threads
- RAM: 64GB+
- Disk: 500GB+ NVMe

---

## Cost-Benefit Analysis

**This server: €36.53/month**

**Equivalent cloud resources (AWS us-east-1):**
```
3x t3.xlarge (4 vCPU, 16GB): ~$300/month
EBS storage (250GB gp3): ~$20/month
Data transfer: ~$20/month
───────────────────────────────────
Total: ~$340/month = €320/month

Savings: €283/month (89% cost reduction)
Annual: €3,396 saved
```

**Break-even vs buying hardware:**
- Used server (~€500): 1.4 months
- New workstation (~€2000): 5.5 months

**Conclusion:** Dedicated server optimal for learning/lab use

---

## Lessons Learned

1. **Don't conflate cores with threads** - Use thread count for vCPU budget
2. **Conservative overcommit (1.25-1.5x) is safe** - Beyond 2x risks contention
3. **Never overcommit RAM** - OOM kills > CPU throttling
4. **Plan 20-30% headroom** - For snapshots, experiments, growth
5. **Document BEFORE building** - Prevents "let's just try..." mistakes

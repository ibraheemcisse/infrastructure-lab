# Production Infrastructure Lab

Bare metal to production-grade Kubernetes cluster with comprehensive observability and chaos engineering validation.

## Stack
```
Hetzner Dedicated (i7-6700, 64GB, 2x512GB NVMe RAID1)
├── Proxmox VE 8.x (Type-1 hypervisor)
├── Dual-bridge networking (public + NAT)
├── 3-node Kubernetes 1.28
├── Prometheus + Grafana observability
└── Chaos scenarios with documented recovery
```

## Phases

1. **Infrastructure** - Virtualization platform (this session)
2. **Kubernetes** - Container orchestration  
3. **Observability** - Metrics, logs, alerts
4. **Chaos** - Resilience validation

## Build Log

See `infrastructure/BUILD_LOG.md` for real-time notes.

## Time to Rebuild

Target: < 4 hours bare metal → working K8s cluster

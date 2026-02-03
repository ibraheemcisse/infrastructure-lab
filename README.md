# Infrastructure Lab

Bare-metal Kubernetes platform demonstrating **security-hardened workloads**, **observability-driven operations**, and **chaos-validated resilience**.

**What this is:** A homelab used to learn by intentionally breaking systems.  
**What this is not:** Enterprise production infrastructure.

---

## Stack

- **Physical:** Hetzner Dedicated (i7-6700, 64GB RAM)
- **Hypervisor:** Proxmox VE
- **Kubernetes:** v1.28 (3 nodes, Kubespray)
- **CNI:** Calico
- **Observability:** Prometheus + Grafana
- **Applications:** FastAPI, PostgreSQL

---

## Architecture
```
┌─────────────────────────────────────────────┐
│ Proxmox Host (Hetzner)                      │
│                                             │
│  ┌──────────┐  ┌─────────┐  ┌──────────┐  │
│  │ k8s-cp-1 │  │ k8s-w-1 │  │ k8s-w-2  │  │
│  │ Control  │  │ Worker  │  │ Worker   │  │
│  └──────────┘  └─────────┘  └──────────┘  │
└─────────────────────────────────────────────┘
         │
         ├─ Applications (healthcare-api)
         ├─ PostgreSQL (StatefulSet)
         └─ Monitoring (Prometheus/Grafana)
```

Single-cluster, single-region, single-control-plane by design.

---

## Security Posture

### Assumptions
- Any pod may be compromised  
- Internal traffic is untrusted  
- Repository is public  

### Controls
- Non-root containers  
- Read-only root filesystems  
- Dropped Linux capabilities  
- RuntimeDefault seccomp  
- Secrets via Kubernetes Secrets  
- Dedicated ServiceAccounts  
- RBAC least privilege  
- NetworkPolicies for isolation  
- No secrets in Git  

**Goal:** Reduce blast radius, not eliminate risk.

---

## What Exists

### Infrastructure
- 3-node Kubernetes cluster
- Terraform VM provisioning (Proxmox)
- Kubespray bootstrap
- Local persistent volumes

### Security
- Pod security contexts
- Minimal ServiceAccounts
- Secret-based configuration
- Network isolation

### Observability
- Prometheus
- Grafana dashboards
- postgres_exporter

### Operations
- GitHub Actions CI/CD
- Chaos testing
- SRE-style postmortems

---

## Chaos Tests

1. Pod CrashLoopBackOff (bad rollout)
2. Node failure (local storage outage)
3. Deployment → StatefulSet migration
4. Memory OOM kill
5. PostgreSQL monitoring instrumentation

Postmortems in `/postmortems/`.

---

## Key Findings

### Node Failure
- Local PV = single point of failure  
- PostgreSQL unavailable for 25 hours  
- Data intact but inaccessible  

**Lesson:** HA storage or external DB required for production.

### Memory OOM
- Container killed at memory limit (137)  
- Recovered in ~10 seconds  
- Multi-replica API remained available  

**Lesson:** Memory limits are hard ceilings.

### Cost vs Scaling
- CPU <25% even at failure point  
- Bottleneck was DB connections  
- Infra scaling did not solve problem  

**Lesson:** Measure before scaling.

---

## Trade-offs

### Local Storage
- Fast, simple, free  
- Not HA  

### Single Control Plane
- Cheaper, simpler  
- No CP HA  

### Static Resource Limits
- Explicit boundaries  
- Not dynamic  

All intentional for lab.

---

## Repository Layout
```
infrastructure/
├── terraform/
└── BUILD_LOG.md

kubernetes/
├── applications/
│   ├── healthcare-api/
│   └── postgresql/
└── monitoring/

postmortems/
chaos/
docs/
```

---

## Rebuild Time

Target: **< 4 hours**  
Bare metal → functioning cluster

Validated during clean rebuilds.

---

## Related Projects

- Multi-node Kubernetes with Terraform  
  https://github.com/ibraheemcisse/multi-node-kubernetes-cluster

- AWS Infrastructure Trade-offs  
  https://github.com/ibraheemcisse/devops-dashboard

- KEDA Autoscaling on EKS  
  https://github.com/ibraheemcisse/KEDA-HTTP-Add-On-with-Autoscaling-on-Kubernetes-EKS-

---

## Demonstrates

- Infrastructure provisioning  
- Kubernetes security hardening  
- Chaos engineering  
- Postmortem-driven improvement  
- Cost/performance analysis  

---

## Does NOT Demonstrate

- Multi-region HA  
- Managed cloud platforms  
- Enterprise-scale ops  
- Perfect security  

Learning environment, not reference architecture.

---

## Philosophy

- Security is a posture  
- Documentation reflects reality  
- Chaos validates assumptions  
- Trade-offs must be explicit  
- Complexity requires justification  

---

## License

MIT

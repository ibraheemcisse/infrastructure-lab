# Infrastructure Lab

Bare-metal Kubernetes platform demonstrating security-hardened deployments, chaos engineering, and operational documentation.

**What this is:** A homelab where I learn by breaking things on purpose.

**What this isn't:** Enterprise production infrastructure.

---

## Stack

**Physical:** Hetzner dedicated server (i7-6700, 64GB RAM)  
**Virtualization:** Proxmox VE  
**Orchestration:** Kubernetes 1.28 (3 nodes, Kubespray)  
**CNI:** Calico  
**Observability:** Prometheus + Grafana  
**Applications:** FastAPI + PostgreSQL  

---

## Architecture
```
┌─────────────────────────────────────────┐
│ Proxmox Host (Hetzner)                  │
│                                         │
│  ┌──────────┐  ┌─────────┐  ┌────────┐│
│  │ k8s-cp-1 │  │ k8s-w-1 │  │k8s-w-2 ││
│  │ Control  │  │ Worker  │  │Worker  ││
│  └──────────┘  └─────────┘  └────────┘│
└─────────────────────────────────────────┘
         │
         ├─> Applications (healthcare-api)
         ├─> PostgreSQL (StatefulSet)
         └─> Monitoring (Prometheus/Grafana)
```

---

## Security Posture

**Assumptions:**
- Any pod can be compromised
- Internal traffic is untrusted
- This repo is public

**Controls:**
- Non-root containers
- Read-only filesystems
- Dropped capabilities
- Secrets via Kubernetes Secret objects
- RBAC-restricted ServiceAccounts
- NetworkPolicies for pod isolation
- No secrets in git

**Goal:** Reduce blast radius, not eliminate risk.

---

## What I Built

**Infrastructure:**
- 3-node Kubernetes cluster (bare metal)
- Terraform provisioning (Proxmox)
- StatefulSet database deployment
- Local persistent storage

**Security:**
- Pod security contexts (non-root, read-only FS, seccomp)
- Dedicated ServiceAccounts with minimal RBAC
- Secrets management (no hardcoded credentials)
- Network isolation

**Observability:**
- Prometheus metrics collection
- Grafana dashboards (nodes, pods, PostgreSQL)
- postgres_exporter for database metrics

**Operations:**
- CI/CD pipeline (GitHub Actions)
- Chaos engineering (5 documented failure scenarios)
- SRE-style postmortems

---

## Chaos Tests

I intentionally broke things to understand failure modes:

1. **Pod CrashLoopBackOff** - Bad deployment during rolling update
2. **Node Failure** - 25-hour outage from local storage limitation
3. **StatefulSet Migration** - Deployment → StatefulSet conversion
4. **Memory OOM** - Out of memory kill and self-healing
5. **PostgreSQL Monitoring** - Database observability setup

Each test has a postmortem in `/postmortems/`.

---

## Key Findings

**Node Failure Test:**
- Local storage creates single point of failure
- When node died, PostgreSQL was unavailable for 25 hours
- Data persisted but was inaccessible until node recovery
- **Lesson:** Distributed storage or external databases required for HA

**Memory OOM Test:**
- Kubernetes killed container at memory limit (exit code 137)
- Self-healing worked (10-second recovery)
- Multi-replica deployment maintained service availability
- **Lesson:** Memory limits are hard ceilings, not throttles like CPU

**Cost Optimization:**
- CPU never the bottleneck (always <25% at breaking point)
- Database connection pooling was the real limit
- Infrastructure scaling didn't fix application-level problems
- **Lesson:** Measure before scaling

---

## Trade-offs

**Local Storage:**
- ✅ Fast, simple, no cost
- ❌ Not HA, tied to single node
- **Choice:** Acceptable for lab, unacceptable for production

**Single Control Plane:**
- ✅ Cheaper, simpler
- ❌ No HA for control plane
- **Choice:** Acceptable for lab

**Hardcoded Limits:**
- ✅ Explicit resource boundaries
- ❌ Not dynamic
- **Choice:** Intentional for learning

---

## Repository Structure
```
infrastructure/
├── terraform/          # VM provisioning
└── BUILD_LOG.md        # Chronological build notes

kubernetes/
├── applications/       # App manifests
│   ├── healthcare-api/
│   └── postgresql/
└── monitoring/         # Observability stack

postmortems/            # Failure analysis
└── 001-*.md through 008-*.md

chaos/                  # Test scenarios
docs/                   # Architecture docs
```

---

## Rebuild Time

**Target:** < 4 hours (bare metal → working cluster)

**Validated:** During clean rebuilds

---

## Related Projects

- [Multi-node K8s with Terraform](https://github.com/ibraheemcisse/multi-node-kubernetes-cluster) - IaC automation
- [KEDA Autoscaling on EKS](https://github.com/ibraheemcisse/KEDA-HTTP-Add-On-with-Autoscaling-on-Kubernetes-EKS-) - Advanced K8s

---

## What This Lab Demonstrates

- Infrastructure provisioning (Terraform + Kubespray)
- Kubernetes security hardening
- Chaos engineering methodology
- Operational documentation (postmortems)
- Cost-performance trade-offs
- Problem-solving under constraints

---

## What This Lab Does NOT Demonstrate

- Multi-region HA
- Managed cloud services (EKS, GKE)
- Enterprise-scale operations
- Perfect security

**This is a learning environment, not a reference architecture.**

---

## Philosophy

- Security is a posture, not a feature
- Documentation must reflect reality
- Chaos testing validates assumptions
- Trade-offs should be explicit
- Complexity requires justification

---

## License

MIT

# Infrastructure Lab  
**Bare Metal → Proxmox → Kubernetes → Observability → Failure**

**Target roles:** Platform Engineer · SRE · Infrastructure Engineer  
**Video walkthrough:** https://youtu.be/4DzHJQIVU0g

A production-style Kubernetes platform built from bare metal to validate **capacity planning, security posture, observability, and failure modes** under real workloads.

This is a **learning and validation environment**, not a reference production architecture.

---

## Why This Exists

Managed Kubernetes hides the hardest decisions.

This lab exists to force those decisions into the open:

- Storage without EBS  
- Failure without autoscaling safety nets  
- Security when you control the entire stack  
- Capacity planning before scale  
- Observability before incident response  

The goal is simple:

> **Expose bad assumptions early, document the consequences, and decide what would change in production.**

---

## High-Level Architecture

- **Bare metal:** Hetzner dedicated server  
- **Hypervisor:** Proxmox VE  
- **Kubernetes:** v1.28, 3 VMs, bootstrapped with Kubespray  
- **Networking:** Calico  
- **Observability:** Prometheus + Grafana  
- **Workloads:** FastAPI (healthcare API), PostgreSQL (StatefulSet)  

Single cluster, single region, single control plane — by design.

---

## What This Lab Demonstrates

### Platform & Infrastructure
- Bare-metal virtualization with Proxmox  
- Capacity planning before cluster creation  
- Kubernetes bootstrapping with Kubespray  
- Local PersistentVolumes for stateful workloads  

### Security Engineering
- Non-root containers and read-only root filesystems  
- Dropped Linux capabilities with `RuntimeDefault` seccomp  
- Least-privilege RBAC and dedicated ServiceAccounts  
- NetworkPolicies for pod-level isolation  
- No secrets committed to Git  

**Goal:** Reduce blast radius, not eliminate risk.

### Observability
- Cluster and application metrics via Prometheus  
- Grafana dashboards for infra, app, and database health  
- PostgreSQL instrumentation with `postgres_exporter`  
- Metrics-driven debugging instead of guesswork  

### Operations & Reliability
- CI/CD using RBAC-restricted ServiceAccounts (no kubeconfig)  
- Controlled chaos experiments  
- SRE-style postmortems with root cause analysis  

---

## Key Design Decisions (and Why)

### Local Storage for PostgreSQL
**Decision:** Local PersistentVolumes on worker nodes  

- Fast and simple  
- No distributed storage complexity  

**Trade-off:**  
- Node failure = database unavailable  

**Production choice:** Distributed storage (Longhorn / Rook) or external managed database.

---

### Single Control Plane
**Decision:** One control plane node  

- Lower cost  
- Simpler topology  

**Trade-off:**  
- Control plane downtime = cluster downtime  

**Production choice:** 3+ control plane nodes behind a load balancer.

---

### PostgreSQL as StatefulSet
**Decision:** StatefulSet instead of Deployment  

- Stable identity  
- Ordered lifecycle  
- Dedicated PVCs  

**Trade-off:**  
- Higher operational complexity  

Correct choice for databases.

---

### Strict Security Contexts
**Decision:** Enforced non-root user, read-only filesystem, dropped capabilities  

- Reduced attack surface  
- Explicit permission requirements  

**Trade-off:**  
- Increased setup and debugging effort  

This should be the default.

---

### CI/CD Without kubeconfig
**Decision:** RBAC-scoped ServiceAccount tokens  

- Least privilege  
- Auditable identity  

**Trade-off:**  
- More upfront RBAC work  

Using kubeconfig in CI is a footgun.

---

## Chaos Experiments

Executed and documented:

1. Bad rollout → `CrashLoopBackOff`  
2. Node failure → local storage outage  
3. Deployment → StatefulSet migration  
4. Memory OOM kill  
5. PostgreSQL observability gaps  

Postmortems are documented in `/postmortems`.

---

## Key Findings

### Node Failure
- PostgreSQL unavailable for **25 hours**  
- Data intact but inaccessible  

**Lesson:** Local storage is unacceptable for production databases.

---

### Memory OOM
- Container killed at memory limit  
- Recovery in ~10 seconds  
- Multi-replica API remained available  

**Lesson:** Memory limits are hard ceilings.

---

### Scaling vs Reality
- CPU usage remained under 25%  
- Bottleneck was database connections  

**Lesson:** Scaling infrastructure does not fix bad assumptions.

---

## What This Proves

After completing this lab, I can:

- Operate Kubernetes without managed control planes  
- Design storage strategies for stateful workloads  
- Apply least-privilege security across clusters  
- Build observability before incidents occur  
- Design and execute chaos experiments  
- Write clear, actionable postmortems  
- Make explicit trade-offs between cost, complexity, and risk  

---

## Repository Structure

```
infrastructure/
  terraform/
  BUILD_LOG.md

kubernetes/
  applications/
  monitoring/

postmortems/
chaos/
docs/
```

---

## Rebuild Time

**< 4 hours**  
Bare metal → functioning cluster  

Validated through clean rebuilds.

---

## Philosophy

- Assumptions fail before systems do  
- Security is about blast radius  
- Observability precedes reliability  
- Chaos validates confidence  
- Complexity must earn its place  

---

## License

MIT

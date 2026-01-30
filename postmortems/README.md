# Postmortem Index

Documenting incidents, failures, and lessons learned during infrastructure lab development.

## Purpose

Postmortems serve multiple purposes:
1. **Learning:** Understand what went wrong and why
2. **Prevention:** Identify concrete actions to prevent recurrence  
3. **Knowledge sharing:** Help others avoid similar mistakes
4. **Interview material:** Demonstrate mature incident response thinking

## Format

Each postmortem follows SRE best practices:
- Blameless (focus on systems, not people)
- Actionable (specific prevention items)
- Timely (written soon after incident)
- Reviewed (lessons actually implemented)

## Incidents

### Critical Severity

**001** - [Network Configuration Lockout](001-network-lockout.md)  
*Date: 2025-01-19 | Duration: 8 hours | Impact: Complete system loss*  
Applied untested network config to live system, lost SSH access, recovered via rebuild.

### Medium Severity

**002** - [Firewall IP Restriction Lockout](002-firewall-ip-lockout.md)  
*Date: 2025-01-21 | Duration: 2 hours | Impact: Web UI access blocked*  
Home IP changed, firewall blocked access. Resolved by implementing Tailscale VPN.

**004** - [CoreDNS CrashLoopBackOff](004-coredns-loop-detection.md)  
*Date: 2025-01-24 | Duration: 15 minutes | Impact: DNS broken*  
DNS forwarding loop. Fixed by updating CoreDNS ConfigMap to use public DNS servers.

### Low Severity

**003** - [Kubespray Deployment Duration](003-kubespray-slow-deployment.md)  
*Date: 2025-01-24 | Duration: 2 hours | Impact: Extended deployment time*  
First-time K8s deployment took 2+ hours vs expected 20-30 mins. Deployment succeeded.

---

## Key Lessons Across All Incidents

**Network/Infrastructure:**
- Test changes incrementally
- Have rollback plans
- Monitor during changes
- Document everything

**Deployment/Configuration:**
- Set realistic time expectations
- Validate after deployment
- Use explicit configurations (avoid defaults)
- Check logs immediately

**Mindset:**
- Patience often beats premature intervention
- Systematic debugging > random fixes
- Documentation enables fast recovery
- Learn from every incident

---

## Statistics

**Total Incidents:** 4  
**Critical:** 1 (25%)  
**Medium:** 2 (50%)  
**Low:** 1 (25%)  

**Average Resolution Time:**  
- Critical: 8 hours (001)  
- Medium: 1 hour avg (002, 004)  
- Low: 2+ hours (003 - not really resolution, just completion)

**Success Rate:**  
- 4/4 incidents resolved successfully (100%)  
- 0 incidents required external support
- All resolutions documented

---

## Postmortem Template

For future incidents, use: `postmortems/TEMPLATE.md`

## 008 - Memory OOM Kill (Chaos Test)
**Date:** 2026-01-30  
**Type:** Chaos Engineering  
**Severity:** Medium

Triggered Out of Memory kill by allocating 200MB against 128Mi limit. Pod killed with exit code 137 (OOMKilled), automatically restarted by Kubernetes in 10 seconds. Validated self-healing and multi-replica resilience.

**Key learnings:** Memory limits are hard ceilings (kill, not throttle), multi-replica essential for availability, exit code 137 = OOM kill.

**File:** [008-memory-oom-chaos.md](008-memory-oom-chaos.md)

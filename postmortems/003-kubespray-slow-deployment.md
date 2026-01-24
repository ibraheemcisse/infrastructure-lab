# Postmortem: Kubespray Deployment Excessive Duration

**Incident ID:** 003  
**Date:** 2025-01-24  
**Duration:** 2+ hours (expected: 20-30 minutes)  
**Severity:** Low (deployment succeeded, just slow)  
**Status:** Resolved - deployment completed successfully

---

## Executive Summary

Kubespray Ansible deployment took over 2 hours instead of expected 20-30 minutes. Cluster deployed successfully but slow execution caused concern. Investigation revealed normal behavior for first-time deployment with verbose task execution.

**Impact:** Extended deployment time, user anxiety  
**Root Cause:** First-time deployment + verbose Ansible output + network latency through SSH ProxyJump  
**Resolution:** Deployment completed successfully, cluster operational

---

## Timeline

**17:00** - Started Kubespray ansible-playbook  
**17:30** - Noticed deployment still in "kubernetes/preinstall" phase  
**18:00** - Concerned about duration (expected to be done)  
**18:30** - Checked nodes, discovered kubelet already running  
**19:00** - Verified cluster partially operational (nodes Ready)  
**19:07** - Still running (2+ hours), tasks completing in milliseconds  
**19:15** - Deployment finished, all pods Running  

---

## Root Cause Analysis

### Primary Causes

**1. First-time deployment overhead:**
- Downloading container images (~2-3GB)
- Installing system packages (containerd, dependencies)
- Generating certificates and keys
- Configuring each node independently

**2. Network latency:**
- All commands routed through SSH ProxyJump (laptop → Proxmox → VMs)
- Each Ansible task requires SSH connection setup
- Hundreds of tasks × connection overhead = significant time

**3. Verbose task execution:**
- Kubespray runs extensive validation checks
- Many "ok" tasks (checking if already configured)
- Timestamped output showed tasks completing in milliseconds
- Many tasks, not slow tasks

### Contributing Factors

**Expectations mismatch:**
- Documentation suggested 20-30 minutes
- First deployment on new infrastructure typically slower
- No prior baseline for this specific setup

**Monitoring gaps:**
- Couldn't easily tell if deployment was progressing or stuck
- Terminal output verbose but not clearly indicating progress percentage

---

## What Went Wrong

**Duration exceeded expectations significantly:**
- Expected: 20-30 minutes
- Actual: 2+ hours
- Anxiety about whether deployment was stuck vs. progressing

**Partial cluster visibility:**
- Discovered cluster already partially working at 1.5 hour mark
- Could have checked earlier to reduce anxiety

---

## What Went Right

### Effective Responses

**Didn't panic and cancel:**
- Resisted urge to Ctrl+C and restart
- Let deployment complete
- Result: successful cluster

**Mid-deployment verification:**
- SSH'd to master node during deployment
- Checked kubelet status (Running)
- Confirmed progress was being made

**Cluster deployed successfully:**
- All 3 nodes Ready
- All system pods Running (after DNS fix)
- No corruption or partial state

---

## Lessons Learned

### What Worked

**Patience:**
- Long deployment ≠ failed deployment
- Letting automated process complete paid off

**Incremental verification:**
- Checking node status during deployment
- Confirming services running

**Documentation mindset:**
- Captured the experience for future reference
- Recognized this as learning opportunity

### What Didn't Work

**Unclear progress indicators:**
- Verbose Ansible output hard to parse
- No clear "X% complete" feedback
- Timestamps showed milliseconds (confusing)

**Expectation management:**
- Should have researched first-time deployment duration
- 20-30 minute estimate likely for subsequent deployments

---

## Action Items

### Immediate (For Future Deployments)

- [ ] Set realistic time expectations (first deployment: 2-3 hours)
- [ ] Monitor cluster status in parallel (separate terminal)
- [ ] Check for "changed" vs "ok" tasks (indicates actual work)

### Short-term (Next Infrastructure Project)

- [ ] Research deployment duration before starting
- [ ] Set up progress monitoring (tmux with split terminals)
- [ ] Document baseline deployment times for future reference

### Long-term (Best Practices)

- [ ] Consider pre-built VM templates (reduce first-time setup)
- [ ] Investigate Kubespray performance tuning options
- [ ] Explore faster deployment methods (k3s, microk8s for dev)

---

## Prevention Strategies

### Technical

**For future Kubespray deployments:**
1. Expect 2-3 hours for first deployment
2. Monitor node status in parallel terminal
3. Check for actual "changed" tasks (indicates progress)
4. Verify services starting (kubelet, containerd)

**For faster iterations:**
1. Create VM snapshots after successful deployment
2. Use cloning for subsequent clusters
3. Consider lighter K8s distributions for testing

### Process

**Before starting long-running tasks:**
1. Research expected duration from community
2. Set up monitoring before execution
3. Have parallel terminal ready for verification
4. Document baseline for future comparison

---

## Success Metrics

**Deployment outcome:**
- ✅ Cluster fully operational
- ✅ All nodes healthy
- ✅ All system pods Running
- ✅ Zero failed tasks

**Knowledge gained:**
- Realistic deployment time expectations
- Kubespray execution patterns
- How to verify progress during deployment

---

## Related Incidents

**002** - Firewall IP Lockout (patience paid off there too)

**Common theme:** Sometimes the solution is to let the process complete rather than interrupt

---

## Retrospective

**What this incident taught:**

**Technical:**
- First-time K8s deployment legitimately takes 2+ hours
- SSH ProxyJump adds latency to every Ansible task
- Verbose output ≠ slow execution

**Process:**
- Set realistic expectations before starting
- Monitor in parallel for peace of mind
- Trust automated tools to complete

**Mindset:**
- Anxiety about long tasks is normal
- Verification reduces anxiety
- Patience is a skill

**Impact on project:**
- Zero negative impact (deployment succeeded)
- Gained realistic time estimation
- Now have baseline for future deployments

---

## References

**Documentation:**
- kubespray/KUBESPRAY_SETUP.md
- infrastructure/BUILD_LOG.md

**External:**
- Kubespray documentation (typical deployment times)
- Community reports of 1-3 hour deployments common

---

## Approvals

**Prepared by:** Ibrahim Cisse  
**Date:** 2025-01-24  
**Status:** Complete

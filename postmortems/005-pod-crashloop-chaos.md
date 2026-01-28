# Postmortem: Pod CrashLoopBackOff During Rolling Update (Chaos Test)

**Incident ID:** 005  
**Date:** 2026-01-28  
**Type:** Chaos Engineering Test  
**Severity:** Low  
**Duration:** 6 minutes  
**Status:** Resolved

---

## Summary

Intentionally deployed breaking change to test Kubernetes rolling update safety and crash loop handling. Patched deployment with command that immediately exits (code 1) to simulate corrupted application deployment.

**Impact:** 0 replicas affected (rolling update halted)  
**User Impact:** None (old pods continued serving, new pod never became Ready)  
**Root Cause:** Intentional bad deployment (chaos test)  
**Resolution:** Rollback to previous deployment version

---

## Timeline

**T+0:00** - Patched deployment with `exit 1` command  
**T+0:05** - New pod created (7b5994c99c-96mjr)  
**T+0:10** - Pod crashed, entered CrashLoopBackOff  
**T+0:20** - Restart 1 (immediate)  
**T+0:30** - Restart 2 (10s backoff)  
**T+0:50** - Restart 3 (20s backoff)  
**T+1:30** - Restart 4 (40s backoff)  
**T+2:30** - Restart 5 (60s backoff)  
**T+4:20** - Observed: old pods still healthy, serving traffic  
**T+5:00** - Executed rollback  
**T+6:00** - Crashing pod terminated, cluster healthy  

---

## Problem

**What we did:**
```bash
kubectl patch deployment healthcare-api --patch \
  '{"spec":{"template":{"spec":{"containers":[{"name":"healthcare-api","command":["sh","-c","exit 1"]}]}}}}'
```

**Effect:**
- New ReplicaSet created (7b5994c99c)
- Pod starts, immediately exits with code 1
- Kubernetes detects failure, attempts restart
- Each restart has increasing backoff delay

**Symptoms:**
```
NAME                              READY   STATUS             RESTARTS   
healthcare-api-7b5994c99c-96mjr   0/1     CrashLoopBackOff   5 (62s ago)
healthcare-api-67b4fd9fd8-gs58m   1/1     Running            0
healthcare-api-67b4fd9fd8-np6px   1/1     Running            0
```

---

## Investigation

**Pod status check:**
```bash
kubectl get pods -l app=healthcare-api
# Result: 1 crashing, 2 healthy
```

**Restart count:**
```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase
# Result: Crashing pod at 5 restarts, old pods at 0
```

**Logs check:**
```bash
kubectl logs healthcare-api-7b5994c99c-96mjr
# Result: Empty (exits immediately, no output)
```

**Service endpoints:**
```bash
kubectl get endpoints healthcare-api
# Result: 10.233.71.8:8000, 10.233.75.8:8000
# Only old healthy pods, NOT the crashing one
```

**Root cause:** Container exits immediately with code 1

---

## Impact

### **System Impact**
- 1 pod in crash loop (resource waste)
- Rolling update halted (stuck waiting for new pod)
- Old ReplicaSet remained active (2 healthy pods)

### **User Impact**
- **ZERO** - This is the key finding!
- Service endpoints excluded crashing pod
- Traffic only routed to healthy pods
- No requests failed
- No latency increase
- No downtime

### **Why Zero Impact?**

**Kubernetes safety mechanisms:**

1. **Rolling Update Strategy:**
   - Creates new pod BEFORE terminating old ones
   - Waits for new pod to pass readiness checks
   - **Never terminates old pods if new ones aren't Ready**
   - Default: maxUnavailable=25%, maxSurge=25%

2. **Health Checks:**
   - Readiness probe: GET /health on port 8000
   - Pod must pass probe to receive traffic
   - Crashing pod NEVER passed readiness check
   - Never added to Service endpoints

3. **Service Load Balancer:**
   - Only routes to endpoints list
   - Automatically excludes pods not Ready
   - Maintained traffic to 2 healthy pods

**Result:** Bad deployment was isolated, never affected users

---

## Resolution

**Immediate rollback:**
```bash
kubectl rollout undo deployment/healthcare-api
```

**What happened:**
1. Kubernetes scaled up old ReplicaSet (already at 2 replicas - no action needed)
2. Kubernetes scaled down new ReplicaSet (terminated crashing pod)
3. Service endpoints unchanged (already correct)
4. Deployment returned to stable state

**Recovery time:** <10 seconds

**Verification:**
```bash
kubectl get pods -l app=healthcare-api
# Result: 2 healthy pods from old ReplicaSet
```

---

## What Kubernetes Did Right

### **Rolling Update Safety**

**Problem prevented:**
- Old pods NOT terminated during update
- Even though rolling update started, it detected failure
- Kept old version running (implicit rollback protection)

**Without this safety:**
- All pods could have been replaced
- Service would be down during crash loops
- Zero-downtime deployment would fail

### **Exponential Backoff**

**Restart attempts:**
```
Restart 1: Immediate
Restart 2: 10 seconds delay
Restart 3: 20 seconds delay
Restart 4: 40 seconds delay
Restart 5: 60 seconds delay
(continues up to 5 minutes max)
```

**Why this matters:**
- Prevents resource exhaustion from rapid restarts
- Gives time for transient issues to resolve
- Doesn't give up (keeps trying indefinitely)

### **Health Check Enforcement**

**Readiness probe configuration:**
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Effect:**
- Pod checked every 5 seconds
- Never passed (pod crashed before probe could run)
- Never added to Service endpoints
- Traffic protected from broken pods

---

## Lessons Learned

### **What This Validates**

**✅ Rolling updates are safe:**
- Bad deployments don't take down healthy pods
- Old version keeps running if new version fails
- Zero-downtime even during failed updates

**✅ Health checks work:**
- Crashing pods never receive traffic
- Service automatically routes around failures
- No manual intervention needed

**✅ Exponential backoff prevents thrashing:**
- System doesn't waste resources on rapid restarts
- Backoff gives time for investigation
- System remains responsive (not overwhelmed with restart attempts)

**✅ Observability clear:**
- Pod status clearly shows CrashLoopBackOff
- Restart count visible and incrementing
- Easy to identify problem pod
- Logs and events provide debugging info

**✅ Recovery simple:**
- Single command rollback
- Automatic cleanup of failed pods
- No manual pod deletion needed

### **Production Implications**

**This test proves:**
1. Can deploy with confidence (bad deploys won't break production)
2. CI/CD can push automatically (rolling update provides safety net)
3. Health checks are essential (must be configured correctly)
4. Rollback is viable recovery strategy (fast and clean)

**Real-world scenarios this protects against:**
- Bad Docker image pushed to registry
- Missing environment variables in new deployment
- Incompatible dependency versions
- Configuration errors in new code
- Database migration failures causing startup crashes

---

## Action Items

### **Monitoring (Immediate)**

- [x] Verify Grafana shows pod restart spikes (confirmed)
- [ ] Configure Alertmanager alert:
```yaml
  alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  for: 5m
  annotations:
    summary: "Pod {{ $labels.pod }} is crash looping"
```

### **Documentation (Short-term)**

- [x] Document rollback procedure in runbook
- [ ] Create troubleshooting guide for CrashLoopBackOff
- [ ] Add health check best practices to onboarding docs

### **Testing (Long-term)**

- [ ] Add automated health check validation in CI
- [ ] Test rollback procedure regularly (every quarter)
- [ ] Document other failure modes to chaos test

---

## Observability

**Grafana during incident:**
- Pod restart count: 0 → 5 over 4 minutes
- CPU: Spikes on each restart attempt
- Memory: Low (exits before allocating much)
- Network: Zero (pod never Ready to receive traffic)

**Kubernetes events:**
```
Warning  BackOff    Pod backing off restarting failed container
Warning  Failed     Container exited with code 1
Normal   Created    Created container healthcare-api
Normal   Started    Started container healthcare-api
Normal   Pulled     Successfully pulled image
```

---

## Related Documentation

- Kubernetes Deployment Strategies: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
- Pod Lifecycle: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- Configure Liveness, Readiness Probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

---

## Chaos Test Success Criteria

**✅ All criteria met:**

1. **Failure injected successfully** - Pod crashed as expected
2. **System self-healed** - Kubernetes attempted restarts with backoff
3. **User traffic protected** - Service excluded crashing pod
4. **Recovery validated** - Rollback worked cleanly
5. **Observable** - Clear status in kubectl and Grafana
6. **Documented** - Full postmortem with learnings

**Conclusion:** Kubernetes rolling update safety mechanisms work as designed. Production deployments are protected from bad releases.

---

**Test conducted by:** Ibrahim Cisse  
**Date:** 2026-01-28  
**Status:** Complete ✅

# Postmortem: Memory OOM Kill (Chaos Test)

**Incident ID:** 008  
**Date:** 2026-01-30  
**Type:** Chaos Engineering Test  
**Severity:** Medium  
**Duration:** 10 seconds  
**Status:** Resolved

---

## Summary

Simulated memory exhaustion by intentionally allocating memory beyond container limits (200MB vs 128Mi limit) to trigger kernel OOM kill. Validated Kubernetes self-healing and restart behavior.

**Impact:** Single pod OOMKilled and restarted  
**User Impact:** Minimal (second replica continued serving traffic)  
**Root Cause:** Intentional memory allocation exceeding limits  
**Resolution:** Kubernetes automatically restarted pod

---

## Timeline

**T+0:00** - Set memory limit to 128Mi (low for testing)  
**T+1:00** - Rolled out pods with new limits  
**T+2:00** - Started memory stress test (target: 200MB)  
**T+2:05** - Memory allocation progressing: 0MB → 10MB → 20MB...  
**T+2:11** - Reached 60MB allocated  
**T+2:12** - **Kernel OOMKiller invoked** (hit 128Mi limit)  
**T+2:12** - Container killed with exit code 137  
**T+2:13** - Kubernetes detected container death  
**T+2:14** - New container started (restart count: 1)  
**T+2:20** - Pod passed health checks  
**T+2:22** - Service endpoints updated  
**T+2:23** - **Fully recovered**  

**Total downtime for affected pod: 10 seconds**

---

## Problem

**What we did:**
```bash
# Set very low memory limit
resources:
  limits:
    memory: "128Mi"

# Allocate more memory than limit
python memory-stress.py 200  # Tries to allocate 200MB
```

**Memory allocation script:**
```python
def allocate_memory(mb):
    data = []
    for i in range(mb):
        chunk = 'x' * (1024 * 1024)  # 1MB chunks
        data.append(chunk)
        print(f"Allocated {i}MB")
    return data
```

**Expected behavior:**
- Container allocates memory successfully up to 128Mi
- Next allocation attempt exceeds limit
- Kernel OOMKiller terminates process immediately
- Container exits with code 137 (128 + 9 SIGKILL)
- Kubernetes restarts container automatically

---

## Investigation

**Terminal output:**
```
Starting memory allocation: 200MB target...
Allocated 0MB
Allocated 10MB
Allocated 20MB
Allocated 30MB
Allocated 40MB
Allocated 50MB
Allocated 60MB
command terminated with exit code 137  ← OOMKilled!
```

**Pod status observed:**
```
NAME                              READY   STATUS      RESTARTS
healthcare-api-5b9b79d8d9-hqqg7   0/1     OOMKilled   0
healthcare-api-5b9b79d8d9-hqqg7   0/1     Running     1 (1s ago)
healthcare-api-5b9b79d8d9-hqqg7   1/1     Running     1 (9s ago)
```

**Evidence collected:**
```bash
# Exit code
kubectl get pod $POD -o jsonpath='{...exitCode}'
# Result: 137

# Termination reason
kubectl get pod $POD -o jsonpath='{...reason}'
# Result: OOMKilled

# Restart count
kubectl get pods -l app=healthcare-api
# Result: RESTARTS = 1

# Last state
kubectl describe pod $POD | grep "Last State" -A10
# Result:
#   Reason:    OOMKilled
#   Exit Code: 137
#   Started:   Fri, 30 Jan 2026 10:41:05
#   Finished:  Fri, 30 Jan 2026 10:48:15
```

---

## How OOMKiller Works

### **Memory Limit Enforcement**

**Linux cgroup limits:**
```
container memory limit = 128Mi (134,217,728 bytes)
cgroup: memory.limit_in_bytes = 134217728
```

**Process behavior:**
1. Application allocates memory (malloc/mmap)
2. Kernel tracks usage in cgroup
3. When usage hits limit:
   - Kernel invokes OOMKiller
   - Selects process with highest OOM score
   - Sends SIGKILL (signal 9)
   - No graceful shutdown
   - Process terminated immediately

### **Why Exit Code 137?**

**Exit code formula:**
```
137 = 128 + signal_number
137 = 128 + 9 (SIGKILL)
```

**Common exit codes:**
- **0** = Clean exit
- **1** = Application error
- **137** = Killed by OOMKiller (128 + 9)
- **143** = Terminated by SIGTERM (128 + 15)

### **OOM Score**

**How kernel chooses victim:**
```bash
# Check OOM score of process
cat /proc/<pid>/oom_score

# Higher score = more likely to be killed
# Score based on:
# - Memory usage (more = higher score)
# - Process age (newer = higher score)
# - Nice value
```

**In container:**
- Usually only one main process
- That process gets killed
- Container exits

---

## Grafana Observations

**Memory usage before OOM:**
- Baseline: ~55 MiB
- During stress: Climbing toward 128 MiB
- At kill: Hit ceiling (100% of limit)
- After restart: Dropped to ~35 MiB (fresh container)

**Key metrics:**
```
Memory Utilization (from requests): 40.5%
Memory Utilization (from limits):   20.2%
Memory Usage: 91.7 MiB → 0 (killed) → 35 MiB (new)
Memory Limit: 128 MiB (hard ceiling)
```

**Graph pattern:**
```
128Mi ┼──────────────────────────┐ LIMIT
      │                          │
 100  │                     ╭────┤ OOM!
      │                   ╭─╯    │
  75  │               ╭───╯      │
      │           ╭───╯          │
  50  │      ╭────╯              │
      │  ╭───╯                   │
  25  ├──╯                       │
      │                          ▼ Restart
   0  └──────────────────────────┴────────
      0s  10s  20s  30s  40s  50s  60s
```

---

## Impact Analysis

### **Affected Pod**

**What happened:**
- Memory allocation reached ~60-70 MB
- Hit 128Mi limit
- OOMKiller invoked
- Process killed (SIGKILL)
- Container exited (code 137)
- Kubernetes detected exit
- Restarted container
- New process started clean
- Health checks passed
- Back in service

**Recovery time: 10 seconds**

### **Unaffected Pod**

**Second replica behavior:**
- Continued running normally
- Memory usage stable (~55 MiB)
- Served all traffic during incident
- No impact from sibling pod failure

**This is why we run multiple replicas!**

### **User Impact**

**Service availability:**
- Requests to dying pod: Failed (~10 seconds worth)
- Requests to healthy pod: Success (100%)
- Load balancer: Automatically excluded dying pod
- Total user-visible failures: Minimal

**Why minimal impact:**
- Service had 2 replicas (50% capacity maintained)
- Load balancer health checks detected failure
- Traffic routed to healthy pod
- Automatic failover (no manual intervention)

---

## Real Production Scenarios

**OOM is common in production. Typical causes:**

### **1. Memory Leak**
```python
# Bad code example
cache = {}  # Global dict
def handle_request(data):
    cache[data.id] = data  # Never cleared!
    # Memory grows forever
```

**Result:**
- Gradual memory increase
- Eventually hits limit
- OOMKilled
- Restarts (leak starts over)
- Repeat cycle

**Solution:** Fix leak, or increase limit as temporary workaround

### **2. Traffic Spike**
```python
# Each request allocates memory
def process_request():
    data = load_large_dataset()  # 10MB
    results = process(data)       # 20MB
    return results
```

**Normal:** 10 requests/sec = 300MB memory (fine)  
**Spike:** 100 requests/sec = 3GB memory (OOM!)

**Solution:** 
- Increase limits for peak load
- Add autoscaling (HPA)
- Implement request throttling

### **3. Wrong Limits**
```yaml
# Application actually needs 512Mi
resources:
  limits:
    memory: "128Mi"  # Too low!
```

**Result:** Constant OOMKilling during normal operation

**Solution:** Right-size limits based on actual usage

### **4. Data Processing**
```python
# Loading entire dataset into memory
def process_csv():
    data = pd.read_csv('large_file.csv')  # 2GB file
    # OOMKilled if limit < 2GB
```

**Solution:**
- Stream processing (chunks)
- Increase limits
- Process externally (not in API pod)

---

## Prevention Strategies

### **Right-Size Memory Limits**

**Methodology:**
```bash
# 1. Monitor actual usage over time
kubectl top pod <pod> --containers

# 2. Find 95th percentile
# Example: 95th percentile = 200Mi

# 3. Set limit with safety margin
limit = 95th_percentile × 1.5
limit = 200Mi × 1.5 = 300Mi
```

**Rule of thumb:**
- **Requests:** Average usage
- **Limits:** Peak usage × 1.5 safety margin

### **Monitor Memory Trends**

**Alerting strategy:**
```yaml
# Alert 1: High memory usage
alert: HighMemoryUsage
expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.80
for: 5m
annotations:
  summary: "Pod using >80% memory for 5 minutes"
  action: "Check for memory leak or increase limits"

# Alert 2: Frequent OOMKills
alert: FrequentOOMKills
expr: rate(kube_pod_container_status_restarts_total{reason="OOMKilled"}[15m]) > 0
annotations:
  summary: "Pod being OOMKilled repeatedly"
  action: "Fix memory leak or increase limits immediately"
```

### **Memory Profiling**

**For Python applications:**
```python
# Add memory profiling
import tracemalloc

tracemalloc.start()

# ... application code ...

# Take snapshot
snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')

# Log top 10 memory consumers
for stat in top_stats[:10]:
    print(stat)
```

**For production:**
- Use profilers: py-spy, memory_profiler, heaptrack
- Track allocation patterns
- Identify leaks before production deployment

### **Graceful Degradation**

**Application-level protection:**
```python
import psutil

def check_memory_pressure():
    """Check if we're approaching limits"""
    process = psutil.Process()
    memory_percent = process.memory_percent()
    
    if memory_percent > 80:
        # Clear caches
        clear_cache()
        # Reject new requests
        raise ServiceUnavailable("Memory pressure high")
    
    return True
```

---

## Lessons Learned

### **OOMKiller Has No Mercy**

**Key differences from CPU throttling:**

| Resource | Behavior When Limit Hit | Recovery |
|----------|------------------------|----------|
| **CPU** | Throttle (slow down) | Automatic (just slower) |
| **Memory** | Kill (immediate death) | Restart (data lost) |

**Why different:**
- CPU is compressible (can slow down)
- Memory is incompressible (can't "slow down" memory)
- Exceeding memory = system instability
- Only option: Kill process

**Implications:**
- No graceful shutdown
- No cleanup possible
- All in-memory state lost
- Connections dropped immediately

### **Multi-Replica is Essential**

**What if single replica?**
- OOMKilled → entire service down
- Users see errors
- Manual intervention needed

**With 2+ replicas:**
- One OOMKilled → others serve traffic
- Brief disruption only
- Automatic recovery
- No manual intervention

**Production recommendation:** Minimum 3 replicas for critical services

### **Memory Limits Are Per-Container**

**Common mistake:**
```yaml
# "My pod can use 256Mi total"
# WRONG - this is per-container!
resources:
  limits:
    memory: "256Mi"
```

**Reality:**
- Pod with 1 container: 256Mi total
- Pod with 3 containers: 768Mi total (256Mi × 3)
- Limits enforced individually

**Example - sidecar container:**
```yaml
containers:
- name: app
  resources:
    limits:
      memory: "512Mi"
- name: istio-proxy
  resources:
    limits:
      memory: "128Mi"
# Total pod memory: 640Mi
```

### **Kubernetes Did Its Job**

**Correct behaviors observed:**
- ✅ Enforced memory limit (killed at 128Mi)
- ✅ Detected container death immediately
- ✅ Restarted container automatically
- ✅ Health checks prevented traffic to dying pod
- ✅ Load balancer excluded unhealthy endpoint
- ✅ Service recovered without manual intervention

**The system worked as designed!**

---

## Action Items

### **Immediate**
- [x] Chaos test completed successfully
- [x] OOM behavior validated
- [x] Kubernetes self-healing confirmed
- [x] Evidence collected (exit code, reason, Grafana)
- [ ] Restore normal memory limits (512Mi) ← Do this now

### **Short-term**
- [ ] Set up memory usage alerts (>80% for 5 min)
- [ ] Set up OOMKill alerts (immediate notification)
- [ ] Baseline normal memory usage for all services
- [ ] Right-size limits based on actual usage patterns
- [ ] Document memory requirements in service README

### **Long-term**
- [ ] Implement memory profiling in development
- [ ] Load test to determine peak memory needs
- [ ] Add memory metrics to SLIs/SLOs
- [ ] Create runbook for OOM incidents
- [ ] Consider Horizontal Pod Autoscaling based on memory

---

## Chaos Test Success Criteria

**✅ All criteria met:**

1. Successfully triggered OOM condition
2. Container killed with exit code 137
3. OOMKilled reason confirmed
4. Kubernetes auto-restarted pod (restart count: 1)
5. Service remained available (second replica)
6. Observable in Grafana (memory spike before kill)
7. Recovery automatic (no manual intervention)
8. Recovery time acceptable (<30 seconds)
9. Documented behavior and lessons

**Result:** OOM handling validated, multi-replica value proven

---

## Interview Talking Points

**What this test demonstrates:**

> "I stress-tested memory limits by intentionally allocating memory beyond container limits. At around 60-70MB allocated against a 128Mi limit, the Linux kernel's OOMKiller terminated the process immediately with SIGKILL - no grace period, no cleanup opportunity. The container exited with code 137, which is 128 plus signal 9 (SIGKILL).
>
> Kubernetes detected the exit within seconds and automatically restarted the container. The whole recovery took about 10 seconds. Because I had 2 replicas, the service stayed available - the load balancer's health checks detected the dying pod and routed all traffic to the healthy replica during recovery.
>
> This taught me that memory limits are hard ceilings enforced by the kernel, not Kubernetes. Unlike CPU which gets throttled, exceeding memory results in immediate termination. This is why multi-replica deployments are essential - they provide resilience during these failure modes. It also showed me the importance of right-sizing memory limits based on actual usage patterns, not guessing."

**Production relevance:**

> "In production, OOM kills are common - usually from memory leaks, traffic spikes, or misconfigured limits. The key is having proper monitoring to catch high memory usage before OOM, and having enough replicas to maintain service during restarts. I'd also set up alerts for both high memory usage (preventive) and OOMKills (reactive) to catch issues before they impact users."

---

**Postmortem created:** 2026-01-30  
**Reviewed by:** Ibrahim Cisse  
**Status:** Complete ✅

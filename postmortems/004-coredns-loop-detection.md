# Postmortem: CoreDNS CrashLoopBackOff (DNS Loop)

**Incident ID:** 004  
**Date:** 2025-01-24  
**Duration:** ~15 minutes (discovery to resolution)  
**Severity:** Medium (cluster functional, DNS broken)  
**Status:** Resolved - CoreDNS healthy

---

## Executive Summary

After successful Kubernetes cluster deployment, CoreDNS pods were in CrashLoopBackOff state. Investigation revealed DNS forwarding loop where CoreDNS was forwarding queries to itself. Fixed by changing forward directive to use public DNS servers (8.8.8.8, 8.8.4.4).

**Impact:** DNS resolution unavailable in cluster (pods couldn't resolve domain names)  
**Root Cause:** CoreDNS ConfigMap forwarding to `/etc/resolv.conf` which pointed back to CoreDNS  
**Resolution:** Updated CoreDNS ConfigMap to forward to public DNS servers

---

## Timeline

**19:15** - Kubespray deployment completed  
**19:16** - Verified cluster: 3 nodes Ready  
**19:17** - **INCIDENT START:** Noticed CoreDNS pods in CrashLoopBackOff  
**19:18** - Checked pod logs: "Loop detected for zone ."  
**19:20** - Researched CoreDNS loop detection  
**19:22** - Identified root cause: `/etc/resolv.conf` forwarding loop  
**19:25** - Edited CoreDNS ConfigMap, changed forward directive  
**19:27** - Deleted CoreDNS pods to trigger restart  
**19:28** - **INCIDENT END:** Both CoreDNS pods Running/Ready  
**19:30** - Verified DNS resolution working  

---

## Root Cause Analysis

### Primary Cause

**DNS forwarding loop:**
```
Pod → CoreDNS (10.233.0.3) → forward to /etc/resolv.conf
                              ↓
                         nameserver 127.0.0.1
                              ↓
                         CoreDNS (localhost:53)
                              ↓
                         [INFINITE LOOP]
```

**CoreDNS configuration:**
```yaml
forward . /etc/resolv.conf  # This was the problem
```

**Node's /etc/resolv.conf:**
```
nameserver 127.0.0.1  # Points back to local CoreDNS
```

**Result:** CoreDNS detected loop and crashed

### Contributing Factors

**Kubespray default configuration:**
- Default CoreDNS ConfigMap uses `/etc/resolv.conf`
- Works in most setups (external DNS available)
- Broke in NAT setup where nodes use local DNS

**NAT network configuration:**
- VMs on private network (10.0.0.0/24)
- DNS configured during Ubuntu install (8.8.8.8, 8.8.4.4)
- But something reset resolv.conf to 127.0.0.1

---

## What Went Wrong

**CoreDNS loop detection triggered:**
```
[FATAL] plugin/loop: Loop (127.0.0.1:35870 -> :53) detected for zone "."
```

**Impact:**
- Pods couldn't resolve external domain names
- Services could only communicate via IP
- Application deployments would fail DNS lookups

**Why not caught earlier:**
- Kubespray completed successfully (CoreDNS deployed)
- Crash happened after deployment
- Not immediately obvious from cluster status

---

## What Went Right

### Effective Responses

**Quick diagnosis:**
- Checked pod logs immediately
- Error message clear: "Loop detected"
- URL provided in error led to documentation

**Correct fix identified:**
- CoreDNS documentation explained loop detection
- Common issue with known solutions
- Applied fix within minutes

**Minimal downtime:**
- Cluster operational (just DNS broken)
- Fix took <10 minutes
- No data loss or state corruption

---

## Lessons Learned

### What Worked

**Systematic debugging:**
1. Observed pod status (CrashLoopBackOff)
2. Checked logs (`kubectl logs`)
3. Read error message carefully
4. Followed documentation link
5. Applied recommended fix

**Understanding the error:**
- "Loop detected" was self-explanatory
- Error message included helpful URL
- CoreDNS documentation had exact solution

**Kubernetes self-healing:**
- Deleting pods triggered automatic restart
- New pods picked up new configuration
- No manual intervention beyond ConfigMap edit

### What Didn't Work

**Default Kubespray configuration:**
- Forward to `/etc/resolv.conf` not safe for all environments
- Should have validated DNS setup before deployment
- NAT environment requires explicit DNS servers

---

## Action Items

### Immediate (Completed)

- [x] Updated CoreDNS ConfigMap to use 8.8.8.8, 8.8.4.4
- [x] Restarted CoreDNS pods
- [x] Verified DNS resolution working

### Short-term (Future Deployments)

- [ ] Pre-configure CoreDNS forward directive in Kubespray
- [ ] Add DNS validation to deployment checklist
- [ ] Document DNS configuration in setup guide

### Long-term (Best Practices)

- [ ] Always specify explicit DNS servers (never rely on /etc/resolv.conf)
- [ ] Test DNS resolution immediately after deployment
- [ ] Add automated DNS health checks

---

## Prevention Strategies

### Technical Controls

**For CoreDNS configuration:**
```yaml
# Always use explicit DNS servers
forward . 8.8.8.8 8.8.4.4 1.1.1.1

# Never use /etc/resolv.conf in uncertain environments
# forward . /etc/resolv.conf  # RISKY
```

**For Kubespray deployments:**
```yaml
# Set in inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
upstream_dns_servers:
  - 8.8.8.8
  - 8.8.4.4
  - 1.1.1.1
```

**Validation after deployment:**
```bash
# Test DNS from any pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Process Controls

**Post-deployment checklist:**
1. ✅ All nodes Ready
2. ✅ All system pods Running (check for CrashLoopBackOff)
3. ✅ DNS resolution working (test with nslookup)
4. ✅ Pod-to-pod communication
5. ✅ External connectivity

---

## Success Metrics

**Resolution:**
- Time to diagnose: 5 minutes
- Time to fix: 3 minutes
- Time to verify: 2 minutes
- Total: 10 minutes (very fast)

**Outcome:**
- ✅ CoreDNS 2/2 pods Running
- ✅ DNS resolution working
- ✅ Cluster 100% healthy

---

## Technical Details

### Error Message
```
[FATAL] plugin/loop: Loop (127.0.0.1:35870 -> :53) detected for zone "."
Query: "HINFO 3242903750542532123.8976191281226897555."
```

### Fix Applied

**Before:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        forward . /etc/resolv.conf  # PROBLEM
    }
```

**After:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        forward . 8.8.8.8 8.8.4.4  # FIXED
    }
```

### Verification
```bash
# CoreDNS pods healthy
$ kubectl get pods -n kube-system -l k8s-app=kube-dns
NAME                       READY   STATUS    RESTARTS   AGE
coredns-77f7cc69db-gq8vz   1/1     Running   0          2m
coredns-77f7cc69db-mtww2   1/1     Running   0          2m

# DNS working
$ kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup google.com
Server:    10.233.0.3
Address 1: 10.233.0.3 kube-dns.kube-system.svc.cluster.local
Name:      google.com
Address 1: 142.250.185.46
```

---

## Related Incidents

**003** - Kubespray Slow Deployment (same session, different issue)

**Common theme:** First-time K8s deployment reveals configuration issues

---

## Retrospective

**What this incident taught:**

**Technical:**
- DNS forwarding loops are common in K8s
- `/etc/resolv.conf` is unreliable in containerized environments
- Always use explicit DNS servers

**Debugging:**
- Pod logs are the first place to look
- Error messages often include solutions
- CoreDNS documentation is excellent

**Process:**
- Post-deployment validation catches issues early
- Having systematic debugging approach helps
- Quick fixes prevent long troubleshooting

**Impact on project:**
- Minimal (caught and fixed quickly)
- Cluster never served traffic (no user impact)
- Good learning experience

---

## References

**Documentation:**
- CoreDNS loop detection: https://coredns.io/plugins/loop#troubleshooting
- Kubespray DNS configuration
- kubernetes/README.md (cluster status)

---

## Approvals

**Prepared by:** Ibrahim Cisse  
**Date:** 2025-01-24  
**Status:** Complete

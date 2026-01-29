# Postmortem: Node Failure with Local Storage (Chaos Test)

**Incident ID:** 006  
**Date:** 2026-01-28  
**Type:** Chaos Engineering Test  
**Severity:** Critical  
**Duration:** ~25 hours  
**Status:** Resolved

---

## Summary

Simulated node failure by shutting down node2 to test Kubernetes resilience and pod rescheduling. Discovered critical architectural flaw: PostgreSQL using local-path storage created node affinity, preventing pod rescheduling to healthy nodes. This resulted in 25-hour database unavailability and cascading API failures.

**Impact:** Complete service outage (database unreachable)  
**User Impact:** 100% - all API requests failed  
**Root Cause:** Local storage binding database to single node  
**Resolution:** Manually restarted failed node from hypervisor

---

## Timeline

**Day 1 - T+0:00** - Initiated chaos test: `shutdown -h now` on node2  
**Day 1 - T+0:40** - node2 marked NotReady by control plane  
**Day 1 - T+5:00** - Kubernetes began evicting pods from node2  
**Day 1 - T+5:30** - Pods stuck in Terminating state (node unreachable)  
**Day 1 - T+6:00** - New API pod created (cz8qr), immediately crashed  
**Day 1 - T+6:10** - Diagnosed: Database connection failed  
**Day 1 - T+7:00** - Force deleted Terminating pods  
**Day 1 - T+7:30** - PostgreSQL pod stayed Pending (PV on dead node)  
**Day 1 - T+8:00** - API pods continued crashing (24 restarts over 25 hours)  
**Day 2 - T+25:00** - Restarted node2 from Proxmox UI  
**Day 2 - T+25:05** - node2 rejoined cluster (Ready)  
**Day 2 - T+25:10** - New postgres pod scheduled on node2  
**Day 2 - T+25:15** - PostgreSQL started, data intact  
**Day 2 - T+25:20** - API pods reconnected successfully  
**Day 2 - T+25:30** - Service fully restored  

---

## Problem

**What happened:**

Killed node2 (which hosted PostgreSQL) to test node failure recovery. Expected Kubernetes to:
1. Detect node failure ✅
2. Evict pods from dead node ✅
3. Reschedule pods on healthy nodes ❌ FAILED

**Why rescheduling failed:**

PostgreSQL pod used PersistentVolume with local-path storage:
```yaml
storageClassName: local-path
nodeAffinity:
  required:
    matchExpressions:
    - key: kubernetes.io/hostname
      operator: In
      values:
      - node2  # ← BOUND TO NODE2
```

**PersistentVolume location:**
```
/data/postgres on node2 disk
```

**Result:**
- PV physically on node2
- Pod can ONLY run on node2 (node affinity)
- When node2 died, pod couldn't be scheduled elsewhere
- Kubernetes correctly refused to create new pod (would lose data)

**Cascading failure:**
```
node2 dies
    ↓
PostgreSQL unreachable (PV on dead node)
    ↓
New API pods try to connect
    ↓
Connection refused (postgres:5432)
    ↓
API pods crash
    ↓
CrashLoopBackOff (24 restarts over 25 hours)
```

---

## Investigation

**Commands used:**
```bash
# Check node status
kubectl get nodes
# Result: node2 NotReady

# Check pod status
kubectl get pods -o wide
# Result: postgres Terminating on node2

# Check new pod crash
kubectl logs healthcare-api-67b4fd9fd8-cz8qr
# Result: sqlalchemy.exc.OperationalError: Connection refused

# Check postgres pod events
kubectl describe pod postgres-84fd6557b7-h928h
# Result: Node had condition: NetworkUnavailable

# Check PVC/PV
kubectl get pvc postgres-pvc
kubectl get pv postgres-pv -o yaml
# Result: PV has nodeAffinity to node2

# Force delete stuck pods
kubectl delete pod postgres-84fd6557b7-h928h --force --grace-period=0

# Try to reschedule postgres
kubectl get pods -l app=postgres
# Result: Stayed Pending (couldn't schedule)
```

**Root cause identified:** Local storage + node affinity = single point of failure

---

## Impact

### **Database Unavailability**
- PostgreSQL completely unreachable for 25 hours
- No way to access data (physically on dead node)
- Kubernetes correctly prevented pod creation (would lose data)

### **API Service Outage**
- All API requests failed (500 errors)
- New pod created: crashed 24 times over 25 hours
- Existing pod: couldn't connect to database
- Users saw: "Database connection failed"

### **User Impact**
- 100% service unavailability
- All CRUD operations failed
- Data reads: impossible
- Data writes: blocked

### **Why This Is Critical**

**In production:**
- 25-hour outage = $X00,000s in lost revenue
- Customer churn
- SLA violations
- Potential data loss if node disk corrupted

---

## Resolution

### **Immediate Action**

Manually restarted node2 from Proxmox hypervisor UI:
1. Logged into Proxmox web interface
2. Located VM: node2 (ID: 102)
3. Clicked "Start"
4. Node booted, kubelet started
5. Node rejoined cluster

### **Automatic Recovery (After Node Return)**

Kubernetes automatically:
1. Detected node2 Ready
2. Created new postgres pod (postgres-84fd6557b7-2tdhl)
3. Pod scheduled on node2 (PV available)
4. PostgreSQL started successfully
5. Data intact (no corruption)
6. API pods reconnected
7. Service restored

### **Verification**
```bash
# Check all pods running
kubectl get pods -o wide
# Result: All Running

# Verify data persistence
kubectl exec -it deployment/postgres -- psql -U healthcare_user -d healthcare -c "SELECT * FROM patients;"
# Result: Alice and Bob still present ✅

# Test API
curl http://localhost:8000/patients
# Result: Returns patient list ✅
```

**Time to recovery:** 5 minutes (from node restart to service operational)

---

## Root Cause Analysis

### **Architectural Flaw**

**Local-path storage design:**
```
PV → Bound to node2 disk (/data/postgres)
    ↓
Pod → Must run on node2 (node affinity)
    ↓
node2 dies → Pod can't move → Data unreachable
```

**Why this happened:**

When we deployed PostgreSQL, we created:
1. PersistentVolume pointing to node2:/data/postgres
2. StorageClass: local-path (node-local storage)
3. PersistentVolumeClaim: Bound to that PV

**Result:** Hard dependency on single node

### **Why Kubernetes Behaved Correctly**

Kubernetes DID NOT reschedule postgres to node3 because:
- PV exists on node2 disk only
- Creating new pod on node3 = new empty database
- Would lose all data (Alice, Bob, appointments)
- Correctly waited for node2 recovery

**This is GOOD behavior** - prevented data loss

### **The Real Problem**

**Architecture, not Kubernetes:**
- Should use distributed storage
- Should use network-attached storage
- Should use cloud PVs (EBS, GCE PD)
- OR use external managed database

---

## What Went Wrong

### **Technical Decisions**

**Decision:** Use local-path storage for simplicity
**Consequence:** Created single point of failure

**Decision:** Deploy stateful workload (database) in cluster
**Consequence:** Subject to node failures

**Decision:** Use dedicated node for storage
**Consequence:** Node failure = data unavailable

### **Missing Safeguards**

- No distributed storage (Ceph, Longhorn, NFS)
- No database replication (postgres primary/replica)
- No backup/restore automation
- No documented recovery procedure
- No alerts for node failure + database down

---

## What Went Right

### **Kubernetes Safety**

✅ Did NOT create new postgres pod on node3 (would lose data)  
✅ Correctly kept pod Pending until node recovered  
✅ Preserved data when node returned  
✅ Automatic recovery after node restart  

### **Data Persistence**

✅ Data survived node death (on disk)  
✅ Data survived node restart  
✅ Data survived pod recreation  
✅ No corruption (postgres clean shutdown)  

### **Observability**

✅ Clear pod status (Terminating, Pending, CrashLoopBackOff)  
✅ Logs showed connection failures  
✅ Events explained why pod couldn't schedule  
✅ PV/PVC status indicated node affinity issue  

---

## Lessons Learned

### **Storage Architecture**

**For stateful workloads:**

❌ **Local-path storage**
- Ties pod to single node
- Node failure = data unavailable
- Manual recovery required

✅ **Distributed storage (Ceph, Longhorn)**
- Data replicated across nodes
- Pod can move to any node
- Automatic failover

✅ **Cloud PVs (EBS, Azure Disk, GCE PD)**
- Detaches from dead node
- Reattaches to new node
- Kubernetes handles automatically

✅ **External database (AWS RDS, Cloud SQL)**
- Outside cluster
- Managed backups
- Multi-AZ replication
- No Kubernetes dependency

### **Database Strategy**

**For production:**

**Option 1: Distributed storage**
```yaml
storageClassName: ceph-rbd  # or longhorn
# Pod can run on any node
# Data replicated across cluster
```

**Option 2: StatefulSet with replication**
```yaml
replicas: 3
# Primary + 2 replicas
# Automatic failover
# Read scalability
```

**Option 3: External managed service**
```yaml
DATABASE_URL: postgresql://rds.amazonaws.com:5432/db
# Outside cluster
# Provider handles HA
# No node dependency
```

### **Recovery Planning**

**Automated recovery procedures:**
- Document node restart process
- Automate node recovery (if possible)
- Set up monitoring alerts
- Test recovery regularly

---

## Action Items

### **Immediate (This Lab)**

- [x] Documented local storage limitation
- [x] Tested node failure scenario
- [x] Verified data persistence after recovery
- [ ] Add "Known Limitations" section to README

### **Short-term (Real Production)**

- [ ] Replace local-path with Longhorn (distributed storage)
- [ ] OR deploy PostgreSQL as external service
- [ ] Set up automated backups
- [ ] Configure replication (primary + replica)
- [ ] Document recovery procedures

### **Long-term (Architecture)**

- [ ] Evaluate managed database services (RDS, Cloud SQL)
- [ ] Implement database backup/restore automation
- [ ] Set up multi-region replication (if needed)
- [ ] Create disaster recovery runbooks
- [ ] Test DR procedures quarterly

---

## Prevention Strategies

### **For This Scenario (Node + DB Failure)**

**Option 1: Distributed Storage**
```bash
# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml

# Use in postgres PVC
storageClassName: longhorn
# Now data replicated across all nodes
# Pod can move freely
```

**Option 2: StatefulSet + Replication**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  replicas: 2  # Primary + standby
  serviceName: postgres
  template:
    # Configure streaming replication
```

**Option 3: External Database**
```
Don't run database in Kubernetes
Use AWS RDS / Google Cloud SQL / Azure Database
App connects via URL
Database provider handles HA
```

### **Monitoring & Alerts**
```yaml
# Alert: Node down + database on that node
alert: NodeDownWithDatabase
expr: up{job="node"} == 0 AND kube_pod_info{pod=~"postgres.*", node="$node"} > 0
for: 1m
annotations:
  summary: "Node {{ $labels.node }} is down and hosts database pod"
  action: "Restart node OR failover database immediately"
```

---

## Production Recommendations

**Based on this chaos test:**

### **DO NOT:**
- ❌ Run stateful workloads with local storage
- ❌ Rely on single node for critical data
- ❌ Deploy single-instance databases in K8s (without replication)

### **DO:**
- ✅ Use distributed storage (Longhorn, Ceph, Rook)
- ✅ OR use external managed databases
- ✅ Implement database replication (primary/standby)
- ✅ Automate backups (daily minimum)
- ✅ Test recovery procedures regularly
- ✅ Document single points of failure

---

## Interview Talking Points

**What this chaos test demonstrates:**

> "I discovered a critical architectural flaw through chaos engineering. When I killed the node hosting PostgreSQL, the service was down for 25 hours because the database used local storage, creating node affinity. Kubernetes correctly prevented data loss by not rescheduling the pod, but this also prevented automatic recovery.
>
> This taught me that stateful workloads require special consideration. In production, I'd either use distributed storage like Longhorn so pods can move freely with their data, or use an external managed database service like AWS RDS that handles high availability independently.
>
> The key learning: Kubernetes protects your data but doesn't magically solve storage architecture problems. You need to design for distributed storage from the start."

---

## Data Verification

**Post-recovery data check:**
```bash
kubectl exec -it deployment/postgres -- psql -U healthcare_user -d healthcare -c "SELECT * FROM patients;"

# Expected result:
  id   |     name      | age |   condition   |     registered_at
-------+---------------+-----+---------------+------------------------
 9a... | Alice Johnson |  35 | Annual Checkup| 2026-01-27 10:18:43...
 deb...| Bob Smith     |  42 | Follow-up     | 2026-01-27 10:18:52...
(2 rows)
```

**✅ Data intact - no corruption, no loss**

---

## References

- Kubernetes Local Persistent Volumes: https://kubernetes.io/docs/concepts/storage/volumes/#local
- Longhorn Distributed Storage: https://longhorn.io/
- StatefulSet Basics: https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/

---

## Chaos Test Outcome

**Success criteria:**
- ✅ Simulated real node failure
- ✅ Discovered architectural limitation
- ✅ Understood Kubernetes behavior
- ✅ Verified data persistence
- ✅ Documented recovery procedure
- ✅ Identified prevention strategies

**Result:** Critical flaw found and documented. This single test is worth more than 10 successful tests.

---

**Postmortem created:** 2026-01-28  
**Reviewed by:** Ibrahim Cisse  
**Status:** Complete ✅

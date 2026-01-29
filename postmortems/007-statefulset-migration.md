# Postmortem: PostgreSQL Migration to StatefulSet

**Incident ID:** 007  
**Date:** 2026-01-29  
**Type:** Planned Maintenance  
**Severity:** Low  
**Duration:** 5 minutes  
**Status:** Complete

---

## Summary

Migrated PostgreSQL from Deployment to StatefulSet to improve database management and enable future replication capabilities.

**Impact:** 5-minute planned downtime  
**User Impact:** Service unavailable during migration  
**Data Loss:** None (backup/restore successful)  
**Result:** Successfully migrated to StatefulSet architecture

---

## Why StatefulSet?

**Deployment limitations:**
- Random pod names (postgres-84fd6557b7-h928h)
- No stable network identity
- PVC assignment not guaranteed
- Not designed for stateful workloads

**StatefulSet advantages:**
- Predictable pod names (postgres-0)
- Stable network identity (postgres-0.postgres)
- Dedicated PVC per pod
- Ordered deployment/scaling
- Foundation for database replication

---

## Migration Process

### Step 1: Backup Data
```bash
kubectl exec -it deployment/postgres -- pg_dump -U healthcare_user healthcare > /tmp/healthcare_backup.sql
```

**Result:** 3 patient records backed up

### Step 2: Delete Old Resources
```bash
kubectl delete deployment postgres
kubectl delete service postgres
kubectl delete pvc postgres-pvc
kubectl delete pv postgres-pv
```

**Result:** Clean slate for new architecture

### Step 3: Create New PV
```bash
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-0
spec:
  capacity:
    storage: 5Gi
  storageClassName: local-path
  local:
    path: /data/postgres
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node2
```

**Why new PV?**
- Old PV was bound to old PVC
- StatefulSet creates new PVC: postgres-storage-postgres-0
- Need matching PV for binding

### Step 4: Deploy StatefulSet
```bash
kubectl apply -f statefulset.yaml
```

**Resources created:**
- Headless Service: postgres (clusterIP: None)
- StatefulSet: postgres (replicas: 1)
- Pod: postgres-0 (stable name)
- PVC: postgres-storage-postgres-0 (auto-created)

### Step 5: Restore Data
```bash
kubectl cp /tmp/healthcare_backup.sql postgres-0:/tmp/backup.sql
kubectl exec -it postgres-0 -- psql -U healthcare_user -d healthcare -f /tmp/backup.sql
```

**Result:** All 3 patients restored (Alice, Bob, Ibrahim)

### Step 6: Verify
```bash
# Check pod
kubectl get pods -l app=postgres
# postgres-0   1/1   Running

# Test API connection
curl http://localhost:8000/patients
# ✅ Returns all patients
```

---

## Technical Improvements

### Before (Deployment)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  template:
    spec:
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc  # Shared PVC reference
```

**Pod name:** postgres-84fd6557b7-2tdhl (random)  
**PVC:** postgres-pvc (shared selection)  
**Service:** postgres (ClusterIP: 10.233.x.x)

### After (StatefulSet)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      storageClassName: local-path
      resources:
        requests:
          storage: 5Gi
```

**Pod name:** postgres-0 (predictable)  
**PVC:** postgres-storage-postgres-0 (dedicated)  
**Service:** postgres (ClusterIP: None - headless)

---

## Benefits Realized

### Stable Identity
- **Pod DNS:** postgres-0.postgres.default.svc.cluster.local
- **Always resolves to same pod**
- **Important for:** Replication configuration, monitoring, debugging

### Ordered Operations
- **Scale up:** postgres-0 starts first, then postgres-1, etc.
- **Scale down:** Reverse order (postgres-2, then postgres-1, etc.)
- **Important for:** Primary/standby replication setup

### Dedicated Storage
- **Each replica gets own PVC**
- **PVC persists even if pod deleted**
- **Important for:** Data safety, pod rescheduling

### Foundation for Replication

**Future scaling possible:**
```yaml
replicas: 3
# postgres-0: primary (read/write)
# postgres-1: standby (streaming replication)
# postgres-2: standby (streaming replication)
```

Each gets dedicated storage:
- postgres-storage-postgres-0 (5Gi)
- postgres-storage-postgres-1 (5Gi)
- postgres-storage-postgres-2 (5Gi)

---

## Lessons Learned

### Manual PV Management Required

**Issue:** No dynamic provisioner (local-path-provisioner not installed)

**Impact:** Had to manually create PV before StatefulSet could bind

**Solution for future:**
- Install local-path-provisioner, OR
- Use cloud environment with dynamic provisioning (EBS, Azure Disk), OR
- Deploy Longhorn for distributed storage

### StatefulSet PVC Naming Convention

**Pattern:** `{volumeClaimTemplate.name}-{statefulset.name}-{ordinal}`

**Example:**
- VCT name: postgres-storage
- StatefulSet name: postgres
- Ordinal: 0
- **Result:** postgres-storage-postgres-0

**Important:** PV must match this exact name for binding

### Headless Service is Required

**Standard Service (what we had):**
```yaml
spec:
  clusterIP: 10.233.x.x
```
- Single IP for load balancing
- Can't address individual pods

**Headless Service (what we need):**
```yaml
spec:
  clusterIP: None
```
- No load balancing IP
- DNS returns all pod IPs
- Enables direct pod addressing: postgres-0.postgres

**Why needed:** StatefulSet pods need stable network identity for replication

---

## Post-Migration Verification

### Data Integrity
```sql
SELECT COUNT(*) FROM patients;
-- Result: 3 ✅

SELECT * FROM patients ORDER BY registered_at;
-- Alice, Bob, Ibrahim all present ✅
```

### API Connectivity
```bash
curl http://localhost:8000/patients
# Returns full patient list ✅

curl -X POST http://localhost:8000/patients -d '{"name":"Test","age":25,"condition":"Checkup"}'
# Creates new patient ✅
```

### Pod Self-Healing
```bash
kubectl delete pod postgres-0
# StatefulSet recreates postgres-0 ✅
# Same PVC reattaches ✅
# Data persists ✅
```

---

## Future Work

### Phase 1: Replication
- [ ] Scale to replicas: 2
- [ ] Configure PostgreSQL streaming replication
- [ ] postgres-0: primary, postgres-1: standby
- [ ] Automatic failover with Patroni

### Phase 2: Distributed Storage
- [ ] Install Longhorn
- [ ] Migrate from local-path to longhorn StorageClass
- [ ] Data replicated across all nodes
- [ ] Pod can move freely

### Phase 3: High Availability
- [ ] 3 replicas with quorum
- [ ] PodDisruptionBudget (minimum 2 available)
- [ ] Backup automation (pg_basebackup)
- [ ] Point-in-time recovery (PITR)

---

## Success Criteria

**✅ All met:**

1. Migration completed successfully
2. Zero data loss (backup/restore verified)
3. API reconnected automatically
4. Downtime under 10 minutes (actual: 5 minutes)
5. StatefulSet features working (stable name, dedicated PVC)
6. Pod self-healing validated
7. Documentation updated

---

**Migration completed by:** Ibrahim Cisse  
**Date:** 2026-01-29  
**Status:** Success ✅

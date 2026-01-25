# Monitoring Stack Deployment

## Overview

Deployed Prometheus monitoring stack using Helm for complete cluster observability.

**Date:** January 25, 2026  
**Duration:** ~1 hour

---

## Components Deployed

### **Prometheus**
- **Purpose:** Metrics collection and storage
- **Scrape interval:** 15 seconds
- **Retention:** 15 days (default)
- **Access:** Internal only

**What it monitors:**
- Node metrics (CPU, RAM, disk, network)
- Kubernetes objects (pods, deployments, services)
- Container metrics (per-pod resources)
- API server performance

### **Grafana**
- **Purpose:** Metrics visualization and dashboards
- **Version:** Latest (via Helm)
- **Access:** Port-forward via SSH tunnel
- **Login:** admin / admin123

**Pre-installed dashboards:**
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace
- Kubernetes / Compute Resources / Node
- Node Exporter / Nodes

### **Supporting Components**
- **kube-state-metrics:** K8s object metrics
- **node-exporter:** Host-level metrics (on all 3 nodes)
- **prometheus-operator:** Manages Prometheus instances
- **alertmanager:** Alert routing (deployed but not configured)

---

## Deployment Process

### **1. Install Helm**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### **2. Add Prometheus Repository**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### **3. Deploy Stack**
```bash
# Create namespace
kubectl create namespace monitoring

# Deploy kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123
```

**Deployment time:** 3-5 minutes

### **4. Verify Installation**
```bash
kubectl get pods -n monitoring
```

**Expected output:**
```
NAME                                                     READY   STATUS    RESTARTS   AGE
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          5m
prometheus-grafana-xxxxx                                 3/3     Running   0          5m
prometheus-kube-prometheus-operator-xxxxx                1/1     Running   0          5m
prometheus-kube-state-metrics-xxxxx                      1/1     Running   0          5m
prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          5m
prometheus-prometheus-node-exporter-xxxxx                1/1     Running   0          5m (x3 nodes)
```

---

## Access Methods

### **Grafana UI**

**Method 1: SSH Tunnel (Current)**

Terminal 1 (master node):
```bash
ssh -J root@100.121.221.116 ibrahim@10.0.0.11
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Terminal 2 (laptop):
```bash
ssh -L 3000:localhost:3000 -J root@100.121.221.116 ibrahim@10.0.0.11
```

Browser: `http://localhost:3000`

**Note:** This method has latency due to double SSH tunnel. Acceptable for lab/demo purposes.

**Future improvement:** Set up Ingress with domain for cleaner access.

### **Prometheus UI (Optional)**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Browser: `http://localhost:9090`

---

## Architecture

### **Data Flow**
```
Cluster Resources
    ↓ (expose metrics)
Prometheus Scrapes
    ↓ (every 15s)
Prometheus Database
    ↓ (PromQL queries)
Grafana
    ↓ (render dashboards)
User Browser
```

### **What Gets Monitored**

**Node-level (via node-exporter):**
- CPU usage per core
- Memory usage
- Disk I/O
- Network traffic
- System load

**Kubernetes-level (via kube-state-metrics):**
- Pod count and status
- Deployment replica status
- Node status
- Resource requests/limits

**Container-level (via cAdvisor in kubelet):**
- Per-container CPU
- Per-container memory
- Container restarts
- Container network

---

## Available Dashboards

### **Cluster Overview**
- Total CPU/Memory usage
- Pod count by namespace
- Node status
- Network I/O

### **Node Details**
- Per-node CPU/Memory/Disk
- System load
- Process count

### **Pod Details**
- CPU/Memory per pod
- Network traffic per pod
- Container restart count

### **Namespace View**
- Resource usage by namespace
- Pod distribution
- Request vs actual usage

---

## Metrics Examples

### **Cluster CPU Usage**
```promql
sum(rate(container_cpu_usage_seconds_total[5m]))
```

### **Memory Usage by Pod**
```promql
sum(container_memory_working_set_bytes) by (pod)
```

### **Pod Count by Namespace**
```promql
count(kube_pod_info) by (namespace)
```

---

## Configuration Details

### **Prometheus Configuration**

**Scrape targets:**
- Kubernetes API server
- Kubelet (on each node)
- Node exporters
- kube-state-metrics
- Service monitors (for future apps)

**Storage:**
- Persistent volume: Not configured (ephemeral for lab)
- Retention: 15 days
- Storage size: Uses available node storage

### **Grafana Configuration**

**Data sources:**
- Prometheus (pre-configured)
- Ready for additional sources (Loki for logs, etc.)

**Authentication:**
- Admin user: admin
- Password: admin123 (set during deployment)

---

## Future Enhancements

### **Short-term (Week 4)**
- [ ] Add ServiceMonitor for Healthcare API
- [ ] Create custom dashboard for API metrics
- [ ] Monitor PostgreSQL metrics

### **Optional Improvements**
- [ ] Set up Ingress for cleaner access
- [ ] Configure persistent storage for Prometheus
- [ ] Add Loki for log aggregation
- [ ] Configure Alertmanager with Slack notifications
- [ ] Set up SSL/TLS for Grafana

---

## Troubleshooting

### **Grafana Not Loading**
- Check port-forward is running
- Verify SSH tunnels are active
- Check Grafana pod status: `kubectl get pods -n monitoring`

### **No Metrics Showing**
- Wait 2-3 minutes for initial scrapes
- Check Prometheus targets: Prometheus UI → Status → Targets
- Verify ServiceMonitors: `kubectl get servicemonitors -n monitoring`

### **High Resource Usage**
- Prometheus can use 1-2GB RAM
- Adjust retention period if needed
- Consider adding resource limits

---

## Week 3 Status

**Completed:**
- ✅ Monitoring stack deployed
- ✅ All components healthy
- ✅ Grafana accessible
- ✅ Metrics being collected
- ✅ Pre-built dashboards available

**Next Steps (Week 4):**
- Deploy Healthcare API to cluster
- Add custom metrics to API
- Create API-specific dashboard
- Monitor application performance

---

## Resources

**Helm Chart:** prometheus-community/kube-prometheus-stack  
**Documentation:** https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack  
**Grafana Docs:** https://grafana.com/docs/  
**Prometheus Docs:** https://prometheus.io/docs/

---

**Deployment completed:** January 25, 2026  
**Status:** Operational ✅

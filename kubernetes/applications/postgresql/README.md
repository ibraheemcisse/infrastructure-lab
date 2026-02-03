# PostgreSQL Database Deployment

## Current Architecture: StatefulSet

**Database:** healthcare  
**User:** healthcare_user  
**Storage:** 5Gi persistent volume on node2

--

## Monitoring Setup

**Date:** 2026-01-30

### PostgreSQL Exporter Deployed

**Components:**
- postgres_exporter (prometheuscommunity/postgres-exporter:v0.15.0)
- ServiceMonitor for Prometheus scraping
- Grafana dashboard (ID: 9628)

**Metrics exposed:**
- `pg_up` - Database availability
- `pg_database_size_bytes` - Database size per database
- `pg_stat_database_*` - Transaction statistics, query counts
- `pg_stat_bgwriter_*` - Background writer stats
- `pg_locks_*` - Lock statistics
- Connection counts, cache hit ratios, buffer statistics

**Grafana Dashboard:**
- Dashboard: PostgreSQL Database (ID: 9628)
- Location: Grafana → Dashboards → PostgreSQL Database

**Key Panels:**
- Active sessions (connection count)
- Transaction rate (commits/rollbacks per second)
- Fetch/Insert/Return data rates
- Database sizes
- CPU and memory usage
- Lock tables
- Buffer cache hit ratio

**Testing:**
Load test with 50 patient inserts + 100 queries showed:
- Transaction spike: baseline → 0.8 TPS peak
- Fetch data: 83K → 499K queries
- Return data: 3.75 MB → 23.7 MB
- Active sessions: 1 → multiple concurrent
- All metrics observable in real-time

**Access:**
```bash
# Port forward Grafana (from laptop)
ssh -L 3000:localhost:3000 -J root@100.121.221.116 ibrahim@10.0.0.11 \
  -t 'kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80'

# Browser: http://localhost:3000
# Navigate to Dashboards → PostgreSQL Database
```

# Postmortem: Firewall IP Restriction Lockout (DRAFT)

**Incident ID:** 002  
**Date:** 2025-01-21  
**Duration:** [TBD - incident ongoing]  
**Severity:** Medium (Management access blocked, SSH still available)  
**Status:** In Progress

---

## Executive Summary

Proxmox web UI became inaccessible after home IP address changed. Firewall rule restricted port 8006 to previous IP (140.213.118.196). New IP (103.225.150.178) blocked by firewall. SSH access on port 22 remained functional (allowed from anywhere).

**Impact:** Unable to access Proxmox web UI for VM management  
**Root Cause:** Dynamic home IP + firewall rule tied to specific IP  
**Resolution:** [To be completed - firewall rule update pending]

---

## Timeline (All times approximate)

**[DATE/TIME]** - Attempted to access Proxmox web UI at https://136.243.171.177:8006  
**[TIME]** - Connection timeout / infinite loading  
**[TIME]** - Verified SSH access still working (port 22)  
**[TIME]** - Checked Proxmox services - all running normally  
**[TIME]** - Identified issue: Home IP changed from 140.213.118.196 to 103.225.150.178  
**[TIME]** - **INCIDENT START:** Confirmed firewall blocking new IP  
**[TIME]** - Documented incident for postmortem  
**[TIME]** - Postponed resolution to next session

---

## Root Cause Analysis

### Primary Cause

Firewall rule configured with specific IP address rather than dynamic access method:
```
ufw allow from 140.213.118.196 to any port 8006 proto tcp
```

Home IP changed (ISP assigned new dynamic IP), breaking access.

### Contributing Factors

**Technical:**
- Dynamic IP assignment from ISP (expected behavior)
- Firewall rule tied to single IP rather than range or VPN
- No alternative access method configured

**Process:**
- Did not anticipate frequency of IP changes
- No monitoring/alerting for IP changes
- No documented procedure for IP updates

---

## What Went Wrong

**Design decision:** Restricted Proxmox UI to specific home IP for security

**Failure mode:** Home IP changed, firewall blocked new IP

**Impact:** Cannot access web UI (but SSH still works)

**Why it's not critical:** 
- SSH access still available for emergency management
- Can update firewall rule via SSH
- No operational impact on running VMs

---

## What Went Right

### Effective Responses

**Security worked as designed:**
- Firewall correctly blocked unauthorized IP
- SSH still accessible for recovery
- System remained secure during incident

**Diagnosis was quick:**
- Immediately identified symptoms (web UI timeout)
- Verified services running (not a service failure)
- Checked firewall rules (found the mismatch)
- Identified current IP (curl ifconfig.me)

**No panic:**
- Recognized this as low-severity incident
- Documented for proper postmortem
- Can resolve in minutes when ready

---

## Lessons Learned

### What Worked

1. **Layered security approach**
   - SSH on different port/rules than web UI
   - Always maintained one access method

2. **Quick diagnosis**
   - Systematic troubleshooting
   - Verified service status before assuming firewall issue

3. **Documentation mindset**
   - Captured incident while fresh
   - Will complete postmortem after resolution

### What Didn't Work

1. **Single IP-based access control**
   - Fragile: breaks when IP changes
   - No fallback method
   - Requires manual intervention

2. **No IP change monitoring**
   - Didn't know IP had changed until access failed
   - Could have proactively updated rule

---

## Action Items

### Immediate (Next Session)

- [ ] Update firewall rule with new IP (103.225.150.178)
- [ ] Test web UI access
- [ ] Document exact commands used
- [ ] Complete this postmortem

### Short-term (Phase 2-3)

- [ ] Implement Tailscale VPN for permanent private network
  - Proxmox gets stable 100.x.x.x IP
  - Laptop gets stable 100.x.x.x IP
  - Access via Tailscale IP (never changes)
  - Remove public IP restriction from firewall

- [ ] Alternative: SSH tunnel for web UI access
  - Keep firewall strict
  - Access UI via: ssh -L 8006:localhost:8006 root@server

- [ ] Alternative: IP range instead of single IP
  - If ISP assigns IPs in predictable range
  - E.g., 103.225.150.0/24

### Long-term

- [ ] Monitoring script for IP changes
  - Alerts when home IP changes
  - Optional: Auto-update firewall rule

- [ ] Document IP update procedure
  - Quick reference for future changes
  - Add to infrastructure/FIREWALL.md

---

## Prevention Strategies

### Technical Solutions

**Option 1: VPN (Tailscale) - RECOMMENDED**
- Proxmox joins Tailscale network
- Laptop joins Tailscale network
- Access Proxmox via Tailscale IP
- Firewall rule: allow 100.x.x.x/10 (Tailscale range)
- **Benefit:** Never update firewall again

**Option 2: SSH Tunnel**
- Keep strict firewall (single IP)
- Access web UI via SSH tunnel
- Command: `ssh -L 8006:localhost:8006 root@server`
- Access UI at: https://localhost:8006
- **Benefit:** No firewall changes needed

**Option 3: IP Range**
- If ISP assigns IPs in predictable range
- Allow entire /24 or /16 range
- **Trade-off:** Less secure, but more convenient

**Option 4: Dynamic DNS + Script**
- Script checks current IP periodically
- Updates firewall if IP changed
- Runs as cron job
- **Trade-off:** Complex, adds moving parts

### Process Improvements

**Access method checklist for future infrastructure:**
1. Primary access method defined
2. Secondary access method configured (SSH)
3. Access method resilient to IP changes
4. Documented update procedure if changes needed

---

## Related Incidents

**001** - Network Configuration Lockout  
Similarity: Both involve network access issues  
Difference: 001 was total loss, 002 has SSH fallback

---

## Success Metrics (To be measured)

**Resolution time:** [TBD]  
**Downtime:** [TBD - web UI only, SSH remained available]  
**Recurrence prevention:** Implement Tailscale or SSH tunnel

---

## Notes for Completion Tomorrow

**When fixing:**
1. Record exact time of firewall rule change
2. Test web UI access immediately after
3. Document any unexpected issues
4. Consider implementing Tailscale same session
5. Update this postmortem with actual timeline
6. Move from DRAFT to final

**Questions to answer:**
- How often does home IP change? (check ISP behavior)
- Is Tailscale appropriate for Phase 2 or wait until later?
- Should we implement quick fix (IP update) + proper fix (Tailscale) separately?

---

## Status: DRAFT

This postmortem will be completed after incident resolution.

**Next session agenda:**
1. Update firewall rule
2. Verify access restored
3. Complete postmortem
4. Decide on permanent solution (Tailscale vs SSH tunnel)
5. Continue with Week 2 (Terraform)

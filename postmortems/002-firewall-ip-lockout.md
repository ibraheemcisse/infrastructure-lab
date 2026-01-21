# Postmortem: Firewall IP Restriction Lockout

**Incident ID:** 002  
**Date:** 2025-01-21  
**Duration:** ~2 hours (discovery to permanent fix)  
**Severity:** Medium (Management access blocked, SSH available)  
**Status:** Resolved with Tailscale implementation

---

## Executive Summary

Proxmox web UI became inaccessible when home IP changed from 140.213.118.196 to 103.225.150.178. Firewall rule restricted port 8006 to previous IP. Instead of applying temporary fix (updating IP), implemented permanent solution (Tailscale VPN).

**Impact:** Temporary loss of web UI access (SSH remained available)  
**Root Cause:** Firewall rule tied to dynamic home IP address  
**Resolution:** Deployed Tailscale for stable private network access

---

## Timeline

**21:00** - Attempted to access Proxmox web UI, connection timeout  
**21:05** - Verified SSH access working, Proxmox services running  
**21:10** - Discovered home IP changed: 140.213.118.196 → 103.225.150.178  
**21:15** - **INCIDENT START:** Confirmed firewall blocking new IP  
**21:20** - Decided against quick fix, opted for permanent solution  
**21:25** - Fixed Proxmox APT repository issue (enterprise repo disabled)  
**21:35** - Installed Tailscale on Proxmox host  
**21:40** - Authenticated Proxmox to Tailscale network  
**21:45** - Installed Tailscale on laptop  
**21:50** - Verified connectivity via Tailscale (ping successful)  
**21:55** - Updated firewall to allow Tailscale network (100.64.0.0/10)  
**22:00** - **INCIDENT END:** Accessed Proxmox UI via Tailscale IP successfully

---

## Root Cause Analysis

### Primary Cause

Firewall access control tied to dynamic IP address:
```
ufw allow from 140.213.118.196 to any port 8006 proto tcp
```

ISP reassigned home IP, breaking access.

### Contributing Factors

**Design decision:**
- Chose IP-based access control for simplicity
- Did not anticipate IP change frequency
- No fallback access method beyond SSH

**Process gap:**
- No monitoring for IP changes
- No documented IP update procedure
- Reactive rather than proactive approach

---

## What Went Wrong

**Fragile design:** Single IP restriction breaks with normal ISP behavior (dynamic IP assignment)

**Predictable failure:** Known limitation of IP-based access control

**Why severity was medium:**
- SSH access maintained (fallback available)
- No operational impact on running systems
- Could fix via SSH in minutes

---

## What Went Right

### Effective Responses

**Chose permanent fix over quick fix:**
- Recognized pattern: would repeat every IP change
- Invested 30 minutes for permanent solution
- Avoided technical debt accumulation

**Discovered underlying issue:**
- Proxmox enterprise repo causing APT failures
- Fixed repository configuration properly
- Prevented future package installation issues

**Systematic implementation:**
- Verified each step (Tailscale install, connectivity, firewall)
- Tested before declaring success
- Documented entire process

---

## Lessons Learned

### What Worked

**1. Engineering judgment**
   - Recognized when to invest in proper solution
   - Avoided repeating manual fixes
   - Thought in systems, not incidents

**2. Root cause analysis**
   - Identified APT repository issue during Tailscale install
   - Fixed underlying problem, not just symptoms

**3. Verification discipline**
   - Tested Tailscale connectivity before updating firewall
   - Confirmed access via new method before removing old

### What Didn't Work

**1. Initial design choice**
   - IP-based access control inappropriate for dynamic IPs
   - Should have used VPN from the start
   - "Simple" solution created maintenance burden

**2. Deferred decision**
   - Knew about Tailscale option during Phase 1
   - Chose "quick" IP restriction instead
   - Delayed proper solution by ~24 hours

---

## Action Items

### Immediate (Completed)

- [x] Fixed Proxmox APT repository configuration
- [x] Installed Tailscale on Proxmox host
- [x] Installed Tailscale on laptop
- [x] Updated firewall to allow Tailscale network
- [x] Verified web UI access via Tailscale IP
- [x] Documented incident and resolution

### Short-term (Optional)

- [ ] Block public access to Proxmox UI entirely (only Tailscale)
- [ ] Install Tailscale on phone for mobile access
- [ ] Configure Tailscale ACLs for fine-grained access control
- [ ] Add Tailscale to infrastructure documentation

### Long-term (Best Practices)

- [ ] Use VPN/private networks for all management access
- [ ] Never expose management planes to public internet
- [ ] Design for operational simplicity, not initial setup speed

---

## Prevention Strategies

### Technical Controls

**For management access:**
1. Default to private networks (VPN/Tailscale)
2. Never rely on dynamic IP addresses
3. Design for mobility (access from anywhere)
4. Use zero-trust networking principles

**For new infrastructure:**
1. Install Tailscale during initial setup
2. Configure firewall for private network only
3. Test access before declaring system ready

### Decision Framework

**When choosing access method:**
- Will this break with normal ISP behavior? → Don't use it
- Will this require manual intervention? → Automate or use different approach
- Does this scale to multiple locations? → If no, reconsider

**Quick fix vs proper fix:**
- If problem will recur → Invest in permanent solution
- If fix takes < 30 minutes → Do it properly first time
- If creating technical debt → Stop and redesign

---

## Success Metrics

**Resolution efficiency:**
- Time to permanent fix: 30 minutes
- Future maintenance: Zero (IP changes no longer matter)
- Access reliability: Works from any network

**Knowledge gained:**
- Tailscale installation and configuration
- Proxmox repository management
- Firewall network range rules
- Zero-trust networking principles

**Process improvements:**
- Choose proper solutions over quick hacks
- Fix root causes, not symptoms
- Design for operations, not just initial setup

---

## Technical Details

### Tailscale Configuration

**Proxmox Tailscale IP:** 100.121.221.116  
**Laptop Tailscale IP:** 100.75.42.14  
**Network:** ibraheemcisse.github tailnet

**Firewall rule:**
```bash
ufw allow from 100.64.0.0/10 to any port 8006 proto tcp comment 'Proxmox UI - Tailscale'
```

**Access method:**
```
https://100.121.221.116:8006
```

### Repository Fix

**Disabled:**
```
# /etc/apt/sources.list.d/pve-enterprise.list
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
```

**Enabled:**
```
# /etc/apt/sources.list.d/pve-no-subscription.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
```

---

## Related Incidents

**001** - Network Configuration Lockout  
Pattern: Network access issues due to untested changes

**002** - Firewall IP Lockout (this incident)  
Pattern: Access issues due to design choices

**Common thread:** Network access design requires careful consideration of failure modes

---

## Retrospective

**What this incident taught:**
- Dynamic IPs are incompatible with IP-based access control
- "Simple" solutions can create maintenance burden
- Investing 30 minutes in proper solution saves hours later
- Tailscale/VPN should be default for management access
- Fix root causes, not symptoms

**Impact on project:**
- Improved security posture (VPN-only access)
- Reduced operational complexity (no IP management)
- Better mobile access (works from anywhere)
- Demonstrated mature engineering judgment

**Would do differently:**
- Install Tailscale during Phase 1 setup
- Never use IP-based access for dynamic IPs
- Design for operations from the start

---

## References

**Documentation:**
- infrastructure/FIREWALL.md (updated with Tailscale)
- infrastructure/SECURITY.md (VPN access documented)

**External resources:**
- Tailscale documentation: https://tailscale.com/kb
- Proxmox no-subscription repository setup

---

## Approvals

**Prepared by:** Ibrahim Cisse  
**Date:** 2025-01-21  
**Reviewed by:** Self (solo project)  
**Status:** Complete

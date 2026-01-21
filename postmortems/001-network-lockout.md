# Postmortem: Network Configuration Lockout

**Incident ID:** 001  
**Date:** 2025-01-19  
**Duration:** ~8 hours (incident + recovery attempts)  
**Severity:** Critical (complete loss of system access)  
**Status:** Resolved via infrastructure rebuild

---

## Executive Summary

During initial network configuration of Proxmox VE, attempted to add NAT bridge (vmbr1) to live system. Applied iptables NAT rules without incremental testing, resulting in immediate loss of SSH connectivity. Multiple recovery attempts through rescue mode failed due to boot issues. Incident resolved by complete system rebuild using documented installation process.

**Impact:** 8 hours downtime, complete loss of work-in-progress system  
**Root Cause:** Applied untested network configuration to production-accessible system without rollback plan  
**Resolution:** Infrastructure rebuild from documented procedures (3 hours)

---

## Timeline (All times approximate)

**T-0:00** - Proxmox VE installation complete, vmbr0 (public bridge) working  
**T+0:15** - Decided to add vmbr1 (NAT bridge) for VM networking  
**T+0:20** - Modified `/etc/network/interfaces` to add vmbr1 configuration including iptables NAT rules  
**T+0:25** - Ran `ifup vmbr1` without prior testing  
**T+0:26** - **INCIDENT START:** Immediate SSH connection timeout, system unresponsive  
**T+0:30** - Attempted to reconnect via SSH: connection timeout  
**T+0:35** - Accessed Hetzner Robot panel, activated rescue mode  
**T+0:45** - Booted into rescue system, mounted Proxmox filesystem  
**T+1:00** - Examined `/etc/network/interfaces`, identified potential iptables rules issue  
**T+1:15** - Modified config to remove vmbr1, attempted to preserve vmbr0 only  
**T+1:30** - Rebooted system, still no SSH access  
**T+2:00** - Re-entered rescue mode, discovered boot partition not mounted during previous fix  
**T+2:30** - Mounted boot partition, found kernel and GRUB files present  
**T+3:00** - Attempted GRUB reinstall via chroot  
**T+3:30** - Rebooted, system still not accessible  
**T+4:00** - Multiple additional rescue mode entries, various recovery attempts  
**T+6:00** - Consulted with mentor, discussed recovery vs rebuild trade-offs  
**T+6:30** - **DECISION:** Abandon recovery, rebuild from documentation  
**T+6:45** - Wiped drives, initiated fresh Debian installation  
**T+7:30** - Debian installed, Proxmox installation in progress  
**T+8:45** - Network bridges configured incrementally (vmbr0 first, tested, then vmbr1)  
**T+9:00** - System fully operational, NAT validated with test VM  
**T+9:00** - **INCIDENT END:** System rebuilt and functional

---

## Root Cause Analysis

### Primary Cause

Applied complex network configuration changes to live system without:
- Incremental testing (both bridges applied simultaneously)
- Syntax validation (did not use `ifup --no-act`)
- Rollback mechanism (no backup SSH session or console access)
- Understanding of iptables rule interactions

### Contributing Factors

**Technical:**
- Insufficient understanding of iptables NAT rule behavior on live bridges
- Did not anticipate that bringing up bridge + NAT rules could affect existing connectivity
- No monitoring of system state during configuration application
- Applied all changes in single operation rather than step-by-step

**Process:**
- No change management procedure for critical infrastructure
- Assumed network changes were easily reversible
- Did not document current working state before modifications
- No peer review or sanity check before applying changes

**Knowledge gaps:**
- Limited experience with live network reconfiguration on remote systems
- Incomplete understanding of bridge + iptables interaction timing
- Did not know to keep backup SSH session during network changes

---

## What Went Wrong

### The Change

Added the following configuration to `/etc/network/interfaces`:
```
auto vmbr1
iface vmbr1 inet static
    address 10.0.0.1/24
    bridge-ports none
    bridge-sfd 0
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '10.0.0.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '10.0.0.0/24' -o vmbr0 -j MASQUERADE
```

Then executed: `ifup vmbr1`

### The Failure

**Hypothesis (most likely):**
The iptables MASQUERADE rule, combined with IP forwarding activation, may have disrupted existing connection tracking state. The existing SSH session was likely caught in a connection tracking state transition that broke the TCP connection.

**Alternative theories:**
- Bridge initialization sequence interfered with existing vmbr0 traffic
- iptables rule application order caused brief DROP of existing connections
- Kernel network stack confusion during simultaneous bridge operations

**Why recovery failed:**
Boot issues emerged during rescue mode recovery attempts. Possible causes:
- GRUB configuration corruption during repeated rescue mode operations
- Incomplete boot partition mount during config repairs
- Network config changes prevented proper system initialization
- File system inconsistencies from multiple emergency reboots

---

## What Went Right

### Effective Responses

**Documentation:**
- Had complete installation procedure documented
- Config files version controlled
- Could reproduce entire system from notes

**Decision Making:**
- Recognized when recovery time exceeded rebuild time (~6 hours)
- Made decisive call to rebuild rather than continue debugging unknown state
- Consulted with mentor for perspective before major decision

**Technical Execution:**
- Rebuild completed successfully in 3 hours (vs 8+ hours of failed recovery)
- Applied lessons immediately: incremental bridge configuration during rebuild
- Validated each step before proceeding to next

**Knowledge Retention:**
- Documented failure mode for future reference
- Understood root cause (untested network changes)
- Learned specific commands for validation (`ifup --no-act`)

---

## Lessons Learned

### What Worked

1. **Documentation-first approach**
   - Having step-by-step installation notes enabled fast rebuild
   - Version control of configs provided known-good reference
   - Time investment in documentation paid off immediately

2. **Stateless infrastructure mindset**
   - Treating server as "cattle not pets" reduced emotional attachment to broken system
   - Rebuild was faster than archaeology
   - Data loss was acceptable (no production state)

3. **Mentor consultation**
   - Outside perspective helped recognize sunk cost fallacy
   - Validation of rebuild decision reduced decision anxiety

### What Didn't Work

1. **Live system changes without testing**
   - Should have used `ifup --no-act` to validate syntax
   - Should have tested on disposable VM first
   - Should have kept backup SSH session open

2. **All-at-once configuration**
   - Should have brought up vmbr0, validated, then vmbr1
   - Should have tested bridges separately before adding NAT
   - Should have tested NAT rules in isolation

3. **No rollback plan**
   - No console access (would have shown boot errors)
   - No automated revert after timeout
   - No backup configuration snapshot

4. **Recovery attempts without clear diagnosis**
   - Spent hours trying solutions without understanding exact failure
   - Each rescue mode attempt potentially made things worse
   - Didn't recognize diminishing returns early enough

---

## Action Items

### Immediate (Completed)

- [x] Rebuild system with incremental network configuration
- [x] Document postmortem for future reference
- [x] Test NAT functionality before declaring success

### Short-term (Next phase)

- [ ] Always use `ifup --no-act` before applying network changes
- [ ] Keep backup SSH session open during network modifications
- [ ] Test network changes on non-critical VM first
- [ ] Document rollback procedures for common changes

### Long-term (Future phases)

- [ ] Implement configuration management (Ansible for reproducible configs)
- [ ] Add monitoring/alerting for host connectivity
- [ ] Consider KVM console access for boot troubleshooting
- [ ] Create automated backup snapshots before major changes

---

## Prevention Strategies

### Technical Controls

**For network changes:**
1. Validate syntax: `ifup --no-act <interface>`
2. Keep backup SSH session open in separate terminal
3. Apply changes incrementally with validation between steps
4. Test on non-production system first when possible
5. Have console access available (KVM, IPMI, etc.)

**For system changes:**
1. Snapshot/backup before major changes
2. Document current working state
3. Have documented rollback procedure
4. Set time limits for troubleshooting before considering rebuild

### Process Controls

**Change management for critical infrastructure:**
1. Document proposed change and expected outcome
2. Identify rollback procedure before applying change
3. Apply change during low-risk time window
4. Validate success criteria immediately after change
5. Document actual outcome (success or failure)

**Decision framework for recovery vs rebuild:**
- If recovery time > rebuild time: rebuild
- If risk of data corruption: rebuild
- If diagnosis unclear after 2 hours: consider rebuild
- If multiple recovery attempts fail: rebuild

---

## Success Metrics

**Rebuild efficiency:**
- Time to rebuild: 3 hours (within 4-hour target)
- Zero issues during rebuild (learned from mistakes)
- All functionality validated before declaring success

**Knowledge gained:**
- Can now explain exact failure mode
- Understand incremental testing importance
- Know specific validation commands
- Have documented procedure for similar situations

**Process improvements:**
- Postmortem template created for future incidents
- Documentation proved its value
- Decision framework for recovery vs rebuild established

---

## Related Incidents

None (first major incident)

---

## References

**Documentation:**
- Infrastructure repo: BUILD_LOG.md (rebuild procedure)
- Network config: infrastructure/network-interfaces-final.conf

**External resources:**
- Hetzner rescue system documentation
- Proxmox network configuration guide
- Linux bridge + iptables interaction

---

## Approvals

**Prepared by:** Ibrahim Cisse  
**Date:** 2025-01-20  
**Reviewed by:** Self (solo project)  
**Status:** Complete

---

## Appendix: Commands That Could Have Prevented This

### Validation before applying
```bash
# Test syntax without actually configuring
ifup --no-act vmbr1

# Show what would change
ip addr show vmbr1 2>/dev/null || echo "Interface doesn't exist yet"
```

### Safe testing approach
```bash
# Bring up bridge without NAT first
auto vmbr1
iface vmbr1 inet static
    address 10.0.0.1/24
    bridge-ports none
    bridge-sfd 0
    bridge-fd 0

# Test bridge only: ifup vmbr1
# Verify: ip addr show vmbr1
# Add NAT rules manually and test
# Then add to interfaces file if successful
```

### Recovery commands used
```bash
# In rescue mode
lsblk                          # Identify partitions
mount /dev/vg0/root /mnt      # Mount root
mount /dev/md0 /mnt/boot      # Mount boot
chroot /mnt /bin/bash         # Enter system
# Make config changes
exit
umount /mnt/boot /mnt
reboot
```

---

## Postmortem Retrospective

**What this incident taught:**
- Failure is an opportunity to learn
- Documentation is insurance
- Stateless infrastructure enables fast recovery
- Knowing when to cut losses is a valuable skill
- Postmortems capture institutional knowledge

**What I would do differently:**
- Test network changes on local VM first
- Use tmux with multiple sessions for critical changes
- Set up console access before making risky changes
- Timebox recovery attempts more strictly

**Impact on project:**
- Delayed progress by ~5 hours (8 hour incident - 3 hour rebuild vs expected 0 hours)
- Gained valuable troubleshooting experience
- Established incident response procedures
- Created reusable postmortem template

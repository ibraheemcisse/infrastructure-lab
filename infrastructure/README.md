# Phase 1: Infrastructure Foundation

## What Was Built

Bare metal dedicated server → Production Proxmox VE platform

## Stack
```
Hetzner Dedicated Server
├── Hardware: i7-6700, 64GB RAM, 2x512GB NVMe
├── Storage: RAID1 (md0 + md1)
│   ├── /boot: 1GB
│   └── LVM (vg0):
│       ├── root: 96GB
│       ├── swap: 20GB
│       └── data: 360GB (/var/lib/vz)
├── OS: Debian 12 Bookworm
└── Hypervisor: Proxmox VE 8.4.16
    ├── vmbr0: Public bridge (host)
    └── vmbr1: NAT bridge (VMs)
```

## Time to Rebuild

From bare metal to working Proxmox: **~3 hours**

## Key Files

- `BUILD_LOG.md` - Detailed build notes
- `network-interfaces-final.conf` - Working network config

## Lessons Learned

1. Always backup network config before changes
2. Test bridge configs with `ifup --no-act` first
3. Comment out conflicting partition definitions
4. LVM "all" size must be last partition

## Next Phase

VM creation with NAT networking validation

## Why This Was a Rebuild

### First Attempt (Jan 18-19)

**What happened:**
1. Successfully installed Proxmox VE
2. Attempted to add NAT bridge (vmbr1) while system was running
3. Ran `ifup vmbr1` without proper testing
4. Network configuration broke - lost SSH access
5. Boot issues after rescue mode recovery attempts
6. Spent 8+ hours troubleshooting boot/network problems

**Root causes:**
- Applied network changes to live system without validation
- iptables NAT rules in config caused network stack issues
- Bootloader became corrupted during recovery attempts
- No clear rollback path once system was broken

**Decision:** Wipe and rebuild with proper methodology

### Second Attempt (Jan 20) - This Build

**What changed:**
1. **Planned approach:** Document → Execute → Verify at each step
2. **Proper sequencing:** Install Debian → Install Proxmox → Configure network
3. **Testing methodology:** Use `ifup --no-act` before applying changes
4. **Incremental validation:** Test vmbr0 first, then vmbr1 separately
5. **Version control:** Git commit after each successful phase

**Result:** Clean build in ~3 hours vs 8+ hours of failed recovery

### Key Takeaway

**Stateless infrastructure mindset validated:**
- Rebuilding from documentation faster than debugging unknown state
- Clear, tested configs > trial-and-error fixes
- Time to rebuild is a quality metric (target: <4 hours)

This approach mirrors production incident response: sometimes the fastest path to resolution is controlled rebuild, not archaeology.

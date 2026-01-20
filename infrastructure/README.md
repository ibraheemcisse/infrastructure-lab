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

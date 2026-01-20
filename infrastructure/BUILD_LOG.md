
### Debian Installation Started

**Time:** [Current time]

**Configuration:**
- Drives: 2x NVMe 512GB RAID1
- Partitions:
  - /boot: 1GB (md0)
  - LVM (md1):
    - root: 96GB → /
    - swap: 8GB
    - data: 370GB → /var/lib/vz
- OS: Debian 12 Bookworm
- Hostname: pve

**Issues encountered:**
1. LV "all" size must be on last partition - FIXED
2. Conflicting PART definitions at bottom - FIXED (commented out)

**Installation running...**

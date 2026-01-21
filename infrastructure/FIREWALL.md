
---

## Update: Tailscale VPN Access

**Date:** 2025-01-21

### Migration from IP-Based to VPN Access

Replaced home IP restriction with Tailscale VPN for permanent solution.

**Previous (fragile):**
```bash
ufw allow from <HOME_IP> to any port 8006 proto tcp
```
Problem: Broke every time home IP changed

**Current (permanent):**
```bash
ufw allow from 100.64.0.0/10 to any port 8006 proto tcp comment 'Proxmox UI - Tailscale'
```
Solution: Allow entire Tailscale network range

### Tailscale Setup

**Installation:**
```bash
# On Proxmox
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# On laptop/phone/other devices
# Same installation, authenticate to same tailnet
```

**Proxmox Tailscale IP:** 100.121.221.116

**Access Proxmox UI:**
```
https://100.121.221.116:8006
```

### Benefits

- ✅ Works from any network (home, mobile, travel)
- ✅ IP never changes (100.x.x.x is stable)
- ✅ Encrypted tunnel (zero-trust security)
- ✅ No firewall updates needed
- ✅ Access from multiple devices
- ✅ No port forwarding required

### Optional: Block Public Access

For maximum security, block public access entirely:
```bash
# Deny public access to Proxmox UI
ufw deny 8006/tcp

# Only Tailscale network can access
ufw allow from 100.64.0.0/10 to any port 8006 proto tcp
```

Now Proxmox UI is accessible ONLY via Tailscale.

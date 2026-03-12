# Edge Node Setup — Cerberus

Complete build log for the Cerberus edge node.

---

## Hardware

| Component | Detail |
|---|---|
| Device | Google Chromebook (Sparky360) |
| CPU | Intel Pentium Silver N5030 @ 1.10GHz (4-core) |
| RAM | 8GB LPDDR4 |
| Storage | 57GB eMMC (mmcblk0) — 15GB used |
| Network | Intel Wireless-AC 9560 (unused) + AX88179 USB Gigabit Ethernet |
| TPM | TPM 2.0 (spi-PRP0001) |

## OS

- **Distribution:** Arch Linux (minimal server install)
- **Kernel:** 6.19.6-arch1-1 (PREEMPT_DYNAMIC)
- **Hostname:** Cerberus
- **Primary user:** foreverlx (UID 1000)

---

## Initial Hardening

### SSH

Real SSH moved to port 2121. Port 22 reserved for Cowrie honeypot.

```
# /etc/ssh/sshd_config key settings
Port 2121
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Authentication uses Ed25519 keys only. Password authentication is disabled.

### Swap

No swap was configured by default. Added 2GB swapfile to prevent OOM kills:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Swappiness tuned to 10 (only use swap under real memory pressure).

### sysctl Hardening

```
# /etc/sysctl.d/99-nightforge.conf
vm.swappiness=10
net.ipv4.ip_unprivileged_port_start=22
```

`ip_unprivileged_port_start=22` allows rootless Podman to bind port 22 for Cowrie. Acceptable on a single-user edge node where port 22 is intentionally assigned to the honeypot.

### nftables Firewall

Default-deny input policy with explicit allowlist. Dynamic blackhole set for automated IP blocking.

See `docs/architecture.md` for full ruleset.

### Auditd

System call logging enabled:

```bash
sudo systemctl enable --now auditd
```

---

## Container Runtime

Rootless Podman with systemd integration (Quadlets).

Key configuration:

```bash
# Allow user services to persist after logout
loginctl enable-linger foreverlx
```

Cerberus components use Quadlets in `~/.config/containers/systemd/`. Legacy homelab services use system-level units in `/etc/systemd/system/`.

---

## Networking

### Ethernet

Primary interface is USB Ethernet (AX88179 adapter):

```
Interface: enp0s21f0u2c2
IP: 192.168.0.251/24 (static via NetworkManager)
```

### WireGuard

WireGuard mesh connects the edge node to NightForge workstation (workstation):

```
Interface: wg0
Address: 10.0.0.1/24
```

Config at `/etc/wireguard/wg0.conf`.

### Tailscale

Tailscale provides authenticated remote access without exposing ports to the internet:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

---

## Scheduled Tasks

### User Crontab (foreverlx)

```
0 2 * * *   /usr/bin/bash /home/foreverlx/backup-script.sh > /home/foreverlx/backup.log 2>&1
0 3 * * *   /home/foreverlx/scripts/maintenance.sh
```

**backup-script.sh** — Backs up Vaultwarden SQLite database to `/home/foreverlx/backups/vaultwarden/` and commits to a private Gitea repository.

**maintenance.sh** — Updates Suricata rules, rotates old JSON logs (>3 days), backs up Vaultwarden and Homepage configs, pre-downloads Arch updates.

### Root Crontab

```
0 3 * * 0   /usr/local/bin/security-updates.sh
```

**security-updates.sh** — Runs `pacman -Syu --noconfirm` and logs to `/var/log/security-updates.log`. Runs weekly (Sunday 03:00 UTC).

---

## Monitoring

| Tool | Port | Purpose |
|---|---|---|
| Netdata | 19999 | Real-time CPU, RAM, container, Suricata metrics |
| Prometheus | 9090 | Metrics collection and retention |
| Homepage | 8282 | NOC dashboard aggregating service status |

---

## Known Issues at Baseline (2026-03-11)

See `docs/known-gaps.md` for full details.

- Homepage does not auto-start on reboot (no systemd service)
- Vaultwarden has two competing service definitions (system service vs. old container)
- No TLS frontend — Vaultwarden accessible HTTP only, Caddy deployment failed
- WireGuard does not persist across reboots reliably

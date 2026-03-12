# Nyx

**Azrael Security homelab and purple-team infrastructure.**

Built and operated by [ForeverLX](https://github.com/foreverlx) — Azrael Security™

| Node | Role |
|---|---|
| **Cerberus** | Chromebook edge node — sensors, detection, honeypot, homelab services |
| **NightForge** | Arch workstation — C2, offensive tooling, heavy compute (planned) |

---

## What It Is

Nyx is Azrael Security's homelab infrastructure project. Cerberus (the edge node) is a production-grade, low-footprint sensor platform running on an 8GB Chromebook. It demonstrates a full purple-team feedback loop:

```
Internet Threats
      │
      ▼
┌─────────────────────────────┐
│      Edge Node (Cerberus)      │
│  Chromebook · Arch Linux    │
│  192.168.0.251 (LAN)        │
│                             │
│  ┌──────────┐ ┌──────────┐  │
│  │ Suricata │ │  Cowrie  │  │
│  │   IDS    │ │ Honeypot │  │
│  └────┬─────┘ └────┬─────┘  │
│       └──────┬─────┘        │
│              ▼              │
│      NightForge Shield      │
│    (Scoring + Automation)   │
│              │              │
│    ┌─────────┴──────────┐   │
│    │                    │   │
│    ▼                    ▼   │
│ nftables             Scan   │
│ Blackhole            Queue  │
└─────────────────────────────┘
      │
      ▼
┌─────────────────┐
│  NightForge workstation  │
│  Arch · 32GB    │
│  Mythic · LLM   │
└─────────────────┘
```

**The loop:** Suricata IDS and Cowrie SSH honeypot feed a threat scoring engine. IPs crossing the score threshold are automatically blocked via nftables and queued for Nuclei reconnaissance.

---

## Edge Node Specs

| Component | Detail |
|---|---|
| Hardware | Google Chromebook (Pentium Silver N5030, 4-core) |
| RAM | 8GB + 2GB swap |
| Storage | 57GB eMMC (15GB used) |
| OS | Arch Linux (kernel 6.19.6) |
| Networking | Ethernet (AX88179), Tailscale VPN, WireGuard mesh |
| Container runtime | Rootless Podman + systemd Quadlets |

---

## Active Components

| Component | Role | Port | Status |
|---|---|---|---|
| Suricata 8.0.3 | Network IDS | — | ✅ Active |
| Cowrie 2.9.13 | SSH honeypot | 22 | ✅ Active (Quadlet) |
| NightForge Shield | Scoring → nftables + queue | — | ✅ Active |
| nftables | Firewall + dynamic blackhole | — | ✅ Active |
| Pi-hole | DNS sinkhole | 53/80/443 | ✅ Active |
| Gitea | Private Git server | 3000/2222 | ✅ Active |
| Vaultwarden | Password manager | 8081 | ✅ Active (HTTP only) |
| Netdata | Performance monitoring | 19999 | ✅ Active |
| Prometheus | Metrics | 9090 | ✅ Active |
| Tailscale | Secure remote access | — | ✅ Active |
| Homepage | NOC dashboard | 8282 | ✅ Active (manual start) |

---

## Quickstart

```bash
# 1. Apply sysctl settings
sudo cp configs/sysctl/99-nightforge.conf /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.d/99-nightforge.conf

# 2. Create data directories
sudo mkdir -p /var/nightforge/{cowrie-logs,cowrie-lib,scan-queue}
sudo chown -R $USER:$USER /var/nightforge/
sudo chown -R 100998:100998 /var/nightforge/cowrie-logs /var/nightforge/cowrie-lib
sudo touch /var/nightforge/scan-queue.txt

# 3. Deploy Cowrie honeypot (Quadlet)
cp edge-node/containers/nightforge-cowrie.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start nightforge-cowrie.service

# 4. Deploy Shield
mkdir -p ~/scripts/suricata
cp edge-node/scripts/suricata-shield.sh ~/scripts/suricata/
chmod +x ~/scripts/suricata/suricata-shield.sh
cp edge-node/systemd/nightforge-shield.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now nightforge-shield.service

# 5. Enable linger so services survive logout
loginctl enable-linger $USER
```

---

## Repository Structure

```
nightforge/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── edge-node-setup.md
│   ├── services.md
│   ├── nightforge-shield.md
│   ├── ops.md
│   └── known-gaps.md
├── edge-node/
│   ├── containers/
│   │   └── nightforge-cowrie.container
│   ├── systemd/
│   │   └── nightforge-shield.service
│   └── scripts/
│       └── suricata-shield.sh
└── configs/
    └── sysctl/
        └── 99-nightforge.conf
```

---

> All tooling is deployed on infrastructure owned and operated by the author for authorized research and portfolio development. Authorized use only.

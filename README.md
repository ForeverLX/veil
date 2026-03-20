# Veil

**Azrael Security — Offensive Security Infrastructure**

Built and operated by [ForeverLX](https://github.com/ForeverLX) | Azrael Security™

> Veil is the operational infrastructure layer connecting all Azrael Security nodes. It is not a simulation environment — it is a production-grade offensive security homelab built for real adversary emulation, threat detection, and red team infrastructure research.

---

## Infrastructure Overview

| Node | Role | OS | WireGuard IP |
|---|---|---|---|
| **Cerberus** | Edge node — services, detection, honeypot | Arch Linux (headless) | `10.0.0.1` (hub) |
| **NightForge** | Operator workstation — tooling, compute, development | Arch Linux + Niri WM | `10.0.0.3` |
| **Tairn** | Attack node — Mythic C2, agent staging, lab targets | NixOS 24.11 (declarative) | `10.0.0.4` |

All inter-node communication runs exclusively over a WireGuard hub-and-spoke mesh. No node is directly reachable from WAN.

---

## Architecture

```
                        Internet
                           │
                    ┌──────▼──────┐
                    │  Cerberus   │
                    │ 10.0.0.1    │
                    │ 192.168.1.x │
                    │             │
                    │ Cowrie      │
                    │ Suricata    │
                    │ Pi-hole     │
                    │ Caddy TLS   │
                    │ Gitea       │
                    │ Vaultwarden │
                    │ Netdata     │
                    │ Homepage    │
                    └──────┬──────┘
                           │ WireGuard mesh (10.0.0.0/24)
              ┌────────────┴────────────┐
              │                         │
    ┌─────────▼────────┐     ┌──────────▼──────────┐
    │   NightForge      │     │       Tairn          │
    │   10.0.0.3        │     │       10.0.0.4       │
    │   192.168.1.x     │     │   192.168.122.x      │
    │                   │     │   (libvirt NAT,      │
    │ Operator WS       │     │    NightForge-local) │
    │ Niri WM           │     │                      │
    │ Offensive tooling │     │ Mythic C2            │
    │ Podman profiles   │     │ Poseidon agent       │
    │ Neovim / tmux     │     │ HTTP C2 profile      │
    │ Ollama (local AI) │     │ Lab target VMs       │
    └───────────────────┘     │ NixOS declarative    │
                              └──────────────────────┘
```

**WireGuard topology:** Hub-and-spoke via Cerberus. Cerberus is the always-on edge node and mesh hub. NightForge and Tairn peer exclusively through Cerberus. Hairpin routing enabled for node-to-node communication across the mesh.

---

## Node Detail

### Cerberus — Edge Node

Chromebook running headless Arch Linux. Serves as the perimeter sensor platform and homelab services hub. All services run as rootless Podman Quadlets under systemd.

**Detection stack:**
- **Cowrie 2.9.13** — SSH honeypot on port 22. Captures attacker TTPs, credentials, and session data.
- **Suricata 8.0.3** — Network IDS with live rule updates.
- **Pi-hole** — DNS sinkhole + `.lan` domain resolution for all nodes.

**Services:**
- **Gitea** — Self-hosted Git server (primary remote for all Veil repos)
- **Vaultwarden** — Self-hosted password manager
- **Caddy** — Reverse proxy with automatic local CA TLS for all `.lan` domains
- **Netdata** — Real-time performance monitoring
- **Homepage** — NOC dashboard

**Firewall:** nftables. WireGuard hairpin routing via `iif "wg0" oif "wg0" accept`. rp_filter=0 on wg0 interface.

### NightForge — Operator Workstation

Primary operator environment. Arch Linux with Niri Wayland compositor. All offensive tooling, development, and infrastructure management runs here.

- **Hardware:** i3-10105F, 32GB RAM, GTX 1650
- **Compositor:** Niri (Wayland, scrolling tiling layout)
- **Container runtime:** Podman rootless (ad, re, web, toolbox profiles)
- **Editor:** Neovim with LSP
- **Shell:** Zsh + Starship
- **VM management:** libvirt (Tairn hosted here as NAT VM)
- **Local AI:** Ollama (`qwen2.5:14b` for RAG pipeline)

See [nightforge](https://github.com/ForeverLX/nightforge) for full workstation configuration and operator framework.

### Tairn — Attack Node

NixOS 24.11 VM hosted on NightForge via libvirt NAT. Declarative configuration — entire system state is version controlled in `configuration.nix`. Dedicated to offensive operations and course lab work.

- **C2 framework:** Mythic (Docker-based)
- **Primary agent:** Poseidon (Go, Linux)
- **C2 profile:** HTTP C2
- **Operation:** Operation Azrael
- **Access:** WireGuard-only (`10.0.0.4`). Mythic UI locked to mesh via iptables DOCKER-USER chain.
- **Courses:** Certified Red Team Analyst (CRTA), Certified Red Team Infrastructure Developer (CRT-ID) via CyberWarfare Labs — all technique work documented with MITRE ATT&CK mapping

---

## Security Posture

| Control | Implementation |
|---|---|
| Network segmentation | WireGuard mesh — no node reachable from WAN |
| C2 access control | iptables DOCKER-USER — port 7443 restricted to `10.0.0.0/24` |
| Container isolation | Rootless Podman Quadlets (Cerberus), Docker (Tairn — Mythic requirement) |
| Secret management | Vaultwarden + `/etc/containers/secrets/` for Quadlet env injection |
| DNS | Pi-hole (`.lan` resolution + sinkhole) |
| TLS | Caddy local CA (all `.lan` services) |
| SSH | Key-only auth, no root password login |
| Declarative infra | Tairn entire OS state in `configuration.nix` — reproducible from scratch |

---

## Repository Structure

```
veil/
├── README.md
├── configs/
│   ├── sysctl/
│   │   └── 99-wireguard.conf
│   └── nftables/
│       └── cerberus.nft
├── edge-node/
│   ├── containers/          # Podman Quadlet unit files
│   ├── systemd/             # User systemd units
│   └── scripts/             # Shield + automation scripts
├── dotfiles/                # Shared shell/prompt configs (Starship)
└── docs/
    ├── architecture.md
    ├── wireguard-mesh.md
    ├── cerberus-setup.md
    ├── tairn-setup.md
    ├── services.md
    ├── ops.md
    ├── troubleshooting.md
    └── known-gaps.md
```

---

## Quickstart — Cerberus Edge Node

```bash
# 1. Apply sysctl settings
sudo cp configs/sysctl/99-wireguard.conf /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf

# 2. Create data directories
sudo mkdir -p /var/nightforge/{cowrie-logs,cowrie-lib,scan-queue}
sudo chown -R $USER:$USER /var/nightforge/
sudo chown -R 100998:100998 /var/nightforge/cowrie-logs /var/nightforge/cowrie-lib

# 3. Deploy Cowrie honeypot
cp edge-node/containers/nightforge-cowrie.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start nightforge-cowrie.service

# 4. Enable linger
loginctl enable-linger $USER
```

---

## Disclaimer

All tooling is deployed on infrastructure owned and operated by the author for authorized security research and portfolio development. Authorized use only.

---

**Author:** Darrius Grate (ForeverLX) | Azrael Security™
**License:** MIT

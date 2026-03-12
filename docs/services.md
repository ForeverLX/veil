# Services Reference

All services running on the Cerberus edge node (192.168.0.251).

---

## Nyx Core Services (Running on Cerberus)

### Suricata IDS

| Field | Value |
|---|---|
| Version | 8.0.3 |
| Manager | systemd (system) |
| Unit | suricata.service |
| Interface | enp0s21f0u2c2 (af-packet) |
| Threads | 4 workers |
| Memory | ~648MB |
| Log path | /var/log/suricata/fast.log |
| Rule updates | suricata-update (via maintenance.sh) |

```bash
sudo systemctl status suricata
sudo tail -f /var/log/suricata/fast.log
```

---

### Cowrie SSH Honeypot

| Field | Value |
|---|---|
| Version | 2.9.13 |
| Image | docker.io/cowrie/cowrie:latest |
| Manager | Rootless Podman Quadlet |
| Unit | nightforge-cowrie.service (user) |
| Port | host:22 → container:2222 |
| Log host path | /var/nightforge/cowrie-logs/cowrie.json |
| Lib host path | /var/nightforge/cowrie-lib/ |
| Container UID | 100998 (rootless namespace) |

Cowrie presents a fake SSH server on port 22. All authentication attempts, commands, and file downloads are logged as JSON events.

```bash
systemctl --user status nightforge-cowrie
tail -f /var/nightforge/cowrie-logs/cowrie.json | jq .
```

---

### NightForge Shield

| Field | Value |
|---|---|
| Script | ~/scripts/suricata/suricata-shield.sh |
| Manager | systemd user service |
| Unit | nightforge-shield.service (user) |
| Inputs | /var/log/suricata/fast.log, /var/nightforge/cowrie-logs/cowrie.json |
| Output — blocks | nftables blackhole set (1hr TTL) |
| Output — queue | /var/nightforge/scan-queue.txt |

See `docs/nightforge-shield.md` for full scoring model documentation.

```bash
systemctl --user status nightforge-shield
journalctl --user -u nightforge-shield -f
```

---

## Homelab Services

### Pi-hole

| Field | Value |
|---|---|
| Image | docker.io/pihole/pihole:latest |
| Manager | podman generate systemd (system) |
| Unit | container-pihole.service |
| Network mode | host |
| Ports | 53 (DNS), 80/443 (web UI) |
| Web UI | http://192.168.0.251/admin |

Pi-hole provides local DNS resolution and network-wide ad/tracker blocking.

```bash
sudo systemctl status container-pihole
```

> ⚠️ **Gap:** Admin password stored in plaintext in `/etc/systemd/system/container-pihole.service`. Migrate to environment file in Phase S1.

---

### Gitea

| Field | Value |
|---|---|
| Image | docker.io/gitea/gitea:latest |
| Manager | hand-written systemd unit (system) |
| Unit | container-gitea.service |
| Ports | 3000 (web), 2222 (SSH) |
| Web UI | http://192.168.0.251:3000 |
| Data | /srv/gitea/ |

Private Git server. Hosts internal repos including the automated Vaultwarden backup repo.

```bash
sudo systemctl status container-gitea
```

---

### Vaultwarden

| Field | Value |
|---|---|
| Version | 1.35.4 |
| Image | docker.io/vaultwarden/server:latest |
| Manager | podman generate systemd (system) — CONFLICTED |
| Active container | vaultwarden (user), port 8081 |
| System unit | container-vaultwarden.service, port 8080 |
| Web UI | http://192.168.0.251:8081 |
| Data | /srv/vaultwarden/ |

> ⚠️ **Gap (Critical):** Two competing service definitions exist:
> - User container `vaultwarden` — runs on port 8081, managed manually
> - System unit `container-vaultwarden.service` — attempts port 8080, container exits immediately
>
> Currently using user container on 8081. Requires Quadlet migration and consolidation in Phase S1.

> ⚠️ **Gap:** No TLS frontend. Vaultwarden requires HTTPS for web vault UI. Caddy deployment is planned but currently non-functional.

```bash
podman ps | grep vault
podman logs vaultwarden
```

---

### Homepage Dashboard

| Field | Value |
|---|---|
| Image | docker.io/gethomepage/homepage:latest |
| Manager | Manual podman start (no systemd unit) |
| Port | 8282 |
| Web UI | http://192.168.0.251:8282 |

> ⚠️ **Gap:** No auto-restart on reboot. Must be manually started after each reboot:
> ```bash
> podman start homepage
> ```
> Quadlet migration planned in Phase S1.

---

### Netdata

| Field | Value |
|---|---|
| Manager | systemd |
| Port | 19999 |
| Web UI | http://192.168.0.251:19999 |

Real-time monitoring of CPU, RAM, containers, Suricata rule hits, and network throughput.

---

### Prometheus

| Field | Value |
|---|---|
| Manager | systemd |
| Port | 9090 |
| Web UI | http://192.168.0.251:9090 |

Metrics collection. Configured to scrape local exporters.

---

### Tailscale

| Field | Value |
|---|---|
| Manager | systemd (tailscaled) |
| Interface | tailscale0 |

Provides authenticated remote access to the edge node without port forwarding. SSH access via Tailscale IP on port 2121.

---

## Port Reference

| Port | Protocol | Service | Notes |
|---|---|---|---|
| 22 | TCP | Cowrie honeypot | Fake SSH — all connections logged |
| 53 | TCP/UDP | Pi-hole DNS | |
| 80/443 | TCP | Pi-hole web UI | |
| 2121 | TCP | Real SSH (sshd) | Actual admin access |
| 2222 | TCP | Gitea SSH | |
| 3000 | TCP | Gitea web | |
| 8081 | TCP | Vaultwarden | HTTP only (gap) |
| 8282 | TCP | Homepage | |
| 9090 | TCP | Prometheus | |
| 19999 | TCP | Netdata | |

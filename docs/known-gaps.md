# Known Gaps

Documented gaps in the Cerberus edge node deployment as of baseline 2026-03-11.

These are not failures — they are documented technical debt with clear remediation plans. Each gap has a phase assigned.

---

## Gap 1 — Pi-hole Password in Plaintext Systemd Unit

**Severity:** Medium
**Phase:** S1

**Description:**
The Pi-hole systemd service (`/etc/systemd/system/container-pihole.service`) contains the admin password in plaintext as an environment variable. Any user who can read systemd unit files or run `systemctl show` can extract it.

**Evidence:**
```
Environment=WEBPASSWORD=<password>
```

**Fix:**
```bash
# Create environment file
sudo mkdir -p /etc/nightforge/secrets
echo "WEBPASSWORD=<password>" | sudo tee /etc/nightforge/secrets/pihole.env
sudo chmod 600 /etc/nightforge/secrets/pihole.env

# Update unit to use EnvironmentFile=
sudo systemctl edit container-pihole.service
```

---

## Gap 2 — Vaultwarden: Two Competing Service Definitions

**Severity:** High
**Phase:** S1

**Description:**
Two separate service definitions manage Vaultwarden:

1. **System unit** (`/etc/systemd/system/container-vaultwarden.service`) — attempts to start a container on port 8080. Container starts, logs "Rocket has launched from http://0.0.0.0:8080", but then exits immediately. Root cause not yet diagnosed.

2. **User container** (`vaultwarden`) — the original container started with `podman run`. Runs on port 8081. Currently the only working Vaultwarden instance.

The nftables config originally allowed port 8081 but was changed to 8080 during a cleanup pass, causing Vaultwarden to become unreachable from LAN. Port 8081 is now re-added.

**Fix:**
- Migrate Vaultwarden to a user Quadlet
- Remove `container-vaultwarden.service` from `/etc/systemd/system/`
- Remove old user container
- Deploy single Quadlet on a decided port
- Update nftables config accordingly

---

## Gap 3 — No TLS Frontend

**Severity:** Medium
**Phase:** S1

**Description:**
No HTTPS termination is deployed. Vaultwarden requires HTTPS for the web vault UI (browser Subtle Crypto API requirement). All homelab services are accessible HTTP only.

Caddy was planned as the TLS reverse proxy but the Caddy container consistently exits with code 1. Root cause: configuration errors in Caddyfile — not yet resolved.

**Current workaround:**
Vaultwarden is accessible via the admin panel at HTTP only. Browser client vault functionality is non-operational until TLS is deployed.

**Fix:**
```
edge-node/containers/
└── caddy.container     ← Quadlet with working Caddyfile
```

Caddyfile should reverse-proxy:
- `vaultwarden.local` → 127.0.0.1:8081
- `gitea.local` → 127.0.0.1:3000
- `homepage.local` → 127.0.0.1:8282

Local DNS entries in Pi-hole pointing `.local` names to 192.168.0.251.

---

## Gap 4 — Homepage Has No Auto-Start

**Severity:** Low
**Phase:** S1

**Description:**
Homepage container was started manually with `podman run` and has no systemd service. It does not survive reboot. After each reboot, `podman start homepage` must be run manually.

**Fix:**
```ini
# ~/.config/containers/systemd/homepage.container
[Container]
Image=docker.io/gethomepage/homepage:latest
PublishPort=8282:3000
Volume=%h/homepage-config:/app/config
AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
```

---

## Gap 5 — WireGuard Does Not Persist Across Reboots

**Severity:** Medium
**Phase:** S1

**Description:**
WireGuard interface `wg0` is not present after reboot. The `wg-quick@wg0.service` may not be enabled, or the config at `/etc/wireguard/wg0.conf` may be missing.

**Verification:**
```bash
sudo systemctl status wg-quick@wg0
ls /etc/wireguard/
```

**Fix:**
```bash
sudo systemctl enable wg-quick@wg0
```

---

## Gap 6 — Homepage Service Config Out of Date

**Severity:** Low
**Phase:** S1

**Description:**
Homepage `services.yaml` has two issues:
- Vaultwarden URL points to port 8081 (correct) but was at some point set to 8080 (wrong)
- Pi-hole and Cerberus scan stats have no entries in the dashboard

**Fix:**
Update `~/homepage-config/services.yaml` to:
- Confirm Vaultwarden points to correct active port
- Add Pi-hole widget
- Add Cerberus scan queue stats (via custom API or script widget)

---

## Gap 7 — Caddy Never Successfully Deployed

**Severity:** Medium
**Phase:** S1

**Description:**
Caddy appears in previous documentation as "deployed" but has never run successfully on this node. Container exits with code 1. No TLS certificates have been issued.

**Root cause:** Caddyfile configuration errors — likely missing or misconfigured site block for the LAN environment (no public DNS, no ACME challenge reachability for production certs).

**Fix options:**
1. Use Caddy with a local CA (`tls internal`) — generates self-signed certs with a local root CA. Best for homelab.
2. Use Caddy with Tailscale certificate provisioning if all access is over Tailscale.

---

## Gap 8 — Scan Queue Worker Not Deployed

**Severity:** Low
**Phase:** 4

**Description:**
The scan queue at `/var/nightforge/scan-queue.txt` accumulates blocked IPs for Nuclei reconnaissance, but no worker process consumes the queue. As of baseline (2026-03-11), 60+ IPs are queued.

**Planned implementation:**
```
~/nightforge/recon-worker.sh       — dequeues IPs, runs nuclei
~/.config/systemd/user/
└── nightforge-recon.timer         — every 5 minutes
└── nightforge-recon.service       — one-shot execution
```

Worker will run `nuclei -rl 10 -c 5` against each queued IP and write results to `/var/nightforge/recon-results/`.

---

## Remediation Priority

| Gap | Severity | Phase | Effort |
|---|---|---|---|
| Gap 2 — Vaultwarden conflict | High | S1 | Medium |
| Gap 3 — No TLS | Medium | S1 | Medium |
| Gap 5 — WireGuard reboots | Medium | S1 | Low |
| Gap 1 — Pi-hole password | Medium | S1 | Low |
| Gap 7 — Caddy failed | Medium | S1 | Medium |
| Gap 4 — Homepage no auto-start | Low | S1 | Low |
| Gap 6 — Homepage config stale | Low | S1 | Low |
| Gap 8 — No scan queue worker | Low | 4 | High |

---

## Future Phase — Network Segmentation (VLANs + DMZ)

**Severity:** Enhancement
**Phase:** 6 (long-term)

**Description:**
The current network is flat — all devices share 192.168.0.0/24. A mature homelab/red team infrastructure should have segmented VLANs with clearly defined trust boundaries.

**Proposed Zone Architecture:**

```
DMZ (Demilitarized Zone)
└── Cerberus edge node — honeypots, public-facing sensors
└── No inbound trust from Ops or C2 zones

Ops Zone
└── Gitea, Vaultwarden, Homepage, Pi-hole
└── Trusted from Management only

Red / C2 Zone
└── NightForge workstation — Mythic, offensive tooling
└── Isolated from Ops and DMZ
└── Egress-only to internet

Management Zone
└── Out-of-band admin access to all zones
└── Strictest access controls
```

**Prerequisites:**
- Managed switch with 802.1Q VLAN tagging support
- Router/firewall supporting inter-VLAN routing with ACLs
  (pfSense or OPNsense on a mini-PC, or Proxmox-based virtual router)
- Pi-hole moved to Management or Ops zone
- Tailscale termination point in Management zone

**Value:**
- Cerberus compromise does not laterally reach NightForge workstation or credentials
- Red team traffic never shares a broadcast domain with homelab services
- Defensible architecture suitable for portfolio documentation and client demonstrations

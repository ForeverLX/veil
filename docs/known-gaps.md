# Known Gaps

Current gaps in the Nyx / Cerberus edge node deployment as of 2026-03-13.

---

## Resolved Gaps (Phase S1 Complete)

| Gap | Resolution |
|---|---|
| Pi-hole password in plaintext | Migrated to system Quadlet with secrets file |
| Vaultwarden competing services | Single user Quadlet on port 8081 |
| No TLS frontend | Caddy deployed with local CA, all services on .lan domains |
| Homepage no auto-start | User Quadlet, linger enabled |
| WireGuard reboot persistence | wg-quick@wg0 enabled, NightForge peer added (10.0.0.3) |
| Homepage config stale | Fully rebuilt — Netdata/Gitea widgets, icons, SearXNG search |
| Caddy never deployed | Deployed with host networking, local CA trusted on all nodes |
| Gitea hand-written system unit | Migrated to user Quadlet |
| Pi-hole hand-written system unit | Migrated to system Quadlet, DNS upstream Cloudflare-only |
| NightForge DNS single point of failure | FallbackDNS=1.1.1.1 1.0.0.1 added to resolved drop-in |

---

## Active Gaps

### Gap 1 — Homepage Netdata Service Widgets Show Identical Data
**Severity:** Low
**Phase:** D1

**Description:**
Suricata IDS, Cowrie Honeypot, and Netdata service cards all display the
same Netdata chart data. Each card should show a distinct metric relevant
to its function.

**Fix:**
- Suricata IDS → `app.Suricata-Main_cpu_utilization` or `suricata.alerts`
- Cowrie Honeypot → container-specific cgroup chart
- Netdata card → `system.cpu` summary

---

### Gap 2 — SearXNG Autocomplete Not Working
**Severity:** Low
**Phase:** D1

**Description:**
Homepage search widget `suggestionUrl` points to SearXNG autocompleter
but suggestions are not appearing. Likely a CORS or endpoint format issue.

**Fix:**
Verify SearXNG autocomplete endpoint and correct the suggestionUrl format.

---

### Gap 3 — Netdata Not Monitoring Containers
**Severity:** Medium
**Phase:** D1

**Description:**
Netdata sees host system metrics but container-level metrics are not
visible. Podman socket not mounted into Netdata container.

**Fix:**
```ini
# Add to /etc/containers/systemd/netdata.container
Volume=/run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
```

---

### Gap 4 — No Scan Queue Worker
**Severity:** Low
**Phase:** 4

**Description:**
Scan queue accumulates blocked IPs for Nuclei recon but no worker
consumes the queue.

**Planned implementation:**
- `~/nightforge/recon-worker.sh` — dequeues IPs, runs nuclei
- `nightforge-recon.timer` — every 5 minutes
- Results written to `/var/nightforge/recon-results/`

---

### Gap 5 — NightForge Not Integrated into Nyx Infrastructure
**Severity:** Medium
**Phase:** N1

**Description:**
NightForge (i3-10105F, 32GB RAM, Arch Linux, kernel 6.19.6-zen1) is a
fully operational offensive security workstation running the Niri
compositor. The offsec-workstation repo (commit ccf368dd) documents a
complete environment including:

- Operator Terminal Framework v0.5.0 — contextual awareness on terminal
  startup, VPN detection, engagement context, MITRE ATT&CK logging
- Container Profiles v0.4.0 — rootless Podman profiles for AD, RE, web,
  and toolbox workflows
- 60+ documented keybinds, screenshot system, Obsidian integration
- Active engage/ directory with archive, current, templates, test-lab

WireGuard is connected (10.0.0.3) but NightForge is not yet integrated
into the Nyx NOC dashboard or centralized monitoring.

**Planned:**
- Netdata agent on NightForge reporting to Cerberus
- NightForge service cards in Homepage NOC dashboard
- Mythic C2 deployment on NightForge (Phase 4)
- Centralized log aggregation from NightForge to Cerberus

---

### Gap 6 — No Network Segmentation (VLANs)
**Severity:** Enhancement
**Phase:** 6 (long-term)

**Description:**
Network is flat — all devices on 192.168.0.0/24. Mature red team
infrastructure requires segmented VLANs with defined trust boundaries.

**Proposed zones:**
- DMZ — Cerberus honeypots, public-facing sensors
- Ops — Gitea, Vaultwarden, Homepage, Pi-hole
- Red/C2 — NightForge, Mythic, offensive tooling
- Management — out-of-band admin access

**Prerequisites:** Managed switch, pfSense/OPNsense router.

---

## Remediation Priority

| Gap | Severity | Phase | Effort |
|---|---|---|---|
| Gap 3 — Netdata container metrics | Medium | D1 | Low |
| Gap 5 — NightForge Nyx integration | Medium | N1 | Medium |
| Gap 1 — Duplicate widget data | Low | D1 | Low |
| Gap 2 — SearXNG autocomplete | Low | D1 | Low |
| Gap 4 — Scan queue worker | Low | 4 | High |
| Gap 6 — Network segmentation | Enhancement | 6 | Very High |

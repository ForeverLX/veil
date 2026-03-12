# NightForge Shield

The Shield is the automation core of NightForge. It monitors Suricata and Cowrie in real time, scores threat events, blocks high-confidence IPs via nftables, and queues them for Nuclei reconnaissance.

---

## How It Works

The Shield runs as a persistent systemd user service with two parallel monitoring loops:

1. **Suricata monitor** — tails `/var/log/suricata/fast.log`
2. **Cowrie monitor** — tails `/var/nightforge/cowrie-logs/cowrie.json`

Each loop parses events, classifies them, adds to a per-IP score accumulator, and triggers blocking + queuing when the score threshold is reached.

---

## Scoring Model

| Event | Score | Reason |
|---|---|---|
| `suricata_exploit` | +3 | Exploit/shellcode/injection/RCE signatures |
| `suricata_c2` | +5 | C2/beacon/callback signatures |
| `suricata_scan` | +1 | Port scan/probe/sweep signatures |
| `suricata_alert` | +2 | All other Suricata alerts |
| `cowrie_login_success` | +4 | Attacker successfully authenticated to honeypot |
| `cowrie_login_failed` | +2 | Failed honeypot authentication attempt |
| `cowrie_command` | +3 | Command executed inside honeypot shell |
| `cowrie_download` | +5 | File download attempted inside honeypot |

**Block threshold: score ≥ 4**

This means a single exploit attempt or successful honeypot login triggers an immediate block. A port scan alone does not — it requires accumulation or a second event.

---

## Whitelist

The following ranges are never blocked regardless of score:

```
169.254.0.0/16   (pasta container bridge — internal)
192.168.0.0/24   (LAN)
10.0.0.0/8       (WireGuard mesh)
127.0.0.0/8      (loopback)
100.86.0.0/16    (Tailscale)
```

---

## Actions on Threshold

When an IP reaches score ≥ 4, two actions fire simultaneously:

**1. nftables block (1 hour TTL)**
```bash
sudo /usr/bin/nft add element inet filter blackhole "{ $ip timeout 1h }"
```

**2. Scan queue entry**
```
format: IP|SCORE|TIMESTAMP|REASON
example: 192.73.248.83|4|1773207259|suricata_alert
```

The scan queue at `/var/nightforge/scan-queue.txt` is processed by the Nuclei worker (systemd timer, every 5 minutes, rate-limited to 10 req/s).

---

## Service Management

```bash
# Status
systemctl --user status nightforge-shield.service

# Logs (live)
journalctl --user -u nightforge-shield.service -f

# Restart
systemctl --user restart nightforge-shield.service
```

### Service Definition

```ini
# ~/.config/systemd/user/nightforge-shield.service
[Unit]
Description=NightForge Shield — Suricata + Cowrie → nftables
After=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /home/foreverlx/scripts/suricata/suricata-shield.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

---

## Log Output Format

```
[NightForge] 192.73.248.83 | reason=suricata_alert | score=4 | 05:34:19Z
[NightForge] BLOCKED+QUEUED 192.73.248.83 (score: 4)
```

---

## Real-World Performance

On first boot after deployment (2026-03-11), the edge node blocked 20+ unique IPs within the first 60 seconds of Suricata coming online. The scan queue accumulated 67+ entries in the first 8 hours of operation — all from unsolicited internet scanning activity against the node's public-facing interface.

The blackhole set processes approximately 118,000+ packets/6.8MB from blocked IPs per session, demonstrating the volume of automated scanning activity present on a residential IP.

---

## Known Limitations

- Score accumulator is in-memory only — restarting the shield resets scores for all IPs
- Scan queue grows unbounded; no deduplication between runs
- Nuclei worker not yet deployed (Phase 3 backlog)
- Shield does not yet forward results to Mythic C2 (Phase 4)

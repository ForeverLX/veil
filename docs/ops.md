# Operations Runbook

Day-to-day operations for the Cerberus edge node.

---

## Daily Checks

```bash
# 1. Verify core services are running
systemctl --user status nightforge-cowrie nightforge-shield
sudo systemctl status suricata container-pihole container-gitea

# 2. Check scan queue size
wc -l /var/nightforge/scan-queue.txt
tail -5 /var/nightforge/scan-queue.txt

# 3. Check blackhole set (currently blocked IPs)
sudo nft list set inet filter blackhole

# 4. Check Suricata for recent alerts
sudo tail -20 /var/log/suricata/fast.log

# 5. Check Cowrie for recent logins
tail -20 /var/nightforge/cowrie-logs/cowrie.json | jq 'select(.eventid == "cowrie.login.success")'
```

---

## SSH Access

```bash
# LAN access
ssh foreverlx@192.168.0.251 -p 2121

# Remote access via Tailscale
ssh foreverlx@<tailscale-ip> -p 2121
```

Port 22 is Cowrie. Do NOT attempt to SSH on port 22 — all connections are logged.

---

## Service Management

### NightForge Shield

```bash
systemctl --user status nightforge-shield
systemctl --user restart nightforge-shield
journalctl --user -u nightforge-shield -f --output=cat
```

### Cowrie Honeypot

```bash
systemctl --user status nightforge-cowrie
systemctl --user restart nightforge-cowrie
journalctl --user -u nightforge-cowrie -n 50
```

### Suricata

```bash
sudo systemctl status suricata
sudo journalctl -u suricata -n 30
# Update rules
sudo suricata-update && sudo systemctl reload suricata
```

---

## Manual Starts (Gaps — Fix in Phase S1)

```bash
# Homepage — no auto-start, run after reboot
podman start homepage

# Vaultwarden — use user container on 8081
podman start vaultwarden
```

---

## Firewall Operations

```bash
# View current ruleset
sudo nft list ruleset

# View current blackhole set
sudo nft list set inet filter blackhole

# Manually block an IP (1 hour)
sudo nft add element inet filter blackhole '{ 1.2.3.4 timeout 1h }'

# Manually unblock an IP
sudo nft delete element inet filter blackhole '{ 1.2.3.4 }'

# Reload firewall from config
sudo systemctl restart nftables
```

---

## Scan Queue

```bash
# View queue
cat /var/nightforge/scan-queue.txt

# Count queued IPs
wc -l /var/nightforge/scan-queue.txt

# Clear queue (after processing)
> /var/nightforge/scan-queue.txt

# Manual Nuclei scan against a queued IP (rate-limited)
nuclei -u 1.2.3.4 -rl 10 -c 5 -silent
```

---

## Log Locations

| Log | Path |
|---|---|
| Suricata alerts | /var/log/suricata/fast.log |
| Suricata full EVE JSON | /var/log/suricata/eve.json |
| Cowrie events | /var/nightforge/cowrie-logs/cowrie.json |
| NightForge Shield | journalctl --user -u nightforge-shield |
| Scan queue | /var/nightforge/scan-queue.txt |
| Backup log | ~/backup.log |
| Security updates | /var/log/security-updates.log |
| Auditd | /var/log/audit/audit.log |

---

## Backup Procedures

### Automated (Daily 02:00 UTC)

`~/backup-script.sh` runs automatically via cron:
- Copies Vaultwarden SQLite database to `~/backups/vaultwarden/`
- Commits with timestamp
- Pushes to `ssh://git@192.168.0.251:2222/foreverlx/backups.git`

### Manual Backup

```bash
# Run backup script manually
bash ~/backup-script.sh
cat ~/backup.log
```

### Verify Gitea Backup Repo

```bash
# Check latest commit
curl -s http://192.168.0.251:3000/foreverlx/backups | grep "commit"
```

---

## Maintenance

### Weekly Maintenance (Automated — Sunday 03:00 UTC)

`/usr/local/bin/security-updates.sh` runs as root:
- `pacman -Syu --noconfirm`
- Logs to `/var/log/security-updates.log`

### Manual Maintenance

```bash
bash ~/scripts/maintenance.sh
```

Performs:
- Suricata rule update
- Log rotation (removes cowrie.json entries >3 days)
- Vaultwarden SQLite backup
- Homepage config backup
- Arch package cache pre-download

---

## Reboot Procedure

After reboot, verify:

```bash
# Core Nyx services (Cerberus)
systemctl --user status nightforge-cowrie nightforge-shield

# System services
sudo systemctl status suricata container-pihole container-gitea container-vaultwarden

# Manual starts (until Phase S1 Quadlet migration)
podman start homepage
podman start vaultwarden  # if system service fails

# Firewall
sudo nft list ruleset | grep policy

# Verify Cowrie is on port 22
ss -tlnp | grep :22
```

---

## Troubleshooting

### Cowrie Not Logging

```bash
# Check volume ownership
ls -la /var/nightforge/cowrie-logs/
# Should be owned by UID 100998

# Fix if wrong
sudo chown -R 100998:100998 /var/nightforge/cowrie-logs /var/nightforge/cowrie-lib

# Check container logs
journalctl --user -u nightforge-cowrie -n 30
```

### Shield Not Blocking

```bash
# Check if service is running
systemctl --user status nightforge-shield

# Check nftables blackhole set exists
sudo nft list sets | grep blackhole

# Verify sudo nft works for user
sudo nft list ruleset | head -5

# Check script permissions
ls -la ~/scripts/suricata/suricata-shield.sh
```

### Vaultwarden Not Accessible

```bash
# Check which container is running
podman ps | grep vault
sudo podman ps | grep vault

# Check port
ss -tlnp | grep 8081

# Check firewall
sudo nft list ruleset | grep 8081
```

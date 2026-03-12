#!/usr/bin/env bash
# Nyx — NightForge Shield v2
# Monitors Suricata fast.log and Cowrie cowrie.json
# Scores threat events per IP and auto-blocks via nftables blackhole set
# Queues blocked IPs for Nuclei reconnaissance
#
# Node: Cerberus (edge node)
# Author: ForeverLX — Azrael Security
# Service: ~/.config/systemd/user/nightforge-shield.service

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
SURICATA_LOG="/var/log/suricata/fast.log"
COWRIE_LOG="/var/nightforge/cowrie-logs/cowrie.json"
SCAN_QUEUE="/var/nightforge/scan-queue.txt"
BLOCK_THRESHOLD=4
LOG_PREFIX="[NightForge]"

# IP ranges that should never be blocked
WHITELIST_PATTERNS=(
    "^169\.254\."   # pasta container bridge
    "^192\.168\."   # LAN
    "^10\."         # WireGuard / private
    "^127\."        # loopback
    "^100\.86\."    # Tailscale
    "^172\."        # Docker/Podman bridge ranges
)

# ─── State ────────────────────────────────────────────────────────────────────
declare -A IP_SCORES
declare -A BLOCKED_IPS

# ─── Functions ────────────────────────────────────────────────────────────────

is_whitelisted() {
    local ip="$1"
    for pattern in "${WHITELIST_PATTERNS[@]}"; do
        if [[ "$ip" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

add_score() {
    local ip="$1"
    local score="$2"
    local reason="$3"

    if is_whitelisted "$ip"; then
        return
    fi

    IP_SCORES["$ip"]=$(( ${IP_SCORES["$ip"]:-0} + score ))
    local total="${IP_SCORES[$ip]}"

    echo "$LOG_PREFIX $ip | reason=$reason | score=$total | $(date -u +%H:%M:%SZ)"

    if [[ "$total" -ge "$BLOCK_THRESHOLD" && -z "${BLOCKED_IPS[$ip]:-}" ]]; then
        block_ip "$ip" "$total" "$reason"
    fi
}

block_ip() {
    local ip="$1"
    local score="$2"
    local reason="$3"
    local ts
    ts=$(date -u +%s)

    BLOCKED_IPS["$ip"]=1

    # Block in nftables (1 hour TTL)
    sudo /usr/bin/nft add element inet filter blackhole "{ $ip timeout 1h }" 2>/dev/null || true

    # Add to scan queue
    echo "${ip}|${score}|${ts}|${reason}" >> "$SCAN_QUEUE"

    echo "$LOG_PREFIX BLOCKED+QUEUED $ip (score: $score)"
}

classify_suricata() {
    local line="$1"
    local ip

    # Extract source IP (before the ->)
    ip=$(echo "$line" | grep -oP '\d{1,3}(\.\d{1,3}){3}(?=:\d+\s*->)' | head -1)
    [[ -z "$ip" ]] && return

    local msg_lower
    msg_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')

    if echo "$msg_lower" | grep -qE "exploit|shellcode|injection|rce|overflow|execution"; then
        add_score "$ip" 3 "suricata_exploit"
    elif echo "$msg_lower" | grep -qE "c2|beacon|callback|rat |trojan|backdoor"; then
        add_score "$ip" 5 "suricata_c2"
    elif echo "$msg_lower" | grep -qE "scan|probe|sweep|brute|password"; then
        add_score "$ip" 1 "suricata_scan"
    else
        add_score "$ip" 2 "suricata_alert"
    fi
}

classify_cowrie() {
    local line="$1"
    local ip eventid

    ip=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('src_ip',''))" 2>/dev/null)
    [[ -z "$ip" ]] && return

    eventid=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('eventid',''))" 2>/dev/null)

    case "$eventid" in
        cowrie.login.success)    add_score "$ip" 4 "cowrie_login_success" ;;
        cowrie.login.failed)     add_score "$ip" 2 "cowrie_login_failed" ;;
        cowrie.command.input)    add_score "$ip" 3 "cowrie_command" ;;
        cowrie.session.file_download) add_score "$ip" 5 "cowrie_download" ;;
    esac
}

# ─── Main ─────────────────────────────────────────────────────────────────────

echo "$LOG_PREFIX Shield starting — threshold=$BLOCK_THRESHOLD"
echo "$LOG_PREFIX Monitoring: $SURICATA_LOG + $COWRIE_LOG"

# Ensure scan queue file exists
mkdir -p "$(dirname "$SCAN_QUEUE")"
touch "$SCAN_QUEUE"

# Monitor both logs in parallel subshells
tail -Fn0 "$SURICATA_LOG" 2>/dev/null | while read -r line; do
    [[ -n "$line" ]] && classify_suricata "$line"
done &

tail -Fn0 "$COWRIE_LOG" 2>/dev/null | while read -r line; do
    [[ -n "$line" ]] && classify_cowrie "$line"
done &

wait

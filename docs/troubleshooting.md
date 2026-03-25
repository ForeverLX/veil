# Veil Troubleshooting Runbook

Documented issues, root causes, and resolutions encountered during Veil
infrastructure builds. Maintained as an operational reference and
portfolio artifact demonstrating systematic debugging methodology.

---

## DNS & Networking

### Issue: .local.lan domains not resolving in browser
**Symptom:** Browser ignores system DNS for .local TLD, DNS_PROBE_POSSIBLE
**Root cause:** Browsers treat .local as mDNS (RFC 6762), bypassing system DNS
**Resolution:** Migrate all domains to .lan TLD — Pi-hole hosts file updated,
Caddyfile updated, all service URLs updated
**Lesson:** Never use .local for homelab DNS — use .lan, .home.arpa, or .internal

---

### Issue: NightForge loses all DNS when Cerberus goes offline
**Symptom:** All DNS resolution fails on NightForge including public internet
**Root cause:** Single DNS server (Pi-hole on Cerberus) with no fallback configured
**Resolution:** Added dual Cloudflare fallback to systemd-resolved drop-in at
/etc/systemd/resolved.conf.d/20-pihole.conf — DNS=192.168.0.251,
FallbackDNS=1.1.1.1 1.0.0.1, Domains=~lan
**Lesson:** Always configure fallback DNS — single point of failure for DNS
is unacceptable even in a homelab

---

### Issue: Cerberus not using its own Pi-hole for DNS
**Symptom:** curl https://search.lan fails on Cerberus, resolves fine externally
**Root cause:** /etc/resolv.conf managed by NetworkManager, pointing to 1.1.1.1
**Resolution:** Manually set resolv.conf to 192.168.0.251 as primary nameserver,
then used chattr +i to prevent NetworkManager from overwriting it
**Lesson:** Always verify the node hosting DNS is also using it

---

### Issue: Pasta container networking — containers cannot reach host services
**Symptom:** Homepage widgets returning errors, curl to host LAN IP fails
from inside container
**Root cause:** Pasta networking (rootless Podman default) — containers cannot
reach the host via its own LAN IP
**Resolution:** Use host.containers.internal for all intra-host container
communication. Added pasta rules to nftables for 169.254.0.0/16 in both
input and forward chains
**Lesson:** rootless Podman pasta networking requires host.containers.internal,
not the host LAN IP

---

### Issue: Mixed content blocking Netdata iframe
**Symptom:** Iframe blank, browser console shows Mixed Content error
**Root cause:** dash.lan served over HTTPS, Netdata iframe src was HTTP
**Resolution:** Point iframe src to https://netdata.lan via Caddy TLS proxy
**Lesson:** All resources on an HTTPS page must also be HTTPS

---

### Issue: Homepage SearXNG autocomplete failing
**Symptom:** No suggestions appearing, Homepage logs show httpProxy errors
**Root cause:** Homepage proxies suggestionUrl through its own backend container.
Container DNS could not resolve search.lan.
**Resolution:** Use host.containers.internal for suggestionUrl —
http://host.containers.internal:8888/autocompleter?q=
**Lesson:** Homepage proxies suggestion requests server-side — use internal
addressing, not .lan domains for widget URLs

---

### Issue: libvirt VMs cannot get DHCP lease after nftables migration
**Symptom:** VM gets no IP, DHCP discover packets visible on virbr0 via tcpdump
but dnsmasq never responds. journalctl shows no DHCPDISCOVER entries.
**Root cause:** nftables input chain policy DROP with no rule allowing UDP port 67
(DHCP). DHCP discover packets from VMs (source 0.0.0.0) don't match the existing
`ip saddr 192.168.122.0/24 iif "virbr0" accept` rule because they have no IP yet.
libvirt also defaults to iptables backend — must explicitly set nftables backend.
**Resolution:**
- Set firewall_backend = "nftables" in /etc/libvirt/network.conf
- Add `iif "virbr0" udp dport 67 accept` to nftables input chain
- Restart libvirtd after backend change
**Lesson:** When migrating to nftables, audit all services that inject firewall
rules (libvirt, Docker, etc.) and ensure backend alignment. DHCP is stateless
and pre-IP — it will never match source IP rules.

---

### Issue: Full mesh and DNS failure — Cerberus ethernet interface down
**Symptom:** NightForge browser DNS fails for all domains (external and .lan).
ping 8.8.8.8 succeeds from NightForge but all name resolution fails.
WireGuard handshake to Cerberus stale with 0 B received despite keepalive.
SSH to Cerberus on port 2121 hangs with no response.
**Root cause:** Physical ethernet interface (enp6s21f0u2c2) on Cerberus went
DOWN. Cascade: no internet → WireGuard cannot handshake → Pi-hole unreachable
→ all DNS fails on NightForge. nftables also failed to reload on interface
loss.
**Resolution:**
1. Physical access to Cerberus
2. `sudo ip link set enp6s21f0u2c2 up`
3. `sudo systemctl restart nftables`
4. `sudo wg-quick down wg0 && sudo wg-quick up wg0`
5. Verify: `sudo wg show` — confirm NightForge handshake is fresh
**Lesson:** Diagnose bottom-up — physical interface first, then routing, then
WireGuard, then DNS. A stale WireGuard handshake with keepalive active means
the underlying network path is broken, not WireGuard itself. SSH hanging on
the recovery port (2121) is a strong signal the interface is down, not a
firewall issue.

---

## Containers & Quadlets

### Issue: Podman socket missing after container restart
**Symptom:** Homepage docker integration failing, ENOENT podman.sock errors
**Root cause:** Podman socket service stopped, socket file removed
**Resolution:** systemctl --user start podman.socket and add
After=podman.socket + Requires=podman.socket to dependent Quadlets
**Lesson:** Podman socket is ephemeral — dependent services must declare it

---

### Issue: Quadlet health checks not evaluating
**Symptom:** Containers show "Up X minutes" without healthy/unhealthy status
**Root cause:** HealthCmd keys appended after [Install] section instead of
inside [Container] section — Quadlet generator silently ignored them
**Resolution:** Health check keys must be inside [Container] section.
Always verify with: /usr/lib/systemd/system-generators/podman-system-generator
--user --dryrun to confirm flags appear in generated ExecStart
**Lesson:** Always verify Quadlet output with --dryrun before restarting services

---

### Issue: Cowrie container has no shell utilities for health checks
**Symptom:** All health check commands fail — no curl, bash, ps, or pgrep
**Root cause:** Cowrie uses a minimal distroless-style image
**Resolution:** Skip health check for Cowrie. Monitor via
docker_local.containers_state chart in Netdata instead
**Lesson:** Not all containers support health checks — document as known
limitation rather than forcing an inappropriate solution

---

### Issue: SearXNG ownership conflict after first container run
**Symptom:** sed/chmod on config files returns "Operation not permitted"
**Root cause:** Container ran as UID 100976, took ownership of mounted config files
**Resolution:** sudo chown -R foreverlx:foreverlx ~/searxng/config/
Stop container before editing mounted config files
**Lesson:** Stop containers before editing their mounted config volumes

---

## WireGuard

### Issue: wg-quick fails with resolvconf signature mismatch
**Symptom:** wg-quick up/down fails, interface deleted immediately on exit
**Root cause:** /etc/resolv.conf modified outside resolvconf control
**Resolution:** sudo resolvconf -u then retry wg-quick up
**Lesson:** Run resolvconf -u before bringing up WireGuard if resolv.conf
was manually modified

---

### Issue: WireGuard hub-and-spoke peers cannot reach each other through hub
**Symptom:** NightForge cannot ping Tairn via 10.0.0.4, packets arrive at
Cerberus but are never forwarded. tcpdump on wg0 shows requests with no replies.
**Root cause:** Two compounding issues:
1. Kernel rp_filter (Reverse Path Filter) drops packets that arrive and would
   be forwarded back out the same interface — a security feature that treats
   same-interface forwarding as spoofing
2. nftables forward chain missing an explicit iif "wg0" oif "wg0" accept rule
   for same-interface forwarding (hairpin traffic)
**Resolution:**
- Set rp_filter=0 on wg0 and all interfaces via /etc/sysctl.d/99-wireguard.conf
- Add `iif "wg0" oif "wg0" accept` to nftables forward chain
- Add explicit host routes for each spoke: `ip route add 10.0.0.x/32 dev wg0`
  via PostUp in wg0.conf on Cerberus
**Lesson:** WireGuard hub-and-spoke requires explicit kernel configuration for
hairpin forwarding. rp_filter is a legitimate security control — document the
tradeoff. Cryptographic peer authentication in WireGuard mitigates the spoofing
risk that rp_filter normally guards against.

---

### Issue: Tairn WireGuard peer config drift after reboot

**Symptom:** Cerberus wg show shows Tairn endpoint as 192.168.1.145:50555 (NightForge's LAN IP), no handshake
**Root cause:** Stale endpoint cached from prior session, wrong IP written into Cerberus wg0.conf. Tairn config also had allowedIPs = 10.0.0.0/24 on Cerberus peer instead of 10.0.0.1/32, causing route conflict
**Resolution:** Corrected Cerberus wg0.conf — removed Tairn endpoint entirely (Tairn initiates). Corrected Tairn configuration.nix — 10.0.0.1/32 on Cerberus peer, removed direct endpoint from NightForge peer
**Lesson:** In hub-and-spoke, spokes initiate to hub only. Hub should have no endpoint for spokes — WireGuard learns it dynamically. Never set a spoke-to-spoke direct endpoint.

---

### Issue: vnet0 not attached to virbr0 after reboot (Tairn unreachable)

**Symptom:** ssh tairn fails, bridge link show empty, virbr0 shows NO-CARRIER, Tairn has no default route
**Root cause:** nftables failed at boot (referenced virbr0 before it existed), leaving libvirt without NAT rules. Race condition between libvirt VM start and bridge attachment — vnet0 created but never added to virbr0
**Resolution:** Removed virbr0 references from /etc/nftables.conf (libvirt manages its own rules). Created /etc/systemd/system/vnet0-bridge-fix.service — oneshot after libvirtd.service that runs ip link set vnet0 master virbr0 && ip link set vnet0 up
**Lesson:** When two subsystems have implicit ordering dependencies (libvirt bridge attachment vs nftables load), enforce it explicitly with a oneshot systemd service. After= is the correct tool, not manual intervention.

---

## TLS & Caddy

### Issue: Caddy CA certificate not trusted on Cerberus itself
**Symptom:** curl returns empty for https://*.lan from Cerberus
**Root cause:** Local CA cert installed on NightForge but not on Cerberus
**Resolution:** Copy root.crt from Caddy container to
/etc/ca-certificates/trust-source/anchors/ then run update-ca-trust run
**Lesson:** Install local CA on every node including the node running Caddy

---

## Pi-hole

### Issue: Pi-hole v6 Homepage widget incompatible
**Symptom:** Pi-hole widget shows no data
**Root cause:** Pi-hole v6 changed to session-based API authentication.
Homepage widget not updated for v6 API.
**Resolution:** Remove Pi-hole widget, monitor via direct link to pihole.lan/admin
**Lesson:** Check widget compatibility before upgrading self-hosted services

---

## System

### Issue: User Quadlets not starting after reboot on headless node
**Symptom:** All user services down after reboot with no active SSH session
**Root cause:** systemd user session not started without active login
**Resolution:** loginctl enable-linger foreverlx
**Lesson:** Always enable linger for headless nodes running user Quadlets

---

### Issue: Pi-hole slow to start after reboot
**Symptom:** DNS resolution unavailable for several minutes post-boot
**Root cause:** Hand-written systemd unit with no proper dependency ordering,
replaced by Quadlet with correct After= directives
**Resolution:** Migrate to system Quadlet — faster startup, proper dependency
management, consistent with rest of stack
**Lesson:** Hand-written podman-generate-systemd units are fragile —
always use Quadlets for new deployments

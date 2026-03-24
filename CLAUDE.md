# Veil — Infrastructure CLAUDE.md

## What This Repo Is
Veil is Darrius's three-node WireGuard mesh infrastructure. Everything in this repo
is production — changes have real consequences on a live mesh. Treat it accordingly.

## Node Registry
| Node | Role | OS | WireGuard IP | SSH |
|---|---|---|---|---|
| Cerberus | Edge / hub | Arch Linux (headless) | 10.0.0.1 | `ssh cerberus` or `ssh -p 2121 foreverlx@192.168.1.251` |
| NightForge | Operator workstation | Arch Linux | 10.0.0.3 | `ssh nightforge` |
| Tairn | Attack node / C2 | NixOS 24.11 | 10.0.0.4 | `ssh tairn` (WireGuard only) |

## Key Paths
**Cerberus:**
- `~/veil/` — primary config dir
- `~/.config/containers/systemd/` — Podman rootless Quadlets
- `~/caddy/Caddyfile` — Caddy reverse proxy
- `~/homepage/config/` — Homepage dashboard
- `/etc/wireguard/wg0.conf` — WireGuard config
- `/etc/nftables.conf` — firewall rules

**NightForge:**
- `~/Github/veil/` — this repo
- `~/Github/veil/docs/skills/` — skill files
- `~/Github/veil/docs/troubleshooting.md` — operational runbook
- `/etc/wireguard/wg0.conf` — WireGuard config
- `/etc/nftables.conf` — firewall rules
- `/etc/systemd/system/vnet0-bridge-fix.service` — libvirt bridge race fix

**Tairn:**
- `/etc/nixos/configuration.nix` — NixOS declarative config
- `~/Mythic/` — Mythic C2 installation

## Topology Rules (Hard)
- Hub-and-spoke via Cerberus — all traffic routes through 10.0.0.1
- Tairn initiates to Cerberus only — Cerberus has no endpoint entry for Tairn
- NightForge reaches Tairn via WireGuard (10.0.0.4) — never via 192.168.122.230
- Cerberus cannot reach 192.168.122.x — libvirt NAT is NightForge-only
- WireGuard on NightForge: `sudo resolvconf -u && sudo wg-quick up wg0`
- Tairn config changes always require `sudo nixos-rebuild switch` — Darrius executes only

## Container Runtime Split
- **Cerberus:** Podman rootless Quadlets (no daemon, security-first)
- **Tairn:** Docker (Mythic requires it)
- Never suggest switching either node's runtime

## What Claude Code May Do in This Repo
- Read any config file for context and debugging
- Suggest edits to WireGuard configs, NixOS config, nftables, Quadlet units
- Explain what a config change will do and what the failure mode is before suggesting it
- Update docs: `troubleshooting.md`, skill files, README
- Generate conventional commits and stage changes

## What Claude Code Must Never Do in This Repo
- Edit `wg0.conf` directly on any node — suggest the change, Darrius applies it
- Edit `configuration.nix` directly — suggest only, Darrius reviews and applies
- Run `sudo nixos-rebuild switch` — Darrius executes after reviewing diff
- Run `sudo wg-quick` or any `wg` command — Darrius executes manually
- Run `sudo systemctl` commands touching WireGuard services
- Assume a topology change is safe — always surface the failure mode first

## Locked Technical Decisions
| Decision | Choice | Rationale |
|---|---|---|
| C2 framework | Mythic | Industry recognized, rich agent ecosystem |
| Primary agent | Poseidon (Go, Linux) | Aligns with Linux/kernel focus |
| C2 network access | WireGuard-only (10.0.0.x) | Mirrors real engagement OPSEC |
| C2 VM OS | NixOS 24.11 | Declarative, reproducible, portfolio signal |
| Container runtime (Cerberus) | Podman rootless Quadlets | Security, no daemon |
| Container runtime (Tairn) | Docker | Mythic officially supports Docker |
| DNS | Pi-hole on Cerberus | .lan domains + ad blocking |
| TLS | Caddy local CA | Simple, automatic for .lan |

## Gitea Remote
`ssh://git@192.168.1.251:2222/foreverlx/veil.git`
Sync to both GitHub and Gitea on every push.

## Name History
This infrastructure was previously called "Nyx." It is now "Veil." Never reference Nyx
in any new work, commits, or documentation.

## Agent Routing
- Use `infra-auditor` for all read-only config review
- Use `router-escalation` for any topology changes or multi-node coordination

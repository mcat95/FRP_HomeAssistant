# Context: FRP add-on for Home Assistant (fork of WeeXnes/FRP_HomeAssistant)

This repo is a personal fork of https://github.com/WeeXnes/FRP_HomeAssistant, a small
Home Assistant add-on that runs `frpc` (Fast Reverse Proxy client) so Home Assistant can be
reached from the internet through a VPS. The upstream repo is unmaintained (all commits are from
Sept 2024, frp pinned to v0.60.0, amd64 only). This fork exists so the owner controls updates.

## Goal

Make the add-on installable and working on the owner's Home Assistant machine, which is
almost certainly ARM (the Install button in the Add-on Store is greyed out because upstream
`config.yaml` only lists `amd64`). Confirm the architecture with `ha info` on the HA console
(`arch:` line, probably `aarch64`).

## Overall architecture (already working, do not change)

```
frpc (this add-on, HA host network) ──TCP 7000──► frps on VPS (direct, no Traefik)
Browser ──HTTPS 443──► Traefik ──► frps container :8123 ──tunnel──► HA at 192.168.1.179:80
```

### VPS side (separate repo/folder, already deployed and tested)
- `frps` runs via docker compose, image `ghcr.io/fatedier/frps:v0.71.0`.
- Only port 7000 is published on the host. frpc connects there directly.
- Traefik (ports 80/443 only) routes `home.mcat.es` to the frps container's port 8123
  (routers `homemcat` / `homemcat-http`, certresolver `lets-encr`, Docker network `traefik`).
- `frps.toml`: `bindPort = 7000`, token auth (token hardcoded), `allowPorts = [{ single = 8123 }]`,
  no dashboard.
- **remote_port must be 8123**: frps only allows 8123 and Traefik forwards to it.
- Tunnel was verified end-to-end with a test frpc + `python3 -m http.server`.

### Home Assistant side
- HA local IP: `192.168.1.179`. **HA listens on port 80**, not 8123.
- `configuration.yaml` already contains (and is working):
  ```yaml
  http:
    server_port: 80
    use_x_forwarded_for: true
    trusted_proxies:
      - 192.168.1.179
  ```
  (`server_port: 80` must stay; losing it previously made HA unreachable.)
- Intended add-on options: server_addr = VPS IP/domain, server_port = 7000, token = frps token,
  local_ip = 192.168.1.179, **local_port = 80**, remote_port = 8123.

## Changes to make in this repo

All in `frp_addon/`:

1. **config.yaml**
   - Add architectures: `amd64, aarch64, armv7, armhf, i386`.
   - Bump `version` to `"0.71.0"` (HA needs a version change to notice updates).
   - Change the `token` schema type from `str` to `password` (masks it in the UI).
2. **Dockerfile**
   - Use `ARG BUILD_ARCH` (passed by the Supervisor) to pick the right frp release asset:
     amd64 → `amd64`, aarch64 → `arm64`, armv7/armhf → `arm`, i386 → `386`; fail otherwise.
   - frp `v0.71.0` (matches the server). Asset URL pattern:
     `https://github.com/fatedier/frp/releases/download/v${V}/frp_${V}_linux_${ARCH}.tar.gz`
     (arm64 and arm assets verified to exist).
   - Use `curl -fsSL ... | tar -xz -C /tmp`, move `frpc` to `/usr/local/bin/frpc`, clean up.
3. **run.sh**
   - Generate `/etc/frpc.toml` in the current TOML format instead of the deprecated INI
     (`serverAddr`, `serverPort`, `auth.method = "token"`, `auth.token`, one `[[proxies]]`
     entry: `name = "homeassistant"`, `type = "tcp"`, `localIP`, `localPort`, `remotePort`).
   - **Do not print the config / token to the log** (upstream did `cat /etc/frpc.ini`).
     Log a one-line summary with `bashio::log.info` instead.
   - `exec /usr/local/bin/frpc -c /etc/frpc.toml`.
4. Optionally: update `repository.yaml` (`url`, `maintainer`) and README to point at this fork,
   and fix README config docs (mention local_port may differ from 8123, remote_port must match
   the server's allowPorts).

A draft of these three files was already written in a previous chat; recreating them from the
spec above is fine.

## Gotchas learned so far
- frp runs config files through Go's template engine **including comments**. Never put `{{ }}`
  anywhere in a frp config (it caused `template: frp:1: missing value for command` on the server).
- No build.yaml exists, so the Supervisor uses its default base image per arch (Alpine-based,
  has bashio). Keep `apk add --no-cache curl` to be safe.
- The add-on uses `network: mode: host`, so frpc reaches HA via its LAN IP; that LAN IP is what
  HA sees as the proxy, hence it is in `trusted_proxies`.

## How to verify
1. Commit and push to the fork.
2. In HA: Settings → Add-ons → Add-on Store → ⋮ → Check for updates, refresh. Version 0.71.0
   should appear and Install should be clickable. First install builds locally (a few minutes).
3. Configure options as above, enable Start on boot + Watchdog, start.
4. Add-on log should show `login to server success` and `start proxy success`.
5. Open https://home.mcat.es. A 400 error means a trusted_proxies mismatch: check
   `ha core logs | grep -i forward` for the rejected IP.
6. Then set Settings → System → Network → Home Assistant URL → Internet = https://home.mcat.es,
   and enable MFA for all users.

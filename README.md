# TailDrop

Drag a file in, get a link anyone on your tailnet can download. Nothing leaves the tailnet, links
expire on their own, and the store never grows past 5 GB.

Three ways in: the **TailDrop** app (a floating drop target with the live link list), the Finder
Quick Action, or `tnshare` on the command line.

## Two destinations

| | `This Mac` (local) | `ovh1` (hosted) |
|---|---|---|
| Upload | none — clones the file locally | copies the file to ovh1 |
| Works while the Mac sleeps | no | yes |
| Who can download | only peers your ACL lets into this Mac | anyone the ACL lets into ovh1 |

Local is instant and private. Hosted survives sleep and reaches people your Mac's ACL blocks —
which, on this tailnet, is every contractor. `tnshare doctor` prints exactly who is on each side.

## How it works

Tailscale's macOS GUI build cannot serve files from disk — the sandbox blocks
`tailscale serve --set-path`. So local shares use proxy mode instead:

1. A LaunchAgent (`net.webdevs.tnshared`, `bin/tnshared.py`) runs an HTTP server on
   `127.0.0.1:8731`, unreachable from any network.
2. `tailscale serve --bg --https=8443 http://127.0.0.1:8731` publishes it at
   `https://<this-mac>.<tailnet>.ts.net:8443/` — tailnet only, real TLS cert.
3. `tnshare add FILE` clones the file into the share store under a random 24-hex token. On APFS the
   clone is copy-on-write: instant, no extra disk, and it keeps the daemon out of TCC-protected
   folders (Desktop, Documents, Downloads) that a LaunchAgent cannot read.

Hosted shares skip all that: the file goes to `ovh1`, which runs real `tailscaled` and can publish a
path directly. A transient systemd timer deletes it at expiry.

Unknown and expired tokens 404, path traversal is rejected, and `Range` requests work so large
downloads resume.

## Storage

The local store is capped at 5 GB (`TNSHARE_MAX_BYTES`). Adding a file past the ceiling revokes the
oldest shares until it fits, and reports which ones went. A single file bigger than the cap is
refused rather than half-shared. `tnshare du` shows usage — it counts allocated blocks, so APFS
clones are billed honestly at near zero.

## CLI

```bash
tnshare add [--ttl SECONDS] [--hosted] FILE...   # share; links are copied to the clipboard
tnshare hosted FILE...                           # same, forced to ovh1
tnshare list [--json]                            # live shares and time left
tnshare doctor                                   # who can reach local links, and the ACL fix
tnshare du                                       # store usage against the cap
tnshare stop TOKEN... | stop-all                 # revoke
```

## Install

```bash
./install.sh          # daemon, CLI, Finder Quick Actions
app/build-app.sh      # builds app/build/TailDrop.app
```

`install.sh` puts the CLI in `~/Library/Application Support/TailnetShare/bin/`, symlinks it into
`~/.local/bin`, loads the LaunchAgent, and installs the Quick Actions. The hosted side needs
`server/tnshare-host` at `/usr/local/bin/tnshare-host` on the server, reachable over SSH.

## Configuration

| Variable | Default |
|---|---|
| `TNSHARE_TTL` | `86400` (24h) |
| `TNSHARE_MAX_BYTES` | `5368709120` (5 GiB) |
| `TNSHARE_PORT` | `8731` (local HTTP) |
| `TNSHARE_HTTPS_PORT` | `8443` (Serve) |
| `TNSHARE_HOST_SSH` | the hosted server's SSH target |

## Limits

- Local links need this Mac awake, online and running Tailscale. Downloads resume after a wake.
- Everything is tailnet-only. Reaching people outside it would need `tailscale funnel`, which
  exposes the file to the public internet and is deliberately not wired up.
- The clone is taken at share time, so later edits to the original are not published.

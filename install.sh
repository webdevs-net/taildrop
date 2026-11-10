#!/bin/bash
# Installs the Tailnet Share daemon, CLI and Finder Quick Actions.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Library/Application Support/TailnetShare"
LABEL=net.webdevs.tnshared
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$APP/bin" "$APP/shares" "$HOME/Library/LaunchAgents" "$HOME/Library/Services"
install -m 755 "$SRC/bin/tnshare" "$SRC/bin/tnshared.py" "$APP/bin/"

# Put the CLI on PATH.
mkdir -p "$HOME/.local/bin"
ln -sf "$APP/bin/tnshare" "$HOME/.local/bin/tnshare"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$APP/bin/tnshared.py</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$APP/daemon.log</string>
  <key>StandardOutPath</key><string>$APP/daemon.log</string>
</dict>
</plist>
PLISTEOF

launchctl bootout "gui/$UID/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$PLIST"

"$SRC/make-quick-action.sh" "Send by Tailnet" "$SRC/actions/send-by-tailnet.sh"
"$SRC/make-quick-action.sh" "Stop Tailnet Shares" "$SRC/actions/stop-tailnet-shares.sh"
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

echo "Installed. CLI: $APP/bin/tnshare"

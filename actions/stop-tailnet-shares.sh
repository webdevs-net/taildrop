#!/bin/bash
# Quick Action body: revoke every active tailnet share.
export PATH="$HOME/Library/Application Support/TailnetShare/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
tnshare stop-all
osascript -e 'display notification "All tailnet share links revoked" with title "Send by Tailnet"'

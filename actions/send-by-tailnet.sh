#!/bin/bash
# Quick Action body: share the selected items and copy the links.
export PATH="$HOME/Library/Application Support/TailnetShare/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
out=$(tnshare add --hosted "$@" 2>&1) || {
  osascript -e "display notification \"${out//\"/}\" with title \"Send by Tailnet failed\""
  exit 1
}
count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
osascript -e "display notification \"$count link(s) copied to clipboard\" with title \"Send by Tailnet\" subtitle \"Served from ovh1 · expires in 24 hours\""

#!/bin/bash
# Stops and removes the AgentBridge launchd job. Leaves ~/.agentbridge (state, logs)
# and ~/AgentBridge-work (sandbox, pending proposals) in place so nothing is lost.
set -euo pipefail
LABEL="${AGENTBRIDGE_LABEL:-com.agentbridge.relay}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && echo "Stopped $LABEL" || echo "$LABEL was not running"
# Also clean up legacy label if present
launchctl bootout "gui/$(id -u)/com.voodoo.agentbridge" 2>/dev/null || true
[ -f "$PLIST" ] && rm "$PLIST" && echo "Removed $PLIST"
echo "Kept ~/.agentbridge and ~/AgentBridge-work. Delete them yourself if you want a clean slate."

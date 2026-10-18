#!/bin/bash
# AgentBridge relay installer for macOS.
# Verifies claude -p works, runs the containment self-test, then installs the launchd job.
# Nothing is installed if any check fails. Re-running is safe (it upgrades in place).
set -euo pipefail

ACCOUNT="${AGENTBRIDGE_ACCOUNT:-}"
RELAY_HOME="$HOME/.agentbridge"
WORK_DIR="$HOME/AgentBridge-work"
LABEL="${AGENTBRIDGE_LABEL:-com.agentbridge.relay}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
UID_NUM="$(id -u)"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nFAIL: %s\n' "$*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "This installer is for macOS."

step "Checking python3"
if [ -x "/opt/homebrew/bin/python3" ]; then
  PY="/opt/homebrew/bin/python3"
elif [ -x "/usr/local/bin/python3" ]; then
  PY="/usr/local/bin/python3"
elif command -v python3 >/dev/null 2>&1 && [ "$(command -v python3)" != "/usr/bin/python3" ]; then
  PY="$(command -v python3)"
else
  PY="/usr/bin/python3"
fi
[ -x "$PY" ] || fail "python3 not found. Install Python via Homebrew (brew install python) or Xcode Command Line Tools: xcode-select --install"
"$PY" -c 'import sys; assert sys.version_info >= (3,9), sys.version' \
  || fail "python3 is older than 3.9"
REAL_PY="$("$PY" -c 'import sys; print(sys.executable)')"
echo "    $PY ($("$PY" --version 2>&1)) [resolved: $REAL_PY]"

step "Checking the claude CLI"
CLAUDE_BIN="$(command -v claude || true)"
for c in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do
  [ -n "$CLAUDE_BIN" ] && break
  [ -x "$c" ] && CLAUDE_BIN="$c"
done
[ -n "$CLAUDE_BIN" ] || fail "claude not found. Install Claude Code, run 'claude' once to log in, then re-run."
CLAUDE_BIN="$(cd "$(dirname "$CLAUDE_BIN")" && pwd)/$(basename "$CLAUDE_BIN")"
echo "    $CLAUDE_BIN ($("$CLAUDE_BIN" --version 2>/dev/null || echo 'version unknown'))"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "    note: ANTHROPIC_API_KEY is set in this shell. The relay strips it so claude -p uses"
  echo "          your Claude Code login. Set AGENTBRIDGE_USE_API_KEY=1 to bill the API key instead."
fi

step "Finding the AgentBridge folder in Google Drive"
BRIDGE_DIR=""
for d in "$HOME/Library/CloudStorage/GoogleDrive-"*/*/AgentBridge "$HOME/Library/CloudStorage/GoogleDrive-"*/"AgentBridge"; do
  [ -d "$d" ] && { BRIDGE_DIR="$d"; break; }
done
if [ -z "$BRIDGE_DIR" ]; then
  echo "    Not found. Checklist:"
  echo "     - Google Drive for Desktop is installed and signed in"
  echo "     - The AgentBridge folder exists in My Drive (if shared with you, right-click -> Organize -> Add shortcut -> My Drive)"
  echo "     - The folder has synced locally (open it once in Finder)"
  fail "AgentBridge folder not found under ~/Library/CloudStorage"
fi
echo "    $BRIDGE_DIR"
ls "$BRIDGE_DIR" >/dev/null 2>&1 || fail "macOS blocked reading the Drive folder from this terminal. Allow access when prompted, then re-run."

step "Installing relay files"
mkdir -p "$RELAY_HOME/logs" "$WORK_DIR/pending"
chmod 700 "$RELAY_HOME"
install -m 700 "$SRC_DIR/relay.py" "$RELAY_HOME/relay.py"
echo '{"mcpServers": {}}' > "$RELAY_HOME/empty-mcp.json"
echo "    relay  : $RELAY_HOME"
echo "    sandbox: $WORK_DIR"

export AGENTBRIDGE_CLAUDE_BIN="$CLAUDE_BIN" AGENTBRIDGE_ACCOUNT="$ACCOUNT"

step "Diagnostics"
"$PY" "$RELAY_HOME/relay.py" --check || fail "Diagnostics failed (see above)."

step "Containment self-test (5 short claude -p runs, about 1-3 minutes)"
if ! "$PY" "$RELAY_HOME/relay.py" --selftest; then
  echo
  echo "    The relay was NOT scheduled. If only 'claude -p runs' failed, run 'claude' once"
  echo "    in a terminal to log in and re-run this script. Any other FAIL means the sandbox"
  echo "    is leaking on this Claude Code version: send the output above back to Claude."
  exit 1
fi

step "Installing the launchd job ($LABEL)"
PLIST_SRC="$SRC_DIR/agentbridge.plist"
[ -f "$PLIST_SRC" ] || PLIST_SRC="$SRC_DIR/com.voodoo.agentbridge.plist"
sed -e "s#__LABEL__#$LABEL#g" \
    -e "s#__PYTHON__#$PY#g" \
    -e "s#__RELAY_HOME__#$RELAY_HOME#g" \
    -e "s#__CLAUDE_DIR__#$(dirname "$CLAUDE_BIN")#g" \
    -e "s#__CLAUDE_BIN__#$CLAUDE_BIN#g" \
    -e "s#__ACCOUNT__#$ACCOUNT#g" \
    "$PLIST_SRC" > "$PLIST"
plutil -lint "$PLIST" >/dev/null || fail "Generated plist is invalid: $PLIST"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
launchctl kickstart -k "gui/$UID_NUM/$LABEL"

step "Waiting for the first heartbeat"
for _ in $(seq 1 12); do
  sleep 5
  [ -f "$RELAY_HOME/heartbeat.json" ] && break
done
if [ -f "$RELAY_HOME/heartbeat.json" ]; then
  cat "$RELAY_HOME/heartbeat.json"
  if grep -q '"permission_denied"' "$RELAY_HOME/heartbeat.json"; then
    echo
    echo "    The background job can't read Google Drive. Open System Settings > Privacy &"
    echo "    Security > Full Disk Access, click +, press Cmd+Shift+G, enter $REAL_PY, add it,"
    echo "    then run: launchctl kickstart -k gui/$UID_NUM/$LABEL"
  fi
else
  echo "    No heartbeat yet. Check $RELAY_HOME/logs/relay.log and launchd.err.log"
fi

cat <<EOF

Done. The relay polls every 20 seconds.
  Logs      : $RELAY_HOME/logs/relay.log
  Status    : cat $RELAY_HOME/heartbeat.json
  Pause     : touch $RELAY_HOME/PAUSE      (or put a file named PAUSE in the Drive folder)
  Resume    : rm $RELAY_HOME/PAUSE
  Proposals : $WORK_DIR/pending/   (side effects waiting for your review)
  Uninstall : $SRC_DIR/uninstall.sh
EOF

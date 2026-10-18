# Agent Prompt for AgentBridge Installation

Copy and paste the prompt below into your autonomous coding agent (**Claude Code**, **Google Antigravity**, **Hermes**, or **OpenClaw**) to install and verify AgentBridge on macOS.

---

```markdown
You are installing and verifying the AgentBridge relay daemon on this Mac.
AgentBridge connects Muse to a local restricted Claude agent runner via Google Drive.

Please execute the following steps strictly and report the verbatim output:

### Step 1: Pre-flight Verification
1. Verify macOS environment (`uname -s` must be Darwin).
2. Check python3. Prefer Homebrew python (`/opt/homebrew/bin/python3`) or find the resolved executable path:
   python3 -c "import sys; print(sys.executable)"
3. Verify the `claude` CLI is installed and logged in (`claude --version`).
4. Verify the Google Drive folder exists under:
   ~/Library/CloudStorage/GoogleDrive-<ACCOUNT>/*/AgentBridge
   (NOTE: If the folder was shared with you, ensure you added a shortcut to "My Drive" in Google Drive web UI so macOS syncs it to disk).

### Step 2: Verification of Configuration & Plist
In the `agentbridge` directory:
- Ensure `agentbridge.plist` specifies:
  <key>ProcessType</key>
  <string>Standard</string>
  (CRITICAL: Never use "Background" QoS, as APFS FileProvider will deadlock with EDEADLK).

### Step 3: Execution of Installer & Self-Tests
1. Run:
   chmod +x install.sh uninstall.sh
2. Run `./install.sh` (or `AGENTBRIDGE_ACCOUNT="your-email@gmail.com" ./install.sh`).
3. Allow the 5 containment self-tests to run. Do not skip any check. If any test fails, stop and report the error.

### Step 4: Verification of Daemon & Heartbeat
1. Wait 10 seconds and check daemon status:
   cat ~/.agentbridge/heartbeat.json
2. Check the logs:
   tail -n 25 ~/.agentbridge/logs/relay.log
   tail -n 25 ~/.agentbridge/logs/launchd.err.log

### Troubleshooting:
- If `heartbeat.json` shows `"status": "permission_denied"`, macOS TCC is blocking the daemon.
  Grant Full Disk Access to the resolved python executable (e.g., /opt/homebrew/bin/python3 or the path from sys.executable), then restart the daemon:
  launchctl kickstart -k gui/$(id -u)/com.agentbridge.relay
```

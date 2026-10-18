---
name: agentbridge-setup
description: Install, configure, verify, and troubleshoot the AgentBridge relay (Muse <-> Claude / Agent mailbox via Google Drive) on macOS.
---

# AgentBridge Setup & Troubleshooting Skill

This skill guides an autonomous coding agent (Claude Code, Antigravity, Hermes, or OpenClaw) to install, configure, verify, and supervise the AgentBridge relay on macOS.

---

## 1. System Overview

**AgentBridge** connects a mobile/external client (Muse) to a local macOS agent runner via a Google Drive folder mailbox:
- **`to_claude.jsonl`**: Written only by Muse; read by the relay daemon.
- **`to_muse.jsonl`**: Written only by the local relay; read by Muse.
- **`~/AgentBridge-work/`**: Isolated execution sandbox where `claude -p` runs with tool and path restrictions.
- **`~/.agentbridge/`**: Daemon configuration, watermarks, heartbeat, and logs (outside the sandbox).
- **`agentbridge.plist`**: A macOS `launchd` LaunchAgent that polls every 20 seconds.

---

## 2. Mandatory Pre-Flight Verification

Before running `install.sh` or launching the daemon, verify the following 3 requirements:

### A. Google Drive "Shared with me" vs "My Drive" (Gotcha 1)
- If the `AgentBridge` folder was shared with the user's Google account, macOS Google Drive for Desktop **does not sync it to disk** while it resides in "Shared with me".
- **Fix**: The user must open Google Drive in a web browser, locate the `AgentBridge` folder in "Shared with me", right-click → **Organize** → **Add shortcut** → choose **My Drive**.
- Once shortcutted, Google Drive creates a symlink in `~/Library/CloudStorage/GoogleDrive-<ACCOUNT>/My Drive/`.

### B. Python Binary & TCC Full Disk Access (Gotcha 2)
- macOS TCC blocks background `launchd` daemons from reading `~/Library/CloudStorage/` unless the **resolved executable binary** has Full Disk Access.
- **Warning**: `/usr/bin/python3` is a macOS shim that resolves to an Xcode CommandLineTools framework binary (e.g. `Python.app`). Adding `/usr/bin/python3` to Full Disk Access does **not** grant access to the daemon!
- **Fix**:
  1. Prefer `/opt/homebrew/bin/python3` or resolve the real binary:
     ```bash
     python3 -c 'import sys; print(sys.executable)'
     ```
  2. If the heartbeat reports `permission_denied`, open **System Settings > Privacy & Security > Full Disk Access**, click `+`, press `Cmd+Shift+G`, enter the resolved binary path, and grant access.

### C. Launchd ProcessType Standard (Gotcha 3)
- In the launchd plist (`agentbridge.plist`), **never** set `<key>ProcessType</key><string>Background</string>`.
- Background QoS on macOS causes `EDEADLK` (`[Errno 11] Resource deadlock avoided`) when reading APFS FileProvider virtual files (CloudStorage).
- **Fix**: Always use `<key>ProcessType</key><string>Standard</string>` (or omit `ProcessType`).

---

## 3. Installation Steps

### Step 1: Locate or Unpack AgentBridge
Ensure the files (`relay.py`, `install.sh`, `agentbridge.plist`, `uninstall.sh`) are present in a folder (e.g. `~/Downloads/agentbridge` or `~/agentbridge`).

### Step 2: Set Permissions
```bash
chmod +x install.sh uninstall.sh
```

### Step 3: Run the Installer
```bash
# Optional: specify custom account or service label:
export AGENTBRIDGE_ACCOUNT="user@gmail.com"
export AGENTBRIDGE_LABEL="com.agentbridge.relay"
./install.sh
```

The installer will:
1. Check Python 3.9+ and resolve the runtime binary.
2. Locate the `claude` CLI.
3. Locate `~/Library/CloudStorage/GoogleDrive-$ACCOUNT/.../AgentBridge`.
4. Deploy `relay.py` to `~/.agentbridge/` and prepare `~/AgentBridge-work/`.
5. Execute the 5 containment self-tests (`relay.py --selftest`).
6. Bootstrap and kickstart the launchd service `com.agentbridge.relay`.

---

## 4. Post-Install Verification & Supervision

Run the following checks to confirm end-to-end operation:

1. **Check Daemon Status & Heartbeat**:
   ```bash
   cat ~/.agentbridge/heartbeat.json
   ```
   - `status: "idle"`: Healthy and waiting for messages.
   - `status: "permission_denied"`: Needs Full Disk Access for the resolved python executable.
   - `status: "no_bridge_folder"`: Google Drive folder missing or not yet shortcutted to My Drive.

2. **Inspect Logs**:
   ```bash
   tail -n 30 ~/.agentbridge/logs/relay.log
   tail -n 30 ~/.agentbridge/logs/launchd.err.log
   ```

3. **Verify Launchd Job is Active**:
   ```bash
   launchctl list | grep agentbridge
   ```

4. **Kickstart / Restart Daemon**:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.agentbridge.relay
   ```

---

## 5. Day-to-Day Operations

| Action | Command / File |
| :--- | :--- |
| **Check Heartbeat** | `cat ~/.agentbridge/heartbeat.json` |
| **Stream Logs** | `tail -f ~/.agentbridge/logs/relay.log` |
| **Pause Relay** | `touch ~/.agentbridge/PAUSE` (or create a file named `PAUSE` in Google Drive) |
| **Resume Relay** | `rm ~/.agentbridge/PAUSE` |
| **Review Proposals** | `ls -la ~/AgentBridge-work/pending/` |
| **Uninstall** | `~/Downloads/agentbridge/uninstall.sh` |

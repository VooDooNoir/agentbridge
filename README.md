# AgentBridge

> **A secure, asynchronous file-drop mailbox bridge between Muse and local Mac AI agents (Claude Code, Google Antigravity, Hermes, and OpenClaw) via Google Drive.**

[![macOS](https://img.shields.io/badge/os-macOS%2012%2B-blue)](https://apple.com)
[![Python](https://img.shields.io/badge/python-3.9%2B-brightgreen)](https://python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Architecture Overview

AgentBridge creates a decoupled, highly-contained bridge between a mobile or cloud agent (**Muse**) and an autonomous coding agent running locally on your Mac (**Claude Code**, **Antigravity**, **Hermes**, or **OpenClaw**):

```
+-----------------------------------------------------------+
|                          MUSE                             |
|  (Mobile / Web Agent running on phone or cloud)          |
+-----------------------------------------------------------+
                              │
                    Writes to_claude.jsonl
                    Reads  to_muse.jsonl
                              ▼
+-----------------------------------------------------------+
|                Google Drive for Desktop                   |
|   ~/Library/CloudStorage/GoogleDrive-.../My Drive/        |
|                    AgentBridge/                           |
+-----------------------------------------------------------+
                              ▲
                    Reads  to_claude.jsonl
                    Writes to_muse.jsonl
                              │
+-----------------------------------------------------------+
|               AgentBridge Relay Daemon                    |
|      (macOS launchd: com.agentbridge.relay)               |
|   ~/.agentbridge/relay.py  (polls every 20s)              |
+-----------------------------------------------------------+
                              │
             Invokes restricted claude -p runner
                              ▼
+-----------------------------------------------------------+
|                 Sandboxed Workspace                       |
|   ~/AgentBridge-work/                                     |
|   - Deny rules for SSH, env, credentials, system folders  |
|   - Strictly isolated tools & empty MCP configuration     |
|   - Proposals written to ~/AgentBridge-work/pending/      |
+-----------------------------------------------------------+
```

---

## Repository Structure

```
.
├── README.md                      # Complete system documentation
├── PROMPT.md                      # One-shot copy-paste prompt for AI agents
├── MUSE_INSTRUCTIONS.md           # Standing instructions for Muse
├── relay.py                       # Core relay daemon (v1.0.1, Python 3.9+ stdlib only)
├── install.sh                     # Automated macOS installer & self-test suite
├── uninstall.sh                   # Clean uninstaller (preserves logs & proposals)
├── agentbridge.plist              # launchd service template (Standard QoS)
├── skills/
│   └── agentbridge-setup/
│       └── SKILL.md               # Portable Agent Skill (Claude/Antigravity/Hermes/OpenClaw)
└── LICENSE                        # MIT License
```

---

## Quick Start for Friends

If you have an autonomous coding agent on your Mac (Claude Code, Google Antigravity, Hermes, or OpenClaw):

1. **Clone or Download this repository**:
   ```bash
   git clone https://github.com/<YOUR_USER>/agentbridge.git
   cd agentbridge
   ```
2. **Google Drive Pre-flight**:
   - Ensure Google Drive for Desktop is signed in.
   - If the `AgentBridge` folder is shared with your Google account, open Google Drive in a web browser, find `AgentBridge` under **"Shared with me"**, right-click → **Organize** → **Add shortcut** → choose **My Drive** (*macOS CloudStorage will not sync folders to disk unless shortcutted*).
3. **Run Autonomous Agent Installation**:
   Open your agent in the repository directory and give it the prompt in [`PROMPT.md`](PROMPT.md).
4. **Set Up Muse**:
   Paste the instructions from [`MUSE_INSTRUCTIONS.md`](MUSE_INSTRUCTIONS.md) into Muse.

---

## Manual Installation

If you prefer installing directly from terminal:

```bash
chmod +x install.sh uninstall.sh

# If using a specific Google account:
export AGENTBRIDGE_ACCOUNT="your-email@gmail.com"

./install.sh
```

The installer performs 5 containment self-tests before scheduling the daemon:
1. Verifies `claude -p` execution.
2. Asserts reading outside sandbox (`~/.agentbridge`) is blocked.
3. Asserts writing outside sandbox is blocked.
4. Asserts outbound network/web access is blocked.
5. Asserts writing inside sandbox (`~/AgentBridge-work`) succeeds.

---

## 3 Critical macOS Gotchas (Solved in this Repo)

### 1. Google Drive "Shared with me" Sync
- Google Drive for Desktop on macOS **does not** sync items that only exist in "Shared with me".
- **Solution:** Right-click the folder in the web interface and click **Add shortcut to My Drive**. It will immediately appear under `~/Library/CloudStorage/GoogleDrive-<ACCOUNT>/My Drive/AgentBridge`.

### 2. TCC Full Disk Access & Python Shim
- macOS Full Disk Access (FDA) evaluates the **resolved binary**, not the `/usr/bin/python3` shim.
- **Solution:** `install.sh` preferentially detects Homebrew's `/opt/homebrew/bin/python3` and reports the exact resolved path (`sys.executable`) to add to System Settings > Privacy & Security > Full Disk Access if permissions are blocked.

### 3. FileProvider I/O Deadlock (EDEADLK)
- Setting `ProcessType=Background` in a launchd plist causes `[Errno 11] Resource deadlock avoided` when reading APFS FileProvider virtual files.
- **Solution:** `agentbridge.plist` specifies `ProcessType=Standard`.
---

## Security & Containment Model

- **File Deny Rules:** Reading `~/.ssh`, `~/.claude`, `~/.agentbridge`, `~/Library`, `~/Documents`, `~/Desktop`, `~/Downloads`, `/Volumes`, `/etc`, and any `.env` file is strictly denied.
- **Tool Restrictions:** Shell commands accept only benign read commands (`ls`, `wc`, `git status`). File editing is scoped exclusively to `./**`.
- **MCP Isolation:** Relayed runs enforce `--strict-mcp-config` with an empty config, preventing local MCP server leakage.
- **State Isolation:** The relay's watermarks, state, and logs live in `~/.agentbridge`, completely outside the agent's work directory (`~/AgentBridge-work`).
- **External Proposals:** Any proposed side effect outside the sandbox is written to `~/AgentBridge-work/pending/` for human review.

---

## Day-to-Day Operations

| Task | Command |
| :--- | :--- |
| **Check Heartbeat** | `cat ~/.agentbridge/heartbeat.json` |
| **View Live Logs** | `tail -f ~/.agentbridge/logs/relay.log` |
| **Pause Bridge** | `touch ~/.agentbridge/PAUSE` (or drop `PAUSE` into Google Drive) |
| **Resume Bridge** | `rm ~/.agentbridge/PAUSE` |
| **Review Proposals** | `ls -la ~/AgentBridge-work/pending/` |
| **Restart Daemon** | `launchctl kickstart -k gui/$(id -u)/com.agentbridge.relay` |
| **Uninstall** | `./uninstall.sh` (preserves state & pending proposals) |

---

## License

MIT © Supervoodoo

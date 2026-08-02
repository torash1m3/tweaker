# WIN11 TWEAKER v1.0

A zero-dependency, single-command Terminal User Interface (TUI) Windows 11 system optimizer written in pure PowerShell 5.1 / 7+.

![TUI Interface](https://img.shields.io/badge/Windows-11-blue.svg) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blueviolet.svg)

---

## 🚀 One-Line Execution Command

To run **WIN11 TWEAKER** on a clean Windows 11 system (no installation or external software required):

Open **PowerShell as Administrator** and execute:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/YOUR_USERNAME/tweaker/main/tweaker.ps1 | iex"
```

---

## ✨ Features

- **3-State Toggle Engine (`Space` bar):**
  - `[+] ENABLE` — Apply registry tweak / optimization
  - `[-] REVERT` — Restore Windows default setting
  - `[ ] SKIP` — Leave setting untouched
- **Live System State Inspection (`[SYS: ON]` / `[SYS: OFF]`):** Automatically detects which registry keys are currently active in your Windows system.
- **Developer Presets:** Gamer & Performance, Privacy & Security Hardening, Minimal Win10 Feel.
- **System Restore Point Manager:** Create, launch GUI (`rstrui`), or manage restore points with automatic 24-hour frequency bypass.
- **Winget Package Installer:** 1-click silent unattended installation for 7-Zip, Chrome, Telegram, VS Code, VLC.
- **Pre-Flight Confirmation Screen:** Review scheduled actions before applying.
- **Real-time Console Logging & Desktop Log Export:** Automatically saves `tweaker_log_<timestamp>.txt` to user's Desktop.

---

## 📁 Repository Structure

```text
tweaker/
├── tweaker.ps1              # Main entry point & TUI Engine
├── config.json              # App metadata and defaults
├── presets/                 # Developer Presets folder
│   ├── gamer_performance.json
│   ├── privacy_hardening.json
│   └── minimal_win10.json
├── implementation_plan.md   # Architectural specification
└── README.md                # Project documentation
```

---

## 🛠️ GitHub Push & Short Link Setup

1. **Initialize Git and push to GitHub:**
   ```powershell
   git init
   git add .
   git commit -m "Initial release v1.0"
   gh repo create tweaker --public --source=. --remote=origin --push
   ```

2. **Shorten URL for fast typing:**
   - Copy raw URL: `https://raw.githubusercontent.com/YOUR_USERNAME/tweaker/main/tweaker.ps1`
   - Shorten using [is.gd](https://is.gd) or [clck.ru](https://clck.ru) (e.g. `is.gd/mywin11`)
   - Now run on fresh Win11 with:
     ```powershell
     powershell -ExecutionPolicy Bypass -Command "iwr -useb is.gd/mywin11 | iex"
     ```

# WIN11 TWEAKER v2.0

Personal, zero-dependency Windows 11 bootstrap toolkit for PowerShell 5.1 and 7+.
It is optimized for repeatable setup of a fresh personal system: registry policies,
Appx cleanup, removal of Windows restrictions, Winget installation and exact registry rollback.

## Usage

Version 2 is modular, so clone or download the complete repository.

```powershell
.\tweaker.ps1                                      # interactive TUI
.\tweaker.ps1 -Mode Inspect                        # read-only inspection
.\tweaker.ps1 -Mode Plan -Profile FreshInstall     # read-only preview
.\tweaker.ps1 -Mode Apply -Profile FreshInstall    # apply, self-elevates
.\tweaker.ps1 -Mode Revert -Snapshot .\state\ID.json
```

## Architecture

```text
tweaker.ps1               Minimal CLI/bootstrap
config.json               Runtime defaults
src/Core.ps1              Catalog, profiles, plans, snapshots and execution
src/Providers.ps1         Registry, Appx, files, Winget and restore points
src/Tui.ps1               Interactive console client
tweaks/*.psd1             Declarative tweak catalog
profiles/*.psd1           Personal profiles
data/winget-apps.psd1     Winget package catalog
state/                    Machine snapshots (Git ignored)
logs/                     JSON execution logs (Git ignored)
tests/Validation.Tests.ps1 Read-only tests without Pester
```

The TUI and CLI use the same engine. UI code never changes the system directly.

## Profiles

- `FreshInstall` — complete clean-system baseline.
- `Gamer & Performance` — responsiveness and bloat cleanup.
- `Privacy & Hardening` — telemetry, notifications and restrictions off.
- `Minimal Win10 Feel` — classic menu, silent UAC and no widgets.

Profiles may inherit other profiles through `Extends` and override actions by tweak ID.

## State and rollback

Before applying reversible registry tweaks, the engine records whether each key/value
existed, its type and exact value. Revert restores that snapshot instead of guessing
Windows defaults. Appx removal and removal of Zone.Identifier streams are marked
irreversible, so the UI does not offer a fake rollback.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Validation.Tests.ps1
```

Validation parses every PowerShell file, imports the module, and checks tweak IDs,
profile references and catalog structure. It never applies system changes.

## Adding a registry tweak

Add a record to `tweaks/*.psd1`:

```powershell
@{
    Id='ExampleTweak'; Category='Interface'; Title='Example tweak'
    Description='What it changes'; Provider='Registry'; Reversible=$true
    Restart='Explorer'
    Operations=@(@{Path='HKCU:\Software\Example';Name='Enabled';Type='DWord';Value=0})
}
```

Run validation after changing the catalog or profiles.

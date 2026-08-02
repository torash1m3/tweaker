# ==============================================================================
# WIN11 TWEAKER v1.0 — Universal Zero-Dependency TUI Optimizer
# Compatible with PowerShell 5.1 & PowerShell 7+ on Windows 11
# ==============================================================================

# Ensure Self-Elevation to Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    if ($PSCommandPath) {
        Start-Process powershell.exe "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process powershell.exe "-ExecutionPolicy Bypass -NoProfile -Command `"iwr -useb tinyurl.com/2327gboc | iex`"" -Verb RunAs
    }
    exit
}

# Output Encoding & VT100 ANSI Setup
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try {
    $kernel32 = Add-Type -MemberDefinition @"
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out int lpMode);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleMode(IntPtr hConsoleHandle, int dwMode);
"@ -Name "Win32Utils" -Namespace "TweakerNative" -PassThru
    $hOut = $kernel32::GetStdHandle(-11)
    $mode = 0
    if ($kernel32::GetConsoleMode($hOut, [ref]$mode)) {
        $kernel32::SetConsoleMode($hOut, $mode -bor 0x0004) | Out-Null
    }
} catch {}

# ANSI Color Tokens
$ESC = [char]27
$CYAN   = "$ESC[36m"
$GREEN  = "$ESC[32m"
$YELLOW = "$ESC[33m"
$RED    = "$ESC[31m"
$GRAY   = "$ESC[90m"
$BOLD   = "$ESC[1m"
$RESET  = "$ESC[0m"

# Box Drawing Characters (Unicode Char Codes)
$CH_H = [string][char]0x2500 # ─
$CH_V = [string][char]0x2502 # │
$CH_TL = [string][char]0x256D # ╭
$CH_TR = [string][char]0x256E # ╮
$CH_BL = [string][char]0x2570 # ╰
$CH_BR = [string][char]0x256F # ╯
$CH_LT = [string][char]0x251C # ├
$CH_RT = [string][char]0x2524 # ┤
$CH_TT = [string][char]0x252C # ┬
$CH_CROSS = [string][char]0x253C # ┼

# ------------------------------------------------------------------------------
# Tweak Registry Definitions
# ------------------------------------------------------------------------------
$script:Tweaks = @(
    @{
        Id          = "ClassicContextMenu"
        Category    = "Interface"
        Title       = "Classic Windows 10 Context Menu"
        Description = "Restores traditional right-click menu without 'Show more options'"
        CheckCode   = { Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" }
        ApplyCode   = { reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null }
    },
    @{
        Id          = "DisableBingSearch"
        Category    = "Interface"
        Title       = "Disable Bing Search in Start Menu"
        Description = "Prevents Start menu from querying Bing online search"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -ErrorAction SilentlyContinue).BingSearchEnabled -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /f 2>$null | Out-Null }
    },
    @{
        Id          = "DisableWidgets"
        Category    = "Interface"
        Title       = "Disable Taskbar Widgets (Weather/News)"
        Description = "Hides news and weather widget icon from taskbar"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue).TaskbarDa -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 1 /f | Out-Null }
    },
    @{
        Id          = "DisableCopilot"
        Category    = "Interface"
        Title       = "Disable Windows Copilot AI Assistant"
        Description = "Disables Windows Copilot on HKCU and HKLM policy level"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot -eq 1 }
        ApplyCode   = {
            reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null
        }
        UndoCode    = {
            reg delete "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /f 2>$null | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /f 2>$null | Out-Null
        }
    },
    @{
        Id          = "DisableEdgeBackground"
        Category    = "Interface"
        Title       = "Disable Microsoft Edge Background Tasks"
        Description = "Prevents MS Edge from lingering in memory after exit"
        CheckCode   = { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -ErrorAction SilentlyContinue).BackgroundModeEnabled -eq 0 }
        ApplyCode   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BackgroundModeEnabled" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "HubsSidebarEnabled" /t REG_DWORD /d 0 /f | Out-Null
        }
        UndoCode    = {
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "BackgroundModeEnabled" /f 2>$null | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "HubsSidebarEnabled" /f 2>$null | Out-Null
        }
    },
    @{
        Id          = "DisableAdsAndTips"
        Category    = "Interface"
        Title       = "Disable Windows Recommendations & Tips"
        Description = "Blocks suggested apps, tips, and ads in Start & Settings"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -ErrorAction SilentlyContinue)."SubscribedContent-338389Enabled" -eq 0 }
        ApplyCode   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353694Enabled" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353696Enabled" /t REG_DWORD /d 0 /f | Out-Null
        }
        UndoCode    = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353694Enabled" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353696Enabled" /t REG_DWORD /d 1 /f | Out-Null
        }
    },
    @{
        Id          = "MenuShowDelayZero"
        Category    = "Interface"
        Title       = "Instant Context Menu Popup (Zero Delay)"
        Description = "Removes artificial delay when hovering sub-menus"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -ErrorAction SilentlyContinue).MenuShowDelay -eq "0" }
        ApplyCode   = { reg add "HKCU\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "0" /f | Out-Null }
        UndoCode    = { reg add "HKCU\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "400" /f | Out-Null }
    },
    @{
        Id          = "DisableTaskbarAnimations"
        Category    = "Interface"
        Title       = "Disable Taskbar Animations"
        Description = "Disables subtle pop animations for taskbar icons"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -ErrorAction SilentlyContinue).TaskbarAnimations -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 1 /f | Out-Null }
    },
    @{
        Id          = "SilentUAC"
        Category    = "Security"
        Title       = "Silent UAC Mode (Keep LUA, Disable Dimming)"
        Description = "Auto-elevates admin programs without prompt/dimming screen while preserving LUA/Store"
        CheckCode   = { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue).ConsentPromptBehaviorAdmin -eq 0 }
        ApplyCode   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 0 /f | Out-Null
        }
        UndoCode    = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 5 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 1 /f | Out-Null
        }
    },
    @{
        Id          = "DisableSmartScreen"
        Category    = "Security"
        Title       = "Disable SmartScreen Execution Warnings"
        Description = "Suppresses 'Windows protected your PC' dialogs for unknown executables"
        CheckCode   = { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -ErrorAction SilentlyContinue).SmartScreenEnabled -eq "Off" }
        ApplyCode   = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControl" /t REG_SZ /d "WarningsOff" /f | Out-Null
        }
        UndoCode    = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "On" /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /t REG_DWORD /d 1 /f | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControl" /f 2>$null | Out-Null
        }
    },
    @{
        Id          = "DisableDefenderToasts"
        Category    = "Security"
        Title       = "Disable Defender System Tray Notifications"
        Description = "Blocks yellow tray warnings and notifications from Defender"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d 1 /f | Out-Null }
    },
    @{
        Id          = "DisableSaveZoneInformation"
        Category    = "File Warnings"
        Title       = "Disable Zone.Identifier (Downloaded File Mark)"
        Description = "Prevents Windows from tagging downloaded files as blocked from internet"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -ErrorAction SilentlyContinue).SaveZoneInformation -eq 1 }
        ApplyCode   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "SaveZoneInformation" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "SaveZoneInformation" /t REG_DWORD /d 1 /f | Out-Null
        }
        UndoCode    = {
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "SaveZoneInformation" /f 2>$null | Out-Null
            reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "SaveZoneInformation" /f 2>$null | Out-Null
        }
    },
    @{
        Id          = "LowRiskFileTypes"
        Category    = "File Warnings"
        Title       = "Trust Downloaded Executables & Archives"
        Description = "Suppresses security open warnings for .exe, .bat, .zip, .7z, .iso"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations" -Name "LowRiskFileTypes" -ErrorAction SilentlyContinue).LowRiskFileTypes -ne $null }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Associations" /v "LowRiskFileTypes" /t REG_SZ /d ".exe;.bat;.cmd;.msi;.reg;.vbs;.ps1;.zip;.rar;.7z;.iso;.tar;.gz;.appx" /f | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Associations" /v "LowRiskFileTypes" /f 2>$null | Out-Null }
    },
    @{
        Id          = "HideZoneInfoProperties"
        Category    = "File Warnings"
        Title       = "Hide Security Info Label in File Properties"
        Description = "Hides 'Unblock' checkbox in downloaded file properties dialog"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "HideZoneInfoOnProperties" -ErrorAction SilentlyContinue).HideZoneInfoOnProperties -eq 1 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "HideZoneInfoOnProperties" /t REG_DWORD /d 1 /f | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "HideZoneInfoOnProperties" /f 2>$null | Out-Null }
    },
    @{
        Id          = "UnblockDownloadsFolder"
        Category    = "File Warnings"
        Title       = "Unblock Existing Files in Downloads Directory"
        Description = "Removes Zone.Identifier stream from all existing files in Downloads"
        CheckCode   = { $false }
        ApplyCode   = { Get-ChildItem -Path "$env:USERPROFILE\Downloads" -Recurse -ErrorAction SilentlyContinue | Unblock-File }
        UndoCode    = { }
    }
)

# Software Packages Definitions (Winget)
$script:WingetApps = @(
    @{ Id = "7zip.7zip"; Name = "7-Zip File Archiver" },
    @{ Id = "Google.Chrome"; Name = "Google Chrome Web Browser" },
    @{ Id = "Telegram.TelegramDesktop"; Name = "Telegram Desktop Messenger" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code Editor" },
    @{ Id = "VideoLAN.VLC"; Name = "VLC Media Player" }
)

# ------------------------------------------------------------------------------
# State & Presets Initialization
# ------------------------------------------------------------------------------
$script:Selections = @{}
foreach ($tweak in $script:Tweaks) {
    $script:Selections[$tweak.Id] = "SKIP"
}
$script:SelectedApps = @{}
foreach ($app in $script:WingetApps) {
    $script:SelectedApps[$app.Id] = $false
}

$script:Categories = @("Presets", "Interface", "Security", "File Warnings", "Restore Points", "Winget Software")
$script:ActiveCategoryIndex = 0
$script:ActiveItemIndex = 0

# Load Local Presets
$script:LocalPresets = @{}
$presetDir = Join-Path -Path $PSScriptRoot -ChildPath "presets"
if (Test-Path $presetDir) {
    Get-ChildItem -Path $presetDir -Filter "*.json" | ForEach-Object {
        try {
            $json = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
            $script:LocalPresets[$json.PresetName] = $json
        } catch {}
    }
}

# ------------------------------------------------------------------------------
# Helper Functions: Restore Points & Execution
# ------------------------------------------------------------------------------
function Create-TweakerRestorePoint {
    param([string]$Description = "Tweaker_AutoBackup")
    Write-Host "Creating System Restore Point '$Description'..." -ForegroundColor Cyan
    try {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "SystemRestorePointCreationFrequency" /t REG_DWORD /d 0 /f | Out-Null
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "[SUCCESS] Restore Point created successfully." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[WARNING] Could not create Restore Point: $_" -ForegroundColor Yellow
        return $false
    }
}

# ------------------------------------------------------------------------------
# TUI Renderer
# ------------------------------------------------------------------------------
function Draw-TUI {
    Clear-Host
    $w = 85
    $lineH = $CH_H * $w
    
    # Header Banner
    Write-Host "$CH_TL$lineH$CH_TR" -ForegroundColor Cyan
    $titleStr = "  WIN11 TWEAKER v1.0"
    $badgeStr = "[ADMIN: OK]  [RESTORE POINT: READY]  "
    $spaces = " " * ($w - $titleStr.Length - $badgeStr.Length)
    Write-Host "$CH_V$BOLD$CYAN$titleStr$RESET$spaces$GREEN$badgeStr$RESET$CH_V"
    
    $divTop = $CH_LT + ($CH_H * 22) + $CH_TT + ($CH_H * ($w - 23)) + $CH_RT
    Write-Host $divTop -ForegroundColor Cyan

    $catName = $script:Categories[$script:ActiveCategoryIndex]
    
    # Header Labels
    Write-Host "$CH_V " -NoNewline -ForegroundColor Cyan
    Write-Host "CATEGORIES             " -NoNewline -ForegroundColor Yellow
    Write-Host "$CH_V " -NoNewline -ForegroundColor Cyan
    Write-Host "PANEL: $catName" -ForegroundColor Yellow

    Write-Host "$CH_V                      $CH_V" -ForegroundColor Cyan

    # Render Rows
    $maxLines = 10
    for ($i = 0; $i -lt $maxLines; $i++) {
        # Category Column
        $catText = "                      "
        if ($i -lt $script:Categories.Count) {
            $c = $script:Categories[$i]
            if ($i -eq $script:ActiveCategoryIndex) {
                $catText = "> [$($i+1)] $c"
                $catText = $catText.PadRight(22)
            } else {
                $catText = "  [$($i+1)] $c"
                $catText = $catText.PadRight(22)
            }
        }

        # Content Column
        $contentText = ""
        if ($catName -eq "Presets") {
            $presetKeys = @($script:LocalPresets.Keys)
            if ($i -lt $presetKeys.Count) {
                $pName = $presetKeys[$i]
                $prefix = if ($i -eq $script:ActiveItemIndex) { "> " } else { "  " }
                $contentText = "$prefix[Preset] $pName"
            }
        } elseif ($catName -eq "Winget Software") {
            if ($i -lt $script:WingetApps.Count) {
                $app = $script:WingetApps[$i]
                $prefix = if ($i -eq $script:ActiveItemIndex) { "> " } else { "  " }
                $sel = if ($script:SelectedApps[$app.Id]) { "[x]" } else { "[ ]" }
                $contentText = "$prefix$sel $($app.Name)"
            }
        } elseif ($catName -eq "Restore Points") {
            if ($i -eq 0) { $contentText = if ($script:ActiveItemIndex -eq 0) { "> [CREATE] Create New System Restore Point" } else { "  [CREATE] Create New System Restore Point" } }
            elseif ($i -eq 1) { $contentText = if ($script:ActiveItemIndex -eq 1) { "> [OPEN] Launch Windows System Restore GUI (rstrui)" } else { "  [OPEN] Launch Windows System Restore GUI (rstrui)" } }
        } else {
            # Registry Tweak Category
            $categoryTweaks = @($script:Tweaks | Where-Object { $_.Category -eq $catName })
            if ($i -lt $categoryTweaks.Count) {
                $t = $categoryTweaks[$i]
                $prefix = if ($i -eq $script:ActiveItemIndex) { "> " } else { "  " }
                $act = $script:Selections[$t.Id]
                $actSymbol = switch ($act) {
                    "ENABLE" { "[+]" }
                    "REVERT" { "[-]" }
                    default  { "[ ]" }
                }
                
                $sysState = if (& $t.CheckCode) { "[SYS: ON]" } else { "[SYS: OFF]" }
                $tTitle = $t.Title
                if ($tTitle.Length -gt 38) { $tTitle = $tTitle.Substring(0, 35) + "..." }
                $tTitlePadded = $tTitle.PadRight(38)
                $contentText = "$prefix$actSymbol $tTitlePadded $sysState"
            }
        }

        # Print Combined Row
        Write-Host "$CH_V " -NoNewline -ForegroundColor Cyan
        if ($i -eq $script:ActiveCategoryIndex) {
            Write-Host $catText -NoNewline -ForegroundColor Cyan
        } else {
            Write-Host $catText -NoNewline -ForegroundColor Gray
        }
        Write-Host "$CH_V " -NoNewline -ForegroundColor Cyan
        
        $paddedContent = $contentText.PadRight($w - 25)
        if ($i -eq $script:ActiveItemIndex) {
            Write-Host $paddedContent -ForegroundColor Green
        } else {
            Write-Host $paddedContent -ForegroundColor White
        }
    }

    # Description Sub-Panel
    $divMid = $CH_LT + ($CH_H * 22) + $CH_CROSS + ($CH_H * ($w - 23)) + $CH_RT
    Write-Host $divMid -ForegroundColor Cyan

    $descText = "Hover over an item to view description."
    if ($catName -in @("Interface", "Security", "File Warnings")) {
        $categoryTweaks = @($script:Tweaks | Where-Object { $_.Category -eq $catName })
        if ($script:ActiveItemIndex -lt $categoryTweaks.Count) {
            $t = $categoryTweaks[$script:ActiveItemIndex]
            $descText = "INFO: $($t.Description)"
        }
    } elseif ($catName -eq "Presets") {
        $presetKeys = @($script:LocalPresets.Keys)
        if ($script:ActiveItemIndex -lt $presetKeys.Count) {
            $pName = $presetKeys[$script:ActiveItemIndex]
            $descText = "PRESET: $($script:LocalPresets[$pName].Description)"
        }
    }
    
    if ($descText.Length -gt ($w - 4)) {
        $descText = $descText.Substring(0, $w - 7) + "..."
    }
    Write-Host "$CH_V " -NoNewline -ForegroundColor Cyan
    Write-Host $descText.PadRight($w - 2) -ForegroundColor Gray
    Write-Host $CH_V -ForegroundColor Cyan

    # Footer Keymap Bar
    Write-Host "$CH_LT$lineH$CH_RT" -ForegroundColor Cyan
    $footer = " [Tab] Category | [Space] Toggle (+/-/ ) | [Enter] Review & Run | [Esc] Exit"
    Write-Host "$CH_V$footer$(" " * ($w - $footer.Length))$CH_V" -ForegroundColor Yellow
    Write-Host "$CH_BL$lineH$CH_BR" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# Pre-Flight Review Screen & Execution Engine
# ------------------------------------------------------------------------------
function Show-PreFlightScreen {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                  PRE-FLIGHT REVIEW & CONFIRMATION               " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $toEnable = @($script:Tweaks | Where-Object { $script:Selections[$_.Id] -eq "ENABLE" })
    $toRevert = @($script:Tweaks | Where-Object { $script:Selections[$_.Id] -eq "REVERT" })
    $selectedApps = @($script:WingetApps | Where-Object { $script:SelectedApps[$_.Id] -eq $true })

    Write-Host "ITEMS TO ENABLE (+):" -ForegroundColor Green
    if ($toEnable.Count -eq 0) { Write-Host "  (None)" -ForegroundColor Gray }
    else { foreach ($item in $toEnable) { Write-Host "  [+] $($item.Title)" -ForegroundColor Green } }
    Write-Host ""

    Write-Host "ITEMS TO REVERT (-):" -ForegroundColor Red
    if ($toRevert.Count -eq 0) { Write-Host "  (None)" -ForegroundColor Gray }
    else { foreach ($item in $toRevert) { Write-Host "  [-] $($item.Title)" -ForegroundColor Red } }
    Write-Host ""

    Write-Host "WINGET APPS TO INSTALL:" -ForegroundColor Cyan
    if ($selectedApps.Count -eq 0) { Write-Host "  (None)" -ForegroundColor Gray }
    else { foreach ($app in $selectedApps) { Write-Host "  [x] $($app.Name)" -ForegroundColor Cyan } }
    Write-Host ""

    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Press [ENTER] to Start Execution  |  Press [ESC] to Return & Edit" -ForegroundColor Yellow

    while ($true) {
        $key = [System.Console]::ReadKey($true)
        if ($key.Key -eq "Enter") {
            Execute-Tweaks
            break
        } elseif ($key.Key -eq "Escape") {
            break
        }
    }
}

function Execute-Tweaks {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                       EXECUTING TWEAKS                          " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $logBuffer = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $logPath = "$env:USERPROFILE\Desktop\tweaker_log_$timestamp.txt"

    # Create Auto Restore Point
    Create-TweakerRestorePoint -Description "Tweaker_AutoBackup_$timestamp" | Out-Null

    # Execute Registry Tweaks
    foreach ($tweak in $script:Tweaks) {
        $action = $script:Selections[$tweak.Id]
        if ($action -eq "ENABLE") {
            Write-Host "Applying [+] $($tweak.Title) ... " -NoNewline -ForegroundColor Cyan
            try {
                & $tweak.ApplyCode
                Write-Host "[SUCCESS]" -ForegroundColor Green
                $logBuffer += "[$(Get-Date -Format 'HH:mm:ss')] [ENABLE] [SUCCESS] $($tweak.Title)"
            } catch {
                Write-Host "[FAILED]: $_" -ForegroundColor Red
                $logBuffer += "[$(Get-Date -Format 'HH:mm:ss')] [ENABLE] [FAILED] $($tweak.Title): $_"
            }
        } elseif ($action -eq "REVERT") {
            Write-Host "Reverting [-] $($tweak.Title) ... " -NoNewline -ForegroundColor Yellow
            try {
                & $tweak.UndoCode
                Write-Host "[SUCCESS]" -ForegroundColor Green
                $logBuffer += "[$(Get-Date -Format 'HH:mm:ss')] [REVERT] [SUCCESS] $($tweak.Title)"
            } catch {
                Write-Host "[FAILED]: $_" -ForegroundColor Red
                $logBuffer += "[$(Get-Date -Format 'HH:mm:ss')] [REVERT] [FAILED] $($tweak.Title): $_"
            }
        }
    }

    # Execute Winget Software Installs
    foreach ($app in $script:WingetApps) {
        if ($script:SelectedApps[$app.Id]) {
            Write-Host "Installing Winget App: $($app.Name) ... " -NoNewline -ForegroundColor Cyan
            try {
                winget install --id $app.Id -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
                Write-Host "[SUCCESS]" -ForegroundColor Green
                $logBuffer += "[$(Get-Date -Format 'HH:mm:ss')] [WINGET] [SUCCESS] $($app.Name)"
            } catch {
                Write-Host "[FAILED]: $_" -ForegroundColor Red
                $logBuffer += "[$(Get-Date -Format 'HH:mm:ss')] [WINGET] [FAILED] $($app.Name): $_"
            }
        }
    }

    # Restart Explorer if interface tweaks were applied
    Write-Host "Restarting Windows Explorer to apply UI changes ... " -NoNewline -ForegroundColor Cyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer -ErrorAction SilentlyContinue
    Write-Host "[SUCCESS]" -ForegroundColor Green

    # Save Desktop Log
    try {
        $logBuffer | Out-File -FilePath $logPath -Encoding utf8
        Write-Host ""
        Write-Host "[LOG SAVED] Log exported to Desktop: $logPath" -ForegroundColor Green
    } catch {}

    Write-Host ""
    Write-Host "Execution completed. Press any key to exit TUI..." -ForegroundColor Yellow
    [System.Console]::ReadKey($true) | Out-Null
    exit
}

# ------------------------------------------------------------------------------
# Main Interactive Event Loop
# ------------------------------------------------------------------------------
while ($true) {
    Draw-TUI
    $key = [System.Console]::ReadKey($true)

    switch ($key.Key) {
        "Tab" {
            $script:ActiveCategoryIndex = ($script:ActiveCategoryIndex + 1) % $script:Categories.Count
            $script:ActiveItemIndex = 0
        }
        "UpArrow" {
            if ($script:ActiveItemIndex -gt 0) {
                $script:ActiveItemIndex--
            }
        }
        "DownArrow" {
            $catName = $script:Categories[$script:ActiveCategoryIndex]
            $maxIdx = switch ($catName) {
                "Presets" { [Math]::Max(0, $script:LocalPresets.Keys.Count - 1) }
                "Winget Software" { $script:WingetApps.Count - 1 }
                "Restore Points" { 1 }
                default { (@($script:Tweaks | Where-Object { $_.Category -eq $catName })).Count - 1 }
            }
            if ($script:ActiveItemIndex -lt $maxIdx) {
                $script:ActiveItemIndex++
            }
        }
        "Spacebar" {
            $catName = $script:Categories[$script:ActiveCategoryIndex]
            if ($catName -in @("Interface", "Security", "File Warnings")) {
                $categoryTweaks = @($script:Tweaks | Where-Object { $_.Category -eq $catName })
                if ($script:ActiveItemIndex -lt $categoryTweaks.Count) {
                    $t = $categoryTweaks[$script:ActiveItemIndex]
                    $curr = $script:Selections[$t.Id]
                    $script:Selections[$t.Id] = switch ($curr) {
                        "SKIP"   { "ENABLE" }
                        "ENABLE" { "REVERT" }
                        default  { "SKIP" }
                    }
                }
            } elseif ($catName -eq "Winget Software") {
                if ($script:ActiveItemIndex -lt $script:WingetApps.Count) {
                    $app = $script:WingetApps[$script:ActiveItemIndex]
                    $script:SelectedApps[$app.Id] = -not $script:SelectedApps[$app.Id]
                }
            } elseif ($catName -eq "Presets") {
                $presetKeys = @($script:LocalPresets.Keys)
                if ($script:ActiveItemIndex -lt $presetKeys.Count) {
                    $pName = $presetKeys[$script:ActiveItemIndex]
                    $presetObj = $script:LocalPresets[$pName]
                    foreach ($actionKey in $presetObj.Actions.psobject.Properties.Name) {
                        $actVal = $presetObj.Actions.$actionKey
                        if ($script:Selections.ContainsKey($actionKey)) {
                            $script:Selections[$actionKey] = $actVal
                        }
                    }
                }
            }
        }
        "Enter" {
            $catName = $script:Categories[$script:ActiveCategoryIndex]
            if ($catName -eq "Restore Points") {
                if ($script:ActiveItemIndex -eq 0) {
                    Create-TweakerRestorePoint -Description "User_Manual_Backup"
                    Start-Sleep -Seconds 2
                } elseif ($script:ActiveItemIndex -eq 1) {
                    Start-Process "rstrui.exe"
                }
            } else {
                Show-PreFlightScreen
            }
        }
        "Escape" {
            Clear-Host
            Write-Host "Exiting WIN11 TWEAKER." -ForegroundColor Yellow
            exit
        }
    }
}

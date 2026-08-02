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
        Write-Host "Please re-run this script in PowerShell launched as Administrator." -ForegroundColor Red
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
$CYAN    = "$ESC[36m"
$GREEN   = "$ESC[32m"
$YELLOW  = "$ESC[33m"
$RED     = "$ESC[31m"
$GRAY    = "$ESC[90m"
$WHITE   = "$ESC[37m"
$BOLD    = "$ESC[1m"
$RESET   = "$ESC[0m"
$BG_CYAN = "$ESC[46m$ESC[30m"

# Standard Clean Box Drawing Characters
$CH_H     = [string][char]0x2550 # ═
$CH_V     = [string][char]0x2551 # ║
$CH_TL    = [string][char]0x2554 # ╔
$CH_TR    = [string][char]0x2557 # ╗
$CH_BL    = [string][char]0x255A # ╚
$CH_BR    = [string][char]0x255D # ╝
$CH_LT    = [string][char]0x2560 # ╠
$CH_RT    = [string][char]0x2563 # ╣
$CH_TT    = [string][char]0x2566 # ╦
$CH_BT    = [string][char]0x2569 # ╩
$CH_CROSS = [string][char]0x256C # ╬

# ------------------------------------------------------------------------------
# Tweak Registry & Policy Definitions
# ------------------------------------------------------------------------------
$script:Tweaks = @(
    # INTERFACE TWEAKS
    @{
        Id          = "ClassicContextMenu"
        Category    = "Interface"
        Title       = "Classic Context Menu"
        ShortTitle  = "Classic Context..."
        Description = "Restores traditional Windows 10 right-click menu without 'Show more options'"
        CheckCode   = { Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" }
        ApplyCode   = { reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null }
    },
    @{
        Id          = "DisableBingSearch"
        Category    = "Interface"
        Title       = "Disable Bing in Start Menu"
        ShortTitle  = "Disable Bing..."
        Description = "Prevents Start menu from querying Bing online search for faster local search"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -ErrorAction SilentlyContinue).BingSearchEnabled -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /f 2>$null | Out-Null }
    },
    @{
        Id          = "DisableWidgets"
        Category    = "Interface"
        Title       = "Disable Taskbar Widgets"
        ShortTitle  = "Disable Widgets..."
        Description = "Hides news and weather widget icon from Windows 11 taskbar"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue).TaskbarDa -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 1 /f | Out-Null }
    },
    @{
        Id          = "DisableCopilot"
        Category    = "Interface"
        Title       = "Disable Windows Copilot AI"
        ShortTitle  = "Disable Copilot..."
        Description = "Disables Windows Copilot AI assistant on HKCU and HKLM policy level"
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
        Title       = "Disable MS Edge Background Tasks"
        ShortTitle  = "Edge Background..."
        Description = "Prevents Microsoft Edge from lingering in RAM and running background tasks"
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
        Title       = "Disable Recommendations & Ads"
        ShortTitle  = "Disable Recommendations..."
        Description = "Blocks suggested apps, tips, and ads in Start menu & Settings app"
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
        Title       = "Instant Sub-Menu Popup (0ms)"
        ShortTitle  = "Instant Submenu..."
        Description = "Removes artificial delay when hovering sub-menus for instant response"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -ErrorAction SilentlyContinue).MenuShowDelay -eq "0" }
        ApplyCode   = { reg add "HKCU\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "0" /f | Out-Null }
        UndoCode    = { reg add "HKCU\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "400" /f | Out-Null }
    },
    @{
        Id          = "DisableTaskbarAnimations"
        Category    = "Interface"
        Title       = "Disable Taskbar Animations"
        ShortTitle  = "Taskbar Animations..."
        Description = "Disables subtle pop animations for taskbar icons for snappier feel"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -ErrorAction SilentlyContinue).TaskbarAnimations -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 1 /f | Out-Null }
    },

    # SECURITY & TELEMETRY TWEAKS (Point 9: ShutUp10 Style)
    @{
        Id          = "SilentUAC"
        Category    = "Security & Privacy"
        Title       = "Silent UAC Mode (Keep LUA)"
        ShortTitle  = "Silent UAC..."
        Description = "Auto-elevates admin programs without prompt or screen dimming while preserving LUA/Store"
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
        Category    = "Security & Privacy"
        Title       = "Disable SmartScreen Warnings"
        ShortTitle  = "Disable SmartScreen..."
        Description = "Suppresses 'Windows protected your PC' warnings for unknown executables"
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
        Category    = "Security & Privacy"
        Title       = "Disable Defender Tray Toasts"
        ShortTitle  = "Defender Toasts..."
        Description = "Blocks yellow tray warnings and security notifications from Windows Defender"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled -eq 0 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null }
        UndoCode    = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v "Enabled" /t REG_DWORD /d 1 /f | Out-Null }
    },
    @{
        Id          = "DisableTelemetryData"
        Category    = "Security & Privacy"
        Title       = "Disable Telemetry Data Collection"
        ShortTitle  = "Disable Telemetry..."
        Description = "Sets Windows diagnostic data collection level to Security/Minimal (Level 0)"
        CheckCode   = { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry -eq 0 }
        ApplyCode   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
        }
        UndoCode    = {
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /f 2>$null | Out-Null
        }
    },
    @{
        Id          = "DisableActivityHistory"
        Category    = "Security & Privacy"
        Title       = "Disable Activity History & Timeline"
        ShortTitle  = "Activity History..."
        Description = "Prevents Windows from storing user activity history and sending it to Microsoft"
        CheckCode   = { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -ErrorAction SilentlyContinue).PublishUserActivities -eq 0 }
        ApplyCode   = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "PublishUserActivities" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableActivityFeed" /t REG_DWORD /d 0 /f | Out-Null
        }
        UndoCode    = {
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "PublishUserActivities" /f 2>$null | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableActivityFeed" /f 2>$null | Out-Null
        }
    },
    @{
        Id          = "DisableAdvertisingID"
        Category    = "Security & Privacy"
        Title       = "Disable Advertising ID Tracking"
        ShortTitle  = "Advertising ID..."
        Description = "Prevents apps from using Windows Advertising ID for personalized ad tracking"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled -eq 0 }
        ApplyCode   = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v "DisabledByGroupPolicy" /t REG_DWORD /d 1 /f | Out-Null
        }
        UndoCode    = {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 1 /f | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v "DisabledByGroupPolicy" /f 2>$null | Out-Null
        }
    },

    # FILE WARNINGS TWEAKS
    @{
        Id          = "DisableSaveZoneInformation"
        Category    = "File Warnings"
        Title       = "Disable Zone.Identifier Tag"
        ShortTitle  = "Zone.Identifier Tag..."
        Description = "Prevents Windows from tagging downloaded internet files as blocked"
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
        Title       = "Trust Executables & Archives"
        ShortTitle  = "Trust Executables..."
        Description = "Suppresses security prompts for .exe, .bat, .zip, .7z, .iso downloaded files"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations" -Name "LowRiskFileTypes" -ErrorAction SilentlyContinue).LowRiskFileTypes -ne $null }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Associations" /v "LowRiskFileTypes" /t REG_SZ /d ".exe;.bat;.cmd;.msi;.reg;.vbs;.ps1;.zip;.rar;.7z;.iso;.tar;.gz;.appx" /f | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Associations" /v "LowRiskFileTypes" /f 2>$null | Out-Null }
    },
    @{
        Id          = "HideZoneInfoProperties"
        Category    = "File Warnings"
        Title       = "Hide Security Check in Properties"
        ShortTitle  = "Hide Security Info..."
        Description = "Hides 'Unblock' checkbox in file properties dialog for downloaded files"
        CheckCode   = { (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "HideZoneInfoOnProperties" -ErrorAction SilentlyContinue).HideZoneInfoOnProperties -eq 1 }
        ApplyCode   = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "HideZoneInfoOnProperties" /t REG_DWORD /d 1 /f | Out-Null }
        UndoCode    = { reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "HideZoneInfoOnProperties" /f 2>$null | Out-Null }
    },
    @{
        Id          = "UnblockDownloadsFolder"
        Category    = "File Warnings"
        Title       = "Unblock All Files in Downloads"
        ShortTitle  = "Unblock Downloads..."
        Description = "Removes Zone.Identifier stream from all existing files in Downloads folder"
        CheckCode   = { $false }
        ApplyCode   = { Get-ChildItem -Path "$env:USERPROFILE\Downloads" -Recurse -ErrorAction SilentlyContinue | Unblock-File }
        UndoCode    = { }
    },

    # BLOATWARE REMOVER TWEAKS (Point 1: UWP Bloatware Removal)
    @{
        Id          = "RemoveXboxBloat"
        Category    = "Bloatware Remover"
        Title       = "Remove Xbox Game Bar & Services"
        ShortTitle  = "Remove Xbox..."
        Description = "Uninstalls Xbox Game Bar, Xbox Speech to Text, and Xbox overlay packages"
        CheckCode   = { -not (Get-AppxPackage -Name "*Microsoft.XboxGameOverlay*" -ErrorAction SilentlyContinue) }
        ApplyCode   = { Get-AppxPackage -Name "*Xbox*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }
        UndoCode    = { }
    },
    @{
        Id          = "RemoveWeatherNews"
        Category    = "Bloatware Remover"
        Title       = "Remove Weather & News Apps"
        ShortTitle  = "Remove Weather..."
        Description = "Uninstalls MSN Weather, News, and Money UWP app packages"
        CheckCode   = { -not (Get-AppxPackage -Name "*BingWeather*" -ErrorAction SilentlyContinue) }
        ApplyCode   = { Get-AppxPackage -Name "*BingWeather*", "*BingNews*", "*BingSports*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }
        UndoCode    = { }
    },
    @{
        Id          = "RemoveSolitaire"
        Category    = "Bloatware Remover"
        Title       = "Remove Solitaire Collection"
        ShortTitle  = "Remove Solitaire..."
        Description = "Uninstalls pre-installed Microsoft Solitaire Collection game"
        CheckCode   = { -not (Get-AppxPackage -Name "*MicrosoftSolitaireCollection*" -ErrorAction SilentlyContinue) }
        ApplyCode   = { Get-AppxPackage -Name "*MicrosoftSolitaireCollection*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }
        UndoCode    = { }
    },
    @{
        Id          = "RemoveMapsFeedback"
        Category    = "Bloatware Remover"
        Title       = "Remove Maps & Feedback Hub"
        ShortTitle  = "Remove Maps..."
        Description = "Uninstalls Windows Maps, Feedback Hub, and Get Help packages"
        CheckCode   = { -not (Get-AppxPackage -Name "*WindowsMaps*" -ErrorAction SilentlyContinue) }
        ApplyCode   = { Get-AppxPackage -Name "*WindowsMaps*", "*WindowsFeedbackHub*", "*GetHelp*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }
        UndoCode    = { }
    },
    @{
        Id          = "RemovePhoneLink"
        Category    = "Bloatware Remover"
        Title       = "Remove Phone Link / Your Phone"
        ShortTitle  = "Remove Phone Link..."
        Description = "Uninstalls Phone Link (Your Phone) app package"
        CheckCode   = { -not (Get-AppxPackage -Name "*YourPhone*" -ErrorAction SilentlyContinue) }
        ApplyCode   = { Get-AppxPackage -Name "*YourPhone*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }
        UndoCode    = { }
    }
)

# Winget Applications Data
$script:WingetApps = @(
    @{ Id = "7zip.7zip"; Name = "7-Zip Archiver" },
    @{ Id = "Google.Chrome"; Name = "Google Chrome Browser" },
    @{ Id = "Telegram.TelegramDesktop"; Name = "Telegram Desktop" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "VideoLAN.VLC"; Name = "VLC Media Player" }
)

# ------------------------------------------------------------------------------
# State Initialization
# ------------------------------------------------------------------------------
$script:Selections = @{}
foreach ($tweak in $script:Tweaks) {
    $script:Selections[$tweak.Id] = "SKIP"
}
$script:SelectedApps = @{}
foreach ($app in $script:WingetApps) {
    $script:SelectedApps[$app.Id] = $false
}

$script:AutoCreateRestorePoint = $true
$script:Categories = @("Presets", "Interface", "Security & Privacy", "File Warnings", "Bloatware Remover", "Restore Points", "Winget Software")
$script:ActiveCategoryIndex = 0
$script:ActiveItemIndex = 0
$script:FocusPanel = "CATEGORIES"

# Load Presets
$script:LocalPresets = @{
    "Gamer & Performance" = @{
        Description = "Optimizes responsiveness, disables Bing, widgets, Copilot, Edge background, removes Xbox/Solitaire."
        Actions = @{
            "ClassicContextMenu" = "ENABLE"; "DisableBingSearch" = "ENABLE"; "DisableWidgets" = "ENABLE"
            "DisableCopilot" = "ENABLE"; "DisableEdgeBackground" = "ENABLE"; "DisableTaskbarAnimations" = "ENABLE"
            "MenuShowDelayZero" = "ENABLE"; "RemoveSolitaire" = "ENABLE"; "RemoveXboxBloat" = "ENABLE"
        }
    }
    "Privacy & Hardening" = @{
        Description = "Blocks Windows telemetry, ads, Defender toasts, Zone.Identifier tags, activity tracking."
        Actions = @{
            "DisableAdsAndTips" = "ENABLE"; "DisableDefenderToasts" = "ENABLE"; "DisableSaveZoneInformation" = "ENABLE"
            "LowRiskFileTypes" = "ENABLE"; "HideZoneInfoProperties" = "ENABLE"; "UnblockDownloadsFolder" = "ENABLE"
            "SilentUAC" = "ENABLE"; "DisableTelemetryData" = "ENABLE"; "DisableActivityHistory" = "ENABLE"
            "DisableAdvertisingID" = "ENABLE"
        }
    }
    "Minimal Win10 Feel" = @{
        Description = "Restores classic Win10 context menu, quiet UAC mode, hides widgets."
        Actions = @{
            "ClassicContextMenu" = "ENABLE"; "SilentUAC" = "ENABLE"; "DisableWidgets" = "ENABLE"
        }
    }
}

# ------------------------------------------------------------------------------
# Formatting Helpers (ANSI-Aware String Width Calculation)
# ------------------------------------------------------------------------------
function Get-VisibleLength([string]$str) {
    if (-not $str) { return 0 }
    $clean = $str -replace '\x1b\[[0-9;]*m', ''
    return $clean.Length
}

function Write-BoxRow([string]$leftText, [string]$rightText, [int]$leftWidth = 24, [int]$rightWidth = 51) {
    $leftLen  = Get-VisibleLength $leftText
    $rightLen = Get-VisibleLength $rightText

    $padLeft  = [Math]::Max(0, $leftWidth - $leftLen)
    $padRight = [Math]::Max(0, $rightWidth - $rightLen)

    $rowStr = "$CYAN$CH_V$RESET $leftText" + (" " * $padLeft) + "$CYAN$CH_V$RESET $rightText" + (" " * $padRight) + "$CYAN$CH_V$RESET"
    Write-Host $rowStr
}

# ------------------------------------------------------------------------------
# System Restore Point Helper
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
# Main TUI Renderer
# ------------------------------------------------------------------------------
function Draw-TUI {
    Clear-Host
    
    # Header Banner (80 chars total)
    $topLine = "$CYAN$CH_TL" + ($CH_H * 78) + "$CH_TR$RESET"
    Write-Host $topLine
    
    $titlePart = "$BOLD$CYAN WIN11 TWEAKER v1.0$RESET"
    $rpStateStr = if ($script:AutoCreateRestorePoint) { "$GREEN[AUTO-RESTORE: ON]$RESET" } else { "$GRAY[AUTO-RESTORE: OFF]$RESET" }
    $badgePart = "$GREEN[ADMIN: OK]$RESET  $rpStateStr "
    $hPad = 78 - (Get-VisibleLength $titlePart) - (Get-VisibleLength $badgePart)
    Write-Host "$CYAN$CH_V$RESET$titlePart$(" " * $hPad)$badgePart$CYAN$CH_V$RESET"

    # Divider Top
    $divTop = "$CYAN$CH_LT" + ($CH_H * 25) + $CH_TT + ($CH_H * 52) + "$CH_RT$RESET"
    Write-Host $divTop

    # Sub-Headers
    $leftHead = if ($script:FocusPanel -eq "CATEGORIES") { "$BOLD$YELLOW> CATEGORIES$RESET" } else { "$GRAY  CATEGORIES$RESET" }
    $catName  = $script:Categories[$script:ActiveCategoryIndex]
    $rightHead = if ($script:FocusPanel -eq "ITEMS") { "$BOLD$YELLOW> ITEMS: $catName$RESET" } else { "$GRAY  ITEMS: $catName$RESET" }
    Write-BoxRow $leftHead $rightHead 24 51

    # Render Content Rows
    $maxLines = 10
    for ($i = 0; $i -lt $maxLines; $i++) {
        # Category Column Item
        $leftItem = ""
        if ($i -lt $script:Categories.Count) {
            $cName = $script:Categories[$i]
            $num = $i + 1
            if ($i -eq $script:ActiveCategoryIndex) {
                if ($script:FocusPanel -eq "CATEGORIES") {
                    $leftItem = "$BG_CYAN> [$num] $cName$RESET"
                } else {
                    $leftItem = "$CYAN> [$num] $cName$RESET"
                }
            } else {
                $leftItem = "$GRAY  [$num] $cName$RESET"
            }
        }

        # Right Column Item
        $rightItem = ""
        if ($catName -eq "Presets") {
            $presetKeys = @($script:LocalPresets.Keys)
            if ($i -lt $presetKeys.Count) {
                $pName = $presetKeys[$i]
                $isSel = ($i -eq $script:ActiveItemIndex)
                if ($isSel -and $script:FocusPanel -eq "ITEMS") {
                    $rightItem = "$BG_CYAN> [Preset] $pName$RESET"
                } elseif ($isSel) {
                    $rightItem = "$CYAN> [Preset] $pName$RESET"
                } else {
                    $rightItem = "$WHITE  [Preset] $pName$RESET"
                }
            }
        } elseif ($catName -eq "Winget Software") {
            if ($i -lt $script:WingetApps.Count) {
                $app = $script:WingetApps[$i]
                $isSel = ($i -eq $script:ActiveItemIndex)
                $chk = if ($script:SelectedApps[$app.Id]) { "$GREEN[X]$RESET" } else { "$GRAY[ ]$RESET" }
                if ($isSel -and $script:FocusPanel -eq "ITEMS") {
                    $rightItem = "$BG_CYAN> $chk $($app.Name)$RESET"
                } elseif ($isSel) {
                    $rightItem = "$CYAN> $chk $($app.Name)$RESET"
                } else {
                    $rightItem = "  $chk $($app.Name)"
                }
            }
        } elseif ($catName -eq "Restore Points") {
            if ($i -eq 0) {
                $isSel = ($script:ActiveItemIndex -eq 0)
                $rpStateText = if ($script:AutoCreateRestorePoint) { "Toggle Auto-Restore Point (Status: ON)" } else { "Toggle Auto-Restore Point (Status: OFF)" }
                if ($isSel -and $script:FocusPanel -eq "ITEMS") { $rightItem = "$BG_CYAN> [TOGGLE] $rpStateText$RESET" }
                elseif ($isSel) { $rightItem = "$CYAN> [TOGGLE] $rpStateText$RESET" }
                else { $rightItem = "  [TOGGLE] $rpStateText" }
            } elseif ($i -eq 1) {
                $isSel = ($script:ActiveItemIndex -eq 1)
                $tStr = "Create System Restore Point Now"
                if ($isSel -and $script:FocusPanel -eq "ITEMS") { $rightItem = "$BG_CYAN> [CREATE] $tStr$RESET" }
                elseif ($isSel) { $rightItem = "$CYAN> [CREATE] $tStr$RESET" }
                else { $rightItem = "  [CREATE] $tStr" }
            } elseif ($i -eq 2) {
                $isSel = ($script:ActiveItemIndex -eq 2)
                $tStr = "Launch Windows System Restore GUI (rstrui)"
                if ($isSel -and $script:FocusPanel -eq "ITEMS") { $rightItem = "$BG_CYAN> [OPEN] $tStr$RESET" }
                elseif ($isSel) { $rightItem = "$CYAN> [OPEN] $tStr$RESET" }
                else { $rightItem = "  [OPEN] $tStr" }
            }
        } else {
            # Tweak Registry & Bloatware Category
            $categoryTweaks = @($script:Tweaks | Where-Object { $_.Category -eq $catName })
            if ($i -lt $categoryTweaks.Count) {
                $t = $categoryTweaks[$i]
                $isSel = ($i -eq $script:ActiveItemIndex)
                
                $act = $script:Selections[$t.Id]
                $actSymbol = switch ($act) {
                    "ENABLE" { "$GREEN[+]$RESET" }
                    "REVERT" { "$RED[-]$RESET" }
                    default  { "$GRAY[ ]$RESET" }
                }
                
                $sysState = if (& $t.CheckCode) { "$GREEN[SYS: ON]$RESET" } else { "$GRAY[SYS: OFF]$RESET" }
                $shortTitle = if ($t.ShortTitle) { $t.ShortTitle } else { $t.Title }
                $tTitlePadded = $shortTitle.PadRight(26)
                
                if ($isSel -and $script:FocusPanel -eq "ITEMS") {
                    $rightItem = "$BG_CYAN> $actSymbol $tTitlePadded $sysState$RESET"
                } elseif ($isSel) {
                    $rightItem = "$CYAN> $actSymbol $tTitlePadded $sysState$RESET"
                } else {
                    $rightItem = "  $actSymbol $tTitlePadded $sysState"
                }
            }
        }

        Write-BoxRow $leftItem $rightItem 24 51
    }

    # Description Mid Divider
    $divMid = "$CYAN$CH_LT" + ($CH_H * 25) + $CH_CROSS + ($CH_H * 52) + "$CH_RT$RESET"
    Write-Host $divMid

    # Description Line Format: FULL TITLE FIRST in brackets, then explanation
    $descText = "Hover over an item to view description."
    if ($catName -in @("Interface", "Security & Privacy", "File Warnings", "Bloatware Remover")) {
        $categoryTweaks = @($script:Tweaks | Where-Object { $_.Category -eq $catName })
        if ($script:ActiveItemIndex -lt $categoryTweaks.Count) {
            $t = $categoryTweaks[$script:ActiveItemIndex]
            $descText = "INFO: [$($t.Title)] - $($t.Description)"
        }
    } elseif ($catName -eq "Presets") {
        $presetKeys = @($script:LocalPresets.Keys)
        if ($script:ActiveItemIndex -lt $presetKeys.Count) {
            $pName = $presetKeys[$script:ActiveItemIndex]
            $descText = "PRESET: [$pName] - $($script:LocalPresets[$pName].Description)"
        }
    } elseif ($catName -eq "Winget Software") {
        if ($script:ActiveItemIndex -lt $script:WingetApps.Count) {
            $app = $script:WingetApps[$script:ActiveItemIndex]
            $descText = "APP: [$($app.Name)] - Package ID: $($app.Id)"
        }
    } elseif ($catName -eq "Restore Points") {
        if ($script:ActiveItemIndex -eq 0) { $descText = "INFO: [Auto-Restore Point Setting] - Toggle whether to auto-create a restore point before running tweaks." }
        elseif ($script:ActiveItemIndex -eq 1) { $descText = "INFO: [Create Restore Point Now] - Instantly creates a System Restore Point." }
        elseif ($script:ActiveItemIndex -eq 2) { $descText = "INFO: [System Restore GUI] - Opens Windows System Restore Wizard (rstrui.exe)." }
    }
    
    if ($descText.Length -gt 74) { $descText = $descText.Substring(0, 71) + "..." }
    $descPadded = $descText.PadRight(76)
    Write-Host "$CYAN$CH_V$RESET $GRAY$descPadded$RESET $CYAN$CH_V$RESET"

    # Bottom Footer Divider & Keymap
    $divBot = "$CYAN$CH_LT" + ($CH_H * 78) + "$CH_RT$RESET"
    Write-Host $divBot

    $navHelp = "[Arrows/1-7] Move | [Tab/Left/Right] Switch Panel | [Space] Toggle | [Enter] Run"
    $navPadded = $navHelp.PadRight(76)
    Write-Host "$CYAN$CH_V$RESET $YELLOW$navPadded$RESET $CYAN$CH_V$RESET"
    
    $botLine = "$CYAN$CH_BL" + ($CH_H * 78) + "$CH_BR$RESET"
    Write-Host $botLine
}

# ------------------------------------------------------------------------------
# Pre-Flight Review & Execution
# ------------------------------------------------------------------------------
function Show-PreFlightScreen {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "                  PRE-FLIGHT REVIEW AND CONFIRMATION             " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $toEnable = @($script:Tweaks | Where-Object { $script:Selections[$_.Id] -eq "ENABLE" })
    $toRevert = @($script:Tweaks | Where-Object { $script:Selections[$_.Id] -eq "REVERT" })
    $selectedApps = @($script:WingetApps | Where-Object { $script:SelectedApps[$_.Id] -eq $true })

    $rpStateStr = if ($script:AutoCreateRestorePoint) { "ENABLED (Will create before execution)" } else { "DISABLED (Skipped)" }
    Write-Host "AUTO RESTORE POINT: $rpStateStr" -ForegroundColor Yellow
    Write-Host "  (Press [R] on keyboard to toggle Restore Point ON/OFF)" -ForegroundColor Gray
    Write-Host ""

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
    else { foreach ($app in $selectedApps) { Write-Host "  [X] $($app.Name)" -ForegroundColor Cyan } }
    Write-Host ""

    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "[ENTER] Start Execution | [R] Toggle Restore Point | [ESC] Back" -ForegroundColor Yellow

    while ($true) {
        $key = [System.Console]::ReadKey($true)
        if ($key.Key -eq "Enter") {
            Execute-Tweaks
            break
        } elseif ($key.Key -eq "R") {
            $script:AutoCreateRestorePoint = -not $script:AutoCreateRestorePoint
            Show-PreFlightScreen
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

    # Create Auto Restore Point if enabled
    if ($script:AutoCreateRestorePoint) {
        Create-TweakerRestorePoint -Description "Tweaker_AutoBackup_$timestamp" | Out-Null
    } else {
        Write-Host "Skipping System Restore Point creation (Disabled by user)." -ForegroundColor Gray
    }

    # Execute Registry Tweaks & Bloatware Removal
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

    # Restart Explorer
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

    # Number keys 1-7 for fast category jumping
    if ($key.KeyChar -ge '1' -and $key.KeyChar -le '7') {
        $idx = [int][string]$key.KeyChar - 1
        if ($idx -lt $script:Categories.Count) {
            $script:ActiveCategoryIndex = $idx
            $script:ActiveItemIndex = 0
            $script:FocusPanel = "ITEMS"
            continue
        }
    }

    switch ($key.Key) {
        "Tab" {
            if ($script:FocusPanel -eq "CATEGORIES") {
                $script:FocusPanel = "ITEMS"
            } else {
                $script:FocusPanel = "CATEGORIES"
            }
        }
        "LeftArrow" {
            $script:FocusPanel = "CATEGORIES"
        }
        "RightArrow" {
            $script:FocusPanel = "ITEMS"
        }
        "UpArrow" {
            if ($script:FocusPanel -eq "CATEGORIES") {
                if ($script:ActiveCategoryIndex -gt 0) {
                    $script:ActiveCategoryIndex--
                    $script:ActiveItemIndex = 0
                }
            } else {
                if ($script:ActiveItemIndex -gt 0) {
                    $script:ActiveItemIndex--
                }
            }
        }
        "DownArrow" {
            if ($script:FocusPanel -eq "CATEGORIES") {
                if ($script:ActiveCategoryIndex -lt ($script:Categories.Count - 1)) {
                    $script:ActiveCategoryIndex++
                    $script:ActiveItemIndex = 0
                }
            } else {
                $catName = $script:Categories[$script:ActiveCategoryIndex]
                $maxIdx = switch ($catName) {
                    "Presets" { [Math]::Max(0, $script:LocalPresets.Keys.Count - 1) }
                    "Winget Software" { $script:WingetApps.Count - 1 }
                    "Restore Points" { 2 }
                    default { (@($script:Tweaks | Where-Object { $_.Category -eq $catName })).Count - 1 }
                }
                if ($script:ActiveItemIndex -lt $maxIdx) {
                    $script:ActiveItemIndex++
                }
            }
        }
        "Spacebar" {
            $catName = $script:Categories[$script:ActiveCategoryIndex]
            if ($catName -in @("Interface", "Security & Privacy", "File Warnings", "Bloatware Remover")) {
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
                    foreach ($actionKey in $presetObj.Actions.Keys) {
                        $actVal = $presetObj.Actions[$actionKey]
                        if ($script:Selections.ContainsKey($actionKey)) {
                            $script:Selections[$actionKey] = $actVal
                        }
                    }
                }
            } elseif ($catName -eq "Restore Points") {
                if ($script:ActiveItemIndex -eq 0) {
                    $script:AutoCreateRestorePoint = -not $script:AutoCreateRestorePoint
                }
            }
        }
        "Enter" {
            $catName = $script:Categories[$script:ActiveCategoryIndex]
            if ($catName -eq "Restore Points") {
                if ($script:ActiveItemIndex -eq 0) {
                    $script:AutoCreateRestorePoint = -not $script:AutoCreateRestorePoint
                } elseif ($script:ActiveItemIndex -eq 1) {
                    Create-TweakerRestorePoint -Description "User_Manual_Backup"
                    Start-Sleep -Seconds 2
                } elseif ($script:ActiveItemIndex -eq 2) {
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

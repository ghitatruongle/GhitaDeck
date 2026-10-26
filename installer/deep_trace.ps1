# ============================================================================
# GhitaDeck Deep Trace Scanner
# Finds ALL remaining traces anywhere on the system
# REQUIRES: Administrator privileges
# ============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "============================================================" -ForegroundColor White
Write-Host "  GhitaDeck Deep Trace Scanner" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Requires Administrator privileges." -ForegroundColor Red
    pause
    exit 1
}

$found = @()
$searchTerms = @('ghita_deck', 'ghita_ppt', 'ghita', 'GhitaPPT', 'GHITA')

function Search-Registry {
    param([string]$path, [string]$label)
    Write-Host "  Scanning $label..." -ForegroundColor Cyan
    Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        $key = $_.PSPath
        foreach ($term in $searchTerms) {
            $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -like "*$term*" -or "$($p.Value)" -like "*$term*") {
                    $script:found += "Registry: $key -> $($p.Name) = $($p.Value)"
                    Write-Host "    FOUND: $key" -ForegroundColor Yellow
                    break
                }
            }
        }
        # Recurse subkeys
        Get-ChildItem -Path $key -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($term in $searchTerms) {
                $name = $_.Name
                if ($name -like "*$term*") {
                    $script:found += "Registry key: $name"
                    Write-Host "    FOUND key: $name" -ForegroundColor Yellow
                }
            }
        }
    }
}

function Search-Directory {
    param([string]$path, [string]$label, [int]$depth = 3)
    Write-Host "  Scanning $label (depth $depth)..." -ForegroundColor Cyan
    foreach ($term in $searchTerms) {
        Get-ChildItem -Path $path -Filter "*$term*" -Recurse -Depth $depth -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $script:found += "$label : $($_.FullName)"
            Write-Host "    FOUND: $($_.FullName)" -ForegroundColor Yellow
        }
    }
}

Write-Host "[1/8] Registry (HKLM)... " -NoNewline -ForegroundColor Yellow
Search-Registry "HKLM:\SOFTWARE" "HKLM\SOFTWARE"
Search-Registry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "Uninstall"
Search-Registry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "Startup"
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[2/8] Registry (HKCU)... " -NoNewline -ForegroundColor Yellow
Search-Registry "HKCU:\SOFTWARE" "HKCU\SOFTWARE"
Search-Registry "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "HKCU Startup"
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[3/8] ProgramData (all users)... " -NoNewline -ForegroundColor Yellow
Search-Directory "C:\ProgramData" "ProgramData" 4
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[4/8] System32 & Windows dirs (shallow)... " -NoNewline -ForegroundColor Yellow
Search-Directory "C:\Windows\System32" "System32" 2
Search-Directory "C:\Windows\SysWOW64" "SysWOW64" 2
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[5/8] User AppData (Roaming + Local + LocalLow)... " -NoNewline -ForegroundColor Yellow
Search-Directory $env:APPDATA "Roaming" 5
Search-Directory $env:LOCALAPPDATA "Local" 5
Search-Directory "$env:USERPROFILE\AppData\LocalLow" "LocalLow" 4
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[6/8] User home (Documents, Desktop, etc)... " -NoNewline -ForegroundColor Yellow
Search-Directory $env:USERPROFILE "UserHome" 4
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[7/8] Root drives (C:\ top-level)... " -NoNewline -ForegroundColor Yellow
Get-PSDrive -PSProvider 'FileSystem' -ErrorAction SilentlyContinue | Where-Object { $_.Used -ne $null } | ForEach-Object {
    $root = $_.Root
    Write-Host "  Scanning $root..." -ForegroundColor Cyan
    foreach ($term in $searchTerms) {
        Get-ChildItem -Path $root -Filter "*$term*" -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $script:found += "Root: $($_.FullName)"
            Write-Host "    FOUND: $($_.FullName)" -ForegroundColor Yellow
        }
    }
}
Write-Host "  Done." -ForegroundColor Green

Write-Host ""
Write-Host "[8/8] Scheduled Tasks & Services... " -NoNewline -ForegroundColor Yellow
foreach ($term in $searchTerms) {
    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*$term*" -or $_.TaskPath -like "*$term*" } | ForEach-Object {
        $script:found += "Task: $($_.TaskName)"
        Write-Host "    FOUND task: $($_.TaskName)" -ForegroundColor Yellow
    }
    Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$term*" -or $_.DisplayName -like "*$term*" } | ForEach-Object {
        $script:found += "Service: $($_.Name)"
        Write-Host "    FOUND service: $($_.Name)" -ForegroundColor Yellow
    }
}
Write-Host "  Done." -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SCAN COMPLETE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($found.Count -eq 0) {
    Write-Host "  No traces of GhitaPPT/GhitaDeck found anywhere!" -ForegroundColor Green
} else {
    Write-Host "  Found $($found.Count) items:" -ForegroundColor Yellow
    foreach ($item in $found) {
        Write-Host "    - $item" -ForegroundColor Yellow
    }
}
Write-Host ""
Write-Host "Press any key to exit..."
pause

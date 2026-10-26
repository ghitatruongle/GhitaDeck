$ErrorActionPreference = 'SilentlyContinue'
$found = @()
$patterns = @('ghita_deck', 'ghita_ppt', 'GhitaPPT', 'ghita-ppt')

function Check-Path {
    param([string]$p, [string]$label)
    if (Test-Path $p) {
        $script:found += "$label : $p"
        Write-Host "  FOUND: $p" -ForegroundColor Yellow
    }
}

function Search-Directory {
    param([string]$path, [string]$label, [int]$depth = 4)
    Write-Host "[Scanning] $label ($path)..." -ForegroundColor Cyan
    foreach ($pat in $patterns) {
        Get-ChildItem $path -Filter "*$pat*" -Recurse -Depth $depth -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $script:found += "$label : $($_.FullName)"
            Write-Host "  FOUND: $($_.FullName)" -ForegroundColor Yellow
        }
    }
}

Write-Host ''
Write-Host '===========================================' -ForegroundColor White
Write-Host '  DEEP TRACE SCAN - GhitaDeck' -ForegroundColor White
Write-Host '===========================================' -ForegroundColor White

Write-Host ''
Write-Host '[1] Install directories' -ForegroundColor Yellow
Check-Path 'C:\Program Files\GhitaPPT' 'Program Files'
Check-Path 'C:\Program Files (x86)\GhitaPPT' 'Program Files x86'
Check-Path 'C:\Users\Acer\AppData\Local\Programs\GhitaPPT' 'LocalAppData Programs'

Write-Host ''
Write-Host '[2] User data folders' -ForegroundColor Yellow
Check-Path 'C:\Users\Acer\AppData\Roaming\com.example\ghita_ppt_converter' 'Roaming data'
Check-Path 'C:\Users\Acer\AppData\Local\com.example\ghita_ppt_converter' 'Local data'
Check-Path 'C:\Users\Acer\AppData\Local\flutter_webview_windows\ghita_deck' 'WebView cache'
Check-Path 'C:\Users\Acer\AppData\Local\GhitaPPT' 'Local dir'
Check-Path 'C:\Users\Acer\AppData\Roaming\GhitaPPT' 'Roaming dir'

Write-Host ''
Write-Host '[3] Shortcuts (Desktop + Start Menu)' -ForegroundColor Yellow
Get-ChildItem "$env:USERPROFILE\Desktop" -Filter '*GhitaPPT*' -ErrorAction SilentlyContinue | ForEach-Object {
    $script:found += "Desktop: $($_.FullName)"
    Write-Host "  FOUND: $($_.FullName)" -ForegroundColor Yellow
}
Get-ChildItem 'C:\Users\Public\Desktop' -Filter '*GhitaPPT*' -ErrorAction SilentlyContinue | ForEach-Object {
    $script:found += "Public: $($_.FullName)"
    Write-Host "  FOUND: $($_.FullName)" -ForegroundColor Yellow
}
$hkcuMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
Get-ChildItem $hkcuMenu -Filter '*GhitaPPT*' -ErrorAction SilentlyContinue | ForEach-Object {
    $script:found += "StartMenu HKCU: $($_.FullName)"
    Write-Host "  FOUND: $($_.FullName)" -ForegroundColor Yellow
}
$hklmMenu = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
Get-ChildItem $hklmMenu -Filter '*GhitaPPT*' -ErrorAction SilentlyContinue | ForEach-Object {
    $script:found += "StartMenu HKLM: $($_.FullName)"
    Write-Host "  FOUND: $($_.FullName)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host '[4] Registry (HKCU)' -ForegroundColor Yellow
foreach ($pat in $patterns) {
    Get-ChildItem 'HKCU:\SOFTWARE' -Filter "*$pat*" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $script:found += "HKCU: $($_.PSPath)"
        Write-Host "  FOUND: $($_.PSPath)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '[5] Running processes' -ForegroundColor Yellow
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match 'ghita_ppt' -or "$($_.MainModule.FileName)" -match 'ghita_ppt'
} | ForEach-Object {
    $script:found += "Process: $($_.ProcessName)"
    Write-Host "  FOUND: $($_.ProcessName) PID $($_.Id)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host '[6] Temp files' -ForegroundColor Yellow
Get-ChildItem $env:TEMP -Filter '*ghita_ppt*' -ErrorAction SilentlyContinue | ForEach-Object {
    $script:found += "Temp: $($_.FullName)"
    Write-Host "  FOUND: $($_.FullName)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host '===========================================' -ForegroundColor Cyan
if ($found.Count -eq 0) {
    Write-Host '  NO TRACES FOUND - SYSTEM IS CLEAN' -ForegroundColor Green
} else {
    Write-Host "  FOUND $($found.Count) TRACES:" -ForegroundColor Yellow
    $found | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}
Write-Host '===========================================' -ForegroundColor Cyan

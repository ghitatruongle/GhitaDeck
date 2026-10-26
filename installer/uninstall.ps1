param(
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$productName = "GhitaDeck"
$appId = "{A3F8E1C2-5B7D-4E9A-B6C1-2D3F4A5B6C7D}_is1"

function Find-RegisteredUninstaller {
    $registryRoots = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($root in $registryRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($entry in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            $properties = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue
            if ($entry.PSChildName -eq $appId -or $properties.DisplayName -eq $productName) {
                $command = $properties.QuietUninstallString
                if (-not $command) { $command = $properties.UninstallString }
                if ($command -and $command -match '^"?([^"\s]+(?:\s[^"\s]+)*)"?(?:\s+(.*))?$') {
                    $candidate = $Matches[1]
                    if (Test-Path -LiteralPath $candidate) { return $candidate }
                }
            }
        }
    }
    return $null
}

$uninstaller = Find-RegisteredUninstaller
if (-not $uninstaller) {
    $knownPaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\GhitaDeck\unins000.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\GhitaPPT Converter\unins000.exe"),
        (Join-Path $env:ProgramFiles "GhitaDeck\unins000.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "GhitaDeck\unins000.exe"),
        (Join-Path $env:ProgramFiles "GhitaPPT Converter\unins000.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "GhitaPPT Converter\unins000.exe")
    )
    $uninstaller = $knownPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

if (-not $uninstaller) {
    throw "$productName is not installed, or its official uninstaller could not be found."
}

$arguments = if ($Silent) { "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" } else { "" }
$process = if ($arguments) {
    Start-Process -FilePath $uninstaller -ArgumentList $arguments -Wait -PassThru
} else {
    Start-Process -FilePath $uninstaller -Wait -PassThru
}
if ($process.ExitCode -ne 0) {
    throw "The official uninstaller exited with code $($process.ExitCode)."
}

Write-Host "$productName was uninstalled successfully." -ForegroundColor Green

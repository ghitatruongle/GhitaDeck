param(
    [switch]$SmokeInstall,
    [switch]$SmokeLaunch,
    [switch]$RequireSignature
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputDir = Join-Path $PSScriptRoot "output"
$ReleaseExe = Join-Path $ProjectRoot "build\windows\x64\runner\Release\ghita_ppt_converter.exe"
$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
if ($SmokeLaunch) { $SmokeInstall = $true }

$versionLine = Get-Content -LiteralPath $PubspecPath |
    Where-Object { $_ -match '^version:\s*(\S+)\s*$' } |
    Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+(\d+))?\s*$') {
    throw "pubspec.yaml version is missing or invalid."
}
$major = $Matches[1]
$minor = $Matches[2]
$patch = $Matches[3]
$pre = $Matches[4]
$build = if ($Matches[5]) { $Matches[5] } else { '0' }
$suffix = if ($pre) { "-$pre" } else { '' }
$displayVersion = "$major.$minor.$patch$suffix+$build"
$numericVersion = "$major.$minor.$patch.$build"
# Artifact filenames carry no +build suffix — mirror build_installer.ps1's
# FileBase ("GhitaPPT-Setup-2.0.1-beta2.exe", "GhitaPPT-Setup-2.0.0.exe").
$fileBase = if ($pre) { "$major.$minor.$patch-$pre" } else { "$major.$minor.$patch" }
$installerName = "GhitaPPT-Setup-$fileBase.exe"
$installerPath = Join-Path $OutputDir $installerName
$checksumPath = Join-Path $OutputDir "GhitaPPT-Setup-$fileBase.sha256"
$metadataPath = Join-Path $OutputDir "GhitaPPT-Setup-$fileBase.release.json"

foreach ($path in @($ReleaseExe, $installerPath, $checksumPath, $metadataPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required release artifact is missing: $path" }
}

$releaseInfo = (Get-Item -LiteralPath $ReleaseExe).VersionInfo
if ($releaseInfo.ProductName -ne "GhitaPPT Converter" -or
    $releaseInfo.CompanyName -ne "Ghita" -or
    $releaseInfo.FileVersion -ne $displayVersion) {
    throw "Release EXE metadata does not match the expected product/version."
}

$installerInfo = (Get-Item -LiteralPath $installerPath).VersionInfo
if ($installerInfo.ProductName.Trim() -ne "GhitaPPT Converter" -or
    $installerInfo.FileVersion.Trim() -ne $numericVersion) {
    throw "Installer metadata does not match the expected product/version."
}

$actualInstallerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$actualExeHash = (Get-FileHash -LiteralPath $ReleaseExe -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedChecksum = "$actualInstallerHash *$installerName"
if ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -ne $expectedChecksum) {
    throw "SHA-256 checksum file does not match the installer."
}

$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if ($metadata.schemaVersion -ne 1 -or
    $metadata.product -ne "GhitaPPT Converter" -or
    $metadata.version -ne $displayVersion -or
    $metadata.numericVersion -ne $numericVersion -or
    $metadata.installer -ne $installerName -or
    $metadata.installerSha256 -ne $actualInstallerHash -or
    $metadata.applicationExeSha256 -ne $actualExeHash -or
    $metadata.architecture -ne "x64" -or
    -not ($metadata.installScope -eq "per-machine" -or $metadata.installScope -eq "per-user")) {
    throw "Release metadata manifest validation failed."
}

$installerSignature = Get-AuthenticodeSignature -LiteralPath $installerPath
$applicationSignature = Get-AuthenticodeSignature -LiteralPath $ReleaseExe
if ($metadata.installerSignatureStatus -ne $installerSignature.Status.ToString() -or
    $metadata.applicationSignatureStatus -ne $applicationSignature.Status.ToString()) {
    throw "Signature status in the release manifest is stale."
}
if ($RequireSignature -and
    ($installerSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
     $applicationSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid)) {
    throw "A valid Authenticode signature is required but one or more artifacts are not signed."
}

if ($SmokeInstall) {
    $smokeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("GhitaPPT-release-smoke-" + [guid]::NewGuid().ToString("N"))
    if (Test-Path -LiteralPath $smokeRoot) { throw "Unexpected existing smoke-test path: $smokeRoot" }

    # /CURRENTUSER: the installer defaults to Program Files (PrivilegesRequired
    # = admin + UAC), which a non-elevated automation shell cannot complete.
    # The override is allowed in the wizard (PrivilegesRequiredOverridesAllowed)
    # so silent smoke tests install per-user into the temp dir; real end-user
    # installs still get the Program Files default via the UAC prompt.
    $install = Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /DIR=`"$smokeRoot`"" -Wait -PassThru
    if ($install.ExitCode -ne 0) { throw "Installer smoke test failed with exit code $($install.ExitCode)." }

    foreach ($relativePath in @("ghita_ppt_converter.exe", "flutter_windows.dll", "ghita_core.dll", "data\app.so", "data\flutter_assets\AssetManifest.bin", "unins000.exe")) {
        if (-not (Test-Path -LiteralPath (Join-Path $smokeRoot $relativePath))) {
            throw "Installed file is missing: $relativePath"
        }
    }

    $installedInfo = (Get-Item -LiteralPath (Join-Path $smokeRoot "ghita_ppt_converter.exe")).VersionInfo
    if ($installedInfo.ProductName -ne "GhitaPPT Converter" -or $installedInfo.FileVersion -ne $displayVersion) {
        throw "Installed EXE metadata validation failed."
    }

    # T18.3: auto-start stays OFF unless the task was explicitly selected.
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $autoStartValue = (Get-ItemProperty -LiteralPath $runKey -ErrorAction SilentlyContinue)."GhitaPPT Converter"
    if ($autoStartValue) {
        throw "Auto-start registry value exists after a silent install that did not select the task."
    }

    # T18.7 — data-group contract. Group A (user data) must survive the
    # default uninstall; Group B (regenerable cache) must be cleaned.
    $groupADocs = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GhitaPPT'
    $groupAPrefs = Join-Path $env:APPDATA 'Ghita\GhitaPPT Converter'
    $groupBCache = Join-Path $env:LOCALAPPDATA 'GhitaPPT\image_cache'
    $groupBLog = Join-Path $env:APPDATA 'GhitaPPT\engine.log'

    # Seed a marker in each group so the assertions below are meaningful
    # (a real user would already have these after using the app).
    New-Item -ItemType Directory -Path $groupADocs -Force | Out-Null
    $markerDoc = Join-Path $groupADocs 'verify_marker.txt'
    Set-Content -LiteralPath $markerDoc -Value 'group A marker' -NoNewline
    New-Item -ItemType Directory -Path $groupAPrefs -Force | Out-Null
    $markerPref = Join-Path $groupAPrefs 'verify_marker.json'
    Set-Content -LiteralPath $markerPref -Value '{}' -NoNewline
    New-Item -ItemType Directory -Path $groupBCache -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $groupBCache 'verify_marker.bin') -Value 'x' -NoNewline
    New-Item -ItemType Directory -Path (Split-Path -Parent $groupBLog) -Force | Out-Null
    Set-Content -LiteralPath $groupBLog -Value 'marker' -NoNewline

    if ($SmokeLaunch) {
        $installedExe = Join-Path $smokeRoot "ghita_ppt_converter.exe"
        $application = $null
        try {
            $application = Start-Process -FilePath $installedExe -PassThru
            Start-Sleep -Seconds 3
            if ($application.HasExited) {
                throw "Installed application exited unexpectedly with code $($application.ExitCode)."
            }
        } finally {
            if ($application -and -not $application.HasExited) {
                Stop-Process -Id $application.Id -Force
                $application.WaitForExit()
            }
        }
    }

    $uninstaller = Join-Path $smokeRoot "unins000.exe"
    $uninstall = Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru
    if ($uninstall.ExitCode -ne 0) { throw "Uninstaller smoke test failed with exit code $($uninstall.ExitCode)." }
    if (Test-Path -LiteralPath $smokeRoot) { throw "Smoke-test installation directory remains after uninstall: $smokeRoot" }

    # T18.7 — default uninstall: Group A survives, Group B is gone.
    if (-not (Test-Path -LiteralPath $markerDoc)) {
        throw "Group A (documents) was removed by a default uninstall - user data must be preserved."
    }
    if (-not (Test-Path -LiteralPath $markerPref)) {
        throw "Group A (preferences / API keys) was removed by a default uninstall; must be preserved."
    }
    if (Test-Path -LiteralPath (Join-Path $groupBCache 'verify_marker.bin')) {
        throw "Group B (image cache) survived the uninstall; it must be cleaned."
    }
    if (Test-Path -LiteralPath $groupBLog) {
        throw "Group B (engine log) survived the uninstall; it must be cleaned."
    }
    if ((Get-ItemProperty -LiteralPath $runKey -ErrorAction SilentlyContinue)."GhitaPPT Converter") {
        throw "Auto-start registry value survived the uninstall."
    }

    # Cleanup of the Group A markers this smoke run created (never touches
    # real user files — only the two marker files it wrote above).
    Remove-Item -LiteralPath $markerDoc -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $markerPref -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $groupBCache 'verify_marker.bin') -Force -ErrorAction SilentlyContinue
}

[pscustomobject]@{
    Product = "GhitaPPT Converter"
    Version = $displayVersion
    Installer = $installerPath
    InstallerSha256 = $actualInstallerHash
    InstallerSignature = $installerSignature.Status.ToString()
    ApplicationSignature = $applicationSignature.Status.ToString()
    SmokeInstall = if ($SmokeInstall) { "Passed" } else { "Skipped" }
    SmokeLaunch = if ($SmokeLaunch) { "Passed" } else { "Skipped" }
    Validation = "Passed"
} | Format-List

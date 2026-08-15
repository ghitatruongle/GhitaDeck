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
$installerName = "GhitaPPT-Setup-$displayVersion.exe"
$installerPath = Join-Path $OutputDir $installerName
$checksumPath = Join-Path $OutputDir "GhitaPPT-Setup-$displayVersion.sha256"
$metadataPath = Join-Path $OutputDir "GhitaPPT-Setup-$displayVersion.release.json"

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
    $metadata.installScope -ne "per-user") {
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

    $install = Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$smokeRoot`"" -Wait -PassThru
    if ($install.ExitCode -ne 0) { throw "Installer smoke test failed with exit code $($install.ExitCode)." }

    foreach ($relativePath in @("ghita_ppt_converter.exe", "flutter_windows.dll", "data\app.so", "data\flutter_assets\AssetManifest.bin", "unins000.exe")) {
        if (-not (Test-Path -LiteralPath (Join-Path $smokeRoot $relativePath))) {
            throw "Installed file is missing: $relativePath"
        }
    }

    $installedInfo = (Get-Item -LiteralPath (Join-Path $smokeRoot "ghita_ppt_converter.exe")).VersionInfo
    if ($installedInfo.ProductName -ne "GhitaPPT Converter" -or $installedInfo.FileVersion -ne $displayVersion) {
        throw "Installed EXE metadata validation failed."
    }

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

param(
    [switch]$Clean,
    [switch]$OpenOutput,
    [switch]$RequireCleanSource,
    [string]$SigningCertificateThumbprint,
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$InstallerDir = Join-Path $ProjectRoot "installer"
$OutputDir = Join-Path $InstallerDir "output"
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$ReleaseExe = Join-Path $ReleaseDir "ghita_ppt_converter.exe"
$IssPath = Join-Path $InstallerDir "ghita_ppt_installer.iss"
$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"

function Read-ProjectVersion {
    $versionLine = Get-Content -LiteralPath $PubspecPath |
        Where-Object { $_ -match '^version:\s*(\S+)\s*$' } |
        Select-Object -First 1
    if (-not $versionLine -or $versionLine -notmatch '^version:\s*(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+(\d+))?\s*$') {
        throw "pubspec.yaml must contain a Flutter version in MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD] format."
    }

    $major = $Matches[1]
    $minor = $Matches[2]
    $patch = $Matches[3]
    $pre = $Matches[4]
    $build = if ($Matches[5]) { $Matches[5] } else { '0' }
    $core = "$major.$minor.$patch"
    $suffix = if ($pre) { "-$pre" } else { '' }

    return [pscustomobject]@{
        Display = "$core$suffix+$build"
        Core = $core
        Build = $build
        Numeric = "$core.$build"
    }
}

function Find-InnoSetup {
    $paths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    return $null
}

function Find-SignTool {
    $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $kitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path -LiteralPath $kitsRoot) {
        return Get-ChildItem -LiteralPath $kitsRoot -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
            Sort-Object FullName -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
    return $null
}

function Invoke-CodeSign {
    param([Parameter(Mandatory)][string]$Path)

    if (-not $SigningCertificateThumbprint) { return }
    $signTool = Find-SignTool
    if (-not $signTool) {
        throw "signtool.exe was not found. Install the Windows SDK before requesting code signing."
    }

    $arguments = @(
        "sign", "/sha1", $SigningCertificateThumbprint,
        "/fd", "SHA256", "/tr", $TimestampUrl, "/td", "SHA256",
        $Path
    )
    $process = Start-Process -FilePath $signTool -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        throw "Code signing failed for $Path with exit code $($process.ExitCode)."
    }
}

function Convert-PngToIco {
    param([string]$PngPath, [string]$IcoPath)

    if (-not (Test-Path -LiteralPath $PngPath)) {
        throw "Application logo not found: $PngPath"
    }

    Add-Type -AssemblyName System.Drawing
    $png = $null
    $bitmap = $null
    $icon = $null
    $stream = $null
    try {
        $png = [System.Drawing.Image]::FromFile($PngPath)
        $bitmap = New-Object System.Drawing.Bitmap $png, 256, 256
        $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
        $stream = [System.IO.File]::Create($IcoPath)
        $icon.Save($stream)
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($icon) { $icon.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($png) { $png.Dispose() }
    }
}

function Get-SignatureInfo {
    param([Parameter(Mandatory)][string]$Path)

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    return [pscustomobject]@{
        Status = $signature.Status.ToString()
        Subject = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
        Thumbprint = if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null }
    }
}

$projectVersion = Read-ProjectVersion
$expectedInstallerName = "GhitaPPT-Setup-$($projectVersion.Display).exe"
$expectedInstallerPath = Join-Path $OutputDir $expectedInstallerName
$sourceRevision = (& git -C $ProjectRoot rev-parse HEAD).Trim()
$sourceStatus = (& git -C $ProjectRoot status --porcelain | Out-String).Trim()
$sourceDirty = -not [string]::IsNullOrWhiteSpace($sourceStatus)

if ($RequireCleanSource -and $sourceDirty) {
    throw "The working tree is dirty. Commit/stash changes or omit -RequireCleanSource for an internal build."
}
if (-not (Test-Path -LiteralPath $ReleaseExe)) {
    throw "Release executable not found. Run 'flutter build windows --release' first."
}
if (-not (Test-Path -LiteralPath $IssPath)) {
    throw "Installer definition not found: $IssPath"
}

$releaseVersion = (Get-Item -LiteralPath $ReleaseExe).VersionInfo.FileVersion
if ($releaseVersion -ne $projectVersion.Display) {
    throw "Release EXE version is '$releaseVersion' but pubspec.yaml is '$($projectVersion.Display)'. Rebuild Release first."
}

$innoSetup = Find-InnoSetup
if (-not $innoSetup) {
    throw "Inno Setup 6 compiler was not found. Install it from https://jrsoftware.org/isdl.php and run again."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor White
Write-Host "  GhitaPPT Installer Builder v$($projectVersion.Display)" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White
Write-Host "Using Inno Setup: $innoSetup" -ForegroundColor Green
Write-Host "Source revision: $sourceRevision (dirty: $sourceDirty)" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
if ($Clean) {
    Write-Host "Cleaning generated release artifacts..." -ForegroundColor Yellow
    foreach ($pattern in @("GhitaPPT-Setup-*.exe", "GhitaPPT-Setup-*.sha256", "GhitaPPT-Setup-*.release.json")) {
        Get-ChildItem -LiteralPath $OutputDir -Filter $pattern -File -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }
}

$pngIcon = Join-Path $ProjectRoot "assets\images\app_logo.png"
$icoPath = Join-Path $InstallerDir "app_icon.ico"
Convert-PngToIco -PngPath $pngIcon -IcoPath $icoPath
Invoke-CodeSign -Path $ReleaseExe

$compilerArguments = @(
    "/DMyAppVersion=$($projectVersion.Core)",
    "/DMyAppBuild=$($projectVersion.Build)",
    "/DMyAppDisplayVersion=$($projectVersion.Display)",
    "`"$IssPath`""
)
Write-Host "Compiling $expectedInstallerName..." -ForegroundColor Yellow
$compile = Start-Process -FilePath $innoSetup -ArgumentList $compilerArguments -Wait -PassThru -NoNewWindow
if ($compile.ExitCode -ne 0) {
    throw "Inno Setup compile failed with exit code $($compile.ExitCode)."
}
if (-not (Test-Path -LiteralPath $expectedInstallerPath)) {
    throw "Expected installer was not produced: $expectedInstallerPath"
}

Invoke-CodeSign -Path $expectedInstallerPath

$setupItem = Get-Item -LiteralPath $expectedInstallerPath
$setupHash = (Get-FileHash -LiteralPath $expectedInstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$releaseHash = (Get-FileHash -LiteralPath $ReleaseExe -Algorithm SHA256).Hash.ToLowerInvariant()
$setupSignature = Get-SignatureInfo -Path $expectedInstallerPath
$releaseSignature = Get-SignatureInfo -Path $ReleaseExe
$checksumPath = Join-Path $OutputDir "$($setupItem.BaseName).sha256"
$metadataPath = Join-Path $OutputDir "$($setupItem.BaseName).release.json"

Set-Content -LiteralPath $checksumPath -Value "$setupHash *$($setupItem.Name)" -NoNewline -Encoding ascii
$metadata = [ordered]@{
    schemaVersion = 1
    product = "GhitaPPT Converter"
    version = $projectVersion.Display
    numericVersion = $projectVersion.Numeric
    installer = $setupItem.Name
    installerSha256 = $setupHash
    installerSizeBytes = $setupItem.Length
    installerSignatureStatus = $setupSignature.Status
    installerSignerSubject = $setupSignature.Subject
    applicationExeSha256 = $releaseHash
    applicationSignatureStatus = $releaseSignature.Status
    applicationSignerSubject = $releaseSignature.Subject
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    architecture = "x64"
    installScope = "per-user"
    sourceRevision = $sourceRevision
    sourceDirty = $sourceDirty
} | ConvertTo-Json
Set-Content -LiteralPath $metadataPath -Value $metadata -Encoding utf8

Write-Host ""
Write-Host "Build complete" -ForegroundColor Green
Write-Host "  Installer:  $expectedInstallerPath" -ForegroundColor Cyan
Write-Host "  Size:       $([math]::Round($setupItem.Length / 1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "  SHA-256:    $setupHash" -ForegroundColor Cyan
Write-Host "  Signature:  $($setupSignature.Status)" -ForegroundColor Cyan
Write-Host "  Manifest:   $metadataPath" -ForegroundColor Cyan

if ($OpenOutput) {
    Start-Process explorer.exe -ArgumentList "/select,`"$expectedInstallerPath`""
}

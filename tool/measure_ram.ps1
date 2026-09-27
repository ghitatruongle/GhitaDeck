param(
    [string]$ExePath = "build\windows\x64\runner\Release\ghita_ppt_converter.exe",
    [int]$DurationSeconds = 30,
    [int]$IntervalMs = 1000,
    [string]$Label = "run",
    [string]$OutFile = ""
)

# T19 - deterministic RSS sampler for the Release app (no DevTools).
#
# Starts the executable, samples Working Set (RSS-equivalent on Windows) and
# private bytes every IntervalMs, and prints/writes a compact report. Used for
# startup+idle baselines, export sessions and soak runs; the numbers land in
# tool/ram_results_*.md.
#
# Usage:
#   powershell -File tool/measure_ram.ps1 -DurationSeconds 30 -Label idle
#   powershell -File tool/measure_ram.ps1 -DurationSeconds 1800 -Label soak -OutFile tool/ram_soak.md

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ExePath)) {
    throw "Release executable not found: $ExePath - run 'flutter build windows --release' first."
}

function New-MarkdownRow {
    param([string[]]$Cells)
    # A literal '|' inside a double-quoted PowerShell string ends the pipeline,
    # so the separator is built from its code point.
    $sep = [char]124
    return ($sep + ($Cells -join (" $sep ")) + " $sep")
}

function Get-ProcessMetrics {
    param([System.Diagnostics.Process]$Process)
    # Refresh() makes the values live; without it Process caches the snapshot
    # taken when the object was created.
    $Process.Refresh()
    return [pscustomobject]@{
        WorkingSetMB = [math]::Round($Process.WorkingSet64 / 1MB, 1)
        PrivateMB    = [math]::Round($Process.PrivateMemorySize64 / 1MB, 1)
        Threads      = $Process.Threads.Count
    }
}

Write-Host "Starting $ExePath (label: $Label)..." -ForegroundColor Cyan
$process = Start-Process -FilePath $ExePath -PassThru -WindowStyle Minimized

$samples = New-Object System.Collections.Generic.List[object]
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$startupMs = $null

try {
    while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds) {
        if ($process.HasExited) {
            Write-Host "Process exited early with code $($process.ExitCode)." -ForegroundColor Yellow
            break
        }
        $m = Get-ProcessMetrics -Process $process
        if (-not $startupMs) { $startupMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0) }
        $samples.Add([pscustomobject]@{
            Seconds      = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            WorkingSetMB = $m.WorkingSetMB
            PrivateMB    = $m.PrivateMB
            Threads      = $m.Threads
        }) | Out-Null
        Start-Sleep -Milliseconds $IntervalMs
    }
} finally {
    if (-not $process.HasExited) {
        $process.CloseMainWindow() | Out-Null
        Start-Sleep -Milliseconds 400
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    }
}

if ($samples.Count -eq 0) {
    throw "No samples collected - the process may have failed to start."
}

$ws = $samples | ForEach-Object { $_.WorkingSetMB }
$pv = $samples | ForEach-Object { $_.PrivateMB }
$first = $samples[0]
$last = $samples[$samples.Count - 1]
$peak = ($ws | Measure-Object -Maximum).Maximum
$steady = if ($samples.Count -gt 5) {
    ($ws | Select-Object -Skip 5 | Measure-Object -Average).Average
} else { ($ws | Measure-Object -Average).Average }
$growth = [math]::Round($last.WorkingSetMB - $first.WorkingSetMB, 1)

$report = [pscustomobject]@{
    Label            = $Label
    Exe              = $ExePath
    Samples          = $samples.Count
    DurationSeconds  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    FirstSampleMB    = $first.WorkingSetMB
    SteadyAvgMB      = [math]::Round($steady, 1)
    PeakMB           = [math]::Round($peak, 1)
    LastMB           = $last.WorkingSetMB
    GrowthMB         = $growth
    PrivateLastMB    = $last.PrivateMB
    PrivatePeakMB    = [math]::Round(($pv | Measure-Object -Maximum).Maximum, 1)
    ThreadsLast      = $last.Threads
}

Write-Host ""
Write-Host "=== RAM report: $Label ===" -ForegroundColor Green
$report | Format-List

if ($OutFile) {
    $lines = New-Object System.Collections.Generic.List[string]
    $row = New-MarkdownRow @($Label, "$($report.SteadyAvgMB) MB",
        "$($report.PeakMB) MB", "$($report.PrivateLastMB) MB",
        "$($report.GrowthMB) MB", "$($report.Samples)",
        "$($report.DurationSeconds) s")
    $lines.Add($row) | Out-Null

    if (-not (Test-Path -LiteralPath $OutFile)) {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        $header = New-Object System.Collections.Generic.List[string]
        $header.Add("") | Out-Null
        $header.Add("## $Label - $stamp") | Out-Null
        $header.Add("") | Out-Null
        $header.Add((New-MarkdownRow @("Run", "Steady avg (WorkingSet)", "Peak",
            "Private (last)", "Growth first-to-last", "Samples", "Duration"))) | Out-Null
        $header.Add((New-MarkdownRow @("---", "---", "---", "---", "---", "---", "---"))) | Out-Null
        $header | Set-Content -LiteralPath $OutFile -Encoding utf8
    }
    $lines | Add-Content -LiteralPath $OutFile -Encoding utf8
    Write-Host "Appended to $OutFile" -ForegroundColor Green
}

# Verify the 5 refreshed template previews' background pixels match the
# data-bg-color baked into each template file.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$cases = @{
    'business'  = '#0F1F33'
    'creative'  = '#170A26'
    'academic'  = '#0E2A2E'
    'marketing' = '#26121A'
    'minimal'   = '#F7F9F4'
}

$dir = 'D:/GhitaPPT/tool/template_previews'
$fail = $false

foreach ($slug in $cases.Keys) {
    $png = Join-Path $dir ($slug + '_preview.png')
    $bmp = New-Object System.Drawing.Bitmap($png)
    # Sample top-left, top-right, bottom-left and center - away from text.
    $points = @(
        @(640, 640),   # near bottom center (below content)
        @(30, 30),     # top-left corner
        @(1240, 30),   # top-right corner
        @(30, 680)     # bottom-left
    )
    $bad = @()
    foreach ($p in $points) {
        $c = $bmp.GetPixel($p[0], $p[1])
        $hex = ('#{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)
        if ($hex -ne $cases[$slug]) { $bad += ($p -join ',') + ' => ' + $hex }
    }
    $bmp.Dispose()
    if ($bad.Count -gt 0) {
        $fail = $true
        Write-Output ('FAIL ' + $slug + ' expected ' + $cases[$slug] + ' but got: ' + ($bad -join '; '))
    } else {
        Write-Output ('PASS ' + $slug + ' = ' + $cases[$slug])
    }
}

if ($fail) { exit 1 } else { Write-Output 'ALL_PASS' }

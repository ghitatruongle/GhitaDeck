Add-Type -AssemblyName System.Drawing
$dir = 'D:\GhitaPPT\tool\template_mockups'
$expect = @{
  'business_A'  = '#0F1F33'
  'creative_C'  = '#170A26'
  'academic_C'  = '#0E2A2E'
  'marketing_B' = '#26121A'
  'minimal_A'   = '#FFFFFF'
  'minimal_B'   = '#F7F9F4'
}
foreach ($name in $expect.Keys) {
  $bmp = [System.Drawing.Bitmap]::FromFile("$dir\$name.png")
  $c = $bmp.GetPixel(20, 700)
  $hex = '#{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B
  $ok = if ($hex -eq $expect[$name]) { 'OK' } else { 'MISMATCH' }
  Write-Output ("{0}: {1} expected {2} -> {3}" -f $name, $hex, $expect[$name], $ok)
  $bmp.Dispose()
}

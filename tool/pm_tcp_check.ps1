# T10.3 — privacy: no outbound TCP from the Release exe in the first 8 s.
$p = Start-Process -FilePath 'build\windows\x64\runner\Release\ghita_ppt_converter.exe' -PassThru
Start-Sleep -Seconds 8
$lines = netstat -ano | Select-String " $($p.Id)$"
Write-Host "APP PID $($p.Id) - matched sockets:"
if ($lines) { $lines | ForEach-Object { Write-Host $_.Line } } else { Write-Host 'NONE (0 sockets for the app)' }
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue

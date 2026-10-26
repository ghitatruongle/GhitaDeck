@echo off
:: Run deep trace elevated with output capture
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','E:\GhitaPPT\installer\deep_trace.ps1' -RedirectStandardOutput 'E:\GhitaPPT\installer\scan_output.txt' -RedirectStandardError 'E:\GhitaPPT\installer\scan_errors.txt'"
echo Elevated process started. Waiting for completion...
:waitloop
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq powershell.exe" 2>nul | find /I "powershell.exe" >nul
if %ERRORLEVEL%==0 goto waitloop
echo.
echo Scan complete. Output saved to E:\GhitaPPT\installer\scan_output.txt
type "E:\GhitaPPT\installer\scan_output.txt"
pause

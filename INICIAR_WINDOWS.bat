@echo off
setlocal
title Bounty Studio - Servidor da live
cd /d "%~dp0"
where py >nul 2>&1
if not errorlevel 1 (
  py -3 --version >nul 2>&1
  if not errorlevel 1 (
    py -3 "%~dp0src\BountyStudio.Server\servidor.py"
    goto finish
  )
)
where python >nul 2>&1
if not errorlevel 1 (
  python --version >nul 2>&1
  if not errorlevel 1 (
    python "%~dp0src\BountyStudio.Server\servidor.py"
    goto finish
  )
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\BountyStudio.Server\servidor-windows.ps1"
:finish
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar. Veja a mensagem acima.
  pause
)
endlocal

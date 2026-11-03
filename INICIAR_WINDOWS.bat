@echo off
setlocal
title Bounty Studio
cd /d "%~dp0"

rem Se o executavel desktop estiver presente, inicia-o diretamente
if exist "%~dp0BountyStudio.exe" (
  start "" "%~dp0BountyStudio.exe"
  goto finish
)

rem Fallback para desenvolvedores rodando a engine via script caso o .exe ainda nao tenha sido compilado
echo Executavel BountyStudio.exe nao encontrado. Tentando iniciar engine interna...

where py >nul 2>&1
if not errorlevel 1 (
  py -3 -c "import sys; sys.exit(0)" >nul 2>&1
  if not errorlevel 1 (
    py -3 "%~dp0src\BountyStudio.Server\servidor.py"
    goto finish
  )
)

where python >nul 2>&1
if not errorlevel 1 (
  python -c "import sys; sys.exit(0)" >nul 2>&1
  if not errorlevel 1 (
    python "%~dp0src\BountyStudio.Server\servidor.py"
    goto finish
  )
)

where pwsh >nul 2>&1
if not errorlevel 1 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0src\BountyStudio.Server\servidor-windows.ps1"
  goto finish
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0src\BountyStudio.Server\servidor-windows.ps1"

:finish
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar o aplicativo.
  pause
)
endlocal

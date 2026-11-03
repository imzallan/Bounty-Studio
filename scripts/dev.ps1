<#
.SYNOPSIS
    Inicia o servidor de desenvolvimento do Bounty Studio.
.DESCRIPTION
    Executa o servidor local em modo desenvolvimento com auto-abertura do navegador.
#>
param(
    [int]$Port = 8787,
    [switch]$NoBrowser
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$serverScript = Join-Path $projectRoot 'src\BountyStudio.Server\servidor-windows.ps1'

Write-Host "Iniciando servidor de desenvolvimento Bounty Studio na porta $Port..." -ForegroundColor Cyan

$params = @('-File', $serverScript, '-Port', $Port)
if ($NoBrowser) { $params += '-NoBrowser' }

& powershell.exe -ExecutionPolicy Bypass @params


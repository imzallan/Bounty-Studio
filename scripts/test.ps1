<#
.SYNOPSIS
    Executor unificado da suíte de testes do Bounty Studio.
.DESCRIPTION
    Executa testes unitários de regras de progressão e testes de integração da API HTTP.
#>
param(
    [switch]$SkipIntegration
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$testsDir = Join-Path $projectRoot 'tests'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   BOUNTY STUDIO - TEST RUNNER" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$exitCode = 0

# 1. Testes Unitários de Regras
Write-Host "[1/2] Executando testes unitários de regras..." -ForegroundColor Yellow
$ruleTestScript = Join-Path $testsDir 'Test-BountyRules.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ruleTestScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha nos testes de regras." -ForegroundColor Red
    $exitCode = 1
} else {
    Write-Host "[OK] Testes de regras aprovados." -ForegroundColor Green
}

# 2. Testes de Integração da API
if (-not $SkipIntegration) {
    Write-Host "`n[2/2] Executando testes de integração da API..." -ForegroundColor Yellow
    $apiTestScript = Join-Path $testsDir 'Test-ServerApi.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $apiTestScript -TestPort 8989
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERRO] Falha nos testes de integração da API." -ForegroundColor Red
        $exitCode = 1
    } else {
        Write-Host "[OK] Testes de integração da API aprovados." -ForegroundColor Green
    }
} else {
    Write-Host "`n[2/2] Testes de integração ignorados (--SkipIntegration)." -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
if ($exitCode -eq 0) {
    Write-Host "   TODOS OS TESTES PASSARAM COM SUCESSO!" -ForegroundColor Green
} else {
    Write-Host "   OCORRERAM FALHAS NOS TESTES!" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

exit $exitCode

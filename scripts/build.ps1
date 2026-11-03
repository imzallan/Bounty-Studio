<#
.SYNOPSIS
    Script de compilação do executável desktop BountyStudio.exe.
.DESCRIPTION
    Compila o executável standalone Windows utilizando o csc.exe embutido no .NET Framework 4.8.
    Gera dist/BountyStudio.exe e atualiza o executável da raiz.
#>
param(
    [string]$Version = '',
    [string]$GitHubRepository = $env:GITHUB_REPOSITORY,
    [string]$OutputFileName = 'BountyStudio.exe',
    [switch]$NoRootCopy
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$desktopBuild = Join-Path $projectRoot 'src\BountyStudio.Desktop\build.ps1'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  COMPILANDO EXECUTÁVEL BOUNTY STUDIO" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$params = @{}
if ($Version) { $params['Version'] = $Version }
if ($GitHubRepository) { $params['GitHubRepository'] = $GitHubRepository }
if ($OutputFileName) { $params['OutputFileName'] = $OutputFileName }

& $desktopBuild @params

if ($LASTEXITCODE -eq 0) {
    $distExe = Join-Path $projectRoot "dist\$OutputFileName"
    $rootExe = Join-Path $projectRoot $OutputFileName
    if (-not $NoRootCopy -and (Test-Path $distExe)) {
        Copy-Item -LiteralPath $distExe -Destination $rootExe -Force
        Write-Host "[OK] Executável atualizado na raiz: $rootExe" -ForegroundColor Green
    }
    Write-Host "`nCompilação do aplicativo .exe concluída com sucesso!" -ForegroundColor Green
} else {
    Write-Error "Falha na compilação do Bounty Studio."
}

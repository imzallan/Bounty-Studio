<#
.SYNOPSIS
    Limpa artefatos gerados de compilação e arquivos temporários.
#>
param(
    [switch]$IncludeData
)

$projectRoot = Split-Path -Parent $PSScriptRoot

$pathsToClean = @(
    (Join-Path $projectRoot 'dist'),
    (Join-Path $projectRoot 'src\BountyStudio.Desktop\obj')
)

if ($IncludeData) {
    $pathsToClean += (Join-Path $projectRoot 'dados')
}

foreach ($target in $pathsToClean) {
    if (Test-Path $target) {
        Write-Host "Removendo: $target" -ForegroundColor Yellow
        Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Get-ChildItem -Path $projectRoot -Include *.tmp, *.log, *.ilk, *.pdb -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
}

Write-Host "Limpeza de artefatos concluída." -ForegroundColor Green


<#
.SYNOPSIS
    Sincroniza os dados compartilhados em src/BountyStudio.Shared/Data com o overlay.html.
.DESCRIPTION
    Mantém o overlay.html como arquivo offline auto-suficiente e distribucional,
    enquanto permite desenvolvimento modular e desacoplado nos arquivos JSON.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$dataDir = Join-Path $ProjectRoot 'src\BountyStudio.Shared\Data'
$htmlPath = Join-Path $ProjectRoot 'src\BountyStudio.Web\overlay.html'

if (-not (Test-Path $htmlPath)) {
    throw "Arquivo HTML não encontrado em $htmlPath"
}

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

$mappings = @(
    @{ Id = 'bounty-defaults'; File = 'defaults.json' },
    @{ Id = 'bounty-rules'; File = 'rules.json' },
    @{ Id = 'bounty-slot-costs'; File = 'slot-costs.json' },
    @{ Id = 'bounty-creatures'; File = 'creatures.json' },
    @{ Id = 'bounty-sprites'; File = 'sprites.json' }
)

$updated = $html
foreach ($map in $mappings) {
    $filePath = Join-Path $dataDir $map.File
    if (Test-Path $filePath) {
        $json = ([System.IO.File]::ReadAllText($filePath, $utf8)).Trim()
        # Compact single-line JSON to keep HTML slim
        try {
            $parsed = $json | ConvertFrom-Json
            $json = $parsed | ConvertTo-Json -Compress -Depth 20
        } catch {
            # use raw text if compaction fails
        }
        $pattern = '(<script id="' + [regex]::Escape($map.Id) + '" type="application/json">)(.*?)(</script>)'
        if ([regex]::IsMatch($updated, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
            $updated = [regex]::Replace($updated, $pattern, '${1}' + $json + '${3}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            Write-Host "[OK] Atualizado tag '$($map.Id)' a partir de $($map.File)" -ForegroundColor Green
        } else {
            Write-Warning "Tag '$($map.Id)' não encontrada em overlay.html"
        }
    }
}

[System.IO.File]::WriteAllText($htmlPath, $updated, $utf8)
Write-Host "overlay.html sincronizado com sucesso com os dados compartilhados." -ForegroundColor Cyan


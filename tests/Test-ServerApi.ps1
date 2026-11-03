<#
.SYNOPSIS
    Testes de integração para a API do Servidor Bounty Studio (PowerShell backend).
.DESCRIPTION
    Inicia uma instância temporária do servidor na porta 8989, testa as rotas HTTP,
    as mutações de estado atômicas, os cálculos automáticos de pontos e encerra o processo.
#>

param(
    [int]$TestPort = 8989
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$serverScript = Join-Path $projectRoot 'src\BountyStudio.Server\servidor-windows.ps1'

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Assert-Test([bool]$Condition, [string]$Message) {
    $script:totalTests++
    if ($Condition) {
        $script:passedTests++
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        $script:failedTests++
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
    }
}

Write-Host "=== TESTES DE INTEGRAÇÃO DA API DO SERVIDOR (Porta $TestPort) ===" -ForegroundColor Cyan

$serverProc = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$serverScript", "-Port", "$TestPort", "-NoBrowser" -PassThru

try {
    # 1. Aguarda o servidor subir e valida health check
    $started = $false
    for ($i = 0; $i -lt 25; $i++) {
        Start-Sleep -Milliseconds 250
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$TestPort/api/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($health -and $health.kind -eq 'bounty-studio') {
                $started = $true
                break
            }
        } catch { }
    }

    Assert-Test $started "Servidor iniciou e respondeu ao health check com kind='bounty-studio'"

    if (-not $started) {
        throw "Servidor não conseguiu iniciar na porta $TestPort."
    }

    # 2. Rota de Estado Inicial
    $state = Invoke-RestMethod -Uri "http://127.0.0.1:$TestPort/api/state" -TimeoutSec 5
    Assert-Test ($state.schemaVersion -eq 7) "GET /api/state retorna schemaVersion = 7"
    Assert-Test ($null -ne $state.title) "GET /api/state contém campo 'title'"
    Assert-Test ($null -ne $state.damage) "GET /api/state contém campo 'damage'"
    $initialRevision = $state.revision

    # 3. Mutação de Estado via POST /api/state com 'patch'
    $payload = @{
        patch = @{
            title = "Bounty Talisman - Test Suite"
            damage = 10.0
            characterName = "Antigravity Hero"
            slot1 = $true
            monster1 = "Demon"
        }
    } | ConvertTo-Json -Depth 5

    $updateResp = Invoke-RestMethod -Uri "http://127.0.0.1:$TestPort/api/state" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 5
    Assert-Test ($updateResp.title -eq "Bounty Talisman - Test Suite") "POST /api/state atualizou 'title'"
    Assert-Test ($updateResp.damage -eq 10.0) "POST /api/state atualizou 'damage' para 10.0"
    Assert-Test ($updateResp.characterName -eq "Antigravity Hero") "POST /api/state atualizou 'characterName'"
    Assert-Test ($updateResp.slot1 -eq $true) "POST /api/state habilitou slot1"
    Assert-Test ($updateResp.points -gt 0) "Pontos recalculados automaticamente após incremento de atributos"
    Assert-Test ($updateResp.revision -gt $initialRevision) "Revisão incrementada após mutação atômica"

    # 4. Ajuste de nível via POST /api/state com 'adjust'
    $adjustPayload = @{
        adjust = @{
            key = "bestiary"
            levels = 1
        }
    } | ConvertTo-Json -Depth 5

    $adjustResp = Invoke-RestMethod -Uri "http://127.0.0.1:$TestPort/api/state" -Method Post -Body $adjustPayload -ContentType "application/json" -TimeoutSec 5
    Assert-Test ($adjustResp.bestiary -gt 5) "POST /api/state com adjust key='bestiary' incrementou 1 nível"

    # 5. Páginas Web (Overlay e Painel) - Usando -UseBasicParsing para evitar dependência do mshtml/IE
    $panelResp = Invoke-WebRequest -Uri "http://127.0.0.1:$TestPort/painel" -UseBasicParsing -TimeoutSec 5
    Assert-Test ($panelResp.StatusCode -eq 200) "GET /painel retorna status 200 OK"
    Assert-Test ($panelResp.RawContentLength -gt 100000) "GET /painel serviu conteúdo HTML do aplicativo"

    $overlayResp = Invoke-WebRequest -Uri "http://127.0.0.1:$TestPort/overlay" -UseBasicParsing -TimeoutSec 5
    Assert-Test ($overlayResp.StatusCode -eq 200) "GET /overlay retorna status 200 OK"

    # 6. Restauração do Estado
    $resetPayload = @{
        patch = @{
            title = "Bounty Talisman"
            damage = 2.5
            bestiary = 5.0
            characterName = "Seu personagem"
            slot1 = $false
            monster1 = ""
        }
    } | ConvertTo-Json -Depth 5

    $cleanResp = Invoke-RestMethod -Uri "http://127.0.0.1:$TestPort/api/state" -Method Post -Body $resetPayload -ContentType "application/json" -TimeoutSec 5
    Assert-Test ($cleanResp.title -eq "Bounty Talisman") "Estado restaurado com sucesso para 'Bounty Talisman'"
    Assert-Test ($cleanResp.damage -eq 2.5) "Dano restaurado com sucesso para 2.5"

} finally {
    if ($serverProc -and -not $serverProc.HasExited) {
        Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nResumo da API: $passedTests passaram, $failedTests falharam de $totalTests testes." -ForegroundColor $(if ($failedTests -eq 0) { 'Green' } else { 'Red' })

if ($failedTests -gt 0) {
    exit 1
}

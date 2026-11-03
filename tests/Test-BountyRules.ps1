<#
.SYNOPSIS
    Testes unitários para regras de cálculo do Bounty Talisman.
.DESCRIPTION
    Verifica a progressão matemática das faixas de atributos (Damage, Leech, Loot, Bestiary)
    e custos de desbloqueio de slots da Preferred List.
#>

param([switch]$VerboseOutput)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rulesPath = Join-Path $projectRoot 'src\BountyStudio.Shared\Data\rules.json'
$slotCostsPath = Join-Path $projectRoot 'src\BountyStudio.Shared\Data\slot-costs.json'

if (-not (Test-Path $rulesPath)) {
    throw "rules.json não encontrado em $rulesPath"
}

$rules = Get-Content -LiteralPath $rulesPath -Raw | ConvertFrom-Json
$slotCosts = Get-Content -LiteralPath $slotCostsPath -Raw | ConvertFrom-Json

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Assert-Equal($Actual, $Expected, [string]$Message) {
    $script:totalTests++
    if ($Actual -eq $Expected) {
        $script:passedTests++
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        $script:failedTests++
        Write-Host "  [FAIL] $Message - Esperado: $Expected, Obtido: $Actual" -ForegroundColor Red
    }
}

function Build-LevelTable($rule) {
    $value = [int][Math]::Round($rule.base * 100)
    $values = [System.Collections.Generic.List[double]]::new()
    $spent = [System.Collections.Generic.List[long]]::new()
    $values.Add($value / 100.0)
    $spent.Add(0)
    $total = 0
    foreach ($band in $rule.bands) {
        $end = [int][Math]::Round($band.until * 100)
        $step = [int][Math]::Round($band.step * 100)
        $cost = [long]$band.initialCost
        while ($value -lt $end) {
            $value = [Math]::Min($end, $value + $step)
            $values.Add($value / 100.0)
            $total += $cost
            $spent.Add($total)
            $cost += [long]$band.costStep
        }
    }
    return @{ Values = $values.ToArray(); Spent = $spent.ToArray() }
}

Write-Host "=== TESTES DE REGRAS DE PROGRESSÃO DO TALISMÃ ===" -ForegroundColor Cyan

# 1. Teste de slots
Assert-Equal $slotCosts.Count 5 "Total de 5 slots de preferred list"
Assert-Equal $slotCosts[0] 0 "Slot 0 é gratuito (0 pontos)"
Assert-Equal $slotCosts[1] 300 "Slot 1 custa 300 pontos"
Assert-Equal $slotCosts[2] 600 "Slot 2 custa 600 pontos"
Assert-Equal $slotCosts[3] 900 "Slot 3 custa 900 pontos"
Assert-Equal $slotCosts[4] 1200 "Slot 4 custa 1200 pontos"

$totalSlotCost = 0
foreach ($c in $slotCosts) { $totalSlotCost += $c }
Assert-Equal $totalSlotCost 3000 "Custo total para desbloquear todos os slots = 3000 pontos"

# 2. Teste de regras de dano
$dmgRule = $rules.damage
Assert-Equal $dmgRule.base 2.5 "Dano base deve ser 2.5%"
Assert-Equal $dmgRule.max 50 "Dano máximo deve ser 50%"
Assert-Equal $dmgRule.bands.Count 3 "Dano possui 3 faixas de progressão"

$dmgTable = Build-LevelTable $dmgRule
Assert-Equal $dmgTable.Values[0] 2.5 "Primeiro nível de dano é 2.5"
Assert-Equal $dmgTable.Spent[0] 0 "Primeiro nível de dano tem custo 0"
Assert-Equal $dmgTable.Values[-1] 50.0 "Último nível de dano alcança o teto de 50%"

# 3. Teste de Leech e Loot (mesma estrutura de dano)
foreach ($attr in @('leech', 'loot')) {
    $rule = $rules.$attr
    Assert-Equal $rule.base 2.5 "$attr base deve ser 2.5%"
    Assert-Equal $rule.max 50 "$attr máximo deve ser 50%"
    $tbl = Build-LevelTable $rule
    Assert-Equal $tbl.Values[-1] 50.0 "$attr teto deve ser 50%"
}

# 4. Teste de Bestiary
$bestiaryRule = $rules.bestiary
Assert-Equal $bestiaryRule.base 5 "Bestiary base deve ser 5%"
Assert-Equal $bestiaryRule.max 100 "Bestiary máximo deve ser 100%"
$bestiaryTable = Build-LevelTable $bestiaryRule
Assert-Equal $bestiaryTable.Values[-1] 100.0 "Bestiary teto deve ser 100%"

Write-Host "`nResumo: $passedTests passaram, $failedTests falharam de $totalTests testes." -ForegroundColor $(if ($failedTests -eq 0) { 'Green' } else { 'Red' })

if ($failedTests -gt 0) {
    exit 1
}


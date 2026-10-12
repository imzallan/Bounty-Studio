param(
    [Parameter(Mandatory = $true)][int]$ParentPid,
    [Parameter(Mandatory = $true)][string]$StagedPath,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256
)

$ErrorActionPreference = 'Stop'
$logPath = Join-Path $env:LOCALAPPDATA 'Bounty Studio\App\logs\update.log'

function Write-UpdateLog([string]$Message) {
    try {
        $folder = Split-Path -Parent $logPath
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        Add-Content -LiteralPath $logPath -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8
    } catch { }
}

$target = [IO.Path]::GetFullPath($TargetPath)
$staged = [IO.Path]::GetFullPath($StagedPath)
$folder = Split-Path -Parent $target
$replacement = $target + '.update'
$backup = $target + '.previous'
$replaced = $false

try {
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        $parent = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
        if ($null -eq $parent) { break }
        Start-Sleep -Milliseconds 500
    }
    if (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue) { throw 'O aplicativo anterior não encerrou no tempo esperado.' }
    if (-not (Test-Path -LiteralPath $staged -PathType Leaf)) { throw 'O arquivo baixado não foi encontrado.' }
    $stagedHash = (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash
    if ($stagedHash -ine $ExpectedSha256) { throw 'O hash do arquivo baixado não confere.' }

    Remove-Item -LiteralPath $replacement -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    [IO.File]::Copy($staged, $replacement, $false)
    if ((Get-FileHash -LiteralPath $replacement -Algorithm SHA256).Hash -ine $ExpectedSha256) {
        throw 'A cópia temporária do aplicativo não passou na verificação SHA-256.'
    }

    [IO.File]::Replace($replacement, $target, $backup)
    $replaced = $true
    $started = Start-Process -FilePath $target -WorkingDirectory $folder -PassThru
    Start-Sleep -Seconds 3
    $started.Refresh()
    if ($started.HasExited) { throw 'A nova versão encerrou durante a inicialização.' }

    Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
    Write-UpdateLog 'Atualização aplicada e nova versão iniciada.'
} catch {
    Write-UpdateLog ('Falha ao aplicar atualização: ' + $_.Exception.Message)
    if ($replaced -and (Test-Path -LiteralPath $backup -PathType Leaf)) {
        try {
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
            [IO.File]::Move($backup, $target)
        } catch { Write-UpdateLog ('Falha ao restaurar a versão anterior: ' + $_.Exception.Message) }
    }
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        try {
            $restart = New-Object System.Diagnostics.ProcessStartInfo
            $restart.FileName = $target
            $restart.WorkingDirectory = $folder
            $restart.UseShellExecute = $false
            $restart.EnvironmentVariables['BOUNTY_STUDIO_SKIP_UPDATE'] = '1'
            [System.Diagnostics.Process]::Start($restart) | Out-Null
        } catch { Write-UpdateLog ('Falha ao reabrir o aplicativo: ' + $_.Exception.Message) }
    }
}

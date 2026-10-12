param(
    [string]$Version = '',
    [string]$GitHubRepository = $env:GITHUB_REPOSITORY,
    [string]$OutputFileName = 'BountyStudio.exe'
)

$ErrorActionPreference = 'Stop'
$desktopRoot = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $desktopRoot)
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$icon = Join-Path $desktopRoot 'BountyStudio.ico'
$manifest = Join-Path $desktopRoot 'app.manifest'
$vendor = Join-Path $desktopRoot 'vendor\webview2'
$outputDir = Join-Path $projectRoot 'dist'
if ([IO.Path]::GetFileName($OutputFileName) -ne $OutputFileName -or $OutputFileName -notmatch '\.exe$') { throw 'OutputFileName deve ser apenas um nome de arquivo .exe.' }
$outputExe = Join-Path $outputDir $OutputFileName
$manifestDir = Join-Path $desktopRoot 'obj'
$payloadManifest = Join-Path $manifestDir 'Payload.manifest'
$buildInfoTemplate = Join-Path $desktopRoot 'BuildInfo.cs.template'
$buildInfoSource = Join-Path $manifestDir 'BuildInfo.cs'
$versionFile = Join-Path $projectRoot 'VERSION'

if ([string]::IsNullOrWhiteSpace($Version)) { $Version = (Get-Content -LiteralPath $versionFile -Raw).Trim() }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Informe a versão no formato SemVer X.Y.Z, por exemplo 1.0.1.' }
if (-not [string]::IsNullOrWhiteSpace($GitHubRepository) -and $GitHubRepository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw 'GitHubRepository deve ter o formato owner/repository.'
}

if (-not (Test-Path -LiteralPath $compiler)) { throw 'Compilador .NET Framework 4.x nao encontrado. Execute este script em um Windows com o runtime .NET Framework.' }
if (-not (Test-Path -LiteralPath $icon)) { & (Join-Path $desktopRoot 'GenerateIcon.ps1') | Out-Null }
if (-not (Test-Path -LiteralPath $manifest)) { throw 'Manifesto do aplicativo nao encontrado.' }
New-Item -ItemType Directory -Force -Path $outputDir,$manifestDir | Out-Null

$template = [System.IO.File]::ReadAllText($buildInfoTemplate)
if ([string]::IsNullOrWhiteSpace($GitHubRepository)) { $GitHubRepository = '' }
$buildInfo = $template.Replace('__VERSION__', $Version).Replace('__GITHUB_REPOSITORY__', $GitHubRepository)
[System.IO.File]::WriteAllText($buildInfoSource, $buildInfo, [System.Text.UTF8Encoding]::new($false))

$versionParts = $Version.Split('.')
$displayVersion = 'v' + $versionParts[0] + '.' + $versionParts[1]
$sourceHtml = Join-Path $projectRoot 'src\BountyStudio.Web\overlay.html'
$versionedHtml = Join-Path $manifestDir 'overlay.versioned.html'
$htmlText = [System.IO.File]::ReadAllText($sourceHtml, [System.Text.Encoding]::UTF8).Replace('class="app-version">v1.0</span>', 'class="app-version">' + $displayVersion + '</span>')
[System.IO.File]::WriteAllText($versionedHtml, $htmlText, [System.Text.UTF8Encoding]::new($false))

$payload = @(
    @{ Source = 'src\BountyStudio.Desktop\obj\overlay.versioned.html'; Resource = 'BountyStudio.Payload.Html'; Target = '251vqzs.html' },
    @{ Source = 'src\BountyStudio.Server\servidor-windows.ps1'; Resource = 'BountyStudio.Payload.Server'; Target = 'servidor-windows.ps1' },
    @{ Source = 'src\BountyStudio.Desktop\apply-update.ps1'; Resource = 'BountyStudio.Payload.UpdateHelper'; Target = 'updates\apply-update.ps1' },
    @{ Source = 'assets\ffmpeg\ffmpeg.exe'; Resource = 'BountyStudio.Payload.Encoder'; Target = 'tools\ffmpeg.exe' },
    @{ Source = 'assets\ffmpeg\ffmpeg-manifest.json'; Resource = 'BountyStudio.Payload.EncoderManifest'; Target = 'tools\ffmpeg-manifest.json' },
    @{ Source = 'assets\ffmpeg\FFMPEG_LICENSE.txt'; Resource = 'BountyStudio.Payload.FfmpegLicense'; Target = 'tools\FFMPEG_LICENSE.txt' },
    @{ Source = 'docs\GUIA.md'; Resource = 'BountyStudio.Payload.Guide'; Target = 'LEIA_PRIMEIRO.md' },
    @{ Source = 'docs\CREDITOS.md'; Resource = 'BountyStudio.Payload.Credits'; Target = 'CREDITOS.md' },
    @{ Source = 'src\BountyStudio.Desktop\BountyStudio.ico'; Resource = 'BountyStudio.Payload.Icon'; Target = 'BountyStudio.ico' },
    @{ Source = 'src\BountyStudio.Desktop\vendor\webview2\Microsoft.Web.WebView2.Core.dll'; Resource = 'BountyStudio.Payload.WebViewCore'; Target = 'Microsoft.Web.WebView2.Core.dll' },
    @{ Source = 'src\BountyStudio.Desktop\vendor\webview2\Microsoft.Web.WebView2.WinForms.dll'; Resource = 'BountyStudio.Payload.WebViewForms'; Target = 'Microsoft.Web.WebView2.WinForms.dll' },
    @{ Source = 'src\BountyStudio.Desktop\vendor\webview2\WebView2Loader.dll'; Resource = 'BountyStudio.Payload.WebViewLoader'; Target = 'WebView2Loader.dll' },
    @{ Source = 'src\BountyStudio.Desktop\vendor\webview2\WEBVIEW2_LICENSE.txt'; Resource = 'BountyStudio.Payload.WebViewLicense'; Target = 'licenses\webview2\LICENSE.txt' },
    @{ Source = 'src\BountyStudio.Desktop\vendor\webview2\WEBVIEW2_NOTICE.txt'; Resource = 'BountyStudio.Payload.WebViewNotice'; Target = 'licenses\webview2\NOTICE.txt' }
)

$manifestLines = New-Object System.Collections.Generic.List[string]
$arguments = @(
    '/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/codepage:65001',
    '/reference:System.dll', '/reference:System.Core.dll', '/reference:System.Runtime.Serialization.dll', '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll',
    ('/reference:' + (Join-Path $vendor 'Microsoft.Web.WebView2.Core.dll')),
    ('/reference:' + (Join-Path $vendor 'Microsoft.Web.WebView2.WinForms.dll')),
    ('/win32icon:' + $icon), ('/win32manifest:' + $manifest),
    ('/out:' + $outputExe), (Join-Path $desktopRoot 'Program.cs'), $buildInfoSource
)

foreach ($resource in $payload) {
    $file = Join-Path $projectRoot $resource.Source
    if (-not (Test-Path -LiteralPath $file)) { throw "Arquivo necessario ausente: $file" }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
    $manifestLines.Add($resource.Resource + '|' + $resource.Target + '|' + $hash)
    $arguments += '/resource:' + $file + ',' + $resource.Resource
}

[System.IO.File]::WriteAllLines($payloadManifest, $manifestLines, [System.Text.Encoding]::ASCII)
$arguments += '/resource:' + $payloadManifest + ',BountyStudio.Payload.Manifest'

& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "A compilacao falhou com codigo $LASTEXITCODE." }
Write-Output "Executavel criado: $outputExe"
if ([string]::IsNullOrWhiteSpace($GitHubRepository)) { Write-Warning 'Este build local nao atualiza via GitHub até ser compilado com -GitHubRepository owner/repository.' }

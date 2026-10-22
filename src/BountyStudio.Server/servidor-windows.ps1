# Bounty Studio -- Windows PowerShell 5.1+, no external modules.
# Bound to 127.0.0.1 only. Used when Python is not installed.
param([int]$Port = 8787, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$BountyUtf8 = [System.Text.UTF8Encoding]::new($false)
$BountyProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BountySourceMode = Test-Path -LiteralPath (Join-Path $BountyProjectRoot 'src\BountyStudio.Web\overlay.html')
if ($BountySourceMode) {
    $BountyRoot = $BountyProjectRoot
    $BountyHtmlPath = Join-Path $BountyRoot 'src\BountyStudio.Web\overlay.html'
    $BountyToolsRoot = Join-Path $BountyRoot 'assets\ffmpeg'
}
else {
    $BountyRoot = $PSScriptRoot
    $BountyHtmlPath = Join-Path $BountyRoot '251vqzs.html'
    $BountyToolsRoot = Join-Path $BountyRoot 'tools'
}
$BountyHtml = [System.IO.File]::ReadAllBytes($BountyHtmlPath)
$BountyHtmlText = $BountyUtf8.GetString($BountyHtml)
if ($BountySourceMode) {
    $BountyVersionParts = ([System.IO.File]::ReadAllText((Join-Path $BountyRoot 'VERSION'), $BountyUtf8)).Trim().Split('.')
    $BountyDisplayVersion = if ($BountyVersionParts.Length -ge 2) { 'v' + $BountyVersionParts[0] + '.' + $BountyVersionParts[1] } else { 'v1.0' }
    $BountyHtmlText = $BountyHtmlText.Replace('<span class="app-version">v1.0</span>', '<span class="app-version">' + $BountyDisplayVersion + '</span>')
    $BountyHtml = $BountyUtf8.GetBytes($BountyHtmlText)
}
$BountyDefaultText = [regex]::Match($BountyHtmlText, '<script id="bounty-defaults" type="application/json">(.*?)</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$BountyDefaultObject = $BountyDefaultText | ConvertFrom-Json
$BountyDefaults = @{}
foreach ($property in $BountyDefaultObject.PSObject.Properties) { $BountyDefaults[$property.Name] = $property.Value }
$BountyRuleText = [regex]::Match($BountyHtmlText, '<script id="bounty-rules" type="application/json">(.*?)</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$BountyRules = @{}
foreach ($property in ($BountyRuleText | ConvertFrom-Json).PSObject.Properties) { $BountyRules[$property.Name] = $property.Value }
$BountyLevelValues = @{}
$BountySpentByLevel = @{}
foreach ($key in $BountyRules.Keys) {
    $values = [System.Collections.Generic.List[double]]::new()
    $spent = [System.Collections.Generic.List[long]]::new()
    $value = [int][Math]::Round($BountyRules[$key].base * 100); $total = [long]0
    $values.Add($value / 100.0); $spent.Add(0)
    foreach ($band in $BountyRules[$key].bands) {
        $end = [int][Math]::Round($band.until * 100); $step = [int][Math]::Round($band.step * 100)
        $cost = [long]$band.initialCost
        while ($value -lt $end) {
            $value = [Math]::Min($end, $value + $step); $values.Add($value / 100.0)
            $total += $cost; $spent.Add($total); $cost += [long]$band.costStep
        }
    }
    $BountyLevelValues[$key] = $values.ToArray()
    $BountySpentByLevel[$key] = $spent.ToArray()
}
$BountySlotCosts = ([regex]::Match($BountyHtmlText, '<script id="bounty-slot-costs" type="application/json">(.*?)</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value) | ConvertFrom-Json
$BountyCreatures = @{}
$BountyCreatureText = [regex]::Match($BountyHtmlText, '<script id="bounty-creatures" type="application/json">(.*?)</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
foreach ($creature in ($BountyCreatureText | ConvertFrom-Json)) { $BountyCreatures[$creature.name] = $creature }
$BountyEmbeddedSprites = @{}
$BountySpriteText = [regex]::Match($BountyHtmlText, '<script id="bounty-sprites" type="application/json">(.*?)</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
foreach ($property in ($BountySpriteText | ConvertFrom-Json).PSObject.Properties) { $BountyEmbeddedSprites[$property.Name] = $property.Value }
$BountyLimits = @{}
foreach ($key in $BountyRules.Keys) { $BountyLimits[$key] = $BountyRules[$key].max }
$BountyEditable = @($BountyDefaults.Keys | Where-Object { $_ -notin @('schemaVersion','revision','updatedAt','points','slot0') })
$BountyMajorCharms = @('Carnage','Curse','Divine Wrath','Dodge','Enflame','Freeze','Low Blow','Overpower','Overflux','Parry','Poison','Savage Blow','Wound','Zap')
$BountyMinorCharms = @('Adrenaline Burst','Bless','Cleanse','Cripple','Fatal Hold','Gut','Numb','Scavenge','Vampiric Embrace','Void Inversion',"Void's Call")
$BountyCharmIconUrls = @{
    'Carnage'='https://www.tibiawiki.com.br/images/3/30/Carnage_Icon.gif'; 'Curse'='https://www.tibiawiki.com.br/images/e/e3/Curse_Icon.gif'
    'Divine Wrath'='https://www.tibiawiki.com.br/images/c/cc/Divine_Wrath_Icon.gif'; 'Dodge'='https://www.tibiawiki.com.br/images/2/25/Dodge_Icon.gif'
    'Enflame'='https://www.tibiawiki.com.br/images/7/74/Enflame_Icon.gif'; 'Freeze'='https://www.tibiawiki.com.br/images/7/72/Freeze_Icon.gif'
    'Low Blow'='https://www.tibiawiki.com.br/images/8/8c/Low_Blow_Icon.gif'; 'Overpower'='https://www.tibiawiki.com.br/images/2/2b/Overpower_Icon.gif'
    'Overflux'='https://www.tibiawiki.com.br/images/2/20/Overflux_Icon.gif'; 'Parry'='https://www.tibiawiki.com.br/images/a/a8/Parry_Icon.gif'
    'Poison'='https://www.tibiawiki.com.br/images/5/59/Poison_Icon.gif'; 'Savage Blow'='https://www.tibiawiki.com.br/images/e/e6/Savage_Blow_Icon.gif'
    'Wound'='https://www.tibiawiki.com.br/images/d/d9/Wound_Icon.gif'; 'Zap'='https://www.tibiawiki.com.br/images/2/2f/Zap_Icon.gif'
    'Adrenaline Burst'='https://www.tibiawiki.com.br/images/1/1d/Adrenaline_Burst_Icon.gif'; 'Bless'='https://www.tibiawiki.com.br/images/6/6c/Bless_Icon.gif'
    'Cleanse'='https://www.tibiawiki.com.br/images/9/92/Cleanse_Icon.gif'; 'Cripple'='https://www.tibiawiki.com.br/images/9/9c/Cripple_Icon.gif'
    'Fatal Hold'='https://www.tibiawiki.com.br/images/b/b8/Fatal_Hold_Icon.gif'; 'Gut'='https://www.tibiawiki.com.br/images/f/f0/Gut_Icon.gif'
    'Numb'='https://www.tibiawiki.com.br/images/0/03/Numb_Icon.gif'; 'Scavenge'='https://www.tibiawiki.com.br/images/5/5f/Scavenge_Icon.gif'
    'Vampiric Embrace'='https://www.tibiawiki.com.br/images/4/41/Vampiric_Embrace_Icon.gif'; 'Void Inversion'='https://www.tibiawiki.com.br/images/7/79/Void_Inversion_Icon.gif'
    "Void's Call"='https://www.tibiawiki.com.br/images/c/c6/Void%27s_Call_Icon.gif'
}
$BountyDifficulties = @('', 'Beginner','Adept','Expert','Master')
$BountyState = $BountyDefaults.Clone()
$BountyStatePath = Join-Path $BountyRoot 'dados\bounty-state.json'
$BountyCreatureInfoCachePath = Join-Path $BountyRoot 'dados\creature-info-cache.json'
$BountyCreatureInfoCache = @{}
$BountyAddress = "http://127.0.0.1:$Port"

function Get-BountyFiniteNumber($Value) {
    if ($null -eq $Value -or $Value -is [bool] -or $Value -is [string] -or $Value -isnot [System.ValueType]) { throw [System.ArgumentException]::new('Informe um numero valido.') }
    try { $n = [double]$Value } catch { throw [System.ArgumentException]::new('Informe um numero valido.') }
    if ([double]::IsNaN($n) -or [double]::IsInfinity($n)) { throw [System.ArgumentException]::new('Informe um numero valido.') }
    return $n
}

function Get-BountyNumber($Value, [double]$Maximum) {
    $n = Get-BountyFiniteNumber $Value
    return [Math]::Round([Math]::Max([double]0, [Math]::Min([double]$Maximum, [double]$n)), 2)
}

function Get-BountyAttributeLevel([string]$Key, $Value) {
    $rule = $BountyRules[$Key]; $n = Get-BountyFiniteNumber $Value
    $n = [Math]::Max([double]$rule.base, [Math]::Min([double]$rule.max, [double]$n))
    $values = $BountyLevelValues[$Key]; $best = 0; $distance = [double]::PositiveInfinity
    for ($i=0; $i -lt $values.Length; $i++) {
        $d = [Math]::Abs($values[$i] - $n)
        if ($d -le ($distance + 0.000000001)) { $best=$i; $distance=$d }
    }
    return $best
}

function Get-BountyAttributeValue([string]$Key, $Value) {
    return $BountyLevelValues[$Key][(Get-BountyAttributeLevel $Key $Value)]
}

function Set-BountyDerivedPoints([hashtable]$State) {
    $State.slot0 = $true; $available = $true
    for ($i=1; $i -le 4; $i++) { $available = ($available -and [bool]$State["slot$i"]); $State["slot$i"] = $available }
    $total = 0
    foreach ($key in $BountyRules.Keys) {
        $level = Get-BountyAttributeLevel $key $State[$key]
        $State[$key] = $BountyLevelValues[$key][$level]
        $total += $BountySpentByLevel[$key][$level]
    }
    for ($i=0; $i -le 4; $i++) { if ($State["slot$i"]) { $total += $BountySlotCosts[$i] } }
    $State.points = [long]$total; $State.schemaVersion = $BountyDefaults.schemaVersion
    return $State
}
function Apply-BountyPatch([hashtable]$Current, $Patch) {
    if ($null -eq $Patch -or ($Patch -isnot [pscustomobject] -and $Patch -isnot [hashtable])) { throw [System.ArgumentException]::new('Formato de alteracao invalido.') }
    $next = $Current.Clone()
    $properties = if ($Patch -is [hashtable]) { @($Patch.Keys | ForEach-Object { [pscustomobject]@{Name=$_; Value=$Patch[$_]} }) } else { @($Patch.PSObject.Properties) }
    foreach ($property in $properties) {
        $key = $property.Name; $value = $property.Value
        if ($BountyEditable -cnotcontains $key) { throw [System.ArgumentException]::new('Campo invalido.') }
        if ($BountyRules.ContainsKey($key)) { $next[$key] = Get-BountyAttributeValue $key $value }
        elseif ($BountyLimits.ContainsKey($key)) { $next[$key] = Get-BountyNumber $value $BountyLimits[$key] }
        elseif ($key -ceq 'theme') {
            if (@('emerald','sapphire','ruby') -cnotcontains $value) { throw [System.ArgumentException]::new('Tema invalido.') }
            $next[$key] = $value
        }
        elseif ($key -ceq 'difficulty') {
            if ($value -isnot [string] -or $BountyDifficulties -cnotcontains $value) { throw [System.ArgumentException]::new('Dificuldade da bounty invalida.') }
            $next[$key] = $value
        }
        elseif ($key.StartsWith('charm')) {
            if ($value -isnot [string] -or ($value -ne '' -and $BountyMajorCharms -cnotcontains $value)) { throw [System.ArgumentException]::new('Charm invalido.') }
            $next[$key] = $value
        }
        elseif ($key.StartsWith('minorCharm')) {
            if ($value -isnot [string] -or ($value -ne '' -and $BountyMinorCharms -cnotcontains $value)) { throw [System.ArgumentException]::new('Minor Charm invalido.') }
            $next[$key] = $value
        }
        elseif ($BountyDefaults[$key] -is [bool]) {
            if ($value -isnot [bool]) { throw [System.ArgumentException]::new('Opcao invalida.') }
            $next[$key] = $value
        }
        elseif ($key.StartsWith('monster')) {
            if ($value -isnot [string] -or ($value.Trim() -and -not $BountyCreatures.ContainsKey($value.Trim()))) { throw [System.ArgumentException]::new('Selecione um monstro do catalogo.') }
            $next[$key] = if ($value.Trim()) { $BountyCreatures[$value.Trim()].name } else { '' }
        }
        else {
            if ($value -isnot [string]) { throw [System.ArgumentException]::new('Texto invalido.') }
            $limit = if ($key -cin @('title','characterName')) { 32 } else { 44 }
            $next[$key] = $value.Substring(0, [Math]::Min($value.Length, $limit))
        }
    }
    foreach ($property in $properties) {
        if ($property.Name -cmatch '^slot[1-4]$' -and $property.Value -eq $true) {
            $index = [int]$property.Name.Substring(4)
            for ($previous=1; $previous -lt $index; $previous++) {
                if (-not $next["slot$previous"]) { throw [System.ArgumentException]::new('Adquira os slots anteriores primeiro.') }
            }
        }
    }
    return (Set-BountyDerivedPoints $next)
}

function Save-BountyState([hashtable]$State) {
    $directory = [System.IO.Path]::GetDirectoryName($BountyStatePath)
    [void][System.IO.Directory]::CreateDirectory($directory)
    $temporary = $BountyStatePath + '.tmp'
    [System.IO.File]::WriteAllText($temporary, ($State | ConvertTo-Json -Depth 8), $BountyUtf8)
    if ([System.IO.File]::Exists($BountyStatePath)) { [System.IO.File]::Replace($temporary, $BountyStatePath, [NullString]::Value) }
    else { [System.IO.File]::Move($temporary, $BountyStatePath) }
}

function Write-BountyResponse($Stream, [int]$Code, $Body, [string]$ContentType='application/json; charset=utf-8', [string]$Location='') {
    if ($Body -is [byte[]]) { $bytes = $Body }
    else { $bytes = $BountyUtf8.GetBytes(($Body | ConvertTo-Json -Depth 8 -Compress)) }
    # Preserve empty byte arrays (PowerShell otherwise unwraps them to null).
    if ($null -eq $bytes) { $bytes = [byte[]]@() }
    $reason = switch ($Code) {200 {'OK'} 204 {'No Content'} 302 {'Found'} 400 {'Bad Request'} 403 {'Forbidden'} 404 {'Not Found'} 405 {'Method Not Allowed'} 415 {'Unsupported Media Type'} default {'Internal Server Error'}}
    $header = "HTTP/1.1 $Code $reason`r`nContent-Type: $ContentType`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nX-Frame-Options: SAMEORIGIN`r`nContent-Security-Policy: default-src 'self' 'unsafe-inline' data:; connect-src 'self'; img-src 'self' data: https://www.tibiawiki.com.br; frame-ancestors 'self';`r`nReferrer-Policy: strict-origin-when-cross-origin`r`nConnection: close`r`n"
    if ($Location) { $header += "Location: $Location`r`n" }
    $header += "`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($bytes.Length -gt 0) { $Stream.Write($bytes, 0, $bytes.Length) }
    $Stream.Flush()
}

$BountyJobs = @{}

function Get-BountyQuery([string]$Target) {
    $result = @{}
    $split = $Target -split '\?', 2
    if ($split.Length -gt 1) {
        foreach ($part in ($split[1] -split '&')) {
            $pair = $part -split '=', 2
            if ($pair.Length -eq 2) { $result[[Uri]::UnescapeDataString($pair[0])] = [Uri]::UnescapeDataString($pair[1].Replace('+',' ')) }
        }
    }
    return $result
}

function Read-BountyBody($Stream, [int]$Size) {
    $bytes = [byte[]]::new($Size); $read = 0
    while ($read -lt $Size) { $count=$Stream.Read($bytes,$read,$Size-$read); if ($count -le 0) { throw [System.ArgumentException]::new('Requisicao incompleta.') }; $read+=$count }
    return ,$bytes
}

function Get-BountySprite([string]$Name) {
    if (-not $BountyCreatures.ContainsKey($Name)) { throw [System.ArgumentException]::new('Monstro nao encontrado no catalogo.') }
    $creature = $BountyCreatures[$Name]
    if ($BountyEmbeddedSprites.ContainsKey($creature.name)) { return ,([Convert]::FromBase64String(($BountyEmbeddedSprites[$creature.name] -split ',',2)[1])) }
    $cache = Join-Path $BountyRoot 'dados\sprites'
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try { $digest = $hash.ComputeHash($BountyUtf8.GetBytes($creature.name)); $key = ([BitConverter]::ToString($digest)).Replace('-','').ToLower().Substring(0,24) } finally { $hash.Dispose() }
    $file = Join-Path $cache ($key + '.gif')
    if ([System.IO.File]::Exists($file)) { $bytes = [System.IO.File]::ReadAllBytes($file) }
    else {
        if (-not $creature.url.StartsWith('https://www.tibiawiki.com.br/images/')) { throw [System.ArgumentException]::new('Origem de imagem invalida.') }
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $request = [System.Net.HttpWebRequest]::Create($creature.url)
            $request.UserAgent = 'BountyStudio/1.0 (local overlay)'; $request.Timeout = 12000; $request.ReadWriteTimeout = 12000
            $response = $request.GetResponse(); $spriteStream = $response.GetResponseStream(); $memory = [System.IO.MemoryStream]::new()
            try {
                $chunk = [byte[]]::new(8192)
                while (($count=$spriteStream.Read($chunk,0,$chunk.Length)) -gt 0) { $memory.Write($chunk,0,$count); if ($memory.Length -gt 2097152) { throw 'too large' } }
                $bytes = $memory.ToArray()
            } finally { $memory.Dispose(); $spriteStream.Dispose(); $response.Dispose() }
        } catch { throw [System.ArgumentException]::new('GIF indisponivel. Verifique a internet e clique em recarregar.') }
        if ($bytes.Length -lt 6 -or $bytes.Length -gt 2097152 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'GIF8') { throw [System.ArgumentException]::new('GIF invalido.') }
        [void][System.IO.Directory]::CreateDirectory($cache); [System.IO.File]::WriteAllBytes($file,$bytes)
    }
    if ($bytes.Length -lt 6 -or $bytes.Length -gt 2097152 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'GIF8') { throw [System.ArgumentException]::new('GIF invalido.') }
    return ,$bytes
}

function Get-BountyCharmIcon([string]$Name) {
    if (-not $BountyCharmIconUrls.ContainsKey($Name)) { throw [System.ArgumentException]::new('Charm nao encontrado no catalogo.') }
    $cache = Join-Path $BountyRoot 'dados\charm-icons'
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try { $digest = $hash.ComputeHash($BountyUtf8.GetBytes($Name)); $key = ([BitConverter]::ToString($digest)).Replace('-','').ToLower().Substring(0,24) } finally { $hash.Dispose() }
    $file = Join-Path $cache ($key + '.gif')
    if ([System.IO.File]::Exists($file)) { $bytes = [System.IO.File]::ReadAllBytes($file) }
    else {
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $request = [System.Net.HttpWebRequest]::Create($BountyCharmIconUrls[$Name])
            $request.UserAgent = 'BountyStudio/1.0 (local overlay; charm icons from Tibia Wiki)'; $request.Timeout = 12000; $request.ReadWriteTimeout = 12000
            $response = $request.GetResponse(); $iconStream = $response.GetResponseStream(); $memory = [System.IO.MemoryStream]::new()
            try {
                $chunk = [byte[]]::new(8192)
                while (($count=$iconStream.Read($chunk,0,$chunk.Length)) -gt 0) { $memory.Write($chunk,0,$count); if ($memory.Length -gt 65536) { throw 'too large' } }
                $bytes = $memory.ToArray()
            } finally { $memory.Dispose(); $iconStream.Dispose(); $response.Dispose() }
        } catch { throw [System.ArgumentException]::new('Icone de charm indisponivel. Verifique a internet.') }
        if ($bytes.Length -lt 6 -or $bytes.Length -gt 65536 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'GIF8') { throw [System.ArgumentException]::new('Icone de charm invalido.') }
        [void][System.IO.Directory]::CreateDirectory($cache); [System.IO.File]::WriteAllBytes($file,$bytes)
    }
    if ($bytes.Length -lt 6 -or $bytes.Length -gt 65536 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'GIF8') { throw [System.ArgumentException]::new('Icone de charm invalido.') }
    return ,$bytes
}

function Get-BountyCreatureInfoNumber([string]$Wikitext, [string]$Key) {
    $match = [regex]::Match($Wikitext, '(?im)^\s*\|\s*' + [regex]::Escape($Key) + '\s*=\s*([^\r\n]*)')
    if (-not $match.Success) { return $null }
    $value = ($match.Groups[1].Value -split '\|',2)[0] -replace '\D',''
    if (-not $value) { return $null }
    try { return [long]$value } catch { return $null }
}

function Save-BountyCreatureInfoCache {
    $temporary = $BountyCreatureInfoCachePath + '.tmp'
    $json = ConvertTo-Json -InputObject $BountyCreatureInfoCache -Depth 8
    [System.IO.File]::WriteAllText($temporary, $json, $BountyUtf8)
    if ([System.IO.File]::Exists($BountyCreatureInfoCachePath)) { [System.IO.File]::Replace($temporary, $BountyCreatureInfoCachePath, [NullString]::Value) }
    else { [System.IO.File]::Move($temporary, $BountyCreatureInfoCachePath) }
}

function Get-BountyCreatureInfo([string]$Name) {
    if (-not $BountyCreatures.ContainsKey($Name)) { throw [System.ArgumentException]::new('Monstro nao encontrado no catalogo.') }
    $canonical = $BountyCreatures[$Name].name
    $source = 'https://www.tibiawiki.com.br/wiki/' + [uri]::EscapeDataString($canonical.Replace(' ','_'))
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $cached = $BountyCreatureInfoCache[$canonical]
    if ($null -ne $cached) {
        try {
            if (($now - [double]$cached.cachedAt) -lt 2592000) { return @{name=$canonical;hp=$cached.hp;xp=$cached.xp;source=$source;available=$true} }
        } catch {}
    }

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $page = [uri]::EscapeDataString($canonical)
        $url = 'https://www.tibiawiki.com.br/api.php?action=parse&page=' + $page + '&prop=wikitext&format=json'
        $request = [System.Net.HttpWebRequest]::Create($url)
        $request.UserAgent = 'BountyStudio/1.0 (local overlay; creature stats from Tibia Wiki)'
        $request.Timeout = 8000; $request.ReadWriteTimeout = 8000
        $response = $request.GetResponse(); $reader = [System.IO.StreamReader]::new($response.GetResponseStream(), $BountyUtf8)
        try { $json = $reader.ReadToEnd() } finally { $reader.Dispose(); $response.Dispose() }
        $payload = $json | ConvertFrom-Json
        $wikitext = $payload.parse.wikitext
        if ($wikitext -is [pscustomobject]) { $wikitext = $wikitext.'*' }
        if ($wikitext -isnot [string]) { $wikitext = '' }
        $hp = Get-BountyCreatureInfoNumber $wikitext 'hp'
        $xp = Get-BountyCreatureInfoNumber $wikitext 'exp'
        if ($null -ne $hp -or $null -ne $xp) {
            $entry = @{name=$canonical;hp=$hp;xp=$xp;source=$source;cachedAt=$now}
            $BountyCreatureInfoCache[$canonical] = $entry
            try { Save-BountyCreatureInfoCache } catch {}
            return @{name=$canonical;hp=$hp;xp=$xp;source=$source;available=$true}
        }
    } catch {}

    if ($null -ne $cached) { return @{name=$canonical;hp=$cached.hp;xp=$cached.xp;source=$source;available=$true;stale=$true} }
    return @{name=$canonical;hp=$null;xp=$null;source=$source;available=$false}
}

function Get-BountyEncoderError($ErrorObject) {
    $cause=$ErrorObject; $code=0
    while ($cause) {
        if ($cause -is [System.ComponentModel.Win32Exception]) { $code=$cause.NativeErrorCode; break }
        $cause=$cause.InnerException
    }
    if ($code -in @(193,216)) { return 'O Windows nao conseguiu executar o codificador. Este pacote requer Windows de 64 bits.' }
    if ($code -eq 5) { return 'O sistema negou a execucao do codificador. Verifique a permissao de execucao de tools/ffmpeg.exe.' }
    if ($code -eq 2) { return 'O codificador nao foi encontrado. Extraia a pasta tools do pacote atualizado.' }
    if ($code) { return ('Nao foi possivel abrir o codificador de video. Codigo do Windows: '+$code+'.') }
    return 'Nao foi possivel abrir o codificador de video. Reinicie o painel e tente novamente.'
}

function Test-BountyEncoder([string]$Binary) {
    $probe=[System.Diagnostics.Process]::new(); $probe.StartInfo.FileName=$Binary; $probe.StartInfo.Arguments='-version'
    $probe.StartInfo.UseShellExecute=$false; $probe.StartInfo.CreateNoWindow=$true
    $probe.StartInfo.RedirectStandardOutput=$true; $probe.StartInfo.RedirectStandardError=$true
    try {
        [void]$probe.Start(); $probe.BeginOutputReadLine(); $probe.BeginErrorReadLine()
        if (-not $probe.WaitForExit(8000)) { $probe.Kill(); throw [System.ArgumentException]::new('O codificador nao respondeu. Reinicie o painel e tente novamente.') }
        if ($probe.ExitCode -ne 0) { throw [System.ArgumentException]::new('O codificador nao iniciou corretamente. Reinicie o painel e verifique a pasta tools do pacote atualizado.') }
    } catch [System.ArgumentException] { throw }
    catch { throw [System.ArgumentException]::new((Get-BountyEncoderError $_.Exception)) }
    finally { $probe.Dispose() }
}

function Get-BountyEncoder {
    $bundled = Join-Path $BountyToolsRoot 'ffmpeg.exe'
    if ([System.IO.File]::Exists($bundled)) {
        try { $manifest=[System.IO.File]::ReadAllText((Join-Path $BountyToolsRoot 'ffmpeg-manifest.json'),$BountyUtf8) | ConvertFrom-Json }
        catch { throw [System.ArgumentException]::new('Os arquivos do codificador estao incompletos. Extraia o pacote atualizado inteiro, incluindo a pasta tools.') }
        if ((Get-Item -LiteralPath $bundled).Length -ne $manifest.size) { throw [System.ArgumentException]::new('O codificador de video esta incompleto. Baixe o pacote atualizado e substitua a pasta tools inteira.') }
        if ((Get-FileHash -LiteralPath $bundled -Algorithm SHA256).Hash -ine $manifest.sha256) { throw [System.ArgumentException]::new('O arquivo do codificador foi alterado ou corrompido. Substitua a pasta tools pelo conteudo do pacote atualizado.') }
        Test-BountyEncoder $bundled
        return $bundled
    }
    $command = Get-Command ffmpeg -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { Test-BountyEncoder $command.Source; return $command.Source }
    throw [System.ArgumentException]::new('Codificador nao encontrado. Extraia todos os arquivos do pacote, incluindo a pasta tools.')
}

function Remove-BountyJob([string]$Id) {
    if (-not $BountyJobs.ContainsKey($Id)) { return }
    $job = $BountyJobs[$Id]; $BountyJobs.Remove($Id)
    if ($job.process) {
        try { if (-not $job.process.HasExited) { $job.process.Kill(); [void]$job.process.WaitForExit(3000) } } catch {}
        $job.process.Dispose()
    }
    if ([System.IO.Directory]::Exists($job.directory)) { Remove-Item -LiteralPath $job.directory -Recurse -Force -ErrorAction SilentlyContinue }
}

function Get-BountyJob([string]$Id) {
    if ($Id -cnotmatch '^[0-9a-f]{32}$' -or -not $BountyJobs.ContainsKey($Id)) { throw [System.ArgumentException]::new('Exportacao nao encontrada. Tente novamente.') }
    $job = $BountyJobs[$Id]; $job.touched = [DateTime]::UtcNow
    return $job
}

function Get-BountyJobStatus($Job) {
    if ($Job.status -eq 'encoding' -and $Job.process.HasExited) {
        $file = Join-Path $Job.directory 'overlay.webm'
        $Job.status = if ($Job.process.ExitCode -eq 0 -and [System.IO.File]::Exists($file) -and (Get-Item -LiteralPath $file).Length -gt 0) { 'ready' } else { 'error' }
    }
    $message = if ($Job.status -eq 'error') { 'Nao foi possivel codificar o video. Extraia o pacote completo e tente novamente.' } else { $null }
    return @{status=$Job.status;error=$message}
}

function Handle-BountyAsset($Stream, [string]$Path, $Query) {
    if ($Path -eq '/api/sprite') { $bytes = Get-BountySprite $Query['name']; Write-BountyResponse $Stream 200 $bytes 'image/gif'; return }
    if ($Path -eq '/api/charm-icon') { $bytes = Get-BountyCharmIcon $Query['name']; Write-BountyResponse $Stream 200 $bytes 'image/gif'; return }
    if ($Path -eq '/api/creature-info') { $info = Get-BountyCreatureInfo $Query['name']; Write-BountyResponse $Stream 200 $info; return }
    $job = Get-BountyJob $Query['id']; $status = Get-BountyJobStatus $job
    if ($Path -eq '/api/export/status') { Write-BountyResponse $Stream 200 $status }
    elseif ($Path -eq '/api/export/video' -and $status.status -eq 'ready') { Write-BountyResponse $Stream 200 ([System.IO.File]::ReadAllBytes((Join-Path $job.directory 'overlay.webm'))) 'video/webm' }
    else { throw [System.ArgumentException]::new('O video ainda nao esta pronto.') }
}

function Handle-BountyExport($Stream, [string]$Path, $Query, $Headers) {
    $size=0
    if (-not [int]::TryParse($Headers['Content-Length'],[ref]$size)) { throw [System.ArgumentException]::new('Tamanho de requisicao invalido.') }
    $type=($Headers['Content-Type'] -split ';')[0].Trim()
    if ($Path -eq '/api/export/frame') {
        if ($type -ne 'image/png' -or $size -lt 33 -or $size -gt 2097152) { throw [System.ArgumentException]::new('Quadro de video invalido.') }
        $bytes=Read-BountyBody $Stream $size
        if ([BitConverter]::ToString($bytes,0,8) -ne '89-50-4E-47-0D-0A-1A-0A' -or [BitConverter]::ToString($bytes,12,4) -ne '49-48-44-52' -or [BitConverter]::ToString($bytes,16,8) -ne '00-00-04-B0-00-00-01-68') { throw [System.ArgumentException]::new('O quadro precisa ser um PNG de 1200 x 360.') }
        $index=-1
        if (-not [int]::TryParse($Query['index'],[ref]$index) -or $index -lt 0 -or $index -ge 270) { throw [System.ArgumentException]::new('Indice de quadro invalido.') }
        $job=Get-BountyJob $Query['id']
        if ($job.status -ne 'collecting') { throw [System.ArgumentException]::new('Esta exportacao nao esta recebendo quadros.') }
        [System.IO.File]::WriteAllBytes((Join-Path $job.directory ('{0:D3}.png' -f $index)),$bytes); [void]$job.frames.Add($index)
        Write-BountyResponse $Stream 200 @{ok=$true}; return
    }
    if ($type -ne 'application/json' -or $size -le 0 -or $size -gt 1024) { throw [System.ArgumentException]::new('Requisicao de exportacao invalida.') }
    try { $payload=$BountyUtf8.GetString((Read-BountyBody $Stream $size)) | ConvertFrom-Json } catch { throw [System.ArgumentException]::new('JSON invalido.') }
    if ($payload -isnot [pscustomobject]) { throw [System.ArgumentException]::new('Requisicao de exportacao invalida.') }
    if ($Path -eq '/api/export/start') {
        if ($payload.fps -ne 30 -or $payload.frameCount -ne 270) { throw [System.ArgumentException]::new('O video precisa ter 9 segundos, a 30 quadros por segundo.') }
        $binary=Get-BountyEncoder
        foreach ($oldId in @($BountyJobs.Keys)) { if (([DateTime]::UtcNow-$BountyJobs[$oldId].touched).TotalSeconds -gt 600) { Remove-BountyJob $oldId } }
        if ($BountyJobs.Count -ge 3) { throw [System.ArgumentException]::new('Aguarde ou cancele a outra exportacao antes de tentar novamente.') }
        $id=[Guid]::NewGuid().ToString('N'); $directory=Join-Path ([System.IO.Path]::GetTempPath()) ('bounty-video-'+$id)
        [void][System.IO.Directory]::CreateDirectory($directory)
        $BountyJobs[$id]=@{directory=$directory;frames=[System.Collections.Generic.HashSet[int]]::new();status='collecting';binary=$binary;touched=[DateTime]::UtcNow;process=$null}
        Write-BountyResponse $Stream 200 @{id=$id}; return
    }
    $id=$Query['id']; $job=Get-BountyJob $id
    if ($Path -eq '/api/export/finish') {
        if ($job.status -ne 'collecting' -or $job.frames.Count -ne 270) { throw [System.ArgumentException]::new('A exportacao precisa dos 270 quadros antes de finalizar.') }
        $framePattern=Join-Path $job.directory '%03d.png'; $output=Join-Path $job.directory 'overlay.webm'
        $arguments='-hide_banner -loglevel error -y -framerate 30 -i "'+$framePattern+'" -frames:v 270 -an -c:v libvpx-vp9 -pix_fmt yuva420p -b:v 0 -lossless 1 -deadline good -cpu-used 4 -threads 2 -auto-alt-ref 0 "'+$output+'"'
        $process=[System.Diagnostics.Process]::new(); $process.StartInfo.FileName=$job.binary; $process.StartInfo.Arguments=$arguments
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true; $process.StartInfo.RedirectStandardError=$true
        try { [void]$process.Start(); $process.BeginErrorReadLine() } catch { $message=Get-BountyEncoderError $_.Exception; $process.Dispose(); throw [System.ArgumentException]::new($message) }
        $job.process=$process; $job.status='encoding'; Write-BountyResponse $Stream 200 @{ok=$true}
    }
    elseif ($Path -eq '/api/export/cancel') { Remove-BountyJob $id; Write-BountyResponse $Stream 200 @{ok=$true} }
    else { throw [System.ArgumentException]::new('Requisicao invalida.') }
}


if ([System.IO.File]::Exists($BountyCreatureInfoCachePath)) {
    try {
        $storedInfo = [System.IO.File]::ReadAllText($BountyCreatureInfoCachePath, $BountyUtf8) | ConvertFrom-Json
        if ($storedInfo -is [pscustomobject]) { foreach ($property in $storedInfo.PSObject.Properties) { $BountyCreatureInfoCache[$property.Name] = $property.Value } }
    } catch {}
}

if ([System.IO.File]::Exists($BountyStatePath)) {
    try {
        $stored = [System.IO.File]::ReadAllText($BountyStatePath, $BountyUtf8) | ConvertFrom-Json
        if ($stored -isnot [pscustomobject]) { throw 'invalid state' }
        foreach ($key in ($BountyEditable | Sort-Object)) {
            if ($null -ne $stored.PSObject.Properties[$key]) {
                try { $BountyState = Apply-BountyPatch $BountyState @{ $key = $stored.$key } } catch {}
            }
        }
        if ($stored.revision -is [System.ValueType] -and $stored.revision -isnot [bool] -and $stored.revision -ge 0 -and $stored.revision -lt 9007199254740991) { $BountyState.revision = [long]$stored.revision }
        if ($stored.updatedAt -is [string]) { $BountyState.updatedAt = $stored.updatedAt }
    } catch { Write-Host 'Aviso: usando os valores iniciais; arquivo salvo nao pode ser lido.' -ForegroundColor Yellow }
}

$BountyState = Set-BountyDerivedPoints $BountyState
$BountyState.overlayUrlEnabled = $false
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try { $listener.Start() }
catch {
    try {
        $health = Invoke-RestMethod "$BountyAddress/api/health" -TimeoutSec 1
        if ($health.kind -eq 'bounty-studio') {
            Write-Host 'O Bounty Studio ja esta aberto.'
            if (-not $NoBrowser) { Start-Process "$BountyAddress/painel" }
            exit 0
        }
    } catch {}
    Write-Host "Nao foi possivel abrir a porta $Port. Feche o programa que usa essa porta e tente novamente." -ForegroundColor Red
    exit 1
}

Write-Host "`nBOUNTY STUDIO`n" -ForegroundColor Yellow
Write-Host "Painel:  $BountyAddress/painel"
Write-Host "Overlay: $BountyAddress/overlay"
Write-Host "`nDeixe esta janela aberta durante a live. Ctrl+C encerra.`n"
if (-not $NoBrowser) { Start-Process "$BountyAddress/painel" }
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $null
        try {
            $client.NoDelay = $true
            $stream = $client.GetStream(); $stream.ReadTimeout = 1000; $stream.WriteTimeout = 1000
            $headerBuilder = [System.Text.StringBuilder]::new()
            $ending = 0
            while ($headerBuilder.Length -lt 16384) {
                $b = $stream.ReadByte()
                if ($b -lt 0) { throw 'closed connection' }
                [void]$headerBuilder.Append([char]$b)
                $expected = @(13,10,13,10)[$ending]
                if ($b -eq $expected) { $ending++ } elseif ($b -eq 13) { $ending=1 } else { $ending=0 }
                if ($ending -eq 4) { break }
            }
            if ($ending -ne 4) { Write-BountyResponse $stream 400 @{error='Requisicao muito grande.'}; continue }
            $lines = $headerBuilder.ToString() -split "`r`n"
            $request = $lines[0].Split(' ')
            if ($request.Length -ne 3 -or -not $request[1].StartsWith('/')) { Write-BountyResponse $stream 400 @{error='Requisicao invalida.'}; continue }
            $method = $request[0]; $path = ($request[1] -split '\?',2)[0]; $query = Get-BountyQuery $request[1]; $stream.ReadTimeout = 15000; $stream.WriteTimeout = 15000
            $headers = @{}
            foreach ($line in $lines[1..($lines.Length-1)]) {
                $colon = $line.IndexOf(':')
                if ($colon -gt 0) { $headers[$line.Substring(0,$colon).Trim()] = $line.Substring($colon+1).Trim() }
            }
            if ($headers.ContainsKey('Sec-Fetch-Site') -and $headers['Sec-Fetch-Site'] -eq 'cross-site') { Write-BountyResponse $stream 403 @{error='Acesso cross-site nao autorizado.'}; continue }
            if ($headers['Host'] -notin @("127.0.0.1:$Port", "localhost:$Port")) { Write-BountyResponse $stream 403 @{error='Endereco local invalido.'}; continue }
            if ($headers.ContainsKey('Origin') -and $headers['Origin'] -notin @("http://127.0.0.1:$Port", "http://localhost:$Port")) { Write-BountyResponse $stream 403 @{error='Origem invalida.'}; continue }
            if ($headers.ContainsKey('Referer') -and -not ($headers['Referer'].StartsWith("http://127.0.0.1:$Port/") -or $headers['Referer'].StartsWith("http://localhost:$Port/"))) {
                Write-BountyResponse $stream 403 @{error='Origem de navegacao nao autorizada.'}; continue
            }
            if ($method -eq 'GET') {
                if ($path -in @('/api/sprite','/api/charm-icon','/api/creature-info','/api/export/status','/api/export/video')) {
                    try { Handle-BountyAsset $stream $path $query }
                    catch [System.ArgumentException] { Write-BountyResponse $stream 400 @{error=$_.Exception.Message} }
                    catch { Write-BountyResponse $stream 400 @{error='Nao foi possivel carregar esta imagem ou exportacao.'} }
                    continue
                }
                switch ($path) {
                    '/api/health' { Write-BountyResponse $stream 200 @{kind='bounty-studio';version=$BountyDefaults.schemaVersion} }
                    '/api/state' { Write-BountyResponse $stream 200 $BountyState }
                    '/overlay' { Write-BountyResponse $stream 200 $BountyHtml 'text/html; charset=utf-8' }
                    '/painel' { Write-BountyResponse $stream 200 $BountyHtml 'text/html; charset=utf-8' }
                    '/251vqzs.html' { Write-BountyResponse $stream 200 $BountyHtml 'text/html; charset=utf-8' }
                    '/' { Write-BountyResponse $stream 302 ([byte[]]@()) 'text/html' '/painel' }
                    '/painel.html' { Write-BountyResponse $stream 302 ([byte[]]@()) 'text/html' '/painel' }
                    '/favicon.ico' { Write-BountyResponse $stream 204 ([byte[]]@()) }
                    default { Write-BountyResponse $stream 404 @{error='Pagina nao encontrada.'} }
                }
            }
            elseif ($method -eq 'POST' -and $path.StartsWith('/api/export/')) {
                try { Handle-BountyExport $stream $path $query $headers }
                catch [System.ArgumentException] { Write-BountyResponse $stream 400 @{error=$_.Exception.Message} }
                catch { Write-BountyResponse $stream 400 @{error='Nao foi possivel gerar o video. Extraia o pacote completo e tente novamente.'} }
            }
            elseif ($method -eq 'POST' -and $path -eq '/api/state') {
                if (($headers['Content-Type'] -split ';')[0].Trim() -ne 'application/json') { Write-BountyResponse $stream 415 @{error='Envie alteracoes em JSON.'}; continue }
                $size = 0
                if (-not [int]::TryParse($headers['Content-Length'], [ref]$size) -or $size -le 0 -or $size -gt 16384) { Write-BountyResponse $stream 400 @{error='Tamanho de alteracao invalido.'}; continue }
                $bodyBytes = [byte[]]::new($size); $read=0
                while ($read -lt $size) { $count=$stream.Read($bodyBytes,$read,$size-$read); if ($count -le 0) { throw 'closed body' }; $read+=$count }
                try { $payload = $BountyUtf8.GetString($bodyBytes) | ConvertFrom-Json } catch { Write-BountyResponse $stream 400 @{error='JSON invalido.'}; continue }
                try {
                    if ($payload -isnot [pscustomobject]) { throw [System.ArgumentException]::new('Formato de alteracao invalido.') }
                    $patch = if ($null -ne $payload.PSObject.Properties['patch']) { $payload.patch } else { @{} }
                    $next = Apply-BountyPatch $BountyState $patch
                    if ($null -ne $payload.PSObject.Properties['adjust']) {
                        $adjust = $payload.adjust
                        if ($adjust -isnot [pscustomobject] -or $BountyLimits.Keys -cnotcontains $adjust.key) { throw [System.ArgumentException]::new('Ajuste invalido.') }
                        if ($null -ne $adjust.PSObject.Properties['levels']) {
                            $levels = $adjust.levels
                            if ($null -eq $levels -or $levels -is [bool] -or $levels -is [string] -or $levels -isnot [System.ValueType] -or $levels -notin @(-1,1)) { throw [System.ArgumentException]::new('Adicione ou remova um nivel por vez.') }
                            $current = Get-BountyAttributeLevel $adjust.key $next[$adjust.key]
                            $values = $BountyLevelValues[$adjust.key]
                            $target = [int][Math]::Max(0, [Math]::Min($values.Length-1, $current + $levels))
                            $next[$adjust.key] = $values[$target]
                        }
                        else {
                            $delta = $adjust.delta
                            if ($null -eq $delta -or $delta -is [bool] -or $delta -is [string] -or $delta -isnot [System.ValueType]) { throw [System.ArgumentException]::new('Ajuste invalido.') }
                            $delta = [double]$delta
                            if ([double]::IsNaN($delta) -or [double]::IsInfinity($delta) -or [Math]::Abs($delta) -gt 1000000000) { throw [System.ArgumentException]::new('Ajuste invalido.') }
                            $next[$adjust.key] = Get-BountyAttributeValue $adjust.key ($next[$adjust.key]+$delta)
                        }
                    }
                    $next = Set-BountyDerivedPoints $next
                    $next.revision = [long]$BountyState.revision + 1
                    $next.updatedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                    Save-BountyState $next
                    $BountyState = $next
                    Write-BountyResponse $stream 200 $BountyState
                }
                catch [System.ArgumentException] { Write-BountyResponse $stream 400 @{error=$_.Exception.Message} }
                catch { Write-BountyResponse $stream 500 @{error='Nao foi possivel salvar. Extraia o pacote para uma pasta com permissao de escrita.'} }
            }
            else { Write-BountyResponse $stream 405 @{error='Metodo nao permitido.'} }
        }
        catch { try { if ($null -ne $stream) { Write-BountyResponse $stream 400 @{error='Requisicao incompleta.'} } } catch {} }
        finally { if ($null -ne $stream) { $stream.Dispose() }; $client.Close() }
    }
}
finally { $listener.Stop(); foreach ($id in @($BountyJobs.Keys)) { Remove-BountyJob $id } }

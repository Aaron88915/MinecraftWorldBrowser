param(
    [string]$Owner = 'Aaron88915',
    [string]$Repository = 'MinecraftWorldBrowser',
    [string]$Branch = 'main',
    [string]$ProjectPath = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$projectDirectory = if ([string]::IsNullOrWhiteSpace($ProjectPath)) { (Get-Location).Path } else { Split-Path -Parent $ProjectPath }
$projectDirectory = [IO.Path]::GetFullPath($projectDirectory)
$changeLogPath = Join-Path $projectDirectory 'CHANGELOG.md'
$changeLog = Get-Content -LiteralPath $changeLogPath -Raw -Encoding UTF8

$credentialInput = "protocol=https`nhost=github.com`n`n"
$credentialLines = $credentialInput | git credential fill 2>$null
$credential = @{}
foreach ($line in $credentialLines) {
    $separator = $line.IndexOf('=')
    if ($separator -gt 0) { $credential[$line.Substring(0, $separator)] = $line.Substring($separator + 1) }
}
if (-not $credential.ContainsKey('password') -or [string]::IsNullOrWhiteSpace($credential.password)) {
    throw 'GitHub credential is unavailable. Push once with Git Credential Manager and complete the browser login first.'
}
$token = $credential.password
$headers = @{
    Authorization = "Bearer $token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'MinecraftWorldBrowser-ReleasePublisher'
}
$apiBase = "https://api.github.com/repos/$Owner/$Repository"

function Invoke-GitHubJson {
    param(
        [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')][string]$Method,
        [string]$Uri,
        [object]$Body,
        [switch]$AllowNotFound
    )

    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            $arguments = @{ Method = $Method; Uri = $Uri; Headers = $headers }
            if ($null -ne $Body) {
                $arguments.ContentType = 'application/json; charset=utf-8'
                $arguments.Body = $Body | ConvertTo-Json -Depth 8 -Compress
            }
            return Invoke-RestMethod @arguments
        }
        catch {
            $statusCode = 0
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($AllowNotFound -and $statusCode -eq 404) { return $null }
            if ($attempt -ge 4 -or $statusCode -lt 500) { throw }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
}

function Get-ReleaseNotes {
    param([string]$Version)
    $escaped = [regex]::Escape($Version)
    $pattern = "(?ms)^## \[$escaped\] - (?<date>\d{4}-\d{2}-\d{2})\r?\n(?<body>.*?)(?=^## \[|\z)"
    $match = [regex]::Match($changeLog, $pattern)
    if (-not $match.Success) { throw "CHANGELOG entry missing for $Version." }
    $notes = "构建日期：$($match.Groups['date'].Value)`n`n" + $match.Groups['body'].Value.Trim()
    if ($Version -ne '3.2.6') {
        $notes += "`n`n> 历史二进制归档：本地未保留此版本的独立源码快照，附件是当时构建的原始 EXE；仓库当前源码对应 v3.2.6。"
    }
    return $notes
}

function Upload-ReleaseAsset {
    param([object]$Release, [System.IO.FileInfo]$File)
    $assetExists = @($Release.assets | Where-Object { $_.name -eq $File.Name }).Count -gt 0
    if ($assetExists) {
        Write-Output "ASSET EXISTS: $($File.Name)"
        return
    }

    $uploadUri = "https://uploads.github.com/repos/$Owner/$Repository/releases/$($Release.id)/assets?name=$([Uri]::EscapeDataString($File.Name))"
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            Invoke-RestMethod -Method Post -Uri $uploadUri -Headers $headers -ContentType 'application/vnd.microsoft.portable-executable' -InFile $File.FullName | Out-Null
            Write-Output "ASSET UPLOADED: $($File.Name)"
            return
        }
        catch {
            if ($attempt -ge 4) { throw }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
}

$description = '集中浏览、搜索、备份和恢复多个 Minecraft Java 启动器与实例中的世界存档。'
Invoke-GitHubJson -Method Patch -Uri $apiBase -Body @{
    description = $description
    has_issues = $true
    has_projects = $false
    has_wiki = $false
} | Out-Null
Invoke-GitHubJson -Method Put -Uri "$apiBase/topics" -Body @{
    names = @('minecraft', 'minecraft-java', 'world-manager', 'pcl2', 'hmcl', 'prism-launcher', 'windows')
} | Out-Null
Write-Output 'REPOSITORY METADATA UPDATED'

$binaries = @(Get-ChildItem -LiteralPath $projectDirectory -File -Filter 'MinecraftWorldBrowser-v*.exe' | Sort-Object LastWriteTime, Name)
if ($binaries.Count -ne 52) { throw "Expected 52 versioned EXEs, found $($binaries.Count)." }

foreach ($binary in $binaries) {
    if ($binary.BaseName -notmatch '^MinecraftWorldBrowser-v(?<version>\d+(?:\.\d+){1,2})$') {
        throw "Unexpected release filename: $($binary.Name)"
    }
    $version = $Matches.version
    $tag = "v$version"
    $notes = Get-ReleaseNotes $version
    $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $binary.FullName).Hash
    $notes += "`n`n**文件校验**`n`n" + '```text' + "`nSHA-256  $sha256`n" + '```'
    $release = Invoke-GitHubJson -Method Get -Uri "$apiBase/releases/tags/$tag" -Body $null -AllowNotFound
    if ($null -eq $release) {
        $release = Invoke-GitHubJson -Method Post -Uri "$apiBase/releases" -Body @{
            tag_name = $tag
            target_commitish = $Branch
            name = "Minecraft World Browser $tag"
            body = $notes
            draft = $false
            prerelease = $false
        }
        Write-Output "RELEASE CREATED: $tag"
    }
    else {
        $release = Invoke-GitHubJson -Method Patch -Uri "$apiBase/releases/$($release.id)" -Body @{
            name = "Minecraft World Browser $tag"
            body = $notes
            draft = $false
            prerelease = $false
        }
        Write-Output "RELEASE UPDATED: $tag"
    }
    Upload-ReleaseAsset -Release $release -File $binary
}

$expectedTags = @($binaries | ForEach-Object { 'v' + ($_.BaseName -replace '^MinecraftWorldBrowser-v', '') })
$missing = $expectedTags
for ($attempt = 1; $attempt -le 5 -and $missing.Count -gt 0; $attempt++) {
    $allReleases = Invoke-GitHubJson -Method Get -Uri "$apiBase/releases?per_page=100" -Body $null
    $publishedTags = @($allReleases | ForEach-Object { $_.tag_name })
    $missing = @($expectedTags | Where-Object { $_ -notin $publishedTags })
    if ($missing.Count -gt 0 -and $attempt -lt 5) { Start-Sleep -Seconds (2 * $attempt) }
}
if ($missing.Count -gt 0) { throw "Release verification failed. Missing: $($missing -join ', ')" }
Write-Output "RELEASE VERIFICATION OK: $($binaries.Count) releases"

$token = $null
$credential.Clear()

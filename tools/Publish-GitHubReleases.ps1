param(
    [string]$Owner = 'Aaron88915',
    [string]$Repository = 'MinecraftWorldBrowser',
    [string]$Branch = 'main',
    [string]$ProjectPath = $PSScriptRoot,
    [string[]]$Versions,
    [switch]$IncludeLinuxAssets,
    [switch]$SkipRepositoryMetadata,
    [switch]$DirectNetwork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($DirectNetwork) { [Net.WebRequest]::DefaultWebProxy = New-Object Net.WebProxy }

$projectDirectory = if ([string]::IsNullOrWhiteSpace($ProjectPath)) { (Get-Location).Path } else { Split-Path -Parent $ProjectPath }
$projectDirectory = [IO.Path]::GetFullPath($projectDirectory)
$changeLogPath = Join-Path $projectDirectory 'CHANGELOG.md'
$changeLog = Get-Content -LiteralPath $changeLogPath -Raw -Encoding UTF8
$versionEntries = [regex]::Matches($changeLog, '(?m)^## \[(?<version>\d+(?:\.\d+){1,2})\] - ')
if ($versionEntries.Count -eq 0) { throw 'No release versions found in CHANGELOG.' }
$latestVersion = $versionEntries[0].Groups['version'].Value

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
    if ($Version -ne $latestVersion) {
        $notes += "`n`n> 历史二进制归档：附件是当时构建的原始 EXE；仓库当前源码对应 v$latestVersion。"
    }
    return $notes
}

function Upload-ReleaseAsset {
    param([object]$Release, [System.IO.FileInfo]$File)
    $existing = @($Release.assets | Where-Object { $_.name -eq $File.Name })
    $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $File.FullName).Hash.ToLowerInvariant()
    if ($existing.Count -gt 0 -and $existing[0].digest -eq "sha256:$sha256") {
        Write-Output "ASSET EXISTS: $($File.Name)"
        return
    }

    $uploadName = if ($existing.Count -gt 0) { $File.Name + '.upload-' + [Guid]::NewGuid().ToString('N') } else { $File.Name }
    $uploadUri = "https://uploads.github.com/repos/$Owner/$Repository/releases/$($Release.id)/assets?name=$([Uri]::EscapeDataString($uploadName))"
    $contentType = if ($File.Name.EndsWith('.exe')) { 'application/vnd.microsoft.portable-executable' } elseif ($File.Name.EndsWith('.tar.gz')) { 'application/gzip' } elseif ($File.Name.EndsWith('.sha256')) { 'text/plain' } else { 'application/octet-stream' }
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            $uploaded = Invoke-RestMethod -Method Post -Uri $uploadUri -Headers $headers -ContentType $contentType -InFile $File.FullName -TimeoutSec 600
            break
        }
        catch {
            $currentAssets = @(Invoke-GitHubJson -Method Get -Uri "$apiBase/releases/$($Release.id)/assets?per_page=100" -Body $null)
            $completed = @($currentAssets | Where-Object { $_.name -eq $uploadName -and $_.digest -eq "sha256:$sha256" -and $_.state -eq 'uploaded' })
            if ($completed.Count -eq 1) { $uploaded = $completed[0]; break }
            if ($attempt -ge 4) { throw }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
    if ($uploaded.size -ne $File.Length -or $uploaded.digest -ne "sha256:$sha256") { throw "Uploaded asset checksum mismatch: $($File.Name)" }
    if ($existing.Count -gt 0) {
        Invoke-GitHubJson -Method Delete -Uri "$apiBase/releases/assets/$($existing[0].id)" -Body $null | Out-Null
        Invoke-GitHubJson -Method Patch -Uri "$apiBase/releases/assets/$($uploaded.id)" -Body @{ name = $File.Name } | Out-Null
    }
    Write-Output "ASSET UPLOADED: $($File.Name)"
}

if (-not $SkipRepositoryMetadata) {
$description = '集中浏览、搜索、备份和恢复多个 Minecraft Java 启动器与实例中的世界存档。'
Invoke-GitHubJson -Method Patch -Uri $apiBase -Body @{
    description = $description
    has_issues = $true
    has_projects = $false
    has_wiki = $false
} | Out-Null
Invoke-GitHubJson -Method Put -Uri "$apiBase/topics" -Body @{
    names = @('minecraft', 'minecraft-java', 'world-manager', 'pcl2', 'hmcl', 'prism-launcher', 'windows', 'linux')
} | Out-Null
Write-Output 'REPOSITORY METADATA UPDATED'
}

$binaries = @(Get-ChildItem -LiteralPath $projectDirectory -File -Filter 'MinecraftWorldBrowser-v*.exe' | Sort-Object LastWriteTime, Name)
if ($Versions) {
    foreach ($requested in $Versions) {
        if ($requested -notin @($versionEntries | ForEach-Object { $_.Groups['version'].Value })) { throw "Version missing from CHANGELOG: $requested" }
    }
    $binaries = @($binaries | Where-Object { ($_.BaseName -replace '^MinecraftWorldBrowser-v', '') -in $Versions })
    if ($binaries.Count -ne $Versions.Count) { throw 'Requested release binary is missing.' }
}
$missingBinaries = @($versionEntries | ForEach-Object { 'MinecraftWorldBrowser-v' + $_.Groups['version'].Value + '.exe' } | Where-Object { -not (Test-Path -LiteralPath (Join-Path $projectDirectory $_)) })
if ($missingBinaries.Count -gt 0) { throw "Release binaries missing: $($missingBinaries -join ', ')" }

foreach ($binary in $binaries) {
    if ($binary.BaseName -notmatch '^MinecraftWorldBrowser-v(?<version>\d+(?:\.\d+){1,2})$') {
        throw "Unexpected release filename: $($binary.Name)"
    }
    $version = $Matches.version
    $tag = "v$version"
    $notes = Get-ReleaseNotes $version
    $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $binary.FullName).Hash
    $notes += "`n`n**文件校验**`n`n" + '```text' + "`nSHA-256  $sha256`n" + '```'
    $linuxFiles = @()
    if ($IncludeLinuxAssets -and $version -eq $latestVersion) {
        foreach ($suffix in @('linux-x86_64-install.run', 'linux-x86_64.tar.gz', 'linux-source.tar.gz')) {
            $path = Join-Path $projectDirectory "MinecraftWorldBrowser-v$version-$suffix"
            $checksumPath = "$path.sha256"
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or -not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) { throw "Linux asset missing: $path" }
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
            if ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -ne "$hash  $([IO.Path]::GetFileName($path))") { throw "Linux asset checksum mismatch: $path" }
            $linuxFiles += Get-Item -LiteralPath $path, $checksumPath
        }
        $notes += "`n`n**Linux 一键安装（Kali / Debian / Ubuntu）**`n`n" + '```sh' + "`nsh MinecraftWorldBrowser-v$version-linux-x86_64-install.run`n" + '```' + "`n`n安装器自动补齐 Qt 系统依赖，并创建桌面和应用菜单图标。请用普通用户执行，缺少依赖时会提示输入 sudo 密码。重复安装保留配置和备份记录。解压版附带可双击的「一键安装.desktop」。`n`nLinux 附件同时提供 SHA-256 校验文件。"
    }
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
    foreach ($linuxFile in $linuxFiles) { Upload-ReleaseAsset -Release $release -File $linuxFile }
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

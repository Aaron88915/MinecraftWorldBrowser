param(
    [string]$Executable = 'MinecraftWorldBrowser-preview.exe',
    [string]$BaselineExecutable,
    [string]$OutputDirectory = 'build\telegram-ui'
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
if (-not [IO.Path]::IsPathRooted($Executable)) { $Executable = Join-Path $projectDirectory $Executable }
if (-not [IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory = Join-Path $projectDirectory $OutputDirectory }
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw "EXE missing: $Executable" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Invoke-HiddenCheck {
    param([string]$Path, [string[]]$Arguments)
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -WindowStyle Hidden -PassThru
    try {
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw "UI verification timed out: $Path"
        }
        if ($process.ExitCode -ne 0) {
            $errorLog = Join-Path ([IO.Path]::GetTempPath()) 'MinecraftWorldBrowser-smoke-error.txt'
            $details = if ($Arguments -contains '--smoke-test' -and (Test-Path -LiteralPath $errorLog)) { Get-Content -Raw -LiteralPath $errorLog } else { 'No error log for this check.' }
            throw "UI verification failed (exit $($process.ExitCode)): $Path`n$details"
        }
    }
    finally { $process.Dispose() }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectDirectory 'MinecraftWorldBrowser.ps1') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Source self-test failed.' }
Invoke-HiddenCheck -Path $Executable -Arguments @('--smoke-test')
Write-Output 'EXE SMOKE OK'

$jobs = @(@{ Path = $Executable; Prefix = 'after' })
if (-not [string]::IsNullOrWhiteSpace($BaselineExecutable)) {
    if (-not [IO.Path]::IsPathRooted($BaselineExecutable)) { $BaselineExecutable = Join-Path $projectDirectory $BaselineExecutable }
    $jobs += @{ Path = $BaselineExecutable; Prefix = 'before' }
}
foreach ($job in $jobs) {
    foreach ($theme in @('light', 'dark')) {
        $imagePath = Join-Path $OutputDirectory ($job.Prefix + '-' + $theme + '.png')
        $arguments = @('"--render-preview=' + $imagePath + '"')
        if ($theme -eq 'dark') { $arguments += '--dark' }
        Invoke-HiddenCheck -Path $job.Path -Arguments $arguments
        Write-Output ('PREVIEW OK: ' + $imagePath)
        if ($job.Prefix -eq 'after') {
            $liveImage = Join-Path $OutputDirectory ('live-' + $theme + '.png')
            $liveArguments = @('"--render-preview=' + $liveImage + '"', '--capture-screen')
            if ($theme -eq 'dark') { $liveArguments += '--dark' }
            Invoke-HiddenCheck -Path $job.Path -Arguments $liveArguments
            if (-not (Test-Path -LiteralPath $liveImage -PathType Leaf)) { throw 'Live screenshot was not generated.' }
            Write-Output ('LIVE SCREENSHOT OK: ' + $liveImage)
            $detailsImage = Join-Path $OutputDirectory ('details-' + $theme + '.png')
            $detailsArguments = @('"--render-details-preview=' + $detailsImage + '"')
            if ($theme -eq 'dark') { $detailsArguments += '--dark' }
            Invoke-HiddenCheck -Path $job.Path -Arguments $detailsArguments
            if (-not (Test-Path -LiteralPath $detailsImage -PathType Leaf)) { throw 'Details preview was not generated.' }
            Write-Output ('DETAILS PREVIEW OK: ' + $detailsImage)
        }
    }
}

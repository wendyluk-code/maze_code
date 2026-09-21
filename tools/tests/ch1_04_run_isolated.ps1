[CmdletBinding()]
param(
    [ValidateSet('ch1_04', 'ch1_02_entry', 'ch1_02_real_flow')]
    [string]$Test = 'ch1_04',
    [string]$GodotPath = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$OutputDir = '',
    [switch]$NoCapture,
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

$godotVersion = ((& $GodotPath --version | Select-Object -First 1) -join '').Trim()
if ($godotVersion -notmatch '^4\.7\.2') {
    throw "Godot 4.7.2 is required; got: $godotVersion"
}

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('maze_code_ch1_04_isolated_' + [guid]::NewGuid().ToString('N'))
$isolatedAppData = Join-Path $runRoot 'Roaming'
$isolatedLocalAppData = Join-Path $runRoot 'Local'
New-Item -ItemType Directory -Path $isolatedAppData, $isolatedLocalAppData | Out-Null

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $runRoot 'reports'
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$realAppData = $env:APPDATA
$realLocalAppData = $env:LOCALAPPDATA
$realSavePath = Join-Path $realAppData 'Godot\app_userdata\maze_code\save.json'

function Get-SaveMetadata([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{ exists = $false; length = 0; sha256 = '' }
    }
    $item = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return [ordered]@{ exists = $true; length = $item.Length; sha256 = $hash }
}

function Normalize-Path([string]$Path) {
    return $Path.Replace('\', '/').TrimEnd('/').ToLowerInvariant()
}

$realBefore = Get-SaveMetadata $realSavePath
$outputStdout = Join-Path $OutputDir ($Test + '.stdout.txt')
$outputStderr = Join-Path $OutputDir ($Test + '.stderr.txt')
$reportPath = Join-Path $OutputDir ($Test + '-report.json')

$godotArgs = @()
if ($Headless) {
    $godotArgs += '--headless'
}
$godotArgs += @('--path', $workspace)
switch ($Test) {
    'ch1_04' {
        $godotArgs += @('--scene', 'res://tools/tests/ch1_04_tieshan_suite.tscn')
        $godotArgs += @('--', '--replay-tutorial', ('--isolation-root=' + $runRoot),
            ('--isolation-appdata=' + $isolatedAppData), ('--report=' + $reportPath))
        if (-not $NoCapture) {
            $godotArgs += '--output=' + (Join-Path $OutputDir 'CH1-04-tieshan-dialog.png')
        }
    }
    'ch1_02_entry' {
        $godotArgs += @('--scene', 'res://tools/tests/ch1_02_entry_suite.tscn')
        $godotArgs += @('--', ('--output=' + $reportPath))
    }
    'ch1_02_real_flow' {
        $godotArgs += @('--script', 'res://tools/tests/ch1_02_real_flow.gd')
        $reportPath = Join-Path $OutputDir 'ch1-02-real-flow-report.json'
        $godotArgs += @('--', ('--output-dir=' + $OutputDir))
        if ($NoCapture) {
            $godotArgs += '--no-capture'
        }
    }
}

$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$oldIsolationMarker = $env:MAZE_CH1_04_ISOLATED
$process = $null
try {
    $env:APPDATA = $isolatedAppData
    $env:LOCALAPPDATA = $isolatedLocalAppData
    $env:MAZE_CH1_04_ISOLATED = '1'
    $process = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $outputStdout -RedirectStandardError $outputStderr
}
finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if ($null -eq $oldIsolationMarker) {
        Remove-Item Env:MAZE_CH1_04_ISOLATED -ErrorAction SilentlyContinue
    } else {
        $env:MAZE_CH1_04_ISOLATED = $oldIsolationMarker
    }
}

$isolatedSavePath = Join-Path $isolatedAppData 'Godot\app_userdata\maze_code\save.json'
$realAfter = Get-SaveMetadata $realSavePath
$isolatedAfter = Get-SaveMetadata $isolatedSavePath
$realUnchanged = ($realBefore | ConvertTo-Json -Compress) -eq ($realAfter | ConvertTo-Json -Compress)
$isolatedUserDir = Join-Path $isolatedAppData 'Godot\app_userdata\maze_code'
$isolationPathValid = (Normalize-Path $isolatedUserDir).StartsWith((Normalize-Path $runRoot) + '/')

$summary = [ordered]@{
    test = $Test
    godot_version = $godotVersion
    workspace = $workspace
    command = ($GodotPath + ' ' + ($godotArgs -join ' '))
    exit_code = $process.ExitCode
    isolation_root = $runRoot
    isolated_appdata = $isolatedAppData
    isolated_user_dir = $isolatedUserDir
    isolation_path_valid = $isolationPathValid
    real_save_path = $realSavePath
    real_save_before = $realBefore
    real_save_after = $realAfter
    real_save_unchanged = $realUnchanged
    isolated_save_path = $isolatedSavePath
    isolated_save_after = $isolatedAfter
    stdout = $outputStdout
    stderr = $outputStderr
    report = $reportPath
}
$summaryPath = Join-Path $OutputDir ($Test + '-runner-summary.json')
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output ('RUNNER summary=' + $summaryPath)
Write-Output ('RUNNER exit_code=' + $process.ExitCode)
Write-Output ('RUNNER real_save_unchanged=' + $realUnchanged)
Write-Output ('RUNNER isolation_path_valid=' + $isolationPathValid)
Write-Output ('RUNNER stdout=' + $outputStdout)
Write-Output ('RUNNER stderr=' + $outputStderr)
Write-Output ('RUNNER report=' + $reportPath)
if ($Test -eq 'ch1_04' -and -not $NoCapture) {
    Write-Output ('RUNNER screenshot=' + (Join-Path $OutputDir 'CH1-04-tieshan-dialog.png'))
}
exit $process.ExitCode

[CmdletBinding()]
param(
    [string]$GodotPath = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found: $GodotPath" }
$godotVersion = ((& $GodotPath --version | Select-Object -First 1) -join '').Trim()
if ($godotVersion -notmatch '^4\.7\.2') { throw "Godot 4.7.2 is required; got: $godotVersion" }

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('maze_code_ch1_05_isolated_' + [guid]::NewGuid().ToString('N'))
$isolatedAppData = Join-Path $runRoot 'Roaming'
$isolatedLocalAppData = Join-Path $runRoot 'Local'
New-Item -ItemType Directory -Path $isolatedAppData, $isolatedLocalAppData | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $runRoot 'reports' }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

function Get-SaveMetadata([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{ exists = $false; length = 0; sha256 = '' } }
    $item = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return [ordered]@{ exists = $true; length = $item.Length; sha256 = $hash }
}

$realSavePath = Join-Path $env:APPDATA 'Godot\app_userdata\maze_code\save.json'
$realBefore = Get-SaveMetadata $realSavePath
$reportPath = Join-Path $OutputDir 'ch1-05-frontdesk-report.json'
$stdoutPath = Join-Path $OutputDir 'ch1-05-frontdesk.stdout.txt'
$stderrPath = Join-Path $OutputDir 'ch1-05-frontdesk.stderr.txt'
$args = @('--headless', '--path', $workspace, '--scene', 'res://tools/tests/ch1_05_frontdesk_suite.tscn', '--',
    ('--isolation-root=' + $runRoot), ('--isolation-appdata=' + $isolatedAppData), ('--report=' + $reportPath))

$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$oldMarker = $env:MAZE_CH1_05_ISOLATED
$process = $null
try {
    $env:APPDATA = $isolatedAppData
    $env:LOCALAPPDATA = $isolatedLocalAppData
    $env:MAZE_CH1_05_ISOLATED = '1'
    $process = Start-Process -FilePath $GodotPath -ArgumentList $args -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
}
finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if ($null -eq $oldMarker) { Remove-Item Env:MAZE_CH1_05_ISOLATED -ErrorAction SilentlyContinue }
    else { $env:MAZE_CH1_05_ISOLATED = $oldMarker }
}

$realAfter = Get-SaveMetadata $realSavePath
$isolatedSavePath = Join-Path $isolatedAppData 'Godot\app_userdata\maze_code\save.json'
$isolatedAfter = Get-SaveMetadata $isolatedSavePath
$reportExists = Test-Path -LiteralPath $reportPath -PathType Leaf
$report = $null
$reportValid = $false
$reportFailuresClear = $false
if ($reportExists) {
    try {
        $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
        $reportValid = $null -ne $report
        $reportFailuresClear = [int]$report.failures -eq 0
    } catch { $reportValid = $false }
}
$realUnchanged = ($realBefore | ConvertTo-Json -Compress) -eq ($realAfter | ConvertTo-Json -Compress)
$exitCode = if ($null -ne $process) { [int]$process.ExitCode } else { 1 }
$runnerPassed = $exitCode -eq 0 -and $realUnchanged -and $reportExists -and $reportValid -and $reportFailuresClear
$summary = [ordered]@{
    test = 'ch1_05'
    godot_version = $godotVersion
    workspace = $workspace
    command = $GodotPath + ' ' + ($args -join ' ')
    exit_code = $exitCode
    runner_passed = $runnerPassed
    isolation_root = $runRoot
    isolated_appdata = $isolatedAppData
    isolated_save = $isolatedAfter
    real_save_path = $realSavePath
    real_save_before = $realBefore
    real_save_after = $realAfter
    real_save_unchanged = $realUnchanged
    stdout = $stdoutPath
    stderr = $stderrPath
    report = $reportPath
    report_exists = $reportExists
    report_valid = $reportValid
    report_failures_clear = $reportFailuresClear
}
$summaryPath = Join-Path $OutputDir 'ch1-05-frontdesk-runner-summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output ('RUNNER summary=' + $summaryPath)
Write-Output ('RUNNER godot_exit_code=' + $exitCode)
Write-Output ('RUNNER runner_passed=' + $runnerPassed)
Write-Output ('RUNNER real_save_unchanged=' + $realUnchanged)
Write-Output ('RUNNER isolated_save=' + ($isolatedSavePath))
Write-Output ('RUNNER report=' + $reportPath)
exit $(if ($runnerPassed) { 0 } else { 1 })

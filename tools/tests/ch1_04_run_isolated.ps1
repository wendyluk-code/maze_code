[CmdletBinding()]
param(
    [ValidateSet('ch1_04', 'ch1_02_entry', 'ch1_02_real_flow')]
    [string]$Test = 'ch1_04',
    [string]$GodotPath = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$OutputDir = '',
    [switch]$NoCapture,
    [switch]$Headless,
    [switch]$FixtureRealSaveChange
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

function Test-SaveMetadataEqual([object]$Left, [object]$Right) {
    return ($Left | ConvertTo-Json -Compress) -eq ($Right | ConvertTo-Json -Compress)
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
    $process = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $outputStdout -RedirectStandardError $outputStderr
    if (-not $process.WaitForExit(120000)) {
        $process.Kill()
        throw 'Godot CH1-04 exceeded the 120 second budget.'
    }
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
$realAfterActual = Get-SaveMetadata $realSavePath
$isolatedAfter = Get-SaveMetadata $isolatedSavePath
$realAfterChecked = $realAfterActual
if ($FixtureRealSaveChange) {
    # 仅改变门禁比较使用的内存 fixture，绝不写入真实 save.json。
    $realAfterChecked = [ordered]@{
        exists = $realAfterActual.exists
        length = [int64]$realAfterActual.length + 1
        sha256 = 'fixture-real-save-change'
    }
}
$realUnchanged = Test-SaveMetadataEqual $realBefore $realAfterChecked
$isolatedUserDir = Join-Path $isolatedAppData 'Godot\app_userdata\maze_code'
$isolationPathValid = (Normalize-Path $isolatedUserDir).StartsWith((Normalize-Path $runRoot) + '/')

$reportExists = Test-Path -LiteralPath $reportPath -PathType Leaf
$reportValid = $false
$reportFailuresClear = $false
$reportError = ''
$report = $null
if ($reportExists) {
    try {
        $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
        $reportValid = $null -ne $report
        if ($reportValid -and $report.PSObject.Properties.Name -contains 'failures') {
            $failureValue = $report.failures
            if ($null -eq $failureValue) {
                $reportFailuresClear = $true
            } elseif ($failureValue -is [System.Array]) {
                $reportFailuresClear = @($failureValue).Count -eq 0
            } else {
                $reportFailuresClear = [int]$failureValue -eq 0
            }
        }
    } catch {
        $reportError = 'parse_failed'
    }
} else {
    $reportError = 'missing'
}

$screenshotRequired = $Test -eq 'ch1_04' -and -not $NoCapture
$screenshotPath = if ($Test -eq 'ch1_04') {
    Join-Path $OutputDir 'CH1-04-tieshan-dialog.png'
} else {
    ''
}
$screenshotExists = -not $screenshotRequired
if ($screenshotRequired) {
    $screenshotExists = (Test-Path -LiteralPath $screenshotPath -PathType Leaf) `
        -and ((Get-Item -LiteralPath $screenshotPath).Length -gt 0)
}
$visibleCapturePassed = -not $screenshotRequired
if ($screenshotRequired -and $reportValid) {
    $visibleCaptureChecks = @($report.checks | Where-Object { $_.name -eq 'visible_capture' })
    $visibleCapturePassed = ($visibleCaptureChecks.Count -eq 1) `
        -and [bool]$visibleCaptureChecks[0].passed
}
$processExitCode = if ($null -ne $process) { [int]$process.ExitCode } else { 1 }
$runnerPassed = (
    ($processExitCode -eq 0) `
        -and $realUnchanged `
        -and $isolationPathValid `
        -and $reportExists `
        -and $reportValid `
        -and $reportFailuresClear `
        -and $screenshotExists `
        -and $visibleCapturePassed
)
$runnerExitCode = if ($runnerPassed) { 0 } else { 1 }

$summary = [ordered]@{
    test = $Test
    godot_version = $godotVersion
    workspace = $workspace
    command = ($GodotPath + ' ' + ($godotArgs -join ' '))
    exit_code = $processExitCode
    runner_exit_code = $runnerExitCode
    runner_passed = $runnerPassed
    fixture_real_save_change = [bool]$FixtureRealSaveChange
    isolation_root = $runRoot
    isolated_appdata = $isolatedAppData
    isolated_user_dir = $isolatedUserDir
    isolation_path_valid = $isolationPathValid
    real_save_path = $realSavePath
    real_save_before = $realBefore
    real_save_after = $realAfterActual
    real_save_after_checked = $realAfterChecked
    real_save_unchanged = $realUnchanged
    isolated_save_path = $isolatedSavePath
    isolated_save_after = $isolatedAfter
    stdout = $outputStdout
    stderr = $outputStderr
    report = $reportPath
    report_exists = $reportExists
    report_valid = $reportValid
    report_failures_clear = $reportFailuresClear
    report_error = $reportError
    screenshot_required = $screenshotRequired
    screenshot = $screenshotPath
    screenshot_exists = $screenshotExists
    visible_capture_passed = $visibleCapturePassed
}
$summaryPath = Join-Path $OutputDir ($Test + '-runner-summary.json')
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output ('RUNNER summary=' + $summaryPath)
Write-Output ('RUNNER godot_exit_code=' + $processExitCode)
Write-Output ('RUNNER runner_exit_code=' + $runnerExitCode)
Write-Output ('RUNNER runner_passed=' + $runnerPassed)
Write-Output ('RUNNER fixture_real_save_change=' + [bool]$FixtureRealSaveChange)
Write-Output ('RUNNER real_save_unchanged=' + $realUnchanged)
Write-Output ('RUNNER isolation_path_valid=' + $isolationPathValid)
Write-Output ('RUNNER report_exists=' + $reportExists)
Write-Output ('RUNNER report_valid=' + $reportValid)
Write-Output ('RUNNER report_failures_clear=' + $reportFailuresClear)
Write-Output ('RUNNER screenshot_required=' + $screenshotRequired)
Write-Output ('RUNNER screenshot_exists=' + $screenshotExists)
Write-Output ('RUNNER visible_capture_passed=' + $visibleCapturePassed)
Write-Output ('RUNNER stdout=' + $outputStdout)
Write-Output ('RUNNER stderr=' + $outputStderr)
Write-Output ('RUNNER report=' + $reportPath)
if ($Test -eq 'ch1_04') {
    Write-Output ('RUNNER screenshot=' + $screenshotPath)
}
exit $runnerExitCode

[CmdletBinding()]
param(
    [string]$GodotPath = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found: $GodotPath" }
$version = ((& $GodotPath --version | Select-Object -First 1) -join '').Trim()
if ($version -notmatch '^4\.7\.2') { throw "Godot 4.7.2 required; got $version" }

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('maze_code_ch1_ui_isolated_' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $runRoot 'Roaming'
$local = Join-Path $runRoot 'Local'
New-Item -ItemType Directory -Path $app, $local | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $runRoot 'artifacts' }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$report = Join-Path $OutputDir 'ch1-ui-01-report.json'
$stdout = Join-Path $OutputDir 'ch1-ui-01.stdout.txt'
$stderr = Join-Path $OutputDir 'ch1-ui-01.stderr.txt'

function Get-SaveMetadata([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [ordered]@{ exists = $false; length = 0; sha256 = '' } }
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{ exists = $true; length = $item.Length; sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
}

$realSave = Join-Path $env:APPDATA 'Godot\app_userdata\maze_code\save.json'
$realBefore = Get-SaveMetadata $realSave
$args = @('--path', $workspace, '--scene', 'res://tools/tests/ch1_ui_order_card_suite.tscn', '--',
    ('--isolation-root=' + $runRoot), ('--report=' + $report), ('--output-dir=' + $OutputDir))
$oldApp = $env:APPDATA; $oldLocal = $env:LOCALAPPDATA; $oldMarker = $env:MAZE_CH1_UI_ISOLATED
try {
    $env:APPDATA = $app
    $env:LOCALAPPDATA = $local
    $env:MAZE_CH1_UI_ISOLATED = '1'
    $process = Start-Process -FilePath $GodotPath -ArgumentList $args -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $completed = $process.WaitForExit(120000)
    if (-not $completed) {
        Stop-Process -Id $process.Id -Force
        throw "CH1-UI-01 runner exceeded its 120-second timeout; outputs: $stdout / $stderr"
    }
}
finally {
    $env:APPDATA = $oldApp; $env:LOCALAPPDATA = $oldLocal
    if ($null -eq $oldMarker) { Remove-Item Env:MAZE_CH1_UI_ISOLATED -ErrorAction SilentlyContinue }
    else { $env:MAZE_CH1_UI_ISOLATED = $oldMarker }
}
$realAfter = Get-SaveMetadata $realSave
$realUnchanged = ($realBefore | ConvertTo-Json -Compress) -eq ($realAfter | ConvertTo-Json -Compress)
$reportValid = $false; $reportClear = $false
if (Test-Path -LiteralPath $report -PathType Leaf) {
    try { $data = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json; $reportValid = $null -ne $data; $reportClear = @($data.failures).Count -eq 0 } catch {}
}
$screenshots = @('CH1-UI-01-order-card-1152x648.png', 'CH1-UI-01-order-card-1280x720.png') |
    ForEach-Object { Join-Path $OutputDir $_ }
$screenshotsExist = @($screenshots | Where-Object { (Test-Path -LiteralPath $_ -PathType Leaf) -and (Get-Item -LiteralPath $_).Length -gt 0 }).Count -eq 2
$passed = $process.ExitCode -eq 0 -and $reportValid -and $reportClear -and $realUnchanged -and $screenshotsExist
$summary = [ordered]@{ ticket = 'CH1-UI-01'; godot_version = $version; workspace = $workspace; command = $GodotPath + ' ' + ($args -join ' '); exit_code = $process.ExitCode; runner_passed = $passed; report = $report; stdout = $stdout; stderr = $stderr; screenshots = $screenshots; screenshots_exist = $screenshotsExist; isolation_root = $runRoot; isolated_save = (Join-Path $app 'Godot\app_userdata\maze_code\save.json'); real_save = $realSave; real_save_before = $realBefore; real_save_after = $realAfter; real_save_unchanged = $realUnchanged }
$summaryPath = Join-Path $OutputDir 'ch1-ui-01-runner-summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output "RUNNER summary=$summaryPath"
Write-Output "RUNNER passed=$passed"
Write-Output "RUNNER real_save_unchanged=$realUnchanged"
Write-Output "RUNNER report=$report"
Write-Output "RUNNER screenshots=$($screenshots -join ';')"
Write-Output "RUNNER stdout=$stdout"
Write-Output "RUNNER stderr=$stderr"
exit $(if ($passed) { 0 } else { 1 })

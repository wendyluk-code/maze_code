param(
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$ProjectRoot = 'F:/maze_code',
    [string]$OutputRoot = '',
    [ValidateSet('visual','editor','headless')][string]$Mode = 'visual'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Godot)) { throw "Godot missing: $Godot" }
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/door_fx/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if ((Test-Path -LiteralPath $OutputRoot) -and @(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -gt 0) { throw 'OutputRoot must be empty' }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$realSaveRoot = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function SaveFingerprint {
    if (!(Test-Path -LiteralPath $realSaveRoot)) { return 'absent' }
    $entries = @(Get-ChildItem -LiteralPath $realSaveRoot -Recurse -File | Where-Object { $_.Extension -eq '.json' } | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($realSaveRoot.Length) + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
    return ($entries -join '|')
}
$before = SaveFingerprint
$profile = Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
Copy-Item -LiteralPath $Godot -Destination (Join-Path $profile 'Godot.exe')
Set-Content -LiteralPath (Join-Path $profile '_sc_') -Value ''
$settingsDir = Join-Path $profile 'editor_data'
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
@'
[gd_resource type="EditorSettings" format=3]
[resource]
interface/editor/behavior/import_resources_when_unfocused = true
filesystem/import/blender/enabled = false
'@ | Set-Content -LiteralPath (Join-Path $settingsDir 'editor_settings-4.7.tres') -Encoding utf8
$Godot = Join-Path $profile 'Godot.exe'
$report = Join-Path $OutputRoot 'acceptance.json'
$psi = [Diagnostics.ProcessStartInfo]::new($Godot)
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile
$psi.Environment['LOCALAPPDATA'] = $profile
$psi.Environment['MAZE_QTE03_PROFILE'] = $profile
$engineArgs = @('--path', $ProjectRoot, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', 'res://tools/tests/door_fx_input.tscn', '--', ('--report=' + $report), ('--output-dir=' + $OutputRoot))
if ($Mode -eq 'editor') { $engineArgs = @('--headless','--editor','--path',$ProjectRoot,'--import') }
if ($Mode -eq 'headless') { $engineArgs = @('--headless','--path',$ProjectRoot,'--quit-after','5') }
foreach ($engineArg in $engineArgs) {
    $psi.ArgumentList.Add([string]$engineArg)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = !$process.WaitForExit(240000)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $OutputRoot 'stdout.log'), $stdout)
[IO.File]::WriteAllText((Join-Path $OutputRoot 'stderr.log'), $stderr)
$after = SaveFingerprint
$errorLines = @(($stdout + "`n" + $stderr) -split "`r?`n" | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:|.*Parse Error:)' })
$environmentErrors = @($errorLines | Where-Object { $_ -match 'Failed to get system certificates|Failed to read the root certificate store|Cannot open file.*editor_settings|Error saving editor settings' })
$unexpectedErrors = @($errorLines | Where-Object { $_ -notin $environmentErrors })
$summary = [ordered]@{ exit_code=$process.ExitCode; timed_out=$timedOut; report_exists=(Test-Path -LiteralPath $report); unexpected_errors=$unexpectedErrors; environment_errors=$environmentErrors; real_save_before=$before; real_save_after=$after; real_save_unchanged=($before -eq $after); output=$OutputRoot }
if (Test-Path -LiteralPath $report) { $r = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json; $summary.checks=$r.checks; $summary.failures=$r.failures; $summary.display=$r.display }
$summary | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'runner-summary.json')
Write-Output ([ordered]@{exit_code=$process.ExitCode; timed_out=$timedOut; checks=$summary.checks; failures=$summary.failures; unexpected_errors=$unexpectedErrors; environment_errors=$environmentErrors; real_save_unchanged=($before -eq $after); output=$OutputRoot} | ConvertTo-Json -Depth 8)
if ($before -ne $after) { throw 'Real save fingerprint changed; no restore attempted' }
if ($Mode -ne 'visual') { if ($timedOut -or $process.ExitCode -ne 0 -or $unexpectedErrors.Count -gt 0) { throw 'Engine check failed' }; return }
if ($timedOut -or !(Test-Path -LiteralPath $report)) { throw 'Acceptance did not complete; logs preserved' }
if ($summary.checks -le 0 -or $summary.failures -ne 0 -or $process.ExitCode -ne 0 -or $unexpectedErrors.Count -gt 0) { throw 'Acceptance failed; see report and engine logs' }
if ($before -ne $after) { throw 'Real save fingerprint changed' }

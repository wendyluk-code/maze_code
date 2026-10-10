param(
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$ProjectRoot = 'F:/maze_code',
    [string]$OutputRoot = ''
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Godot)) { throw "Godot missing: $Godot" }
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/cooking_v2/acceptance/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if ((Test-Path -LiteralPath $OutputRoot) -and @(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -gt 0) { throw 'OutputRoot must be empty' }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$realSave = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code/save.json'
function SaveFingerprint { if (Test-Path -LiteralPath $realSave) { (Get-FileHash -LiteralPath $realSave -Algorithm SHA256).Hash } else { 'absent' } }
function SlotFingerprints {
    $directory = Join-Path (Split-Path -Parent $realSave) 'saves'
    $slots = [ordered]@{}
    if (Test-Path -LiteralPath $directory) {
        foreach ($file in Get-ChildItem -LiteralPath $directory -File | Sort-Object Name) { $slots[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    }
    return ($slots | ConvertTo-Json -Compress)
}
$before = SaveFingerprint
$slotsBefore = SlotFingerprints
$profile = Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
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
foreach ($engineArg in @('--path', $ProjectRoot, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', 'res://tools/tests/cooking_v2_acceptance.tscn', '--', ('--report=' + $report), ('--output-dir=' + (Join-Path $OutputRoot 'screenshots')))) {
    $psi.ArgumentList.Add([string]$engineArg)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = !$process.WaitForExit(120000)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $OutputRoot 'stdout.log'), $stdout)
[IO.File]::WriteAllText((Join-Path $OutputRoot 'stderr.log'), $stderr)
$after = SaveFingerprint
$slotsAfter = SlotFingerprints
$errorLines = @(($stdout + "`n" + $stderr) -split "`r?`n" | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:|.*Parse Error:)' })
# Only these pre-existing isolated-profile platform errors are reported separately.
$environmentErrors = @($errorLines | Where-Object { $_ -match 'Failed to get system certificates|Failed to read the root certificate store|Cannot open file.*editor_settings|Error saving editor settings' })
$unexpectedErrors = @($errorLines | Where-Object { $_ -notin $environmentErrors })
$summary = [ordered]@{ exit_code=$process.ExitCode; timed_out=$timedOut; report_exists=(Test-Path -LiteralPath $report); unexpected_errors=$unexpectedErrors; environment_errors=$environmentErrors; real_save_before=$before; real_save_after=$after; real_slots_before=$slotsBefore; real_slots_after=$slotsAfter; real_save_unchanged=($before -eq $after -and $slotsBefore -eq $slotsAfter); output=$OutputRoot }
if (Test-Path -LiteralPath $report) { $r = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json; $summary.checks=$r.checks; $summary.failures=$r.failures; $summary.display=$r.display }
$summary | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'runner-summary.json')
Write-Output ($summary | ConvertTo-Json -Depth 12)
if ($timedOut -or !(Test-Path -LiteralPath $report)) { throw 'Acceptance did not complete; logs preserved' }
if ($summary.checks -le 0 -or $summary.failures -ne 0 -or $process.ExitCode -ne 0 -or $unexpectedErrors.Count -gt 0) { throw 'Acceptance failed; see report and engine logs' }
if (-not $summary.real_save_unchanged) { throw 'Real save fingerprint changed' }

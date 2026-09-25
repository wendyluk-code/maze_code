param(
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$ProjectRoot = 'F:/maze_code',
    [string]$OutputRoot = ''
)
$ErrorActionPreference = 'Stop'
$scriptRoot = (Resolve-Path (Join-Path $PSScriptRoot 'ch1_qte_03_input.gd')).Path
if (!(Test-Path -LiteralPath $Godot)) { throw "Godot executable missing: $Godot" }
if (!(Test-Path -LiteralPath $ProjectRoot)) { throw "Project root missing: $ProjectRoot" }
if (!$OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot ('../../output/ch1_qte_03/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { if (@(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -gt 0) { throw 'OutputRoot must be empty' } }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$realSave = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code/save.json'
function Fingerprint { if (Test-Path -LiteralPath $realSave) { (Get-FileHash -LiteralPath $realSave -Algorithm SHA256).Hash } else { 'absent' } }
$before = Fingerprint
$profile = Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$report = Join-Path $OutputRoot 'qte03.json'
$stdoutPath = Join-Path $OutputRoot 'qte03.stdout.log'
$stderrPath = Join-Path $OutputRoot 'qte03.stderr.log'
$psi = [Diagnostics.ProcessStartInfo]::new($Godot)
$psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile; $psi.Environment['LOCALAPPDATA'] = $profile; $psi.Environment['MAZE_QTE03_PROFILE'] = $profile
$scriptArg = if (Test-Path -LiteralPath (Join-Path $ProjectRoot 'tools/tests/ch1_qte_03_input.tscn')) { 'res://tools/tests/ch1_qte_03_input.tscn' } else { $scriptRoot }
$args = @('--path', $ProjectRoot, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--script', $scriptArg, '--report=' + $report, '--output-dir=' + (Join-Path $OutputRoot 'screenshots'))
$psi.Arguments = (($args | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ')
$p = [Diagnostics.Process]::new(); $p.StartInfo = $psi; $null = $p.Start()
$outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
$timedOut = !$p.WaitForExit(120000)
if ($timedOut) { $p.Kill($true); $p.WaitForExit() }
$out = $outTask.GetAwaiter().GetResult(); $err = $errTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText($stdoutPath, $out); [IO.File]::WriteAllText($stderrPath, $err)
$after = Fingerprint
$summary = [ordered]@{ project=$ProjectRoot; script=$scriptRoot; exit_code=$p.ExitCode; timed_out=$timedOut; report_exists=(Test-Path $report); real_save_before=$before; real_save_after=$after; real_save_unchanged=($before -eq $after); stdout=$stdoutPath; stderr=$stderrPath }
if (Test-Path $report) { $r = Get-Content -Raw $report | ConvertFrom-Json; $summary.checks=$r.checks; $summary.failures=$r.failures }
$summary | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'runner-summary.json')
if ($timedOut) { throw 'QTE03 timed out; logs preserved' }
if (!(Test-Path $report)) { throw 'QTE03 report missing' }
if ($summary.checks -le 0) { throw 'QTE03 report has no checks' }
if ($summary.failures -ne 0 -or $p.ExitCode -ne 0) { throw "QTE03 failed: checks=$($summary.checks), failures=$($summary.failures), exit=$($p.ExitCode)" }
if ($before -ne $after) { throw 'Real save fingerprint changed' }
Write-Host ($summary | ConvertTo-Json -Compress)

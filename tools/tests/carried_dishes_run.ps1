param(
    [ValidateSet('import','smoke','flow')][string]$Mode = 'flow',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot = '',
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Godot)) { throw 'Godot executable missing' }
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/carried_dishes/' + $Mode + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputRoot '.gdignore'), '')
$realDirectory = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Fingerprints {
    $values = [ordered]@{}
    if (Test-Path -LiteralPath $realDirectory) {
        Get-ChildItem -LiteralPath $realDirectory -Recurse -File -Filter '*.json' | Sort-Object FullName | ForEach-Object { $values[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
    return ($values | ConvertTo-Json -Compress)
}
$before = Fingerprints
[IO.File]::WriteAllText((Join-Path $OutputRoot 'real_saves_before.json'), $before)
$profile = Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$psi = [Diagnostics.ProcessStartInfo]::new($Godot)
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile
$psi.Environment['LOCALAPPDATA'] = $profile
$psi.Environment['MAZE_QTE03_PROFILE'] = $profile
$arguments = @('--path', $ProjectRoot, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility')
switch ($Mode) {
    'import' { $arguments += @('--headless','--editor','--quit') }
    'smoke' { $arguments += @('--headless','--quit-after','5') }
    'flow' { $arguments += 'res://tools/tests/carried_dishes.tscn' }
}
$report = Join-Path $OutputRoot 'report.json'
$arguments += @('--', ('--report=' + $report), ('--output-dir=' + (Join-Path $OutputRoot 'screenshots')))
foreach ($engineArgument in $arguments) { $psi.ArgumentList.Add([string]$engineArgument) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$outTask = $process.StandardOutput.ReadToEndAsync()
$errTask = $process.StandardError.ReadToEndAsync()
$timeout = if ($Mode -in @('flow','entry_flow')) { 240000 } else { 240000 }
$timedOut = !$process.WaitForExit($timeout)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
$stdout = $outTask.GetAwaiter().GetResult()
$stderr = $errTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $OutputRoot 'stdout.log'), $stdout)
[IO.File]::WriteAllText((Join-Path $OutputRoot 'stderr.log'), $stderr)
$after = Fingerprints
[IO.File]::WriteAllText((Join-Path $OutputRoot 'real_saves_after.json'), $after)
$allLogs = $stdout + "`n" + $stderr
$environmentErrors = @($allLogs -split "`n" | Where-Object { $_ -match '^ERROR: (Failed to read the root certificate store\.|Cannot save file .*editor_settings-4\.7\.tres|Error saving editor settings to .*editor_settings-4\.7\.tres)' })
$errors = @($allLogs -split "`n" | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:|.*Parse Error:)' -and $_ -notin $environmentErrors })
$certificateWarning = $allLogs -match 'certificates|certificate|system_certs'
$summary = [ordered]@{ mode=$Mode; exit_code=$process.ExitCode; timed_out=$timedOut; errors=$errors; environment_errors=$environmentErrors; certificate_warning=$certificateWarning; real_saves_unchanged=($before -eq $after); command=$arguments; output=$OutputRoot }
if (Test-Path -LiteralPath $report) { $r = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json; $summary.checks=$r.checks; $summary.failures=$r.failures }
$summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'summary.json')
$summary | ConvertTo-Json -Depth 8
if ($timedOut -or $process.ExitCode -ne 0 -or $before -ne $after -or $errors.Count -gt 0 -or ($summary.Contains('failures') -and $summary.failures -ne 0)) { throw '验收未通过，日志已保留' }
if ($Mode -notin @('import','smoke') -and !(Test-Path -LiteralPath $report)) { throw '验收报告缺失' }




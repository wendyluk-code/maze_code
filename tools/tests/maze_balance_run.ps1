param([string]$Scene = 'res://tools/tests/maze_balance.tscn', [string]$Name = 'flow', [switch]$Resume)
$ErrorActionPreference = 'Stop'
$project = 'F:\maze_code'
$engine = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$outputPath = Join-Path $project 'output\maze_balance'
$profilePath = Join-Path $outputPath 'profile'
New-Item -ItemType Directory -Force $profilePath | Out-Null
$realSave = Join-Path $env:APPDATA 'Godot\app_userdata\maze_code\save.json'
function Fingerprint { $saveRoot = Split-Path $realSave; if (Test-Path -LiteralPath $saveRoot) { return ((Get-ChildItem -LiteralPath $saveRoot -Filter '*.json' -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join '|') }; return 'absent' }
$before = Fingerprint
$psi = [Diagnostics.ProcessStartInfo]::new($engine)
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profilePath
$psi.Environment['LOCALAPPDATA'] = $profilePath
$psi.Environment['MAZE_QTE03_PROFILE'] = $profilePath
foreach ($item in @('--path', $project, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--log-file', (Join-Path $outputPath ($Name + '-engine.log')), $Scene, '--', '--verify-stamina', ('--output-dir=' + $outputPath), ('--report=' + (Join-Path $outputPath ($Name + '-report.json'))))) {
    $psi.ArgumentList.Add($item)
}
$process = [Diagnostics.Process]::new()
if ($Resume) { $psi.ArgumentList.Add('--resume-stamina') }
$process.StartInfo = $psi
$null = $process.Start()
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
$timedOut = !$process.WaitForExit(300000)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
[IO.File]::WriteAllText((Join-Path $outputPath ($Name + '-stdout.log')), $stdout.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $outputPath ($Name + '-stderr.log')), $stderr.GetAwaiter().GetResult())
$after = Fingerprint
$scriptErrors = [bool](($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()) -match 'SCRIPT ERROR:|Parse Error:')
$summary = @{ exit_code = $process.ExitCode; timed_out = $timedOut; real_save_unchanged = ($before -eq $after); script_errors = $scriptErrors }
$summary | ConvertTo-Json | Set-Content (Join-Path $outputPath ($Name + '-runner.json'))
$summary | ConvertTo-Json
if ($timedOut -or $process.ExitCode -ne 0 -or $before -ne $after -or $scriptErrors) { throw '迷宫平衡验收失败；查看 output/maze_balance 下的日志' }



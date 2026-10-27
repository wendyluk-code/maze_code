param([string]$Scene = 'res://tools/tests/recipe_source_check.tscn', [string]$Name = 'component')
$ErrorActionPreference = 'Stop'
$project = 'F:\maze_code'
$engine = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$outputPath = Join-Path $project 'output\recipe_unlock_check'
$profilePath = Join-Path $outputPath 'profile'
New-Item -ItemType Directory -Force $profilePath | Out-Null
$realSave = Join-Path $env:APPDATA 'Godot\app_userdata\maze_code\save.json'
function Fingerprint { if (Test-Path -LiteralPath $realSave) { (Get-FileHash -LiteralPath $realSave).Hash } else { 'absent' } }
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
foreach ($item in @('--path', $project, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--log-file', (Join-Path $outputPath ($Name + '-engine.log')), $Scene, '--', '--verify-recipe', ('--output-dir=' + $outputPath), ('--report=' + (Join-Path $outputPath ($Name + '-report.json'))))) {
    $psi.ArgumentList.Add($item)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
$timedOut = !$process.WaitForExit(120000)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
[IO.File]::WriteAllText((Join-Path $outputPath ($Name + '-stdout.log')), $stdout.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $outputPath ($Name + '-stderr.log')), $stderr.GetAwaiter().GetResult())
$after = Fingerprint
$summary = @{ exit_code = $process.ExitCode; timed_out = $timedOut; real_save_unchanged = ($before -eq $after) }
$summary | ConvertTo-Json | Set-Content (Join-Path $outputPath ($Name + '-runner.json'))
$summary | ConvertTo-Json
if ($timedOut -or $process.ExitCode -ne 0 -or $before -ne $after) { throw '食谱预览验收失败；查看 output/recipe_book_preview 下的日志' }



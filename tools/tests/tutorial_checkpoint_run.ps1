param([string]$OutputRoot = '', [switch]$Headless, [switch]$Resume)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if (!(Test-Path -LiteralPath $godot)) { throw 'Godot executable missing' }
if (!$OutputRoot) { $OutputRoot = Join-Path $projectRoot ('output/tutorial_checkpoint/' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputRoot '.gdignore'), '')
$formalRoot = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Get-SaveFingerprint {
    $entries = [ordered]@{}
    if (Test-Path -LiteralPath $formalRoot) {
        Get-ChildItem -LiteralPath $formalRoot -Recurse -File -Filter '*.json' | Sort-Object FullName | ForEach-Object {
            $entries[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
    return ($entries | ConvertTo-Json -Compress)
}
$before = Get-SaveFingerprint
$profile = Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$psi = [Diagnostics.ProcessStartInfo]::new($godot)
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile
$psi.Environment['LOCALAPPDATA'] = $profile
$psi.Environment['MAZE_CHECKPOINT_PROFILE'] = $profile
$arguments = @('--path', $projectRoot, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--script', 'res://tools/tests/tutorial_checkpoint_flow.gd')
if ($Headless) { $arguments += '--headless' }
$prefix = if ($Resume) { 'resume-' } else { '' }
$report = Join-Path $OutputRoot ($prefix + 'report.json')
$arguments += @('--', ('--report=' + $report))
if ($Resume) { $arguments += '--resume' }
foreach ($argument in $arguments) { $psi.ArgumentList.Add($argument) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$outTask = $process.StandardOutput.ReadToEndAsync()
$errTask = $process.StandardError.ReadToEndAsync()
# 仅回收本次 Start 返回的进程对象，不枚举或终止其他游戏/验收进程。
$timedOut = !$process.WaitForExit(120000)
if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
$stdout = $outTask.GetAwaiter().GetResult()
$stderr = $errTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $OutputRoot ($prefix + 'stdout.log')), $stdout)
[IO.File]::WriteAllText((Join-Path $OutputRoot ($prefix + 'stderr.log')), $stderr)
$unchanged = $before -eq (Get-SaveFingerprint)
$errors = @((($stdout + "`n" + $stderr) -split "`n") | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.' })
$summary = [ordered]@{ exit_code=$process.ExitCode; timed_out=$timedOut; real_saves_unchanged=$unchanged; errors=$errors; output=$OutputRoot }
if (Test-Path -LiteralPath $report) {
    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    $summary.checks = $result.checks
    $summary.failures = $result.failures
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $OutputRoot ($prefix + 'summary.json'))
$summary | ConvertTo-Json -Depth 5
if ($timedOut -or $process.ExitCode -ne 0 -or !$unchanged -or $errors.Count -gt 0 -or !(Test-Path -LiteralPath $report) -or $result.failures -ne 0) { throw '检查点验收失败，日志已保留' }

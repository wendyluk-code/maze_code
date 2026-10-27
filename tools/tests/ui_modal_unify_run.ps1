param(
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot = '',
    [string]$Scene = 'res://tools/tests/ui_modal_unify_visual.tscn',
    [string]$Mode = '',
    [string]$Resolution = '1280x720',
    [string]$ReportName = 'acceptance.json'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Godot)) { throw "Godot 可执行文件不存在：$Godot" }
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/ui_modal_unify/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if ((Test-Path -LiteralPath $OutputRoot) -and @(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -gt 0) { throw '输出目录必须为空，避免覆盖既有证据' }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$realSave = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code/save.json'
function SaveFingerprint {
    $values = [ordered]@{}
    $directory = Split-Path $realSave
    if (Test-Path -LiteralPath $directory) {
        Get-ChildItem -LiteralPath $directory -Recurse -File -Filter '*.json' | Sort-Object FullName | ForEach-Object { $values[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
    return ($values | ConvertTo-Json -Compress)
}
$before = SaveFingerprint
$profile = Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$report = Join-Path $OutputRoot $ReportName
$psi = [Diagnostics.ProcessStartInfo]::new($Godot)
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile
$psi.Environment['LOCALAPPDATA'] = $profile
$psi.Environment['MAZE_QTE03_PROFILE'] = $profile
$psi.Environment['MAZE_START01_ROOT'] = $profile
$psi.Environment['MAZE_PRO_01_ISOLATED'] = '1'
foreach ($engineArg in @('--path', $ProjectRoot, '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', $Scene, '--resolution', $Resolution, '--', ('--mode=' + $Mode), ('--isolation-root=' + $profile), ('--report=' + $report), ('--output-dir=' + $OutputRoot))) {
    $psi.ArgumentList.Add([string]$engineArg)
}
if ($Scene -eq 'res://tools/tests/cooking_hold_one_second.tscn') { $psi.ArgumentList.Add('--expected-ms=500') }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = !$process.WaitForExit(180000)
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
if (Test-Path -LiteralPath $report) { $r = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json; $summary.checks=if ($r.checks -is [array]) { $r.checks.Count } else { $r.checks }; $summary.failures=$r.failures; $summary.display=$r.display }
$summary | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'runner-summary.json')
Write-Output ([pscustomobject]$summary | Select-Object exit_code,timed_out,checks,failures,unexpected_errors,environment_errors,real_save_unchanged,output | ConvertTo-Json -Depth 8)
if ($timedOut -or !(Test-Path -LiteralPath $report)) { throw '验收未结束或缺少报告；原始日志已保留' }
if ($summary.checks -le 0 -or $summary.failures -ne 0 -or $process.ExitCode -ne 0 -or $unexpectedErrors.Count -gt 0) { throw '验收失败，请查看报告与引擎日志' }
if ($before -ne $after) { throw '正式存档指纹变化；不推断来源、不回写存档' }

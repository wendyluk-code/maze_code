param(
    [string]$Scene = 'res://tools/tests/card_retirement.tscn',
    [string]$Name = 'retirement',
    [ValidateSet('scene','import','smoke')][string]$Mode = 'scene'
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if (!(Test-Path -LiteralPath $engine)) { throw 'Godot 可执行文件不存在' }
$evidenceRoot = Join-Path $project ('output/retire_cards_20261017/' + $Name)
if (Test-Path -LiteralPath $evidenceRoot) { throw '证据目录已存在，请使用新的Name' }
$profile = Join-Path $evidenceRoot 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
Set-Content -LiteralPath (Join-Path $evidenceRoot '.gdignore') -Value ''
$realDirectory = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Fingerprint {
    $values = [ordered]@{}
    if (Test-Path -LiteralPath $realDirectory) {
        Get-ChildItem -LiteralPath $realDirectory -Recurse -File -Filter '*.json' | Sort-Object FullName | ForEach-Object {
            $values[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
    return ConvertTo-Json -InputObject $values -Compress
}
$before = Fingerprint
$psi = [Diagnostics.ProcessStartInfo]::new($engine)
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile
$psi.Environment['LOCALAPPDATA'] = $profile
$psi.Environment['MAZE_QTE03_PROFILE'] = $profile
$report = Join-Path $evidenceRoot 'report.json'
$arguments = @('--path',$project,'--audio-driver','Dummy','--rendering-method','gl_compatibility')
switch ($Mode) {
    'import' { $arguments += @('--headless','--editor','--quit') }
    'smoke' { $arguments += @('--headless','--quit-after','5') }
    'scene' { $arguments += @($Scene,'--',('--report='+$report),('--output-dir='+$evidenceRoot)) }
}
foreach ($argument in $arguments) { $psi.ArgumentList.Add($argument) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timeout = !$process.WaitForExit(300000)
if ($timeout) { $process.Kill($true); $process.WaitForExit() }
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $evidenceRoot 'stdout.log'),$stdout)
[IO.File]::WriteAllText((Join-Path $evidenceRoot 'stderr.log'),$stderr)
$after = Fingerprint
[IO.File]::WriteAllText((Join-Path $evidenceRoot 'formal_before.json'),$before)
[IO.File]::WriteAllText((Join-Path $evidenceRoot 'formal_after.json'),$after)
$errors = @(($stdout + "`n" + $stderr) -split "`n" | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:)' })
$environmentErrors = @($errors | Where-Object { $_ -match 'root certificate store|system certificates|editor_settings-4.7.tres' })
$projectErrors = @($errors | Where-Object { $_ -notin $environmentErrors })
$summary = [ordered]@{command=$arguments;exit_code=$process.ExitCode;timed_out=$timeout;formal_saves_unchanged=($before -eq $after);project_errors=$projectErrors;environment_errors=$environmentErrors}
if (Test-Path -LiteralPath $report) {
    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    $summary.checks = $result.checks
    $summary.failures = $result.failures
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $evidenceRoot 'summary.json')
$summary | ConvertTo-Json -Depth 8
if ($timeout -or $process.ExitCode -ne 0 -or $before -ne $after -or $projectErrors.Count -gt 0) { throw '验收失败，日志已保存' }
if ($Mode -eq 'scene' -and (!(Test-Path -LiteralPath $report) -or $summary.checks -le 0 -or $summary.failures -ne 0)) { throw '验收报告未通过' }

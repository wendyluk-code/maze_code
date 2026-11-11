param([string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,[string]$RunName='r1',[switch]$Import,[switch]$Smoke,[switch]$WaterCheck,[string]$RuntimeName='c03_ahong_runtime')
$ErrorActionPreference='Stop'
$godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if (!(Test-Path -LiteralPath $godot)) { throw 'Godot 不存在' }
$runtime=Join-Path $ProjectRoot ('output/'+$RuntimeName)
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
foreach ($folder in @('assets','scripts','data','scenes','addons','tools','generated_assets')) {
    if (!(Test-Path -LiteralPath (Join-Path $runtime $folder))) { New-Item -ItemType Junction -Path (Join-Path $runtime $folder) -Target (Join-Path $ProjectRoot $folder) | Out-Null }
}
$config=[IO.File]::ReadAllText((Join-Path $ProjectRoot 'project.godot')).Replace('config/name="maze_code"','config/name="maze_c03_ahong_isolated"')
if (!$config.Contains('config/name="maze_c03_ahong_isolated"')) { throw '独立项目名未设置，禁止启动' }
[IO.File]::WriteAllText((Join-Path $runtime 'project.godot'),$config)
$output=Join-Path $ProjectRoot ('output/c03_ahong_'+$RunName)
if (Test-Path -LiteralPath $output) { throw '证据目录已存在' }
New-Item -ItemType Directory -Force -Path $output,(Join-Path $output 'profile') | Out-Null
$profile=Join-Path $output 'profile'
$psi=[Diagnostics.ProcessStartInfo]::new($godot)
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
foreach ($key in @('APPDATA','LOCALAPPDATA','MAZE_QTE03_PROFILE')) { $psi.Environment[$key]=$profile }
$argsList=@('--path',$runtime,'--audio-driver','Dummy','--rendering-method','gl_compatibility')
if ($Import) { $argsList+=@('--headless','--editor','--quit') }
elseif ($WaterCheck) { $argsList+=@('--headless','--script','res://tools/tests/c03_ahong_build_water.gd','--','--verify') }
elseif ($Smoke) { $argsList+=@('--headless','--quit-after','5') }
else { $argsList+=@('res://tools/tests/c03_ahong.tscn','--resolution','1280x720','--',('--report='+$output+'/report.json'),('--output-dir='+$output)) }
foreach ($arg in $argsList) { $psi.ArgumentList.Add($arg) }
$p=[Diagnostics.Process]::Start($psi)
$stdout=$p.StandardOutput.ReadToEndAsync()
$stderr=$p.StandardError.ReadToEndAsync()
$timedOut=!$p.WaitForExit(240000)
if ($timedOut) { $p.Kill($true); $p.WaitForExit() }
$outText=$stdout.GetAwaiter().GetResult()
$errText=$stderr.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $output 'stdout.log'),$outText)
[IO.File]::WriteAllText((Join-Path $output 'stderr.log'),$errText)
Write-Output ('Exit='+$p.ExitCode+' Output='+$output)
$errors=@(($outText+"`n"+$errText) -split "`n" | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch 'root certificate store|editor_settings|Error saving editor settings' })
$report=$null
if (Test-Path (Join-Path $output 'report.json')) { $report=Get-Content (Join-Path $output 'report.json') -Raw | ConvertFrom-Json; $report | Select-Object checks,failures,user_dir | ConvertTo-Json }
$summary=@{exit_code=$p.ExitCode;timed_out=$timedOut;unexpected_errors=$errors;isolated_project='maze_c03_ahong_isolated';formal_save_accessed=$false}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $output 'runner-summary.json')
if ($timedOut -or $p.ExitCode -ne 0 -or $errors.Count -gt 0 -or (!$Import -and !$Smoke -and !$WaterCheck -and (!$report -or $report.failures -ne 0))) { throw '验收失败，详见原始日志' }

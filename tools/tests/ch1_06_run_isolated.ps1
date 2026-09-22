[CmdletBinding()]
param([string]$GodotPath='F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',[string]$OutputDir='')
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$version=((& $GodotPath --version | Select-Object -First 1)-join '').Trim()
if($version -notmatch '^4\.7\.2'){throw "Godot 4.7.2 required; got $version"}
$runRoot=Join-Path ([IO.Path]::GetTempPath()) ('maze_code_ch1_06_isolated_'+[guid]::NewGuid().ToString('N'))
$app=Join-Path $runRoot 'Roaming'; $local=Join-Path $runRoot 'Local'; New-Item -ItemType Directory -Path $app,$local|Out-Null
if([string]::IsNullOrWhiteSpace($OutputDir)){$OutputDir=Join-Path $runRoot 'reports'}; New-Item -ItemType Directory -Path $OutputDir -Force|Out-Null
$report=Join-Path $OutputDir 'ch1-06-warehouse-report.json'; $stdout=Join-Path $OutputDir 'ch1-06.stdout.txt'; $stderr=Join-Path $OutputDir 'ch1-06.stderr.txt'
$args=@('--headless','--path',$workspace,'--scene','res://tools/tests/ch1_06_warehouse_suite.tscn','--',('--isolation-root='+$runRoot),('--isolation-appdata='+$app),('--report='+$report))
$oldA=$env:APPDATA; $oldL=$env:LOCALAPPDATA; $oldM=$env:MAZE_CH1_06_ISOLATED
try{$env:APPDATA=$app;$env:LOCALAPPDATA=$local;$env:MAZE_CH1_06_ISOLATED='1';$p=Start-Process -FilePath $GodotPath -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr}
finally{$env:APPDATA=$oldA;$env:LOCALAPPDATA=$oldL;if($null -eq $oldM){Remove-Item Env:MAZE_CH1_06_ISOLATED -ErrorAction SilentlyContinue}else{$env:MAZE_CH1_06_ISOLATED=$oldM}}
$valid=$false;$clear=$false;if(Test-Path $report){try{$j=Get-Content -Raw $report|ConvertFrom-Json;$valid=$null-ne $j;$clear=[int]$j.failures -eq 0}catch{}}
$passed=($p.ExitCode -eq 0)-and$valid-and$clear
$summary=[ordered]@{test='ch1_06';godot_version=$version;workspace=$workspace;exit_code=$p.ExitCode;runner_passed=$passed;report=$report;stdout=$stdout;stderr=$stderr;isolated_root=$runRoot}
$summaryPath=Join-Path $OutputDir 'ch1-06-runner-summary.json';$summary|ConvertTo-Json -Depth 8|Set-Content $summaryPath -Encoding UTF8
Write-Output "RUNNER summary=$summaryPath";Write-Output "RUNNER godot_exit_code=$($p.ExitCode)";Write-Output "RUNNER runner_passed=$passed";Write-Output "RUNNER report=$report";exit $(if($passed){0}else{1})

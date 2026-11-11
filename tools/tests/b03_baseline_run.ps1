param([string]$SourceRoot='F:/maze_code',[string]$RunName='r1',[switch]$Import,[string]$Mode='matrix',[string]$EvidenceRoot='', [switch]$Final)
$ErrorActionPreference='Stop'
$ticketRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidenceBase=if($EvidenceRoot){$EvidenceRoot}else{Join-Path $ticketRoot 'output'}
$runtime=Join-Path $evidenceBase 'b03_runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
foreach($folder in @('assets','scripts','data','scenes','addons','tools','generated_assets')) {
 if (!(Test-Path -LiteralPath (Join-Path $runtime $folder))) { New-Item -ItemType Junction -Path (Join-Path $runtime $folder) -Target (Join-Path $SourceRoot $folder) | Out-Null }
}
$testDir=Join-Path $runtime 'b03_tests'
New-Item -ItemType Directory -Force $testDir | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'b03_baseline.gd'),(Join-Path $PSScriptRoot 'b03_baseline.tscn') -Destination $testDir
if($Final){Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'b03_final.gd') -Destination $testDir; $scenePath=Join-Path $testDir 'b03_baseline.tscn'; $sceneText=[IO.File]::ReadAllText($scenePath).Replace('b03_baseline.gd','b03_final.gd'); [IO.File]::WriteAllText($scenePath,$sceneText)}
$config=[IO.File]::ReadAllText((Join-Path $SourceRoot 'project.godot')).Replace('config/name="maze_code"','config/name="maze_b03_isolated"')
if (!$config.Contains('config/name="maze_b03_isolated"')) { throw '隔离项目名失败' }
[IO.File]::WriteAllText((Join-Path $runtime 'project.godot'),$config)
$output=Join-Path $evidenceBase ('b03_'+$RunName)
if(Test-Path $output) { throw '证据目录已存在' }
New-Item -ItemType Directory -Force $output,(Join-Path $output 'profile') | Out-Null
$files=@(Get-ChildItem (Join-Path $SourceRoot 'scripts'),(Join-Path $SourceRoot 'data') -Recurse -File | Where-Object Extension -in '.gd','.json','.tres')
$before=@{}; foreach($f in $files) { $before[$f.FullName.Substring($SourceRoot.Length+1)]=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }
$before | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 (Join-Path $output 'source_hashes.json')
$godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if(!(Test-Path $godot)) {throw 'Godot不存在'}
$psi=[Diagnostics.ProcessStartInfo]::new($godot);$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
foreach($key in @('APPDATA','LOCALAPPDATA','MAZE_QTE03_PROFILE')) { $psi.Environment[$key]=(Join-Path $output 'profile') }
$argsList=@('--path',$runtime,'--audio-driver','Dummy','--rendering-method','gl_compatibility')
if($Import) {$argsList+=@('--headless','--editor','--quit')} else {$argsList+=@('res://b03_tests/b03_baseline.tscn','--resolution','1280x720','--',('--report='+$output+'/report.json'),('--output-dir='+$output),('--mode='+$Mode))}
foreach($arg in $argsList) {$psi.ArgumentList.Add($arg)}
$p=[Diagnostics.Process]::Start($psi);$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit(480000)
if($timeout) {$p.Kill($true);$p.WaitForExit()}
$outText=$stdout.GetAwaiter().GetResult();$errText=$stderr.GetAwaiter().GetResult();[IO.File]::WriteAllText((Join-Path $output 'stdout.log'),$outText);[IO.File]::WriteAllText((Join-Path $output 'stderr.log'),$errText)
$changed=@();foreach($f in $files) {$key=$f.FullName.Substring($SourceRoot.Length+1);if((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne $before[$key]) {$changed+=$key}}
$errors=@(($outText+"`n"+$errText)-split "`n" | Where-Object {$_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch 'root certificate store|editor_settings|Error saving editor settings'})
@{exit_code=$p.ExitCode;timed_out=$timeout;source_changed=$changed;unexpected_errors=$errors;source_root=$SourceRoot;isolated_project='maze_b03_isolated'} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $output 'runner-summary.json')
Write-Output ('Exit='+$p.ExitCode+' Output='+$output)
$report=$null;if(Test-Path (Join-Path $output 'report.json')) {$report=Get-Content (Join-Path $output 'report.json') -Raw | ConvertFrom-Json;$report | Select-Object checks,failures,user_dir | ConvertTo-Json}
if($timeout -or $p.ExitCode -ne 0 -or $errors.Count -gt 0 -or $changed.Count -gt 0 -or (!$Import -and (!$report -or $report.failures -ne 0))) {throw '验收失败或生产源发生并发变化，详见证据'}

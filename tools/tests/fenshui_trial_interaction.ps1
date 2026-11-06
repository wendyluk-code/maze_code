param(
 [string]$ProjectRoot=(Resolve-Path "$PSScriptRoot/../..").Path,
 [string]$OutputRoot="",
 [string]$SourceSave="D:/workspace/代号：料理迷宫/output/fs01/play-final/profile/Godot/app_userdata/maze_code/chapter-ending-test.json",
 [string]$Godot="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference="Stop"
if(-not $OutputRoot){$OutputRoot=Join-Path $ProjectRoot "output/fs01/interaction"}
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
$profile=Join-Path $OutputRoot "profile"
New-Item -ItemType Directory -Force $profile | Out-Null
$names=@("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE","FS01_DIAG_SOURCE","GODOT_EDITOR_CUSTOM_FEATURES")
$old=@{}
foreach($name in $names){$old[$name]=[Environment]::GetEnvironmentVariable($name,"Process")}
try{
 $env:APPDATA=$profile
 $env:LOCALAPPDATA=$profile
 $env:MAZE_QTE03_PROFILE=$profile
 $env:FS01_DIAG_SOURCE=$SourceSave
 $env:GODOT_EDITOR_CUSTOM_FEATURES=if($old.GODOT_EDITOR_CUSTOM_FEATURES){$old.GODOT_EDITOR_CUSTOM_FEATURES+",maze_automated_test"}else{"maze_automated_test"}
 $sourceHash=(Get-FileHash -LiteralPath $SourceSave).Hash
 $arguments=@("--path",('"'+$ProjectRoot+'"'),"--resolution","1280x720","--scene","res://tools/tests/fenshui_trial_interaction.tscn","--log-file",('"'+$OutputRoot+'/interaction.log"'),"--","--fs01-check",('"--output-dir='+$OutputRoot+'"'),('"--report='+$OutputRoot+'/report.json"'))
 $p=Start-Process $Godot -WindowStyle Hidden -ArgumentList $arguments -PassThru
 if(-not $p.WaitForExit(120000)){$p.Kill();throw "交互验收超过120秒，产物保留"}
 if((Get-FileHash -LiteralPath $SourceSave).Hash -ne $sourceHash){throw "源体验档发生变化，保留现场，不恢复或覆盖"}
 Get-Content (Join-Path $OutputRoot "interaction.log") -Tail 8
 if($p.ExitCode -ne 0){throw "交互验收失败，退出码 $($p.ExitCode)，查看 $OutputRoot"}
 $legacyProfile=Join-Path $OutputRoot "legacy-profile"
 $legacyUser=Join-Path $legacyProfile "Godot/app_userdata/maze_code"
 New-Item -ItemType Directory -Force $legacyUser | Out-Null
 Copy-Item -LiteralPath $SourceSave -Destination (Join-Path $legacyUser "chapter-ending-test.json")
 $env:APPDATA=$legacyProfile
 $env:LOCALAPPDATA=$legacyProfile
 $env:MAZE_QTE03_PROFILE=$legacyProfile
 foreach($stage in @("legacy-first","legacy-again")){
  $arguments=@("--path",('"'+$ProjectRoot+'"'),"--scene","res://tools/tests/fenshui_trial_legacy_restart.tscn","--log-file",('"'+$OutputRoot+"/$stage.log"+'"'),"--","--fs01-resume","--fs01-check",('"--report='+$OutputRoot+"/$stage.json"+'"'))
  $p=Start-Process $Godot -WindowStyle Hidden -ArgumentList $arguments -PassThru
  if(-not $p.WaitForExit(30000)){$p.Kill();throw "旧档重启验收超过30秒"}
  if($p.ExitCode -ne 0){throw "旧档重启失败：$stage，退出码 $($p.ExitCode)"}
 }
 if((Get-FileHash -LiteralPath $SourceSave).Hash -ne $sourceHash){throw "旧档重启测试期间源体验档发生变化"}
}finally{
 foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$old[$name],"Process")}
}

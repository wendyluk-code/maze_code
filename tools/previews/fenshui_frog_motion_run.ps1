param([switch]$CheckOnly,[string]$OutputRoot="",[string]$ScenePath="res://tools/previews/fenshui_frog_motion.tscn")
$ErrorActionPreference="Stop"
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$scene=$ScenePath
$out=Join-Path $root "output/fenshui-frog-motion-20261031/play"
if($OutputRoot){$out=[IO.Path]::GetFullPath($OutputRoot)}
$profile=Join-Path $out "profile"
if($CheckOnly){[ordered]@{project=$root;scene=$scene;profile=$profile;will_launch=$false}|ConvertTo-Json;return}
New-Item -ItemType Directory -Path $profile -Force|Out-Null
$psi=[Diagnostics.ProcessStartInfo]::new("D:/Tools/Godot/Godot_v4.7.2-stable_win64.exe")
$psi.WorkingDirectory=$root
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
foreach($key in @("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE")){$psi.Environment[$key]=$profile}
$psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_automated_test"
foreach($arg in @("--path",$root,"--resolution","1280x720","--scene",$scene,"--log-file",(Join-Path $out "engine.log"))){$psi.ArgumentList.Add($arg)}
$psi.ArgumentList.Add("--")
$psi.ArgumentList.Add("--frog-motion-passive")
$psi.ArgumentList.Add("--frog-window-report="+(Join-Path $out "window.json"))
$p=[Diagnostics.Process]::Start($psi)
$keys=if($scene -eq "res://tools/previews/fenshui_frog_direction.tscn"){"静态核对；F7下一朝向、F8下一关键姿态、F10蹲姿、F9原单向战斗"}else{"默认循环；按钮或F7重播、F8暂停、F10逐姿态、F9恢复原战斗"}
[ordered]@{pid=$p.Id;started_at=(Get-Date -Format o);scene=$scene;profile=$profile;keys=$keys}|ConvertTo-Json

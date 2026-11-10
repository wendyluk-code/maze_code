param([Parameter(Mandatory=$true)][string]$OutputRoot,[switch]$LeftChain,[switch]$Front24,[switch]$Unified)
$ErrorActionPreference="Stop"
if($LeftChain -and $Front24){throw "左前旧链与双前向24姿态是两个不同候选，请只选择一个"}
if($Unified -and ($LeftChain -or $Front24)){throw "统一实战已包含当前双前向候选，不与旧入口开关混用"}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$out=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $out){throw "体验目录已存在，不覆盖旧档"}
$profile=Join-Path $out "profile"
New-Item -ItemType Directory -Path $profile -Force|Out-Null
$psi=[Diagnostics.ProcessStartInfo]::new("D:/Tools/Godot/Godot_v4.7.2-stable_win64.exe")
$psi.WorkingDirectory=$root
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
foreach($key in @("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE")){$psi.Environment[$key]=$profile}
$psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_automated_test"
$entryScene=if($Front24){"res://tools/previews/fenshui_frog_front24_play.tscn"}elseif($LeftChain){"res://tools/previews/fenshui_frog_left_play.tscn"}else{"res://tools/previews/fenshui_frog_play.tscn"}
if($Unified){$entryScene="res://tools/previews/fenshui_unified_play.tscn"}
foreach($arg in @("--path",$root,"--resolution","1280x720","--scene",$entryScene,"--log-file",(Join-Path $out "engine.log"),"--",("--frog-window-report="+(Join-Path $out "window.json")))){$psi.ArgumentList.Add($arg)}
$p=[Diagnostics.Process]::Start($psi)
$result=[ordered]@{pid=$p.Id;started_at=(Get-Date -Format o);project=$root;head=(git -C $root rev-parse HEAD);profile=$profile;scene="res://scenes/maze_fenshui.tscn";entry_scene=$entryScene;left_chain_candidate=[bool]$LeftChain;front24_candidate=([bool]$Front24 -or [bool]$Unified);unified=[bool]$Unified;formal_combat=$true;entry="点击开始体验后由用户手动聚焦；方向键或WASD移动、左键攻击、空格/1/2选招式、Tab锁定/切换、Q解除、Ctrl+0满血"}
$result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out "launch.json") -Encoding utf8
$result|ConvertTo-Json

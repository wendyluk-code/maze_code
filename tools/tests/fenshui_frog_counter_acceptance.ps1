param([Parameter(Mandatory=$true)][string]$OutputRoot,[string]$ContinueFrom="",[string[]]$SkipCases=@(),[switch]$Front24,[switch]$Unified,[switch]$HealHit)
$ErrorActionPreference="Stop"
if($Unified -and $Front24){throw "统一实战清单已包含新前向实战，请勿同时指定旧候选清单"}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$out=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $out){throw "输出目录已存在，不覆盖证据"}
New-Item -ItemType Directory -Path $out|Out-Null
$files=@(Get-ChildItem -LiteralPath (Join-Path $root 'scripts/maze'),(Join-Path $root 'data/maze') -File -Filter '*.gd')
if($HealHit){$files+=Get-Item -LiteralPath (Join-Path $root 'scripts/maze/fenshui_hit_feedback.gdshader')}
$files+=@(Get-ChildItem -LiteralPath (Join-Path $root 'tools/tests') -File -Filter 'fenshui*')
$files+=@(Get-ChildItem -LiteralPath (Join-Path $root 'tools/previews') -File -Filter 'fenshui*')
$files+=@(Get-ChildItem -LiteralPath (Join-Path $root 'assets/monsters/wind_frog/counter_candidate') -Recurse -File -Filter '*.png')
$files+=Get-Item -LiteralPath (Join-Path $root 'assets/monsters/wind_frog/counter_candidate/directions/left-chain/prepared.json')
$files+=Get-Item -LiteralPath (Join-Path $root 'assets/monsters/wind_frog/counter_candidate/directions/back-right-chain/prepared.json'),(Join-Path $root 'assets/monsters/wind_frog/counter_candidate/directions/back-left-chain/prepared.json'),(Join-Path $root 'scripts/ui/components/capture_dialog.gd'),(Join-Path $root 'scripts/ui/components/capture_attempt_modal.gd')
function Snapshot {
 $result=[ordered]@{}
 foreach($file in $files|Sort-Object FullName){$result[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName).Hash}
 $result|ConvertTo-Json -Compress
}
$real=Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function RealSaves {
 $result=[ordered]@{}
 if(Test-Path -LiteralPath $real){foreach($file in Get-ChildItem -LiteralPath $real -File -Filter '*.json' -Recurse|Sort-Object FullName){$result[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName).Hash}}
 $result|ConvertTo-Json -Compress
}
$started=Get-Date -Format o
$before=Snapshot
$saveBefore=RealSaves
[IO.File]::WriteAllText((Join-Path $out 'sources-before.json'),$before)
[IO.File]::WriteAllText((Join-Path $out 'real-saves-before.json'),$saveBefore)
$cases=@(
 @('state','fenshui_frog_counter',$false),
 @('back-chain','fenshui_frog_back_chain',$false),
 @('full-state','fenshui_frog_full_state',$false),
 @('full-battle','fenshui_frog_full_flow',$true),
 @('full-capture','fenshui_frog_full_capture',$true),
 @('battle','fenshui_frog_counter_flow',$true),
 @('depth','fenshui_frog_depth',$true),
 @('labels','fenshui_combat_labels',$true),
 @('player-attacks','fenshui_player_attack_flow',$true),
 @('sprint','fenshui_sprint_flow',$true),
 @('direction-keys','fenshui_frog_direction',$true),
 @('left-chain','fenshui_frog_left_chain',$true),
 @('left-depth','fenshui_frog_left_depth',$true),
 @('left-capture','fenshui_frog_left_capture',$true),
 @('capture','fenshui_frog_capture',$true),
 @('play-entry','fenshui_frog_play_flow',$true),
 @('preview','fenshui_frog_motion',$true),
 @('axe-clock','fenshui_hitstop_state',$false),
 @('ranged-clock','fenshui_ranged_hitstop_state',$false)
)
if($Front24){
 $cases=@(
  @('front24-battle','fenshui_frog_front24_flow',$true),
  @('front24-capture','fenshui_frog_front24_capture',$true),
  @('front24-depth','fenshui_frog_front24_depth',$true),
  @('old-full-battle','fenshui_frog_full_flow',$true),
  @('old-full-capture','fenshui_frog_full_capture',$true),
  @('labels','fenshui_combat_labels',$true),
  @('player-attacks','fenshui_player_attack_flow',$true),
  @('sprint','fenshui_sprint_flow',$true),
  @('old-play-entry','fenshui_frog_play_flow',$true),
  @('axe-clock','fenshui_hitstop_state',$false),
  @('ranged-clock','fenshui_ranged_hitstop_state',$false)
 )
}
if($Unified){
 $cases=@(
  @('body-state','fenshui_body_state',$false),
  @('eel-body-shore','fenshui_eel_body_shore',$false),
  @('body-flow','fenshui_body_flow',$true),
  @('marker-flow','fenshui_lock_marker_flow',$true),
  @('seven-monster-flow','fenshui_unified_flow',$true),
  @('navigation-state','fenshui_frog_navigation',$false),
  @('navigation-flow','fenshui_frog_navigation_flow',$true),
  @('front24-battle','fenshui_frog_front24_flow',$true),
  @('front24-capture','fenshui_frog_front24_capture',$true),
  @('return-lock','fenshui_return_lock_flow',$true),
  @('player-attacks','fenshui_player_attack_flow',$true),
  @('sprint','fenshui_sprint_flow',$true),
  @('axe-clock','fenshui_hitstop_state',$false),
  @('ranged-clock','fenshui_ranged_hitstop_state',$false)
 )
}
$reached=$ContinueFrom -eq ""
if($HealHit){$cases=@(@('peak-state','fenshui_frog_peak_state',$false),@('fast-heal-state','fenshui_fast_heal_state',$false),@('water-heal-state','fenshui_water_heal_state',$false),@('heal-state','fenshui_heal_state',$false),@('hit-feedback-state','fenshui_hit_feedback_state',$false),@('heal-hit-seven','fenshui_heal_hit_flow',$true),@('frog-sweat','fenshui_frog_sweat_flow',$true))+$cases}
foreach($case in $cases){
 if($case[0] -eq $ContinueFrom){$reached=$true}
 if(-not $reached -or $case[0] -in $SkipCases){continue}
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -ScenePath ("res://tools/tests/"+$case[1]+".tscn") -Offscreen:([bool]$case[2]) -OutputRoot (Join-Path $out $case[0])
}
if(-not $reached){throw "未找到继续位置"}
if($HealHit){
 foreach($phase in @('seed','restore')){
  & "$PSScriptRoot/fenshui_hitstop_run.ps1" -ScenePath 'res://tools/tests/fenshui_heal_restart.tscn' -Phase $phase -ProfileRoot (Join-Path $out 'heal-restart-profile') -OutputRoot (Join-Path $out ('heal-restart-'+$phase))
 }
}
if($Front24){
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_frog_front24_depth.tscn' -Phase wide -OutputRoot (Join-Path $out 'front24-depth-wide')
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_frog_play_flow.tscn' -Phase front24 -OutputRoot (Join-Path $out 'front24-play')
 foreach($phase in @('seed','restore')){
  & "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen:($phase -eq 'restore') -ScenePath 'res://tools/tests/fenshui_frog_front24_restart.tscn' -Phase $phase -ProfileRoot (Join-Path $out 'front24-restart-profile') -OutputRoot (Join-Path $out ('front24-restart-'+$phase))
 }
}elseif(-not $Unified){
& "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_frog_attachment.tscn' -Phase bubble -OutputRoot (Join-Path $out 'bubble')
& "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_combat_labels.tscn' -Phase wide -OutputRoot (Join-Path $out 'labels-wide')
& "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_frog_left_depth.tscn' -Phase wide -OutputRoot (Join-Path $out 'left-depth-wide')
foreach($phase in @('right','left','wide','left-wide')){
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_frog_back_depth.tscn' -Phase $phase -OutputRoot (Join-Path $out ('back-depth-'+$phase))
}
foreach($phase in @('seed','restore')){
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen:($phase -eq 'restore') -ScenePath 'res://tools/tests/fenshui_frog_full_restart.tscn' -Phase $phase -ProfileRoot (Join-Path $out 'full-restart-profile') -OutputRoot (Join-Path $out ('full-restart-'+$phase))
}
}
if($Unified){
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_frog_play_flow.tscn' -Phase unified -OutputRoot (Join-Path $out 'unified-play')
}
foreach($phase in @('seed','restore')){
 & "$PSScriptRoot/fenshui_hitstop_run.ps1" -ScenePath 'res://tools/tests/fenshui_frog_counter_restart.tscn' -Phase $phase -ProfileRoot (Join-Path $out 'restart-profile') -OutputRoot (Join-Path $out "restart-$phase")
}
& "$PSScriptRoot/fenshui_hitstop_run.ps1" -ScriptPath 'res://tools/tests/fenshui_area_lightning.gd' -OutputRoot (Join-Path $out 'area-state')
# 渲染与帧门槛独占引擎顺序，不与其他图形验收并行。
& "$PSScriptRoot/fenshui_hitstop_run.ps1" -Offscreen -ScenePath 'res://tools/tests/fenshui_area_flow.tscn' -OutputRoot (Join-Path $out 'area-flow')
foreach($mode in @('import','smoke')){
 & "$PSScriptRoot/combat_02_run.ps1" -Mode $mode -ProjectRoot $root -Godot 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' -OutputRoot (Join-Path $out $mode)
}
$after=Snapshot
$saveAfter=RealSaves
[IO.File]::WriteAllText((Join-Path $out 'sources-after.json'),$after)
[IO.File]::WriteAllText((Join-Path $out 'real-saves-after.json'),$saveAfter)
$report=[ordered]@{started_at=$started;ended_at=(Get-Date -Format o);project=$root;head=(git -C $root rev-parse HEAD);continued_from=$ContinueFrom;skipped_cases=$SkipCases;scope="本次实际执行清单；继续模式须另核前段证据与文件未变";source_files=$files.Count;sources_unchanged=($before -eq $after);real_saves_unchanged=($saveBefore -eq $saveAfter);passed=($before -eq $after -and $saveBefore -eq $saveAfter)}
$report|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'acceptance.json') -Encoding utf8
$report|ConvertTo-Json
if(-not $report.passed){throw "源码或正式档发生变化，不能认定固定版本验收通过"}

param(
    [ValidateSet('import','smoke','flow','team','restart_seed','restart_restore','old_details','old_team','old_party','legacy_team','review_edges','r2')][string]$Mode = 'flow',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot = '',
    [string]$ProfileRoot = '',
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference = 'Stop'
$scenes = @{
    r2='rec01_r2'; review_edges='rec01_review_edges'; flow='rec01_flow'; team='rec01_team'; restart_seed='rec01_restart_seed'; restart_restore='rec01_restart_restore'
    old_details='home_character_details'; old_team='combat_04_access'; legacy_team='team_entry_ui_02'; old_party='chapter_ending_input'
}
$runMode = if ($Mode -in @('import','smoke')) { $Mode } else { 'flow' }
$scenePath = if ($scenes.ContainsKey($Mode)) { 'res://tools/tests/' + $scenes[$Mode] + '.tscn' } else { '' }
& (Join-Path $PSScriptRoot 'combat_02_run.ps1') -Mode $runMode -ProjectRoot $ProjectRoot -OutputRoot $OutputRoot -ProfileRoot $ProfileRoot -Godot $Godot -ScenePath $scenePath

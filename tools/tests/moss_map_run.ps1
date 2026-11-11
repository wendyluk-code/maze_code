param(
    [ValidateSet('flow','restore','import','smoke')][string]$Mode='flow',
    [string]$Godot='D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputRoot='',
    [string]$ProfileRoot=''
)
$ErrorActionPreference='Stop'
if (!$OutputRoot) { $OutputRoot=Join-Path $PSScriptRoot ('../../output/moss-map-20261029/'+$Mode) }
if ($Mode -eq 'restore' -and !$ProfileRoot) { throw '恢复验收须指定此前流程的隔离 ProfileRoot' }
$previous=$env:MOSS_MAP_RESTORE
try {
    $env:MOSS_MAP_RESTORE=if ($Mode -eq 'restore') {'1'} else {''}
    $runnerMode=if ($Mode -in @('import','smoke')) {$Mode} else {'flow'}
    & (Join-Path $PSScriptRoot 'combat_02_run.ps1') -Mode $runnerMode -Godot $Godot -OutputRoot $OutputRoot -ProfileRoot $ProfileRoot -ScenePath res://tools/tests/moss_map_acceptance.tscn
} finally { $env:MOSS_MAP_RESTORE=$previous }

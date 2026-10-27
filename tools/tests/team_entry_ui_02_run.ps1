param(
    [ValidateSet('import','smoke','flow','resume')][string]$Mode = 'flow',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot = '',
    [string]$ProfileRoot = '',
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/team_entry_ui_02/' + $Mode + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
& (Join-Path $PSScriptRoot 'team_entry_01_run.ps1') -Mode $Mode -ProjectRoot $ProjectRoot -OutputRoot $OutputRoot -ProfileRoot $ProfileRoot -Godot $Godot -TestScene 'res://tools/tests/team_entry_ui_02.tscn'

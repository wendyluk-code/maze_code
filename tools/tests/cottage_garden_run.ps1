param(
    [ValidateSet('flow','restore','regression','import','smoke')][string]$Mode='flow',
    [string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$Godot='D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputRoot='',
    [string]$ProfileRoot=''
)
$ErrorActionPreference='Stop'
if (!$OutputRoot) { $OutputRoot=Join-Path $ProjectRoot ('output/cottage-garden-20261028/final-'+$Mode) }
if ($Mode -eq 'restore' -and !$ProfileRoot) { throw '恢复检查需要此前流程验收的隔离存档目录' }
$previous=$env:COTTAGE_GARDEN_RESTORE
try {
    $env:COTTAGE_GARDEN_RESTORE=if ($Mode -eq 'restore') { '1' } else { '' }
    $runnerMode=if ($Mode -in @('import','smoke')) { $Mode } else { 'flow' }
    $scene=if ($Mode -eq 'regression') { 'res://tools/tests/waterkeeper_flow.tscn' } else { 'res://tools/tests/cottage_garden.tscn' }
    & (Join-Path $PSScriptRoot 'combat_02_run.ps1') -Mode $runnerMode -ProjectRoot $ProjectRoot -Godot $Godot -OutputRoot $OutputRoot -ProfileRoot $ProfileRoot -ScenePath $scene
    $paths=@('assets/maps/waterkeeper_cottage.png','assets/maps/waterkeeper_cottage_soil.png',
        'assets/props/cottage_garden/tomato.png','assets/props/cottage_garden/turnip.png',
        'data/maze/waterkeeper_cottage_roads.gd','scripts/maze/cottage_garden.gd',
        'scripts/maze/cottage_plant.gdshader','scripts/maze/maze_entry.gd',
        'tools/prepare_cottage_garden.gd','tools/tests/cottage_garden.gd',
        'tools/tests/cottage_garden.tscn','tools/tests/cottage_garden_run.ps1',
        'tools/tests/cottage_garden_preview.py','docs/waterkeeper_cottage.md')
    $rows=foreach ($path in $paths) { $hash=Get-FileHash -LiteralPath (Join-Path $ProjectRoot $path) -Algorithm SHA256; [ordered]@{path=$path;sha256=$hash.Hash} }
    [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($OutputRoot)) 'source_snapshot.json'),($rows | ConvertTo-Json -Depth 4))
} finally { $env:COTTAGE_GARDEN_RESTORE=$previous }

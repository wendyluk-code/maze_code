param(
    [ValidateSet('flow','restore','regression','import','smoke')][string]$Mode = 'flow',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$Godot = 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputRoot = '',
    [string]$ProfileRoot = ''
)
$ErrorActionPreference = 'Stop'
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/waterkeeper-integration-20261028/' + $Mode) }
if ($Mode -eq 'restore' -and !$ProfileRoot) { throw '跨进程恢复必须指定此前流程验收的隔离 ProfileRoot' }
$previous = $env:MAZE_WATERKEEPER_RESTORE
try {
    $env:MAZE_WATERKEEPER_RESTORE = if ($Mode -eq 'restore') { '1' } else { '' }
    $runnerMode = if ($Mode -in @('import','smoke')) { $Mode } else { 'flow' }
    $scene = if ($Mode -eq 'regression') { 'res://tools/tests/moss_pool_flow.tscn' } else { 'res://tools/tests/waterkeeper_flow.tscn' }
    & (Join-Path $PSScriptRoot 'combat_02_run.ps1') -Mode $runnerMode -ProjectRoot $ProjectRoot -Godot $Godot -OutputRoot $OutputRoot -ProfileRoot $ProfileRoot -ScenePath $scene
    $paths = @(
        'assets/maps/waterkeeper_cottage.png','scenes/maze_waterkeeper_cottage.tscn',
        'data/maze/waterkeeper_cottage_roads.gd','data/maze/waterkeeper_cottage_projection.gd',
        'data/maze/moss_pool_projection.gd','data/maze/region_routes.gd',
        'scripts/maze/maze_entry.gd','scripts/maze/capture_run.gd','scripts/maze/combat_simulation.gd',
        'scripts/save_manager.gd','scripts/ui/components/maze_map.gd',
        'scripts/ui/components/maze_map_view.gd','scripts/ui/shallow_map_fog.gdshader',
        'tools/tests/waterkeeper_flow.gd','tools/tests/waterkeeper_run.ps1','tools/tests/combat_02_run.ps1',
        'tools/tests/waterkeeper_preview.gd','tools/tests/waterkeeper_preview.tscn',
        'docs/waterkeeper_cottage.md','docs/ui_component_library.md'
    )
    $hashes = foreach ($path in $paths) {
        $hash = Get-FileHash -LiteralPath (Join-Path $ProjectRoot $path) -Algorithm SHA256
        [ordered]@{ path=$path; sha256=$hash.Hash }
    }
    [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($OutputRoot)) 'source_snapshot.json'), ($hashes | ConvertTo-Json -Depth 4))
} finally {
    $env:MAZE_WATERKEEPER_RESTORE = $previous
}

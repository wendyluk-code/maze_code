param(
 [ValidateSet('flow','edges','seed','restore','import','smoke','regression','sparring','backpack','skills','lifecycle','recipes','bento','freezer','bento_seed','bento_restore','bento_concurrent')][string]$Mode='flow',
 [string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
 [string]$EvidenceRoot='',
 [string]$Godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference='Stop'
if (!$EvidenceRoot) { $EvidenceRoot=Join-Path $ProjectRoot 'output/bento01' }
$EvidenceRoot=[IO.Path]::GetFullPath($EvidenceRoot)
$bin=Join-Path $EvidenceRoot 'bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
[IO.File]::WriteAllText((Join-Path $EvidenceRoot '.gdignore'),'')
$engine=Join-Path $bin 'godot.exe'
if (!(Test-Path -LiteralPath $engine)) { Copy-Item -LiteralPath $Godot -Destination $engine }
$settings=Join-Path $EvidenceRoot 'import/profile/Godot/editor_settings-4.7.tres'
New-Item -ItemType Directory -Force (Split-Path $settings) | Out-Null
if (!(Test-Path $settings)) {
 [IO.File]::WriteAllText($settings, '[gd_resource type="EditorSettings" format=3]' + "`n`n" + '[resource]' + "`n" + 'filesystem/import/blender/blender_path = "F:/Blender Foundation/Blender 5.2/blender.exe"' + "`n")
}
$runMode=if ($Mode -in @('import','smoke')) { $Mode } else { 'flow' }
$scene=switch ($Mode) {
 'bento_concurrent' { 'res://tools/tests/bento01_flow.tscn' }
 'bento_seed' { 'res://tools/tests/bento01_flow.tscn' }
 'bento_restore' { 'res://tools/tests/bento01_flow.tscn' }
 'bento' { 'res://tools/tests/bento01_flow.tscn' }
 'freezer' { 'res://tools/tests/freezer_01.tscn' }
 'lifecycle' { 'res://tools/tests/bento01_lifecycle.tscn' }
 'recipes' { 'res://tools/tests/yf03_recipes.tscn' }
 'flow' { 'res://tools/tests/yf03_flow.tscn' }
 'edges' { 'res://tools/tests/yf03_edges.tscn' }
 'seed' { 'res://tools/tests/yf03_restart.tscn' }
 'restore' { 'res://tools/tests/yf03_restart.tscn' }
 'sparring' { 'res://tools/tests/yf03_sparring.tscn' }
 'backpack' { 'res://tools/tests/yf03_backpack.tscn' }
 'skills' { 'res://tools/tests/combat_skill_01.tscn' }
 'regression' { 'res://tools/tests/guard_remove_capture.tscn' }
 default { '' }
}
$oldRestart=$env:YF03_RESTART
$oldBento=$env:BENTO01_PHASE
try {
 $env:YF03_RESTART=$Mode
 $env:BENTO01_PHASE=$Mode -replace 'bento_',''
 $profile=if ($Mode -in @('seed','restore','bento_seed','bento_restore')) { Join-Path $EvidenceRoot 'restart_profile' } else { '' }
 & (Join-Path $ProjectRoot 'tools/tests/yf03_engine.ps1') -Mode $runMode -ProjectRoot $ProjectRoot -OutputRoot (Join-Path $EvidenceRoot $Mode) -ProfileRoot $profile -Godot $engine -ScenePath $scene
} finally { $env:YF03_RESTART=$oldRestart; $env:BENTO01_PHASE=$oldBento }

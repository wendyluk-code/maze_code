param(
 [ValidateSet('flow','edges','seed','restore','import','smoke','regression')][string]$Mode='flow',
 [string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
 [string]$EvidenceRoot='',
 [string]$Godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference='Stop'
if (!$EvidenceRoot) { $EvidenceRoot=Join-Path $ProjectRoot 'output/yf02' }
$EvidenceRoot=[IO.Path]::GetFullPath($EvidenceRoot)
$bin=Join-Path $EvidenceRoot 'bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
[IO.File]::WriteAllText((Join-Path $EvidenceRoot '.gdignore'),'')
$engine=Join-Path $bin 'godot.exe'
if (!(Test-Path -LiteralPath $engine)) { Copy-Item -LiteralPath $Godot -Destination $engine }
$runMode=if ($Mode -in @('import','smoke')) { $Mode } else { 'flow' }
$scene=switch ($Mode) {
 'flow' { 'res://tools/tests/yf02_flow.tscn' }
 'edges' { 'res://tools/tests/yf02_edges.tscn' }
 'seed' { 'res://tools/tests/yf02_restart.tscn' }
 'restore' { 'res://tools/tests/yf02_restart.tscn' }
 'regression' { 'res://tools/tests/guard_remove_capture.tscn' }
 default { '' }
}
$oldRestart=$env:YF02_RESTART
try {
 $env:YF02_RESTART=$Mode
 $profile=if ($Mode -in @('seed','restore')) { Join-Path $EvidenceRoot 'restart_profile' } else { '' }
 & (Join-Path $ProjectRoot 'tools/tests/combat_02_run.ps1') -Mode $runMode -ProjectRoot $ProjectRoot -OutputRoot (Join-Path $EvidenceRoot $Mode) -ProfileRoot $profile -Godot $engine -ScenePath $scene
} finally { $env:YF02_RESTART=$oldRestart }

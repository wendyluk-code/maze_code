param(
    [ValidateSet('layout','state','import','smoke','flow','restart_seed','restart_restore')][string]$Mode='flow',
    [string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$OutputRoot='',
    [string]$ProfileRoot=''
)
$ErrorActionPreference='Stop'
if (!$OutputRoot) { $OutputRoot=Join-Path $ProjectRoot ('output/combat_03/'+$Mode+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')) }
$parameters=@{ProjectRoot=$ProjectRoot;OutputRoot=$OutputRoot;ProfileRoot=$ProfileRoot}
if ($Mode -in @('import','smoke')) { $parameters.Mode=$Mode }
else {
    $parameters.Mode='flow'
    $parameters.ScenePath='res://tools/tests/combat_03_'+$(if($Mode -like 'restart_*'){'restart'}else{$Mode})+'.tscn'
}
if ($Mode -like 'restart_*') { $env:COMBAT03_PHASE=$Mode -replace 'restart_','' }
& (Join-Path $ProjectRoot 'tools/tests/combat_02_run.ps1') @parameters
exit 0

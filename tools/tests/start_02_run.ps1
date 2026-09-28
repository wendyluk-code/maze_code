param([switch]$Gui, [string]$Resolution='1152x648', [string]$Label='1152', [string]$OutputDirectory='')
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path "$PSScriptRoot/../..").Path
$output=if($OutputDirectory){$OutputDirectory}else{Join-Path $workspace 'output/start_02'}
$runRoot=Join-Path $output $(if($Gui){'isolated'}else{'isolated-'+[guid]::NewGuid().ToString('N')})
$env:MAZE_START02_ROOT=$runRoot
$env:APPDATA=Join-Path $runRoot $(if($Gui){'gui/Roaming'}else{'state/Roaming'})
$env:LOCALAPPDATA=Join-Path $runRoot $(if($Gui){'gui/Local'}else{'state/Local'})
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
function Launch($Name,$Arguments,$Visible=$false) {
 $quoted=($Arguments | ForEach-Object {'"'+$_+'"'}) -join ' '
 $style=if($Visible){'Normal'}else{'Hidden'}
 Start-Process -FilePath $godot -ArgumentList $quoted -WindowStyle $style -PassThru -RedirectStandardOutput "$output/$Name.stdout.log" -RedirectStandardError "$output/$Name.stderr.log"
}
function Wait-Case($Name,$Process){
 if(-not $Process.WaitForExit(180000)){Stop-Process -Id $Process.Id; throw "$Name 超时"}
 $Process.WaitForExit()
 $err=Get-Content "$output/$Name.stderr.log" -Raw
 if($Process.ExitCode -ne 0 -or $err -match '(?m)^(SCRIPT ERROR:|ERROR:)'){throw "$Name 失败"}
}
if($Gui){
 $p=Launch "gui-$Label" @('--path',$workspace,'--scene','res://tools/tests/start_02_suite.tscn','--rendering-method','gl_compatibility','--resolution',$Resolution,'--','--mode=gui',"--label=$Label","--report=$output/gui-$Label.json") $true
 $p.Id | Set-Content "$output/gui.pid"
 return
}
$p=Launch 'editor' @('--headless','--editor','--path',$workspace,'--quit'); Wait-Case 'editor' $p
$p=Launch 'state' @('--headless','--path',$workspace,'--scene','res://tools/tests/start_02_suite.tscn','--','--mode=state',"--report=$output/state.json"); Wait-Case 'state' $p
$p=Launch 'restart' @('--headless','--path',$workspace,'--scene','res://tools/tests/start_02_suite.tscn','--','--mode=restart',"--report=$output/restart.json")
$userDir=Get-ChildItem $env:APPDATA -Filter lock-target.txt -Recurse | Select-Object -First 1 -ExpandProperty DirectoryName
$deadline=(Get-Date).AddSeconds(20)
while(-not(Test-Path "$userDir/ready-for-lock") -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 100}
$target=Get-Content "$userDir/lock-target.txt" -Raw
$lock=[System.IO.File]::Open($target,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
try{
 Set-Content "$userDir/locked" 'locked'
 while(-not(Test-Path "$userDir/lock-done") -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 100}
} finally {$lock.Dispose()}
Wait-Case 'restart' $p
$p=Launch 'smoke' @('--headless','--path',$workspace,'--quit-after','5'); Wait-Case 'smoke' $p
Get-Content "$output/state.json","$output/restart.json" -Raw

param(
 [ValidateSet("Fresh","Resume","Check")][string]$Mode="Fresh",
 [string]$ProjectRoot=(Resolve-Path "$PSScriptRoot/../..").Path,
 [string]$Godot="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe",
 [string]$OutputRoot=""
)
$ErrorActionPreference="Stop"
if (-not $OutputRoot) { $OutputRoot=Join-Path $ProjectRoot "output/fs01/play" }
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
$profile=Join-Path $OutputRoot "profile"
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$names=@("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE","GODOT_EDITOR_CUSTOM_FEATURES")
$old=@{}
foreach ($name in $names) { $old[$name]=[Environment]::GetEnvironmentVariable($name,"Process") }
try {
 foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$profile,"Process") }
 $env:GODOT_EDITOR_CUSTOM_FEATURES=$old.GODOT_EDITOR_CUSTOM_FEATURES
 if($Mode -eq "Check") { $env:GODOT_EDITOR_CUSTOM_FEATURES=if($old.GODOT_EDITOR_CUSTOM_FEATURES){$old.GODOT_EDITOR_CUSTOM_FEATURES+",maze_automated_test"}else{"maze_automated_test"} }
 $stages=if ($Mode -eq "Check") { @("scene","warning","restart") } else { @("play") }
 foreach ($stage in $stages) {
  $arguments=@("--path",('"'+$ProjectRoot+'"'),"--resolution","1280x720","--scene","res://tools/previews/fenshui_borrow_lightning.tscn","--log-file",('"'+(Join-Path $OutputRoot "$stage.log")+'"'),"--")
  if ($Mode -eq "Resume" -or $stage -in @("warning","restart")) { $arguments+="--fs01-resume" }
  if ($stage -eq "scene") { $arguments+="--fs01-check" }
  if ($stage -in @("warning","restart")) { $arguments+="--fs01-restart-check" }
  if ($stage -eq "warning") { $arguments+="--fs01-warning-check" }
  $arguments+=@(('"--output-dir='+$OutputRoot+'"'),('"--report='+(Join-Path $OutputRoot "$stage.json")+'"'))
  $style=if ($Mode -eq "Check") { "Hidden" } else { "Normal" }
  $process=Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle $style -PassThru
  if ($Mode -eq "Check") {
   if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "验收进程超过60秒，证据保留于 $OutputRoot" }
   if ($process.ExitCode -ne 0) { throw "验收失败：$stage，退出码 $($process.ExitCode)，查看 $OutputRoot" }
  } else { Write-Output "试玩进程 $($process.Id)；独立存档 $profile" }
 }
} finally {
 foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$old[$name],"Process") }
}

param(
 [ValidateSet("unit","restart")][string]$Mode="unit",
 [string]$ProjectRoot=(Resolve-Path "$PSScriptRoot/../..").Path,
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [string]$Godot="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference="Stop"
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $OutputRoot){throw "输出目录已存在，拒绝覆盖或自动重试"}
New-Item -ItemType Directory -Force $OutputRoot | Out-Null
$profile=Join-Path $OutputRoot "profile"
$summary=@()
$phases=if($Mode -eq "restart"){@("seed","restore")}else{@("unit")}
foreach($phase in $phases){
 $row=[ordered]@{phase=$phase;started_at=(Get-Date -Format o);profile=$profile;head=(git -C $ProjectRoot rev-parse HEAD)}
 $psi=[Diagnostics.ProcessStartInfo]::new($Godot)
 $psi.UseShellExecute=$false
 $psi.CreateNoWindow=$true
 $psi.WorkingDirectory=$ProjectRoot
 foreach($key in @("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE")){$psi.Environment[$key]=$profile}
 $psi.Environment.Remove("FS01_TIMING_DIAG") | Out-Null
 $psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_automated_test"
 $args=@("--headless","--path",$ProjectRoot,"--audio-driver","Dummy","--log-file",(Join-Path $OutputRoot ($phase+".log")))
 if($Mode -eq "restart"){$args+=@("--scene","res://tools/tests/silverfish_shore_restart.tscn","--",("--phase="+$phase),("--report="+(Join-Path $OutputRoot ($phase+".json"))))}
 else{$args+=@("--script","res://tools/tests/silverfish_shore.gd")}
 foreach($arg in $args){$psi.ArgumentList.Add($arg)}
 $row.command=$args
 $p=[Diagnostics.Process]::Start($psi)
 $row.pid=$p.Id
 $row.timed_out=!$p.WaitForExit(120000)
 if($row.timed_out){$p.Kill($true);$p.WaitForExit()}
 $row.exit_code=$p.ExitCode
 $row.ended_at=Get-Date -Format o
 $row.errors=@(Select-String -LiteralPath (Join-Path $OutputRoot ($phase+".log")) -Pattern "^ERROR:","^SCRIPT ERROR:","Parse Error" | ForEach-Object {$_.Line})
 $summary+=$row
 ConvertTo-Json -InputObject $summary -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputRoot "summary.json") -Encoding utf8
 if($row.timed_out -or $row.exit_code -ne 0 -or $row.errors.Count){throw "银鳞鱼状态测试未通过，保留原日志"}
}
ConvertTo-Json -InputObject $summary -Depth 8

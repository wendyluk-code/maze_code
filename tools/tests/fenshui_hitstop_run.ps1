param(
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [string]$ScenePath="res://tools/tests/fenshui_hitstop_state.tscn",
 [string]$ScriptPath="",
 [string]$ProjectRoot="",
 [switch]$Offscreen,
 [string]$ProfileRoot="",
 [string]$Phase="",
 [ValidateSet("","gl_compatibility","forward_plus")][string]$RenderingMethod=""
)
$ErrorActionPreference="Stop"
if(-not ("HitstopWindowCheck" -as [type])){
 Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HitstopWindowCheck {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr handle, out uint processId);
 public static uint ForegroundProcess() { uint pid; GetWindowThreadProcessId(GetForegroundWindow(), out pid); return pid; }
}
"@
}
$root=if($ProjectRoot){[IO.Path]::GetFullPath($ProjectRoot)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))}
$out=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $out){throw "输出目录已存在，不覆盖原始证据"}
New-Item -ItemType Directory -Path $out | Out-Null
$profile=if($ProfileRoot){[IO.Path]::GetFullPath($ProfileRoot)}else{Join-Path $out "profile"}
New-Item -ItemType Directory -Path $profile -Force | Out-Null
$psi=[Diagnostics.ProcessStartInfo]::new("D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe")
$psi.WorkingDirectory=$root
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
foreach($name in @("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE")){$psi.Environment[$name]=$profile}
$psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_automated_test"
if($Offscreen){$psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_hitstop_screenless_test"}
$arguments=@("--path",$root,"--audio-driver","Dummy","--resolution","1280x720","--scene",$ScenePath,"--log-file",(Join-Path $out "engine.log"))
if($ScriptPath){$arguments=@("--path",$root,"--audio-driver","Dummy","--script",$ScriptPath,"--log-file",(Join-Path $out "engine.log"))}
if($RenderingMethod){$arguments+=@("--rendering-method",$RenderingMethod)}
if(-not $Offscreen){$arguments+="--headless"}
$arguments+=@("--","--fs01-check",("--report="+(Join-Path $out "report.json")),("--output-dir="+$out))
if($Phase){$arguments+="--phase=$Phase"}
foreach($argument in $arguments){$psi.ArgumentList.Add($argument)}
$summary=[ordered]@{started_at=(Get-Date -Format o);working_directory=$root;head=(git -C $root rev-parse HEAD);command=$arguments;offscreen=[bool]$Offscreen;max_seconds=120}
$p=[Diagnostics.Process]::Start($psi)
$summary.pid=$p.Id
$summary.foreground_test_pid_seen=$false
$summary.foreground_samples=0
$watch=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(50) -and $watch.Elapsed.TotalSeconds -lt 120){
 $summary.foreground_samples++
 if([HitstopWindowCheck]::ForegroundProcess() -eq $p.Id){$summary.foreground_test_pid_seen=$true}
}
$summary.timed_out=-not $p.HasExited
if($summary.timed_out){$p.Kill($true);$p.WaitForExit()}
$summary.exit_code=$p.ExitCode
$summary.ended_at=Get-Date -Format o
$summary.errors=@(Select-String -LiteralPath (Join-Path $out "engine.log") -Pattern "^ERROR:","^SCRIPT ERROR:","Parse Error" | ForEach-Object {$_.Line})
if(Test-Path -LiteralPath (Join-Path $out "report.json")){$report=Get-Content -LiteralPath (Join-Path $out "report.json") -Raw | ConvertFrom-Json -AsHashtable;$summary.checks=$report.checks;$summary.failures=$report.failures}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out "summary.json") -Encoding utf8
$summary | ConvertTo-Json -Depth 5
if($summary.timed_out -or $summary.exit_code -ne 0 -or $summary.errors.Count -gt 0 -or $summary.foreground_test_pid_seen){throw "本次验收未通过，保留原始日志"}

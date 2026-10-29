param(
 [string]$ProjectRoot=(Resolve-Path "$PSScriptRoot/../..").Path,
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [Parameter(Mandatory=$true)][string]$SourceSave,
 [string]$Godot="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe",
 [switch]$AllowPrimaryScreenForThisExperiment
)
$ErrorActionPreference="Stop"
if(!$AllowPrimaryScreenForThisExperiment){throw "必须显式传入本次诊断的主屏许可"}
$root=[IO.Path]::GetFullPath($ProjectRoot)
$out=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $out){throw "实验目录已存在，一次实验不自动重试或覆盖"}
New-Item -ItemType Directory -Force $out | Out-Null
$profile=Join-Path $out "profile"
New-Item -ItemType Directory -Force $profile | Out-Null
$before=(Get-FileHash -LiteralPath $SourceSave -Algorithm SHA256).Hash
$summary=[ordered]@{started_at=(Get-Date -Format o);head=(git -C $root rev-parse HEAD);source=$SourceSave;source_sha256_before=$before;sequence=@("free_battle_1152x648","free_battle_1280x720","skills_and_damage","success","failure","cancel","eel","legacy_replay");max_seconds=120;timing_diag_enabled=$false;working_directory=$root}
$psi=[Diagnostics.ProcessStartInfo]::new($Godot)
$psi.WorkingDirectory=$root
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.Environment["APPDATA"]=$profile
$psi.Environment["LOCALAPPDATA"]=$profile
$psi.Environment["MAZE_QTE03_PROFILE"]=$profile
$psi.Environment["FS01_DIAG_SOURCE"]=$SourceSave
$psi.Environment.Remove("FS01_TIMING_DIAG") | Out-Null
$psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_automated_test"
$args=@("--path",$root,"--audio-driver","Dummy","--screen","0","--resolution","1280x720","--scene","res://tools/tests/fenshui_trial_interaction.tscn","--log-file",(Join-Path $out "engine.log"),"--","--fs01-check",("--report="+(Join-Path $out "report.json")),("--output-dir="+$out))
foreach($arg in $args){$psi.ArgumentList.Add($arg)}
$summary.command=$args
$summary.profile=$profile
try {
 $p=[Diagnostics.Process]::Start($psi)
 $summary.pid=$p.Id
 $summary.timed_out=!$p.WaitForExit(120000)
 if($summary.timed_out){$p.Kill($true);$p.WaitForExit()}
 $summary.exit_code=$p.ExitCode
 $summary.errors=@(Select-String -LiteralPath (Join-Path $out "engine.log") -Pattern "^ERROR:","^SCRIPT ERROR:","Parse Error" | ForEach-Object {$_.Line})
 if(Test-Path -LiteralPath (Join-Path $out "report.json")){$r=Get-Content -LiteralPath (Join-Path $out "report.json") -Raw | ConvertFrom-Json -AsHashtable;$summary.checks=$r.checks;$summary.failures=$r.failures;$summary.window_protection_check=@($r.results | Where-Object {$_.label -eq "测试窗口从启动起不可聚焦、不接管桌面输入"});$summary.frame_samples=$r.frame_ms.Count;$summary.frame_max_ms=($r.frame_ms | Measure-Object -Maximum).Maximum;$summary.frame_total_ms=($r.frame_ms | Measure-Object -Sum).Sum;$summary.frame_mean_ms=($r.frame_ms | Measure-Object -Average).Average;$summary.renderer=@(Select-String -LiteralPath (Join-Path $out "engine.log") -Pattern "Vulkan.*Forward" | ForEach-Object {$_.Line})}
} finally {
 $summary.ended_at=Get-Date -Format o
 $summary.source_sha256_after=(Get-FileHash -LiteralPath $SourceSave -Algorithm SHA256).Hash
 $summary.source_unchanged=($summary.source_sha256_after -eq $before)
 $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out "summary.json") -Encoding utf8
 $summary | ConvertTo-Json -Depth 8
}
if(!$summary.source_unchanged){throw "源档发生变化，停止且不回写"}

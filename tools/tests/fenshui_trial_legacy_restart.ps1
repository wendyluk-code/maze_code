param(
 [Parameter(Mandatory=$true)][string]$SourceSave,
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [string]$ProjectRoot=(Resolve-Path "$PSScriptRoot/../..").Path,
 [string]$Godot="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference="Stop"
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $OutputRoot){throw "输出目录已存在，请指定新目录以保留旧证据"}
$profile=Join-Path $OutputRoot "profile"
$user=Join-Path $profile "Godot/app_userdata/maze_code"
New-Item -ItemType Directory -Force $user | Out-Null
$before=(Get-FileHash -LiteralPath $SourceSave -Algorithm SHA256).Hash
$save=Join-Path $user "chapter-ending-test.json"
Copy-Item -LiteralPath $SourceSave -Destination $save
$summary=[ordered]@{started_at=(Get-Date -Format o);source=$SourceSave;source_sha256_before=$before;native_focus_verified=$false;stages=@()}
$reports=@()
try{
 foreach($stage in @("first","again")){
  $inputHash=(Get-FileHash -LiteralPath $save -Algorithm SHA256).Hash
  $psi=[Diagnostics.ProcessStartInfo]::new($Godot)
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $psi.Environment["APPDATA"]=$profile
  $psi.Environment["LOCALAPPDATA"]=$profile
  $psi.Environment["MAZE_QTE03_PROFILE"]=$profile
  $psi.Environment["GODOT_EDITOR_CUSTOM_FEATURES"]="maze_automated_test"
  $report=Join-Path $OutputRoot ($stage+".json")
  $log=Join-Path $OutputRoot ($stage+".log")
  $arguments=@("--headless","--path",$ProjectRoot,"--scene","res://tools/tests/fenshui_trial_legacy_restart.tscn","--log-file",$log,"--","--fs01-resume","--fs01-check",("--report="+$report))
  foreach($arg in $arguments){$psi.ArgumentList.Add($arg)}
  $start=Get-Date -Format o
  $p=[Diagnostics.Process]::Start($psi)
  $timedOut=!$p.WaitForExit(60000)
  if($timedOut){$p.Kill($true);$p.WaitForExit()}
  $errors=@(Select-String -LiteralPath $log -Pattern "^ERROR:","^SCRIPT ERROR:","Parse Error" | ForEach-Object {$_.Line})
  $item=[ordered]@{stage=$stage;started_at=$start;ended_at=(Get-Date -Format o);pid=$p.Id;command=$arguments;exit_code=$p.ExitCode;timed_out=$timedOut;errors=$errors;input_save_sha256=$inputHash;output_save_sha256=(Get-FileHash -LiteralPath $save -Algorithm SHA256).Hash}
  if(Test-Path -LiteralPath $report){$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json;$item.checks=$r.checks;$item.failures=$r.failures;$reports+=,$r}
  $summary.stages+=,$item
  if($timedOut -or $p.ExitCode -ne 0 -or $errors.Count -or !(Test-Path -LiteralPath $report) -or $item.failures -ne 0){throw ("旧档恢复失败："+$stage+"；保留日志，不自动重试")}
 }
 $summary.second_loaded_first_save=($summary.stages[0].output_save_sha256 -eq $summary.stages[1].input_save_sha256)
 $summary.state_restored_equal=((ConvertTo-Json -InputObject $reports[0].saved_state -Depth 8 -Compress) -ceq (ConvertTo-Json -InputObject $reports[1].restored_state -Depth 8 -Compress))
 if(!$summary.second_loaded_first_save -or !$summary.state_restored_equal){throw "第二进程未精确恢复首次保存的生命、奖励或计时"}
}finally{
 $summary.source_sha256_after=(Get-FileHash -LiteralPath $SourceSave -Algorithm SHA256).Hash
 $summary.source_unchanged=($before -eq $summary.source_sha256_after)
 $summary.ended_at=Get-Date -Format o
 $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputRoot "summary.json") -Encoding utf8
 $summary | ConvertTo-Json -Depth 8
}
if(!$summary.source_unchanged){throw "源体验档发生变化，停止且不回写"}


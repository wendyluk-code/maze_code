param(
 [ValidateSet('editor','smoke','check','state','flow','persistence')][string]$Mode='state',
 [string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
 [string]$OutputRoot='',
 [string]$Scene='',
 [string]$Godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $Godot)) {throw 'Godot引擎不存在'}
if (!$OutputRoot) {$OutputRoot=Join-Path $ProjectRoot ('output/elder_01_repair/'+$Mode+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))}
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
$runtime=Join-Path $OutputRoot 'runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputRoot '.gdignore'),'')
$engine=Join-Path $runtime 'godot.exe'
Copy-Item -LiteralPath $Godot -Destination $engine
New-Item -ItemType File -Force (Join-Path $runtime '_sc_') | Out-Null
$data=Join-Path $runtime 'editor_data'
New-Item -ItemType Directory -Force $data | Out-Null
$userDir=Join-Path $OutputRoot 'profile/Godot/app_userdata/maze_code'
New-Item -ItemType Directory -Force (Join-Path $userDir 'logs') | Out-Null
@'
[gd_resource type="EditorSettings" format=3]
[resource]
filesystem/import/blender/blender_path = "F:/Blender Foundation/Blender 5.2/blender.exe"
'@ | Set-Content -Encoding utf8 (Join-Path $data 'editor_settings-4.7.tres')
$realDir=Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Fingerprints {
 $values=[ordered]@{}
 if (Test-Path -LiteralPath $realDir) {Get-ChildItem -LiteralPath $realDir -Recurse -File -Filter '*.json' | Sort-Object FullName | ForEach-Object {$values[$_.FullName]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}
 return ($values | ConvertTo-Json -Compress)
}
$before=Fingerprints
[IO.File]::WriteAllText((Join-Path $OutputRoot 'real_saves_before.json'),$before)
$results=@()
function Invoke-Case([string]$Name,[string[]]$CaseArgs) {
 $psi=[Diagnostics.ProcessStartInfo]::new($engine)
 $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
 $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
 $psi.Environment['APPDATA']=Join-Path $OutputRoot 'profile'
 $psi.Environment['LOCALAPPDATA']=Join-Path $OutputRoot 'profile'
 foreach ($a in $CaseArgs) {$psi.ArgumentList.Add($a)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;[void]$p.Start()
 $out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
 $timeout=!$p.WaitForExit(240000)
 if ($timeout) {$p.Kill($true);$p.WaitForExit()}
 $stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult()
 [IO.File]::WriteAllText((Join-Path $OutputRoot "$Name.stdout.log"),$stdout)
 [IO.File]::WriteAllText((Join-Path $OutputRoot "$Name.stderr.log"),$stderr)
 $errors=@(($stdout+"`n"+$stderr) -split "`n" | Where-Object {$_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch 'Failed to read the root certificate store'})
 $script:results += [ordered]@{name=$Name;exit_code=$p.ExitCode;timed_out=$timeout;errors=$errors;command=$CaseArgs;certificate_error=($stderr -match 'certificate');finished_at=(Get-Date -Format o)}
 if ($timeout -or $p.ExitCode -ne 0 -or $errors.Count) {throw "$Name 验收失败，见日志"}
}
try {
 $argsBase=@('--path',$ProjectRoot,'--audio-driver','Dummy','--rendering-method','gl_compatibility')
 if ($Mode -eq 'editor') {Invoke-Case 'editor' ($argsBase+@('--headless','--editor','--quit'))}
 elseif ($Mode -eq 'smoke') {Invoke-Case 'smoke' ($argsBase+@('--headless','--quit-after','5'))}
 elseif ($Mode -eq 'check') {Invoke-Case 'check' ($argsBase+@('--headless','--check-only','--script','res://tools/tests/elder_01_state.gd'))}
 elseif ($Mode -eq 'persistence') {
  foreach ($stage in @('accepted','partial','delivered')) {
   foreach ($phase in @('prepare','verify')) {
    Invoke-Case "$stage-$phase" ($argsBase+@('--headless','res://tools/tests/elder_01_persistence.tscn','--',"--stage=$stage","--phase=$phase","--isolation-root=$OutputRoot","--report=$OutputRoot/$stage-$phase.json"))
   }
  }
 } else {
  $caseArgs=$argsBase
  if ($Mode -eq 'state') {$caseArgs+= '--headless'}
  $scenePath = if ($Scene) {$Scene} else {"res://tools/tests/elder_01_$Mode.tscn"}
  $caseArgs+=@($scenePath,'--',"--isolation-root=$OutputRoot","--report=$OutputRoot/report.json","--output-dir=$OutputRoot/screenshots")
  Invoke-Case $Mode $caseArgs
 }
} finally {
 $after=Fingerprints
 [IO.File]::WriteAllText((Join-Path $OutputRoot 'real_saves_after.json'),$after)
 [ordered]@{mode=$Mode;real_saves_unchanged=($before -eq $after);expected_user_dir=$userDir;results=$results;output=$OutputRoot;finished_at=(Get-Date -Format o)} | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'execution.json')
}
if ($before -ne $after) {throw '正式存档指纹改变，验收失败'}
$OutputRoot


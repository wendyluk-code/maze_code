param([string]$OutputRoot='F:/maze_code/output/audio_editor/flow_r1', [string]$Scene='res://tools/tests/audio_editor_flow.tscn', [switch]$Headless, [int]$QuitAfter=0, [string[]]$ExtraArgs=@())
$ErrorActionPreference='Stop'
$engine='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if (!(Test-Path -LiteralPath $engine)) { throw 'Godot不存在' }
New-Item -ItemType Directory -Force $OutputRoot | Out-Null
$profile=Join-Path $OutputRoot 'profile'
New-Item -ItemType Directory -Force $profile | Out-Null
$formal=Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Get-SaveFingerprint {
 $fingerprint=@{}
 if(Test-Path -LiteralPath $formal){ Get-ChildItem -LiteralPath $formal -Recurse -File -Filter '*.json' | ForEach-Object { $fingerprint[$_.FullName]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } }
 return $fingerprint
}
$before=Get-SaveFingerprint
$psi=[Diagnostics.ProcessStartInfo]::new($engine)
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$psi.Environment['APPDATA']=$profile
$psi.Environment['LOCALAPPDATA']=$profile
$psi.Environment['MAZE_QTE03_PROFILE']=$profile
$argsList=@('--path','F:/maze_code','--rendering-method','gl_compatibility','--resolution','1152x648','--position','120,100','--log-file',"$OutputRoot/engine.log")
if($Headless){$argsList+='--headless'}
if($QuitAfter -gt 0){$argsList+=@('--quit-after',[string]$QuitAfter)}
$argsList+=@($Scene,'--',"--output-dir=$OutputRoot","--report=$OutputRoot/report.json")
$argsList+=$ExtraArgs
foreach($engineArg in $argsList){$psi.ArgumentList.Add($engineArg)}
$process=[Diagnostics.Process]::new()
$process.StartInfo=$psi
[void]$process.Start()
$outTask=$process.StandardOutput.ReadToEndAsync()
$errTask=$process.StandardError.ReadToEndAsync()
$timeout= -not $process.WaitForExit(180000)
if($timeout){$process.Kill($true);$process.WaitForExit()}
[IO.File]::WriteAllText("$OutputRoot/stdout.log",$outTask.GetAwaiter().GetResult())
[IO.File]::WriteAllText("$OutputRoot/stderr.log",$errTask.GetAwaiter().GetResult())
$after=Get-SaveFingerprint
$same=($before.Count -eq $after.Count)
foreach($key in $before.Keys){if($before[$key] -ne $after[$key]){$same=$false}}
$summary=[ordered]@{scene=$Scene;exit_code=$process.ExitCode;timeout=$timeout;formal_saves_unchanged=$same;before=$before;after=$after}
if(Test-Path "$OutputRoot/report.json"){$report=Get-Content -Raw "$OutputRoot/report.json" | ConvertFrom-Json;$summary.checks=$report.checks;$summary.failures=$report.failures}
$summary | ConvertTo-Json -Depth 8 | Set-Content "$OutputRoot/runner.json"
[pscustomobject]$summary | Select-Object scene,exit_code,timeout,formal_saves_unchanged,checks,failures | ConvertTo-Json
if($timeout -or $process.ExitCode -ne 0 -or -not $same -or ($summary.Contains('failures') -and $summary.failures -ne 0)){exit 1}

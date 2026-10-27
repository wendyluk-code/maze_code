param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$Entry,
    [Parameter(Mandatory)][string]$OutputRoot,
    [string]$ProjectRoot='F:/maze_code',
    [string]$TestPack='',
    [switch]$Headless,
    [switch]$DirectScript,
    [string[]]$ExtraArguments=@(),
    [int]$TimeoutSeconds=180
)
$ErrorActionPreference='Stop'
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force $OutputRoot,"$OutputRoot/profile","$OutputRoot/screenshots" | Out-Null
$real=Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Save-Fingerprints {
    $result=[ordered]@{}
    Get-ChildItem $real -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {$result[$_.FullName]=(Get-FileHash $_.FullName).Hash}
    return ($result | ConvertTo-Json -Compress)
}
$before=Save-Fingerprints
if($TestPack -or $DirectScript){
    $testRuntime="$OutputRoot/runtime"
    New-Item -ItemType Directory -Force $testRuntime | Out-Null
    foreach($name in @('CookingMaze.exe','CookingMaze.pck')){New-Item -ItemType HardLink -Path "$testRuntime/$name" -Target (Join-Path (Split-Path $Executable) $name) | Out-Null}
    $scriptPath=if($DirectScript){$Entry}else{"$ProjectRoot/tools/tests/package_test_bootstrap.gd"}
    $scriptPath=$scriptPath.Replace('\','/')
    @"
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="$scriptPath" id="1"]
[node name="PackageCheck" type="Node"]
script = ExtResource("1")
"@ | Set-Content -Encoding utf8 "$testRuntime/check.tscn"
    @"
[application]
run/main_scene="$($testRuntime.Replace('\','/'))/check.tscn"
"@ | Set-Content -Encoding utf8 "$testRuntime/override.cfg"
    $Executable="$testRuntime/CookingMaze.exe"
}
$psi=[Diagnostics.ProcessStartInfo]::new($Executable)
$psi.WorkingDirectory=Split-Path $Executable
$psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
$psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
foreach($key in @('APPDATA','LOCALAPPDATA','MAZE_QTE03_PROFILE','MAZE_CHECKPOINT_PROFILE')){$psi.Environment[$key]="$OutputRoot/profile"}
$psi.Environment['MAZE_TEST_PCK']=$TestPack
$psi.Environment['MAZE_TEST_ENTRY']=$Entry
$arguments=@('--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','1152x648')
if($Headless){$arguments+='--headless'}
if(!$TestPack -and !$DirectScript){$arguments+=@('--path',$ProjectRoot,$Entry)}
$arguments+=@('--',"--report=$OutputRoot/report.json","--output-dir=$OutputRoot/screenshots","--isolation-root=$OutputRoot/profile")
$arguments+=$ExtraArguments
foreach($argument in $arguments){$psi.ArgumentList.Add($argument)}
$p=[Diagnostics.Process]::Start($psi)
$out=$p.StandardOutput.ReadToEndAsync(); $err=$p.StandardError.ReadToEndAsync()
$timedOut=!$p.WaitForExit($TimeoutSeconds*1000)
if($timedOut){$p.Kill($true);$p.WaitForExit()}
$stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult()
$stdout | Set-Content -Encoding utf8 "$OutputRoot/stdout.log"
$stderr | Set-Content -Encoding utf8 "$OutputRoot/stderr.log"
$errors=@(($stdout+"`n"+$stderr) -split "`n" | Where-Object {$_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch 'Failed to read the root certificate store'})
$after=Save-Fingerprints
$before | Set-Content "$OutputRoot/real-saves-before.json"
$after | Set-Content "$OutputRoot/real-saves-after.json"
$summary=[ordered]@{entry=$Entry;executable=$Executable;arguments=$arguments;exit_code=$p.ExitCode;timed_out=$timedOut;errors=$errors;real_saves_unchanged=($before -eq $after);report_exists=(Test-Path "$OutputRoot/report.json")}
if($summary.report_exists){$r=Get-Content -Raw "$OutputRoot/report.json" | ConvertFrom-Json;$summary.checks=$r.checks;$summary.failures=$r.failures}
$summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 "$OutputRoot/summary.json"
$summary | ConvertTo-Json -Depth 8
if($timedOut -or $p.ExitCode -ne 0 -or $errors.Count -gt 0 -or $before -ne $after -or !$summary.report_exists -or $summary.failures -ne 0){throw '交互验收失败，详见日志和报告'}

param([ValidateSet("test","import","export")][string]$Step="test",[string]$Name="red",[int]$Seconds=120,[string]$Scene="res://tools/previews/rock_full_test.tscn",[string]$Kind="",[string]$ProjectPath="",[string]$Settings="")
$ErrorActionPreference="Stop"
$root=$PSScriptRoot
New-Item -ItemType Directory -Force -Path "$root/profile","$root/public" | Out-Null
$info=[Diagnostics.ProcessStartInfo]::new("D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe")
$info.UseShellExecute=$false
$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
foreach($key in @("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE","TEMP","TMP")){$info.Environment[$key]="$root/profile"}
if(!$ProjectPath){$ProjectPath="$root/stage"}
if($Settings){$info.Environment["MAZE_COMBAT_TEST_SETTINGS_FILE"]=$Settings}
$arguments=@("--headless","--path",$ProjectPath,"--log-file","$root/$Name-engine.log")
if($Step -eq "test"){$arguments+=@($Scene,"--","--report=$root/$Name.json")}
elseif($Step -eq "import"){$arguments+=@("--editor","--import")}
else{$arguments+=@("--export-debug","Web LAN","$root/public/game.html")}
if($Step -eq "test" -and $Kind){$arguments+="--arena-kind=$Kind"}
foreach($arg in $arguments){$info.ArgumentList.Add($arg)}
$start=Get-Date
$process=[Diagnostics.Process]::Start($info)
$stdout=$process.StandardOutput.ReadToEndAsync()
$stderr=$process.StandardError.ReadToEndAsync()
$timedout=-not $process.WaitForExit($Seconds*1000)
if($timedout){$process.Kill($true);$process.WaitForExit()}
$log=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
[IO.File]::WriteAllText("$root/$Name.log",$log)
$errors=@($log.Split([char]10)|Where-Object {$_ -match "^(ERROR:|SCRIPT ERROR:)"})
$result=[ordered]@{start=$start.ToString("o");end=(Get-Date -Format o);pid=$process.Id;exit=$process.ExitCode;timeout=$timedout;arguments=$arguments;errors=$errors}
$result|ConvertTo-Json -Depth 4|Set-Content "$root/$Name-execution.json" -Encoding utf8
$result|ConvertTo-Json -Depth 4
Get-Content "$root/$Name.log" -Tail 12
if($timedout -or $process.ExitCode -ne 0 -or $errors.Count){exit 1}

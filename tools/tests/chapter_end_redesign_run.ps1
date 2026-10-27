param([string]$Scene='res://tools/tests/chapter_end_redesign.tscn',[string]$Name='redesign',[switch]$Headless,[switch]$Editor)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if (!(Test-Path -LiteralPath $engine)) { throw 'Godot不存在' }
$outputPath=Join-Path $project 'output/chapter_end_redesign'
$profilePath=Join-Path $outputPath 'profile'
New-Item -ItemType Directory -Force $profilePath | Out-Null
$realDirectory=Join-Path $env:APPDATA 'Godot/app_userdata/maze_code'
function Fingerprint {
    $rows=@()
    if (Test-Path -LiteralPath $realDirectory) {
        $rows=@(Get-ChildItem -LiteralPath $realDirectory -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]logs[\\/]' } | Sort-Object FullName | ForEach-Object { @{path=$_.FullName;hash=(Get-FileHash -LiteralPath $_.FullName).Hash} })
    }
    ConvertTo-Json -InputObject $rows -Compress
}
$before=Fingerprint
$before | Set-Content (Join-Path $outputPath "$Name-formal-before.json")
$psi=[Diagnostics.ProcessStartInfo]::new($engine)
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$psi.Environment['APPDATA']=$profilePath
$psi.Environment['LOCALAPPDATA']=$profilePath
$psi.Environment['MAZE_QTE03_PROFILE']=$profilePath
$argsList=@('--path',$project,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--log-file',(Join-Path $outputPath "$Name-engine.log"))
if ($Headless) { $argsList+='--headless' }
if ($Editor) { $argsList+=@('--editor','--quit') }
elseif ($Name -eq 'startup') { $argsList+=@('--quit-after','5') }
else { $argsList+=@($Scene,'--',"--output-dir=$outputPath",('--report='+(Join-Path $outputPath "$Name-report.json"))) }
foreach ($item in $argsList) { $psi.ArgumentList.Add($item) }
$p=[Diagnostics.Process]::new(); $p.StartInfo=$psi
$null=$p.Start(); $stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
if (!$p.WaitForExit(180000)) { $p.Kill($true); throw '验收超时' }
[IO.File]::WriteAllText((Join-Path $outputPath "$Name-stdout.log"),$stdout.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $outputPath "$Name-stderr.log"),$stderr.GetAwaiter().GetResult())
$after=Fingerprint
$after | Set-Content (Join-Path $outputPath "$Name-formal-after.json")
$summary=@{exit_code=$p.ExitCode;formal_save_directory_unchanged=($before -eq $after)}
$summary | ConvertTo-Json | Set-Content (Join-Path $outputPath "$Name-runner.json")
$summary | ConvertTo-Json
if ($p.ExitCode -ne 0 -or $before -ne $after) { throw '验收失败，查看日志' }

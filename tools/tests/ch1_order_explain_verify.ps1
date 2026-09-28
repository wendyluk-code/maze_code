$ErrorActionPreference = 'Stop'
$projectRoot = 'F:/maze_code'
$evidenceRoot = "$projectRoot/output/ch1_order_explain"
$engine = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$env:APPDATA = "$evidenceRoot/profile/Roaming"
$env:LOCALAPPDATA = "$evidenceRoot/profile/Local"
$env:MAZE_QTE03_PROFILE = "$evidenceRoot/profile"
$runs = @(
    @{Name='expand_regression'; Args="--path $projectRoot --rendering-method gl_compatibility --audio-driver Dummy res://tools/tests/ch1_order_expand_input.tscn -- --output-dir=$evidenceRoot/regression --report=$evidenceRoot/expand_regression.json"},
    @{Name='editor_verified'; Args="--headless --editor --path $projectRoot --quit"},
    @{Name='scene_verified'; Args="--headless --path $projectRoot res://scenes/restaurant_map_2d.tscn --quit-after 5"}
)
$results = foreach ($run in $runs) {
    $log = "$evidenceRoot/$($run.Name).log"
    $argsWithLog = if ($run.Args.Contains(' -- ')) {
        $run.Args.Replace(' -- ', " --log-file $log -- ")
    } else { "$($run.Args) --log-file $log" }
    $process = Start-Process -FilePath $engine -ArgumentList $argsWithLog -PassThru -WindowStyle Hidden
    $timeout = if ($run.Name -eq 'expand_regression') { 120000 } else { 60000 }
    if (-not $process.WaitForExit($timeout)) {
        $process.Kill()
        throw "$($run.Name) exceeded bounded timeout"
    }
    $text = Get-Content -LiteralPath $log -Raw
    [pscustomobject]@{Name=$run.Name;ExitCode=$process.ExitCode;HasError=($text -match 'ERROR:');Log=$log}
}
$results | ConvertTo-Json | Set-Content "$evidenceRoot/verification_runs.json" -Encoding utf8
$results | Format-Table
if (@($results | Where-Object { $_.ExitCode -ne 0 -or $_.HasError }).Count -gt 0) { exit 1 }

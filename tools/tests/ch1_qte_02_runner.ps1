param(
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$OutputRoot = '',
    [switch]$ProbeOnly,
    [switch]$LifecycleOnly,
    [switch]$StateOnly,
    [switch]$EngineOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (!(Test-Path -LiteralPath $Godot)) { throw "Godot executable missing: $Godot" }
if (!$OutputRoot) { $OutputRoot = Join-Path $projectRoot ('output/ch1_qte_02/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if ((Test-Path -LiteralPath $OutputRoot) -and @(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -gt 0) { throw 'OutputRoot must be empty: reports must be created by this run' }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputRoot '.gdignore'), '')
$realSave = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code/save.json'
function Fingerprint { if (Test-Path -LiteralPath $realSave) { (Get-FileHash -LiteralPath $realSave -Algorithm SHA256).Hash } else { 'absent' } }
$before = Fingerprint
$runs = [Collections.Generic.List[object]]::new()
$completed = $false
# Godot 编辑器会重新生成元数据；保存现有字节，结束后只撤销本次导入副作用。
$metadata = @{}
foreach ($relative in @(git -C $projectRoot -c core.quotepath=false ls-files --cached --others --exclude-standard -- '*.import' '*.uid')) {
    $path = Join-Path $projectRoot $relative
    if (Test-Path -LiteralPath $path) { $metadata[$relative] = [IO.File]::ReadAllBytes($path) }
}
function Run-Godot([string]$Name, [string]$Profile, [string[]]$Arguments, [switch]$RequireReport) {
    $profilePath = Join-Path $OutputRoot ('profiles/' + $Profile)
    New-Item -ItemType Directory -Force -Path $profilePath | Out-Null
    $psi = [Diagnostics.ProcessStartInfo]::new($Godot)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['APPDATA'] = $profilePath
    $psi.Environment['LOCALAPPDATA'] = $profilePath
    $psi.Environment['MAZE_QTE02_PROFILE'] = $profilePath
    foreach ($arg in (@('--path', $projectRoot, '--audio-driver', 'Dummy') + $Arguments)) { $psi.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $null = $process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = !$process.WaitForExit(120000)
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    $outText = $stdout.GetAwaiter().GetResult()
    $errText = $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $OutputRoot "$Name.stdout.log"), $outText)
    [IO.File]::WriteAllText((Join-Path $OutputRoot "$Name.stderr.log"), $errText)
    if ($timedOut) { throw "Timeout: $Name (stdout/stderr preserved)" }
    $checks = 0; $failures = 0
    $reportPath = Join-Path $OutputRoot "$Name.json"
    if ($RequireReport) {
        if (!(Test-Path $reportPath)) { throw "Missing current report: $Name" }
        $report = Get-Content -Raw $reportPath | ConvertFrom-Json
        $checks = $report.checks; $failures = $report.failures
        if ($checks -le 0) { throw "No checks: $Name" }
    }
    $engineErrors = $outText + $errText -match '(?m)^ERROR:'
    $entry = [ordered]@{ name=$Name; pid=$process.Id; exit_code=$process.ExitCode; checks=$checks; failures=$failures; script_errors=($outText + $errText -match 'SCRIPT ERROR|Parse Error'); engine_errors=$engineErrors; arguments=$Arguments }
    $runs.Add($entry)
    Write-Host ($entry | ConvertTo-Json -Compress)
    if (!$ProbeOnly -and ($entry.exit_code -ne 0 -or $entry.script_errors -or $failures -gt 0 -or $engineErrors)) { throw "Failed: $Name" }
}
try {
    Run-Godot 'editor' 'editor' @('--headless','--editor','--quit')
    if ($EngineOnly) {
        Run-Godot 'startup' 'startup' @('--headless','--quit-after','5')
        Run-Godot 'restaurant_startup' 'restaurant_startup' @('--headless','res://scenes/restaurant_map_2d.tscn','--quit-after','5')
    }
    if ($ProbeOnly) {
        foreach ($case in @('stale','progress','quality')) { Run-Godot "probe_$case" "probe_$case" @('--headless','--script','res://tools/tests/ch1_qte_02_probe.gd','--',$case) }
    }
    if ($LifecycleOnly) {
        Run-Godot 'lifecycle' 'lifecycle' @('--rendering-method','gl_compatibility','--path',$projectRoot,'res://tools/tests/ch1_qte_02_input.tscn','--','--mode=lifecycle',"--report=$OutputRoot/lifecycle.json","--output-dir=$OutputRoot/screenshots") -RequireReport
    }
    if ($StateOnly) {
        Run-Godot 'state_unit' 'unit' @('--headless','--script','res://tools/tests/ch1_qte_02_state.gd','--','--mode=unit',"--report=$OutputRoot/state_unit.json") -RequireReport
    }
    if (!$LifecycleOnly -and !$ProbeOnly -and !$StateOnly -and !$EngineOnly) {
        Run-Godot 'startup' 'startup' @('--headless','--quit-after','5')
        Run-Godot 'restaurant_startup' 'restaurant_startup' @('--headless','res://scenes/restaurant_map_2d.tscn','--quit-after','5')
        Run-Godot 'state_unit' 'unit' @('--headless','--script','res://tools/tests/ch1_qte_02_state.gd','--','--mode=unit',"--report=$OutputRoot/state_unit.json") -RequireReport
        foreach ($sample in @('before','active','locked1','locked2','locked3','legacy','settled20','delivered1','delivered2','delivered3')) {
            Run-Godot "write_$sample" $sample @('--headless','--script','res://tools/tests/ch1_qte_02_state.gd','--','--mode=write',"--sample=$sample","--report=$OutputRoot/write_$sample.json") -RequireReport
            foreach ($iteration in @(1,2)) {
                Run-Godot "read_${sample}_$iteration" $sample @('--headless','--script','res://tools/tests/ch1_qte_02_state.gd','--','--mode=read',"--sample=$sample","--report=$OutputRoot/read_${sample}_$iteration.json") -RequireReport
            }
            if ($sample -in @('active','legacy','locked1','locked2','locked3')) {
                $quality = if ($sample.StartsWith('locked')) { $sample.Substring(6) } else { '1' }
                Run-Godot "input_$sample" $sample @('--rendering-method','gl_compatibility','res://tools/tests/ch1_qte_02_input.tscn','--','--mode=resume',"--quality=$quality","--label=$sample","--report=$OutputRoot/input_$sample.json","--output-dir=$OutputRoot/screenshots") -RequireReport
                Run-Godot "served_$sample" $sample @('--headless','--script','res://tools/tests/ch1_qte_02_state.gd','--','--mode=read',"--sample=delivered$quality","--report=$OutputRoot/served_$sample.json") -RequireReport
            }
        }
        foreach ($mode in @('failure','lifecycle')) {
            Run-Godot $mode $mode @('--rendering-method','gl_compatibility','res://tools/tests/ch1_qte_02_input.tscn','--',"--mode=$mode","--report=$OutputRoot/$mode.json","--output-dir=$OutputRoot/screenshots") -RequireReport
        }
        Run-Godot 'qte01_input' 'qte01' @('--rendering-method','gl_compatibility','res://tools/tests/ch1_qte_01_input.tscn','--',"--report=$OutputRoot/qte01_input.json","--output-dir=$OutputRoot/qte01_screenshots") -RequireReport
    }
    $completed = $true
} finally {
    foreach ($relative in @(git -C $projectRoot -c core.quotepath=false ls-files --cached --others --exclude-standard -- '*.import' '*.uid')) {
        $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
        if (!$path.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar)) { throw 'Metadata outside project' }
        if ($metadata.ContainsKey($relative)) { [IO.File]::WriteAllBytes($path, $metadata[$relative]) }
        elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    $after = Fingerprint
    $totalChecks = 0; $totalFailures = 0
    foreach ($run in $runs) { $totalChecks += $run.checks; $totalFailures += $run.failures }
    $summary = [ordered]@{ completed=$completed; checks=$totalChecks; failures=$totalFailures; real_save_before=$before; real_save_after=$after; real_save_unchanged=($before -eq $after); runs=$runs }
    $summary | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 (Join-Path $OutputRoot 'runner-summary.json')
    if ($before -ne $after) { throw 'Real save fingerprint changed' }
}

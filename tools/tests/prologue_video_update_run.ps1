param(
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$ProjectRoot = 'F:/maze_code',
    [string]$OutputRoot = '',
    [string[]]$Modes = @('mouse','old','missing','stalled','save-failure','replay','race','natural','hold-e')
)
$ErrorActionPreference = 'Stop'
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('output/prologue_video_update/tests/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if ((Test-Path -LiteralPath $OutputRoot) -and @(Get-ChildItem -LiteralPath $OutputRoot -Force).Count -gt 0) { throw 'OutputRoot must be empty' }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$realSave = Join-Path $env:APPDATA 'Godot/app_userdata/maze_code/save.json'
function Fingerprint { if (Test-Path -LiteralPath $realSave) { (Get-FileHash -LiteralPath $realSave -Algorithm SHA256).Hash } else { 'absent' } }
function SlotFingerprints {
    $directory = Join-Path (Split-Path -Parent $realSave) 'saves'
    $slots = [ordered]@{}
    if (Test-Path -LiteralPath $directory) {
        foreach ($file in Get-ChildItem -LiteralPath $directory -File | Sort-Object Name) { $slots[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    }
    return ($slots | ConvertTo-Json -Compress)
}
$before = Fingerprint
$slotsBefore = SlotFingerprints
$results = @()
foreach ($mode in $Modes) {
    $caseRoot = Join-Path $OutputRoot $mode
    $profile = Join-Path $caseRoot 'profile'
    $saveDir = Join-Path $profile 'Godot/app_userdata/maze_code'
    New-Item -ItemType Directory -Force -Path $caseRoot,$saveDir | Out-Null
    if ($mode -eq 'replay') { [IO.File]::WriteAllText((Join-Path $saveDir 'save.json'),'{"tutorial_done":false,"chapter_1_done":true,"chapter_1_intro":"guest_arrived","reputation":77,"sentinel":"formal-save-do-not-touch"}') }
    $report = Join-Path $caseRoot 'acceptance.json'
    $psi = [Diagnostics.ProcessStartInfo]::new($Godot)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['APPDATA'] = $profile
    $psi.Environment['LOCALAPPDATA'] = $profile
    $psi.Environment['MAZE_PRO_01_ISOLATED'] = '1'
    $resolution = if ($mode -eq 'natural') { '1152x648' } else { '1280x720' }
    $arguments = @('--path',$ProjectRoot,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution',$resolution,'--scene','res://tools/tests/pro_01_suite.tscn','--',"--mode=$mode","--report=$report","--output-dir=$caseRoot","--isolation-root=$profile")
    if ($mode -eq 'replay') { $arguments += '--replay-prologue' }
    foreach ($argument in $arguments) { $psi.ArgumentList.Add([string]$argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $psi; $null = $process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = !$process.WaitForExit($(if ($mode -in @('natural','hold-e')) { 360000 } else { 45000 }))
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    $stdout = $stdoutTask.GetAwaiter().GetResult(); $stderr = $stderrTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $caseRoot 'stdout.log'),$stdout)
    [IO.File]::WriteAllText((Join-Path $caseRoot 'stderr.log'),$stderr)
    $errors = @(($stdout + "`n" + $stderr) -split "`r?`n" | Where-Object { $_ -match '^(ERROR:|SCRIPT ERROR:|.*Parse Error:)' })
    $environmentErrors = @($errors | Where-Object { $_ -match 'Failed to get system certificates|Failed to read the root certificate store|Cannot open file.*editor_settings|Error saving editor settings' })
    $unexpected = @($errors | Where-Object { $_ -notin $environmentErrors })
    $result = [ordered]@{ mode=$mode; resolution=$resolution; exit_code=$process.ExitCode; timed_out=$timedOut; report_exists=(Test-Path -LiteralPath $report); environment_errors=$environmentErrors; unexpected_errors=$unexpected }
    if (Test-Path -LiteralPath $report) { $r=Get-Content -Raw -LiteralPath $report | ConvertFrom-Json; $result.checks=$r.checks.Count; $result.failures=$r.failures }
    $result.passed = !$timedOut -and $result.report_exists -and $result.checks -gt 0 -and $result.failures -eq 0 -and $process.ExitCode -eq 0 -and $unexpected.Count -eq 0
    $results += $result
    Write-Output ($result | ConvertTo-Json -Compress -Depth 6)
    if (!$result.passed) { break }
}
$after = Fingerprint
$slotsAfter = SlotFingerprints
$unchanged = $before -eq $after -and $slotsBefore -eq $slotsAfter
$summary = [ordered]@{ results=$results; real_save_before=$before; real_save_after=$after; real_slots_before=$slotsBefore; real_slots_after=$slotsAfter; real_save_unchanged=$unchanged; passed=($results.Count -eq $Modes.Count -and @($results | Where-Object {!$_.passed}).Count -eq 0 -and $unchanged) }
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $OutputRoot 'runner-summary.json') -Encoding utf8
if (!$summary.passed) { throw 'Prologue verification failed; inspect runner-summary.json and per-case logs' }

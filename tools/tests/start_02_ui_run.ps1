[CmdletBinding()]
param([string[]]$Modes = @('visual-manage-1152','visual-manage-1280'), [switch]$Import, [string]$OutputDirectory='')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$godot = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot 不存在' }
$output = if($OutputDirectory){$OutputDirectory}else{Join-Path $workspace 'output/start_02/ui'}
$runRoot = Join-Path $env:TEMP ('maze_start01_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $output,$runRoot | Out-Null
$savedRoaming = $env:APPDATA
$savedLocal = $env:LOCALAPPDATA
$savedIsolation = $env:MAZE_START01_ROOT
$savedPrologue = $env:MAZE_PRO_01_ISOLATED
$savedLifecycleReport = $env:CH1_11_REPORT
$results = @()
function Invoke-Case([string]$Name, [string[]]$Arguments) {
    $quoted = ($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $process = Start-Process -FilePath $godot -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $output "$Name.stdout.log") -RedirectStandardError (Join-Path $output "$Name.stderr.log")
    if (-not $process.WaitForExit(180000)) { Stop-Process -Id $process.Id; throw "$Name 超时，已停止本次进程" }
    $process.WaitForExit()
    $stderr = [string](Get-Content -LiteralPath (Join-Path $output "$Name.stderr.log") -Raw)
    $passed = $process.ExitCode -eq 0 -and $stderr -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)'
    $script:results += [ordered]@{mode=$Name; passed=$passed; exit_code=$process.ExitCode}
    if (-not $passed) { throw "$Name 失败，见 stdout/stderr 日志" }
}
try {
    $env:MAZE_START01_ROOT = $runRoot
    $env:MAZE_PRO_01_ISOLATED = '1'
    foreach ($mode in @('setup') + $Modes) {
        $caseName = if ($mode -eq 'restart') { 'state' } else { $mode }
        $env:APPDATA = Join-Path $runRoot "$caseName/Roaming"
        $env:LOCALAPPDATA = Join-Path $runRoot "$caseName/Local"
        New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        if ($mode -eq 'setup') {
            if ($Import) { Invoke-Case 'editor' @('--headless','--editor','--path',$workspace,'--quit') }
            Invoke-Case 'smoke' @('--headless','--path',$workspace,'--quit-after','5')
            continue
        }
        $arguments = @('--path',$workspace,'--scene','res://tools/tests/start_02_ui.tscn')
        $caseMode = $mode
        if ($mode.Contains('prologue-')) {
            $caseMode = $mode.Substring($mode.IndexOf('prologue-') + 9)
            $arguments = @('--path',$workspace,'--scene','res://tools/tests/start_01_prologue_regression.tscn')
        }
        if ($mode -eq 'lifecycle') {
            $arguments = @('--path',$workspace,'--scene','res://tools/tests/ch1_11_lifecycle_suite.tscn')
            $env:CH1_11_REPORT = Join-Path $output 'lifecycle.json'
        }
        if ($mode.StartsWith('visual')) { $arguments += @('--rendering-method','gl_compatibility','--resolution',$(if ($mode.EndsWith('1152')) {'1152x648'} else {'1280x720'})) }
        else { $arguments = @('--headless') + $arguments }
        $arguments += @('--',"--mode=$caseMode","--report=$output/$mode.json","--output-dir=$output","--isolation-root=$runRoot")
        if ($mode.Contains('prologue-replay')) { $arguments += '--replay-prologue' }
        Invoke-Case $mode $arguments
    }
} finally {
    $env:APPDATA = $savedRoaming
    $env:LOCALAPPDATA = $savedLocal
    $env:MAZE_START01_ROOT = $savedIsolation
    $env:MAZE_PRO_01_ISOLATED = $savedPrologue
    $env:CH1_11_REPORT = $savedLifecycleReport
    [ordered]@{results=$results; isolated_root=$runRoot} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'latest-run.json') -Encoding utf8
}
$results | Format-Table

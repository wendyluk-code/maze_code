[CmdletBinding()]
param(
    [string]$GodotPath = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$OutputDir = '',
    [string[]]$Modes = @(),
    [switch]$Visual,
    [switch]$Import
)
$ErrorActionPreference = 'Stop'
if ($Modes.Count -eq 0) {
    $Modes = if ($Visual) { @('mouse','esc','space','enter','race','old','missing','stalled','save-failure','replay','natural') } else { @('migration','atomic') }
}
if (-not $Visual -and @($Modes | Where-Object { $_ -notin @('migration','atomic') }).Count -gt 0) {
    throw '播放/鼠标/场景验收必须指定 -Visual；无头模式只运行存档契约和解析/冒烟检查'
}
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) { throw '找不到 Godot 可执行文件' }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('maze_pro_01_' + [guid]::NewGuid().ToString('N'))
if (-not $OutputDir) { $OutputDir = Join-Path $runRoot 'reports' }
New-Item -ItemType Directory -Force -Path $runRoot,$OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
function Get-SaveFingerprint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'absent' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Invoke-Godot([string]$Name, [string[]]$Arguments, [int]$Timeout = 120000) {
    $quoted = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $windowStyle = if ($Visual -and $Name -in $Modes) { 'Normal' } else { 'Hidden' }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -WindowStyle $windowStyle -PassThru `
        -RedirectStandardOutput (Join-Path $OutputDir "$Name.stdout.txt") `
        -RedirectStandardError (Join-Path $OutputDir "$Name.stderr.txt")
    if (-not $process.WaitForExit($Timeout)) {
        Stop-Process -Id $process.Id
        throw "$Name 超时 $Timeout 毫秒，已停止该隔离进程"
    }
    $process.WaitForExit()
    $errors = Get-Content -LiteralPath (Join-Path $OutputDir "$Name.stderr.txt") -Raw
    if ($errors -match '(?m)^(SCRIPT ERROR:|ERROR:)') { return 1 }
    return $process.ExitCode
}
$realSave = Join-Path $env:APPDATA 'Godot\app_userdata\maze_code\save.json'
$before = Get-SaveFingerprint $realSave
$oldRoaming = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
$oldFlag = $env:MAZE_PRO_01_ISOLATED
$results = @()
$failure = ''
try {
    $env:MAZE_PRO_01_ISOLATED = '1'
    foreach ($mode in @('setup') + $Modes) {
        $caseRoot = Join-Path $runRoot $mode
        $env:APPDATA = Join-Path $caseRoot 'Roaming'
        $env:LOCALAPPDATA = Join-Path $caseRoot 'Local'
        $saveDir = Join-Path $env:APPDATA 'Godot\app_userdata\maze_code'
        New-Item -ItemType Directory -Force -Path $saveDir,$env:LOCALAPPDATA | Out-Null
        if ($mode -eq 'setup') {
            $code = Invoke-Godot 'version' @('--version')
            $version = (Get-Content (Join-Path $OutputDir 'version.stdout.txt') -Raw).Trim()
            if ($code -ne 0 -or $version -notmatch '^4\.7\.2') { throw "需要 Godot 4.7.2，当前为 $version" }
            if ($Import) {
                $code = Invoke-Godot 'editor-parse' @('--headless','--editor','--path',$workspace,'--quit')
                $results += [ordered]@{mode='editor-parse'; passed=($code -eq 0); exit_code=$code}
                if ($code -ne 0) { throw '编辑器解析失败，见日志' }
            }
            $code = Invoke-Godot 'runtime-smoke' @('--headless','--path',$workspace,'--quit-after','5')
            $results += [ordered]@{mode='runtime-smoke'; passed=($code -eq 0); exit_code=$code}
            if ($code -ne 0) { throw '运行冒烟失败，见日志' }
            continue
        }
        if ($mode -eq 'replay') {
            '{"tutorial_done":false,"chapter_1_done":true,"chapter_1_intro":"guest_arrived","reputation":77,"sentinel":"formal-save-do-not-touch"}' | Set-Content -LiteralPath (Join-Path $saveDir 'save.json') -Encoding UTF8
        }
        $report = Join-Path $OutputDir "$mode.json"
        $arguments = @('--path',$workspace,'--resolution','1280x720','--scene','res://tools/tests/pro_01_suite.tscn')
        if (-not $Visual) { $arguments = @('--headless') + $arguments }
        $arguments += @('--',"--mode=$mode","--isolation-root=$caseRoot","--report=$report","--output-dir=$OutputDir")
        if ($mode -eq 'replay') { $arguments += '--replay-prologue' }
        $code = Invoke-Godot $mode $arguments $(if ($mode -in @('natural','manual')) { 360000 } else { 120000 })
        $passed = $false
        if (Test-Path -LiteralPath $report) {
            $details = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
            $passed = $code -eq 0 -and $details.failures -eq 0 -and $details.checks.Count -gt 0
        }
        $results += [ordered]@{mode=$mode; passed=$passed; exit_code=$code; report=$report}
        if (-not $passed) { throw "$mode 失败，见报告" }
    }
} catch {
    $failure = $_.Exception.Message
} finally {
    $env:APPDATA = $oldRoaming
    $env:LOCALAPPDATA = $oldLocal
    $env:MAZE_PRO_01_ISOLATED = $oldFlag
}
$after = Get-SaveFingerprint $realSave
$passed = -not $failure -and $before -eq $after -and @($results | Where-Object { -not $_.passed }).Count -eq 0
$summary = [ordered]@{ticket='PRO-01'; passed=$passed; error=$failure; godot_version=$version; visual=[bool]$Visual
    workspace=$workspace; isolated_root=$runRoot; real_save_unchanged=($before -eq $after)
    real_save_before=$before; real_save_after=$after; results=$results}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDir 'summary.json') -Encoding UTF8
Write-Output ($summary | ConvertTo-Json -Depth 8)
exit $(if ($passed) { 0 } else { 1 })

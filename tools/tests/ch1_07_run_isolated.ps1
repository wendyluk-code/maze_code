[CmdletBinding()]
param(
    [string]$GodotPath = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [string]$OutputDir = '',
    [switch]$Visual,
    [switch]$Import
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) { throw '找不到 Godot 可执行文件' }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('maze_ch1_07_' + [guid]::NewGuid().ToString('N'))
$roaming = Join-Path $runRoot 'Roaming'
$localData = Join-Path $runRoot 'Local'
if (-not $OutputDir) { $OutputDir = Join-Path $runRoot 'reports' }
New-Item -ItemType Directory -Force -Path $roaming,$localData,$OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
function Get-SaveFingerprint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'absent' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Invoke-Godot([string]$Name, [string[]]$Arguments) {
    # Start-Process 的参数字符串需显式引用路径，兼容含空格的项目与输出目录。
    $quoted = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $OutputDir "$Name.stdout.txt") `
        -RedirectStandardError (Join-Path $OutputDir "$Name.stderr.txt")
    if (-not $process.WaitForExit(120000)) {
        Stop-Process -Id $process.Id
        throw "$Name 超过 120 秒，已停止该验收进程"
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
$oldFlag = $env:MAZE_CH1_07_ISOLATED
$results = @()
try {
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $localData
    $env:MAZE_CH1_07_ISOLATED = '1'
    if ($Import) {
        $code = Invoke-Godot 'editor-import' @('--headless','--editor','--path',$workspace,'--quit')
        if ($code -ne 0) { throw "编辑器导入失败：$code" }
    }
    foreach ($mode in @('flow','resume_cook','resume_deliver')) {
        $report = Join-Path $OutputDir "$mode.json"
        $arguments = @('--path',$workspace,'--scene','res://tools/tests/ch1_07_cooking_suite.tscn')
        if (-not $Visual) { $arguments = @('--headless') + $arguments }
        $arguments += @('--',"--mode=$mode","--isolation-root=$runRoot","--report=$report","--output-dir=$OutputDir")
        $code = Invoke-Godot $mode $arguments
        $passed = $false
        if (Test-Path -LiteralPath $report) {
            $details = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
            $passed = $code -eq 0 -and $details.failures -eq 0 -and $details.checks.Count -gt 0
        }
        $results += [ordered]@{ mode=$mode; exit_code=$code; passed=$passed; report=$report }
        if (-not $passed) { break }
    }
    # 最低主入口冒烟检查同样使用隔离存档。
    $code = Invoke-Godot 'main-smoke' @('--headless','--path',$workspace,'--quit-after','5')
    $results += [ordered]@{ mode='main-smoke'; exit_code=$code; passed=($code -eq 0) }
} finally {
    $env:APPDATA = $oldRoaming
    $env:LOCALAPPDATA = $oldLocal
    $env:MAZE_CH1_07_ISOLATED = $oldFlag
}
$after = Get-SaveFingerprint $realSave
$passed = $results.Count -eq 4 -and @($results | Where-Object { -not $_.passed }).Count -eq 0 -and $before -eq $after
$summary = [ordered]@{
    ticket='CH1-07'; passed=$passed; visual=[bool]$Visual; workspace=$workspace; isolated_root=$runRoot
    real_save_unchanged=($before -eq $after); real_save_before=$before; real_save_after=$after; results=$results
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDir 'summary.json') -Encoding UTF8
Write-Output ($summary | ConvertTo-Json -Depth 8)
exit $(if ($passed) { 0 } else { 1 })

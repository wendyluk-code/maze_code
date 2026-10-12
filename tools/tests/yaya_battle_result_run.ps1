[CmdletBinding()]
param([string[]]$Modes = @('flow','menu','navigation'), [switch]$Import)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$sourceGodot = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $sourceGodot)) { throw 'Godot 不存在' }
$output = Join-Path $workspace ('output/br01/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$runtime = Join-Path $output 'runtime'
New-Item -ItemType Directory -Force $output,$runtime | Out-Null
# 便携引擎的用户路径可能忽略 APPDATA；复制自包含引擎并启用隔离便携目录。
$godot = Join-Path $runtime 'godot.exe'
Copy-Item -LiteralPath $sourceGodot -Destination $godot
New-Item -ItemType File -Path (Join-Path $runtime '_sc_') | Out-Null
$savedRoaming = $env:APPDATA
$savedLocal = $env:LOCALAPPDATA
$results = @()
function Invoke-Case([string]$Name, [string[]]$Arguments) {
    $quoted = ($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $process = Start-Process -FilePath $godot -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $output "$Name.stdout.log") -RedirectStandardError (Join-Path $output "$Name.stderr.log")
    if (-not $process.WaitForExit(240000)) { Stop-Process -Id $process.Id; throw "$Name 超时，已停止本次进程" }
    $process.WaitForExit()
    $stderr = [string](Get-Content -LiteralPath (Join-Path $output "$Name.stderr.log") -Raw)
    # 沙箱证书读取失败单独披露；任何脚本、资源及其他错误使本次验收失败。
    $actionable = $stderr -replace '(?m)^ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates[^\r\n]*\r?\n',''
    $passed = $process.ExitCode -eq 0 -and $actionable -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)'
    $script:results += [ordered]@{mode=$Name; passed=$passed; exit_code=$process.ExitCode; finished_at=(Get-Date -Format o); certificate_error=($stderr -match 'root certificate store')}
    if (-not $passed) { throw "$Name 失败，见 stdout/stderr 日志" }
}
try {
    $env:APPDATA = Join-Path $output 'profile/Roaming'
    $env:LOCALAPPDATA = Join-Path $output 'profile/Local'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    if ($Import) { Invoke-Case 'editor' @('--headless','--editor','--path',$workspace,'--quit') }
    Invoke-Case 'smoke' @('--headless','--path',$workspace,'--quit-after','5')
    foreach ($mode in $Modes) {
        $scene = switch ($mode) { 'flow' {'yaya_battle_result_input'} 'menu' {'yaya_battle_menu_input'} 'navigation' {'yaya_battle_input'} 'battle' {'yaya_battle_input'} default {throw '未知验收模式'} }
        $arguments = @('--path',$workspace,'--scene',"res://tools/tests/$scene.tscn",'--rendering-method','gl_compatibility','--resolution','1280x720','--',"--output-dir=$output/$mode")
        if ($mode -eq 'navigation') { $arguments += '--navigation-only' }
        Invoke-Case $mode $arguments
    }
} finally {
    $env:APPDATA = $savedRoaming
    $env:LOCALAPPDATA = $savedLocal
    [ordered]@{finished_at=(Get-Date -Format o); results=$results; isolated_runtime=$runtime; output=$output} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'execution.json') -Encoding utf8
}
$results | Format-Table
Write-Output $output

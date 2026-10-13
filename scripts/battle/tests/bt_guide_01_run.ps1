param([ValidateSet('editor','smoke','scene','lifecycle','cancel','display','demo')][string]$Mode = 'scene', [switch]$Small, [string]$ImportCache = '')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$output = Join-Path $workspace 'output/bt_guide_01'
$sourceGodot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $sourceGodot)) { throw 'Godot 引擎不存在' }
$runtime = Join-Path $output 'runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
$godot = Join-Path $runtime 'godot.exe'
if (-not (Test-Path -LiteralPath $godot)) { Copy-Item -LiteralPath $sourceGodot -Destination $godot }
New-Item -ItemType File -Force (Join-Path $runtime '_sc_'),(Join-Path $output '.gdignore') | Out-Null
$savedRoaming = $env:APPDATA
$savedLocal = $env:LOCALAPPDATA
$results = @()
# 全新工作树可只读复用同一基线的导入缓存；不会修改来源目录。
if ($ImportCache) {
    $cacheSource = (Resolve-Path -LiteralPath $ImportCache).Path
    $cacheTarget = Join-Path $workspace '.godot/imported'
    New-Item -ItemType Directory -Force $cacheTarget | Out-Null
    Get-ChildItem -LiteralPath $cacheSource -File | Copy-Item -Destination $cacheTarget
}
function Invoke-Check([string]$name, [string[]]$arguments) {
    $quoted = ($arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $stdout = Join-Path $output "$name.stdout.log"
    $stderr = Join-Path $output "$name.stderr.log"
    $process = Start-Process -FilePath $godot -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(240000)) { Stop-Process -Id $process.Id; throw "$name 超时，已停止本次进程" }
    $process.WaitForExit()
    $errors = [string](Get-Content -LiteralPath $stderr -Raw)
    $actionable = $errors -replace '(?m)^ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates[^\r\n]*\r?\n',''
    $passed = $process.ExitCode -eq 0 -and $actionable -notmatch '(?m)^(SCRIPT ERROR:|ERROR:)'
    $script:results += [ordered]@{name=$name; passed=$passed; exit_code=$process.ExitCode; finished_at=(Get-Date -Format o); certificate_error=($errors -match 'root certificate store')}
    if (-not $passed) { throw "$name 失败，检查 stdout/stderr 日志" }
}
try {
    $env:APPDATA = Join-Path $output 'profile/Roaming'
    $env:LOCALAPPDATA = Join-Path $output 'profile/Local'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA,(Join-Path $workspace 'output/bt_ui_02'),(Join-Path $workspace 'output/bt_fx_01'),(Join-Path $workspace 'output/card_display_02') | Out-Null
    $width = if ($Small) { '1152' } else { '1280' }
    $resolution = if ($Small) { '1152x648' } else { '1280x720' }
    if ($Mode -eq 'editor') { Invoke-Check 'editor' @('--headless','--editor','--path',$workspace,'--quit') }
    elseif ($Mode -eq 'smoke') { Invoke-Check 'smoke' @('--headless','--path',$workspace,'--quit-after','5') }
    else {
        $suite = switch ($Mode) {
            'scene' { 'bt_guide_01_scene_suite.gd' }
            'lifecycle' { 'bt_guide_01_lifecycle_suite.gd' }
            'cancel' { 'bt_fx_01_cancel_suite.gd' }
            'display' { 'card_display_scene_suite.gd' }
            'demo' { 'bt_ui_02_demo_suite.gd' }
        }
        $arguments = @('--path',$workspace,'--script',"res://scripts/battle/tests/$suite",'--rendering-method','gl_compatibility','--resolution',$resolution)
        if ($Small) { $arguments += @('--','small') }
        Invoke-Check "${Mode}_${width}" $arguments
    }
} finally {
    $env:APPDATA = $savedRoaming
    $env:LOCALAPPDATA = $savedLocal
    $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output "${Mode}_${width}_execution.json") -Encoding utf8
}
$results | Format-Table

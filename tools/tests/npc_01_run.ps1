param([ValidateSet('state','scene','editor','startup')][string]$Mode='state', [switch]$Small, [switch]$SkipBlenderFor2D)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidenceRoot = Join-Path $projectRoot 'output/npc_01'
$runtimeRoot = Join-Path $evidenceRoot 'runtime'
New-Item -ItemType Directory -Force $runtimeRoot | Out-Null
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'output/day1_03') | Out-Null
$engine = Join-Path $runtimeRoot 'godot.exe'
if (-not (Test-Path $engine)) {
    Copy-Item -LiteralPath 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -Destination $engine
    New-Item -ItemType File -Force (Join-Path $runtimeRoot '_sc_') | Out-Null
}
$oldAppData = $env:APPDATA
$formalSaveRoot = Join-Path $oldAppData 'Godot/app_userdata/maze_code'
function Get-FormalSaveFingerprint {
    if (-not (Test-Path -LiteralPath $formalSaveRoot)) { return 'absent' }
    return ((Get-ChildItem -LiteralPath $formalSaveRoot -Filter '*.json' -File -Recurse |
        Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join "`n")
}
$formalBefore = Get-FormalSaveFingerprint
$configPath = Join-Path $projectRoot 'project.godot'
$originalConfig = [System.IO.File]::ReadAllBytes($configPath)
$configHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
try {
    if ($SkipBlenderFor2D) {
        $textConfig = [System.Text.Encoding]::UTF8.GetString($originalConfig)
        if ($textConfig -match '\[filesystem\]') { throw '已有filesystem设置，拒绝自动覆盖' }
        [System.IO.File]::WriteAllText($configPath, $textConfig + "`n[filesystem]`n`nimport/blender/enabled=false`n", [System.Text.UTF8Encoding]::new($false))
    }
    $env:APPDATA = Join-Path $evidenceRoot 'profile'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $suffix = if ($Small) {'1152'} else {'1280'}
    $log = Join-Path $evidenceRoot ($Mode + $suffix + '.log')
    $arguments = @('--path', $projectRoot, '--log-file', $log)
    switch ($Mode) {
        'editor' { $arguments += @('--headless','--import') }
        'startup' { $arguments += @('--headless','--quit-after','5') }
        'state' { $arguments += @('--headless','res://tools/tests/day1_customers.tscn','--quit-after','300') }
        'scene' {
            $resolution = if ($Small) {'1152x648'} else {'1280x720'}
            $arguments += @('--rendering-method','gl_compatibility','--resolution',$resolution,'res://tools/tests/npc_01_scene.tscn','--max-fps','60')
        }
    }
    $quotedArguments = $arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $engine -ArgumentList $quotedArguments -WindowStyle Hidden -PassThru
    $timeout = if ($Mode -eq 'editor') {180000} else {90000}
    if (-not $process.WaitForExit($timeout)) { $process.Kill(); throw '验收进程超过有界时限，已停止' }
    $result = Get-Content -LiteralPath $log -Raw
    if ($process.ExitCode -ne 0 -or $result -match 'SCRIPT ERROR|Parse Error|FAIL |素材缺失|Failed loading resource|Failed to load script|has no resource loaders') { throw "验收错误，见 $log" }
    if ($Mode -in @('state','scene') -and $result -notmatch 'RESULT checks=\d+ failures=0') { throw "缺少成功报告，见 $log" }
    Write-Output "DAY1 $Mode 已通过：$log"
} finally {
    $env:APPDATA = $oldAppData
    if ($SkipBlenderFor2D) { [System.IO.File]::WriteAllBytes($configPath, $originalConfig) }
    $afterHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
    if ($afterHash -ne $configHash) { throw 'project.godot恢复校验失败' }
    Write-Output "project.godot SHA256恢复一致：$afterHash"
    $formalAfter = Get-FormalSaveFingerprint
    if ($formalBefore -ne $formalAfter) { throw '正式JSON存档指纹发生变化' }
    Write-Output '正式JSON存档指纹前后一致'
}

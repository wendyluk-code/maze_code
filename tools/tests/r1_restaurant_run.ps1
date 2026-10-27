param([ValidateSet('state','scene','editor','startup')][string]$Mode='state', [switch]$Small)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidenceRoot = Join-Path $projectRoot 'output/r1'
$runtimeRoot = Join-Path $evidenceRoot 'runtime'
New-Item -ItemType Directory -Force $runtimeRoot | Out-Null
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'output/day1_03') | Out-Null
$engine = Join-Path $runtimeRoot 'godot.exe'
if (-not (Test-Path $engine)) {
    Copy-Item -LiteralPath 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -Destination $engine
    New-Item -ItemType File -Force (Join-Path $runtimeRoot '_sc_') | Out-Null
}
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $evidenceRoot 'profile'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $suffix = if ($Small) {'1152'} else {'1280'}
    $log = Join-Path $evidenceRoot ($Mode + $suffix + '.log')
    $arguments = @('--path', $projectRoot, '--log-file', $log)
    switch ($Mode) {
        'editor' { $arguments += @('--headless','--editor','--quit') }
        'startup' { $arguments += @('--headless','--quit-after','5') }
        'state' { $arguments += @('--headless','res://tools/tests/day1_customers.tscn','--quit-after','300') }
        'scene' {
            $resolution = if ($Small) {'1152x648'} else {'1280x720'}
            $arguments += @('--rendering-method','gl_compatibility','--resolution',$resolution,'res://tools/tests/r1_restaurant_scene.tscn','--max-fps','60')
        }
    }
    $quotedArguments = $arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $engine -ArgumentList $quotedArguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw '验收进程超过60秒，已停止' }
    $result = Get-Content -LiteralPath $log -Raw
    if ($process.ExitCode -ne 0 -or $result -match 'SCRIPT ERROR|Parse Error|FAIL |素材缺失|Failed loading resource|Failed to load script|has no resource loaders') { throw "验收错误，见 $log" }
    if ($Mode -in @('state','scene') -and $result -notmatch 'RESULT checks=\d+ failures=0') { throw "缺少成功报告，见 $log" }
    Write-Output "R1 $Mode 已通过：$log"
} finally {
    $env:APPDATA = $oldAppData
}


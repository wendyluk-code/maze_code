param([string]$OutputDir = 'F:\maze_code\output\ch1_dialog_identity')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$engine = 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw '找不到 Godot 可执行文件' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$runs = @()
foreach ($size in @('1152x648', '1280x720')) {
    $caseDir = Join-Path $OutputDir $size
    $profile = Join-Path $caseDir 'profile'
    New-Item -ItemType Directory -Force -Path $caseDir,(Join-Path $profile 'Roaming'),(Join-Path $profile 'Local') | Out-Null
    $roamingBefore = $env:APPDATA
    $localBefore = $env:LOCALAPPDATA
    try {
        $env:APPDATA = Join-Path $profile 'Roaming'
        $env:LOCALAPPDATA = Join-Path $profile 'Local'
        $width = $size.Split('x')[0]
        $arguments = @('--path', $projectRoot, '--rendering-method', 'gl_compatibility',
            '--audio-driver', 'Dummy', '--resolution', $size,
            '--script', 'res://tools/tests/ch1_dialog_identity.gd', '--',
            "--output-dir=$caseDir", "--isolation-root=$profile", "--width=$width")
        $quoted = ($arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
        $process = Start-Process -FilePath $engine -ArgumentList $quoted -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $caseDir 'stdout.log') `
            -RedirectStandardError (Join-Path $caseDir 'stderr.log')
        if (-not $process.WaitForExit(120000)) {
            Stop-Process -Id $process.Id
            throw "$size 对话验收超时 120 秒"
        }
        $process.WaitForExit()
        $reportPath = Join-Path $caseDir 'report.json'
        $report = if (Test-Path -LiteralPath $reportPath) { Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json } else { $null }
        $errors = Get-Content -LiteralPath (Join-Path $caseDir 'stderr.log') -Raw
        $scriptErrors = $errors -match '(?m)^(SCRIPT ERROR:|ERROR: (?!Failed to read the root certificate store))'
        $passed = $process.ExitCode -eq 0 -and $null -ne $report -and $report.failures.Count -eq 0 -and -not $scriptErrors
        $runs += [pscustomobject]@{ Size=$size; Passed=$passed; ExitCode=$process.ExitCode; Checks=$report.checks.Count; Report=$reportPath; ScriptErrors=$scriptErrors }
    } finally {
        $env:APPDATA = $roamingBefore
        $env:LOCALAPPDATA = $localBefore
    }
}
$runs | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDir 'runs.json') -Encoding UTF8
$runs | Format-Table -AutoSize
if (@($runs | Where-Object { -not $_.Passed }).Count -gt 0) { exit 1 }

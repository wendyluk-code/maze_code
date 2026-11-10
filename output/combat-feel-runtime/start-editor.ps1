param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$url = 'http://127.0.0.1:8777/'
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$server = Join-Path $PSScriptRoot 'serve.cjs'
$entry = Join-Path $project 'output/combat-feel-playground/preview.html'
function Test-Editor {
    try {
        $identity = Invoke-RestMethod -Uri ($url+'editor-instance.json') -TimeoutSec 2
        if ($identity.editor -ne 'maze-combat-editor' -or $identity.workspace -ne $project) { return $false }
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        return $response.StatusCode -eq 200 -and $response.Content.Contains('料理迷宫 · 统一对打编辑器') -and $response.Content.Contains('editor-core.js')
    } catch { return $false }
}
try {
    if (!(Test-Path -LiteralPath $server) -or !(Test-Path -LiteralPath $entry)) {
        throw '缺少本工作区的编辑器文件，请保留 output/combat-feel-runtime 和 combat-feel-playground。'
    }
    $listener = @(Get-NetTCPConnection -LocalPort 8777 -State Listen -ErrorAction SilentlyContinue)
    if ($listener.Count -gt 0) {
        if (!(Test-Editor)) { throw '8777已被其他服务占用或编辑器无响应。未关闭任何进程，请先核对端口归属。' }
        Write-Host '8777编辑器已运行，复用现有服务。'
    } else {
        $node = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $nodePath = if ($node) { $node.Source } else { $null }
        if (!$nodePath) {
            foreach ($candidate in @('C:/Program Files/nodejs/node.exe','C:/nvm4w/nodejs/node.exe')) {
                if (Test-Path -LiteralPath $candidate) { $nodePath=$candidate; break }
            }
        }
        if (!$nodePath) { throw '未找到Node.js。请安装Node.js后重试；无需启动Godot编辑器。' }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $stdout = Join-Path $PSScriptRoot ('launcher-'+$stamp+'.log')
        $stderr = Join-Path $PSScriptRoot ('launcher-'+$stamp+'-error.log')
        $process = Start-Process -FilePath $nodePath -ArgumentList ('"'+$server+'"') -WorkingDirectory $project -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        $ready=$false
        for ($i=0; $i -lt 20; $i++) {
            if (Test-Editor) { $ready=$true; break }
            $process.Refresh()
            if ($process.HasExited) { break }
            Start-Sleep -Milliseconds 250
        }
        if (!$ready) { throw ('编辑器未能就绪。检查日志：'+$stderr+'；未关闭其他进程。') }
        Write-Host ('8777编辑器已启动，进程 '+$process.Id+'。日志：'+$stdout)
    }
    if (!$NoBrowser) { Start-Process $url }
    Write-Host ('入口：'+$url)
    Write-Host '参数修改后点击“应用候选并重开”；本脚本不导出游戏、不写正式参数或存档。'
    exit 0
} catch {
    Write-Host ('启动失败：'+$_.Exception.Message) -ForegroundColor Red
    exit 1
}

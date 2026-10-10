$ErrorActionPreference = 'Stop'
$taskRoot = 'F:/maze_code'
$evidence = "$taskRoot/output/ch1_task_status_v2"
$engine = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$env:APPDATA = "$evidence/profile/Roaming"
$env:LOCALAPPDATA = "$evidence/profile/Local"
$env:MAZE_QTE03_PROFILE = "$evidence/profile"
$process = Start-Process -FilePath $engine -ArgumentList "--path $taskRoot --rendering-method gl_compatibility --audio-driver Dummy --log-file $evidence/gui.log res://tools/tests/ch1_task_status_v2.tscn -- --output-dir=$evidence --report=$evidence/report.json" -PassThru -WindowStyle Hidden
if (-not $process.WaitForExit(120000)) {
    $process.Kill()
    throw '专项验收超过120秒，已停止本脚本启动的进程。'
}
$report = Get-Content "$evidence/report.json" -Raw | ConvertFrom-Json
$report | Select-Object checks, failures, display, user_dir
if ($process.ExitCode -ne 0 -or $report.failures -ne 0) { exit 1 }
$log = Get-Content "$evidence/gui.log" -Raw
if ($log -match 'SCRIPT ERROR:|Parse Error:') { throw '存在脚本错误，请查看 gui.log。' }

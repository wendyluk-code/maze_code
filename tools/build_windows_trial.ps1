param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputRoot = '',
    [string]$Godot = 'F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference = 'Stop'
if (!$OutputRoot) { $OutputRoot = Join-Path $ProjectRoot ('build/windows_trial_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path $OutputRoot) { throw '使用新的输出目录，避免混入旧包。' }
New-Item -ItemType Directory -Force "$OutputRoot/stage", "$OutputRoot/release", "$OutputRoot/evidence", "$OutputRoot/engine/editor_data" | Out-Null
New-Item -ItemType File "$OutputRoot/.gdignore", "$OutputRoot/engine/_sc_" | Out-Null
Copy-Item -LiteralPath $Godot -Destination "$OutputRoot/engine/godot.exe"
$engine = "$OutputRoot/engine/godot.exe"
$version = (& $engine --version | Out-String).Trim()
$templateVersion = ($version -split '\.')[0..2] -join '.'
$templates = Join-Path (Split-Path $Godot) "editor_data/export_templates/$templateVersion.stable"
if (!(Test-Path "$templates/windows_release_x86_64.exe")) { throw "缺少匹配的导出模板：$templates" }
# 扫描全部游戏资源引用的顶层目录，不能仅凭名称判断 generated_assets 是开发产物。
$roots = [Collections.Generic.HashSet[string]]::new()
foreach ($name in @('assets','data','scenes','scripts')) { $null = $roots.Add($name) }
$excludedFiles = @('scripts/ui/recipe_book_preview.gd','scenes/ui/recipe_book_preview.tscn')
$sourceFiles = foreach ($root in @('scripts','data','scenes')) {
    Get-ChildItem (Join-Path $ProjectRoot $root) -Recurse -File | Where-Object {
        $_.Extension -in @('.gd','.tscn','.tres','.json') -and $_.FullName -notmatch '[\\/]tests[\\/]'
    }
}
foreach ($file in $sourceFiles) {
    $relative = [IO.Path]::GetRelativePath($ProjectRoot,$file.FullName).Replace('\','/')
    if ($relative -in $excludedFiles) { continue }
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName),'res://([A-Za-z_][A-Za-z_0-9]*)/')) {
        $name = $match.Groups[1].Value
        if ($name -in @('tools','output','addons')) { throw "运行代码引用了开发目录，请核实：$relative -> $name" }
        $null = $roots.Add($name)
    }
}
foreach ($name in $roots) {
    if (!(Test-Path (Join-Path $ProjectRoot $name))) { throw "依赖目录缺失：$name" }
    robocopy (Join-Path $ProjectRoot $name) "$OutputRoot/stage/$name" /E /XD tests /XF recipe_book_preview.gd recipe_book_preview.gd.uid recipe_book_preview.tscn *.blend *.blend.import /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) { throw "复制失败：$name" }
}
$config = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'project.godot'))
$config = $config -replace '(?m)^_mcp_game_helper=.*\r?\n','' -replace 'enabled=PackedStringArray\("res://addons/godot_ai/plugin.cfg"\)','enabled=PackedStringArray()'
[IO.File]::WriteAllText("$OutputRoot/stage/project.godot",$config)
$templatePath = $templates.Replace('\','/')
@"
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.ogv"
exclude_filter="*.md,*.psd,*.blend,*.gif,*.html,*.py,*.ps1"
export_path="../release/CookingMaze.exe"
script_export_mode=2
[preset.0.options]
custom_template/debug="$templatePath/windows_debug_x86_64.exe"
custom_template/release="$templatePath/windows_release_x86_64.exe"
binary_format/architecture="x86_64"
binary_format/embed_pck=false
debug/export_console_wrapper=0
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
codesign/enable=false
application/modify_resources=false
"@ | Set-Content -Encoding utf8 "$OutputRoot/stage/export_presets.cfg"
$manifest = @(Get-ChildItem "$OutputRoot/stage/scripts","$OutputRoot/stage/data" -Recurse -Filter '*.gd' | ForEach-Object {
    'res://' + [IO.Path]::GetRelativePath("$OutputRoot/stage",$_.FullName).Replace('\','/')
})
ConvertTo-Json -InputObject $manifest | Set-Content -Encoding utf8 "$OutputRoot/evidence/runtime-scripts.json"
$snapshot = @(Get-ChildItem "$OutputRoot/stage" -Recurse -File | Where-Object {
    $_.Extension -notin @('.import','.uid') -and $_.Name -notin @('project.godot','export_presets.cfg')
} | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath("$OutputRoot/stage",$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash}
})
ConvertTo-Json -InputObject $snapshot | Set-Content -Encoding utf8 "$OutputRoot/evidence/source-snapshot.json"
function Run-Engine([string[]]$Arguments,[string]$Name,[string]$Executable=$engine) {
    $psi = [Diagnostics.ProcessStartInfo]::new($Executable)
    $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $psi.Environment['APPDATA']="$OutputRoot/evidence/build-profile"
    $psi.Environment['LOCALAPPDATA']="$OutputRoot/evidence/build-profile"
    $psi.Environment['MAZE_PACKAGE_MANIFEST']="$OutputRoot/evidence/runtime-scripts.json"
    $psi.Environment['MAZE_PACKAGE_REPORT']="$OutputRoot/evidence/runtime-audit.json"
    foreach($arg in $Arguments){$psi.ArgumentList.Add($arg)}
    $p=[Diagnostics.Process]::Start($psi)
    $stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
    if(!$p.WaitForExit(240000)){$p.Kill($true); throw "$Name 超时"}
    $log=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
    $log | Set-Content -Encoding utf8 "$OutputRoot/evidence/$Name.log"
    $errors=@($log -split "`n" | Where-Object {$_ -match '^(ERROR:|SCRIPT ERROR:)' -and $_ -notmatch 'Failed to read the root certificate store'})
    # 第一次导入之前缓存尚未建立，错误以导入后的正式导出和运行脚本全量加载为准。
    if($p.ExitCode -ne 0 -or ($Name -ne 'import' -and $errors.Count -gt 0)){throw "$Name 失败，见日志"}
    Write-Output "$Name passed"
}
Run-Engine @('--headless','--editor','--path',"$OutputRoot/stage",'--import') 'import'
Run-Engine @('--headless','--path',"$OutputRoot/stage",'--export-release','Windows Desktop',"$OutputRoot/release/CookingMaze.exe") 'export'
# release 模板不支持 --script；用相同二进制/PCK的隔离副本和 override.cfg 指定测试入口。
$audit="$OutputRoot/evidence/audit-runtime"
New-Item -ItemType Directory $audit | Out-Null
foreach($name in @('CookingMaze.exe','CookingMaze.pck')) { New-Item -ItemType HardLink -Path "$audit/$name" -Target "$OutputRoot/release/$name" | Out-Null }
$auditScript=(Join-Path $PSScriptRoot 'tests/package_runtime_audit.gd').Replace('\','/')
@"
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="$auditScript" id="1"]
[node name="PackageAudit" type="Node"]
script = ExtResource("1")
"@ | Set-Content -Encoding utf8 "$audit/check.tscn"
@"
[application]
run/main_scene="$($audit.Replace('\','/'))/check.tscn"
"@ | Set-Content -Encoding utf8 "$audit/override.cfg"
Run-Engine @('--headless') 'runtime-audit' "$audit/CookingMaze.exe"
$report=Get-Content -Raw "$OutputRoot/evidence/runtime-audit.json" | ConvertFrom-Json
if($report.checked -lt 1 -or $report.failed.Count -gt 0){throw '运行脚本完整性验收失败'}
# 并行任务可能在构建期间写入；发现变化就拒绝把混合快照称为当前版本。
$changed=@($snapshot | Where-Object {
    $source=Join-Path $ProjectRoot $_.path
    !(Test-Path $source) -or (Get-FileHash $source).Hash -ne $_.sha256
})
if($changed.Count){$changed | ConvertTo-Json | Set-Content "$OutputRoot/evidence/concurrent-changes.json";throw '构建期间来源文件改变，请固定版本后重建。'}
Copy-Item (Join-Path (Split-Path $Godot) 'LICENSE.txt') "$OutputRoot/release/Godot-LICENSE.txt"
[ordered]@{source=$ProjectRoot; engine=$version; resource_roots=@($roots); runtime_scripts=$report.checked; output=$OutputRoot} | ConvertTo-Json | Set-Content -Encoding utf8 "$OutputRoot/evidence/build.json"
Write-Output "构建完成，尚需交互验收：$OutputRoot/release"

param([Parameter(Mandatory=$true)][string]$OutputRoot,
 [ValidateSet('res://tools/previews/fenshui_web_play.tscn','res://tools/previews/fenshui_feedback_play.tscn','res://scenes/start_screen.tscn')]
 [string]$EntryScene='res://tools/previews/fenshui_web_play.tscn')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$out=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $out){throw '使用新目录，不能覆盖历史导出'}
New-Item -ItemType Directory -Path "$out/stage","$out/public","$out/profile" -Force|Out-Null
foreach($name in @('assets','data','scenes','scripts','materials','generated_assets','tools/tests','tools/previews')){
 robocopy (Join-Path $root $name) (Join-Path "$out/stage" $name) /E /XD .godot output /XF *.blend *.blend.import *.ps1 *.py *.md *.html *.gif /NFL /NDL /NJH /NJS /NP|Out-Null
 if($LASTEXITCODE -gt 7){throw "复制失败：$name"}
}
$config=[IO.File]::ReadAllText((Join-Path $root 'project.godot'))
$formal=($EntryScene -eq 'res://scenes/start_screen.tscn')
if(-not $formal){$config=$config.Replace('config/name="maze_code"','config/name="maze_fenshui_lan"').Replace('run/main_scene="res://scenes/start_screen.tscn"',('run/main_scene="'+$EntryScene+'"'))}
$config=$config -replace '(?m)^_mcp_game_helper=.*\r?\n','' -replace 'enabled=PackedStringArray\("res://addons/godot_ai/plugin.cfg"\)','enabled=PackedStringArray()'
$nl=[Environment]::NewLine
$config += $nl+'[rendering]'+$nl+'renderer/rendering_method="gl_compatibility"'+$nl+'renderer/rendering_method.mobile="gl_compatibility"'+$nl
[IO.File]::WriteAllText("$out/stage/project.godot",$config)
$preset=@'
[preset.0]
name="Web LAN"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter="*.md,*.ps1,*.py,*.blend,*.gif,*.html"
export_path="../public/index.html"
script_export_mode=1
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
'@
$godot='D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe'
function RunGodot([string]$Name,[string[]]$Arguments){
 $psi=[Diagnostics.ProcessStartInfo]::new($godot)
 $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
 $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($k in @('APPDATA','LOCALAPPDATA','MAZE_QTE03_PROFILE')){$psi.Environment[$k]="$out/profile"}
 foreach($arg in $Arguments){$psi.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::Start($psi)
 $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
 if(-not $p.WaitForExit(240000)){$p.Kill($true);throw "$Name 超过240秒"}
 $log=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
 [IO.File]::WriteAllText("$out/$Name.log",$log)
 $errors=@($log.Split([char]10)|Where-Object {$_ -match '^(ERROR:|SCRIPT ERROR:)'})
 [ordered]@{step=$Name;exit_code=$p.ExitCode;errors=$errors}|ConvertTo-Json -Depth 4|Write-Output
 if($p.ExitCode -ne 0 -or ($Name -ne 'import-cold' -and $errors.Count)){throw "$Name 失败，保留日志"}
}
$templates='C:/Users/KSG/AppData/Roaming/Godot/export_templates/4.7.2.stable'
$preset=$preset+$nl+'custom_template/debug="'+$templates+'/web_nothreads_debug.zip"'+$nl+'custom_template/release="'+$templates+'/web_nothreads_release.zip"'+$nl
[IO.File]::WriteAllText("$out/stage/export_presets.cfg",$preset)
RunGodot 'import-cold' @('--headless','--editor','--path',"$out/stage",'--import')
# 全新缓存首次启动时项目默认字体尚未导入；完成扫描后再严格复验，不能忽略正式导出错误。
RunGodot 'import' @('--headless','--editor','--path',"$out/stage",'--import')
RunGodot 'export' @('--headless','--path',"$out/stage",$(if($formal){'--export-release'}else{'--export-debug'}),'Web LAN',"$out/public/index.html")
[ordered]@{source=$root;head=(git -C $root rev-parse HEAD);output=$out;entry=$EntryScene;threaded=$false;created_at=(Get-Date -Format o)}|ConvertTo-Json|Set-Content -LiteralPath "$out/build.json" -Encoding utf8

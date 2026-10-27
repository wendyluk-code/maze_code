param([string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")), [ValidateSet("check","state","persistence","flow","smoke","editor")][string]$Mode="check", [string]$OutputRoot="output/yf_01", [ValidateSet("1152x648","1280x720")][string]$Resolution="1152x648")
$ErrorActionPreference="Stop"
$root=(Resolve-Path $ProjectRoot).Path; New-Item -ItemType Directory -Force (Join-Path $root $OutputRoot) | Out-Null
$profile=Join-Path $root "$OutputRoot/profile"; New-Item -ItemType Directory -Force (Join-Path $profile 'Godot/app_userdata/maze_code/logs') | Out-Null
$env:APPDATA=$profile; $env:LOCALAPPDATA=$profile
$godot='F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'; $log=Join-Path $root "$OutputRoot/$Mode.log"
$args=@('--headless','--path',$root,'--quit-after','5'); if($Mode -eq 'editor'){ $args=@('--headless','--editor','--path',$root,'--quit') }
if($Mode -eq 'state') { $args=@('--headless','--path',$root,'res://tools/tests/yf_01_state.tscn') }
elseif($Mode -in @('flow','persistence')) { $args=@('--path',$root,'--rendering-method','gl_compatibility','--resolution',$Resolution,'--disable-vsync','res://tools/tests/yf_01_flow.tscn','--',"--isolation-root=$profile/Godot/app_userdata/maze_code","--output-dir=$root/$OutputRoot/screenshots","--report=$root/$OutputRoot/report.json") }
& $godot @args 2>&1 | Tee-Object -FilePath $log
$exitCode=$LASTEXITCODE
$errors=Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:' | Where-Object { $_.Line -notmatch 'root certificate|user://logs|editor_settings' }
$summary=[ordered]@{mode=$Mode; project_root=$root; user_data_dir=$env:APPDATA; command=($godot+' '+($args -join ' ')); exit_code=$exitCode; errors=@($errors | ForEach-Object {$_.Line}); status=if($errors -or $exitCode -ne 0){'failed'}else{'passed'}}
$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $root "$OutputRoot/$Mode.summary.json")
if($errors -or $exitCode -ne 0){ exit 1 }

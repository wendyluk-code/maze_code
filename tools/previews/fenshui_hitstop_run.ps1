param([switch]$UsePrimaryScreen,[switch]$CheckOnly,[switch]$Ranged,[ValidateSet("0","30","40","50","70")][int]$Milliseconds=0)
$ErrorActionPreference="Stop"
if(($Ranged -and $Milliseconds -notin @(0,30,50)) -or (-not $Ranged -and $Milliseconds -notin @(0,40,70))){throw "远程档位为0／30／50，铁山档位为0／40／70，未启动"}
Add-Type -AssemblyName System.Windows.Forms
$screens=@([System.Windows.Forms.Screen]::AllScreens)
$screen=-1
for($i=0;$i -lt $screens.Count;$i++){if(-not $screens[$i].Primary){$screen=$i;break}}
if($screen -lt 0 -and $UsePrimaryScreen){$screen=0}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$base=if($Ranged){"output/fenshui-ranged-hitstop-20261031/play"}else{"output/fenshui-hitstop-20261031/play"}
$scene=if($Ranged){"res://tools/previews/fenshui_ranged_hitstop.tscn"}else{"res://tools/previews/fenshui_hitstop.tscn"}
$profile=Join-Path $root "$base/profile"
if($CheckOnly){[ordered]@{project=$root;scene=$scene;screens=$screens.Count;selected_screen=$screen;isolated_profile=$profile;will_launch=$false} | ConvertTo-Json;return}
if($screen -lt 0){throw "当前没有副屏，未启动窗口。你准备好在主屏试玩时，可主动加 -UsePrimaryScreen 运行。"}
New-Item -ItemType Directory -Path $profile -Force | Out-Null
$psi=[Diagnostics.ProcessStartInfo]::new("D:/Tools/Godot/Godot_v4.7.2-stable_win64.exe")
$psi.WorkingDirectory=$root
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
foreach($key in @("APPDATA","LOCALAPPDATA","MAZE_QTE03_PROFILE")){$psi.Environment[$key]=$profile}
$psi.Environment.Remove("GODOT_EDITOR_CUSTOM_FEATURES") | Out-Null
foreach($arg in @("--path",$root,"--screen",[string]$screen,"--resolution","1280x720","--scene",$scene,"--log-file",(Join-Path $root "$base/engine.log"))){$psi.ArgumentList.Add($arg)}
$psi.ArgumentList.Add("--")
$psi.ArgumentList.Add("--hitstop-ms="+$Milliseconds)
$p=[Diagnostics.Process]::Start($psi)
[ordered]@{pid=$p.Id;started_at=(Get-Date -Format o);screen=$screen;profile=$profile;keys=if($Ranged){"空格锅铲／1芽芽／2铁山70毫秒；F5远程切档；F6重置；左键攻击；按钮回血"}else{"F5切档并重置；F6重置；2选择铁山；左键挥斧"}} | ConvertTo-Json

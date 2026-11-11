param(
 [int]$TargetProcessId=0,
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [switch]$Launch
)
$ErrorActionPreference="Stop"
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$out=[IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $out -Force|Out-Null
if(-not ("FrogNativeWindowCheck" -as [type])) {
 Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class FrogNativeWindowCheck {
 public delegate bool EnumProc(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb,IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr h,int i);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h,StringBuilder b,int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder b,int n);
 [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h,int a,out int v,int n);
 public sealed class Observation {
  public long hwnd;public string title;public bool visible,minimized,wsVisible,noActivate;public int cloaked;
 }
 public static uint ForegroundPid(){uint p;GetWindowThreadProcessId(GetForegroundWindow(),out p);return p;}
 public static Observation[] Read(int processId){
  var result=new List<Observation>();
  EnumWindows((h,p)=>{
   uint id;GetWindowThreadProcessId(h,out id);if(id!=processId)return true;
   var cls=new StringBuilder(128);GetClassName(h,cls,128);if(cls.ToString()!="Engine")return true;
   var title=new StringBuilder(512);GetWindowText(h,title,512);int cloak;
   if(DwmGetWindowAttribute(h,14,out cloak,4)!=0)cloak=-1;
   result.Add(new Observation{hwnd=h.ToInt64(),title=title.ToString(),visible=IsWindowVisible(h),minimized=IsIconic(h),wsVisible=(GetWindowLongPtr(h,-16).ToInt64()&0x10000000)!=0,noActivate=(GetWindowLongPtr(h,-20).ToInt64()&0x08000000)!=0,cloaked=cloak});
   return true;
  },IntPtr.Zero);return result.ToArray();
 }
}
'@
}
$started=Get-Date
$launchInfo=$null
if($Launch){
 if($TargetProcessId){throw "不能同时指定已有进程和新启动"}
 $launchInfo=& (Join-Path $root "tools/previews/fenshui_frog_motion_run.ps1") -OutputRoot (Join-Path $out "play")|ConvertFrom-Json
 $TargetProcessId=[int]$launchInfo.pid
}
if($TargetProcessId -le 0){throw "必须指定目标进程或使用Launch"}
$samples=[Collections.Generic.List[object]]::new()
$ready=-not $Launch
$deadline=(Get-Date).AddSeconds(25)
$sampleUntil=$null
do {
 $foreground=[FrogNativeWindowCheck]::ForegroundPid()
 $windows=@([FrogNativeWindowCheck]::Read($TargetProcessId))
 if($Launch -and (Test-Path -LiteralPath (Join-Path $out "play/window.json"))){$ready=$true}
 $samples.Add([ordered]@{at=(Get-Date -Format o);foreground_pid=$foreground;windows=$windows;ready=$ready})
 if($ready -and $null -eq $sampleUntil){$sampleUntil=(Get-Date).AddSeconds(2)}
 if($null -ne $sampleUntil -and (Get-Date) -ge $sampleUntil){break}
 Start-Sleep -Milliseconds 50
} while((Get-Date) -lt $deadline)
$observed=@($samples|Where-Object ready)
$checks=[ordered]@{
 ready=$ready
 main_window_present=($observed.Count -gt 0 -and @($observed|Where-Object {$_.windows.Count -ne 1}).Count -eq 0)
 native_visible=($observed.Count -gt 0 -and @($observed|Where-Object {@($_.windows|Where-Object {-not $_.visible -or -not $_.wsVisible -or $_.minimized -or $_.cloaked -ne 0}).Count -gt 0}).Count -eq 0)
 remains_unfocusable=($observed.Count -gt 0 -and @($observed|Where-Object {@($_.windows|Where-Object {-not $_.noActivate}).Count -gt 0}).Count -eq 0)
 no_foreground_capture=(@($samples|Where-Object {$_.foreground_pid -eq $TargetProcessId}).Count -eq 0)
}
$failed=@($checks.Keys|Where-Object {-not $checks[$_]})
$report=[ordered]@{started_at=$started.ToString("o");finished_at=(Get-Date -Format o);target_pid=$TargetProcessId;launch=$launchInfo;checks=$checks;failures=$failed;samples=$samples}
$json=$report|ConvertTo-Json -Depth 9
[IO.File]::WriteAllText((Join-Path $out "native-window.json"),$json)
[ordered]@{target_pid=$TargetProcessId;checks=$checks;failures=$failed;sample_count=$samples.Count;report=(Join-Path $out "native-window.json")}|ConvertTo-Json -Depth 4
if($failed.Count){exit 1}

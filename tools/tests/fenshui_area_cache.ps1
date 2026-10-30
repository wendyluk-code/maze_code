param([string]$SourceRoot="D:/workspace/代号：料理迷宫",[string]$ProjectRoot=(Resolve-Path "$PSScriptRoot/../..").Path)
$ErrorActionPreference="Stop"
$copied=@();$skipped=@()
foreach($relative in @(git -C $ProjectRoot ls-files "*.import")){
 $local=Join-Path $ProjectRoot $relative
 $source=Join-Path $SourceRoot $relative
 $asset=$relative.Substring(0,$relative.Length-7)
 if(!(Test-Path -LiteralPath $source) -or !(Test-Path -LiteralPath (Join-Path $SourceRoot $asset))){$skipped+=$relative;continue}
 if((Get-FileHash -LiteralPath (Join-Path $ProjectRoot $asset)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $SourceRoot $asset)).Hash -or (Get-Content -Raw -LiteralPath $local).Replace([string][char]13,"") -ne (Get-Content -Raw -LiteralPath $source).Replace([string][char]13,"")){$skipped+=$relative;continue}
 foreach($match in [regex]::Matches((Get-Content -Raw -LiteralPath $local),'res://\.godot/imported/[^"\r\n]+')){
  $path=$match.Value.Substring(6)
  $from=Join-Path $SourceRoot $path
  $to=Join-Path $ProjectRoot $path
  if(!(Test-Path -LiteralPath $from)){continue}
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  Copy-Item -LiteralPath $from -Destination $to
  $copied+=$path
 }
}
# 类缓存只保留本地脚本实际声明的同名类；运行时仍加载本工作树源码。
$cache=Get-Content -Raw -LiteralPath (Join-Path $SourceRoot ".godot/global_script_class_cache.cfg")
$entries=@()
foreach($entry in [regex]::Matches($cache,'\{[^}]+\}')){
 $path=[regex]::Match($entry.Value,'"path": "res://([^"\r\n]+)"').Groups[1].Value
 $name=[regex]::Match($entry.Value,'"class": &"([^"\r\n]+)"').Groups[1].Value
 $file=Join-Path $ProjectRoot $path
 if((Test-Path -LiteralPath $file) -and (Get-Content -Raw -LiteralPath $file) -match ("(?m)^class_name\s+"+[regex]::Escape($name)+"\b")){$entries+=$entry.Value}
}
New-Item -ItemType Directory -Force (Join-Path $ProjectRoot ".godot") | Out-Null
("list=["+($entries -join ", ")+"]") | Set-Content -LiteralPath (Join-Path $ProjectRoot ".godot/global_script_class_cache.cfg") -Encoding utf8
@{copied=@($copied | Select-Object -Unique).Count;classes=$entries.Count;skipped=$skipped} | ConvertTo-Json -Depth 4

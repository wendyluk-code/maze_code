param([Parameter(Mandatory=$true)][string]$PublicRoot,[Parameter(Mandatory=$true)][string]$OutputRoot,[int]$Port=8086)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$public=[IO.Path]::GetFullPath($PublicRoot)
$out=[IO.Path]::GetFullPath($OutputRoot)
if(-not(Test-Path -LiteralPath "$public/index.html")){throw '缺少真正的网页导出入口'}
if(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue){throw '端口已被使用，不关闭其他服务'}
New-Item -ItemType Directory -Path $out -Force|Out-Null
$server=Join-Path $root 'tools/web/serve_fenshui.cjs'
$arguments=@(('"'+$server+'"'),('"'+$public+'"'),[string]$Port)
$process=Start-Process -FilePath 'C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$out/server.log" -RedirectStandardError "$out/server-error.log"
$ready=$false
$deadline=(Get-Date).AddSeconds(15)
while((Get-Date) -lt $deadline){
 try{$r=Invoke-WebRequest "http://127.0.0.1:$Port/" -TimeoutSec 2;$ready=$r.StatusCode -eq 200}catch{}
 if($ready){break};if($process.HasExited){throw '静态服务提前退出'};Start-Sleep -Milliseconds 100
}
if(-not $ready){throw '服务未就绪，保留进程和日志供检查'}
$ip=(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias '以太网'|Where-Object {$_.IPAddress -notlike '169.254.*'}|Select-Object -First 1).IPAddress
$result=[ordered]@{pid=$process.Id;ready=$ready;listen='0.0.0.0';port=$Port;public_root=$public;local_url="http://127.0.0.1:$Port/";lan_url=('http://{0}:{1}/' -f $ip,$Port);started_at=(Get-Date -Format o)}
$result|ConvertTo-Json|Set-Content -LiteralPath "$out/launch.json" -Encoding utf8
$result|ConvertTo-Json

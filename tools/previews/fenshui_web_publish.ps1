param(
 [Parameter(Mandatory=$true)][string]$PublicRoot,
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [Parameter(Mandatory=$true)][int]$ExpectedPid,
 [Parameter(Mandatory=$true)][string]$ExpectedRoot,
 [string]$CertificateRoot="",
 [int]$Port=8449
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$public=[IO.Path]::GetFullPath($PublicRoot)
$previous=[IO.Path]::GetFullPath($ExpectedRoot)
$out=[IO.Path]::GetFullPath($OutputRoot)
$server=[IO.Path]::GetFullPath((Join-Path $root 'tools/web/serve_fenshui.cjs'))
$credentials=if($CertificateRoot){[IO.Path]::GetFullPath($CertificateRoot)}else{Join-Path $root 'output/fenshui-player-hurt-20261104/https'}
$cert=Join-Path $credentials 'certificate.pem'
$key=Join-Path $credentials 'private-key.pem'
if(-not(Test-Path -LiteralPath $cert) -or -not(Test-Path -LiteralPath $key)){throw '原局域网证书不完整，不停止旧服务'}
if(-not(Test-Path -LiteralPath "$public/index.html")){throw '新网页包缺失'}
if(Test-Path -LiteralPath $out){throw '不覆盖旧启动记录'}
$old=Get-CimInstance Win32_Process -Filter "ProcessId=$ExpectedPid"
if(-not $old -or $old.Name -ne 'node.exe' -or -not $old.CommandLine.Contains($server) -or -not $old.CommandLine.Contains($previous) -or -not $old.CommandLine.Contains(" $Port ")){throw '旧服务归属变化，不停止其他进程'}
$listener=Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
if(@($listener|Where-Object {$_.OwningProcess -ne $ExpectedPid}).Count){throw '端口归属变化'}
New-Item -ItemType Directory -Path $out|Out-Null
Stop-Process -Id $ExpectedPid
$args=@(('"'+$server+'"'),('"'+$public+'"'),[string]$Port,('"'+$cert+'"'),('"'+$key+'"'))
$p=Start-Process -FilePath 'C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$out/server.log" -RedirectStandardError "$out/server-error.log"
$ready=$false;$deadline=(Get-Date).AddSeconds(15)
while((Get-Date) -lt $deadline){
 try{$ready=(Invoke-WebRequest "https://127.0.0.1:$Port/" -SkipCertificateCheck -TimeoutSec 2).StatusCode -eq 200}catch{}
 if($ready){break};if($p.HasExited){throw '新服务提前退出，保留旧包与启动错误'};Start-Sleep -Milliseconds 100
}
if(-not $ready){throw '新服务未就绪，不能报告已启动'}
$record=[ordered]@{pid=$p.Id;ready=$ready;public_root=$public;listen='0.0.0.0';port=$Port;url="https://10.11.179.57:$Port/";previous_pid=$ExpectedPid;previous_root=$previous;certificate='沿用既有局域网试玩证书；未修改系统信任或防火墙';certificate_root=$credentials;started_at=(Get-Date -Format o)}
$record|ConvertTo-Json|Set-Content -LiteralPath "$out/launch.json" -Encoding utf8
$record|ConvertTo-Json

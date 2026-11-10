param([Parameter(Mandatory=$true)][string]$PublicRoot,[Parameter(Mandatory=$true)][string]$OutputRoot,[int]$Port=8443)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$public=[IO.Path]::GetFullPath($PublicRoot)
$out=[IO.Path]::GetFullPath($OutputRoot)
if(-not(Test-Path -LiteralPath "$public/index.html")){throw '缺少网页游戏导出包'}
if(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue){throw '端口已被占用，不替换他人服务'}
if(Test-Path -LiteralPath $out){throw 'HTTPS输出目录已存在，不覆盖证书或日志'}
New-Item -ItemType Directory -Path $out|Out-Null
$ip=(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias '以太网'|Where-Object {$_.IPAddress -notlike '169.254.*'}|Select-Object -First 1).IPAddress
$rsa=[Security.Cryptography.RSA]::Create(2048)
$request=[Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=CookingMaze LAN Trial',$rsa,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
$san=[Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
$san.AddIpAddress([Net.IPAddress]::Parse($ip));$san.AddIpAddress([Net.IPAddress]::Loopback);$san.AddDnsName('localhost')
$request.CertificateExtensions.Add($san.Build())
$cert=$request.CreateSelfSigned([DateTimeOffset]::Now.AddMinutes(-5),[DateTimeOffset]::Now.AddDays(30))
[IO.File]::WriteAllText("$out/certificate.pem",$cert.ExportCertificatePem())
[IO.File]::WriteAllText("$out/private-key.pem",$rsa.ExportPkcs8PrivateKeyPem())
# 证书仅作为此进程TLS输入，私钥不在公开目录，不安装任何信任根。
$server=Join-Path $root 'tools/web/serve_fenshui.cjs'
$arguments=@(('"'+$server+'"'),('"'+$public+'"'),[string]$Port,('"'+$out+'/certificate.pem"'),('"'+$out+'/private-key.pem"'))
$process=Start-Process -FilePath 'C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$out/server.log" -RedirectStandardError "$out/server-error.log"
$ready=$false;$deadline=(Get-Date).AddSeconds(15)
while((Get-Date) -lt $deadline){
 try{$r=Invoke-WebRequest "https://127.0.0.1:$Port/" -SkipCertificateCheck -TimeoutSec 2;$ready=$r.StatusCode -eq 200}catch{}
 if($ready){break};if($process.HasExited){throw 'HTTPS服务提前退出'};Start-Sleep -Milliseconds 100
}
if(-not $ready){throw 'HTTPS服务未就绪'}
$result=[ordered]@{pid=$process.Id;ready=$ready;public_root=$public;listen='0.0.0.0';port=$Port;url=('https://{0}:{1}/' -f $ip,$Port);certificate='本次局域网试玩自签证书；未安装信任根';expires=$cert.NotAfter.ToString('o');started_at=(Get-Date -Format o)}
$result|ConvertTo-Json|Set-Content -LiteralPath "$out/launch.json" -Encoding utf8
$result|ConvertTo-Json

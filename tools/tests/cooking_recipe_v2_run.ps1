param([ValidateSet('state','legacy-state','legacy-lifecycle')][string]$Mode = 'state')
$ErrorActionPreference = 'Stop'
$root = 'F:\maze_code'
$outDir = Join-Path $root ('output/cooking_v2/' + $Mode + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$profile = Join-Path $outDir 'profile'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$psi = [Diagnostics.ProcessStartInfo]::new('F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Environment['APPDATA'] = $profile
$psi.Environment['LOCALAPPDATA'] = $profile
$psi.Environment['MAZE_COOKING_V2_PROFILE'] = $profile
$psi.Environment['MAZE_QTE02_PROFILE'] = $profile
$report = Join-Path $outDir 'report.json'
$engineArgs = @('--path',$root,'--audio-driver','Dummy')
if ($Mode -eq 'state') { $engineArgs += @('--headless','--script','res://tools/tests/cooking_recipe_v2_state.gd','--',"--report=$report") }
elseif ($Mode -eq 'legacy-state') { $engineArgs += @('--headless','--script','res://tools/tests/ch1_qte_02_state.gd','--','--mode=unit',"--report=$report") }
else { $engineArgs += @('--rendering-method','gl_compatibility','res://tools/tests/ch1_qte_02_input.tscn','--','--mode=lifecycle',"--report=$report","--output-dir=$outDir/screenshots") }
foreach ($argument in $engineArgs) { $psi.ArgumentList.Add($argument) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$null = $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (!$process.WaitForExit(120000)) { $process.Kill($true); throw 'Godot timeout' }
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $outDir 'stdout.log'), $stdout)
[IO.File]::WriteAllText((Join-Path $outDir 'stderr.log'), $stderr)
Write-Host $outDir
if (!(Test-Path -LiteralPath $report)) { Write-Host $stdout; Write-Host $stderr; throw 'No report generated' }
$result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
Write-Host ($result | Select-Object checks,failures | ConvertTo-Json -Compress)
$filtered = ($stdout + $stderr) -replace '(?m)^ERROR: Failed to read the root certificate store\.\r?\n', ''
if ($process.ExitCode -ne 0 -or $result.failures -ne 0 -or $result.checks -le 0 -or $filtered -match 'SCRIPT ERROR|Parse Error|(?m)^ERROR:') { Write-Host $stderr; throw 'Verification failed' }

param([ValidateSet('medium','low')][string]$Quality='medium')
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force 'test-results' | Out-Null
$log=Join-Path $PSScriptRoot "test-results\$stamp.log"
$errlog=Join-Path $PSScriptRoot "test-results\$stamp-errors.log"
$memory=Join-Path $PSScriptRoot "test-results\$stamp-memory.csv"
'elapsed_seconds,working_set_bytes,private_bytes' | Set-Content $memory
$watch=[System.Diagnostics.Stopwatch]::StartNew()
$game=Start-Process -FilePath '.\BreezelyIsles.exe' -ArgumentList '--','--benchmark','--duration=300',"--quality=$Quality" -PassThru -RedirectStandardOutput $log -RedirectStandardError $errlog
while (-not $game.HasExited) {
 $game.Refresh()
 "$([math]::Round($watch.Elapsed.TotalSeconds,2)),$($game.WorkingSet64),$($game.PrivateMemorySize64)" | Add-Content $memory
 Start-Sleep -Seconds 2
}
$game.WaitForExit()
Get-Content $log
Write-Host "Exit code: $($game.ExitCode). 请交回 test-results 与日志中 BENCHMARK_REPORT 所指文件夹。"
if ($game.ExitCode -ne 0) { exit $game.ExitCode }

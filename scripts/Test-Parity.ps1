param(
  [string]$DevEcoPath = 'D:/Huawei/DevEco Studio'
)

$ErrorActionPreference = 'Stop'
$repoPath = Split-Path $PSScriptRoot -Parent
$wrapperPath = Join-Path $DevEcoPath 'tools/hvigor/bin/hvigorw.bat'
if (!(Test-Path -LiteralPath $wrapperPath)) {
  throw 'DevEco wrapper not found. Pass -DevEcoPath with your installation directory.'
}

Push-Location $repoPath
$previousSdk = $env:DEVECO_SDK_HOME
$previousJava = $env:JAVA_HOME
try {
  $runner = Get-Content -Raw 'entry/src/main/ets/debug/DebugRunner.ts'
  if ($runner -notmatch 'export const CURRENT_DEBUG_TARGET:\s*DebugTarget\s*=\s*DebugTarget\.NONE\s*;') {
    throw 'CURRENT_DEBUG_TARGET must be NONE before regression validation.'
  }
  $env:DEVECO_SDK_HOME = Join-Path $DevEcoPath 'sdk'
  $env:JAVA_HOME = Join-Path $DevEcoPath 'jbr'
  $reportPath = 'entry/.test/default/intermediates/test/coverage_data/test_result.txt'
  $started = Get-Date
  & $wrapperPath test --no-daemon
  if ($LASTEXITCODE -ne 0) { throw "Local tests failed with exit code $LASTEXITCODE." }
  $report = Get-Item -LiteralPath $reportPath
  if ($report.LastWriteTime -lt $started) { throw 'Test report is stale.' }
  $summary = Get-Content -LiteralPath $reportPath | Select-String '^Tests run: (\d+), Failure: (\d+), Error: (\d+), Pass: (\d+), Ignore: (\d+)' | Select-Object -Last 1
  if (!$summary) { throw 'Test summary not found.' }
  $counts = $summary.Matches[0].Groups
  if ([int]$counts[1].Value -le 0 -or [int]$counts[2].Value -ne 0 -or [int]$counts[3].Value -ne 0 -or [int]$counts[5].Value -ne 0 -or [int]$counts[1].Value -ne [int]$counts[4].Value) {
    throw "Regression gate failed: $summary"
  }
  Write-Output "Parity regression passed: $summary"
} finally {
  $env:DEVECO_SDK_HOME = $previousSdk
  $env:JAVA_HOME = $previousJava
  Pop-Location
}

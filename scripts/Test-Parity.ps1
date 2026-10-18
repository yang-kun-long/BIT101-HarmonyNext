param(
  [string]$DevEcoPath = 'D:/Huawei/DevEco Studio',
  [switch]$Build,
  [string]$Device = '',
  [string]$BundleName = 'com.example.bit101harmonyos'
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
$evidenceRoot = Join-Path $repoPath 'entry/build/parity'
$evidencePath = Join-Path $evidenceRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
New-Item -ItemType Directory -Force -Path $evidencePath | Out-Null
$stages = [System.Collections.Generic.List[object]]::new()
$result = [ordered]@{
  started = (Get-Date).ToString('o')
  commit = (& git rev-parse HEAD)
  dirty = [bool](& git status --porcelain)
  device = $Device
  build = [bool]($Build -or $Device)
  status = 'running'
  stages = $stages
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidencePath 'result.json') -Encoding utf8
Write-Output ('Parity evidence: ' + $evidencePath)

function Invoke-ParityStage {
  param([string]$Name, [string]$Command, [string[]]$Arguments)
  $logPath = Join-Path $evidencePath ($Name + '.log')
  Write-Output ('Parity stage: ' + $Name)
  $output = & $Command @Arguments 2>&1
  $commandExit = $LASTEXITCODE
  $output | Out-File -LiteralPath $logPath -Encoding utf8
  $stages.Add([ordered]@{ name = $Name; exitCode = $commandExit; log = $logPath })
  if ($commandExit -ne 0) {
    Get-Content -LiteralPath $logPath -Tail 60 | Write-Output
    throw ('Parity stage failed: ' + $Name + '. See ' + $logPath)
  }
}

function Assert-ParitySummary {
  param([string]$Text)
  $pattern = 'Tests run: ([0-9]+), Failure: ([0-9]+), Error: ([0-9]+), Pass: ([0-9]+), Ignore: ([0-9]+)'
  $summaries = [regex]::Matches($Text, $pattern)
  if ($summaries.Count -eq 0) { throw 'Test summary not found.' }
  $lastSummary = $summaries[$summaries.Count - 1]
  $counts = $lastSummary.Groups
  if ([int]$counts[1].Value -le 0 -or [int]$counts[2].Value -ne 0 -or [int]$counts[3].Value -ne 0 -or [int]$counts[5].Value -ne 0 -or [int]$counts[1].Value -ne [int]$counts[4].Value) {
    throw ('Regression gate failed: ' + $lastSummary.Value)
  }
  Write-Output ('Parity regression passed: ' + $lastSummary.Value)
}

try {
  $runner = Get-Content -Raw 'entry/src/main/ets/debug/DebugRunner.ts'
  if ($runner -notmatch 'export const CURRENT_DEBUG_TARGET:\s*DebugTarget\s*=\s*DebugTarget\.NONE\s*;') {
    throw 'CURRENT_DEBUG_TARGET must be NONE before regression validation.'
  }
  $env:DEVECO_SDK_HOME = Join-Path $DevEcoPath 'sdk'
  $suite = Get-Content -Raw 'entry/src/test/List.test.ets'
  foreach ($testFile in Get-ChildItem 'entry/src/test' -Filter '*.test.ets') {
    if ($testFile.Name -eq 'List.test.ets') { continue }
    $testModule = $testFile.Name.Substring(0, $testFile.Name.Length - 4)
    $importLine = $suite.Split([char]10) | Where-Object { $_.Contains('./' + $testModule + [char]39) }
    if (!$importLine) { throw ('Local test is not imported: ' + $testFile.Name) }
    $functionName = ($importLine.Trim() -split ' ')[1]
    if (!$suite.Contains($functionName + '();')) {
      throw ('Local test is not registered: ' + $testFile.Name)
    }
  }
  $env:JAVA_HOME = Join-Path $DevEcoPath 'jbr'
  $reportPath = 'entry/.test/default/intermediates/test/coverage_data/test_result.txt'
  $started = Get-Date
  Invoke-ParityStage 'local-tests' $wrapperPath @('test', '--no-daemon')
  $report = Get-Item -LiteralPath $reportPath
  if ($report.LastWriteTime -lt $started) { throw 'Test report is stale.' }
  Assert-ParitySummary (Get-Content -Raw -LiteralPath $reportPath)
  Copy-Item -LiteralPath $reportPath -Destination (Join-Path $evidencePath 'local-test-result.txt')

  if ($Build -or $Device) {
    Invoke-ParityStage 'debug-build' 'devecocli' @('build')
    if ($Device) {
      Invoke-ParityStage 'device-info' 'devecocli' @('device', 'view', '-t', $Device)
      Invoke-ParityStage 'debug-run' 'devecocli' @('run', '--module', 'entry', '--device', $Device, '--skip-build')
      Invoke-ParityStage 'device-test-build' 'devecocli' @('build', '--modules', 'entry@ohosTest')
      $testHap = Get-ChildItem 'entry/build/default/outputs/ohosTest' -Filter '*-signed.hap' | Select-Object -First 1
      if (!$testHap) { throw 'Signed device test HAP not found.' }
      $hdcPath = Join-Path $DevEcoPath 'sdk/default/openharmony/toolchains/hdc.exe'
      # devecocli cannot install a test feature or invoke aa test.
      Invoke-ParityStage 'device-test-install' $hdcPath @('-t', $Device, 'install', '-r', $testHap.FullName)
      if ((Get-Content -Raw (Join-Path $evidencePath 'device-test-install.log')) -notmatch 'successfully') {
        throw 'Device test install did not report success.'
      }
      Invoke-ParityStage 'device-tests' $hdcPath @('-t', $Device, 'shell', 'aa', 'test', '-b', $BundleName, '-m', 'entry_test', '-s', 'unittest', 'OpenHarmonyTestRunner', '-s', 'timeout', '60000', '-w', '60')
      Assert-ParitySummary (Get-Content -Raw (Join-Path $evidencePath 'device-tests.log'))
    }
    Invoke-ParityStage 'release-build' 'devecocli' @('build', '--build-mode', 'release')
    if ($Device) {
      $coldStart = Get-Date
      Invoke-ParityStage 'release-stop' $hdcPath @('-t', $Device, 'shell', 'aa', 'force-stop', $BundleName)
      Invoke-ParityStage 'release-run' 'devecocli' @('run', '--module', 'entry', '--device', $Device, '--build-mode', 'release', '--skip-build')
      Start-Sleep -Seconds 2
      Invoke-ParityStage 'release-process' $hdcPath @('-t', $Device, 'shell', 'pidof', $BundleName)
      if ((Get-Content -Raw (Join-Path $evidencePath 'release-process.log')) -notmatch '[0-9]+') {
        throw 'Release app did not remain running after launch.'
      }
      $seconds = [Math]::Max(1, [int][Math]::Ceiling(((Get-Date) - $coldStart).TotalSeconds))
      Invoke-ParityStage 'release-log' 'devecocli' @('log', '--device', $Device, '--bundle-name', $BundleName, '--from', ($seconds.ToString() + 's'), '--tail', '2000')
      $releaseLog = Get-Content -Raw (Join-Path $evidencePath 'release-log.log')
      if ($releaseLog.Contains('No running process found')) { throw 'Release logs could not be collected.' }
      if ($releaseLog.Contains('[DebugRunner] START') -or $releaseLog.Contains('[DebugRunner] SUMMARY')) {
        throw 'Release cold start executed DebugCase.'
      }
      $powerShellPath = (Get-Process -Id $PID).Path
      Invoke-ParityStage 'release-share' $powerShellPath @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'Test-ParityShare.ps1'), '-DevEcoPath', $DevEcoPath, '-Device', $Device)
      Invoke-ParityStage 'release-crash' 'devecocli' @('log', '--device', $Device, '--bundle-name', $BundleName, '--crash')
      if (!(Get-Content -Raw (Join-Path $evidencePath 'release-crash.log')).Contains('No crash logs found')) {
        throw 'Crash records require review. See release-crash.log.'
      }
    }
  }
  $result.status = 'passed'
} catch {
  $result.status = 'failed'
  $result.error = $_.Exception.Message
  throw
} finally {
  try {
    $result.finished = (Get-Date).ToString('o')
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidencePath 'result.json') -Encoding utf8
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'latest.json') -Encoding utf8
  } finally {
    $env:DEVECO_SDK_HOME = $previousSdk
    $env:JAVA_HOME = $previousJava
    Pop-Location
  }
}

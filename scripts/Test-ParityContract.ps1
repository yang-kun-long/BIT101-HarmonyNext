$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'Test-Parity.ps1'
$parseTokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$parseTokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
$summaryFunction = $ast.Find({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-ParitySummary'
}, $true)
. ([scriptblock]::Create($summaryFunction.Extent.Text))

# hvigor and aa test may exit zero even when Hypium reports failures.
$badReports = @(
  '',
  'BUILD SUCCESSFUL',
  'Tests run: 0, Failure: 0, Error: 0, Pass: 0, Ignore: 0',
  'Tests run: 3, Failure: 1, Error: 0, Pass: 2, Ignore: 0',
  'Tests run: 3, Failure: 0, Error: 1, Pass: 2, Ignore: 0',
  'Tests run: 3, Failure: 0, Error: 0, Pass: 2, Ignore: 1',
  'Tests run: 3, Failure: 0, Error: 0, Pass: 2, Ignore: 0',
  ('Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0' + [Environment]::NewLine +
    'Tests run: 3, Failure: 1, Error: 0, Pass: 2, Ignore: 0')
)
foreach ($report in $badReports) {
  $rejected = $false
  try { Assert-ParitySummary $report | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw ('Gate accepted an invalid report: ' + $report) }
}
Assert-ParitySummary 'Tests run: 311, Failure: 0, Error: 0, Pass: 311, Ignore: 0'
Assert-ParitySummary 'OHOS_REPORT_RESULT: stream=Tests run: 96, Failure: 0, Error: 0, Pass: 96, Ignore: 0'
Write-Output 'Parity gate contract: 10 checks passed.'

param(
  [string]$DevEcoPath = 'D:/Huawei/DevEco Studio',
  [Parameter(Mandatory)][string]$Device
)
$ErrorActionPreference = 'Stop'
$hdcPath = Join-Path $DevEcoPath 'sdk/default/openharmony/toolchains/hdc.exe'

# devecocli has no UI automation command. Run against the normally launched release app.
function Get-ParityNodes {
  & $hdcPath -t $Device shell uitest dumpLayout -p /data/local/tmp/bit101-parity-layout.json | Out-Null
  $tree = (& $hdcPath -t $Device shell cat /data/local/tmp/bit101-parity-layout.json) | ConvertFrom-Json
  function Expand-Node($node) {
    $node.attributes
    foreach ($child in $node.children) { Expand-Node $child }
  }
  Expand-Node $tree
}

function Wait-ParityText([string]$Text) {
  $deadline = (Get-Date).AddSeconds(8)
  do {
    $node = Get-ParityNodes | Where-Object { $_.text -eq $Text } | Select-Object -First 1
    if ($node) { return $node }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $deadline)
  throw ('Expected UI text was absent: ' + $Text)
}

function Click-ParityText([string]$Text) {
  $node = Wait-ParityText $Text
  $coords = [regex]::Matches($node.bounds, '[0-9]+')
  $pointX = [int](([int]$coords[0].Value + [int]$coords[2].Value) / 2)
  $pointY = [int](([int]$coords[1].Value + [int]$coords[3].Value) / 2)
  & $hdcPath -t $Device shell uitest uiInput click $pointX $pointY | Out-Null
}

Click-ParityText '我'
Click-ParityText '设置'
Click-ParityText '关于'
for ($attempt = 0; $attempt -lt 2; $attempt++) {
  Click-ParityText '导出诊断日志'
  Wait-ParityText 'BIT101 诊断日志' | Out-Null
  Write-Output ('Share panel opened: attempt ' + ($attempt + 1))
  & $hdcPath -t $Device shell uitest uiInput keyEvent Back | Out-Null
  Wait-ParityText '导出诊断日志' | Out-Null
}
& $hdcPath -t $Device shell uitest uiInput keyEvent Back | Out-Null
& $hdcPath -t $Device shell uitest uiInput keyEvent Back | Out-Null
Wait-ParityText '我' | Out-Null
Write-Output 'PASS: release diagnostic share opened, cancelled and reopened.'

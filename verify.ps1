$p = Start-Process -FilePath '.\zig-out\bin\fizz.exe' -PassThru
$spid = $p.Id
Write-Output ("STARTED:" + $spid)
Start-Sleep -Seconds 3
try {
  $r1 = Invoke-WebRequest -Uri 'http://127.0.0.1:8787/' -TimeoutSec 20 -UseBasicParsing
  $b1 = $r1.Content
  Write-Output ("LEN:" + $b1.Length)
  Write-Output ("RC_B14:" + $b1.Contains('$RC("B:14"'))
  Write-Output ("RX_B7:" + $b1.Contains('$RX("B:7"'))
  Write-Output ("RX_B19:" + $b1.Contains('$RX("B:19"'))
  Write-Output ("RC_B28:" + $b1.Contains('$RC("B:28"'))
  Write-Output ("BARE_TR:" + $b1.Contains('<tr id="S:'))
  Write-Output ("ESCAPED:" + $b1.Contains('&lt;script&gt;'))
  $iRX7 = $b1.IndexOf('$RX("B:7"')
  $iRC7 = $b1.IndexOf('$RC("B:7"')
  Write-Output ("RX7idx:" + $iRX7 + " RC7idx:" + $iRC7)
} catch {
  Write-Output ("ERR1:" + $_.Exception.Message)
}
try {
  $r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8787/abort?after=11' -TimeoutSec 20 -UseBasicParsing
  $b2 = $r2.Content
  Write-Output ("ABORTLEN:" + $b2.Length)
} catch {
  Write-Output ("ERR2:" + $_.Exception.Message)
}
Stop-Process -Id $spid -Force -ErrorAction SilentlyContinue
Write-Output "STOPPED"

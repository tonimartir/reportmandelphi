Remove-Item ".\tests\fpc\LclMonacoTest\selftest_result.log" -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath ".\tests\fpc\LclMonacoTest\LclMonacoTest.exe" -ArgumentList "--selftest" -PassThru
$exited = $proc.WaitForExit(10000)
Write-Host "Process finished within 10s: $exited"
if (Test-Path ".\tests\fpc\LclMonacoTest\selftest_result.log") {
    Write-Host "--- LOG OUTPUT ---"
    Get-Content ".\tests\fpc\LclMonacoTest\selftest_result.log"
} else {
    Write-Host "No log file found."
}
if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force
    Write-Host "Process was killed."
}

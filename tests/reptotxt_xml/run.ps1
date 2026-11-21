# reptotxt -xml: the DFM reports of repman\repsamples saved as XML lose nothing.
#
#   1. reptotxt -xml converts the folder: every DFM report is converted (reptotxt reads each XML again
#      and fails when its properties are not those of the report), every XML one is copied;
#   2. printreptopdf -u prints the DFM and the XML of the reports that run without a database: the
#      PDFs are identical but the creation date and the /ID;
#   3. with -Linux, the same with the Linux64 binaries (binrl64) in an ubuntu:26.04 container of the
#      Docker of WSL (linux-test.sh). The binaries linked with the Ubuntu 26.04 SDK need its glibc;
#      sample4 does not run there (its biolife.cds is a binary MIDAS packet, not supported on Linux).
#
# Build first (Win32 Debug by default): reptotxt and printreptopdf of repman\reportmanxe2.groupproj.
#   powershell -File tests\reptotxt_xml\run.ps1 [-Config Debug|Release] [-Linux]
param(
  [ValidateSet('Debug', 'Release')][string]$Config = 'Debug',
  [switch]$Linux
)
# Continue: in Windows PowerShell a native program writing to stderr would stop the script
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bin = if ($Config -eq 'Debug') { 'bin32' } else { 'binr32' }
$reptotxt = Join-Path $root "repman\utils\reptotxt\$bin\reptotxt.exe"
$printreptopdf = Join-Path $root "repman\utils\printreptopdf\$bin\printreptopdf.exe"
foreach ($exe in $reptotxt, $printreptopdf) {
  if (-not (Test-Path $exe)) { throw "Build it first: $exe" }
}
$samples = Join-Path $root 'repman\repsamples'
$work = Join-Path ([IO.Path]::GetTempPath()) ('reptotxt_xml_' + [guid]::NewGuid().ToString('N'))
$out = Join-Path $work 'xml'
New-Item -ItemType Directory -Path $work | Out-Null
$failed = 0

function Check([bool]$ok, [string]$what) {
  if ($ok) { Write-Host "[OK]   $what" } else { Write-Host "[FAIL] $what"; $script:failed++ }
}

# The PDF text without its creation and modification dates and its /ID
function Normalized([string]$file) {
  $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($file))
  $text = [regex]::Replace($text, "\(D:[0-9+Z'\-]+\)", '(D)')
  return [regex]::Replace($text, '/ID\s*\[[^\]]*\]', '/ID[]')
}

try {
  $reports = @(Get-ChildItem $samples -Filter *.rep)
  $lines = & $reptotxt -xml $samples $out 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  $lines | ForEach-Object { Write-Host "       $_" }
  Check ($code -eq 0) "reptotxt -xml repsamples: exit code 0"
  $summary = $lines | Where-Object { $_ -match '^(\d+) converted, (\d+) copied \(XML already\), (\d+) failed$' } | Select-Object -Last 1
  Check ($summary -and ([int]$Matches[1] + [int]$Matches[2]) -eq $reports.Count -and [int]$Matches[1] -gt 0 -and [int]$Matches[3] -eq 0) "the $($reports.Count) reports: the DFM ones converted and verified, the XML ones copied, none failed"

  # The reports of repsamples that print without a database
  foreach ($report in 'arabonly', 'sample4') {
    $a = Join-Path $work "$report.dfm.pdf"
    $b = Join-Path $work "$report.xml.pdf"
    Push-Location $samples
    try {
      & $printreptopdf -q -u (Join-Path $samples "$report.rep") $a 2>&1 | Out-Null
      & $printreptopdf -q -u (Join-Path $out "$report.rep") $b 2>&1 | Out-Null
    } finally { Pop-Location }
    $same = (Test-Path $a) -and (Test-Path $b) -and ((Normalized $a) -ceq (Normalized $b))
    Check $same "$report.rep: the PDF of the XML is the one of the DFM (but the date and /ID)"
  }

  if ($Linux) {
    $toLinux = { param($p) (& wsl.exe wslpath -a ($p -replace '\\', '/')).Trim() }
    $r = & $toLinux $root
    $t = & $toLinux $PSScriptRoot
    $result = & wsl.exe -- docker run --rm -v "${r}:/r:ro" -v "${t}:/w:ro" ubuntu:26.04 bash /w/linux-test.sh 2>&1 | ForEach-Object { "$_" }
    $result | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { Write-Host "       $_" }
    Check (($result -match '^\d+ converted, \d+ copied \(XML already\), 0 failed$').Count -eq 1) 'Linux64: the conversion of repsamples, none failed'
    Check (($result -match '^arabonly: PDFs identical').Count -eq 1) 'Linux64: arabonly.rep, the PDF of the XML is the one of the DFM'
  }
} finally {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { Write-Host "RESULT: $failed FAILED"; exit 1 }
Write-Host 'RESULT: OK'
exit 0

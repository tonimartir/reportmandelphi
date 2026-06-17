# Tarea 03 - Empaqueta el OCX ActiveX por arquitectura (solo el .ocx):
#   reportman_ax_<ver>_x64.zip  (activex\binr64\Reportman.ocx)
#   reportman_ax_<ver>_x32.zip  (activex\binr32\Reportman.ocx)
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 03: zips del ActiveX/OCX (v$Version) =="
New-CleanDir $ActiveXDir

$targets = @(
  [pscustomobject]@{ Arch = 'x64'; Ocx = (Join-Path $RepoRoot 'activex\binr64\Reportman.ocx') },
  [pscustomobject]@{ Arch = 'x32'; Ocx = (Join-Path $RepoRoot 'activex\binr32\Reportman.ocx') }
)

foreach ($t in $targets) {
  if (-not (Test-Path $t.Ocx)) { Fail "No encuentro el OCX: $($t.Ocx)" }
  $zip = Join-Path $ActiveXDir ("reportman_ax_{0}_{1}.zip" -f $VerU, $t.Arch)
  if (Test-Path $zip) { Remove-Item $zip -Force }
  # Solo el OCX dentro del zip
  Compress-Archive -Path $t.Ocx -DestinationPath $zip -Force
}

Ok "Tarea 03 OK:"
Get-ChildItem $ActiveXDir -Filter *.zip | ForEach-Object {
  Write-Host ("  {0}  ({1} KB)" -f $_.Name, [math]::Round($_.Length / 1KB, 1))
}
exit 0

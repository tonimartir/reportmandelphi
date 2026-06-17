# Tarea 02 - Compila los dos instaladores InnoSetup del Designer y los deja en
# release_<ver>\Designer\.  Usa /O para que ISCC escriba directamente ahi.
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 02: instaladores InnoSetup del Designer (v$Version) =="
if (-not (Test-Path $Iscc)) { Fail "No encuentro ISCC.exe: $Iscc" }
New-CleanDir $DesignerDir

$issFiles = @(
  (Join-Path $InstallDir 'reportmanxe_64.iss'),       # Designer Delphi x64 (sin net2)
  (Join-Path $InstallDir 'reportmanxe_x32.iss'),      # Designer Delphi x86 (sin net2)
  (Join-Path $InstallDir 'reportmanxe_net_64.iss'),   # Report Manager .NET Designer x64 (self-contained)
  (Join-Path $InstallDir 'reportmanxe_net_x32.iss')   # Report Manager .NET Designer x86 (self-contained)
)

foreach ($iss in $issFiles) {
  if (-not (Test-Path $iss)) { Fail "No encuentro el .iss: $iss" }
  Info ""
  Info "ISCC  $iss"
  & $Iscc "/O$DesignerDir" $iss
  if ($LASTEXITCODE -ne 0) { Fail "ISCC fallo en $iss (exit $LASTEXITCODE)" }
}

$out = @(Get-ChildItem $DesignerDir -Filter *.exe)
if ($out.Count -lt 4) { Fail "Esperaba 4 instaladores en $DesignerDir, hay $($out.Count)" }
Ok "Tarea 02 OK:"
$out | ForEach-Object { Write-Host ("  {0}  ({1} MB)" -f $_.Name, [math]::Round($_.Length / 1MB, 1)) }
exit 0

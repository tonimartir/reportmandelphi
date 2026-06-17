# Tarea 05 - Empaqueta el binario Linux de printreptopdf:
#   printreptopdf_linux_<ver>.zip   (repman\utils\printreptopdf\binrl64\printreptopdf)
# OJO: el binario Linux NO lo produce el build Windows; debe estar compilado
# (Linux64 Release via PAServer) antes de ejecutar esta tarea.
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 05: zip Linux de printreptopdf (v$Version) =="
New-CleanDir $LinuxDir

$bin = Join-Path $RepoRoot 'repman\utils\printreptopdf\binrl64\printreptopdf'
if (-not (Test-Path $bin)) {
  Fail "No encuentro el binario Linux: $bin  (compila printreptopdf Linux64 Release via PAServer antes)"
}

$zip = Join-Path $LinuxDir ("printreptopdf_linux_{0}.zip" -f $VerU)
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $bin -DestinationPath $zip -Force

Ok ("Tarea 05 OK: {0} ({1} MB)" -f (Split-Path $zip -Leaf), [math]::Round((Get-Item $zip).Length / 1MB, 1))
Info "   Nota: el bit +x no se conserva en un zip hecho en Windows; el usuario hara"
Info "         'chmod +x printreptopdf' tras descomprimir en Linux."
exit 0

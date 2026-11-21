# Tarea 05 - Empaqueta los binarios Linux de printreptopdf y reptotxt:
#   printreptopdf_linux_<ver>.zip   (repman\utils\printreptopdf\binrl64\printreptopdf)
# The Linux binary comes from task 01c (Delphi Linux64 Release, no PAServer).
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 05: zip Linux de printreptopdf (v$Version) =="
# Sin vaciar la carpeta: la tarea 06 deja ahi los paquetes del disenador
# (make-release.ps1 ya vacia release_<v> al empezar)
New-Item -ItemType Directory -Path $LinuxDir -Force | Out-Null

# reptotxt (-xml saves DFM reports as XML) travels in the same zip, so its name stays the one
# the download pages link to
$bins = @(
  (Join-Path $RepoRoot 'repman\utils\printreptopdf\binrl64\printreptopdf'),
  (Join-Path $RepoRoot 'repman\utils\reptotxt\binrl64\reptotxt')
)
foreach ($bin in $bins) {
  if (-not (Test-Path $bin)) {
    Fail "No encuentro el binario Linux: $bin  (run 01c-build-linux64.ps1 first)"
  }
}

$zip = Join-Path $LinuxDir ("printreptopdf_linux_{0}.zip" -f $VerU)
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $bins -DestinationPath $zip -Force

Ok ("Tarea 05 OK: {0} ({1} MB)" -f (Split-Path $zip -Leaf), [math]::Round((Get-Item $zip).Length / 1MB, 1))
Info "   Nota: el bit +x no se conserva en un zip hecho en Windows; el usuario hara"
Info "         'chmod +x printreptopdf reptotxt' tras descomprimir en Linux."
exit 0

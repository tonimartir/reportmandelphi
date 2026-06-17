# Tarea 01 - Build completo de la solucion reportmanxe2 en Release Win32 + Win64.
# Hace build LIMPIO (borra DCUs sueltos en la raiz y los dir dcur32/dcur64 de los
# proyectos de la solucion) para evitar los Internal Errors F2084 por DCU obsoleto.
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 01: build completo de la solucion (Release Win32 + Win64) =="
Info "   Solucion: $GroupProj"
if (-not (Test-Path $GroupProj)) { Fail "No encuentro el group project: $GroupProj" }

Import-RsVars
if (-not (Test-Path $MsBuild)) { Fail "No encuentro MSBuild: $MsBuild" }

# --- Limpieza para build reproducible ---
Info "   Limpiando DCUs obsoletos..."
# (a) DCUs sueltos en la raiz (contaminacion de compilaciones dcc32 standalone)
Get-ChildItem (Join-Path $RepoRoot '*.dcu') -File -ErrorAction SilentlyContinue | Remove-Item -Force
# (b) dir de DCUs Release de los proyectos de la solucion (excluye copias de
#     reportmand7\ y getit\, que no forman parte de reportmanxe2)
$dcuDirs = Get-ChildItem $RepoRoot -Recurse -Directory -Include 'dcur32','dcur64' -ErrorAction SilentlyContinue |
  Where-Object { ($_.FullName -notmatch '\\reportmand7\\') -and ($_.FullName -notmatch '\\getit\\') }
foreach ($d in $dcuDirs) { Remove-Item $d.FullName -Recurse -Force -ErrorAction SilentlyContinue }

foreach ($plat in @('Win32', 'Win64')) {
  Info ""
  Info "== Build  Release / $plat  (/t:Build) =="
  & $MsBuild $GroupProj /t:Build /p:Config=Release /p:Platform=$plat /nologo /v:m
  if ($LASTEXITCODE -ne 0) { Fail "Build fallo en Release/$plat (exit $LASTEXITCODE)" }
}

Ok "Tarea 01 OK: binarios Release Win32 + Win64 generados."
exit 0

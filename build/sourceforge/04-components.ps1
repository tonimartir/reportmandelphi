# Tarea 04 - Components: todos los ARCHIVOS de la raiz del repo + la carpeta
# packages\, limpiando los artefactos *.o y *.dcu. Produce la carpeta de fuentes
# y un zip subible reportman_components_<ver>.zip.
# Se limpia sobre la COPIA (no se toca el arbol fuente).
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 04: Components (fuentes raiz + packages, sin *.o/*.dcu) + zip =="
New-CleanDir $ComponentsDir

$srcName = "reportman_components_$VerU"
$srcDir  = Join-Path $ComponentsDir $srcName
New-Item -ItemType Directory -Path $srcDir -Force | Out-Null

# (a) todos los ficheros sueltos de la raiz, salvo *.o y *.dcu
$rootFiles = Get-ChildItem $RepoRoot -File |
  Where-Object { ($_.Extension -ne '.o') -and ($_.Extension -ne '.dcu') }
foreach ($f in $rootFiles) { Copy-Item $f.FullName $srcDir -Force }

# (b) la carpeta packages\ completa
$pkgSrc  = Join-Path $RepoRoot 'packages'
$pkgDest = Join-Path $srcDir 'packages'
if (-not (Test-Path $pkgSrc)) { Fail "No encuentro la carpeta packages: $pkgSrc" }
Copy-Item $pkgSrc $pkgDest -Recurse -Force

# Segunda pasada: limpia cualquier *.o/*.dcu que viniera dentro de packages\
Get-ChildItem $srcDir -Recurse -Include *.o, *.dcu -File -ErrorAction SilentlyContinue |
  Remove-Item -Force

# zip subible (raiz del zip = reportman_components_<ver>\)
$zip = Join-Path $ComponentsDir "$srcName.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $srcDir -DestinationPath $zip -Force

$nFiles = (Get-ChildItem $srcDir -Recurse -File | Measure-Object).Count
$zipMB  = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Ok ("Tarea 04 OK: {0} ficheros en {1}\, + {2} ({3} MB)" -f $nFiles, $srcName, (Split-Path $zip -Leaf), $zipMB)
exit 0

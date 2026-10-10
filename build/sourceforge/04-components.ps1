# Tarea 04 - Components: todos los ARCHIVOS de la raiz del repo + la carpeta
# packages\ + lcl\, design_lcl\ y rtl_fpc\ (the Lazarus packages need them),
# limpiando los artefactos *.o y *.dcu. Produce la carpeta de fuentes
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

# (a) the loose files of the root that are in git (not the IDE caches such as
#     *.dproj.local, *.identcache or *.stat lying next to them)
$rootFiles = @(& git -C $RepoRoot ls-files) | Where-Object { $_ -notmatch '/' }
if ($rootFiles.Count -eq 0) { Fail "git ls-files found no root files" }
foreach ($f in $rootFiles) { Copy-Item (Join-Path $RepoRoot $f) $srcDir -Force }

# (b) la carpeta packages\ completa
$pkgSrc  = Join-Path $RepoRoot 'packages'
$pkgDest = Join-Path $srcDir 'packages'
if (-not (Test-Path $pkgSrc)) { Fail "No encuentro la carpeta packages: $pkgSrc" }
Copy-Item $pkgSrc $pkgDest -Recurse -Force

# (c) the folders the Lazarus packages in packages\fpc and packages\fpc_lcl take
#     their units from; only the files in git, so no .ppu/.o or backups
foreach ($d in @('lcl', 'design_lcl', 'rtl_fpc')) {
  $files = @(& git -C $RepoRoot ls-files -- $d)
  if ($LASTEXITCODE -ne 0 -or $files.Count -eq 0) { Fail "git ls-files found nothing in $d" }
  foreach ($rel in $files) {
    $dest = Join-Path $srcDir $rel
    New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
    Copy-Item (Join-Path $RepoRoot $rel) $dest -Force
  }
}

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

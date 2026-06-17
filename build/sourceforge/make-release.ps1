# Orquestador del release de SourceForge: ejecuta los subscripts en orden y
# para en el primer fallo. Para depurar uno a uno, ejecuta cada NN-*.ps1 suelto.
#
#   .\make-release.ps1              # build completo + empaquetado
#   .\make-release.ps1 -SkipBuild   # salta la tarea 01 (reusa binarios ya compilados)
[CmdletBinding()]
param([switch]$SkipBuild)
. "$PSScriptRoot\_common.ps1"

Info "==== Release SourceForge  v$Version  ===="
Info "Salida: $ReleaseDir"
New-CleanDir $ReleaseDir

$steps = @()
if (-not $SkipBuild) {
  $steps += '01-build-solution.ps1'
  $steps += '01b-build-net2.ps1'
}
$steps += '02-designer-innosetup.ps1'
$steps += '03-activex-zip.ps1'
$steps += '04-components.ps1'
$steps += '05-linux-zip.ps1'

foreach ($s in $steps) {
  & (Join-Path $PSScriptRoot $s)
  if ($LASTEXITCODE -ne 0) { Fail "Subscript $s fallo (exit $LASTEXITCODE)" }
}

Ok ""
Ok "==== Release $Version COMPLETO ===="
Info "Sube a SourceForge el contenido de:"
Info "  $ReleaseDir"
Get-ChildItem $ReleaseDir -Recurse -File |
  Select-Object @{n='Archivo';e={ $_.FullName.Substring($ReleaseDir.Length + 1) }},
                @{n='MB';     e={ [math]::Round($_.Length / 1MB, 2) }} |
  Format-Table -AutoSize
exit 0

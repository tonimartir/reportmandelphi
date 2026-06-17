# Lanzador del release de SourceForge.
# La logica vive en build\sourceforge\ como subscripts (uno por tarea).
# Ver build\sourceforge\README.md
#
#   .\make-sourceforge.ps1              # build completo + empaquetado
#   .\make-sourceforge.ps1 -SkipBuild   # reusa binarios ya compilados
[CmdletBinding()]
param([switch]$SkipBuild)
& "$PSScriptRoot\sourceforge\make-release.ps1" @PSBoundParameters
exit $LASTEXITCODE

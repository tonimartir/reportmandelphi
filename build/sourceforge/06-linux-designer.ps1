# Tarea 06 - Paquetes Linux del disenador LCL (Report Manager Designer):
#   release_<v>\Linux\reportman-designer_<v>_amd64.deb        (Qt6, recomendado)
#   release_<v>\Linux\reportman-designer-gtk2_<v>_amd64.deb   (GTK2, transitorio)
#   release_<v>\Linux\ReportManDesigner-<v>-x86_64.AppImage   (Qt6)
#   release_<v>\Linux\SHA256SUMS            (todos los ficheros de Linux\)
# Los genera build\linux\build-linux.ps1 con el Docker de WSL: compilacion Qt6
# y GTK2, selftest de ambas, lintian y pruebas en maquinas limpias (ubuntu
# 22.04/24.04/26.04, debian 12/13); si algo falla, esta tarea falla. Con
# -SkipBuild reutiliza los paquetes de build\linux\out\<v>\ si ya existen los
# tres.
[CmdletBinding()]
param([switch]$SkipBuild)
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 06: paquetes Linux del disenador (v$Version) =="
$out      = Join-Path $RepoRoot "build\linux\out\$Version"
$packages = @(
  (Join-Path $out ("reportman-designer_{0}_amd64.deb" -f $Version)),
  (Join-Path $out ("reportman-designer-gtk2_{0}_amd64.deb" -f $Version)),
  (Join-Path $out ("ReportManDesigner-{0}-x86_64.AppImage" -f $Version))
)

$have = @($packages | Where-Object { Test-Path $_ }).Count -eq $packages.Count
if ($SkipBuild -and $have) {
  Info "   -SkipBuild: reutilizo los paquetes de $out"
} else {
  if ($SkipBuild) { Info "   -SkipBuild: faltan paquetes en $out, se generan" }
  & (Join-Path $RepoRoot 'build\linux\build-linux.ps1')
  if ($LASTEXITCODE -ne 0) { Fail "build-linux.ps1 fallo (exit $LASTEXITCODE)" }
}
foreach ($f in $packages) {
  if (-not (Test-Path $f)) { Fail "No encuentro $f" }
}

New-Item -ItemType Directory -Path $LinuxDir -Force | Out-Null
# Paquetes de una version anterior del disenador (p. ej. la AppImage GTK2)
Get-ChildItem $LinuxDir -File | Where-Object {
  $_.Name -like 'reportman-designer*.deb' -or $_.Name -like 'ReportManDesigner-*.AppImage'
} | Remove-Item -Force
Copy-Item -Path $packages -Destination $LinuxDir -Force

# Formato de sha256sum, con LF y sin BOM: en Linux se comprueba con
#   sha256sum -c SHA256SUMS
$sumsFile = Join-Path $LinuxDir 'SHA256SUMS'
$lines = Get-ChildItem $LinuxDir -File | Where-Object { $_.Name -ne 'SHA256SUMS' } |
  Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
  }
[IO.File]::WriteAllText($sumsFile, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))

Ok ("Tarea 06 OK: {0}" -f $LinuxDir)
Get-ChildItem $LinuxDir -File |
  Select-Object Name, @{n='MB'; e={ [math]::Round($_.Length / 1MB, 2) }} |
  Format-Table -AutoSize
exit 0

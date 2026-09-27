# Tarea 06 - Paquetes Linux del disenador LCL (Report Manager Designer, GTK2):
#   release_<v>\Linux\reportman-designer_<v>_amd64.deb
#   release_<v>\Linux\ReportManDesigner-<v>-x86_64.AppImage
#   release_<v>\Linux\SHA256SUMS            (todos los ficheros de Linux\)
# Los genera build\linux\build-linux.ps1 con el Docker de WSL: compilacion,
# selftest, lintian y pruebas en maquinas limpias (ubuntu 22.04/24.04,
# debian 12); si algo falla, esta tarea falla. Con -SkipBuild reutiliza los
# paquetes de build\linux\out\<v>\ si ya existen.
[CmdletBinding()]
param([switch]$SkipBuild)
. "$PSScriptRoot\_common.ps1"

Info "== Tarea 06: paquetes Linux del disenador (v$Version) =="
$out      = Join-Path $RepoRoot "build\linux\out\$Version"
$deb      = Join-Path $out ("reportman-designer_{0}_amd64.deb" -f $Version)
$appimage = Join-Path $out ("ReportManDesigner-{0}-x86_64.AppImage" -f $Version)

if ($SkipBuild -and (Test-Path $deb) -and (Test-Path $appimage)) {
  Info "   -SkipBuild: reutilizo los paquetes de $out"
} else {
  & (Join-Path $RepoRoot 'build\linux\build-linux.ps1')
  if ($LASTEXITCODE -ne 0) { Fail "build-linux.ps1 fallo (exit $LASTEXITCODE)" }
}
foreach ($f in @($deb, $appimage)) {
  if (-not (Test-Path $f)) { Fail "No encuentro $f" }
}

New-Item -ItemType Directory -Path $LinuxDir -Force | Out-Null
Copy-Item -Path $deb, $appimage -Destination $LinuxDir -Force

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

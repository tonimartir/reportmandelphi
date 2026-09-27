# Fase 6: genera los paquetes Linux del disenador (Report Manager Designer,
# LCL Qt6 y GTK2) desde Windows, con el Docker que corre dentro de WSL.
#
#   .\build-linux.ps1               # imagen + compilacion Qt6 y GTK2 + selftest
#                                   # de ambas + los dos .deb + AppImage +
#                                   # pruebas en maquinas limpias
#   .\build-linux.ps1 -SkipTests    # sin las pruebas en contenedores limpios (6.6)
#   .\build-linux.ps1 -SkipImage    # reutiliza la imagen ya construida
#   .\build-linux.ps1 -NoCache      # reconstruye la imagen desde cero
#   .\build-linux.ps1 -Qt5Spike     # ademas compila con --ws=qt5 (no se empaqueta)
#
# El release de SourceForge (build\sourceforge\06-linux-designer.ps1) llama a
# este script y copia los paquetes a release_<v>\Linux\ con SHA256SUMS.
#
# Salida (ignorada por git): build\linux\out\<version>\ con
#   reportman-designer_<v>_amd64.deb        (Qt6, el recomendado)
#   reportman-designer-gtk2_<v>_amd64.deb   (GTK2, transitorio)
#   ReportManDesigner-<v>-x86_64.AppImage   (Qt6)
#   build-info.txt, lintian-<paquete>.txt, selftest-<ws>.log y tests\
#   (registros y capturas).
# La version sale de RM_VERSION en rpmdconsts.pas.
[CmdletBinding()]
param(
  [string]$OutDir,
  [string]$WslDistro,
  [switch]$SkipImage,
  [switch]$NoCache,
  [switch]$SkipTests,
  [switch]$Qt5Spike
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Image    = 'reportman-linux-builder:fpc3.2.2-laz4.8-qt6'

function Fail([string]$m) { Write-Host ""; Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }
function Info([string]$m) { Write-Host $m -ForegroundColor Cyan }
function Ok([string]$m)   { Write-Host $m -ForegroundColor Green }

function Get-RmVersion {
  $f = Join-Path $RepoRoot 'rpmdconsts.pas'
  if (-not (Test-Path $f)) { Fail "No encuentro rpmdconsts.pas: $f" }
  $t = Get-Content $f -Raw
  if ($t -match "RM_VERSION\s*=\s*'([^']+)'") { return $Matches[1] }
  Fail "No pude leer RM_VERSION de $f"
}

$WslPrefix = @()
if ($WslDistro) { $WslPrefix = @('-d', $WslDistro) }

# Ejecuta un programa dentro de WSL (sin shell intermedio: los argumentos
# llegan tal cual) y devuelve su codigo de salida. stderr se muestra como
# texto normal: en PowerShell 5.1, con la salida redirigida, cada linea de
# stderr seria un error que pararia el script con ErrorActionPreference=Stop.
function Invoke-WslRc([string[]]$Cmd) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & wsl.exe @WslPrefix -e @Cmd 2>&1 | ForEach-Object { Write-Host "$_" }
    return $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prev
  }
}

# Igual, pero para el script si falla
function Invoke-Wsl([string]$What, [string[]]$Cmd) {
  $rc = Invoke-WslRc $Cmd
  if ($rc -ne 0) { Fail "$What (codigo $rc)" }
}

function ConvertTo-WslPath([string]$p) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $r = & wsl.exe @WslPrefix -e wslpath -a ($p -replace '\\', '/') 2>$null
    $rc = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prev
  }
  if ($rc -ne 0 -or -not $r) { Fail "wslpath no convierte $p" }
  return ([string]$r).Trim()
}

$Version = Get-RmVersion
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot "build\linux\out\$Version" }
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

if ((Invoke-WslRc @('docker', 'version', '--format', 'Docker {{.Server.Version}}')) -ne 0) {
  Fail 'Docker no responde dentro de WSL (wsl -e docker version)'
}

$WslRepo = ConvertTo-WslPath $RepoRoot
$WslOut  = ConvertTo-WslPath $OutDir
Info "==== Report Manager Designer $Version - paquetes Linux"
Info "Repositorio: $RepoRoot ($WslRepo)"
Info "Salida:      $OutDir"
$sw = [Diagnostics.Stopwatch]::StartNew()

if (-not $SkipImage) {
  Info "== Imagen $Image (build/linux/Dockerfile.builder)"
  $b = @('docker', 'build', '-f', "$WslRepo/build/linux/Dockerfile.builder", '-t', $Image)
  if ($NoCache) { $b += '--no-cache' }
  $b += "$WslRepo/build/linux"
  Invoke-Wsl 'docker build' $b
}

# Fecha de los ficheros empaquetados: la del ultimo commit (builds repetibles)
$Sde = ''
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try { $Sde = [string](& git -C $RepoRoot log -1 --format=%ct 2>$null | Select-Object -First 1) } catch { $Sde = '' }
$ErrorActionPreference = $prevEap
$SdeArgs = @()
if ($Sde -match '^\d+$') { $SdeArgs = @('-e', "SOURCE_DATE_EPOCH=$Sde") }

Info "== Compilacion, selftest y empaquetado (build-in-container.sh)"
Invoke-Wsl 'build-in-container.sh' (@('docker', 'run', '--rm') + $SdeArgs + @(
  '-v', "${WslRepo}:/src:ro", '-v', "${WslOut}:/out", $Image,
  'bash', '/src/build/linux/build-in-container.sh'))

if ($Qt5Spike) {
  Info "== Spike Qt5 (--ws=qt5, solo compilacion y arranque)"
  New-Item -ItemType Directory -Path (Join-Path $OutDir 'qt5-spike') -Force | Out-Null
  $rc = Invoke-WslRc @('docker', 'run', '--rm', '-v', "${WslRepo}:/src:ro",
    '-v', "${WslOut}/qt5-spike:/out", $Image, 'bash', '/src/build/linux/spike-qt5.sh')
  if ($rc -ne 0) { Write-Host "AVISO: el spike Qt5 ha fallado (ver qt5-spike\)" -ForegroundColor Yellow }
}

if (-not $SkipTests) {
  Info "== Pruebas en maquinas limpias (test-packages.sh: 3 paquetes en ubuntu:22.04, ubuntu:24.04, debian:12, debian:13, ubuntu:26.04)"
  Invoke-Wsl 'test-packages.sh' @('bash', "$WslRepo/build/linux/test-packages.sh", $WslOut)
}

$sw.Stop()
Ok ""
Ok ("==== Paquetes Linux {0} OK ({1:N0} s)" -f $Version, $sw.Elapsed.TotalSeconds)
Get-ChildItem $OutDir -File |
  Select-Object Name, @{n='MB'; e={ [math]::Round($_.Length / 1MB, 2) }} |
  Format-Table -AutoSize
exit 0

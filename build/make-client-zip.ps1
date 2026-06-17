<#
.SYNOPSIS
  Construye repmandxp.exe y reportman.ocx (Debug/Release x Win32/Win64),
  los organiza por Producto -> Config -> Plataforma y genera un ZIP para
  entregar a un cliente.

.DESCRIPTION
  Autonomo: no pide nada por consola. Aborta y devuelve exit code != 0 en
  cuanto un build o una copia falla. En Debug incluye el fichero .map.

.PARAMETER Version
  Texto para el nombre de la carpeta/zip. Por defecto se lee la constante
  RM_VERSION de rpmdconsts.pas (la version de producto de Reportman).

.PARAMETER SkipBuild
  Salta la compilacion y solo re-empaqueta lo que ya este compilado
  (util para probar el empaquetado sin esperar al build).

.PARAMETER RsVars / MsBuild
  Rutas alternativas al entorno de RAD Studio y a MSBuild.

.EXAMPLE
  .\make-client-zip.ps1
.EXAMPLE
  .\make-client-zip.ps1 -Version 2.8.0.188
#>
[CmdletBinding()]
param(
  [string]$Version = '',
  [string]$RsVars  = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat',
  [string]$MsBuild = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe',
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$msg) {
  Write-Host ""
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

# --- Rutas base (derivadas de la ubicacion del script) ---
$RepoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$GroupProj = Join-Path $RepoRoot 'repman\reportmanxe2.groupproj'
$DistRoot  = Join-Path $PSScriptRoot 'dist'

if (-not (Test-Path $GroupProj)) { Fail "No encuentro el group project: $GroupProj" }

# --- Version para el nombre de carpeta/zip: constante RM_VERSION de rpmdconsts.pas ---
if (-not $Version) {
  $constFile = Join-Path $RepoRoot 'rpmdconsts.pas'
  if (Test-Path $constFile) {
    $txt = Get-Content $constFile -Raw
    if ($txt -match "RM_VERSION\s*=\s*'([^']+)'") { $Version = $Matches[1] }
  }
  if (-not $Version) {
    Fail "No pude leer RM_VERSION de rpmdconsts.pas. Pasa la version con -Version."
  }
}
$PackName = "reportman_" + ($Version -replace '\.', '_')   # 4.0.8 -> reportman_4_0_8
$StageDir = Join-Path $DistRoot $PackName
$ZipPath  = Join-Path $DistRoot "$PackName.zip"

# --- Matriz de productos ---
#   Name    : carpeta de producto dentro del paquete
#   Target  : target del group project
#   BaseDir : carpeta del .dproj donde el compilador deja las salidas
#   Bin/Map : nombre exacto del binario y de su mapa (se copian POR NOMBRE,
#             nunca por glob, para no arrastrar los dbx*.dll de binr32, etc.)
$Products = @(
  [pscustomobject]@{ Name='repmandxp'; Target='repmandxp'; BaseDir=(Join-Path $RepoRoot 'repman');  Bin='repmandxp.exe'; Map='repmandxp.map' },
  [pscustomobject]@{ Name='activex';   Target='reportman'; BaseDir=(Join-Path $RepoRoot 'activex'); Bin='reportman.ocx'; Map='reportman.map' }
)

# Config + Plataforma -> subcarpeta de salida del compilador Delphi
$OutSub = @{
  'Release|Win32' = 'binr32'
  'Release|Win64' = 'binr64'
  'Debug|Win32'   = 'bin32'
  'Debug|Win64'   = 'bin64'
}
$Configs   = @('Release','Debug')
$Platforms = @('Win32','Win64')

# --- Importa el entorno de rsvars.bat al proceso actual ---
function Import-RsVars([string]$bat) {
  if (-not (Test-Path $bat)) { Fail "No encuentro rsvars.bat: $bat" }
  $dump = cmd /c "call `"$bat`" && set"
  foreach ($line in $dump) {
    if ($line -match '^([^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
  }
}

if (-not $SkipBuild) {
  Write-Host "== Entorno RAD Studio (rsvars) ==" -ForegroundColor Cyan
  Write-Host "   $RsVars"
  Import-RsVars $RsVars

  if (-not (Test-Path $MsBuild)) {
    $cmd = Get-Command msbuild -ErrorAction SilentlyContinue
    if ($cmd) { $MsBuild = $cmd.Source } else { Fail "No encuentro MSBuild: $MsBuild" }
  }
  Write-Host "   MSBuild: $MsBuild"

  # --- Build limpio: elimina DCUs obsoletos ---
  # (a) DCUs sueltos en la raiz del repo. La raiz esta en el search path, asi
  #     que un .dcu dejado ahi por una compilacion dcc32 standalone (con
  #     $IFDEF distintos) hace reventar al compilador con un Internal Error
  #     F2084. El build canonico nunca deja DCUs en la raiz.
  $strayDcus = @(Get-ChildItem (Join-Path $RepoRoot '*.dcu') -File -ErrorAction SilentlyContinue)
  if ($strayDcus.Count -gt 0) {
    Write-Host "   Limpiando $($strayDcus.Count) DCU(s) sueltos en la raiz del repo" -ForegroundColor Yellow
    $strayDcus | Remove-Item -Force
  }
  # (b) Dir de DCUs de cada producto. El build por defecto es incremental y
  #     reutiliza DCUs del dir de salida; si una config poco compilada (p.ej.
  #     Debug/Win64) tiene DCUs viejos con interfaces que ya cambiaron, el
  #     compilador tambien reviente con F2084. Borrarlos fuerza recompilacion
  #     coherente y binarios frescos. Se recrean al compilar.
  foreach ($p in $Products) {
    foreach ($d in @('dcur32', 'dcur64', 'dcu32', 'dcu64')) {
      $dd = Join-Path $p.BaseDir $d
      if (Test-Path $dd) { Remove-Item $dd -Recurse -Force }
    }
  }

  foreach ($cfg in $Configs) {
    foreach ($plat in $Platforms) {
      Write-Host ""
      Write-Host "== Build  $cfg / $plat ==" -ForegroundColor Cyan
      $mbArgs = @(
        $GroupProj,
        '/t:repmandxp;reportman',
        "/p:Config=$cfg",
        "/p:Platform=$plat",
        '/nologo', '/v:m'
      )
      # Forzar mapa detallado en Debug (repmandxp/Win64 no lo trae en el dproj)
      if ($cfg -eq 'Debug') { $mbArgs += '/p:DCC_MapFile=3' }

      & $MsBuild @mbArgs
      if ($LASTEXITCODE -ne 0) { Fail "MSBuild fallo en $cfg / $plat (exit $LASTEXITCODE)" }
    }
  }
}

# --- Stage limpio ---
Write-Host ""
Write-Host "== Empaquetando ==" -ForegroundColor Cyan
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
if (Test-Path $ZipPath)  { Remove-Item $ZipPath -Force }
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

$missing = @()
foreach ($p in $Products) {
  foreach ($cfg in $Configs) {
    foreach ($plat in $Platforms) {
      $sub     = $OutSub["$cfg|$plat"]
      $srcDir  = Join-Path $p.BaseDir $sub
      $destDir = Join-Path $StageDir (Join-Path $p.Name (Join-Path $cfg $plat))
      New-Item -ItemType Directory -Path $destDir -Force | Out-Null

      $srcBin = Join-Path $srcDir $p.Bin
      if (Test-Path $srcBin) { Copy-Item $srcBin $destDir -Force }
      else { $missing += $srcBin }

      if ($cfg -eq 'Debug') {
        $srcMap = Join-Path $srcDir $p.Map
        if (Test-Path $srcMap) { Copy-Item $srcMap $destDir -Force }
        else { $missing += $srcMap }
      }
    }
  }
}

if ($missing.Count -gt 0) {
  Write-Host "Faltan archivos esperados:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  - $_" }
  Fail "Empaquetado incompleto."
}

# --- ZIP (incluye la carpeta '$PackName' como raiz del archivo) ---
Compress-Archive -Path $StageDir -DestinationPath $ZipPath -Force

# --- Resumen ---
Write-Host ""
Write-Host "== OK ==" -ForegroundColor Green
Write-Host "Carpeta: $StageDir"
$zipMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
Write-Host "ZIP:     $ZipPath  ($zipMB MB)"
Write-Host ""
Get-ChildItem $StageDir -Recurse -File |
  Select-Object @{n='Archivo';e={ $_.FullName.Substring($StageDir.Length + 1) }},
                @{n='KB';     e={ [math]::Round($_.Length / 1KB, 1) }} |
  Format-Table -AutoSize

exit 0

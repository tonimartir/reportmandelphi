# Helpers compartidos por los subscripts del release de SourceForge.
# Se incluye con dot-source desde cada subscript:  . "$PSScriptRoot\_common.ps1"
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path   # ...\reportman
$SfDir      = $PSScriptRoot                                           # ...\build\sourceforge
$GroupProj  = Join-Path $RepoRoot 'repman\reportmanxe2.groupproj'
$InstallDir = Join-Path $RepoRoot 'install'
$RsVars     = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'
$MsBuild    = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
$Iscc       = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'

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

$Version       = Get-RmVersion          # 4.0.8
$VerU          = $Version -replace '\.', '_'   # 4_0_8
$ReleaseDir    = Join-Path $SfDir "release_$VerU"
$DesignerDir   = Join-Path $ReleaseDir 'Designer'
$ActiveXDir    = Join-Path $ReleaseDir 'ActiveX'
$ComponentsDir = Join-Path $ReleaseDir 'Components'
$LinuxDir      = Join-Path $ReleaseDir 'Linux'

function Import-RsVars {
  if (-not (Test-Path $RsVars)) { Fail "No encuentro rsvars.bat: $RsVars" }
  cmd /c "call `"$RsVars`" && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process') }
  }
}

function New-CleanDir([string]$p) {
  if (Test-Path $p) { Remove-Item $p -Recurse -Force }
  New-Item -ItemType Directory -Path $p -Force | Out-Null
}

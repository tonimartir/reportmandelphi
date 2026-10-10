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

# Zip of a folder with '/' in the entry names. Compress-Archive of Windows
# PowerShell 5.1 writes '\', which the zip format does not allow: 7-Zip or
# unzip on Linux then make flat files named "dir\file.pas".
# With -IncludeBaseDirectory the entries start with the folder's own name.
function New-ZipFromFolder([string]$folder, [string]$zip, [switch]$IncludeBaseDirectory) {
  Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
  $folder = (Resolve-Path $folder).Path.TrimEnd('\')
  $prefix = if ($IncludeBaseDirectory) { (Split-Path $folder -Leaf) + '/' } else { '' }
  if (Test-Path $zip) { Remove-Item $zip -Force }
  $archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
  try {
    foreach ($f in Get-ChildItem $folder -Recurse -File) {
      $name = $prefix + $f.FullName.Substring($folder.Length + 1).Replace('\', '/')
      [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $name, 'Optimal')
    }
  } finally { $archive.Dispose() }
}

function New-CleanDir([string]$p) {
  if (Test-Path $p) { Remove-Item $p -Recurse -Force }
  New-Item -ItemType Directory -Path $p -Force | Out-Null
}

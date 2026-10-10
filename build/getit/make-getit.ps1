# GetIt package of Report Manager for RAD Studio 13 (Delphi 13.x).
#
#   .\make-getit.ps1              sync, version, clean-room build, zip
#   .\make-getit.ps1 -NoSync      keep getit\Source\Common as it is
#
# 1. Sync: every file already in getit\Source\Common is refreshed from the
#    repository root (or server\web); rpconf.inc is not, it is the GetIt
#    configuration (no BDE, Zeos, IBX, TeeChart, Indy or dbExpress). A new
#    unit is added by copying it there once and listing it in the .dpk/.dproj.
# 2. Version and date from RM_VERSION into package.json and
#    reportman_package.json.
# 3. Clean-room build: the package is copied to a folder laid out like the
#    IDE's CatalogRepository and built with MSBuild against a copy of the
#    IDE's EnvOptions.proj whose Win32/Win64 library path keeps only the
#    Delphi folders plus the Source\Common path GetIt adds, so nothing from the
#    developer's library path (the repository root, Zeos...) can fill a gap.
#    The three packages and the two examples are built for Win32 and Win64,
#    Debug, as package.json asks. It fails when a unit is implicitly imported
#    into a package (W1033: it would end up in two packages) or when a package
#    imports a .bpl that is not part of RAD Studio.
# 4. Zip of the files of getit\ in git, for the GetIt submission form.
[CmdletBinding()]
param([switch]$NoSync)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$GetIt    = Join-Path $RepoRoot 'getit'
$Common   = Join-Path $GetIt 'Source\Common'
$Studio   = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$RsVars   = Join-Path $Studio 'bin\rsvars.bat'
$MsBuild  = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
$UserEnv  = Join-Path $env:APPDATA 'Embarcadero\BDS\37.0\EnvOptions.proj'
$Work     = Join-Path $env:TEMP 'reportman-getit'
$OutDir   = Join-Path $PSScriptRoot 'out'

function Fail([string]$m) { Write-Host ""; Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }
function Info([string]$m) { Write-Host $m -ForegroundColor Cyan }
function Ok([string]$m)   { Write-Host $m -ForegroundColor Green }

$consts = Get-Content (Join-Path $RepoRoot 'rpmdconsts.pas') -Raw
if ($consts -notmatch "RM_VERSION\s*=\s*'([^']+)'") { Fail 'RM_VERSION not found' }
$Version = $Matches[1]
Info "==== GetIt package $Version (RAD Studio 13) ===="

# --- 1. Sync ---------------------------------------------------------------
if (-not $NoSync) {
  $n = 0; $missing = @()
  foreach ($f in Get-ChildItem $Common -File) {
    if ($f.Name -eq 'rpconf.inc') { continue }
    $src = @((Join-Path $RepoRoot $f.Name), (Join-Path $RepoRoot "server\web\$($f.Name)")) |
      Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $src) { $missing += $f.Name; continue }
    if ((Get-FileHash $src).Hash -ne (Get-FileHash $f.FullName).Hash) {
      Copy-Item $src $f.FullName -Force; $n++
    }
  }
  if ($missing) { Fail ("Not in the repository any more (remove them from getit and the packages): " + ($missing -join ', ')) }
  Ok "Sync: $n files refreshed"
}

# --- 2. Version ------------------------------------------------------------
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
foreach ($j in 'package.json', 'reportman_package.json') {
  $p = Join-Path $GetIt $j
  $t = [IO.File]::ReadAllText($p)
  $t = [regex]::Replace($t, '"Version":\s*"[^"]*"', "`"Version`": `"$Version`"")
  $t = [regex]::Replace($t, '"Modified":\s*"[^"]*"', "`"Modified`": `"$stamp`"")
  [IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding $false))
}
Ok "Version: $Version ($stamp)"

# --- 3. Clean-room build ---------------------------------------------------
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
$Catalog = Join-Path $Work 'CatalogRepository\Reportman'
New-Item -ItemType Directory -Force $Catalog | Out-Null
Copy-Item (Join-Path $GetIt '*') $Catalog -Recurse -Force
$CatCommon = Join-Path $Catalog 'Source\Common'

$envText = [IO.File]::ReadAllText($UserEnv)
$std = '$(BDSLIB)\$(Platform)\release;$(BDSUSERDIR)\Imports;$(BDS)\Imports;$(BDS)\include'
foreach ($plat in 'Win32', 'Win64') {
  $out = Join-Path $Work "out\$plat"
  New-Item -ItemType Directory -Force $out | Out-Null
  $m = [regex]::Match($envText, "(<PropertyGroup Condition=`"'\`$\(Platform\)'=='$plat'`">)(.*?)(</PropertyGroup>)", 'Singleline')
  if (-not $m.Success) { Fail "No $plat group in $UserEnv" }
  $body = $m.Groups[2].Value
  $values = @{ DelphiLibraryPath = "$std;$out;$CatCommon"; DelphiDCPOutput = $out; DelphiDLLOutputPath = $out; DelphiBrowsingPath = '' }
  foreach ($tag in $values.Keys) {
    $v = $values[$tag]
    $body = [regex]::Replace($body, "<$tag>.*?</$tag>", { param($x) "<$tag>$v</$tag>" }.GetNewClosure(), 'Singleline')
  }
  $envText = $envText.Substring(0, $m.Groups[2].Index) + $body + $envText.Substring($m.Groups[2].Index + $m.Groups[2].Length)
}
$CleanEnv = Join-Path $Work 'EnvOptions.clean.proj'
[IO.File]::WriteAllText($CleanEnv, $envText, (New-Object Text.UTF8Encoding $false))

cmd /c "call `"$RsVars`" && set" | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process') }
}

function Build([string]$proj, [string]$plat, [string]$label, [string[]]$extra = @()) {
  $log = Join-Path $Work "$label-$plat.log"
  Push-Location (Split-Path $proj -Parent)
  try {
    & $MsBuild (Split-Path $proj -Leaf) /t:Build /p:Config=Debug "/p:Platform=$plat" "/p:EnvOptions=$CleanEnv" @extra /nologo /v:m 2>&1 |
      Out-File $log -Encoding utf8
    $code = $LASTEXITCODE
  } finally { Pop-Location }
  if ($code -ne 0) {
    Select-String -Path $log -Pattern 'Fatal:|error ' | Select-Object -First 10 | ForEach-Object { Write-Host ('   ' + $_.Line.Trim()) }
    Fail "$label $plat failed (log $log)"
  }
  $implicit = @(Select-String -Path $log -Pattern "W1033[^']*'([^']+)'" -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  if ($implicit) { Fail "$label $plat implicitly imports: $($implicit -join ', ') (add them to a package)" }
  Ok ("  {0,-22} {1}" -f $label, $plat)
}

# The DLL names in the import table of a PE file (32 or 64 bits). tdump is not
# used: given its arguments from a script it can take the .bpl as its output
# file and wait on standard input.
function Get-PeImports([string]$path) {
  $b = [IO.File]::ReadAllBytes($path)
  $pe = [BitConverter]::ToInt32($b, 0x3C)
  if ([BitConverter]::ToUInt32($b, $pe) -ne 0x4550) { Fail "$path is not a PE file" }
  $coff = $pe + 4
  $nsec = [BitConverter]::ToUInt16($b, $coff + 2)
  $optSize = [BitConverter]::ToUInt16($b, $coff + 16)
  $opt = $coff + 20
  $dirs = if ([BitConverter]::ToUInt16($b, $opt) -eq 0x20B) { $opt + 112 } else { $opt + 96 }
  $impRva = [BitConverter]::ToUInt32($b, $dirs + 8)
  $sec = $opt + $optSize
  $toOff = {
    param($rva)
    for ($i = 0; $i -lt $nsec; $i++) {
      $s = $sec + 40 * $i
      $va = [BitConverter]::ToUInt32($b, $s + 12); $size = [BitConverter]::ToUInt32($b, $s + 8)
      if ($size -eq 0) { $size = [BitConverter]::ToUInt32($b, $s + 16) }
      if ($rva -ge $va -and $rva -lt $va + $size) { return $rva - $va + [BitConverter]::ToUInt32($b, $s + 20) }
    }
    return -1
  }
  $names = @()
  $d = & $toOff $impRva
  while ($d -ge 0) {
    $nameRva = [BitConverter]::ToUInt32($b, $d + 12)
    if ($nameRva -eq 0) { break }
    $o = & $toOff $nameRva
    $e = $o; while ($b[$e] -ne 0) { $e++ }
    $names += [Text.Encoding]::ASCII.GetString($b, $o, $e - $o)
    $d += 20
  }
  return $names
}

$Allowed = '^(rtl|dbrtl|dsnap|adortl|xmlrtl|designide|vcl[a-z]*|FireDAC[A-Za-z]*|reportman_(rtl|vcl|designvcl))370\.bpl$|^reportman_(rtl|vcl|designvcl)\.bpl$'
foreach ($plat in 'Win32', 'Win64') {
  foreach ($pkg in 'reportman_rtl', 'reportman_vcl', 'reportman_designvcl') {
    Build (Join-Path $Catalog "Source\Delphi\$pkg.dproj") $plat $pkg
    $bpl = Join-Path $Work "out\$plat\$pkg.bpl"
    $imports = @(Get-PeImports $bpl | Where-Object { $_ -match '\.bpl$' } | Sort-Object -Unique)
    if (-not $imports) { Fail "No package imports found in $bpl" }
    $foreign = @($imports | Where-Object { $_ -notmatch $Allowed })
    if ($foreign) { Fail "$pkg $plat imports packages that are not part of RAD Studio: $($foreign -join ', ')" }
    Write-Host ("     requires at run time: " + (($imports | ForEach-Object { $_ -replace '370\.bpl$|\.bpl$', '' }) -join ' '))
  }
  foreach ($ex in 'VCLDemo\VCLDemo.dproj', 'CreatePDF\CreatePDF.dproj') {
    $exe = Join-Path $Work "out\examples\$plat"
    Build (Join-Path $Catalog "Source\Examples\$ex") $plat ([IO.Path]::GetFileNameWithoutExtension($ex)) @("/p:DCC_ExeOutput=$exe")
  }
}

# --- 4. Zip ----------------------------------------------------------------
New-Item -ItemType Directory -Force $OutDir | Out-Null
$zip = Join-Path $OutDir "Reportman-getit-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
$stage = Join-Path $Work 'zip'
New-Item -ItemType Directory -Force $stage | Out-Null
$files = @(& git -C $RepoRoot ls-files -- getit)
foreach ($rel in $files) {
  $dest = Join-Path $stage ($rel.Substring('getit/'.Length))
  New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
  Copy-Item (Join-Path $RepoRoot $rel) $dest -Force
}
# Not Compress-Archive: Windows PowerShell 5.1 writes '\' in the entry names
. (Join-Path $RepoRoot 'build\sourceforge\_common.ps1')
New-ZipFromFolder $stage $zip
Ok ("Zip: {0} ({1:n1} MB, {2} files)" -f $zip, ((Get-Item $zip).Length / 1MB), $files.Count)
Info "Commit getit\ before zipping again: the zip takes the files git knows."
exit 0

<#
.SYNOPSIS
  Genera el paquete de Report Manager para el Online Package Manager (OPM) de
  Lazarus: el zip de repositorio, la entrada JSON de la lista de paquetes y el
  JSON externo de actualizaciones. No sube nada a ningun sitio.

.DESCRIPTION
  Pasos:
   1. Lee RM_VERSION de rpmdconsts.pas y sincroniza la version de los tres .lpk
      (packages\fpc\reportman_rtl.lpk, packages\fpc_lcl\reportman_lcl.lpk,
      packages\fpc_lcl\reportman_designlcl.lpk), incluida la version minima con
      la que se requieren entre ellos. Si cambia algo en el arbol de trabajo lo
      avisa: hay que hacer commit, porque el zip sale de git.
   2. Extrae de "git archive <Ref>" solo los ficheros de build\opm\opm_files.txt,
      con la estructura del repositorio (las rutas ..\..\ de los .lpk siguen
      valiendo) y fin de linea CRLF fijo (core.autocrlf=true), de modo que el
      resultado no depende de la configuracion de git de la maquina.
   3. Crea <Nombre>.zip con una unica carpeta raiz (<BaseDir>/...), igual que
      el formulario "Create repository package" de OPM
      (opkman_createrepositorypackagefrm.pas + opkman_zipper.pas): solo
      ficheros, rutas con '/', fecha de las entradas = fecha del commit.
   4. Escribe <Nombre>.json (PackageData0/PackageFiles0, mismo formato que
      TSerializablePackages.PackagesToJSON: tamano, MD5 en minusculas,
      RepositoryDate = Now como TDateTime) y update_<Nombre>.json (formato de
      TUpdatePackage.SaveToJSON), donde <Nombre> = DisplayName sin espacios.
   5. Con -Validate / -ValidateWsl comprueba los artefactos como un usuario
      nuevo de OPM: opm_check (fpjson + TUnZipper de FPC) descomprime el zip,
      se registra Zeos en una configuracion de Lazarus PRIVADA (--pcp) y se
      compilan los tres paquetes desde la copia extraida, en orden de
      dependencias y con compilacion limpia (-B), como hace el instalador de
      OPM (opkman_installer.pas: pcfCleanCompile).

  Salida en build\opm\out\ (ignorada por git).

.PARAMETER Ref
  Commit/rama/tag de git del que se empaqueta. Por defecto HEAD.

.PARAMETER Validate
  Valida en Windows con lazbuild (-LazBuild) y Zeos (-ZeosDir).

.PARAMETER ValidateWsl
  Valida tambien en Linux dentro de WSL (lazbuild del PATH de WSL, gtk2).

.PARAMETER RefreshFileList
  No empaqueta: lee los .ppu de un build previo del arbol de trabajo
  (packages\fpc\build_fpc.bat) con ppudump y anade a opm_files.txt los
  ficheros que falten. Lista, sin borrarlos, los que ya no aparecen.

.PARAMETER NoSync
  No toca los .lpk del arbol de trabajo (la copia empaquetada se sincroniza
  siempre).

.EXAMPLE
  .\make_opm_package.ps1
.EXAMPLE
  .\make_opm_package.ps1 -Validate -ValidateWsl
.EXAMPLE
  .\make_opm_package.ps1 -RefreshFileList
#>
[CmdletBinding()]
param(
  [string]$Ref = 'HEAD',
  [string]$OutDir,
  [string]$BaseDir = 'reportman',
  [string]$DisplayName = 'Report Manager',
  [string]$Category = 'Reporting',
  [string]$HomePageURL = 'https://reportman.es',
  [string]$SVNURL = 'https://github.com/tonimartir/reportmandelphi',
  [string]$UpdateBaseURL = 'https://reportman.es/opm/',
  [string]$CommunityDescription = 'Report Manager: banded report engine and visual report designer. Reports are stored as .rep files, previewed and printed with the LCL, and exported to PDF, SVG, HTML, CSV and text. Also available for Delphi (VCL) and .NET.',
  [string]$ExternalDependencies = 'Nothing extra is needed to compile. At run time some features load optional native libraries on demand: FreeType, HarfBuzz and ICU for advanced text shaping in PDF/SVG output, fontconfig on Linux, the client library of the database used through Zeos or SQLdb (the FireDAC connections: SQLite, PostgreSQL, MySQL/MariaDB, Firebird, SQL Server, Oracle, ODBC) and, on Windows, WebView2Loader.dll plus the Microsoft Edge WebView2 Runtime for the Monaco SQL editor and the AI chat of the designer (without them, and on Linux, the SQL editor is a SynEdit and the chat uses the TurboPower IPro HTML viewer, both included with Lazarus).',
  [string]$LazCompatibility = 'Trunk, 4.8.0, 4.6.0, 4.4.0, 4.2.0, 4.0.0, 3.8.0, 3.6.0, 3.4.0, 3.2.0, 3.0.0',
  [string]$FPCCompatibility = '3.2.2',
  [string]$SupportedWidgetSet = 'win32/win64, gtk2, gtk3, qt, qt5, qt6',
  [switch]$ForceNotify,
  [int]$InternalVersion = 1,
  [switch]$Validate,
  [switch]$ValidateWsl,
  [string]$LazBuild = 'C:\lazarus\lazbuild.exe',
  [string]$Fpc,
  [string]$ZeosDir = 'C:\desarrollo\tools\delphicomponents\zeosxe10',
  [string]$WslWidgetSet = 'gtk2',
  [switch]$RefreshFileList,
  [string]$Target = 'x86_64-win64',
  [switch]$NoSync
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot 'out' }
$Manifest = Join-Path $PSScriptRoot 'opm_files.txt'
$Lpks = @('packages/fpc/reportman_rtl.lpk', 'packages/fpc_lcl/reportman_lcl.lpk', 'packages/fpc_lcl/reportman_designlcl.lpk')
$SiblingPkgs = @('reportman_rtl', 'reportman_lcl', 'reportman_designlcl')
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Inv = [Globalization.CultureInfo]::InvariantCulture

function Fail([string]$msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Info([string]$msg) { Write-Host $msg -ForegroundColor Cyan }
function Warn([string]$msg) { Write-Host "AVISO: $msg" -ForegroundColor Yellow }

function Invoke-Git {
  $out = & git -C $RepoRoot @args
  if ($LASTEXITCODE -ne 0) { Fail "git $($args -join ' ') ha fallado" }
  return $out
}

# Ejecuta un programa externo capturando stdout+stderr como texto. Devuelve
# @(exitcode, lineas). (En Windows PowerShell 5.1, 2>&1 con
# ErrorActionPreference=Stop aborta en la primera linea de stderr.)
function Invoke-Exe([string]$Exe, [string[]]$Arguments) {
  $ErrorActionPreference = 'Continue'
  $out = @(& $Exe @Arguments 2>&1 | ForEach-Object { "$_" })
  return @($LASTEXITCODE, $out)
}

# ---------------------------------------------------------------- versiones
function Get-RmVersion([string]$text, [string]$where) {
  if ($text -notmatch "RM_VERSION\s*=\s*'([0-9]+(\.[0-9]+){0,3})'") { Fail "No encuentro RM_VERSION en $where" }
  $parts = @($Matches[1].Split('.') | ForEach-Object { [int]$_ })
  while ($parts.Count -lt 4) { $parts += 0 }
  return ,$parts
}

# Atributos como los escribe Lazarus (TPkgVersion): se omiten los ceros.
function Format-LazVersionAttrs([int[]]$v) {
  $names = 'Major', 'Minor', 'Release', 'Build'
  $parts = @()
  for ($i = 0; $i -lt 4; $i++) { if ($v[$i] -ne 0) { $parts += ('{0}="{1}"' -f $names[$i], $v[$i]) } }
  return ($parts -join ' ')
}

# Version "A.B.C.D" como la escribe OPM (VersionAsString)
function Format-Version4([int[]]$v) { return ('{0}.{1}.{2}.{3}' -f $v[0], $v[1], $v[2], $v[3]) }

# Sincroniza <Version .../> del paquete y <MinVersion .../> de las dependencias
# entre los paquetes de Report Manager, a nivel de texto (sin reformatear el XML).
function Sync-LpkText([string]$text, [int[]]$ver) {
  $attrs = Format-LazVersionAttrs $ver
  $rxVer = New-Object regex '(?m)^([ \t]*)<Version(?:\s+(?:Major|Minor|Release|Build)="\d+")*\s*/>(\r?)$'
  $n = $rxVer.Matches($text).Count
  if ($n -gt 1) { throw 'hay mas de un <Version Major=...> de paquete' }
  if ($n -eq 1) {
    $text = $rxVer.Replace($text, { param($m) "$($m.Groups[1].Value)<Version $attrs/>$($m.Groups[2].Value)" })
  } else {
    $rxFiles = New-Object regex '(?m)^([ \t]*)<Files Count='
    $m = $rxFiles.Match($text)
    if (-not $m.Success) { throw 'no encuentro <Files Count=...> para insertar <Version>' }
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $text = $text.Insert($m.Index, "$($m.Groups[1].Value)<Version $attrs/>$nl")
  }
  foreach ($dep in $SiblingPkgs) {
    $rxMin = New-Object regex ('(?m)^([ \t]*)<PackageName Value="' + $dep + '"/>(\r?\n)[ \t]*<MinVersion[^>]*/>')
    $text = $rxMin.Replace($text, { param($m) "$($m.Groups[1].Value)<PackageName Value=`"$dep`"/>$($m.Groups[2].Value)$($m.Groups[1].Value)<MinVersion $attrs Valid=`"True`"/>" })
    $rxNoMin = New-Object regex ('(?m)^([ \t]*)<PackageName Value="' + $dep + '"/>(\r?\n)(?![ \t]*<MinVersion)')
    $text = $rxNoMin.Replace($text, { param($m) "$($m.Groups[1].Value)<PackageName Value=`"$dep`"/>$($m.Groups[2].Value)$($m.Groups[1].Value)<MinVersion $attrs Valid=`"True`"/>$($m.Groups[2].Value)" })
  }
  return $text
}

function Sync-LpkFile([string]$path, [int[]]$ver) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $text = $Utf8NoBom.GetString($bytes, [int]$bom * 3, $bytes.Length - [int]$bom * 3)
  $new = Sync-LpkText $text $ver
  if ($new -ceq $text) { return $false }
  $enc = New-Object System.Text.UTF8Encoding($bom)
  [IO.File]::WriteAllText($path, $new, $enc)
  return $true
}

# ---------------------------------------------------------------- manifiesto
function Read-Manifest {
  if (-not (Test-Path $Manifest)) { Fail "No existe $Manifest" }
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($line in [IO.File]::ReadAllLines($Manifest)) {
    $p = ($line -replace '#.*$', '').Trim()
    if ($p) { $list.Add(($p -replace '\\', '/')) }
  }
  return ,$list.ToArray()
}

# ---------------------------------------------------------------- herramientas FPC
function Find-FpcTool([string]$exe) {
  if ($Fpc) {
    $cand = Join-Path (Split-Path $Fpc -Parent) $exe
    if (Test-Path $cand) { return $cand }
  }
  $lazDir = Split-Path $LazBuild -Parent
  $hit = Get-ChildItem (Join-Path $lazDir 'fpc') -Recurse -Filter $exe -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match 'bin\\x86_64-win64$|bin\\i386-win32$' } | Select-Object -First 1
  if (-not $hit) { Fail "No encuentro $exe bajo $lazDir\fpc (usa -Fpc)" }
  return $hit.FullName
}

function ConvertTo-WslPath([string]$p) {
  $full = [IO.Path]::GetFullPath($p)
  if ($full -notmatch '^([A-Za-z]):\\(.*)$') { Fail "Ruta no convertible a WSL: $full" }
  return '/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
}

# ================================================================ -RefreshFileList
if ($RefreshFileList) {
  $isLinux = $Target -like '*-linux'
  $ppudump = $null
  if (-not $isLinux) { $ppudump = Find-FpcTool 'ppudump.exe' }
  # paquete -> carpeta de .ppu, rutas de unidades (carpeta del .lpk primero) y de include
  $pkgs = @(
    @{ Lib = "packages\fpc\lib\$Target"; Fu = @('packages\fpc', '', 'rtl_fpc'); Fi = @('') },
    @{ Lib = "packages\fpc_lcl\lib\reportman_lcl\$Target"; Fu = @('packages\fpc_lcl', 'lcl'); Fi = @('') },
    @{ Lib = "packages\fpc_lcl\lib\reportman_designlcl\$Target"; Fu = @('packages\fpc_lcl', 'design_lcl'); Fi = @('', 'lcl', 'design_lcl') }
  )
  $gitFiles = @{}
  foreach ($g in (Invoke-Git ls-files)) { $gitFiles[$g.ToLower()] = $g }
  function Find-In([string[]]$dirs, [string]$name) {
    foreach ($d in $dirs) {
      $rel = if ($d) { ($d -replace '\\', '/') + '/' + $name } else { $name }
      $full = [IO.Path]::GetFullPath((Join-Path $RepoRoot $rel))
      if (-not $full.StartsWith($RepoRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
      $rel = ($full.Substring($RepoRoot.Length + 1) -replace '\\', '/').ToLower()
      if ($gitFiles.ContainsKey($rel)) { return $gitFiles[$rel] }
    }
    return $null
  }
  $found = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($l in $Lpks + @('LICENSE.TXT')) { [void]$found.Add($l) }
  $unresolved = @()
  foreach ($pk in $pkgs) {
    $libDir = Join-Path $RepoRoot $pk.Lib
    if (-not (Test-Path $libDir)) { Fail "No existe $libDir. Compila antes con packages\fpc\build_fpc.bat (o build_fpc.sh para Linux)." }
    foreach ($ppu in Get-ChildItem $libDir -Filter *.ppu) {
      # ppudump de Windows no sabe leer las fechas de un .ppu de Linux: en ese caso el de WSL
      if ($isLinux) { $r = Invoke-Exe 'wsl' @('-e', 'ppudump', '-vi', (ConvertTo-WslPath $ppu.FullName)) }
      else { $r = Invoke-Exe $ppudump @('-vi', $ppu.FullName) }
      if ($r[0] -ne 0) { Fail "ppudump ha fallado con $($ppu.FullName)" }
      $out = $r[1]
      $unitRel = $null
      foreach ($line in $out) {
        $hit = $null
        if ($line -match '^Source file (\d+) : (\S+)') {
          $name = $Matches[2]
          if ([int]$Matches[1] -eq 1) { $unitRel = Find-In $pk.Fu $name; $hit = $unitRel }
          else {
            $ud = if ($unitRel) { Split-Path $unitRel -Parent } else { '' }
            $hit = Find-In (@($ud) + $pk.Fi) $name
          }
        } elseif ($line -match '^Resource file: (\S+)') {
          $name = $Matches[1]
          $ud = if ($unitRel) { Split-Path $unitRel -Parent } else { '' }
          $hit = Find-In (@($ud) + $pk.Fi + @('')) $name
        } else { continue }
        if ($hit) { [void]$found.Add($hit) } else { $unresolved += "$($ppu.Name): $name" }
      }
    }
  }
  $current = Read-Manifest
  $curSet = New-Object 'System.Collections.Generic.HashSet[string]' (, [string[]]$current)
  $added = @($found | Where-Object { -not $curSet.Contains($_) } | Sort-Object)
  $unused = @($current | Where-Object { -not $found.Contains($_) })
  foreach ($u in $unresolved) { Warn "sin resolver (fuera del repositorio o no versionado): $u" }
  if ($added.Count -gt 0) {
    $block = @('', "# --- anadidos por -RefreshFileList ($Target, $(Get-Date -Format 'yyyy-MM-dd')) ---") + $added
    [IO.File]::AppendAllText($Manifest, (($block -join "`r`n") + "`r`n"), $Utf8NoBom)
    Info "Anadidos a opm_files.txt ($($added.Count)):"; $added | ForEach-Object { "  $_" }
  } else { Info 'opm_files.txt ya contiene todos los ficheros usados por el build.' }
  if ($unused.Count -gt 0) {
    Warn "en opm_files.txt pero no usados por el build $Target (pueden ser de otra plataforma; revisalos a mano):"
    $unused | ForEach-Object { "  $_" }
  }
  exit 0
}

# ================================================================ 1. versiones
$wtConsts = Join-Path $RepoRoot 'rpmdconsts.pas'
$wtVer = Get-RmVersion ([IO.File]::ReadAllText($wtConsts)) $wtConsts
$refVer = Get-RmVersion ((Invoke-Git show "${Ref}:rpmdconsts.pas") -join "`n") "${Ref}:rpmdconsts.pas"
$wtVerStr = Format-Version4 $wtVer
$refVerStr = Format-Version4 $refVer
Info "RM_VERSION: $refVerStr en $Ref (arbol de trabajo: $wtVerStr)"
if ($wtVerStr -ne $refVerStr) { Warn "RM_VERSION del arbol de trabajo no coincide con $Ref; el zip se genera desde $Ref." }

if (-not $NoSync) {
  $changed = @()
  foreach ($l in $Lpks) {
    if (Sync-LpkFile (Join-Path $RepoRoot $l) $wtVer) { $changed += $l }
  }
  if ($changed.Count -gt 0) {
    Warn ("versiones sincronizadas con RM_VERSION en el arbol de trabajo: " + ($changed -join ', ') + ". Haz commit: el zip se genera desde git.")
  } else { Info 'Los .lpk del arbol de trabajo ya tienen la version de RM_VERSION.' }
}

# ================================================================ 2. staging
$files = Read-Manifest
$inRef = New-Object 'System.Collections.Generic.HashSet[string]' (, [string[]](Invoke-Git ls-tree -r --name-only $Ref))
$missing = @($files | Where-Object { -not $inRef.Contains($_) })
if ($missing.Count -gt 0) { Fail ("opm_files.txt nombra ficheros que no estan en ${Ref} (ojo a mayusculas): " + ($missing -join ', ')) }
foreach ($l in $Lpks) { if ($files -notcontains $l) { Fail "opm_files.txt debe incluir $l" } }

$PackageName = $DisplayName -replace ' ', ''          # como FPackageName en OPM
$ZipName = "$PackageName.zip"
$JsonName = "$PackageName.json"
$UpdJsonName = "update_$PackageName.json"
$ZipPath = Join-Path $OutDir $ZipName
$JsonPath = Join-Path $OutDir $JsonName
$UpdJsonPath = Join-Path $OutDir $UpdJsonName
$StageRoot = Join-Path $OutDir 'stage'
$StageDir = Join-Path $StageRoot $BaseDir

New-Item -ItemType Directory -Force $OutDir | Out-Null
foreach ($p in @($StageRoot, $ZipPath, $JsonPath, $UpdJsonPath, (Join-Path $OutDir 'stage.tar'))) {
  if (Test-Path $p) { Remove-Item -Recurse -Force $p }
}
New-Item -ItemType Directory -Force $StageDir | Out-Null

$tar = Join-Path $OutDir 'stage.tar'
Info "Extrayendo $($files.Count) ficheros de git archive $Ref ..."
& git -C $RepoRoot -c core.autocrlf=true archive --format=tar -o $tar $Ref -- @files
if ($LASTEXITCODE -ne 0) { Fail 'git archive ha fallado' }
# bsdtar de Windows (un tar GNU del PATH, p. ej. el de Git, tomaria "C:" por un host remoto)
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path $tarExe)) { $tarExe = 'tar' }
& $tarExe -xf $tar -C $StageDir
if ($LASTEXITCODE -ne 0) { Fail 'tar -xf ha fallado' }
Remove-Item -Force $tar

$refLpkChanged = @()
foreach ($l in $Lpks) {
  if (Sync-LpkFile (Join-Path $StageDir $l) $refVer) { $refLpkChanged += $l }
}
if ($refLpkChanged.Count -gt 0) {
  Warn ("en ${Ref} estos .lpk no tenian la version de RM_VERSION; se corrige solo en el paquete: " + ($refLpkChanged -join ', '))
}

# ================================================================ 3. zip
$commitUnix = [long]((Invoke-Git log -1 --format=%ct $Ref) | Select-Object -First 1)
$stamp = [DateTimeOffset]::FromUnixTimeSeconds($commitUnix).ToLocalTime()
Add-Type -AssemblyName System.IO.Compression
$sorted = [string[]]$files.Clone()
[Array]::Sort($sorted, [StringComparer]::Ordinal)
$fs = [IO.File]::Open($ZipPath, [IO.FileMode]::CreateNew)
try {
  $za = New-Object System.IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create, $true)
  try {
    foreach ($rel in $sorted) {
      $src = Join-Path $StageDir ($rel -replace '/', '\')
      $entry = $za.CreateEntry("$BaseDir/$rel", [IO.Compression.CompressionLevel]::Optimal)
      $entry.LastWriteTime = $stamp
      $bytes = [IO.File]::ReadAllBytes($src)
      $es = $entry.Open()
      try { $es.Write($bytes, 0, $bytes.Length) } finally { $es.Dispose() }
    }
  } finally { $za.Dispose() }
} finally { $fs.Dispose() }

$zipSize = (Get-Item $ZipPath).Length
$zipMd5 = (Get-FileHash -Algorithm MD5 $ZipPath).Hash.ToLower()   # MD5Print(MD5File())
$repoDate = (Get-Date).ToOADate()                                   # MetaPkg.RepositoryDate := now

# ================================================================ 4. JSON
# Emula TJSONData.FormatJSON([], 2) de fpjson: "clave" : valor, sangria de 2,
# sLineBreak (CRLF en Windows), sin escapar '/' (StrictEscaping=False).
$NL = "`r`n"
function Format-JsonString([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($c in $s.ToCharArray()) {
    switch ([int]$c) {
      0x22 { [void]$sb.Append('\"') }
      0x5C { [void]$sb.Append('\\') }
      8 { [void]$sb.Append('\b') }
      9 { [void]$sb.Append('\t') }
      10 { [void]$sb.Append('\n') }
      12 { [void]$sb.Append('\f') }
      13 { [void]$sb.Append('\r') }
      default {
        if ([int]$c -lt 32) { [void]$sb.Append(('\u{0:X4}' -f [int]$c)) } else { [void]$sb.Append($c) }
      }
    }
  }
  return '"' + $sb.ToString() + '"'
}
# Numero en coma flotante como Str() de FPC (TJSONFloatNumber.GetAsString)
function New-JsonFloat([double]$d) { return New-Object PSObject -Property @{ Raw = $d.ToString('E16', $Inv) } }
function Format-Json($v, [int]$ind) {
  if ($null -eq $v) { return 'null' }
  if ($v -is [System.Collections.Specialized.OrderedDictionary]) {
    if ($v.Count -eq 0) { return '{}' }
    $pad = ' ' * ($ind + 2)
    $members = foreach ($k in $v.Keys) { $pad + (Format-JsonString $k) + ' : ' + (Format-Json $v[$k] ($ind + 2)) }
    return '{' + $NL + ($members -join (',' + $NL)) + $NL + (' ' * $ind) + '}'
  }
  if ($v -is [array]) {
    $r = '[' + $NL
    for ($i = 0; $i -lt $v.Count; $i++) {
      $r += (' ' * ($ind + 2)) + (Format-Json $v[$i] ($ind + 2))
      if ($i -lt $v.Count - 1) { $r += ',' }
      $r += $NL
    }
    return $r + (' ' * $ind) + ']'
  }
  if ($v -is [bool]) { if ($v) { return 'true' } else { return 'false' } }
  if ($v -is [int] -or $v -is [long]) { return $v.ToString($Inv) }
  if ($v -is [string]) { return Format-JsonString $v }
  if ($v.PSObject.Properties['Raw']) { return $v.Raw }
  throw "tipo JSON no soportado: $($v.GetType().FullName)"
}

# Lee un .lpk como LoadPackageData() de opkman_createrepositorypackagefrm.pas
function Get-XAttr($node, [string]$child, [string]$attr, $default) {
  if ($null -eq $node) { return $default }
  $n = $node.SelectSingleNode($child)
  if ($null -eq $n -or -not $n.HasAttribute($attr)) { return $default }
  return $n.GetAttribute($attr)
}
function Get-XVersion($node) {
  $r = @()
  foreach ($a in 'Major', 'Minor', 'Release', 'Build') {
    $x = [int](Get-XAttr $node '.' $a 0)
    if ($x -gt 9999) { $x = 9999 } elseif ($x -lt 0) { $x = 0 }
    $r += $x
  }
  return ,$r
}
# TPkgVersion.AsString: A.B, A.B.C o A.B.C.D
function Format-PkgVersionShort([int[]]$v) {
  $s = "$($v[0]).$($v[1])"
  if ($v[3] -ne 0) { $s += ".$($v[2]).$($v[3])" } elseif ($v[2] -ne 0) { $s += ".$($v[2])" }
  return $s
}
# Codigos de PackageType en packagelist.json (orden antiguo TPackageType)
$PkgTypeCode = @{ 'RunAndDesignTime' = 0; 'DesignTime' = 1; 'RunTime' = 2; 'RunTimeOnly' = 3 }

$lazPkgs = @()
$updPkgs = @()
foreach ($l in $Lpks) {
  $xml = New-Object System.Xml.XmlDocument
  $xml.Load((Join-Path $StageDir ($l -replace '/', '\')))
  $pkg = $xml.SelectSingleNode('/CONFIG/Package')
  $type = [string](Get-XAttr $pkg 'Type' 'Value' 'RunTime')
  if (-not $PkgTypeCode.ContainsKey($type)) { Fail "Tipo de paquete desconocido en ${l}: $type" }
  $ver = Get-XVersion $pkg.SelectSingleNode('Version')
  $deps = @()
  $req = $pkg.SelectSingleNode('RequiredPkgs')
  if ($req) {
    foreach ($item in $req.SelectNodes('*')) {
      $d = [string](Get-XAttr $item 'PackageName' 'Value' '')
      $minN = $item.SelectSingleNode('MinVersion')
      $maxN = $item.SelectSingleNode('MaxVersion')
      $minOk = (Get-XAttr $item 'MinVersion' 'Valid' 'False') -eq 'True'
      $maxOk = (Get-XAttr $item 'MaxVersion' 'Valid' 'False') -eq 'True'
      $minV = if ($minOk) { Get-XVersion $minN } else { @(0, 0, 0, 0) }
      $maxV = if ($maxOk) { Get-XVersion $maxN } else { @(0, 0, 0, 0) }
      # GetDependenciesAsString(False): se omiten las versiones nulas
      if (($minV | Measure-Object -Sum).Sum -gt 0) { $d += '(' + (Format-PkgVersionShort $minV) + ')' }
      if (($maxV | Measure-Object -Sum).Sum -gt 0) { $d += '(' + (Format-PkgVersionShort $maxV) + ')' }
      $deps += $d
    }
  }
  $lpkName = Split-Path $l -Leaf
  $relPath = (Split-Path $l -Parent) -replace '\\', '/'
  $jsonRel = if ($relPath) { ($relPath + '/') -replace '/', '\/' } else { '' }
  $lp = [ordered]@{}
  $lp['Name'] = $lpkName
  $lp['Description'] = [string](Get-XAttr $pkg 'Description' 'Value' '')
  $lp['Author'] = [string](Get-XAttr $pkg 'Author' 'Value' '')
  $lp['License'] = [string](Get-XAttr $pkg 'License' 'Value' '')
  $lp['RelativeFilePath'] = $jsonRel
  $lp['VersionAsString'] = Format-Version4 $ver
  $lp['LazCompatibility'] = $LazCompatibility
  $lp['FPCCompatibility'] = $FPCCompatibility
  $lp['SupportedWidgetSet'] = $SupportedWidgetSet
  $lp['PackageType'] = [int]$PkgTypeCode[$type]
  $lp['DependenciesAsString'] = ($deps -join ', ')
  $lazPkgs += $lp
  if ((Format-Version4 $ver) -ne $refVerStr) { Fail "$l tiene version $(Format-Version4 $ver) y RM_VERSION es $refVerStr" }

  $up = [ordered]@{}
  $up['ForceNotify'] = [bool]$ForceNotify
  $up['InternalVersion'] = [int]$InternalVersion
  $up['Name'] = $lpkName
  $up['Version'] = Format-Version4 $ver
  $updPkgs += $up
}

if (-not $UpdateBaseURL.EndsWith('/')) { $UpdateBaseURL += '/' }
$meta = [ordered]@{}
$meta['Name'] = $DisplayName
$meta['DisplayName'] = $DisplayName
$meta['Category'] = $Category
$meta['CommunityDescription'] = $CommunityDescription
$meta['ExternalDependecies'] = $ExternalDependencies        # sic, asi en OPM
$meta['OrphanedPackage'] = 0
$meta['RepositoryFileName'] = $ZipName
$meta['RepositoryFileSize'] = [long]$zipSize
$meta['RepositoryFileHash'] = $zipMd5
$meta['RepositoryDate'] = New-JsonFloat $repoDate
$meta['PackageBaseDir'] = ($BaseDir + '/') -replace '/', '\/'
$meta['HomePageURL'] = $HomePageURL
$meta['DownloadURL'] = $UpdateBaseURL + $UpdJsonName          # "Update link (JSON)"
$meta['SVNURL'] = $SVNURL

$list = [ordered]@{}
$list['PackageData0'] = $meta
$list['PackageFiles0'] = $lazPkgs
[IO.File]::WriteAllText($JsonPath, (Format-Json $list 0), $Utf8NoBom)

# TUpdatePackage.SaveToJSON (fpjsonrtti, propiedades en orden alfabetico).
# UpdatePackageData.Name = carpeta base, como CreateJSONForUpdates.
$updData = [ordered]@{}
$updData['DisableInOPM'] = $false
$updData['DownloadZipURL'] = $UpdateBaseURL + $ZipName
$updData['Name'] = $BaseDir
$upd = [ordered]@{}
$upd['UpdateLazPackages'] = $updPkgs
$upd['UpdatePackageData'] = $updData
[IO.File]::WriteAllText($UpdJsonPath, (Format-Json $upd 0), $Utf8NoBom)

Remove-Item -Recurse -Force $StageRoot

# ================================================================ 5. validacion
$results = [ordered]@{}

function Get-OpmCheckExe([string]$dir) {
  $fpcExe = if ($Fpc) { $Fpc } else { Find-FpcTool 'fpc.exe' }
  New-Item -ItemType Directory -Force $dir | Out-Null
  $r = Invoke-Exe $fpcExe @('-O1', "-FE$dir", "-FU$dir", (Join-Path $PSScriptRoot 'opm_check.pas'))
  if ($r[0] -ne 0) { $r[1] | Select-Object -Last 20 | ForEach-Object { "  $_" }; Fail 'no compila opm_check.pas' }
  return (Join-Path $dir 'opm_check.exe')
}

# Ejecuta la secuencia de compilacion de OPM. $run recibe (argumentos lazbuild) y
# devuelve @(exitcode, salida). $touch toca rpsecutil.pas (plan B, ver docs\opm.md).
function Invoke-OpmBuildSequence([scriptblock]$run, [scriptblock]$touch, [string]$pkgRoot, [string]$sep, [string]$label, [string]$logDir) {
  $order = @('packages{0}fpc{0}reportman_rtl.lpk', 'packages{0}fpc_lcl{0}reportman_lcl.lpk', 'packages{0}fpc_lcl{0}reportman_designlcl.lpk') |
    ForEach-Object { $pkgRoot + $sep + ($_ -f $sep) }
  $status = 'OK'
  for ($i = 0; $i -lt $order.Count; $i++) {
    $lpk = $order[$i]
    $name = [IO.Path]::GetFileNameWithoutExtension(($lpk -replace '/', '\'))
    $r = & $run @('-B', $lpk)
    $r[1] | Out-File -Encoding utf8 (Join-Path $logDir "$label-$name.log")
    if ($r[0] -eq 0) { Info "  [$label] $name (lazbuild -B): OK"; continue }
    $txt = ($r[1] | Out-String)
    $err = @($r[1] | Where-Object { "$_" -match 'Fatal:|Error:' } | Select-Object -First 3)
    Warn "  [$label] $name (lazbuild -B): FALLA"; $err | ForEach-Object { Write-Host "      $_" }
    if ($i -gt 0 -and $txt -match "Can't find unit rpsecutil") {
      $status = 'FALLA rpsecutil (plan B OK)'
      Warn "  [$label] ppu obsoleto de rpsecutil tras la compilacion limpia de reportman_rtl: regresion del CRC del ciclo rpsection/rpsubreport/rpsecutil (ver CLAUDE.md). Rompe la instalacion desde OPM. Solo para diagnostico: tocar rpsecutil.pas y recompilar reportman_rtl."
      Start-Sleep -Seconds 3
      $null = & $touch
      $r2 = & $run @($order[0])
      $r2[1] | Out-File -Encoding utf8 (Join-Path $logDir "$label-reportman_rtl-2.log")
      if ($r2[0] -ne 0) { Warn "  [$label] reportman_rtl (2a pasada): FALLA"; return 'FALLA' }
      $r3 = & $run @('-B', $lpk)
      $r3[1] | Out-File -Encoding utf8 (Join-Path $logDir "$label-$name-2.log")
      if ($r3[0] -ne 0) { Warn "  [$label] $name (tras plan B): FALLA"; return 'FALLA' }
      Info "  [$label] $name (tras plan B): OK"
      continue
    }
    return 'FALLA'
  }
  # Los proyectos de ejemplo (examples\lazarus), como los abre un usuario tras instalar
  foreach ($ex in 'pdfconsole', 'preview', 'designer') {
    $lpi = $pkgRoot + $sep + ('examples{0}lazarus{0}' -f $sep) + $ex + $sep + "$ex.lpi"
    $r = & $run @($lpi)
    $r[1] | Out-File -Encoding utf8 (Join-Path $logDir "$label-example-$ex.log")
    if ($r[0] -eq 0) { Info "  [$label] ejemplo ${ex}: OK"; continue }
    $err = @($r[1] | Where-Object { "$_" -match 'Fatal:|Error:' } | Select-Object -First 3)
    Warn "  [$label] ejemplo ${ex}: FALLA"; $err | ForEach-Object { Write-Host "      $_" }
    return 'FALLA'
  }
  return $status
}

if ($Validate -or $ValidateWsl) {
  $ValDir = Join-Path $OutDir 'validate'
  if (Test-Path $ValDir) { Remove-Item -Recurse -Force $ValDir }
  New-Item -ItemType Directory -Force $ValDir | Out-Null
  if (-not (Test-Path (Join-Path $ZeosDir 'packages\lazarus\zcomponent.lpk'))) { Fail "No encuentro Zeos en $ZeosDir (packages\lazarus\zcomponent.lpk)" }
  $zeosLpks = 'zcore', 'zplain', 'zparsesql', 'zdbc', 'zcomponent'
}

if ($Validate) {
  Info 'Validacion Windows (configuracion Lazarus privada) ...'
  $w = Join-Path $ValDir 'win'
  $pkgDir = Join-Path $w 'packages'          # como onlinepackagemanager\packages
  $pcp = Join-Path $w 'pcp'
  New-Item -ItemType Directory -Force $pkgDir, $pcp | Out-Null
  $chk = Get-OpmCheckExe (Join-Path $w 'opm_check')
  $r = Invoke-Exe $chk @($JsonPath, $UpdJsonPath, $ZipPath, $pkgDir)
  $r[1] | Out-File -Encoding utf8 (Join-Path $w 'opm_check.log')
  if ($r[0] -ne 0) { $r[1] | ForEach-Object { "  $_" }; $results['opm_check (Windows)'] = 'FALLA' }
  else { $results['opm_check (Windows)'] = 'OK' }
  # Zeos como lo dejaria OPM (paquete zeosdbo), copia limpia sin lib\
  $z = Join-Path $pkgDir 'zeosdbo'
  & robocopy (Join-Path $ZeosDir 'src') (Join-Path $z 'src') /E /XD lib backup /XF *.o *.ppu *.compiled /NFL /NDL /NJH /NJS /NP | Out-Null
  & robocopy (Join-Path $ZeosDir 'packages\lazarus') (Join-Path $z 'packages\lazarus') /E /XD lib backup /XF *.o *.ppu *.compiled *.exe /NFL /NDL /NJH /NJS /NP | Out-Null
  $links = @($zeosLpks | ForEach-Object { Join-Path $z "packages\lazarus\$_.lpk" })
  $r = Invoke-Exe $LazBuild (@("--pcp=$pcp", '--add-package-link') + $links)
  if ($r[0] -ne 0) { $r[1] | ForEach-Object { "  $_" }; Fail 'no se pudo registrar Zeos en la configuracion privada' }
  $root = Join-Path $pkgDir $BaseDir
  $run = { param($a) return Invoke-Exe $LazBuild (@("--pcp=$pcp", '--ws=win32', '--no-write-project') + $a) }
  $touch = { (Get-Item (Join-Path $root 'rpsecutil.pas')).LastWriteTime = Get-Date }
  $results['lazbuild Windows (win32)'] = Invoke-OpmBuildSequence $run $touch $root '\' 'win' $w
}

if ($ValidateWsl) {
  Info "Validacion Linux en WSL ($WslWidgetSet) ..."
  $lw = '/tmp/rm_opm_validate'
  $l = Join-Path $ValDir 'wsl'
  New-Item -ItemType Directory -Force $l | Out-Null
  $r = Invoke-Exe 'wsl' @('-e', 'rm', '-rf', $lw)
  $r = Invoke-Exe 'wsl' @('-e', 'mkdir', '-p', "$lw/packages/zeosdbo", "$lw/pcp", "$lw/opm_check")
  if ($r[0] -ne 0) { Fail 'WSL no disponible' }
  $r = Invoke-Exe 'wsl' @('-e', 'fpc', '-O1', "-FE$lw/opm_check", "-FU$lw/opm_check", (ConvertTo-WslPath (Join-Path $PSScriptRoot 'opm_check.pas')))
  if ($r[0] -ne 0) { $r[1] | Select-Object -Last 20 | ForEach-Object { "  $_" }; Fail 'no compila opm_check.pas en WSL' }
  $r = Invoke-Exe 'wsl' @('-e', "$lw/opm_check/opm_check", (ConvertTo-WslPath $JsonPath), (ConvertTo-WslPath $UpdJsonPath), (ConvertTo-WslPath $ZipPath), "$lw/packages")
  $r[1] | Out-File -Encoding utf8 (Join-Path $l 'opm_check.log')
  if ($r[0] -ne 0) { $r[1] | ForEach-Object { "  $_" }; $results['opm_check (Linux)'] = 'FALLA' }
  else { $results['opm_check (Linux)'] = 'OK' }
  $r = Invoke-Exe 'wsl' @('-e', 'cp', '-r', (ConvertTo-WslPath (Join-Path $ZeosDir 'src')), (ConvertTo-WslPath (Join-Path $ZeosDir 'packages')), "$lw/packages/zeosdbo/")
  if ($r[0] -ne 0) { Fail 'no se pudo copiar Zeos a WSL' }
  $r = Invoke-Exe 'wsl' @('-e', 'rm', '-rf', "$lw/packages/zeosdbo/packages/lazarus/lib")
  $links = @($zeosLpks | ForEach-Object { "$lw/packages/zeosdbo/packages/lazarus/$_.lpk" })
  $r = Invoke-Exe 'wsl' (@('-e', 'lazbuild', "--pcp=$lw/pcp", '--add-package-link') + $links)
  if ($r[0] -ne 0) { $r[1] | ForEach-Object { "  $_" }; Fail 'no se pudo registrar Zeos en WSL' }
  $root = "$lw/packages/$BaseDir"
  $run = { param($a) return Invoke-Exe 'wsl' (@('-e', 'lazbuild', "--pcp=$lw/pcp", "--ws=$WslWidgetSet", '--no-write-project') + $a) }
  $touch = { $null = Invoke-Exe 'wsl' @('-e', 'touch', "$root/rpsecutil.pas") }
  $results["lazbuild Linux ($WslWidgetSet)"] = Invoke-OpmBuildSequence $run $touch $root '/' 'wsl' $l
}

# ================================================================ resumen
Write-Host ''
Info "Paquete OPM de Report Manager $refVerStr ($Ref, $($files.Count) ficheros)"
"  Zip de repositorio : $ZipPath"
"                       $zipSize bytes, MD5 $zipMd5"
"  Lista de paquetes  : $JsonPath"
"  JSON de updates    : $UpdJsonPath"
"                       publicar en $($UpdateBaseURL)$UpdJsonName junto a $($UpdateBaseURL)$ZipName"
if ($results.Count -gt 0) {
  Write-Host ''
  Info 'Validacion:'
  foreach ($k in $results.Keys) { '  {0,-28}: {1}' -f $k, $results[$k] }
  "  Registros en $ValDir"
  if (@($results.Values | Where-Object { $_ -ne 'OK' }).Count -gt 0) { exit 2 }
}
exit 0

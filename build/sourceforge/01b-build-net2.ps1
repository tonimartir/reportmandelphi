# Tarea net2 - Build .NET (SDK, net9.0-windows) de designer + printreport como
# SELF-CONTAINED por RID (win-x64 y win-x86): el instalador .NET independiente
# NO requiere el runtime .NET instalado (a cambio de mas tamano).
# Destinos:  repman\binr64\net2 (win-x64)   repman\binr32\net2 (win-x86)
[CmdletBinding()]
param()
. "$PSScriptRoot\_common.ps1"

$CsRoot   = 'C:\desarrollo\danzai\comunnt\reportman'
$projects = @(
  [pscustomobject]@{ Name = 'designer';    Proj = (Join-Path $CsRoot 'designer\designer.csproj') },
  [pscustomobject]@{ Name = 'printreport'; Proj = (Join-Path $CsRoot 'printreport\printreport.csproj') }
)
$builds = @(
  [pscustomobject]@{ Rid = 'win-x64'; Dest = (Join-Path $RepoRoot 'repman\binr64\net2') },
  [pscustomobject]@{ Rid = 'win-x86'; Dest = (Join-Path $RepoRoot 'repman\binr32\net2') }
)

Info "== Tarea net2: build .NET designer + printreport (self-contained win-x64 + win-x86) =="
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Fail "No encuentro 'dotnet' (SDK .NET) en PATH." }
foreach ($p in $projects) { if (-not (Test-Path $p.Proj)) { Fail "No encuentro el proyecto .NET: $($p.Proj)" } }

foreach ($b in $builds) {
  Info ""
  Info "---- RID $($b.Rid)  ->  $($b.Dest) ----"
  foreach ($p in $projects) {
    Info "dotnet publish $($p.Name)  (-c Release -r $($b.Rid) --self-contained)"
    & dotnet publish $p.Proj -c Release -r $b.Rid --self-contained true --nologo -v minimal
    if ($LASTEXITCODE -ne 0) { Fail "dotnet publish fallo en $($p.Name) / $($b.Rid) (exit $LASTEXITCODE)" }
  }
  # net2 = merge de las dos carpetas publish de este RID (comparten Reportman.*.dll y runtime)
  New-CleanDir $b.Dest
  foreach ($p in $projects) {
    $pub = Join-Path (Split-Path $p.Proj -Parent) "bin\Release\net9.0-windows\$($b.Rid)\publish"
    if (-not (Test-Path $pub)) { Fail "No encuentro la salida publish: $pub" }
    Copy-Item (Join-Path $pub '*') $b.Dest -Recurse -Force
  }
  $n = (Get-ChildItem $b.Dest -Recurse -File | Measure-Object).Count
  Ok ("  net2 {0}: {1} ficheros en {2}" -f $b.Rid, $n, $b.Dest)
}

Ok "Tarea net2 OK (self-contained win-x64 + win-x86)."
exit 0

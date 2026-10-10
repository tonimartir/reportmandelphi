# Task 01c - Delphi Linux64 Release builds of printreptopdf and repwebexe.
#   repman\utils\printreptopdf\binrl64\printreptopdf   (zipped by task 05)
#   server\web\repwebexe                                (copied to the Docker
#                                                        artifacts folder)
# No PAServer: MSBuild compiles and links against the Linux64 SDK already pulled
# into RAD Studio (Tools > Options > SDK Manager); PAServer is only needed to
# pull or update that SDK, or to run and debug from the IDE.
#
# The SDK is Rocky Linux 8 (glibc 2.28) on purpose: glibc tags each symbol with
# the version that last changed it and a binary asks for the newest tags found
# in the SDK it was linked against, so a Rocky 9 / Ubuntu 22.04+ SDK (glibc
# 2.34+) gives binaries that do not start on Red Hat 8. Linked against 2.28
# they run there and on every newer distribution.
[CmdletBinding()]
param([string]$PlatformSdk = 'rocky8.10.sdk')
. "$PSScriptRoot\_common.ps1"

Info "== Task 01c: Linux64 Release (printreptopdf, repwebexe), SDK $PlatformSdk =="
Import-RsVars
if (-not (Test-Path $MsBuild)) { Fail "MSBuild not found: $MsBuild" }

$targets = @(
  [pscustomobject]@{ Proj = (Join-Path $RepoRoot 'repman\utils\printreptopdf\printreptopdf.dproj');
                     Bin  = (Join-Path $RepoRoot 'repman\utils\printreptopdf\binrl64\printreptopdf') },
  [pscustomobject]@{ Proj = (Join-Path $RepoRoot 'server\web\repwebexe.dproj');
                     Bin  = (Join-Path $RepoRoot 'server\web\repwebexe') }
)

foreach ($t in $targets) {
  $name  = [IO.Path]::GetFileNameWithoutExtension($t.Proj)
  $start = Get-Date
  Info ""
  Info "== Build  Release / Linux64  $name =="
  # A build leaves the .res with a new timestamp; put back the committed one
  $res = [IO.Path]::ChangeExtension($t.Proj, '.res')
  Push-Location (Split-Path $t.Proj -Parent)
  try {
    & $MsBuild $t.Proj /t:Build /p:Config=Release /p:Platform=Linux64 "/p:PlatformSDK=$PlatformSdk" /nologo /v:m
    $code = $LASTEXITCODE
  } finally { Pop-Location }
  & git -C $RepoRoot checkout -- $res 2>$null
  if ($code -ne 0) { Fail "Linux64 build of $name failed (exit $code)" }

  if (-not (Test-Path $t.Bin)) { Fail "The build did not leave $($t.Bin)" }
  $f = Get-Item $t.Bin
  if ($f.LastWriteTime -lt $start) { Fail "$($t.Bin) is older than this build" }
  $magic = [IO.File]::ReadAllBytes($t.Bin)[0..3]
  if (-not ($magic[0] -eq 0x7F -and $magic[1] -eq 0x45 -and $magic[2] -eq 0x4C -and $magic[3] -eq 0x46)) {
    Fail "$($t.Bin) is not an ELF executable"
  }
  Ok ("  {0}  ({1} MB)" -f $t.Bin, [math]::Round($f.Length / 1MB, 1))
}

# The Docker image of the web server takes repwebexe from here
# (server\docker\web\scripts\publish-docker-wsl.sh, REPWEBEXE_SOURCE)
$dockerDir = Join-Path $RepoRoot 'server\docker\web\artifacts\linux64'
New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null
Copy-Item (Join-Path $RepoRoot 'server\web\repwebexe') $dockerDir -Force

Ok "Task 01c OK: Linux64 binaries built; repwebexe also in $dockerDir"
exit 0

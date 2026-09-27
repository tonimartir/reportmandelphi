#!/bin/sh
# Builds the three Free Pascal / Lazarus packages of Report Manager (Linux).
# Usage: packages/fpc/build_fpc.sh [clean] [--ws=gtk2|qt5]   (lazbuild from PATH)
#
# Each package is compiled once, as the Lazarus IDE / Online Package Manager
# does: a clean or incremental build of reportman_rtl leaves consistent PPUs
# (see the FPC 3.2.2 note in the interface uses of rpsection.pas).
# Use "clean" to rebuild reportman_rtl from scratch, e.g. if FPC ever reports
# "Compilation raised exception internally" after an incremental build.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LAZBUILD=${LAZBUILD:-lazbuild}
RTLCLEAN=
if [ "$1" = "clean" ]; then
  RTLCLEAN=-B
  shift
fi

echo "Compiling reportman_rtl.lpk..."
"$LAZBUILD" $RTLCLEAN --no-write-project "$@" "$ROOT/packages/fpc/reportman_rtl.lpk"

echo "Compiling reportman_lcl.lpk..."
"$LAZBUILD" --no-write-project "$@" "$ROOT/packages/fpc_lcl/reportman_lcl.lpk"

echo "Compiling reportman_designlcl.lpk..."
"$LAZBUILD" --no-write-project "$@" "$ROOT/packages/fpc_lcl/reportman_designlcl.lpk"

echo "SUCCESS"

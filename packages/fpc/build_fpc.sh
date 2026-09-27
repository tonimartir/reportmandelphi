#!/bin/sh
# Builds the three Free Pascal / Lazarus packages of Report Manager (Linux).
# Usage: packages/fpc/build_fpc.sh [clean] [--ws=gtk2|qt5]   (lazbuild from PATH)
#
# Use "clean" if FPC stops with "Compilation raised exception internally":
# incremental builds of the unit cycle below can crash FPC 3.2.2 after an
# interface change in one of the engine units.
#
# FPC 3.2.2 needs a second, incremental pass over reportman_rtl: the unit
# cycle rpsection (implementation) -> rpsubreport -> rpsecutil -> rpsection
# leaves rpsecutil.ppu with a stale interface checksum after a clean build,
# and the packages that use reportman_rtl then fail with
# "Can't find unit rpsecutil used by rpsubreport". Touching rpsecutil.pas
# makes lazbuild recompile it (and its dependents) consistently. lazbuild
# compares file ages with 2-second resolution, hence the wait before touching.
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
sleep 3
touch "$ROOT/rpsecutil.pas"
"$LAZBUILD" --no-write-project "$@" "$ROOT/packages/fpc/reportman_rtl.lpk"

echo "Compiling reportman_lcl.lpk..."
"$LAZBUILD" --no-write-project "$@" "$ROOT/packages/fpc_lcl/reportman_lcl.lpk"

echo "Compiling reportman_designlcl.lpk..."
"$LAZBUILD" --no-write-project "$@" "$ROOT/packages/fpc_lcl/reportman_designlcl.lpk"

echo "SUCCESS"

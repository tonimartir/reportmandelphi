#!/bin/bash
# Component palette icons of the Lazarus packages. The SVG files of this
# folder are rendered at 24, 36 and 48 pixels: the IDE takes <CLASS>,
# <CLASS>_150 and <CLASS>_200 for 100, 150 and 200 % (96, 144 and 192 ppi).
# They are written to the resources of each package:
#   lcl/rpreglcl.lrs                reportman_lcl
#   design_lcl/rpmregdesignlcl.lrs  reportman_designlcl
#   rtl_fpc/rpmregicons.res         reportman_rtl (it does not use the LCL:
#                                   a .res, linked by rpmreg.pas)
# Needs rsvg-convert (librsvg) and lazres (tools of Lazarus). RSVG_CONVERT
# and LAZRES name other commands, for example a container:
#   RSVG_CONVERT="docker run --rm -i <image with librsvg2-bin> rsvg-convert" \
#     packages/icons/make_icons.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
RSVG_CONVERT=${RSVG_CONVERT:-rsvg-convert}
LAZRES=${LAZRES:-lazres}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The three sizes of a class, named as the IDE looks for them
render() {
  local name
  name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  $RSVG_CONVERT -w 24 -h 24 < "$HERE/$1.svg" > "$TMP/$name.png"
  $RSVG_CONVERT -w 36 -h 36 < "$HERE/$1.svg" > "$TMP/${name}_150.png"
  $RSVG_CONVERT -w 48 -h 48 < "$HERE/$1.svg" > "$TMP/${name}_200.png"
  echo "$name.png ${name}_150.png ${name}_200.png"
}

# <resource file> <class>...
pack() {
  local out=$1 files=()
  shift
  for class in "$@"; do
    # shellcheck disable=SC2207
    files+=($(render "$class"))
  done
  (cd "$TMP" && $LAZRES "$out" "${files[@]}" > /dev/null)
  echo "$out: ${#files[@]} images"
}

pack "$ROOT/lcl/rpreglcl.lrs" tlclreport trpmaskedit trppreviewcontrol
pack "$ROOT/design_lcl/rpmregdesignlcl.lrs" trpdesignerlcl trprulerlcl
pack "$ROOT/rtl_fpc/rpmregicons.res" trpevaluator trpalias trplastusedstrings \
  trptranslator tpdfreport

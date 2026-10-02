#!/bin/bash
# Compila Report Manager Designer para macOS (repman/repmandesigner_lcl.app)
# despues de setup-toolchain.sh, build-deps.sh y los paquetes:
#
#   . ~/dev/env.sh
#   LAZBUILD=lazbuild sh packages/fpc/build_fpc.sh
#   build/macos/build-designer.sh
#   open repman/repmandesigner_lcl.app
#
# Lazarus deja el ejecutable en repman/ y lo enlaza desde
# repmandesigner_lcl.app/Contents/MacOS; el motor encuentra las traducciones
# (repman/reportmanres.*) y los ejemplos junto al ejecutable real. Este script
# anade a Contents/Resources/languages las traducciones de la LCL
# (lclstrconsts.<idioma>.po de la Lazarus que compila, como los paquetes de
# Linux): los botones y dialogos estandar en el idioma del usuario, el de
# Preferencias del Sistema > Idioma y region.
set -euo pipefail

T=${RM_MACOS_TOOLS:-$HOME/dev}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
LAZ=${LAZARUS_DIR:-$T/lazarus}
# Los idiomas de reportmanres.* (ca = .cat, cs = .csy) y pt_BR ademas de pt
LCL_LANGUAGES="es ca cs de fr it lt pt pt_BR"

if ! command -v lazbuild > /dev/null && [ -f "$T/env.sh" ]; then
    . "$T/env.sh"
fi
lazbuild --no-write-project "$SRC/repman/lcl_designer/repmandesigner_lcl.lpi"

APP=$SRC/repman/repmandesigner_lcl.app
mkdir -p "$APP/Contents/Resources/languages"
for l in $LCL_LANGUAGES; do
    cp "$LAZ/lcl/languages/lclstrconsts.$l.po" "$APP/Contents/Resources/languages/"
done
echo "Listo: open $APP"

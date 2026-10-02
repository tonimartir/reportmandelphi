#!/bin/bash
# Compila en un Mac el paquete de Lazarus Online Package Manager tal como lo
# instala un usuario: solo los ficheros de build/opm/opm_files.txt (sacados de
# "git archive HEAD", como make_opm_package.ps1), en una configuracion de
# Lazarus vacia (--pcp nueva) con Zeos, los tres paquetes con -B y los cuatro
# ejemplos de examples/lazarus; despues pdfconsole escribe sales.pdf. Es la
# validacion -Validate de make_opm_package.ps1 para LCL Cocoa (Intel o Apple
# Silicon), despues de setup-toolchain.sh:
#
#   build/macos/opm-check.sh [carpeta de trabajo]
#
# La carpeta de trabajo es $TMPDIR/rm_opm_check si no se indica; los registros
# de lazbuild quedan en ella. Sale con 1 al primer fallo.
set -euo pipefail

T=${RM_MACOS_TOOLS:-$HOME/dev}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
W=${1:-${TMPDIR:-/tmp}/rm_opm_check}
W=${W%/}
PKG=$W/packages/reportman

LB() {
    "$T/lazarus/lazbuild" --pcp="$W/pcp" --lazarusdir="$T/lazarus" --compiler="$T/fpc/bin/fpc" \
        --no-write-project "$@"
}
step() {
    local log=$1; shift
    if LB "$@" > "$W/$log.log" 2>&1; then
        echo "  OK     $log"
    else
        echo "  FALLA  $log" >&2
        grep -E '(Error|Fatal):' "$W/$log.log" | head -n 5 >&2 || tail -n 20 "$W/$log.log" >&2
        exit 1
    fi
}

echo "== Paquete OPM ($(uname -m)) en $W"
rm -rf "$W"
mkdir -p "$PKG" "$W/pcp" "$W/packages/zeosdbo"
# Solo los ficheros de la lista, con las rutas del repositorio
FILES=$(grep -v '^[[:space:]]*#' "$SRC/build/opm/opm_files.txt" | tr -d '\r' | sed '/^[[:space:]]*$/d')
# shellcheck disable=SC2086
git -C "$SRC" archive HEAD -- $FILES | tar -x -C "$PKG"
n=$(find "$PKG" -type f | wc -l | tr -d ' ')
echo "  $n ficheros"
[ "$n" -eq "$(echo "$FILES" | wc -l | tr -d ' ')" ] || { echo "ERROR: faltan ficheros de opm_files.txt en HEAD" >&2; exit 1; }

# Zeos como lo deja OPM (paquete zeosdbo), sin lo compilado
cp -R "$T/zeos/src" "$W/packages/zeosdbo/"
mkdir -p "$W/packages/zeosdbo/packages"
cp -R "$T/zeos/packages/lazarus" "$W/packages/zeosdbo/packages/"
find "$W/packages/zeosdbo" -type d -name lib -prune -exec rm -rf {} +
for p in "$W"/packages/zeosdbo/packages/lazarus/{zcore,zplain,zparsesql,zdbc,zcomponent}.lpk \
         "$PKG/packages/fpc/reportman_rtl.lpk" \
         "$PKG/packages/fpc_lcl/reportman_lcl.lpk" \
         "$PKG/packages/fpc_lcl/reportman_designlcl.lpk"; do
    LB --add-package-link "$p" > /dev/null
done

# Los tres paquetes desde cero, en el orden de OPM, y los ejemplos
step reportman_rtl -B "$PKG/packages/fpc/reportman_rtl.lpk"
step reportman_lcl -B "$PKG/packages/fpc_lcl/reportman_lcl.lpk"
step reportman_designlcl -B "$PKG/packages/fpc_lcl/reportman_designlcl.lpk"
for ex in pdfconsole preview designer postgresql; do
    proj=$ex
    [ "$ex" = postgresql ] && proj=pgreport
    step "ejemplo-$ex" "$PKG/examples/lazarus/$ex/$proj.lpi"
done

# pdfconsole: el informe de ejemplo a PDF
EX=$PKG/examples/lazarus/pdfconsole
(cd "$EX" && ./pdfconsole) > "$W/pdfconsole.log" 2>&1 \
    || { cat "$W/pdfconsole.log" >&2; echo "ERROR: pdfconsole ha fallado" >&2; exit 1; }
[ "$(head -c 5 "$EX/sales.pdf")" = "%PDF-" ] || { echo "ERROR: pdfconsole no ha escrito sales.pdf" >&2; exit 1; }
echo "  OK     pdfconsole: sales.pdf, $(wc -c < "$EX/sales.pdf" | tr -d ' ') bytes ($(lipo -archs "$EX/pdfconsole"))"
cp "$EX/sales.pdf" "$W/sales.pdf"
echo "Listo: paquete OPM compilado en $(uname -m)"

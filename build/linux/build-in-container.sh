#!/bin/bash
# Fase 6.3: compila y empaqueta Report Manager Designer (LCL/GTK2) dentro de
# la imagen reportman-linux-builder (build/linux/Dockerfile.builder).
#
#   docker run --rm -v <repo>:/src:ro -v <salida>:/out reportman-linux-builder \
#       bash /src/build/linux/build-in-container.sh [opciones]
#
# Opciones:
#   --skip-selftest   no ejecuta LclDesignerTest --selftest
#   --skip-deb        no genera el .deb
#   --skip-appimage   no genera la AppImage
#   --ws=<widgetset>  gtk2 (por defecto) o qt5 (spike: solo compila)
#
# /src se monta de solo lectura: se copian los fuentes necesarios a
# /build/src y se compila siempre desde cero, con una configuracion privada
# de lazbuild (--pcp) en la que se registran Zeos y los tres paquetes.
# Artefactos en /out: el .deb, la AppImage, build-info.txt, lintian.txt y
# selftest.log.
set -euo pipefail

SRC=${SRC:-/src}
OUT=${OUT:-/out}
WORK=${WORK:-/build}
ZEOS=${ZEOS:-/opt/zeos}
B=$WORK/src
PCP=$WORK/lazconfig
WS=gtk2
DO_SELFTEST=1
DO_DEB=1
DO_APPIMAGE=1

for a in "$@"; do
    case "$a" in
        --skip-selftest) DO_SELFTEST=0 ;;
        --skip-deb) DO_DEB=0 ;;
        --skip-appimage) DO_APPIMAGE=0 ;;
        --ws=*) WS=${a#--ws=} ;;
        *) echo "Opcion desconocida: $a" >&2; exit 2 ;;
    esac
done
if [ "$WS" != gtk2 ]; then
    # Solo se empaqueta GTK2 (decision de la Fase 6); otro widgetset = spike
    DO_SELFTEST=0; DO_DEB=0; DO_APPIMAGE=0
fi

step() { echo; echo "==== $*"; }
T0=$(date +%s)

# ---- 1. Copia de trabajo (solo lo que necesita la compilacion)
step "Copiando fuentes de $SRC a $B"
rm -rf "$B"
mkdir -p "$B"
# Unidades del motor y recursos de la raiz (sin subdirectorios)
find "$SRC" -maxdepth 1 -type f \
    ! -name '*.exe' ! -name '*.dll' ! -name '*.zip' ! -name '*.o' ! -name '*.ppu' \
    -exec cp -p {} "$B/" \;
EXCL=(--exclude='lib/' --exclude='backup/' --exclude='*.ppu' --exclude='*.o'
      --exclude='*.exe' --exclude='*.dll' --exclude='*.log' --exclude='*.lps'
      --exclude='*.compiled')
for d in rtl_fpc lcl design_lcl packages/fpc packages/fpc_lcl \
         tests/fpc/LclDesignerTest repman/lcl_designer repman/repsamples build/linux; do
    mkdir -p "$B/$d"
    rsync -a "${EXCL[@]}" "$SRC/$d/" "$B/$d/"
done
rm -f "$B/repman/lcl_designer/repmandesigner_lcl.res"
cp -p "$SRC"/repman/reportmanres.* "$B/repman/"
mkdir -p "$B/doc"
cp -p "$SRC/doc/favicon.svg" "$SRC/doc/icon-512.png" "$B/doc/"

VERSION=$(sed -n "s/^[[:space:]]*RM_VERSION[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$B/rpmdconsts.pas" | head -n 1)
[ -n "$VERSION" ] || { echo "ERROR: no encuentro RM_VERSION" >&2; exit 1; }
echo "RM_VERSION=$VERSION  widgetset=$WS"

# ---- 2. Configuracion privada de lazbuild + registro de paquetes
step "Registrando Zeos y los paquetes de Report Manager (--pcp=$PCP)"
rm -rf "$PCP"
LAZ=(lazbuild "--pcp=$PCP")
"${LAZ[@]}" --add-package-link \
    "$ZEOS/packages/lazarus/zcore.lpk" \
    "$ZEOS/packages/lazarus/zdbc.lpk" \
    "$ZEOS/packages/lazarus/zparsesql.lpk" \
    "$ZEOS/packages/lazarus/zplain.lpk" \
    "$ZEOS/packages/lazarus/zcomponent.lpk" \
    "$B/packages/fpc/reportman_rtl.lpk" \
    "$B/packages/fpc_lcl/reportman_lcl.lpk" \
    "$B/packages/fpc_lcl/reportman_designlcl.lpk"

# ---- 3. Paquetes: packages/fpc/build_fpc.sh (una pasada por paquete, como el
# IDE), siempre "clean"; la copia de trabajo es nueva, asi que es desde cero
step "Compilando los paquetes (build_fpc.sh clean, --ws=$WS)"
LAZBUILD=lazbuild sh "$B/packages/fpc/build_fpc.sh" clean "--pcp=$PCP" "--ws=$WS"

# ---- 4. Disenador en modo Release (sin informacion de depuracion, strip)
step "Compilando repmandesigner_lcl (Release, $WS)"
"${LAZ[@]}" "--ws=$WS" --bm=Release --no-write-project "$B/repman/lcl_designer/repmandesigner_lcl.lpi"
DESIGNER=$B/repman/repmandesigner_lcl
file "$DESIGNER"
ls -l "$DESIGNER"

mkdir -p "$OUT"
if [ "$WS" != gtk2 ]; then
    cp "$DESIGNER" "$OUT/repmandesigner_lcl-$WS"
    echo "Spike $WS: compilacion correcta ($OUT/repmandesigner_lcl-$WS)"
    exit 0
fi

# ---- 5. Selftest del disenador bajo Xvfb (un fallo rompe la build)
if [ "$DO_SELFTEST" = 1 ]; then
    step "Compilando y ejecutando LclDesignerTest --selftest (Xvfb)"
    "${LAZ[@]}" "--ws=$WS" --no-write-project "$B/tests/fpc/LclDesignerTest/LclDesignerTest.lpi"
    rm -f "$B/tests/fpc/LclDesignerTest/selftest.log"
    set +e
    (cd "$B" && timeout 1800 xvfb-run -a -s "-screen 0 1600x1200x24" \
        ./tests/fpc/LclDesignerTest/LclDesignerTest --selftest) > "$WORK/selftest.out" 2>&1
    RC=$?
    set -e
    cp "$B/tests/fpc/LclDesignerTest/selftest.log" "$OUT/selftest.log" 2>/dev/null || true
    tail -n 5 "$OUT/selftest.log" 2>/dev/null || true
    if [ $RC -ne 0 ]; then
        cp "$WORK/selftest.out" "$OUT/selftest.out"
        echo "ERROR: LclDesignerTest --selftest ha fallado (codigo $RC)" >&2
        grep -n "TEST_FAILED" "$OUT/selftest.log" 2>/dev/null | head -n 20 >&2 || true
        tail -n 30 "$WORK/selftest.out" >&2
        exit 1
    fi
    echo "Selftest OK"
fi

# ---- 6. Paquetes
if [ "$DO_DEB" = 1 ]; then
    step "Paquete .deb"
    bash "$B/build/linux/make-deb.sh" "$B" "$DESIGNER" "$OUT"
    DEB=$OUT/reportman-designer_${VERSION}_amd64.deb
    step "lintian"
    set +e
    lintian --info --display-info --pedantic "$DEB" > "$OUT/lintian.txt" 2>&1
    set -e
    cat "$OUT/lintian.txt"
    if grep -q '^E: ' "$OUT/lintian.txt"; then
        echo "ERROR: lintian informa de errores" >&2
        exit 1
    fi
fi
if [ "$DO_APPIMAGE" = 1 ]; then
    step "AppImage"
    bash "$B/build/linux/make-appimage.sh" "$B" "$DESIGNER" "$OUT"
fi

# ---- 7. Resumen
{
    echo "Report Manager Designer $VERSION - build Linux ($WS)"
    echo "Fecha: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "Imagen: $(. /etc/os-release && echo "$PRETTY_NAME"), FPC $(fpc -iV), Lazarus $(lazbuild --version | tail -n 1)"
    echo "Zeos: $(grep -o 'ZEOS_[A-Z]*_VERSION = [0-9]*' "$ZEOS/src/core/ZClasses.pas" | tr '\n' ' ')"
    echo
    echo "Artefactos:"
    (cd "$OUT" && ls -l -- *.deb *.AppImage 2>/dev/null) || true
    echo
    echo "sha256:"
    (cd "$OUT" && sha256sum -- *.deb *.AppImage 2>/dev/null) || true
} > "$OUT/build-info.txt"
cat "$OUT/build-info.txt"
echo
echo "SUCCESS ($(( $(date +%s) - T0 )) s)"

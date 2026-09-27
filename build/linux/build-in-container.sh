#!/bin/bash
# Fase 6.3/6.8: compila y empaqueta Report Manager Designer (LCL, Qt6 y GTK2)
# dentro de la imagen reportman-linux-builder (build/linux/Dockerfile.builder).
#
#   docker run --rm -v <repo>:/src:ro -v <salida>:/out reportman-linux-builder \
#       bash /src/build/linux/build-in-container.sh [opciones]
#
# Opciones:
#   --skip-selftest   no ejecuta LclDesignerTest --selftest ni LclAIChatTest
#   --skip-deb        no genera los .deb
#   --skip-appimage   no genera la AppImage
#   --ws=<widgetset>  solo ese widgetset: qt6 (.deb + AppImage), gtk2 (.deb) u
#                     otro (qt5...: spike, solo compila). Por defecto qt6 y gtk2.
#
# /src se monta de solo lectura: se copian los fuentes necesarios a
# /build/src y cada widgetset se compila desde cero en su propia copia
# (/build/src-<ws>: los paquetes no separan la salida por widgetset), con su
# configuracion privada de lazbuild (--pcp) en la que se registran Zeos y los
# tres paquetes. Artefactos en /out:
#   reportman-designer_<v>_amd64.deb         Qt6 (el recomendado)
#   reportman-designer-gtk2_<v>_amd64.deb    GTK2 (transitorio)
#   ReportManDesigner-<v>-x86_64.AppImage    Qt6
#   build-info.txt, lintian-<paquete>.txt, selftest-<ws>.log,
#   aichattest-<ws>.log y shots-<ws>/ (panel de IA)
set -euo pipefail

SRC=${SRC:-/src}
OUT=${OUT:-/out}
WORK=${WORK:-/build}
ZEOS=${ZEOS:-/opt/zeos}
QT6PAS_DIR=${QT6PAS_DIR:-/opt/libqt6pas}
B=$WORK/src
WSLIST="qt6 gtk2"
DO_SELFTEST=1
DO_DEB=1
DO_APPIMAGE=1

for a in "$@"; do
    case "$a" in
        --skip-selftest) DO_SELFTEST=0 ;;
        --skip-deb) DO_DEB=0 ;;
        --skip-appimage) DO_APPIMAGE=0 ;;
        --ws=*) WSLIST=${a#--ws=} ;;
        *) echo "Opcion desconocida: $a" >&2; exit 2 ;;
    esac
done
SPIKE=0
case "$WSLIST" in
    "qt6 gtk2"|qt6|gtk2) ;;
    *) SPIKE=1   # Solo se empaquetan Qt6 y GTK2 (decision de la Fase 6)
esac

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
         tests/fpc/LclDesignerTest tests/fpc/LclAIChatTest tests/fpc/HubClientTest \
         repman/lcl_designer repman/repsamples build/linux; do
    mkdir -p "$B/$d"
    rsync -a "${EXCL[@]}" "$SRC/$d/" "$B/$d/"
done
rm -f "$B/repman/lcl_designer/repmandesigner_lcl.res"
cp -p "$SRC"/repman/reportmanres.* "$B/repman/"
mkdir -p "$B/doc"
cp -p "$SRC/doc/favicon.svg" "$SRC/doc/icon-512.png" "$B/doc/"

VERSION=$(sed -n "s/^[[:space:]]*RM_VERSION[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$B/rpmdconsts.pas" | head -n 1)
[ -n "$VERSION" ] || { echo "ERROR: no encuentro RM_VERSION" >&2; exit 1; }
echo "RM_VERSION=$VERSION  widgetsets=$WSLIST"
mkdir -p "$OUT"

# build_ws <ws>: pasos 2 a 5 para un widgetset; deja el disenador en
# $WORK/bin/repmandesigner_lcl-<ws>
build_ws() {
    local ws=$1
    local bw=$WORK/src-$ws pcp=$WORK/lazconfig-$ws
    local -a laz opt=()
    rm -rf "$bw" "$pcp"
    cp -a "$B" "$bw"
    laz=(lazbuild "--pcp=$pcp")
    # libQt6Pas (compilada en la imagen) no esta en las rutas del enlazador
    [ "$ws" = qt6 ] && opt=("--opt=-Fl$QT6PAS_DIR/lib")

    # ---- 2. Configuracion privada de lazbuild + registro de paquetes
    step "[$ws] Registrando Zeos y los paquetes de Report Manager (--pcp=$pcp)"
    "${laz[@]}" --add-package-link \
        "$ZEOS/packages/lazarus/zcore.lpk" \
        "$ZEOS/packages/lazarus/zdbc.lpk" \
        "$ZEOS/packages/lazarus/zparsesql.lpk" \
        "$ZEOS/packages/lazarus/zplain.lpk" \
        "$ZEOS/packages/lazarus/zcomponent.lpk" \
        "$bw/packages/fpc/reportman_rtl.lpk" \
        "$bw/packages/fpc_lcl/reportman_lcl.lpk" \
        "$bw/packages/fpc_lcl/reportman_designlcl.lpk"

    # ---- 3. Paquetes: packages/fpc/build_fpc.sh (una pasada por paquete,
    # como el IDE), siempre "clean"; la copia de trabajo es nueva
    step "[$ws] Compilando los paquetes (build_fpc.sh clean, --ws=$ws)"
    LAZBUILD=lazbuild sh "$bw/packages/fpc/build_fpc.sh" clean "--pcp=$pcp" "--ws=$ws" "${opt[@]}"

    # ---- 4. Disenador en modo Release (sin informacion de depuracion, strip)
    step "[$ws] Compilando repmandesigner_lcl (Release)"
    "${laz[@]}" "--ws=$ws" "${opt[@]}" --bm=Release --no-write-project \
        "$bw/repman/lcl_designer/repmandesigner_lcl.lpi"
    mkdir -p "$WORK/bin"
    cp "$bw/repman/repmandesigner_lcl" "$WORK/bin/repmandesigner_lcl-$ws"
    file "$WORK/bin/repmandesigner_lcl-$ws"
    ls -l "$WORK/bin/repmandesigner_lcl-$ws"
    [ "$SPIKE" = 1 ] && return 0

    # ---- 5. Selftest del disenador bajo Xvfb (un fallo rompe la build)
    [ "$DO_SELFTEST" = 1 ] || return 0
    step "[$ws] Compilando y ejecutando LclDesignerTest --selftest (Xvfb)"
    "${laz[@]}" "--ws=$ws" "${opt[@]}" --no-write-project "$bw/tests/fpc/LclDesignerTest/LclDesignerTest.lpi"
    rm -f "$bw/tests/fpc/LclDesignerTest/selftest.log"
    local rc
    set +e
    # Qt6: libQt6Pas desde la imagen y la plataforma X11 de Xvfb
    (cd "$bw" && LD_LIBRARY_PATH=$QT6PAS_DIR/lib QT_QPA_PLATFORM=xcb \
        timeout 1800 xvfb-run -a -s "-screen 0 1600x1200x24" \
        ./tests/fpc/LclDesignerTest/LclDesignerTest --selftest) > "$WORK/selftest-$ws.out" 2>&1
    rc=$?
    set -e
    cp "$bw/tests/fpc/LclDesignerTest/selftest.log" "$OUT/selftest-$ws.log" 2>/dev/null || true
    tail -n 5 "$OUT/selftest-$ws.log" 2>/dev/null || true
    if [ $rc -ne 0 ]; then
        cp "$WORK/selftest-$ws.out" "$OUT/selftest-$ws.out"
        echo "ERROR: LclDesignerTest --selftest ($ws) ha fallado (codigo $rc)" >&2
        grep -n "TEST_FAILED" "$OUT/selftest-$ws.log" 2>/dev/null | head -n 20 >&2 || true
        tail -n 30 "$WORK/selftest-$ws.out" >&2
        exit 1
    fi
    echo "Selftest $ws OK"

    # ---- 5b. Panel de IA (Fase 7.2): LclAIChatTest contra un Hub simulado,
    # con heaptrc (falla si hay fugas) y capturas en $OUT/shots-<ws>
    step "[$ws] Compilando y ejecutando LclAIChatTest (Xvfb)"
    "${laz[@]}" "--ws=$ws" "${opt[@]}" --no-write-project "$bw/tests/fpc/LclAIChatTest/LclAIChatTest.lpi"
    mkdir -p "$OUT/shots-$ws"
    set +e
    (cd "$bw" && LD_LIBRARY_PATH=$QT6PAS_DIR/lib QT_QPA_PLATFORM=xcb \
        timeout 900 xvfb-run -a -s "-screen 0 1600x1200x24" \
        ./tests/fpc/LclAIChatTest/LclAIChatTest "--shots=$OUT/shots-$ws") > "$OUT/aichattest-$ws.log" 2>&1
    rc=$?
    set -e
    tail -n 4 "$OUT/aichattest-$ws.log"
    if [ $rc -ne 0 ]; then
        echo "ERROR: LclAIChatTest ($ws) ha fallado (codigo $rc)" >&2
        grep -n -A 12 "TEST_FAILED" "$OUT/aichattest-$ws.log" | head -n 40 >&2 || true
        exit 1
    fi
    echo "LclAIChatTest $ws OK"
}

# lint_deb <.deb>: lintian; un error rompe la build
lint_deb() {
    local deb=$1 pkg txt
    pkg=$(dpkg-deb -f "$deb" Package)
    txt=$OUT/lintian-$pkg.txt
    step "lintian $pkg"
    set +e
    lintian --info --display-info --pedantic "$deb" > "$txt" 2>&1
    set -e
    cat "$txt"
    if grep -q '^E: ' "$txt"; then
        echo "ERROR: lintian informa de errores en $pkg" >&2
        exit 1
    fi
}

for ws in $WSLIST; do
    build_ws "$ws"
done
if [ "$SPIKE" = 1 ]; then
    for ws in $WSLIST; do cp "$WORK/bin/repmandesigner_lcl-$ws" "$OUT/"; done
    echo "Spike $WSLIST: compilacion correcta ($OUT/repmandesigner_lcl-*)"
    exit 0
fi

# ---- 6. Paquetes (Qt6: .deb + AppImage; GTK2: .deb)
for ws in $WSLIST; do
    bin=$WORK/bin/repmandesigner_lcl-$ws
    if [ "$DO_DEB" = 1 ]; then
        step "Paquete .deb ($ws)"
        bash "$B/build/linux/make-deb.sh" "$B" "$bin" "$OUT" "$ws"
        if [ "$ws" = qt6 ]; then
            lint_deb "$OUT/reportman-designer_${VERSION}_amd64.deb"
        else
            lint_deb "$OUT/reportman-designer-${ws}_${VERSION}_amd64.deb"
        fi
    fi
    if [ "$DO_APPIMAGE" = 1 ] && [ "$ws" = qt6 ]; then
        step "AppImage ($ws)"
        bash "$B/build/linux/make-appimage.sh" "$B" "$bin" "$OUT"
    fi
done

# ---- 7. Resumen
{
    echo "Report Manager Designer $VERSION - build Linux ($WSLIST)"
    echo "Fecha: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "Imagen: $(. /etc/os-release && echo "$PRETTY_NAME"), FPC $(fpc -iV), Lazarus $(lazbuild --version | tail -n 1)"
    echo "Zeos: $(grep -o 'ZEOS_[A-Z]*_VERSION = [0-9]*' "$ZEOS/src/core/ZClasses.pas" | tr '\n' ' ')"
    echo "Qt6: $(dpkg-query -W -f='${Version}' libqt6core6 2>/dev/null); libQt6Pas $(cat "$QT6PAS_DIR/sha256.txt" 2>/dev/null)"
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

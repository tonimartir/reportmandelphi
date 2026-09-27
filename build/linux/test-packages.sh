#!/bin/bash
# Fase 6.6: pruebas del .deb y de la AppImage en maquinas limpias (contenedores
# nuevos de cada distro). Se ejecuta donde haya Docker (WSL en Windows; lo
# llama build-linux.ps1):
#
#   test-packages.sh <directorio de artefactos> [imagen...]
#
# Imagenes por defecto: ubuntu:22.04 ubuntu:24.04 debian:12. Por cada una:
#  deb       apt install ./reportman-designer_<v>_amd64.deb sin nada mas
#            instalado (apt debe traer todas las dependencias); ldd sin
#            "not found" y las librerias que el motor abre con dlopen presentes;
#            .desktop, iconos y MIME instalados y registrados por los
#            disparadores de shared-mime-info / desktop-file-utils; arranca
#            "reportman-designer <ejemplo>.rep" bajo xvfb-run: debe seguir vivo a
#            los 15 s, con la ventana titulada con el informe y sin excepciones
#            en la salida; apt remove y purge dejan el sistema limpio.
#  appimage  ReportManDesigner-<v>-x86_64.AppImage --appimage-extract-and-run
#            <ejemplo>.rep igual, con solo las librerias que un escritorio
#            siempre tiene (X11, fontconfig, FreeType, HarfBuzz, fuentes).
# Registros y capturas en <artefactos>/tests/; resumen al final (codigo de
# salida 1 si falla alguna prueba).
#
# Variables: SAMPLE (informe de repman/repsamples, por defecto sample4.rep),
#            WAIT (segundos de ejecucion, 15), SHOTS=0 (sin capturas).
set -uo pipefail

SAMPLE=${SAMPLE:-sample4.rep}
WAIT=${WAIT:-15}
SHOTS=${SHOTS:-1}
EXC_RE='exception|access violation|unhandled|segmentation fault|^ERROR:|Fatal|core dumped'

# ======================================================================
# Parte que se ejecuta DENTRO del contenedor de prueba
# ======================================================================
if [ "${1:-}" = "--inside" ]; then
    MODE=$2 PKGFILE=$3 TAG=$4
    export DEBIAN_FRONTEND=noninteractive
    FAILS=0
    ok()   { echo "  [OK]   $*"; }
    fail() { echo "  [FAIL] $*"; FAILS=$((FAILS + 1)); }
    info() { echo "  [INFO] $*"; }
    apt_q() { apt-get -o Dpkg::Use-Pty=0 -q "$@"; }

    # run_designer <captura> <orden...>: arranca el disenador bajo Xvfb y
    # comprueba que sigue vivo a los $WAIT s y que su ventana existe. Corre en
    # su propio grupo de procesos (setsid) para terminarlo entero (la AppImage
    # lanza el programa como hijo); la salida se revisa tal como estaba antes
    # de terminarlo.
    run_designer() {
        local shot=$1; shift
        rm -f /tmp/run.out /tmp/run.snap /tmp/xwin.txt
        xvfb-run -a -s "-screen 0 1280x1024x24" bash -c '
            setsid "$@" > /tmp/run.out 2>&1 &
            pid=$!
            sleep '"$WAIT"'
            xwininfo -root -tree > /tmp/xwin.txt 2>&1 || true
            if [ -n "'"$shot"'" ] && command -v import >/dev/null 2>&1; then
                import -window root "'"$shot"'" >/dev/null 2>&1 || true
            fi
            cp /tmp/run.out /tmp/run.snap
            if kill -0 "$pid" 2>/dev/null; then
                kill -- -"$pid" 2>/dev/null; sleep 1; kill -9 -- -"$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
                exit 0
            fi
            wait "$pid"; echo "EXITED rc=$?" >> /tmp/run.snap
            exit 1' _ "$@"
        local rc=$?
        echo "  ---- salida del disenador:"
        sed 's/^/  | /' /tmp/run.snap | tail -n 40
        if [ $rc -eq 0 ]; then ok "sigue vivo a los ${WAIT}s"; else fail "el disenador ha terminado antes de ${WAIT}s"; fi
        if grep -Eiq "$EXC_RE" /tmp/run.snap; then
            fail "excepciones/errores en la salida"
        else
            ok "sin excepciones en la salida"
        fi
        local title
        title=$(grep -o '"Report Manager Designer[^"]*"' /tmp/xwin.txt | head -n 1)
        if echo "$title" | grep -q "\[$SAMPLE\]"; then
            ok "ventana principal: $title"
        else
            fail "no aparece la ventana con el informe abierto (titulo: ${title:-ninguno})"
        fi
    }

    echo "==== $TAG / $MODE: $(. /etc/os-release && echo "$PRETTY_NAME")"
    apt_q update >/dev/null

    if [ "$MODE" = deb ]; then
        BEFORE=$(dpkg-query -W -f='${Package}\n' | wc -l)
        echo "-- apt install ./$(basename "$PKGFILE")"
        cp "$PKGFILE" /tmp/
        if apt_q install -y "/tmp/$(basename "$PKGFILE")" > /tmp/apt.log 2>&1; then
            AFTER=$(dpkg-query -W -f='${Package}\n' | wc -l)
            ok "instalado; apt ha anadido $((AFTER - BEFORE)) paquetes (dependencias + recomendados)"
        else
            tail -n 30 /tmp/apt.log
            fail "apt install"; echo "RESULT $TAG $MODE FAIL"; exit 1
        fi
        EXE=/opt/reportman-designer/reportman-designer
        echo "-- dependencias"
        if ldd "$EXE" | grep -q "not found"; then
            ldd "$EXE" | grep "not found"; fail "ldd: librerias sin resolver"
        else
            ok "ldd: todas las librerias enlazadas resueltas"
        fi
        for l in libfreetype.so.6 libfontconfig.so.1 libharfbuzz.so.0 libsqlite3.so.0; do
            if ldconfig -p | grep -q "$l "; then ok "dlopen: $l"; else fail "dlopen: falta $l"; fi
        done
        icu=$(ldconfig -p | grep -o 'libicuuc\.so\.[0-9]*' | sort -u | head -n 1)
        if [ -n "$icu" ]; then ok "dlopen: $icu"; else fail "dlopen: falta libicuuc.so.N"; fi
        if ldconfig -p | grep -q 'libharfbuzz-subset.so.0 '; then
            ok "dlopen: libharfbuzz-subset.so.0 (recomendado)"
        else
            info "sin libharfbuzz-subset.so.0 (opcional; Ubuntu 22.04 no la tiene)"
        fi
        echo "-- ficheros"
        for f in /usr/bin/reportman-designer \
                 /usr/share/applications/reportman-designer.desktop \
                 /usr/share/mime/packages/reportman-designer.xml \
                 /usr/share/icons/hicolor/48x48/apps/reportman-designer.png \
                 /usr/share/icons/hicolor/scalable/apps/reportman-designer.svg \
                 "/opt/reportman-designer/samples/$SAMPLE" \
                 /opt/reportman-designer/reportmanres.es; do
            if [ -e "$f" ]; then ok "$f"; else fail "falta $f"; fi
        done
        # Las imagenes Docker minimas excluyen /usr/share/man al instalar
        # (dpkg path-exclude): se comprueba que el paquete la contiene
        if dpkg -L reportman-designer | grep -q '/usr/share/man/man1/reportman-designer.1.gz'; then
            ok "pagina de manual en el paquete"
        else
            fail "falta la pagina de manual en el paquete"
        fi
        echo "-- integracion con el escritorio (disparadores)"
        apt_q install -y --no-install-recommends shared-mime-info desktop-file-utils > /tmp/apt2.log 2>&1 \
            || { tail -n 20 /tmp/apt2.log; fail "apt install shared-mime-info desktop-file-utils"; }
        if [ -f /usr/share/mime/application/x-reportman-report.xml ]; then
            ok "MIME application/x-reportman-report registrado"
        else
            fail "MIME no registrado en /usr/share/mime"
        fi
        if grep -q 'application/x-reportman-report=.*reportman-designer.desktop' /usr/share/applications/mimeinfo.cache 2>/dev/null; then
            ok "mimeinfo.cache: *.rep se abre con reportman-designer.desktop"
        else
            fail "mimeinfo.cache sin la asociacion"
        fi
        desktop-file-validate /usr/share/applications/reportman-designer.desktop \
            && ok "desktop-file-validate" || fail "desktop-file-validate"
        echo "-- ejecucion"
        apt_q install -y --no-install-recommends xvfb xauth x11-utils > /tmp/apt3.log 2>&1 \
            || { tail -n 20 /tmp/apt3.log; fail "apt install xvfb"; }
        if [ "$SHOTS" = 1 ]; then
            apt_q install -y --no-install-recommends imagemagick > /dev/null 2>&1 || true
        fi
        # --version/--help no necesitan pantalla; sin DISPLAY avisa y sale
        VER=$(env -u DISPLAY reportman-designer --version 2>&1 | head -n 5)
        echo "$VER" | sed 's/^/  | /'
        echo "$VER" | grep -q "^Report Manager Designer" && ok "--version (sin pantalla)" || fail "--version"
        NODISP=$(env -u DISPLAY reportman-designer 2>&1); NRC=$?
        if [ $NRC -ne 0 ] && echo "$NODISP" | grep -q "cannot open the X display"; then
            ok "sin DISPLAY: aviso y codigo $NRC"
        else
            fail "sin DISPLAY: rc=$NRC, salida: $NODISP"
        fi
        SHOT=""; [ "$SHOTS" = 1 ] && SHOT="/res/$TAG-deb.png"
        cd /tmp && run_designer "$SHOT" reportman-designer "/opt/reportman-designer/samples/$SAMPLE"
        echo "-- desinstalacion"
        if apt_q remove -y reportman-designer > /tmp/apt4.log 2>&1; then ok "apt remove"; else tail -n 20 /tmp/apt4.log; fail "apt remove"; fi
        for f in /opt/reportman-designer /usr/bin/reportman-designer \
                 /usr/share/applications/reportman-designer.desktop \
                 /usr/share/mime/packages/reportman-designer.xml \
                 /usr/share/mime/application/x-reportman-report.xml \
                 /usr/share/icons/hicolor/48x48/apps/reportman-designer.png; do
            if [ -e "$f" ] || [ -L "$f" ]; then fail "queda $f"; else ok "borrado $f"; fi
        done
        if grep -q reportman-designer /usr/share/applications/mimeinfo.cache 2>/dev/null; then
            fail "mimeinfo.cache conserva la asociacion"
        else
            ok "mimeinfo.cache limpio"
        fi
        apt_q purge -y reportman-designer > /dev/null 2>&1
        if dpkg-query -W -f='${Status}' reportman-designer 2>/dev/null | grep -q installed; then
            fail "dpkg sigue viendo el paquete"
        else
            ok "purge: sin rastro en dpkg"
        fi
    else
        echo "-- entorno minimo de escritorio (X11, fontconfig, FreeType, HarfBuzz, fuentes)"
        apt_q install -y --no-install-recommends xvfb xauth x11-utils libfontconfig1 \
            libfreetype6 libharfbuzz0b fonts-dejavu-core > /tmp/apt.log 2>&1 \
            || { tail -n 20 /tmp/apt.log; fail "apt install"; }
        if [ "$SHOTS" = 1 ]; then
            apt_q install -y --no-install-recommends imagemagick > /dev/null 2>&1 || true
        fi
        cp "$PKGFILE" /tmp/rm.AppImage && chmod +x /tmp/rm.AppImage
        echo "-- dependencias (AppImage extraida)"
        (cd /tmp && ./rm.AppImage --appimage-extract > /dev/null 2>&1)
        EXE=/tmp/squashfs-root/opt/reportman-designer/reportman-designer
        if [ -x "$EXE" ]; then
            nf=$(ldd "$EXE" | grep "not found" || true)
            if [ -n "$nf" ]; then echo "$nf"; fail "ldd: librerias sin resolver"; else ok "ldd: todas resueltas (incluidas + sistema)"; fi
            info "del sistema: $(ldd "$EXE" | grep -v squashfs-root | grep -o '^[[:space:]]*[^ ]*\.so[^ ]*' | tr -d '\t' | tr '\n' ' ')"
        else
            fail "no se pudo extraer la AppImage"
        fi
        rm -rf /tmp/squashfs-root
        VER=$(env -u DISPLAY /tmp/rm.AppImage --appimage-extract-and-run --version 2>&1 | head -n 5)
        echo "$VER" | sed 's/^/  | /'
        echo "$VER" | grep -q "^Report Manager Designer" && ok "--version" || fail "--version"
        SHOT=""; [ "$SHOTS" = 1 ] && SHOT="/res/$TAG-appimage.png"
        cd /tmp && run_designer "$SHOT" /tmp/rm.AppImage --appimage-extract-and-run "/samples/$SAMPLE"
    fi

    if [ $FAILS -eq 0 ]; then echo "RESULT $TAG $MODE PASS"; exit 0; fi
    echo "RESULT $TAG $MODE FAIL ($FAILS)"; exit 1
fi

# ======================================================================
# Orquestacion (en el anfitrion con Docker)
# ======================================================================
if [ $# -lt 1 ]; then
    echo "Uso: $0 <directorio de artefactos> [imagen...]" >&2
    exit 2
fi
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
OUTDIR=$(cd "$1" && pwd); shift
IMAGES=("$@")
[ ${#IMAGES[@]} -eq 0 ] && IMAGES=(ubuntu:22.04 ubuntu:24.04 debian:12)
DEB=$(ls "$OUTDIR"/reportman-designer_*_amd64.deb 2>/dev/null | head -n 1)
APPIMAGE=$(ls "$OUTDIR"/ReportManDesigner-*-x86_64.AppImage 2>/dev/null | head -n 1)
RES=$OUTDIR/tests
mkdir -p "$RES"
SUMMARY=()
RC=0

run_case() {   # run_case <imagen> <deb|appimage> <fichero>
    local img=$1 mode=$2 file=$3 tag log
    tag=$(echo "$img" | tr ':/' '--')
    log=$RES/$tag-$mode.log
    echo ">>> $img $mode"
    docker pull -q "$img" > /dev/null
    docker run --rm -e SAMPLE="$SAMPLE" -e WAIT="$WAIT" -e SHOTS="$SHOTS" \
        -v "$OUTDIR:/pkg:ro" -v "$HERE:/tests:ro" -v "$RES:/res" \
        -v "$REPO/repman/repsamples:/samples:ro" \
        "$img" bash /tests/test-packages.sh --inside "$mode" "/pkg/$(basename "$file")" "$tag" \
        > "$log" 2>&1
    local r=$?
    grep -E '^\s+\[(FAIL|INFO)\]' "$log" || true
    SUMMARY+=("$(tail -n 1 "$log")")
    [ $r -ne 0 ] && RC=1
}

for img in "${IMAGES[@]}"; do
    if [ -n "$DEB" ]; then run_case "$img" deb "$DEB"; fi
    if [ -n "$APPIMAGE" ]; then run_case "$img" appimage "$APPIMAGE"; fi
done
echo
echo "==== Resumen ($(basename "${DEB:-sin .deb}"), $(basename "${APPIMAGE:-sin AppImage}"))"
printf '%s\n' "${SUMMARY[@]}" | tee "$RES/summary.txt"
exit $RC

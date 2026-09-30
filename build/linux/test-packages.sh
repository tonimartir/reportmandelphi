#!/bin/bash
# Fase 6.6/6.8: pruebas de los paquetes en maquinas limpias (contenedores
# nuevos de cada distro). Se ejecuta donde haya Docker (WSL en Windows; lo
# llama build-linux.ps1):
#
#   test-packages.sh <directorio de artefactos> [imagen...]
#
# Imagenes por defecto: ubuntu:22.04 ubuntu:24.04 debian:12 debian:13
# ubuntu:26.04. En cada una, en contenedores separados:
#  deb       reportman-designer_<v>_amd64.deb (Qt6) y
#  deb-gtk2  reportman-designer-gtk2_<v>_amd64.deb (GTK2):
#            apt install ./<paquete>.deb sin nada mas instalado (apt debe
#            traer todas las dependencias); ldd sin "not found" (Qt6:
#            libQt6Pas privada por RUNPATH, plugin xcb de Qt) y las librerias
#            que el motor abre con dlopen presentes; .desktop, iconos y MIME
#            instalados y registrados por los disparadores de shared-mime-info /
#            desktop-file-utils; --version y el aviso sin pantalla; arranca
#            "reportman-designer <ejemplo>.rep" bajo xvfb-run: debe seguir vivo
#            a los 15 s, con la ventana titulada con el informe y sin
#            excepciones en la salida (Qt6: tambien en una sesion Wayland
#            simulada, donde debe usar X11/XWayland); instalar la otra variante
#            la sustituye y volver a instalar esta, tambien; apt remove y
#            purge dejan el sistema limpio.
#  appimage  ReportManDesigner-<v>-x86_64.AppImage (Qt6)
#            --appimage-extract-and-run <ejemplo>.rep igual, con solo lo que un
#            escritorio siempre tiene (X11, fontconfig, FreeType, HarfBuzz,
#            fuentes, libegl1 y libopengl0 de glvnd).
# Registros y capturas en <artefactos>/tests/; resumen al final (codigo de
# salida 1 si falla alguna prueba).
#
# Variables: SAMPLE (informe de repman/repsamples, por defecto sample4.rep),
#            WAIT (segundos de ejecucion, 15), SHOTS=0 (sin capturas),
#            PARALLEL (contenedores a la vez, 5).
set -uo pipefail

SAMPLE=${SAMPLE:-sample4.rep}
WAIT=${WAIT:-15}
SHOTS=${SHOTS:-1}
PARALLEL=${PARALLEL:-5}
EXC_RE='exception|access violation|unhandled|segmentation fault|^ERROR:|Fatal|core dumped'

# ======================================================================
# Parte que se ejecuta DENTRO del contenedor de prueba
# ======================================================================
if [ "${1:-}" = "--inside" ]; then
    MODE=$2 PKGFILE=$3 TAG=$4 OTHERFILE=${5:-}
    export DEBIAN_FRONTEND=noninteractive
    FAILS=0
    ok()   { echo "  [OK]   $*"; }
    fail() { echo "  [FAIL] $*"; FAILS=$((FAILS + 1)); }
    info() { echo "  [INFO] $*"; }
    apt_q() { apt-get -o Dpkg::Use-Pty=0 -q "$@"; }
    pkg_status() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | tr -d ' '; }

    # run_designer <captura> <orden...>: arranca el disenador bajo Xvfb y
    # comprueba que sigue vivo a los $WAIT s y que su ventana existe. Corre en
    # su propio grupo de procesos (setsid) para terminarlo entero (la AppImage
    # lanza el programa como hijo); la salida se revisa tal como estaba antes
    # de terminarlo. Las variables de RUN_ENV (VAR=valor...) se pasan al
    # programa.
    RUN_ENV=()
    run_designer() {
        local shot=$1; shift
        rm -f /tmp/run.out /tmp/run.snap /tmp/xwin.txt
        xvfb-run -a -s "-screen 0 1280x1024x24" bash -c '
            setsid env "$@" > /tmp/run.out 2>&1 &
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
            exit 1' _ "${RUN_ENV[@]}" "$@"
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

    # check_installed <paquete> <widgetset>: la variante instalada es esa
    check_installed() {
        local pkg=$1 ws=$2 v
        if [ "$(pkg_status "$pkg")" = ii ]; then ok "$pkg instalado"; else fail "$pkg no esta instalado ($(pkg_status "$pkg"))"; fi
        v=$(env -u DISPLAY reportman-designer --version 2>&1 | head -n 1)
        if echo "$v" | grep -q "(LCL $ws)"; then ok "reportman-designer es la variante $ws: $v"; else fail "reportman-designer no es $ws: $v"; fi
        if [ "$ws" = qt6 ]; then
            [ -e /opt/reportman-designer/lib/libQt6Pas.so.6 ] && ok "libQt6Pas privada presente" || fail "falta /opt/reportman-designer/lib/libQt6Pas.so.6"
        else
            [ ! -e /opt/reportman-designer/lib ] && ok "sin /opt/reportman-designer/lib (GTK2)" || fail "queda /opt/reportman-designer/lib"
        fi
        for f in /usr/share/applications/reportman-designer.desktop /usr/share/mime/packages/reportman-designer.xml; do
            [ -e "$f" ] && ok "$f" || fail "falta $f"
        done
        if grep -q 'application/x-reportman-report=.*reportman-designer.desktop' /usr/share/applications/mimeinfo.cache 2>/dev/null; then
            ok "mimeinfo.cache: *.rep sigue asociado"
        else
            fail "mimeinfo.cache sin la asociacion"
        fi
    }

    echo "==== $TAG / $MODE: $(. /etc/os-release && echo "$PRETTY_NAME")"
    apt_q update >/dev/null

    if [ "$MODE" = deb ] || [ "$MODE" = deb-gtk2 ]; then
        PKG=$(dpkg-deb -f "$PKGFILE" Package)
        WS=qt6; [ "$MODE" = deb-gtk2 ] && WS=gtk2
        BEFORE=$(dpkg-query -W -f='${Package}\n' | wc -l)
        echo "-- apt install ./$(basename "$PKGFILE") ($PKG, $WS)"
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
        if ldd "$EXE" | grep "not found" >/dev/null; then
            ldd "$EXE" | grep "not found"; fail "ldd: librerias sin resolver"
        else
            ok "ldd: todas las librerias enlazadas resueltas"
        fi
        if [ "$WS" = qt6 ]; then
            q=$(ldd "$EXE" | grep -o 'libQt6Pas.so.6 => [^ ]*')
            if [ "$q" = "libQt6Pas.so.6 => /opt/reportman-designer/lib/libQt6Pas.so.6" ]; then
                ok "RUNPATH: $q"
            else
                fail "libQt6Pas no se resuelve desde /opt/reportman-designer/lib ($q)"
            fi
            info "Qt6 de la distribucion: $(dpkg-query -W -f='${db:Status-Abbrev}${Package} ${Version}\n' 'libqt6core6*' 2>/dev/null | sed -n 's/^ii *//p' | tr '\n' ' ')"
            xcb=$(find /usr/lib/x86_64-linux-gnu/qt6/plugins/platforms -name libqxcb.so 2>/dev/null | head -n 1)
            if [ -n "$xcb" ] && ! ldd "$xcb" | grep "not found" >/dev/null; then
                ok "plugin de plataforma xcb: $xcb"
            else
                fail "falta el plugin xcb de Qt6 (o sus dependencias)"
            fi
        fi
        # grep sin -q tras una tuberia: con pipefail, grep -q cierra la tuberia
        # al encontrar la linea y ldconfig/ldd/dpkg acaban con SIGPIPE (falso
        # fallo segun el orden de la salida)
        for l in libfreetype.so.6 libfontconfig.so.1 libharfbuzz.so.0 libsqlite3.so.0; do
            if ldconfig -p | grep "$l " >/dev/null; then ok "dlopen: $l"; else fail "dlopen: falta $l"; fi
        done
        icu=$(ldconfig -p | grep -o 'libicuuc\.so\.[0-9]*' | sort -u | head -n 1)
        if [ -n "$icu" ]; then ok "dlopen: $icu"; else fail "dlopen: falta libicuuc.so.N"; fi
        if ldconfig -p | grep 'libharfbuzz-subset.so.0 ' >/dev/null; then
            ok "dlopen: libharfbuzz-subset.so.0 (recomendado)"
        else
            info "sin libharfbuzz-subset.so.0 (opcional; Ubuntu 22.04 no la tiene)"
        fi
        echo "-- ficheros"
        for f in /usr/bin/reportman-designer \
                 /usr/share/applications/reportman-designer.desktop \
                 /usr/share/mime/packages/reportman-designer.xml \
                 /usr/share/icons/hicolor/48x48/apps/reportman-designer.png \
                 /usr/share/icons/hicolor/256x256/apps/reportman-designer.png \
                 "/opt/reportman-designer/samples/$SAMPLE" \
                 /opt/reportman-designer/reportmanres.es \
                 /opt/reportman-designer/languages/lclstrconsts.es.po \
                 "/usr/share/doc/$PKG/copyright"; do
            if [ -e "$f" ]; then ok "$f"; else fail "falta $f"; fi
        done
        # Las imagenes Docker minimas excluyen /usr/share/man al instalar
        # (dpkg path-exclude): se comprueba que el paquete la contiene
        if dpkg -L "$PKG" | grep '/usr/share/man/man1/reportman-designer.1.gz' >/dev/null; then
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
        # --version/--help no necesitan pantalla; sin pantalla avisa y sale
        VER=$(env -u DISPLAY reportman-designer --version 2>&1 | head -n 6)
        echo "$VER" | sed 's/^/  | /'
        echo "$VER" | grep -q "^Report Manager Designer .*(LCL $WS)" && ok "--version (sin pantalla)" || fail "--version"
        NODISP=$(env -u DISPLAY -u WAYLAND_DISPLAY reportman-designer 2>&1); NRC=$?
        if [ $NRC -ne 0 ] && echo "$NODISP" | grep -Eq "cannot open the (X )?display"; then
            ok "sin pantalla: aviso y codigo $NRC"
        else
            fail "sin pantalla: rc=$NRC, salida: $NODISP"
        fi
        SHOT=""; [ "$SHOTS" = 1 ] && SHOT="/res/$TAG-$MODE.png"
        cd /tmp && run_designer "$SHOT" reportman-designer "/opt/reportman-designer/samples/$SAMPLE"
        if [ "$WS" = qt6 ]; then
            # Sesion Wayland (sin compositor: WAYLAND_DISPLAY no existe) con
            # XWayland (DISPLAY de Xvfb) y el plugin wayland de Qt instalado:
            # si Qt eligiera Wayland no habria ventana en X. Debe usar xcb.
            echo "-- sesion Wayland simulada (qt6-wayland instalado)"
            apt_q install -y --no-install-recommends qt6-wayland > /tmp/apt5.log 2>&1 \
                || { tail -n 20 /tmp/apt5.log; fail "apt install qt6-wayland"; }
            mkdir -p -m 0700 /tmp/xdg
            RUN_ENV=(XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-rm XDG_RUNTIME_DIR=/tmp/xdg)
            SHOT=""; [ "$SHOTS" = 1 ] && SHOT="/res/$TAG-$MODE-wayland.png"
            run_designer "$SHOT" reportman-designer "/opt/reportman-designer/samples/$SAMPLE"
            RUN_ENV=()
        fi
        if [ -n "$OTHERFILE" ]; then
            OTHERPKG=$(dpkg-deb -f "$OTHERFILE" Package)
            OTHERWS=gtk2; [ "$WS" = gtk2 ] && OTHERWS=qt6
            echo "-- la otra variante sustituye a esta: apt install ./$(basename "$OTHERFILE")"
            cp "$OTHERFILE" /tmp/
            if apt_q install -y "/tmp/$(basename "$OTHERFILE")" > /tmp/apt6.log 2>&1; then
                ok "apt install $OTHERPKG"
                grep -E "^(Removing|Unpacking|Replacing|The following packages will be REMOVED)" /tmp/apt6.log | sed 's/^/  | /'
            else
                tail -n 30 /tmp/apt6.log; fail "apt install $OTHERPKG"
            fi
            [ "$(pkg_status "$PKG")" != ii ] && ok "$PKG desinstalado por $OTHERPKG" || fail "$PKG sigue instalado junto a $OTHERPKG"
            check_installed "$OTHERPKG" "$OTHERWS"
            echo "-- y al reves: apt install ./$(basename "$PKGFILE")"
            if apt_q install -y "/tmp/$(basename "$PKGFILE")" > /tmp/apt7.log 2>&1; then
                ok "apt install $PKG"
            else
                tail -n 30 /tmp/apt7.log; fail "apt install $PKG"
            fi
            [ "$(pkg_status "$OTHERPKG")" != ii ] && ok "$OTHERPKG desinstalado por $PKG" || fail "$OTHERPKG sigue instalado junto a $PKG"
            check_installed "$PKG" "$WS"
        fi
        echo "-- desinstalacion"
        if apt_q remove -y "$PKG" > /tmp/apt4.log 2>&1; then ok "apt remove $PKG"; else tail -n 20 /tmp/apt4.log; fail "apt remove"; fi
        for f in /opt/reportman-designer /usr/bin/reportman-designer \
                 /usr/share/applications/reportman-designer.desktop \
                 /usr/share/mime/packages/reportman-designer.xml \
                 /usr/share/mime/application/x-reportman-report.xml \
                 /usr/share/icons/hicolor/48x48/apps/reportman-designer.png \
                 "/usr/share/doc/$PKG"; do
            if [ -e "$f" ] || [ -L "$f" ]; then fail "queda $f"; else ok "borrado $f"; fi
        done
        if grep -q reportman-designer /usr/share/applications/mimeinfo.cache 2>/dev/null; then
            fail "mimeinfo.cache conserva la asociacion"
        else
            ok "mimeinfo.cache limpio"
        fi
        # La variante sustituida queda "rc" (quitada, con su postrm pendiente
        # de purge), como cualquier paquete quitado por un Conflicts
        apt_q purge -y "$PKG" > /dev/null 2>&1
        if [ -n "$OTHERFILE" ] && [ "$(pkg_status "$OTHERPKG")" = rc ]; then
            apt_q purge -y "$OTHERPKG" > /dev/null 2>&1
        fi
        for p in reportman-designer reportman-designer-gtk2; do
            s=$(pkg_status "$p")
            case "$s" in
                ""|un) ok "purge: sin rastro de $p en dpkg${s:+ ($s)}" ;;
                *) fail "dpkg sigue viendo $p ($s)" ;;
            esac
        done
    else
        echo "-- entorno minimo de escritorio (X11, fontconfig, FreeType, HarfBuzz, fuentes, EGL/OpenGL de glvnd)"
        apt_q install -y --no-install-recommends xvfb xauth x11-utils libx11-6 libx11-xcb1 libxcb1 \
            libfontconfig1 libfreetype6 libharfbuzz0b fonts-dejavu-core libegl1 libopengl0 > /tmp/apt.log 2>&1 \
            || { tail -n 20 /tmp/apt.log; fail "apt install"; }
        if [ "$SHOTS" = 1 ]; then
            apt_q install -y --no-install-recommends imagemagick > /dev/null 2>&1 || true
        fi
        cp "$PKGFILE" /tmp/rm.AppImage && chmod +x /tmp/rm.AppImage
        echo "-- dependencias (AppImage extraida)"
        (cd /tmp && ./rm.AppImage --appimage-extract > /dev/null 2>&1)
        R=/tmp/squashfs-root
        EXE=$R/opt/reportman-designer/reportman-designer
        if [ -x "$EXE" ]; then
            nf=$(ldd "$EXE" | grep "not found" || true)
            if [ -n "$nf" ]; then echo "$nf"; fail "ldd: librerias sin resolver"; else ok "ldd: todas resueltas (incluidas + sistema)"; fi
            info "del sistema: $(ldd "$EXE" | grep -v squashfs-root | grep -o '^[[:space:]]*[^ ]*\.so[^ ]*' | tr -d '\t' | tr '\n' ' ')"
            # Plugins de Qt (con las librerias del AppDir); libcups es la del
            # sistema (aqui no hay CUPS: sin impresoras, no es un fallo)
            for p in $(cd "$R/usr/plugins" && find . -name '*.so' | sort); do
                nf=$(LD_LIBRARY_PATH=$R/usr/lib ldd "$R/usr/plugins/$p" | grep "not found" | grep -v 'libcups.so.2' || true)
                if [ -n "$nf" ]; then echo "$nf"; fail "plugin $p: librerias sin resolver"; else ok "plugin $p"; fi
            done
            for l in libEGL.so.1 libOpenGL.so.0 libGLX.so.0 libGL.so.1; do
                [ -e "$R/usr/lib/$l" ] && fail "la AppImage incluye $l (debe ser la del sistema)"
            done
            [ -f "$R/opt/reportman-designer/qt.conf" ] && ok "qt.conf junto al ejecutable" || fail "falta qt.conf"
        else
            fail "no se pudo extraer la AppImage"
        fi
        rm -rf "$R"
        VER=$(env -u DISPLAY /tmp/rm.AppImage --appimage-extract-and-run --version 2>&1 | head -n 6)
        echo "$VER" | sed 's/^/  | /'
        echo "$VER" | grep -q "^Report Manager Designer .*(LCL qt6)" && ok "--version" || fail "--version"
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
[ ${#IMAGES[@]} -eq 0 ] && IMAGES=(ubuntu:22.04 ubuntu:24.04 debian:12 debian:13 ubuntu:26.04)
DEB=$(ls "$OUTDIR"/reportman-designer_*_amd64.deb 2>/dev/null | head -n 1)
DEBGTK2=$(ls "$OUTDIR"/reportman-designer-gtk2_*_amd64.deb 2>/dev/null | head -n 1)
APPIMAGE=$(ls "$OUTDIR"/ReportManDesigner-*-x86_64.AppImage 2>/dev/null | head -n 1)
RES=$OUTDIR/tests
mkdir -p "$RES"
rm -f "$RES"/*.log "$RES"/*.png "$RES/summary.txt"

run_case() {   # run_case <imagen> <deb|deb-gtk2|appimage> <fichero> [otra variante]
    local img=$1 mode=$2 file=$3 other=${4:-} tag log
    tag=$(echo "$img" | tr ':/' '--')
    log=$RES/$tag-$mode.log
    docker run --rm -e SAMPLE="$SAMPLE" -e WAIT="$WAIT" -e SHOTS="$SHOTS" \
        -v "$OUTDIR:/pkg:ro" -v "$HERE:/tests:ro" -v "$RES:/res" \
        -v "$REPO/repman/repsamples:/samples:ro" \
        "$img" bash /tests/test-packages.sh --inside "$mode" "/pkg/$(basename "$file")" "$tag" \
        ${other:+"/pkg/$(basename "$other")"} > "$log" 2>&1
    echo "<<< $img $mode: $(tail -n 1 "$log")"
}

CASES=()
for img in "${IMAGES[@]}"; do
    docker pull -q "$img" > /dev/null
    if [ -n "$DEB" ]; then CASES+=("$img deb $DEB $DEBGTK2"); fi
    if [ -n "$DEBGTK2" ]; then CASES+=("$img deb-gtk2 $DEBGTK2 $DEB"); fi
    if [ -n "$APPIMAGE" ]; then CASES+=("$img appimage $APPIMAGE"); fi
done
echo "==== ${#CASES[@]} pruebas, $PARALLEL a la vez"
for c in "${CASES[@]}"; do
    # shellcheck disable=SC2086
    run_case $c &
    while [ "$(jobs -rp | wc -l)" -ge "$PARALLEL" ]; do wait -n; done
done
wait

SUMMARY=()
RC=0
for c in "${CASES[@]}"; do
    read -r img mode _ <<< "$c"
    log=$RES/$(echo "$img" | tr ':/' '--')-$mode.log
    grep -E '^\s+\[(FAIL|INFO)\]' "$log" | sed "s|^|$img $mode:|" || true
    last=$(tail -n 1 "$log")
    case "$last" in
        "RESULT "*" PASS") ;;
        "RESULT "*) RC=1 ;;
        *) RC=1; last="RESULT $img $mode FAIL (sin resultado: ver $log)" ;;
    esac
    SUMMARY+=("$last")
done
echo
echo "==== Resumen ($(basename "${DEB:-sin .deb Qt6}"), $(basename "${DEBGTK2:-sin .deb GTK2}"), $(basename "${APPIMAGE:-sin AppImage}"))"
printf '%s\n' "${SUMMARY[@]}" | tee "$RES/summary.txt"
exit $RC

#!/bin/bash
# Spike Qt5 de la Fase 6.1: compila el disenador con --ws=qt5 en la imagen de
# build y lo arranca 15 s bajo Xvfb. No se empaqueta (se distribuye GTK2).
#
#   docker run --rm -v <repo>:/src:ro -v <salida>:/out reportman-linux-builder \
#       bash /src/build/linux/spike-qt5.sh
#
# Deja en /out: repmandesigner_lcl-qt5, qt5-run.log y qt5-shot.png.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
SAMPLE=${SAMPLE:-sample4.rep}

echo "==== Instalando libqt5pas-dev (Ubuntu 22.04)"
apt-get update -qq
apt-get install -y -q --no-install-recommends libqt5pas-dev qt5-gtk-platformtheme x11-utils > /dev/null
dpkg-query -W -f='${Package} ${Version}\n' libqt5pas1 libqt5pas-dev libqt5core5a
# La libqt5pas de Ubuntu 22.04 (2.6) es anterior a la que espera la LCL de
# Lazarus 4.8 (faltan QGuiApplication_applicationState, QTimer_singleShot3...
# al enlazar): se sustituye por la de libqt5pas upstream (la que recomienda el
# wiki de Lazarus), QT5PAS=distro deja la de la distribucion.
if [ "${QT5PAS:-upstream}" = upstream ]; then
    QURL=https://github.com/davidbannon/libqt5pas/releases/download/v1.2.16
    cd /tmp || exit 1
    curl -fsSL -O "$QURL/libqt5pas1_2.16-4_amd64.deb" -O "$QURL/libqt5pas-dev_2.16-4_amd64.deb"
    sha256sum libqt5pas1_2.16-4_amd64.deb libqt5pas-dev_2.16-4_amd64.deb
    apt-get install -y -q --allow-downgrades ./libqt5pas1_2.16-4_amd64.deb ./libqt5pas-dev_2.16-4_amd64.deb > /dev/null
    dpkg-query -W -f='${Package} ${Version}\n' libqt5pas1 libqt5pas-dev
    cd /
fi

echo "==== Compilacion --ws=qt5"
if ! bash /src/build/linux/build-in-container.sh --ws=qt5; then
    echo "SPIKE QT5: la compilacion ha fallado"
    exit 1
fi

BIN=/out/repmandesigner_lcl-qt5
echo "==== ldd (Qt)"
ldd "$BIN" | grep -i -E 'qt|not found'

echo "==== Arranque bajo Xvfb (${SAMPLE}, 15 s)"
cd /tmp || exit 1
xvfb-run -a -s "-screen 0 1280x1024x24" bash -c '
    QT_QPA_PLATFORM=xcb "$1" "$2" > /out/qt5-run.log 2>&1 &
    pid=$!
    sleep 15
    xwininfo -root -tree | grep -o "\"Report Manager Designer[^\"]*\"" | head -n 3
    import -window root /out/qt5-shot.png 2>/dev/null || true
    if kill -0 $pid 2>/dev/null; then echo "SPIKE QT5: vivo a los 15 s"; kill $pid; else wait $pid; echo "SPIKE QT5: terminado rc=$?"; fi
' _ "$BIN" "/build/src/repman/repsamples/$SAMPLE"
echo "---- salida del disenador (qt5):"
tail -n 30 /out/qt5-run.log

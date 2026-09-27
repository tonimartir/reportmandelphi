#!/bin/bash
# Fase 6.5/6.8: arma ReportManDesigner-<RM_VERSION>-x86_64.AppImage (Qt6). Se
# ejecuta dentro de la imagen reportman-linux-builder (lo llama
# build-in-container.sh):
#
#   make-appimage.sh <arbol de fuentes> <ejecutable Release Qt6> <directorio de salida>
#
# El AppDir tiene el mismo arbol que el .deb (opt/reportman-designer con el
# ejecutable, las traducciones y los ejemplos) mas usr/bin/reportman-designer
# como enlace; linuxdeploy copia a usr/lib las dependencias del ejecutable
# (libQt6Pas de la imagen, Qt 6.2.4 de Ubuntu 22.04...) y de los plugins de Qt
# que se copian a usr/plugins (no hace falta linuxdeploy-plugin-qt):
#   platforms/libqxcb.so                 X11 (tambien XWayland)
#   platforminputcontexts/               teclas muertas/compose e IBus
#   printsupport/libcupsprintersupport   impresoras CUPS (con la libcups del
#                                        sistema; sin ella no hay impresoras)
# qt.conf junto al ejecutable hace que Qt solo busque plugins en el AppDir
# (nunca los de la Qt del sistema, de otra version).
#
# Librerias del sistema (no se incluyen):
#  - libEGL.so.1 y libOpenGL.so.0 (glvnd): las enlaza libQt6Gui; estan en la
#    "excludelist" de AppImage porque deben casar con el controlador grafico
#    del sistema, y todo escritorio con Mesa las tiene.
#  - FreeType, fontconfig y HarfBuzz: tambien en la excludelist (las usa Qt
#    para las fuentes y el motor por dlopen); asi libharfbuzz-subset.so.0 del
#    sistema casa con su libharfbuzz.so.0.
#  - libcups.so.2 (impresion): la del sistema, como con GTK2.
# Si se incluyen, aunque esten en la excludelist, libgpg-error.so.0 y
# libcom_err.so.2: las necesitan libgcrypt/libkrb5 (incluidas) y faltan en
# instalaciones minimas (Debian 13).
# Librerias que el motor abre con dlopen(): ICU (libicuuc.so.70, que ademas
# usa Qt) y SQLite (libsqlite3.so.0) se incluyen.
set -euo pipefail
. "$(dirname "$0")/common.sh"

if [ $# -ne 3 ]; then
    echo "Uso: $0 <arbol de fuentes> <ejecutable Qt6> <directorio de salida>" >&2
    exit 2
fi
SRC=$(cd "$1" && pwd)
BIN=$2
OUT=$3
VERSION=$(rm_version "$SRC")
APPIMAGE=$OUT/ReportManDesigner-${VERSION}-x86_64.AppImage
LIBDIR=/usr/lib/x86_64-linux-gnu
QTPLUGINS=$LIBDIR/qt6/plugins
QT6PAS_LIB=${QT6PAS_DIR:-/opt/libqt6pas}/lib

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
AD=$WORK/AppDir

echo "== make-appimage: $VERSION (Qt6)"
stage_app "$SRC" "$BIN" "$AD"
sed 's/\r$//' "$SRC/LICENSE.TXT" > "$AD$APP_PREFIX/LICENSE.TXT"
install -d -m 0755 "$AD/usr/bin" "$AD/usr/lib"
ln -s "../..$APP_PREFIX/$APP_ID" "$AD/usr/bin/$APP_ID"

# Plugins de Qt6 y qt.conf (Prefix relativo al directorio del ejecutable)
PLUGINS=(platforms/libqxcb.so
         platforminputcontexts/libcomposeplatforminputcontextplugin.so
         platforminputcontexts/libibusplatforminputcontextplugin.so)
DEPLOY=()
for p in "${PLUGINS[@]}"; do
    install -D -m 0644 "$QTPLUGINS/$p" "$AD/usr/plugins/$p"
    DEPLOY+=(--deploy-deps-only "$AD/usr/plugins/$p")
done
# El de CUPS no pasa por linuxdeploy: desplegaria las dependencias de libcups
# (GnuTLS, Kerberos, Avahi, p11-kit...), que solo usaria la libcups del
# sistema, que no las toma del AppDir. Sus demas dependencias son las Qt ya
# incluidas: basta el RUNPATH que linuxdeploy pone a los otros plugins.
p=printsupport/libcupsprintersupport.so
install -D -m 0644 "$QTPLUGINS/$p" "$AD/usr/plugins/$p"
patchelf --set-rpath '$ORIGIN/../../lib' "$AD/usr/plugins/$p"
cat > "$AD$APP_PREFIX/qt.conf" <<'EOF'
[Paths]
Prefix = ../../usr
Plugins = plugins
EOF

# libQt6Pas no esta en las rutas del sistema de la imagen: LD_LIBRARY_PATH
# para que linuxdeploy (ldd) la encuentre y la copie a usr/lib
(cd "$WORK" && LD_LIBRARY_PATH=$QT6PAS_LIB linuxdeploy \
    --appdir "$AD" \
    --deploy-deps-only "$AD$APP_PREFIX/$APP_ID" \
    "${DEPLOY[@]}" \
    --library "$LIBDIR/libicuuc.so.70" \
    --library "$LIBDIR/libsqlite3.so.0" \
    --desktop-file "$AD/usr/share/applications/$APP_ID.desktop" \
    --icon-file "$AD/usr/share/icons/hicolor/256x256/apps/$APP_ID.png")
# SQLdb (sqlite3dyn de FPC) abre "libsqlite3.so" cuando el sistema no tiene
# libsqlite3.so.0 en la ruta estandar: con el enlace encuentra la incluida.
ln -sf libsqlite3.so.0 "$AD/usr/lib/libsqlite3.so"
# En la excludelist pero no siempre presentes (ver la cabecera); no tienen
# mas dependencias que libc
for l in libgpg-error.so.0 libcom_err.so.2; do
    cp -L "$(ldconfig -p | awk -v l="$l" '$1 == l && /x86-64/ {print $NF; exit}')" "$AD/usr/lib/$l"
    chmod 0644 "$AD/usr/lib/$l"
done
for l in libQt6Pas.so.6 libQt6Core.so.6 libQt6Gui.so.6 libQt6Widgets.so.6 libQt6PrintSupport.so.6 libQt6XcbQpa.so.6; do
    [ -e "$AD/usr/lib/$l" ] || { echo "ERROR: falta usr/lib/$l en el AppDir" >&2; exit 1; }
done
for l in libEGL.so.1 libOpenGL.so.0 libGLX.so.0 libGL.so.1 libcups.so.2; do
    [ ! -e "$AD/usr/lib/$l" ] || { echo "ERROR: usr/lib/$l no debe incluirse" >&2; exit 1; }
done
# El plugin de CUPS solo debe necesitar libcups del sistema
nf=$(LD_LIBRARY_PATH=$AD/usr/lib ldd "$AD/usr/plugins/$p" | grep 'not found' | grep -v 'libcups.so.2' || true)
[ -z "$nf" ] || { echo "ERROR: $p: $nf" >&2; exit 1; }

echo "   AppRun: $(readlink "$AD/AppRun" || echo '(script)')"
echo "   RUNPATH: $(readelf -d "$AD$APP_PREFIX/$APP_ID" | grep -E 'RUNPATH|RPATH' || echo '(ninguno)')"
echo "   usr/lib: $(find "$AD/usr/lib" -maxdepth 1 -name '*.so*' | wc -l) librerias, $(du -sm "$AD/usr/lib" | cut -f1) MB"
echo "   plugins: $(cd "$AD/usr/plugins" && find . -name '*.so' | sort | tr '\n' ' ')"

# Fechas fijas (SOURCE_DATE_EPOCH o la de rpmdconsts.pas) para builds repetibles
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
    SOURCE_DATE_EPOCH=$(stat -c %Y "$SRC/rpmdconsts.pas")
fi
export SOURCE_DATE_EPOCH
find "$AD" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

mkdir -p "$OUT"
rm -f "$APPIMAGE"
# Runtime fijado en la imagen (sin descargas); sin informacion de
# actualizacion (no hay canal de actualizaciones todavia).
(cd "$WORK" && VERSION=$VERSION ARCH=x86_64 appimagetool \
    --runtime-file /opt/appimage/runtime-x86_64 \
    --no-appstream \
    "$AD" "$APPIMAGE")
chmod 0755 "$APPIMAGE"
ls -l "$APPIMAGE"

#!/bin/bash
# Fase 6.5: arma ReportManDesigner-<RM_VERSION>-x86_64.AppImage. Se ejecuta
# dentro de la imagen reportman-linux-builder (lo llama build-in-container.sh):
#
#   make-appimage.sh <arbol de fuentes> <ejecutable Release> <directorio de salida>
#
# El AppDir tiene el mismo arbol que el .deb (opt/reportman-designer con el
# ejecutable, las traducciones y los ejemplos) mas usr/bin/reportman-designer
# como enlace; linuxdeploy copia a usr/lib las dependencias del ejecutable y
# el plugin GTK (DEPLOY_GTK_VERSION=2) los modulos de GDK-Pixbuf y GLib.
#
# Librerias que el motor abre con dlopen():
#  - ICU (libicuuc.so.70) y SQLite (libsqlite3.so.0): se incluyen.
#  - FreeType, fontconfig y HarfBuzz: NO se incluyen. Estan en la "excludelist"
#    de AppImage (deben coincidir con las del sistema, que siempre las tiene
#    porque las usan Pango y GTK); asi libharfbuzz-subset.so.0 del sistema
#    casa con su libharfbuzz.so.0.
#  - CUPS (impresion, Printer4Lazarus): la del sistema.
set -euo pipefail
. "$(dirname "$0")/common.sh"

if [ $# -ne 3 ]; then
    echo "Uso: $0 <arbol de fuentes> <ejecutable> <directorio de salida>" >&2
    exit 2
fi
SRC=$(cd "$1" && pwd)
BIN=$2
OUT=$3
VERSION=$(rm_version "$SRC")
APPIMAGE=$OUT/ReportManDesigner-${VERSION}-x86_64.AppImage
LIBDIR=/usr/lib/x86_64-linux-gnu

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
AD=$WORK/AppDir

echo "== make-appimage: $VERSION"
stage_app "$SRC" "$BIN" "$AD"
sed 's/\r$//' "$SRC/LICENSE.TXT" > "$AD$APP_PREFIX/LICENSE.TXT"
install -d -m 0755 "$AD/usr/bin" "$AD/usr/lib"
ln -s "../..$APP_PREFIX/$APP_ID" "$AD/usr/bin/$APP_ID"

# Hook propio (se ejecuta despues del del plugin GTK, orden alfabetico): el
# plugin esta pensado para GTK3 y apunta GTK_DATA_PREFIX al AppDir, donde no
# hay temas GTK2; sin el, GTK2 usa los temas del sistema (/usr/share/themes).
install -d -m 0755 "$AD/apprun-hooks"
cat > "$AD/apprun-hooks/reportman-gtk2.sh" <<'EOF'
# Report Manager Designer (GTK2): temas GTK2 del sistema
unset GTK_DATA_PREFIX
unset GTK_THEME
EOF

export DEPLOY_GTK_VERSION=2
(cd "$WORK" && linuxdeploy \
    --appdir "$AD" \
    --deploy-deps-only "$AD$APP_PREFIX/$APP_ID" \
    --library "$LIBDIR/libicuuc.so.70" \
    --library "$LIBDIR/libsqlite3.so.0" \
    --desktop-file "$AD/usr/share/applications/$APP_ID.desktop" \
    --icon-file "$AD/usr/share/icons/hicolor/256x256/apps/$APP_ID.png" \
    --plugin gtk)
# SQLdb (sqlite3dyn de FPC) abre "libsqlite3.so" cuando el sistema no tiene
# libsqlite3.so.0 en la ruta estandar: con el enlace encuentra la incluida.
ln -sf libsqlite3.so.0 "$AD/usr/lib/libsqlite3.so"
# libfribidi (la usa Pango) esta en la excludelist de AppImage, pero no todos
# los sistemas la tienen: se incluye (no tiene dependencias y su ABI es estable).
cp -L "$LIBDIR/libfribidi.so.0" "$AD/usr/lib/"

echo "   AppRun:"
sed 's/^/     /' "$AD/AppRun"
echo "   RUNPATH: $(readelf -d "$AD$APP_PREFIX/$APP_ID" | grep -E 'RUNPATH|RPATH' || echo '(ninguno)')"
echo "   usr/lib: $(find "$AD/usr/lib" -maxdepth 1 -name '*.so*' | wc -l) librerias"

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

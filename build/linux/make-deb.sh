#!/bin/bash
# Fase 6.4: arma reportman-designer_<RM_VERSION>_amd64.deb. Se ejecuta dentro
# de la imagen reportman-linux-builder (lo llama build-in-container.sh):
#
#   make-deb.sh <arbol de fuentes> <ejecutable Release> <directorio de salida>
#
# Dependencias: las de enlace (GTK2, GLib, Pango, X11...) las calcula
# dpkg-shlibdeps sobre el ejecutable; se anaden a mano las librerias que el
# motor abre con dlopen(), que dpkg-shlibdeps no ve:
#   libfreetype.so.6 (rpfreetype2), libfontconfig.so.1 (rpfontconfig),
#   libharfbuzz.so.0 (rpHarfBuzz), libsqlite3.so.0 (SQLdb/Zeos),
#   libicuuc.so.<60..90> (rpICU, prueba versiones: de ahi las alternativas).
# libharfbuzz-subset.so.0 es opcional para el motor (sin ella el PDF incrusta
# la fuente entera) y Ubuntu 22.04 no la empaqueta: va en Recommends.
# Los nombres t64 (Ubuntu 24.04) se anaden como alternativas.
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
PKG=$APP_ID
DEB=$OUT/${PKG}_${VERSION}_amd64.deb

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ROOT=$WORK/root

echo "== make-deb: $PKG $VERSION"
stage_app "$SRC" "$BIN" "$ROOT"

# /usr/bin/reportman-designer -> /opt/reportman-designer/reportman-designer
# (enlace absoluto: une dos directorios raiz distintos)
install -d -m 0755 "$ROOT/usr/bin"
ln -s "$APP_PREFIX/$APP_ID" "$ROOT/usr/bin/$APP_ID"

# Pagina de manual
install -d -m 0755 "$ROOT/usr/share/man/man1"
sed "s/@VERSION@/$VERSION/" "$FILES_DIR/reportman-designer.1" \
    | gzip -9n > "$ROOT/usr/share/man/man1/$APP_ID.1.gz"

# Fecha reproducible: SOURCE_DATE_EPOCH o la de rpmdconsts.pas
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
    SOURCE_DATE_EPOCH=$(stat -c %Y "$SRC/rpmdconsts.pas")
fi
export SOURCE_DATE_EPOCH
PKGDATE=$(LC_ALL=C date -u -R -d "@$SOURCE_DATE_EPOCH")

# /usr/share/doc: copyright y changelog (paquete nativo: changelog.gz)
DOC=$ROOT/usr/share/doc/$PKG
install -d -m 0755 "$DOC"
{
    echo "Report Manager Designer (reportman-designer)"
    echo "Upstream: https://reportman.es  -  Toni Martir <toni@reportman.es>"
    echo
    echo "Copyright (c) 1994-2026 Toni Martir <toni@reportman.es>"
    echo
    echo "Report Manager is distributed under the Mozilla Public License 1.1"
    echo "(full text below), with the GNU General Public License as the"
    echo "alternative described in its Exhibit A (dual license). On Debian"
    echo "systems the GNU licenses are in /usr/share/common-licenses/."
    echo
    echo "The executable also contains, statically linked:"
    echo " - Free Pascal RTL/FCL and the Lazarus LCL: modified LGPL (LGPL with"
    echo "   static linking exception), https://www.freepascal.org"
    echo "   https://www.lazarus-ide.org"
    echo "   The LCL translations in $APP_PREFIX/languages"
    echo "   (lclstrconsts.*.po) are part of Lazarus, same license as the LCL."
    echo " - ZeosLib 8.0: LGPL 2.1 with static linking exception,"
    echo "   https://sourceforge.net/projects/zeoslib"
    echo " - Portions: PDF export base by K.Nishita; ZLib compression by"
    echo "   Jean-loup Gailly, Mark Adler and Jacques Nomssi Nzali; barcode"
    echo "   code by Andreas Schmidt and friends."
    echo
    echo "The LGPL is in /usr/share/common-licenses/LGPL-2.1."
    echo
    echo "------------------------------------------------------------------------"
    echo
    sed 's/\r$//' "$SRC/LICENSE.TXT"
} > "$DOC/copyright"
{
    echo "$PKG ($VERSION) unstable; urgency=medium"
    echo
    echo "  * Report Manager Designer $VERSION, LCL/GTK2 build for Linux."
    echo "    Release notes: https://reportman.es"
    echo
    echo " -- Toni Martir <toni@reportman.es>  $PKGDATE"
} | gzip -9n > "$DOC/changelog.gz"

install -D -m 0644 "$FILES_DIR/lintian-overrides" \
    "$ROOT/usr/share/lintian/overrides/$PKG"

# ---- Dependencias
mkdir -p "$WORK/shlibs/debian"
touch "$WORK/shlibs/debian/control"
SHLIBS=$(cd "$WORK/shlibs" && dpkg-shlibdeps -O -e"$ROOT$APP_PREFIX/$APP_ID" \
    | sed -n 's/^shlibs:Depends=//p')
echo "   dpkg-shlibdeps: $SHLIBS"

declare -a DEPS=()
declare -A SEEN=()
add_dep() {                       # add_dep "<nombre> [(version)]"
    local item=$1 name=${1%% *}
    [ -n "${SEEN[$name]:-}" ] && return 0
    SEEN[$name]=1
    case "$name" in
        # Renombrados t64 en Ubuntu 24.04 (proveen el nombre antiguo con
        # version, pero la alternativa explicita es mas clara para apt)
        libgtk2.0-0|libglib2.0-0|libatk1.0-0|libcups2)
            local ver=${item#"$name"}
            item="$item | ${name}t64$ver" ;;
    esac
    DEPS+=("$item")
}
IFS=',' read -r -a parts <<< "$SHLIBS"
for p in "${parts[@]}"; do
    p=$(echo "$p" | sed 's/^ *//; s/ *$//')
    [ -n "$p" ] && add_dep "$p"
done
for p in libfreetype6 libfontconfig1 libharfbuzz0b libsqlite3-0 \
         "libicu70 | libicu71 | libicu72 | libicu73 | libicu74 | libicu75 | libicu76 | libicu77 | libicu78" \
         fonts-dejavu-core; do
    add_dep "$p"
done
DEPENDS=$(printf '%s, ' "${DEPS[@]}")
DEPENDS=${DEPENDS%, }
RECOMMENDS="fonts-liberation, libharfbuzz-subset0, libcups2 | libcups2t64"

# ---- DEBIAN/
install -d -m 0755 "$ROOT/DEBIAN"
install -m 0755 "$FILES_DIR/postinst" "$ROOT/DEBIAN/postinst"
install -m 0755 "$FILES_DIR/postrm" "$ROOT/DEBIAN/postrm"
find "$ROOT" -type d -exec chmod 0755 {} +
INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Architecture: amd64
Maintainer: Toni Martir <toni@reportman.es>
Installed-Size: $INSTALLED_SIZE
Depends: $DEPENDS
Recommends: $RECOMMENDS
Section: misc
Priority: optional
Homepage: https://reportman.es
Description: Report Manager report designer (LCL/GTK2)
 Report Manager Designer creates database reports (.rep files): bands,
 labels, expressions, charts, barcodes and images bound to SQL queries,
 with preview, printing and export to PDF and other formats.
 .
 This package installs the designer in /opt/reportman-designer together
 with its translations and sample reports, adds it to the applications
 menu and registers the application/x-reportman-report MIME type so that
 *.rep files open with a double click.
EOF
(cd "$ROOT" && find . -path ./DEBIAN -prune -o -type f -printf '%P\0' \
    | LC_ALL=C sort -z | xargs -0 md5sum > DEBIAN/md5sums)
chmod 0644 "$ROOT/DEBIAN/control" "$ROOT/DEBIAN/md5sums"

# Fechas de los ficheros fijadas a SOURCE_DATE_EPOCH: dos builds de los mismos
# fuentes dan el mismo .deb
find "$ROOT" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

mkdir -p "$OUT"
rm -f "$DEB"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB"
echo "   control:"
sed 's/^/     /' "$ROOT/DEBIAN/control"
ls -l "$DEB"

#!/bin/bash
# Fase 6.4/6.8: arma el .deb del disenador. Se ejecuta dentro de la imagen
# reportman-linux-builder (lo llama build-in-container.sh):
#
#   make-deb.sh <arbol de fuentes> <ejecutable Release> <directorio de salida> <qt6|gtk2>
#
# Dos variantes con los mismos ficheros, que se sustituyen una a otra al
# instalarlas (Conflicts + Replaces):
#   qt6   reportman-designer_<v>_amd64.deb        la recomendada
#   gtk2  reportman-designer-gtk2_<v>_amd64.deb   transitoria (GTK2 esta
#         abandonado; Debian 14 lo retirara), Provides: reportman-designer
#
# Qt6: libQt6Pas (el puente C de la LCL con Qt6) no esta en Ubuntu 22.04/24.04
# ni en Debian 12; se incluye la de la imagen como libreria privada en
# /opt/reportman-designer/lib y el ejecutable la encuentra por su RUNPATH
# ($ORIGIN/lib, patchelf). Se prefiere RUNPATH a un lanzador con
# LD_LIBRARY_PATH: solo afecta al ejecutable (no lo heredan los programas que
# abra el disenador), funciona igual desde /usr/bin, el menu o /opt, y ldd y
# dpkg-shlibdeps lo ven. El resto de Qt es el de la distribucion.
#
# Dependencias: las de enlace (Qt6 o GTK2, X11, libc...) las calcula
# dpkg-shlibdeps sobre el ejecutable y, en Qt6, sobre libQt6Pas; se anaden a
# mano las que se cargan en tiempo de ejecucion, que dpkg-shlibdeps no ve:
#   qt6-qpa-plugins (Qt6: el plugin xcb en Ubuntu 22.04; en las demas va en
#   libqt6gui6), libfreetype.so.6 (rpfreetype2), libfontconfig.so.1
#   (rpfontconfig), libharfbuzz.so.0 (rpHarfBuzz), libsqlite3.so.0
#   (SQLdb/Zeos), libicuuc.so.<60..90> (rpICU, prueba versiones: de ahi las
#   alternativas), libssl.so.3 + libcrypto.so.3 (Hub y driver rpdbHttp por
#   HTTPS: rphttpclientfpc carga OpenSSL 3 o 1.1) y ca-certificates (la
#   verificacion del certificado del servidor usa el almacen del sistema).
# libharfbuzz-subset.so.0 es opcional para el motor (sin ella el PDF incrusta
# la fuente entera) y Ubuntu 22.04 no la empaqueta: va en Recommends.
# Suggests: las librerias cliente de las conexiones FireDAC / SQLdb (libpq,
# MySQL o MariaDB, Firebird, FreeTDS, unixODBC); se cargan al conectar.
# Los nombres t64 (Ubuntu 24.04; libqt6core6t64 tambien en Debian 13 y Ubuntu
# 26.04) se anaden como alternativas.
set -euo pipefail
. "$(dirname "$0")/common.sh"

if [ $# -ne 4 ]; then
    echo "Uso: $0 <arbol de fuentes> <ejecutable> <directorio de salida> <qt6|gtk2>" >&2
    exit 2
fi
SRC=$(cd "$1" && pwd)
BIN=$2
OUT=$3
WS=$4
VERSION=$(rm_version "$SRC")
case "$WS" in
    qt6)  PKG=$APP_ID; OTHER=$APP_ID-gtk2 ;;
    gtk2) PKG=$APP_ID-gtk2; OTHER=$APP_ID ;;
    *) echo "Widgetset no empaquetado: $WS" >&2; exit 2 ;;
esac
DEB=$OUT/${PKG}_${VERSION}_amd64.deb

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# Arbol del paquete como el de debhelper (debian/<paquete>, con DEBIAN/): asi
# dpkg-shlibdeps lo reconoce y resuelve el $ORIGIN del RUNPATH
ROOT=$WORK/debian/$PKG
install -d -m 0755 "$ROOT/DEBIAN"
touch "$WORK/debian/control"

echo "== make-deb: $PKG $VERSION ($WS)"
stage_app "$SRC" "$BIN" "$ROOT"

if [ "$WS" = qt6 ]; then
    # libQt6Pas privada + RUNPATH (ver la cabecera)
    QT6PAS_LIB=${QT6PAS_DIR:-/opt/libqt6pas}/lib
    real=$(readlink -f "$QT6PAS_LIB/libQt6Pas.so.6")
    install -d -m 0755 "$ROOT$APP_PREFIX/lib"
    install -m 0644 "$real" "$ROOT$APP_PREFIX/lib/"
    ln -s "$(basename "$real")" "$ROOT$APP_PREFIX/lib/libQt6Pas.so.6"
    patchelf --set-rpath '$ORIGIN/lib' "$ROOT$APP_PREFIX/$APP_ID"
    echo "   RUNPATH: $(readelf -d "$ROOT$APP_PREFIX/$APP_ID" | grep -o 'RUNPATH.*')"
fi

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
    echo "Report Manager Designer ($PKG)"
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
    if [ "$WS" = qt6 ]; then
        echo
        echo "$APP_PREFIX/lib/libQt6Pas.so.* is the Qt6 binding of the Lazarus"
        echo "LCL (lcl/interfaces/qt6/cbindings of Lazarus, built unmodified"
        echo "against Qt 6): LGPL 3 (modified LGPL, like the LCL),"
        echo "https://www.lazarus-ide.org. Qt 6 itself is used from the"
        echo "distribution packages."
    fi
    echo
    echo "The LGPL is in /usr/share/common-licenses/LGPL-2.1 (and LGPL-3)."
    echo
    echo "------------------------------------------------------------------------"
    echo
    sed 's/\r$//' "$SRC/LICENSE.TXT"
} > "$DOC/copyright"
{
    echo "$PKG ($VERSION) unstable; urgency=medium"
    echo
    if [ "$WS" = qt6 ]; then
        echo "  * Report Manager Designer $VERSION for Linux, LCL Qt6 build."
    else
        echo "  * Report Manager Designer $VERSION for Linux, LCL GTK2 build"
        echo "    (transitional; the recommended package is reportman-designer)."
    fi
    echo "    Release notes: https://reportman.es"
    echo
    echo " -- Toni Martir <toni@reportman.es>  $PKGDATE"
} | gzip -9n > "$DOC/changelog.gz"

# Overrides de lintian (files/lintian-overrides, escritos para
# reportman-designer) con el nombre de este paquete
install -d -m 0755 "$ROOT/usr/share/lintian/overrides"
sed "s/^$APP_ID:/$PKG:/" "$FILES_DIR/lintian-overrides" \
    > "$ROOT/usr/share/lintian/overrides/$PKG"
chmod 0644 "$ROOT/usr/share/lintian/overrides/$PKG"

# ---- Dependencias
# dpkg-shlibdeps sobre el ejecutable y, en Qt6, sobre libQt6Pas; esta no es de
# ningun paquete del sistema: shlibs.local la declara sin dependencia (va en
# este mismo paquete)
SHLIBS_OBJS=(-e"$ROOT$APP_PREFIX/$APP_ID")
if [ "$WS" = qt6 ]; then
    echo "libQt6Pas 6" > "$WORK/debian/shlibs.local"
    SHLIBS_OBJS+=(-e"$ROOT$APP_PREFIX/lib/libQt6Pas.so.6")
fi
SHLIBS=$(cd "$WORK" && dpkg-shlibdeps -O "${SHLIBS_OBJS[@]}" \
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
        # version, pero la alternativa explicita es mas clara para apt);
        # libqt6core6t64 tambien en Debian 13 / Ubuntu 26.04
        libgtk2.0-0|libglib2.0-0|libatk1.0-0|libcups2|libqt6[a-z]*6)
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
[ "$WS" = qt6 ] && add_dep qt6-qpa-plugins
for p in libfreetype6 libfontconfig1 libharfbuzz0b libsqlite3-0 \
         "libicu70 | libicu71 | libicu72 | libicu73 | libicu74 | libicu75 | libicu76 | libicu77 | libicu78" \
         "libssl3 | libssl3t64" ca-certificates \
         fonts-dejavu-core; do
    add_dep "$p"
done
DEPENDS=$(printf '%s, ' "${DEPS[@]}")
DEPENDS=${DEPENDS%, }
RECOMMENDS="fonts-liberation, libharfbuzz-subset0, libcups2 | libcups2t64, xdg-utils"

# Las dos variantes instalan los mismos ficheros: cada una sustituye a la
# otra. La GTK2 provee ademas el nombre reportman-designer.
if [ "$WS" = qt6 ]; then
    RELATIONS="Conflicts: $OTHER
Replaces: $OTHER"
    SYNOPSIS="Report Manager report designer"
    BUILDDESC=" This package installs the designer (Qt 6 build) in
 /opt/reportman-designer together with its translations and sample
 reports, adds it to the applications menu and registers the
 application/x-reportman-report MIME type so that *.rep files open with a
 double click. The GTK2 build (reportman-designer-gtk2) is replaced when
 this package is installed."
else
    RELATIONS="Provides: $APP_ID (= $VERSION)
Conflicts: $OTHER
Replaces: $OTHER"
    SYNOPSIS="Report Manager report designer (GTK2 build, transitional)"
    BUILDDESC=" This is the GTK2 build of the designer, kept for a transition period
 for systems where the Qt 6 build (package reportman-designer) cannot be
 used. GTK2 is no longer maintained; prefer reportman-designer. Both
 packages install the same files in /opt/reportman-designer, the
 applications menu entry and the application/x-reportman-report MIME
 type, so installing one replaces the other."
fi

# ---- DEBIAN/
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
Suggests: libpq5, libmariadb3 | libmysqlclient21, libfbclient2, libsybdb5, libodbc2
$RELATIONS
Section: misc
Priority: optional
Homepage: https://reportman.es
Description: $SYNOPSIS
 Report Manager Designer creates database reports (.rep files): bands,
 labels, expressions, charts, barcodes and images bound to SQL queries,
 with preview, printing and export to PDF and other formats.
 .
$BUILDDESC
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

# shellcheck shell=bash
# Funciones comunes del empaquetado Linux de Report Manager Designer.
# Se incluye (source) desde make-deb.sh y make-appimage.sh.

LINUX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FILES_DIR=$LINUX_DIR/files
APP_ID=reportman-designer
APP_PREFIX=/opt/reportman-designer

# Version del producto: RM_VERSION de rpmdconsts.pas (como Get-RmVersion en
# build/sourceforge/_common.ps1).
rm_version() {
    local v
    v=$(sed -n "s/^[[:space:]]*RM_VERSION[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$1/rpmdconsts.pas" | head -n 1)
    if [ -z "$v" ]; then
        echo "ERROR: no encuentro RM_VERSION en $1/rpmdconsts.pas" >&2
        return 1
    fi
    echo "$v"
}

# stage_app <arbol de fuentes> <ejecutable> <raiz destino>
# Arbol comun del .deb y de la AppImage:
#   <raiz>/opt/reportman-designer/reportman-designer   ejecutable (sin simbolos)
#   <raiz>/opt/reportman-designer/reportmanres.*       traducciones (el motor
#                                                      las busca junto al exe)
#   <raiz>/opt/reportman-designer/samples/             informes de ejemplo y
#                                                      sus datos (sin los PDF)
#   <raiz>/usr/share/applications/reportman-designer.desktop
#   <raiz>/usr/share/mime/packages/reportman-designer.xml
#   <raiz>/usr/share/icons/hicolor/<n>x<n>/apps/reportman-designer.png
#   <raiz>/usr/share/icons/hicolor/scalable/apps/reportman-designer.svg
stage_app() {
    local src=$1 bin=$2 root=$3
    local app=$root$APP_PREFIX
    local f s d

    install -d -m 0755 "$app" "$app/samples"
    install -m 0755 "$bin" "$app/$APP_ID"
    strip --strip-all --remove-section=.comment --remove-section=.note "$app/$APP_ID"

    for f in "$src"/repman/reportmanres.*; do
        install -m 0644 "$f" "$app/"
    done
    # En Linux el motor elige la traduccion por el idioma de LANG (ca_ES ->
    # reportmanres.ca, cs_CZ -> reportmanres.cs); dos ficheros usan el
    # codigo de Windows
    if [ -f "$app/reportmanres.cat" ]; then ln -sf reportmanres.cat "$app/reportmanres.ca"; fi
    if [ -f "$app/reportmanres.csy" ]; then ln -sf reportmanres.csy "$app/reportmanres.cs"; fi
    find "$src/repman/repsamples" -maxdepth 1 -type f ! -iname '*.pdf' \
        -exec install -m 0644 {} "$app/samples/" \;

    install -D -m 0644 "$FILES_DIR/reportman-designer.desktop" \
        "$root/usr/share/applications/$APP_ID.desktop"
    install -D -m 0644 "$FILES_DIR/reportman-designer-mime.xml" \
        "$root/usr/share/mime/packages/$APP_ID.xml"

    # Iconos hicolor generados desde el SVG del proyecto (doc/favicon.svg)
    for s in 16 22 24 32 48 64 128 256 512; do
        d=$root/usr/share/icons/hicolor/${s}x${s}/apps
        install -d -m 0755 "$d"
        rsvg-convert -w "$s" -h "$s" -f png -o "$d/$APP_ID.png" "$src/doc/favicon.svg"
    done
    d=$root/usr/share/icons/hicolor/scalable/apps
    install -d -m 0755 "$d"
    sed 's/\r$//' "$src/doc/favicon.svg" > "$d/$APP_ID.svg"
    chmod 0644 "$d/$APP_ID.svg"
}

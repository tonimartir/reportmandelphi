#!/bin/bash
# Prepara en un Mac (Intel o Apple Silicon, macOS 11 o posterior) lo necesario
# para compilar Report Manager Designer con LCL-Cocoa, sin sudo y sin tocar
# /usr/local:
#
#   $RM_MACOS_TOOLS/fpc        FPC 3.2.2 (el del .dmg oficial, sin instalarlo;
#                              trae los compiladores x86_64 y aarch64)
#   $RM_MACOS_TOOLS/lazarus    Lazarus 4.8 (zip oficial de la arquitectura del
#                              Mac: x86_64 o aarch64)
#   $RM_MACOS_TOOLS/lazcfg     configuracion privada de lazbuild (--pcp)
#   $RM_MACOS_TOOLS/zeos       Zeos 8.0 (el commit del build de Linux)
#   $RM_MACOS_TOOLS/bin/lazbuild   envoltorio con --pcp, --lazarusdir y --compiler
#   $RM_MACOS_TOOLS/env.sh     . env.sh  pone bin/ y fpc/bin en el PATH
#
# RM_MACOS_TOOLS es ~/dev por defecto. Requisito previo: las Command Line Tools
# de Xcode (xcode-select --install). Despues:
#
#   . ~/dev/env.sh
#   LAZBUILD=lazbuild sh packages/fpc/build_fpc.sh
#
# Se usa FPC 3.2.2, el mismo que en Windows y Linux, aunque Lazarus 4.8 para
# macOS se publica con 3.2.4rc1: por eso las PPU que trae el zip de Lazarus se
# recompilan aqui una vez (lazbuild -B -r), porque lazbuild no lo hace solo.
# A esa copia de Lazarus se le aplican los parches de build/macos/patches
# (fallos de la LCL Cocoa que aun no estan corregidos en Lazarus).
#
# Se puede volver a ejecutar: solo descarga e instala lo que falta, y solo
# recompila Lazarus si cambian FPC o los parches ($RM_MACOS_TOOLS/lazarus/
# .rm-build). Asi la cache de GitHub Actions (.github/workflows/macos.yml)
# guarda $RM_MACOS_TOOLS sin las descargas ($RM_MACOS_TOOLS/dl).
set -euo pipefail

T=${RM_MACOS_TOOLS:-$HOME/dev}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
SF=https://downloads.sourceforge.net/project/lazarus
# El .dmg de FPC 3.2.2 es el mismo para Intel y Apple Silicon
FPC_DMG=fpc-3.2.2.intelarm64-macosx.dmg
FPC_DMG_URL="$SF/Lazarus%20macOS%20x86-64/Lazarus%204.0/$FPC_DMG"
FPC_DMG_MD5=50babbde74790a5b86bc63c1fa3250d0
case $(uname -m) in
    x86_64)
        LAZ_ZIP=lazarus-darwin-x86_64-4.8.zip
        LAZ_ZIP_URL="$SF/Lazarus%20macOS%20x86-64/Lazarus%204.8/$LAZ_ZIP"
        LAZ_ZIP_MD5=08f5b014ea5708c261baf6e56448502d ;;
    arm64)
        LAZ_ZIP=lazarus-darwin-aarch64-4.8.zip
        LAZ_ZIP_URL="$SF/Lazarus%20macOS%20aarch64/Lazarus%204.8/$LAZ_ZIP"
        LAZ_ZIP_MD5=cbae6277b656739f5846d363a9220d6b ;;
    *) echo "Arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
esac
ZEOS_COMMIT=c527f51a4663d6e6415e9e87e0f7c3480c1228b2

xcode-select -p > /dev/null || { echo "Faltan las Command Line Tools: xcode-select --install" >&2; exit 1; }

mkdir -p "$T/dl" "$T/bin" "$T/lazcfg"
cd "$T/dl"

# md5 publicado por SourceForge (el unico que publica)
fetch() {
    local url=$1 name=$2 sum=$3
    [ -f "$name" ] || curl -fL --retry 5 -o "$name" "$url"
    [ "$(md5 -q "$name")" = "$sum" ] || { echo "md5 incorrecto: $name" >&2; exit 1; }
}

# FPC: el contenido del paquete (usr/local) en $T/fpc, con su fpc.cfg
if [ ! -x "$T/fpc/bin/fpc" ]; then
    fetch "$FPC_DMG_URL" "$FPC_DMG" "$FPC_DMG_MD5"
    mnt=$(mktemp -d)
    hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$FPC_DMG" > /dev/null
    rm -rf "$T/fpcpkg"
    pkgutil --expand-full "$mnt"/*.mpkg/Contents/Packages/*.pkg "$T/fpcpkg"
    hdiutil detach "$mnt" > /dev/null
    rm -rf "$T/fpc"
    mv "$T/fpcpkg/Payload/usr/local" "$T/fpc"
    rm -rf "$T/fpcpkg"
fi
# fpc.cfg nombra el SDK y el clang de las Command Line Tools (o de Xcode): se
# vuelve a generar si ya no existen (otra version, o la cache de Actions en
# otra imagen del runner)
XR=""
if [ -f "$T/fpc/etc/fpc.cfg" ]; then
    XR=$(sed -n 's/^-XR//p' "$T/fpc/etc/fpc.cfg" | head -n 1)
fi
if [ -z "$XR" ] || [ ! -d "$XR" ]; then
    mkdir -p "$T/fpc/etc"
    rm -f "$T/fpc/etc/fpc.cfg"
    "$T/fpc/lib/fpc/3.2.2/samplecfg" "$T/fpc/lib/fpc/3.2.2" "$T/fpc/etc" > /dev/null
fi
# fpc busca primero ~/.fpc.cfg
if [ ! -e "$HOME/.fpc.cfg" ]; then
    ln -s "$T/fpc/etc/fpc.cfg" "$HOME/.fpc.cfg"
fi

# Lazarus
if [ ! -x "$T/lazarus/lazbuild" ]; then
    fetch "$LAZ_ZIP_URL" "$LAZ_ZIP" "$LAZ_ZIP_MD5"
    rm -rf "$T/lazarus" "$T/laztmp"
    xattr -c "$LAZ_ZIP"
    unzip -q "$LAZ_ZIP" -d "$T/laztmp"
    mv "$T/laztmp/lazarus" "$T/lazarus"
    rmdir "$T/laztmp"
    xattr -cr "$T/lazarus"
fi

# Correcciones de la LCL Cocoa que aun no estan en Lazarus (build/macos/patches)
for p in "$SRC"/build/macos/patches/lazarus-*.patch; do
    if patch -d "$T/lazarus" -p1 -R -s -f --dry-run < "$p" > /dev/null 2>&1; then
        echo "Ya aplicado: $(basename "$p")"
    else
        patch -d "$T/lazarus" -p1 -s -f < "$p"
        echo "Aplicado: $(basename "$p")"
    fi
done

# Zeos
if [ ! -d "$T/zeos/src" ]; then
    [ -f zeos.tar.gz ] || curl -fL --retry 5 -o zeos.tar.gz \
        "https://github.com/marsupilami79/zeoslib/archive/$ZEOS_COMMIT.tar.gz"
    rm -rf "$T/zeos"; mkdir -p "$T/zeos"
    tar -xzf zeos.tar.gz -C "$T/zeos" --strip-components=1
fi

cat > "$T/bin/lazbuild" <<EOF
#!/bin/sh
exec "$T/lazarus/lazbuild" --pcp="$T/lazcfg" --lazarusdir="$T/lazarus" --compiler="$T/fpc/bin/fpc" "\$@"
EOF
chmod +x "$T/bin/lazbuild"
cat > "$T/env.sh" <<EOF
export PATH="$T/bin:$T/fpc/bin:\$PATH"
EOF
. "$T/env.sh"

for p in "$T"/zeos/packages/lazarus/{zcore,zplain,zparsesql,zdbc,zcomponent}.lpk \
         "$SRC/packages/fpc/reportman_rtl.lpk" \
         "$SRC/packages/fpc_lcl/reportman_lcl.lpk" \
         "$SRC/packages/fpc_lcl/reportman_designlcl.lpk"; do
    lazbuild --add-package-link "$p" > /dev/null
done

# Todo con FPC 3.2.2: FCL, LazUtils, LCL Cocoa, SynEdit, IPro, Zeos y los
# tres paquetes de Report Manager. Una vez, y otra si cambian los parches
STAMP="FPC $(fpc -iV) $(uname -m) $(cat "$SRC"/build/macos/patches/lazarus-*.patch | md5 -q)"
if [ "$(cat "$T/lazarus/.rm-build" 2>/dev/null)" != "$STAMP" ]; then
    lazbuild -B -r --no-write-project "$SRC/packages/fpc_lcl/reportman_designlcl.lpk"
    echo "$STAMP" > "$T/lazarus/.rm-build"
else
    echo "Lazarus ya compilado con FPC $(fpc -iV) y los parches de ahora"
fi

fpc -iV
lazbuild --version
echo "Listo: . $T/env.sh"

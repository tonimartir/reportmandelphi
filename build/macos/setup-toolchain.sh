#!/bin/bash
# Prepara en un Mac (Intel, macOS 11 o posterior) lo necesario para compilar
# Report Manager Designer con LCL-Cocoa, sin sudo y sin tocar /usr/local:
#
#   $RM_MACOS_TOOLS/fpc        FPC 3.2.2 (el del .dmg oficial, sin instalarlo)
#   $RM_MACOS_TOOLS/lazarus    Lazarus 4.8 (zip oficial)
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
set -euo pipefail

T=${RM_MACOS_TOOLS:-$HOME/dev}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
SF=https://downloads.sourceforge.net/project/lazarus/Lazarus%20macOS%20x86-64
FPC_DMG=fpc-3.2.2.intelarm64-macosx.dmg
FPC_DMG_MD5=50babbde74790a5b86bc63c1fa3250d0
LAZ_ZIP=lazarus-darwin-x86_64-4.8.zip
LAZ_ZIP_MD5=08f5b014ea5708c261baf6e56448502d
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
fetch "$SF/Lazarus%204.0/$FPC_DMG" "$FPC_DMG" "$FPC_DMG_MD5"
fetch "$SF/Lazarus%204.8/$LAZ_ZIP" "$LAZ_ZIP" "$LAZ_ZIP_MD5"
[ -f zeos.tar.gz ] || curl -fL --retry 5 -o zeos.tar.gz \
    "https://github.com/marsupilami79/zeoslib/archive/$ZEOS_COMMIT.tar.gz"

# FPC: el contenido del paquete (usr/local) en $T/fpc, con su fpc.cfg
if [ ! -x "$T/fpc/bin/fpc" ]; then
    mnt=$(mktemp -d)
    hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$FPC_DMG" > /dev/null
    rm -rf "$T/fpcpkg"
    pkgutil --expand-full "$mnt"/*.mpkg/Contents/Packages/*.pkg "$T/fpcpkg"
    hdiutil detach "$mnt" > /dev/null
    rm -rf "$T/fpc"
    mv "$T/fpcpkg/Payload/usr/local" "$T/fpc"
    rm -rf "$T/fpcpkg"
    mkdir -p "$T/fpc/etc"
    "$T/fpc/lib/fpc/3.2.2/samplecfg" "$T/fpc/lib/fpc/3.2.2" "$T/fpc/etc" > /dev/null
fi
# fpc busca primero ~/.fpc.cfg
if [ ! -e "$HOME/.fpc.cfg" ]; then
    ln -s "$T/fpc/etc/fpc.cfg" "$HOME/.fpc.cfg"
fi

# Lazarus
if [ ! -x "$T/lazarus/lazbuild" ]; then
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
# tres paquetes de Report Manager
lazbuild -B -r --no-write-project "$SRC/packages/fpc_lcl/reportman_designlcl.lpk"

fpc -iV
lazbuild --version
echo "Listo: . $T/env.sh"

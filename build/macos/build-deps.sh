#!/bin/bash
# Compila en un Mac las librerias que el motor carga en tiempo de ejecucion
# para medir y dar forma al texto fuera de Windows (rpfreetype2, rpHarfBuzz,
# rpfontconfig), en $RM_MACOS_DEPS/prefix (~/dev/macdeps por defecto):
#
#   libfreetype.6.dylib          FreeType 2.13.3 (zlib del sistema)
#   libharfbuzz.0.dylib          HarfBuzz 10.4.0 con hb-ft
#   libharfbuzz-subset.0.dylib   HarfBuzz subset (subconjuntos de fuentes PDF)
#   libfontconfig.1.dylib        fontconfig 2.15.0 (expat del sistema), con
#                                las carpetas de fuentes de macOS
#
# ICU no se compila: el motor usa /usr/lib/libicucore.dylib de macOS.
# Solo hacen falta las Command Line Tools de Xcode (sin pkg-config, cmake ni
# meson: HarfBuzz se compila desde sus fuentes amalgamadas). Sin sudo.
#
# El motor busca las librerias en Contents/Frameworks del .app, junto al
# ejecutable, en la ruta de dyld (DYLD_LIBRARY_PATH, ~/lib, /usr/local/lib) y
# en los prefijos de Homebrew y MacPorts (rpdarwinlibs.RpLoadDarwinLibrary).
# El script las enlaza en ~/lib. Alternativa sin compilar nada:
#   brew install fontconfig harfbuzz
set -euo pipefail

D=${RM_MACOS_DEPS:-$HOME/dev/macdeps}
PREFIX=$D/prefix
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-10.15}
JOBS=$(sysctl -n hw.ncpu)

FT=freetype-2.13.3
FT_SHA256=0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289
HB_VERSION=10.4.0
HB=harfbuzz-$HB_VERSION
HB_SHA256=480b6d25014169300669aa1fc39fb356c142d5028324ea52b3a27648b9beaad8
FC=fontconfig-2.15.0
FC_SHA256=63a0658d0e06e0fa886106452b58ef04f21f58202ea02a94c39de0d3335d7c0e

mkdir -p "$D/src"
cd "$D/src"
fetch() {
    local url=$1 name=$2 sum=$3
    [ -f "$name" ] || curl -fL --retry 5 -o "$name" "$url"
    echo "$sum  $name" | shasum -a 256 -c -
}
fetch "https://download.savannah.gnu.org/releases/freetype/$FT.tar.xz" "$FT.tar.xz" "$FT_SHA256"
fetch "https://github.com/harfbuzz/harfbuzz/releases/download/$HB_VERSION/$HB.tar.xz" "$HB.tar.xz" "$HB_SHA256"
fetch "https://www.freedesktop.org/software/fontconfig/release/$FC.tar.xz" "$FC.tar.xz" "$FC_SHA256"
rm -rf "$FT" "$HB" "$FC"
for t in "$FT" "$HB" "$FC"; do tar -xf "$t.tar.xz"; done

# FreeType (sin HarfBuzz, PNG, Brotli ni bzip2)
(
    cd "$FT"
    ./configure --prefix="$PREFIX" --disable-static --with-zlib=yes \
        --with-harfbuzz=no --with-png=no --with-brotli=no --with-bzip2=no > ../ft-configure.log
    make -j"$JOBS" > ../ft-make.log
    make install > /dev/null
)

# HarfBuzz: harfbuzz.cc y harfbuzz-subset.cc incluyen todas las fuentes
(
    cd "$HB/src"
    CXXF="-std=c++11 -O2 -fno-exceptions -fno-rtti -fno-threadsafe-statics
        -fvisibility-inlines-hidden -DHAVE_FREETYPE=1 -DHAVE_PTHREAD=1
        -I$PREFIX/include/freetype2"
    # shellcheck disable=SC2086
    clang++ $CXXF -dynamiclib harfbuzz.cc -o libharfbuzz.0.dylib \
        -L"$PREFIX/lib" -lfreetype \
        -install_name "$PREFIX/lib/libharfbuzz.0.dylib" -compatibility_version 1 -current_version 1
    # shellcheck disable=SC2086
    clang++ $CXXF -dynamiclib harfbuzz-subset.cc -o libharfbuzz-subset.0.dylib \
        libharfbuzz.0.dylib \
        -install_name "$PREFIX/lib/libharfbuzz-subset.0.dylib" -compatibility_version 1 -current_version 1
    mkdir -p "$PREFIX/include/harfbuzz"
    cp hb*.h "$PREFIX/include/harfbuzz/"
    cp libharfbuzz.0.dylib libharfbuzz-subset.0.dylib "$PREFIX/lib/"
)

# fontconfig: freetype y expat sin pkg-config. Las fuentes del sistema, las
# de /Library y las del usuario, y las que macOS descarga bajo demanda
(
    cd "$FC"
    FREETYPE_CFLAGS="-I$PREFIX/include/freetype2" FREETYPE_LIBS="-L$PREFIX/lib -lfreetype" \
    EXPAT_CFLAGS="" EXPAT_LIBS="-lexpat" \
    ./configure --prefix="$PREFIX" --sysconfdir="$PREFIX/etc" --localstatedir="$PREFIX/var" \
        --disable-static --disable-docs --disable-nls --disable-cache-build \
        --with-default-fonts=/System/Library/Fonts \
        --with-add-fonts=/Library/Fonts,~/Library/Fonts,/System/Library/AssetsV2/com_apple_MobileAsset_Font6 \
        > ../fc-configure.log
    make -j"$JOBS" > ../fc-make.log
    make install > /dev/null
)

ls -la "$PREFIX"/lib/*.dylib

# Enlaces en ~/lib, la primera carpeta de la busqueda de dyld: asi las
# encuentran tambien las aplicaciones abiertas desde el Finder (sin
# DYLD_LIBRARY_PATH), los ejemplos y los disenadores compilados en este Mac.
# RM_MACOS_NO_HOME_LIB=1 no los crea.
if [ "${RM_MACOS_NO_HOME_LIB:-}" != "1" ]; then
    mkdir -p "$HOME/lib"
    for l in libfreetype.6.dylib libharfbuzz.0.dylib libharfbuzz-subset.0.dylib libfontconfig.1.dylib; do
        ln -sf "$PREFIX/lib/$l" "$HOME/lib/$l"
    done
    echo "Enlazadas en $HOME/lib"
fi
echo "Listo"

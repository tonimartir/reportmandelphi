#!/bin/bash
# Mete OpenSSL 3 en una aplicacion de macOS hecha con los paquetes de Report
# Manager para Lazarus, para que tenga HTTPS (driver Reportman DB Agent, login
# y asistentes de IA) en un Mac sin Homebrew:
#
#   build/macos/bundle-openssl.sh MiAplicacion.app [carpeta con las librerias]
#
# Copia libssl.3.dylib y libcrypto.3.dylib en Contents/Frameworks, donde el
# motor las busca antes que en ningun otro sitio (rpdarwinlibs.RpDarwinOpenSSL),
# hace que se nombren entre si con @loader_path, copia la licencia de OpenSSL a
# Contents/Resources/licenses y vuelve a firmar la aplicacion (ad hoc, o con
# RM_CODESIGN_IDENTITY). Los certificados raiz son los de macOS
# (/etc/ssl/cert.pem): no hay que copiar ninguno.
#
# Las librerias se toman de la carpeta indicada o, si no, de build-deps.sh
# ($RM_MACOS_DEPS/prefix/lib, ~/dev/macdeps por defecto), de Homebrew
# (openssl@3) o de MacPorts. Tienen que ser de la misma arquitectura que el
# ejecutable: Homebrew en un Mac con Apple Silicon da librerias arm64, que una
# aplicacion Intel no puede cargar.
set -euo pipefail

APP=${1:-}
[ -n "$APP" ] && [ -d "$APP/Contents/MacOS" ] || {
    echo "Uso: $0 MiAplicacion.app [carpeta con libssl.3.dylib y libcrypto.3.dylib]" >&2
    exit 2
}
APP=$(cd "$APP" && pwd)
LIBS="libssl.3.dylib libcrypto.3.dylib"

# De donde se copian
SRCDIR=${2:-}
if [ -z "$SRCDIR" ]; then
    cands="${RM_MACOS_DEPS:-$HOME/dev/macdeps}/prefix/lib"
    if command -v brew > /dev/null; then
        cands="$cands $(brew --prefix openssl@3 2>/dev/null)/lib"
    fi
    cands="$cands /usr/local/opt/openssl@3/lib /opt/homebrew/opt/openssl@3/lib /opt/local/lib"
    for d in $cands; do
        if [ -f "$d/libssl.3.dylib" ] && [ -f "$d/libcrypto.3.dylib" ]; then
            SRCDIR=$d
            break
        fi
    done
fi
[ -n "$SRCDIR" ] && [ -f "$SRCDIR/libssl.3.dylib" ] && [ -f "$SRCDIR/libcrypto.3.dylib" ] || {
    echo "ERROR: no encuentro libssl.3.dylib y libcrypto.3.dylib." >&2
    echo "  build/macos/build-deps.sh las compila; o brew install openssl@3; o indica la carpeta." >&2
    exit 1
}
echo "== OpenSSL de $SRCDIR"

# La arquitectura del ejecutable tiene que estar en las librerias
EXE=$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Contents/Info.plist")
EXE_ARCHS=$(lipo -archs "$EXE")
for l in $LIBS; do
    LIB_ARCHS=$(lipo -archs "$SRCDIR/$l")
    for a in $EXE_ARCHS; do
        case " $LIB_ARCHS " in
            *" $a "*) ;;
            *) echo "ERROR: $l es $LIB_ARCHS y el ejecutable necesita $a" >&2; exit 1 ;;
        esac
    done
done

FW=$APP/Contents/Frameworks
mkdir -p "$FW"
for l in $LIBS; do
    rm -f "$FW/$l"
    cp -L "$SRCDIR/$l" "$FW/$l"
    chmod u+w "$FW/$l"
    install_name_tool -id "@loader_path/$l" "$FW/$l"
done
# libssl nombra a libcrypto con la ruta de donde se compilo
old=$(otool -L "$FW/libssl.3.dylib" | tail -n +2 | awk '{print $1}' | grep 'libcrypto\.3\.dylib$' || true)
[ -n "$old" ] && install_name_tool -change "$old" "@loader_path/libcrypto.3.dylib" "$FW/libssl.3.dylib"
for l in $LIBS; do
    if otool -L "$FW/$l" | tail -n +2 | awk '{print $1}' | grep -v -E '^(/usr/lib/|/System/|@loader_path/)'; then
        echo "ERROR: $l sigue enlazando una libreria de fuera de la aplicacion" >&2
        exit 1
    fi
done

# La licencia de OpenSSL (Apache 2.0) va con las librerias
LICENSE=""
for f in "$SRCDIR/../LICENSE.txt" "$(dirname "$SRCDIR")/src"/openssl-*/LICENSE.txt \
         "${RM_MACOS_DEPS:-$HOME/dev/macdeps}/src"/openssl-*/LICENSE.txt; do
    [ -f "$f" ] && LICENSE=$f
done
if [ -n "$LICENSE" ]; then
    mkdir -p "$APP/Contents/Resources/licenses"
    cp "$LICENSE" "$APP/Contents/Resources/licenses/OpenSSL-LICENSE.txt"
else
    echo "AVISO: no encuentro la licencia de OpenSSL; distribuyela con la aplicacion" >&2
fi

# Copiar librerias invalida la firma: se vuelve a firmar
codesign --force --deep --sign "${RM_CODESIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Listo: $FW/libssl.3.dylib y libcrypto.3.dylib"

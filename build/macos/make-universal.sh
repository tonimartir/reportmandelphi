#!/bin/bash
# Une la aplicacion x86_64 y la arm64 de make-package.sh en una aplicacion
# universal y su imagen de disco:
#
#   build/macos/make-universal.sh <una .app> <la otra .app> [carpeta de salida]
#
#   <salida>/Report Manager Designer.app
#   <salida>/reportman-designer-<version>-macos-universal.dmg
#   <salida>/SHA256SUMS
#
# La salida es build/macos/out/<version>-universal si no se indica. Las dos
# aplicaciones tienen que ser de la misma version y tener los mismos ficheros:
# el ejecutable y cada libreria de Contents/Frameworks se unen con lipo, y el
# resto (traducciones, ejemplos, fontconfig, licencias) tiene que ser igual.
# El Info.plist es el de la x86_64 con la version minima de macOS de cada
# arquitectura (LSMinimumSystemVersionByArchitecture: 10.15 Intel, 11.0
# Apple Silicon). Firma ad hoc, como make-package.sh. Lo usa el workflow
# .github/workflows/macos.yml, que compila cada .app en su Mac.
set -euo pipefail

SRC=$(cd "$(dirname "$0")/../.." && pwd)
APP_NAME="Report Manager Designer"

[ $# -ge 2 ] && [ -d "$1/Contents/MacOS" ] && [ -d "$2/Contents/MacOS" ] || {
    echo "Uso: $0 <aplicacion x86_64> <aplicacion arm64> [carpeta de salida]" >&2
    exit 2
}

EXE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$1/Contents/Info.plist")
# Cual es cual, por la arquitectura del ejecutable
X86=""; ARM=""
for a in "$1" "$2"; do
    case $(lipo -archs "$a/Contents/MacOS/$EXE") in
        x86_64) X86=$(cd "$a" && pwd) ;;
        arm64) ARM=$(cd "$a" && pwd) ;;
        *) echo "ERROR: $a/Contents/MacOS/$EXE no es solo x86_64 ni solo arm64" >&2; exit 1 ;;
    esac
done
[ -n "$X86" ] && [ -n "$ARM" ] || { echo "ERROR: hace falta una aplicacion x86_64 y otra arm64" >&2; exit 1; }

plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"; }
VERSION=$(plist "$X86" CFBundleShortVersionString)
[ "$(plist "$ARM" CFBundleShortVersionString)" = "$VERSION" ] \
    || { echo "ERROR: version $VERSION (x86_64) y $(plist "$ARM" CFBundleShortVersionString) (arm64)" >&2; exit 1; }
MIN_X86=$(plist "$X86" LSMinimumSystemVersion)
MIN_ARM=$(plist "$ARM" LSMinimumSystemVersion)

OUT=${3:-$SRC/build/macos/out/$VERSION-universal}
APP=$OUT/$APP_NAME.app
DMG=$OUT/reportman-designer-$VERSION-macos-universal.dmg
echo "== $APP_NAME $VERSION: x86_64 (macOS $MIN_X86) + arm64 (macOS $MIN_ARM)"

# Los mismos ficheros en las dos, y los que no son Mach-O, iguales. La firma
# se rehace; el icono lo genera iconutil en cada Mac y puede no ser identico
lista() { (cd "$1" && find . \( -type f -o -type l \) ! -path './Contents/_CodeSignature/*' | sort); }
if ! diff <(lista "$X86") <(lista "$ARM") > /dev/null; then
    diff <(lista "$X86") <(lista "$ARM") >&2 || true
    echo "ERROR: las dos aplicaciones no tienen los mismos ficheros" >&2
    exit 1
fi
MACHO=""
while IFS= read -r f; do
    if file "$X86/$f" | grep -q 'Mach-O'; then
        MACHO="$MACHO $f"
    elif [ "$f" != ./Contents/Info.plist ] && [ "$f" != ./Contents/Resources/reportman.icns ]; then
        cmp -s "$X86/$f" "$ARM/$f" || { echo "ERROR: $f es distinto en las dos aplicaciones" >&2; exit 1; }
    fi
done < <(lista "$X86")
[ -n "$MACHO" ] || { echo "ERROR: no hay ningun Mach-O" >&2; exit 1; }

echo "== Uniendo con lipo"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$X86" "$APP"
rm -rf "$APP/Contents/_CodeSignature"
for f in $MACHO; do
    lipo -create "$X86/$f" "$ARM/$f" -output "$APP/$f"
done

# Info.plist: macOS 10.15 en Intel y 11.0 en Apple Silicon (los Mac con
# Apple Silicon empiezan en macOS 11)
PB=/usr/libexec/PlistBuddy
"$PB" -c "Set :LSMinimumSystemVersion $MIN_X86" "$APP/Contents/Info.plist"
"$PB" -c "Delete :LSMinimumSystemVersionByArchitecture" "$APP/Contents/Info.plist" 2>/dev/null || true
"$PB" -c "Add :LSMinimumSystemVersionByArchitecture dict" \
      -c "Add :LSMinimumSystemVersionByArchitecture:x86_64 string $MIN_X86" \
      -c "Add :LSMinimumSystemVersionByArchitecture:arm64 string $MIN_ARM" \
      "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null

echo "== Arquitecturas"
bad=0
for f in $MACHO; do
    a=$(lipo -archs "$APP/$f")
    printf '  %-48s %s\n' "${f#./Contents/}" "$a"
    case " $a " in *" x86_64 "*) ;; *) bad=1 ;; esac
    case " $a " in *" arm64 "*) ;; *) bad=1 ;; esac
done
[ $bad -eq 0 ] || { echo "ERROR: algun Mach-O no tiene x86_64 y arm64" >&2; exit 1; }

echo "== Firma ad hoc"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "== Imagen de disco"
STAGE=$OUT/dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
(cd "$OUT" && shasum -a 256 "$(basename "$DMG")" > SHA256SUMS)

echo "Listo:"
echo "  $APP"
echo "  $DMG ($(du -h "$DMG" | cut -f1))"
cat "$OUT/SHA256SUMS"

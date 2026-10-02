#!/bin/bash
# Paquete de instalacion de Report Manager Designer para macOS (Intel): una
# aplicacion autonoma y su imagen de disco,
#
#   build/macos/out/<version>/Report Manager Designer.app
#   build/macos/out/<version>/reportman-designer-<version>-macos-x86_64.dmg
#
# despues de setup-toolchain.sh, build-deps.sh y los paquetes
# (LAZBUILD=lazbuild sh packages/fpc/build_fpc.sh). La aplicacion lleva:
#
#   Contents/MacOS/repmandesigner_lcl   el ejecutable (modo Release), no un
#                                       enlace como el .app de desarrollo
#   Contents/Frameworks/                FreeType, HarfBuzz (+ subset) y
#                                       fontconfig de build-deps.sh, enlazadas
#                                       entre si con @loader_path
#   Contents/Resources/fonts/           la configuracion de fontconfig (el
#                                       motor fija FONTCONFIG_PATH al cargarla)
#   Contents/Resources/reportmanres.*   traducciones del motor
#   Contents/Resources/languages/       traducciones de la LCL (Lazarus)
#   Contents/Resources/samples/         los ejemplos (sample4.rep y su
#                                       biolife.cds, sin los PDF)
#
# ICU es la del sistema. OpenSSL 3 (HTTPS: asistentes de IA, agente de datos,
# login) no va dentro: brew install openssl@3, o RP_OPENSSL_DIR. La firma es
# ad hoc (codesign -s -): sin un certificado Developer ID y la notarizacion de
# Apple, Gatekeeper pide abrirla la primera vez con clic derecho > Abrir.
set -euo pipefail

T=${RM_MACOS_TOOLS:-$HOME/dev}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
LAZ=${LAZARUS_DIR:-$T/lazarus}
DEPS=${RM_MACOS_DEPS:-$T/macdeps/prefix}
LCL_LANGUAGES="es ca cs de fr it lt pt pt_BR"
DYLIBS="libfreetype.6.dylib libharfbuzz.0.dylib libharfbuzz-subset.0.dylib libfontconfig.1.dylib"
APP_NAME="Report Manager Designer"
EXE=repmandesigner_lcl
BUNDLE_ID=es.reportman.designer

VERSION=$(sed -n "s/^[[:space:]]*RM_VERSION[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$SRC/rpmdconsts.pas" | head -n 1)
[ -n "$VERSION" ] || { echo "ERROR: no encuentro RM_VERSION en rpmdconsts.pas" >&2; exit 1; }
OUT=$SRC/build/macos/out/$VERSION
APP=$OUT/$APP_NAME.app
DMG=$OUT/reportman-designer-$VERSION-macos-x86_64.dmg

for f in $DYLIBS; do
    [ -f "$DEPS/lib/$f" ] || { echo "ERROR: falta $DEPS/lib/$f (build/macos/build-deps.sh)" >&2; exit 1; }
done
[ -f "$DEPS/etc/fonts/fonts.conf" ] || { echo "ERROR: falta $DEPS/etc/fonts/fonts.conf" >&2; exit 1; }

echo "== Compilando $APP_NAME $VERSION (Release)"
if ! command -v lazbuild > /dev/null && [ -f "$T/env.sh" ]; then
    . "$T/env.sh"
fi
lazbuild --bm=Release --no-write-project "$SRC/repman/lcl_designer/repmandesigner_lcl.lpi" > "$SRC/build/macos/package-build.log" 2>&1 \
    || { tail -20 "$SRC/build/macos/package-build.log"; exit 1; }

echo "== Montando $APP"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" \
    "$APP/Contents/Resources/languages" "$APP/Contents/Resources/samples" \
    "$APP/Contents/Resources/fonts/conf.d"
cp -L "$SRC/repman/$EXE" "$APP/Contents/MacOS/$EXE"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$EXE</string>
  <key>CFBundleIconFile</key><string>reportman</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleSignature</key><string>????</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright 1994-2026 Toni Martir. MPL License.</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>es</string><string>ca</string><string>cs</string><string>de</string><string>fr</string><string>it</string><string>lt</string><string>pt</string></array>
</dict>
</plist>
PLIST

# Las librerias: cada una se nombra a si misma y a las demas por @loader_path
# (el motor las carga con su ruta en Contents/Frameworks)
for f in $DYLIBS; do
    cp -L "$DEPS/lib/$f" "$APP/Contents/Frameworks/$f"
    chmod u+w "$APP/Contents/Frameworks/$f"
    install_name_tool -id "@loader_path/$f" "$APP/Contents/Frameworks/$f"
done
for f in $DYLIBS; do
    for dep in $DYLIBS; do
        install_name_tool -change "$DEPS/lib/$dep" "@loader_path/$dep" "$APP/Contents/Frameworks/$f"
    done
done

# fontconfig: su configuracion con la cache en ~/Library/Caches
sed -e "s|<cachedir>$DEPS/var/cache/fontconfig</cachedir>|<cachedir>~/Library/Caches/$BUNDLE_ID/fontconfig</cachedir>|" \
    "$DEPS/etc/fonts/fonts.conf" > "$APP/Contents/Resources/fonts/fonts.conf"
for f in "$DEPS"/etc/fonts/conf.d/*.conf; do
    cp -L "$f" "$APP/Contents/Resources/fonts/conf.d/"
done

# Traducciones y ejemplos
cp "$SRC"/repman/reportmanres.* "$APP/Contents/Resources/"
for l in $LCL_LANGUAGES; do
    cp "$LAZ/lcl/languages/lclstrconsts.$l.po" "$APP/Contents/Resources/languages/"
done
find "$SRC/repman/repsamples" -maxdepth 1 -type f ! -iname '*.pdf' \
    -exec cp {} "$APP/Contents/Resources/samples/" \;

# Icono: el de la web (512 px) en todos los tamanos
ICONSET=$OUT/reportman.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$SRC/doc/icon-512.png" --out "$ICONSET/icon_${s}x${s}.png" > /dev/null
    d=$((s * 2))
    [ $d -le 512 ] && sips -z $d $d "$SRC/doc/icon-512.png" --out "$ICONSET/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/reportman.icns"
rm -rf "$ICONSET"

echo "== Comprobando que no queda ninguna ruta de esta maquina"
bad=0
while IFS= read -r -d '' f; do
    if file "$f" | grep -q 'Mach-O'; then
        if otool -L "$f" | tail -n +2 | grep -E "$HOME|$DEPS" ; then
            echo "ERROR: $f enlaza una libreria de esta maquina" >&2
            bad=1
        fi
    fi
done < <(find "$APP/Contents/MacOS" "$APP/Contents/Frameworks" -type f -print0)
if grep -q "$DEPS" "$APP/Contents/Resources/fonts/fonts.conf"; then
    echo "ERROR: fonts.conf aun nombra $DEPS" >&2
    bad=1
fi
[ $bad -eq 0 ] || exit 1

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

echo "Listo:"
echo "  $APP"
echo "  $DMG ($(du -h "$DMG" | cut -f1))"

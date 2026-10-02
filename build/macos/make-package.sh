#!/bin/bash
# Paquete de instalacion de Report Manager Designer para macOS: una aplicacion
# autonoma y su imagen de disco, de la arquitectura del Mac que la compila
# (x86_64 o arm64),
#
#   build/macos/out/<version>/Report Manager Designer.app
#   build/macos/out/<version>/reportman-designer-<version>-macos-<arq>.dmg
#
# make-universal.sh une la aplicacion x86_64 y la arm64 en una universal (el
# workflow .github/workflows/macos.yml lo hace en GitHub Actions).
#
# despues de setup-toolchain.sh, build-deps.sh y los paquetes
# (LAZBUILD=lazbuild sh packages/fpc/build_fpc.sh). La aplicacion lleva:
#
#   Contents/MacOS/repmandesigner_lcl   el ejecutable (modo Release), no un
#                                       enlace como el .app de desarrollo
#   Contents/Frameworks/                FreeType, HarfBuzz (+ subset),
#                                       fontconfig y OpenSSL 3 de
#                                       build-deps.sh, enlazadas entre si con
#                                       @loader_path
#   Contents/Resources/fonts/           la configuracion de fontconfig (el
#                                       motor fija FONTCONFIG_PATH al cargarla)
#   Contents/Resources/reportmanres.*   traducciones del motor
#   Contents/Resources/languages/       traducciones de la LCL (Lazarus)
#   Contents/Resources/samples/         los ejemplos (sample4.rep y su
#                                       biolife.cds, sin los PDF)
#   Contents/Resources/licenses/        las licencias de esas librerias
#   Contents/Resources/reportman.icns   el icono del disenador de Windows
#                                       (repman/repmandxp_Icon.ico), como en
#                                       los paquetes de Linux
#
# El Info.plist declara la version minima de macOS (la mayor que piden el
# ejecutable y las librerias, segun otool) y el tipo .rep, para que Finder
# abra los informes con la aplicacion (doble clic, arrastrar al icono, Abrir
# con). ICU es la del sistema. OpenSSL 3 va dentro: lo necesitan el login y
# los asistentes de IA y el driver Reportman DB Agent (HTTPS), y el motor lo
# busca primero en Contents/Frameworks (rpdarwinlibs.RpDarwinOpenSSL); los
# certificados raiz son los de macOS (/etc/ssl/cert.pem). La firma es
# ad hoc (codesign -s -): sin un certificado Developer ID y la notarizacion de
# Apple, Gatekeeper pide abrirla la primera vez con clic derecho > Abrir.
set -euo pipefail

T=${RM_MACOS_TOOLS:-$HOME/dev}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
LAZ=${LAZARUS_DIR:-$T/lazarus}
DEPS=${RM_MACOS_DEPS:-$T/macdeps/prefix}
DEPS_SRC=${RM_MACOS_DEPS_SRC:-$(dirname "$DEPS")/src}
LCL_LANGUAGES="es ca cs de fr it lt pt pt_BR"
DYLIBS="libfreetype.6.dylib libharfbuzz.0.dylib libharfbuzz-subset.0.dylib libfontconfig.1.dylib libssl.3.dylib libcrypto.3.dylib"
APP_NAME="Report Manager Designer"
EXE=repmandesigner_lcl
BUNDLE_ID=es.reportman.designer

VERSION=$(sed -n "s/^[[:space:]]*RM_VERSION[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" "$SRC/rpmdconsts.pas" | head -n 1)
[ -n "$VERSION" ] || { echo "ERROR: no encuentro RM_VERSION en rpmdconsts.pas" >&2; exit 1; }
OUT=$SRC/build/macos/out/$VERSION
APP=$OUT/$APP_NAME.app

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

# La arquitectura: la del ejecutable, que tienen que tener tambien las librerias
ARCH=$(lipo -archs "$SRC/repman/$EXE")
case $ARCH in
    x86_64|arm64) ;;
    *) echo "ERROR: el ejecutable es '$ARCH'; se espera x86_64 o arm64" >&2; exit 1 ;;
esac
for f in $DYLIBS; do
    lipo -archs "$DEPS/lib/$f" | grep -qw "$ARCH" \
        || { echo "ERROR: $DEPS/lib/$f no tiene $ARCH (build-deps.sh en un Mac $ARCH)" >&2; exit 1; }
done
DMG=$OUT/reportman-designer-$VERSION-macos-$ARCH.dmg
echo "== Arquitectura: $ARCH"

# La version minima de macOS: la mayor que piden el ejecutable y las librerias
# (LC_BUILD_VERSION minos, o LC_VERSION_MIN_MACOSX en los binarios antiguos)
min_macos() {
    otool -l "$1" | awk '/LC_BUILD_VERSION/ {b = 1} /LC_VERSION_MIN_MACOSX/ {m = 1}
        b && $1 == "minos" {print $2; exit} m && $1 == "version" {print $2; exit}'
}
MIN_MACOS=$(for f in "$SRC/repman/$EXE" $(for d in $DYLIBS; do echo "$DEPS/lib/$d"; done); do
    min_macos "$f"; done | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
[ -n "$MIN_MACOS" ] || { echo "ERROR: no se pudo leer la version minima de macOS de los binarios" >&2; exit 1; }
echo "== macOS minimo: $MIN_MACOS"

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
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright 1994-2026 Toni Martir. MPL License.</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>es</string><string>ca</string><string>cs</string><string>de</string><string>fr</string><string>it</string><string>lt</string><string>pt</string></array>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Report Manager report</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Owner</string>
      <key>CFBundleTypeIconFile</key><string>reportman</string>
      <key>LSItemContentTypes</key><array><string>$BUNDLE_ID.rep</string></array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key><string>$BUNDLE_ID.rep</string>
      <key>UTTypeDescription</key><string>Report Manager report</string>
      <key>UTTypeConformsTo</key><array><string>public.data</string></array>
      <key>UTTypeIconFile</key><string>reportman</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>rep</string></array>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" > /dev/null

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

# Licencias de las librerias que van dentro (las fuentes que dejo
# build-deps.sh)
LIC=$APP/Contents/Resources/licenses
mkdir -p "$LIC"
for spec in "freetype-*/LICENSE.TXT:FreeType-LICENSE.txt" "freetype-*/docs/FTL.TXT:FreeType-FTL.txt" \
            "harfbuzz-*/COPYING:HarfBuzz-COPYING.txt" "fontconfig-*/COPYING:fontconfig-COPYING.txt" \
            "openssl-*/LICENSE.txt:OpenSSL-LICENSE.txt"; do
    f=$(ls -d "$DEPS_SRC"/${spec%%:*} 2>/dev/null | tail -n 1)
    [ -n "$f" ] || { echo "ERROR: falta la licencia ${spec%%:*} en $DEPS_SRC (build-deps.sh)" >&2; exit 1; }
    cp "$f" "$LIC/${spec#*:}"
done

# Icono: el del disenador de Windows (64 px, el mismo que usan los paquetes de
# Linux), ampliado hasta 256 px
ICONSET=$OUT/reportman.iconset
mkdir -p "$ICONSET"
sips -s format png "$SRC/repman/repmandxp_Icon.ico" --out "$OUT/icon-64.png" > /dev/null
for s in 16 32 128 256; do
    sips -z $s $s "$OUT/icon-64.png" --out "$ICONSET/icon_${s}x${s}.png" > /dev/null
    d=$((s * 2))
    [ $d -le 256 ] && sips -z $d $d "$OUT/icon-64.png" --out "$ICONSET/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/reportman.icns"
rm -rf "$ICONSET" "$OUT/icon-64.png"

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

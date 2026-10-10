# Imagen de compilacion de Report Manager Designer (LCL, Qt6 y GTK2) para
# Linux. Fase 6.3/6.8 (docs/fase6_plan.md). La usa build/linux/build-linux.ps1;
# a mano:
#
#   docker build -f build/linux/Dockerfile.builder -t reportman-linux-builder build/linux
#   docker run --rm -v "$PWD":/src:ro -v "$PWD/build/linux/out":/out \
#       reportman-linux-builder bash /src/build/linux/build-in-container.sh
#
# Base Ubuntu 22.04 (glibc 2.35, Qt 6.2.4): lo que se compila aqui funciona en
# las distros mas nuevas (Ubuntu 24.04, Debian 12...). Todas las descargas
# llevan la version fijada en un ARG y se comprueban con sha256 (o por commit
# en git), para que la imagen sea reproducible.
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    APPIMAGE_EXTRACT_AND_RUN=1

# Compilacion (binutils/ld, libc6-dev, cabeceras GTK2), Xvfb para los selftest,
# generacion de iconos (ImageMagick + rsvg), empaquetado .deb (dpkg-dev,
# fakeroot, lintian, desktop-file-utils) y las librerias que el motor carga en
# tiempo de ejecucion (FreeType, fontconfig, HarfBuzz, ICU, SQLite, CUPS).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git file xz-utils binutils build-essential pkg-config \
      libgtk2.0-dev gtk2-engines-pixbuf librsvg2-common \
      xvfb xauth \
      imagemagick librsvg2-bin \
      dpkg-dev fakeroot lintian desktop-file-utils shared-mime-info rsync \
      libfreetype6 libfontconfig1 libharfbuzz0b libsqlite3-0 libicu70 libcups2 \
      fonts-dejavu-core fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

# FPC 3.2.2 + Lazarus 4.8: los .deb oficiales de SourceForge (la misma version
# de Lazarus que se usa en Windows).
ARG LAZARUS_VERSION=4.8
ARG LAZARUS_DEB=lazarus-project_4.8.0-0_amd64.deb
ARG LAZARUS_DEB_SHA256=401742cefb01ad99a628188034bf728fb5360d641ed2be5f91fb0ee183a301cd
ARG FPC_DEB=fpc-laz_3.2.2-210709_amd64.deb
ARG FPC_DEB_SHA256=92000f2b831184e153aab0c910f8ae9240450e5c6d76dc189cf53116ee501d83
ARG FPCSRC_DEB=fpc-src_3.2.2-210709_amd64.deb
ARG FPCSRC_DEB_SHA256=8c9e145d8056754a9ca39ce3e52e982b8e4816124984c5f542f2a874e721ad53
ARG LAZARUS_URL=https://downloads.sourceforge.net/project/lazarus/Lazarus%20Linux%20amd64%20DEB/Lazarus%20${LAZARUS_VERSION}
# --retry-all-errors: a SourceForge mirror sometimes resets a download halfway
# ("Connection reset by peer"), which --retry alone does not retry
RUN set -eux; cd /tmp; \
    for spec in "$FPC_DEB=$FPC_DEB_SHA256" "$FPCSRC_DEB=$FPCSRC_DEB_SHA256" "$LAZARUS_DEB=$LAZARUS_DEB_SHA256"; do \
      name=${spec%%=*}; sum=${spec##*=}; \
      curl -fsSL --retry 5 --retry-all-errors -o "$name" "$LAZARUS_URL/$name"; \
      echo "$sum  $name" | sha256sum -c -; \
    done; \
    apt-get update; \
    apt-get install -y --no-install-recommends "./$FPC_DEB" "./$FPCSRC_DEB" "./$LAZARUS_DEB"; \
    rm -rf /var/lib/apt/lists/* /tmp/*.deb; \
    fpc -iV; lazbuild --version

# Zeos 8.0 (rama 8.0-patches, "8.0.1-beta"): el commit en el que se basa la
# copia local de Windows (C:\desarrollo\tools\delphicomponents\zeosxe10).
# Se fija por commit (git comprueba la integridad), no por tarball.
ARG ZEOS_REPO=https://github.com/marsupilami79/zeoslib.git
ARG ZEOS_COMMIT=c527f51a4663d6e6415e9e87e0f7c3480c1228b2
RUN set -eux; mkdir -p /opt/zeos; cd /opt/zeos; \
    git init -q; \
    git fetch -q --depth 1 "$ZEOS_REPO" "$ZEOS_COMMIT"; \
    git checkout -q FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "$ZEOS_COMMIT"; \
    rm -rf .git; \
    grep -E "ZEOS_(MAJOR|MINOR|SUB)_VERSION = " src/core/ZClasses.pas

# Qt6 (paquete recomendado desde la 6.8): cabeceras, qmake6 y plugins de
# plataforma de Qt 6.2.4 (Ubuntu 22.04) y patchelf (RUNPATH del .deb Qt6).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      qt6-base-dev qt6-base-dev-tools qmake6 qt6-qpa-plugins libgl-dev patchelf \
 && rm -rf /var/lib/apt/lists/* \
 && dpkg-query -W -f='${Package} ${Version}\n' libqt6core6 qt6-base-dev

# libQt6Pas: el puente C que usa la LCL para hablar con Qt6. Ubuntu 22.04/24.04
# y Debian 12 no la empaquetan (libqt6pas6 llega con Debian 13 y Ubuntu
# 26.04), asi que se compila aqui la 6.2.10 (la que espera la LCL de Lazarus
# 4.8) desde lcl/interfaces/qt6/cbindings del .deb de Lazarus fijado arriba
# (sus fuentes quedan fijadas por el sha256 de ese .deb), con los flags de
# endurecimiento de Debian (sin LTO), y se instala en un prefijo propio: no
# pisa nada del sistema y los paquetes la llevan como libreria privada
# (/opt/reportman-designer/lib en el .deb, usr/lib en la AppImage). Compilada
# contra Qt 6.2.4, funciona con las Qt 6.2 a 6.10 de las distros probadas.
# El sha256 del resultado queda en $QT6PAS_DIR/sha256.txt (build-info.txt).
ARG QT6PAS_VERSION=6.2.10
ENV QT6PAS_DIR=/opt/libqt6pas
RUN set -eux; \
    src=$(dirname "$(readlink -f "$(command -v lazbuild)")")/lcl/interfaces/qt6/cbindings; \
    tr -d '\r' < "$src/Qt6Pas.pro" | grep -qx "else:VERSION = $QT6PAS_VERSION"; \
    rm -rf /tmp/qt6pas; cp -r "$src" /tmp/qt6pas; cd /tmp/qt6pas; \
    export DEB_BUILD_MAINT_OPTIONS="hardening=+all optimize=-lto"; \
    qmake6 "QMAKE_CXXFLAGS+=$(dpkg-buildflags --get CXXFLAGS) $(dpkg-buildflags --get CPPFLAGS)" \
           "QMAKE_LFLAGS+=$(dpkg-buildflags --get LDFLAGS)" > /tmp/qt6pas-qmake.log 2>&1 \
      || { cat /tmp/qt6pas-qmake.log; exit 1; }; \
    make -j"$(nproc)" > /tmp/qt6pas-make.log 2>&1 || { tail -n 60 /tmp/qt6pas-make.log; exit 1; }; \
    lib=libQt6Pas.so.$QT6PAS_VERSION; \
    install -d "$QT6PAS_DIR/lib"; \
    install -m 0644 "$lib" "$QT6PAS_DIR/lib/"; \
    strip --strip-unneeded --remove-section=.comment --remove-section=.note "$QT6PAS_DIR/lib/$lib"; \
    ln -s "$lib" "$QT6PAS_DIR/lib/libQt6Pas.so.6"; \
    ln -s libQt6Pas.so.6 "$QT6PAS_DIR/lib/libQt6Pas.so"; \
    cd /; rm -rf /tmp/qt6pas /tmp/qt6pas-*.log; \
    objdump -p "$QT6PAS_DIR/lib/$lib" | grep -E 'SONAME|NEEDED'; \
    if ldd "$QT6PAS_DIR/lib/$lib" | grep 'not found'; then exit 1; fi; \
    sha256sum "$QT6PAS_DIR/lib/$lib" | tee "$QT6PAS_DIR/sha256.txt"

# AppImage: linuxdeploy arma el AppDir (dependencias de Qt6 incluidas) y
# appimagetool lo empaqueta con un runtime fijado (sin descargas al empaquetar).
# Los plugins de Qt se copian a mano en make-appimage.sh (no hace falta
# linuxdeploy-plugin-qt). Los AppImage se extraen aqui porque en un contenedor
# no hay FUSE.
ARG LINUXDEPLOY_URL=https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage
ARG LINUXDEPLOY_SHA256=c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d
ARG APPIMAGETOOL_URL=https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
ARG APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
ARG RUNTIME_URL=https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64
ARG RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
RUN set -eux; mkdir -p /opt/appimage; cd /opt/appimage; \
    curl -fsSL --retry 5 --retry-all-errors -o linuxdeploy.AppImage "$LINUXDEPLOY_URL"; \
    echo "$LINUXDEPLOY_SHA256  linuxdeploy.AppImage" | sha256sum -c -; \
    curl -fsSL --retry 5 --retry-all-errors -o appimagetool.AppImage "$APPIMAGETOOL_URL"; \
    echo "$APPIMAGETOOL_SHA256  appimagetool.AppImage" | sha256sum -c -; \
    curl -fsSL --retry 5 --retry-all-errors -o runtime-x86_64 "$RUNTIME_URL"; \
    echo "$RUNTIME_SHA256  runtime-x86_64" | sha256sum -c -; \
    chmod +x linuxdeploy.AppImage appimagetool.AppImage; \
    ./linuxdeploy.AppImage --appimage-extract >/dev/null; mv squashfs-root linuxdeploy; \
    ./appimagetool.AppImage --appimage-extract >/dev/null; mv squashfs-root appimagetool; \
    rm linuxdeploy.AppImage appimagetool.AppImage; \
    ln -s /opt/appimage/linuxdeploy/AppRun /usr/local/bin/linuxdeploy; \
    ln -s /opt/appimage/appimagetool/AppRun /usr/local/bin/appimagetool; \
    linuxdeploy --version; appimagetool --version

WORKDIR /build

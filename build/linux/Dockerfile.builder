# Imagen de compilacion de Report Manager Designer (LCL, GTK2) para Linux.
# Fase 6.3 (docs/fase6_plan.md). La usa build/linux/build-linux.ps1; a mano:
#
#   docker build -f build/linux/Dockerfile.builder -t reportman-linux-builder build/linux
#   docker run --rm -v "$PWD":/src:ro -v "$PWD/build/linux/out":/out \
#       reportman-linux-builder bash /src/build/linux/build-in-container.sh
#
# Base Ubuntu 22.04 (glibc 2.35): lo que se compila aqui funciona en las
# distros mas nuevas (Ubuntu 24.04, Debian 12...). Todas las descargas llevan
# la version fijada en un ARG y se comprueban con sha256 (o por commit en git),
# para que la imagen sea reproducible.
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    APPIMAGE_EXTRACT_AND_RUN=1

# Compilacion (binutils/ld, libc6-dev, cabeceras GTK2), Xvfb para el selftest,
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
RUN set -eux; cd /tmp; \
    for spec in "$FPC_DEB=$FPC_DEB_SHA256" "$FPCSRC_DEB=$FPCSRC_DEB_SHA256" "$LAZARUS_DEB=$LAZARUS_DEB_SHA256"; do \
      name=${spec%%=*}; sum=${spec##*=}; \
      curl -fsSL --retry 5 -o "$name" "$LAZARUS_URL/$name"; \
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

# AppImage: linuxdeploy (+ plugin GTK) arma el AppDir y appimagetool lo
# empaqueta con un runtime fijado (sin descargas al empaquetar). Los AppImage se
# extraen aqui porque en un contenedor no hay FUSE.
ARG LINUXDEPLOY_URL=https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage
ARG LINUXDEPLOY_SHA256=c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d
ARG GTK_PLUGIN_URL=https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/7a3fbc31a9e5075073ff8790f26effbac5f84453/linuxdeploy-plugin-gtk.sh
ARG GTK_PLUGIN_SHA256=b0f4cbc684a0103a9651f0955b635eaea0096b3a66c0f5a2c2aa337960375171
ARG APPIMAGETOOL_URL=https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
ARG APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
ARG RUNTIME_URL=https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64
ARG RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
RUN set -eux; mkdir -p /opt/appimage; cd /opt/appimage; \
    curl -fsSL --retry 5 -o linuxdeploy.AppImage "$LINUXDEPLOY_URL"; \
    echo "$LINUXDEPLOY_SHA256  linuxdeploy.AppImage" | sha256sum -c -; \
    curl -fsSL --retry 5 -o appimagetool.AppImage "$APPIMAGETOOL_URL"; \
    echo "$APPIMAGETOOL_SHA256  appimagetool.AppImage" | sha256sum -c -; \
    curl -fsSL --retry 5 -o runtime-x86_64 "$RUNTIME_URL"; \
    echo "$RUNTIME_SHA256  runtime-x86_64" | sha256sum -c -; \
    curl -fsSL --retry 5 -o /usr/local/bin/linuxdeploy-plugin-gtk.sh "$GTK_PLUGIN_URL"; \
    echo "$GTK_PLUGIN_SHA256  /usr/local/bin/linuxdeploy-plugin-gtk.sh" | sha256sum -c -; \
    chmod +x linuxdeploy.AppImage appimagetool.AppImage /usr/local/bin/linuxdeploy-plugin-gtk.sh; \
    ./linuxdeploy.AppImage --appimage-extract >/dev/null; mv squashfs-root linuxdeploy; \
    ./appimagetool.AppImage --appimage-extract >/dev/null; mv squashfs-root appimagetool; \
    rm linuxdeploy.AppImage appimagetool.AppImage; \
    ln -s /opt/appimage/linuxdeploy/AppRun /usr/local/bin/linuxdeploy; \
    ln -s /opt/appimage/appimagetool/AppRun /usr/local/bin/appimagetool; \
    linuxdeploy --version; appimagetool --version

WORKDIR /build

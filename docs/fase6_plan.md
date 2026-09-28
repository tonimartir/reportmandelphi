# Plan de la Fase 6: diseñador LCL autónomo, instalador Linux y build en Docker

## Objetivo

Que un usuario de Linux instale y use el diseñador de Report Manager con la misma
facilidad que el instalador InnoSetup de Windows: descargar, doble clic,
instalar, y tener el programa en el menú con los `.rep` asociados. Todo el
empaquetado se genera de forma reproducible en un contenedor Docker, igual que
hoy `build/sourceforge/*.ps1` genera los instaladores de Windows.

## Punto de partida (verificado al cerrar la subfase 5.5)

- Los paquetes `reportman_rtl`, `reportman_lcl` y `reportman_designlcl` compilan
  en Windows (Lazarus 4.8) y en Linux (WSL Ubuntu 24.04, Lazarus 3.0, GTK2) con
  `packages/fpc/build_fpc.bat` / `build_fpc.sh` (con `clean` si FPC falla con una
  excepción interna).
- El selftest del diseñador (`tests/fpc/LclDesignerTest --selftest`) pasa en
  Windows y en Linux.
- Existe un lanzador de prueba fuera del repo (`rmdesigner`, scratchpad) que abre
  `TFRpMainFLCL` y un `.rep`; se probó en WSLg. Sirve de semilla para 6.1.
- Docker está disponible dentro de WSL (29.x). El Docker de `repweb`
  (`server/docker/web/Dockerfile`) ya usa `ubuntu:22.04` como base.
- La versión sale de `RM_VERSION` en `rpmdconsts.pas` (hoy `4.0.16`), igual que
  en `build/sourceforge/_common.ps1` (`Get-RmVersion`).
- Iconos disponibles: `doc/favicon.svg`, `doc/icon-192.png`, `doc/icon-512.png`.
- Configuración en Linux: el motor busca `dbxdrivers`/`dbxconnections` con
  `Obtainininamelocaluserconfig` (usuario) y en `/usr/local/etc` (sistema), la
  misma convención que usa `repweb`.

## Estado de la implementación (27-09-2026)

| Subfase | Estado | Resumen |
|---|---|---|
| 6.1 Ejecutable | Hecho; falta la verificación manual en VM | `repman/lcl_designer/repmandesigner_lcl.lpi` (ver nota); compila en Windows y en el contenedor (GTK2 y Qt6); spike Qt5 hecho |
| 6.2 Escritorio | Hecho; falta probarlo en un escritorio real | `.desktop`, iconos hicolor 16–512 + SVG, MIME `application/x-reportman-report` |
| 6.3 Docker | Hecho | `build/linux/`: un comando (`build-linux.ps1`) compila Qt6 y GTK2, pasa los dos selftest, empaqueta y prueba |
| 6.4 `.deb` | Hecho | `reportman-designer_4.0.16_amd64.deb` (Qt6, ≈4,2 MB) y `reportman-designer-gtk2_4.0.16_amd64.deb` (GTK2, ≈3,9 MB); lintian sin avisos (overrides justificados) |
| 6.5 AppImage | Hecho | `ReportManDesigner-4.0.16-x86_64.AppImage` (Qt6, ≈31 MB) |
| 6.6 Pruebas | Automáticas hechas; manuales pendientes | `test-packages.sh`: los tres paquetes en Ubuntu 22.04, 24.04, 26.04 y Debian 12, 13 en contenedores limpios |
| 6.7 Publicación | Enganchada al release; subir a mano | Tarea `build/sourceforge/06-linux-designer.ps1` de `make-release.ps1`: los tres paquetes + `SHA256SUMS` en `release_<v>\Linux\` |
| 6.8 Qt6 | Hecho; falta probarlo en un escritorio real (X11 y Wayland) | Qt6 pasa a ser el paquete recomendado; GTK2 queda como transitorio (ver 6.8) |

Guía de instalación para usuarios: `docs/linux-install.md`.

## Decisiones a tomar antes de empezar (con recomendación)

| Decisión | Recomendación | Motivo |
|---|---|---|
| Widgetset | ~~GTK2 en la primera versión; evaluar Qt5 en 6.1~~ **Decidido (27-09-2026): Qt6 principal; GTK2 transitorio hasta Debian 14**; GTK3 y Qt5 no se distribuyen | GTK2 funcionaba y estaba verificado, pero está abandonado (Debian 14 prevé retirarlo) y su HiDPI solo admite factores enteros. Qt6 da aspecto actual y HiDPI fraccionario, y el spike de widgetsets lo validó (compila, selftest, Ubuntu 22.04–26.04 y Debian 12–13). Se publican `reportman-designer` (Qt6), `reportman-designer-gtk2` (GTK2, una o dos versiones más) y la AppImage Qt6 (ver 6.8) |
| Distro mínima | **Ubuntu 22.04 / Debian 12** (glibc 2.35) | Lo compilado en la distro más antigua funciona en las nuevas. Coincide con la base de `repweb` |
| Arquitecturas | **x86_64**; arm64 más adelante | FPC/Lazarus soportan aarch64, pero duplica pruebas |
| Prefijo de instalación | **`/opt/reportman-designer`** + enlace en `/usr/bin` | Programa autocontenido con sus datos, fácil de desinstalar |
| Contenido del paquete | Diseñador + ejemplos + traducciones | `printreptopdf` (Delphi Linux64) como paquete aparte `reportman-tools` |
| Formatos | **`.deb` principal + AppImage** | `.deb` = experiencia InnoSetup en Ubuntu/Debian (apt resuelve dependencias). AppImage = "descargar y ejecutar" en cualquier distro. Flatpak/Snap descartados de momento (el sandbox complica ficheros y bases de datos) |
| Repositorio apt | **No en la primera versión** | Descarga directa desde reportman.es / GitHub Releases. Repositorio firmado más adelante para actualizaciones |
| Versión de Lazarus en Linux | **Lazarus 4.x (la misma rama que en Windows)** | WSL tiene 3.0; unificar evita diferencias de LCL entre plataformas |

## Subfases

### 6.1 Ejecutable `repmandesigner_lcl`

- Proyecto `repman/repmandesigner_lcl.lpi` / `.lpr`, junto a `repmandxp.dpr`,
  que depende de los tres paquetes (sin rutas al motor en el `.lpi`, como los
  tests).
- Arranque: `Application.CreateForm(TFRpMainFLCL, ...)`; si recibe un fichero en
  la línea de órdenes lo abre con `OpenReportFile` (ruta relativa al directorio
  de trabajo). `cthreads` y `cwstring` en Linux.
- Localización de recursos en tiempo de ejecución: traducciones
  (`reportmanres.*`) y ejemplos junto al ejecutable y en
  `<prefijo>/share/reportman-designer`; nunca rutas de desarrollador.
- Preferencias del diseñador (ficheros recientes, opciones) en
  `~/.config/reportman/` (XDG). Revisar que `dbxconnections` del usuario y
  `/usr/local/etc` funcionan como en `repweb` y documentarlo.
- Icono de la aplicación (recurso `.res` con iconos de 16 a 256 px).
- Versión y "Acerca de" leyendo `RM_VERSION`.
- Spike de 1–2 días: compilar con Qt5 (`--ws=qt5`, `libqt5pas`) y comparar con
  GTK2 en HiDPI; decidir el widgetset definitivo.
- Verificación: arranca en Windows y en Linux (WSLg y VM Hyper-V con xrdp), abre
  todos los `repman/repsamples/*.rep`, guarda, vista previa y exportación PDF.

**Estado (hecho):**

- El proyecto está en `repman/lcl_designer/` (`repmandesigner_lcl.lpi`, `.lpr`,
  `.ico` y `rmdcmdline.pas`), no directamente en `repman/`: allí hay unidades
  Delphi antiguas (`TmSchema.pas`, `QThemed.pas`…) y FPC busca primero en el
  directorio del proyecto; en Windows recompilaba `TmSchema` y el enlace fallaba
  con "Can't find unit Themes". El ejecutable se escribe en `repman/`
  (`repmandesigner_lcl[.exe]`, ignorado por git), junto a `reportmanres.*` y
  `repsamples/`, para que funcione igual desde el árbol de desarrollo.
- `rmdcmdline.pas` va antes de `Interfaces` en el `uses`: `--help` y
  `--version` (versión y carpetas usadas) funcionan sin pantalla, y sin
  `DISPLAY` avisa en vez de terminar sin mensaje. Acepta rutas relativas y URIs
  `file://`; las excepciones no controladas también salen por stderr.
- Datos: ejemplos junto al ejecutable (`samples/` o `repsamples/`), en
  `<prefijo>/share/reportman-designer/samples` o en `$APPDIR`. Las traducciones
  las carga el motor (`rptranslator`) **solo junto al ejecutable**
  (`ParamStr(0)`, que FPC resuelve con `/proc/self/exe`, así que el enlace de
  `/usr/bin` funciona): por eso los paquetes las instalan con el binario en
  `/opt/reportman-designer/`. Leerlas de `share/` exigiría cambiar
  `rptranslator` (unidad compartida con Delphi); no se ha hecho.
  El idioma sale de `LC_ALL`, `LC_MESSAGES` o `LANG` (en ese orden, como
  POSIX); `rptranslator` resuelve `ca`/`cs` a `reportmanres.cat`/`.csy`, que
  usan códigos de Windows. Los textos de la propia LCL (botones de los
  diálogos, diálogos estándar) se traducen al mismo idioma con los
  `lclstrconsts.<idioma>.po` de Lazarus (`rmdcmdline.TranslateLCL`, desde
  `<exe>/languages/`); `stage_app` los copia de la Lazarus de la imagen de
  compilación (no están en el repositorio).
- Preferencias propias del lanzador (posición, tamaño, maximizada, última
  carpeta) en `$XDG_CONFIG_HOME/reportman/designer_lcl.ini` (por defecto
  `~/.config/reportman/`; en Windows `%LOCALAPPDATA%\reportman\`). El
  diseñador LCL no tiene aún ficheros recientes. Las conexiones siguen la
  convención del motor, igual que `repweb`: `~/.borland/dbxconnections` y
  `dbxdrivers`, con `/usr/local/etc/dbx*.conf` como plantilla que se copia la
  primera vez; la biblioteca, `~/.repmandlib` (documentado en
  `docs/linux-install.md`).
- Modo Release: -O2, sin información de depuración, `-Xs`: 16 MB en Linux,
  15 MB en Win64. Compila en Windows (Lazarus 4.8 con `--pcp` privado, modos
  Default y Release; abre `sample4.rep`/`mod300.rep` y guarda las
  preferencias) y en el contenedor. En Windows, con los paquetes compilados
  (`packages\fpc\build_fpc.bat`):
  `C:\lazarus\lazbuild.exe --ws=win32 --bm=Release repman\lcl_designer\repmandesigner_lcl.lpi`.
- **Spike Qt5**: los tres paquetes y el diseñador compilan con `--ws=qt5`. Con
  la `libqt5pas` 2.6 de Ubuntu 22.04 el enlace falla (faltan
  `QGuiApplication_applicationState`, `QTimer_singleShot3`…: es anterior a la
  LCL de Lazarus 4.8); con la libqt5pas 2.16 de
  github.com/davidbannon/libqt5pas enlaza, arranca bajo Xvfb y abre
  `sample4.rep` igual que GTK2 (`build/linux/spike-qt5.sh`,
  `build-linux.ps1 -Qt5Spike`). Distribuir Qt5 obligaría a incluir
  `libQt5Pas.so.1` en los paquetes (las distros LTS traen versiones viejas).
  El spike posterior de widgetsets (GTK2, GTK3, Qt5, Qt6) llevó a elegir Qt6:
  ver 6.8.
- Pendiente: la verificación manual (WSLg y VM con xrdp; lista en 6.6).

### 6.2 Integración con el escritorio Linux

- `reportman-designer.desktop` (categorías `Office;Development;`, `MimeType=`,
  `Exec=reportman-designer %f`).
- Iconos `hicolor`: 16, 32, 48, 64, 128, 256, 512 px más `scalable` (SVG), a
  partir de `doc/favicon.svg` / `doc/icon-512.png`.
- Tipo MIME `application/x-reportman-report` para `*.rep`
  (`/usr/share/mime/packages/reportman-designer.xml`) para abrir con doble clic.
- Verificación: aparece en el menú, `xdg-open informe.rep` abre el diseñador.

**Estado (hecho):** ficheros en `build/linux/files/`.
`reportman-designer.desktop` usa `Categories=Office;Database;`:
`desktop-file-validate` avisa de que `Office;Development;` son dos categorías
principales y el programa saldría dos veces en el menú. Iconos hicolor de 16,
22, 24, 32, 48, 64, 128, 256 y 512 px generados en el contenedor con
`rsvg-convert` desde `doc/favicon.svg`, más el SVG en `scalable`; el `.ico` de
Windows (16–256 px) se generó igual. El XML MIME reconoce `*.rep` por
extensión y por contenido (`object TRpReport`). En los contenedores de prueba
los disparadores de shared-mime-info y desktop-file-utils registran el tipo y
la asociación (`mimeinfo.cache`), y se deshacen al desinstalar. Falta verlo en
un escritorio real (menú, doble clic, `xdg-open`).

### 6.3 Imagen Docker de compilación

Carpeta `build/linux/`:

- `Dockerfile.builder`: `FROM ubuntu:22.04`; `build-essential`,
  `libgtk2.0-dev` (o `libqt5pas-dev`), `xvfb`, `imagemagick`, `dpkg-dev`,
  `file`, `librsvg2-bin`; FPC 3.2.2 y Lazarus 4.x desde los `.deb` oficiales
  (versiones fijadas en `ARG`).
- Zeos: se monta como volumen de solo lectura (hoy vive fuera del repo en
  `C:\desarrollo\tools\delphicomponents\zeosxe10`) y se registra con
  `lazbuild --add-package-link`. Alternativa a decidir: fijar una versión de
  Zeos 8 descargada en la imagen para no depender de la máquina.
- `build-in-container.sh`: registra paquetes, `build_fpc.sh clean`, compila
  `repmandesigner_lcl` en modo Release (sin información de depuración, `strip`)
  y ejecuta `LclDesignerTest --selftest` bajo `xvfb-run` (fallo = build roto).
- `build-linux.ps1` (Windows): orquesta desde el flujo actual con
  `wsl docker build` / `wsl docker run -v <repo>:/src:ro -v <out>:/out`; el
  release los deja en `release_<ver>\Linux\` junto a los de `build/sourceforge`.
- Verificación: build limpia desde cero en la imagen; mismo resultado dos veces.

**Estado (hecho):**

- `Dockerfile.builder`: Ubuntu 22.04; FPC 3.2.2 y Lazarus 4.8 (la versión de
  Windows) desde los `.deb` oficiales de SourceForge; linuxdeploy
  1-alpha-20251107-1, appimagetool 1.9.1 y el runtime type2 20251108. Todo con
  sha256 en `ARG`. Desde 6.8: Qt 6.2.4 de desarrollo (`qt6-base-dev`,
  `qmake6`, `qt6-qpa-plugins`), `patchelf` y la libQt6Pas 6.2.10 compilada en
  su propia capa (ver 6.8); ya no usa linuxdeploy-plugin-gtk. Etiqueta
  `reportman-linux-builder:fpc3.2.2-laz4.8-qt6`.
- **Zeos se fija dentro de la imagen** (decisión tomada): commit `c527f51a` de
  la rama 8.0-patches (Zeos 8.0.1-beta), el commit en el que se basa la copia
  local `zeosxe10`. La copia local lleva además 9 cambios propios (Delphi Linux,
  `ZCbor`, MySQL/PostgreSQL), ninguno necesario para compilar con FPC en Linux.
- `build-in-container.sh`: copia de trabajo de lo necesario, `--pcp` privado
  con `--add-package-link` (Zeos y los tres paquetes), `build_fpc.sh clean`
  (una pasada por paquete desde 57961c6), diseñador en Release,
  `LclDesignerTest --selftest` bajo `xvfb-run` (fallo = build roto), `.deb` +
  lintian (un error = build roto) + AppImage, y `build-info.txt`. Desde 6.8 lo
  hace dos veces, Qt6 y GTK2, cada una en su copia (`/build/src-qt6`,
  `/build/src-gtk2`: los paquetes no separan la salida por widgetset) y con su
  `--pcp`; los dos selftest rompen la build. Tarda unos 145 s (antes 75 s).
  `build-linux.ps1 -Qt5Spike` completo, con la imagen construida desde
  cero (descarga ~250 MB) y las 6 pruebas de 6.6, tardó 12,5 min (antes de
  6.8).
- `build-linux.ps1`: un solo comando desde Windows (Docker dentro de WSL)
  construye la imagen, compila, empaqueta y ejecuta las pruebas de 6.6. Deja
  todo en `build\linux\out\<versión>\` (ignorado por git); `-Qt5Spike` repite
  la compilación con Qt5, `-SkipTests`, `-SkipImage`, `-NoCache`. La copia al
  release la hace la tarea 06 de `build\sourceforge` (ver 6.7).
- Builds repetibles: las fechas de los ficheros empaquetados se fijan a
  `SOURCE_DATE_EPOCH` (la fecha del último commit, que pasa
  `build-linux.ps1`). Comprobado: dos compilaciones limpias de los mismos
  fuentes en la misma imagen dan el mismo `.deb`, la misma AppImage y el mismo
  ejecutable (sha256 idénticos). La imagen en sí no es bit a bit repetible
  (`apt-get` instala las actualizaciones del día de Ubuntu 22.04).

### 6.4 Paquete `.deb`

- `make-deb.sh` (dentro del contenedor) arma el árbol:
  `/opt/reportman-designer/` (binario, traducciones, ejemplos),
  `/usr/bin/reportman-designer` (enlace), `.desktop`, iconos y MIME.
- `DEBIAN/control` con las dependencias, para que `apt` las instale solo:
  ```
  Package: reportman-designer
  Version: 4.0.16
  Architecture: amd64
  Depends: libgtk2.0-0 | libgtk2.0-0t64, libfreetype6, libfontconfig1,
   libharfbuzz0b, libharfbuzz-subset0, libsqlite3-0,
   libicu70 | libicu72 | libicu74 | libicu76, fonts-dejavu-core
  Recommends: fonts-liberation
  ```
  (la ICU se carga dinámicamente probando versiones, por eso admite
  alternativas).
- `postinst`/`postrm`: `update-desktop-database`, `update-mime-database`,
  `gtk-update-icon-cache`.
- Revisión con `lintian` (sin errores).
- Nombre: `reportman-designer_<ver>_amd64.deb`.
- Verificación: `sudo apt install ./reportman-designer_<ver>_amd64.deb` en un
  Ubuntu limpio instala todo sin pasos manuales; `apt remove` lo deja limpio.

**Estado (hecho):** `make-deb.sh`, unos 4 MB (xz). Desde 6.8 arma dos
variantes: `reportman-designer` (Qt6) y `reportman-designer-gtk2`; lo que
sigue describe la GTK2 y lo común (las dependencias Qt6 están en 6.8).
Diferencias con lo previsto:

- `Depends` = lo que calcula `dpkg-shlibdeps` sobre el binario (GTK2, GLib,
  ATK, Pango, Cairo, GDK-Pixbuf, X11, libc6 ≥ 2.34), con alternativas `t64`
  para los paquetes renombrados en Ubuntu 24.04, más lo que el motor abre con
  `dlopen` (comprobado en el código: `libfreetype.so.6`, `libfontconfig.so.1`,
  `libharfbuzz.so.0`, `libsqlite3.so.0`, `libicuuc.so.60..90`):
  `libfreetype6, libfontconfig1, libharfbuzz0b, libsqlite3-0,
  libicu70 | … | libicu78, fonts-dejavu-core`.
- `libharfbuzz-subset0` pasa a `Recommends` (no existe en Ubuntu 22.04, ver
  riesgos), junto con `fonts-liberation` y `libcups2 | libcups2t64`
  (Printer4Lazarus carga CUPS dinámicamente).
- Incluye página de manual, `copyright` (MPL 1.1/GPL y avisos de FPC/LCL y
  Zeos) y `changelog.gz`. `postinst`/`postrm` llaman a
  `update-desktop-database`, `update-mime-database` y `gtk-update-icon-cache`
  solo si existen (los disparadores de dpkg ya lo hacen en Debian/Ubuntu).
- lintian 2.114 (`--pedantic`): sin errores ni avisos. Overrides, con su
  motivo en `build/linux/files/lintian-overrides`: `dir-or-file-in-opt`
  (decisión de instalar en `/opt`), `hardening-no-pie`/`-bindnow`/`-fortify`
  (FPC no los genera) y `spelling-error-in-binary`/`-in-copyright` (erratas en
  cadenas del motor compartido con Delphi y en el texto literal de la MPL).

### 6.5 AppImage

- `make-appimage.sh` con `linuxdeploy` + `linuxdeploy-plugin-gtk`
  (`DEPLOY_GTK_VERSION=2`) o el plugin Qt si se elige Qt5.
- Empaqueta FreeType, HarfBuzz, ICU y SQLite; fontconfig y las fuentes se toman
  del sistema.
- Nombre: `ReportManDesigner-<ver>-x86_64.AppImage`.
- Verificación: arranca en Ubuntu 22.04, 24.04 y Debian 12 sin instalar nada.

**Estado (hecho; desde 6.8 la AppImage es Qt6, ver 6.8).** Lo que sigue
describe la AppImage GTK2 que se publicaba antes. `make-appimage.sh`, unos
29 MB. El AppDir reutiliza el
árbol del `.deb` (`opt/reportman-designer` + enlace `usr/bin`); linuxdeploy
despliega las dependencias del binario (`--deploy-deps-only`, RUNPATH
`$ORIGIN/../../usr/lib`) y el plugin GTK con `DEPLOY_GTK_VERSION=2`;
appimagetool usa el runtime fijado en la imagen (sin descargas). Diferencia con
el plan: **FreeType, HarfBuzz y fontconfig no se incluyen** (están en la
excludelist de AppImage y deben casar con las del sistema, que siempre las
tiene; así `libharfbuzz-subset.so.0` del sistema casa con su HarfBuzz). Sí se
incluyen GTK2, Pango, Cairo, GLib, ICU 70, SQLite (con el enlace
`libsqlite3.so` que busca SQLdb) y `libfribidi` (excluida por AppImage pero no
siempre presente). El plugin GTK está pensado para GTK3; un hook propio quita
`GTK_DATA_PREFIX`/`GTK_THEME` para que GTK2 use los temas del sistema.

### 6.6 Pruebas en máquina limpia

- VM Hyper-V Ubuntu Server con xrdp: instalar el `.deb`, abrir el menú, doble
  clic en un `.rep`, crear un informe con el asistente, conexión SQLite de
  ejemplo, vista previa, exportar PDF, deshacer/rehacer, guardar, desinstalar.
- Snapshot limpio de la VM para repetir la prueba en cada versión.
- Lista de comprobación en `docs/` para el release.

**Estado (automáticas hechas, manuales pendientes):** `build/linux/test-packages.sh`
(lo llama `build-linux.ps1`) crea para cada imagen (`ubuntu:22.04`,
`ubuntu:24.04`, `debian:12`; desde 6.8 también `debian:13` y `ubuntu:26.04`,
y los tres paquetes: 15 contenedores, 5 a la vez) un contenedor nuevo y:

- `.deb`: `apt install ./reportman-designer_<v>_amd64.deb` sin nada más
  instalado (apt trae 78–108 paquetes con GTK2 y 187–244 con Qt6, según la
  distro; con Recommends); `ldd` sin "not found"; presentes las
  librerías que el motor abre con `dlopen`; ficheros instalados;
  shared-mime-info y desktop-file-utils registran el MIME y la asociación;
  `desktop-file-validate`; `--version` sin pantalla y aviso sin `DISPLAY`;
  `reportman-designer samples/sample4.rep` bajo `xvfb-run`: vivo a los 15 s,
  ventana "Report Manager Designer - [sample4.rep]" y sin excepciones;
  `apt remove`/`purge` no dejan ficheros, MIME ni asociación.
- AppImage: con solo X11, fontconfig, FreeType, HarfBuzz y fuentes del sistema,
  `ldd` de la AppImage extraída sin "not found", `--version` y la misma prueba
  de 15 s con `--appimage-extract-and-run`.
- Desde 6.8, además: el `.deb` Qt6 resuelve `libQt6Pas` desde
  `/opt/reportman-designer/lib` (RUNPATH) y tiene el plugin xcb de Qt; se
  arranca también en una sesión Wayland simulada (`XDG_SESSION_TYPE=wayland`,
  `WAYLAND_DISPLAY` sin compositor, `qt6-wayland` instalado) y debe abrir su
  ventana en X11; instalar la otra variante sustituye a la probada (y al revés)
  sin perder el menú ni la asociación; tras `purge` dpkg no ve ninguna de las
  dos. La AppImage Qt6 se prueba con X11, fontconfig, FreeType, HarfBuzz,
  fuentes, `libegl1` y `libopengl0`, y cada plugin de Qt incluido debe resolver
  sus librerías (salvo `libcups.so.2`, que es la del sistema).
- Deja registros y capturas de pantalla en `build\linux\out\<v>\tests\`.

Lista de comprobación manual para cada release (VM Hyper-V Ubuntu con xrdp,
snapshot limpio; y WSLg):

1. Doble clic en el `.deb` (Centro de software) → instala sin preguntar
   dependencias.
2. El menú muestra "Report Manager Designer" con su icono; abre.
3. Doble clic en un `.rep` del gestor de archivos → abre ese informe.
4. Nuevo informe con el asistente; conexión SQLite de ejemplo
   (`samples/dbxconnections.ini`, `clientes.db`).
5. Vista previa, exportar a PDF y abrir el PDF (fuentes incrustadas).
6. Deshacer/rehacer, guardar, cerrar y volver a abrir; la ventana recuerda su
   posición (`~/.config/reportman/designer_lcl.ini`).
7. Imprimir (CUPS) a PDF virtual.
8. `LANG=es_ES.UTF-8` y `LANG=ca_ES.UTF-8`: textos traducidos.
9. AppImage: `chmod +x` y doble clic en la misma VM (sin el `.deb`).
10. `sudo apt remove reportman-designer`: desaparecen el menú y la asociación.
11. Qt6 en un escritorio Wayland (Ubuntu 24.04 GNOME): arranca por XWayland,
    HiDPI al 125/150/200 %, y una prueba con `QT_QPA_PLATFORM=wayland`
    (posición de ventanas, menús contextuales, arrastrar componentes,
    portapapeles).
12. `sudo apt install ./reportman-designer-gtk2_<v>_amd64.deb` sustituye al
    Qt6 y el diseñador GTK2 abre; volver a instalar el Qt6.

### 6.7 Publicación

- Añadir los artefactos Linux al flujo de release (`build/make-release.ps1`):
  página de descargas de reportman.es y GitHub Releases
  (`tonimartir/reportmandelphi`).
- Opcional: workflow de GitHub Actions (`ubuntu-22.04`) que ejecuta la misma
  imagen Docker en cada etiqueta de versión.
- Más adelante: repositorio apt firmado para actualizaciones automáticas.

**Estado (enganchada al release, 27-09-2026):** la tarea
`build\sourceforge\06-linux-designer.ps1`, última de `make-release.ps1`, llama a
`build-linux.ps1` (compilación, selftest, lintian y las pruebas de 6.6; un fallo
para el release) y copia los paquetes a `release_<v>\Linux\`, junto al zip de
`printreptopdf`, con un `SHA256SUMS` de toda la carpeta
(`sha256sum -c SHA256SUMS`). Desde 6.8 son tres: `reportman-designer_<v>_amd64.deb`
(Qt6), `reportman-designer-gtk2_<v>_amd64.deb` y la AppImage Qt6; antes de
copiarlos borra de `Linux\` los paquetes del diseñador que hubiera. Con
`-SkipBuild` reutiliza los de `build\linux\out\<v>\` si están los tres. La
tarea 05 ya no vacía `Linux\`. Falta subirlo (SourceForge, página de descargas
de reportman.es, GitHub Releases); no hay workflow de GitHub Actions ni
repositorio apt.

### 6.8 Qt6: paquete recomendado (GTK2 transitorio)

Decisión de Toni (27-09-2026), tras el spike de widgetsets: en Linux se
publican

| Fichero | Widgetset | Papel |
|---|---|---|
| `reportman-designer_<v>_amd64.deb` | Qt6 | El recomendado |
| `reportman-designer-gtk2_<v>_amd64.deb` | GTK2 | Transitorio, una o dos versiones (GTK2 está abandonado; Debian 14 prevé retirarlo) |
| `ReportManDesigner-<v>-x86_64.AppImage` | Qt6 | Sustituye a la AppImage GTK2 |

GTK3 y Qt5 no se distribuyen. Aún no se ha publicado nada, así que no hay
actualización desde paquetes anteriores que conservar.

**libQt6Pas.** La LCL de Lazarus 4.8 necesita la libQt6Pas 6.2.10 (el puente C
de la LCL con Qt6, `lcl/interfaces/qt6/cbindings`, Qt ≥ 6.2.3). Ubuntu
22.04/24.04 y Debian 12 no la empaquetan (`libqt6pas6` llega con Debian 13 y
Ubuntu 26.04). La imagen de compilación la compila en su propia capa desde las
cbindings del `.deb` de Lazarus (fijado por sha256; se comprueba que el `.pro`
es la 6.2.10), con qmake6 contra la Qt 6.2.4 de Ubuntu 22.04, los flags de
endurecimiento de `dpkg-buildflags` (sin LTO) y `strip`, y la instala en
`/opt/libqt6pas` (fuera de las rutas del sistema; `sha256.txt` al lado, que
copia `build-info.txt`). Tarda unos 4 min, solo al construir la imagen, y es
repetible: dos compilaciones de la capa dieron el mismo sha256 (`08a72c70…`). El
enlace del diseñador la encuentra con `lazbuild --opt=-Fl/opt/libqt6pas/lib`
y el selftest con `LD_LIBRARY_PATH`. Compilada contra Qt 6.2.4 funciona con
las Qt 6.2.4, 6.4.2, 6.8.2 y 6.10.2 de las distros probadas (Qt mantiene la
compatibilidad binaria dentro de Qt 6).

**`.deb` Qt6.** `libQt6Pas.so.6.2.10` va como librería privada en
`/opt/reportman-designer/lib/` y el ejecutable la encuentra por su RUNPATH
`$ORIGIN/lib` (patchelf al empaquetar). Se prefiere a un lanzador con
`LD_LIBRARY_PATH` porque solo afecta al ejecutable (no lo heredan los programas
que abre el diseñador), funciona igual desde `/usr/bin`, el menú o `/opt`, y
`ldd`/`dpkg-shlibdeps` lo ven. Depends: lo que calcula `dpkg-shlibdeps` sobre
el ejecutable y libQt6Pas (`libqt6core6`, `libqt6gui6`, `libqt6widgets6`,
`libqt6printsupport6` ≥ 6.1/6.2, cada uno con su alternativa `…t64`: Ubuntu
24.04 los renombró todos y Debian 13/Ubuntu 26.04 solo `libqt6core6t64`;
`libstdc++6`, `libgcc-s1`, `libx11-6`, `libc6` ≥ 2.35), más `qt6-qpa-plugins`
(en Ubuntu 22.04 trae el plugin xcb; en las demás está en `libqt6gui6`) y las
mismas librerías que el motor carga en tiempo de ejecución y los mismos
Recommends que GTK2. El plugin de CUPS de Qt viene con `libqt6printsupport6`.
lintian: sin avisos nuevos; el override `dir-or-file-in-opt` ya cubría
`lib/` (su motivo lo menciona). `dpkg-shlibdeps` trabaja sobre un árbol
`debian/<paquete>` con `DEBIAN/` para resolver el `$ORIGIN`, y `shlibs.local`
declara libQt6Pas sin dependencia (va en el propio paquete).

**Las dos variantes.** Instalan los mismos ficheros:
`reportman-designer-gtk2` tiene `Provides: reportman-designer (= <v>)`,
`Conflicts:` y `Replaces: reportman-designer`, y `reportman-designer` tiene
`Conflicts:` y `Replaces: reportman-designer-gtk2`: instalar una quita la otra
(queda en estado `rc` hasta un `purge`, por su `postrm`). `apt remove
reportman-designer` no quita la GTK2 (apt no quita paquetes virtuales): la
guía da los dos nombres. `reportman-designer --version` dice `(LCL qt6)` o
`(LCL gtk2)`.

**Wayland.** Prueba con `weston --backend=headless --renderer=pixman` (sin
pantalla) en Debian 13 (Qt 6.8.2), Ubuntu 24.04 (Qt 6.4.2) y Ubuntu 26.04
(Qt 6.10.2), con `QT_QPA_PLATFORM=wayland`: el `LclDesignerTest --selftest`
completo pasa y el diseñador abre `sample4.rep`, se pinta bien (decoración de
ventana de Qt) y sigue vivo a los 15 s. Lo que no se puede comprobar sin un
escritorio real (y que el protocolo Wayland limita): colocar ventanas (el
diseñador recupera su posición y centra sus diálogos con
`poScreenCenter`/`poMainFormCenter`), menús contextuales y arrastre con un
puntero real, el portapapeles (weston sin asiento) y la decoración de ventana
en GNOME (sin decoraciones del servidor, Qt dibuja las suyas). Por eso `rmdcmdline.SetupQtPlatform` (antes de crear la
QApplication) pone `QT_QPA_PLATFORM=xcb` si hay `DISPLAY` (X11 o XWayland) y
el usuario no ha elegido plataforma (variable o `-platform`); sin `DISPLAY`
pero con `WAYLAND_DISPLAY` elige `wayland`; sin ninguno avisa ("cannot open
the display") y sale con 1, como GTK2. Se hace en el propio programa y no en un
lanzador para que valga igual desde `/usr/bin`, `/opt`, el menú y la AppImage.
Hace falta porque Qt 6, según su versión y el escritorio, prefiere Wayland en
una sesión Wayland si está `qt6-wayland`, que Ubuntu 24.04/26.04 y Debian 13
instalan como Recommends de `libqt6gui6`. `test-packages.sh` lo comprueba con una sesión Wayland simulada.
Con el `.deb` instalado, weston y Xvfb (como XWayland) a la vez, en Ubuntu
22.04/24.04/26.04 y Debian 13: sin `QT_QPA_PLATFORM` la ventana sale en X11;
con `QT_QPA_PLATFORM=wayland`, y sin `DISPLAY`, sale en weston (la Qt 6.2 de
Ubuntu 22.04 avisa "Wayland does not support QWindow::requestActivate()": la
LCL activa ventanas, algo que Wayland no permite). Documentado en
`docs/linux-install.md` y en la página de manual (`QT_QPA_PLATFORM`).

**AppImage Qt6.** linuxdeploy despliega las dependencias del ejecutable
(libQt6Pas con `LD_LIBRARY_PATH`, Qt 6.2.4 de Ubuntu 22.04, ICU 70, GLib,
libxcb-*, libxkbcommon…) y de los plugins de Qt que se copian a mano a
`usr/plugins` (no hace falta linuxdeploy-plugin-qt): `platforms/libqxcb.so`,
`platforminputcontexts` (compose/teclas muertas e IBus) y
`printsupport/libcupsprintersupport.so`; este último se copia sin linuxdeploy
(solo `patchelf`), porque linuxdeploy metería las dependencias de libcups
(GnuTLS, Kerberos, Avahi, p11-kit), que solo usaría la libcups del sistema. Un
`qt.conf` junto al ejecutable (`Prefix = ../../usr`) hace que Qt solo cargue
los plugins del AppDir. No se incluyen `libEGL.so.1`/`libOpenGL.so.0` (glvnd,
excludelist de AppImage; los tiene todo escritorio con Mesa), ni FreeType,
fontconfig, HarfBuzz ni libcups; sí `libgpg-error.so.0` (la usa libgcrypt,
dependencia de libsystemd/libdbus) y `libcom_err.so.2`, que faltan en
instalaciones mínimas de Debian 13. Solo lleva el plugin X11 (sin Wayland
nativo). Unos 31 MB (51 librerías, 70 MB sin comprimir; la ICU son 34 MB).

**Pruebas.** Los dos selftest (Qt6 y GTK2) bajo Xvfb rompen la build; el
de Qt6 con `QT_QPA_PLATFORM=xcb`. `test-packages.sh` prueba los tres paquetes
en Ubuntu 22.04, 24.04, 26.04 y Debian 12, 13 (ver 6.6): las 15 pruebas pasan
(unos 4,5 min, 5 contenedores a la vez). `build-linux.ps1` completo, con la
capa de libQt6Pas reconstruida, tarda unos 12 min.

## Riesgos conocidos

- **GTK2 obsoleto**: Debian 14 prevé retirarlo. Mitigado en 6.8: Qt6 es el
  paquete recomendado y la AppImage es Qt6; `reportman-designer-gtk2` se
  publica una o dos versiones más y después se retira (quitar `gtk2` de
  `WSLIST` en `build-in-container.sh`, su caso en `make-deb.sh`,
  `test-packages.sh` y la tarea 06).
- **libQt6Pas privada**: la mantenemos nosotros (versión fijada por la de
  Lazarus). Al cambiar de Lazarus hay que revisar `QT6PAS_VERSION` en
  `Dockerfile.builder` (la comprobación del `.pro` rompe la imagen si no
  casa). Depende de la compatibilidad binaria de Qt 6 (probada de 6.2.4 a
  6.10.2); una Qt 7 exigiría otro paquete. Si las distros con `libqt6pas6`
  6.2.10 (Debian 13, Ubuntu 26.04) fueran las mínimas, se podría depender de
  ella en vez de incluirla.
- **Qt6 en Wayland nativo sin probar en un escritorio real**: por eso va por
  XWayland salvo `QT_QPA_PLATFORM=wayland` (ver 6.8). Si XWayland
  desapareciera de algún escritorio, el diseñador ya usa Wayland nativo sin
  `DISPLAY`, pero habría que validar la colocación de ventanas y menús.
- **AppImage con Qt 6.2.4**: la Qt de Ubuntu 22.04 (la más antigua soportada)
  va dentro; es la versión LTS más vieja de Qt 6, sin plugin Wayland ni tema
  GTK (estilo Fusion). CUPS es el del sistema: sin él no hay impresoras.
- **FPC 3.2.2 y el ciclo de unidades del motor**: resuelto. `System.NetEncoding`
  en la implementación de `rpsection`/`rpdrawitem` cambiaba su CRC de interfaz
  y dejaba checksums obsoletos en el ciclo rpsection/rpsubreport/rpsecutil; con
  FPC ahora se usa en la interfaz y cada paquete compila en una sola pasada
  (también desde el IDE/OPM). En la imagen se compila siempre en limpio.
- **Zeos fuera del repo**: resuelto para Linux; la imagen fija Zeos por commit
  (ver 6.3). La copia local de Windows sigue siendo aparte.
- **HarfBuzz subset en Ubuntu 22.04**: no existe `libharfbuzz-subset0` (llega
  con HarfBuzz 4+); el motor lo tolera (el PDF incrusta la fuente entera), por
  eso va en `Recommends` y no en `Depends` como decía el plan.
- **Traducciones solo junto al ejecutable** (`rptranslator`): condiciona el
  diseño del paquete (todo en `/opt/reportman-designer`). Si se quisiera
  `/usr/share`, hay que cambiar `rptranslator` (unidad compartida con Delphi).
- **Ejecutables no PIE**: FPC 3.2.2 no genera PIE ni usa `-z now`/FORTIFY;
  lintian lo marca y se documenta con overrides.
- **Menú principal sin traducir**: resuelto (70cd0e7): menús y barra de
  herramientas con `TranslateStr` y los textos de la LCL traducidos.
- **Funciones solo Windows**: DataDirect/WebRTC queda en HTTP. En Linux no hay
  Monaco (decisión del 28-09-2026: hasta que la LCL GTK3 esté lista): el
  editor SQL es SynEdit con completado por esquema y la sugerencia de SQL de
  la IA (1da814b).
- **Vista previa en Linux**: resuelto; el texto se recorta (9c74a64) y el HTML
  en línea conserva sus estilos (`LclSnapshotTest`, `TestTextClipAndAlign` y
  `TestHtmlRuns`).
- **Paridad del inspector**: resuelta; las listas de propiedades de los
  elementos son las de la VCL (`LclDesignerTest`, `TestItemInterfaces`).

## Criterios de aceptación de la Fase 6

1. Un usuario de Ubuntu 22.04+ instala el `.deb` con doble clic o `apt install`
   sin instalar nada a mano, y lo desinstala limpio.
2. El diseñador aparece en el menú y abre los `.rep` con doble clic.
3. La AppImage arranca en Ubuntu 22.04, 24.04 y Debian 12 (desde 6.8 también
   Debian 13 y Ubuntu 26.04).
4. Todo el empaquetado Linux se genera con un único comando desde Windows
   (`build/linux/build-linux.ps1`) en Docker, e incluye el selftest bajo Xvfb.
5. El selftest del diseñador y el grupo Delphi siguen en verde (Delphi solo ve
   arreglos de bugs, regla de la 5.5).

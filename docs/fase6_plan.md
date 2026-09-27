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

## Decisiones a tomar antes de empezar (con recomendación)

| Decisión | Recomendación | Motivo |
|---|---|---|
| Widgetset | **GTK2 en la primera versión**; evaluar Qt5 en 6.1 | GTK2 ya funciona y está verificado. GTK2 está obsoleto a medio plazo (Qt5/Qt6 dan mejor HiDPI y aspecto moderno), pero cambiar ahora retrasa la entrega. El criterio para cambiar: HiDPI y aspecto en Ubuntu 24.04+ |
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

### 6.2 Integración con el escritorio Linux

- `reportman-designer.desktop` (categorías `Office;Development;`, `MimeType=`,
  `Exec=reportman-designer %f`).
- Iconos `hicolor`: 16, 32, 48, 64, 128, 256, 512 px más `scalable` (SVG), a
  partir de `doc/favicon.svg` / `doc/icon-512.png`.
- Tipo MIME `application/x-reportman-report` para `*.rep`
  (`/usr/share/mime/packages/reportman-designer.xml`) para abrir con doble clic.
- Verificación: aparece en el menú, `xdg-open informe.rep` abre el diseñador.

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
  `wsl docker build` / `wsl docker run -v <repo>:/src:ro -v <out>:/out`, y deja
  los artefactos en `release_<ver>\Linux\` junto a los de `build/sourceforge`.
- Verificación: build limpia desde cero en la imagen; mismo resultado dos veces.

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

### 6.5 AppImage

- `make-appimage.sh` con `linuxdeploy` + `linuxdeploy-plugin-gtk`
  (`DEPLOY_GTK_VERSION=2`) o el plugin Qt si se elige Qt5.
- Empaqueta FreeType, HarfBuzz, ICU y SQLite; fontconfig y las fuentes se toman
  del sistema.
- Nombre: `ReportManDesigner-<ver>-x86_64.AppImage`.
- Verificación: arranca en Ubuntu 22.04, 24.04 y Debian 12 sin instalar nada.

### 6.6 Pruebas en máquina limpia

- VM Hyper-V Ubuntu Server con xrdp: instalar el `.deb`, abrir el menú, doble
  clic en un `.rep`, crear un informe con el asistente, conexión SQLite de
  ejemplo, vista previa, exportar PDF, deshacer/rehacer, guardar, desinstalar.
- Snapshot limpio de la VM para repetir la prueba en cada versión.
- Lista de comprobación en `docs/` para el release.

### 6.7 Publicación

- Añadir los artefactos Linux al flujo de release (`build/make-release.ps1`):
  página de descargas de reportman.es y GitHub Releases
  (`tonimartir/reportmandelphi`).
- Opcional: workflow de GitHub Actions (`ubuntu-22.04`) que ejecuta la misma
  imagen Docker en cada etiqueta de versión.
- Más adelante: repositorio apt firmado para actualizaciones automáticas.

## Riesgos conocidos

- **GTK2 obsoleto**: alguna distro futura puede retirarlo. Mitigación: spike Qt5
  en 6.1 y AppImage con las librerías incluidas.
- **FPC 3.2.2 y el ciclo de unidades del motor**: resuelto. `System.NetEncoding`
  en la implementación de `rpsection`/`rpdrawitem` cambiaba su CRC de interfaz
  y dejaba checksums obsoletos en el ciclo rpsection/rpsubreport/rpsecutil; con
  FPC ahora se usa en la interfaz y cada paquete compila en una sola pasada
  (también desde el IDE/OPM). En la imagen se compila siempre en limpio.
- **Zeos fuera del repo**: la build depende de una carpeta local; decidir en 6.3
  si se fija una versión dentro de la imagen.
- **Funciones solo Windows**: Monaco (WebView2) cae al editor de texto simple;
  DataDirect/WebRTC queda en HTTP. Valorar WebKitGTK para Monaco en una fase
  posterior.
- **Vista previa en Linux**: el texto que desborda no se recorta y el HTML en
  línea se pinta sin formato (hallazgos de la auditoría); conviene corregirlo
  antes o durante 6.6.
- **Paridad del inspector** (gráfico, código de barras, imagen, expresión): sigue
  pendiente como fase propia; no bloquea el instalador pero sí la experiencia.

## Criterios de aceptación de la Fase 6

1. Un usuario de Ubuntu 22.04+ instala el `.deb` con doble clic o `apt install`
   sin instalar nada a mano, y lo desinstala limpio.
2. El diseñador aparece en el menú y abre los `.rep` con doble clic.
3. La AppImage arranca en Ubuntu 22.04, 24.04 y Debian 12.
4. Todo el empaquetado Linux se genera con un único comando desde Windows
   (`build/linux/build-linux.ps1`) en Docker, e incluye el selftest bajo Xvfb.
5. El selftest del diseñador y el grupo Delphi siguen en verde (Delphi solo ve
   arreglos de bugs, regla de la 5.5).

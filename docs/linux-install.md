# Report Manager Designer en Linux

El diseñador de Report Manager para Linux es la versión LCL (Lazarus, GTK2) del
diseñador de Windows. Se distribuye de dos formas:

| Formato | Fichero | Para quién |
|---|---|---|
| Paquete `.deb` | `reportman-designer_<versión>_amd64.deb` | Ubuntu 22.04 o posterior, Debian 12 o posterior y derivadas (Linux Mint 21+, Pop!_OS, Zorin…). `apt` instala las dependencias solo. |
| AppImage | `ReportManDesigner-<versión>-x86_64.AppImage` | Cualquier distribución x86_64 con glibc 2.35 o posterior. Se descarga y se ejecuta, sin instalar nada. |

Solo hay versión para PC de 64 bits (x86_64). La versión (por ejemplo `4.0.16`)
es la misma que la del diseñador de Windows.

## Instalar el paquete `.deb` (recomendado)

1. Descarga `reportman-designer_<versión>_amd64.deb` desde
   [reportman.es](https://reportman.es).
2. Instálalo:
   - con doble clic, que lo abre con el instalador de aplicaciones del
     escritorio (Centro de software de Ubuntu, GDebi…), o
   - desde un terminal, en la carpeta de la descarga:

     ```sh
     sudo apt install ./reportman-designer_4.0.16_amd64.deb
     ```

     El `./` es necesario: le dice a `apt` que es un fichero y no un paquete del
     repositorio. `apt` descarga e instala todas las dependencias.

Después de instalarlo:

- **Report Manager Designer** aparece en el menú de aplicaciones (Oficina).
- Los ficheros `.rep` se abren con el diseñador con doble clic (tipo MIME
  `application/x-reportman-report`).
- Se puede arrancar desde un terminal: `reportman-designer [informe.rep]`
  (`reportman-designer --version` muestra la versión y las carpetas que usa;
  `man reportman-designer` tiene la ayuda).

Qué instala:

| Ruta | Contenido |
|---|---|
| `/opt/reportman-designer/` | El programa, las traducciones (`reportmanres.*`, y en `languages/` las de la LCL) y los ejemplos (`samples/`) |
| `/usr/bin/reportman-designer` | Enlace al programa |
| `/usr/share/applications/reportman-designer.desktop` | Entrada del menú |
| `/usr/share/mime/packages/reportman-designer.xml` | Tipo MIME de `*.rep` |
| `/usr/share/icons/hicolor/*/apps/reportman-designer.*` | Iconos (16 a 512 px y SVG) |

### Desinstalar

```sh
sudo apt remove reportman-designer
```

Quita el programa, el menú, los iconos y la asociación de `*.rep`. Tus ficheros
no se tocan: preferencias (`~/.config/reportman/`), conexiones
(`~/.borland/`) ni informes.

### Actualizar

Instala el `.deb` de la versión nueva igual que la primera vez; `apt` sustituye
la anterior. (Todavía no hay repositorio `apt` con actualizaciones automáticas.)

## Usar la AppImage

1. Descarga `ReportManDesigner-<versión>-x86_64.AppImage`.
2. Dale permiso de ejecución y ábrela:

   ```sh
   chmod +x ReportManDesigner-4.0.16-x86_64.AppImage
   ./ReportManDesigner-4.0.16-x86_64.AppImage [informe.rep]
   ```

   (o, en el gestor de archivos: Propiedades → Permitir ejecutar como programa,
   y doble clic).

La AppImage lleva dentro GTK2, Pango, Cairo, GLib, ICU y SQLite. Del sistema usa
lo que tiene cualquier escritorio: X11 (o XWayland), fontconfig, FreeType,
HarfBuzz, las fuentes y CUPS para imprimir.

- Si al abrirla aparece un error de **FUSE**, ejecútala sin montarla:
  `./ReportManDesigner-4.0.16-x86_64.AppImage --appimage-extract-and-run`
  (o instala el paquete `fuse3`/`fuse` de tu distribución).
- La AppImage no se añade sola al menú ni se asocia con `*.rep`. Para eso usa
  el `.deb` o una herramienta como AppImageLauncher o Gear Lever.
- Para borrarla, borra el fichero.

## Dependencias del paquete `.deb`

`apt` las instala automáticamente; se listan por si se instala en una
distribución no soportada o algo falla.

- Enlazadas al programa (las calcula `dpkg-shlibdeps`): GTK2 (`libgtk2.0-0` o
  `libgtk2.0-0t64`), GLib, ATK, Pango, Cairo, GDK-Pixbuf, X11 y glibc 2.34 o
  posterior.
- Cargadas en tiempo de ejecución por el motor: `libfreetype6`,
  `libfontconfig1`, `libharfbuzz0b`, `libsqlite3-0` y una ICU entre la 70 y la
  78 (`libicu70` en Ubuntu 22.04, `libicu72` en Debian 12, `libicu74` en
  Ubuntu 24.04…), más las fuentes `fonts-dejavu-core`.
- Recomendadas (se instalan salvo con `--no-install-recommends`):
  `fonts-liberation` (métricas compatibles con Arial/Times/Courier),
  `libharfbuzz-subset0` (el PDF incrusta solo los caracteres usados de cada
  fuente; sin ella incrusta la fuente entera; Ubuntu 22.04 no la tiene) y
  `libcups2` para imprimir.

## Primeros pasos

- Los ejemplos están en `/opt/reportman-designer/samples/`. Esa carpeta es de
  solo lectura; para modificarlos, cópialos a tu carpeta personal:

  ```sh
  cp -r /opt/reportman-designer/samples ~/reportman-ejemplos
  ```

  Los ejemplos con datos necesitan su conexión: las de prueba (por ejemplo
  `SQLITETEST`, SQLite sobre `clientes.db`) están en
  `samples/dbxconnections.ini` y se dan de alta en la configuración de
  conexiones del diseñador.
- El idioma del diseñador (menús, barras de herramientas, diálogos y
  mensajes, también los botones de los diálogos estándar) sigue `LC_ALL`,
  `LC_MESSAGES` o `LANG`, en ese orden (español, inglés, catalán, francés,
  alemán, italiano, portugués, checo y lituano; si no hay traducción, inglés).
  Por ejemplo `LANG=fr_FR.UTF-8 reportman-designer`.

## Configuración

| Qué | Dónde |
|---|---|
| Preferencias del diseñador (posición de la ventana, última carpeta) | `~/.config/reportman/designer_lcl.ini` (respeta `XDG_CONFIG_HOME`) |
| Conexiones y controladores de bases de datos | `~/.borland/dbxconnections` y `~/.borland/dbxdrivers`, compartidos con las demás herramientas de Report Manager |
| Plantillas de conexiones para todos los usuarios | `/usr/local/etc/dbxconnections.conf` y `/usr/local/etc/dbxdrivers.conf`: se copian a `~/.borland/` la primera vez (la misma convención que el servidor `repweb`) |
| Conexiones de la biblioteca de informes | `~/.repmandlib` |

## Limitaciones conocidas de la versión Linux

- **Editor SQL sin Monaco**: el editor Monaco (autocompletado, resaltado) usa
  WebView2, que solo existe en Windows. En Linux el SQL y las expresiones se
  editan con el editor de texto simple.
- **DataDirect solo por HTTP**: el canal directo WebRTC (P2P) del controlador
  *Reportman Agent* solo está en Windows. En Linux las consultas van siempre por
  HTTP a través del Hub (`api.reportman.es`), con los mismos resultados y algo
  más de latencia.
- **GTK2**: aspecto clásico y escalado HiDPI limitado (solo factores enteros,
  por ejemplo `GDK_SCALE=2 reportman-designer`). En Wayland funciona a través
  de XWayland. Se valorará Qt5/Qt6 en versiones futuras.
- **Vista previa**: el texto que desborda su caja no se recorta y el HTML en
  línea se pinta sin formato (pendiente en el motor LCL).
- **Inspector de objetos**: algunos editores específicos (gráfico, código de
  barras, imagen, expresión) todavía no tienen la misma funcionalidad que en
  Windows.
- Solo x86_64; arm64 más adelante.

## Problemas frecuentes

- **`error while loading shared libraries: libXXX.so`** con la AppImage: falta
  una librería básica del escritorio en el sistema; instálala con el gestor de
  paquetes (por ejemplo `libfribidi0`, `libharfbuzz0b`, `libfontconfig1`) o usa
  el `.deb`.
- **`No ICU library found`** al exportar o previsualizar: instala la ICU de tu
  distribución (`apt install libicu74`, `libicu72`…).
- **`cannot open the X display`**: el diseñador necesita un escritorio gráfico
  (X11 o XWayland); por SSH usa `ssh -X` o un escritorio remoto.
  `reportman-designer --version` y `--help` funcionan sin pantalla.

## Para desarrolladores: generar los paquetes

Los paquetes se generan en un contenedor Docker (Ubuntu 22.04, FPC 3.2.2,
Lazarus 4.8 y Zeos 8.0 fijados), desde Windows con Docker dentro de WSL:

```powershell
build\linux\build-linux.ps1              # imagen + compilación + selftest + .deb + AppImage + pruebas
build\linux\build-linux.ps1 -SkipTests   # sin las pruebas en máquinas limpias
```

El resultado queda en `build\linux\out\<versión>\`. Detalles en
`build/linux/` (`Dockerfile.builder`, `build-in-container.sh`, `make-deb.sh`,
`make-appimage.sh`, `test-packages.sh`) y en `docs/fase6_plan.md`.

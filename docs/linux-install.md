# Report Manager Designer en Linux

El diseñador de Report Manager para Linux es la versión LCL (Lazarus) del
diseñador de Windows, compilada con Qt 6. Se distribuye en tres ficheros:

| Fichero | Qué es | Para quién |
|---|---|---|
| `reportman-designer_<versión>_amd64.deb` | Paquete `.deb`, **Qt 6 (recomendado)** | Ubuntu 22.04 o posterior, Debian 12 o posterior y derivadas (Linux Mint 21+, Pop!_OS, Zorin…). `apt` instala las dependencias solo. |
| `reportman-designer-gtk2_<versión>_amd64.deb` | Paquete `.deb`, GTK2 (transitorio) | Las mismas distribuciones, solo si la versión Qt 6 no te sirve (ver [¿Qt 6 o GTK2?](#qt-6-o-gtk2)). |
| `ReportManDesigner-<versión>-x86_64.AppImage` | AppImage, Qt 6 | Cualquier distribución x86_64 con glibc 2.35 o posterior. Se descarga y se ejecuta, sin instalar nada. |

Solo hay versión para PC de 64 bits (x86_64). La versión (por ejemplo `4.0.16`)
es la misma que la del diseñador de Windows. `SHA256SUMS`, junto a los
ficheros, permite comprobar la descarga (`sha256sum -c SHA256SUMS
--ignore-missing`).

## ¿Qt 6 o GTK2?

- **Qt 6 (`reportman-designer`)**: el recomendado. Aspecto actual y escalado
  HiDPI automático, también con factores fraccionarios (sigue la escala del
  escritorio; se puede forzar con `QT_SCALE_FACTOR=1.5 reportman-designer`).
- **GTK2 (`reportman-designer-gtk2`)**: el mismo diseñador compilado con GTK2,
  que se publica durante una o dos versiones como alternativa. GTK2 ya no
  tiene mantenimiento y Debian 14 tiene previsto retirarlo, así que este
  paquete desaparecerá. Úsalo solo si tu sistema no tiene los paquetes de Qt 6
  o si algo falla con la versión Qt 6 (y avísanos, para corregirlo).

Los dos paquetes instalan los mismos ficheros y no pueden estar instalados a la
vez: **instalar uno sustituye al otro**. Para cambiar, instala el otro `.deb`:

```sh
sudo apt install ./reportman-designer-gtk2_4.0.16_amd64.deb   # pasar a GTK2
sudo apt install ./reportman-designer_4.0.16_amd64.deb        # volver a Qt 6
```

`apt` avisa de que quita el paquete anterior. Tus preferencias, conexiones e
informes no cambian (son los mismos para las dos versiones).
`reportman-designer --version` dice cuál tienes: `(LCL qt6)` o `(LCL gtk2)`.

## Instalar el paquete `.deb` (recomendado)

1. Descarga `reportman-designer_<versión>_amd64.deb` (Qt 6) desde
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
| `/opt/reportman-designer/lib/` | Solo Qt 6: `libQt6Pas`, el enlace de la LCL con Qt 6 (Ubuntu 22.04/24.04 y Debian 12 no la tienen); el resto de Qt 6 es el de la distribución |
| `/usr/bin/reportman-designer` | Enlace al programa |
| `/usr/share/applications/reportman-designer.desktop` | Entrada del menú |
| `/usr/share/mime/packages/reportman-designer.xml` | Tipo MIME de `*.rep` |
| `/usr/share/icons/hicolor/*/apps/reportman-designer.*` | Iconos (16 a 512 px y SVG) |

### Desinstalar

```sh
sudo apt remove reportman-designer        # versión Qt 6
sudo apt remove reportman-designer-gtk2   # versión GTK2
```

Quita el programa, el menú, los iconos y la asociación de `*.rep`. Tus ficheros
no se tocan: preferencias (`~/.config/reportman/`), conexiones
(`~/.borland/`) ni informes. (`apt remove reportman-designer` no quita la
versión GTK2: hay que dar su nombre. `sudo apt autoremove` quita después las
dependencias que ya nadie usa.)

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

La AppImage es la versión Qt 6: lleva dentro Qt 6.2 (con su plugin X11),
`libQt6Pas`, GLib, ICU y SQLite. Del sistema usa lo que tiene cualquier
escritorio: X11 (o XWayland), fontconfig, FreeType, HarfBuzz, las fuentes,
`libEGL.so.1` y `libOpenGL.so.0` (paquetes `libegl1` y `libopengl0`, los
instala cualquier escritorio con Mesa), CUPS para imprimir (sin CUPS no hay
impresoras, pero el resto funciona) y OpenSSL con los certificados de CA
para las conexiones HTTPS al Hub (sin ellos solo fallan esas conexiones). No
hay AppImage GTK2.

- Si al abrirla aparece un error de **FUSE**, ejecútala sin montarla:
  `./ReportManDesigner-4.0.16-x86_64.AppImage --appimage-extract-and-run`
  (o instala el paquete `fuse3`/`fuse` de tu distribución).
- La AppImage no se añade sola al menú ni se asocia con `*.rep`. Para eso usa
  el `.deb` o una herramienta como AppImageLauncher o Gear Lever.
- Para borrarla, borra el fichero.

## Dependencias de los paquetes `.deb`

`apt` las instala automáticamente; se listan por si se instala en una
distribución no soportada o algo falla.

- Qt 6 (`reportman-designer`), enlazadas al programa (las calcula
  `dpkg-shlibdeps`): Qt 6.2 o posterior (`libqt6core6`, `libqt6gui6`,
  `libqt6widgets6` y `libqt6printsupport6`, o sus nombres `…t64` de Ubuntu
  24.04), `libstdc++6`, X11 y glibc 2.35 o posterior; además
  `qt6-qpa-plugins` (en Ubuntu 22.04 trae el plugin X11 de Qt). `libQt6Pas`
  va dentro del paquete.
- GTK2 (`reportman-designer-gtk2`), enlazadas al programa: GTK2
  (`libgtk2.0-0` o `libgtk2.0-0t64`), GLib, ATK, Pango, Cairo, GDK-Pixbuf, X11
  y glibc 2.34 o posterior.
- Las dos, cargadas en tiempo de ejecución por el motor: `libfreetype6`,
  `libfontconfig1`, `libharfbuzz0b`, `libsqlite3-0` y una ICU entre la 70 y la
  78 (`libicu70` en Ubuntu 22.04, `libicu72` en Debian 12, `libicu74` en
  Ubuntu 24.04…), más las fuentes `fonts-dejavu-core`.
- Las dos, para HTTPS (IA de `aiapi.reportman.es` y driver `rpdbHttp` del
  Agente): OpenSSL 3 (`libssl3` o `libssl3t64`; el motor también acepta la
  1.1) y `ca-certificates`, porque el certificado del servidor se verifica con
  el almacén de CA del sistema.
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
  `samples/dbxconnections.ini`. Dalas de alta con los mismos parámetros en
  Informe > Configuración de datos > Configurar (el editor de
  `~/.borland/dbxconnections`, o de `~/.dbxconnections` si el primero no
  existe), o copia sus secciones a ese fichero.
- El idioma del diseñador (menús, barras de herramientas, diálogos y
  mensajes, también los botones de los diálogos estándar) sigue `LC_ALL`,
  `LC_MESSAGES` o `LANG`, en ese orden (español, inglés, catalán, francés,
  alemán, italiano, portugués, checo y lituano; si no hay traducción, inglés).
  Por ejemplo `LANG=fr_FR.UTF-8 reportman-designer`.

## Wayland

En una sesión Wayland (GNOME, KDE Plasma…) el diseñador funciona a través de
XWayland, como una aplicación X11:

- La versión Qt 6, si la variable `QT_QPA_PLATFORM` no está definida, elige
  X11 (`xcb`) aunque la sesión sea Wayland. Con el Wayland nativo de Qt la LCL
  no puede colocar las ventanas (el protocolo no lo permite): el diseñador no
  recuperaría su posición ni centraría los diálogos, y no se ha probado en un
  escritorio real. Si defines `QT_QPA_PLATFORM`, se respeta; para probar el
  Wayland nativo (paquete `.deb`, con `qt6-wayland` instalado):

  ```sh
  sudo apt install qt6-wayland
  QT_QPA_PLATFORM=wayland reportman-designer
  ```

  La AppImage solo lleva el plugin X11 de Qt.
- La versión GTK2 solo funciona sobre X11/XWayland.

Si el escritorio no tiene XWayland (poco habitual), la versión Qt 6 usa el
Wayland nativo si está instalado `qt6-wayland`.

## Configuración

| Qué | Dónde |
|---|---|
| Preferencias del diseñador (posición de la ventana, última carpeta) | `~/.config/reportman/designer_lcl.ini` (respeta `XDG_CONFIG_HOME`) |
| Conexiones y controladores de bases de datos | `~/.borland/dbxconnections` y `~/.borland/dbxdrivers`, compartidos con las demás herramientas de Report Manager; si no existen, `~/.dbxconnections` y `~/.dbxdrivers` |
| Plantillas de conexiones para todos los usuarios | `/usr/local/etc/dbxconnections.conf` y `/usr/local/etc/dbxdrivers.conf`: se copian a `~/.borland/` la primera vez (la misma convención que el servidor `repweb`) |
| Conexiones de la biblioteca de informes | `~/.repmandlib` |

## Limitaciones conocidas de la versión Linux

- **Editor SQL sin Monaco**: el editor Monaco usa WebView2, que solo existe en
  Windows (no habrá Monaco en Linux hasta que la LCL GTK3 esté lista). En
  Linux el SQL se edita con un SynEdit con resaltado, completado de las tablas
  y columnas del esquema (Ctrl+Espacio, y solo tras `.` y `FROM`/`JOIN`) y la
  sugerencia de IA de Monaco: se escribe un comentario en lenguaje natural y
  la IA propone el SQL en gris en el cursor; Tab lo acepta, Esc lo descarta.
  Las respuestas del chat de IA se muestran con el visor HTML nativo.
- **Controladores de datos**: MyBase (ficheros de texto y XML), Zeos,
  FireDAC / SQLdb y Reportman AI Agent. ADO, BDE, IBX, dbExpress y .NET son
  de la versión Windows (Delphi); un informe que los use muestra su
  conexión como "(no disponible)" y no la cambia.
- **FireDAC / SQLdb**: FireDAC no existe en Linux; las conexiones FireDAC
  (las mismas que escribe el diseñador de Windows: `DriverName=FireDac` y su
  `DriverID`) se abren con SQLdb, el motor de bases de datos de Free Pascal.
  Drivers: SQLite, PG (PostgreSQL), MySQL (y MariaDB), FB e IB (Firebird e
  InterBase), MSSQL (SQL Server, con FreeTDS), Ora (Oracle) y ODBC. Cada uno
  necesita la librería cliente de su base de datos, que se carga al conectar:
  `libpq5`, `libmariadb3` o `libmysqlclient21`, `libfbclient2`, `libsybdb5`,
  el Instant Client de Oracle o `libodbc2` (el paquete `.deb` las sugiere).
  ASA, DB2, Informix, Teradata y MongoDB no tienen conector en SQLdb.
- **Exportar a Excel** no existe (la versión Windows usa Excel por OLE): la
  vista previa guarda en PDF, PDF/A-3, HTML, SVG, CSV, texto, PNG, BMP y
  metafile. *Enviar por correo* abre el cliente de correo del escritorio con
  el PDF adjunto (`xdg-email`, paquete `xdg-utils`).
- **DataDirect solo por HTTP**: el canal directo WebRTC (P2P) del controlador
  *Reportman Agent* solo está en Windows. En Linux las consultas van siempre por
  HTTP a través de `aiapi.reportman.es` y el Hub, con los mismos resultados y algo
  más de latencia.
- **Versión GTK2** (`reportman-designer-gtk2`): aspecto clásico y escalado
  HiDPI limitado: textos y ventanas crecen con el DPI del escritorio
  (`Xft.dpi`, que GNOME ajusta al escalar), pero los iconos y lo que dibuja
  GTK2 (barras de desplazamiento, casillas) se quedan pequeños, y
  `GDK_SCALE` no tiene efecto en GTK2. Es transitoria: GTK2 ya no se
  mantiene y el paquete desaparecerá en una o dos versiones; usa la versión
  Qt 6.
- **Wayland**: la versión Qt 6 va por XWayland salvo que se pida el Wayland
  nativo (ver [Wayland](#wayland)).
- Solo x86_64; arm64 más adelante.

## Problemas frecuentes

- **`error while loading shared libraries: libXXX.so`** con la AppImage: falta
  una librería básica del escritorio en el sistema; instálala con el gestor de
  paquetes (por ejemplo `libegl1` y `libopengl0` para `libEGL.so.1` y
  `libOpenGL.so.0`, `libharfbuzz0b`, `libfontconfig1`) o usa el `.deb`.
- **`Could not load the Qt platform plugin "xcb"`** (versión Qt 6): falta el
  plugin X11 de Qt o una de sus librerías. Con el `.deb` no debería pasar
  (`apt` las instala); comprueba que están `qt6-qpa-plugins` y `libqt6gui6`
  (o `libqt6gui6t64`) y, como solución rápida, prueba el paquete GTK2.
- **`No ICU library found`** al exportar o previsualizar: instala la ICU de tu
  distribución (`apt install libicu74`, `libicu72`…).
- **`cannot open the display`** / **`cannot open the X display`**: el
  diseñador necesita un escritorio gráfico (X11, XWayland o, con Qt 6,
  Wayland); por SSH usa `ssh -X` o un escritorio remoto.
  `reportman-designer --version` y `--help` funcionan sin pantalla.

## Para desarrolladores: generar los paquetes

Los paquetes se generan en un contenedor Docker (Ubuntu 22.04, FPC 3.2.2,
Lazarus 4.8, Zeos 8.0 y Qt 6.2.4 con `libQt6Pas` 6.2.10 compilada en la
imagen, todo fijado), desde Windows con Docker dentro de WSL:

```powershell
build\linux\build-linux.ps1              # imagen + compilación Qt6 y GTK2 + selftests + 2 .deb + AppImage + pruebas
build\linux\build-linux.ps1 -SkipTests   # sin las pruebas en máquinas limpias
```

El resultado queda en `build\linux\out\<versión>\`. Detalles en
`build/linux/` (`Dockerfile.builder`, `build-in-container.sh`, `make-deb.sh`,
`make-appimage.sh`, `test-packages.sh`) y en `docs/fase6_plan.md`.

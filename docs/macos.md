# Report Manager Designer en macOS (LCL Cocoa)

El diseñador LCL (el mismo de Linux) compila en macOS con el widgetset nativo
**Cocoa** y pasa `LclDesignerTest --selftest` completo. Probado en macOS 11 Big
Sur (Intel, x86_64) con FPC 3.2.2 y Lazarus 4.8. Todavía no hay paquete para
distribuir (`.app` con sus librerías, firmado): ver [Pendiente](#pendiente).

## Compilar

Todo se instala en la carpeta del usuario (`~/dev` por defecto), sin `sudo` y
sin tocar `/usr/local`. El único requisito previo son las Command Line Tools de
Xcode:

```sh
xcode-select --install
```

Desde una copia del repositorio en el Mac:

```sh
build/macos/setup-toolchain.sh     # FPC 3.2.2, Lazarus 4.8, Zeos, lazbuild (~650 MB)
build/macos/build-deps.sh          # FreeType, HarfBuzz y fontconfig (~25 MB de fuentes)
. ~/dev/env.sh                     # lazbuild y fpc en el PATH
LAZBUILD=lazbuild sh packages/fpc/build_fpc.sh
lazbuild --no-write-project repman/lcl_designer/repmandesigner_lcl.lpi
```

- `setup-toolchain.sh` usa el `.dmg` oficial de FPC 3.2.2 **sin instalarlo**
  (extrae el paquete en `~/dev/fpc`) y el zip oficial de Lazarus 4.8. El
  Lazarus 4.8 de macOS se publica con FPC 3.2.4rc1, pero se usa 3.2.2, el
  mismo que en Windows y Linux. Por eso las PPU de Lazarus se recompilan una
  vez (`lazbuild -B -r`). También aplica los parches de
  `build/macos/patches` a esa copia de Lazarus.
- `lazbuild` es un envoltorio con su propia configuración (`~/dev/lazcfg`), en
  la que están registrados Zeos y los tres paquetes de Report Manager.
- `RM_MACOS_TOOLS` y `RM_MACOS_DEPS` cambian las carpetas de los dos scripts.

Lazarus genera `repman/repmandesigner_lcl.app` (y `LclDesignerTest.app`):
dentro del bundle hay un enlace al ejecutable, que se queda junto al `.lpi`.

## Probar

```sh
lazbuild --no-write-project tests/fpc/LclDesignerTest/LclDesignerTest.lpi
export DYLD_LIBRARY_PATH=~/dev/macdeps/prefix/lib
tests/fpc/LclDesignerTest/LclDesignerTest --selftest
```

Se ejecuta el binario, no el `.app`: el test busca los ejemplos
(`repman/repsamples`) relativos al ejecutable. Hace falta una sesión gráfica
abierta con el mismo usuario (sirve lanzarlo por SSH). `selftest.log` se
escribe en modo añadir: hay que leer solo la última ejecución.

## Librerías del motor

Fuera de Windows el motor mide y da forma al texto con FreeType, HarfBuzz,
fontconfig e ICU, que se cargan al usarse (no hacen falta para compilar):

| Librería | En macOS |
|---|---|
| FreeType, HarfBuzz (+ subset), fontconfig | `build/macos/build-deps.sh` las compila en `~/dev/macdeps/prefix/lib` |
| ICU | `/usr/lib/libicucore.dylib`, la del sistema (sus funciones no llevan sufijo de versión) |

`RpLoadDarwinLibrary` (`rtl_fpc/rpdarwinlibs.pas`) busca cada `.dylib` en este
orden: `Contents/Frameworks` del `.app`, junto al ejecutable, la búsqueda de
dyld (`DYLD_LIBRARY_PATH`, `/usr/local/lib`) y los prefijos de Homebrew
(`/opt/homebrew/lib`) y MacPorts (`/opt/local/lib`). Si no hay fontconfig, el
motor recorre las carpetas de fuentes de macOS.

## Bases de datos

Los dos drivers directos del motor FPC funcionan en macOS:

- **FireDAC / SQLdb**: PostgreSQL, MySQL o MariaDB, Firebird, SQLite y ODBC.
  No hay MSSQL, porque FPC no compila `mssqlconn` para macOS; a SQL Server se
  llega por ODBC con el driver de FreeTDS.
- **Zeos**: los mismos protocolos.

`tests/fpc/SqldbDriversTest/run_macos.sh` los prueba contra PostgreSQL 16,
MySQL 8.0 y Firebird 5. Los servidores corren en la carpeta del usuario, sin
`sudo`, y el script los descarga la primera vez. También prueba SQLite, con
la librería del sistema, y lo hace con los dos drivers: 96 comprobaciones.

Una aplicación abierta desde Finder no recibe `DYLD_LIBRARY_PATH`, así que el
motor busca la librería cliente de cada servidor (`rtl_fpc/rpdarwinlibs.pas`)
en este orden:

1. La de la conexión: `VendorLib` (FireDAC / SQLdb) o `LibraryLocation` (Zeos),
   con la ruta completa del `.dylib`.
2. La búsqueda de dyld (`~/lib`, `/usr/local/lib`, `/usr/lib`).
3. Las carpetas de los instaladores habituales:

| Servidor | Dónde |
|---|---|
| PostgreSQL | Homebrew (`libpq`, `postgresql@N`), Postgres.app, EnterpriseDB (`/Library/PostgreSQL/N`), MacPorts |
| MySQL | el paquete de MySQL (`/usr/local/mysql`), Homebrew (`mysql-client`, `mysql`), MacPorts |
| MariaDB | Homebrew (`mariadb-connector-c`) |
| Firebird | el paquete de Firebird (`/Library/Frameworks/Firebird.framework`) |
| ODBC | unixODBC de Homebrew o MacPorts, y el iODBC de macOS |
| SQLite | la de macOS |

No uses `DYLD_LIBRARY_PATH` con la carpeta `lib` de un servidor. Esas carpetas
traen su propia `libiconv`, `libssl`… que tapan las del sistema y rompen otras
librerías. Para probar desde la terminal, `DYLD_FALLBACK_LIBRARY_PATH` (con
`/usr/local/lib:/usr/lib` al final) no tiene ese problema.

## Notas del port

- **`LINUX` en Darwin.** En las unidades raíz, `LINUX` significa «el camino del
  motor fuera de Windows» (FreeType en vez de GDI). `rpconf.inc` lo define
  también para FPC en Darwin; lo que de verdad cambia en macOS (nombres de
  librería, flags de sockets) va bajo `DARWIN`. Delphi no ve nada de esto.
- **SQLdb sin MSSQL.** FPC no compila `mssqlconn` para macOS: la familia
  FireDAC / SQLdb no ofrece MSSQL (con ODBC y el driver ODBC de FreeTDS se
  llega a SQL Server). Las librerías cliente se buscan con nombres `.dylib`.
- **Combos que se colocan a mano.** En Cocoa, un `TComboBox` `csDropDownList`
  tiene ancho preferido (el de su contenido) y `AutoSize` lo impone. Si un
  `Resize` vuelve a fijar el ancho, la LCL entra en bucle (`ChangeBounds loop
  detected`). Los combos que se colocan en código van anclados a izquierda y
  derecha: así su ancho es fijo y `AutoSize` solo ajusta la altura.
- **Parche de la LCL Cocoa**
  (`build/macos/patches/lazarus-cocoa-adjustsizer.patch`). El ajustador
  asíncrono de las barras de desplazamiento guarda el último control sin
  enterarse de si se libera. Si un formulario se destruye justo después de un
  cambio de maquetación, la siguiente vuelta del bucle de eventos usa memoria
  liberada. Solo pasa con barras de desplazamiento clásicas (con ratón, o
  «Mostrar barras de desplazamiento: siempre»). El fallo sigue en la rama
  principal de Lazarus.
- **Ficheros MyBase junto al informe.** Un fichero MyBase con nombre relativo
  (`biolife.cds` de `sample4`, con la conexión sin `DATABASE`) se busca también
  en la carpeta del informe abierto en el diseñador (`RpReportFolder`). En
  Windows el Explorador y el diálogo Abrir dejan esa carpeta como directorio
  actual. En macOS la aplicación arranca en `/`.
- **El informe sin nombre.** El formulario del diseñador LCL no tiene nombre
  (`CreateNew`). Mientras existe, el `TReader` de FPC daba al informe que se
  cargaba el nombre `_1`: se guardaba como `object _1: TRpReport` y dos copias
  con el mismo propietario chocaban («Duplicate name»). `LoadFromStream` quita
  ese nombre automático, también de los informes que ya se guardaron así.
  Pasaba con el diseñador LCL en todas las plataformas.
- **Contextos gráficos.** Con Cocoa, cada `TBitmap` con canvas crea contextos
  gráficos que esperan en el *autorelease pool* hasta la siguiente vuelta del
  bucle de eventos, y liberar muchos de golpe cuesta tiempo cuadrático. No hay
  que crear un bitmap por cada medida de texto en las rutinas de maquetación.

## Pendiente

- Empaquetar el `.app` para distribuir. Los `.dylib` irían en
  `Contents/Frameworks`, con `install_name_tool` para que se encuentren entre
  sí (`@loader_path`). La configuración de fontconfig también tendría que ir
  dentro, y el diseñador tendría que fijar `FONTCONFIG_FILE` al arrancar,
  porque `build-deps.sh` deja en la librería la ruta de `~/dev/macdeps`.
  Faltan además `Info.plist`, el icono y, para Gatekeeper, la firma y la
  notarización.
- Apple Silicon (arm64): no probado. El FPC 3.2.2 del `.dmg` ya incluye el
  compilador `ppca64`.
- La impresión (Printer4Lazarus con Cocoa) no está probada todavía.

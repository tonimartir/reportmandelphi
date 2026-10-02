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
tests/fpc/LclDesignerTest/LclDesignerTest --selftest
```

Se ejecuta el binario, no el `.app`: el test busca los ejemplos
(`repman/repsamples`) relativos al ejecutable. Hace falta una sesión gráfica
abierta con el mismo usuario (sirve lanzarlo por SSH). `selftest.log` se
escribe en modo añadir: hay que leer solo la última ejecución.

Pasan en macOS 11 (Intel), sin variables `DYLD_*` (las librerías de
`build-deps.sh` están enlazadas en `~/lib`):

| Test | Resultado |
|---|---|
| `LclDesignerTest --selftest` | completo |
| `LclSnapshotTest` (vista previa LCL contra el PDF) | 18 de 18 (sin la prueba de la impresión Cairo, que es de Linux) |
| `LclAIChatTest` (paneles de IA contra un Hub falso) | 1312 comprobaciones, sin fugas de memoria |
| `HubClientTest` (cliente HTTP, Hub y login OAuth) | 497 comprobaciones; las de TLS local necesitan un `openssl` 1.1.1+ (`RP_OPENSSL_EXE`) |
| `SqldbDriversTest/run_macos.sh` | 96 comprobaciones |
| `PdfTest` | completo (con las pruebas de codificación del PDF y de los campos FMTBcd) |
| `examples/lazarus` | los tres ejemplos y los dos informes de `postgresql` |

Los tests con HTTPS necesitan OpenSSL 3 (ver más abajo); para no instalarlo,
`RP_OPENSSL_DIR` puede apuntar a una carpeta con `libssl.3.dylib` y
`libcrypto.3.dylib`.

## Librerías del motor

Fuera de Windows el motor mide y da forma al texto con FreeType, HarfBuzz,
fontconfig e ICU, que se cargan al usarse (no hacen falta para compilar):

| Librería | En macOS |
|---|---|
| FreeType, HarfBuzz (+ subset), fontconfig | `brew install fontconfig harfbuzz`, o `build/macos/build-deps.sh`, que las compila en `~/dev/macdeps/prefix/lib` y las enlaza en `~/lib` |
| ICU | `/usr/lib/libicucore.dylib`, la del sistema (sus funciones no llevan sufijo de versión) |
| OpenSSL 3 (HTTPS: IA, agente, login) | `brew install openssl@3`, o `build-deps.sh` (OpenSSL 3.5.9, también enlazada en `~/lib`); el paquete la lleva en `Contents/Frameworks` |

`RpLoadDarwinLibrary` (`rtl_fpc/rpdarwinlibs.pas`) busca cada `.dylib` en este
orden: `Contents/Frameworks` del `.app`, junto al ejecutable, la búsqueda de
dyld (`DYLD_LIBRARY_PATH`, `~/lib`, `/usr/local/lib`) y los prefijos de
Homebrew (`/opt/homebrew/lib`) y MacPorts (`/opt/local/lib`). Si no hay
fontconfig, el motor recorre las carpetas de fuentes de macOS.

**OpenSSL.** El `openssl.pas` de FPC 3.2.2 no conoce OpenSSL 3 y en macOS
acaba cargando el OpenSSL 0.9.8 que el sistema conserva por compatibilidad,
sin las funciones para verificar certificados. `RpPrepareOpenSSL`
(`rtl_fpc/rphttpclientfpc.pas`) solo carga un OpenSSL 3 o 1.1, buscado por
`RpDarwinOpenSSL` en `RpOpenSSLFolder` (lo fija la aplicación),
`RP_OPENSSL_DIR`, `Contents/Frameworks`, junto al ejecutable, `~/lib`,
Homebrew (`openssl@3`, `openssl@1.1`) y MacPorts. Si no lo encuentra, el
error lo dice. Los certificados raíz son los de `/etc/ssl/cert.pem`.

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

`examples/lazarus/postgresql` es el ejemplo con base de datos: `createdb.sh`
crea el usuario y la base `rpsample` en un PostgreSQL (Homebrew,
Postgres.app...) y `pgreport` imprime a PDF `sales_sqldb.rep` (FireDAC, que
FPC abre con SQLdb) y `sales_zeos.rep` (Zeos). Sus conexiones están en el
`dbxconnections.ini` de la carpeta; el diseñador lee las del usuario:
`~/.borland/dbxconnections` si existe (la ubicación histórica, la de los
paquetes de Linux y el servidor web) y si no `~/.dbxconnections`, que es lo
normal en un Mac. Antes `TRpConnAdmin.LoadConfig` solo usaba la de
`~/.borland` si también existía `~/.borland/dbxdrivers`; ahora cada fichero
se busca por separado (fuera de Windows, también en Delphi Linux).

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
- **Parches de la LCL Cocoa** (`build/macos/patches`, los aplica
  `setup-toolchain.sh`; los dos fallos siguen en la rama principal de
  Lazarus):
  - `lazarus-cocoa-adjustsizer.patch`. El ajustador asíncrono de las barras
    de desplazamiento guarda el último control sin enterarse de si se libera.
    Si un formulario se destruye justo después de un cambio de maquetación,
    la siguiente vuelta del bucle de eventos usa memoria liberada. Solo pasa
    con barras de desplazamiento clásicas (con ratón, o «Mostrar barras de
    desplazamiento: siempre»).
  - `lazarus-cocoa-setlclfont-leak.patch`. `setLCLFont` copia la fuente del
    control y no libera la copia: se pierde un `TFont` por cada fila visible
    de cada `TListBox`.
- **Texto rotado en la vista previa.** `rplcldriver` guardaba el handle de la
  fuente antes de cambiar `Orientation` y lo restauraba después, pero el
  `TFont` de la LCL ya lo había liberado. Cocoa fallaba con el handle
  liberado; ahora se restaura la orientación.
- **SIGPIPE.** macOS no tiene `MSG_NOSIGNAL`: los sockets planos (peticiones
  HTTP, el servidor local del login) también lanzan `SIGPIPE` si el otro lado
  ha cerrado. `rphttpclientfpc` lo ignora al iniciarse en Darwin, salvo que
  la aplicación tenga su propio manejador. El navegador del login se abre con
  `/usr/bin/open`.
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
- **Acentos con las fuentes estándar del PDF.** Helvetica, Courier y Times
  van con `WinAnsiEncoding` (Windows-1252). `PDFCompatibleText` añadía cada
  `WideChar` a un `string`, y en FPC fuera de Windows ese `string` es UTF-8: la
  «é» se escribía con sus dos bytes UTF-8 y el lector mostraba «Ã©». Ahora
  `WinAnsiChar` da el byte de Windows-1252. Pasaba también en Linux con FPC.
- **Campos FMTBcd.** Zeos da un `numeric` sin precisión (`cantidad * precio`)
  como `TFMTBCDField`. FPC no sabe sumar su variante FMTBcd a un entero, y los
  totales, que empiezan en 0, fallaban con «Invalid variant operation».
  `TIdenField` la convierte a `Double`, como hace Delphi con `USEBCD`.
- **Idioma.** El motor (`rptranslator`), la LCL (`gettext`) y el idioma de la
  IA leen `LC_ALL`, `LC_MESSAGES` y `LANG`, y macOS no da `LANG` a las
  aplicaciones abiertas desde Finder (Terminal sí): el diseñador salía en
  inglés con el Mac en español. Sin esas variables se usa
  `RpDarwinUserLanguage`, el primer idioma de Preferencias del Sistema (con el
  país de la región si no lo lleva), leído de CoreFoundation.
- **Ficheros junto al ejecutable.** Lazarus deja el ejecutable en la carpeta
  del proyecto y lo enlaza desde `X.app/Contents/MacOS`; `ParamStr(0)` es ese
  enlace. `RpDarwinDataDirs` da `Contents/Resources` y la carpeta del
  ejecutable real, y ahí buscan `rptranslator` (`reportmanres.*`) y el
  diseñador (ejemplos y `languages/lclstrconsts.*.po`, que
  `build/macos/build-designer.sh` copia en `Contents/Resources`).
- **Contextos gráficos.** Con Cocoa, cada `TBitmap` con canvas crea contextos
  gráficos que esperan en el *autorelease pool* hasta la siguiente vuelta del
  bucle de eventos, y liberar muchos de golpe cuesta tiempo cuadrático. No hay
  que crear un bitmap por cada medida de texto en las rutinas de maquetación.

## Paquete de instalación

`build/macos/make-package.sh` compila el diseñador en modo Release y monta
`build/macos/out/<versión>/Report Manager Designer.app` y su `.dmg`:

- `Contents/MacOS/repmandesigner_lcl`: el ejecutable copiado (el `.app` de
  desarrollo solo tiene un enlace a `repman/`).
- `Contents/Frameworks`: las cuatro `.dylib` de `build-deps.sh`, con
  `install_name_tool` para que se nombren entre sí por `@loader_path`. El
  script falla si alguna sigue apuntando a `~/dev/macdeps`.
- `Contents/Resources/fonts`: el `fonts.conf` de `build-deps.sh` y su
  `conf.d`, con la caché en `~/Library/Caches/es.reportman.designer`. Ese
  fontconfig busca su configuración en la carpeta donde se compiló; antes de
  cargarlo, `RpDarwinPrepareFontconfig` fija `FONTCONFIG_PATH` (con el
  `setenv` de la libc, que es la que lee fontconfig) si la aplicación trae
  `fonts.conf` y el usuario no ha fijado `FONTCONFIG_FILE` ni
  `FONTCONFIG_PATH`.
- `Contents/Frameworks` también lleva OpenSSL 3.5 (`libssl.3.dylib`,
  `libcrypto.3.dylib`): sin él no hay HTTPS, y el login y los asistentes de
  IA fallaban en un Mac sin Homebrew. `RpDarwinOpenSSL` lo busca ahí antes
  que en ningún otro sitio; los certificados raíz son los de macOS
  (`/etc/ssl/cert.pem`). `Contents/Resources/licenses` lleva las licencias de
  las librerías de dentro.
- `Contents/Resources`: `reportmanres.*`, `languages/lclstrconsts.*.po`, los
  ejemplos en `samples/` (sin los PDF) y el icono, hecho de `doc/icon-512.png`.
- `Info.plist`: `LSMinimumSystemVersion` es la mayor versión mínima que
  piden el ejecutable y las librerías según `otool` (hoy 10.15, la de
  `MACOSX_DEPLOYMENT_TARGET` en `build-deps.sh`; el ejecutable de FPC pide
  10.8), para que un macOS más antiguo diga que no se puede abrir en vez de
  fallar al cargar FreeType. Y el tipo `.rep` (`UTExportedTypeDeclarations`,
  `es.reportman.designer.rep`) con la aplicación como editor
  (`CFBundleDocumentTypes`).
- Firma ad hoc (`codesign -s -`) y `.dmg` comprimido con un enlace a
  Aplicaciones.

**OpenSSL en las aplicaciones de los usuarios de Lazarus.** Los paquetes no
llevan binarios. Para distribuir una aplicación a Macs sin Homebrew,
`build/macos/bundle-openssl.sh MiApp.app [carpeta]` copia `libssl.3.dylib` y
`libcrypto.3.dylib` (de `build-deps.sh`, Homebrew o MacPorts) en
`Contents/Frameworks`, las enlaza entre sí con `@loader_path`, comprueba que
son de la arquitectura del ejecutable, copia la licencia y vuelve a firmar
(ad hoc o con `RM_CODESIGN_IDENTITY`).

**Abrir `.rep` desde Finder.** Doble clic, soltar en el icono o «Abrir con»
llegan como `application:openURLs:`; LCL Cocoa guarda los ficheros hasta que
la aplicación corre y los entrega a `Application.OnDropFiles`.
`repmandesigner_lcl.lpr` (solo en Darwin) abre el primer `.rep` con
`OpenReportFile`, que antes pregunta si hay cambios sin guardar. Probado con
`open informe.rep` sin `-a` (lo que hace el doble clic) con el diseñador
cerrado (arranca con ese informe) y abierto (lo abre en la misma instancia).

Probado en macOS 11 con `~/lib` y `~/dev/macdeps` renombrados: instalado
desde el `.dmg` en `~/Applications`, las cuatro librerías se cargan de
`Contents/Frameworks` (`DYLD_PRINT_LIBRARIES`), fontconfig lee el
`fonts.conf` de la aplicación (`FC_DEBUG=1024`), `sample4` sale a PDF y en
la vista previa LCL con los datos de `biolife.cds`, los textos en español, y
la aplicación abierta con `open` muestra su ventana.

## Pendiente

- Firmar el paquete con un certificado Developer ID y notarizarlo (cuenta
  de desarrollador de Apple), para que Gatekeeper lo abra sin «clic
  derecho > Abrir».
- Apple Silicon (arm64): no probado. El FPC 3.2.2 del `.dmg` ya incluye el
  compilador `ppca64`.
- La impresión (Printer4Lazarus con Cocoa) no está probada todavía.

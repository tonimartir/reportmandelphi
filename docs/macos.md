# Report Manager Designer en macOS (LCL Cocoa)

El diseñador LCL (el mismo de Linux) compila en macOS con el widgetset nativo
**Cocoa** y pasa `LclDesignerTest --selftest` completo, con FPC 3.2.2 y
Lazarus 4.8. Probado a mano en macOS 11 Big Sur (Intel, x86_64) y, con
[GitHub Actions](#github-actions-intel-y-apple-silicon), en macOS 15 Intel y
Apple Silicon (arm64). El [paquete de instalación](#paquete-de-instalación) es
un `.dmg` con la aplicación firmada ad hoc; el universal lleva las dos
arquitecturas.

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
- Los dos scripts usan la arquitectura del Mac (`uname -m`). En Apple
  Silicon, `setup-toolchain.sh` baja el zip de Lazarus para aarch64 (el
  `.dmg` de FPC es el mismo: trae `ppcx64` y `ppca64`), y `build-deps.sh`
  compila las librerías arm64 con macOS 11.0 como mínimo (10.15 en Intel).
- Se pueden volver a ejecutar: solo descargan, instalan o compilan lo que
  falta o lo que ha cambiado (`~/dev/lazarus/.rm-build`,
  `~/dev/macdeps/prefix/.rm-build`).
- **FPC 3.2.2 con Xcode 15 o posterior.** FPC 3.2.2 está pensado para macOS
  hasta la versión 11, y con las herramientas actuales de Apple tiene dos
  fallos (Lazarus 4.8 para macOS se publica con FPC 3.2.4rc1 por esto).
  `setup-toolchain.sh` los detecta y los resuelve al final de `fpc.cfg`,
  entre marcas; en un Mac con herramientas antiguas (las Command Line Tools
  12 de macOS 11) no añade nada:
  - En Intel, FPC escribe las etiquetas de los `goto` que salen de un bloque
    (Zeos, `ZDbcResultSet`) como símbolos globales dentro de la función, y el
    ensamblador de clang 15 o posterior las rechaza («non-private labels
    cannot appear between .cfi_startproc / .cfi_endproc pairs»). En x86_64,
    `fpc.cfg` usa `~/dev/fpc/asfix`: un `clang` que las vuelve privadas
    (prefijo `L`, sin `.globl`) antes de ensamblar; solo se usan dentro de
    su unidad, el código es el mismo. Las demás herramientas son enlaces a
    las de verdad. `RM_MACOS_ASFIX=1` lo pone aunque no haga falta.
  - El enlazador nuevo (ld-prime) se cae (*segmentation fault*) al enlazar
    los ejecutables de FPC 3.2.2: `fpc.cfg` añade `-k-ld_classic`. Xcode 16
    aún lo tiene, pero Apple lo da por obsoleto: cuando lo quite habrá que
    pasar a FPC 3.2.4 (ver [Pendiente](#pendiente)).

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
`build-deps.sh` están enlazadas en `~/lib`). El
[workflow de GitHub Actions](#github-actions-intel-y-apple-silicon) pasa
además la selftest, `PdfTest` y el paquete de OPM en macOS 15, Intel y Apple
Silicon:

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

## GitHub Actions (Intel y Apple Silicon)

La VirtualBox no puede ejecutar arm64; GitHub Actions sí, gratis en un
repositorio público. `.github/workflows/macos.yml` **solo se lanza a mano**
(nunca en cada push) y no publica nada: el `.dmg` queda como artefacto de la
ejecución (30 días). Desde la web, *Actions > macOS > Run workflow*; o con
`gh`:

```sh
gh workflow run macos.yml --repo tonimartir/reportmandelphi
gh run watch --repo tonimartir/reportmandelphi
gh run download <id> --repo tonimartir/reportmandelphi -n reportman-designer-macos-universal
```

La casilla «Compilar desde cero» (`-f sin_cache=true`) no usa la caché.
Trabajos:

1. **build**, en `macos-15` (Apple Silicon M1) y `macos-15-intel`:
   `setup-toolchain.sh` y `build-deps.sh` (con `~/dev` en la caché de
   Actions, una por arquitectura y por el contenido de los scripts y los
   parches, sin las descargas), `build_fpc.sh`, `LclDesignerTest --selftest`
   (los runners tienen sesión gráfica), `PdfTest`,
   `build/macos/opm-check.sh` y `make-package.sh`. El `.app` de cada
   arquitectura se sube como artefacto (en un `.tar.gz`, que conserva
   permisos y firma).
2. **universal**, en `macos-15`: `build/macos/make-universal.sh` une los dos
   `.app` con `lipo` (el ejecutable y cada `.dylib`; el resto tiene que ser
   idéntico), comprueba que todos los Mach-O tienen x86_64 y arm64, firma ad
   hoc y crea `reportman-designer-<versión>-macos-universal.dmg` y su
   `SHA256SUMS` (la salida de `lipo` queda en el resumen de la ejecución).
3. **smoke**, en los dos Mac: monta el `.dmg` y ejecuta el diseñador de
   dentro: `--version`; `--check-https` contra `aiapi.reportman.es` con
   `DYLD_PRINT_LIBRARIES` (falla si `libssl` y `libcrypto` no salen de
   `Contents/Frameworks`); y abre `sample4.rep`, comprueba a los 25 s que
   sigue vivo y que el proceso es de la arquitectura del Mac (`vmmap`:
   `ARM64` o `X86-64`).

El diseñador no tiene `--selftest` (es del proyecto `LclDesignerTest`): el
`.dmg` se prueba con esas tres cosas. `opm-check.sh` es la validación de
`make_opm_package.ps1 -Validate` para macOS: extrae de `git archive HEAD`
solo los ficheros de `build/opm/opm_files.txt`, registra Zeos y los tres
paquetes en una `--pcp` vacía, los compila con `-B`, compila los cuatro
ejemplos y ejecuta `pdfconsole`, que escribe `sales.pdf`.

Tiempos (03-10-2026): con la caché, 13 minutos (build x86_64 11 min 31 s,
arm64 4 min 52 s; el `.dmg` y sus pruebas, 2 minutos); sin ella, 20 minutos
(x86_64 17 min 46 s, de ellos 5 de herramientas y 7 de librerías; arm64
10 min 53 s). El `.dmg` universal de esa ejecución también pasa en macOS 11
Intel (la VirtualBox, con `~/lib` escondido): firma, `--check-https` con el
OpenSSL de `Contents/Frameworks` y `sample4.rep` abierto como X86-64.

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

- **Apple Silicon.** `rpfreetype2` declaraba `FT_Long`, `FT_Fixed` y `FT_Pos`
  (el `long` de C, de 64 bits en los Unix de 64 bits) de 64 bits solo con
  `CPUX64`, que FPC no define en aarch64: `FT_FaceRec` se leía desplazado.
  Ahora también con FPC en aarch64.
- **Excepciones de coma flotante.** HarfBuzz calcula con valores intermedios
  NaN con algunas fuentes (las variables del sistema de macOS 15). C lo
  ignora, pero los programas de consola de FPC tienen las excepciones de coma
  flotante activadas (la LCL las enmascara): `CalcGlyphPositions` llama a
  HarfBuzz con ellas enmascaradas y restaura la máscara del programa.

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
`build/macos/out/<versión>/Report Manager Designer.app` y su `.dmg`
(`reportman-designer-<versión>-macos-x86_64.dmg` o `-arm64.dmg`, la
arquitectura del Mac que lo compila). `build/macos/make-universal.sh
<app x86_64> <app arm64>` une los dos en el `.dmg` universal (lo hace el
workflow de Actions):

- `Contents/MacOS/repmandesigner_lcl`: el ejecutable copiado (el `.app` de
  desarrollo solo tiene un enlace a `repman/`).
- `Contents/Frameworks`: las `.dylib` de `build-deps.sh`, con
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
  (`CFBundleDocumentTypes`). En la universal, `LSMinimumSystemVersion` es la
  de Intel y `LSMinimumSystemVersionByArchitecture` da 10.15 a x86_64 y 11.0
  a arm64 (no hay Mac con Apple Silicon anterior a macOS 11).
- Firma ad hoc (`codesign -s -`) y `.dmg` comprimido con un enlace a
  Aplicaciones.

**OpenSSL en las aplicaciones de los usuarios de Lazarus.** Los paquetes no
llevan binarios. Para distribuir una aplicación a Macs sin Homebrew,
`build/macos/bundle-openssl.sh MiApp.app [carpeta]` copia `libssl.3.dylib` y
`libcrypto.3.dylib` (de `build-deps.sh`, Homebrew o MacPorts) en
`Contents/Frameworks`, las enlaza entre sí con `@loader_path`, comprueba que
son de la arquitectura del ejecutable, copia la licencia y vuelve a firmar
(ad hoc o con `RM_CODESIGN_IDENTITY`). Para una aplicación universal se le
dan dos carpetas, una de cada arquitectura, y las une con `lipo`.

**`--check-https [url]`.** El diseñador conecta como el login y los
asistentes de IA (certificado verificado), dice qué OpenSSL ha cargado y
sale con 0 si el servidor responde. Sirve para comprobar el paquete sin
abrir la interfaz y para diagnosticar un «el login no funciona».

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

Con OpenSSL dentro (02-10-2026, con `~/lib` escondido): HTTPS a
`api.reportman.es` desde la aplicación instalada usa el `libssl` de
`Contents/Frameworks` y rechaza un certificado caducado; Toni comprobó en la
VM el inicio de sesión de IA y el copilot completo.

**Publicarlo en SourceForge.** El `.dmg` y su `SHA256SUMS` van en
`Report Manager Designer/Designer 4.0/macOS`, como la carpeta `Linux`. Desde
el 03-10-2026 está el universal (`reportman-designer-4.0.17-macos-universal.dmg`,
de la ejecución 37083747716 de Actions, probado también instalado en la
VirtualBox con macOS 11); el 4.0.16 solo Intel pasó a la subcarpeta
`macOS/4.0.16` con su `SHA256SUMS`.
Sustituir el fichero por SFTP le quita las propiedades: hay que volver a
marcar «Default Download For: Mac» en su ficha (Files, botón *i*), o los Mac
reciben el instalador de Windows. Se comprueba con
`https://sourceforge.net/projects/reportman/best_release.json`.

## Pendiente

- Firmar el paquete con un certificado Developer ID y notarizarlo (cuenta
  de desarrollador de Apple), para que Gatekeeper lo abra sin «clic
  derecho > Abrir».
- Probar el `.dmg` universal a mano en un Mac con Apple Silicon (en Actions
  pasan la selftest y las pruebas del `.dmg`, pero nadie lo ha usado).
- FPC 3.2.2 depende de `-ld_classic`, que Apple da por obsoleto: cuando un
  Xcode lo quite, pasar a FPC 3.2.4 en macOS (o al 3.2.4rc1 con el que se
  publica Lazarus 4.8 para macOS).
- La impresión (Printer4Lazarus con Cocoa) no está probada todavía.
- Los tooltips no aparecen en LCL Cocoa (Lazarus 4.8), en ningún control:
  la LCL nunca llega a pedirlos (`Application.OnShowHint` no se llama).
  `TLCLCommonCallback.MouseMove` avisa de la entrada del usuario con
  `_KeyMsg.Msg` en vez de `LM_MOUSEMOVE` (corregido en la rama principal de
  Lazarus), pero arreglar solo eso no basta. Se deja hasta subir de
  versión de Lazarus.

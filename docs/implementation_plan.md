# Port de Report Manager a Free Pascal / Lazarus: plan y estado

Este documento sustituye al plan de trabajo original de Gemini Flash 3.8, que
solo describía la subfase 4.3. Reúne todas las fases del port con su estado
real a 27-09-2026 y corrige lo que aquel plan daba por hecho y no se cumplía.
El detalle de la Fase 6 (ejecutable, instalador Linux, Docker, release) está
en `docs/fase6_plan.md`; la guía de usuario, en `docs/linux-install.md`, y el
paquete del Online Package Manager de Lazarus, en `docs/opm.md`.

Autoría: fases 1 a 5.4 por Gemini Flash 3.8 (18 a 27-09-2026); la subfase 5.5
de estabilización y la Fase 6, por Claude.

## Objetivo

- Motor de informes compilable con FPC 3.2.2 en Windows y Linux, con salida
  PDF/SVG/PNG/texto y el mismo resultado que la versión Delphi.
- Vista previa y diseñador LCL (Lazarus 4.x; Linux con Qt6, y GTK2 como
  paquete de transición) equivalentes al diseñador VCL de Delphi.
- Todo ello **sin cambiar el producto Delphi**, que comparte las unidades del
  motor.

## Reglas (no negociables)

1. **Unidades compartidas.** Las unidades `rp*.pas` de la raíz son también el
   producto Delphi. Delphi solo puede ver arreglos de bugs genuinos (que se
   corrigen en código común, para los dos compiladores); todo lo demás del port
   va dentro de `{$IFDEF FPC}`. Se verifica comparando el código tal como lo ve
   Delphi (con los bloques FPC eliminados) antes y después de cada cambio.
2. Trampas que la compilación Win32/Win64 de Delphi no detecta:
   - `{$DEFINE}` globales en `rpconf.inc` (por ejemplo `USEZEOS` solo para FPC);
   - unidades de FPC en el `{$ELSE}` de `{$IFDEF MSWINDOWS}` (rompen Delphi
     Linux64);
   - BOM UTF-8: los proyectos Delphi no fijan la página de códigos, así que un
     fichero sin BOM se lee como cp1252, y FPC trata un BOM como
     `{$codepage utf8}`. No añadir ni quitar BOM.
   - Varias unidades mezclan Latin-1 y UTF-8 en comentarios: editar sin
     reescribir esos bytes.
3. Código solo FPC: `rtl_fpc/`, `lcl/`, `design_lcl/`, `packages/fpc*`,
   `tests/fpc/`, `repman/lcl_designer/`, `build/linux/`, `build/opm/`.
4. Nada de rutas de desarrollador en paquetes, proyectos ni código.
5. Cada cambio se verifica en: grupo Delphi Win32/Win64 + Linux64 +
   paquetes 13.0; paquetes FPC en Windows y Linux; `LclDesignerTest
   --selftest`, `LclSnapshotTest` y `PdfTest` en los dos sistemas.

## Paquetes y compilación

| Paquete | Contenido |
|---|---|
| `packages/fpc/reportman_rtl.lpk` | Motor: unidades de la raíz + `rtl_fpc/`; requiere Zeos (`zcomponent`) |
| `packages/fpc_lcl/reportman_lcl.lpk` | Runtime LCL: vista previa, driver LCL, diálogo de parámetros (`lcl/`) |
| `packages/fpc_lcl/reportman_designlcl.lpk` | Diseñador LCL, Monaco/WebView2 en Windows (`design_lcl/`) |

Los tres son `RunAndDesignTime` y compilan en una sola pasada, igual que desde
el IDE o el OPM:

```bat
packages\fpc\build_fpc.bat            (Linux: packages/fpc/build_fpc.sh)
C:\lazarus\lazbuild.exe --ws=win32 --no-write-project tests\fpc\LclDesignerTest\LclDesignerTest.lpi
tests\fpc\LclDesignerTest\LclDesignerTest.exe --selftest
```

## Fases

| Fase | Contenido | Commits | Estado |
|---|---|---|---|
| 1 | Paquete del motor para FPC; texto complejo (DirectWrite en Windows, FreeType/HarfBuzz en Linux); datos MyBase/MIDAS XML con `TBufDataset`; SQLite vía la abstracción FireDAC; paquete `reportman_lcl` y vista previa; exportar a PDF/A-3 y PNG | 3e03a06 … cb66d67 | Hecha |
| 2 | Marco del diseñador visual LCL, carpetas `rtl_fpc`/`lcl`/`design_lcl`, selección, tiradores y reglas | 6ae4ff3 … 961fa31 | Hecha |
| 3.1–3.5 | Inspector de objetos; paleta y herramientas; árbol de estructura y explorador de datos; configuración de datos y secciones; configurar página, vista previa, editor SQL Monaco; `TFRpMainFLCL` reutilizable y `TRpDesignerLCL.Execute`; registro de componentes en la paleta de Lazarus | c6baddd … d288b33 | Hecha |
| 4.1–4.3 | Diálogos: editor de expresiones, rejilla, acerca de; asistente de informes, selección de campos, secciones externas; parámetros, búsqueda de valores y librería de informes en base de datos | 81c911d … 0d10358 | Hecha (4.3 completada en 5.5) |
| 5.1–5.4 | Deshacer/rehacer: motor (`rpmdundocuelcl`), panel de historial, instrumentación de acciones, atajos y estado modificado | a2a6684 … b725f80 | Hecha (corregida en 5.5) |
| 5.5 | Estabilización: aislamiento de Delphi, infraestructura, sin pérdida de datos, undo fiable, tests de regresión reales, bugs comunes corregidos también en Delphi | a7c6c89 … 1014d29 | Hecha |
| — | Compilación en una sola pasada (CRC de `rpsection`), zip OPM, Base64 binario seguro en FPC, paridad del inspector con la VCL, vista previa Linux con Cairo/FreeType igual que el PDF | 57961c6 … cc8e917 | Hecha |
| 6 | Diseñador autónomo, `.deb` + AppImage construidos en Docker, pruebas en máquinas limpias, enganche al release de SourceForge | 07bfa5a … b3ea54b | Hecha salvo pruebas manuales y subida (ver `fase6_plan.md`) |

### Subfase 5.5: qué se corrigió

- **P0, aislamiento de Delphi** (a7c6c89): todo el trabajo del port quedó bajo
  `{$IFDEF FPC}`; Delphi compila de nuevo exactamente el código anterior al
  port salvo arreglos genuinos (claves PDF `/CIDToGIDMap` y `/Length1`, fuga de
  anotaciones, lecturas fuera de rango en `rpinfoprovid`/`rpHarfBuzz`, mensaje
  de FireDAC). `USEZEOS` solo para FPC; `dynlibs` solo en FPC (rompía Delphi
  Linux64); BOM restaurados.
- **P3, infraestructura** (d98e24b): fuera los paquetes duplicados de la raíz y
  `packagefiles.xml` con rutas absolutas; `build_fpc.bat/.sh`; tests que usan
  los paquetes sin rutas al motor.
- **P1/P2, diseñador** (33c8b25, 5b4a150): abrir un informe no deja uno a
  medias; todos los diálogos registran deshacer o marcan el informe como
  modificado; configuración de datos sobre copias (Cancelar funciona);
  deshacer consistente ante fallos, orden Z, inspector con valores del modelo;
  deshacer el borrado de parámetros/conexiones/datasets ya no los recrea
  vacíos (el mismo fallo estaba en la VCL y se corrigió también en Delphi).
- Bugs comunes corregidos en Delphi al mismo tiempo (41391af, 1014d29): deshacer
  en la VCL, color de fondo por defecto del metafile, reserva de fuentes,
  expresiones de gráfico y BidiModes al deshacer un borrado.

### Correcciones al plan original de la 4.3

| El plan decía | Lo que hay |
|---|---|
| (no mencionaba las unidades compartidas) | Regla 1: el port había cambiado código que compila Delphi; se aisló en P0 |
| Pruebas "exhaustivas" en `umainform.pas` | Aquellas pruebas creaban los diálogos y comprobaban poco más (que la lista de parámetros se rellenaba, que existían los controles). Las pruebas de comportamiento están en `tests/fpc/LclDesignerTest/uregressiontests.pas` (asserts sobre el estado del modelo tras cada acción, vigilante de diálogos modales) |
| `rprflclparams.BSearchClick` llama a `ParamValueSearch` | `reportman_lcl` no puede depender del diseñador: el botón usa el gancho `GlobalParamValueSearch`, que instala `design_lcl/rpmdfsearchlcl.pas`. Sin el paquete del diseñador el botón de búsqueda no se muestra |
| `SelectReportFromLibrary` con un árbol propio | Se sustituyó por el port del árbol de la VCL (tablas `REPMAN_REPORTS`/`REPMAN_GROUPS`), con carga segura y guardado de vuelta a la librería |
| Diálogo de parámetros | Faltaban `UpdateValue` de la VCL, los errores de conversión visibles y el deshacer diferido (`deferUndoUntilAccept`) |
| Compilar solo `reportman_designlcl.lpk` | Se compilan los tres paquetes con `build_fpc.bat` (el motor también cambia) |
| Textos con IDs de `TranslateStr` | Varios IDs eran inventados; se sustituyeron por los de la VCL |

## Fase 7: diseño con IA y Hub en FPC/LCL (en curso: 7.1 hecha)

El diseñador Delphi tiene tres asistentes de IA, todos a través de
`api.reportman.es` y con los esquemas (tablas, columnas, relaciones) que el
usuario define en `app.reportman.es`:

1. **Asistente SQL con esquema**: chat que escribe y corrige las consultas de
   los datasets (`TFRpChatFrame` de `rpfrmchatvcl` en modo SQL, selector de
   esquema `rpfrmaischemaselectorvcl`) y autocompletado del editor SQL Monaco
   con el esquema (`rpfrmmonacoeditorvcl`).
2. **Asistente de expresiones**: chat dentro del editor de expresiones
   (`rpchatdialogvcl`).
3. **Asistente de diseño**: chat que crea y modifica el informe completo
   (`TFRpChatFrame` en modo diseño, `ShowAIChat` del diseñador), aplicando
   los contratos de `rpreportdesignercontracts`.

Además está el driver de datos del Agente (`rpdbHttp`, `rpdatahttp`). Antes de
7.1 nada de esto estaba en los paquetes FPC: sus unidades usan `System.JSON`,
`System.Net.HttpClient`, `System.NetEncoding`/`DateUtils`, VCL y WebView2. En
FPC solo existe el editor Monaco del diseñador LCL (WebView2, solo Windows; en
Linux cae a un `TMemo`), sin autocompletado de esquema.

| Subfase | Contenido |
|---|---|
| 7.1 Base portable (hecha) | `rpaireportcontracts`, `rpreportdesignercontracts`, `rpauthmanager` y `rpdatahttp` compilando con FPC: JSON, HTTP/TLS (`fphttpclient` + OpenSSL), codificación y fechas con equivalentes de la API de Delphi en `rtl_fpc/`, todo bajo `{$IFDEF FPC}` (Delphi sin cambios). Registro en `reportman_rtl.lpk`. Da ya valor sin diseñador: el driver del Agente (`rpdbHttp`) en Linux y en aplicaciones Lazarus. Detalle abajo |
| 7.2 Sesión y esquemas | Login (OAuth con la redirección local), selección de modelo (`rpfrmaiselectionvcl`) y selector de esquema en LCL; estilo común de los chats (`rpchatmodernstyle`). Markdown de las respuestas: WebView2 en Windows (ya hay `rpwebview2`/`rplclwebview` en LCL) y un visor HTML de Lazarus (IPro, `TIpHtmlPanel`) en Linux |
| 7.3 Asistente SQL | `TFRpChatFrame` en modo SQL dentro de la configuración de datos LCL, y autocompletado con el esquema en Monaco (Windows); en Linux, completado sobre el editor alternativo |
| 7.4 Asistente de expresiones | Port del chat de `rpchatdialogvcl` al editor de expresiones LCL (`rpexpredlglcl`) |
| 7.5 Asistente de diseño | `TFRpChatFrame` en modo diseño en el diseñador LCL; aplicar los contratos al modelo con deshacer y refresco del diseñador, igual que la VCL |
| 7.6 Pruebas | Tests de regresión de los tres asistentes con respuestas del Hub simuladas (sin red), en Windows y Linux; prueba real contra `api.reportman.es` a mano |

El chat común (`TFRpChatFrame`) se porta en 7.3 y se reutiliza en 7.5; el
orden sigue la dependencia (el esquema sirve al SQL y al diseño) y deja el
asistente más grande, el de diseño, para el final.

**La inteligencia está en el servidor** (`api.reportman.es`): el cliente solo
habla HTTP/JSON, muestra el chat y aplica lo que devuelve. En Windows la
interfaz rica es web y se reutiliza tal cual: Monaco (`MonacoEditorAssets`) y
WebMarkdown (`WebMarkdownAssets`) sobre el WebView2 que ya aloja el diseñador
LCL (`rpwebview2`, `rplclwebview`). Falta en Pascal el puente de Monaco con el
esquema y la IA (el Monaco VCL tiene ~1.300 líneas de eso; el LCL, ninguna),
alojar WebMarkdown en LCL y los marcos de chat nativos.

**Linux no tiene WebView2** (hoy el Monaco LCL cae a un `TMemo`). Opciones:
(a) nativa: SynEdit con completado por esquema en Pascal y un visor HTML de
Lazarus para el markdown; (b) Chromium embebido (CEF4Delphi, compatible con
Lazarus) para usar el mismo Monaco/WebMarkdown, a costa de ~150–200 MB por
instalación (sin comprobar con Qt6); (c) WebKit del sistema, que exige GTK3.
Plan: Windows completo primero; en Linux la opción (a), y (b) solo si hace
falta.

Tamaño aproximado: unas 9.000 líneas de interfaz VCL a portar más la capa
JSON/HTTP. Riesgos: OpenSSL en Windows con FPC (DLL a distribuir), la
redirección OAuth local, `System.Threading` (pasar a `TThread`) y el render
de markdown sin WebView2 en Linux.

### Subfase 7.1: qué se hizo

**Unidades compartidas.** `rpaireportcontracts`, `rpreportdesignercontracts`,
`rpauthmanager` y `rpdatahttp` entran en `reportman_rtl.lpk` y compilan con
FPC 3.2.2 en Windows y Linux (Lazarus 3.0 y 4.8, gtk2 y qt6). Solo cambian
los `uses` y unos pocos bloques bajo `{$IFDEF FPC}`: Delphi ve exactamente el
código anterior (comprobado con el código tal como lo ve Delphi). En
`rpauthmanager` la ventana oculta (`AllocateHWnd`) que pasa los eventos del
hilo de escucha al hilo principal se sustituye en FPC por `TThread.Queue`, y
el login OAuth (Google, Microsoft) funciona también en Linux con la
redirección local. `rpdatainfo` activa `rpdbHttp` en FPC (las conexiones
`RemoteServer` siguen siendo solo Delphi) y trae el único cambio que ve
Delphi, un bug común: si la primera consulta `rpdbHttp` de un dataset fallaba,
el dataset en memoria que crea `Open` no lo liberaba nadie.

**Equivalentes de la API de Delphi** (`rtl_fpc/`, `{$mode delphi}`), con los
mismos nombres para que las unidades compartidas solo cambien los `uses`:

| Unidad | Sustituye a | Notas |
|---|---|---|
| `rpjsonfpc` | `System.JSON` | Parser y serialización propios con las reglas de Delphi (`ToJSON`, `ToString`, `Format`, escapes, números, `TJSONBool` que devuelve `TJSONTrue`/`TJSONFalse`, propiedad `Owned`). Se compara con la salida real de Delphi (229 casos). Diferencias: no hay `GetValue<T>`/`TryGetValue<T>`/`AsType<T>` genéricos (las unidades compartidas no los usan) y un `\uD800` suelto se convierte en U+FFFD (Delphi lo guarda en UTF-16; un `string` UTF-8 no puede) |
| `rphttpclientfpc` | `System.Net.HttpClient`, `System.Net.HttpClientComponent` | `TNetHTTPClient`/`THTTPClient`/`IHTTPResponse` sobre `fphttpclient` con un manejador OpenSSL propio que verifica el certificado y el nombre del servidor (almacén del sistema en Linux; almacenes ROOT y CA de Windows; `cacert.pem` junto al ejecutable o `RpHttpCAFile`) y respeta `OnValidateServerCertificate`. `OnReceiveData` llega a medida que llegan los datos (respuestas `chunked` y de larga duración, las del chat de IA) y `Abort := True` corta la petición al momento. Diferencias: un solo tiempo de espera de E/S (`ResponseTimeout`, entre dos lecturas: no corta un stream activo; `SendTimeout` no se usa), sin proxy y sin gzip. En Unix ignora SIGPIPE si la aplicación no lo trata: OpenSSL escribe en el socket sin `MSG_NOSIGNAL` y un servidor que cierra la conexión terminaría el proceso. También `RpOpenUrlInBrowser` y `RpWaitForLoopbackRequest`, el receptor HTTP en 127.0.0.1 de la redirección OAuth |
| `rpnetencodingfpc` | `System.NetEncoding` | Base64 (líneas de 76 como Delphi), Base64String, URL y HTML |
| `rpioutilsfpc` | `System.IOUtils` | Lo que usan las unidades: `TPath`, `TFile`, `TDirectory` |
| `rpsysutilsfpc` | `TFormatSettings.Invariant`, ISO 8601 de `DateUtils` | FPC 3.2.2 no tiene `Invariant`; sus funciones ISO 8601 no leen lo mismo que las de Delphi |

**OpenSSL** (solo lo necesita el HTTPS de FPC; Delphi usa el cliente HTTP del
sistema). Se carga en tiempo de ejecución; sin ella solo fallan las
conexiones HTTPS, con una excepción que lo dice.

- Windows: `libssl-3-x64.dll` + `libcrypto-3-x64.dll` (64 bits) o
  `libssl-3.dll` + `libcrypto-3.dll` (32 bits), o las de la 1.1, junto al
  ejecutable o en el `PATH`. No están en git: una aplicación Lazarus que use
  `rpdbHttp` o el Hub debe distribuirlas. Confianza: almacenes ROOT y CA de
  Windows.
- Linux: `libssl.so.3` (o la 1.1) y los certificados de CA del sistema. El
  `.deb` depende de `libssl3 | libssl3t64` y `ca-certificates`; la AppImage
  usa las del sistema (no se incluyen, para que reciban las actualizaciones de
  seguridad).

**Pruebas** (`tests/fpc/HubClientTest`, sin red): JSON contra la salida de
Delphi (`golden/json_delphi.txt`, generada con `delphi/JsonGolden.dpr`),
propiedad y fugas; cliente HTTP contra un servidor local (streaming
`chunked`, cancelar a mitad, tiempos de espera, TLS con un certificado de
prueba, redirección OAuth); un Hub simulado para el login, `rpdbHttp` a través
de `TRpDatabaseInfoItem`, los métodos de IA (`SuggestSql`, `ExplainSql`,
`GetTableSchema`, `PreprocessSqlContext`, `ModifyReport`, `SubmitAIReport`,
`SuggestExpressionStream` con cancelación, `GetUserSchemas`,
`GetUserAgents`), respuestas 401 y OAuth con un navegador simulado. Todo con
heaptrc sin fugas, en un directorio de configuración temporal. 457
comprobaciones en Windows y 458 en Linux. `HubClientTest --smoke` hace a mano una
petición anónima real a `api.reportman.es`.

**Encontrado y sin corregir** (también en Delphi): `TRpConnAdmin.LoadConfig`
ignora `DBXConnectionsOverride` si no existe el fichero de drivers;
`TRpDatabaseHttp.GetSchemas` (no se usa) falla con un acceso a nil porque
envía un cuerpo nil; los precios de `ParseTiers` usan `StrToFloatDef` con la
configuración regional; el puerto aleatorio de la redirección OAuth puede
caer en un rango reservado de Windows; no se comprueba el parámetro `state`
de OAuth.

**Queda para 7.2 y siguientes**: interfaz LCL de login, selección de modelo y
de esquema, marcos de chat, puente Monaco–esquema; si hace falta, proxy HTTP
y, en Windows, un cliente sobre WinHTTP para no distribuir OpenSSL.

## Pendiente

- **Traducción del diseñador LCL**: menús y varios formularios tienen el texto
  fijo en español; pasar a `TranslateStr` con los IDs de la VCL (textos por
  defecto en inglés) y traducir también los textos propios de la LCL
  (`LCLStrConsts`) con los `.po` de Lazarus. El idioma ya se detecta en
  Linux (`LC_ALL`/`LC_MESSAGES`/`LANG`).
- **Widgetset de Linux** (decidido 27-09-2026; empaquetado hecho, ver
  `fase6_plan.md` 6.8, falta probarlo en un escritorio real): Qt6 pasa a
  ser el principal (`.deb` `reportman-designer` y AppImage), con
  `libQt6Pas` 6.2.10 compilada en el builder e incluida en el paquete; GTK2 se
  mantiene como `.deb` de transición (`reportman-designer-gtk2`) hasta que
  Debian 14 lo retire. Motivos, medidos: Qt6 pasa el selftest y escala solo
  en HiDPI; GTK2 no escala los iconos y está sin mantenimiento desde 2020;
  GTK3 (alfa en Lazarus 4.8) falla el selftest y se dibuja mal; Qt5 solo
  escala con `QT_SCALE_FACTOR` y su `libqt5pas` es demasiado antigua en
  Ubuntu 22.04 y Debian 12. GTK3 se volverá a evaluar con Lazarus 5, donde
  será el widgetset por defecto.
- **Pruebas manuales** en una VM Ubuntu con escritorio (lista en
  `fase6_plan.md`, 6.6 y 6.8): aplazadas por decisión de Toni (27-09-2026)
  hasta después de la Fase 7. Cubren lo que las pruebas automáticas no ven:
  HiDPI real, impresión con CUPS, portapapeles/arrastre y Wayland con
  entrada real en la versión Qt6.
- **Publicación**: subir los paquetes del release (`build/sourceforge`, tarea
  06) y enviar el zip OPM (`build/opm`) al Online Package Manager.
- **Traducciones solo junto al ejecutable**: `rptranslator` busca los
  `reportmanres.*` al lado del binario; por eso los paquetes Linux instalan en
  `/opt/reportman-designer`.

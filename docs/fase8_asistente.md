# Fase 8: asistente de informe nuevo en el diseñador LCL

En el diseñador VCL, Archivo > Nuevo abre un asistente
(`NewModernReportWizard`, `rpmdfnewreportwizardvcl`) que elige de dónde
saca los datos el informe (Agente de Reportman AI, base de datos directa o
ninguna), crea o elige la conexión, el esquema del Hub y termina con una
petición para el asistente de diseño. Con lo elegido, el diseñador prepara
el chat de diseño y, si hay petición, se la manda a la IA
(`rpmdfmainvcl` `ANewExecute`). En el diseñador LCL Archivo > Nuevo creaba
un informe en blanco (7.5 lo dejó pendiente). En esta fase se porta el
asistente con las mismas páginas, el mismo comportamiento y el mismo
resultado.

## Unidades

| Unidad | Qué es |
|---|---|
| `design_lcl/rpmdfnewreportwizardlcl.pas` | Nueva. Port de `TFRpNewReportWizardVCL` (`TFRpNewReportWizardLCL`, `NewModernReportWizard`, `RpPrepareModernNewReport`) |
| `design_lcl/rpdbxadminlcl.pas` | Nueva. La parte de `server/web/rpwebdbxadmin` (`TRpWebDbxAdminService`) que usa el asistente, para FPC |
| `design_lcl/rpmdfmainlcl.pas` | Archivo > Nuevo abre el asistente (`NewReportFromWizard`) y prepara el chat de diseño |
| `packages/fpc_lcl/reportman_designlcl.lpk`/`.pas`, `build/opm/opm_files.txt` | Las dos unidades nuevas |
| `tests/fpc/LclAIChatTest/uainewreporttests.pas` | Pruebas nuevas (`RunAINewReportTests`), llamadas desde `LclAIChatTest.lpr` |

Las unidades compartidas de la raíz, `server/web` y las VCL no se tocan (lo
encontrado en ellas está al final, sin corregir).

## Páginas

| Página | VCL | LCL |
|---|---|---|
| Tipo de conexión | Agente de Reportman AI, conexión directa, sin conexión (Siguiente pasa a Finalizar) | Igual |
| Nombre de la conexión (Agente) | Conexiones existentes del Agente de `dbxconnections`, Probar conexión, o una nueva | Igual; la prueba va en un hilo |
| Conexión de Reportman AI | API key, Iniciar sesión (`GET api/agent/databases`), base de datos del Hub; al seguir crea la conexión (`ApiKey`, `HubDatabaseId`) y la prueba (`api/agent/testconnection`) | Igual, en hilos; el combo muestra los nombres (el VCL muestra `nombre=id`) |
| Esquema (Agente) | Selector de esquemas con la tarjeta de cuenta, primero los de la base elegida; guarda `ApiKey`/`HubDatabaseId` del esquema en la conexión nueva | Igual (`TFRpAISchemaSelectorLCL`, carga en segundo plano) |
| ¿Tiene esquema? (directa) | Sí / No | Igual |
| Esquema (directa) | Selector de esquemas | Igual |
| Controlador | Familia (FireDAC, Zeos, dbExpress, BDE, DAO) y controlador concreto | FireDAC (SQLite) y Zeos, ver abajo |
| Nombre de la conexión (directa) | Existentes de la familia con el controlador, Probar conexión, o una nueva | Igual |
| Parámetros | Los del controlador (editor según el tipo), Probar conexión; al seguir se guardan | Igual; la prueba va en un hilo |
| Cadena ADO | Solo DAO | No existe en FPC (no hay ADO) |
| Finalizar | Ejemplo y petición para la IA; con petición y sin esquema pregunta si seguir sin IA | Igual |

Las páginas de login con conexión existente y de login del esquema directo,
que el VCL no alcanza nunca (`NextPageFor` no lleva a ellas), se portan
igual.

El resultado es el del VCL: el informe nuevo (`CreateNew`, grupo `TOTAL`,
secciones de 275) con la conexión elegida (`rpdbHttp`, `rpfiredac` o
`rpdatazeos`), y la petición, la base de datos, el esquema y la API key del
Hub para el chat.

## Conexiones en FPC (`rpdbxadminlcl`)

`rpwebdbxadmin` no está en los paquetes FPC: usa `System.JSON`, los
metadatos de FireDAC y dbExpress. `rpdbxadminlcl` hace lo mismo sobre los
mismos ficheros (`TRpConnAdmin`: `dbxconnections` y las secciones de
`dbxdrivers`) para los controladores del motor FPC:

| | VCL (`rpwebdbxadmin`) | LCL (`rpdbxadminlcl`) |
|---|---|---|
| Crear | `CreateConnection` | Igual; SQLite sin las claves de los cargadores dbExpress |
| Parámetros | `GetConnectionParams`: los del controlador (FireDAC con sus metadatos), valores guardados, opciones y editor (texto, contraseña, lista cerrada o editable, memo) | Igual con las secciones de `dbxdrivers` (sin metadatos de FireDAC) |
| Guardar | `UpdateConnectionParams`: solo los parámetros del controlador | Igual |
| Probar | `TestConnection`/`TestConnectionValues`: Agente por HTTP, el resto conectando con `TRpDatabaseInfoItem.Connect` y los valores como `DBPARAM_` | Igual (`RpExecuteConnectionTest`, sin estado compartido: corre en un hilo) |

Familias:

- **FireDAC**: el motor FPC abre con su FireDAC (SQLdb) solo SQLite, y
  solo si `DriverName` es `Sqlite` (con `DriverName=FireDac` lo rechaza, ver
  el punto 1 del final). Las conexiones nuevas se guardan con
  `DriverName=Sqlite` y `Database`, que el FireDAC de Delphi abre también.
  Se listan las `Sqlite` y las FireDAC con `DriverID=SQLite`.
- **Zeos**: una conexión `ZeosLib` con el protocolo elegido en
  `Database Protocol` (la clave que lee `rpdatainfo`); los protocolos, los
  del VCL (`ado` solo en Windows).
- **dbExpress, BDE y DAO**: no están en el motor FPC; no se ofrecen.
- **Agente**: igual que el VCL.

## Integración en el diseñador

- Archivo > Nuevo (Ctrl+N) y el botón Nuevo abren el asistente
  (`NewReportFromWizard`, pública). Si se cancela, el informe actual se
  queda (en el VCL `DoDisable` lo libera antes y el diseñador se queda sin
  informe).
- Al terminar: `InstallReport` (como abrir un informe), el chat toma el
  contexto del Hub del asistente (`SetHubContext`) y arranca su
  inicialización en línea (o la deja pendiente si el panel está oculto,
  como 7.5). Si hay petición, aparece en el chat como mensaje del usuario y
  se lanza con `BeginDesignChatContextRefresh`, como el VCL; si el panel de
  IA estaba oculto se muestra sin cambiar la preferencia guardada.
- `NewReport` sigue creando un informe en blanco sin preguntar: la usan el
  constructor, las pruebas y quien quiera el comportamiento anterior;
  `RpDesignerLCLNewReportWizard := False` hace que Archivo > Nuevo cree
  también el informe en blanco.
- `TRpDesignerLCL` (modo alojado) oculta Nuevo, como antes.
- El asistente clásico (`rpmdfwizardlcl`, Archivo > Asistente de informes e
  Informe > Asistente) no cambia.

## Diferencias con el VCL (decisiones)

- **Hilos.** Iniciar sesión, las pruebas de conexión y la validación de la
  conexión nueva del Agente van en `TRpAsyncWorker` y vuelven por el buzón;
  mientras tanto la navegación y los botones de la página esperan y la
  barra inferior dice qué se hace. El VCL bloquea la ventana (reloj de
  arena). Cancelar durante una petición cierra y descarta su respuesta.
- **Familias** del motor FPC (arriba).
- **Zeos nueva.** El VCL crea una conexión dbExpress `Interbase` y pierde el
  protocolo (punto 2 del final); el LCL crea una `ZeosLib` con el protocolo.
- **Volver atrás.** El VCL crea la conexión nueva al pasar de página y, si
  se vuelve atrás y se sigue con el mismo nombre, dice que ya existe. El LCL
  recuerda la conexión que ha creado: la reutiliza (con sus parámetros
  editados) si el controlador es el mismo y la vuelve a crear si cambió.
- **Base de datos del Hub:** el combo muestra el nombre (el VCL, `nombre=id`).
- **Petición en el chat:** se ve como mensaje del usuario (el VCL la envía
  sin mostrarla) y muestra el panel de IA si estaba oculto.
- Si la familia tiene un solo controlador (FireDAC: SQLite) queda elegido.
- **Tamaño:** 700×500 (el VCL 720×540), limitado al área de trabajo; cabe
  en 800×600. Los controles de cada página se encadenan con anclas (se
  adaptan a textos traducidos largos) y los botones tienen ancho fijo según
  su texto más largo (sin `AutoSize` en `alLeft`/`alRight`, ver
  `rpexpredlglcl`).
- **Textos traducibles** (el VCL tiene los textos en inglés fijos).

## Textos

`TranslateStr` con los ids nuevos 1710–1783 (lista con las nueve
traducciones en `docs/i18n/fase8_asistente_ids.txt`, UTF-8, separada por
tabuladores: `id en es ca cs de fr it lt pt`). Se reutilizan 94 (Cancel),
147 (Driver), 400 (Connection name), 933/934/935 (Next/Back/Finish), 1101
(Database driver), 1102 (New connection), 1131 (New Report), 1149
(Refresh) y 1528 (Schema). Los mensajes técnicos de `rpdbxadminlcl`
(`Connection name is required`, `Agent Connection: Fail`...) siguen en
inglés, como en `rpwebdbxadmin`.

## Pruebas (`tests/fpc/LclAIChatTest/uainewreporttests.pas`)

Contra un Hub simulado propio (sin red) y un `dbxconnections` del sandbox,
con heaptrc (0 bloques sin liberar):

- **Conexiones:** crear SQLite, Zeos (protocolo en `Database Protocol`, sin
  claves de biblioteca) y Agente; parámetros con su editor (lista cerrada
  del protocolo con los de `dbxdrivers`, contraseña, texto), guardar solo
  los del controlador, valores de prueba con lo editado encima, prueba del
  Agente (base, API key, mensaje del Hub; error de la base caída), prueba
  SQLite que abre (y crea) el fichero, nombres y controladores rechazados.
- **Diseño:** cabe en 800×600, botones separados y dentro de la ventana,
  el texto de ayuda se parte, ventana estrecha sin bucles.
- **Sin conexión:** hace falta elegir tipo, Siguiente pasa a Finalizar,
  termina al momento, quita las conexiones, informe con el grupo `TOTAL`;
  Cancelar.
- **Agente con conexión nueva:** solo conexiones del Agente, nombre
  existente o vacío rechazado, login obligatorio, API key vacía, clave
  rechazada (en un hilo, navegación bloqueada, estado), clave buena con las
  bases del Hub, prueba fallida (la página se queda, conexión creada con
  base y clave), volver atrás y seguir con la misma conexión (la página de
  login recarga las bases, como el VCL), prueba buena, esquemas de la clave
  y de la cuenta con los de la base elegida primero, ir y volver, petición y
  resultado (base, esquema, clave, conexión `rpdbHttp`).
- **Agente con conexión existente:** Probar conexión en un hilo (base y
  clave de la conexión), sin página de login, su esquema elegido.
- **SQLite directa con esquema:** esquema de la cuenta, familias del motor
  FPC, cambio de familia, conexiones listadas (sin FireDAC Firebird, Zeos,
  Agente ni dbExpress) con su controlador, nombre existente rechazado,
  parámetros (DriverName solo lectura), prueba con lo editado sin guardar,
  guardado, volver atrás sin volver a crear la conexión, resultado con el
  esquema de la conexión directa.
- **Zeos directa sin esquema:** protocolos, prueba de una existente, conexión
  nueva con el protocolo, parámetros (protocolo lista cerrada, contraseña),
  cambiar de protocolo con el mismo nombre (se vuelve a crear), petición sin
  esquema (No se queda, Sí termina sin petición).
- **Archivo > Nuevo del diseñador** (asistente modal manejado por un
  temporizador): Cancelar deja el informe; sin el asistente
  (`RpDesignerLCLNewReportWizard := False`) informe en blanco; con el
  asistente (conexión existente del Agente, esquema y petición, panel de IA
  oculto): informe nuevo con la conexión y el grupo `TOTAL`, contexto del
  Hub en el chat, panel visible sin cambiar la preferencia, la petición en
  el chat y en la petición de diseño al Hub (instrucciones, esquema, base,
  clave, informe) y el diseño aplicado.

Capturas (`--shots`): `newreport_route`, `newreport_agent_login`,
`newreport_agent_schema`, `newreport_driver`, `newreport_connection`,
`newreport_params`, `newreport_finish`, `newreport_designer`.

Resultados:

- Windows: `LclAIChatTest` 1101 comprobaciones (308 nuevas), 0 omitidas,
  sin fugas (en una de ocho ejecuciones heaptrc marcó 2 bloques reservados
  por un hilo de `ufakeserver` al cerrar; no se repitió);
  `LclDesignerTest --selftest` correcto; el diseñador autónomo
  (`repmandesigner_lcl`, Release) compila; zip OPM validado
  (`make_opm_package.ps1 -Validate`, lista de ficheros comprobada con
  `-RefreshFileList`).
- WSL (Lazarus 3.0, GTK2): paquetes y pruebas compilan;
  `LclDesignerTest --selftest` correcto; la serie nueva sola, 304
  comprobaciones, 2 omitidas (GTK marca siempre un botón de radio del grupo,
  así que no se puede probar "sin elegir tipo" ni "sin elegir Sí/No"), sin
  fugas. `LclAIChatTest` completo no llega a la serie nueva: el servidor X
  de WSLg (Xwayland) cae en la serie 7.4 ("Expression editor with a
  report", `Fatal server error: request could not be marshaled: can't send
  file descriptor`), antes de ejecutar nada de esta fase.
- Qt6 y Docker: no probados.

En GTK el primer botón de radio de cada grupo sale marcado: el tipo de
conexión empieza en Reportman AI y la pregunta del esquema en Sí.

## Encontrado en código común, `server/web` o VCL (sin corregir)

1. `rpdatainfo.pas:2684-2712` (solo FPC, `{$IFDEF FPC}` del driver
   FireDAC): toma como controlador `DriverName` y solo si está vacío
   `DriverID`, y rechaza lo que no sea SQLite. Una conexión FireDAC
   guardada por el diseñador Delphi (`DriverName=FireDac`,
   `DriverID=SQLite`) no se abre en FPC ("Database driver not supported -
   FireDac (FPC): FIREDAC"). Arreglo: con `DriverName` `FireDac` (o vacío)
   usar `DriverID`. Por eso el asistente LCL crea `DriverName=Sqlite`.
2. `rpmdfnewreportwizardvcl.pas:897` (`FamilyDriverName`): para Zeos
   devuelve `Interbase`, y `CreateConnection(nombre, 'Interbase',
   protocolo)` (`:751`) ignora el protocolo (`rpwebdbxadmin` solo usa el
   tercer parámetro con dbExpress). La conexión "Zeos" nueva es dbExpress
   Interbase sin `Database Protocol`, la página de parámetros muestra los de
   Interbase y el informe (`rpdatazeos`) no abre (protocolo vacío).
   Arreglo: crear `ZeosLib` y escribir `Database Protocol`.
3. `rpmdfnewreportwizardvcl.pas:707/736-760`: la conexión nueva se crea al
   pasar de página; volviendo atrás y siguiendo con el mismo nombre dice
   "This connection name already exists" (la creó el propio asistente).
4. `rpmdfnewreportwizardvcl.pas:1765` (`LoadHubDatabases`): el combo
   muestra las líneas `nombre=id`.
5. `server/web/rpwebdbxadmin.pas:907-910` (`IsClosedOptionSet`) usa
   `S_FD_True`/`S_FD_False`/`S_FD_Yes`/`S_FD_No` de
   `FireDAC.Stan.Consts`, que solo está en los `uses` con `FIREDAC`: sin
   `FIREDAC` la unidad no compila.
6. `rpdatahttp.pas:1803` (`GetHubDatabases`): `GetValue('displayName').Value`
   falla con una base sin `displayName` y se informa como "no se pudo
   contactar" (el LCL usa `displayName` o `name`).
7. `rpmdfmainvcl.pas:640-653` (`ANewExecute`): `DoDisable` libera el informe
   antes del asistente; si se cancela, el diseñador queda sin informe
   (quizá intencionado; el LCL conserva el actual).

## Para integrar

- Añadir los ids 1710–1783 a los `reportmanres.*` (y `REPORTMANRES.RES`).

# Fase 7.3: asistente SQL con esquema en el diseñador LCL

Port al diseñador Lazarus del asistente SQL del diseñador Delphi
(`rpmdfdatasetsvcl` + `rpfrmmonacoeditorvcl`), sobre la base de 7.2
(`TFRpChatFrame`, `rpaithreadslcl`, selección de modelo, tarjeta de cuenta).
Solo cambian unidades LCL; las unidades compartidas de la raíz y las VCL no se
tocan (lo encontrado en ellas está al final, sin corregir).

## Qué se hizo

### Unidades

| Unidad | Cambio |
|---|---|
| `design_lcl/rpmdfdinfolcl.pas` | Diálogo de conexiones y datasets: el chat del asistente SQL a la derecha del editor, contexto del Hub del dataset, peticiones en hilos, aplicar, auditar |
| `design_lcl/rpfrmmonacoeditorlcl.pas` | Editor SQL con la API del `TFRpMonacoEditorVCL` (esquema, IA, modelo, pestaña de auditoría), puente Monaco–esquema–IA, editor alternativo SynEdit con completado por esquema |
| `packages/fpc_lcl/reportman_designlcl.lpk` | Nueva dependencia: `SynEdit` |
| `tests/fpc/LclAIChatTest/uaisqltests.pas` | Pruebas nuevas (`RunAISqlTests`), llamadas desde `LclAIChatTest.lpr` |

No hay unidades nuevas (no cambia `build/opm/opm_files.txt`). En
`docs/opm.md` y en la descripción de dependencias de `make_opm_package.ps1`
se añade SynEdit.

### Diálogo de datos (`rpmdfdinfolcl`, port de `TFRpDatasetsVCL`)

- **Chat**: `TFRpChatFrame` en un panel a la derecha del editor SQL (con
  divisor), como `PChatHost` de la VCL. Se crea con el primer dataset
  (`EnsureAdvancedEditors`) con el mensaje inicial del VCL, y arranca la
  inicialización en línea (tarjeta, agentes, esquemas). El diálogo es más
  grande (1060×720 a 96 ppp) para que quepan editor y chat.
- **Contexto del Hub** (`ApplyActiveDataInfoContext`): `HubDatabaseId` y
  `ApiKey` de los parámetros de la conexión del dataset (`dbxconnections`),
  `HubSchemaId` del dataset, `runtime` (`ADO_Net` para conexiones del Hub o
  .Net, `Delphi` para el resto) como el VCL. Se aplica al editor y al chat al
  elegir dataset y al cambiar su conexión. Al crear un dataset o cambiarle la
  conexión hereda el esquema de otro dataset de la misma conexión
  (`FindSiblingHubSchemaId`).
- **Enviar**: `TranslateToSql` (`NlToSql/TranslateToSQLStream`) en un
  `TRpAsyncWorker`. El SQL a refinar es el del editor; el progreso llega como
  mensajes al buzón del diálogo y alimenta el chat igual que el
  `ChatTranslateProgress` del VCL (respuesta en streaming en el registro de
  IA, tokens, etapas). Errores del servicio y "No SQL was returned by the
  service." como en el VCL.
- **Stop**: el botón Stop/Clear del chat y el de la selección de modelo
  cortan el stream al momento (`IRpAsyncCancel`, se comprueba en cada bloque
  recibido) y la versión de la petición descarta lo que llegue después.
- **Aplicar**: el SQL sugerido pasa al editor como una edición que se puede
  deshacer con Ctrl+Z (Monaco: `executeEdits`; SynEdit: un bloque de
  deshacer), al editor de texto ("Monaco / Texto") y a la copia de trabajo del
  dataset. Como el resto del diálogo, el informe no cambia hasta Aceptar;
  entonces el cambio de `sql` (y de `hubSchemaId`) queda en el deshacer del
  diseñador en el mismo grupo.
- **Auditar (explicar el SQL)**: pestaña *Audit* del editor, botón *Audit
  SQL*: `ExplainSql` en un hilo; la explicación se muestra y se guarda en
  `SQLExplanation` del dataset (y el error en `SQLExplanationError`). Como el
  VCL, la comparación de cambios incluye la explicación; si solo cambia la
  explicación el informe queda marcado como modificado (no es una propiedad
  del deshacer).
- **Esquema**: elegir un esquema en el editor o en el chat lo guarda en
  `HubSchemaId` del dataset y lo aplica al otro (`SyncActiveSchemaContext`).
- El diálogo compartido (`GDataConfigDialog`, de `Application`) se libera en
  la finalización de la unidad, antes que `rpaithreadslcl`.

### Editor SQL (`rpfrmmonacoeditorlcl`, port de `TFRpMonacoEditorVCL`)

Mantiene la API LCL anterior (`TryCreateWebView`, `SQL`, `SetTheme`,
`OnWebMessage`, `ActivateFallback`...) y añade la del VCL: combo de esquemas
con botón de configuración en la web, botón *AI* (activa o desactiva la
inferencia, preferencia `AIEnabled`), selección de modelo
(`TFRpAISelectionLCL`), páginas *SQL editor* y *Audit*, `SetHubContext`,
`HubDatabaseId`/`HubSchemaId`, `RuntimeDb`, `AITier`/`AIMode`/`AgentSecret`/
`AgentAiId`, `GetSchemaApiKey`, `AuditText`, `SetAuditBusy`, `UpdateAITokens`,
`AppendLog`, `OnSchemaChanged`, `OnAuditSql`, `OnInferenceLog`. La lista de
esquemas y agentes se carga en un hilo (la del API key de la conexión y la de
la cuenta, mezcladas como en el VCL).

**Puente con Monaco (Windows, WebView2).** La página es la misma del VCL
(`MonacoEditorAssets.res`, sin cambios). Mensajes:

| Mensaje | Qué hace |
|---|---|
| `00:` | Editor listo: envía el SQL, el tema, el lenguaje e instala el proveedor de completado por esquema |
| `01:<sql>` | Contenido cambiado (`\n` → `\r\n`) → `OnContentChanged` |
| `02:<id>:<offset>\n<sql>` | Completado de IA, como el VCL: espera de 1 s, `SuggestSql` (`NlToSql/SuggestSqlCodeStream`) en un hilo con el esquema del editor, respuesta con `window.receiveAICompletions` (texto fantasma y lista). Mismo texto (solo se movió el cursor) o IA desactivada: respuesta vacía al momento. Una petición nueva cancela la que está en curso y se lanza al acabar esta |
| `03:<id>:<offset>:<explícito>\n<sql>` | Completado por esquema (nuevo): lo envía un proveedor de completado que el editor instala en la página con `ExecuteScript` al recibir `00:`; se contesta con `window.rpReceiveSchemaCompletions` con las tablas y columnas del esquema, calculadas por el mismo motor Pascal que el editor alternativo. Los offsets de Monaco son UTF-16 y se convierten |

Los mensajes se tratan después de volver del evento de WebView2 (el VCL usa
`TThread.ForceQueue`); `ProcessWebMessage` trata uno directamente (pruebas).
El Stop de la selección de modelo cancela el completado de IA en curso (en el
VCL no hace nada).

**Tablas y columnas del esquema.** Son las que el usuario define en
`app.reportman.es`: `schemaTables` de cada esquema en la respuesta de
`GET api/agent/databases` (la misma petición de la lista de esquemas), con la
API key del esquema elegido. Se cargan en un hilo al cambiar de esquema y se
guardan por esquema; se vuelven a pedir al cambiar de usuario o de lista.

**Motor de completado** (`RpSqlCompletionItems`, sin interfaz): columnas
tras `alias.` o `TABLA.` (alias de `FROM`/`JOIN`, con `AS` o sin él, tablas
con prefijo de esquema, sin mirar comentarios ni tablas derivadas); tablas
tras `FROM`, `JOIN`, `INTO`, `UPDATE`, `TABLE` y tras una coma de la lista del
`FROM`; al pedirlo (Ctrl+Espacio, o al escribir en Monaco) las columnas de las
tablas de la sentencia, las tablas y, en el editor alternativo, palabras
clave SQL. En el resto de casos no propone nada: ahí completa la IA.

### Editor alternativo: SynEdit

Linux, Windows sin WebView2 o `RPM_FORCE_WEBVIEW_FALLBACK`: en lugar del
`TMemo` (el del VCL) un `TSynEdit` con:

- resaltado SQL (`TSynSQLSyn`) con las tablas del esquema como nombres de
  tabla, y los colores de los temas de Monaco (claro y oscuro, botón *Tema*);
- `TSynCompletion` con el motor de arriba: Ctrl+Espacio, y solo al escribir
  `.` o un espacio tras `FROM`/`JOIN`... si hay algo que proponer; la lista
  se filtra al escribir y muestra el tipo de la columna o "table";
- deshacer (también de una sugerencia aplicada) y números de línea;
- el completado de IA de Monaco (añadido tras 7.5, a petición de Toni: en
  Linux no habrá Monaco hasta que la LCL GTK3 esté lista). Tras una edición
  de teclado (escribir, Intro, borrar, cortar, pegar, tabular; no deshacer,
  rehacer ni aceptar la sugerencia) el editor pide `SuggestSql` como lo haría
  un mensaje `02:`: el texto con CRLF y el offset UTF-16 del cursor, con la
  misma espera de 1 s, cancelación y "mismo texto" que Monaco. El primer
  elemento `inlineCompletions` se pinta como texto fantasma (gris, cursiva)
  en el cursor, con un gancho `peAfterPaint` de SynEdit; las líneas
  siguientes tapan de momento las de debajo (Monaco las desplaza). **Tab** lo
  inserta como un solo paso de deshacer; **Esc**, escribir o mover el cursor
  lo descartan; una respuesta para un cursor que se ha movido no se muestra.
  Tras la última línea, "Tab para aceptar, Esc para descartar" (id 1561).
  Así, un comentario en lenguaje natural (`-- clientes con saldo`) se
  convierte en el SQL que lo implementa. La lista `listCompletions` no se usa:
  el desplegable es el del esquema.

En Linux es el editor normal: ya no se intenta WebView2 ni se busca
`MonacoEditor.zip`, y no se escriben los avisos de "fallback" en el registro
(en Windows sí, como el VCL, con un texto traducible).

**Por qué SynEdit y no un popup propio sobre el `TMemo`.** SynEdit forma
parte de toda instalación de Lazarus (el IDE es un SynEdit), se pinta con el
lienzo de la LCL igual en win32, GTK2 y Qt6, y trae resaltado SQL, deshacer y
un completado probado (`TSynCompletion`, el del IDE) con su ventana, teclado
y filtro. Un popup propio sobre un `TMemo` necesitaría calcular la posición
del cursor en píxeles (distinto en cada widgetset), gestionar el foco y el
teclado de una ventana emergente, y seguiría sin resaltado. Coste: una
dependencia más en `reportman_designlcl.lpk`, que no hay que instalar aparte.
Comprobado: zip OPM validado en Windows y en WSL (`-Validate -ValidateWsl`),
Docker Qt6 y GTK2.

## Paridad con el VCL

| Función | LCL |
|---|---|
| Chat SQL (esquema, modelo, cuenta, enviar, streaming, tokens, aplicar, stop) | Igual |
| SQL a refinar = SQL del editor; runtime; esquema del hermano | Igual |
| Auditar/explicar el SQL | Igual (pestaña *Audit*) |
| Completado de IA en Monaco (`02:`) | Igual |
| Combo de esquemas, botón de configuración, botón AI, selección de modelo en el editor | Igual |
| Aviso de WebView2 ausente en el registro | Igual (solo Windows) |
| Aplicar una sugerencia | Se puede deshacer con Ctrl+Z en el editor (el VCL también desde el 28-09-2026: antes usaba `setValue`) |
| Explicación de la auditoría | Va al dataset auditado aunque se cambie de dataset mientras llega (igual en el VCL desde el 28-09-2026) |
| Lista de esquemas vacía, o sin el esquema del dataset | No cambia el `HubSchemaId` del dataset: solo lo cambia una elección del usuario (`SchemaChangeFromLoad` del chat; igual en el VCL desde el 28-09-2026) |
| Stop de la selección de modelo en el editor | Cancela el completado de IA y la auditoría (igual en el VCL desde el 28-09-2026) |
| Completado por esquema (tablas/columnas) | Nuevo, en Monaco y en el editor alternativo |
| Editor sin WebView2 | SynEdit con resaltado y completado (el VCL: `TMemo`) |
| Completado de IA en el editor alternativo | Sí: texto fantasma en el cursor, Tab/Esc (el VCL, con `TMemo`, no lo tiene) |
| Parar la auditoría | Sí, con el Stop de la selección de modelo del editor (su respuesta no se guarda) |
| Texto de la auditoría | `TMemo` de texto como el VCL, aunque venga en Markdown |

## Textos

`TranslateStr` con los ids nuevos 1552–1561 (lista con las nueve
traducciones en `docs/i18n/fase7_3_ids.txt`, ya en `repman/reportmanres.*` y
en `REPORTMANRES.RES`; 1561 es el aviso del texto fantasma). Se reutilizan 1528 (Schema), 1496 (Configure DB
Schemas) y 1536 (Generation stopped.). Los mensajes de diagnóstico del
registro siguen en inglés, como en 7.2.

## Pruebas (`tests/fpc/LclAIChatTest/uaisqltests.pas`)

Contra un Hub simulado propio (sin red), con heaptrc (0 bloques sin liberar):

- **Motor**: tablas tras `FROM`/`JOIN`/coma del `FROM`, columnas tras alias
  (con `AS`, prefijo de esquema, nombre de tabla), comentarios y tablas
  derivadas, casos sin contexto, palabras clave, offsets UTF-16; carga de
  `schemaTables` (tipos por nombre, numéricos antiguos, clave primaria).
- **Puente Monaco sin WebView2** (control sin padre, mensajes a
  `ProcessWebMessage`, scripts capturados con `OnScript`): lista de esquemas
  y tablas cargadas, `00:` (SQL + proveedor instalado), `01:`, `03:` (tablas,
  columnas de un alias, offset UTF-16, respuesta vacía), `02:` (petición con
  cursor, esquema, base, API key y runtime; respuesta a la página; mismo
  texto; IA desactivada; petición reemplazada cancelada a tiempo; Stop de la
  selección de modelo), aplicar con `executeEdits`, tema, cambio de esquema en
  el combo.
- **Editor alternativo**: SynEdit visible, tablas resaltadas, popup con
  tablas tras `FROM`, filtro al escribir, elemento insertado, columnas de un
  alias sustituyendo lo escrito, lista completa al pedirlo, popup automático
  tras `.` y `FROM ` (no tras otras palabras), aplicar y Ctrl+Z, tema oscuro.
- **Completado de IA del editor alternativo**: un comentario y un Intro dan
  una sola petición tras la espera (texto con CRLF, offset UTF-16, esquema,
  API key), texto fantasma de tres líneas que no entra en el SQL, Tab lo
  inserta (cursor al final, un solo Ctrl+Z, sin petición nueva), deshacer y
  rehacer no piden, Tab sin sugerencia tabula, Esc, mover el cursor y
  escribir lo descartan, respuesta de un cursor movido descartada, retroceso
  pide, offset de una letra de dos bytes, IA desactivada sin petición.
- **Diálogo de datos**: chat creado y a la derecha, contexto del Hub (base,
  esquema, runtime), esquemas del chat y del editor cargados, prompt en
  streaming con el cuerpo de la petición comprobado, créditos, aplicar
  (editor, editor de texto, copia de trabajo; informe intacto), Ctrl+Z/redo en
  el editor, error del servicio, Stop a mitad (corte en < 2,5 s, nada
  después), auditoría (texto, dataset, registro), esquema elegido en el editor
  guardado en el dataset y seguido por el chat, segundo dataset, Aceptar con
  deshacer y rehacer del informe.
- **WebView2 (Windows)**: proveedor instalado en la página real, ida y vuelta
  `03:` y `02:` desde el JavaScript, el widget de sugerencias de Monaco con las
  tablas del esquema, y el diálogo con Monaco aplicando una sugerencia.

Resultados (todas con heaptrc sin fugas):

- Windows: `LclAIChatTest` 397 comprobaciones, 0 omitidas (con WebView2);
  `LclDesignerTest --selftest`, `HubClientTest` (469) y el diseñador
  `repmandesigner_lcl` (Release) compilan y pasan.
- WSL (Lazarus 3.0, GTK2): `LclAIChatTest` 370 comprobaciones (en una de
  cinco ejecuciones se omite el popup automático porque la ventana no recibe
  el foco; en otra, un error de E/S del servidor X de WSLg sin relación con
  las pruebas).
- Docker (`build-linux.ps1 -SkipImage`): Qt6 y GTK2 compilan, selftest y
  `LclAIChatTest` (370, 0 omitidas) pasan, lintian limpio y las 15 pruebas de
  paquetes en máquinas limpias pasan.
- Zip OPM: `make_opm_package.ps1 -Validate -ValidateWsl` correcto (Windows
  win32 y WSL gtk2, compilación limpia con la dependencia SynEdit).

Capturas (`--shots`): `sql_assistant_dialog`, `sql_fallback_editor`,
`sql_fallback_completion`, `sql_fallback_dark`, `sql_fallback_ai_suggestion`,
`sql_fallback_ai_accepted` y, en Windows,
`sql_monaco_completion` y `sql_assistant_monaco`.

## Encontrado en el VCL y en unidades compartidas

Verificado y corregido el 28-09-2026 (commits dd5a3d4 y siguiente): 1 a 4.
5 y 6 no son fallos (lecturas atómicas; mismo desplazamiento del campo).

1. `rpmdfdatasetsvcl.pas:827` (`ChatSchemaChange`): el chat llama a
   `OnSchemaChanged` al terminar de cargar su lista
   (`rpfrmchatvcl` `ApplyLoadedSchemas` → `ComboSchemaChange`); si la lista
   llega vacía (sin sesión o sin red) el dataset pasa a `HubSchemaId = 0` y
   Aceptar lo guarda: se pierde el esquema. Arreglo: salir si
   `FChat.ComboSchema.Items.Count <= 1` y `FChat.GetHubSchemaId = 0` (lo hace
   el LCL).
2. `rpmdfdatasetsvcl.pas:1281` (`MonacoAuditSql`): la explicación se guarda en
   el dataset seleccionado cuando llega la respuesta, no en el auditado.
   Arreglo: guardar el `Name` del dataset al empezar y buscarlo al terminar.
3. `rpfrmmonacoeditorvcl.pas:703` (`SetSQL` con `setValue`, usado al aplicar
   una sugerencia desde `rpmdfdatasetsvcl.pas:951`): borra la pila de deshacer
   de Monaco, así que aplicar no se puede deshacer con Ctrl+Z. Arreglo: un
   método que aplique con `executeEdits` y `pushUndoStop`.
4. `rpfrmmonacoeditorvcl.pas:363`: `FAISelection.OnStopRequest` no se asigna;
   el botón Stop de la selección de modelo del editor no hace nada durante el
   completado de IA o la auditoría.
5. `rpmdfdatasetsvcl.pas:1043`: el hilo del chat lee `FChatRequestVersion`,
   un campo del frame, sin sincronizar (y el frame puede estar liberado).
   Inofensivo en la práctica; el LCL usa un indicador compartido.
6. `rpdatainfo.pas:2009` (`TRpDatabaseinfoitem.UpdateConAdmin`): convierte
   `Collection` a `TRpDataInfoList` para leer `FReport`, pero es un
   `TRpDatabaseInfoList`; funciona porque el campo está en la misma posición.
   Arreglo: `TRpDatabaseInfoList(Collection).FReport`.

## Pendiente

- ~~Añadir los ids 1552–1560 a los `reportmanres.*`~~ (hecho, 4893c74).
- Completado de columnas con conexiones locales (Zeos, SQLite...) sin
  esquema del Hub: se podría usar `GetTableNames`/`GetFieldNames` de la
  conexión (conectar al abrir el completado).
- ~~Completado de IA en el editor alternativo (Linux)~~ (hecho, ecd5a0e).
- ~~Parar la auditoría desde el Stop de la selección de modelo~~ (hecho).

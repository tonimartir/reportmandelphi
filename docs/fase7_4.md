# Subfase 7.4: asistente de expresiones en el editor LCL

Port del chat de IA del editor de expresiones del VCL (`TFRpExpredialogVCL`
de `rpchatdialogvcl`, envuelto por `rpexpredlgvcl`) al editor de expresiones
LCL, `design_lcl/rpexpredlglcl.pas`, sobre la base de la 7.2
(`TFRpChatFrame`, `rpaithreadslcl`) y el cliente del Hub de la 7.1
(`TRpDatabaseHttp.SuggestExpressionStream`). Plan general en
`implementation_plan.md` (Fase 7).

## Qué hace

El editor tiene dos partes, como el VCL: a la izquierda el editor clásico
(expresión, categorías, operaciones, ayuda, Añadir, Comprobar sintaxis,
Mostrar resultado, Aceptar/Cancelar) y a la derecha, con un separador, el
chat común (`TFRpChatFrame`) sin selector de esquema
(`SetShowSchemaSelector(False)`): tarjeta de cuenta, modelo, pestañas Chat,
Registro de IA y Registro de red, y el cuadro del prompt con Enviar,
Aplicar y Limpiar/Detener.

- **Petición.** Enviar lanza un hilo (`TRpExpressionChatWorker`) que llama a
  `SuggestExpressionStream` con el prompt, la expresión del memo, la
  posición del cursor, el proveedor y el modo del selector de modelo (y el
  agente local si es el elegido) y el **contexto semántico**. El progreso se
  transmite al registro de IA y a los tokens del selector de modelo con los
  mismos porcentajes de prellenado que el VCL
  (`GetExpressionPrefillPercent`).
- **Validación.** La expresión sugerida se comprueba con el evaluador del
  diálogo (`CheckSyntax`). Si falla, se avisa ("Local validation failed…")
  y se pide una vez más con `fix = true` enviando la expresión inválida; si
  sigue sin ser válida se sugiere igualmente, con el error y el aviso de que
  se puede aplicar y editar a mano. Los mensajes del chat son los del VCL.
- **Aplicar** sustituye la expresión del memo (como el VCL: "Click 'Apply'
  to replace the expression") y deja el cursor al final.
- **Detener** cancela la petición (el indicador de cancelación corta el
  stream al llegar el siguiente trozo) y el chat queda libre al momento con
  "Generation stopped.".
- **Perfil.** El `userProfile` de la respuesta actualiza los créditos del
  selector de modelo.
- **Contexto semántico** (`RpBuildExpressionSemanticContextJson`, el
  `BuildExpressionSemanticContextJson` del VCL): bloques
  `[DATASET_COLUMNS alias columns]` con las columnas de los datasets del
  alias del evaluador (tipo semántico del campo) y las columnas de los
  datasets del Agente que da el Hub, bloque `[MEMORY_VARIABLES]` con los
  parámetros del informe (`M.NOMBRE:tipo`) y el catálogo de funciones y
  constantes del evaluador que tienen ayuda para la IA (`AIHelp`), sin los
  elementos expresión del informe.
- **Con un informe** (`TRpExpreDialogLCL.Report`, lo que hace el inspector
  de objetos, igual que el VCL): al mostrarse, el diálogo abre los datasets
  del informe en segundo plano (`PrepareLiveContext`) y pide al Hub las
  columnas de los datasets `rpdbHttp` (`CollectAgentSchemaOnlyContext`,
  `GetTableSchema`). Mientras tanto usa una copia del evaluador y el botón
  Actualizar muestra "Refreshing..."; al terminar pasa al evaluador del
  informe y la lista de campos incluye también las columnas del Agente
  ("Field from dataset ALIAS", modelo `ALIAS.CAMPO:tipo`). Actualizar vuelve
  a abrirlos.
- **Sin sesión del Hub** el editor clásico funciona como antes y la tarjeta
  de cuenta ofrece iniciar sesión (7.2). Una petición sin sesión o con el Hub
  inaccesible termina con el error en el chat; el editor no se bloquea en
  ningún caso (la petición va en un hilo y Detener libera el chat).

`CollectAgentSchemaOnlyContext` y `BuildDesignExpressionContextJson` (el
contexto del asistente de diseño, que el VCL usa desde `rpmdfmainvcl`) están
en la interfaz de `rpexpredlglcl`, como en `rpchatdialogvcl`, para el
asistente de diseño (7.5).

## Ficheros

| Fichero | Cambio |
|---|---|
| `design_lcl/rpexpredlglcl.pas` | El editor con el chat, los hilos, el refresco de datasets y los constructores de contexto. Misma API que antes (`TFRpExpreDialogLCL`, `TRpExpreDialogLCL`, `ChangeExpression`, `ChangeExpressionW`, `ExpressionCalculateW`) más la del VCL (`InitializeDialog`, `ConfigureReportRefresh`, `Report`, `PrintDriver`) |
| `design_lcl/rpmdobjinsplcl.pas` | El botón de expresión del inspector pasa el informe al diálogo (`Report`), como el inspector VCL |
| `tests/fpc/LclAIChatTest/uaiexprtests.pas` | Pruebas nuevas (`RunAIExprTests`) |
| `tests/fpc/LclAIChatTest/LclAIChatTest.lpr` | Llama a `RunAIExprTests` |
| `docs/i18n/fase7_4_ids.txt` | Textos nuevos (ids 1600–1611) en los nueve idiomas |

No hay unidades nuevas en los paquetes ni cambios en unidades compartidas de
la raíz ni en unidades VCL.

## Diferencias con el VCL

- **Hilos**: FPC 3.2.2 no tiene métodos anónimos; los hilos son
  `TRpAsyncWorker` y los mensajes WM_USER+204/205 llegan por un
  `TRpAsyncMailbox` (`rpaithreadslcl`), que se desconecta al destruir el
  diálogo.
- **Cancelación por petición**: cada petición tiene su propio indicador y
  versión. Detener libera el chat al instante y descarta los mensajes que
  lleguen después; el VCL deja el chat ocupado hasta que el hilo ve el
  indicador (que solo se mira cuando llegan datos) y un prompt nuevo
  reinicia el indicador compartido, con lo que una petición detenida podía
  seguir.
- **Validación en el hilo principal** (`TThread.Synchronize`); el hilo del
  VCL usa el evaluador del formulario desde el hilo de trabajo.
- **Cierre durante el refresco**: el diálogo espera a que termine un
  refresco de datasets en curso al destruirse, para que ningún hilo siga
  abriendo los datasets del informe del diseñador (el VCL lo deja seguir).
- **Destino del alias**: sin alias de destino (`RpAlias`) el evaluador del
  informe conserva su propio alias (el que llena `PrepareLiveContext`); el
  VCL le asigna siempre `RpAlias`, también cuando es nil. El inspector LCL no
  pasa el `AliasList` externo del informe, que el diálogo vaciaría.
- **`BuildDesignExpressionContextJson`** no crea un formulario y, si no se
  le da alias, deja el del evaluador del informe como estaba (el VCL lo deja
  apuntando a un alias que libera).
- **Textos** con `TranslateStr` (el VCL los tiene fijos en inglés). Los
  textos que van a la IA (incidencias del contexto) siguen en inglés.
- **Modo diseño** del diálogo VCL (`TRpChatMode.rcmDesign`): no se porta;
  nada lo activa en el VCL (el asistente de diseño está en la ventana
  principal).
- Arreglos del editor LCL de la 4.1 hechos al portar: Añadir inserta el
  nombre del elemento (antes insertaba el modelo, p. ej. `function
  Uppercase(s:string):string`) en la posición del cursor (el VCL lo añade al
  final); Aceptar de `ExpressionCalculateW` evalúa la expresión como el VCL
  (antes devolvía Null salvo tras Mostrar resultado); el diálogo es
  redimensionable y se distribuye con alineaciones.
- Los valores `null` del JSON de la respuesta se tratan como vacíos (en
  Delphi `TJSONNull.Value` es `'null'`).

## Textos

Ids nuevos 1600–1611 en `docs/i18n/fase7_4_ids.txt` (id, en, es, ca, cs,
de, fr, it, lt, pt, separados por tabuladores); se añaden a los
`reportmanres.*` al integrar. Se reutilizan Refresh (1149), Stop (1522),
Apply (1535), Generation stopped. (1536) y Suggested expression (1538) de la
7.2, y los del editor clásico.

| Id | Texto |
|---|---|
| 1600 | Mensaje inicial del asistente |
| 1601 | Local validation failed. Running one automatic fix. |
| 1602 | Generated expression is still invalid after one automatic fix: |
| 1603 | You can still apply it and edit it manually. |
| 1604 | Expression fixed after local validation. |
| 1605 | Expression generated. |
| 1606 | No final response received |
| 1607 | Response without result |
| 1608 | Empty expression returned |
| 1609 | Refreshing... |
| 1610 | Reopen datasets and refresh fields (ayuda de Actualizar) |
| 1611 | Field from dataset (ayuda de una columna del Agente) |

## Pruebas

`tests/fpc/LclAIChatTest/uaiexprtests.pas` (`RunAIExprTests`, llamada desde
`LclAIChatTest.lpr` después de las pruebas de la 7.2), con un Hub simulado
propio sobre `ufakeserver`, sin red, en el entorno aislado de
`LclAIChatTest` (heaptrc, 0 bloques sin liberar). El informe de prueba tiene
un dataset MyBase (XML MIDAS generado en el directorio temporal) y un
dataset del Agente (`rpdbHttp`) que no abre y cuyas columnas da el Hub.

- Sin sesión: tarjeta de cuenta con el login, sin selector de esquema,
  mensaje inicial, editor clásico (validación, Añadir en el cursor), el Hub
  rechaza el prompt (401) y el error sale en el chat sin tocar la expresión.
- Refresco con informe: datasets abiertos en segundo plano, columnas del
  Agente pedidas al Hub (SQL, base de datos, API key de la conexión), lista
  de campos, contexto semántico exacto (bloques de columnas, parámetros,
  funciones y constantes con ayuda para la IA), Actualizar con la copia del
  evaluador.
- Prompts: respuesta válida transmitida (registro de IA, sugerencia,
  explicación, créditos del perfil), cuerpo enviado al Hub (prompt,
  expresión, cursor, `fix`, modo, proveedor, contexto, token), Aplicar;
  inválida y corregida con un reintento `fix`; inválida tras el reintento;
  errores del servidor y expresión vacía.
- Detener a mitad (el hilo termina en milisegundos y no llega nada más) y el
  diálogo destruido mientras transmite.
- `TRpExpreDialogLCL.Execute` modal con informe (el camino del inspector),
  guiado por un temporizador: refresco, prompt, Aplicar, Aceptar.
- `CollectAgentSchemaOnlyContext` y `BuildDesignExpressionContextJson`
  (fuentes vivas y del Agente, alias del evaluador intacto).
- Hub inaccesible (puerto local cerrado): el editor sigue funcionando,
  Detener libera el chat y cerrar el diálogo no espera a la petición.

En Windows, además, una captura del editor con el chat en WebView2.

Resultados (27-09-2026): Windows, `LclAIChatTest` 361 comprobaciones (167
de la 7.4) sin fugas, `LclDesignerTest --selftest`, `HubClientTest` (469) y
el diseñador autónomo compilan y pasan; WSL (Lazarus 3.0, GTK2) y Docker
(Qt6 y GTK2) en el apartado de verificación del commit.

## Encontrado

1. **FPC 3.2.2 en Windows: una conexión rechazada tarda el tiempo de
   conexión entero (60 s).** `ssockets` (`TInetSocket.Connect` con
   `ConnectTimeout`) hace `select` solo con el conjunto de escritura, y en
   Windows un `connect` no bloqueante rechazado se señala en el conjunto de
   excepciones: el `select` espera los 60 s de
   `TNetHTTPClient.ConnectionTimeout` (`rtl_fpc/rphttpclientfpc.pas:1105`,
   `1253`). Con el Hub inaccesible (puerto cerrado) cada petición al Hub
   tarda 60 s en fallar en Windows (medido: 59,6 s; en Linux falla al
   momento). El editor no se bloquea (Detener libera el chat), pero un
   refresco de datasets con datasets del Agente en esas condiciones tarda
   lo mismo. Arreglo propuesto: en `rphttpclientfpc`, crear el socket con una
   subclase de `TInetSocket` cuyo `CheckSocketConnectTimeout` (virtual) pase
   también el conjunto de excepciones a `select` en Windows; como
   `TFPCustomHTTPClient.FSocket` es privado, hay que redefinir
   `ConnectToServer` en una subclase de `TFPHTTPClient`, o conectar antes
   con un socket propio.
2. **VCL, `rpchatdialogvcl.pas:667-682` y `781-782`**
   (`BuildDesignExpressionContextJson`): con `ARpAlias = nil` asigna al
   evaluador del informe un alias que libera al final; el evaluador queda
   apuntando a memoria liberada. Hoy `rpmdfmainvcl` pasa siempre `RpAlias1`,
   así que no se produce. Arreglo: guardar el `Rpalias` anterior del
   evaluador y restaurarlo en el `finally` cuando el alias es propio (lo que
   hace el port).
3. **VCL, `rpchatdialogvcl.pas:2425` y `1794-1798`**: el indicador de
   cancelación es un campo compartido del formulario que `SendExpressionPrompt`
   pone a False; un prompt enviado tras Detener y antes de que el hilo
   anterior vea el indicador hace que la petición detenida siga y publique
   su resultado. Además, tras Detener el chat sigue ocupado hasta que llegan
   datos. Arreglo: un indicador por petición (objeto con contador de
   referencias) y terminar el estado ocupado en `StopExpressionRequest`.
4. **VCL, `rpchatdialogvcl.pas:2455-2503`**: el hilo de trabajo llama a
   `ValidateExpressionText`, que cambia y evalúa `evaluator.Expression` del
   formulario desde el hilo mientras el hilo principal puede usarlo
   (Comprobar sintaxis, Mostrar resultado). Arreglo: validar con
   `TThread.Synchronize`.
5. **VCL, `rpchatdialogvcl.pas:1722` y `1736-1739`**: `Values[...].Value` de
   un `null` JSON da `'null'` en Delphi; si el Hub devolviera
   `"errorMessage": null` se mostraría "null" como error. Arreglo: tratar
   `TJSONNull` como vacío.
6. **VCL, `rpchatdialogvcl.pas:896`** (`ConfigureReportRefresh`): reinicia
   `FRefreshVersion` a 0 aunque haya un refresco en curso; el mensaje del
   refresco anterior puede coincidir con la versión del siguiente. El port
   solo incrementa la versión (y espera al refresco en curso).

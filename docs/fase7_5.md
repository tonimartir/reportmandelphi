# Fase 7.5: asistente de diseño con IA en el diseñador LCL

El panel de IA de la ventana del diseñador LCL (`design_lcl/rpmdfmainlcl`,
7.2) ya tenía la tarjeta de cuenta, el modelo, el esquema y el chat común
(`TFRpChatFrame`), pero el chat respondía que no había asistente. En 7.5 se
conecta el asistente de diseño, con el mismo comportamiento que el diseñador
VCL (`rpmdfmainvcl`): el usuario describe un cambio, el servidor
(`api.reportman.es`) devuelve el informe modificado y el diseñador lo carga.

## Qué hace

| Paso | VCL (`rpmdfmainvcl`) | LCL (`rpmdfmainlcl`) |
|---|---|---|
| Petición | `BuildDesignChatRequest`: XML del informe, modo, nivel, idioma, esquema/base de datos del Hub, API key, agente local | Igual (`BuildDesignChatRequest`, pública) |
| Contexto de datos | Hilo con `PrepareLiveContext` + esquema de los datasets del Agente; `BuildDesignExpressionContextJson` (de `rpchatdialogvcl`) | Igual, con el port de `rpexpredlglcl` (7.4) compartido con el asistente de expresiones; el hilo abre los datasets de una **copia** del informe |
| Datasets que no abren | Pregunta si enviar igualmente | Igual (`ConfirmDesignPromptWithDatasetErrors`) |
| Preproceso SQL | `BuildPreprocessSqlContextRequest` / `ApplyPreprocessSqlContextResult`: explicación de las SQL sin explicar | Igual; el frame reconstruye la petición con las explicaciones |
| Inferencia | `BeginBlockChanges`/`EndBlockChanges`; un cambio del informe pregunta si cancelar la inferencia | Igual (`ReportBlockChanges`, texto traducible) |
| Resultado | `report.Clear` + `LoadFromStream` en el mismo objeto; refresca diseño, estructura e historial | Igual (mismo objeto: el anfitrión de `TRpDesignerLCL` lo conserva), sin fugas y validado antes |
| Deshacer | El historial viaja en el XML (BINCUE) y vuelve con las operaciones del cambio | Igual (ver abajo) |
| Stop | `StopDesignChatRequest`: cancela, invalida el refresco de contexto, desbloquea | Igual |
| Actualizar | Botón *Refresh* del chat: refresca el contexto | Igual |
| Mensaje inicial | "Describe report changes here or ask for assistance. Any change can be undone." | Igual, traducible (id 1640) |
| Ver > Chat IA | `Preferences/ShowAIChat` del fichero `repmand` | Igual (mismo fichero y clave, compartido con el VCL) |

## Deshacer un cambio de la IA

El diseñador Delphi guarda el historial de deshacer dentro del XML del
informe (propiedad `BINCUE`, el JSON de `TUndoCue`, `rpxmlstream`). La
petición de diseño envía ese XML; el servidor añade las operaciones de su
cambio al historial y devuelve el documento con el `BINCUE` actualizado.
Al recargarlo, el historial vuelve con ellas: Ctrl+Z deshace el cambio de la
IA paso a paso y el historial anterior sigue intacto.

En FPC ese código estaba fuera (`{$IFNDEF FPC}`): el paquete del motor no
puede usar la unidad de deshacer del diseñador. En master (a7855a1)
`rpxmlstream` escribe y lee `BINCUE` a través de dos ganchos
(`RpUndoCueToJson`, `RpUndoCueFromJson`); en 7.5 los registra
`design_lcl/rpmdundocuelcl` (sección `initialization`):

- **Escritura**: `ToJSON` del historial, o nada si está vacío (como Delphi).
- **Lectura**: si el informe no tiene historial se crea (como Delphi); si lo
  tiene (el diseñador recargando el documento de la IA en su informe) se
  sustituye su contenido en el mismo objeto, que es el que usan el
  diseñador y el panel de historial.
- **JSON**: las mismas claves y tipos que el `TUndoCue` de Delphi
  (`rpmdundocue`). Diferencias sin efecto: Delphi escapa el texto no ASCII
  (secuencias de escape Unicode de JSON) y el LCL lo escribe en UTF-8; los
  números reales de fpjson van
  en notación exponencial. Cada uno lee lo que escribe el otro (probado con
  el `BINCUE` de `repsamples/debugagentexample.rep` y con escapes, nulos,
  booleanos y reales). El `ToJSON` del LCL pasa a ser compacto, como el de
  Delphi (viaja en hexadecimal dentro del XML).

Al aplicar el resultado (`ApplyModifiedReportDocument`):

1. El documento se carga antes en un informe temporal: si no carga, el
   informe no cambia (el VCL lo borraba antes de cargar) y el chat muestra
   el error.
2. Se recarga en el mismo `TRpReport` sin las fugas de `TRpReport.Clear`
   (secciones y componentes se liberan). Los ficheros incrustados no se
   duplican; si el documento no trae ninguno, se conservan los del informe.
3. Si el `BINCUE` devuelto añade operaciones sobre el historial enviado,
   `TUndoCue.HistoryExtendedFrom` descarta la rama de rehacer y un punto
   guardado que quedara en ella: el informe queda modificado y deshacer
   hasta el estado guardado lo deja sin modificar.
4. Si el documento no trae las operaciones de su cambio, el cambio no se
   puede deshacer: el informe queda modificado hasta guardarlo
   (`MarkExternalChange`) y el historial anterior se conserva (como el VCL).

El diseñador LCL también conserva ahora el historial de los informes que
abre (`OpenReportFile`, librería), como el VCL: antes lo borraba. Solo el
formato XML lo guarda (en texto y binario no hay `BINCUE`, igual que en
Delphi).

## Diferencias con el VCL (decisiones)

- **Contexto sobre una copia.** El VCL abre los datasets del informe que se
  está diseñando desde un hilo mientras el usuario puede seguir editándolo.
  El LCL los abre en una copia (flujo binario, sin los ficheros
  incrustados): el informe del diseñador no se toca desde el hilo.
- **Validación previa del documento** (punto 1 de arriba).
- **Prompt validado.** El VCL solo lo olvida al parar (su
  `WMHandleDesignChatPayload`, que lo olvidaba al terminar, no se llama
  nunca), así que repetir el mismo texto no refrescaba el contexto. El LCL
  lo olvida al empezar la inferencia.
- **Panel oculto.** Con Ver > Chat IA desactivado el panel no hace
  peticiones al Hub hasta que se muestra. La preferencia se guarda al
  cambiarla (el VCL guarda todas sus preferencias al cerrar).
- **Conexiones inexistentes.** `TRpDatabaseInfoList.ItemByName` lanza una
  excepción si no encuentra la conexión; el código del VCL espera `nil`. El
  LCL la busca con `IndexOf` (en `rpmdfmainlcl` y, tras la fusión con 7.4,
  también en `rpexpredlglcl`): un dataset sin conexión válida ya no rompe el
  contexto ni la petición.
- **Panel de historial.** Sus botones Deshacer/Rehacer (ocultos en el VCL)
  preguntan también si cancelar una inferencia en curso, en lugar de fallar.
- La barra de progreso del contexto va en el chat y el texto en la barra de
  estado (sin barra marquee dentro de la barra de estado).
- No incluido: el asistente de informe nuevo del VCL con un prompt inicial
  (`NewModernReportWizard`), que no existe en el diseñador LCL.

## Textos

Ids nuevos 1640–1651 con `TranslateStr` y texto por omisión en inglés; las
traducciones (es, ca, cs, de, fr, it, lt, pt) están en
`docs/i18n/fase7_5_ids.txt` (UTF-8, separado por tabuladores:
`id en es ca cs de fr it lt pt`) para añadirlas a los `reportmanres.*`. Se
reutilizan los ids del chat de 7.2 (1536 "Generation stopped.", 1539, 1540,
1149 "Refresh").

## Pruebas

- `tests/fpc/LclAIChatTest/uaidesigntests.pas` (`RunAIDesignTests`, tras
  las de 7.2, 7.4 y 7.3), con un Hub simulado propio sobre `ufakeserver`:
  - prompt, contexto, petición (XML con `BINCUE`, instrucciones, contexto) y
    diseño transmitido y aplicado: el informe (mismo objeto, mismo
    historial) tiene el título en la cabecera y el componente movido, está
    modificado, y el diseño, el árbol y el historial lo muestran;
  - Ctrl+Z / Ctrl+Y deshacen y rehacen el cambio paso a paso, y después el
    historial manual anterior se deshace hasta el informe nuevo (sin
    modificar);
  - preproceso SQL (orden de las peticiones, explicación en la petición y en
    el informe; un segundo prompt ya no preprocesa);
  - datasets que no abren: pregunta, cancelación y envío;
  - edición bloqueada durante la inferencia (un cambio o un deshacer
    rechazado no toca el modelo; aceptado, cancela la inferencia);
  - Stop de la inferencia (rápido, sin trozos ni aplicación posteriores) y
    del refresco de contexto;
  - `ShowAIChat` guardado en el fichero de preferencias, leído por una
    ventana nueva y sin peticiones al Hub mientras el panel está oculto.
  Capturas `design_before`, `design_after` y `design_no_ai_panel`.
- `tests/fpc/LclDesignerTest/uregressiontests.pas` (al final): JSON del
  historial compatible con Delphi, historial en el XML del informe,
  `HistoryExtendedFrom`, e historial conservado por el diseñador al abrir
  el `.rep` de Delphi y al guardar y reabrir (XML sí, texto no).

Resultados (tras fusionar 7.3 y 7.4): Windows, `LclAIChatTest` 739
comprobaciones (las cuatro series) sin fugas, `LclDesignerTest --selftest`,
`LclSnapshotTest` 19/19, `HubClientTest` 469 y el diseñador autónomo; WSL
(Lazarus 3.0, GTK2), `LclAIChatTest` 699 sin fugas y `--selftest`; Docker
(`build-linux.ps1 -SkipImage`), `LclAIChatTest` 705 en Qt6 y GTK2 sin
fugas, `--selftest` en los dos, lintian sin errores y las 15 pruebas en
máquinas limpias.

## Encontrado en código común o VCL (sin cambiar)

1. `TRpBaseReport.Clear` (`rpbasereport.pas:1018`) quita los componentes
   del informe con `RemoveComponent` sin liberarlos (fuga de todas las
   secciones y componentes cada vez que el VCL aplica un cambio de la IA,
   `rpmdfmainvcl.pas:3544`) y no vacía `EmbeddedFiles`, que la lectura XML
   añade: se duplican. Arreglo: liberar las secciones de cada subinforme
   (`FreeSections`) antes de `FreeSubreports`, liberar los componentes que
   queden y vaciar (liberando) `EmbeddedFiles`.
2. `TRpDatabaseInfoList.ItemByName` (`rpdatainfo.pas:6097`) lanza una
   excepción; esperan `nil` `rpmdfmainvcl.pas:1096` y `:3273`,
   `rpchatdialogvcl.pas:441`, `:712` y `:1918`. Un dataset cuya conexión no
   existe hace fallar el asistente. Arreglo: `IndexOf` + `Items[]`.
3. `rpmdfmainvcl.pas:3572` `WMHandleDesignChatPayload` es código muerto
   (nadie envía `WM_USER + 206`); por eso `FDesignChatValidatedPrompt` no se
   limpia tras una petición.
4. Solo FPC: `TRpBaseReport.ReadEmbeddedFiles`/`WriteEmbeddedFiles`
   (`rpbasereport.pas:2051-2069` y `2109-2126`) pasan una variable `TBytes` a
   `TStream.Read/Write`, que en FPC no tiene sobrecarga `TBytes`: se lee y
   escribe sobre la propia variable (corrupción de memoria al cargar y datos
   basura al guardar un `.rep` con ficheros incrustados en formato
   texto/binario). Arreglo válido para los dos compiladores:
   `if ssize > 0 then memStream.Read(bytes[0], ssize)` (y lo mismo con
   `Write`).
5. `TRpBaseReport.Destroy` (`rpbasereport.pas:790-843`) no libera los
   `TEmbeddedFile` de `EmbeddedFiles`: fuga de cada informe con ficheros
   incrustados (el diseñador LCL los libera en su informe temporal de
   validación). Arreglo: liberarlos en el destructor.
6. `rpchatdialogvcl.pas:671-683`: con `ARpAlias = nil`,
   `BuildDesignExpressionContextJson` deja el evaluador del informe
   apuntando a un alias que libera al terminar (el diseñador VCL pasa
   `RpAlias1`, así que no le afecta).

## Otros cambios

- `build/linux/test-packages.sh`: con `pipefail`, `ldconfig -p | grep -q`
  fallaba al azar (grep cierra la tubería y ldconfig acaba con SIGPIPE): la
  prueba de debian-12 deb dijo "falta libsqlite3.so.0" con la librería
  instalada. Ahora grep lee toda la salida.
- `LclAIChatTest` y `LclDesignerTest` usan su propio fichero de
  preferencias (`RpDesignerLCLConfigFile`), no el del usuario.

## Para integrar

- Añadir los ids 1640–1651 a los `reportmanres.*`.

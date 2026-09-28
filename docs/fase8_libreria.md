# Fase 8: biblioteca de informes en el diseñador LCL

Port al diseñador Lazarus de lo que le faltaba de las bibliotecas de informes
(informes guardados en una base de datos, tablas `REPMAN_REPORTS` y
`REPMAN_GROUPS`) del diseñador Delphi: el editor de conexiones de biblioteca
(`rpeditconnvcl`), el árbol de la biblioteca con sus acciones
(`rpmdftreevcl`) y el menú *Archivo > Bibliotecas* (configurar, abrir de,
guardar en). Antes el LCL solo abría un informe de una biblioteca ya
configurada y lo guardaba de vuelta en el mismo sitio, con un árbol de solo
lectura.

Solo cambian unidades LCL; las unidades compartidas de la raíz y las VCL no se
tocan (lo encontrado en ellas está al final, sin corregir).

## Qué se hizo

### Unidades

| Unidad | Cambio |
|---|---|
| `design_lcl/rpeditconnlcl.pas` (nueva) | Port de `TFRpEditConVCL`: `TFRpEditConLCL` y `ShowModifyConnections` |
| `design_lcl/rpmdftreelcl.pas` (nueva) | Port de `TFRpDBTreeVCL`: `TFRpDBTreeLCL` (un `TPanel` construido en código, sin `.lfm`), sus iconos y `RpLibraryCommit` |
| `design_lcl/rpmdfopenliblcl.pas` | El diálogo de biblioteca aloja el árbol editable; `TRpLibNodeInfo` pasa a `rpmdftreelcl` (alias) y se mantiene la API anterior (`ATree`, `EditTree`, `SelectedNodeReportName`) |
| `design_lcl/rpmdfmainlcl.pas` | *Archivo > Bibliotecas...* con *Configurar bibliotecas*, *Abrir de biblioteca* y *Guardar en biblioteca*; `RpDesignerLCLLibConfigFile`; commit tras leer y guardar en la biblioteca |
| `packages/fpc_lcl/reportman_designlcl.lpk` / `.pas`, `build/opm/opm_files.txt` | Las dos unidades nuevas |
| `tests/fpc/LclDesignerTest/ulibrarytests.pas` (nueva) | Pruebas de comportamiento (`RunLibraryTests`), llamadas desde `umainform.pas` tras las de regresión |

### Editor de conexiones de biblioteca (`rpeditconnlcl`)

Como el VCL: lista de conexiones a la izquierda y, de la seleccionada,
*Cargar parámetros*, *Cargar par. controlador*, *Preguntar contraseña*,
controlador (`GetRpDatabaseDrivers`, los once de siempre: el fichero se
comparte con el diseñador Delphi), tabla de informes, campo del informe, campo
de búsqueda, tabla de grupos y cadena ADO. Barra con *Nueva conexión*,
*Eliminar conexión* y *Renombrar* (iconos del diálogo de datos) y los botones
*Configurar*, *Crear biblioteca*, *Comprobar conexión* y *Explorar
biblioteca*. Se edita una copia de las conexiones; *Aceptar* la devuelve.

- *Comprobar conexión*: conecta, desconecta y muestra `SRpConnectionOk`.
- *Crear biblioteca*: `TRpDatabaseInfoItem.CreateLibrary` con las tablas y
  campos de la conexión, y commit (si no, las tablas desaparecen al liberar la
  copia).
- *Explorar biblioteca*: el diálogo de biblioteca sobre la copia, con el árbol
  editable (como el VCL, los cambios en la base de datos son inmediatos
  aunque luego se cancele el editor).
- *Configurar* (`ShowDBXConfig`): el diálogo de configuración DBX lo porta
  otro agente (`rpdbxconfiglcl`); el botón queda sin acción con el comentario
  `// Wired to rpdbxconfiglcl.ShowDBXConfig when merged`.
- La cadena ADO se muestra con la contraseña enmascarada (como el VCL) pero es
  de solo lectura: ADO no existe en FPC y el VCL, al editarla, guarda la
  cadena enmascarada. El botón *Build...* (`PromptDataSource`) no se porta.
- Las funciones sin preguntas (`NewConnection`, `DeleteConnection`,
  `RenameConnection`, `TestConnection`, `CreateLibrary`) son lo que hacen los
  botones tras preguntar al usuario.

El diseñador (*Configurar bibliotecas*, VCL `ALibrariesExecute`) edita sus
conexiones de biblioteca y, si se acepta, las guarda en `repmandlib` (el mismo
fichero del diseñador Delphi). `RpDesignerLCLLibConfigFile` permite otro
fichero (las pruebas usan uno temporal).

### Árbol de la biblioteca (`rpmdftreelcl`)

`EditTree(dbitem, readonly)` lee grupos e informes (sin los blobs) y construye
el árbol como antes (raíz con el alias, grupos en orden de la tabla, informes
por nombre, informes de grupos inexistentes en la raíz, ciclos cortados). Sin
`readonly` (el diálogo de biblioteca, como el VCL) las acciones son:

| Acción (VCL) | LCL |
|---|---|
| Nuevo grupo (`ANewFolder`) | En el grupo seleccionado o en el del informe seleccionado; código `MAX+1` |
| Nuevo informe (`ANew`) | Informe vacío (`CreateNew`) en el grupo seleccionado o en el del informe seleccionado |
| Eliminar (`ADelete`) | Confirmación; un grupo con informes o subgrupos no se elimina (`SRpExistReportInThisGroup`, `SRpGroupParent`) |
| Renombrar (menú contextual) | Grupo o informe |
| Arrastrar y soltar | Un informe pasa al grupo del destino; un grupo pasa a ser hijo del grupo destino (o del grupo del informe destino). Se expande el grupo sobre el que se mantiene el nodo |
| Buscar (`AFind` + caja) | Desde el nodo siguiente al seleccionado, sin distinguir mayúsculas; Intro en la caja también busca |
| Vista previa, imprimir, parámetros | Con `TLCLReport` (runtime LCL) en lugar de `TVCLReport`; activos solo con un informe seleccionado |
| Configurar impresora | `TLCLReport.PrinterSetup` |
| Exportar a carpeta | Un fichero `.rep` por informe en un árbol de carpetas como los grupos; progreso y *Cancelar* como el VCL |

Cada cambio se hace en la base de datos al momento y se confirma
(`RpLibraryCommit`, ver abajo). Los métodos sin preguntas (`NewReport`,
`NewGroup`, `DeleteNode`, `RenameNode`, `CanMoveNode`/`MoveNode`, `FindNext`,
`ExportToFolder`, `LoadSelectedReport`) son públicos. Los iconos son los de
la VCL (`ImageCollection1` de `rpmdftreevcl.dfm`, 19×19).

### Guardar en biblioteca y abrir de biblioteca

*Guardar en biblioteca* (VCL `ASaveToExecute`): el diálogo de biblioteca, donde
se elige un informe o se crea uno con *Nuevo informe*; el informe se guarda
sobre él y pasa a ser el documento (título `BIBLIOTECA->INFORME`, *Guardar*
vuelve a guardar allí). Si falla, el documento sigue siendo el anterior.
*Abrir de biblioteca* ya existía; ahora está en el submenú y su diálogo tiene el
árbol editable. En modo alojado (`TRpDesignerLCL`) el submenú se oculta.

### Transacciones (`RpLibraryCommit`)

En FPC el controlador FireDac se implementa con SQLdb/SQLite: `Connect` abre
una transacción que `DoCommit` no confirma y que se deshace al liberar la
conexión (ver hallazgo 1). El LCL confirma tras cada cambio del árbol, tras
crear la biblioteca y tras guardar un informe, y también tras leer (una
transacción de lectura abierta mantiene el bloqueo compartido de SQLite y otra
conexión, por ejemplo la copia del editor de conexiones, no podría escribir).
Para Zeos no hace nada (autocommit).

## Paridad con el VCL

| Función | LCL |
|---|---|
| Editor de conexiones: nueva, eliminar, renombrar, parámetros, controlador, tablas y campos | Igual |
| Comprobar conexión, crear biblioteca, explorar biblioteca | Igual |
| Configuración DBX | Pendiente de `rpdbxconfiglcl` (botón sin acción) |
| Cadena ADO | Solo lectura; sin *Build...* |
| Árbol: nuevo grupo/informe, eliminar, renombrar, mover, buscar, exportar, vista previa, imprimir, parámetros, impresora | Igual |
| Archivo > Bibliotecas (configurar, abrir de, guardar en) | Igual (mismos ids de texto) |
| Barra de desplazamiento automático al arrastrar (`timerscroll1`) | La del propio `TTreeView` de la LCL |
| `FillTree(adir)` / `FillTree(alist)` del frame VCL (árbol de carpetas) | No se portan: el diálogo de biblioteca no los usa |

Diferencias (arreglos de fallos del VCL, ver la lista del final):

- *Nuevo informe* con un informe seleccionado lo pone en el grupo de ese
  informe (el VCL lo cuelga del nodo del informe).
- Un nombre de informe repetido (nuevo o renombrado) da un mensaje propio (id
  1820); el VCL depende de la clave primaria de la tabla.
- La raíz (la biblioteca) no se renombra, elimina ni arrastra; un grupo nunca
  se mueve dentro de su propia rama.
- Mover un informe usa el campo de búsqueda de la conexión (el VCL,
  `REPORT_NAME`/`NOMBRE`).
- Cancelar el nombre de una conexión nueva o renombrada no hace nada (el VCL
  crea o deja una conexión sin nombre); renombrar a un nombre existente da
  error; *Comprobar conexión* sin conexión da un mensaje.
- Cambiar el controlador desconecta la conexión.
- Exportar a carpeta pide la carpeta con `TSelectDirectoryDialog` (el VCL, con
  un diálogo de guardar); los nombres de fichero y carpeta quitan también los
  caracteres que Windows no admite.
- Una biblioteca con el controlador Reportman AI Agent da "controlador no
  soportado" en lugar de un acceso ilegal (hallazgo 3).
- Todo se confirma al momento (en Delphi FireDAC se confirma al desconectar).

## Diseño

- Diálogos para una pantalla de 800×600: el editor de conexiones mide
  640×460 y sus editores van en un `TScrollBox`; el de biblioteca, 520×450.
  Botones de tamaño fijo (sin `AutoSize` alineados a los lados), columna de
  etiquetas del ancho de la traducción más larga y editores anclados al borde
  derecho con `AnchorSide`.
- Textos con los mismos ids que el VCL (1080/1081, 1102–1105, 1115–1123,
  143–147, 151, 512, 748, `SRpConfigLib`, `SRpOpenFrom`, `SRpSaveTo`,
  `SRpNewFolder`, `SRpNewReport`, `SRpDeleteSelection`, `SRpSearchReport`,
  `SRpExportFolder`, `SRpRename`...). Un texto nuevo: 1820 "The report already
  exists in the library", con sus traducciones en
  `docs/i18n/fase8_libreria_ids.txt` (pendiente de pasar a
  `repman/reportmanres.*` y `REPORTMANRES.RES`).

## Pruebas (`tests/fpc/LclDesignerTest/ulibrarytests.pas`)

Contra bibliotecas SQLite en una carpeta temporal (sin servidor): durante las
pruebas el directorio actual es esa carpeta, con su `dbxconnections.ini` (una
conexión FireDac→SQLdb y otra Zeos, las dos SQLite) y un `repmandlib`
temporal. Los diálogos modales (editor de conexiones, diálogo de biblioteca,
cajas de mensaje y de texto) se contestan con un guion: una cola de diálogos
esperados que se atienden al mostrarse. El manejador se instala después de la
guarda de `uregressiontests`, así que actúa primero y marca los formularios
con su etiqueta. Las comprobaciones de la base de datos se hacen con una
conexión SQLite independiente, que solo ve lo confirmado.

- **Editor de conexiones** (por el menú): submenú y sus tres entradas, oculto
  en modo alojado; nueva conexión con nombre pedido (mayúsculas, valores por
  defecto), parámetros, controlador y tabla guardados en la conexión,
  *Comprobar conexión* (mensaje), *Crear biblioteca* (tablas confirmadas),
  *Explorar biblioteca* (árbol de la copia), *Configurar* sin diálogo, nombre
  repetido, entrada cancelada, renombrar (y a un nombre existente), eliminar,
  conexión Zeos; *Aceptar* devuelve las conexiones al diseñador y las guarda
  en `repmandlib`; *Cancelar* no cambia nada; un diseñador nuevo las lee.
- **Árbol**: grupos nuevos (anidado, cancelado, código siguiente), informes
  nuevos (en el grupo, en el grupo de un informe seleccionado, blob válido,
  nombre repetido), acciones activas según el nodo, renombrar grupo (menú
  contextual) e informe (y a un nombre existente), eliminar un grupo con
  informes y con subgrupos (errores), mover informes (métodos y eventos de
  arrastre `OnDragOver`/`OnDragDrop` con el diálogo visible) y grupos (no a su
  rama ni a su padre; a la raíz), eliminar con confirmación (cancelada y
  aceptada), buscar (siguiente, sin más resultados, grupos), exportar a
  carpeta (ficheros por grupo iguales a los blobs), cargar el informe
  seleccionado para la vista previa, aceptar la selección, árbol de solo
  lectura; barra en una sola fila; y al final la biblioteca se lee de nuevo
  con otra conexión y está igual.
- **Guardar en y abrir de biblioteca** (por el menú): informe nuevo creado en
  el diálogo y guardado (documento, título, sin modificar, contenido en la
  base de datos), *Guardar* vuelve a guardar allí, un guardado fallido
  conserva el documento, lo guardado sigue tras cerrar el diseñador, *Abrir de
  biblioteca* con doble clic en otro diseñador.
- **Zeos**: grupo, informe y renombrar en una biblioteca Zeos; guardar el
  informe (queda guardado aunque la llamada falla por el hallazgo 2, que se
  registra como `[KNOWN_ROOT_BUG]`).
- **Reportman AI Agent**: `EditTree` da "controlador no soportado".
- Capturas opcionales con `RP_LIBTESTS_SHOTS=<carpeta>`:
  `connections_dialog.png` y `library_dialog.png`.

Resultados:

- Windows (win32): `LclDesignerTest --selftest` pasa, desde la raíz del
  repositorio y desde `tests/fpc/LclDesignerTest` (allí también corre la
  prueba de árbol de 5.5, que desde la raíz se omite porque existe
  `dbxconnections.ini`). `repmandesigner_lcl` compila.
- heaptrc: un programa aparte con solo `RunLibraryTests` (esperando a los
  hilos del panel de IA antes de salir) da 0 bloques sin liberar.
- Zip OPM: `make_opm_package.ps1 -Validate` correcto (los tres paquetes
  compilan desde el zip con las dos unidades nuevas).
- WSL (Lazarus 3.0, GTK2): paquetes y `LclDesignerTest --selftest` pasan (las
  pruebas usan `libsqlite3.so.0` si no está `libsqlite3.so`, como
  `rpdatainfo`; la prueba de árbol de 5.5 se sigue omitiendo allí por eso).

## Encontrado en unidades compartidas

Estado a 28-09-2026: todos corregidos (3823976, 96f61e5 y f58dfb4). 1 en
FPC (`DoCommit` confirma la transacción SQLdb); en Delphi FireDAC no se ha
tocado (confirma al desconectar, sin comprobar). El botón *Configurar*
abre `rpdbxconfiglcl.ShowDBXConfig`.


1. `rpdatainfo.pas:6185` (`TRpDatabaseInfoItem.DoCommit`) no tiene rama para
   la conexión SQLdb de FPC (controlador FireDac). `Connect`
   (`rpdatainfo.pas:2738`) inicia una transacción; `SaveReportStream`
   (`rpdatainfo.pas:5659`) hace el `UPDATE` y llama a `DoCommit`, que no la
   confirma; al liberar la conexión `TSQLTransaction` la deshace (su `Action`
   por defecto es `caRollback`). Comprobado: un `SaveReportStream` directo y
   liberar la lista de conexiones deja el informe como estaba. Además la
   transacción de lectura abierta bloquea a otras conexiones SQLite que
   escriban. Arreglo propuesto, solo FPC: en `DoCommit` confirmar
   `FSQLDBInternalTransaction` si está activa. En Delphi con FireDAC pasa
   algo parecido (la transacción de `Connect`, líneas 2614/2642, solo se
   confirma al desconectar), sin comprobar en Delphi.
2. `rpdatainfo.pas:6203` (`DoCommit`, rama `USEZEOS`): `TZConnection.Commit`
   lanza "Invalid operation in AutoCommit mode" en modo autocommit (el de
   Zeos por defecto), así que `SaveReportStream` falla después de guardar.
   Comprobado con Zeos+SQLite en FPC. Arreglo: confirmar solo si no está en
   autocommit.
3. `rpdatainfo.pas:4773` (`OpenDatasetFromSQL`) no tiene rama para `rpdbHttp`:
   la consulta queda a `nil` y `FSQLInternalQuery.Active:=True` es un acceso
   ilegal. Afecta a todas las funciones de biblioteca (árbol, abrir, guardar,
   crear) con una conexión Reportman AI Agent, también en el VCL. El LCL lo
   comprueba antes (`RpCheckLibraryDriver`).
4. `rpdatainfo.pas:5581` (`CreateLibrary`) no usa su parámetro `groupstable`:
   crea siempre `REPMAN_GROUPS`.
5. `rpbasereport.pas:956` (`SaveToStream`, formato texto, el de por defecto)
   usa `ObjectBinaryToText`, que en FPC 3.2.2 no admite `vaNull`
   (`classes.inc:1978`): un informe con un parámetro de valor nulo (todo
   parámetro nuevo: `Value` devuelve `Null`) no se puede guardar en texto
   ("Invalid property type from streamed property: 0"). Afecta a *Guardar*
   en fichero y en biblioteca del diseñador LCL. Comprobado; las pruebas dan
   valor a sus parámetros.

En unidades VCL de la raíz (el LCL no los tiene):

6. `rpmdftreevcl.pas:1392`: mover un informe usa `REPORT_NAME`/`NOMBRE` en
   lugar de `ReportSearchField`.
7. `rpmdftreevcl.pas:1038`: *Nuevo informe* con un informe seleccionado añade
   el nodo como hijo del informe.
8. `rpmdftreevcl.pas`: la raíz se puede renombrar, eliminar (si está vacía,
   `curnode.Free` borra todo el árbol) y arrastrar; soltar un grupo sobre un
   informe de su propia rama escribe un ciclo en `PARENT_GROUP` antes de que
   `MoveTo` falle.
9. `rpmdftreevcl.pas:513/554`: `lobjects.Remove(curnode.Data)` sin liberar el
   `TRpNodeInfo`; `rpmdftreevcl.pas:1186`: `aparam2` sin liberar al renombrar
   un grupo.
10. `rpeditconnvcl.pas:136/245`: cancelar el nombre crea una conexión sin
    nombre o deja la renombrada sin nombre; la comprobación de nombre
    repetido usa `>0` en lugar de `>=0`; `rpeditconnvcl.pas:362`: *Comprobar
    conexión* sin conexión seleccionada usa `Items[-1]`;
    `rpeditconnvcl.pas:228/291`: editar la cadena ADO guarda la contraseña
    enmascarada.

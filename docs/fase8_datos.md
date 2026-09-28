# Fase 8 (datos): conexiones y conjuntos de datos en el diseñador LCL

Port al diseñador Lazarus de lo que faltaba de la configuración de acceso a
datos del diseñador Delphi: el marco de conexiones (`rpmdfconnectionvcl`), el
de conjuntos de datos (`rpmdfdatasetsvcl`: *Mostrar datos*, página MyBase y
uniones), el diálogo del archivo de conexiones (`rpdbxconfigvcl`), la rejilla
de datos (`rpmdfsampledatavcl`) y la configuración de archivos de texto
(`rpmdfdatatextvcl`). Solo cambian unidades LCL, paquetes, pruebas y
documentación; las unidades compartidas de la raíz y las VCL no se tocan (lo
encontrado en ellas está al final, sin corregir).

## Qué se hizo

### Unidades

| Unidad | Cambio |
|---|---|
| `design_lcl/rpdbxconfiglcl.pas` | Nueva: `ShowDBXConfig(ConnectionsFile)`, port de `TFRpDBXConfigVCL`; además los controladores del build FPC, la prueba de conexión en un hilo y `RpCaptionWidth` |
| `design_lcl/rpmdfsampledatalcl.pas` | Nueva: `ShowDataset(Data)`, los registros en una rejilla |
| `design_lcl/rpmdfdatatextlcl.pas` | Nueva: `ShowDataTextConfig(filename, samplefile)` |
| `design_lcl/rpmdfdinfolcl.pas` | Pestañas de conexiones y de conjuntos de datos (abajo); el diálogo cabe en 800x600 |
| `packages/fpc_lcl/reportman_designlcl.lpk` / `.pas` | Las tres unidades nuevas |
| `build/opm/opm_files.txt` | Las tres unidades nuevas (sin `.lfm`: se construyen en código) |
| `tests/fpc/LclDesignerTest/udataconfigtests.pas` | Pruebas nuevas sin red (`RunDataConfigTests`, llamadas desde `umainform.pas` tras las de regresión) |
| `tests/fpc/LclAIChatTest/uaidatatests.pas` | Pruebas nuevas con un Hub simulado (`RunAIDataTests`, llamadas desde `LclAIChatTest.lpr`) |

### Pestaña de conexiones (port de `TFRpConnectionVCL`)

- **Controladores** (arriba, como `GDriver`/`MHelp`/`BConfig` del VCL): la
  lista muestra solo los que abren conexiones en el build FPC —MyBase, Zeos,
  FireDAC (solo SQLite: la capa FireDAC de FPC usa SQLdb) y Reportman AI
  Agent—, con los nombres de `GetRpDatabaseDrivers` y la descripción del VCL
  (la del Agent, que el VCL tenía fija en inglés, y la nota de SQLite tienen
  id). Por defecto está elegido Zeos, el controlador SQL general del build
  (el VCL elige dbExpress).
- **Configurar** abre `ShowDBXConfig`; al volver se relee el archivo de
  conexiones y se desconectan y recargan las conexiones de la copia de
  trabajo, como el VCL, y se reaplica el contexto del Hub del dataset.
- **Nueva conexión**: el botón crea una conexión con el controlador elegido
  en la lista (antes el LCL usaba el `.Net`, `rpdatadriver`, que no abre nada
  en FPC). Su flecha (el `PopAdd` del VCL) ofrece *Nuevo* y las conexiones del
  archivo de conexiones que abre el controlador elegido; al añadir una, su
  controlador sale de su `DriverName` (`ResolveFpcConnectionDriver`: FireDac y
  SQLite → FireDAC/SQLite, Reportman AI Agent → Agent, cualquier otro
  controlador dbExpress → Zeos, que toma `DriverName` como protocolo). Las
  entradas sin `DriverName` no se ofrecen (el VCL no ofrece ninguna para
  MyBase). Una conexión que ya está en el informe no se añade dos veces.
- **Combo del controlador**: solo los controladores del build; si el informe
  tiene una conexión con otro (ADO, IBX, BDE, .Net...), ese aparece solo para
  ella, marcado *(No disponible)*, y se conserva: abrir y aceptar un informe
  así no cambia nada.
- **Cargar parámetros / Cargar parámetros del controlador** (`LoadParams`,
  `LoadDriverParams`), en la copia de trabajo y en el deshacer como el resto.
- **Conectar** (prueba): en un hilo, sobre una copia de la conexión y de los
  parámetros del informe; el botón se desactiva mientras tanto y el resultado
  (`SRpConnectionOk` o el error del controlador) se muestra en un mensaje. Una
  respuesta de una sesión anterior del diálogo (cerrado o con otro informe) se
  descarta.

### Archivo de conexiones (`rpdbxconfiglcl`, port de `TFRpDBXConfigVCL`)

- Archivo de controladores y de conexiones; combo *Mostrar conexiones del
  controlador* (`[Todos]` y los controladores instalados); añadir (pide el
  nombre; con un controlador elegido), eliminar (pide confirmación),
  propiedades del controlador (bibliotecas), conectar y cerrar, con los
  textos y sugerencias del VCL.
- Parámetros de la entrada (`CreateParamsControls`): un editor por
  parámetro, combo cuando el archivo de controladores tiene una sección con
  su nombre (`Zeos TransIsolation`, `Database Protocol`...), `DriverName` de
  solo lectura, contraseña oculta; cada cambio se escribe en el archivo al
  momento, como el VCL.
- **Seleccionar conexión...** junto a `HubDatabaseId`: con el `ApiKey` de la
  entrada pide al Hub sus bases de datos en un hilo (`GetHubDatabases`); el
  botón queda en *Cargando...* y desactivado; la respuesta abre un menú con las
  bases y elegir una escribe su id. Sin API key, sin bases o con un error del
  Hub, el mensaje del VCL (con id). Cambiar de entrada o cerrar el diálogo
  descarta la respuesta.
- **Conectar**: las entradas del Agent se prueban contra el Hub
  (`api/agent/testconnection`, `ExecuteHttpConnectionTest` del VCL: el mensaje
  del Hub o *Agent Connection / Database Connection: Success/Fail* con el
  error); las demás, abriendo y cerrando la conexión con el controlador que da
  `ResolveFpcConnectionDriver`. Las dos en un hilo (el VCL, en el de la
  interfaz).
- `ShowDBXConfig(ConnectionsFile)` edita ese archivo (en el VCL el parámetro
  no llega al `TRpConnAdmin`; ver al final).

### Pestaña de conjuntos de datos (port de `TFRpDatasetsVCL`)

- **Mostrar datos** (barra de la pestaña, junto a *Parámetros*, que pasa a
  la barra como en el VCL para seguir disponible con la página MyBase): abre en
  un hilo una copia de las conexiones, conjuntos de datos y parámetros de la
  copia de trabajo (con maestros y uniones) y muestra el dataset con
  `rpmdfsampledatalcl`. Al cerrar la ventana la copia se cierra y se libera
  (el VCL deja abierto el dataset del diálogo). Los errores se muestran en un
  mensaje. El botón se desactiva sin conexión o mientras se abre.
- **Rejilla de registros** (`rpmdfsampledatalcl`): el VCL muestra un registro
  cada vez (Primero/Siguiente); aquí una rejilla con el número de registro y
  un campo por columna, leída hacia delante (los datasets pueden ser
  unidireccionales) en bloques de 1000 registros con *Más registros*; memos
  por su primera línea y binarios como `(BLOB)`.
- **Página MyBase** (en lugar de la de SQL cuando la conexión del dataset es
  MyBase, como las pestañas del VCL): archivo MyBase y de definición de
  campos con *Buscar...*, campos índice y campos maestros, y *Modificar...*
  (`ShowDataTextConfig` con la ruta de la conexión MyBase; solo se conecta
  una conexión MyBase, que no usa red).
- **Uniones** (dentro de la página MyBase, como en el VCL: solo los datasets
  MyBase las usan): combo con los demás datasets, `>` añade (con *Unión en
  paralelo* pide los campos comunes: `DS-CAMPOS`), `<` quita, *Agrupar
  uniones*. Un dataset no se añade dos veces.
- **Configuración de archivos de texto** (`rpmdfdatatextlcl`): las
  definiciones en un `TStringGrid` con las columnas del VCL (tipo y *Trim* con
  listas desplegables), nuevo campo tras el seleccionado, eliminar,
  separadores de registro, *Abrir* (guarda y lee el archivo de muestra con las
  definiciones en la pestaña *Datos*), *Aceptar* guarda y *Cancelar* (o
  cerrar, como en el VCL) descarta. Las filas sin nombre no se guardan; un
  tipo que no está en la lista se conserva por su número.

### Copias de trabajo, Cancelar y deshacer

Todo se edita en las copias de trabajo del diálogo (Cancelar lo descarta) y
Aceptar lo registra en un grupo de deshacer:

- La comparación de cambios incluye las propiedades MyBase y las uniones.
- `dataUnions` se graba en las operaciones de alta, baja y modificación
  (`ptStringArray`, que los dos deshacer, Delphi y LCL, ya aplican): deshacer
  y rehacer restauran las uniones, también las de un dataset borrado. El
  diálogo VCL no las graba.
- Las propiedades MyBase no son propiedades del deshacer (tampoco en el de
  Delphi, que la historia comparte en `BINCUE`): un cambio de ellas, o un
  alta o baja de un dataset que las tenga, marca el informe como modificado
  (`MarkExternalChange`), como la explicación de la auditoría SQL.

### Tamaño

El diálogo de datos pasa de 1060x720 fijos a no superar el área de trabajo
de la pantalla, y los de configuración de conexiones, texto y registros caben
en 800x600. En el de datos se corrigen los anclajes a la derecha calculados
antes del tamaño final (el combo del controlador y *Abrir al inicio* se salían
de la ventana), los botones de la barra del SQL toman el ancho de su texto y el
chat ocupa como mucho 2/5 del ancho. Botones de ancho fijo según el texto
(`RpCaptionWidth`), nunca `AutoSize` alineados a los lados.

## Diferencias con el VCL

| Función | LCL |
|---|---|
| Controladores | Solo los del build FPC; otro controlador de un informe se conserva, *(No disponible)* |
| Conexión nueva | Clic: nueva conexión con el controlador de la lista y nombre editable (el VCL pide el nombre); flecha: *Nuevo* y las del archivo |
| Controlador de una conexión del archivo | `ResolveFpcConnectionDriver` (el VCL: dbExpress para los desconocidos) |
| Conectar, Mostrar datos, descubrimiento del Hub, prueba del Agent | En hilos y sobre copias (el VCL, en el hilo de la interfaz y sobre el diálogo) |
| Mostrar datos | Rejilla por bloques; la copia se cierra al terminar (el VCL deja el dataset abierto) |
| Parámetros | En la barra de la pestaña (como el VCL); antes estaba en la barra del SQL |
| Deshacer | Graba las uniones; el VCL no |
| `ShowDBXConfig(ConnectionsFile)` | Edita ese archivo |
| Propiedades del controlador | Bibliotecas para todos (no hay editor de FireDAC) |
| *Buscar...* del archivo de definiciones | Filtro de archivos ini (el VCL deja el de todos los archivos) |
| Configuración de texto | `TStringGrid` con listas en vez de `TDBGrid` con campos de búsqueda; botón *Cancelar* |

## No portado

- Constructor de cadenas ADO, controladores .Net (`printreport.exe`),
  pestañas BDE (tabla, índices, rango, filtro): no existen en FPC.
- Editor de conexiones FireDAC (FireDAC no está en FPC) y reinicio del pool
  de canales WebRTC al cerrar el diálogo de conexiones (solo Windows/Delphi).
- Indicador de transporte WebRTC de la ventana de datos (`rpdctransportchip`,
  solo Windows/Delphi).

## Textos

`TranslateStr` con los ids nuevos 1670–1681 (lista con las nueve
traducciones en `docs/i18n/fase8_datos_ids.txt`; falta añadirlos a
`repman/reportmanres.*` y a `REPORTMANRES.RES`): descripción del Agent,
*Seleccionar conexión...*, *Cargando...*, los mensajes del descubrimiento,
los de la prueba del Agent, la nota de SQLite y *Más registros*. El resto
reutiliza los ids y constantes `SRp*` del VCL (143–177, 156, 164–168, 212, 355,
684, 735, 753, 1036, 1082–1096, 1101, 1440, 1441...). Los títulos de las
columnas de definiciones son los nombres de campo del VCL (sin traducir,
como allí).

## Pruebas

**`LclDesignerTest --selftest`** (`udataconfigtests.pas`, sin red, sin
ventanas modales: `Interactive = False` y `OnShowDataset`):

- Pestaña de conexiones: cuatro controladores, Zeos por defecto,
  descripciones; conexiones ADO y .Net conservadas (*No disponible*) y Aceptar
  sin cambios no graba nada; conexiones del archivo por controlador (FireDAC:
  SQLite y FireDac; Zeos: ZeosLib y MySQL; Agent; ninguna para MyBase);
  el desplegable se rellena sin acumular; añadir una conexión del archivo con
  su controlador, no dos veces; nueva conexión con el controlador de la lista;
  cargar parámetros en la copia, informe intacto hasta Aceptar; Aceptar graba
  tres altas y una modificación; deshacer y rehacer; Cancelar descarta.
- Conectar en un hilo: error de una conexión sin entrada, SQLite por la capa
  FireDAC correcta, respuesta de una sesión anterior descartada, diálogo
  destruido mientras prueba.
- Pestaña de conjuntos de datos: página MyBase o SQL según la conexión (y al
  cambiarla), propiedades MyBase y uniones (en paralelo con campos comunes,
  quitar, no duplicar, agrupar) en la copia, releídas al volver al dataset;
  Cancelar las descarta; Aceptar las aplica en una operación, deshacer y
  rehacer restauran las uniones y el informe sigue modificado por las
  propiedades MyBase; borrar un dataset con uniones y deshacer lo recupera con
  ellas.
- Mostrar datos en un hilo: registros de un archivo de texto con su archivo de
  definiciones (campos, tres registros en bloques de dos, fin), la copia de
  trabajo no se abre, un error (archivo inexistente) por el gancho y por
  mensaje, diálogo destruido mientras abre.
- Rejilla: 2500 registros en bloques de 1000, títulos, memo, número de
  registro, dataset cerrado.
- Configuración de texto: leer dos definiciones y el archivo de muestra,
  añadir una tras la seleccionada, guardar y releer (tipo, posición, tamaño,
  separador), *Abrir* con los tres registros, eliminar y guardar.
- Los cuatro diálogos caben en la pantalla.

**`LclAIChatTest`** (`uaidatatests.pas`, Hub simulado, heaptrc):

- Diálogo del archivo de conexiones sobre un archivo temporal: edita ese
  archivo, controladores, entradas por controlador, añadir sin controlador
  falla, añadir con los parámetros del controlador (sin bibliotecas),
  `DriverName` de solo lectura, combo para `Zeos TransIsolation`, contraseña
  oculta, cambios escritos al momento (también vacíos), releídos, eliminar.
- Descubrimiento del Hub: sin API key (mensaje, ninguna petición), botón
  *Cargando...*, menú con las dos bases, elegir una escribe `HubDatabaseId`,
  sin bases, error del Hub, petición sustituida por otra entrada (sin mensaje
  ni menú), diálogo destruido mientras busca.
- Conectar: mensaje del Hub, mensaje por defecto, fallo con el error del Hub,
  entrada Zeos sin servidor (error en el hilo), diálogo destruido mientras
  prueba.
- Diálogo de datos: conexiones del archivo para Zeos y para el Agent,
  Conectar con el controlador Agent (correcto y con una conexión sin entrada).
- Disposición a 780x560: controles dentro de sus paneles, página MyBase con
  sus uniones y página SQL (capturas `data_connections`, `data_mybase`,
  `data_sql` y `dbxconfig_entry` con `--shots`).

Resultados:

- Windows (win32): paquetes, `LclDesignerTest --selftest` correcto,
  `LclAIChatTest` 894 comprobaciones, 0 omitidas, heaptrc sin bloques sin
  liberar; el diseñador `repmandesigner_lcl` (Release) compila.
- WSL (Lazarus 3.0, GTK2): paquetes y proyectos compilan;
  `LclDesignerTest --selftest` correcto. `LclAIChatTest` completo se cortó en
  tres ejecuciones con "Fatal IO error 11 (Resource temporarily unavailable)
  on X server :0" de WSLg, cada vez en un grupo anterior distinto (cuenta,
  expresiones, diseño; ya visto en 7.3, sin relación con las pruebas); las
  pruebas de esta fase solas (`uaidatatests` con el mismo arenero y heaptrc)
  pasan: 95 comprobaciones, 0 bloques sin liberar.

## Encontrado en unidades compartidas y en el VCL (sin corregir)

1. `rpdatainfo.pas:2684` (FPC, `rpfiredac`): `driverId` toma `DriverName`
   antes que `DriverID`, así que una entrada FireDAC como las que escribe
   *Añadir* con el controlador FireDac (`DriverName=FireDac`,
   `DriverID=SQLite`) se rechaza en `:2711` con "Controlador de base de datos
   no soportado - FireDac (FPC): FIREDAC"; solo abren las entradas con
   `DriverName=SQLite`. Comprobado con un programa contra `reportman_rtl`.
   Arreglo: si `DriverName` es `FireDac` (o está vacío), usar `DriverID`.
2. `rpdatatext.pas:127-167/169-212`: `SaveFieldObjListToFile` no escribe
   `precision` ni `FillFieldObjList` la lee, pero `FillClientDatasetFromFile`
   la usa (`:447`, `:570`): los decimales de un campo moneda
   (`posbeginprecision` + `precision`) nunca se aplican desde un archivo
   guardado, y la columna PRECISION de los diálogos VCL y LCL se pierde al
   guardar.
3. `rpdatatext.pas:596-598` y `:610-612`: los campos hora y fecha-hora leen la
   hora, los minutos y los segundos en `yearpos`, `monthpos` y `yearpos` en
   lugar de `hourpos`, `minpos` y `secpos`.
4. `rpdbxconfigvcl.pas:290/297-321`: `ShowDBXConfig(ConnectionsFile)` asigna
   el archivo después de `FormCreate`, que ya ha leído el de `TRpConnAdmin`; el
   diálogo edita siempre el archivo por defecto y el parámetro solo llega a
   *Conectar*. Hoy solo se llama sin parámetro.
5. `rpmdfconnectionvcl.pas:281-377` (`GDriverClick`): no hay caso para FireDac
   (la lista de conexiones disponibles se queda con la del controlador
   anterior) y Zeos ofrece las entradas `Interbase`, no las `ZeosLib`.
6. `rpmdfdinfovcl.pas:493-564` (`RecordUndoChanges`): no graba `dataUnions`
   (el deshacer de Delphi la aplica): aceptar un cambio solo de uniones no deja
   operación y deshacer no lo revierte. Tampoco marca el informe por las
   propiedades MyBase.

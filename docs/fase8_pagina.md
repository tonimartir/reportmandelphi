# Fase 8: configurar página, configuración de impresoras e información del sistema (LCL)

Port al diseñador y al runtime Lazarus de lo que faltaba respecto al
diseñador Delphi en la configuración de página (`rppagesetupvcl`), el
diálogo de propiedades de un fichero incrustado (`rpmdfembeddedfile`), la
configuración de impresoras (`rpmdprintconfigvcl`) y la información del
sistema (`rpmdsysinfo`). Solo cambian unidades LCL; las unidades
compartidas de la raíz no se tocan (lo encontrado en ellas está al final,
sin corregir).

## Qué se hizo

### Unidades

| Unidad | Paquete | Cambio |
|---|---|---|
| `lcl/rppagesetuplcl.pas/.lfm` | `reportman_lcl` | Opciones PDF, ficheros incrustados y pestaña Metadatos; el botón Configurar impresoras abre la configuración |
| `lcl/rpmdfembeddedfilelcl.pas` (nueva) | `reportman_lcl` | Port de `rpmdfembeddedfile`: `AskEmbeddedFileData` |
| `lcl/rpmdprintconfiglcl.pas` (nueva) | `reportman_lcl` | Port de `rpmdprintconfigvcl`: `ShowPrintersConfiguration` |
| `design_lcl/rpmdsysinfolcl.pas` (nueva) | `reportman_designlcl` | Port de `rpmdsysinfo`: `ShowSysInfo` |
| `design_lcl/rpmdundocuelcl.pas` | `reportman_designlcl` | Propiedad de deshacer `embeddedFiles` (ficheros incrustados) |
| `design_lcl/rpmdfmainlcl.pas` | `reportman_designlcl` | La configuración de página registra también las opciones PDF, los metadatos y los ficheros incrustados en el deshacer |
| `design_lcl/rpmdcueviewlcl.pas` | `reportman_designlcl` | El detalle de una operación del historial corta los valores largos (200 caracteres) |
| `tests/fpc/LclDesignerTest/upagesetuptests.pas` (nueva) | — | Pruebas (`RunPageSetupTests`, llamada desde `umainform` tras las de regresión) |

Las unidades nuevas están en los `.lpk`/`.pas` de sus paquetes y en
`build/opm/opm_files.txt` (`make_opm_package.ps1 -RefreshFileList` confirma
que la lista está completa). `reportman_lcl` sigue sin depender del
diseñador: la configuración de página y la de impresoras son del runtime
(también las usan la vista previa y `TLCLReport.PageSetup`); la información
del sistema es del diseñador. **El menú no se toca**: el coordinador
conecta `ASysInfo` a `ShowSysInfo` en la ventana principal.

### Configurar página (`rppagesetuplcl`)

- **Opciones**: formato preferido (como antes), grupo *Opciones PDF*
  (conformidad PDF 1.4 / PDF A/3 y comprimido) y grupo *Ficheros
  incrustados* con Añadir, Eliminar y Modificar sobre una lista (nombre,
  tipo MIME, tamaño, relación, descripción y fechas), como `rppagesetupvcl`.
- **Metadatos** (pestaña nueva): autor, título, asunto, palabras clave,
  creador, productor, fechas de creación y modificación y contenido XMP.
- **Cancelar no cambia nada**: el diálogo trabaja sobre copias
  (`TEmbeddedFile.Clone`); con Aceptar el informe recibe las copias y libera
  las suyas. Todo valor tecleado se valida antes de tocar el informe (como
  ya hacía el LCL).
- **Añadir**: diálogo de abrir con los tipos del VCL (XML, PDF, imagen,
  otro) y el tipo MIME deducido de la extensión (`RpMimeTypeFromFileName`).
  Luego pide las propiedades (`AskEmbeddedFileData`); si se cancela, el
  fichero no se añade.
- **API**: `Report` (asignarlo lee las opciones; `ExecutePageSetup` lo hace
  antes de mostrar el diálogo), `AddEmbeddedFile`, `ModifyEmbeddedFile`,
  `DeleteEmbeddedFile`, `EmbeddedFileCount`/`EmbeddedFiles[]` y `Accepted`.
  Las usan las pruebas y permiten un anfitrión sin el diálogo de ficheros.
- Botones de ancho fijo (sin `AutoSize` alineados a un lado) y el mismo
  tamaño que antes (537×471): cabe en 800×600.

### Deshacer en el diseñador

`TFRpMainFLCL.BtnPageSetupClick` guardaba antes y comparaba después 29
propiedades del informe. Ahora son 40: se añaden `PDFConformance`,
`PDFCompressed`, `DocAuthor`, `DocTitle`, `DocSubject`, `DocKeywords`,
`DocCreator`, `DocProducer`, `DocCreationDate`, `DocModificationDate` y
`DocXMPContent` (nombres Delphi de `GetItemProperty`/`SetItemProperty`, que
el deshacer de Delphi también aplica).

Los ficheros incrustados no entran en el historial de deshacer (decisión
de la integración, 28-09-2026): el agente los registraba como una
propiedad `embeddedFiles` (la lista en JSON con el contenido en Base64),
pero los motores de deshacer de Delphi y de C# no la conocen (un historial
del LCL fallaba al deshacer en el VCL) y el historial viaja con cada
petición al asistente de diseño. Como en el VCL corregido, un cambio de los
ficheros marca el informe modificado (`MarkExternalChange`) y no se
deshace.

### Ficheros incrustados (`rpmdfembeddedfilelcl`)

`AskEmbeddedFileData(TEmbeddedFile): Boolean`, con los campos del VCL:
descripción, nombre, tipo MIME (desplegable editable con
`GetCommonMimeTypes`), relación (`AFRelationShip`) y fechas ISO 8601. Se
construye en código (`CreateNew`) con la columna de etiquetas medida sobre
el texto traducido y nunca más ancho que la pantalla.

### Configuración de impresoras (`rpmdprintconfiglcl`)

Mismo diálogo que el VCL: la lista de impresoras lógicas (las 18 con nombre
y *Printer1*…*Printer50*, claves `Printer0`…`Printer67`), la impresora
física de cada una (`Printer.Printers` de la LCL: Windows, CUPS en GTK2,
Qt en Qt6), fuentes de impresora, controlador de solo texto y conversión
OEM, desplazamiento izquierdo y superior, y los códigos de cortar papel y
abrir cajón. Mismas secciones y claves que lee `rptypes`
(`PrinterNames`, `PrinterOffsetX/Y`, `PrinterFonts`, `CutPaperOn`/`CutPaper`,
`OpenDrawerOn`/`OpenDrawer`, `PrinterEscapeStyle`/`PrinterDriver`,
`PrinterEscapeOem`).

Ficheros (`rpmdshfolder`):

| | Windows | Linux |
|---|---|---|
| Sistema | `%ProgramData%\reportman.ini` | `/etc/reportman` |
| Usuario | `%LOCALAPPDATA%\reportman.ini` | `~/.etc.reportman` |
| Usuario antiguo (solo lectura) | `%APPDATA%\reportman.ini` | `~/.reportman` |

- **Lectura**: los valores del fichero que usa el motor, con las reglas de
  `rptypes.CheckLoadedPrinterConfig` (`RpPrinterConfigFileName`): el de
  sistema si existe, si no el de usuario si existe, si no el antiguo.
- **Aceptar**: guarda en el fichero elegido (usuario o sistema, o la ruta
  escrita) y recarga la configuración del motor (`ReloadPrinterConfig`):
  `GetPrinterOffset`, `PrinterSelection` de `rplcldriver`, etc. leen los
  valores nuevos al momento. Si hay fichero de sistema el motor lee ese,
  como en el VCL.
- **Cancelar** no escribe nada. Ojo en FPC: `TMemIniFile` guarda sus cambios
  pendientes al liberarse (Delphi no); el diálogo quita el nombre del fichero
  antes de liberarlo.
- Mostrar una impresora no escribe nada (en el VCL los `OnClick`/`OnChange`
  de los controles escriben al cargar los valores).
- La ventana se ensancha si los textos traducidos de la derecha no caben
  (fuente de GTK2), sin pasar del ancho de la pantalla.

### Información del sistema (`rpmdsysinfolcl`)

`procedure ShowSysInfo`, autónomo (no depende de la ventana principal).
Dos páginas, *Impresora seleccionada* e *Información del sistema*, para
caber en 800×600 con la fuente de cualquier widgetset; valores en cuadros
de solo lectura (se pueden copiar).

- **Común** (unidad `Printers` de la LCL): nombre, estado, tipo (local o de
  red), resolución (`XDPI`×`YDPI`), orientación, copias por hardware
  (`CanRenderCopies`), papel (`PaperSize`: nombre y tamaño físico) y
  bandejas (`SupportedBins`).
- **Windows** (`{$IFDEF MSWINDOWS}`, WinSpool y un contexto de información
  `CreateIC`, sin tocar la impresora de la LCL): dispositivo, controlador,
  puerto, ubicación y estado (`GetPrinter` nivel 2), color, resolución,
  formulario y su tamaño (`DocumentProperties`, `GetForm`), copias máximas,
  intercalado y dúplex, bandejas con número y nombre
  (`DeviceCapabilities`), tamaño físico, tecnología y capacidades de líneas,
  polígonos, curvas, ráster y texto (`GetDeviceCaps`), como el VCL.
  Versión de Windows con `RtlGetVersion` (no depende del manifiesto).
- **Linux/Unix**: lo que CUPS sabe de la cola, cargando `libcups.so.2` en
  tiempo de ejecución (`cupsGetDests`/`cupsGetOption`), igual con GTK2 y
  Qt6: modelo (controlador), URI del dispositivo (puerto), descripción,
  ubicación, estado y motivos, y del `printer-type` color, dúplex, copias,
  intercalado y remota. Sin CUPS o sin impresoras se ve la parte común.
  Sistema: `uname` y `PRETTY_NAME` de `/etc/os-release`; en lugar del OEM
  ID, la arquitectura; procesadores de `/proc/cpuinfo` (el `GetCPUCount` de
  FPC 3.2.2 devuelve 1 fuera de Windows).
- **Sistema** (todos): pantalla y resolución, separadores de fecha, hora,
  decimales y miles, y el widgetset de la LCL.

## Diferencias con el VCL

| Función | VCL | LCL |
|---|---|---|
| Deshacer de los ficheros incrustados | No se registra; ahora marca el informe modificado (corregido) | Igual: no se registra, marca el informe modificado |
| Líneas por pulgada en el deshacer | `LinesPerInch` (corregido; antes el alias `linesPerInch`, 0/1) | `LinesPerInch` (valor exacto) |
| Tipo MIME al añadir | Según el filtro elegido (`image/jpg` para `.jpg`) | Según la extensión (`image/jpeg`); se puede cambiar en el diálogo |
| Relación en el diálogo del fichero | Nombres del enumerado (`PDF_AF_Data`) | Nombres del PDF (`Data`), como en la lista |
| Botones de la lista | Iconos | Texto; doble clic en la lista = Modificar |
| Configuración de impresoras: impresora por omisión | Guarda el texto traducido "Impresora por omisión" como nombre | Guarda cadena vacía (mismo efecto en `PrinterSelection`) |
| Configuración de impresoras: al mostrar una impresora | Escribe sus valores en el fichero | No escribe |
| Configuración de impresoras: lectura | Fichero de usuario nuevo aunque el motor lea el antiguo | El fichero que lee el motor |
| Controlador de texto desconocido | Deja el del anterior | En blanco |
| Información del sistema | Una ventana, etiquetas en negrita | Dos páginas, cuadros de solo lectura; ubicación, tipo de impresora y widgetset añadidos; en Linux, CUPS |
| Tamaño del formulario | Alto × ancho (intercambiados) | Ancho × alto |
| Nombre del procedimiento | `RpShowSystemInfo` | `ShowSysInfo` |

## Textos

Se reutilizan los ids y los `SRp*` del VCL (`TranslateStr` de los
`FormCreate`: 93, 94, 98, 100, 102, 106, 107, 113, 143, 741–746, 763–767,
976, 1058, 1061–1079, 1323; `SRpPDFOptions`, `SRpEmbeddedFiles`,
`SRpDocAuthor`…`SRpXMPMetadata`, `SRpMimetype`, `SRpRelationShip`, etc.).
Textos nuevos, ids 1800–1814 (`docs/i18n/fase8_pagina_ids.txt`, con las
nueve traducciones; falta añadirlos a los `reportmanres.*`): tipos de
fichero del diálogo de abrir (1800–1803, fijos en inglés en el VCL),
*Duplex*, *Separators*, *Decimal*, *Thousand* (fijos en inglés en el VCL),
y los nuevos *Location*, *Printer type*, *Local*, *Network*, *Widgetset*,
*Printing* y *Stopped*.

## Pruebas (`tests/fpc/LclDesignerTest/upagesetuptests.pas`)

Los diálogos modales se contestan desde un manejador de visibilidad de
formularios que va antes que el vigilante de `uregressiontests` (marca los
esperados con su `Tag`, así el vigilante sigue fallando con cualquier otro).
18 diálogos contestados:

- **Valor de deshacer**: sin ficheros, dos ficheros (UTF-8, contenido
  binario con bytes 0 y 255, fichero vacío), ida y vuelta, valores
  inválidos que no cambian el informe, a través del motor de deshacer y de
  su JSON (`BINCUE`), deshacer y rehacer, `ReadUndoPropertyValue`, tipos
  MIME.
- **Diálogo del fichero incrustado**: Aceptar aplica todos los campos (el
  contenido no cambia), Cancelar no cambia nada.
- **Configurar página** (métodos del diálogo): muestra los valores del
  informe, trabaja sobre copias, Cancelar no cambia nada, Aceptar aplica los
  metadatos, las opciones PDF y los ficheros (modificado, añadido, añadido y
  cancelado, eliminado); guardar y cargar en XML, binario y texto;
  Configurar impresoras abre la configuración (cancelada).
- **En el diseñador** (`BtnPageSetup`, diálogo modal con el de ficheros
  modal dentro): Cancelar no registra nada; Aceptar registra una operación
  con los metadatos, PDF y ficheros; deshacer y rehacer; un cambio solo de
  ficheros se registra y marca el informe; guardar como XML y abrir: los
  ficheros y el historial vuelven y se deshacen y rehacen en el informe
  cargado; eliminar y deshacer. La ventana del diseñador se abre sin el
  panel de IA (fichero de preferencias temporal): ningún hilo del Hub queda
  vivo al terminar el programa.
- **Configuración de impresoras**: 68 impresoras lógicas, fichero de
  usuario, mostrar una impresora no escribe, valores de *Printer50*
  (impresora física, desplazamientos, fuentes, cortar papel, abrir cajón,
  EPSON, sin OEM) que se mantienen al cambiar de impresora, Aceptar, y
  **`rptypes` lee lo guardado** (`GetPrinterOffset`, `GetDeviceFontsOption`,
  `PrinterRawOpEnabled`, `GetPrinterRawOp` decodificado,
  `GetPrinterEscapeStyleDriver`/`Option`, `GetPrinterEscapeOem`,
  `GetPrinterConfigName`); releer del fichero; Cancelar no escribe. El
  fichero de configuración del usuario se guarda antes y se restaura
  después, también si falla una comprobación. Si existe un fichero de
  sistema, se omite (el motor no leería el de usuario).
- **`ShowSysInfo`**: se abre, rellena sistema, procesadores, pantalla,
  widgetset y separadores (y en Windows con impresora, controlador,
  tecnología y capacidades) y se cierra.
- Todos los diálogos caben en 800×600.

Resultados:

- Windows (win32): `LclDesignerTest --selftest` correcto; con heaptrc, ningún
  bloque sin liberar de estas unidades (los 116 del conjunto completo son de
  otras pruebas y de `TRpChart`, ver abajo). Un ejecutable solo con estas
  pruebas y heaptrc: un bloque, el vigilante de `uregressiontests`.
  `PdfTest` y `LclSnapshotTest` (19/19) correctos.
- WSL (Lazarus 3.0, GTK2): paquetes, `LclDesignerTest --selftest`,
  `PdfTest` y `LclSnapshotTest` (19/19) correctos; las pruebas de esta fase
  con heaptrc, igual que en Windows. Sin impresoras en WSL: se prueba la
  ruta sin impresoras y la configuración en `~/.etc.reportman`.
- Capturas de los diálogos en win32 y GTK2 revisadas (textos que no caben,
  columnas cortadas).
- Zip OPM: `make_opm_package.ps1 -Validate` (Windows) y `-ValidateWsl`
  (GTK2) correctos: los tres paquetes compilan desde el zip.

## Encontrado en el VCL y en unidades compartidas

Estado a 28-09-2026: 1, 2, 3, 5 y 7 corregidos en Delphi (6752a42); 4
corregido en FPC con `rtl_fpc/rpstreamfpc` (96f61e5), que además corrige
la moneda truncada de FPC 3.2.2 en todos los formatos; 6 se deja (menor:
los valores solo se escriben al aceptar).


1. `rppagesetupvcl.pas:506-516` y `609-612`: los ficheros incrustados se
   sustituyen fuera del deshacer. Si solo cambian los ficheros no se añade
   ninguna operación, así que el informe no queda modificado
   (`report.Modified` solo cambia en `AddOperation`) y al cerrar el diseñador
   no se pregunta si guardar: el cambio se pierde. Además deshacer el resto
   de cambios no devuelve los ficheros.
2. `rppagesetupvcl.pas:390` y `527-528`: el deshacer usa el alias web
   `linesPerInch`, que `TRpBaseReport.GetItemProperty` convierte en 0 (600)
   o 1 (cualquier otro valor) y `SetItemProperty` en 600 u 800
   (`rpbasereport.pas:2886`, `3040`). Cambiar de 700 a 900 no se registra (ni
   marca el informe) y deshacer/rehacer 600→700 deja 800.
3. `rppagesetupvcl.pas`: fugas. La lista `EmbeddedFiles` (línea 233) no se
   libera nunca (no hay `OnDestroy`); con Cancelar no se liberan las copias
   de `ReadOptions` (703-707); Eliminar (779) quita la copia de la lista sin
   liberarla.
4. `rpbasereport.pas:956` (solo FPC): el formato de texto, el de omisión,
   corrompe los caracteres no ASCII de las propiedades publicadas `string`
   (`DocAuthor`…`DocXMPContent`, `ForcePaperName`...). FPC escribe el
   `AnsiString` UTF-8 como bytes (`vaString`) y `ObjectBinaryToText` (modo
   DFM) pasa cada byte a `#nnn`; al leer, `#195#177` son dos caracteres y
   "ñ" vuelve como "Ã±". Reproducción: `DocAuthor := 'Autor ñ'`,
   `StreamFormat := rpStreamText`, `SaveToStream` y `LoadFromStream`. XML y
   binario lo conservan; un informe de texto guardado por Delphi se lee bien
   en FPC. Arreglo posible bajo `{$IFDEF FPC}`: escribir esas propiedades
   como UTF-8 (`vaUTF8String`, lo que hace Delphi y que `ObjectBinaryToText`
   pasa a `#241`), o `ObjectBinaryToText(..., oteLFM)` (bytes UTF-8 sin
   escapar, que Delphi leería como ANSI).
5. `rpmdchart.pas:218`: `TRpChart` crea `FSeries` y no tiene destructor:
   cada gráfico liberado pierde su colección de series y sus elementos
   (Delphi y FPC). Es la mayoría de los bloques sin liberar de
   `LclDesignerTest` con heaptrc.
6. `rpmdprintconfigvcl.pas`: al mostrar una impresora (`LSelPrinterClick`,
   176-215) los `OnClick`/`OnChange` escriben en el fichero los valores
   mostrados; `ComboPrintersChange` (llamado en 194 y 296-300) guarda el
   texto traducido "Impresora por omisión" como nombre de impresora física;
   `ReadPrintersConfig` (221-231) lee el fichero de usuario nuevo aunque
   `rptypes` (1140-1153) esté leyendo el antiguo (`Obtainininameuserconfig`),
   así que guardar desde el diálogo en ese caso parte de una configuración
   vacía. Todo menor.
7. `rpmdsysinfo.pas:314-315` y `322-323`: el tamaño del formulario usa `cy`
   para el ancho y `cx` para el alto (se muestra alto × ancho).

## Pendiente

- ~~Conectar `ASysInfo` a `ShowSysInfo`~~ (Ayuda > Información del sistema).
- ~~Añadir los ids 1800–1814~~ (9c72238).

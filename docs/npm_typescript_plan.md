# Report Manager en npm: el motor en TypeScript

Fecha: 21-11-2026 (revisado el mismo día: sin lector DFM y sin WebAssembly). Estado:
**prototipo en marcha** (ver «Estado del prototipo»); quedan decisiones de la sección 9.

## Estado del prototipo (21-11-2026, noche)

Código en `typescript/` del repositorio C# (`tonimartir/reportman`, rama `main`; subido el
21-11-2026, y los últimos commits de la F1 en local sin push), unas 59.000 líneas de TypeScript sin
contar las pruebas, 1.427 pruebas. Paquetes `@reportman/*` en la versión `0.1.0-alpha.1`, listos
para publicar con la etiqueta `next` (estado de la F1 en la sección 5). Cada parte se ha portado entera y comprobado contra el motor C# con el
arnés `typescript/tools/golden-cs`; las partes que faltan fallan con un error claro («not supported
yet»), nunca con una salida distinta.

| Paquete | Qué hace ya | Comprobación contra C# |
|---|---|---|
| `@reportman/lib` | Modelo del diseñador sin Angular, lector XML del `.rep` (normal y zlib), rechazo claro del DFM | 22 informes: 0 diferencias en 23.382 valores |
| `@reportman/metafile` | Metafile, páginas, objetos, contrato `PrintOut` (dispositivo que mide) | (base de los demás) |
| `@reportman/text` | Las 14 fuentes estándar del PDF y el salto de línea del motor; fuentes TrueType/OpenType con fontkit (elección por nombre y estilo, métricas, fallback por cobertura, shaping), bidi con bidi-js, escrituras complejas, texto HTML | 1.395 medidas con fuentes estándar y 703 con TrueType (latín, árabe, hebreo, devanagari, tailandés, CJK, coreano) idénticas |
| `@reportman/pdf` | PDF con fuentes estándar: texto, formas, anotaciones, metadatos, Flate; imágenes JPEG, BMP, PNG y GIF (decodificadores propios que dan los mismos píxeles que SkiaSharp); fuentes incrustadas como subconjuntos (Type0/CID, ToUnicode); PDF/A-3B con archivos asociados | PDFs idénticos byte a byte con fuentes estándar; con fuentes incrustadas, todo igual salvo los bytes de los subconjuntos (fontkit, no hb-subset) y menos del 0,01 % de píxeles distintos |
| `@reportman/engine` | Expresiones (todas las funciones, formatos y culturas de .NET), datos con contrato de anfitrión, parámetros en dos pasos (`Describe`/`Apply` del servidor .NET), secciones, grupos, subinformes, maestro/detalle, columnas, dos pasadas, imágenes (campo, expresión, fondos de sección, `IMAGEOP`), códigos de barras (18 tipos 1D, PDF417, QR), gráficos (`VectorChart`, `GRAPHIC*`) | 6.244 expresiones idénticas; metafile objeto a objeto en **los 9 ejemplos**; PDF byte a byte en los 7 que van con fuentes estándar (`letter` e `international` necesitan TrueType) y en más de cien informes sintéticos |
| `@reportman/node` | `openReport`, `describeParameters` (paso 1), `executeToPdf` (paso 2), SQLite con `node:sqlite`, filas dadas por el anfitrión (REST), fuentes del sistema (`fonts`), formulario HTML de referencia, CLI `reportman-pdf` | PDFs idénticos byte a byte a C# |

Sin dependencias nativas ni WebAssembly (`npm run check:pure-js`): las únicas dependencias de
producción del núcleo son `fflate`, `i18next` (modelo del diseñador), `@zxing/library` (bloques
del QR), `fontkit` y `bidi-js`; los drivers añaden `pg`, `node-firebird`, `mysql2` y `tedious`.

**Drivers** (paquetes aparte, JS puro, cada uno imitando al proveedor ADO.NET que usa
Reportman.Server, comprobados contra bases reales en Docker):

| Paquete | Base | Comprobación contra C# |
|---|---|---|
| `@reportman/driver-postgres` (`pg`) | PostgreSQL 17 | 56 casos iguales a Npgsql 10 (PDF byte a byte o el mismo error) |
| `@reportman/driver-firebird` (`node-firebird`) | Firebird 5 | 10 informes byte a byte y todos los tipos iguales a FirebirdClient 10.3 |
| `@reportman/driver-mysql` (`mysql2`) | MySQL 8.4 y MariaDB 11.8 | 12 informes byte a byte; las mismas sentencias en el log del servidor que MySqlConnector 2.5 |
| `@reportman/driver-mssql` (`tedious`) | SQL Server 2022 | Los 8 ejemplos y 30 casos sintéticos o de error byte a byte; las mismas sentencias que SqlClient 6.1 (trazadas en el servidor con Extended Events: lote simple, o `sp_executesql` con sus mismas declaraciones) y 46 consultas con los mismos tipos y valores; cadena de conexión leída como SqlClient |
| `@reportman/driver-http` (solo `fetch`, también en el navegador) | Agent de Reportman AI (API HTTP del Hub) | 42 informes byte a byte y las 168 peticiones idénticas a `HttpAgentExecutor`, contra un Hub simulado en local (sin tocar producción); sin el canal WebRTC |

Errores del motor C# encontrados con PostgreSQL y MySQL: Npgsql y MySqlConnector solo admiten un
comando (un lector) a la vez por conexión, así que el motor C# falla con `sales-by-category` y con
cualquier informe que abra un segundo dataset o un maestro/detalle sobre la misma conexión, y
`GETVALUEFROMSQL` falla siempre en PostgreSQL; además, con MySqlConnector manda dos veces cada
consulta de detalle. Con SQL Server pasaba lo mismo sin `MultipleActiveResultSets`
(«There is already an open DataReader…»); ahora el motor C# lo añade a la cadena si esta no lo
dice, y solo falla con un `False` explícito. El motor TypeScript los ejecuta en todos los casos (lee
cada resultado entero).

`npm run check:dist` carga cada paquete compilado en Node puro, como lo recibirá un usuario de npm,
y ejecuta la línea de órdenes sobre los siete ejemplos.

Del driver de SQL Server quedan fuera, con un error claro: la seguridad integrada de Windows, casi
todos los métodos de Azure AD, canalizaciones con nombre, memoria compartida, LocalDB y Always
Encrypted. Las uniones de conjuntos de datos (MyBase, normal, agrupada y en paralelo) están portadas y
comprobadas contra C#, que ahora las construye como Delphi (ejemplos `contacts` y
`year-over-year`). Fuera todavía en general: `.rpmf`, `dbxconnections.ini` para las
conexiones directas, los datasets REST declarativos (decisión 9.6), el escritor XML de
`@reportman/lib`, el servidor Node (F6) y el diseñador en npm (F7). El conversor DFM → XML ya
existe, fuera del motor: `reptotxt -xml` de Delphi, que comprueba que el XML da el mismo informe.

## 0. Resumen

- **Qué**: ejecutar `.rep` en Node.js (y en el navegador) **solo con JavaScript**, publicado en npm
  como paquetes separados por capas:
  - sin binarios nativos, sin WebAssembly, sin Docker y sin dependencias del sistema operativo;
  - nuestro código en TypeScript, y las dependencias de terceros en JavaScript puro.
- **Base**: el motor C# (`tonimartir/reportman`), traducido a TypeScript. Es el más cercano al
  lenguaje de destino, su PDF es código propio sin nativos, y su modelo JSON camelCase ya es el que
  usa el diseñador web (`reportman-lib`). Delphi queda como referencia de la salida que hoy obtienen
  quienes ejecutan `.rep` de Delphi.
- **Primer entregable comprometido (F1)**: la prueba de concepto de dos pasos con los informes
  reales del patrocinador:
  1. cargar el informe, resolver sus parámetros (con las listas de los lookups) → **JSON**;
  2. recibir los valores → **PDF** en un `Uint8Array`.
- **Formato: solo XML, como el motor C#.**
  - El formato por defecto de Delphi es DFM de texto; no se escribe un lector DFM en TypeScript.
  - Los `.rep` DFM se pasan a XML una vez: desde el diseñador Delphi (formato de guardado XML) o con
    un conversor por línea de órdenes que se le da al usuario (sección 1.4).
  - El diseño del informe no cambia, solo su codificación; el PDF de Delphi del DFM y el del XML
    deben ser idénticos, y la F0 lo comprueba.
- **Las fuentes, sin FreeType ni HarfBuzz**: **fontkit** (JavaScript puro, MIT, el motor de fuentes
  de pdfkit) lee las fuentes, da las métricas, hace el shaping OpenType y los subconjuntos para el
  PDF; **bidi-js** sustituye a ICU (sección 2.1). Ya se ha medido contra DirectWrite, también con
  bidi, y el resultado es el mismo.
- **La lógica del paso 1 y el paso 2 ya existe en C#**: `ReportParameters.Describe` / `Apply` en
  `Reportman.Designer.Server`, la que usa ReportmanFiscal. Se porta tal cual, y el JSON que produce
  Node será **el mismo** que produce .NET.

## 1. Punto de partida

### 1.1 El motor C#

Repositorio `C:\desarrollo\danzai\comunnt\reportman` (público, MPL-2.0). Las únicas dependencias
nativas son de fuentes e imágenes; todo lo demás es C# gestionado.

| Proyecto | Líneas | Qué se necesita para ejecutar un `.rep` |
|---|---|---|
| `Reportman.Reporting` | 39.500 | ~27.700: modelo, lector XML, evaluador, parámetros, datos, secciones, elementos, códigos de barras. El resto es del diseñador o de la IA (`UndoCue`, `CopilotClientSql`, `SchemaGeneration`, `DatabaseCatalogReader`, `LocalSchemaFile`, `ReportmanAgentClient`, `ExternalReport`, `ReportLibraryConfig`), o código muerto (`SqlParser`, `QRCodeEncoder`, `PagedDataTable`). |
| `Reportman.Drawing` | 28.800 | ~13.000 de metafile y utilidades, más el PDF: `PDFCanvas` 5.450, `PrintOutPDFBase` 790, `TrueType` 850 (subconjunto glyf/loca gestionado), `FontInfoProvider` 600, `BitmapUtil` 610. |
| `Reportman.Drawing.CrossPlatform` | 4.760 | `FontInfoFt` 2.875: selección de fuentes, métricas, fallback, saltos de línea, bidi. Son unas 27 líneas de llamadas a FreeType y 16 a HarfBuzz; el resto es lógica gestionada. Además `HbSubset`, `FontConfig` y `Bidi` (ICU, solo 7 funciones `ubidi_*`). |

Para la paridad completa hay que portar unas **50.000 líneas de C#**. La prueba de concepto
necesita aproximadamente un subconjunto de 25.000 a 30.000 (sección 5, F1).

Cómo se ejecuta hoy (lo que hay que reproducir):

- **Modelo «pull»**: el driver de salida pide páginas (`MetaFile.RequestPage`), y eso hace avanzar
  el informe (`BaseReport.RequestPage` → `PrintNextPage`). Es síncrono y de un solo hilo; la
  ejecución asíncrona opcional es un `Thread` con sondeo.
- **El driver de salida es también el que mide**: `TextExtent`, `TextExtentLineInfo`,
  `GraphicExtent` y `MetaFile.CalcTextExtent` se llaman durante la paginación. Sin un dispositivo
  que mida texto no hay paginación.
- **Datos**: `ReportDataset` es un `DataTable` que se alimenta de un `IDataReader`, solo hacia
  delante y con un búfer de 2 filas (un cambio de grupo retrocede una fila para imprimir los pies),
  o de un `DataView` en memoria. El maestro/detalle vuelve a ejecutar el detalle cuando cambian las
  columnas del maestro.
- **Evaluador**: un intérprete descendente recursivo **sin AST**, que vuelve a tokenizar en cada
  evaluación. Tiene 41 funciones integradas y 33 identificadores del informe. `Variant` usa
  `System.Decimal` y `DateTime` sin zona. Los formatos son cadenas personalizadas de .NET, y las
  máscaras de fecha de Delphi se traducen a .NET.
- **Agent / Hub**: `POST {base}/api/agent/execute` con
  `{hubDatabaseId, sql, parameters[{name,value,dbType}]}`, que responde JSON `{data:{columns,rows}}`.
  En .NET 8 se intenta antes WebRTC, con un DataSet en `FastSerializer`.

### 1.2 Lo que ya hay en TypeScript (diseñador web)

Está en `ReportmanAI/Reportman.Server.Web/projects/`, un repositorio **privado**.

| Paquete | Estado |
|---|---|
| `reportman-lib` (modelo, unas 3.860 líneas) | **El código ya no depende de Angular.** Solo lo declara en las peerDependencies y en el build con ng-packagr. Su única importación en tiempo de ejecución es `i18next`, que se inicializa al importar, y solo usa del navegador `navigator.clipboard` (en 2 sitios). Contiene datos y edición (registro de componentes, añadir/borrar/mover con deshacer, importar); **no ejecuta nada**. Nunca lee ni escribe XML: siempre recibe el JSON camelCase del servidor. No tiene tests. |
| `ngx-reportman-lib` (diseñador Angular) | Superficie de diseño con fabric.js. La vista previa es un PDF en base64 hecho por el motor C# y mostrado en un `<iframe>`. Los adaptadores del inspector (`designer-interface-*.ts`, unas 4.400 líneas) casi no dependen del framework, pero se apoyan en el `TranslationService` de Angular y usan cadenas traducidas como identificadores de tipo. |
| `reportman-designer` | El componente web `<reportman-designer>` (Angular Elements). |

Los nombres de npm ya están decididos (`docs/server-componentes-plan.md` de ReportmanAI, del
06-10-2026). Se reutilizan `reportman-lib` y `ngx-reportman-lib`, hoy retirados en npm
(`0.0.26` y `0.0.37`, sin licencia), y se añade `reportman-designer`, que está libre. Su
publicación es la F8 de aquel plan, que espera a decidir la licencia.

La copia de `don6web2/projects/reportman-lib` es la original, más antigua; no se reutiliza.

### 1.3 Reportman.Server y Reportman.Designer.Server

- **API pública de ejecución**: `POST/GET /api/reports/{alias}/execute`, en `pdf|metafile|text|csv`,
  con la clave en `X-ReportmanServer-ApiKey`. Los parámetros van por nombre o alias. Esta ruta no
  valida.
- **`GET /api/reports/{alias}/parameters`**: es una forma básica (`name, type, description, hint,
  visible, value, allowNulls`) que **no resuelve los lookups**. Está congelada como contrato.
- **La versión completa del paso 1 y el paso 2 existe como servicio de biblioteca**
  (`Reportman.Designer.Server/Engine/ReportParameters.cs`):
  - `Describe` devuelve `ParameterDescription {name, type, typeName, description, hint,
    errorMessage, value (ISO), allowNulls, readOnly, freeText, editable, options[{text,value}],
    selected[], hasSearch}`;
  - `Apply` convierte por tipo y rechaza con `Unknown | NotEditable | Required | WrongType |
    NotAnOption | Validation`, y después llama a `CheckParameters`.
  - Solo ReportmanFiscal lo expone, con `/parametros` + `/pdf`.
- **Protocolo del diseñador**: `/api/designer/*` (`ReadReport` con 13 operaciones, `WriteReport`,
  `ExecuteReport`, `AiContext`, `SqlColumns`, `ToXml`, `FromXml`, `SqlSchema`). La foto de las
  rutas está en `Reportman.Server.Tests/Contract`.
- **Conexiones**: solo decide `dbxconnections.ini`. Desde el 06-10-2026 un informe cuyo alias no
  está ahí no abre la conexión que trae dentro (`Server__AllowReportConnections` lo reactiva). Node
  debe aplicar la misma regla.

### 1.4 El formato `.rep`: solo XML, con conversión previa del DFM

Delphi detecta el formato por el primer byte (`rpbasereport.pas:1109-1118`):

| Primer byte | Formato | Delphi | C# | npm |
|---|---|---|---|---|
| `o` | DFM de texto (`object TRpReport …`) | **por defecto** (`FStreamFormat:=rpStreamtext`, `rpbasereport.pas:570`) | no | no: se convierte |
| `TPF0` | DFM binario | sí | no | no: se convierte |
| `x` → DFM | zlib + DFM binario | sí | no | no: se convierte |
| `<` | XML | sí | sí | **sí** |
| `x` → `<` | zlib + XML | sí | sí | **sí** |

El lector de C# (`ReportReader.ReadXML`, `ReportReader.cs:313-351`) solo descomprime y parsea XML.
El motor npm hará lo mismo. En `repman/repsamples` hay 8 XML, 7 DFM de texto y 1 DFM binario
comprimido (`mod130.rep`).

Un `.rep` hecho con Delphi sin cambiar el formato de guardado es DFM. Se convierte una sola vez,
con una de estas dos vías:

- **Desde el diseñador Delphi**: en la configuración del informe, elegir XML como formato de
  guardado y guardar. Es lo que ya pide hoy el README del motor C# para usar un `.rep` en .NET.
- **Con un conversor por línea de órdenes**, para muchos informes de golpe:
  - `reptotxt -xml`, ampliando la herramienta que ya existe (ver abajo), para Windows y
    Linux. **Se hace al final de todo** (sección 5, «Al final»);
  - acepta archivos y carpetas, y escribe el XML sin tocar el original;
  - cuesta poco: `LoadFromFile` → `StreamFormat:=rpStreamXML` → `SaveToFile`. `SaveToStream` ya
    escribe con `WriteReportXML`, y es el mismo XML que lee C#.

**Se reutiliza `reptotxt`** (`repman/utils/reptotxt`, con su pareja `txttorep`):
- Ya es el conversor `.rep` por línea de órdenes, con origen y destino o `-stdin`, y está documentado
  en `doc/doc/commandline.html`.
- Hoy solo pasa DFM binario o comprimido a DFM de texto. Lo hace a nivel de stream
  (`rpwriter.FileReportToPlainText` → `ObjectBinaryToText`), sin cargar el informe, y por eso solo
  depende de `rpwriter`, `rptypes`, `rpmdconsts` y zlib.
- Para escribir XML tiene que **cargar** el informe en un `TRpReport`. La opción `-xml` le añade el
  motor RTL, como `printreptopdf`, que sirve de modelo para la lista de `uses`. Sin `-xml` se
  comporta exactamente como ahora.
- No está en `repman/reportmanxe2.groupproj` (solo en el antiguo `reportmanxp.groupproj`) ni en los
  scripts de release. Hay que añadirlo al grupo, a la build de Linux64 y a la release, y documentar
  la opción en `commandline.html`.

El motor npm reconoce un DFM por su primer byte y responde con un error claro («este `.rep` está en
formato DFM de Delphi: guárdalo como XML desde el diseñador»; cuando exista el conversor, también
«o conviértelo con reptotxt -xml»), nunca con un error de análisis.

La conversión solo cambia la codificación, no el diseño, pero hay que **comprobar** que el XML de
Delphi guarda todas las propiedades que tiene el DFM. La F0 lo mide con el corpus: el PDF de Delphi
del DFM y el del XML convertido deben ser idénticos.

## 2. Por qué el motor C#, y qué se descartó

- **C# frente a Delphi**: TypeScript se parece mucho más a C# (clases, GC, genéricos, excepciones).
  El JSON del modelo y el diseñador TS ya salen de C#. Además, el PDF de C# (`PDFCanvas`) es
  gestionado y ya resolvió lo que en Delphi depende de DirectWrite o de FreeType: métricas de las
  14 fuentes estándar en tablas, subconjunto TrueType propio y PDF/A-3.
- **FluentReports / pdfkit**: tienen su propio modelo de informe, definido por código. La semántica
  de un `.rep` (grupos, agregados, parámetros, subinformes, expresiones) habría que escribirla igual
  encima, y el PDF no saldría como el de Report Manager: otras métricas, otra colocación del texto,
  otros saltos de línea. Se toman como fuente de ideas (por ejemplo, para el diseñador), no como base.
- **Ejecutar el binario nativo desde Node** (el puente actual): es justo lo que se quiere eliminar.
- **Compilar el motor a WebAssembly** (Blazor/NativeAOT-WASM o FPC→WASM): fuera por la regla de
  solo JavaScript. Además no daría paquetes separables ni tipos TypeScript.

### 2.1 Qué sustituye a FreeType, HarfBuzz, ICU y fontconfig

En la ruta de PDF, C# usa las bibliotecas nativas para tareas acotadas. FreeType no rasteriza
nada: solo enumera, da nombres, el cmap y los avances. Todo lo demás (selección, alias, fallback,
métricas OS/2, CFF, saltos de línea, PDF) ya es C# gestionado y se traduce.

| Hoy (nativo) | Para qué se usa | Sustituto en JavaScript puro |
|---|---|---|
| FreeType (unas 27 líneas) | abrir fuentes, nombres, cmap, avances, cobertura | **fontkit**: TTF, OTF, WOFF, WOFF2, TTC y DFONT; métricas (`unitsPerEm`, ascent, descent, capHeight, tablas como `OS/2`), cmap, avances, variaciones |
| HarfBuzz, shaping (unas 16 líneas) | glifos, clusters, avances y desplazamientos por tramo | **fontkit** `layout()`: GSUB/GPOS (kern, liga…) y shapers Default, Universal (USE), Arabic, Indic, Hangul, Hebrew, Myanmar y Thai |
| HarfBuzz, hb-subset (`HbSubset.cs`) | subconjunto compacto para incrustar | **fontkit** `createSubset()`, pensado para PDF (TrueType y CFF); de respaldo, el port del subconjunto glyf/loca de `TrueType.cs` |
| ICU (7 funciones `ubidi_*`) | niveles bidi y tramos visuales | **bidi-js** (UAX #9, MIT) |
| fontconfig | buscar una fuente por familia, estilo y texto | código propio: escaneo de carpetas + tabla `name` de fontkit + los alias y el fallback por cobertura que ya tiene `FontInfoFt` (C# gestionado) |
| Skia (solo decodificar) | PNG, GIF… a RGBA para el PDF | decodificadores JS: **fast-png** (sobre fflate) y **omggif**; JPEG no se decodifica (pasa tal cual), BMP con el port de `BitmapUtil` |
| SharpZipLib | zlib del `.rep`, del PDF y del `.rpmf` | **fflate** |

Sobre fontkit:
- **Madurez**: existe desde 2014, es el motor de fuentes de pdfkit y lo mantiene foliojs. La versión
  3.0.0 es del 11-11-2026, con licencia MIT.
- **Dependencias**: `dfa`, `brotli` (decodificador JS para WOFF2), `fflate`, `restructure`,
  `unicode-trie` y `unicode-properties`, todas JS. Su build de Node usa el zlib integrado de Node;
  la del navegador, fflate.
- **Comprobado el 21-11-2026** con la lista de archivos de cada paquete: fontkit 3.0.0, brotli 2.1.0
  y bidi-js 1.1.0 no traen `.wasm`, `.node` ni bibliotecas nativas.
- **Ya medido**: un agente comparó la medida de fontkit con la del PDF medido con DirectWrite, también
  con texto bidi, y el resultado es el mismo. DirectWrite es lo que usa Delphi en Windows, así que es
  la referencia de quien hoy ejecuta `.rep` de Delphi. La F3 convierte esa comparación en pruebas
  de regresión del corpus, también contra el driver FreeType/HarfBuzz de C#. Si apareciera un
  fallo de fontkit en algún script, se arregla en el proyecto original o en un shaper propio
  registrado con `registerShaper`.

Descartados:
- **text-shaper** (TypeScript, MIT, al estilo de HarfBuzz): es muy joven (0.1.x desde diciembre de
  2025), lo mantiene una sola persona, no anuncia subconjuntos y su paquete lleva núcleos
  WebAssembly opcionales. Queda en observación.
- **opentype.js** 2.0: sin dependencias, pero su shaping se limita a `liga`/`rlig`, kerning y un
  árabe básico.
- **harfbuzzjs**: es WASM.

## 3. Principios de diseño

1. **El núcleo no hace E/S.** Los paquetes del núcleo se compilan con `lib: ["ES2023"]` y
   `types: []`, sin DOM ni `@types/node`: usar `fs`, `window` o `fetch` en ellos **no compila**. El
   anfitrión aporta los bytes del informe, los de las fuentes, el acceso a datos, el reloj y la
   configuración regional.
2. **Solo JavaScript.**
   - Nuestro código es TypeScript compilado a JS. Las dependencias, JS puro: ni `.wasm`, ni `.node`,
     ni `.so`/`.dll`, ni scripts de instalación que bajen binarios.
   - En los paquetes de Node se pueden usar los módulos integrados de Node (`node:zlib`,
     `node:sqlite`), porque forman parte del runtime y no añaden nada que instalar.
   - La CI lo vigila: una prueba recorre el árbol de dependencias de producción de cada paquete
     publicado y falla si encuentra binarios, WebAssembly o scripts `install`.
3. **Asíncrono en los bordes de datos, síncrono por dentro.**
   - Los drivers de Node son asíncronos, así que avanzar un registro, abrir un dataset y generar una
     página son `async`.
   - El evaluador es síncrono sobre un **AST que se parsea una sola vez**.
   - Las funciones con E/S (`GETVALUEFROMSQL`, `REOPEN`, imagen desde archivo) marcan su expresión,
     y esa expresión se evalúa por una ruta asíncrona.
   - La apertura perezosa de datasets (`OnDatasetNeeded`) se sustituye por un análisis previo de las
     expresiones.
4. **El dispositivo que mide es el que pinta.** Como en C#, el motor pagina contra una interfaz
   `LayoutDevice` (los 5 métodos abstractos de `PrintOut`), y el PDF la implementa. Así medida y
   salida no pueden discrepar.
5. **Contratos compartidos con .NET**:
   - el JSON camelCase del modelo (`ReportJsonSettings`);
   - el `ParameterDescription` del paso 1 y los errores de `Apply` del paso 2;
   - el metafile binario `.rpmf`;
   - el `dbxconnections.ini` con su regla de codificación.
6. **Paridad medida, no supuesta.** Cada fase se cierra contra un corpus con las salidas de C# y de
   Delphi (sección 6). Las rarezas de C# se catalogan: se conservan, o se corrigen **en los tres
   motores**.
7. **Tipos de valor propios**: un decimal de 28-29 dígitos (`decimal.js` o BigInt escalado) y una
   fecha-hora «de pared» sin zona horaria (nunca `Date` para valores del informe). La conversión
   desde y hacia el double de Delphi se usa en el `.rep` y en SQLite.
8. **ESM + tipos**; Node ≥ 22 LTS (Node 20 salió de soporte en abril de 2026); navegadores actuales;
   licencia MPL-2.0 como el motor.

## 4. Los paquetes

### 4.1 Mapa

```
                     NÚCLEO (navegador y Node, sin E/S)
  reportman-lib ──────► reportman-engine          reportman-pdf
  modelo, JSON,        evaluador, parámetros,    metafile → PDF;
  lector/escritor XML  datos (interfaces),       implementa el
  (zlib: fflate)       paginación                LayoutDevice
                             │                       │   │
                             ▼                       ▼   │
                       reportman-metafile ◄──────────┘   │
                       páginas del metafile, .rpmf,      │
                       contrato LayoutDevice             │
                             ▲                           │
                             └── reportman-text ◄────────┘
                                 métricas estándar, saltos de línea;
                                 OpenType, shaping y subconjuntos
                                 (fontkit), bidi (bidi-js)

                     ANFITRIÓN NODE (= «la API de C#» en Node)
  reportman-node      Report.load/describeParameters/executeToPdf, fs,
                      fuentes del sistema, dbxconnections.ini, CLI reportman-pdf
  reportman-driver-*  postgres · mysql · mssql · firebird · oracle · sqlite
                      (Node, JS puro)
  reportman-driver-http  Agent de Reportman AI (Hub) + REST/JSON (fetch: Node y navegador)
  reportman-server    API HTTP compatible con Reportman.Server y /api/designer/*

                     SALIDAS Y DISEÑO (fases posteriores)
  reportman-export    CSV, texto, SVG, HTML (XLSX opcional)
  reportman-canvas    vista previa del metafile en Canvas 2D (navegador)
  ngx-reportman-lib · reportman-designer   (ya existen; F8 del plan del servidor)
```

**`reportman-metafile`** (añadido el 21-11-2026, al empezar el prototipo) es el contrato que
comparten el motor y las salidas: las páginas del metafile, `.rpmf` y la interfaz `LayoutDevice`.
Una salida (PDF, SVG, canvas) o un visor de `.rpmf` dependen de él sin necesitar el motor, y el
motor depende de él sin necesitar ninguna salida. Equivale al núcleo de `Reportman.Drawing` de C#.

Las flechas indican dependencia. Los drivers dependen de las **interfaces**
de `reportman-engine`, nunca al revés: quien instala `reportman-node` solo baja el driver de su
base de datos.

### 4.2 Qué pieza de C# corresponde a cada paquete

| C# hoy | npm |
|---|---|
| `Reportman.Reporting.Design.Json` (modelo ↔ JSON) + `ReportReader` (lector y escritor XML) | `reportman-lib` |
| `Reportman.Reporting` (runtime) + `VectorChart`, códigos de barras | `reportman-engine` |
| `MetaFile`, `MetaPage`, `MetaObject*`, `TextObjectStruct` y la parte abstracta de `PrintOut` (`Reportman.Drawing`) | `reportman-metafile` |
| `PDFCanvas`, `PrintOutPDFBase`, `TrueType`, `BitmapUtil` | `reportman-pdf` |
| `FontInfoProvider`, `FontInfoFt` (su lógica gestionada), `HtmlTextParser`; `Bidi`, `HbSubset` y `FontConfig` se sustituyen (sección 2.1) | `reportman-text` |
| API pública (`Report.LoadFromFile`, `Params`, `PrintOutPDF*`), `printreportpdf`, y de `Designer.Server`: `ReportDocumentService`, `ReportExecutionService`, `ReportParameters` | `reportman-node` |
| Proveedores ADO.NET (`DirectProviders`), `HttpAgentExecutor`, `DbxDirectConnections`/`DbxIniDocument` | `reportman-driver-*`, `reportman-node` |
| `Reportman.Server` (rutas públicas) + `Reportman.Designer.Server` (protocolo) | `reportman-server` |
| `PrintOutCSV`, `PrintOutText`, y los drivers SVG/HTML de Delphi (C# no los tiene) | `reportman-export` |

### 4.3 Cómo se usa (boceto de API)

Node, los dos pasos:

```ts
import { openReport } from 'reportman-node';
import postgres from 'reportman-driver-postgres';

const report = await openReport('ventas.rep', {
  connections: { VENTAS: postgres({ host, database, user, password }) },  // o dbxconnections.ini
  locale: 'pt-BR',
});
const parametros = await report.describeParameters();   // paso 1 → ParameterDescription[]
const pdf = await report.executeToPdf({ CLIENTE: 42, DESDE: '2026-01-01' });  // paso 2 → Uint8Array
```

Núcleo, en el navegador o en Node sin `reportman-node`:

```ts
import { readReport } from 'reportman-lib';            // XML y XML con zlib
import { ReportEngine } from 'reportman-engine';
import { PdfDevice } from 'reportman-pdf';

const device = new PdfDevice({ fonts });               // mide y pinta
const engine = new ReportEngine(readReport(bytes), { data: miProveedor, device });
const metafile = await engine.run({ params });
const pdf = device.render(metafile);
```

El JSON del paso 1 es el de .NET:

```json
{ "name": "CLIENTE", "type": 11, "typeName": "List", "description": "Cliente", "hint": "",
  "errorMessage": "", "value": "42", "allowNulls": false, "readOnly": false, "freeText": false,
  "editable": true, "options": [{ "text": "ACME", "value": "42" }], "selected": [], "hasSearch": false }
```

## 5. Fases

Cada fase deja algo que funciona y se puede usar, y se cierra con su criterio «hecho cuando». Las
estimaciones son días de trabajo con IA, orientativas. La F0 no necesita nada del patrocinador; la
F1 sí (sección 10).

### F0 — Base y red de seguridad · 2-3 días

**Estado (21-11-2026): hecha, salvo las salidas de Delphi del corpus.**
- **CI** en este equipo, no en GitHub: `npm run ci` copia el árbol de trabajo y lo instala, compila,
  prueba y comprueba en Windows con su Node y en Linux en Docker dentro de WSL, con `node:22` y
  `node:24`. En verde en los tres: 1.363, 1.233 y 1.233 pruebas; las demás se saltan por las fuentes
  de Windows, poppler o una base de datos que no está.
- **`reportman-lib` vive solo en el repositorio C#**: ReportmanAI lo compila por ruta (`tsconfig`
  `paths`, con sus dependencias desde su propio `node_modules`) y `projects/reportman-model` se ha
  borrado de ReportmanAI. Comprobado con `npm run build:server`, el paquete `ngx-reportman-lib` y
  las pruebas de la web. Se trajo lo único que solo tenía ReportmanAI (`RpKey_1849` y la copia de
  las uniones en el historial de deshacer) y el diseñador web usa ya los nombres JSON del modelo C#
  (`dpires`, `docXMPContent`, `vAlignment`, `bde*`).
- **`rep-inventory`**: `npm run inventory -- <informes>` lee los 11 ejemplos de `samples/` y los 8
  XML de `repman/repsamples`; los 8 DFM de esa carpeta salen aparte, para guardarlos como XML.
- **Pendiente**: las salidas de Delphi (`printreptopdf`) de cada informe del corpus como un
  conjunto; hoy se comparan a mano (ejemplos de uniones). No se usan eslint ni tsup: `tsc -b`
  compila y la frontera del núcleo la pone `types: []`.

- **Monorepo** (decisión 9.1):
  - workspaces, TypeScript 5.9, tsup (ESM + `.d.ts`), vitest y eslint con fronteras entre paquetes;
  - la regla de compilación del principio 1 y la prueba de «solo JavaScript» del principio 2;
  - CI en Node 22 y 24, Linux y Windows, en este equipo (`npm run ci`, Linux en WSL), no en GitHub.
- **Traslado de `reportman-lib`** desde ReportmanAI (sección 9.1):
  - se copia sin historial, en un commit inicial que dice de dónde viene;
  - ReportmanAI pasa a compilarlo por ruta desde el repositorio C# (`tsconfig` `paths`), como ya
    hace con el motor C#;
  - comprobado con la build del servidor (`npm run build:server`) y la del componente.
- Esqueleto de los paquetes del núcleo y de `reportman-node`, versión `0.0.x`, sin publicar.
- **Corpus de referencia**:
  - informes: los 9 de `samples/` de C# con `samples.db` (XML, SQLite, Helvetica estándar), los 8
    XML de `repman/repsamples`, y los informes del patrocinador cuando lleguen (guardados como XML
    desde el diseñador Delphi; el conversor llega al final, sección 5, «Al final»);
  - salidas de C#: compilar `printreportpdf` y sacar PDF + metafile (`-m`) de cada informe;
  - salidas de Delphi: compilar `printreptopdf` y sacar el PDF de cada informe. Es la referencia de
    lo que el patrocinador ve hoy;
  - herramientas de comparación (solo de pruebas, aquí sí valen nativos): diferencia de metafiles
    objeto a objeto (posición ±1 twip, textos, estilos) y raster de PDF con `pdftoppm` en WSL.
- **`rep-inventory`**: el primer uso del lector XML en TypeScript. Lista lo que usa un conjunto de
  `.rep`: clases, propiedades distintas del valor por defecto, funciones, tipos de parámetro,
  drivers, fuentes y formatos. **Con él se fija el alcance exacto de la F1** sobre los informes
  reales.

**Hecho cuando** (la F0 entera):
- la CI está en verde, y ReportmanAI compila con `reportman-lib` traído del repositorio C#;
- el corpus está generado y `rep-inventory` lee todos sus `.rep`.

### F1 — Prueba de concepto: los dos pasos con los `.rep` del patrocinador · 10-12 días

**Objetivo funcional**: desde Node y solo con `npm install`, cargar un `.rep` de Delphi en XML
(guardado como XML desde el diseñador si estaba en DFM, sin cambiar su diseño), devolver sus
parámetros como JSON con los lookups resueltos contra su base de datos, y con los valores devolver el
PDF.

Alcance por paquete:

- **`reportman-lib` 0.1**:
  - el modelo sin Angular: sin peerDependencies, i18n opcional, portapapeles fuera, hidratación
    completa de elementos y conexiones, y los nombres JSON corregidos (anexo B);
  - lector de XML y XML-zlib (port de `ReportReader`), y detección del DFM con el error de la
    sección 1.4.
- **`reportman-engine` 0.1**:
  - `Variant` (decimal, fecha sin zona) y evaluador sobre AST, con las funciones puras y las
    variables del informe que use el inventario;
  - parámetros: port de `ReportParameters.Describe`/`Apply`, `UpdateLookupValues`,
    `CheckParameters`, y los tipos InitialValue, ExpreB, ExpreA, Subst, List y Multiple;
  - datasets: SQL con parámetros por nombre, sustituciones y maestro/detalle por `DataSource`
    (materializados en memoria; el streaming es de la F2);
  - paginación: subinforme principal e hijos; cabeceras y pies de página y de grupo
    (`ChangeExpression`, `PageRepeat`); detalle; `PrintCondition`, `BeforePrint`/`AfterPrint`;
    autoexpandir; ajuste de línea; `PAGECOUNT`;
  - elementos: etiqueta, expresión (`DisplayFormat`, agregados de grupo, página y general), forma e
    imagen (JPEG, PNG, BMP); y lo demás que pida el inventario.
- **`reportman-text` 0.1**: métricas de las 14 fuentes estándar y el salto de línea simple
  (`TextExtentSimple`), idénticos a C# y Delphi.
- **`reportman-pdf` 0.1**: PDF 1.4 con fuentes estándar y WinAnsi (cubre el portugués y el
  español), formas, imágenes, Flate; `PdfDevice` como dispositivo de medida.
- **`reportman-node` 0.1**:
  - `openReport`, `describeParameters`, `executeToPdf`;
  - conexiones por alias desde las opciones o `dbxconnections.ini`;
  - el driver de la base de datos del patrocinador (uno de los `reportman-driver-*`);
  - **filas aportadas por el anfitrión para un dataset** (el `DataViewOverride` de C#): con eso un
    dataset ya puede venir de una API REST desde el código, sin esperar a la F4;
  - CLI `reportman-pdf informe.rep -paramNOMBRE=valor -o salida.pdf`;
  - un ejemplo de formulario HTML de parámetros generado desde el JSON.

**Fuera de alcance**, salvo que el inventario lo exija:
- TrueType incrustado y shaping. Si lo exige, primero TrueType sin shaping complejo: avances y cmap
  de fontkit, y su subconjunto (o el de `TrueType.cs`);
- PDF/A, gráficos, PDF417/QR, texto HTML, columnas, otras salidas, diseñador.

Lo que no se soporta falla con un error claro («X no está soportado todavía»), nunca con una salida
equivocada.

**Hecho cuando**:
- los informes del patrocinador dan PDFs equivalentes a los de `printreptopdf` de Delphi: las mismas
  páginas y los mismos textos, y una diferencia raster por debajo del umbral;
- el JSON del paso 1 coincide con el de `ReportParameters.Describe` de C# para el mismo informe;
- funciona en Node 22 y 24, en Linux y Windows, sin binarios.

**Estado (21-11-2026)**: hecha, falta publicar.

- Los tres informes del patrocinador (convertidos con `reptotxt -xml`, Zeos sobre PostgreSQL)
  dan, con el motor TypeScript y su base de datos, las mismas páginas y los mismos textos que los
  PDF de Delphi, palabra por palabra salvo la hora de `NOW`. Diferencia raster: 0,22 %, 1,62 % y
  3,14 % (desplazamientos de menos de un punto; el QR del DANFE dibuja otro patrón de módulos,
  pero leído con zxing da la misma URL de consulta con la misma clave).
- Las diferencias encontradas eran errores del motor C#, corregidos en los dos motores con las
  fixtures de `golden-cs` regeneradas (decisión 9.8): los `#13#10` del analizador, `VAL`, fecha
  frente a número (por su valor OLE, como Delphi), las horas sin fecha impresas sin la fecha, los
  alias de dataset sin distinguir mayúsculas, las búsquedas `:NOMBRE` de los parámetros de
  sustitución que `ConvertToDotNet` convertía en parámetros SQL, y los tipos de los parámetros con
  Npgsql. Las comillas de un `SubsExpreList`, como en Delphi, solo se aplican a los informes
  convertidos desde drivers que solo tiene Delphi (`ConvertedFromDelphi`): los nativos de C# y los
  del Agent siguen igual, porque su valor ya va entre comillas.
- Adaptador para la aplicación del patrocinador (CommonJS): sus dos llamadas con el mismo contrato
  que su puente Delphi (el JSON del paso 1 de `uReportProcessor.pas`, las conversiones de los
  valores del paso 2, idioma 4 si el informe trae uno fuera de rango, CODEMP y CODFIL), y el
  driver síncrono solo para los informes que lo necesitan (`isSynchronousDataRequired`). Probado
  a través de su propio servidor: los tres PDF iguales a los de Delphi.
- Paquetes renombrados a `@reportman/*`, versión `0.1.0-alpha.1`, `publishConfig` con acceso
  público y etiqueta `next`. `npm pack` de los once e instalación limpia en un proyecto CommonJS
  comprobadas. CI local en Windows y en Linux con Node 22 y 24.
- Falta: publicar (Toni, con su llave: `npm publish --workspaces` desde `typescript/`), y enviar
  el adaptador al patrocinador.

### F2 — Motor completo: paridad funcional con C# · 3-4 semanas

- **Expresiones y formatos**: todas las funciones (41 + 33) y todos los tipos de parámetro;
  `Language`/cultura; formatos (.NET y máscaras de fecha de Delphi); semántica decimal; el catálogo
  de rarezas.
- **Paginación completa**:
  - columnas (`HorzDesp`/`VertDesp`), `AlignBottom`, `SkipPage`, saltar a página y posición,
    `BeginPageExpression`;
  - `TwoPass`, `GROUPPAGECOUNT`, impresión parcial y texto multipágina;
  - subinformes anidados, uniones Mybase (normal y paralela), `ExecuteSubReportIndexes`.
- **Elementos**:
  - códigos de barras 1D (codificadores propios) y PDF417 (port);
  - QR: el codificador de ZXing en JS, que da la misma matriz, u otro equivalente;
  - gráficos vectoriales (`VectorChart`), imágenes de fondo, `IMAGEOP`/`GRAPHICOP`/`TEXTOP`.
- **Funciones con E/S** (`GETVALUEFROMSQL`, `REOPEN`, imágenes por ruta mediante un resolvedor del
  anfitrión) por la ruta asíncrona.
- **Streaming**: páginas generadas de forma asíncrona, datasets solo hacia delante con búfer de 2
  filas, progreso y cancelación con `AbortSignal`.
- **Metafile `.rpmf`** (v4.1) de lectura y escritura, compatible con las vistas previas de C# y
  Delphi.
- El núcleo pasa sus tests también **en el navegador** (Chromium y Firefox).

**Hecho cuando**: todo el corpus pasa la diferencia de metafile contra C# y la raster contra PDF, y
los tests de `tests/` del motor C# están portados.

### F3 — Tipografía y PDF completo · 2-3 semanas

- **`reportman-text`, sobre fontkit**:
  - lectura de fuentes (TTF, OTF, TTC, WOFF/WOFF2);
  - métricas como `FontInfoFt`, con la lógica typo/win de OS/2 portada de C#;
  - registro de fuentes aportadas por el anfitrión. En Node, un escaneo de las carpetas del sistema
    y de una carpeta propia sustituye a fontconfig, con los mismos alias (Arial → Liberation Sans/
    Arimo…);
  - fallback por cobertura (`hasGlyphForCodePoint`) y emoji monocromo.
- **Texto complejo**:
  - shaping con **fontkit** `layout()` por tramo (nivel bidi × segmento HTML × cobertura), igual
    que hoy se trocea para HarfBuzz;
  - bidi con **bidi-js**, usado como hoy se usa ICU (niveles y tramos visuales);
  - texto HTML (`HtmlTextParser` con un parser HTML en JS puro) y justificado.
- **`reportman-pdf`**:
  - Type0 / CIDFontType2 / CIDFontType0 con `ToUnicode` y `CIDToGIDMap`;
  - subconjunto con fontkit `createSubset()`, y el port de `TrueType.cs` como respaldo;
  - glifo a glifo (`Tm`/`Tj`), ligaduras en PUA;
  - **PDF/A-3B**: XMP, OutputIntent sRGB y archivos incrustados (facturas electrónicas);
  - enlaces, anotaciones y metadatos.

**Hecho cuando**:
- `international.rep` y los ejemplos árabes y CJK del corpus coinciden con la salida de Delphi
  (DirectWrite) y con el driver FreeType de C#, como pruebas de regresión;
- veraPDF valida el PDF/A-3B (herramienta de pruebas).

### F4 — Datos · 2 semanas

- **Drivers en JS puro**, con un contrato común: parámetros con tipo y por nombre, esquema de
  columnas, y transacción implícita que se confirma al desconectar, como en C#.
  - `reportman-driver-postgres` (pg)
  - `-mysql` (mysql2)
  - `-mssql` (tedious)
  - `-firebird` (node-firebird)
  - `-oracle` (oracledb en modo Thin, que es JS). **Verificado (21-11-2026)**: `oracledb` 26.0.0
    pesa 4 MB, trae los binarios del modo Thick (`.node` de Windows x64, Linux x64/arm64 y macOS
    arm64) y un script `install` que solo comprueba la versión de Node y el binario. **DECIDIDO**:
    se acepta como excepción documentada al principio 2, en su propio paquete y siempre en modo Thin
    (el núcleo sigue siendo JavaScript puro), y se hace cuando un cliente lo necesite.
  - `-sqlite` (`node:sqlite`, integrado en Node)
  - Con `pg` no se instala `pg-native`, que es opcional.
- **Conexiones de Delphi**:
  - traducción de los drivers de `DatabaseInfo` (FireDAC, Zeos, IBX, dbExpress, BDE, ADO, DotNet2)
    y sus parámetros al driver de Node;
  - `dbxconnections.ini` con la regla de codificación de C# y Delphi;
  - las contraseñas DPAPI no se pueden leer fuera de Windows: se resuelven con una retrollamada del
    anfitrión o variables de entorno.
- **`reportman-driver-http`**:
  - el Agent de Reportman AI por el Hub (`/api/agent/execute`), en Node y en el navegador (sin
    WebRTC nativo);
  - **datasets REST/JSON** (decisión 9.6).
- Seguridad: solo las conexiones que declara el anfitrión, salvo `allowReportConnections`, como en
  Reportman.Server.

**Hecho cuando**: hay pruebas de integración por base de datos en la CI (servicios Docker) con el
esquema de `samples.db`, y el Agent funciona contra la base de ejemplo de la nube.

### F5 — Otras salidas y vista previa en el navegador · 2 semanas

- **`reportman-export`**:
  - CSV (`PrintOutCSV`) y texto plano (`PrintOutText` PLAIN; ESC/POS más adelante);
  - **SVG y HTML**, portados de los drivers de Delphi porque C# no los tiene;
  - XLSX opcional.
- **`reportman-canvas`**: pinta el metafile en Canvas 2D (páginas, zoom) con las mismas fuentes que
  `reportman-text` (`FontFace` desde los mismos bytes), así que la vista previa es idéntica al PDF.

**Hecho cuando**: las salidas coinciden con los drivers de Delphi en el corpus, y la vista previa en
canvas coincide con el raster del PDF.

### F6 — Servidor Node: `reportman-server` · 1-2 semanas

- Manejadores independientes del framework, con adaptadores para `node:http`, Express y Fastify.
- **API pública compatible con Reportman.Server**:
  - `/api/reports/{alias}/execute` (pdf, metafile, text y csv; clave API);
  - `/parameters` con su forma congelada, más una ruta nueva con el `ParameterDescription` completo;
  - almacén en carpeta con alias y `dbxconnections.ini`.
- **Protocolo `/api/designer/*`** (`ReadReport`, `WriteReport`, `ExecuteReport`, `Evaluate`,
  `CheckSyntax`, `ReadDataset`, `ReadFunctions`, `ToXml`, `FromXml`): `ngx-reportman-lib` funciona
  contra un servidor Node sin .NET.
- El puente de la IA queda fuera; sigue en .NET.

**Hecho cuando**: las fotos de contrato de `Reportman.Server.Tests` (el subconjunto de rutas
implementado) pasan contra Node, y `<reportman-designer>` funciona contra él.

### F7 — El diseñador web en npm · 3-4 semanas

Enlaza con la F8 de `server-componentes-plan.md`.

- Publicar `reportman-lib` (sin framework desde la F1).
- Un **`reportman-designer-core`** nuevo con:
  - los adaptadores del inspector y un traductor inyectable;
  - identificadores de tipo que no sean textos traducidos;
  - el registro del deshacer y la fábrica por `className`;
  - la lógica sacada de `report-editor`, `object-inspector` y `report-structure-tree`.
- `ngx-reportman-lib` y `reportman-designer` publicados.
- **Lo nuevo**: vista previa, evaluación y comprobación de sintaxis **en el navegador**, con
  `reportman-engine` + `reportman-canvas`/`reportman-pdf`, sin ida y vuelta al servidor cuando los
  datos vienen de REST, del Agent o de memoria.
- Puerta: la licencia del diseñador (decisión 1 de aquel plan).

### Al final — Conversor DFM → XML: `reptotxt -xml` · 1-2 días

Planificada, no hecha, y **se deja para el final de todo** (decisión de Toni, 21-11-2026). Hasta
entonces, un `.rep` en DFM se guarda como XML desde el diseñador Delphi. Se trabaja en el
repositorio Delphi (`master`, mensajes en inglés, los dos remotos).

1. **`repman/utils/reptotxt/reptotxt.dpr`**: una opción `-xml` en cualquier posición.
   - Sin ella, el comportamiento actual no cambia (DFM binario o comprimido → DFM de texto).
   - Con ella, crea un `TRpReport`, lo carga (`LoadFromFile`, o el stream de `-stdin`), pone
     `StreamFormat:=rpStreamXML` y lo guarda en el destino (o en la salida estándar).
   - Los `uses` del motor RTL se toman de `printreptopdf`: solo lo necesario para cargar los
     componentes del informe, sin drivers de datos que no hagan falta.
2. **Carpetas**: `reptotxt -xml <carpeta origen> <carpeta destino>` recorre los `*.rep`, mantiene
   las rutas relativas y nunca escribe sobre el origen.
   - Un `.rep` que ya es XML (`<`, o zlib que contiene `<`) se copia tal cual.
   - Al final escribe cuántos convirtió, cuántos copió y cuántos fallaron.
   - El código de salida es 1 si alguno falló, y los errores van a la salida de error.
3. **Ayuda**: `SRpRepToTxt3` (`rpmdconsts.pas`) con la nueva sintaxis.
4. **Builds**:
   - `reptotxt.dproj` entra en `repman/reportmanxe2.groupproj` (Win32/Win64);
   - la plataforma Linux64 en el `.dproj` y en `build/sourceforge/01c-build-linux64.ps1` (SDK
     Rocky 8);
   - el ejecutable va en la release (`make-release.ps1`).
5. **Documentación**: la opción `-xml` en `doc/doc/commandline.html` y en su versión española, si la
   tiene.
6. **Prueba** (un script en `tests/`):
   - convertir los 8 DFM de `repman/repsamples`;
   - comparar el PDF de `printreptopdf` del DFM original con el del XML: deben ser idénticos, salvo
     la fecha y el `/ID`.
   - Una propiedad que se pierda es un fallo real del formato XML. Se arregla en `rpxmlstream.pas`
     (regla de las unidades compartidas: solo correcciones reales), y C# también se beneficia.
7. **Hecho cuando**: los 8 DFM convierten con PDFs idénticos en Windows y Linux64, y el grupo compila
   sin avisos nuevos.

## 6. Pruebas y paridad

- **Corpus**: los `.rep` de Delphi y de C#, los del patrocinador y los que añada cada fase. Cada
  informe lleva junto a él sus salidas de C# y de Delphi y su `rep-inventory`.
- **Tres niveles de comparación**:
  1. unitarias, portadas de C# y nuevas: evaluador, formatos, decimal, lectores;
  2. **metafile**, objeto a objeto, contra C#;
  3. **raster** del PDF contra C# y Delphi.
  El nivel 2 encuentra los errores de paginación antes que el 3.
- **Motores cruzados**:
  - el escritor XML de TS se valida abriendo su XML con C# y con Delphi;
  - los informes que venían en DFM se comparan además contra el PDF de Delphi del DFM original, que
    es lo que ve hoy el usuario de Delphi.
- **CI**: Node 22/24 × Linux/Windows, y el navegador para el núcleo. Las bases de datos, en
  servicios Docker de la CI (F4).

## 7. Tres motores: cómo no divergir

Delphi, C# y TypeScript ejecutarán el mismo `.rep`. Las reglas:

1. El corpus es común y lo pasan los tres; un informe nuevo entra con sus salidas.
2. Un cambio de formato o de semántica se hace en los tres en la misma tanda de trabajo, o no se hace.
3. Las rarezas de C# (anexo B) se deciden una vez, para los tres motores.
4. Si TypeScript vive junto a C# (decisión 9.1), un mismo commit puede cambiar los dos con sus
   pruebas.

## 8. Riesgos

| Riesgo | Qué se hace |
|---|---|
| `.rep` de Delphi en DFM | Se guardan como XML desde el diseñador Delphi; al final, `reptotxt -xml`, que comprueba con los 8 DFM del corpus que el XML no pierde nada (PDF idéntico). |
| El XML de Delphi no guarda alguna propiedad del DFM | Se detecta en la F0 y se arregla en `rpxmlstream.pas`: es un fallo real del formato, que también afecta a C#. |
| Diferencias de medida: otro salto de línea, otra paginación | Tablas estándar copiadas tal cual; diferencia de metafile en cada fase. |
| Shaping de fontkit (texto complejo) | Riesgo bajo: ya medido igual que DirectWrite, también con bidi. Queda como prueba de regresión del corpus en la F3; si algún script falla, se arregla en fontkit o en un shaper propio (`registerShaper`). |
| Una dependencia JS deja de mantenerse | Se eligen paquetes en mantenimiento (fontkit 3.0, bidi-js, fflate); el contrato de `reportman-text` permite cambiar de motor de fuentes sin tocar el motor de informes. |
| Una dependencia trae binarios o WASM (p. ej. `oracledb`) | La prueba del principio 2 lo detecta; se sustituye o se deja como excepción documentada. |
| Motor síncrono frente a drivers asíncronos | Principio 3: asíncrono en los bordes, evaluador síncrono sobre AST, ruta asíncrona solo para las funciones con E/S. |
| Decimal, fechas y formatos de .NET | Tipos propios y pruebas contra C# con las culturas reales (es, en, ca, pt-BR). |
| Driver JS de la base del patrocinador (p. ej. Firebird 4/5 con cifrado de cable) | Se comprueba en la F0, en cuanto se sepa qué base es. |
| Tamaño de la F1 frente al plazo | El alcance lo fija `rep-inventory` sobre los informes reales; lo no soportado falla claro. |
| Informes grandes (memoria) | Materializado en la F1, streaming en la F2, con medidas. |
| Nombres de npm ocupados por otros | Reservarlos pronto (decisión 9.2). |

## 9. Decisiones de Toni

1. **Dónde vive el código** — **DECIDIDO (21-11-2026)**: en `typescript/` de `tonimartir/reportman`,
   junto al motor C#. Así un commit cambia los dos motores con sus pruebas, y el corpus y `samples/`
   ya están ahí.

   **Qué se traslada y qué no** (recomendación):

   | Código TS de hoy (ReportmanAI, privado) | ¿Al repositorio C#? | Por qué |
   |---|---|---|
   | `reportman-lib` (modelo, ~3.860 líneas) | **Sí, en la F0** (hecho el 21-11-2026; la copia de ReportmanAI se ha borrado) | El motor depende de él, así que tiene que ser público y MPL. Ya está casi todo en inglés y no depende de Angular en el código. |
   | `ngx-reportman-lib` + `reportman-designer` (diseñador) | **Todavía no: en la F7** | Su licencia está sin decidir (MPL o comercial, decisión 1 de `server-componentes-plan.md`). Lleva el copiloto y el puente de la IA, y la app del servidor lo compila desde el código fuente. Trasladarlo ahora rompe la build de ReportmanAI sin ganar nada para el motor. |
   | La app de Reportman.Server.Web (consola, conexiones, asistente) | **No** | Es del anfitrión .NET y privada. |
   | El canal de datos TS de Reportman.Web (`fast-serializer.ts`, WebRTC) | **No por ahora** | El driver del Agent de la F4 va por HTTP con `fetch`. Si algún día hay WebRTC en el navegador, se reutiliza de ahí. |
   | `don6web2/projects/reportman-lib` | **No** | Es la copia antigua, superada. |

   - Se copia **sin historial**: el de ReportmanAI es privado y sus mensajes hablan de cosas
     internas (créditos, nube), así que no se arrastra a un repositorio público. Se hace un commit
     inicial que dice de dónde viene.
   - ReportmanAI pasa a compilarlo por ruta, como ya hace con el motor C#, y desde la F8 de su plan
     lo tomará de npm.
2. **Nombres** — **DECIDIDO (21-11-2026)**: ámbito `@reportman/*`. La organización `reportman`
   de npm está creada (gratuita, paquetes públicos; dueño `tonimartir`). Los paquetes:
   `@reportman/lib`, `metafile`, `text`, `pdf`, `engine`, `node`, `driver-*`, y más adelante
   `export`, `canvas`, `server` y `ngx`. Los `reportman-lib` (0.0.26) y `ngx-reportman-lib` (0.0.37)
   de 2025 siguen obsoletos y no se reutilizan.
3. **Licencia** — **DECIDIDO**: MPL-2.0 para todos los paquetes del motor (`lib`, `metafile`,
   `text`, `pdf`, `engine`, `node` y los drivers), como el motor C#. El diseñador y el servidor
   Node se deciden aparte (la F7 depende de la licencia del diseñador).
4. **Node mínimo** — **DECIDIDO**: 22.12, la primera 22 en la que un proyecto CommonJS puede hacer
   `require()` de un paquete ESM sin opciones.
5. **ESM solo o ESM + CommonJS** — **DECIDIDO**: solo ESM. `check:dist` comprobará que cada paquete
   se carga con `require()` desde CommonJS (en Node ≥ 22.12, sin `await` de primer nivel en los
   módulos que se cargan). Si algún usuario necesitara un Node anterior con CommonJS, se añade la
   versión doble después.
6. **Datasets REST/JSON** — **DECIDIDO**: solo el gancho del anfitrión (las filas de un dataset las
   da el programa; ya hecho). Un tipo de conexión REST en el formato `.rep` queda como proyecto
   aparte, si un patrocinador lo pide.
7. **Entrega de la F1** — **DECIDIDO**: versión previa pública en npm (`0.1.0-alpha.N`, etiqueta
   `next`; la etiqueta `latest` no se usa hasta la 1.0). El código ya es público en el repositorio C#.
8. **Errores de C# o de Delphi encontrados al portar** — **DECIDIDO**: se corrigen en los tres
   motores, revisando a fondo que cada corrección sea compatible con los informes existentes; si no
   puede serlo, se discute antes de hacerla.
9. **El orden de F2 a F7 y su financiación** — **DECIDIDO**: primero el motor. Las conexiones de
   Delphi y `dbxconnections.ini` (parte de la F4) → F1 en cuanto lleguen los informes → F2 → F3 → F5
   → F6 → F7 → conversor DFM. Si se avanza en una fase sin patrocinador lo decide Toni fase a fase.

## 10. Lo que falta del patrocinador (bloquea la F1, no la F0)

**Recibido (21-11-2026)**: un repositorio de referencia con su base de datos (esquema y datos de
prueba), tres `.rep` reales **en DFM de texto**, cómo los ejecuta hoy (dos pasos: el JSON de los
parámetros con sus listas resueltas y el PDF sin comprimir) y su aplicación Node (CommonJS). Las
fuentes son las Type1 estándar (Helvetica). Se da por hecho que su Node de producción es al menos
la 22.12 (con CommonJS hace falta, decisión 9.5). Los tres informes están guardados como XML con
`reptotxt -xml` (21-11-2026).

- La base de datos y su versión.
- Dos o tres `.rep` reales, con sus conexiones (`dbxconnections.ini` o los parámetros de conexión,
  sin contraseñas). Mejor en XML (guardados desde el diseñador Delphi); si vienen en DFM, los convertimos
  nosotros desde el diseñador. El conversor por línea de órdenes llega al final.
- Cómo se ejecutan hoy: comando de `printreptopdf` o `repwebexe`, y cómo se pasan los parámetros.
- Versión de Node, ESM o CommonJS, y sistema donde corre (¿contenedores Linux?).
- Configuración regional y fuentes (¿Type1 estándar o TrueType?), y si necesitan PDF/A.

---

## Anexo A. Dependencias previstas (todas JavaScript puro, navegador y Node)

Versiones y fechas consultadas en npm el 21-11-2026.

| Para | Librería | Licencia | Última versión | Fase |
|---|---|---|---|---|
| zlib (`.rep`, PDF, `.rpmf`) | fflate | MIT | 0.8.3 (07-2026) | F1 |
| Decimal 28-29 dígitos | decimal.js (o BigInt propio) | MIT | 10.6.0 (07-2025) | F1 |
| PNG | fast-png (sobre fflate), o decodificador propio | MIT | 8.0.0 (12-2025) | F1 |
| GIF | omggif | MIT | 1.0.10 (2022, estable) | F2 |
| QR | @zxing/library (port de ZXing: la misma matriz que ZXing.Net) o qrcode-generator | Apache-2.0 / MIT | 0.23.0 / 2.0.4 | F2 |
| Fuentes: lectura, métricas, shaping, subconjuntos | **fontkit** | MIT | 3.0.0 (11-2026) | F1 (si hay TrueType) / F3 |
| Bidi | **bidi-js** (UAX #9) | MIT | 1.1.0 (09-2026) | F3 |
| HTML del texto enriquecido | parser HTML en JS puro (por elegir) | — | — | F3 |
| Bases de datos | pg, mysql2, tedious, node-firebird, oracledb (Thin; ver F4), `node:sqlite` | varias, por revisar en la F4 | — | F1 (la del patrocinador) / F4 |

Ni `.wasm` ni binarios: lo comprueba la prueba del principio 2 en cada versión.

## Anexo B. Defectos encontrados durante el análisis (por verificar antes de corregir)

`reportman-lib` (ReportmanAI, `projects/reportman-model/src/lib/models/`):

- `report.ts:1095` registra `databaseAlias` con el nombre `dataUnions`, y `report.ts:1103`
  registra `sql` con el nombre `openOnStart`: al deshacer el borrado de un dataset se pierde su SQL.
- `report.ts:960` compara el componente consigo mismo: añadir una sección borra los
  identificadores de sus expresiones y gráficos.
- `report.ts:488` y `undo-cue.ts:248, 263, 273…` borran de `components` con el nombre sin pasar a
  mayúsculas, pero las claves están en mayúsculas.
- `report.ts:1220` usa un id de grupo nuevo en vez del recibido.
- `report.ts:287` muestra `newItem` (siempre `undefined`) en el mensaje de error.
- `report-hydration.ts` no crea instancias de los elementos de las secciones ni de
  `databaseInfo`.
- Nombres JSON que no coinciden con C#: `previewMargings`, `valignment`, `docXmpContent`, `bDE*`,
  `dpiRes`; `exportDoNewLine` es un número.
- Valores por defecto distintos: `linesPerInch` 6 frente a 600; `language` sin definir frente a -1.
- Falta `embeddedFiles`.

`ngx-reportman-lib`:

- `designer-interface-size-pos.ts:124-127` devuelve `align` para `posX` y `posY`.

Motor C# (`tonimartir/reportman`):

- `MetaObjectPolygon.cs:55-62` guarda los campos en otro orden que al leerlos.
- `MetaObjectExport.cs:50-51` escribe `TextExpP` dos veces.
- `EvalFunctions.cs:777`: `FLOATTODATETIME` usa `Convert.ToDateTime(double)`, que .NET no admite.
- `BaseReport.cs:2240`: `NUMPAGINA` está tratado pero nunca se registra.
- `BaseReport.cs:1598-1607`: `PARAMINFO` lee `Selected` como índices, mientras el formulario guarda
  valores.
- `DatabaseInfo.cs:956-1017`: `GetDataReaderFromSQL` usa `Connection.CreateCommand()`, que falla
  con el Agent porque `Connection` es nulo.
- `IdenFunction`: una llamada anidada a la misma función en un argumento que no es el primero
  (`MAX(a, MAX(b,c))`) parece sobrescribir los argumentos de la llamada exterior.
- `PrintOutPDFBase.cs:694-719`: `GraphicExtent` da 0×0 para PNG (afecta a `DrawStyle=Full`).
- Ruta FreeType: `singleline` se acepta y no se usa, y `LastLine` solo marca la última línea de
  todo el texto, así que el justificado alarga también la última línea de cada párrafo.

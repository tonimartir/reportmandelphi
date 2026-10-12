# Proveedor de texto Core Text para macOS (plan)

Plan del 12-10-2026. Objetivo: que en macOS el motor **mida y pinte con el mismo
motor de texto del sistema**, como Windows con DirectWrite, en lugar de medir con
HarfBuzz + FreeType y pintar con la LCL Cocoa (que hoy convierte los glifos en
caracteres sueltos: la lam-alif pierde la alif, las letras árabes salen sin unir
y el espaciado no cuadra con lo medido).

## Situación actual

| | Mide (TextExtent, PDF) | Pinta (vista previa, impresión) |
|---|---|---|
| Windows (VCL y LCL) | DirectWrite (`rpinfoprovgdi`, `RpDirectWriteRenderer`) | DirectWrite / GDI |
| Linux (LCL GTK) | HarfBuzz + FreeType + ICU + fontconfig (`rpinfoprovft`) | Cairo con los glifos y el fichero de FreeType |
| macOS (LCL Cocoa) | HarfBuzz + FreeType + ICU + fontconfig (`rpinfoprovft`) | `DrawRunLCL`: carácter a carácter con `TextOut` (**roto**) |

La interfaz que hay que cumplir es `TRpInfoProvider` (`rpinfoprovid.pas`):
`FillFontData`, `TextExtent`, `NFCNormalize`, `GetCharWidth`, `GetGlyphWidth`,
`GetKerning`, `GetFontStream`, `GetFullFontStream`. `TextExtent` devuelve
`TRpLineInfoArray`: por línea, sus `TGlyphPos` (glifo, posición y avance en
twips, cluster, `FontFamily` del glifo cuando el sistema ha sustituido la fuente,
estilo, tamaño y color del segmento HTML). El PDF (`rppdffile.pas`, ~4930) cambia
de fuente glifo a glifo con `FontFamily` y la resuelve con `FillFontData`.

## Correspondencia DirectWrite → Core Text

| DirectWrite (`rpinfoprovgdi`) | Core Text (`rpinfoprovct`) |
|---|---|
| `IDWriteTextFormat` + rangos del HTML en `IDWriteTextLayout` | `CFAttributedString` con un `CTFont` por rango |
| Corte de líneas por anchura del layout | `CTTypesetterSuggestLineBreak` + `CTTypesetterCreateLine` |
| `TTextExtentRenderer.DrawGlyphRun` | `CTLineGetGlyphRuns` → cada `CTRun` |
| `DWRITE_GLYPH_RUN` (índices, avances, offsets) | `CTRunGetGlyphs`, `CTRunGetPositions`, `CTRunGetAdvances` |
| `clusterMap` (carácter → glifo) | `CTRunGetStringIndices` (glifo → carácter, UTF-16) |
| `bidiLevel` | `CTRunGetStatus` (`kCTRunStatusRightToLeft`) |
| Fuente del run (fallback) | atributo `kCTFontAttributeName` del run |
| DIP (1/96") | puntos (1/72") |
| `NormalizeToNFC` | `CFStringNormalize(kCFStringNormalizationFormC)` |
| Datos de la fuente: `GetFontData` de GDI + subconjunto de HarfBuzz | `kCTFontURLAttribute` (fichero) + cara dentro del `.ttc` + subconjunto de HarfBuzz |

Los headers están en FPC 3.2.2 (`univint`/`MacOSAll`: `CTFont`, `CTFontDescriptor`,
`CTFontManager`, `CTLine`, `CTRun`, `CTTypesetter`, `CTStringAttributes`…); API C,
sin Objective-C. Lo que falte del SDK moderno se declara a mano.

## Diseño

- **Unidad nueva `rtl_fpc/rpinfoprovct.pas`** (`TRpCTInfoProvider`), solo FPC +
  Darwin, hermana de `rpinfoprovgdi`. En `reportman_rtl.lpk` y en
  `build/opm/opm_files.txt` (`-RefreshFileList`).
- **Selección** en `TrpPDFCanvas.Create` (`rppdffile.pas`, compartido con Delphi:
  dentro de `{$IF DEFINED(FPC) AND DEFINED(DARWIN)}`, Delphi no ve nada).
  Interruptor `RP_TEXT_ENGINE=freetype|coretext` para comparar y como vuelta
  atrás; Core Text pasa a ser el de por defecto solo al final (fase 5).
- **Identidad de la fuente.** Lo que mide, lo que pinta y lo que se incrusta
  tiene que ser **la misma cara**. Las de macOS son a menudo colecciones `.ttc`
  (Helvetica, Geeza Pro, PingFang…). Se guarda el nombre PostScript de cada cara
  (`CTFontCopyPostScriptName`) en `TRpTTFontData`; para incrustar, se abre el
  fichero de `kCTFontURLAttribute` y se busca con HarfBuzz la cara con ese nombre
  PostScript (índice dentro del `.ttc`).
- **Sustitución de fuentes (fallback), como ya hace DirectWrite.** En Windows,
  `TTextExtentRenderer.DrawGlyphRun` (`RpDirectWriteRenderer.pas`) compara la
  fuente del run con la pedida y, si es otra, pone en `GlyphPos.FontFamily` el
  nameID 1 de su tabla `name` (`GetFontFamilyFromFontFace`, en caché por cara);
  el PDF cambia de fuente glifo a glifo con ese nombre y la negrita/cursiva
  originales, y el proveedor la resuelve e incrusta como cualquier otra. Core
  Text igual: comparar el `kCTFontAttributeName` del `CTRun` con el `CTFont`
  pedido y usar el nameID 1 de `CTFontCopyTable(kCTFontTableName)`, **no**
  `CTFontCopyFamilyName` (da la familia tipográfica: «Helvetica Neue» para
  «Helvetica Neue Light», y al resolverla se perdería el grosor).
- **Incrustar.** `GetFontStream`: subconjunto de HarfBuzz sobre esa cara, como
  Windows; las variables (CFF2/fvar, p. ej. SF Pro) enteras, como hace
  `rpinfoprovgdi`. HarfBuzz se queda en el `.app` para eso (no para dar forma).
- **Pintar (LCL Cocoa).** `TRpTextPainter.DrawRun` en `lcl/rplcldriver.pas`: el
  `CGContext` del lienzo (`TCocoaContext(Canvas.Handle).CGContext`, igual en el
  bitmap de la vista previa y en el PDF de la impresora) y
  `CTFontDrawGlyphs` con el mismo `CTFont` (nombre PostScript + tamaño) y los
  mismos glifos y posiciones de `TextExtent`. Sin volver a dar forma: mide y
  pinta Core Text.

## Fases

**Fase 0 — Prueba de concepto y referencia (antes de escribir el proveedor).**
- Programa de consola en el Mac: maqueta con `CTTypesetter` textos de prueba
  (árabe con «لا» y «الاستدلال», mezcla bidi con números y `{{…}}`, ligaduras
  latinas «fi», emoji, CJK, HTML con dos fuentes) y vuelca runs, glifos,
  posiciones, índices de texto, dirección y fuente de cada run. Confirma el
  orden de los runs y de los glifos RTL, y qué da `StringIndices` en una
  ligadura (dos caracteres → un glifo).
- Referencia: PDF y vista previa (`LclSnapshotTest`) de un juego de informes
  (`htmltest`, `bold`, árabe, `sample4`, rotados, justificados, CJK, emoji) con
  el proveedor actual.
- **Punto de decisión:** si el modelo de datos de Core Text no encaja con
  `TGlyphPos`/clusters, se para y se replantea.

**Resultados de la fase 0 (12-10-2026, macOS 15.8.1).** Programa:
`tests/fpc/CoreTextProbe/ctprobe.lpr` (`fpc -FUlib -FElib -k-framework -kCoreText
ctprobe.lpr`). Referencia con el proveedor actual en el Mac de pruebas,
`~/ctref/ft`: PDF del motor (`PdfTest <informe> <pdf>`) e instantáneas de la
vista previa (`LclSnapshotTest`) de `htmltest`, `arab2wordwrap`, `bold`,
`boldold` y `sample4`; volcado de la prueba en `~/ctref/ctprobe.out`.

- **Los headers de FPC sirven** (`MacOSAll`); hay que enlazar el framework
  `CoreText` explícitamente (`{$linkframework CoreText}` en la unidad), si no
  falta `CTFontCreateCopyWithSymbolicTraits`.
- **El modelo encaja con `TGlyphPos`**, con la misma semántica que HarfBuzz y
  DirectWrite: los runs de una línea vienen en orden visual (de izquierda a
  derecha) y los glifos de cada run también; cada glifo lleva el índice UTF-16
  del primer carácter de su cluster (en un run RTL, decrecientes). Una ligadura
  es un glifo con el índice de su primer carácter: lam-alif de «الاستدلال» y «لا»
  (un glifo para dos caracteres, Arial), «ffi», «ffl», «fi» (Hoefler Text).
- **Corte de líneas**: `CTTypesetterSuggestLineBreak` corta bien árabe y texto
  con dos fuentes; el espacio final de una línea RTL sale como un run aparte.
- **Sustitución**: Apple Color Emoji (emoji), PingFang SC (chino: cara 144 de
  232 de `PingFangUI.ttc`, en `/System/Library/PrivateFrameworks/...`, legible),
  Hiragino Sans W3 (japonés). Arial de macOS tiene árabe: no sustituye.
- **El nameID 1 no sirve en macOS para volver a la misma cara** (decisión
  cambiada respecto al diseño de arriba):
  - puede estar localizado: el primero de PingFang SC es «蘋方-簡» y
    `CTFontCreateWithName` con él da Helvetica;
  - Apple pone el grosor en el nameID 2: el nameID 1 de Helvetica Neue Light es
    «Helvetica Neue», y al resolverlo se pierde el Light.
  Para los runs sustituidos, `TGlyphPos.FontFamily` llevará el **nombre
  PostScript** (`PingFangSC-Regular`), que `CTFontCreateWithName` resuelve a esa
  cara exacta; `FillFontData`, si el nombre es un PostScript que existe, toma
  esa cara sin volver a aplicar negrita/cursiva. (En Windows el nameID 1
  localizado no molesta: GDI acepta nombres de familia localizados.)
- **Cara dentro del `.ttc`**: su posición en
  `CTFontManagerCreateFontDescriptorsFromURL`; confirmar en la fase 1 que es el
  mismo índice que el de HarfBuzz al incrustar.
- **Pregunta abierta**: Apple Color Emoji es de mapas de bits (`sbix`), sin
  contornos: ver cómo se incrusta en el PDF (hoy y con Core Text).
- **`LclSnapshotTest` no detecta el fallo actual** (pasa 18 de 18 con el árabe
  mal dibujado): comprueba posiciones, recortes y colores, no los glifos. En la
  fase 5 hace falta una comprobación que compare la vista previa con el PDF
  rasterizado.

**Fase 1 — Esqueleto.** Resolver familia + negrita + cursiva → `CTFont`
(con caché), `FillFontData` (ascent, descent, capheight, bbox, italic angle,
unidades por em, nombre PostScript, fichero y cara), anchuras de carácter y de
glifo (`CTFontGetGlyphsForCharacters`, `CTFontGetAdvancesForGlyphs`), flujos
de la fuente. `TextExtent` de una línea LTR. `sample4.rep` a PDF.

**Resultados de la fase 1 (12-10-2026).** `rtl_fpc/rpinfoprovct.pas`
(`TRpCTInfoProvider`, hereda de `TRpFTInfoProvider` solo la incrustación),
en `reportman_rtl` y elegido en `TrpPDFCanvas.Create` con
`RP_TEXT_ENGINE=coretext`. Prueba: `tests/fpc/CoreTextProviderTest` (compara
con FreeType la cara, las métricas, las anchuras, el kerning y la fuente
incrustada; sale con 1 si algo falla).

- Con la misma cara (Arial normal/negrita/cursiva, Times New Roman, Courier
  New, Helvetica Neue Bold, Geeza Pro) las métricas y las anchuras son
  idénticas a las de FreeType (diferencia 0,000 milésimas); un carácter sin
  glifo mide lo que el `.notdef`, como en FreeType.
- La cara se encuentra en su fichero también en las colecciones (Helvetica
  Neue Bold es la 1, Light la 7) y la fuente incrustada es esa cara (se
  comprueba por los avances de los glifos usados: el subconjunto de HarfBuzz
  conserva los números de glifo pero no el nombre).
- Diferencias que son correcciones:
  - **Helvetica**: FreeType elige Verdana en macOS (el apaño de Linux
    Helvetica → Cantarell; fontconfig cae en Verdana); Core Text, Helvetica.
    Hoy los informes con `LFontName` Helvetica salen en Verdana en el Mac.
  - **Métricas de las colecciones**: `ReadOS2Metrics` de FreeType lee la
    cabecera de la colección y no la tabla OS/2 de la cara (Geeza Pro:
    interlineado 807 frente a 136); Core Text lee la tabla de la cara.
  - **Kerning**: FreeType devuelve 0 en macOS; Core Text lee la tabla `kern`
    (formato 0) en milésimas de em, como hace Windows.
- **Fuentes variables** (fase 3): «PingFangSC-Regular» es la instancia
  `wght`=400 de la cara 16 «PingFang SC» de `PingFangUI.ttc` (28 caras
  variables; la instancia por defecto es PingFangSC-Medium). Se encuentra la
  cara por familia y se guardan los valores de los ejes
  (`CTFontCopyVariation`); falta incrustar la instancia (subconjunto de
  HarfBuzz fijando los ejes). Hoy se incrusta el fichero entero (56 MB) con la
  instancia por defecto, igual que con FreeType.
- **El PDF de `sample4.rep` pasa a la fase 2**: guardado con «PrinterFonts =
  Recalculate», el PDF fuerza la forma compleja en todo el texto
  (`UsePdfFonts`), así que todo va por `TextExtent`; es el camino de los
  informes actuales.

**Fase 2 — TextExtent completo.** Varios párrafos (`DividesIntoLines`), corte
por palabras, una sola línea, RTL con la semántica de `BidiParagraphLevel`
(dirección de escritura del párrafo), clusters y `LineCluster` como
`RpDirectWriteRenderer`, segmentos HTML (`rphtmlparser`) como rangos
atribuidos (familia, tamaño, estilo, color), sustitución de fuentes,
`NFCNormalize`.

**Resultados de la fase 2 (12-10-2026).** `TRpCTInfoProvider.TextExtent`:
párrafos (CR, LF, CR LF, sobre el texto UTF-16), una cadena atribuida por
párrafo con la fuente de cada segmento HTML y la dirección del párrafo
(`BidiParagraphLevel`: la primera letra fuerte, y sin ella la del objeto),
`CTTypesetter` (forma, bidi, sustitución, corte por anchura con
`CTTypesetterSuggestLineBreak`), runs y glifos en orden visual. Contrato:
`XAdvance`/`XOffset`/`YOffset` en twips calculados desde las posiciones
absolutas de Core Text (sin acumular redondeos); `Position` desde 1 en el
texto, `Text` la línea, `LineCluster` desde 0 en `Text`; `FontFamily` la del
segmento o `LFontName`, y en un run sustituido `@` + el nombre PostScript de
su cara (`CRpCTFaceMark`: esa cara exacta, sin el estilo del texto); se
quitan los blancos de los extremos de la línea; altura y línea base de las
fuentes de la línea; un párrafo en blanco conserva su altura.

- `CoreTextProviderTest` comprueba: lam-alif como un glifo, ningún glifo 0,
  cada glifo en su carácter (`CharCode = Text[LineCluster+1]`), corte por
  anchura, HTML (negrita, cursiva, fuente por segmento), sustitución marcada
  (emoji, chino), párrafo en blanco, ligadura «ffi».
- PDF con `RP_TEXT_ENGINE=coretext` de `htmltest`, `arab2wordwrap`, `bold`,
  `boldold` y `sample4` (en `~/ctref/ct` del Mac, frente a `~/ctref/ft`):
  - `arab2wordwrap`: con FreeType el PDF de hoy sale **roto** (cuadros con
    interrogación, líneas que faltan); con Core Text, completo, ligado y
    cortado.
  - `htmltest`: los segmentos HTML en su sitio (con FreeType, desplazados en
    el texto árabe) y las ligaduras árabes correctas.
- Fallos del proveedor de FreeType que este no repite:
  - `ParseHtml` da los segmentos en UTF-8 y FreeType mide su longitud en
    bytes para situarlos en el texto UTF-16: en HTML con texto no ASCII los
    estilos y las fuentes caen desplazados.
  - `DividesIntoLines` recibe un `string` de 8 bits en FPC: las posiciones de
    los párrafos son de bytes de UTF-8.
  - Una línea en blanco desaparece (el texto de debajo sube); DirectWrite la
    conserva.
  - Mide con `LFontName` pero marca los glifos con `WFontName`: el PDF los
    dibuja con otra fuente.
  - Altura de línea: DirectWrite, sin `USE_TYPO_METRICS`, hace la línea al
    menos `usWinAscent + usWinDescent`; FreeType se queda con la de `hhea`
    (Helvetica: 1000 frente a 1175, líneas que se pisan).
- Pendiente para la fase 3: `ToUnicode` en FPC compara el texto de la línea
  (`string` de 8 bits, UTF-8) carácter a carácter con `CharCode` (UTF-16), así
  que con texto no ASCII no atribuye las ligaduras (solo afecta a copiar
  texto del PDF; igual con FreeType).
- La vista previa y la impresión LCL miden ya con Core Text si se elige, pero
  siguen pintando carácter a carácter (`DrawRunLCL`) hasta la fase 4.

**Fase 3 — PDF.** Selección en `rppdffile`, incrustar las caras sustitutas,
`ToUnicode` de las ligaduras (`glyphText`), PDF/A-3.

**Fase 4 — Pintar.** Core Text en `TRpTextPainter` (vista previa e impresión):
glifos con `CTFontDrawGlyphs`, rotación, recorte; subrayado y tachado ya los
dibuja el driver. Se retira `DrawRunLCL` en Cocoa.

**Resultados de las fases 3 y 4 (12-10-2026).**

- **Pintar (fase 4)**: `lcl/rpcocoatext.pas` (en `reportman_lcl`) dibuja con
  `CTFontDrawGlyphs` sobre el `CGContext` del lienzo de la LCL Cocoa (el mapa
  de bits de la vista previa y el contexto PDF de Printer4Lazarus) los glifos
  y posiciones de `TextExtent`, con el mismo `CTFont`; cada glifo se coloca
  trasladando el sistema de coordenadas (giro y volteo en la matriz de
  texto). `TRpTextPainter` lo usa (`UseCocoa`) cuando el proveedor es Core
  Text; si no, sigue `DrawRunLCL`. `LclSnapshotTest` con
  `RP_TEXT_ENGINE=coretext`: 18/18 y el árabe de `htmltest` unido.
- **Caras sin contornos incrustables (fase 3)**: las caras de PingFang en
  macOS 15 no tienen `glyf` ni `CFF`, sino `hvgl` (formato propio de Apple):
  ni HarfBuzz ni un visor de PDF lo leen, así que el chino no se puede
  incrustar con ellas. La lista de sustitución por defecto de Core Text
  (`CTFontCopyDefaultCascadeListForLanguages`) pone PingFang antes que
  Hiragino Sans GB (`CFF`); el proveedor aplica a cada fuente esa lista sin
  las caras `hvgl` y `CFF2` (`kCTFontCascadeListAttribute`), y el chino sale
  en Hiragino Sans GB.
- **Instancias de fuentes variables `glyf`**: `GetFontStream` hace el
  subconjunto de HarfBuzz fijando cada eje en el valor de la instancia
  (`hb_subset_input_pin_axis_location`, HarfBuzz ≥ 6).
- **Texto que se copia del PDF** (`rppdffile.pas`):
  - en FPC el `ToUnicode` recorría el texto en UTF-8 como si fuera UTF-16
    (copiar árabe o una ligadura daba basura): ahora UTF-16 en
    `TextoDeCadaGlifo` y en el CMap, dentro de `{$IFDEF FPC}`;
  - `/W` solo declaraba el glifo nominal de cada carácter: las formas unidas
    del árabe y las ligaduras quedaban con `/DW 1000` (un em), y al copiar el
    visor partía las palabras árabes letra a letra. Ahora declara también los
    glifos de `glyphsInfo` (afecta a todas las plataformas, también Delphi:
    es un fallo del PDF).
- `tests/fpc/CoreTextProviderTest/run_macos.sh`: la prueba del proveedor, y
  `htmltest`/`arab2wordwrap` a PDF con Core Text cuyo texto extrae PDFKit
  (`pdftext.swift`) con las palabras árabes enteras.
- Pendiente: los emoji de Apple Color Emoji son mapas de bits (`sbix`): en el
  PDF no tienen contornos (igual que con FreeType). Y una familia que no
  existe en el Mac («Noto Nask Arabic» de `htmltest.rep`) cae en la fuente
  por defecto del sistema; fontconfig elegía la más parecida.

**Fase 5 — Pruebas, documentación y paso a por defecto.**
`LclSnapshotTest` (vista previa = PDF) y `PdfTest` en el Mac; comparación con la
referencia de la fase 0; impresión real (RM_PDF y la HP); `docs/macos.md`,
`CLAUDE.md`, lista del OPM; `.dmg` nuevo con Actions (con visto bueno).

## Riesgos y preguntas abiertas

- Orden de los runs y de los glifos RTL en `CTLine` (fase 0).
- Cortes de línea de Core Text frente a los de ICU: los informes pueden cortar
  distinto que en Linux (como ya pasa entre Windows y Linux).
- Identidad de la cara entre medir e incrustar: con el mismo criterio que
  Windows (nameID 1 + negrita/cursiva) la resolución de vuelta tiene que dar la
  misma cara; en macOS además dentro de un `.ttc` (se localiza por nombre
  PostScript). Comprobarlo en la fase 0 con Geeza Pro, Helvetica Neue Light y
  un emoji.
- Fuentes variables del sistema (SF Pro): incrustar enteras, como Windows.
- Rendimiento: caché de `CTFont` por familia/estilo/tamaño.
- Hilos: el servidor de informes mide en varios hilos; los objetos Core Text
  inmutables son seguros entre hilos, los `CTFont` en caché se comparten con
  cuidado.
- La LCL de **Windows** pinta también con `DrawRunLCL` (glifos de DirectWrite
  convertidos en caracteres): probablemente tiene el mismo defecto con las
  ligaduras árabes. Fuera de este plan; revisar después.

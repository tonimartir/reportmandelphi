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

**Fase 2 — TextExtent completo.** Varios párrafos (`DividesIntoLines`), corte
por palabras, una sola línea, RTL con la semántica de `BidiParagraphLevel`
(dirección de escritura del párrafo), clusters y `LineCluster` como
`RpDirectWriteRenderer`, segmentos HTML (`rphtmlparser`) como rangos
atribuidos (familia, tamaño, estilo, color), sustitución de fuentes,
`NFCNormalize`.

**Fase 3 — PDF.** Selección en `rppdffile`, incrustar las caras sustitutas,
`ToUnicode` de las ligaduras (`glyphText`), PDF/A-3.

**Fase 4 — Pintar.** Core Text en `TRpTextPainter` (vista previa e impresión):
glifos con `CTFontDrawGlyphs`, rotación, recorte; subrayado y tachado ya los
dibuja el driver. Se retira `DrawRunLCL` en Cocoa.

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

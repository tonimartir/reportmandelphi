# Port de Report Manager a Free Pascal / Lazarus: plan y estado

Este documento sustituye al plan de trabajo original de Gemini Flash 3.8, que
solo describía la subfase 4.3. Reúne todas las fases del port con su estado
real a 27-09-2026 y corrige lo que aquel plan daba por hecho y no se cumplía.
El detalle de la Fase 6 (ejecutable, instalador Linux, Docker, release) está
en `docs/fase6_plan.md`; la guía de usuario, en `docs/linux-install.md`, y el
paquete del Online Package Manager de Lazarus, en `docs/opm.md`.

Autoría: fases 1 a 5.4 por Gemini Flash 3.8 (18 a 27-09-2026); la subfase 5.5
de estabilización y la Fase 6, por Claude.

## Objetivo

- Motor de informes compilable con FPC 3.2.2 en Windows y Linux, con salida
  PDF/SVG/PNG/texto y el mismo resultado que la versión Delphi.
- Vista previa y diseñador LCL (Lazarus 4.x; Linux con GTK2) equivalentes al
  diseñador VCL de Delphi.
- Todo ello **sin cambiar el producto Delphi**, que comparte las unidades del
  motor.

## Reglas (no negociables)

1. **Unidades compartidas.** Las unidades `rp*.pas` de la raíz son también el
   producto Delphi. Delphi solo puede ver arreglos de bugs genuinos (que se
   corrigen en código común, para los dos compiladores); todo lo demás del port
   va dentro de `{$IFDEF FPC}`. Se verifica comparando el código tal como lo ve
   Delphi (con los bloques FPC eliminados) antes y después de cada cambio.
2. Trampas que la compilación Win32/Win64 de Delphi no detecta:
   - `{$DEFINE}` globales en `rpconf.inc` (por ejemplo `USEZEOS` solo para FPC);
   - unidades de FPC en el `{$ELSE}` de `{$IFDEF MSWINDOWS}` (rompen Delphi
     Linux64);
   - BOM UTF-8: los proyectos Delphi no fijan la página de códigos, así que un
     fichero sin BOM se lee como cp1252, y FPC trata un BOM como
     `{$codepage utf8}`. No añadir ni quitar BOM.
   - Varias unidades mezclan Latin-1 y UTF-8 en comentarios: editar sin
     reescribir esos bytes.
3. Código solo FPC: `rtl_fpc/`, `lcl/`, `design_lcl/`, `packages/fpc*`,
   `tests/fpc/`, `repman/lcl_designer/`, `build/linux/`, `build/opm/`.
4. Nada de rutas de desarrollador en paquetes, proyectos ni código.
5. Cada cambio se verifica en: grupo Delphi Win32/Win64 + Linux64 +
   paquetes 13.0; paquetes FPC en Windows y Linux; `LclDesignerTest
   --selftest`, `LclSnapshotTest` y `PdfTest` en los dos sistemas.

## Paquetes y compilación

| Paquete | Contenido |
|---|---|
| `packages/fpc/reportman_rtl.lpk` | Motor: unidades de la raíz + `rtl_fpc/`; requiere Zeos (`zcomponent`) |
| `packages/fpc_lcl/reportman_lcl.lpk` | Runtime LCL: vista previa, driver LCL, diálogo de parámetros (`lcl/`) |
| `packages/fpc_lcl/reportman_designlcl.lpk` | Diseñador LCL, Monaco/WebView2 en Windows (`design_lcl/`) |

Los tres son `RunAndDesignTime` y compilan en una sola pasada, igual que desde
el IDE o el OPM:

```bat
packages\fpc\build_fpc.bat            (Linux: packages/fpc/build_fpc.sh)
C:\lazarus\lazbuild.exe --ws=win32 --no-write-project tests\fpc\LclDesignerTest\LclDesignerTest.lpi
tests\fpc\LclDesignerTest\LclDesignerTest.exe --selftest
```

## Fases

| Fase | Contenido | Commits | Estado |
|---|---|---|---|
| 1 | Paquete del motor para FPC; texto complejo (DirectWrite en Windows, FreeType/HarfBuzz en Linux); datos MyBase/MIDAS XML con `TBufDataset`; SQLite vía la abstracción FireDAC; paquete `reportman_lcl` y vista previa; exportar a PDF/A-3 y PNG | 3e03a06 … cb66d67 | Hecha |
| 2 | Marco del diseñador visual LCL, carpetas `rtl_fpc`/`lcl`/`design_lcl`, selección, tiradores y reglas | 6ae4ff3 … 961fa31 | Hecha |
| 3.1–3.5 | Inspector de objetos; paleta y herramientas; árbol de estructura y explorador de datos; configuración de datos y secciones; configurar página, vista previa, editor SQL Monaco; `TFRpMainFLCL` reutilizable y `TRpDesignerLCL.Execute`; registro de componentes en la paleta de Lazarus | c6baddd … d288b33 | Hecha |
| 4.1–4.3 | Diálogos: editor de expresiones, rejilla, acerca de; asistente de informes, selección de campos, secciones externas; parámetros, búsqueda de valores y librería de informes en base de datos | 81c911d … 0d10358 | Hecha (4.3 completada en 5.5) |
| 5.1–5.4 | Deshacer/rehacer: motor (`rpmdundocuelcl`), panel de historial, instrumentación de acciones, atajos y estado modificado | a2a6684 … b725f80 | Hecha (corregida en 5.5) |
| 5.5 | Estabilización: aislamiento de Delphi, infraestructura, sin pérdida de datos, undo fiable, tests de regresión reales, bugs comunes corregidos también en Delphi | a7c6c89 … 1014d29 | Hecha |
| — | Compilación en una sola pasada (CRC de `rpsection`), zip OPM, Base64 binario seguro en FPC, paridad del inspector con la VCL, vista previa Linux con Cairo/FreeType igual que el PDF | 57961c6 … cc8e917 | Hecha |
| 6 | Diseñador autónomo, `.deb` + AppImage construidos en Docker, pruebas en máquinas limpias, enganche al release de SourceForge | 07bfa5a … b3ea54b | Hecha salvo pruebas manuales y subida (ver `fase6_plan.md`) |

### Subfase 5.5: qué se corrigió

- **P0, aislamiento de Delphi** (a7c6c89): todo el trabajo del port quedó bajo
  `{$IFDEF FPC}`; Delphi compila de nuevo exactamente el código anterior al
  port salvo arreglos genuinos (claves PDF `/CIDToGIDMap` y `/Length1`, fuga de
  anotaciones, lecturas fuera de rango en `rpinfoprovid`/`rpHarfBuzz`, mensaje
  de FireDAC). `USEZEOS` solo para FPC; `dynlibs` solo en FPC (rompía Delphi
  Linux64); BOM restaurados.
- **P3, infraestructura** (d98e24b): fuera los paquetes duplicados de la raíz y
  `packagefiles.xml` con rutas absolutas; `build_fpc.bat/.sh`; tests que usan
  los paquetes sin rutas al motor.
- **P1/P2, diseñador** (33c8b25, 5b4a150): abrir un informe no deja uno a
  medias; todos los diálogos registran deshacer o marcan el informe como
  modificado; configuración de datos sobre copias (Cancelar funciona);
  deshacer consistente ante fallos, orden Z, inspector con valores del modelo;
  deshacer el borrado de parámetros/conexiones/datasets ya no los recrea
  vacíos (el mismo fallo estaba en la VCL y se corrigió también en Delphi).
- Bugs comunes corregidos en Delphi al mismo tiempo (41391af, 1014d29): deshacer
  en la VCL, color de fondo por defecto del metafile, reserva de fuentes,
  expresiones de gráfico y BidiModes al deshacer un borrado.

### Correcciones al plan original de la 4.3

| El plan decía | Lo que hay |
|---|---|
| (no mencionaba las unidades compartidas) | Regla 1: el port había cambiado código que compila Delphi; se aisló en P0 |
| Pruebas "exhaustivas" en `umainform.pas` | Aquellas pruebas creaban los diálogos y comprobaban poco más (que la lista de parámetros se rellenaba, que existían los controles). Las pruebas de comportamiento están en `tests/fpc/LclDesignerTest/uregressiontests.pas` (asserts sobre el estado del modelo tras cada acción, vigilante de diálogos modales) |
| `rprflclparams.BSearchClick` llama a `ParamValueSearch` | `reportman_lcl` no puede depender del diseñador: el botón usa el gancho `GlobalParamValueSearch`, que instala `design_lcl/rpmdfsearchlcl.pas`. Sin el paquete del diseñador el botón de búsqueda no se muestra |
| `SelectReportFromLibrary` con un árbol propio | Se sustituyó por el port del árbol de la VCL (tablas `REPMAN_REPORTS`/`REPMAN_GROUPS`), con carga segura y guardado de vuelta a la librería |
| Diálogo de parámetros | Faltaban `UpdateValue` de la VCL, los errores de conversión visibles y el deshacer diferido (`deferUndoUntilAccept`) |
| Compilar solo `reportman_designlcl.lpk` | Se compilan los tres paquetes con `build_fpc.bat` (el motor también cambia) |
| Textos con IDs de `TranslateStr` | Varios IDs eran inventados; se sustituyeron por los de la VCL |

## Pendiente

- **Traducción del diseñador LCL**: menús y varios formularios tienen el texto
  fijo en español; pasar a `TranslateStr` con los IDs de la VCL (textos por
  defecto en inglés) y traducir también los textos propios de la LCL
  (`LCLStrConsts`) con los `.po` de Lazarus. El idioma ya se detecta en
  Linux (`LC_ALL`/`LC_MESSAGES`/`LANG`).
- **Widgetset de Linux** (decidido 27-09-2026, en implementación): Qt6 pasa a
  ser el principal (`.deb` `reportman-designer` y AppImage), con
  `libQt6Pas` 6.2.10 compilada en el builder e incluida en el paquete; GTK2 se
  mantiene como `.deb` de transición (`reportman-designer-gtk2`) hasta que
  Debian 14 lo retire. Motivos, medidos: Qt6 pasa el selftest y escala solo
  en HiDPI; GTK2 no escala los iconos y está sin mantenimiento desde 2020;
  GTK3 (alfa en Lazarus 4.8) falla el selftest y se dibuja mal; Qt5 solo
  escala con `QT_SCALE_FACTOR` y su `libqt5pas` es demasiado antigua en
  Ubuntu 22.04 y Debian 12. GTK3 se volverá a evaluar con Lazarus 5, donde
  será el widgetset por defecto.
- **Pruebas manuales** en una VM Ubuntu con escritorio (lista en
  `fase6_plan.md`, 6.6).
- **Publicación**: subir los paquetes del release (`build/sourceforge`, tarea
  06) y enviar el zip OPM (`build/opm`) al Online Package Manager.
- **Traducciones solo junto al ejecutable**: `rptranslator` busca los
  `reportmanres.*` al lado del binario; por eso los paquetes Linux instalan en
  `/opt/reportman-designer`.

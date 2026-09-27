# Report Manager en el Online Package Manager (OPM) de Lazarus

El *Online Package Manager* es el gestor de paquetes integrado en el IDE de
Lazarus (menú **Paquete → Online Package Manager**). Descarga la lista central
`https://packages.lazarus-ide.org/packagelist.json`, baja el zip de cada paquete,
lo descomprime en `<config de Lazarus>/onlinepackagemanager/packages/`, compila
los `.lpk` y, si son de diseño, los instala en el IDE (que se recompila).

Este documento explica qué contiene el paquete OPM de Report Manager, cómo se
regenera y valida, cómo se envía al repositorio central y cómo se publican las
actualizaciones. Todo lo descrito sobre formatos sale del código de OPM
(`C:\lazarus\components\onlinepackagemanager\`, Lazarus 4.8), no de memoria.

**Nada de esto sube ficheros a ningún sitio**: el script solo genera artefactos
en `build\opm\out\`.

## 1. Qué contiene

### Paquetes Lazarus

| Paquete (`.lpk`) | Ruta en el zip | Contenido | Requiere |
|---|---|---|---|
| `reportman_rtl` | `packages/fpc/` | Motor no visual: modelo de informe, evaluador, datos (Zeos, SQLdb/SQLite, texto) y exportación PDF/SVG/HTML/CSV/texto/metafile. Unidades de la raíz + `rtl_fpc/`. | `FCL(1.0)`, `zcomponent(8.0)` |
| `reportman_lcl` | `packages/fpc_lcl/` | Runtime LCL: `TLCLReport`, vista previa, configuración de página, parámetros, impresión (`lcl/`). | `reportman_rtl(4.0.16)`, LCL, Printer4Lazarus, `FCL(1.0)`, DateTimeCtrls |
| `reportman_designlcl` | `packages/fpc_lcl/` | Diseñador visual embebible `TRpDesignerLCL` (`design_lcl/`). | `reportman_rtl(4.0.16)`, `reportman_lcl(4.0.16)`, LCL, `FCL(1.0)` |

Los tres son **RunAndDesignTime**: cada uno registra componentes en la paleta
*Reportman* (`Register` en `rpmreg.pas`, `lcl/rpreglcl.pas` y
`design_lcl/rpmregdesignlcl.pas`) y a la vez los usan las aplicaciones en
tiempo de ejecución (`TRpDesignerLCL` también). Un paquete `DesignTime` no se
podría usar desde un proyecto y uno `RunTime` no registraría la paleta. OPM
instala en el IDE los paquetes RunAndDesignTime, así que tras instalarlos el
IDE se recompila.

Metadatos que viven en los `.lpk` (OPM los lee de ahí al crear el paquete):
`Author` (Toni Martir), `Description` (inglés), `License` (MPL 1.1, con la GPL
como alternativa; ver `LICENSE.TXT`), `Version` = `RM_VERSION` de
`rpmdconsts.pas` (4.0.16 → Major 4, Release 16) y las dependencias con su
versión mínima. Las versiones mínimas entre los tres paquetes de Report Manager
son la propia versión del producto, para no mezclar paquetes de versiones
distintas; `zcomponent(8.0)` es la versión de Zeos probada y la que ofrece OPM
(paquete *ZeosDBO*, que contiene `zcomponent.lpk` 8.0). Al instalar Report
Manager, OPM detecta la dependencia y propone instalar ZeosDBO.

Metadatos que **no** están en los `.lpk` sino en el JSON (en el formulario de
OPM se rellenan a mano; aquí son parámetros del script):

| Campo JSON | Valor por defecto | Parámetro |
|---|---|---|
| `Name` / `DisplayName` | `Report Manager` | `-DisplayName` |
| `Category` | `Reporting` | `-Category` |
| `HomePageURL` | `https://reportman.es` | `-HomePageURL` |
| `DownloadURL` (*Update link (JSON)*) | `https://reportman.es/opm/update_ReportManager.json` | `-UpdateBaseURL` |
| `SVNURL` | `https://github.com/tonimartir/reportmandelphi` | `-SVNURL` |
| `CommunityDescription`, `ExternalDependecies` | textos en inglés | `-CommunityDescription`, `-ExternalDependencies` |
| `LazCompatibility` | `4.8.0, 4.6.0, …, 3.0.0` | `-LazCompatibility` |
| `FPCCompatibility` | `3.2.2` | `-FPCCompatibility` |
| `SupportedWidgetSet` | `gtk2, win32/win64` | `-SupportedWidgetSet` |
| `PackageBaseDir` | `reportman` | `-BaseDir` |

Las compatibilidades solo se muestran y sirven para filtrar en OPM; no
bloquean la instalación. Probado: Lazarus 4.8 (Windows, win32) y Lazarus 3.0
(Linux, gtk2), ambos con FPC 3.2.2.

### Ficheros

`build\opm\opm_files.txt` enumera los **141 ficheros** que necesitan los tres
paquetes: las unidades que FPC compila (también las que no figuran en los
`.lpk` pero se encuentran por la ruta de búsqueda, como `rphtmlparser.pas` o
`rptruetype.pas`), los `.inc` (`rpconf.inc`, `rpfdmidas.inc`, `zconf.inc`),
los `.lfm`, `.lrs` y `.dcr`, los recursos `REPORTMANRES.RES` y
`dbxdrivers.RES`, `MonacoEditorAssets.RES` (editor SQL Monaco del diseñador,
solo Windows: `{$R ../MonacoEditorAssets.res}` en
`design_lcl/rpfrmmonacoeditorlcl.pas`), los `.lpk` con sus `.pas` de paquete y
`LICENSE.TXT`.

La lista se obtuvo con `ppudump` de los `.ppu` de un build Windows
(x86_64-win64) y otro Linux (x86_64-linux, gtk2): son exactamente los
ficheros que FPC abre. Linux usa los mismos salvo el recurso de Monaco. Que
está completa se demuestra compilando desde el zip descomprimido (sección 3).

El zip tiene una sola carpeta raíz y dentro la estructura del repositorio, de
modo que las rutas relativas de los `.lpk` (`..\..\rpsection.pas`,
`..\..\lcl\…`) siguen valiendo:

```
reportman/LICENSE.TXT
reportman/rpsection.pas            (y el resto de unidades del motor)
reportman/rtl_fpc/…
reportman/lcl/…
reportman/design_lcl/…
reportman/packages/fpc/reportman_rtl.lpk
reportman/packages/fpc_lcl/reportman_lcl.lpk
reportman/packages/fpc_lcl/reportman_designlcl.lpk
```

Tamaño: ~4,9 MB comprimido (3,9 MB son el recurso de Monaco). No incluye
nada de Delphi/VCL, ejemplos, binarios ni documentación.

## 2. Regenerar el paquete

```powershell
build\opm\make_opm_package.ps1                      # solo genera
build\opm\make_opm_package.ps1 -Validate -ValidateWsl   # genera y valida (sección 3)
```

Pasos que hace el script:

1. Lee `RM_VERSION` de `rpmdconsts.pas` y sincroniza en el árbol de trabajo
   la `<Version>` de los tres `.lpk` y la `<MinVersion>` con la que se
   requieren entre ellos (edición de texto, sin reformatear el XML). Si cambia
   algo lo avisa: **hay que hacer commit**, porque el zip sale de git.
2. Extrae de `git archive HEAD` (o `-Ref <commit|tag>`) solo los ficheros de
   `opm_files.txt`, con fin de línea CRLF fijo (`core.autocrlf=true`), y aplica
   el mismo ajuste de versión a la copia (si `HEAD` no lo tenía, lo avisa).
3. Crea el zip como el formulario *Create repository package* de OPM
   (`opkman_createrepositorypackagefrm.pas` + `opkman_zipper.pas`): solo
   ficheros, rutas con `/`, carpeta raíz `reportman/`, nombre
   `DisplayName` sin espacios + `.zip`. Las entradas llevan la fecha del
   commit, así que el mismo commit en la misma zona horaria da el mismo MD5.
4. Escribe los dos JSON con el formato exacto de OPM (fpjson `FormatJSON`,
   `"clave" : valor`, sangría 2, CRLF):
   - `ReportManager.json`: la entrada de la lista de paquetes
     (`PackageData0` + `PackageFiles0`), como `TSerializablePackages.PackagesToJSON`.
     `RepositoryFileSize` = bytes del zip, `RepositoryFileHash` = MD5 en
     minúsculas (`MD5Print(MD5File())`), `RepositoryDate` = `Now` como
     `TDateTime` escrito como `Str()` de FPC (`4.6292…E+004`), rutas con `\/`
     como separador (`"reportman\\/"`, `"packages\\/fpc\\/"`), `PackageType`
     con la codificación antigua de OPM (0 = RunAndDesignTime) y
     `DependenciesAsString` como `TPkgVersion.AsString` (`zcomponent(8.0)`).
   - `update_ReportManager.json`: el JSON externo de actualizaciones, como
     `TUpdatePackage.SaveToJSON` (propiedades en orden alfabético,
     `DownloadZipURL` = `<UpdateBaseURL>ReportManager.zip`).

Salida en `build\opm\out\` (ignorada por git):

| Fichero | Para qué |
|---|---|
| `ReportManager.zip` | Zip de repositorio (central y de actualizaciones) |
| `ReportManager.json` | Entrada para `packagelist.json` del repositorio central |
| `update_ReportManager.json` | JSON de actualizaciones a publicar en `https://reportman.es/opm/` |
| `validate\` | Copias descomprimidas, configuraciones privadas y logs de la validación |

### Mantener la lista de ficheros

Si se añade o quita una unidad del motor, `-Validate` fallará con *Can't find
unit* o *Can't open include file*. Para regenerar la lista:

```bat
packages\fpc\build_fpc.bat
powershell build\opm\make_opm_package.ps1 -RefreshFileList
```

`-RefreshFileList` pasa `ppudump` por los `.ppu` de `packages\*\lib\<target>`
del árbol de trabajo, añade a `opm_files.txt` lo que falte y lista (sin
borrarlo) lo que ya no aparece. Con `-Target x86_64-linux` usa los `.ppu` de
un build hecho en WSL sobre el mismo árbol (`packages/fpc/build_fpc.sh`) y el
`ppudump` de WSL (el de Windows no lee las fechas de un `.ppu` de Linux). Los
ficheros de una sola plataforma (Monaco) aparecen como "no usados" en la
otra: no se deben borrar.

## 3. Validar como un usuario nuevo de OPM

`-Validate` (Windows) y `-ValidateWsl` (Linux en WSL, gtk2) hacen:

1. Compilan `build\opm\opm_check.pas` con FPC y lo ejecutan. Usa el mismo
   código que OPM: lee `ReportManager.json` como `JSONToPackages` (fpjson,
   `VarToDateTime`, conversión `\/` → separador), lee el JSON de
   actualizaciones con `TJSONDeStreamer`, comprueba tamaño y MD5, descomprime
   con `TUnZipper` calculando `IsDirZipped`/`ZippedBaseDir` como
   `TPackageUnzipper` y verifica que cada `.lpk` queda en
   `<packages>/<PackageBaseDir><RelativeFilePath><Name>`.
2. Copian Zeos (`-ZeosDir`, por defecto
   `C:\desarrollo\tools\delphicomponents\zeosxe10`, sin `lib\`) junto al
   paquete, como lo dejaría OPM tras instalar ZeosDBO, y lo registran en una
   configuración de Lazarus **privada** (`lazbuild --pcp=…`), nunca en la del
   IDE del usuario.
3. Compilan los tres paquetes desde la copia descomprimida en orden de
   dependencias y con compilación limpia (`lazbuild -B`), que es lo que hace
   el instalador de OPM (`opkman_installer.pas`: `DoCompilePackage` con
   `pcfCleanCompile`).

El script termina con código 2 si algo no sale OK. Los logs quedan en
`build\opm\out\validate\`.

### Resultado actual (4.0.16, 2026-09-27)

| Comprobación | Windows (Lazarus 4.8, win32) | Linux (WSL, Lazarus 3.0, gtk2) |
|---|---|---|
| `opm_check` (JSON, MD5, descompresión) | OK | OK |
| `reportman_rtl` (`-B`, primera compilación) | OK | OK |
| `reportman_lcl` (`-B`) | OK | OK |
| `reportman_designlcl` (`-B`) | OK | OK |

Todo compila en una sola pasada desde el zip, con Zeos recién compilado y
una configuración de Lazarus vacía, así que la lista de ficheros está completa.

Antes del commit 57961c6 la segunda compilación fallaba con `Can't find unit
rpsecutil used by rpsubreport`: el ciclo `rpsection` → `rpsubreport` →
`rpsecutil` dejaba `rpsecutil.ppu` con un checksum obsoleto tras una
compilación limpia (ver `CLAUDE.md`). OPM compila cada paquete una sola vez,
así que ese fallo rompería la instalación. Si vuelve a aparecer, el script lo
detecta, prueba a tocar `rpsecutil.pas` y recompilar `reportman_rtl` (solo
para distinguir una regresión de ese problema de un fichero que falte) y
termina con error igualmente.

No se valida la recompilación del IDE que hace OPM al instalar paquetes de
diseño (reemplazaría el `lazarus.exe` del usuario). Para eso, prueba manual en
un Lazarus desechable (sección 6).

## 4. Enviar el paquete al repositorio central

Según el código de OPM y su wiki
(<https://wiki.freepascal.org/Online_Package_Manager>), hay dos caminos. En
ambos el mantenedor de OPM revisa el paquete (malware, licencia…) antes de
añadirlo a `packagelist.json`.

**A. Desde el IDE (formulario de OPM).** En **Paquete → Online Package
Manager**, botón **Create → Create repository package**:

1. *Package directory*: la carpeta `reportman` **descomprimida del zip
   generado** (por ejemplo `build\opm\out\validate\win\packages\reportman`
   antes de compilar, o una extracción limpia). No la raíz del repositorio:
   OPM busca `.lpk` recursivamente y metería el `reportman.lpk` histórico y
   los de `tests/`, y además comprimiría todo el repositorio.
2. En el nodo raíz: *Category* `Reporting`, *Display name* `Report Manager`,
   *Home page*, *Update link (JSON)*
   `https://reportman.es/opm/update_ReportManager.json`, *SVN*, *Community
   description* y *External dependencies* (los valores de la tabla de la
   sección 1). Marcar *JSON for updates* si se quiere que genere también el
   JSON de actualizaciones.
3. En cada `.lpk`: compatibilidad de Lazarus y FPC y widgetsets. Versión,
   descripción, autor, licencia y dependencias salen del `.lpk`.
4. **Create** genera el zip y los JSON en local (equivalentes a los del
   script). **Submit** vuelve a comprimir la carpeta y sube por HTTP el zip,
   `ReportManager.json` y, si se marcó, `update_ReportManager.json` a
   `lazarusopm.org` (`zip.php` / `json.php`; las URL están en base64 en
   `opkman_const.pas`). Al terminar muestra *"Your request will be processed
   in 24 hours"*.

   Al recomprimir, OPM excluye por defecto `*.ppu`, `*.o`, `*.compiled`,
   `*.exe`, `*.dll`, `*.zip`, ficheros sin extensión y las carpetas `lib`,
   `backup`, `units`… (`cExcludedFilesDef` / `cExcludedFoldersDef`); por eso
   conviene partir de una extracción limpia, sin compilar.

**B. Manual.** Publicar `ReportManager.zip` y `ReportManager.json` (por
ejemplo en `https://reportman.es/opm/` o como adjuntos de una release de
GitHub) y enviar los enlaces a `opm@lazarus-ide.org`, o en el hilo de OPM del
foro de Lazarus (<https://forum.lazarus.freepascal.org/index.php/topic,34297.0.html>).

## 5. Actualizaciones mediante el JSON externo

El campo `DownloadURL` de la entrada (*Update link (JSON)* en el formulario)
apunta a `https://reportman.es/opm/update_ReportManager.json`. OPM
(`opkman_updates.pas`) lo descarga periódicamente, sin pasar por el
mantenedor:

- Solo lo hace si el usuario tiene activada la opción *Check for updates* en
  las opciones de OPM (en una instalación nueva el valor es *Never*). La URL
  tiene que contener `.json` y devolver 200; se siguen redirecciones.
- Si `Version` de un `.lpk` es mayor que la instalada, OPM marca el paquete
  en la columna *External repository* y **Update → From third party
  repository** descarga `DownloadZipURL`, lo descomprime sobre
  `packages/reportman/` y recompila/instala. Por eso `DownloadZipURL` debe
  apuntar a un zip con la misma estructura (el `ReportManager.zip` generado).
- OPM compara las versiones **como cadenas** (`"4.0.16.0" < "4.0.17.0"`):
  funciona mientras cada componente mantenga el número de cifras (de 4.0.16 a
  4.0.99, o de 4.0.99 a 4.1.0), pero no detectaría por ejemplo 4.0.9 → 4.0.10.
- `ForceNotify` + `InternalVersion` (`-ForceNotify -InternalVersion N`):
  con `ForceNotify` a `true` solo se avisa cuando `InternalVersion` supera la
  que el usuario tenía al instalar; incrementarlo en cada publicación.
- `DisableInOPM: true` deja el paquete gris en OPM (útil si se publica una
  versión rota); el script lo escribe a `false`.

Para publicar una versión: subir `ReportManager.zip` y
`update_ReportManager.json` a `https://reportman.es/opm/` (sustituyendo los
anteriores). El JSON de actualizaciones no cambia la copia del repositorio
central: para que los usuarios nuevos reciban la versión nueva hay que volver
a enviar el paquete (sección 4).

## 6. Lista de comprobación antes de cada envío

1. `RM_VERSION` actualizado en `rpmdconsts.pas`. Ejecutar el script una vez
   (sincroniza los `.lpk`), revisar y hacer commit de los `.lpk`.
2. Si cambiaron las unidades del motor: `build_fpc.bat` +
   `-RefreshFileList` (y `-Target x86_64-linux` tras `build_fpc.sh` en WSL);
   revisar el diff de `opm_files.txt`.
3. `make_opm_package.ps1 -Validate -ValidateWsl` con todo en OK (código de
   salida 0).
4. Prueba de instalación real en un Lazarus desechable (instalar recompila el
   IDE): servir un repositorio de prueba con
   `ReportManager.json` copiado como `packagelist.json` junto a
   `ReportManager.zip` (`python -m http.server 8000` en esa carpeta), añadir
   `http://localhost:8000/` en *Options → Remote repository*, instalar Zeos
   antes desde el repositorio oficial (el de prueba solo contiene Report
   Manager), instalar los tres paquetes, comprobar que el IDE se recompila,
   que aparece la paleta *Reportman* y que el diseñador abre.
5. Revisar los campos del JSON: categoría, compatibilidades (solo versiones
   probadas), URLs, descripciones.
6. Publicar `ReportManager.zip` y `update_ReportManager.json` en
   `https://reportman.es/opm/` **antes** de enviar, para que el enlace de
   actualizaciones ya funcione cuando el mantenedor lo revise.
7. Enviar (sección 4) desde el mismo commit con el que se generó el zip y
   etiquetarlo.
8. Tras la aceptación, comprobar en OPM (*Refresh*) que aparece *Report
   Manager* con la versión correcta y que se instala.

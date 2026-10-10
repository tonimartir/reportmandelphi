# build\sourceforge\ — release para SourceForge (v se lee de RM_VERSION)

Pipeline en subscripts, uno por tarea, para depurar de uno en uno. Cada uno es
autonomo (exit != 0 si falla) y se puede ejecutar suelto.

| Subscript | Tarea | Salida |
|-----------|-------|--------|
| `01-build-solution.ps1` | Build limpio de `reportmanxe2` en **Release Win32 + Win64** | binarios en `binr32`/`binr64` |
| `01b-build-net2.ps1` | Build .NET **self-contained** (`designer` + `printreport`, win-x64 + win-x86) de `danzai\comunnt\reportman` | `repman\binr64\net2\` (x64), `repman\binr32\net2\` (x86) |
| `02-designer-innosetup.ps1` | Compila los **4** `.iss` con ISCC: Delphi x64/x86 (sin net2) + .NET x64/x86 | `release_<v>\Designer\` (4 instaladores) |
| `03-activex-zip.ps1` | Zipea el OCX por arquitectura | `release_<v>\ActiveX\reportman_ax_<v>_x64.zip` y `_x32.zip` |
| `04-components.ps1` | Fuentes raiz + `packages\`, sin `*.o`/`*.dcu` | `release_<v>\Components\` (carpeta + `reportman_components_<v>.zip`) |
| `05-linux-zip.ps1` | Zipea `printreptopdf` Linux64 | `release_<v>\Linux\printreptopdf_linux_<v>.zip` |
| `06-linux-designer.ps1` | Paquetes Linux del **diseñador LCL** (FPC/Lazarus; Qt6 recomendado y GTK2 transitorio) con `build\linux\build-linux.ps1`: compilación, selftest de los dos, lintian y pruebas en máquinas limpias | `release_<v>\Linux\reportman-designer_<v>_amd64.deb` (Qt6), `reportman-designer-gtk2_<v>_amd64.deb`, `ReportManDesigner-<v>-x86_64.AppImage` (Qt6) y `SHA256SUMS` |

Orquestador: `make-release.ps1` (o `..\make-sourceforge.ps1`). `-SkipBuild` reusa
binarios ya compilados y los paquetes Linux de `build\linux\out\<v>\` si existen.

Requisitos: RAD Studio 37.0 (`rsvars.bat`), MSBuild .NET v4.0.30319,
Inno Setup 6 (`ISCC.exe`); para la tarea 06, Docker dentro de WSL (la imagen
del builder se crea sola la primera vez; ver `docs\fase6_plan.md`).

## Arquitectura de instaladores (definitiva)
4 instaladores de **Designer**:
- `reportman_designer_4_0_8_x64.exe` / `_x86.exe` — Designer **Delphi**, **sin net2** (pequenos).
- `reportman_designer_net_4_0_8_x64.exe` / `_x86.exe` — **Report Manager .NET Designer**, **self-contained** (no requiere .NET instalado); instala net2 en `{app}\net2`, DefaultDir = carpeta del Designer Delphi (editable) + acceso en menu inicio. Si ambos van a la misma carpeta, el Delphi usa el driver .NET. Tambien standalone.

## Notas
- **Versión de los instaladores**: no se escribe a mano. Los cuatro `.iss` incluyen
  `install\version.iss`, que la toma de `RM_VERSION` (`rpmdconsts.pas`); la tarea 02
  la pasa además como `ISCC /DAppVer=<v>`. Los instaladores .NET ya no llevan `beta`
  en el nombre (`reportman_designer_net_<v>_x64.exe`).
- **net2**: `01b-build-net2.ps1` lo publica self-contained (win-x64 -> `binr64\net2`, win-x86 -> `binr32\net2`).
- **Linux**: `binrl64\printreptopdf` debe estar compilado (PAServer) antes de la tarea 05.
  La tarea 05 ya no vacía `release_<v>\Linux\` (lo hace `make-release.ps1` al
  empezar), así que 05 y 06 pueden ejecutarse sueltas en cualquier orden.
  `SHA256SUMS` cubre todo lo que haya en `Linux\` al ejecutar la 06.
- **ActiveX**: el zip lleva solo el `Reportman.ocx`.
- **Components**: fuentes Delphi; el Designer .NET no lo necesita (sus librerias van por NuGet).

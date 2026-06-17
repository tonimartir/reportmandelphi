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

Orquestador: `make-release.ps1` (o `..\make-sourceforge.ps1`). `-SkipBuild` reusa
binarios ya compilados.

Requisitos: RAD Studio 37.0 (`rsvars.bat`), MSBuild .NET v4.0.30319,
Inno Setup 6 (`ISCC.exe`).

## Arquitectura de instaladores (definitiva)
4 instaladores de **Designer**:
- `reportman_designer_4_0_8_x64.exe` / `_x86.exe` — Designer **Delphi**, **sin net2** (pequenos).
- `reportman_designer_net_4_0_8_x64.exe` / `_x86.exe` — **Report Manager .NET Designer**, **self-contained** (no requiere .NET instalado); instala net2 en `{app}\net2`, DefaultDir = carpeta del Designer Delphi (editable) + acceso en menu inicio. Si ambos van a la misma carpeta, el Delphi usa el driver .NET. Tambien standalone.

## Notas
- **net2**: `01b-build-net2.ps1` lo publica self-contained (win-x64 -> `binr64\net2`, win-x86 -> `binr32\net2`).
- **Linux**: `binrl64\printreptopdf` debe estar compilado (PAServer) antes de la tarea 05.
- **ActiveX**: el zip lleva solo el `Reportman.ocx`.
- **Components**: fuentes Delphi; el Designer .NET no lo necesita (sus librerias van por NuGet).

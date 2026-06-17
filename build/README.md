# build\ — scripts de empaquetado (Windows)

Dos scripts autonomos. Cada uno devuelve exit code `!= 0` si algo falla.

## 1) make-client-zip.ps1 — entrega a cliente

Compila **repmandxp.exe** y **reportman.ocx** en las 4 combinaciones
Debug/Release x Win32/Win64 (desde `repman\reportmanxe2.groupproj`,
targets `repmandxp` y `reportman`), los organiza por producto/config/plataforma
y genera un ZIP. En **Debug** incluye ademas el `.map`.

```powershell
.\make-client-zip.ps1                 # autodetecta version (RM_VERSION de rpmdconsts.pas) y compila todo
.\make-client-zip.ps1 -Version 2.8.0.188
.\make-client-zip.ps1 -SkipBuild      # solo re-empaqueta lo ya compilado
```
o doble clic en **make-client-zip.cmd**.

Salida (en `build\dist\`):

```
reportman_<ver>\                      <- la carpeta  (<ver> = RM_VERSION con puntos->'_', p.ej. 4.0.8 -> 4_0_8)
  repmandxp\
    Release\ Win32\ repmandxp.exe       Win64\ repmandxp.exe
    Debug\   Win32\ repmandxp.exe + .map  Win64\ repmandxp.exe + .map
  activex\
    Release\ Win32\ reportman.ocx        Win64\ reportman.ocx
    Debug\   Win32\ reportman.ocx + .map  Win64\ reportman.ocx + .map
reportman_<ver>.zip                   <- el zip (de la carpeta)
```

Se copia **por nombre exacto** (no por glob), para no arrastrar los `dbx*.dll`
ni el `.drc` que conviven en `binr32`.

Requisitos: RAD Studio 37.0 (`rsvars.bat`) y MSBuild .NET Framework v4.0.30319.
Rutas alternativas con `-RsVars` / `-MsBuild`.

## 2) make-sourceforge.ps1 — publicacion en SourceForge (Inno Setup)

**Pendiente** (siguiente fase). Stub con las notas de partida.

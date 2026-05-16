# Copilot Instructions

## Compilacion del diseñador Delphi

- Para compilar el diseñador Delphi XP, no compilar `repmandxp.dpr` directamente.
- El flujo correcto es abrir o compilar el grupo `repman/reportmanxe2.groupproj`.
- Dentro del grupo, el subproyecto correcto es `repmandxp`.
- La configuracion correcta para reproducir el build del diseñador es `Debug`.
- La plataforma correcta es `Win32` (x86 en el IDE).

## Comando correcto desde linea de comandos

Ejecutar desde `c:/desarrollo/prog/toni/reportman/repman`:

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
"C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" reportmanxe2.groupproj /t:repmandxp /p:Config=Debug /p:Platform=Win32 /nologo /v:m
```

## Notas importantes

- Si se intenta compilar `repmandxp.dpr` con `dcc32` directamente, pueden aparecer errores falsos de entorno, rutas o librerias VCL que no reflejan el flujo real del proyecto.
- Para diagnosticar errores reales del diseñador, usar siempre el build del grupo `reportmanxe2.groupproj` con target `repmandxp`.
- Si el usuario dice "compila repmandxp", asumir este flujo salvo que indique otra configuracion o plataforma.
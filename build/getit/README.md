# build\getit\ — paquete de GetIt (RAD Studio 13 / Delphi 13.x)

Report Manager está en GetIt solo para RAD Studio 13
(<https://getitnow.embarcadero.com/report-manager-reportman/>); las demás versiones
de Delphi compilan desde el código fuente. Embarcadero lo publica a partir de un
formulario de envío al que se adjunta el zip que genera este script.

```powershell
.\build\getit\make-getit.ps1            # sincroniza, versión, compilación en limpio, zip
.\build\getit\make-getit.ps1 -NoSync    # sin sincronizar getit\Source\Common
```

Salida: `build\getit\out\Reportman-getit-<v>.zip` (gitignored). Se hace commit de
`getit\` antes de generar el zip definitivo: el zip toma los ficheros que git conoce.

## Qué hace

1. **Sincroniza** `getit\Source\Common`: cada fichero que ya está allí se copia de
   la raíz del repositorio (o de `server\web`). `rpconf.inc` **no**: es la
   configuración de GetIt, sin BDE, Zeos, IBX, TeeChart, Indy ni dbExpress, y con los
   mismos interruptores de comportamiento que el `rpconf.inc` de la raíz en Delphi 13
   (`ISDELPHI`, `USEBCD`, `USEKERNING`…). Una unidad nueva se añade a mano una vez:
   se copia a `Source\Common` y se pone en el `.dpk` y el `.dproj` de su paquete
   (`reportman_rtl` lo que no usa VCL, `reportman_vcl` lo visual,
   `reportman_designvcl` el diseñador).
2. Pone la versión (`RM_VERSION`) y la fecha en `package.json` y
   `reportman_package.json`.
3. **Compila en limpio**: copia el paquete a una carpeta con la forma del
   `CatalogRepository` del IDE y compila con MSBuild contra una copia de
   `EnvOptions.proj` cuya ruta de librería de Win32/Win64 solo tiene las carpetas de
   Delphi y la ruta `Source\Common` que añade GetIt: nada de la ruta del
   desarrollador (la raíz del repositorio, Zeos…) puede tapar una unidad que falte.
   No toca la configuración del IDE ni sus `.bpl`. Compila los tres paquetes y los
   dos ejemplos en Win32 y Win64 (Debug, como `package.json`) y **falla** si:
   - una unidad entra en un paquete sin estar en su `contains` (aviso W1033: acabaría
     en dos paquetes y el IDE no podría cargarlos), o
   - un paquete importa un `.bpl` que no es de RAD Studio. Lista lo que importa cada
     uno: RTL, VCL, FireDAC, ADO, `dsnap`, `vcledge`, `designide`, o
   - un paquete no deja sus ficheros de C++Builder (`.hpp`, `.bpi`, `.lib`/`.a`): los
     `.dproj` llevan `DCC_CBuilderOutput=All`, de modo que al instalar desde GetIt los
     `.hpp` van a `hpp\$(Platform)` y los `.bpi`/`.lib` junto a los `.dcp`, las rutas
     que C++Builder ya busca. En la sala limpia los `.hpp` van a su carpeta de trabajo,
     no a la del IDE.
4. Genera el zip con los ficheros de `getit\` que están en git.

## C++Builder

Probado el 19-10-2026 en RAD Studio 13 con un programa de consola C++ que carga un
informe y lo exporta a PDF con `TPDFReport`, enlazado con los paquetes en tiempo de
ejecución (`reportman_rtl.bpi` y los de FireDAC de los que depende): compila, enlaza y
saca los mismos PDF en Win32 (`bcc32c`), Win64 (`bcc64`) y Win64 Modern (`bcc64x`).

- GetIt compila los paquetes para Win32 y Win64 (`package.json`). Para Win64 Modern
  hay que compilarlos a mano para *Windows 64-bit (Modern)*: el compilador de Delphi
  genera entonces objetos COFF (`-JF:COFFI`). No se pide en `package.json` porque esa
  plataforma solo existe si está instalado C++Builder.
- RAD Studio 13 ya no trae las cabeceras del SDK de Windows: en la primera compilación
  C++ las copia del SDK de Microsoft a `include\windows\sdk`, y solo acepta las
  versiones 10.0.26100.4188, .4654 y .4948 (una más nueva, como la .8249 que instala
  Visual Studio, deja `windows.h` sin encontrar).

La prueba que falta es la instalación en un IDE limpio: `bds.exe -r ReportmanClean`
arranca RAD Studio con otra rama del registro, como recién instalado, sin tocar el
perfil normal; allí se instalan los tres paquetes de `Source\Delphi` y se abre
`Examples\VCLDemo`.

**Ediciones de Delphi**: el paquete RTL usa los drivers de FireDAC para MySQL,
PostgreSQL, Advantage y ODBC además de los locales; según la edición de RAD Studio
esos drivers pueden no estar instalados.

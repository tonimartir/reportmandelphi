unit rpfontconfig;

interface

uses
  System.SysUtils,
  System.Classes; // Necesario para TLibHandle

// --- 1. Tipos de Datos Opcacos de Fontconfig ---

type
  // Los tipos de Fontconfig se definen como Pointers
  PFcConfig = Pointer;
  PFcPattern = Pointer;
  PFcFontSet = Pointer;
  PFcObjectSet = Pointer;
  PChar = PAnsiChar; // Usamos PAnsiChar para mapear a 'const char*' (UTF-8) en Linux

// --- 2. Variables de Control y Constantes ---

const
  // Nombre estándar de la librería Fontconfig en Linux
  FONTCONFIG_LIB_NAME = 'libfontconfig.so.1';

  // Constantes comunes de Fontconfig
// Constantes de PROPIEDADES (Nombres de objetos Fontconfig)
  FC_FAMILY = 'family'; // Familia de fuente (ej. Arial)
  FC_FILE = 'file';     // Ruta del archivo de fuente devuelto
  FC_WEIGHT = 'weight'; // Peso (Bold/Normal)
  FC_SLANT = 'slant';   // Inclinación (Italic/Roman)

  // Constantes de VALORES (Mapeo de estilos)
  // Pesos
  FC_WEIGHT_NORMAL = 80;
  FC_WEIGHT_BOLD = 200;

  // Inclinación (Slant)
  FC_SLANT_ROMAN = 0;   // Normal
  FC_SLANT_ITALIC = 100; // Cursiva
var
  // Manejador de la librería (SafeLoadLibrary)
  FontConfigLibHandle: THandle; // THandle es el tipo estándar de Delphi para manejadores de librerías
  // Bandera para saber si la inicialización fue exitosa
  FontConfigAvailable: Boolean;

// --- 3. Firmas de Funciones (T_Prefix) ---

// Inicialización y limpieza
type
  T_FcInit = function: Boolean; cdecl;
  T_FcConfigGetCurrent = function: PFcConfig; cdecl;
  T_FcFini = procedure; cdecl;

// Patrones y matching
T_FcPatternBuild = function: PFcPattern; cdecl;
  T_FcPatternDestroy = procedure(p: PFcPattern); cdecl;
  T_FcFontMatch = function(config: PFcConfig; p: PFcPattern; out result: PFcPattern): PFcPattern; cdecl;
  // PARÁMETRO RENOMBRADO: 'object' -> 'pcObject'
  T_FcPatternGetString = function(p: PFcPattern; const pcObject: PChar; n: Integer; out s: PChar): Boolean; cdecl;

// Adición de propiedades a un patrón
  // PARÁMETRO RENOMBRADO: 'object' -> 'pcObject'
  T_FcPatternAddString = function(p: PFcPattern; const pcObject: PChar; s: PChar): Boolean; cdecl;
  // PARÁMETRO RENOMBRADO: 'object' -> 'pcObject'
  T_FcPatternAddInteger = function(p: PFcPattern; const pcObject: PChar; i: Integer): Boolean; cdecl;

// --- 4. Variables de Funciones Enlazadas (Punteros) ---

var
  // Inicialización
  FcInit: T_FcInit;
  FcConfigGetCurrent: T_FcConfigGetCurrent;
  FcFini: T_FcFini;

  // Patrones y Matching
  FcPatternBuild: T_FcPatternBuild;
  FcPatternDestroy: T_FcPatternDestroy;
  FcFontMatch: T_FcFontMatch;
  FcPatternGetString: T_FcPatternGetString;

  // Adición de propiedades
  FcPatternAddString: T_FcPatternAddString;
  FcPatternAddInteger: T_FcPatternAddInteger;

// --- 5. Función de Inicialización Principal ---

procedure InitFontConfig;

implementation

// Función auxiliar para obtener la dirección de la función
function GetProc(const FuncName: string): Pointer;
begin
  // Nota: GetProcAddress requiere PAnsiChar para FuncName en las APIs de Unix/Delphi
  Result := GetProcAddress(FontConfigLibHandle, PWideChar(FuncName));
end;

procedure InitFontConfig;
var
  ProcPtr: Pointer;
begin
  // Inicialización defensiva
  FontConfigAvailable := False;
  FontConfigLibHandle := 0;

  // 1. Cargar la librería dinámicamente usando SafeLoadLibrary (Delphi)
  FontConfigLibHandle := SafeLoadLibrary(FONTCONFIG_LIB_NAME);

  if FontConfigLibHandle = 0 then
  begin
    Exit;
  end;

  // 2. Enlazar las funciones clave usando GetProcAddress (Delphi)

  // Inicialización y limpieza
  ProcPtr := GetProc('FcInit'); @FcInit := ProcPtr;
  ProcPtr := GetProc('FcConfigGetCurrent'); @FcConfigGetCurrent := ProcPtr;
  ProcPtr := GetProc('FcFini'); @FcFini := ProcPtr;

  // Patrones y Matching
  ProcPtr := GetProc('FcPatternBuild'); @FcPatternBuild := ProcPtr;
  ProcPtr := GetProc('FcPatternDestroy'); @FcPatternDestroy := ProcPtr;
  ProcPtr := GetProc('FcFontMatch'); @FcFontMatch := ProcPtr;
  ProcPtr := GetProc('FcPatternGetString'); @FcPatternGetString := ProcPtr;

  // Adición de propiedades
  ProcPtr := GetProc('FcPatternAddString'); @FcPatternAddString := ProcPtr;
  ProcPtr := GetProc('FcPatternAddInteger'); @FcPatternAddInteger := ProcPtr;

  // 3. Verificar y Inicializar
  if Assigned(FcInit) and Assigned(FcFontMatch) and Assigned(FcFini) then
  begin
    if FcInit() then
    begin
      FontConfigAvailable := True;
    end
    else
    begin
      System.SysUtils.FreeLibrary(FontConfigLibHandle);
      FontConfigLibHandle := 0;
    end;
  end
  else
  begin
    System.SysUtils.FreeLibrary(FontConfigLibHandle);
    FontConfigLibHandle := 0;
  end;
end;

initialization
  FontConfigAvailable := False;

finalization
  if FontConfigAvailable and (FontConfigLibHandle <> 0) and Assigned(FcFini) then
  begin
    FcFini;
    System.SysUtils.FreeLibrary(FontConfigLibHandle);
  end;
end.

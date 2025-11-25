unit rpfontconfig;

interface

uses
  System.SysUtils,
  System.Classes;

// --- 1. Tipos de Datos Opcacos de Fontconfig ---

type
  PFcConfig = Pointer;
  PFcPattern = Pointer;
  PFcFontSet = Pointer;
  PFcObjectSet = Pointer;
  PChar = PAnsiChar;
  PFcCharSet = Pointer;

// --- 2. Variables de Control y Constantes ---

const
  FONTCONFIG_LIB_NAME = 'libfontconfig.so.1';

  FC_FAMILY = 'family';
  FC_FILE = 'file';
  FC_TEXT = 'text';
  FC_WEIGHT = 'weight';
  FC_SLANT = 'slant';
  FC_INDEX = 'index'; // La propiedad que almacena el índice de fuente (Integer)

  FC_WEIGHT_NORMAL = 80;
  FC_WEIGHT_BOLD = 200;

  FC_SLANT_ROMAN = 0;
  FC_SLANT_ITALIC = 100;

const
  FC_MATCH_PATTERN = 0; // Tipo de objeto: Patrón (Familia)
  FC_MATCH_FONT = 1;   // Tipo de objeto: Fuente (Estilo, etc.)
  FC_FALLBACK = 'fallback';

  // Propiedad para el script (aunque se usa FC_LANG o se deriva, es bueno tener el concepto)
  FC_CHARSET = 'charset';
var
  FontConfigLibHandle: THandle;
  FontConfigAvailable: Boolean;

// --- 3. Firmas de Funciones (T_Prefix) ---

type
  T_FcInit = function: Boolean; cdecl;
  T_FcConfigGetCurrent = function: PFcConfig; cdecl;
  T_FcFini = procedure; cdecl;

  // NUEVA FUNCIÓN: Crea un nuevo patrón (sin argumentos variables)
  T_FcPatternCreate = function: PFcPattern; cdecl;
  T_FcPatternDestroy = procedure(p: PFcPattern); cdecl;
  T_FcFontMatch = function(config: PFcConfig; p: PFcPattern; out result: PFcPattern): PFcPattern; cdecl;
  T_FcPatternGetString = function(p: PFcPattern; const pcObject: PChar; n: Integer; out s: PChar): Boolean; cdecl;

  // Funciones de Adición (parámetros fijos)
  T_FcPatternAddString = function(p: PFcPattern; const pcObject: PChar; s: PChar): Boolean; cdecl;
  T_FcPatternAddInteger = function(p: PFcPattern; const pcObject: PChar; i: Integer): Boolean; cdecl;
  T_FcDefaultSubstitute = procedure(p: PFcPattern); cdecl;
  T_FcConfigSubstitute = function(config: PFcConfig; p: PFcPattern; objectType: Integer): Boolean; cdecl; // objectType es FcMatchPattern = 0
  T_FcPatternGetInteger = function(p: PFcPattern; const pcObject: PChar; n: Integer; out i: Integer): Boolean; cdecl;

  T_FcCharSetCreate = function: PFcCharSet; cdecl;
  T_FcCharSetDestroy = procedure(cs: PFcCharSet); cdecl;
  T_FcCharSetAddChar = function(cs: PFcCharSet; uc: Cardinal): Boolean; cdecl;
  T_FcPatternAddCharSet = function(p: PFcPattern; const pszObject: PChar; cs: PFcCharSet): Boolean; cdecl;

var
  FcInit: T_FcInit;
  FcConfigGetCurrent: T_FcConfigGetCurrent;
  FcFini: T_FcFini;

  // FcPatternBuild ELIMINADO
  FcPatternCreate: T_FcPatternCreate;
  FcPatternDestroy: T_FcPatternDestroy;
  FcFontMatch: T_FcFontMatch;
  FcPatternGetString: T_FcPatternGetString;

  FcPatternAddString: T_FcPatternAddString;
  FcPatternAddInteger: T_FcPatternAddInteger;
  FcConfigSubstitute: T_FcConfigSubstitute;
  FcDefaultSubstitute: T_FcDefaultSubstitute;
  FcPatternGetInteger: T_FcPatternGetInteger;

  FcCharSetCreate: T_FcCharSetCreate;
  FcCharSetDestroy: T_FcCharSetDestroy;
  FcCharSetAddChar: T_FcCharSetAddChar;
  FcPatternAddCharSet: T_FcPatternAddCharSet;

procedure InitFontConfig;

function FcCreatePattern(const FamilyName: string; IsBold, IsItalic: Boolean; const UnicodeContent: WideString): PFcPattern;

implementation

function GetProc(const FuncName: string): Pointer;
begin
  Result := GetProcAddress(FontConfigLibHandle, PWideChar(FuncName));
end;

procedure InitFontConfig;
var
  ProcPtr: Pointer;
begin
  FontConfigAvailable := False;
  FontConfigLibHandle := 0;

  FontConfigLibHandle := SafeLoadLibrary(FONTCONFIG_LIB_NAME);

  if FontConfigLibHandle = 0 then
    Exit;

  // Enlace de funciones de bajo nivel
  ProcPtr := GetProc('FcInit'); @FcInit := ProcPtr;
  ProcPtr := GetProc('FcFini'); @FcFini := ProcPtr;
  ProcPtr := GetProc('FcConfigGetCurrent'); @FcConfigGetCurrent := ProcPtr;

  // Enlace de las nuevas funciones de creación y adición
  ProcPtr := GetProc('FcPatternCreate'); @FcPatternCreate := ProcPtr; // NUEVA FUNCIÓN
  ProcPtr := GetProc('FcPatternDestroy'); @FcPatternDestroy := ProcPtr;
  ProcPtr := GetProc('FcFontMatch'); @FcFontMatch := ProcPtr;
  ProcPtr := GetProc('FcPatternGetString'); @FcPatternGetString := ProcPtr;

  ProcPtr := GetProc('FcPatternAddString'); @FcPatternAddString := ProcPtr;
  ProcPtr := GetProc('FcPatternAddInteger'); @FcPatternAddInteger := ProcPtr;
  ProcPtr := GetProc('FcDefaultSubstitute'); @FcDefaultSubstitute := ProcPtr;
  ProcPtr := GetProc('FcConfigSubstitute'); @FcConfigSubstitute := ProcPtr;
  ProcPtr := GetProc('FcPatternGetInteger'); @FcPatternGetInteger := ProcPtr;
  ProcPtr := GetProc('FcCharSetCreate'); @FcCharSetCreate := ProcPtr;
  ProcPtr := GetProc('FcCharSetDestroy'); @FcCharSetDestroy := ProcPtr;
  ProcPtr := GetProc('FcCharSetAddChar'); @FcCharSetAddChar := ProcPtr;
  ProcPtr := GetProc('FcPatternAddCharSet'); @FcPatternAddCharSet := ProcPtr;

  // 3. Verificar y Inicializar (usando ahora FcPatternCreate)
  if Assigned(FcInit) and Assigned(FcFontMatch) and Assigned(FcFini) and Assigned(FcPatternCreate) then
  begin
    if FcInit() then
      FontConfigAvailable := True
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

function FcCreatePattern(const FamilyName: string; IsBold, IsItalic: Boolean; const UnicodeContent: WideString): PFcPattern;
var
  Pattern: PFcPattern;
  WeightValue: Integer;
  SlantValue: Integer;
  // Variables locales para mantener la cadena UTF-8 en memoria
  // durante la llamada a FcPatternAddString:
  UTF8Family: UTF8String;
  CharSet: PFcCharSet;
  i:integer;
begin
  Result := nil;

  if not FontConfigAvailable or not Assigned(FcPatternCreate) or not Assigned(FcPatternAddString) or not Assigned(FcPatternAddInteger) then
    Exit;

  // 1. Convertir los strings Unicode a UTF-8 (const char* esperado)
  // Utilizamos UTF8Encode para convertir WideString/String a UTF8String
  UTF8Family := UTF8Encode(FamilyName);


  // 2. Determinar los valores de estilo
  if IsBold then
    WeightValue := FC_WEIGHT_BOLD
  else
    WeightValue := FC_WEIGHT_NORMAL;

  if IsItalic then
    SlantValue := FC_SLANT_ITALIC
  else
    SlantValue := FC_SLANT_ROMAN;

  // 3. Crear el patrón
  Pattern := FcPatternCreate();

  if not Assigned(Pattern) then
    Exit;

  try
    // 4. Añadir la familia de fuente (usando PAnsiChar(UTF8String))

    // 5. Añadir Peso e Inclinación
    FcPatternAddInteger(Pattern, PChar(FC_WEIGHT), WeightValue);
    FcPatternAddInteger(Pattern, PChar(FC_SLANT), SlantValue);
    if Length(UTF8Family)>0 then
      FcPatternAddString(Pattern, PChar(FC_FAMILY), PAnsiChar(UTF8Family));
    if Length(UnicodeContent)>0 then
    begin
    // 1. CREAR el conjunto de caracteres
    CharSet := FcCharSetCreate();

    // 2. RELLENAR el conjunto de caracteres con los códigos Unicode de la cadena
    // (Asumimos que la iteración por WideString funciona directamente para obtener FcChar32)
    for i := 1 to Length(unicodeContent) do
    begin
      // Usamos runText[i] que es Word/WideChar, y lo casteamos a Cardinal (FcChar32)
      // para asegurar el tipo de parámetro correcto para el C API.
      FcCharSetAddChar(CharSet, Cardinal(unicodeContent[i]));
    end;

    // 3. PASAR el conjunto de caracteres al patrón con la propiedad FC_CHARSET
    // Esto informa a Fontconfig qué glifos faltan (el requisito de script).
    // Nota: El parámetro PChar(FC_CHARSET) debe ser la constante definida como 'charset'
    FcPatternAddCharSet(Pattern, PChar(FC_CHARSET), CharSet);

    // 4. LIBERAR el objeto CharSet (el patrón hace una copia interna)
    FcCharSetDestroy(CharSet);
    end;


    Result := Pattern;

  except
    FcPatternDestroy(Pattern);
    Result := nil;
  end;
end;

initialization
  FontConfigAvailable := False;

finalization
  if FontConfigAvailable and (FontConfigLibHandle <> 0) and Assigned(FcFini) then
  begin
    System.SysUtils.FreeLibrary(FontConfigLibHandle);
  end;
end.

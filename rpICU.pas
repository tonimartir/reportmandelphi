unit rpICU;


interface

uses SysUtils,
{$IFDEF MSWINDOWS}
 Windows,
{$ENDIF}
Generics.Collections;


const
  U_ZERO_ERROR                  = 0;
  U_ILLEGAL_ARGUMENT_ERROR      = 1;
  U_MISSING_RESOURCE_ERROR      = 2;
  U_INVALID_FORMAT_ERROR        = 3;
  U_FILE_ACCESS_ERROR           = 4;
  U_INTERNAL_PROGRAM_ERROR      = 5;
  U_MESSAGE_PARSE_ERROR         = 6;
  U_MEMORY_ALLOCATION_ERROR     = 7;
  U_INDEX_OUTOFBOUNDS_ERROR     = 8;
  U_PARSE_ERROR                 = 9;
  U_INVALID_CHAR_FOUND          = 10;
  U_TRUNCATED_CHAR_FOUND        = 11;
  U_ILLEGAL_CHAR_FOUND          = 12;
  U_INVALID_TABLE_FORMAT        = 13;
  U_INVALID_TABLE_FILE          = 14;
  U_BUFFER_OVERFLOW_ERROR       = 15;
  U_UNSUPPORTED_ERROR           = 16;
  U_RESOURCE_TYPE_MISMATCH      = 17;
  U_ILLEGAL_ESCAPE_SEQUENCE     = 18;
  U_UNSUPPORTED_ESCAPE_SEQUENCE = 19;
  U_NO_SPACE_AVAILABLE          = 20;
  U_CE_NOT_FOUND_ERROR          = 21;
  U_PRIMARY_TOO_LONG_ERROR      = 22;
  U_STATE_TOO_OLD_ERROR         = 23;
  U_TOO_MANY_ALIASES_ERROR      = 24;
  U_ENUM_OUT_OF_SYNC_ERROR      = 25;
  U_INVARIANT_CONVERSION_ERROR  = 26;
  U_INVALID_STATE_ERROR         = 27;
  U_COLLATOR_VERSION_MISMATCH   = 28;
  U_USELESS_COLLATOR_ERROR      = 29;
  U_NO_WRITE_PERMISSION         = 30;
  U_STANDARD_ERROR_LIMIT        = 31;
  U_BAD_VARIABLE_DEFINITION     = 32;
  U_PARSE_ERROR_LIMIT           = 33;
  U_UNEXPECTED_TOKEN_ERROR      = 34;
  U_AMBIGUOUS_ALIAS_WARNING     = 35;
  U_FMT_PARSE_ERROR             = 36;
  U_MULTIPLE_ORDINALS_ERROR     = 37;
  U_INVALID_PATH               = 38;
  U_IO_ERROR                   = 39;
  U_STACK_OVERFLOW_ERROR       = 40;
  U_INTERNAL_PROGRAM_ERROR2    = 41;
  U_NOT_FOUND_ERROR            = 42;
  U_ILLEGAL_REGEX_PATTERN      = 43;
  U_RECURSION_LIMIT_EXCEEDED   = 44;
  U_INVALID_TABLE_FORMAT2      = 45;
  U_INVALID_STATE_ERROR2       = 46;
  U_UNSUPPORTED_CONVERSION     = 47;
  U_ILLEGAL_ARGUMENT_ERROR2    = 48;
  U_MISSING_RESOURCE_ERROR2    = 49;
  U_INVALID_FORMAT_ERROR2      = 50;


const
  UBIDI_DO_MIRRORING = $0001;
  UBIDI_MAX_EXPLICIT_LEVEL = 61;
  UBIDI_DEFAULT_LTR        = $FE;  // level para pedir LTR automático
  UBIDI_DEFAULT_RTL        = $FF;  // level para pedir RTL automático
  UBIDI_L       = 0;   // Letter L
  UBIDI_R       = 1;   // Letter R
  UBIDI_AL      = 2;   // Arabic Letter

  UBIDI_EN      = 3;   // European Number
  UBIDI_ES      = 4;   // European Separator
  UBIDI_ET      = 5;   // European Terminator
  UBIDI_AN      = 6;   // Arabic Number
  UBIDI_CS      = 7;   // Common Separator

  UBIDI_B       = 8;   // Paragraph Separator
  UBIDI_S       = 9;   // Segment Separator
  UBIDI_WS      = 10;  // Whitespace
  UBIDI_ON      = 11;  // Other Neutrals

  UBIDI_LRE     = 12;
  UBIDI_LRO     = 13;
  UBIDI_RLE     = 14;
  UBIDI_RLO     = 15;
  UBIDI_PDF     = 16;
  UBIDI_NSM     = 17;  // Non-spacing mark
  UBIDI_BN      = 18;  // Boundary Neutral

  UBIDI_NEUTRAL = UBIDI_ON; //


 const
   USCRIPT_INVALID_CODE = -1;
  USCRIPT_COMMON       = 0;
  USCRIPT_INHERITED    = 1;
  USCRIPT_ARABIC       = 13;
  USCRIPT_LATIN        = 25;

const
  UBRK_CHARACTER = 0;
  UBRK_WORD      = 1;
  UBRK_LINE      = 2;
  UBRK_SENTENCE  = 3;
  // UBreakIterator devuelve este valor cuando no hay más límites
  UBRK_DONE = -1;
 type
   // Representa un iterador de límites de texto
  UBreakIterator = Pointer;
  UScriptCode=Integer;
  UChar = Int32; // 32 bi
  PUNormalizer2 = Pointer;
  UErrorCode = Integer;
  UBiDi = Pointer;
    UBiDiLevel = Byte;
  UBiDiDirection = (
    UBIDI_LTR = 0,
    UBIDI_RTL = 1,
    UBIDI_MIXED = 2
  );

  // Helper records for extended BiDi handling and glyph arrangement
  TBidiRun = record
    LogicalStart: Integer;
    Length: Integer;
    Level: UBiDiLevel;
    VisualIndex: Integer;
    Direction: UBiDiDirection;
    Script: UScriptCode;
    ScriptString: AnsiString;
    Text: UnicodeString; // copia del texto de este run
    LineBreaks: TDictionary<Integer,Integer>; // índice inicio -> índice siguiente break
  end;
  EICU = Class(Exception)
  End;


  // Punteros a funciones de ICU
  TUnorm2_getNFCInstance = function(out status: UErrorCode): PUNormalizer2; cdecl;
  TUnorm2_normalize = function(norm2: PUNormalizer2; const src: PWord; length: Integer;
                                dest: PWord; capacity: Integer; out status: UErrorCode): Integer; cdecl;
  T_ubidi_open = function: UBiDi; cdecl;
  T_ubidi_close = procedure(pBiDi: UBiDi); cdecl;
  T_ubidi_setPara = procedure(pBiDi: UBiDi;
                              text: PWideChar;
                              length: Integer;
                              paraLevel: UBiDiLevel;
                              embeddingLevels: Pointer;
                              var status: UErrorCode); cdecl;
  T_ubidi_getVisualRun = function(pBiDi: UBiDi; runIndex: Int32;
                                  out logicalStart: Int32; out length: Int32
                                 ): UBiDiDirection; cdecl;
  T_ubidi_getVisualMap = procedure(pBiDi: UBiDi; indexMap: PInteger; var status: Integer); cdecl;
  T_ubidi_getLength    = function(pBiDi: UBiDi): Integer; cdecl;
  T_ubidi_countRuns = function(pBiDi: UBiDi; var pErrorCode: Int32): Int32; cdecl;

  T_ubidi_getLogicalRun = procedure(pBiDi: UBiDi; start: Integer;
                                    var limit: Integer; var level: UBiDiLevel); cdecl;
  T_ubidi_getLevelAt = function(pBiDi: UBiDi; charIndex: Int32): UBiDiLevel; cdecl;
  T_uscript_getScript = function(ch: UChar; var status: UErrorCode): UScriptCode; cdecl;
    T_uscript_getShortName = function(scriptCode: UScriptCode): PAnsiChar; cdecl;

    T_ubrk_open = function(type_: Integer; locale: PAnsiChar; text: PWideChar; textLen: Integer; var status: UErrorCode): UBreakIterator; cdecl;

  // Cerrar un BreakIterator
  T_ubrk_close = procedure(bi: UBreakIterator); cdecl;

  // Reiniciar iterador al inicio
  T_ubrk_first = function(bi: UBreakIterator): Integer; cdecl;

  // Avanzar al siguiente límite
  T_ubrk_next = function(bi: UBreakIterator): Integer; cdecl;

  // Cambiar el texto del iterador
  T_ubrk_setText = procedure(bi: UBreakIterator; text: PWideChar; textLen: Integer; var status: UErrorCode); cdecl;

TICUBidi = class
  private
    FBidi: UBiDi;
  public
    constructor Create(ParaCapacity: Integer = 0);
    destructor Destroy; override;
    function SetPara(const Text: UnicodeString; ParaLevel: UBiDiLevel = 0): Boolean;
    // Extended BiDi helpers
    function GetVisualRun(AVisualIndex: Integer; out ALogicalStart, ALength: Integer; out ALevel: UBiDiLevel): Boolean;
    function GetVisualMap(var Map: TArray<Integer>): Boolean;
    function GetVisualRuns(const AText: UnicodeString): TList<TBidiRun>;
    property Handle: UBidi read FBidi;
  end;



var
  unorm2_getNFCInstance: TUnorm2_getNFCInstance;
  unorm2_normalize: TUnorm2_normalize;
  ubidi_open: T_ubidi_open = nil;
  ubidi_close: T_ubidi_close = nil;
  ubidi_setPara: T_ubidi_setPara = nil;
    ubidi_getVisualRun: T_ubidi_getVisualRun = nil;
  ubidi_getVisualMap: T_ubidi_getVisualMap = nil;
  ubidi_getLength:    T_ubidi_getLength    = nil;
  ICUlib: THandle = 0;
  ICUSuffix: string;
    ubidi_countRuns: T_ubidi_countRuns = nil;
  ubidi_getLogicalRun: T_ubidi_getLogicalRun = nil;
  ubidi_getLevelAt: T_ubidi_getLevelAt = nil;
  uscript_getScript: T_uscript_getScript = nil;
    uscript_getShortName: T_uscript_getShortName = nil;
      ubrk_open: T_ubrk_open = nil;
  ubrk_close: T_ubrk_close = nil;
  ubrk_first: T_ubrk_first = nil;
  ubrk_next: T_ubrk_next = nil;
  ubrk_setText: T_ubrk_setText = nil;
procedure InitICU;
function NormalizeNFC(const S: string): string;


implementation


constructor TICUBidi.Create(ParaCapacity: Integer);
begin
  inherited Create;
  FBidi := ubidi_open;
  if FBidi = nil then
    raise EICU.Create('Failed to initialize ICU BiDi');
end;
destructor TICUBidi.Destroy;
begin
  if FBidi <> nil then
    ubidi_close(FBidi);
  inherited;
end;
function TICUBidi.SetPara(const Text: UnicodeString; ParaLevel: UBiDiLevel): Boolean;
var
  status: Integer;
begin
  status := 0;
  ubidi_setPara(FBidi, PWideChar(Text), Length(Text), ParaLevel, nil, status);
  Result := (status = 0);
end;

function TICUBidi.GetVisualMap(var Map: TArray<Integer>): Boolean;
var
  L, i, status: Integer;
begin
  Result := False;
  status := 0;
  L := ubidi_getLength(FBidi);
  if L <= 0 then Exit;
  SetLength(Map, L);
  ubidi_getVisualMap(FBidi, PInteger(Map), status);
  Result := (status = 0);
end;

function TICUBidi.GetVisualRun(AVisualIndex: Integer; out ALogicalStart, ALength: Integer; out ALevel: UBiDiLevel): Boolean;
var
  map: TArray<Integer>;
  i, foundLogical: Integer;
begin
  Result := False;
  if not GetVisualMap(map) then Exit;
  foundLogical := -1;
  for i := 0 to High(map) do
  begin
    if map[i] = AVisualIndex then
    begin
      foundLogical := i;
      Break;
    end;
  end;
  if foundLogical < 0 then Exit;
  // get logical run that starts at foundLogical
  ubidi_getLogicalRun(FBidi, foundLogical, ALogicalStart, ALevel);
  // ubidi_getLogicalRun returns limit in ALogicalStart param; adjust to return start/length
  ALength := ALogicalStart - foundLogical;
  ALogicalStart := foundLogical;
  Result := True;
end;

(*function TICUBidi.GetVisualRuns: TList<TBidiRun>;
var
  runCount, i: Integer;
  vStart, vLength, vLimit: Integer;
  dir: UBiDiDirection;
  run: TBidiRun;
  err: Integer;
begin
  Result := TList<TBidiRun>.Create;

  if FBidi = nil then
    Exit;

  err := 0;
  runCount := ubidi_countRuns(FBidi, err);
  if (err <> 0) or (runCount <= 0) then
    Exit;

  for i := 0 to runCount - 1 do
  begin
    // devuelve start lógico y length (no limit), y la dirección del run (UBIDI_LTR/UBIDI_RTL/...)
    dir := ubidi_getVisualRun(FBidi, i, vStart, vLength);

    // Seguridad básica
    if (vStart < 0) or (vLength <= 0) then
      Continue;

    vLimit := vStart + vLength; // límite exclusivo

    // rellenar el record básico
    run.LogicalStart := vStart;      // índice lógico del inicio
    run.Length := vLength;           // longitud en unidades lógicas (UTF-16 code units)
    run.VisualIndex := i;            // índice visual (posición del run)



    Result.Add(run);
  end;
end;
*)
function U_FAILURE(code: UErrorCode): Boolean;
begin
  // En ICU, cualquier código >= 0 es éxito
  Result := code < 0;
end;

procedure FillLineBreaks(const RunText: UnicodeString; var Run: TBidiRun);
var
  bi: UBreakIterator;
  status: UErrorCode;
  pos, prevPos: Integer;
begin
  Run.LineBreaks := TDictionary<Integer,Integer>.Create;
  if RunText = '' then
    Exit;

  status := U_ZERO_ERROR;
  // Creamos un BreakIterator de tipo línea
  bi := ubrk_open(UBRK_LINE, 'en', PChar(RunText), Length(RunText), status);
  if U_FAILURE(status) then
    Exit;

  try
    prevPos := ubrk_first(bi);
    pos := ubrk_next(bi);
    while pos <> UBRK_DONE do
    begin
      Run.LineBreaks.Add(prevPos, pos); // de prevPos hasta pos es un segmento
      prevPos := pos;
      pos := ubrk_next(bi);
    end;
  finally
    ubrk_close(bi);
  end;
end;

function TICUBidi.GetVisualRuns(const AText: UnicodeString): TList<TBidiRun>;
var
  runCount, i: Integer;
  vStart, vLength, vLimit: Integer;
  dir: UBiDiDirection;
  run: TBidiRun;
  err: Integer;
  j: Integer;
  pText: PWideChar;
  firstScript: Integer;
  script: Integer;
  uerr: UErrorCode;
  level: UBiDiLevel;
  charCode:UChar;
begin
  Result := TList<TBidiRun>.Create;

  if FBidi = nil then
    Exit;

  // necesitamos el puntero al texto UTF-16
  pText := nil;
  if AText <> '' then
    pText := PWideChar(AText);

  err := 0;
  runCount := ubidi_countRuns(FBidi, err);
  if (err <> 0) or (runCount <= 0) then
    Exit;

  for i := 0 to runCount - 1 do
  begin
    // devuelve start lógico y length (no limit), y la dirección del run (UBIDI_LTR/UBIDI_RTL/UBIDI_MIXED)
    dir := ubidi_getVisualRun(FBidi, i, vStart, vLength);

    // Seguridad básica
    if (vStart < 0) or (vLength <= 0) then
      Continue;

    vLimit := vStart + vLength; // límite exclusivo

    // rellenar el record básico
    run.LogicalStart := vStart;      // índice lógico del inicio
    run.Length := vLength;           // longitud en unidades lógicas (UTF-16 code units)
    run.VisualIndex := i;            // índice visual (posición del run)

    // nivel del primer carácter (útil para afinar direction si es MIXED)
    level := ubidi_getLevelAt(FBidi, vStart);
    run.Level := level;

    // determinar dirección: usar lo devuelto por ubidi_getVisualRun,
    // pero si es UBIDI_MIXED afinamos por el nivel del primer carácter
    if dir = UBIDI_MIXED then
    begin
      if (level and 1) <> 0 then
        run.Direction := UBIDI_RTL
      else
        run.Direction := UBIDI_LTR;
    end
    else
      run.Direction := dir;

    // detectar script del run: buscar el primer script significativo en el rango
    firstScript := -1;
    if Assigned(pText) then
    begin
      uerr := U_ZERO_ERROR;
      for j := vStart to vLimit - 1 do
      begin
        // uscript_getScript espera UChar (UTF-16 unit)
        charCode:=UChar(Ord(pText[j]));
        script := uscript_getScript(charCode, uerr);
        if uerr <> U_ZERO_ERROR then
        begin
          // si hay error, reiniciarlo y seguir
          uerr := U_ZERO_ERROR;
          Continue;
        end;

        if firstScript = -1 then
          firstScript := script
        else if ((script <> firstScript) and (script<>USCRIPT_COMMON) and (script<>USCRIPT_INHERITED)) then
        begin
          // mezcla de scripts dentro del run -> marcar como "common/mixed"
          firstScript := USCRIPT_COMMON;
          Break;
        end;
      end;
    end;
    run.Script := firstScript;
    run.ScriptString := uscript_getShortName(firstScript); // PAnsiChar or nil
    if Assigned(pText) then
      run.Text := Copy(AText, vStart + 1, vLength) // Delphi indices empiezan en 1
    else
      run.Text := '';
    FillLineBreaks(run.Text, run);
    Result.Add(run);
  end;
end;


procedure InitICU;
const
  ICU_MIN_VERSION = 60;
  ICU_MAX_VERSION = 90;
var
  version: Integer;
  libName: string;
  ProcName: string;

  function GetProcAddr(ProcName: string): Pointer;
  begin
{$IFDEF MSWINDOWS}
    Result := GetProcAddress(ICUlib, PWideChar(ProcName));
    if not Assigned(Result) then RaiseLastOSError;
{$ENDIF}
{$IFDEF LINUX}
{$IFDEF FPC}
    Result := Dynlibs.GetProcAddress(ICUlib, ProcName);
    if Result = nil then
      raise Exception.CreateFmt('Error loading %s', [ProcName]);
{$ELSE}
    Result := SysUtils.GetProcAddress(ICUlib, PWideChar(ProcName));
    if Result = nil then RaiseLastOSError;
{$ENDIF}
{$ENDIF}
  end;

begin
 if (ICUlib <>0) then
   exit;
  ICUlib := 0;
  ICUSuffix := '';

  // Intentar cargar la versión de ICU desde 60 hasta 90
  for version := ICU_MIN_VERSION to ICU_MAX_VERSION do
  begin
{$IFDEF MSWINDOWS}
    libName := Format('icuuc%d.dll', [version]);
{$ELSE}
    libName := Format('libicuuc.so.%d', [version]);
{$ENDIF}

    {$IFDEF MSWINDOWS}
    ICUlib :=LoadLibrary(PWideChar(libName));
    {$ELSE}
    ICUlib :=SysUtils.SafeLoadLibrary(libName)
    {$ENDIF};
    if ICUlib <> 0 then
    begin
      ICUSuffix := '_' + IntToStr(version);
      Break;
    end;
  end;

  if ICUlib = 0 then
    raise Exception.Create('No ICU library found from version 60 to 80');


    // ==== Cargar ICU Bidi ====
  ProcName := 'ubidi_open' + AnsiString(ICUSuffix);
  ubidi_open := GetProcAddr(ProcName);
  if not Assigned(ubidi_open) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubidi_close' + AnsiString(ICUSuffix);
  ubidi_close := GetProcAddr(ProcName);
  if not Assigned(ubidi_close) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);


  // Cargar funciones dinámicamente con sufijo detectado
  ProcName := 'unorm2_getNFCInstance' + ICUSuffix;
  unorm2_getNFCInstance := TUnorm2_getNFCInstance(GetProcAddr(ProcName));

  ProcName := 'unorm2_normalize' + PAnsiChar(AnsiString(ICUSuffix));
  unorm2_normalize := TUnorm2_normalize(GetProcAddr(ProcName));

  ProcName := 'ubidi_setPara' + AnsiString(ICUSuffix);
  ubidi_setPara := GetProcAddr(ProcName);
  if not Assigned(ubidi_setPara) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubidi_getVisualRun' + AnsiString(ICUSuffix);
  ubidi_getVisualRun := GetProcAddr(ProcName);
  if not Assigned(ubidi_getVisualRun) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubidi_getVisualMap' + AnsiString(ICUSuffix);
  ubidi_getVisualMap := GetProcAddr(ProcName);
  if not Assigned(ubidi_getVisualMap) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubidi_getLength' + AnsiString(ICUSuffix);
  ubidi_getLength := GetProcAddr(ProcName);
  if not Assigned(ubidi_getLength) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubidi_countRuns' + AnsiString(ICUSuffix);
  ubidi_countRuns := GetProcAddr(ProcName);
  if not Assigned(ubidi_countRuns) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubidi_getLogicalRun' + AnsiString(ICUSuffix);
  ubidi_getLogicalRun := GetProcAddr(ProcName);
  if not Assigned(ubidi_getLogicalRun) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'ubidi_getLevelAt' + AnsiString(ICUSuffix);
  ubidi_getLevelAt := GetProcAddr(ProcName);
  if not Assigned(ubidi_getLevelAt) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'uscript_getScript' + AnsiString(ICUSuffix);
  uscript_getScript := GetProcAddr(ProcName);
  if not Assigned(uscript_getScript) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'uscript_getShortName' + AnsiString(ICUSuffix);
  uscript_getShortName := GetProcAddr(ProcName);
  if not Assigned(uscript_getShortName) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);

  ProcName := 'ubrk_open' + AnsiString(ICUSuffix);
  ubrk_open := GetProcAddr(ProcName);
  if not Assigned(ubrk_open) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'ubrk_close' + AnsiString(ICUSuffix);
  ubrk_close := GetProcAddr(ProcName);
  if not Assigned(ubrk_close) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'ubrk_first' + AnsiString(ICUSuffix);
  ubrk_first := GetProcAddr(ProcName);
  if not Assigned(ubrk_first) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'ubrk_next' + AnsiString(ICUSuffix);
  ubrk_next := GetProcAddr(ProcName);
  if not Assigned(ubrk_next) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
  ProcName := 'ubrk_setText' + AnsiString(ICUSuffix);
  ubrk_setText := GetProcAddr(ProcName);
  if not Assigned(ubrk_setText) then
    raise Exception.CreateFmt('Falta función: %s', [ProcName]);
end;

function NormalizeNFC(const S: string): string;
var
  status: UErrorCode;
  normalizer: PUNormalizer2;
  srcUTF16, destUTF16: TArray<UChar>;
  srcLen, destLen, i: Integer;
begin
  InitICU;

  if not Assigned(unorm2_getNFCInstance) or not Assigned(unorm2_normalize) then
    raise Exception.Create('ICU functions not initialized');

  Result := '';

  // Copiar el string Delphi (UTF-16) a array de UChar
  srcLen := Length(S);
  SetLength(srcUTF16, srcLen);
  for i := 1 to srcLen do
    srcUTF16[i - 1] := UChar(S[i]);

  // Obtener normalizador NFC
  status := U_ZERO_ERROR;
  normalizer := unorm2_getNFCInstance(status);
  if status <> U_ZERO_ERROR then
    raise Exception.CreateFmt('ICU error getting NFC instance: %d', [status]);

  // Preparar buffer de salida (reservar suficiente por si se expande)
  SetLength(destUTF16, srcLen * 2);

  // Normalizar
  destLen := unorm2_normalize(normalizer, PWord(@srcUTF16[0]), srcLen,
                              PWord(@destUTF16[0]), Length(destUTF16), status);
  if status <> U_ZERO_ERROR then
    raise Exception.CreateFmt('ICU error normalizing string: %d', [status]);

  // Ajustar tamaño del resultado y convertir a string Delphi
  SetLength(destUTF16, destLen);
  SetLength(Result, destLen);
  for i := 0 to destLen - 1 do
    Result[i + 1] := WideChar(destUTF16[i]);
end;



initialization

end.

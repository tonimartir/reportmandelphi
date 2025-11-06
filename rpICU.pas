unit rpICU;


interface

uses SysUtils;


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

type
  UChar = Word; // 16 bi
  PUNormalizer2 = Pointer;
  UErrorCode = Integer;

  // Punteros a funciones de ICU
  TUnorm2_getNFCInstance = function(out status: UErrorCode): PUNormalizer2; cdecl;
  TUnorm2_normalize = function(norm2: PUNormalizer2; const src: PWord; length: Integer;
                                dest: PWord; capacity: Integer; out status: UErrorCode): Integer; cdecl;



var
  unorm2_getNFCInstance: TUnorm2_getNFCInstance;
  unorm2_normalize: TUnorm2_normalize;

  ICUlib: THandle = 0;
  ICUSuffix: string;

procedure InitICU;


implementation

procedure InitICU;
const
  ICU_MIN_VERSION = 60;
  ICU_MAX_VERSION = 80;
var
  version: Integer;
  libName: string;
  ProcName: string;

  function GetProcAddr(ProcName: string): Pointer;
  begin
{$IFDEF MSWINDOWS}
    Result := GetProcAddress(ICUlib, ProcName);
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

  // Intentar cargar la versión de ICU desde 60 hasta 80
  for version := ICU_MIN_VERSION to ICU_MAX_VERSION do
  begin
{$IFDEF MSWINDOWS}
    libName := Format('icuuc%d.dll', [version]);
{$ELSE}
    libName := Format('libicuuc.so.%d', [version]);
{$ENDIF}
    ICUlib := {$IFDEF MSWINDOWS}LoadLibrary(PChar(libName)){$ELSE}SysUtils.SafeLoadLibrary(libName){$ENDIF};
    if ICUlib <> 0 then
    begin
      ICUSuffix := '_' + IntToStr(version);
      Break;
    end;
  end;

  if ICUlib = 0 then
    raise Exception.Create('No ICU library found from version 60 to 80');

  // Cargar funciones dinámicamente con sufijo detectado
  ProcName := 'unorm2_getNFCInstance' + ICUSuffix;
  unorm2_getNFCInstance := TUnorm2_getNFCInstance(GetProcAddr(ProcName));

  ProcName := 'unorm2_normalize' + PAnsiChar(AnsiString(ICUSuffix));
  unorm2_normalize := TUnorm2_normalize(GetProcAddr(ProcName));
end;

initialization

end.

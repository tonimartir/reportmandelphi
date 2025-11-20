unit rplinuxexceptionhandler;

{$IFDEF LINUX}
interface

uses
  System.SysUtils,
  System.Classes,
  System.Types;

const
  LineEnding = #10;

procedure WriteToStdError(const AString: string);
procedure InitStackTraceExceptionHandling;


implementation

uses
  System.Character; // solo por compatibilidad de strings si hace falta

// --- Constantes / configuración ---
const
  libc = 'libc.so.6';
  STDERR_FILENO = 2;
  MAX_STACK_DEPTH = 128;
  POINTER_SIZE = SizeOf(Pointer);
  ADDR2LINE_BUF = 1024;

type
  TDl_info = record
    dli_fname: PAnsiChar;
    dli_fbase: Pointer;
    dli_sname: PAnsiChar;
    dli_saddr: Pointer;
  end;
  PDl_info = ^TDl_info;

var initDone:boolean = false;

// --- Externals de libc que usamos ---
function backtrace(buffer: Pointer; size: Integer): Integer; cdecl; external libc name 'backtrace';
function backtrace_symbols(const buffer: Pointer; size: Integer): Pointer; cdecl; external libc name 'backtrace_symbols';
procedure free(p: Pointer); cdecl; external libc name 'free';
function dladdr(addr: Pointer; info: PDl_info): Integer; cdecl; external libc name 'dladdr';
function write(fd: Integer; const buffer: Pointer; count: NativeInt): NativeInt; cdecl; external libc name 'write';

function popen(command: PAnsiChar; mode: PAnsiChar): Pointer; cdecl; external libc name 'popen';
function pclose(stream: Pointer): Integer; cdecl; external libc name 'pclose';
function fgets(s: PAnsiChar; size: Integer; stream: Pointer): PAnsiChar; cdecl; external libc name 'fgets';

// --- Helpers de escritura segura a stderr ---
procedure WriteStreamToHandle(AStream: TMemoryStream; Handle: Integer);
begin
  if (AStream <> nil) and (AStream.Size > 0) then
    write(Handle, AStream.Memory, AStream.Size);
end;

procedure WriteToStdError(const AString: string);
var
  ms: TMemoryStream;
  u8: UTF8String;
begin
  u8 := UTF8String(AString + LineEnding);
  ms := TMemoryStream.Create;
  try
    if Length(u8) > 0 then
      ms.Write(u8[1], Length(u8));
    WriteStreamToHandle(ms, STDERR_FILENO);
  finally
    ms.Free;
  end;
end;

function RunAddr2Line(const AFileName: string; AAddress: NativeUInt; out Lines: TStringList): Boolean;
var
  cmd: AnsiString;
  fileC: PAnsiChar;
  stream: Pointer;
  buf: array[0..ADDR2LINE_BUF - 1] of AnsiChar;
  p: PAnsiChar;
  tmp: AnsiString;
begin
  Result := False;
  Lines := TStringList.Create;
  try
    cmd := AnsiString(Format('addr2line -f -C -e "%s" 0x%x', [AFileName, AAddress]));
    fileC := PAnsiChar(cmd);
    stream := popen(fileC, 'r');

    if stream = nil then
    begin
      Lines.Add('addr2line binary not found! Install binutils.');
      Exit(False);
    end;

    // Leer líneas hasta EOF
    while Assigned(fgets(@buf[0], ADDR2LINE_BUF, stream)) do
    begin
      p := @buf[0];
      tmp := string(p);
      tmp := TrimRight(tmp);
      Lines.Add(string(UTF8String(tmp)));
    end;

    pclose(stream);

    if Lines.Count = 0 then
      Lines.Add('addr2line could not resolve addresses.');

    Result := Lines.Count > 0;
  except
    if Assigned(Lines) then
    begin
      Lines.Clear;
      Lines.Add('Exception running addr2line.');
    end;
    Result := False;
  end;
end;

// --- Funciones que se asignan a Exception class (misma idea que tu original) ---
// GetExceptionStackInfo: captura stack nativo y devuelve puntero opaco con: [Count: NativeInt][Ptr1][Ptr2]...
function GetExceptionStackInfo(P: Pointer): Pointer;
var
  Buffer: array[0..MAX_STACK_DEPTH - 1] of Pointer;
  Count: Integer;
  TotalSize: NativeInt;
  ResultPointer: Pointer;
begin
  Count := backtrace(@Buffer[0], MAX_STACK_DEPTH);

  TotalSize := SizeOf(NativeInt) + Count * POINTER_SIZE;
  ResultPointer := AllocMem(TotalSize);

  if ResultPointer = nil then
  begin
    Result := nil;
    Exit;
  end;

  NativeInt(ResultPointer^) := Count;

  if Count > 0 then
    Move(Buffer[0], Pointer(NativeInt(ResultPointer) + SizeOf(NativeInt))^, Count * POINTER_SIZE);

  Result := ResultPointer;
end;

// Helper para formatear puntero a hex
function PtrToHex(p: Pointer): string;
begin
  Result := Format('0x%x', [NativeUInt(p)]);
end;

// GetStackInfoString: toma el bloque opaco y lo transforma a texto resolviendo símbolos con dladdr+addr2line
function GetStackInfoString(Info: Pointer): string;
var
  Count: NativeInt;
  FramePointers: Pointer;
  i: Integer;
  FrameAddr: Pointer;
  dl: TDl_info;
  fname: string;
  Lines: TStringList;
  ok: Boolean;
  relative: NativeUInt;
  s: string;
begin
  Result := '';
  if Info = nil then Exit;

  Count := NativeInt(Info^);
  if Count <= 0 then Exit;

  FramePointers := Pointer(NativeInt(Info) + SizeOf(NativeInt));

  for i := 0 to Count - 1 do
  begin
    FrameAddr := PPointer(NativeInt(FramePointers) + i * POINTER_SIZE)^;

    // Si dladdr puede identificar la librería/exe:
    if dladdr(FrameAddr, @dl) <> 0 then
    begin
      if dl.dli_fname <> nil then
        fname := string(UTF8ToString(dl.dli_fname))
      else
        fname := '';

      // Primero intenta addr2line con dirección absoluta
      ok := RunAddr2Line(fname, NativeUInt(FrameAddr), Lines);
      if ok and (Lines <> nil) then
      begin
        // addr2line con -f -C devuelve normalmente: function_name\nfile:line\n
        if Lines.Count >= 2 then
          s := Trim(Lines[0]) + ' at ' + Trim(Lines[1])
        else
          s := Trim(Lines.Text);
        Result := Result + s + LineEnding;
        FreeAndNil(Lines);
        Continue;
      end;
      if Assigned(Lines) then FreeAndNil(Lines);

      // Si falló, intenta con dirección relativa (addr - base)
      if dl.dli_fbase <> nil then
      begin
        relative := NativeUInt(FrameAddr) - NativeUInt(dl.dli_fbase);
        ok := RunAddr2Line(fname, relative, Lines);
        if ok and (Lines <> nil) then
        begin
          if Lines.Count >= 2 then
            s := Trim(Lines[0]) + ' at ' + Trim(Lines[1])
          else
            s := Trim(Lines.Text);
          Result := Result + s + LineEnding;
          FreeAndNil(Lines);
          Continue;
        end;
        if Assigned(Lines) then FreeAndNil(Lines);
      end;

      // Si no resolvió con addr2line, intenta usar el nombre de símbolo devuelto por dladdr
      if dl.dli_sname <> nil then
        Result := Result + Format('%s (in %s)%s', [string(UTF8ToString(dl.dli_sname)), fname, LineEnding])
      else
        Result := Result + Format('%s (in %s)%s', [PtrToHex(FrameAddr), fname, LineEnding]);
    end
    else
    begin
      // Si dladdr no ayudó, mostramos la dirección hex
      Result := Result + PtrToHex(FrameAddr) + LineEnding;
    end;
  end;
end;

// CleanUpStackInfo: libera el bloque opaco
procedure CleanUpStackInfo(Info: Pointer);
begin
  if Info <> nil then
    FreeMem(Info);
end;

// Inicialización: asignar las proc pointers en Exception (como hacías)
procedure  InitStackTraceExceptionHandling;
begin
  if (InitDone) then
   exit;
  Pointer(Exception.GetExceptionStackInfoProc) := @GetExceptionStackInfo;
  Pointer(Exception.GetStackInfoStringProc) := @GetStackInfoString;
  Pointer(Exception.CleanUpStackInfoProc) := @CleanUpStackInfo;
  InitDone:=true;
end;

initialization

finalization
  Pointer(Exception.GetExceptionStackInfoProc) := nil;
  Pointer(Exception.GetStackInfoStringProc) := nil;
  Pointer(Exception.CleanUpStackInfoProc) := nil;
end.

{$ELSE}
interface
implementation
end.
{$ENDIF}


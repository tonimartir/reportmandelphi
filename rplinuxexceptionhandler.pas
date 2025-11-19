unit rplinuxexceptionhandler;

// Unidad de control de excepciones para aplicaciones de consola en Linux 64-bit.
// Implementa la misma lógica de enganche que JCL para máxima compatibilidad:
// 1. Log SILENCIOSO de TODAS las excepciones (manejadas o no) mediante hooks internos de la RTL (SetupExceptionProcs).
// 2. Customización del Stack Trace de la clase Exception con backtrace nativo de Linux (usando las firmas correctas).
// 3. Manejo de fallos fatales (SIGSEGV, etc.) usando señales POSIX.

{$IFDEF LINUX}
interface

uses
  System.SysUtils, Classes, Types;

const LineEnding = chr(10);

// Funciones expuestas para uso interno del logger y llamadas internas de la RTL
procedure WriteToStdError(AString: string);

implementation


// Tipo de puntero de función para el Hook de Excepciones Global (para SetupExceptionProcs)
type
  TExceptionProc = function(E: Exception; const ErrorAddr: Pointer): Boolean;

// --- TIPOS CORRECTOS DE CUSTOMIZACIÓN DE STACK INFO (Variables estáticas de la clase Exception) ---
// Estas son las firmas EXACTAS que usa la clase Exception en la RTL.
type
  // La función recibe el PExceptionRecord y debe devolver un puntero al bloque de información de la pila
  TGetExceptionStackInfoProc = function (P: Pointer): Pointer;
  // La función recibe el puntero devuelto arriba y debe formatearlo como string
  TGetStackInfoStringProc = function (Info: Pointer): string;
  // La función recibe el puntero y debe liberar la memoria
  TCleanUpStackInfoProc = procedure (Info: Pointer);


// --- 1. Constantes y Declaraciones de Bajo Nivel (POSIX/libc) ---

const
  libc = 'libc.so.6';
  STDERR_FILENO = 2; // File Descriptor para Standard Error

  // Señales POSIX fatales
  SIGSEGV = 11;
  SIGILL = 4;
  SIGFPE = 8;
  SIGBUS = 7;
  SIGABRT = 6;
  MAX_STACK_DEPTH = 50;

  // Tamaño del puntero en bytes
  POINTER_SIZE = SizeOf(Pointer);

// Tipos de funciones para el manejador de señales
type
  TSigHandler = procedure(signum: Integer); cdecl;
  PSigAction = ^TSigAction;
  TSigAction = packed record
    sa_handler: TSigHandler;
    sa_flags: Integer;
  end;

// Funciones de la librería C
function write(FD: Integer; const Buffer: Pointer; Count: NativeInt): NativeInt; cdecl; external libc;
function backtrace(Buffer: Pointer; Size: Integer): Integer; cdecl; external libc;
function backtrace_symbols(const Buffer: Pointer; Size: Integer): Pointer; cdecl; external libc;
procedure free(P: Pointer); cdecl; external libc;
function sigaction(signum: Integer; act, oldact: PSigAction): Integer; cdecl; external libc;

// --- 2. Implementación de WriteToStdError (Escritura segura en consola) ---

procedure WriteStreamToHandle(AStream: TMemoryStream; Handle: Integer);
begin
  if AStream.Size > 0 then
    write(Handle, AStream.Memory, AStream.Size);
end;

procedure WriteToStdError(AString: string);
var
  AStream: TMemoryStream;
  u8string: UTF8String;
begin
  u8string := AString + LineEnding;
  AStream := TMemoryStream.Create;
  try
    AStream.Write(u8string[1], Length(u8string));
    WriteStreamToHandle(AStream, STDERR_FILENO);
  finally
    AStream.Free;
  end;
end;

// --- 3. Customización de Stack Trace (Las *Proc's de la clase Exception) ---

// Se llama cuando el objeto Exception es creado. Captura la pila nativa y la guarda.
function GetExceptionStackInfo(P: Pointer): Pointer;
var
  Buffer: array[0..MAX_STACK_DEPTH - 1] of Pointer;
  Count: Integer;
  TotalSize: NativeInt;
  ResultPointer: Pointer;
begin
  // 1. Capturar el Stack Trace de bajo nivel
  Count := backtrace(@Buffer[0], MAX_STACK_DEPTH);

  // 2. Calcular el tamaño: NativeInt para el contador + espacio para los punteros de los frames
  TotalSize := SizeOf(NativeInt) + Count * POINTER_SIZE;
  ResultPointer := AllocMem(TotalSize);

  // 3. Almacenar el contador de frames en la primera NativeInt del bloque
  NativeInt(ResultPointer^) := Count;

  // 4. Copiar los punteros de los frames de la pila inmediatamente después del contador
  if Count > 0 then
    Move(Buffer[0], Pointer(NativeInt(ResultPointer) + SizeOf(NativeInt))^, Count * POINTER_SIZE);

  Result := ResultPointer; // Devolver el puntero opaco
end;

// Se llama cuando se accede a E.StackTrace. Convierte la pila guardada en una cadena.
function GetStackInfoString(Info: Pointer): string;
var
  Count: NativeInt;
  FramePointers: Pointer;
  Symbols: Pointer;
  i: Integer;
begin
  Result := '';
  if Info = nil then Exit;

  // 1. Recuperar el contador de frames de la primera NativeInt
  Count := NativeInt(Info^);
  if Count = 0 then Exit;

  // 2. Obtener el puntero a la lista de frames (después del NativeInt del contador)
  FramePointers := Pointer(NativeInt(Info) + SizeOf(NativeInt));

  // 3. Obtener los nombres de símbolos de libc
  Symbols := backtrace_symbols(FramePointers, Count);

  // 4. Concatenar los símbolos en la cadena de resultado
  if Symbols <> nil then
  begin
    for i := 0 to Count - 1 do
    begin
      Result := Result + PAnsiChar(NativeInt(Symbols) + i * POINTER_SIZE) + LineEnding;
    end;

    // 5. Liberar la memoria asignada por backtrace_symbols
    free(Symbols);
  end;
end;

// Se llama cuando el objeto Exception es liberado. Libera la memoria de la pila.
procedure CleanUpStackInfo(Info: Pointer);
begin
  if Info <> nil then
    FreeMem(Info);
end;


procedure InitExceptionHandling;
begin
  // A. Enganche de la customización del Stack Trace (las *Proc's estáticas)
  // Ahora usan las firmas correctas.
  Pointer(Exception.GetExceptionStackInfoProc) := @GetExceptionStackInfo;
  Pointer(Exception.GetStackInfoStringProc) := @GetStackInfoString;
  Pointer(Exception.CleanUpStackInfoProc) := @CleanUpStackInfo;

end;



initialization
  InitExceptionHandling;
end.
finalization
  // Es crucial liberar los hooks al finalizar
  ResetExceptionProcs;

  // Restaurar los hooks de Stack Trace de la clase Exception a nil
  Pointer(Exception.GetExceptionStackInfoProc) := nil;
  Pointer(Exception.GetStackInfoStringProc) := nil;
  Pointer(Exception.CleanUpStackInfoProc) := nil;
{$ELSE}
// El compilador no es LINUX, la unidad está vacía.
interface
implementation
end.
{$ENDIF}

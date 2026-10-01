unit rpfpcutils;


{$mode delphi}

interface


uses SysUtils{$IFDEF DARWIN}, dynlibs{$ENDIF};


function FormatFloat(format:string;number:Double):String;
function FormatCurr(format:string;number:Double):String;
{$IFDEF DARWIN}
// Loads a library of the engine (FreeType, HarfBuzz, fontconfig) on macOS:
// first the copy in the application bundle (Contents/Frameworks), then the
// one next to the executable, then the dyld search (DYLD_LIBRARY_PATH,
// /usr/local/lib) and the Homebrew and MacPorts prefixes. NilHandle when no
// copy loads.
function RpLoadDarwinLibrary(const AName: string): TLibHandle;
{$ENDIF}

implementation

function FormatFloat(format:string;number:Double):String;
begin

 Result:=FloatToStr(number);
end;

function FormatCurr(format:string;number:Double):String;
begin
 Result:=CurrToStr(number);
end;

{$IFDEF DARWIN}
function RpLoadDarwinLibrary(const AName: string): TLibHandle;
var
  LExeDir: string;
  LPaths: array[0..4] of string;
  I: Integer;
begin
  LExeDir := ExtractFilePath(ParamStr(0));
  LPaths[0] := LExeDir + '../Frameworks/' + AName;
  LPaths[1] := LExeDir + AName;
  LPaths[2] := AName;
  LPaths[3] := '/opt/homebrew/lib/' + AName;
  LPaths[4] := '/opt/local/lib/' + AName;
  Result := NilHandle;
  for I := Low(LPaths) to High(LPaths) do
  begin
    Result := SafeLoadLibrary(LPaths[I]);
    if Result <> NilHandle then
      Exit;
  end;
end;
{$ENDIF}

end.

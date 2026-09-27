{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpioutilsfpc                                    }
{       Subset of Delphi's System.IOUtils for           }
{       Free Pascal                                     }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// FPC 3.2.2 has no System.IOUtils. The shared Hub units use TPath, TFile and
// TDirectory for the per-user settings file and a debug log; these records
// provide those methods with Delphi's behaviour (GetHomePath is %APPDATA% on
// Windows and $HOME elsewhere; text files are UTF-8 without BOM).

unit rpioutilsfpc;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes;

type
  TPath = record
  public
    class function Combine(const APath1, APath2: string): string; static;
    class function GetHomePath: string; static;
    class function GetDocumentsPath: string; static;
    class function GetTempPath: string; static;
    class function GetFileName(const AFileName: string): string; static;
    class function GetFileNameWithoutExtension(const AFileName: string): string; static;
    class function GetDirectoryName(const AFileName: string): string; static;
    class function GetExtension(const AFileName: string): string; static;
    class function ChangeExtension(const APath, AExtension: string): string; static;
    class function IsPathRooted(const APath: string): Boolean; static;
    class function DirectorySeparatorChar: Char; static;
    class function PathSeparator: Char; static;
  end;

  TFile = record
  public
    class function Exists(const APath: string): Boolean; static;
    class procedure Delete(const APath: string); static;
    class function ReadAllText(const APath: string): string; static;
    class procedure WriteAllText(const APath, AContents: string); static;
    class procedure AppendAllText(const APath, AContents: string); static;
    class function ReadAllBytes(const APath: string): TBytes; static;
    class procedure WriteAllBytes(const APath: string; const ABytes: TBytes); static;
  end;

  TDirectory = record
  public
    class function Exists(const APath: string): Boolean; static;
    class procedure CreateDirectory(const APath: string); static;
    class procedure Delete(const APath: string; const ARecursive: Boolean = False); static;
  end;

implementation

{ TPath }

class function TPath.Combine(const APath1, APath2: string): string;
begin
  if APath1 = '' then
    Result := APath2
  else if APath2 = '' then
    Result := APath1
  else if IsPathRooted(APath2) then
    Result := APath2
  else
    Result := IncludeTrailingPathDelimiter(APath1) + APath2;
end;

class function TPath.GetHomePath: string;
begin
{$IFDEF MSWINDOWS}
  Result := GetEnvironmentVariable('APPDATA');
{$ELSE}
  Result := GetEnvironmentVariable('HOME');
{$ENDIF}
  if Result = '' then
    Result := GetUserDir;
  Result := ExcludeTrailingPathDelimiter(Result);
end;

class function TPath.GetDocumentsPath: string;
begin
{$IFDEF MSWINDOWS}
  Result := GetEnvironmentVariable('USERPROFILE');
  if Result <> '' then
    Result := Combine(Result, 'Documents');
{$ELSE}
  Result := GetEnvironmentVariable('HOME');
{$ENDIF}
  if Result = '' then
    Result := GetUserDir;
  Result := ExcludeTrailingPathDelimiter(Result);
end;

class function TPath.GetTempPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir);
end;

class function TPath.GetFileName(const AFileName: string): string;
begin
  Result := ExtractFileName(AFileName);
end;

class function TPath.GetFileNameWithoutExtension(const AFileName: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(AFileName), '');
end;

class function TPath.GetDirectoryName(const AFileName: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(ExtractFileDir(AFileName));
end;

class function TPath.GetExtension(const AFileName: string): string;
begin
  Result := ExtractFileExt(AFileName);
end;

class function TPath.ChangeExtension(const APath, AExtension: string): string;
begin
  if (AExtension <> '') and (AExtension[1] <> '.') then
    Result := ChangeFileExt(APath, '.' + AExtension)
  else
    Result := ChangeFileExt(APath, AExtension);
end;

class function TPath.IsPathRooted(const APath: string): Boolean;
begin
{$IFDEF MSWINDOWS}
  Result := (Length(APath) >= 1) and (APath[1] in ['\', '/']) or
    (Length(APath) >= 2) and (APath[2] = ':');
{$ELSE}
  Result := (Length(APath) >= 1) and (APath[1] = '/');
{$ENDIF}
end;

class function TPath.DirectorySeparatorChar: Char;
begin
  Result := PathDelim;
end;

class function TPath.PathSeparator: Char;
begin
  Result := PathSep;
end;

{ TFile }

class function TFile.Exists(const APath: string): Boolean;
begin
  Result := FileExists(APath);
end;

class procedure TFile.Delete(const APath: string);
begin
  SysUtils.DeleteFile(APath);
end;

class function TFile.ReadAllBytes(const APath: string): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

class procedure TFile.WriteAllBytes(const APath: string; const ABytes: TBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
  finally
    LStream.Free;
  end;
end;

class function TFile.ReadAllText(const APath: string): string;
var
  LBytes: TBytes;
  LStart: Integer;
begin
  LBytes := ReadAllBytes(APath);
  LStart := 0;
  if (Length(LBytes) >= 3) and (LBytes[0] = $EF) and (LBytes[1] = $BB) and (LBytes[2] = $BF) then
    LStart := 3;
  SetLength(Result, Length(LBytes) - LStart);
  if Length(Result) > 0 then
    Move(LBytes[LStart], Result[1], Length(Result));
end;

class procedure TFile.WriteAllText(const APath, AContents: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AContents <> '' then
      LStream.WriteBuffer(AContents[1], Length(AContents));
  finally
    LStream.Free;
  end;
end;

class procedure TFile.AppendAllText(const APath, AContents: string);
var
  LStream: TFileStream;
begin
  if FileExists(APath) then
    LStream := TFileStream.Create(APath, fmOpenReadWrite or fmShareDenyWrite)
  else
    LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.Seek(0, soEnd);
    if AContents <> '' then
      LStream.WriteBuffer(AContents[1], Length(AContents));
  finally
    LStream.Free;
  end;
end;

{ TDirectory }

class function TDirectory.Exists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

class procedure TDirectory.CreateDirectory(const APath: string);
begin
  if (APath <> '') and not DirectoryExists(APath) then
    if not ForceDirectories(APath) then
      raise EInOutError.CreateFmt('Cannot create directory %s', [APath]);
end;

procedure DeleteTree(const APath: string);
var
  LSearch: TSearchRec;
  LBase: string;
begin
  LBase := IncludeTrailingPathDelimiter(APath);
  if FindFirst(LBase + AllFilesMask, faAnyFile, LSearch) = 0 then
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
        Continue;
      if (LSearch.Attr and faDirectory) <> 0 then
        DeleteTree(LBase + LSearch.Name)
      else
        SysUtils.DeleteFile(LBase + LSearch.Name);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  RemoveDir(APath);
end;

class procedure TDirectory.Delete(const APath: string; const ARecursive: Boolean);
begin
  if ARecursive then
    DeleteTree(APath)
  else
    RemoveDir(APath);
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdbxdotnet                                     }
{       Connections of this computer shared with .NET   }
{       (DriverName=ADO.NET in dbxconnections)          }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpdbxdotnet;

{ The Reportman AI Desktop and chat, Reportman.Server and the C# designer keep
  the "connections of this computer" in the shared dbxconnections file, in the
  format of Reportman.Server:

    [VENTAS]
    DriverName=ADO.NET
    ProviderFactory=SQLiteCore
    Param.DataSource=C:\datos\ventas.db
    Secret.Password=dpapi:BASE64...
    ConnectionString=Data Source=C:\datos\ventas.db

  - ProviderFactory: the invariant name of the C# designer
    (FirebirdSql.Data.FirebirdClient, SQLServer, MySQLConnector, PostgreSQL,
    Oracle, SQLiteCore, System.Data.Odbc, System.Data.OleDb).
  - Param.<Name>: the property names of the .NET connection string builder.
  - Secret.<Name>: a password, never in clear: 'dpapi:' + base64 of
    CryptProtectData (current user, UI forbidden, entropy = UTF-8 of
    'Reportman.dbxconnections', data = UTF-8 of the password). A Param.Password
    in clear (written by Reportman.Server) may also be there.

  Delphi shows these connections, but it opens them with its own driver and
  parameters, kept in the SAME section under keys of its own:

    Delphi.DriverName=FireDac
    Delphi.DriverID=SQLite
    Delphi.Database=C:\datos\ventas.db

  Delphi never writes DriverName, ProviderFactory, Param.* or
  ConnectionString: the .NET programs keep the keys they do not know
  (Delphi.* included) and rewrite theirs on every save.

  The password is ONE for every program of the computer: the Secret.Password
  of the section (Secret.<Name> of a password, if .NET wrote another name),
  ciphered with DPAPI in the same way. Delphi reads it, and when the user
  types another one (or this Windows user can not read the one there is) it
  writes it there, replacing only that line, as the C# designer does. So the
  two designers, the Desktop and the chat ask for it once. It is never
  written in clear: without DPAPI (outside Windows) it is not saved.

  The first time Delphi uses one, the designers ask for these parameters,
  proposed from the .NET ones (RpDotNetProposeDelphiParams). Writing them
  touches only the Delphi.* lines (and the line of the password) of the
  section: every other byte of the file (other sections, comments, blank
  lines) stays as it was, as the .NET writer does. The whole file is
  written so by Delphi (RpIniSaveChanges, below).

  Phase F9 of docs/reportman-ai-chat-conexiones-locales-plan.md (ReportmanAI). }

interface

{$I rpconf.inc}

uses
  Classes, SysUtils, IniFiles;

const
  RP_DOTNET_DRIVER_NAME = 'ADO.NET';
  RP_DOTNET_PROVIDER_KEY = 'ProviderFactory';
  RP_DOTNET_CONNECTIONSTRING_KEY = 'ConnectionString';
  RP_DOTNET_PARAM_PREFIX = 'Param.';
  RP_DOTNET_SECRET_PREFIX = 'Secret.';
  RP_DOTNET_DELPHI_PREFIX = 'Delphi.';
  RP_DOTNET_DPAPI_PREFIX = 'dpapi:';
  // Not a secret: it only tells these values apart from other DPAPI values
  // of the same Windows user. The same in every program that reads them
  RP_DOTNET_DPAPI_ENTROPY = 'Reportman.dbxconnections';
  // The Delphi driver proposed for every provider (FireDAC in Delphi, SQLdb
  // in the FPC engine, by DriverID)
  RP_DOTNET_PROPOSED_DRIVER = 'FireDac';

resourcestring
  SRpDotNetMark = ' (.NET)';
  SRpDotNetNotDefined = 'The connection %s is a connection of this computer '+
    'shared with .NET (%s): define its Delphi parameters in the connections '+
    'of the designer before opening it';
  SRpDotNetCannotReplace = 'The connection %s is a connection of this '+
    'computer shared with .NET: Delphi can not replace it, choose another name';
  SRpDotNetNotFound = 'The connection %s shared with .NET is not in the '+
    'connections file %s';
  // The dialogs of the designers (VCL and LCL)
  SRpDotNetSetupTitle = 'Delphi parameters of %s';
  // After the text 2071 of reportmanres ('Connection of this computer: %s')
  SRpDotNetSetupInfo = '%s is shared with the .NET programs (Reportman AI, '+
    'Reportman Designer, Reportman.Server). Delphi opens it with a driver of '+
    'its own, and its parameters are kept apart in the same connection: the '+
    'ones of .NET do not change. The password is the one of the connection '+
    'for every program.';
  SRpDotNetSetupProposed = 'They are proposed from the parameters of .NET: '+
    'check them and accept.';
  SRpDotNetSetupNotClear = 'Choose the driver and fill in its parameters.';
  SRpDotNetSetupDefined = 'The Delphi parameters it has now.';
  SRpDotNetDriver = 'Driver';
  SRpDotNetParameter = 'Parameter';
  SRpDotNetValue = 'Value';
  SRpDotNetPassword = 'Password';
  SRpDotNetPasswordKept = 'Stored ciphered for your Windows user, the same '+
    'for every program of this computer.';
  SRpDotNetPasswordNotKept = 'Not kept on this system: it is asked for when '+
    'the connection opens.';
  SRpDotNetParamsButton = 'Delphi parameters...';
  SRpDotNetNotDefinedYet = 'Its Delphi parameters are not defined yet: they '+
    'are asked for the first time it is used.';
  SRpDotNetForget = 'Forget the Delphi parameters of %s? The connection is '+
    'shared with .NET and stays; they are asked for again the next time it '+
    'is used.';

// A DriverName of a connection shared with .NET (ADO.NET)
function RpIsDotNetDriverName(const ADriverName: string): Boolean;
// A parameter that holds a password (never written in clear)
function RpIsPasswordParamName(const AName: string): Boolean;

// DPAPI of the current Windows user ('' / False elsewhere)
function RpDpapiAvailable: Boolean;
// 'dpapi:' + base64, or '' when it can not be ciphered here
function RpDpapiProtect(const APlain: string): string;
// False when it is not a value of this Windows user (or not ciphered)
function RpDpapiUnprotect(const AStored: string; out APlain: string): Boolean;

// Base64 without line breaks (as .NET Convert.ToBase64String)
function RpBase64Encode(const ABytes: TBytes): string;
function RpBase64Decode(const AText: string; out ABytes: TBytes): Boolean;

// The functions below take ASection: the Name=Value lines of the section
// (TMemIniFile.ReadSectionValues of RpCreateConnectionsIni)

// Its Delphi parameters are defined (Delphi.DriverName)
function RpDotNetHasDelphiParams(ASection: TStrings): Boolean;
// Its Delphi parameters (Delphi.* without the prefix) and Password, the one
// of the connection (RpDotNetPassword; not for SQLite, whose .NET password
// is a key of SQLCipher)
procedure RpDotNetDelphiParams(ASection, AParams: TStrings);
// The Delphi parameters proposed from the .NET ones (FireDAC, by DriverID),
// with the password of the connection when it can be read. True when the
// translation is clear; otherwise only DriverName=FireDac
function RpDotNetProposeDelphiParams(ASection, AParams: TStrings;
  AWithPassword: Boolean = True): Boolean;
// The password of the connection: its Secret.* of a password deciphered
// (DPAPI of this user), otherwise one in clear of Reportman.Server
// (Param.Password, Pwd, the connection string); '' when there is none or it
// is of another Windows user
function RpDotNetPassword(ASection: TStrings): string;
// The key the password is written in: the Secret.* of a password there is,
// otherwise Secret.Password
function RpDotNetPasswordKey(ASection: TStrings): string;
// The Delphi driver it opens with: Delphi.DriverName, or the proposed one
function RpDotNetEffectiveDriverName(ASection: TStrings): string;
// 'SQLiteCore: C:\datos\ventas.db' (the provider and where the data is)
function RpDotNetDescription(ASection: TStrings): string;
// The lines to write for AParams: Delphi.<Name>=<Value>, DriverName first,
// empty values and the passwords left out (the password is the one of the
// connection, Secret.*)
procedure RpDotNetDelphiLines(AParams, ALines: TStrings);

{ The shared connections file (dbxconnections), written surgically.

  The designers, the Desktop, the chat and Reportman.Server write the same
  file, so nobody rewrites it whole (TMemIniFile.UpdateFile drops the
  comments and the blank lines, loses the keys of a repeated section and,
  as the file is read when a dialog opens and written when it closes,
  overwrites what another program saved meanwhile). TRpConnAdmin keeps a
  snapshot of what it read (TRpIniSnapshot) and saves the DIFFERENCES
  between it and the TMemIniFile in memory (RpIniSaveChanges), applied line
  by line to the file as it is on disk at that moment: a value changed in
  its line, a new key after the last one of its section, a key deleted
  without its line, a new section at the end, a deleted section without its
  lines. Comments, order, blank lines, the sections and keys of other
  programs and their changes meanwhile stay as they are.

  The encoding, the same rule in Delphi, FPC and .NET: with a UTF-8 BOM
  (EF BB BF) the file is UTF-8 and is written again with its BOM; without
  it, the ANSI code page of the system in Windows and UTF-8 in Linux and
  macOS. The line breaks (CRLF/LF) and whether it ends with one stay. }

type
  // What a connections file had: its sections, with their keys and values
  TRpIniSnapshot = class(TObject)
  private
    FSections: TStringList;
    function GetCount: Integer;
    function GetName(AIndex: Integer): string;
    function GetValues(AIndex: Integer): TStrings;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    // The sections, keys and values of AIni
    procedure Assign(AIni: TCustomIniFile);
    function IndexOf(const ASection: string): Integer;
    property Count: Integer read GetCount;
    property Names[AIndex: Integer]: string read GetName;
    // Name=Value, in their order
    property Values[AIndex: Integer]: TStrings read GetValues;
  end;

// The encoding of a connections file by the rule: UTF-8 with a BOM; without
// it, the ANSI code page of the system in Windows, UTF-8 elsewhere. A
// standard instance (TEncoding.UTF8, TEncoding.ANSI) or, in FPC on Windows,
// a new one of GetACP that the caller frees (AOwned)
function RpIniFileEncoding(const AFileName: string; out AOwned: Boolean): TEncoding;
// The TMemIniFile of a connections file, read by that rule (case
// insensitive). It owns the encoding it needs
function RpCreateConnectionsIni(const AFileName: string): TMemIniFile;
// Frees the TMemIniFile of a connections file WITHOUT writing it: the one
// of FPC writes the whole file when it is freed with changes (CacheUpdates);
// the file is only written by RpIniSaveChanges
procedure RpFreeConnectionsIni(var AIni: TMemIniFile);
// Saves in AFileName, as it is on disk now, the differences between
// ASnapshot (what was read) and AIni (what there is in memory). The file is
// created when it is not there. Every other byte stays
procedure RpIniSaveChanges(const AFileName: string; ASnapshot: TRpIniSnapshot;
  AIni: TCustomIniFile);

// The name of a connection in the lists of the designers (with the mark of
// .NET) and back
function RpDotNetDisplayName(const AName: string): string;
function RpConnectionNameFromDisplay(const AText: string): string;

// The dialogs of the designers. The Delphi drivers that can open a
// connection shared with .NET in this build (ACurrent first when it has one)
procedure RpDotNetDelphiDrivers(ADrivers: TCustomIniFile;
  const ACurrent: string; AList: TStrings);
// The parameters of ADriverName (its section of the drivers file without the
// libraries) with the values of ACurrent of the same names. FireDac keeps
// ACurrent: its parameters are the ones of its DriverID
procedure RpDotNetDriverParams(ADrivers: TCustomIniFile;
  const ADriverName: string; ACurrent, AResult: TStrings);
// The text that shows Delphi parameters, the passwords hidden
function RpDotNetParamsText(AParams: TStrings): string;
// What a connection shared with .NET is, for the dialogs: the text 2071 of
// reportmanres (the same as the C# designer) with its description, then
// SRpDotNetSetupInfo
function RpDotNetSetupText(const AAlias, ADescription: string): string;

implementation

uses
  rpmdconsts;

{$IFDEF MSWINDOWS}
{$IFDEF FPC}
{$PACKRECORDS C}
{$ELSE}
{$ALIGN 8}
{$ENDIF}
type
  PRpDataBlob = ^TRpDataBlob;
  TRpDataBlob = record
    cbData: Cardinal;
    pbData: PByte;
  end;

const
  CRYPTPROTECT_UI_FORBIDDEN = $1;

function CryptProtectData(pDataIn: PRpDataBlob; szDataDescr: PWideChar;
  pOptionalEntropy: PRpDataBlob; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: Cardinal; pDataOut: PRpDataBlob): LongBool; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';
function CryptUnprotectData(pDataIn: PRpDataBlob; ppszDataDescr: Pointer;
  pOptionalEntropy: PRpDataBlob; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: Cardinal; pDataOut: PRpDataBlob): LongBool; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';
function RpLocalFree(hMem: Pointer): Pointer; stdcall;
  external 'kernel32.dll' name 'LocalFree';

const
  MOVEFILE_REPLACE_EXISTING = $1;
  MOVEFILE_WRITE_THROUGH = $8;

function RpMoveFileEx(lpExistingFileName, lpNewFileName: PWideChar;
  dwFlags: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'MoveFileExW';
// The ANSI code page of the system
function RpGetACP: Cardinal; stdcall; external 'kernel32.dll' name 'GetACP';
{$ENDIF}

const
  BASE64_CHARS: string =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

{ Text and bytes }

function Utf8Bytes(const S: string): TBytes;
var
  U: UTF8String;
begin
  Result := nil;
  U := UTF8String(S);
  SetLength(Result, Length(U));
  if Length(U) > 0 then
    Move(U[1], Result[0], Length(U));
end;

function Utf8Text(const B: TBytes; AStart, ACount: Integer): string;
var
  U: UTF8String;
begin
  SetLength(U, ACount);
  if ACount > 0 then
    Move(B[AStart], U[1], ACount);
  Result := string(U);
end;

function RpIsDotNetDriverName(const ADriverName: string): Boolean;
begin
  Result := SameText(Trim(ADriverName), RP_DOTNET_DRIVER_NAME);
end;

function RpIsPasswordParamName(const AName: string): Boolean;
begin
  Result := (Pos('PASSWORD', UpperCase(AName)) > 0) or SameText(Trim(AName), 'pwd');
end;

function RpDotNetDisplayName(const AName: string): string;
begin
  Result := AName + SRpDotNetMark;
end;

function RpConnectionNameFromDisplay(const AText: string): string;
var
  LMark: string;
begin
  Result := AText;
  LMark := SRpDotNetMark;
  if (Length(LMark) > 0) and (Length(Result) > Length(LMark)) and
    (Copy(Result, Length(Result) - Length(LMark) + 1, Length(LMark)) = LMark) then
    Result := Copy(Result, 1, Length(Result) - Length(LMark));
end;

{ Base64 }

function RpBase64Encode(const ABytes: TBytes): string;
var
  I, LLen, LValue: Integer;
begin
  Result := '';
  LLen := Length(ABytes);
  I := 0;
  while I < LLen do
  begin
    LValue := ABytes[I] shl 16;
    if I + 1 < LLen then
      LValue := LValue or (ABytes[I + 1] shl 8);
    if I + 2 < LLen then
      LValue := LValue or ABytes[I + 2];
    Result := Result + BASE64_CHARS[((LValue shr 18) and $3F) + 1] +
      BASE64_CHARS[((LValue shr 12) and $3F) + 1];
    if I + 1 < LLen then
      Result := Result + BASE64_CHARS[((LValue shr 6) and $3F) + 1]
    else
      Result := Result + '=';
    if I + 2 < LLen then
      Result := Result + BASE64_CHARS[(LValue and $3F) + 1]
    else
      Result := Result + '=';
    Inc(I, 3);
  end;
end;

function RpBase64Decode(const AText: string; out ABytes: TBytes): Boolean;
var
  I, LValue, LBits, LCount, LDigit: Integer;
  C: Char;
  LPad: Boolean;
begin
  Result := False;
  SetLength(ABytes, (Length(AText) * 3) div 4 + 3);
  LCount := 0;
  LValue := 0;
  LBits := 0;
  LPad := False;
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    if (C = ' ') or (C = #9) or (C = #13) or (C = #10) then
      Continue;
    if C = '=' then
    begin
      LPad := True;
      Continue;
    end;
    if LPad then
      Exit;
    LDigit := Pos(C, BASE64_CHARS) - 1;
    if LDigit < 0 then
      Exit;
    LValue := (LValue shl 6) or LDigit;
    Inc(LBits, 6);
    if LBits >= 8 then
    begin
      Dec(LBits, 8);
      ABytes[LCount] := (LValue shr LBits) and $FF;
      Inc(LCount);
      LValue := LValue and ((1 shl LBits) - 1);
    end;
  end;
  SetLength(ABytes, LCount);
  Result := True;
end;

{ DPAPI }

function RpDpapiAvailable: Boolean;
begin
{$IFDEF MSWINDOWS}
  Result := True;
{$ELSE}
  Result := False;
{$ENDIF}
end;

function RpDpapiProtect(const APlain: string): string;
{$IFDEF MSWINDOWS}
var
  LData, LEntropy, LOut: TBytes;
  LIn, LEnt, LResult: TRpDataBlob;
{$ENDIF}
begin
  Result := '';
{$IFDEF MSWINDOWS}
  LData := Utf8Bytes(APlain);
  LEntropy := Utf8Bytes(RP_DOTNET_DPAPI_ENTROPY);
  LIn.cbData := Length(LData);
  if Length(LData) > 0 then
    LIn.pbData := @LData[0]
  else
    LIn.pbData := nil;
  LEnt.cbData := Length(LEntropy);
  LEnt.pbData := @LEntropy[0];
  LResult.cbData := 0;
  LResult.pbData := nil;
  if not CryptProtectData(@LIn, nil, @LEnt, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, @LResult) then
    Exit;
  try
    SetLength(LOut, LResult.cbData);
    if LResult.cbData > 0 then
      Move(LResult.pbData^, LOut[0], LResult.cbData);
  finally
    RpLocalFree(LResult.pbData);
  end;
  Result := RP_DOTNET_DPAPI_PREFIX + RpBase64Encode(LOut);
{$ENDIF}
end;

function RpDpapiUnprotect(const AStored: string; out APlain: string): Boolean;
{$IFDEF MSWINDOWS}
var
  LData, LEntropy: TBytes;
  LIn, LEnt, LResult: TRpDataBlob;
  LText: string;
{$ENDIF}
begin
  Result := False;
  APlain := '';
{$IFDEF MSWINDOWS}
  LText := Trim(AStored);
  if (Length(LText) <= Length(RP_DOTNET_DPAPI_PREFIX)) or
    (Copy(LText, 1, Length(RP_DOTNET_DPAPI_PREFIX)) <> RP_DOTNET_DPAPI_PREFIX) then
    Exit;
  if not RpBase64Decode(Copy(LText, Length(RP_DOTNET_DPAPI_PREFIX) + 1,
    Length(LText)), LData) then
    Exit;
  if Length(LData) = 0 then
    Exit;
  LEntropy := Utf8Bytes(RP_DOTNET_DPAPI_ENTROPY);
  LIn.cbData := Length(LData);
  LIn.pbData := @LData[0];
  LEnt.cbData := Length(LEntropy);
  LEnt.pbData := @LEntropy[0];
  LResult.cbData := 0;
  LResult.pbData := nil;
  // Ciphered by another Windows user (or computer): False, it is asked for
  if not CryptUnprotectData(@LIn, nil, @LEnt, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, @LResult) then
    Exit;
  try
    if LResult.cbData > 0 then
    begin
      SetLength(LData, LResult.cbData);
      Move(LResult.pbData^, LData[0], LResult.cbData);
      APlain := Utf8Text(LData, 0, LResult.cbData);
    end;
  finally
    RpLocalFree(LResult.pbData);
  end;
  Result := True;
{$ENDIF}
end;

{ The section }

function SectionValue(ASection: TStrings; const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to ASection.Count - 1 do
    if SameText(Trim(ASection.Names[I]), AName) then
      Exit(Trim(ASection.ValueFromIndex[I]));
end;

function StartsText(const APrefix, AText: string): Boolean;
begin
  Result := SameText(Copy(AText, 1, Length(APrefix)), APrefix);
end;

// A name of a parameter without blanks and underscores, in capitals: the
// names of the builder ('UserID') and of the connection string ('User Id')
// are the same
function NormalName(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AName) do
    if (AName[I] <> ' ') and (AName[I] <> '_') then
      Result := Result + UpCase(AName[I]);
end;

// The pairs of a connection string (key=value;...), the keys as NormalName
procedure ParseConnectionString(const AText: string; APairs: TStrings);
var
  I, LLen: Integer;
  LKey, LValue: string;
  LQuote: Char;
begin
  APairs.Clear;
  I := 1;
  LLen := Length(AText);
  while I <= LLen do
  begin
    LKey := '';
    while (I <= LLen) and (AText[I] <> '=') and (AText[I] <> ';') do
    begin
      LKey := LKey + AText[I];
      Inc(I);
    end;
    LValue := '';
    if (I <= LLen) and (AText[I] = '=') then
    begin
      Inc(I);
      while (I <= LLen) and (AText[I] = ' ') do
        Inc(I);
      if (I <= LLen) and ((AText[I] = '"') or (AText[I] = '''')) then
      begin
        LQuote := AText[I];
        Inc(I);
        while I <= LLen do
        begin
          if AText[I] = LQuote then
          begin
            // A doubled quote is a quote
            if (I < LLen) and (AText[I + 1] = LQuote) then
            begin
              LValue := LValue + LQuote;
              Inc(I, 2);
              Continue;
            end;
            Inc(I);
            Break;
          end;
          LValue := LValue + AText[I];
          Inc(I);
        end;
        while (I <= LLen) and (AText[I] <> ';') do
          Inc(I);
      end
      else
        while (I <= LLen) and (AText[I] <> ';') do
        begin
          LValue := LValue + AText[I];
          Inc(I);
        end;
    end;
    Inc(I);
    if Trim(LKey) <> '' then
      APairs.Add(NormalName(Trim(LKey)) + '=' + Trim(LValue));
  end;
end;

function RpDotNetHasDelphiParams(ASection: TStrings): Boolean;
begin
  Result := SectionValue(ASection, RP_DOTNET_DELPHI_PREFIX + 'DriverName') <> '';
end;

function RpDotNetEffectiveDriverName(ASection: TStrings): string;
begin
  Result := SectionValue(ASection, RP_DOTNET_DELPHI_PREFIX + 'DriverName');
  if Result = '' then
    Result := RP_DOTNET_PROPOSED_DRIVER;
end;

// Sets a value, also an empty one (TStrings.Values deletes the line)
procedure SetParam(AParams: TStrings; const AName, AValue: string);
var
  LIndex: Integer;
begin
  LIndex := AParams.IndexOfName(AName);
  if LIndex >= 0 then
    AParams[LIndex] := AName + '=' + AValue
  else
    AParams.Add(AName + '=' + AValue);
end;

function RpDotNetPasswordKey(ASection: TStrings): string;
var
  I: Integer;
  LName: string;
begin
  for I := 0 to ASection.Count - 1 do
  begin
    LName := Trim(ASection.Names[I]);
    if StartsText(RP_DOTNET_SECRET_PREFIX, LName) and
      RpIsPasswordParamName(Copy(LName, Length(RP_DOTNET_SECRET_PREFIX) + 1, MaxInt)) then
      Exit(LName);
  end;
  Result := RP_DOTNET_SECRET_PREFIX + 'Password';
end;

function RpDotNetPassword(ASection: TStrings): string;
var
  I: Integer;
  LName, LPlain: string;
  LPairs: TStringList;
begin
  Result := '';
  // Ciphered for this Windows user (another one's is not read: it is asked)
  for I := 0 to ASection.Count - 1 do
  begin
    LName := Trim(ASection.Names[I]);
    if StartsText(RP_DOTNET_SECRET_PREFIX, LName) and
      RpIsPasswordParamName(Copy(LName, Length(RP_DOTNET_SECRET_PREFIX) + 1, MaxInt)) then
    begin
      if RpDpapiUnprotect(ASection.ValueFromIndex[I], LPlain) then
        Exit(LPlain);
      Exit('');
    end;
  end;
  // In clear (Reportman.Server)
  for I := 0 to ASection.Count - 1 do
  begin
    LName := Trim(ASection.Names[I]);
    if StartsText(RP_DOTNET_PARAM_PREFIX, LName) and
      RpIsPasswordParamName(Copy(LName, Length(RP_DOTNET_PARAM_PREFIX) + 1, MaxInt)) and
      (ASection.ValueFromIndex[I] <> '') then
      Exit(ASection.ValueFromIndex[I]);
  end;
  LPairs := TStringList.Create;
  try
    ParseConnectionString(SectionValue(ASection, RP_DOTNET_CONNECTIONSTRING_KEY), LPairs);
    Result := LPairs.Values['PASSWORD'];
    if Result = '' then
      Result := LPairs.Values['PWD'];
  finally
    LPairs.Free;
  end;
end;

procedure RpDotNetDelphiParams(ASection, AParams: TStrings);
var
  I: Integer;
  LName, LValue: string;
begin
  AParams.Clear;
  AParams.Add('DriverName=' + SectionValue(ASection,
    RP_DOTNET_DELPHI_PREFIX + 'DriverName'));
  for I := 0 to ASection.Count - 1 do
  begin
    LName := Trim(ASection.Names[I]);
    if not StartsText(RP_DOTNET_DELPHI_PREFIX, LName) then
      Continue;
    LValue := Trim(ASection.ValueFromIndex[I]);
    LName := Copy(LName, Length(RP_DOTNET_DELPHI_PREFIX) + 1, Length(LName));
    // The password is the one of the connection, never a Delphi.* key
    if (LName = '') or SameText(LName, 'DriverName') or
      RpIsPasswordParamName(LName) or StartsText(RP_DOTNET_SECRET_PREFIX, LName) then
      Continue;
    SetParam(AParams, LName, LValue);
  end;
  if not SameText(AParams.Values['DriverID'], 'SQLite') then
  begin
    LValue := RpDotNetPassword(ASection);
    if LValue <> '' then
      SetParam(AParams, 'Password', LValue);
  end;
end;

function RpDotNetDescription(ASection: TStrings): string;
var
  LPairs: TStringList;
  LWhere: string;

  function Find(const ANames: array of string): string;
  var
    I, J: Integer;
  begin
    Result := '';
    for J := Low(ANames) to High(ANames) do
    begin
      for I := 0 to ASection.Count - 1 do
        if StartsText(RP_DOTNET_PARAM_PREFIX, Trim(ASection.Names[I])) and
          (NormalName(Copy(Trim(ASection.Names[I]), Length(RP_DOTNET_PARAM_PREFIX) + 1,
          MaxInt)) = NormalName(ANames[J])) and (Trim(ASection.ValueFromIndex[I]) <> '') then
          Exit(Trim(ASection.ValueFromIndex[I]));
      Result := Trim(LPairs.Values[NormalName(ANames[J])]);
      if Result <> '' then
        Exit;
    end;
  end;

var
  LServer, LDatabase: string;
begin
  LPairs := TStringList.Create;
  try
    ParseConnectionString(SectionValue(ASection, RP_DOTNET_CONNECTIONSTRING_KEY), LPairs);
    // DataSource is the server when there is a database (Firebird, SQL
    // Server), the database itself otherwise (SQLite, Oracle)
    LServer := Find(['Host', 'Server', 'Dsn']);
    LDatabase := Find(['Database', 'InitialCatalog']);
    if LDatabase = '' then
      LDatabase := Find(['DataSource', 'Filename'])
    else if LServer = '' then
      LServer := Find(['DataSource']);
    if (LServer <> '') and (LDatabase <> '') and (LServer <> LDatabase) then
      LWhere := LServer + ' - ' + LDatabase
    else if LDatabase <> '' then
      LWhere := LDatabase
    else
      LWhere := LServer;
    Result := SectionValue(ASection, RP_DOTNET_PROVIDER_KEY);
    if Result = '' then
      Result := RP_DOTNET_DRIVER_NAME;
    if LWhere <> '' then
      Result := Result + ': ' + LWhere;
  finally
    LPairs.Free;
  end;
end;

function RpDotNetProposeDelphiParams(ASection, AParams: TStrings;
  AWithPassword: Boolean): Boolean;
var
  LPairs: TStringList;
  LProvider, LPassword: string;

  // The value of the first of ANames: a Param.* of the section, otherwise a
  // key of its connection string
  function Get(const ANames: array of string): string;
  var
    J, K: Integer;
    LName: string;
  begin
    Result := '';
    for J := Low(ANames) to High(ANames) do
    begin
      for K := 0 to ASection.Count - 1 do
      begin
        LName := Trim(ASection.Names[K]);
        if StartsText(RP_DOTNET_PARAM_PREFIX, LName) and
          (NormalName(Copy(LName, Length(RP_DOTNET_PARAM_PREFIX) + 1, MaxInt)) =
          NormalName(ANames[J])) and (Trim(ASection.ValueFromIndex[K]) <> '') then
          Exit(Trim(ASection.ValueFromIndex[K]));
      end;
      Result := Trim(LPairs.Values[NormalName(ANames[J])]);
      if Result <> '' then
        Exit;
    end;
  end;

  procedure Put(const AName, AValue: string);
  begin
    if AValue <> '' then
      AParams.Add(AName + '=' + AValue);
  end;

  function IsTrue(const AValue: string): Boolean;
  begin
    Result := SameText(AValue, 'true') or SameText(AValue, 'yes') or
      SameText(AValue, 'sspi') or (AValue = '1');
  end;

  procedure PutUserAndPassword(const AUserNames: array of string);
  begin
    Put('User_Name', Get(AUserNames));
    if AWithPassword then
      Put('Password', LPassword);
  end;

var
  LHost, LValue: string;
begin
  Result := False;
  AParams.Clear;
  LPairs := TStringList.Create;
  try
    ParseConnectionString(SectionValue(ASection, RP_DOTNET_CONNECTIONSTRING_KEY), LPairs);
    // The password of the connection: Secret.* (DPAPI of this user), or in
    // clear in Param.* or the connection string
    LPassword := '';
    if AWithPassword then
      LPassword := RpDotNetPassword(ASection);
    AParams.Add('DriverName=' + RP_DOTNET_PROPOSED_DRIVER);
    LProvider := LowerCase(SectionValue(ASection, RP_DOTNET_PROVIDER_KEY));
    if Pos('firebird', LProvider) > 0 then
    begin
      AParams.Add('DriverID=FB');
      // The Firebird server (DataSource of FbConnectionStringBuilder); an
      // embedded server (ServerType=1) has none
      LHost := Get(['DataSource', 'Server', 'Host']);
      LValue := Get(['ServerType']);
      if (LValue = '1') or SameText(LValue, 'Embedded') then
        LHost := '';
      Put('Server', LHost);
      Put('Port', Get(['Port']));
      LValue := Get(['Database', 'InitialCatalog']);
      Put('Database', LValue);
      PutUserAndPassword(['UserID', 'User', 'Uid', 'Username']);
      Put('CharacterSet', Get(['Charset', 'CharacterSet']));
      Put('RoleName', Get(['Role', 'RoleName']));
      Result := LValue <> '';
    end
    else if Pos('sqlite', LProvider) > 0 then
    begin
      AParams.Add('DriverID=SQLite');
      LValue := Get(['DataSource', 'Filename', 'Database']);
      Put('Database', LValue);
      // The Password of Microsoft.Data.Sqlite is a key of SQLCipher, not of
      // the encryption of FireDAC: it is not proposed
      Result := LValue <> '';
    end
    else if (LProvider = 'sqlserver') or (Pos('sqlclient', LProvider) > 0) then
    begin
      AParams.Add('DriverID=MSSQL');
      LHost := Get(['DataSource', 'Server', 'Address', 'Addr']);
      Put('Server', LHost);
      Put('Database', Get(['InitialCatalog', 'Database']));
      if IsTrue(Get(['IntegratedSecurity', 'TrustedConnection'])) then
        AParams.Add('OSAuthent=Yes')
      else
        PutUserAndPassword(['UserID', 'User', 'Uid', 'Username']);
      Result := LHost <> '';
    end
    else if (Pos('postgre', LProvider) > 0) or (Pos('npgsql', LProvider) > 0) then
    begin
      AParams.Add('DriverID=PG');
      LHost := Get(['Host', 'Server', 'DataSource']);
      Put('Server', LHost);
      Put('Port', Get(['Port']));
      Put('Database', Get(['Database', 'InitialCatalog']));
      PutUserAndPassword(['Username', 'UserID', 'User', 'Uid']);
      Result := LHost <> '';
    end
    else if Pos('mysql', LProvider) > 0 then
    begin
      AParams.Add('DriverID=MySQL');
      LHost := Get(['Server', 'Host', 'DataSource']);
      Put('Server', LHost);
      Put('Port', Get(['Port']));
      Put('Database', Get(['Database', 'InitialCatalog']));
      PutUserAndPassword(['UserID', 'User', 'Uid', 'Username']);
      Result := LHost <> '';
    end
    else if Pos('oracle', LProvider) > 0 then
    begin
      AParams.Add('DriverID=Ora');
      // The TNS alias or the EZConnect host:port/service of DataSource
      LValue := Get(['DataSource', 'Database']);
      Put('Database', LValue);
      PutUserAndPassword(['UserID', 'User', 'Uid', 'Username']);
      Result := LValue <> '';
    end
    else if Pos('odbc', LProvider) > 0 then
    begin
      AParams.Add('DriverID=ODBC');
      LValue := Get(['Dsn']);
      Put('DataSource', LValue);
      LHost := Get(['Driver']);
      Put('ODBCDriver', LHost);
      Put('Database', Get(['Database']));
      PutUserAndPassword(['Uid', 'UserID', 'User', 'Username']);
      Result := (LValue <> '') or (LHost <> '');
    end;
    // OLE DB and other providers: no clear translation, only the driver
  finally
    LPairs.Free;
  end;
end;

procedure RpDotNetDelphiLines(AParams, ALines: TStrings);
var
  I: Integer;
  LName, LValue, LDriver: string;
begin
  ALines.Clear;
  LDriver := Trim(AParams.Values['DriverName']);
  if LDriver <> '' then
    ALines.Add(RP_DOTNET_DELPHI_PREFIX + 'DriverName=' + LDriver);
  for I := 0 to AParams.Count - 1 do
  begin
    LName := Trim(AParams.Names[I]);
    if (LName = '') or SameText(LName, 'DriverName') then
      Continue;
    // A Delphi.* key without its prefix (never nested)
    if StartsText(RP_DOTNET_DELPHI_PREFIX, LName) then
      LName := Copy(LName, Length(RP_DOTNET_DELPHI_PREFIX) + 1, MaxInt);
    if (LName = '') or (Pos('=', LName) > 0) then
      Continue;
    LValue := AParams.ValueFromIndex[I];
    // One line per value
    LValue := StringReplace(StringReplace(LValue, #13, ' ', [rfReplaceAll]),
      #10, ' ', [rfReplaceAll]);
    if Trim(LValue) = '' then
      Continue;
    // The password is the one of the connection (Secret.*): never a
    // Delphi.* key, never in clear
    if RpIsPasswordParamName(LName) or StartsText(RP_DOTNET_SECRET_PREFIX, LName) then
      Continue;
    ALines.Add(RP_DOTNET_DELPHI_PREFIX + LName + '=' + LValue);
  end;
end;

{ The dialogs }

procedure RpDotNetDelphiDrivers(ADrivers: TCustomIniFile;
  const ACurrent: string; AList: TStrings);

  procedure AddName(const AName: string);
  var
    I: Integer;
  begin
    if Trim(AName) = '' then
      Exit;
    for I := 0 to AList.Count - 1 do
      if SameText(AList[I], Trim(AName)) then
        Exit;
    AList.Add(Trim(AName));
  end;

{$IFNDEF FPC}
var
  LInstalled: TStringList;
  I: Integer;
{$ENDIF}
begin
  AList.Clear;
  if not RpIsDotNetDriverName(ACurrent) then
    AddName(ACurrent);
  AddName(RP_DOTNET_PROPOSED_DRIVER);
  AddName('ZeosLib');
{$IFNDEF FPC}
  // IBX and the dbExpress drivers of the drivers file
  AddName('Interbase');
  if ADrivers = nil then
    Exit;
  LInstalled := TStringList.Create;
  try
    ADrivers.ReadSection('Installed Drivers', LInstalled);
    for I := 0 to LInstalled.Count - 1 do
      if not (SameText(LInstalled[I], 'Reportman AI Agent') or
        SameText(LInstalled[I], 'DBXTrace') or SameText(LInstalled[I], 'DBXPool') or
        SameText(LInstalled[I], 'DataSnap') or RpIsDotNetDriverName(LInstalled[I])) then
        AddName(LInstalled[I]);
  finally
    LInstalled.Free;
  end;
{$ENDIF}
end;

procedure RpDotNetDriverParams(ADrivers: TCustomIniFile;
  const ADriverName: string; ACurrent, AResult: TStrings);
var
  LDefaults: TStringList;
  I, J: Integer;
  LName, LValue: string;
begin
  AResult.Clear;
  if SameText(Trim(ADriverName), RP_DOTNET_PROPOSED_DRIVER) or (ADrivers = nil) or
    (not ADrivers.SectionExists(Trim(ADriverName))) then
  begin
    for I := 0 to ACurrent.Count - 1 do
      if (Trim(ACurrent.Names[I]) <> '') and not SameText(Trim(ACurrent.Names[I]), 'DriverName') then
        AResult.Add(ACurrent[I]);
    Exit;
  end;
  LDefaults := TStringList.Create;
  try
    ADrivers.ReadSectionValues(Trim(ADriverName), LDefaults);
    for I := 0 to LDefaults.Count - 1 do
    begin
      LName := Trim(LDefaults.Names[I]);
      if (LName = '') or SameText(LName, 'DriverName') or SameText(LName, 'GetDriverFunc') or
        SameText(LName, 'VendorLib') or SameText(LName, 'LibraryName') or
        SameText(LName, 'VendorLibWin64') or SameText(LName, 'VendorLibOsx') or
        SameText(LName, 'LibraryNameOsx') or SameText(LName, 'DriverUnit') or
        SameText(LName, 'DriverPackageLoader') or SameText(LName, 'DriverAssemblyLoader') or
        SameText(LName, 'MetaDataPackageLoader') or SameText(LName, 'MetaDataAssemblyLoader') or
        SameText(LName, 'DisplayDriverName') then
        Continue;
      LValue := LDefaults.ValueFromIndex[I];
      for J := 0 to ACurrent.Count - 1 do
        if SameText(Trim(ACurrent.Names[J]), LName) and (Trim(ACurrent.ValueFromIndex[J]) <> '') then
        begin
          LValue := ACurrent.ValueFromIndex[J];
          Break;
        end;
      AResult.Add(LName + '=' + LValue);
    end;
  finally
    LDefaults.Free;
  end;
end;

function RpDotNetParamsText(AParams: TStrings): string;
var
  I: Integer;
  LName: string;
begin
  Result := '';
  for I := 0 to AParams.Count - 1 do
  begin
    LName := Trim(AParams.Names[I]);
    if LName = '' then
      Continue;
    if Result <> '' then
      Result := Result + sLineBreak;
    if RpIsPasswordParamName(LName) then
    begin
      if AParams.ValueFromIndex[I] <> '' then
        Result := Result + LName + '=********'
      else
        Result := Result + LName + '=';
    end
    else
      Result := Result + LName + '=' + AParams.ValueFromIndex[I];
  end;
end;

function RpDotNetSetupText(const AAlias, ADescription: string): string;
begin
  Result := Format(string(TranslateStr(2071, 'Connection of this computer: %s')),
    [ADescription]) + sLineBreak + Format(SRpDotNetSetupInfo, [AAlias]);
end;

{ The snapshot }

constructor TRpIniSnapshot.Create;
begin
  inherited Create;
  FSections := TStringList.Create;
end;

destructor TRpIniSnapshot.Destroy;
begin
  Clear;
  FSections.Free;
  inherited Destroy;
end;

procedure TRpIniSnapshot.Clear;
var
  I: Integer;
begin
  for I := 0 to FSections.Count - 1 do
    FSections.Objects[I].Free;
  FSections.Clear;
end;

function TRpIniSnapshot.GetCount: Integer;
begin
  Result := FSections.Count;
end;

function TRpIniSnapshot.GetName(AIndex: Integer): string;
begin
  Result := FSections[AIndex];
end;

function TRpIniSnapshot.GetValues(AIndex: Integer): TStrings;
begin
  Result := TStrings(FSections.Objects[AIndex]);
end;

function TRpIniSnapshot.IndexOf(const ASection: string): Integer;
begin
  Result := FSections.IndexOf(ASection);
end;

procedure TRpIniSnapshot.Assign(AIni: TCustomIniFile);
var
  LSections, LKeys, LValues: TStringList;
  I, J: Integer;
begin
  Clear;
  if AIni = nil then
    Exit;
  LSections := TStringList.Create;
  LKeys := TStringList.Create;
  try
    AIni.ReadSections(LSections);
    for I := 0 to LSections.Count - 1 do
    begin
      // A repeated section: the ini reads the first one
      if FSections.IndexOf(LSections[I]) >= 0 then
        Continue;
      LValues := TStringList.Create;
      FSections.AddObject(LSections[I], LValues);
      AIni.ReadSection(LSections[I], LKeys);
      for J := 0 to LKeys.Count - 1 do
        if (Trim(LKeys[J]) <> '') and (LValues.IndexOfName(Trim(LKeys[J])) < 0) then
          LValues.Add(Trim(LKeys[J]) + '=' + AIni.ReadString(LSections[I], LKeys[J], ''));
    end;
  finally
    LKeys.Free;
    LSections.Free;
  end;
end;

{ The encoding }

function RpIniHasBom(const AFileName: string): Boolean;
var
  LStream: TFileStream;
  LBom: array[0..2] of Byte;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    Result := (LStream.Read(LBom, 3) = 3) and (LBom[0] = $EF) and (LBom[1] = $BB) and
      (LBom[2] = $BF);
  finally
    LStream.Free;
  end;
end;

function RpIniFileEncoding(const AFileName: string; out AOwned: Boolean): TEncoding;
begin
  AOwned := False;
  if RpIniHasBom(AFileName) then
    Exit(TEncoding.UTF8);
{$IFDEF MSWINDOWS}
{$IFDEF FPC}
  // TEncoding.ANSI of FPC is the code page of the strings (UTF-8 in
  // Lazarus): the one of the system is GetACP
  Result := TEncoding.GetEncoding(Integer(RpGetACP));
  AOwned := True;
{$ELSE}
  Result := TEncoding.ANSI;
{$ENDIF}
{$ELSE}
  Result := TEncoding.UTF8;
{$ENDIF}
end;

function RpCreateConnectionsIni(const AFileName: string): TMemIniFile;
var
  LEncoding: TEncoding;
  LOwned: Boolean;
begin
  LEncoding := RpIniFileEncoding(AFileName, LOwned);
{$IFDEF FPC}
  // The ini frees an encoding that is not a standard one
  Result := TMemIniFile.Create(AFileName, LEncoding, LOwned, []);
{$ELSE}
  Result := TMemIniFile.Create(AFileName, LEncoding);
  Result.CaseSensitive := False;
{$ENDIF}
end;

procedure RpFreeConnectionsIni(var AIni: TMemIniFile);
begin
  if AIni = nil then
    Exit;
{$IFDEF FPC}
  // Without a file name its UpdateFile of Destroy writes nothing
  AIni.Rename('', False);
{$ENDIF}
  FreeAndNil(AIni);
end;

{ The file }

type
  TRpIniLine = record
    // The line without its line break, as it is in the file
    Text: TBytes;
    // Its line break (empty: the last line of a file that does not end
    // with one)
    Brk: TBytes;
  end;

  // The connections file as it is on disk, line by line: what does not
  // change is written back byte for byte
  TRpIniDocument = class(TObject)
  private
    FLines: array of TRpIniLine;
    FCount: Integer;
    FBom: Boolean;
    FUtf8: Boolean;
    FFinalBreak: Boolean;
    FBreak: TBytes;
    FModified: Boolean;
    FAnsi: TEncoding;
    FOwnsAnsi: Boolean;
    function LineText(AIndex: Integer): string;
    function Encode(const AText: string): TBytes;
    procedure InsertLine(AIndex: Integer; const AText: string);
    procedure DeleteLine(AIndex: Integer);
    function IsBlank(AIndex: Integer): Boolean;
    function KeyOf(AIndex: Integer; out AKey, AValue: string): Boolean;
    function SectionAt(AIndex: Integer; out AName: string): Boolean;
    function FindSection(const AName: string): Integer;
    function SectionEnd(AStart: Integer): Integer;
    function LastKeyLine(AStart: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    procedure AddSection(const ASection: string);
    procedure SetValue(const ASection, AKey, AValue: string);
    procedure DeleteKey(const ASection, AKey: string);
    procedure DeleteSection(const ASection: string);
    property Modified: Boolean read FModified;
  end;

constructor TRpIniDocument.Create;
begin
  inherited Create;
{$IFDEF MSWINDOWS}
{$IFDEF FPC}
  FAnsi := TEncoding.GetEncoding(Integer(RpGetACP));
  FOwnsAnsi := True;
{$ELSE}
  FAnsi := TEncoding.ANSI;
{$ENDIF}
{$ENDIF}
end;

destructor TRpIniDocument.Destroy;
begin
  if FOwnsAnsi then
    FAnsi.Free;
  inherited Destroy;
end;

procedure TRpIniDocument.LoadFromFile(const AFileName: string);
var
  LStream: TFileStream;
  LData: TBytes;
  I, LStart, LFirst, LEnd: Integer;
  LLine: TRpIniLine;
  LCrLf, LFound: Boolean;
begin
  FCount := 0;
  SetLength(FLines, 0);
  FModified := False;
  FBom := False;
  FFinalBreak := True;
  LData := nil;
  if FileExists(AFileName) then
  begin
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(LData, LStream.Size);
      if Length(LData) > 0 then
        LStream.ReadBuffer(LData[0], Length(LData));
    finally
      LStream.Free;
    end;
  end;
  LFirst := 0;
  if (Length(LData) >= 3) and (LData[0] = $EF) and (LData[1] = $BB) and (LData[2] = $BF) then
  begin
    FBom := True;
    LFirst := 3;
  end;
  // The rule: UTF-8 with a BOM; without it, ANSI in Windows, UTF-8 elsewhere
{$IFDEF MSWINDOWS}
  FUtf8 := FBom;
{$ELSE}
  FUtf8 := True;
{$ENDIF}
  // The line break of the file (the one of the system for a new file)
  LFound := False;
  LCrLf := False;
  for I := LFirst to Length(LData) - 1 do
    if LData[I] = 10 then
    begin
      LCrLf := (I > LFirst) and (LData[I - 1] = 13);
      LFound := True;
      Break;
    end;
  if not LFound then
{$IFDEF MSWINDOWS}
    LCrLf := True;
{$ELSE}
    LCrLf := False;
{$ENDIF}
  if LCrLf then
  begin
    SetLength(FBreak, 2);
    FBreak[0] := 13;
    FBreak[1] := 10;
  end
  else
  begin
    SetLength(FBreak, 1);
    FBreak[0] := 10;
  end;
  LStart := LFirst;
  I := LFirst;
  while I < Length(LData) do
  begin
    if LData[I] = 10 then
    begin
      LEnd := I;
      if (LEnd > LStart) and (LData[LEnd - 1] = 13) then
      begin
        Dec(LEnd);
        LLine.Brk := Copy(LData, LEnd, 2);
      end
      else
        LLine.Brk := Copy(LData, I, 1);
      LLine.Text := Copy(LData, LStart, LEnd - LStart);
      if FCount >= Length(FLines) then
        SetLength(FLines, FCount * 2 + 16);
      FLines[FCount] := LLine;
      Inc(FCount);
      LStart := I + 1;
    end;
    Inc(I);
  end;
  if LStart < Length(LData) then
  begin
    // The last line, without a line break
    LLine.Text := Copy(LData, LStart, Length(LData) - LStart);
    LLine.Brk := nil;
    if FCount >= Length(FLines) then
      SetLength(FLines, FCount + 1);
    FLines[FCount] := LLine;
    Inc(FCount);
    FFinalBreak := False;
  end;
end;

procedure TRpIniDocument.SaveToFile(const AFileName: string);
var
  LStream: TFileStream;
  LTemp, LDir: string;
  I: Integer;
  LBreak: TBytes;
  LBom: array[0..2] of Byte;
begin
  LDir := ExtractFileDir(ExpandFileName(AFileName));
  if (LDir <> '') and not DirectoryExists(LDir) then
    ForceDirectories(LDir);
  // Written next to it and moved over it: the file is never half written
  LTemp := AFileName + '.tmp';
  LStream := TFileStream.Create(LTemp, fmCreate);
  try
    if FBom then
    begin
      LBom[0] := $EF;
      LBom[1] := $BB;
      LBom[2] := $BF;
      LStream.WriteBuffer(LBom, 3);
    end;
    for I := 0 to FCount - 1 do
    begin
      if Length(FLines[I].Text) > 0 then
        LStream.WriteBuffer(FLines[I].Text[0], Length(FLines[I].Text));
      // Every line but the last one has its break; the last one, only when
      // the file ended with one
      LBreak := FLines[I].Brk;
      if (I < FCount - 1) or FFinalBreak then
      begin
        if Length(LBreak) = 0 then
          LBreak := FBreak;
      end
      else
        LBreak := nil;
      if Length(LBreak) > 0 then
        LStream.WriteBuffer(LBreak[0], Length(LBreak));
    end;
  finally
    LStream.Free;
  end;
{$IFDEF MSWINDOWS}
  if not RpMoveFileEx(PWideChar(UnicodeString(LTemp)),
    PWideChar(UnicodeString(AFileName)),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
  begin
    DeleteFile(LTemp);
    RaiseLastOSError;
  end;
{$ELSE}
  if not RenameFile(LTemp, AFileName) then
    RaiseLastOSError;
{$ENDIF}
  FModified := False;
end;

function TRpIniDocument.LineText(AIndex: Integer): string;
begin
  if FUtf8 or (FAnsi = nil) then
    Result := Utf8Text(FLines[AIndex].Text, 0, Length(FLines[AIndex].Text))
  else
    Result := FAnsi.GetString(FLines[AIndex].Text);
end;

function TRpIniDocument.Encode(const AText: string): TBytes;
begin
  if FUtf8 or (FAnsi = nil) then
    Result := Utf8Bytes(AText)
  else
    Result := FAnsi.GetBytes(UnicodeString(AText));
end;

procedure TRpIniDocument.InsertLine(AIndex: Integer; const AText: string);
var
  I: Integer;
begin
  if FCount >= Length(FLines) then
    SetLength(FLines, FCount * 2 + 16);
  // A line after the last one: the last one gets its break
  if (AIndex = FCount) and (FCount > 0) and (Length(FLines[FCount - 1].Brk) = 0) then
    FLines[FCount - 1].Brk := FBreak;
  for I := FCount downto AIndex + 1 do
    FLines[I] := FLines[I - 1];
  FLines[AIndex].Text := Encode(AText);
  FLines[AIndex].Brk := FBreak;
  Inc(FCount);
  FModified := True;
end;

procedure TRpIniDocument.DeleteLine(AIndex: Integer);
var
  I: Integer;
begin
  for I := AIndex to FCount - 2 do
    FLines[I] := FLines[I + 1];
  Dec(FCount);
  FModified := True;
end;

function TRpIniDocument.IsBlank(AIndex: Integer): Boolean;
begin
  Result := Trim(LineText(AIndex)) = '';
end;

function TRpIniDocument.KeyOf(AIndex: Integer; out AKey, AValue: string): Boolean;
var
  LText: string;
  P: Integer;
begin
  Result := False;
  AKey := '';
  AValue := '';
  LText := Trim(LineText(AIndex));
  if (LText = '') or (LText[1] = ';') or (LText[1] = '#') or (LText[1] = '[') then
    Exit;
  P := Pos('=', LText);
  if P <= 1 then
    Exit;
  AKey := Trim(Copy(LText, 1, P - 1));
  AValue := Trim(Copy(LText, P + 1, MaxInt));
  Result := AKey <> '';
end;

function TRpIniDocument.SectionAt(AIndex: Integer; out AName: string): Boolean;
var
  LText: string;
begin
  LText := Trim(LineText(AIndex));
  Result := (Length(LText) >= 2) and (LText[1] = '[') and (LText[Length(LText)] = ']');
  if Result then
    AName := Trim(Copy(LText, 2, Length(LText) - 2))
  else
    AName := '';
end;

function TRpIniDocument.FindSection(const AName: string): Integer;
var
  I: Integer;
  LName: string;
begin
  for I := 0 to FCount - 1 do
    if SectionAt(I, LName) and SameText(LName, Trim(AName)) then
      Exit(I);
  Result := -1;
end;

function TRpIniDocument.SectionEnd(AStart: Integer): Integer;
var
  LName: string;
begin
  Result := AStart + 1;
  while (Result < FCount) and not SectionAt(Result, LName) do
    Inc(Result);
end;

function TRpIniDocument.LastKeyLine(AStart: Integer): Integer;
var
  I: Integer;
  LKey, LValue: string;
begin
  Result := AStart;
  for I := AStart + 1 to SectionEnd(AStart) - 1 do
    if KeyOf(I, LKey, LValue) then
      Result := I;
end;

procedure TRpIniDocument.AddSection(const ASection: string);
begin
  if FindSection(ASection) >= 0 then
    Exit;
  // At the end, after a blank line
  if (FCount > 0) and not IsBlank(FCount - 1) then
    InsertLine(FCount, '');
  InsertLine(FCount, '[' + Trim(ASection) + ']');
end;

procedure TRpIniDocument.SetValue(const ASection, AKey, AValue: string);
var
  LStart, I: Integer;
  LKey, LValue: string;
begin
  LStart := FindSection(ASection);
  if LStart < 0 then
  begin
    AddSection(ASection);
    InsertLine(FCount, Trim(AKey) + '=' + AValue);
    Exit;
  end;
  // Its line, where it is (the key as the file has it)
  for I := LStart + 1 to SectionEnd(LStart) - 1 do
    if KeyOf(I, LKey, LValue) and SameText(LKey, Trim(AKey)) then
    begin
      if LValue <> Trim(AValue) then
      begin
        FLines[I].Text := Encode(LKey + '=' + AValue);
        FModified := True;
      end;
      Exit;
    end;
  // A new key, after the last one of its section
  InsertLine(LastKeyLine(LStart) + 1, Trim(AKey) + '=' + AValue);
end;

procedure TRpIniDocument.DeleteKey(const ASection, AKey: string);
var
  LStart, I: Integer;
  LKey, LValue: string;
begin
  LStart := FindSection(ASection);
  if LStart < 0 then
    Exit;
  // Its lines (a key repeated would come back when the file is read again)
  for I := SectionEnd(LStart) - 1 downto LStart + 1 do
    if KeyOf(I, LKey, LValue) and SameText(LKey, Trim(AKey)) then
      DeleteLine(I);
end;

procedure TRpIniDocument.DeleteSection(const ASection: string);
var
  LStart, LLast, I: Integer;
begin
  LStart := FindSection(ASection);
  while LStart >= 0 do
  begin
    // From its header to its last key: the comments and blank lines after
    // it are the ones of what follows
    LLast := LastKeyLine(LStart);
    for I := LLast downto LStart do
      DeleteLine(I);
    // The blank lines that separated it, when there is one before it
    if (LStart = 0) or IsBlank(LStart - 1) then
      while (LStart < FCount) and IsBlank(LStart) do
        DeleteLine(LStart);
    // A repeated section too
    LStart := FindSection(ASection);
  end;
end;

procedure RpIniSaveChanges(const AFileName: string; ASnapshot: TRpIniSnapshot;
  AIni: TCustomIniFile);
var
  LNow: TRpIniSnapshot;
  LDoc: TRpIniDocument;
  LBefore, LAfter: TStrings;
  I, J, K, LIndex: Integer;
  LKey: string;
begin
  if Trim(AFileName) = '' then
    Exit;
  LNow := TRpIniSnapshot.Create;
  LDoc := TRpIniDocument.Create;
  try
    LNow.Assign(AIni);
    // The file as it is now (another program may have written it)
    LDoc.LoadFromFile(AFileName);
    for I := 0 to LNow.Count - 1 do
    begin
      LAfter := LNow.Values[I];
      J := -1;
      if ASnapshot <> nil then
        J := ASnapshot.IndexOf(LNow.Names[I]);
      LBefore := nil;
      if J >= 0 then
        LBefore := ASnapshot.Values[J]
      else
        // A new section, also one without keys
        LDoc.AddSection(LNow.Names[I]);
      // The keys new or changed
      for K := 0 to LAfter.Count - 1 do
      begin
        LKey := LAfter.Names[K];
        if LKey = '' then
          Continue;
        LIndex := -1;
        if LBefore <> nil then
          LIndex := LBefore.IndexOfName(LKey);
        if (LIndex < 0) or (LBefore.ValueFromIndex[LIndex] <> LAfter.ValueFromIndex[K]) then
          LDoc.SetValue(LNow.Names[I], LKey, LAfter.ValueFromIndex[K]);
      end;
      // The keys deleted
      if LBefore <> nil then
        for K := 0 to LBefore.Count - 1 do
          if (LBefore.Names[K] <> '') and (LAfter.IndexOfName(LBefore.Names[K]) < 0) then
            LDoc.DeleteKey(LNow.Names[I], LBefore.Names[K]);
    end;
    // The sections deleted
    if ASnapshot <> nil then
      for J := 0 to ASnapshot.Count - 1 do
        if LNow.IndexOf(ASnapshot.Names[J]) < 0 then
          LDoc.DeleteSection(ASnapshot.Names[J]);
    if LDoc.Modified then
      LDoc.SaveToFile(AFileName);
  finally
    LDoc.Free;
    LNow.Free;
  end;
end;

end.

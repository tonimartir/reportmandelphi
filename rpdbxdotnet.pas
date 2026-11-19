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
  lines) stays as it was (RpDotNetWriteDelphiKeys, RpDotNetWriteKey), as the
  .NET writer does.

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
// (TMemIniFile.ReadSectionValues, the values through RpDotNetIniText)

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

// Replaces the Delphi.* keys of the section AAlias of the file with ALines
// (Delphi.<Name>=<Value>, UTF-8), where the first of them was or after the
// last line of the section. The rest of the file does not change, byte for
// byte. Raises when the file or the section are not there
procedure RpDotNetWriteDelphiKeys(const AFileName, AAlias: string;
  ALines: TStrings);
// Writes AKey=AValue in the section AAlias: its line is replaced where it
// is, or it goes before the Delphi.* keys (after the last line of the
// section when there are none). Nothing else of the file changes
procedure RpDotNetWriteKey(const AFileName, AAlias, AKey, AValue: string);

// A value of an ADO.NET section as read by a TMemIniFile: .NET writes the
// file in UTF-8 and Delphi reads it as ANSI (two characters for each accented
// letter): the UTF-8 bytes are read again; a value read right stays; the FPC
// engine reads it as it is
function RpDotNetIniText(const AValue: string): string;
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

function IsValidUtf8(const B: TBytes; AStart, ACount: Integer): Boolean;
var
  I, LEnd, LMore, J: Integer;
  C: Byte;
begin
  Result := False;
  I := AStart;
  LEnd := AStart + ACount;
  while I < LEnd do
  begin
    C := B[I];
    if C < $80 then
      LMore := 0
    else if (C and $E0) = $C0 then
    begin
      if C < $C2 then
        Exit;
      LMore := 1;
    end
    else if (C and $F0) = $E0 then
      LMore := 2
    else if (C and $F8) = $F0 then
    begin
      if C > $F4 then
        Exit;
      LMore := 3;
    end
    else
      Exit;
    for J := 1 to LMore do
      if (I + J >= LEnd) or ((B[I + J] and $C0) <> $80) then
        Exit;
    Inc(I, LMore + 1);
  end;
  Result := True;
end;

function RpDotNetIniText(const AValue: string): string;
{$IFNDEF FPC}
var
  I: Integer;
  LHigh: Boolean;
  LBytes: TBytes;
{$ENDIF}
begin
  Result := AValue;
{$IFNDEF FPC}
  LHigh := False;
  for I := 1 to Length(AValue) do
    if Ord(AValue[I]) > 127 then
    begin
      LHigh := True;
      Break;
    end;
  if not LHigh then
    Exit;
  // Only when the text is the ANSI reading of UTF-8 bytes: a value that
  // was read right (or written by Delphi) does not go back to the same text
  LBytes := TEncoding.ANSI.GetBytes(AValue);
  if TEncoding.ANSI.GetString(LBytes) <> AValue then
    Exit;
  if IsValidUtf8(LBytes, 0, Length(LBytes)) then
    Result := TEncoding.UTF8.GetString(LBytes);
{$ENDIF}
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

{ The file }

type
  TRpRawLines = array of TBytes;

// The lines of the file, each one with its line break (the last one may
// have none)
function SplitRawLines(const AData: TBytes): TRpRawLines;
var
  I, LStart, LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  LStart := 0;
  for I := 0 to Length(AData) - 1 do
    if AData[I] = 10 then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := Copy(AData, LStart, I - LStart + 1);
      Inc(LCount);
      LStart := I + 1;
    end;
  if LStart < Length(AData) then
  begin
    SetLength(Result, LCount + 1);
    Result[LCount] := Copy(AData, LStart, Length(AData) - LStart);
  end;
end;

// The text of a line without its line break and blanks around it (UTF-8
// when it is valid, the code page of the system otherwise)
function RawLineText(const ALine: TBytes; ASkipBom: Boolean): string;
var
  LStart, LEnd: Integer;
{$IFNDEF FPC}
  LAnsi: TBytes;
{$ENDIF}
begin
  LStart := 0;
  LEnd := Length(ALine);
  if ASkipBom and (LEnd >= 3) and (ALine[0] = $EF) and (ALine[1] = $BB) and
    (ALine[2] = $BF) then
    LStart := 3;
  while (LEnd > LStart) and (ALine[LEnd - 1] in [10, 13]) do
    Dec(LEnd);
  if IsValidUtf8(ALine, LStart, LEnd - LStart) then
    Result := Utf8Text(ALine, LStart, LEnd - LStart)
  else
  begin
{$IFDEF FPC}
    Result := Utf8Text(ALine, LStart, LEnd - LStart);
{$ELSE}
    LAnsi := Copy(ALine, LStart, LEnd - LStart);
    Result := TEncoding.ANSI.GetString(LAnsi);
{$ENDIF}
  end;
  Result := Trim(Result);
end;

function IsSectionLine(const AText: string; out AName: string): Boolean;
begin
  Result := (Length(AText) >= 2) and (AText[1] = '[') and (AText[Length(AText)] = ']');
  if Result then
    AName := Trim(Copy(AText, 2, Length(AText) - 2))
  else
    AName := '';
end;

function HasLineBreak(const ALine: TBytes): Boolean;
begin
  Result := (Length(ALine) > 0) and (ALine[Length(ALine) - 1] = 10);
end;

// A key line of the section that ReplaceSectionKeys replaces: the key AKey
// (AExact) or one that starts with it
function IsKeyLine(const AText, AKey: string; AExact: Boolean): Boolean;
var
  LKey: string;
begin
  Result := False;
  if (Pos('=', AText) <= 1) or (AText[1] = ';') or (AText[1] = '#') then
    Exit;
  LKey := Trim(Copy(AText, 1, Pos('=', AText) - 1));
  if AExact then
    Result := SameText(LKey, AKey)
  else
    Result := StartsText(AKey, LKey);
end;

// Replaces the lines of the key AKey (AExact) or of the keys that start with
// it in the section AAlias with ALines: where the first of them was,
// otherwise (a key) before the Delphi.* keys, otherwise after the last line
// of the section. Every other byte of the file stays
procedure ReplaceSectionKeys(const AFileName, AAlias, AKey: string;
  AExact: Boolean; ALines: TStrings);
var
  LStream: TFileStream;
  LData, LBreak, LBytes: TBytes;
  LLines, LResult: TRpRawLines;
  I, J, LCount, LStart, LEnd, LLastContent, LInsertAt: Integer;
  LText, LName, LTemp: string;
  LFound, LCrLf: Boolean;
  LNewLines: TRpRawLines;

  procedure AddResult(const ALine: TBytes);
  begin
    SetLength(LResult, LCount + 1);
    LResult[LCount] := ALine;
    Inc(LCount);
  end;

begin
  if not FileExists(AFileName) then
    raise Exception.CreateFmt(SRpDotNetNotFound, [AAlias, AFileName]);
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LData, LStream.Size);
    if Length(LData) > 0 then
      LStream.ReadBuffer(LData[0], Length(LData));
  finally
    LStream.Free;
  end;
  LLines := SplitRawLines(LData);
  // The line break of the file (CRLF from the designers and .NET on Windows)
  LCrLf := False;
  LFound := False;
  for I := 0 to Length(LData) - 1 do
    if LData[I] = 10 then
    begin
      LCrLf := (I > 0) and (LData[I - 1] = 13);
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
    SetLength(LBreak, 2);
    LBreak[0] := 13;
    LBreak[1] := 10;
  end
  else
  begin
    SetLength(LBreak, 1);
    LBreak[0] := 10;
  end;
  // The section: from its [ALIAS] to the next section
  LStart := -1;
  LEnd := Length(LLines);
  for I := 0 to Length(LLines) - 1 do
  begin
    LText := RawLineText(LLines[I], I = 0);
    if IsSectionLine(LText, LName) then
    begin
      if LStart >= 0 then
      begin
        LEnd := I;
        Break;
      end;
      if SameText(LName, Trim(AAlias)) then
        LStart := I;
    end;
  end;
  if LStart < 0 then
    raise Exception.CreateFmt(SRpDotNetNotFound, [AAlias, AFileName]);
  // Its last line with something: the blank lines after it are not its own
  LLastContent := LStart;
  for I := LStart + 1 to LEnd - 1 do
    if RawLineText(LLines[I], False) <> '' then
      LLastContent := I;
  // The new lines, UTF-8 (the encoding of the .NET writer)
  SetLength(LNewLines, ALines.Count);
  for I := 0 to ALines.Count - 1 do
  begin
    LBytes := Utf8Bytes(ALines[I]);
    J := Length(LBytes);
    SetLength(LBytes, J + Length(LBreak));
    Move(LBreak[0], LBytes[J], Length(LBreak));
    LNewLines[I] := LBytes;
  end;
  // Where the first line replaced was; a key without line goes before the
  // Delphi.* keys; otherwise after the last line of the section
  LInsertAt := -1;
  for I := LStart + 1 to LEnd - 1 do
    if IsKeyLine(RawLineText(LLines[I], False), AKey, AExact) then
    begin
      LInsertAt := I;
      Break;
    end;
  if (LInsertAt < 0) and AExact then
    for I := LStart + 1 to LEnd - 1 do
      if IsKeyLine(RawLineText(LLines[I], False), RP_DOTNET_DELPHI_PREFIX, False) then
      begin
        LInsertAt := I;
        Break;
      end;
  if LInsertAt < 0 then
    LInsertAt := LLastContent + 1;
  LCount := 0;
  SetLength(LResult, 0);
  for I := 0 to Length(LLines) - 1 do
  begin
    if I = LInsertAt then
      for J := 0 to Length(LNewLines) - 1 do
        AddResult(LNewLines[J]);
    if (I > LStart) and (I < LEnd) and
      IsKeyLine(RawLineText(LLines[I], False), AKey, AExact) then
      Continue;
    // The last line of the file without a line break gets one when lines
    // go after it
    if (I = Length(LLines) - 1) and (LInsertAt = Length(LLines)) and
      (Length(LNewLines) > 0) and (not HasLineBreak(LLines[I])) then
    begin
      LBytes := Copy(LLines[I], 0, Length(LLines[I]));
      J := Length(LBytes);
      SetLength(LBytes, J + Length(LBreak));
      Move(LBreak[0], LBytes[J], Length(LBreak));
      AddResult(LBytes);
    end
    else
      AddResult(LLines[I]);
  end;
  if LInsertAt >= Length(LLines) then
    for J := 0 to Length(LNewLines) - 1 do
      AddResult(LNewLines[J]);
  // Written next to it and moved over it: the file is never half written
  LTemp := AFileName + '.tmp';
  LStream := TFileStream.Create(LTemp, fmCreate);
  try
    for I := 0 to LCount - 1 do
      if Length(LResult[I]) > 0 then
        LStream.WriteBuffer(LResult[I][0], Length(LResult[I]));
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
end;

procedure RpDotNetWriteDelphiKeys(const AFileName, AAlias: string;
  ALines: TStrings);
begin
  ReplaceSectionKeys(AFileName, AAlias, RP_DOTNET_DELPHI_PREFIX, False, ALines);
end;

procedure RpDotNetWriteKey(const AFileName, AAlias, AKey, AValue: string);
var
  LLines: TStringList;
begin
  if (Trim(AKey) = '') or (Pos('=', AKey) > 0) then
    raise Exception.Create('Invalid key: ' + AKey);
  LLines := TStringList.Create;
  try
    LLines.Add(Trim(AKey) + '=' + AValue);
    ReplaceSectionKeys(AFileName, AAlias, Trim(AKey), True, LLines);
  finally
    LLines.Free;
  end;
end;

end.

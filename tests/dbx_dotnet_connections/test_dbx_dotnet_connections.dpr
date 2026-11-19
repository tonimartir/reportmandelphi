program test_dbx_dotnet_connections;

{*******************************************************}
{                                                       }
{   The connections of this computer shared with .NET   }
{   (DriverName=ADO.NET in dbxconnections, rpdbxdotnet) }
{   in a temporary connections file, never the real     }
{   one: a Delphi connection, an Agent connection and   }
{   the ones of .NET (SQLite, Firebird with its         }
{   password ciphered by this test, SQL Server,         }
{   PostgreSQL, MySQL, OLE DB).                          }
{                                                       }
{   1. They are listed, marked as shared with .NET.     }
{   2. Their Delphi parameters are proposed from the    }
{      .NET ones (Param.*, ConnectionString).           }
{   3. The password: DPAPI of this user, the same       }
{      format as .NET (a value ciphered by .NET can be  }
{      given with --dotnet-secret).                     }
{   4. Writing the Delphi.* keys leaves every other     }
{      byte of the file as it was; another password    }
{      goes to Secret.Password (the one of every       }
{      program, as the C# designer), in its line.      }
{   5. AddConnection never replaces them; Delete only   }
{      forgets the Delphi parameters.                   }
{   6. Connect asks for the Delphi parameters the first }
{      time (RpDotNetConnectionSetup) and opens the     }
{      SQLite database with them.                        }
{   7. The subschemas are shared by alias               }
{      (dbxschemas\<ALIAS>.json next to the file).      }
{   8. The surgical save (TRpConnAdmin.SaveConfig) of   }
{      a file with comments, blank lines, a repeated    }
{      section and an accented letter, while another    }
{      program writes it: ANSI and UTF-8 with BOM, CRLF }
{      and LF, with and without a final line break.     }
{                                                       }
{   Delphi: build.bat. Lazarus: test_dbx_dotnet_        }
{   connections.lpi (lazbuild). Run:                    }
{                                                       }
{   test_dbx_dotnet_connections [--keep]                }
{     [--dotnet-secret dpapi:... --dotnet-plain text]   }
{                                                       }
{   --keep leaves the temporary folder (its path is     }
{   written). Exit code 0 when every check passes.      }
{                                                       }
{*******************************************************}

{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
{$IFDEF MSWINDOWS}
  // Before SysUtils: its DeleteFile is the one of strings
  Windows,
{$ENDIF}
  LazUTF8, SysUtils, Classes, IniFiles,
{$ELSE}
  System.SysUtils, System.Classes, System.IniFiles, System.IOUtils,
{$ENDIF}
  rpdbxdotnet, rpdatainfo, rplocalschemas;

var
  Failures: Integer;
  Skipped: Integer;
  GFolder: string;
  GIni: string;
  GPassword: string;
  GSecret: string;
  GSetupCalls: Integer;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  if ACondition then
    WriteLn('OK   ', AWhat)
  else
  begin
    WriteLn('FAIL ', AWhat);
    Inc(Failures);
  end;
end;

procedure Skip(const AWhat: string);
begin
  WriteLn('SKIP ', AWhat);
  Inc(Skipped);
end;

// The n with tilde: an accented letter in a path
function NTilde: string;
begin
{$IFDEF FPC}
  Result := #$C3#$B1;
{$ELSE}
  Result := #$00F1;
{$ENDIF}
end;

function ReadBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
      LStream.ReadBuffer(Result[0], Length(Result));
  finally
    LStream.Free;
  end;
end;

procedure WriteUtf8(const AFileName, AText: string);
var
  LStream: TFileStream;
  LText: UTF8String;
begin
  LText := UTF8String(AText);
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(LText) > 0 then
      LStream.WriteBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
end;

// The bytes as text (UTF-8)
function BytesText(const ABytes: TBytes): string;
var
  LText: UTF8String;
begin
  SetLength(LText, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], LText[1], Length(ABytes));
  Result := string(LText);
end;

function SameBytes(const A, B: TBytes): Boolean;
begin
  Result := (Length(A) = Length(B)) and
    ((Length(A) = 0) or CompareMem(@A[0], @B[0], Length(A)));
end;

// The text in the ANSI code page of the system (a connections file without
// a BOM in Windows, the rule of rpdbxdotnet) and back
function AnsiBytes(const AText: string): TBytes;
{$IFDEF FPC}
var
  LEncoding: TEncoding;
begin
  LEncoding := TEncoding.GetEncoding(Integer(GetACP));
  try
    Result := LEncoding.GetBytes(UnicodeString(AText));
  finally
    LEncoding.Free;
  end;
end;
{$ELSE}
begin
  Result := TEncoding.ANSI.GetBytes(AText);
end;
{$ENDIF}

function AnsiText(const ABytes: TBytes): string;
{$IFDEF FPC}
var
  LEncoding: TEncoding;
begin
  LEncoding := TEncoding.GetEncoding(Integer(GetACP));
  try
    Result := string(LEncoding.GetString(ABytes));
  finally
    LEncoding.Free;
  end;
end;
{$ELSE}
begin
  Result := TEncoding.ANSI.GetString(ABytes);
end;
{$ENDIF}

function HasBom(const ABytes: TBytes): Boolean;
begin
  Result := (Length(ABytes) >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and
    (ABytes[2] = $BF);
end;

// A connections file as text by the rule: UTF-8 with its BOM, ANSI without
function FileText(const ABytes: TBytes): string;
begin
  if HasBom(ABytes) then
    Result := BytesText(Copy(ABytes, 3, Length(ABytes) - 3))
  else
    Result := AnsiText(ABytes);
end;

// The bytes of AText in a connections file: UTF-8 with a BOM or ANSI
function FileBytes(const AText: string; ABom: Boolean): TBytes;
var
  LText: UTF8String;
begin
  if not ABom then
    Exit(AnsiBytes(AText));
  LText := UTF8String(AText);
  SetLength(Result, Length(LText) + 3);
  Result[0] := $EF;
  Result[1] := $BB;
  Result[2] := $BF;
  if Length(LText) > 0 then
    Move(LText[1], Result[3], Length(LText));
end;

procedure WriteBytes(const AFileName: string; const ABytes: TBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(ABytes) > 0 then
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
  finally
    LStream.Free;
  end;
end;

// A connections file as Delphi and (by the rule) .NET write it in Windows:
// ANSI, without a BOM
procedure WriteAnsi(const AFileName, AText: string);
begin
  WriteBytes(AFileName, AnsiBytes(AText));
end;

// The file without its lines that start with Delphi. (they must be the only
// difference with the original)
function WithoutDelphiLines(const AText: string): string;
var
  LLines: TStringList;
  I: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    for I := 0 to LLines.Count - 1 do
      if not SameText(Copy(Trim(LLines[I]), 1, 7), 'Delphi.') then
        Result := Result + LLines[I] + #13#10;
  finally
    LLines.Free;
  end;
end;

function CountOf(const ASub, AText: string): Integer;
var
  P: Integer;
  LRest: string;
begin
  Result := 0;
  LRest := AText;
  P := Pos(ASub, LRest);
  while P > 0 do
  begin
    Inc(Result);
    LRest := Copy(LRest, P + Length(ASub), MaxInt);
    P := Pos(ASub, LRest);
  end;
end;

// A TRpConnAdmin of AFileName (never the real file: the global override is
// the file too while it is created)
function NewAdminFor(const AFileName: string): TRpConnAdmin;
var
  LOverride: string;
begin
  LOverride := DBXConnectionsFileOverride;
  DBXConnectionsFileOverride := AFileName;
  try
    Result := TRpConnAdmin.Create;
    Result.DBXConnectionsOverride := AFileName;
    Result.LoadConfig;
  finally
    DBXConnectionsFileOverride := LOverride;
  end;
end;

function NewAdmin: TRpConnAdmin;
begin
  Result := NewAdminFor(GIni);
end;

procedure WriteFixture;
var
  LText, LDb: string;
begin
  LDb := IncludeTrailingPathDelimiter(GFolder) + 'a' + NTilde + 'o' + PathDelim + 'ventas.db';
  LText :=
    '; The shared connections file of a test (never the real one)'#13#10 +
    '[DELPHI_FB]'#13#10 +
    'DriverName=FireDac'#13#10 +
    'DriverID=FB'#13#10 +
    'Database=C:\data\delphi.fdb'#13#10 +
    'User_Name=SYSDBA'#13#10 +
    'Password=masterkey'#13#10 +
    #13#10 +
    '[AGENTE]'#13#10 +
    'DriverName=Reportman AI Agent'#13#10 +
    'ApiKey=key-of-test'#13#10 +
    'HubDatabaseId=42'#13#10 +
    #13#10 +
    '; A connection of the Reportman AI Desktop'#13#10 +
    '[VENTAS]'#13#10 +
    'DriverName=ADO.NET'#13#10 +
    'ProviderFactory=SQLiteCore'#13#10 +
    'Param.DataSource=' + LDb + #13#10 +
    'ConnectionString=Data Source=' + LDb + #13#10 +
    #13#10 +
    '[CONTA]'#13#10 +
    'DriverName=ADO.NET'#13#10 +
    'ProviderFactory=FirebirdSql.Data.FirebirdClient'#13#10 +
    'Param.DataSource=dbserver'#13#10 +
    'Param.Database=C:\datos\conta.fdb'#13#10 +
    'Param.Port=3051'#13#10 +
    'Param.UserID=CONTABLE'#13#10 +
    'Param.Charset=UTF8'#13#10 +
    'Secret.Password=' + GSecret + #13#10 +
    'ConnectionString=data source=dbserver;initial catalog=C:\datos\conta.fdb;port number=3051;user id=CONTABLE;character set=UTF8'#13#10 +
    'Other.Program=kept as it is'#13#10 +
    #13#10 +
    '[SQLSRV]'#13#10 +
    'DriverName=ADO.NET'#13#10 +
    'ProviderFactory=SQLServer'#13#10 +
    'ConnectionString=Data Source=srv\SQLEXPRESS;Initial Catalog=Gestion;Integrated Security=True;Encrypt=False'#13#10 +
    #13#10 +
    '[PGSQL]'#13#10 +
    'DriverName=ADO.NET'#13#10 +
    'ProviderFactory=PostgreSQL'#13#10 +
    'Param.Host=pghost'#13#10 +
    'Param.Port=5433'#13#10 +
    'Param.Database=erp'#13#10 +
    'Param.Username=lector'#13#10 +
    'Param.Password=clear-from-server'#13#10 +
    #13#10 +
    '[MYSQL]'#13#10 +
    'DriverName=ADO.NET'#13#10 +
    'ProviderFactory=MySQLConnector'#13#10 +
    'ConnectionString=Server=myhost;Port=3307;Database=shop;User ID=web;Password="p;w"'#13#10 +
    #13#10 +
    '[ACCESO]'#13#10 +
    'DriverName=ADO.NET'#13#10 +
    'ProviderFactory=System.Data.OleDb'#13#10 +
    'ConnectionString=Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\datos\a.accdb'#13#10;
  WriteAnsi(GIni, LText);
  ForceDirectories(ExtractFilePath(LDb));
end;

{ 1. The lists }

procedure TestLists;
var
  LAdmin: TRpConnAdmin;
  LNames: TStringList;
begin
  LAdmin := NewAdmin;
  LNames := TStringList.Create;
  try
    LAdmin.GetConnectionNames(LNames, '');
    Check((LNames.IndexOf('DELPHI_FB') >= 0) and (LNames.IndexOf('AGENTE') >= 0) and
      (LNames.IndexOf('VENTAS') >= 0) and (LNames.IndexOf('CONTA') >= 0),
      'the Delphi, Agent and .NET connections are listed (' + LNames.CommaText + ')');
    Check(LAdmin.IsDotNetConnection('VENTAS') and LAdmin.IsDotNetConnection('conta') and
      (not LAdmin.IsDotNetConnection('DELPHI_FB')) and (not LAdmin.IsDotNetConnection('AGENTE')) and
      (not LAdmin.IsDotNetConnection('NONE')),
      'only the ADO.NET sections are shared with .NET');
    Check(LAdmin.ConnectionDisplayName('VENTAS') = 'VENTAS (.NET)',
      'a .NET connection is marked in the lists: ' + LAdmin.ConnectionDisplayName('VENTAS'));
    Check(LAdmin.ConnectionDisplayName('DELPHI_FB') = 'DELPHI_FB',
      'a Delphi connection is not marked');
    Check(RpConnectionNameFromDisplay(LAdmin.ConnectionDisplayName('VENTAS')) = 'VENTAS',
      'the name comes back from the mark');
    LAdmin.GetConnectionNames(LNames, 'ADO.NET');
    Check(LNames.CommaText = 'VENTAS,CONTA,SQLSRV,PGSQL,MYSQL,ACCESO',
      'the ADO.NET filter lists the 6 connections of .NET (' + LNames.CommaText + ')');
    LAdmin.GetConnectionNames(LNames, 'FireDac');
    Check((LNames.IndexOf('DELPHI_FB') >= 0) and (LNames.IndexOf('VENTAS') >= 0) and
      (LNames.IndexOf('AGENTE') < 0),
      'the FireDac filter has the .NET ones (their proposed Delphi driver): ' + LNames.CommaText);
    Check(LAdmin.GetDotNetDescription('VENTAS') = 'SQLiteCore: ' +
      IncludeTrailingPathDelimiter(GFolder) + 'a' + NTilde + 'o' + PathDelim + 'ventas.db',
      'the description says the provider and the database: ' + LAdmin.GetDotNetDescription('VENTAS'));
    Check(LAdmin.GetDotNetDescription('CONTA') = 'FirebirdSql.Data.FirebirdClient: dbserver - C:\datos\conta.fdb',
      'the description of the Firebird one: ' + LAdmin.GetDotNetDescription('CONTA'));
  finally
    LNames.Free;
    LAdmin.Free;
  end;
end;

{ 2. The proposed Delphi parameters }

procedure TestProposal;
var
  LAdmin: TRpConnAdmin;
  LParams: TStringList;
  LClear: Boolean;
begin
  LAdmin := NewAdmin;
  LParams := TStringList.Create;
  try
    Check(not LAdmin.DotNetHasDelphiParams('VENTAS'), 'VENTAS has no Delphi parameters yet');
    LAdmin.GetConnectionParams('VENTAS', LParams);
    Check((LParams.Values['DriverName'] = 'FireDac') and (LParams.Values['DriverID'] = 'SQLite') and
      (LParams.Values['Database'] = IncludeTrailingPathDelimiter(GFolder) + 'a' + NTilde + 'o' +
      PathDelim + 'ventas.db'),
      'SQLite: FireDAC SQLite with its database, the accented path read as UTF-8 (' +
      LParams.CommaText + ')');
    LClear := LAdmin.GetDotNetProposedParams('CONTA', LParams);
    Check(LClear and (LParams.Values['DriverID'] = 'FB') and (LParams.Values['Server'] = 'dbserver') and
      (LParams.Values['Port'] = '3051') and (LParams.Values['Database'] = 'C:\datos\conta.fdb') and
      (LParams.Values['User_Name'] = 'CONTABLE') and (LParams.Values['CharacterSet'] = 'UTF8'),
      'Firebird: FireDAC FB with server, port, database, user and character set');
    Check(LParams.Values['Password'] = GPassword,
      'Firebird: the password deciphered from Secret.Password (DPAPI of this user)');
    LClear := LAdmin.GetDotNetProposedParams('SQLSRV', LParams);
    Check(LClear and (LParams.Values['DriverID'] = 'MSSQL') and
      (LParams.Values['Server'] = 'srv\SQLEXPRESS') and (LParams.Values['Database'] = 'Gestion') and
      (LParams.Values['OSAuthent'] = 'Yes') and (LParams.IndexOfName('User_Name') < 0),
      'SQL Server from the connection string: server, database, integrated security (' +
      LParams.CommaText + ')');
    LClear := LAdmin.GetDotNetProposedParams('PGSQL', LParams);
    Check(LClear and (LParams.Values['DriverID'] = 'PG') and (LParams.Values['Server'] = 'pghost') and
      (LParams.Values['Port'] = '5433') and (LParams.Values['Database'] = 'erp') and
      (LParams.Values['User_Name'] = 'lector') and (LParams.Values['Password'] = 'clear-from-server'),
      'PostgreSQL: the password in clear of Reportman.Server is read');
    LClear := LAdmin.GetDotNetProposedParams('MYSQL', LParams);
    Check(LClear and (LParams.Values['DriverID'] = 'MySQL') and (LParams.Values['Server'] = 'myhost') and
      (LParams.Values['Port'] = '3307') and (LParams.Values['Database'] = 'shop') and
      (LParams.Values['User_Name'] = 'web') and (LParams.Values['Password'] = 'p;w'),
      'MySQL from a connection string with a quoted value (' + LParams.CommaText + ')');
    LClear := LAdmin.GetDotNetProposedParams('ACCESO', LParams);
    Check((not LClear) and (LParams.Count = 1) and (LParams.Values['DriverName'] = 'FireDac'),
      'OLE DB: no clear translation, only the driver to choose');
    Check(LAdmin.EffectiveDriverName('VENTAS') = 'FireDac', 'the Delphi driver of VENTAS is the proposed one');
    Check(LAdmin.EffectiveDriverName('DELPHI_FB') = 'FireDac', 'a Delphi connection: its DriverName');
  finally
    LParams.Free;
    LAdmin.Free;
  end;
end;

{ 3. DPAPI }

procedure TestDpapi(const ADotNetSecret, ADotNetPlain: string);
var
  LStored, LPlain, LText: string;
begin
  LText := 'Contrase' + NTilde + 'a 1';
  LStored := RpDpapiProtect(LText);
  Check(Copy(LStored, 1, 6) = 'dpapi:', 'a password is ciphered as dpapi:BASE64');
  Check(Pos(LText, LStored) = 0, 'the ciphered value does not have the password');
  Check(RpDpapiUnprotect(LStored, LPlain) and (LPlain = LText),
    'it is deciphered for this user (UTF-8, accents included)');
  Check(not RpDpapiUnprotect('dpapi:AAAA', LPlain), 'a value that is not of this user is not deciphered');
  Check(not RpDpapiUnprotect('plain', LPlain), 'a value without dpapi: is not deciphered');
  if ADotNetSecret <> '' then
    Check(RpDpapiUnprotect(ADotNetSecret, LPlain) and (LPlain = ADotNetPlain),
      'a password ciphered by .NET (ProtectedData, CurrentUser, the same entropy) is deciphered')
  else
    Skip('a password ciphered by .NET: give it with --dotnet-secret and --dotnet-plain');
end;

{ 4 and 5. Writing the Delphi parameters }

// The text with the value of the line Secret.Password=... replaced by a mark
// (to compare two files whose only other difference is that line)
function WithoutSecretValue(const AText: string): string;
var
  LLines: TStringList;
  I: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    for I := 0 to LLines.Count - 1 do
      if SameText(Copy(Trim(LLines[I]), 1, 16), 'Secret.Password=') then
        Result := Result + 'Secret.Password=*'#13#10
      else
        Result := Result + LLines[I] + #13#10;
  finally
    LLines.Free;
  end;
end;

function SecretValueOf(const AText: string): string;
var
  LLines: TStringList;
  I: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    for I := 0 to LLines.Count - 1 do
      if SameText(Copy(Trim(LLines[I]), 1, 16), 'Secret.Password=') then
        Exit(Copy(Trim(LLines[I]), 17, MaxInt));
  finally
    LLines.Free;
  end;
end;

procedure TestWrite;
var
  LAdmin, LAdmin2: TRpConnAdmin;
  LBefore, LAfter, LAgain: TBytes;
  LParams: TStringList;
  LText, LNewSecret, LPlain: string;
  LRaised: Boolean;
  LIni: TMemIniFile;
begin
  LBefore := ReadBytes(GIni);
  LAdmin := NewAdmin;
  LParams := TStringList.Create;
  try
    // 1. The proposed parameters with another user and the same password
    LAdmin.GetConnectionParams('CONTA', LParams);
    LParams.Values['User_Name'] := 'DELPHIUSER';
    LAdmin.SetDotNetDelphiParams('CONTA', LParams);
    LAfter := ReadBytes(GIni);
    LText := FileText(LAfter);
    Check(WithoutDelphiLines(LText) = FileText(LBefore),
      'writing the Delphi.* keys leaves every other byte of the file as it was ' +
      '(the password, the same, is not written again)');
    Check((Pos('[CONTA]'#13#10'DriverName=ADO.NET', LText) > 0) and
      (Pos('Other.Program=kept as it is'#13#10'Delphi.DriverName=FireDac'#13#10, LText) > 0),
      'they go after the last line of the section, before its blank line');
    Check((Pos('Delphi.DriverID=FB'#13#10, LText) > 0) and
      (Pos('Delphi.User_Name=DELPHIUSER'#13#10, LText) > 0) and
      (Pos('Delphi.Database=C:\datos\conta.fdb'#13#10, LText) > 0),
      'the Delphi parameters are in Delphi.* keys');
    Check((Pos('Delphi.Secret', LText) = 0) and (Pos('Delphi.Password', LText) = 0) and
      (Pos(GPassword, LText) = 0),
      'the password is not a Delphi.* key and is never in clear');
    LIni := TMemIniFile.Create(GIni);
    try
      Check((LIni.ReadString('CONTA', 'DriverName', '') = 'ADO.NET') and
        (LIni.ReadString('CONTA', 'ProviderFactory', '') = 'FirebirdSql.Data.FirebirdClient') and
        (LIni.ReadString('CONTA', 'Param.UserID', '') = 'CONTABLE') and
        (LIni.ReadString('CONTA', 'Secret.Password', '') = GSecret) and
        (LIni.ReadString('DELPHI_FB', 'Password', '') = 'masterkey'),
        'DriverName, ProviderFactory, Param.*, Secret.Password and the other sections stay');
    finally
      LIni.Free;
    end;
    // Another program (a new TRpConnAdmin) reads them
    LAdmin2 := NewAdmin;
    try
      Check(LAdmin2.DotNetHasDelphiParams('CONTA'), 'CONTA has its Delphi parameters now');
      LAdmin2.GetConnectionParams('CONTA', LParams);
      Check((LParams.Values['DriverName'] = 'FireDac') and (LParams.Values['User_Name'] = 'DELPHIUSER') and
        (LParams.Values['Password'] = GPassword),
        'they are read back, the password the one of the connection (Secret.Password)');
      // 2. Another password: the one of the connection, in Secret.Password,
      // its line replaced where it is
      LParams.Values['Password'] := GPassword + '-delphi';
      LAdmin2.SetDotNetDelphiParams('CONTA', LParams);
      LText := FileText(ReadBytes(GIni));
      LNewSecret := SecretValueOf(LText);
      Check((LNewSecret <> GSecret) and (Copy(LNewSecret, 1, 6) = 'dpapi:') and
        RpDpapiUnprotect(LNewSecret, LPlain) and (LPlain = GPassword + '-delphi'),
        'another password is written ciphered in Secret.Password (as the C# designer)');
      Check(WithoutSecretValue(WithoutDelphiLines(LText)) = WithoutSecretValue(FileText(LBefore)),
        'only the line of Secret.Password changes, in its place');
      Check((Pos('Param.Charset=UTF8'#13#10'Secret.Password=dpapi:', LText) > 0) and
        (CountOf('Secret.Password=', LText) = 1) and (Pos(GPassword + '-delphi', LText) = 0),
        'one Secret.Password, where it was, never in clear');
      WriteLn('     Secret.Password=', LNewSecret);
      // In memory too, the instance that wrote it
      LAdmin2.GetConnectionParams('CONTA', LParams);
      Check(LParams.Values['Password'] = GPassword + '-delphi',
        'the instance that wrote it reads it without reloading');
      // A second write of the same parameters writes the same file
      LAgain := ReadBytes(GIni);
      LParams.Values['RoleName'] := 'READER';
      LAdmin2.SetDotNetDelphiParams('CONTA', LParams);
      LText := FileText(ReadBytes(GIni));
      Check((WithoutDelphiLines(LText) = WithoutDelphiLines(FileText(LAgain))) and
        (CountOf('Delphi.DriverName=', LText) = 1) and (Pos('Delphi.RoleName=READER', LText) > 0),
        'writing them again replaces them, the rest the same (the password not written again)');
      // 5. Never replaced by AddConnection
      LRaised := False;
      try
        LAdmin2.AddConnection('CONTA', 'FireDac');
      except
        LRaised := True;
      end;
      Check(LRaised and LAdmin2.IsDotNetConnection('CONTA'),
        'AddConnection does not erase a connection shared with .NET');
      // DeleteConnection only forgets the Delphi parameters
      LAdmin2.DeleteConnection('CONTA');
      LText := FileText(ReadBytes(GIni));
      Check((LText = WithoutDelphiLines(LText)) and
        (WithoutSecretValue(LText) = WithoutSecretValue(FileText(LBefore))) and
        (SecretValueOf(LText) = LNewSecret),
        'DeleteConnection forgets the Delphi parameters: the original file, with the password kept');
      Check(LAdmin2.IsDotNetConnection('CONTA') and not LAdmin2.DotNetHasDelphiParams('CONTA'),
        'the connection of .NET stays, without Delphi parameters');
    finally
      LAdmin2.Free;
    end;
  finally
    LParams.Free;
    LAdmin.Free;
  end;
  // The file as it was, for the next tests
  WriteFixture;
  Check(SameBytes(ReadBytes(GIni), LBefore), 'the fixture is written again as it was');
end;

// A password ciphered for another Windows user (here: one this user can not
// read): Delphi asks for it and writes it for this user
procedure TestOtherUserPassword;
var
  LAdmin: TRpConnAdmin;
  LParams: TStringList;
  LText, LPlain: string;
  LBefore: TBytes;
begin
  LBefore := ReadBytes(GIni);
  LText := StringReplace(FileText(LBefore), 'Secret.Password=' + GSecret,
    'Secret.Password=dpapi:AQAAAOtherUser', []);
  WriteAnsi(GIni, LText);
  LAdmin := NewAdmin;
  LParams := TStringList.Create;
  try
    LAdmin.GetConnectionParams('CONTA', LParams);
    Check((LParams.IndexOfName('Password') < 0) and (LParams.Values['User_Name'] = 'CONTABLE'),
      'a password of another Windows user is not proposed (it is asked for)');
    LParams.Values['Password'] := GPassword;
    LAdmin.SetDotNetDelphiParams('CONTA', LParams);
    LText := FileText(ReadBytes(GIni));
    Check(RpDpapiUnprotect(SecretValueOf(LText), LPlain) and (LPlain = GPassword),
      'the password typed is written for this Windows user in Secret.Password');
  finally
    LParams.Free;
    LAdmin.Free;
  end;
  WriteFixture;
end;

{ 8. The surgical save of the connections file }

// What the file has as text, by the rule of its encoding (and whether it
// has its BOM)
function FileNow(const AFileName: string; out ABom: Boolean): string;
var
  LBytes: TBytes;
begin
  LBytes := ReadBytes(AFileName);
  ABom := HasBom(LBytes);
  Result := FileText(LBytes);
end;

// The connections dialog (load, change a key, add a key and a connection,
// delete a key and a connection) while ANOTHER program adds a section and
// changes a key of its own between the load and the save. AVariant: the
// encoding (ABom: UTF-8 with BOM; otherwise ANSI), the line break and
// whether the file ends with one
procedure TestSurgicalSave(const AVariant: string; ABom: Boolean;
  const LB: string; AFinal: Boolean);
var
  LFile, LText, LOther, LExpected, LDb, LNew, LNow, LDelphiDb: string;
  LAdmin, LCheck: TRpConnAdmin;
  LBom: Boolean;
  LParams: TStringList;
  LBefore: TBytes;
begin
  LFile := IncludeTrailingPathDelimiter(GFolder) + 'surgical-' + AVariant + '.ini';
  LDb := 'C:\datos\contabilidad a' + NTilde + 'o.fdb';
  LNew := 'C:\datos\nueva a' + NTilde + 'o.db';
  LText :=
    '; The shared connections file of a test' + LB +
    ';   with two lines of comments' + LB +
    LB +
    '[DELPHI_FB]' + LB +
    'DriverName=FireDac' + LB +
    'DriverID=FB' + LB +
    '; the database of the accounts' + LB +
    'Database=' + LDb + LB +
    'User_Name=SYSDBA' + LB +
    LB +
    '[AGENTE]' + LB +
    'DriverName=Reportman AI Agent' + LB +
    'ApiKey=key-of-test' + LB +
    'HubDatabaseId=42' + LB +
    LB +
    LB +
    '; A connection of the Reportman AI Desktop' + LB +
    '[VENTAS]' + LB +
    'DriverName=ADO.NET' + LB +
    'ProviderFactory=SQLiteCore' + LB +
    'Param.DataSource=C:\datos\ventas.db' + LB +
    'ConnectionString=Data Source=C:\datos\ventas.db' + LB +
    LB +
    '[BORRAR]' + LB +
    'DriverName=FireDac' + LB +
    'DriverID=SQLite' + LB +
    'Database=borrar.db' + LB +
    LB +
    '; A repeated section: the ini reads only the first one' + LB +
    '[AGENTE]' + LB +
    'Repeated=kept';
  if AFinal then
    LText := LText + LB;
  WriteBytes(LFile, FileBytes(LText, ABom));

  // The dialog loads the file
  LAdmin := NewAdminFor(LFile);
  try
    Check(LAdmin.config.ReadString('DELPHI_FB', 'Database', '') = LDb,
      AVariant + ': the accented letter is read by the encoding rule (' +
      LAdmin.config.ReadString('DELPHI_FB', 'Database', '') + ')');
    // What the dialog changes
    LAdmin.config.WriteString('DELPHI_FB', 'User_Name', 'CONTABLE');
    LAdmin.config.WriteString('DELPHI_FB', 'CharacterSet', 'UTF8');
    LAdmin.config.DeleteKey('AGENTE', 'ApiKey');
    LAdmin.config.WriteString('NUEVA', 'DriverName', 'FireDac');
    LAdmin.config.WriteString('NUEVA', 'Database', LNew);
    LAdmin.DeleteConnection('BORRAR');

    // Meanwhile another program (the Desktop) changes its connection and
    // adds another one at the end, as the .NET writer does
    LOther := StringReplace(FileNow(LFile, LBom), 'Param.DataSource=C:\datos\ventas.db',
      'Param.DataSource=C:\datos\ventas2.db', []);
    if not AFinal then
      LOther := LOther + LB;
    LOther := LOther + LB + '[OTRO]' + LB + 'DriverName=ADO.NET' + LB +
      'ProviderFactory=PostgreSQL';
    if AFinal then
      LOther := LOther + LB;
    WriteBytes(LFile, FileBytes(LOther, ABom));

    LAdmin.SaveConfig;

    // Only the lines Delphi touched change
    LExpected := StringReplace(LOther, 'User_Name=SYSDBA' + LB,
      'User_Name=CONTABLE' + LB + 'CharacterSet=UTF8' + LB, []);
    LExpected := StringReplace(LExpected, 'ApiKey=key-of-test' + LB, '', []);
    LExpected := StringReplace(LExpected, '[BORRAR]' + LB + 'DriverName=FireDac' + LB +
      'DriverID=SQLite' + LB + 'Database=borrar.db' + LB + LB, '', []);
    if not AFinal then
      LExpected := LExpected + LB;
    LExpected := LExpected + LB + '[NUEVA]' + LB + 'DriverName=FireDac' + LB +
      'Database=' + LNew;
    if AFinal then
      LExpected := LExpected + LB;
    LNow := FileNow(LFile, LBom);
    Check(LNow = LExpected, AVariant + ': the save changes only the lines of Delphi; ' +
      'the section and the change of the other program, the comments, the blank lines ' +
      'and the repeated section stay');
    if LNow <> LExpected then
    begin
      WriteLn('     expected:'#13#10, LExpected);
      WriteLn('     written:'#13#10, LNow);
    end;
    Check(SameBytes(ReadBytes(LFile), FileBytes(LExpected, ABom)),
      AVariant + ': byte for byte, in the encoding of the file (BOM kept: ' +
      BoolToStr(LBom, True) + ')');
    // Nothing changed: nothing written, also over a change of another program
    LBefore := FileBytes(StringReplace(LExpected, 'ProviderFactory=PostgreSQL',
      'ProviderFactory=Oracle', []), ABom);
    WriteBytes(LFile, LBefore);
    LAdmin.SaveConfig;
    Check(SameBytes(ReadBytes(LFile), LBefore),
      AVariant + ': a save without changes does not write the file');

    // The Delphi parameters of a connection shared with .NET, in the
    // encoding of the file
    LDelphiDb := 'C:\datos\ventas a' + NTilde + 'o.db';
    LParams := TStringList.Create;
    try
      LParams.Add('DriverName=FireDac');
      LParams.Add('DriverID=SQLite');
      LParams.Add('Database=' + LDelphiDb);
      LAdmin.SetDotNetDelphiParams('VENTAS', LParams);
    finally
      LParams.Free;
    end;
    LNow := FileNow(LFile, LBom);
    Check(LNow = StringReplace(FileText(LBefore), 'ConnectionString=Data Source=C:\datos\ventas.db' + LB,
      'ConnectionString=Data Source=C:\datos\ventas.db' + LB + 'Delphi.DriverName=FireDac' + LB +
      'Delphi.DriverID=SQLite' + LB + 'Delphi.Database=' + LDelphiDb + LB, []),
      AVariant + ': the Delphi.* keys go after the last key of their section, in the ' +
      'encoding of the file');
  finally
    LAdmin.Free;
  end;

  // Changes in memory that are not saved are not written when it is freed
  // (the TMemIniFile of FPC writes itself then)
  LBefore := ReadBytes(LFile);
  LAdmin := NewAdminFor(LFile);
  try
    LAdmin.config.WriteString('DELPHI_FB', 'User_Name', 'NOT SAVED');
    LAdmin.config.EraseSection('NUEVA');
    LAdmin.LoadConfig;
    LAdmin.config.WriteString('DELPHI_FB', 'User_Name', 'NOT SAVED EITHER');
  finally
    LAdmin.Free;
  end;
  Check(SameBytes(ReadBytes(LFile), LBefore),
    AVariant + ': changes not saved are not written when it is read again or freed');

  // Another program reads it
  LCheck := NewAdminFor(LFile);
  try
    Check((LCheck.config.ReadString('DELPHI_FB', 'User_Name', '') = 'CONTABLE') and
      (LCheck.config.ReadString('DELPHI_FB', 'Database', '') = LDb) and
      (LCheck.config.ReadString('NUEVA', 'Database', '') = LNew),
      AVariant + ': read again, the changes of Delphi are there');
    Check((LCheck.config.ReadString('OTRO', 'ProviderFactory', '') = 'Oracle') and
      (LCheck.config.ReadString('VENTAS', 'Param.DataSource', '') = 'C:\datos\ventas2.db'),
      AVariant + ': read again, the ones of the other program too (' +
      LCheck.config.ReadString('OTRO', 'ProviderFactory', '') + ', ' +
      LCheck.config.ReadString('VENTAS', 'Param.DataSource', '') + ')');
    Check(LCheck.config.ReadString('VENTAS', 'Delphi.Database', '') = LDelphiDb,
      AVariant + ': read again, the Delphi.* keys (' +
      LCheck.config.ReadString('VENTAS', 'Delphi.Database', '') + ')');
    Check((not LCheck.config.SectionExists('BORRAR')) and
      (LCheck.config.ReadString('AGENTE', 'ApiKey', '') = '') and
      (LCheck.config.ReadString('AGENTE', 'HubDatabaseId', '') = '42'),
      AVariant + ': read again, the section and the key deleted are not there');
  finally
    LCheck.Free;
  end;
end;

// An empty file (one that is not there is not used: TRpConnAdmin goes to the
// shared one): SaveConfig writes what there is in memory (ANSI, CRLF in Windows)
procedure TestSaveEmptyFile;
var
  LFile: string;
  LAdmin: TRpConnAdmin;
begin
  LFile := IncludeTrailingPathDelimiter(GFolder) + 'new' + PathDelim + 'dbxconnections.ini';
  ForceDirectories(ExtractFilePath(LFile));
  WriteBytes(LFile, nil);
  LAdmin := NewAdminFor(LFile);
  try
    LAdmin.config.WriteString('PRIMERA', 'DriverName', 'FireDac');
    LAdmin.config.WriteString('PRIMERA', 'Database', 'C:\a' + NTilde + 'o.db');
    LAdmin.SaveConfig;
  finally
    LAdmin.Free;
  end;
  Check(SameBytes(ReadBytes(LFile), AnsiBytes('[PRIMERA]'#13#10'DriverName=FireDac'#13#10 +
    'Database=C:\a' + NTilde + 'o.db'#13#10)),
    'an empty file is written with what there is, ANSI and CRLF in Windows');
end;

{ 6. The first use: Connect asks for them }

function SetupProposed(AConnAdmin: TRpConnAdmin; const AAlias: string): Boolean;
var
  LParams: TStringList;
begin
  // What the dialog of the designer does when it is accepted as proposed
  Inc(GSetupCalls);
  LParams := TStringList.Create;
  try
    AConnAdmin.GetDotNetProposedParams(AAlias, LParams);
    AConnAdmin.SetDotNetDelphiParams(AAlias, LParams);
    Result := True;
  finally
    LParams.Free;
  end;
end;


procedure CopyFile(const ASource, ADest: string);
var
  LIn, LOut: TFileStream;
begin
  LIn := TFileStream.Create(ASource, fmOpenRead or fmShareDenyNone);
  try
    LOut := TFileStream.Create(ADest, fmCreate);
    try
      LOut.CopyFrom(LIn, 0);
    finally
      LOut.Free;
    end;
  finally
    LIn.Free;
  end;
end;

function NewItem(AList: TRpDatabaseInfoList; const AAlias: string): TRpDatabaseInfoItem;
begin
  Result := AList.Add(AAlias);
  Result.Driver := rpfiredac;
  Result.LoginPrompt := False;
end;

procedure TestConnect(const ASampleDb: string);
var
  LList: TRpDatabaseInfoList;
  LItem: TRpDatabaseInfoItem;
  LRaised: Boolean;
  LMessage, LDb: string;
  LAdmin: TRpConnAdmin;
begin
  LDb := IncludeTrailingPathDelimiter(GFolder) + 'a' + NTilde + 'o' + PathDelim + 'ventas.db';
  // The engine finds the file of the global override (-dbxconnectionfile)
  DBXConnectionsFileOverride := GIni;
  // Without the dialog of the designer: a clear error, the proposed
  // parameters are not used without asking
  RpDotNetConnectionSetup := nil;
  LList := TRpDatabaseInfoList.Create(nil);
  try
    LItem := NewItem(LList, 'VENTAS');
    LRaised := False;
    LMessage := '';
    try
      LItem.Connect(nil);
    except
      on E: Exception do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    Check(LRaised and (Pos('VENTAS', LMessage) > 0) and (Pos('.NET', LMessage) > 0),
      'Connect without Delphi parameters nor dialog raises: ' + LMessage);
  finally
    LList.Free;
  end;
  LAdmin := NewAdmin;
  try
    Check(not LAdmin.DotNetHasDelphiParams('VENTAS'), 'and nothing was written');
  finally
    LAdmin.Free;
  end;
  // With the dialog (accepted as proposed): asked once, then opened
  if not FileExists(ASampleDb) then
  begin
    Skip('the SQLite database of the repository (clientes.db) is not there');
    Exit;
  end;
  CopyFile(ASampleDb, LDb);
  RpDotNetConnectionSetup := SetupProposed;
  GSetupCalls := 0;
  LList := TRpDatabaseInfoList.Create(nil);
  try
    LItem := NewItem(LList, 'VENTAS');
    LMessage := '';
    try
      LItem.Connect(nil);
      LItem.DisConnect;
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Check(GSetupCalls = 1, 'the first use asks for the Delphi parameters once');
{$IFDEF FPC}
    if (LMessage <> '') and (Pos('sqlite', LowerCase(LMessage)) > 0) then
      Skip('opening the SQLite database: no sqlite3 library for the FPC engine (' + LMessage + ')')
    else
{$ENDIF}
    Check(LMessage = '', 'Connect opens the SQLite database with the Delphi parameters saved ' +
      '(the accented path included) ' + LMessage);
  finally
    LList.Free;
  end;
  LList := TRpDatabaseInfoList.Create(nil);
  try
    LItem := NewItem(LList, 'VENTAS');
    try
      LItem.Connect(nil);
      LItem.DisConnect;
    except
      // The library of the FPC engine, above
    end;
    Check(GSetupCalls = 1, 'the next use does not ask again');
  finally
    LList.Free;
  end;
  RpDotNetConnectionSetup := nil;
  DBXConnectionsFileOverride := GIni;
end;

{ 7. The subschemas, shared by alias }

procedure TestSubschemas(const AFixture: string);
var
  LList: TRpDatabaseInfoList;
  LItem: TRpDatabaseInfoItem;
  LNames: TStringList;
  LFile, LText: string;
  LAdmin: TRpConnAdmin;
begin
  if not FileExists(AFixture) then
  begin
    Skip('the fixture of the local schema file is not there: ' + AFixture);
    Exit;
  end;
  DBXConnectionsFileOverride := GIni;
  LList := TRpDatabaseInfoList.Create(nil);
  LNames := TStringList.Create;
  try
    LItem := NewItem(LList, 'CONTA');
    LFile := RpLocalSchemaFileName(LItem);
    Check(SameText(LFile, IncludeTrailingPathDelimiter(GFolder) + 'dbxschemas' + PathDelim + 'CONTA.json'),
      'the subschemas of a .NET connection are dbxschemas\<ALIAS>.json next to the file: ' + LFile);
    Check(RpCanHaveLocalSchema(LItem), 'a .NET connection opened with FireDAC can have local subschemas');
    // The file the Desktop or the C# designer writes (format 2)
    ForceDirectories(ExtractFilePath(LFile));
    LText := BytesText(ReadBytes(AFixture));
    LText := StringReplace(LText, '"alias": "FBEXAMPLE"', '"alias": "CONTA"', []);
    WriteUtf8(LFile, LText);
    RpListLocalSubSchemas(LItem, LNames);
    Check(LNames.Count > 0, 'its subschemas are read by alias, without opening the database (' +
      LNames.CommaText + ')');
    Check(Copy(RpLocalDatabaseDialect(LItem), 1, 8) = 'Firebird',
      'the dialect comes from the proposed Delphi parameters: ' + RpLocalDatabaseDialect(LItem));
  finally
    LNames.Free;
    LList.Free;
    DBXConnectionsFileOverride := GIni;
  end;
  // The connection of the subschemas did not change
  LAdmin := NewAdmin;
  try
    Check(LAdmin.IsDotNetConnection('CONTA') and not LAdmin.DotNetHasDelphiParams('CONTA'),
      'reading the subschemas writes nothing in the connection');
  finally
    LAdmin.Free;
  end;
end;

procedure DeleteFolder(const AFolder: string);
var
  LSearch: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*', faAnyFile, LSearch) = 0 then
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
        Continue;
      if (LSearch.Attr and faDirectory) <> 0 then
        DeleteFolder(IncludeTrailingPathDelimiter(AFolder) + LSearch.Name)
      else
        DeleteFile(IncludeTrailingPathDelimiter(AFolder) + LSearch.Name);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  RemoveDir(AFolder);
end;

var
  I: Integer;
  LKeep: Boolean;
  LDotNetSecret, LDotNetPlain, LRoot: string;
begin
  Failures := 0;
  Skipped := 0;
  LKeep := False;
  LDotNetSecret := '';
  LDotNetPlain := '';
  I := 1;
  while I <= ParamCount do
  begin
    if SameText(ParamStr(I), '--keep') then
      LKeep := True
    else if SameText(ParamStr(I), '--dotnet-secret') and (I < ParamCount) then
    begin
      Inc(I);
      LDotNetSecret := ParamStr(I);
    end
    else if SameText(ParamStr(I), '--dotnet-plain') and (I < ParamCount) then
    begin
      Inc(I);
      LDotNetPlain := ParamStr(I);
    end;
    Inc(I);
  end;
  // The repository: three folders above the program (tests\<test>\bin_x86)
  LRoot := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
    PathDelim + '..' + PathDelim);
  Randomize;
  GFolder := IncludeTrailingPathDelimiter({$IFDEF FPC}GetTempDir{$ELSE}TPath.GetTempPath{$ENDIF}) + 'rp_dbx_dotnet_' +
    IntToStr(Random(1000000)) + FormatDateTime('hhnnsszzz', Now);
  ForceDirectories(GFolder);
  GIni := IncludeTrailingPathDelimiter(GFolder) + 'dbxconnections.ini';
  // Every TRpConnAdmin of the test reads the temporary file, never the real one
  DBXConnectionsFileOverride := GIni;
  WriteLn('Temporary connections file: ', GIni);
  try
    try
      GPassword := 'S3cret' + NTilde;
      GSecret := RpDpapiProtect(GPassword);
      if GSecret = '' then
      begin
        Skip('DPAPI: not available on this system');
        GSecret := 'dpapi:unavailable';
      end;
      WriteFixture;
      TestLists;
      TestProposal;
      TestDpapi(LDotNetSecret, LDotNetPlain);
      TestWrite;
      TestOtherUserPassword;
      TestSurgicalSave('ansi-crlf', False, #13#10, True);
      TestSurgicalSave('utf8bom-crlf', True, #13#10, True);
      TestSurgicalSave('ansi-lf-no-final-break', False, #10, False);
      TestSurgicalSave('utf8bom-lf', True, #10, True);
      TestSaveEmptyFile;
      TestConnect(LRoot + 'clientes.db');
      TestSubschemas(LRoot + 'tests' + PathDelim + 'local_schema_file' + PathDelim +
        'dbxschemas-v2.json');
    except
      on E: Exception do
      begin
        WriteLn('FAIL unexpected ', E.ClassName, ': ', E.Message);
        Inc(Failures);
      end;
    end;
  finally
    if LKeep then
      WriteLn('Kept: ', GFolder)
    else
      DeleteFolder(GFolder);
  end;
  WriteLn;
  if Failures = 0 then
    WriteLn('All checks passed (', Skipped, ' skipped)')
  else
    WriteLn(Failures, ' check(s) failed');
  ExitCode := Failures;
end.

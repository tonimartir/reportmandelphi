{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpsqldbconnfpc                                  }
{       FireDAC connections of the FPC engine (SQLdb)   }
{                                                       }
{       This file is under the MPL license              }
{       A copy of the license is in the license.txt     }
{       file included with this distribution            }
{                                                       }
{*******************************************************}

// There is no FireDAC in FPC: the engine opens the FireDAC connections
// (DriverName=FireDac and its DriverID, as Delphi writes them) with SQLdb,
// the database engine of FPC, reading the FireDAC parameters (Server, Port,
// Database, User_Name, Password, CharacterSet...). The drivers are the ones
// SQLdb has: SQLite, PG, MySQL, FB, IB, MSSQL, Ora and ODBC. Their client
// libraries (libpq, libmysqlclient or the MariaDB client, libfbclient,
// FreeTDS, the Oracle client, unixODBC) are loaded when connecting, so none
// of them is needed to run the reports of the other drivers. VendorLib, as in
// FireDAC, names the client library; on macOS they are also looked for in the
// folders of the usual installers (rpdarwinlibs). FPC does not build
// mssqlconn for macOS, so there MSSQL is not one of the drivers (ODBC with the
// FreeTDS ODBC driver reaches SQL Server).

unit rpsqldbconnfpc;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, sqldb;

const
  // The FireDAC driver family in the FPC designer
  RP_SQLDB_FAMILY_CAPTION = 'FireDAC / SQLdb';

// The FireDAC drivers (DriverID) that the FPC engine opens
procedure RpSQLDBDriverIds(AList: TStrings);
// The DriverID as FireDAC writes it ('pg' -> 'PG'); '' when SQLdb does not
// have the driver
function RpSQLDBDriverId(const ADriverId: string): string;
// The FireDAC parameters of a new connection of the driver, with the
// default values (DriverID not included)
procedure RpSQLDBDriverParams(const ADriverId: string; AValues: TStrings);
// The connected SQLdb connection of a FireDAC connection: its DriverID, its
// FireDAC parameters and the database (for SQLite, the file the caller
// found). Raises when SQLdb does not have the driver, the client library can
// not be loaded or the server refuses the connection.
function RpOpenSQLDBConnection(const ADriverId: string; AParams: TStrings;
  const ADatabase: string): TSQLConnection;

implementation

uses
  sqlite3conn, pqconnection, ibconnection, mysql57conn, mysql80conn,
{$IFDEF DARWIN}
  rpdarwinlibs,
{$ELSE}
  mssqlconn,
{$ENDIF}
  oracleconnection, odbcconn;

const
{$IFDEF DARWIN}
  SQLDB_DRIVER_IDS: array[0..6] of string =
    ('SQLite', 'PG', 'MySQL', 'FB', 'IB', 'Ora', 'ODBC');
{$ELSE}
  SQLDB_DRIVER_IDS: array[0..7] of string =
    ('SQLite', 'PG', 'MySQL', 'FB', 'IB', 'MSSQL', 'Ora', 'ODBC');
{$ENDIF}
  // The MariaDB client, with the API of MySQL 5.7
{$IF DEFINED(WINDOWS)}
  MARIADB_LIBRARY = 'libmariadb.dll';
{$ELSEIF DEFINED(DARWIN)}
  MARIADB_LIBRARY = 'libmariadb.3.dylib';
{$ELSE}
  MARIADB_LIBRARY = 'libmariadb.so.3';
{$IFEND}

procedure RpSQLDBDriverIds(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := Low(SQLDB_DRIVER_IDS) to High(SQLDB_DRIVER_IDS) do
    AList.Add(SQLDB_DRIVER_IDS[I]);
end;

function RpSQLDBDriverId(const ADriverId: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(SQLDB_DRIVER_IDS) to High(SQLDB_DRIVER_IDS) do
    if SameText(Trim(ADriverId), SQLDB_DRIVER_IDS[I]) then
      Exit(SQLDB_DRIVER_IDS[I]);
end;

procedure RpSQLDBDriverParams(const ADriverId: string; AValues: TStrings);

  procedure Add(const AName, AValue: string);
  begin
    AValues.Add(AName + '=' + AValue);
  end;

  procedure AddServer(const APort: string);
  begin
    Add('Server', '');
    Add('Port', APort);
    Add('Database', '');
    Add('User_Name', '');
    Add('Password', '');
  end;

var
  LId: string;
begin
  AValues.Clear;
  LId := RpSQLDBDriverId(ADriverId);
  if LId = 'SQLite' then
    Add('Database', '')
  else if LId = 'PG' then
  begin
    AddServer('5432');
    Add('CharacterSet', '');
  end
  else if LId = 'MySQL' then
  begin
    AddServer('3306');
    Add('CharacterSet', '');
  end
  else if (LId = 'FB') or (LId = 'IB') then
  begin
    AddServer('3050');
    Add('CharacterSet', '');
    Add('RoleName', '');
  end
  else if LId = 'MSSQL' then
    AddServer('1433')
  else if LId = 'Ora' then
  begin
    // The TNS name, or host:port/service
    Add('Database', '');
    Add('User_Name', '');
    Add('Password', '');
    Add('CharacterSet', '');
  end
  else if LId = 'ODBC' then
  begin
    Add('DataSource', '');
    Add('ODBCDriver', '');
    Add('ODBCAdvanced', '');
    Add('Database', '');
    Add('User_Name', '');
    Add('Password', '');
  end;
end;

function Param(AParams: TStrings; const AName: string): string;
begin
  Result := Trim(AParams.Values[AName]);
end;

// Server of FireDAC, HostName of dbExpress and Zeos
function ServerParam(AParams: TStrings): string;
begin
  Result := Param(AParams, 'Server');
  if Result = '' then
    Result := Param(AParams, 'HostName');
end;

procedure SetCommonParams(AConnection: TSQLConnection; AParams: TStrings;
  const ADatabase: string);
begin
  AConnection.LoginPrompt := False;
  AConnection.HostName := ServerParam(AParams);
  AConnection.DatabaseName := ADatabase;
  AConnection.UserName := Param(AParams, 'User_Name');
  AConnection.Password := AParams.Values['Password'];
  AConnection.CharSet := Param(AParams, 'CharacterSet');
end;

// Loads the client library of a connection type of SQLdb with the first
// name that loads: SQLdb loads the name of the development package
// (libodbc.so, libsybdb.so), the runtime packages have the versioned one.
// Once loaded, the connections of that type use it.
procedure LoadClientLibrary(const AConnectionType: string;
  const ANames: array of string);
var
  LDef: TConnectionDef;
  LLoad: TLibraryLoadFunction;
  LErrors: string;
  I: Integer;
begin
  LDef := GetConnectionDef(AConnectionType);
  if (LDef = nil) or (LDef.LoadedLibraryName <> '') then
    Exit;
  LLoad := LDef.LoadFunction;
  if not Assigned(LLoad) then
    Exit;
  LErrors := '';
  for I := Low(ANames) to High(ANames) do
  begin
    try
      LLoad(ANames[I]);
      Exit;
    except
      on E: Exception do
        LErrors := LErrors + sLineBreak + E.Message;
    end;
  end;
  raise EInOutError.Create(Format('The client library of %s could not be loaded ' +
    '(install its client package):', [AConnectionType]) + LErrors);
end;

// The client libraries to try, in order: the VendorLib of the connection (as
// in FireDAC), ANames (the library search of the system) and, on macOS, the
// folders of the usual installers (rpdarwinlibs: an application started from
// the Finder has no DYLD_LIBRARY_PATH). Empty: the library of SQLdb.
function ClientLibraries(AParams: TStrings; const ANames: array of string;
  const AKind: string): TStringArray;
var
  LList: TStringList;
  LVendorLib: string;
{$IFDEF DARWIN}
  LInstalled: TStringArray;
{$ENDIF}
  I: Integer;
begin
  LList := TStringList.Create;
  try
    LVendorLib := Param(AParams, 'VendorLib');
    if LVendorLib <> '' then
      LList.Add(LVendorLib);
    for I := Low(ANames) to High(ANames) do
      LList.Add(ANames[I]);
{$IFDEF DARWIN}
    LInstalled := RpDarwinClientLibraries(AKind);
    for I := 0 to High(LInstalled) do
      LList.Add(LInstalled[I]);
{$ENDIF}
    SetLength(Result, LList.Count);
    for I := 0 to LList.Count - 1 do
      Result[I] := LList[I];
  finally
    LList.Free;
  end;
end;

procedure LoadClientLibraries(const AConnectionType: string; const ALibraries: TStringArray);
begin
  if Length(ALibraries) > 0 then
    LoadClientLibrary(AConnectionType, ALibraries);
end;

// Connects, freeing the connection when it fails
function Connected(AConnection: TSQLConnection): TSQLConnection;
begin
  try
    AConnection.Connected := True;
  except
    AConnection.Free;
    raise;
  end;
  Result := AConnection;
end;

// MySQL: the client of MySQL 8.0 (libmysqlclient.so.21), 5.7 (.so.20) or
// the MariaDB one, the first that loads
function OpenMySQL(AParams: TStrings; const ADatabase: string): TSQLConnection;
var
  LErrors: string;
  LStep: Integer;
  LConnection: TSQLConnection;
begin
  Result := nil;
  LErrors := '';
  for LStep := 0 to 2 do
  begin
    try
      case LStep of
        0:
          begin
            LoadClientLibraries('MySQL 8.0', ClientLibraries(AParams,
              [{$IFDEF DARWIN}'libmysqlclient.21.dylib'{$ENDIF}], 'mysql'));
            LConnection := TMySQL80Connection.Create(nil);
          end;
        1: LConnection := TMySQL57Connection.Create(nil);
      else
        begin
          LoadClientLibrary('MySQL 5.7', ClientLibraries(AParams, [MARIADB_LIBRARY], 'mariadb'));
          LConnection := TMySQL57Connection.Create(nil);
          // Its version is the one of MariaDB
          TMySQL57Connection(LConnection).SkipLibraryVersionCheck := True;
        end;
      end;
    except
      on E: EInOutError do
      begin
        LErrors := LErrors + sLineBreak + E.Message;
        Continue;
      end;
    end;
    SetCommonParams(LConnection, AParams, ADatabase);
    if Param(AParams, 'Port') <> '' then
      LConnection.Params.Values['Port'] := Param(AParams, 'Port');
    try
      Result := Connected(LConnection);
      Exit;
    except
      // Another client library; the errors of the server are raised
      on E: EInOutError do
        LErrors := LErrors + sLineBreak + E.Message;
    end;
  end;
  raise EInOutError.Create('No MySQL client library could be loaded ' +
    '(install the MySQL or MariaDB client package):' + LErrors);
end;

function RpOpenSQLDBConnection(const ADriverId: string; AParams: TStrings;
  const ADatabase: string): TSQLConnection;
var
  LId, LServer, LPort, LAdvanced: string;
  LConnection: TSQLConnection;
  I: Integer;
begin
  LId := RpSQLDBDriverId(ADriverId);
  if LId = '' then
    raise Exception.Create('FireDAC / SQLdb: the driver ' + ADriverId +
      ' is not available in the FPC engine');
  LPort := Param(AParams, 'Port');
  if LId = 'MySQL' then
    Exit(OpenMySQL(AParams, ADatabase));
  if LId = 'SQLite' then
  begin
    LoadClientLibraries('SQLite3', ClientLibraries(AParams,
      [{$IFDEF DARWIN}'libsqlite3.dylib'{$ENDIF}], 'sqlite'));
    LConnection := TSQLite3Connection.Create(nil);
    LConnection.DatabaseName := ADatabase;
    Exit(Connected(LConnection));
  end;
  if LId = 'PG' then
  begin
    LoadClientLibraries('PostgreSQL', ClientLibraries(AParams,
      [{$IFDEF DARWIN}'libpq.5.dylib'{$ENDIF}], 'pq'));
    LConnection := TPQConnection.Create(nil);
    SetCommonParams(LConnection, AParams, ADatabase);
    // The parameters go to the connection string of libpq (lower case)
    if LPort <> '' then
      LConnection.Params.Add('port=' + LPort);
  end
  else if (LId = 'FB') or (LId = 'IB') then
  begin
{$IF DEFINED(DARWIN)}
    LoadClientLibraries('Firebird', ClientLibraries(AParams, ['libfbclient.dylib'], 'fbclient'));
{$ELSEIF DEFINED(UNIX)}
    LoadClientLibraries('Firebird', ClientLibraries(AParams,
      ['libfbclient.so.2', 'libfbclient.so', 'libgds.so'], ''));
{$ELSE}
    LoadClientLibraries('Firebird', ClientLibraries(AParams, [], ''));
{$IFEND}
    LConnection := TIBConnection.Create(nil);
    SetCommonParams(LConnection, AParams, ADatabase);
    // A local database (Protocol=Local of FireDAC): no server
    if SameText(Param(AParams, 'Protocol'), 'Local') then
      LConnection.HostName := ''
    else if LPort <> '' then
      LConnection.Params.Values['Port'] := LPort;
    LConnection.Role := Param(AParams, 'RoleName');
  end
{$IFNDEF DARWIN}
  else if LId = 'MSSQL' then
  begin
{$IFDEF UNIX}
    // The FreeTDS runtime package has libsybdb.so.5
    if DBLibLibraryName = 'libsybdb.so' then
      DBLibLibraryName := 'libsybdb.so.5';
{$ENDIF}
    LConnection := TMSSQLConnection.Create(nil);
    SetCommonParams(LConnection, AParams, ADatabase);
    if (LPort <> '') and (LConnection.HostName <> '') then
      LConnection.HostName := LConnection.HostName + ':' + LPort;
  end
{$ENDIF}
  else if LId = 'Ora' then
  begin
    LConnection := TOracleConnection.Create(nil);
    SetCommonParams(LConnection, AParams, ADatabase);
    // Database is the TNS name or host:port/service; with a server,
    // //server:port/database
    LServer := LConnection.HostName;
    if (LServer <> '') and (LPort <> '') then
      LConnection.HostName := LServer + ':' + LPort;
  end
  else
  begin
    // ODBC: the data source (DSN), the ODBC driver and its parameters
{$IF DEFINED(DARWIN)}
    // unixODBC (Homebrew, MacPorts) or the iODBC that comes with macOS
    LoadClientLibraries('ODBC', ClientLibraries(AParams, ['libodbc.2.dylib'], 'odbc'));
{$ELSEIF DEFINED(UNIX)}
    LoadClientLibraries('ODBC', ClientLibraries(AParams, ['libodbc.so.2', 'libodbc.so'], ''));
{$ELSE}
    LoadClientLibraries('ODBC', ClientLibraries(AParams, [], ''));
{$IFEND}
    LConnection := TODBCConnection.Create(nil);
    SetCommonParams(LConnection, AParams, '');
    LConnection.HostName := '';
    LConnection.DatabaseName := Param(AParams, 'DataSource');
    TODBCConnection(LConnection).Driver := Param(AParams, 'ODBCDriver');
    LServer := ServerParam(AParams);
    if LServer <> '' then
      LConnection.Params.Add('SERVER=' + LServer);
    if LPort <> '' then
      LConnection.Params.Add('PORT=' + LPort);
    if ADatabase <> '' then
      LConnection.Params.Add('DATABASE=' + ADatabase);
    // name=value;name=value
    LAdvanced := Param(AParams, 'ODBCAdvanced');
    while LAdvanced <> '' do
    begin
      I := Pos(';', LAdvanced);
      if I = 0 then
        I := Length(LAdvanced) + 1;
      if Trim(Copy(LAdvanced, 1, I - 1)) <> '' then
        LConnection.Params.Add(Trim(Copy(LAdvanced, 1, I - 1)));
      Delete(LAdvanced, 1, I);
    end;
  end;
  Result := Connected(LConnection);
end;

end.

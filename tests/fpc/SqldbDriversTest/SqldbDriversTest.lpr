{ The direct database drivers of the FPC engine against real database
  servers, opened as a report opens its data: the connection of the report
  (from the connections file) and a dataset with its SQL.
  - FireDAC / SQLdb (rtl_fpc/rpsqldbconnfpc): DriverName=FireDac, its
    DriverID and the FireDAC parameters.
  - Zeos (rpdatazeos): the Zeos protocol and its parameters.

  The servers come from environment variables,
  host|port|database|user|password[|client library]; the client library, when
  given, is the VendorLib (FireDAC) or LibraryLocation (Zeos) of the
  connection (on macOS an application has no DYLD_LIBRARY_PATH):
    RP_TEST_PG     PostgreSQL (libpq)
    RP_TEST_MYSQL  MySQL or MariaDB (libmysqlclient or the MariaDB client)
    RP_TEST_FB     Firebird (libfbclient)
  A server that is not configured is skipped. Other tests, when set to 1:
    RP_TEST_ZEOS    the same servers with Zeos
    RP_TEST_SQLITE  SQLite (a database file in the temporary folder), with
                    FireDAC / SQLdb, and with Zeos when RP_TEST_ZEOS is set
  run_docker.sh starts the servers in Docker containers and runs this
  program in a container with the client libraries (FireDAC / SQLdb only).
  On macOS the servers run in the user folder (docs/macos.md). Exit code 1 on
  the first failure. }
program SqldbDriversTest;

{$mode delphi}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, DB, rptypes, rpdatainfo, rpreport, rpmdconsts, utestutil;

const
  // N with tilde, "and", u with acute: the UTF-8 text of the tests
  TEXT_UTF8 = #$C3#$91'and'#$C3#$BA;
  CREATE_TABLE = 'create table rp_sqldb_test (id integer primary key, ' +
    'name varchar(40), amount numeric(12,2), sale_day date)';
  DROP_TABLE = 'drop table if exists rp_sqldb_test';

var
  ConnFile: string;

function FamilyOf(ADriver: TRpDbDriver): string;
begin
  if ADriver = rpdatazeos then
    Result := 'Zeos'
  else
    Result := 'FireDAC / SQLdb';
end;

// A connection of the connections file. ADriverId is the FireDAC DriverID
// or the Zeos protocol
procedure WriteConnection(ADriver: TRpDbDriver; const AName, ADriverId, AConfig,
  APassword: string);
var
  LParts, LIni: TStringList;
begin
  LParts := TStringList.Create;
  LIni := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := AConfig;
    if FileExists(ConnFile) then
      LIni.LoadFromFile(ConnFile);
    LIni.Add('[' + AName + ']');
    if ADriver = rpdatazeos then
    begin
      LIni.Add('Database Protocol=' + ADriverId);
      LIni.Add('HostName=' + LParts[0]);
      LIni.Add('Port=' + LParts[1]);
      LIni.Add('Database=' + LParts[2]);
      LIni.Add('User_Name=' + LParts[3]);
      LIni.Add('Password=' + APassword);
      // The character set of the client, a Zeos property
      if ADriverId = 'mysql' then
        LIni.Add('Property1=codepage=utf8mb4')
      else if ADriverId <> 'sqlite' then
        LIni.Add('Property1=codepage=UTF8');
      if (LParts.Count > 5) and (LParts[5] <> '') then
        LIni.Add('LibraryLocation=' + LParts[5]);
    end
    else
    begin
      LIni.Add('DriverName=FireDac');
      LIni.Add('DriverID=' + ADriverId);
      LIni.Add('Server=' + LParts[0]);
      LIni.Add('Port=' + LParts[1]);
      LIni.Add('Database=' + LParts[2]);
      LIni.Add('User_Name=' + LParts[3]);
      LIni.Add('Password=' + APassword);
      if ADriverId = 'MySQL' then
        LIni.Add('CharacterSet=utf8mb4')
      else
        LIni.Add('CharacterSet=UTF8');
      if (LParts.Count > 5) and (LParts[5] <> '') then
        LIni.Add('VendorLib=' + LParts[5]);
    end;
    LIni.SaveToFile(ConnFile);
  finally
    LIni.Free;
    LParts.Free;
  end;
end;

function PasswordOf(const AConfig: string): string;
var
  LParts: TStringList;
begin
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := AConfig;
    Result := LParts[4];
  finally
    LParts.Free;
  end;
end;

// Connects the connection of the report, waiting for the server to start
procedure ConnectWaiting(AReport: TRpReport; const AName: string);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  while True do
  begin
    try
      AReport.DatabaseInfo.ItemByName(AName).Connect(AReport.Params);
      Exit;
    except
      on E: Exception do
      begin
        // A missing client library does not wait (SQLdb raises EInOutError,
        // Zeos names the library)
        if (E is EInOutError) or (Pos('librar', LowerCase(E.Message)) > 0) or
          (GetTickCount64 - LStart > 90000) then
          Fail(AName + ': ' + E.ClassName + ': ' + E.Message);
        Log('  waiting for the server: ' + E.Message);
        AReport.DatabaseInfo.ItemByName(AName).DisConnect;
        Sleep(2000);
      end;
    end;
  end;
end;

procedure TestServer(ADriver: TRpDbDriver; const ADriverId, AConfig, ADropSql,
  ACreateSql: string; ACheckPassword: Boolean);
var
  LName, LWhat: string;
  LReport: TRpReport;
  LDatabase: TRpDatabaseInfoItem;
  LData: TRpDataInfoItem;
  LDataset: TDataset;
begin
  LWhat := FamilyOf(ADriver) + ' ' + ADriverId;
  if ADriver = rpdatazeos then
    LName := 'TEST_Z_' + UpperCase(ADriverId)
  else
    LName := 'TEST_' + UpperCase(ADriverId);
  WriteConnection(ADriver, LName, ADriverId, AConfig, PasswordOf(AConfig));
  LReport := TRpReport.Create(nil);
  try
    LDatabase := LReport.DatabaseInfo.Add(LName);
    LDatabase.Driver := ADriver;
    LDatabase.LoadParams := True;
    ConnectWaiting(LReport, LName);
    Pass(LWhat + ': connected with the parameters of the connections file');
    if ADriver = rpdatazeos then
      Check(LDatabase.ZConnection <> nil, LWhat + ': a Zeos connection')
    else
    begin
      Check(LDatabase.SQLDBConnection <> nil, LWhat + ': a SQLdb connection');
      Log('  ' + LDatabase.SQLDBConnection.ClassName);
    end;

    // A table with text, numbers and dates (Firebird uses a table after
    // the transaction that creates it; Zeos commits each statement)
    if ADropSql <> '' then
      LDatabase.OpenDatasetFromSQL(ADropSql, nil, True, LReport.Params);
    LDatabase.OpenDatasetFromSQL(ACreateSql, nil, True, LReport.Params);
    if ADriver <> rpdatazeos then
      LDatabase.SQLDBTransaction.CommitRetaining;
    LDatabase.OpenDatasetFromSQL('insert into rp_sqldb_test (id, name, amount, sale_day) ' +
      'values (1, ''' + TEXT_UTF8 + ''', 1234.5, ''2026-09-30'')', nil, True, LReport.Params);
    LDatabase.OpenDatasetFromSQL('insert into rp_sqldb_test (id, name, amount, sale_day) ' +
      'values (2, ''plain'', -7.25, ''2025-01-31'')', nil, True, LReport.Params);
    Pass(LWhat + ': table created and filled');

    // The dataset of a report
    LData := LReport.DataInfo.Add('TESTDATA');
    LData.DatabaseAlias := LName;
    LData.SQL := 'select id, name, amount, sale_day from rp_sqldb_test order by id';
    LData.Connect(LReport.DatabaseInfo, LReport.Params);
    LDataset := LData.Dataset;
    Check(LDataset.Active, LWhat + ': the dataset of the report is open');
    LDataset.First;
    CheckEquals(1, LDataset.FieldByName('id').AsInteger, LWhat + ': first id');
    CheckEquals(TEXT_UTF8, LDataset.FieldByName('name').AsString, LWhat + ': UTF-8 text');
    Check(Abs(LDataset.FieldByName('amount').AsFloat - 1234.5) < 0.001,
      LWhat + ': number ' + LDataset.FieldByName('amount').AsString);
    Check(Trunc(LDataset.FieldByName('sale_day').AsDateTime) = Trunc(EncodeDate(2026, 9, 30)),
      LWhat + ': date ' + LDataset.FieldByName('sale_day').AsString);
    LDataset.Next;
    CheckEquals(2, LDataset.FieldByName('id').AsInteger, LWhat + ': second id');
    Check(Abs(LDataset.FieldByName('amount').AsFloat + 7.25) < 0.001,
      LWhat + ': negative number');
    LDataset.Next;
    Check(LDataset.Eof, LWhat + ': two records');
    LData.Disconnect;
    LDatabase.DisConnect;
  finally
    LReport.Free;
  end;

  if not ACheckPassword then
    Exit;
  // A wrong password: the error of the server, not of the driver
  WriteConnection(ADriver, LName + '_BAD', ADriverId, AConfig, 'wrong-password');
  LReport := TRpReport.Create(nil);
  try
    LDatabase := LReport.DatabaseInfo.Add(LName + '_BAD');
    LDatabase.Driver := ADriver;
    LDatabase.LoadParams := True;
    try
      LDatabase.Connect(LReport.Params);
      Fail(LWhat + ': connected with a wrong password');
    except
      on E: Exception do
      begin
        Check(Pos(string(SRpDriverNotSupported), E.Message) = 0,
          LWhat + ': wrong password refused by the server: ' + E.Message);
        Log('  ' + E.Message);
      end;
    end;
  finally
    LReport.Free;
  end;
end;

// A server of an environment variable
procedure TestEnvServer(ADriver: TRpDbDriver; const ADriverId, AEnvName, ADropSql,
  ACreateSql: string);
var
  LConfig: string;
begin
  LConfig := GetEnvironmentVariable(AEnvName);
  Section(FamilyOf(ADriver) + ': ' + ADriverId);
  if LConfig = '' then
  begin
    Skip(ADriverId + ': ' + AEnvName + ' not set');
    Exit;
  end;
  TestServer(ADriver, ADriverId, LConfig, ADropSql, ACreateSql, True);
end;

// SQLite: a database file, without server nor password
procedure TestSQLite(ADriver: TRpDbDriver; const ADriverId: string);
var
  LFile: string;
begin
  Section(FamilyOf(ADriver) + ': ' + ADriverId);
  LFile := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rpsqldbtest_' +
    IntToStr(GetProcessID) + '.db';
  DeleteFile(LFile);
  try
    TestServer(ADriver, ADriverId, '|0|' + LFile + '||', DROP_TABLE, CREATE_TABLE, False);
  finally
    DeleteFile(LFile);
  end;
end;

procedure TestNotSupported;
var
  LReport: TRpReport;
  LDatabase: TRpDatabaseInfoItem;
begin
  Section('FireDAC / SQLdb: a driver without SQLdb connector');
  WriteConnection(rpfiredac, 'TEST_ASA', 'ASA', 'server|2638|db|user|x', 'x');
  LReport := TRpReport.Create(nil);
  try
    LDatabase := LReport.DatabaseInfo.Add('TEST_ASA');
    LDatabase.Driver := rpfiredac;
    LDatabase.LoadParams := True;
    try
      LDatabase.Connect(LReport.Params);
      Fail('ASA connected');
    except
      on E: Exception do
      begin
        CheckContains(string(SRpDriverNotSupported), E.Message, 'ASA: not supported');
        CheckContains('ASA', E.Message, 'ASA: the driver named');
      end;
    end;
  finally
    LReport.Free;
  end;
end;

var
  WithZeos, WithSQLite: Boolean;
begin
  Verbose := FindCmdLineSwitch('verbose');
  WithZeos := GetEnvironmentVariable('RP_TEST_ZEOS') = '1';
  WithSQLite := GetEnvironmentVariable('RP_TEST_SQLITE') = '1';
  ConnFile := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rpsqldbtest_' +
    IntToStr(GetProcessID) + '.ini';
  DBXConnectionsFileOverride := ConnFile;
  try
    try
      TestNotSupported;
      TestEnvServer(rpfiredac, 'PG', 'RP_TEST_PG', DROP_TABLE, CREATE_TABLE);
      TestEnvServer(rpfiredac, 'MySQL', 'RP_TEST_MYSQL', DROP_TABLE, CREATE_TABLE);
      TestEnvServer(rpfiredac, 'FB', 'RP_TEST_FB', '', 're' + CREATE_TABLE);
      if WithSQLite then
        TestSQLite(rpfiredac, 'SQLite');
      if WithZeos then
      begin
        TestEnvServer(rpdatazeos, 'postgresql', 'RP_TEST_PG', DROP_TABLE, CREATE_TABLE);
        TestEnvServer(rpdatazeos, 'mysql', 'RP_TEST_MYSQL', DROP_TABLE, CREATE_TABLE);
        TestEnvServer(rpdatazeos, 'firebird', 'RP_TEST_FB', '', 're' + CREATE_TABLE);
        if WithSQLite then
          TestSQLite(rpdatazeos, 'sqlite');
      end;
    except
      on E: Exception do
        Fail('unexpected exception ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    DeleteFile(ConnFile);
  end;
  Log('');
  Log(Format('[TESTS_PASSED] %d checks, %d skipped', [TestCount, SkipCount]));
end.

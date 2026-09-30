{ The FireDAC connections of the FPC engine (SQLdb, rtl_fpc/rpsqldbconnfpc)
  against real database servers: each one is a FireDAC connection of the
  connections file (DriverName=FireDac, its DriverID and the FireDAC
  parameters), opened by the engine as a report opens its data: the
  connection of the report and a dataset with its SQL.

  The servers come from environment variables, host|port|database|user|password:
    RP_TEST_PG     PostgreSQL (libpq)
    RP_TEST_MYSQL  MySQL or MariaDB (libmysqlclient or the MariaDB client)
    RP_TEST_FB     Firebird (libfbclient)
  A server that is not configured is skipped. run_docker.sh starts them in
  Docker containers and runs this program in a container with the client
  libraries. Exit code 1 on the first failure. }
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

var
  ConnFile: string;

procedure WriteConnection(const AName, ADriverId, AConfig, APassword: string);
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
        // A missing client library does not wait
        if (E is EInOutError) or (GetTickCount64 - LStart > 90000) then
          Fail(AName + ': ' + E.ClassName + ': ' + E.Message);
        Log('  waiting for the server: ' + E.Message);
        AReport.DatabaseInfo.ItemByName(AName).DisConnect;
        Sleep(2000);
      end;
    end;
  end;
end;

procedure TestServer(const ADriverId, AEnvName, ADropSql, ACreateSql: string);
var
  LConfig, LName: string;
  LReport: TRpReport;
  LDatabase: TRpDatabaseInfoItem;
  LData: TRpDataInfoItem;
  LDataset: TDataset;
begin
  LConfig := GetEnvironmentVariable(AEnvName);
  Section('FireDAC / SQLdb: ' + ADriverId);
  if LConfig = '' then
  begin
    Skip(ADriverId + ': ' + AEnvName + ' not set');
    Exit;
  end;
  LName := 'TEST_' + UpperCase(ADriverId);
  WriteConnection(LName, ADriverId, LConfig, PasswordOf(LConfig));
  LReport := TRpReport.Create(nil);
  try
    LDatabase := LReport.DatabaseInfo.Add(LName);
    LDatabase.Driver := rpfiredac;
    LDatabase.LoadParams := True;
    ConnectWaiting(LReport, LName);
    Pass(ADriverId + ': connected with the FireDAC parameters');
    Check(LDatabase.SQLDBConnection <> nil, ADriverId + ': a SQLdb connection');
    Log('  ' + LDatabase.SQLDBConnection.ClassName);

    // A table with text, numbers and dates (Firebird uses a table after
    // the transaction that creates it)
    if ADropSql <> '' then
      LDatabase.OpenDatasetFromSQL(ADropSql, nil, True, LReport.Params);
    LDatabase.OpenDatasetFromSQL(ACreateSql, nil, True, LReport.Params);
    LDatabase.SQLDBTransaction.CommitRetaining;
    LDatabase.OpenDatasetFromSQL('insert into rp_sqldb_test (id, name, amount, sale_day) ' +
      'values (1, ''' + TEXT_UTF8 + ''', 1234.5, ''2026-09-30'')', nil, True, LReport.Params);
    LDatabase.OpenDatasetFromSQL('insert into rp_sqldb_test (id, name, amount, sale_day) ' +
      'values (2, ''plain'', -7.25, ''2025-01-31'')', nil, True, LReport.Params);
    Pass(ADriverId + ': table created and filled');

    // The dataset of a report
    LData := LReport.DataInfo.Add('TESTDATA');
    LData.DatabaseAlias := LName;
    LData.SQL := 'select id, name, amount, sale_day from rp_sqldb_test order by id';
    LData.Connect(LReport.DatabaseInfo, LReport.Params);
    LDataset := LData.Dataset;
    Check(LDataset.Active, ADriverId + ': the dataset of the report is open');
    LDataset.First;
    CheckEquals(1, LDataset.FieldByName('id').AsInteger, ADriverId + ': first id');
    CheckEquals(TEXT_UTF8, LDataset.FieldByName('name').AsString, ADriverId + ': UTF-8 text');
    Check(Abs(LDataset.FieldByName('amount').AsFloat - 1234.5) < 0.001,
      ADriverId + ': number ' + LDataset.FieldByName('amount').AsString);
    Check(Trunc(LDataset.FieldByName('sale_day').AsDateTime) = Trunc(EncodeDate(2026, 9, 30)),
      ADriverId + ': date ' + LDataset.FieldByName('sale_day').AsString);
    LDataset.Next;
    CheckEquals(2, LDataset.FieldByName('id').AsInteger, ADriverId + ': second id');
    Check(Abs(LDataset.FieldByName('amount').AsFloat + 7.25) < 0.001,
      ADriverId + ': negative number');
    LDataset.Next;
    Check(LDataset.Eof, ADriverId + ': two records');
    LData.Disconnect;
    LDatabase.DisConnect;
  finally
    LReport.Free;
  end;

  // A wrong password: the error of the server, not of the driver
  WriteConnection(LName + '_BAD', ADriverId, LConfig, 'wrong-password');
  LReport := TRpReport.Create(nil);
  try
    LDatabase := LReport.DatabaseInfo.Add(LName + '_BAD');
    LDatabase.Driver := rpfiredac;
    LDatabase.LoadParams := True;
    try
      LDatabase.Connect(LReport.Params);
      Fail(ADriverId + ': connected with a wrong password');
    except
      on E: Exception do
      begin
        Check(Pos(string(SRpDriverNotSupported), E.Message) = 0,
          ADriverId + ': wrong password refused by the server: ' + E.Message);
        Log('  ' + E.Message);
      end;
    end;
  finally
    LReport.Free;
  end;
end;

procedure TestNotSupported;
var
  LReport: TRpReport;
  LDatabase: TRpDatabaseInfoItem;
begin
  Section('FireDAC / SQLdb: a driver without SQLdb connector');
  WriteConnection('TEST_ASA', 'ASA', 'server|2638|db|user|x', 'x');
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

begin
  Verbose := FindCmdLineSwitch('verbose');
  ConnFile := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rpsqldbtest_' +
    IntToStr(GetProcessID) + '.ini';
  DBXConnectionsFileOverride := ConnFile;
  try
    try
      TestNotSupported;
      TestServer('PG', 'RP_TEST_PG', 'drop table if exists rp_sqldb_test',
        'create table rp_sqldb_test (id integer primary key, name varchar(40), ' +
        'amount numeric(12,2), sale_day date)');
      TestServer('MySQL', 'RP_TEST_MYSQL', 'drop table if exists rp_sqldb_test',
        'create table rp_sqldb_test (id integer primary key, name varchar(40), ' +
        'amount numeric(12,2), sale_day date)');
      TestServer('FB', 'RP_TEST_FB', '',
        'recreate table rp_sqldb_test (id integer primary key, name varchar(40), ' +
        'amount numeric(12,2), sale_day date)');
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

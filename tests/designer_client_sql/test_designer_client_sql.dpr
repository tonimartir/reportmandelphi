program test_designer_client_sql;

{*******************************************************}
{                                                       }
{   The design assistant with a direct connection,      }
{   without UI: the same units the chat frames use      }
{   (rplocalschemas, rpdesignerclientsql) against a     }
{   Reportman AI API and a database of this computer.   }
{                                                       }
{   1. The schema file dbxschemas/<ALIAS>.json is       }
{      generated from the catalog, a subschema is       }
{      added and a refresh keeps what was written.      }
{   2. A SQL runs as one more dataset of the report     }
{      (columns, parameters, the error of the base).    }
{   3. ModifyReport with the client SQL turns: the      }
{      assistant adds a dataset on the direct           }
{      connection.                                      }
{                                                       }
{   Delphi: build.bat. Lazarus: test_designer_client_   }
{   sql.lpi (lazbuild). Run:                            }
{                                                       }
{   test_designer_client_sql -connections <ini>         }
{     -alias FBEXAMPLE [-tokenfile <file>]              }
{     [-installid <id>] [-url <api>] [-prompt <text>]   }
{     [-schema <subschema>]                             }
{                                                       }
{   The connections file must define the alias with a   }
{   FireDAC (SQLdb in Lazarus) connection, e.g.         }
{   DriverName=FireDac DriverID=FB Server Port Database }
{   User_Name Password CharacterSet. Without -tokenfile }
{   only steps 1 and 2 run. The token is never printed. }
{   Exit code 0 when every check passes.                }
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
  LazUTF8, SysUtils, Classes, Contnrs, Variants, rpjsonfpc, rphttpclientfpc,
{$ELSE}
  System.SysUtils, System.Classes, System.Contnrs, System.Variants, System.JSON,
{$ENDIF}
  rptypes, rpdatainfo, rpreport, rpxmlstream, rpdatahttp,
  rpreportdesignercontracts, rplocalschemas, rpdesignerclientsql;

type
  TRunner = class
  public
    Turns: Integer;
    SqlRuns: Integer;
    procedure Progress(Sender: TObject; const AActor, AStage, AChunkType,
      AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
  end;

var
  Failures: Integer = 0;

procedure Log(const AText: string);
begin
  WriteLn(AText);
end;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  if ACondition then
    Log('[OK] ' + AWhat)
  else
  begin
    Log('[FAIL] ' + AWhat);
    Inc(Failures);
  end;
end;

function Arg(const AName, ADefault: string): string;
var
  I: Integer;
begin
  Result := ADefault;
  for I := 1 to ParamCount - 1 do
    if SameText(ParamStr(I), '-' + AName) then
      Exit(ParamStr(I + 1));
end;

function OneLine(const AText: string): string;
begin
  Result := StringReplace(StringReplace(AText, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
end;

procedure TRunner.Progress(Sender: TObject; const AActor, AStage, AChunkType,
  AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
begin
  // Only the messages of the client SQL turns (the AI chunks are noise here)
  if SameText(AActor, 'System') and (Pos('Running the SQL', AChunk) = 1) then
    Inc(Turns);
  if SameText(AActor, 'System') and (Length(AChunk) < 300) and
    ((Pos('Running the SQL', AChunk) = 1) or (Pos('Reading the schema', AChunk) = 1) or
    (Pos(' columns', AChunk) > 0)) then
    Log('  [progress] ' + OneLine(AChunk));
end;

function ReadTokenFile(const AFileName: string): string;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.LoadFromFile(AFileName);
    Result := Trim(LList.Text);
  finally
    LList.Free;
  end;
end;

function NewReport(const AAlias: string): TRpReport;
var
  LDatabase: TRpDatabaseInfoItem;
begin
  Result := TRpReport.Create(nil);
  Result.CreateNew;
  LDatabase := Result.DatabaseInfo.Add(AAlias);
  LDatabase.Driver := rpfiredac;
  LDatabase.LoadParams := True;
end;

function ReportXml(AReport: TRpReport): string;
var
  LStream: TStringStream;
begin
{$IFDEF FPC}
  LStream := TStringStream.Create('');
{$ELSE}
  LStream := TStringStream.Create('', TEncoding.UTF8);
{$ENDIF}
  try
    WriteReportXML(AReport, LStream);
    Result := LStream.DataString;
  finally
    LStream.Free;
  end;
end;

function FindTable(AFile: TRpLocalSchemaFile; const AName: string): TJSONObject;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AFile.Tables.Count - 1 do
    if (AFile.Tables.Items[I] is TJSONObject) and
      SameText(TJSONObject(AFile.Tables.Items[I]).Values['name'].Value, AName) then
      Exit(TJSONObject(AFile.Tables.Items[I]));
end;

function PrimaryKeys(ATable: TJSONObject): string;
var
  I: Integer;
  LColumns: TJSONArray;
  LColumn: TJSONObject;
begin
  Result := '';
  if ATable = nil then
    Exit;
  LColumns := ATable.Values['columns'] as TJSONArray;
  for I := 0 to LColumns.Count - 1 do
  begin
    LColumn := LColumns.Items[I] as TJSONObject;
    if SameText(LColumn.Values['isPrimaryKey'].Value, 'true') then
      Result := Result + LColumn.Values['name'].Value + ' ';
  end;
  Result := Trim(Result);
end;

procedure SetTableContext(AFile: TRpLocalSchemaFile; const ATable, AContext: string);
var
  LTable: TJSONObject;
  LPair: TJSONPair;
begin
  LTable := FindTable(AFile, ATable);
  LPair := LTable.RemovePair('context');
  LPair.Free;
  LTable.AddPair('context', AContext);
end;

// 1. The schema file
procedure TestSchemaFile(AReport: TRpReport; const AAlias: string);
var
  LFile: TRpLocalSchemaFile;
  LFileName, LTables: string;
  LSchema: TRpLocalSubSchema;
  LDatabase: TRpDatabaseInfoItem;
begin
  Log('--- 1. Schema file');
  LDatabase := AReport.DatabaseInfo.ItemByName(AAlias);
  LFileName := RpLocalSchemaFileName(LDatabase);
  Log('  file: ' + LFileName);
  if FileExists(LFileName) then
    DeleteFile(LFileName);
  LFile := RpLoadLocalSchema(LDatabase, AReport.Params, True, False);
  try
    Check(FileExists(LFileName), 'the file is generated the first time');
    Log('  dialect ' + LFile.Dialect + ', ' + IntToStr(LFile.TableCount) + ' tables');
    Check(LFile.Dialect <> 'Default', 'the dialect is known');
    Check((FindTable(LFile, 'SALES') <> nil) and (FindTable(LFile, 'CUSTOMERS') <> nil) and
      (FindTable(LFile, 'PRODUCTS') <> nil), 'SALES, CUSTOMERS and PRODUCTS are in the catalog');
    Log('  primary key of PRODUCTS: ' + PrimaryKeys(FindTable(LFile, 'PRODUCTS')));
    Check(PrimaryKeys(FindTable(LFile, 'PRODUCTS')) <> '', 'PRODUCTS has its primary key');
    // A subschema with a table that does not exist, and a context written
    LSchema := LFile.AddSchema('Ventas');
    LSchema.Tables.Add('SALES');
    LSchema.Tables.Add('customers');
    LSchema.Tables.Add('PRODUCTS');
    LSchema.Tables.Add('GONE_TABLE');
    SetTableContext(LFile, 'PRODUCTS', 'Catalog of articles (written by hand)');
    LFile.SaveToFile(LFileName);
  finally
    LFile.Free;
  end;
  // Refresh: the catalog again, keeping what was written
  LFile := RpLoadLocalSchema(LDatabase, AReport.Params, True, True);
  try
    Check(LFile.IndexOfSchema('Ventas') >= 0, 'the refresh keeps the subschema');
    if LFile.IndexOfSchema('Ventas') >= 0 then
    begin
      LSchema := LFile.Schemas[LFile.IndexOfSchema('Ventas')];
      Log('  Ventas after refresh: ' + LSchema.Tables.CommaText);
      Check(LSchema.Tables.Count = 3, 'the refresh drops the table that is gone');
    end;
    Check(FindTable(LFile, 'PRODUCTS').Values['context'].Value =
      'Catalog of articles (written by hand)', 'the refresh keeps the context written');
    LTables := LFile.SchemaTablesJson('Ventas');
    Check((Pos('"SALES"', LTables) > 0) and (Pos('"PRODUCTS"', LTables) > 0),
      'the subschema carries its tables');
  finally
    LFile.Free;
  end;
  AReport.DatabaseInfo.ItemByName(AAlias).DisConnect;
end;

// 2. A SQL run as one more dataset
procedure TestProbe(const ADocument, AAlias: string);
var
  LParam: TRpClientSqlParameter;
  LRequest: TRpClientSqlRequest;
  LResult: TRpClientSqlResult;
  I: Integer;
  LText: string;
begin
  Log('--- 2. Client SQL probe');
  LRequest := TRpClientSqlRequest.Create;
  try
    LRequest.Id := 'p1';
    LRequest.DatabaseAlias := AAlias;
    LRequest.Sql := 'SELECT PRODUCTID, DESCRIPTION, PRICE FROM PRODUCTS WHERE PRODUCTID > :MINID';
    LParam := TRpClientSqlParameter.Create;
    LParam.Name := '@minId';
    LParam.Value := 0;
    LParam.DbType := 11;
    LParam.HasDbType := True;
    LRequest.Parameters.Add(LParam);
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      LText := '';
      for I := 0 to LResult.Columns.Count - 1 do
        LText := LText + TRpClientSqlColumn(LResult.Columns[I]).Name + ':' +
          TRpClientSqlColumn(LResult.Columns[I]).DataType + ' ';
      Log('  columns: ' + LText + LResult.ErrorMessage);
      Check(LResult.Success and (LResult.Columns.Count = 3), 'a SQL with a new parameter gives its columns');
      Check(LResult.Id = 'p1', 'the answer keeps the id');
    finally
      LResult.Free;
    end;
    LRequest.Sql := 'SELECT NOPE FROM PRODUCTS';
    LRequest.Parameters.Clear;
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      Log('  error: ' + OneLine(LResult.ErrorMessage));
      Check((not LResult.Success) and (LResult.ErrorMessage <> ''), 'a wrong SQL answers the message of the database');
    finally
      LResult.Free;
    end;
    // The SQL of the AI never changes data
    LRequest.Sql := 'DELETE FROM PRODUCTS';
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      Log('  DELETE: ' + OneLine(LResult.ErrorMessage));
      Check((not LResult.Success) and (Pos('DELETE', LResult.ErrorMessage) > 0),
        'a DELETE is rejected with its reason');
    finally
      LResult.Free;
    end;
    LRequest.Sql := 'SELECT PRODUCTID FROM PRODUCTS; DROP TABLE PRODUCTS';
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      Log('  SELECT; DROP: ' + OneLine(LResult.ErrorMessage));
      Check(not LResult.Success, 'a DROP after a SELECT is rejected');
    finally
      LResult.Free;
    end;
    LRequest.Sql := 'SELECT COUNT(*) AS N FROM PRODUCTS';
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      Check(LResult.Success and (LResult.Columns.Count = 1),
        'a SELECT still runs after the rejected ones (PRODUCTS is there)');
    finally
      LResult.Free;
    end;
    // FireDAC and SQLdb only prepare it: a statement that fails when it is
    // executed still gives its columns
    LRequest.Sql := 'SELECT 1/0 AS X, PRODUCTID FROM PRODUCTS';
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      Log('  1/0: ' + IntToStr(LResult.Columns.Count) + ' columns ' + OneLine(LResult.ErrorMessage));
      Check(LResult.Success and (LResult.Columns.Count = 2),
        'the statement is prepared, not executed');
    finally
      LResult.Free;
    end;
    // A parameter that the database can not convert fails when the
    // statement executes, not when it is prepared
    LRequest.Sql := 'SELECT PRODUCTID FROM PRODUCTS WHERE PRODUCTID = :BADNUMBER';
    LParam := TRpClientSqlParameter.Create;
    LParam.Name := 'BADNUMBER';
    LParam.Value := 'not a number';
    LParam.DbType := 16;
    LParam.HasDbType := True;
    LRequest.Parameters.Add(LParam);
    LResult := RpProbeClientSql(ADocument, LRequest);
    try
      Log('  bad parameter: ' + IntToStr(LResult.Columns.Count) + ' columns ' +
        OneLine(LResult.ErrorMessage));
      Check(LResult.Success and (LResult.Columns.Count = 1),
        'nothing is executed (a parameter that does not convert is not sent)');
    finally
      LResult.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

procedure CheckSql(const ASql: string; AAllowed: Boolean);
var
  LReason: string;
begin
  Check(RpCheckClientSql(ASql, LReason) = AAllowed,
    BoolToStr(AAllowed, True) + ': ' + OneLine(ASql) + ' ' + LReason);
end;

// The SQL guard alone
procedure TestSqlGuard;
begin
  Log('--- 0. SQL guard');
  CheckSql('SELECT 1 FROM RDB$DATABASE', True);
  CheckSql('  select ''DELETE; DROP'' as X from RDB$DATABASE', True);
  CheckSql('-- drop table x' + #10 + 'SELECT 1 FROM RDB$DATABASE /* update */', True);
  CheckSql('SELECT 1 FROM RDB$DATABASE;  ', True);
  CheckSql('WITH X AS (SELECT 1 AS A FROM RDB$DATABASE) SELECT A FROM X', True);
  CheckSql('SELECT "DELETE", CREATED_AT, UPDATE_DATE FROM T', True);
  CheckSql('(SELECT 1 FROM RDB$DATABASE) UNION (SELECT 2 FROM RDB$DATABASE)', True);
  CheckSql('DELETE FROM PRODUCTS', False);
  CheckSql('SELECT 1 FROM RDB$DATABASE; DROP TABLE PRODUCTS', False);
  CheckSql('drop table PRODUCTS', False);
  CheckSql('UPDATE PRODUCTS SET PRICE = 0', False);
  CheckSql('WITH D AS (DELETE FROM T RETURNING *) SELECT * FROM D', False);
  CheckSql('SELECT * FROM PRODUCTS FOR UPDATE', False);
  CheckSql('SELECT GEN_ID(G_PRODUCTS, 1) FROM RDB$DATABASE', False);
  CheckSql('SELECT NEXT VALUE FOR G_PRODUCTS FROM RDB$DATABASE', False);
  CheckSql('SELECT nextval(''seq'')', False);
  CheckSql('SELECT * INTO NEWTABLE FROM PRODUCTS', False);
  CheckSql('EXECUTE BLOCK AS BEGIN END', False);
  CheckSql('EXEC sp_who', False);
  CheckSql('SELECT 1 FROM T /* not closed', False);
  CheckSql('SELECT ''not closed FROM T', False);
  CheckSql('', False);
end;

// 3. The assistant through the API
procedure TestModifyReport(const ADocument, AAlias, AToken, AInstallId,
  APrompt, ASchemaName: string);
var
  I, LBefore: Integer;
  LDataset: TRpDataInfoItem;
  LFound: TRpDataInfoItem;
  LHttp: TRpDatabaseHttp;
  LReport: TRpReport;
  LRequest: TRpApiModifyReportRequest;
  LResult: TRpApiModifyReportResult;
  LRunner: TRunner;
  LSql: string;
begin
  Log('--- 3. ModifyReport with client SQL turns');
  Log('  prompt: ' + APrompt);
  LRunner := TRunner.Create;
  LHttp := TRpDatabaseHttp.Create;
  LRequest := TRpApiModifyReportRequest.Create;
  LResult := nil;
  try
    LHttp.Token := AToken;
    LHttp.InstallId := AInstallId;
    LRequest.AITier := ratStandard;
    LRequest.Mode := rdmFast;
    LRequest.ReportDocument := ADocument;
    LRequest.ReportFormat := rdfXml;
    LRequest.ReturnModifiedDocument := True;
    LRequest.UserLanguage := 'English';
    LRequest.UserInstructions.Add(APrompt);
    LRequest.Config.LocalAlias := AAlias;
    LRequest.Config.LocalSchemaName := ASchemaName;
    try
      LResult := RpModifyReportWithClientSql(LHttp, LRequest, nil, LRunner.Progress, nil);
    except
      on E: Exception do
        Log('  exception: ' + OneLine(E.Message));
    end;
    Check(LRequest.Config.HasInlineSchema and SameText(LRequest.Config.Name, AAlias),
      'the request carries the inline schema of ' + AAlias);
    Check(LResult <> nil, 'the API answers');
    if LResult = nil then
      Exit;
    Log('  client SQL turns: ' + IntToStr(LRunner.Turns) + ', steps: ' +
      IntToStr(LResult.Steps.Count));
    if LResult.ErrorMessage <> '' then
      Log('  error: ' + OneLine(RpComposeApiErrorMessage(LResult.ErrorMessage, LResult.DebugDetails)));
    if LResult.ResultData.ErrorMessage <> '' then
      Log('  result error: ' + OneLine(LResult.ResultData.ErrorMessage));
    Log('  explanation: ' + OneLine(Copy(LResult.ResultData.Explanation, 1, 400)));
    Check((LResult.ErrorMessage = '') and LResult.ResultData.Success, 'no error');
    Check(LRunner.Turns >= 1, 'the cloud asked the client to run the SQL');
    Check(LResult.ResultData.ModifiedReportDocument <> '', 'a document to apply');
    if LResult.ResultData.ModifiedReportDocument = '' then
      Exit;
    LReport := RpLoadReportDocument(LResult.ResultData.ModifiedReportDocument);
    try
      LFound := nil;
      LBefore := 0;
      for I := 0 to LReport.DataInfo.Count - 1 do
      begin
        LDataset := LReport.DataInfo.Items[I];
        Log('  dataset ' + LDataset.Alias + ' on ' + LDataset.DatabaseAlias + ': ' +
          OneLine(LDataset.SQL));
        if Pos('PRODUCTS', UpperCase(LDataset.SQL)) > 0 then
          LFound := LDataset;
      end;
      for I := 0 to LReport.DatabaseInfo.Count - 1 do
        if LReport.DatabaseInfo.Items[I].Driver = rpdbHttp then
          Inc(LBefore);
      Check(LFound <> nil, 'a dataset of PRODUCTS was created');
      if LFound <> nil then
      begin
        LSql := UpperCase(LFound.SQL);
        Check(SameText(LFound.DatabaseAlias, AAlias), 'the dataset is on the direct connection ' + AAlias);
        Check((Pos('ORDER BY', LSql) > 0) and (Pos('DESCRIPTION', Copy(LSql, Pos('ORDER BY', LSql), MaxInt)) > 0),
          'ordered by description');
        Check(LFound.SQLExplanation <> '', 'the dataset has its explanation');
      end;
      Check(LBefore = 0, 'no Reportman AI Agent connection was added');
    finally
      LReport.Free;
    end;
  finally
    LResult.Free;
    LRequest.Free;
    LHttp.Free;
    LRunner.Free;
  end;
end;

var
  GAlias, GConnections, GDocument, GInstallId, GPrompt, GToken, GTokenFile,
    GUrl: string;
  GReport: TRpReport;
begin
  try
    GConnections := Arg('connections', '');
    GAlias := UpperCase(Arg('alias', 'FBEXAMPLE'));
    GTokenFile := Arg('tokenfile', '');
    GInstallId := Arg('installid', 'delphi-designer-tests');
    GUrl := Arg('url', '');
    GPrompt := Arg('prompt',
      'Add a dataset with all the products (code, description, price) ordered by description');
    if GConnections <> '' then
      DBXConnectionsFileOverride := ExpandFileName(GConnections);
{$IFDEF FPC}
    // The API of a development machine (HUB_API_URL is the production one
    // in a Release build)
    if GUrl <> '' then
    begin
      RpHttpSetUrlRewrite(HUB_API_URL, GUrl);
      RpHttpVerifyServerCertificates := False;
    end;
{$ENDIF}
    Log('API: ' + HUB_API_URL);
    TestSqlGuard;
    GReport := NewReport(GAlias);
    try
      GDocument := ReportXml(GReport);
      TestSchemaFile(GReport, GAlias);
      TestProbe(GDocument, GAlias);
      if GTokenFile <> '' then
      begin
        GToken := ReadTokenFile(GTokenFile);
        TestModifyReport(GDocument, GAlias, GToken, GInstallId, GPrompt, Arg('schema', ''));
      end
      else
        Log('--- 3. skipped: no -tokenfile');
    finally
      GReport.Free;
    end;
  except
    on E: Exception do
    begin
      Log('[FAIL] ' + E.ClassName + ': ' + OneLine(E.Message));
      Inc(Failures);
    end;
  end;
  if Failures = 0 then
    Log('RESULT: OK')
  else
    Log('RESULT: ' + IntToStr(Failures) + ' FAILED');
  ExitCode := Ord(Failures > 0);
end.

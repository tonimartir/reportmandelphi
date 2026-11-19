program test_designer_generate_schema;

{*******************************************************}
{                                                       }
{   "Generate with AI" with a direct connection,        }
{   without UI: the same units the local schema         }
{   screens use (rplocalschemas, rpdesignerclientsql)   }
{   against a Reportman AI API and a database of this   }
{   computer (docs/generar-esquema-con-ia-plan.md G5).  }
{                                                       }
{   0. The configuration "schemas" ([SchemaAI] of       }
{      reportman_auth.ini), only when LOCALAPPDATA is   }
{      a folder below the one of the connections file.  }
{   1. The four requests of the generator, answered     }
{      from the catalog of the connection: the tables,  }
{      the columns (primary key, .NET type), the        }
{      relations in which a table is the source OR the  }
{      target, and at most 10 rows of some tables.      }
{   2. The generation: NlToSql/GenerateSchemaStream     }
{      with clientExecutes, the requests answered on    }
{      this computer until Completed.                   }
{   3. The result as a new subschema of the schema      }
{      file of the connection, with its descriptions    }
{      in the dictionary, saved and read again.         }
{                                                       }
{   Delphi: build.bat. Lazarus: test_designer_          }
{   generate_schema.lpi (lazbuild). Run:                }
{                                                       }
{   test_designer_generate_schema -connections <ini>    }
{     -alias FBEXAMPLE [-tokenfile <file>]              }
{     [-installid <id>] [-url <api>] [-domain ventas]   }
{     [-name <subschema>] [-tier Standard|Precision]    }
{     [-mode fast|reasoning] [-lang es]                 }
{                                                       }
{   The connections file is required and must be one    }
{   of the test: the schema file is written next to it  }
{   (dbxschemas/<ALIAS>.json), never in the shared      }
{   folder of the designers. It must define the alias   }
{   with a FireDAC (SQLdb in Lazarus) connection, e.g.  }
{   DriverName=FireDac DriverID=FB Server Port Database }
{   User_Name Password CharacterSet, or DriverID=SQLite }
{   Database. The tables SALES, CUSTOMERS and PRODUCTS  }
{   of the example database are checked with -example.  }
{   Without -tokenfile only step 1 runs. The token is   }
{   never printed. Exit code 0 when every check passes. }
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
  LazUTF8, SysUtils, Classes, DateUtils, IniFiles, rpjsonfpc, rphttpclientfpc,
{$ELSE}
  System.SysUtils, System.Classes, System.DateUtils, System.IniFiles,
  System.JSON, Winapi.ActiveX,
{$ENDIF}
  rptypes, rpdatainfo, rpreport, rpdatahttp, rplocalschemas,
  rpdesignerclientsql, rpauthmanager;

type
  TRunner = class
  public
    Calls: Integer;
    Lines: Integer;
    InputTokens: Integer;
    OutputTokens: Integer;
    procedure Progress(Sender: TObject; const AActor, AStage, AChunkType,
      AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
  end;

var
  Failures: Integer = 0;

procedure Log(const AText: string);
begin
  WriteLn(AText);
  // Each line at once: a long request of the AI is followed as it goes
  Flush(Output);
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

function HasFlag(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '-' + AName) then
      Exit(True);
end;

function OneLine(const AText: string): string;
begin
  Result := StringReplace(StringReplace(AText, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
end;

function Cut(const AText: string; AMax: Integer): string;
begin
  Result := OneLine(AText);
  if Length(Result) > AMax then
    Result := Copy(Result, 1, AMax) + '...';
end;

procedure TRunner.Progress(Sender: TObject; const AActor, AStage, AChunkType,
  AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
begin
  if AInputTokens > 0 then
    InputTokens := AInputTokens;
  if AOutputTokens > 0 then
    OutputTokens := AOutputTokens;
  // The lines of the cloud for the user, and what this computer reads
  if SameText(AActor, 'System') and SameText(AStage, 'ParsingResult') then
  begin
    Inc(Lines);
    Log('  [AI] ' + Cut(AChunk, 200));
  end
  else if SameText(AActor, 'System') and SameText(AStage, 'ClientRead') then
  begin
    if Pos('Answering ', AChunk) = 1 then
      Inc(Calls);
    Log('  [client] ' + Cut(AChunk, 200));
  end;
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

function JText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.Values[AName];
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function JObject(AObject: TJSONObject; const AName: string): TJSONObject;
begin
  Result := nil;
  if (AObject <> nil) and (AObject.Values[AName] is TJSONObject) then
    Result := TJSONObject(AObject.Values[AName]);
end;

function JArray(AObject: TJSONObject; const AName: string): TJSONArray;
begin
  Result := nil;
  if (AObject <> nil) and (AObject.Values[AName] is TJSONArray) then
    Result := TJSONArray(AObject.Values[AName]);
end;

function Request(const AId, AKind, ATables: string; AMaxRows: Integer): TJSONObject;
var
  LNames: TStringList;
  LTables: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId);
  Result.AddPair('kind', AKind);
  LTables := TJSONArray.Create;
  Result.AddPair('tables', LTables);
  LNames := TStringList.Create;
  try
    LNames.CommaText := ATables;
    for I := 0 to LNames.Count - 1 do
      LTables.Add(LNames[I]);
  finally
    LNames.Free;
  end;
  Result.AddPair('maxRows', TJSONNumber.Create(AMaxRows));
end;

// 1. The four requests, answered from the catalog
procedure TestRequests(AReport: TRpReport; const AAlias: string;
  AExample: Boolean; out ADialect: string; ANames: TStrings);
var
  I, J, LNumbers: Integer;
  LAnswer, LByTable, LColumn, LRelation, LTable: TJSONObject;
  LColumns, LRelations, LRows, LRow: TJSONArray;
  LDatabase: TRpDatabaseInfoItem;
  LIncoming, LPrimaryKey, LNetTypes: Boolean;
  LRequest: TJSONObject;
  LText: string;
begin
  Log('--- 1. The requests of the generator, answered from the catalog');
  LDatabase := AReport.DatabaseInfo.ItemByName(AAlias);
  RpReadLocalSchemaTableNames(LDatabase, AReport.Params, ANames, ADialect);
  Log('  ' + IntToStr(ANames.Count) + ' tables, dialect ' + ADialect + ': ' +
    Cut(ANames.CommaText, 200));
  Check(ANames.Count > 0, 'the catalog has tables');
  Check(ADialect <> 'Default', 'the dialect is known');
  if AExample then
    Check((ANames.IndexOf('SALES') >= 0) and (ANames.IndexOf('CUSTOMERS') >= 0) and
      (ANames.IndexOf('PRODUCTS') >= 0), 'SALES, CUSTOMERS and PRODUCTS are in the catalog');

  // Tables
  LRequest := Request('t1', 'Tables', '', 10);
  try
    LAnswer := RpAnswerSchemaRequest(LDatabase, AReport.Params, ADialect, ANames, LRequest);
    try
      Check((JText(LAnswer, 'id') = 't1') and SameText(JText(LAnswer, 'success'), 'true') and
        (JArray(LAnswer, 'tables') <> nil) and (JArray(LAnswer, 'tables').Count = ANames.Count),
        'Tables: every name, with the id of the request');
    finally
      LAnswer.Free;
    end;
  finally
    LRequest.Free;
  end;

  if not AExample then
    Exit;

  // Columns: a name in lower case is spelled as the catalog; one that is not
  // there has none
  LRequest := Request('c1', 'Columns', 'SALES,customers,NO_SUCH_TABLE', 10);
  try
    LAnswer := RpAnswerSchemaRequest(LDatabase, AReport.Params, ADialect, ANames, LRequest);
    try
      LByTable := JObject(LAnswer, 'columns');
      Check(SameText(JText(LAnswer, 'success'), 'true') and (LByTable <> nil),
        'Columns: answered ' + JText(LAnswer, 'errorMessage'));
      LColumns := JArray(LByTable, 'SALES');
      LPrimaryKey := False;
      LNetTypes := LColumns <> nil;
      LText := '';
      if LColumns <> nil then
        for I := 0 to LColumns.Count - 1 do
        begin
          LColumn := LColumns.Items[I] as TJSONObject;
          if SameText(JText(LColumn, 'isPrimaryKey'), 'true') then
            LPrimaryKey := True;
          if Pos('System.', JText(LColumn, 'detectedNetType')) <> 1 then
            LNetTypes := False;
          LText := LText + JText(LColumn, 'name') + ':' + JText(LColumn, 'declaredDbType') +
            '/' + JText(LColumn, 'detectedNetType') + ' ';
        end;
      Log('  SALES: ' + Cut(LText, 300));
      Check((LColumns <> nil) and (LColumns.Count > 0), 'SALES has its columns');
      Check(LPrimaryKey, 'SALES has its primary key');
      Check(LNetTypes, 'every column has its .NET type');
      Check((JArray(LByTable, 'CUSTOMERS') <> nil) and (JArray(LByTable, 'CUSTOMERS').Count > 0),
        'customers is read as CUSTOMERS');
      Check((JArray(LByTable, 'NO_SUCH_TABLE') <> nil) and
        (JArray(LByTable, 'NO_SUCH_TABLE').Count = 0), 'a table that is not there has no columns');
    finally
      LAnswer.Free;
    end;
  finally
    LRequest.Free;
  end;

  // Relations with OR: the ones that reach CUSTOMERS
  LRequest := Request('r1', 'Relations', 'CUSTOMERS', 10);
  try
    LAnswer := RpAnswerSchemaRequest(LDatabase, AReport.Params, ADialect, ANames, LRequest);
    try
      LRelations := JArray(LAnswer, 'relations');
      LIncoming := False;
      LText := '';
      if LRelations <> nil then
        for I := 0 to LRelations.Count - 1 do
        begin
          LRelation := LRelations.Items[I] as TJSONObject;
          LText := LText + JText(LRelation, 'sourceTable') + JArray(LRelation, 'sourceColumns').ToJSON +
            '->' + JText(LRelation, 'targetTable') + JArray(LRelation, 'targetColumns').ToJSON + ' ';
          if SameText(JText(LRelation, 'targetTable'), 'CUSTOMERS') and
            not SameText(JText(LRelation, 'sourceTable'), 'CUSTOMERS') then
            LIncoming := True;
        end;
      Log('  relations of CUSTOMERS: ' + Cut(LText, 300) + JText(LAnswer, 'errorMessage'));
      Check(SameText(JText(LAnswer, 'includesIncoming'), 'true'), 'the catalog tells the relations that arrive');
      Check(LIncoming, 'a relation that arrives at CUSTOMERS is there (source OR target)');
    finally
      LAnswer.Free;
    end;
  finally
    LRequest.Free;
  end;

  // Rows: at most 10, values as JSON, a table that fails says why
  LRequest := Request('f1', 'Rows', 'PRODUCTS,SALES,NO_SUCH_TABLE', 10);
  try
    LAnswer := RpAnswerSchemaRequest(LDatabase, AReport.Params, ADialect, ANames, LRequest);
    try
      LByTable := JObject(LAnswer, 'rows');
      LTable := JObject(LByTable, 'PRODUCTS');
      LRows := JArray(LTable, 'rows');
      LNumbers := 0;
      if LRows <> nil then
        for I := 0 to LRows.Count - 1 do
        begin
          LRow := LRows.Items[I] as TJSONArray;
          for J := 0 to LRow.Count - 1 do
            if LRow.Items[J] is TJSONNumber then
              Inc(LNumbers);
        end;
      if (LRows <> nil) and (LRows.Count > 0) then
        Log('  PRODUCTS ' + JArray(LTable, 'columns').ToJSON + ' first row: ' +
          Cut(LRows.Items[0].ToJSON, 200));
      Check((LRows <> nil) and (LRows.Count > 0) and (LRows.Count <= 10), 'PRODUCTS: between 1 and 10 rows');
      Check(LNumbers > 0, 'the numbers travel as JSON numbers');
      LRows := JArray(JObject(LByTable, 'SALES'), 'rows');
      Check((LRows <> nil) and (LRows.Count > 0) and (LRows.Count <= 10), 'SALES: between 1 and 10 rows');
      LText := JText(JObject(LByTable, 'NO_SUCH_TABLE'), 'error');
      Log('  NO_SUCH_TABLE: ' + Cut(LText, 160));
      Check(LText <> '', 'a table that can not be read says why and the rest go on');
    finally
      LAnswer.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

// 0. The configuration "schemas" ([SchemaAI] of reportman_auth.ini). Only
// with LOCALAPPDATA in the folder of the test: the file of the user is never
// touched
procedure TestSettings(const AFolder: string);
var
  LFileName, LMode, LTier: string;
  LAgentAiId: Int64;
  LIni: TIniFile;
begin
  Log('--- 0. The configuration "schemas" ([SchemaAI] of reportman_auth.ini)');
  if not SameText(Copy(IncludeTrailingPathDelimiter(ExpandFileName(
    GetEnvironmentVariable('LOCALAPPDATA'))), 1, Length(AFolder)), AFolder) then
  begin
    Log('  skipped: LOCALAPPDATA is not a folder of the test');
    Exit;
  end;
  LFileName := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
    'Reportman' + PathDelim + 'reportman_auth.ini';
  ForceDirectories(ExtractFilePath(LFileName));
  // A file of a session, without the section
  LIni := TIniFile.Create(LFileName);
  try
    LIni.EraseSection('SchemaAI');
    LIni.WriteString('Preferences', 'AILanguage', 'Spanish');
    LIni.WriteString('OtherProgram', 'Key', 'kept');
  finally
    LIni.Free;
  end;
  TRpAuthManager.Instance.GetSchemaAI(LTier, LMode, LAgentAiId);
  Log('  without the section: ' + LTier + '/' + LMode + '/' + IntToStr(LAgentAiId));
  Check((LTier = 'Precision') and (LMode = 'Fast') and (LAgentAiId = 0),
    'without the section: Precision and Fast');
  TRpAuthManager.Instance.SetSchemaAI('Standard', 'Reasoning', 42);
  TRpAuthManager.Instance.GetSchemaAI(LTier, LMode, LAgentAiId);
  Check((LTier = 'Standard') and (LMode = 'Reasoning') and (LAgentAiId = 0),
    'Standard and Reasoning are kept (no agent without LocalAgent)');
  TRpAuthManager.Instance.SetSchemaAI('LocalAgent', 'Fast', 42);
  TRpAuthManager.Instance.GetSchemaAI(LTier, LMode, LAgentAiId);
  Check((LTier = 'LocalAgent') and (LMode = 'Fast') and (LAgentAiId = 42),
    'the AI of an Agent is kept with its id');
  LIni := TIniFile.Create(LFileName);
  try
    Log('  [SchemaAI] Tier=' + LIni.ReadString('SchemaAI', 'Tier', '') + ' Mode=' +
      LIni.ReadString('SchemaAI', 'Mode', '') + ' AgentAiId=' +
      LIni.ReadString('SchemaAI', 'AgentAiId', ''));
    Check(LIni.ReadString('OtherProgram', 'Key', '') = 'kept', 'the rest of the file stays');
    Check(LIni.ReadString('SchemaAI', 'Tier', '') = 'LocalAgent', 'the keys of the C# designer: Tier, Mode, AgentAiId');
  finally
    LIni.Free;
  end;
  TRpAuthManager.Instance.SetSchemaAI('Precision', 'Fast', 0);
end;

// 2 and 3. The generation and the subschema
procedure TestGenerate(AReport: TRpReport; const AAlias, AToken,
  AInstallId: string; AExample: Boolean);
var
  I, LCount, LCredits, LTables, LRelations, LTurns, LDescribed: Integer;
  LDatabase: TRpDatabaseInfoItem;
  LError, LExplanation, LFileName, LJson, LName, LFolder: string;
  LFile: TRpLocalSchemaFile;
  LFrame, LTable: TJSONObject;
  LHttp: TRpDatabaseHttp;
  LRequest: TRpSchemaGenerationRequest;
  LRunner: TRunner;
  LSkipped, LWarnings: TStringList;
  LSchema: TRpLocalSubSchema;
  LStart: TDateTime;
  LSeconds: Double;
begin
  Log('--- 2. The generation (NlToSql/GenerateSchemaStream, clientExecutes)');
  LDatabase := AReport.DatabaseInfo.ItemByName(AAlias);
  LRunner := TRunner.Create;
  LHttp := TRpDatabaseHttp.Create;
  LRequest := TRpSchemaGenerationRequest.Create;
  LWarnings := TStringList.Create;
  LSkipped := TStringList.Create;
  LFrame := nil;
  try
    LHttp.Token := AToken;
    LHttp.InstallId := AInstallId;
    LRequest.Domain := Arg('domain', 'ventas');
    LRequest.SchemaName := Arg('name', '');
    LRequest.AITier := Arg('tier', 'Standard');
    if SameText(Arg('mode', 'fast'), 'reasoning') then
      LRequest.AIMode := 'Reasoning'
    else
      LRequest.AIMode := 'Fast';
    LRequest.LanguageIso := Arg('lang', 'es');
    Log('  domain "' + LRequest.Domain + '", ' + LRequest.AITier + '/' + LRequest.AIMode);
    LStart := Now;
    LFrame := RpGenerateSchema(LHttp, LRequest, LDatabase, AReport.Params, nil,
      LRunner.Progress, nil);
    LSeconds := MilliSecondsBetween(Now, LStart) / 1000;
    Check(LFrame <> nil, 'the generation ends with a final frame');
    if LFrame = nil then
      Exit;
    RpGeneratedSchemaInfo(LFrame, LError, LExplanation, LWarnings, LCredits, LTurns);
    if LError <> '' then
      Log('  error: ' + Cut(LError, 400));
    Log('  status ' + JText(JObject(LFrame, 'result'), 'status') + ', ' +
      IntToStr(LRunner.Calls + 1) + ' calls, ' + IntToStr(LTurns) + ' turns, ' +
      IntToStr(LCredits) + ' credits, ' + FormatFloat('0.0', LSeconds) + ' s, tokens ' +
      IntToStr(LRunner.InputTokens) + ' in / ' + IntToStr(LRunner.OutputTokens) + ' out (last)');
    Check(LError = '', 'no error');
    Check(SameText(JText(JObject(LFrame, 'result'), 'status'), 'Completed'), 'the status is Completed');
    Check(LRunner.Lines > 0, 'the cloud sent lines of progress');
    LJson := RpGeneratedSchemaJson(LFrame, LRequest.Domain, LTables, LRelations);
    Log('  schema: ' + IntToStr(LTables) + ' tables, ' + IntToStr(LRelations) + ' relations');
    Check(LTables >= 1, 'the schema has at least one table');
    Log('  explanation: ' + Cut(LExplanation, 400));
    for I := 0 to LWarnings.Count - 1 do
      Log('  warning: ' + Cut(LWarnings[I], 200));
    if LJson = '' then
      Exit;

    Log('--- 3. The schema as a new subschema of the file of the test');
    LFileName := RpLocalSchemaFileName(LDatabase);
    LFolder := ExtractFilePath(ExpandFileName(DBXConnectionsFileOverride));
    Log('  file: ' + LFileName);
    // Never the shared file of the designers: next to the connections of the
    // test
    Check(SameText(Copy(ExpandFileName(LFileName), 1, Length(LFolder)), LFolder),
      'the schema file is the one of the test');
    if not SameText(Copy(ExpandFileName(LFileName), 1, Length(LFolder)), LFolder) then
      Exit;
    LFile := RpLoadLocalSchema(LDatabase, AReport.Params, True, False);
    try
      LDatabase.DisConnect;
      LCount := RpImportGeneratedSchemaJson(LFile, LJson, LName, LSkipped);
      Log('  imported as "' + LName + '": ' + IntToStr(LCount) + ' tables' );
      if LSkipped.Count > 0 then
        Log('  not imported: ' + LSkipped.CommaText);
      Check(LCount >= 1, 'a new subschema with the tables of the schema');
      Check(LFile.IndexOfSchema(LName) >= 0, 'the subschema is in the file');
      LDescribed := 0;
      if LFile.IndexOfSchema(LName) >= 0 then
      begin
        LSchema := LFile.Schemas[LFile.IndexOfSchema(LName)];
        for I := 0 to LSchema.Tables.Count - 1 do
        begin
          LTable := LFile.FindTable(LSchema.Tables[I]);
          if (LTable <> nil) and (Trim(JText(LTable, 'context')) <> '') then
          begin
            Inc(LDescribed);
            if LDescribed = 1 then
              Log('  ' + LSchema.Tables[I] + ': ' + Cut(JText(LTable, 'context'), 160));
          end;
        end;
      end;
      Check(LDescribed >= 1, 'the descriptions are in the dictionary (' + IntToStr(LDescribed) + ' tables)');
      LFile.SaveToFile(LFileName);
    finally
      LFile.Free;
    end;
    // Read again from the file
    LFile := TRpLocalSchemaFile.Create;
    try
      LFile.LoadFromFile(LFileName);
      Check(LFile.IndexOfSchema(LName) >= 0, 'the subschema is saved in the file of the test');
      if AExample then
        Check(LFile.SchemaTablesJson(LName) <> '[]', 'the subschema travels with its tables');
    finally
      LFile.Free;
    end;
  finally
    LFrame.Free;
    LSkipped.Free;
    LWarnings.Free;
    LRequest.Free;
    LHttp.Free;
    LRunner.Free;
  end;
end;

var
  GAlias, GConnections, GDialect, GInstallId, GToken, GTokenFile, GUrl: string;
  GExample: Boolean;
  GNames: TStringList;
  GReport: TRpReport;
begin
  GReport := nil;
  GNames := TStringList.Create;
  try
    try
{$IFNDEF FPC}
      CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
{$ENDIF}
      GConnections := Arg('connections', '');
      GAlias := UpperCase(Arg('alias', 'FBEXAMPLE'));
      GTokenFile := Arg('tokenfile', '');
      GInstallId := Arg('installid', 'delphi-designer-tests');
      GUrl := Arg('url', '');
      GExample := HasFlag('example');
      // The schema file goes next to the connections file: always one of the
      // test
      if GConnections = '' then
        raise Exception.Create('-connections <ini of the test> is required');
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
      TestSettings(ExtractFilePath(DBXConnectionsFileOverride));
      GReport := NewReport(GAlias);
      TestRequests(GReport, GAlias, GExample, GDialect, GNames);
      GReport.DatabaseInfo.ItemByName(GAlias).DisConnect;
      if GTokenFile <> '' then
      begin
        GToken := ReadTokenFile(GTokenFile);
        TestGenerate(GReport, GAlias, GToken, GInstallId, GExample);
      end
      else
        Log('--- 2. skipped: no -tokenfile');
    except
      on E: Exception do
      begin
        Log('[FAIL] ' + E.ClassName + ': ' + OneLine(E.Message));
        Inc(Failures);
      end;
    end;
  finally
    GReport.Free;
    GNames.Free;
  end;
  if Failures = 0 then
    Log('RESULT: OK')
  else
    Log('RESULT: ' + IntToStr(Failures) + ' FAILED');
  ExitCode := Ord(Failures > 0);
end.

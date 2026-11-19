{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdesignerclientsql                             }
{                                                       }
{       The SQL of the design assistant, run by the     }
{       designer when the database is not in the Hub    }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpdesignerclientsql;

{ The design assistant (ReportDesigner/ModifyReportStream) needs the columns
  of every dataset SQL it writes. The cloud runs the SQL of Hub databases
  itself; for any other database (a direct connection of the designer:
  FireDAC, Zeos, IBX, ADO...) it ends the turn with status
  NeedsClientSqlResults and the SQL to run. The designer opens each one as one
  more dataset of the report document the cloud returned, on the connection
  it names, reads its columns and calls again with them and the signed
  continuation, until the cloud is done:

    1. clientExecutesSql is always sent;
    2. while result.status = NeedsClientSqlResults: open every
       clientSqlRequests[i] (parameters linked as the report will run them),
       call again with the same instructions, reportDocument = the document
       of the turn, existingContextJson = workingContextJson, the
       continuation and clientSqlResults;
    3. at the end the document to apply is modifiedReportDocument or, empty,
       the last document sent (when it changed).

  No UI here: the chat frames (VCL and LCL) call RpModifyReportWithClientSql
  from their worker thread, and the tests call it from a console program.
  The report document is loaded into a report of its own for every SQL: the
  report of the designer is never touched from the worker.

  The SQL is written by the AI and runs without the user seeing it, so it
  can never change data:

  - RpCheckClientSql accepts one statement that starts with SELECT or WITH
    and has none of the words that write, run code or move sequences
    (INSERT, UPDATE, DELETE, MERGE, DROP, ALTER, CREATE, TRUNCATE, GRANT,
    REVOKE, EXEC, EXECUTE, CALL, INTO, GEN_ID, NEXTVAL, SETVAL, NEXT VALUE)
    outside string literals, quoted identifiers and comments. A rejected SQL
    answers success: false with the reason, and the cloud rewrites it;
  - FireDAC (Delphi) and SQLdb (Lazarus) only prepare the statement and read
    its field definitions: nothing is executed. The other drivers open it
    (FireDAC, when it can not describe it, without fetching rows);
  - everything runs inside a transaction that is always rolled back (the
    engine commits its transaction when it disconnects: the rollback comes
    first), read only where the driver has it (FireDAC). }

interface

{$I rpconf.inc}

uses
{$IFDEF FPC}
  SysUtils, Classes, Contnrs, DB, Variants, rpjsonfpc, sqldb,
{$ELSE}
  SysUtils, Classes, Contnrs, DB, Variants, System.JSON,
{$ENDIF}
{$IFDEF MSWINDOWS}
  ActiveX,
{$ENDIF}
{$IFDEF FIREDAC}
  FireDAC.Stan.Intf, FireDAC.Comp.Client, FireDAC.Stan.Option,
  FireDAC.Stan.Param,
{$ENDIF}
{$IFDEF USEZEOS}
  ZConnection,
{$ENDIF}
{$IFDEF USEADO}
  {$IFDEF DELPHIXE2UP}
  Data.Win.ADODB,
  {$ELSE}
  ADODB,
  {$ENDIF}
{$ENDIF}
{$IFDEF USEIBX}
  {$IFDEF DELPHIXE2UP}
  IBX.IBDatabase,
  {$ELSE}
  IBDatabase,
  {$ENDIF}
{$ENDIF}
  rptypes, rpparams, rpeval, rpdatainfo, rpbasereport, rpreport, rpdatahttp,
  rpreportdesignercontracts, rplocalschemas, rpmdconsts;

const
  // As the web designer (copilot-panel): a request is never endless
  RP_MAX_CLIENT_SQL_TURNS = 30;

// Whether a SQL of the AI may run to read its columns: one SELECT (or
// WITH) statement that can not change data. AReason says why not
function RpCheckClientSql(const ASql: string; out AReason: string): Boolean;

// The report of a document (.rep XML): a new report the caller frees
function RpLoadReportDocument(const AReportDocument: string): TRpReport;

// The columns of a SQL of the assistant, run as one more dataset of the
// report (the probe is added to AReport: load a report for each SQL): on
// the connection of the request, with the parameters of the report that it
// names and new ones for the others, with the value the AI gave. Never
// raises: a SQL that does not run answers the message of the database
function RpProbeClientSql(AReport: TRpReport;
  ARequest: TRpClientSqlRequest): TRpClientSqlResult; overload;
function RpProbeClientSql(const AReportDocument: string;
  ARequest: TRpClientSqlRequest): TRpClientSqlResult; overload;

// The schema of the direct connection AConfig.LocalAlias of the report, in
// the config (Name = the alias, Dialect, SchemaTablesJson = the tables of
// the subschema AConfig.LocalSchemaName and SchemaName = that subschema as
// the file spells it). Only a subschema goes to the AI (F8): an empty
// LocalSchemaName, or one that is not in the file, raises the message of
// RpSubSchemaRequiredMessage, never the whole dictionary. The schema file is
// generated from the catalog when it does not exist yet. Nothing to do when
// the config has no LocalAlias or has the tables already
procedure RpResolveLocalSchemaConfig(AConfig: TRpApiDatabaseConfig;
  AReport: TRpReport); overload;
procedure RpResolveLocalSchemaConfig(AConfig: TRpApiDatabaseConfig;
  const AReportDocument: string); overload;
// The same with the connection itself (a copy, RpCopyDatabaseInfo, keeps
// the one of the designer connected)
procedure RpResolveLocalSchemaConfig(AConfig: TRpApiDatabaseConfig;
  ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList); overload;

// ModifyReport with the client SQL turns (see the unit comment). The result
// carries the steps of every turn; its ModifiedReportDocument is the
// document to apply. nil when cancelled
function RpModifyReportWithClientSql(AHttp: TRpDatabaseHttp;
  ARequest: TRpApiModifyReportRequest; Sender: TObject = nil;
  AOnProgress: TRpExpressionStreamProgressEvent = nil;
  ACancel: TRpExpressionStreamCancelEvent = nil): TRpApiModifyReportResult;

{ "Generate with AI" (docs/generar-esquema-con-ia-plan.md, G5): the AI of
  the cloud explores a database it does not know and proposes a schema for
  the domain the user names (NlToSql/GenerateSchemaStream). The loop and the
  prompt live in the cloud; the tools run where the database is reachable:

  - a direct connection (the "turno de apertura en el cliente", as the SQL
    of the copilot above): every call may end with status
    NeedsClientResults and typed requests (Tables, Columns, Relations,
    Rows). This computer reads them with its catalog reader and its preview
    (rplocalschemas), never with a SQL of the cloud, and calls again with
    the results and the signed continuation, until Completed or Failed;
  - a Reportman AI Agent connection: the cloud reads the database through
    the Hub itself, in one call.

  The result (result.schema, a database config with its schemaTables) is
  never saved here: the local schema screens import it as a new subschema
  with its descriptions in the dictionary where it has none
  (RpImportGeneratedSchemaJson: what is written there is kept), unsaved. }

const
  // The calls of one generation (the cloud has its own limits of turns)
  RP_MAX_SCHEMA_GENERATION_CALLS = 40;
  // The rows of a table the generator reads, at most
  RP_SCHEMA_GENERATION_MAX_ROWS = 10;

type
  // What the user asks "Generate with AI"
  TRpSchemaGenerationRequest = class(TPersistent)
  private
    FAgentAiId: Int64;
    FAgentSecret: string;
    FAIMode: string;
    FAITier: string;
    FDomain: string;
    FLanguageIso: string;
    FSchemaName: string;
  public
    procedure Assign(Source: TPersistent); override;
    // As typed: "ventas", "compras", "ventas+compras", "todo"...
    property Domain: string read FDomain write FDomain;
    // Optional: empty, the cloud names it after the domain
    property SchemaName: string read FSchemaName write FSchemaName;
    // Standard, Precision or LocalAgent (with the agent of the user)
    property AITier: string read FAITier write FAITier;
    // Fast or Reasoning
    property AIMode: string read FAIMode write FAIMode;
    property AgentSecret: string read FAgentSecret write FAgentSecret;
    property AgentAiId: Int64 read FAgentAiId write FAgentAiId;
    // The two letters of the descriptions and the progress; '' the
    // language of the AI of the designer
    property LanguageIso: string read FLanguageIso write FLanguageIso;
  end;

// What a request of the generator ({ id, kind, tables, maxRows }) reads on
// the direct connection ADatabase: { id, success, errorMessage } and tables,
// columns (by table, DiscoveredColumn), relations + includesIncoming or rows
// (by table, { columns, rows, error }, at most 10 rows). ATableNames are the
// tables of the catalog (filled when empty): the names asked are spelled as
// the catalog does. Never raises: a request that fails says why
function RpAnswerSchemaRequest(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; const ADialect: string; ATableNames: TStrings;
  ARequest: TJSONObject): TJSONObject;

// The whole generation (see above) on the connection ADatabase (a copy the
// caller may connect: RpCopyDatabaseInfo), with the session of AHttp
// (Token, InstallId). AOnProgress receives the frames of the cloud: the ones
// of actor System and stage ParsingResult are the lines for the user. The
// final frame (GenerateSchemaApiResult: result with status, schema,
// explanation, warnings, creditsConsumed of the whole run and turns;
// userProfile; errorMessage) the caller frees; nil when cancelled
function RpGenerateSchema(AHttp: TRpDatabaseHttp;
  ARequest: TRpSchemaGenerationRequest; ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; Sender: TObject = nil;
  AOnProgress: TRpExpressionStreamProgressEvent = nil;
  ACancel: TRpExpressionStreamCancelEvent = nil): TJSONObject;

// The schema of a final frame that completed, as the JSON text that
// RpImportSchemaJson imports ({ "name", "schemaTables" }; named ADefaultName
// when the cloud gave no name), '' when there is none; ATables and
// ARelations count what it brings
function RpGeneratedSchemaJson(AFrame: TJSONObject; const ADefaultName: string;
  out ATables, ARelations: Integer): string;
// What a final frame says: the error (errorMessage of the frame), the
// explanation of the AI (Markdown), its warnings (one per line), the
// credits of the whole run and its turns
procedure RpGeneratedSchemaInfo(AFrame: TJSONObject; out AError,
  AExplanation: string; AWarnings: TStrings; out ACredits, ATurns: Integer);

type
  // The state of a generation in a thread (RpStartSchemaGeneration)
  TRpSchemaGenerationState = record
    Finished: Boolean;
    // Stopped: there is no result
    Cancelled: Boolean;
    InputTokens: Integer;
    OutputTokens: Integer;
    // The final frame (JSON), when there is one
    ResultJson: string;
    // The generation failed before the final frame (HTTP, the database)
    ErrorMessage: string;
  end;

  IRpSchemaGeneration = interface
    ['{4E2B7C19-6A3D-4F58-B1E0-2C9D8A7F5E31}']
    procedure Cancel;
    function GetState: TRpSchemaGenerationState;
    // The lines for the user that came since the last call (added to ALines)
    procedure TakeLines(ALines: TStrings);
  end;

// "Generate with AI" of the local schema screens: RpGenerateSchema in a
// thread of its own, on a copy of the connection made now, with the session
// of TRpAuthManager. The screen reads GetState and TakeLines with a timer
// (VCL and LCL alike) and may be closed while it runs: the thread keeps the
// task alive and ends on its own after Cancel
function RpStartSchemaGeneration(ARequest: TRpSchemaGenerationRequest;
  ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList): IRpSchemaGeneration;

implementation

uses
{$IFDEF FPC}
  SyncObjs, rpauthmanager;
{$ELSE}
  System.SyncObjs, rpauthmanager;
{$ENDIF}

type
  // UpdateParamsBeforeOpen is protected
  TRpBaseReportAccess = class(TRpBaseReport);

  TRpReadErrorIgnorer = class(TObject)
  public
    procedure ReadError(Reader: TReader; const Message: string;
      var Handled: Boolean);
  end;

procedure TRpReadErrorIgnorer.ReadError(Reader: TReader;
  const Message: string; var Handled: Boolean);
begin
  // A property this build does not know is skipped, as the designer does
  Handled := True;
end;

var
  GReadErrorIgnorer: TRpReadErrorIgnorer = nil;

function RpLoadReportDocument(const AReportDocument: string): TRpReport;
var
  LStream: TStringStream;
begin
  if Trim(AReportDocument) = '' then
    raise Exception.Create('The report document is empty');
  Result := TRpReport.Create(nil);
  try
    // The folder of the report of the designer: the relative SQLite database
    // of a sample is next to it (the XML does not carry it)
    Result.ReportFolder := RpReportFolder;
    Result.FailIfLoadExternalError := False;
    Result.OnReadError := GReadErrorIgnorer.ReadError;
{$IFDEF FPC}
    LStream := TStringStream.Create(AReportDocument);
{$ELSE}
    LStream := TStringStream.Create(AReportDocument, TEncoding.UTF8);
{$ENDIF}
    try
      Result.LoadFromStream(LStream);
    finally
      LStream.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

{ Parameters }

const
  // System.Data.DbType
  DBTYPE_BYTE_ = 2;
  DBTYPE_BOOLEAN_ = 3;
  DBTYPE_CURRENCY_ = 4;
  DBTYPE_DATE_ = 5;
  DBTYPE_DATETIME_ = 6;
  DBTYPE_DECIMAL = 7;
  DBTYPE_DOUBLE_ = 8;
  DBTYPE_INT16 = 10;
  DBTYPE_INT32_ = 11;
  DBTYPE_INT64 = 12;
  DBTYPE_SBYTE = 14;
  DBTYPE_SINGLE = 15;
  DBTYPE_TIME_ = 17;
  DBTYPE_UINT16 = 18;
  DBTYPE_UINT32 = 19;
  DBTYPE_UINT64 = 20;
  DBTYPE_VARNUMERIC = 21;
  DBTYPE_DATETIME2 = 26;
  DBTYPE_DATETIMEOFFSET = 27;

// The name of a parameter in the report: without @, : or ?, letters and
// digits (any other character is _), upper case
function NormalizeParamName(const AName: string): string;
var
  I: Integer;
begin
  Result := Trim(AName);
  while (Result <> '') and CharInSet(Result[1], ['@', ':', '?']) do
    Delete(Result, 1, 1);
  Result := Trim(Result);
  for I := 1 to Length(Result) do
    if not CharInSet(Result[I], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Result[I] := '_';
  Result := UpperCase(Result);
end;

function ParamTypeOf(AParameter: TRpClientSqlParameter): TRpParamType;
begin
  if AParameter.HasDbType then
  begin
    case AParameter.DbType of
      DBTYPE_BOOLEAN_:
        Exit(rpParamBool);
      DBTYPE_BYTE_, DBTYPE_SBYTE, DBTYPE_INT16, DBTYPE_INT32_, DBTYPE_INT64,
      DBTYPE_UINT16, DBTYPE_UINT32, DBTYPE_UINT64:
        Exit(rpParamInteger);
      DBTYPE_CURRENCY_, DBTYPE_DECIMAL, DBTYPE_VARNUMERIC:
        Exit(rpParamCurrency);
      DBTYPE_DOUBLE_, DBTYPE_SINGLE:
        Exit(rpParamDouble);
      DBTYPE_DATE_:
        Exit(rpParamDate);
      DBTYPE_TIME_:
        Exit(rpParamTime);
      DBTYPE_DATETIME_, DBTYPE_DATETIME2, DBTYPE_DATETIMEOFFSET:
        Exit(rpParamDateTime);
    end;
  end;
  case VarType(AParameter.Value) of
    varBoolean:
      Result := rpParamBool;
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord,
    varInt64:
      Result := rpParamInteger;
    varSingle, varDouble:
      Result := rpParamDouble;
    varCurrency:
      Result := rpParamCurrency;
    varDate:
      Result := rpParamDateTime;
  else
    Result := rpParamString;
  end;
end;

// "2024-01-31", "2024-01-31T10:20:30", "2024-01-31 10:20", "10:20:30"
function TryIsoDateTime(const AText: string; out AValue: TDateTime): Boolean;
var
  LText: string;
  LYear, LMonth, LDay, LHour, LMinute, LSecond: Integer;
  LDate, LTime: TDateTime;
begin
  Result := False;
  LText := Trim(AText);
  LDate := 0;
  LTime := 0;
  if (Length(LText) >= 10) and (LText[5] = '-') and (LText[8] = '-') then
  begin
    LYear := StrToIntDef(Copy(LText, 1, 4), -1);
    LMonth := StrToIntDef(Copy(LText, 6, 2), -1);
    LDay := StrToIntDef(Copy(LText, 9, 2), -1);
    if not TryEncodeDate(LYear, LMonth, LDay, LDate) then
      Exit;
    LText := Trim(Copy(LText, 12, MaxInt));
  end
  else if not ((Length(LText) >= 5) and (LText[3] = ':')) then
    Exit;
  if (Length(LText) >= 5) and (LText[3] = ':') then
  begin
    LHour := StrToIntDef(Copy(LText, 1, 2), -1);
    LMinute := StrToIntDef(Copy(LText, 4, 2), -1);
    LSecond := 0;
    if (Length(LText) >= 8) and (LText[6] = ':') then
      LSecond := StrToIntDef(Copy(LText, 7, 2), -1);
    if not TryEncodeTime(LHour, LMinute, LSecond, 0, LTime) then
      Exit;
  end;
  AValue := LDate + LTime;
  Result := True;
end;

function InvariantFloat(const AText: string; out AValue: Double): Boolean;
var
  LFormat: TFormatSettings;
begin
  LFormat := FormatSettings;
  LFormat.DecimalSeparator := '.';
  LFormat.ThousandSeparator := ',';
  Result := SysUtils.TryStrToFloat(Trim(AText), AValue, LFormat);
end;

// The value of the AI as the type of the parameter (as it came when it does
// not convert)
function ParamValueOf(const AValue: Variant; AType: TRpParamType): Variant;
var
  LDate: TDateTime;
  LDouble: Double;
  LInt: Int64;
  LText: string;
begin
  Result := AValue;
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit(Null);
  LText := VarToStr(AValue);
  case AType of
    rpParamBool:
      if VarType(AValue) <> varBoolean then
        Result := SameText(LText, 'true') or (LText = '1');
    rpParamInteger:
      if TryStrToInt64(Trim(LText), LInt) then
        Result := LInt
      else if InvariantFloat(LText, LDouble) then
        Result := LDouble;
    rpParamDouble:
      if VarIsStr(AValue) then
      begin
        if InvariantFloat(LText, LDouble) then
          Result := LDouble;
      end;
    rpParamCurrency:
      if VarIsStr(AValue) then
      begin
        if InvariantFloat(LText, LDouble) then
          Result := Currency(LDouble);
      end
      else
      begin
        // In two steps: FPC 3.2.2 on x86_64 stops with an internal error
        // (2009112507) on Currency(Double(<variant>))
        LDouble := AValue;
        Result := Currency(LDouble);
      end;
    rpParamDate, rpParamTime, rpParamDateTime:
      if VarType(AValue) <> varDate then
      begin
        if TryIsoDateTime(LText, LDate) then
          Result := LDate;
      end;
  end;
end;

// The parameter as the cloud leaves it when it applies the dataset: the
// report's one of that name now also feeds the probe; a new one is created
// with the AI's value (DatasetColumnsCache.LinkParameter of the web designer)
procedure LinkParameter(AReport: TRpReport; const ADatasetAlias: string;
  AParameter: TRpClientSqlParameter);
var
  LName: string;
  LParam: TRpParam;
  LType: TRpParamType;
  LValue: Variant;
begin
  LName := NormalizeParamName(AParameter.Name);
  if LName = '' then
    Exit;
  LParam := AReport.Params.FindParam(LName);
  if LParam <> nil then
  begin
    if LParam.Datasets.IndexOf(ADatasetAlias) < 0 then
      LParam.Datasets.Add(ADatasetAlias);
    Exit;
  end;
  LType := ParamTypeOf(AParameter);
  LValue := ParamValueOf(AParameter.Value, LType);
  LParam := AReport.Params.Add(LName);
  LParam.ParamType := LType;
  LParam.Value := LValue;
  LParam.LastValue := LValue;
  LParam.Datasets.Add(ADatasetAlias);
end;

// The values the parameters take before the datasets open, as the design
// context of the designer (TRpBaseReport.PrepareLiveContext) without opening
// the other datasets
procedure PrepareParams(AReport: TRpReport);
var
  I: Integer;
  LName: string;
  LParam: TRpParam;
begin
  AReport.InitEvaluator;
  AReport.AddReportItemsToEvaluator(AReport.Evaluator);
  for I := 0 to AReport.Params.Count - 1 do
  begin
    LParam := AReport.Params.Items[I];
    if LParam.ParamType = rpParamExpreB then
    begin
      LName := LParam.Name;
      try
        if not VarIsNull(LParam.Value) then
        begin
          AReport.Evaluator.EvaluateText(LName + ':=(' + String(LParam.Value) + ')');
          LParam.LastValue := AReport.Evaluator.EvaluateText(LName);
        end;
      except
        on E: Exception do
          raise Exception.Create(E.Message + ' - ' + LName);
      end;
    end
    else
      LParam.LastValue := LParam.ListValue;
  end;
end;

{ The SQL of the AI never changes data }

function IsWordChar(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_', '$']) or (Ord(C) > 127);
end;

function RpCheckClientSql(const ASql: string; out AReason: string): Boolean;
const
  CWriteWords: array[0..18] of string = ('INSERT', 'UPDATE', 'DELETE', 'MERGE',
    'DROP', 'ALTER', 'CREATE', 'TRUNCATE', 'GRANT', 'REVOKE', 'EXEC',
    'EXECUTE', 'CALL', 'INTO', 'GEN_ID', 'NEXTVAL', 'SETVAL', 'UPSERT',
    'DBLINK_EXEC');
var
  C, LQuote: Char;
  I, J, LLength, LStart: Integer;
  LAfterSemicolon: Boolean;
  LFirst, LPrevious, LWord: string;
begin
  AReason := '';
  LFirst := '';
  LPrevious := '';
  LAfterSemicolon := False;
  LLength := Length(ASql);
  I := 1;
  while (I <= LLength) and (AReason = '') do
  begin
    C := ASql[I];
    // Comments: -- to the end of the line and /* */
    if (C = '-') and (I < LLength) and (ASql[I + 1] = '-') then
    begin
      while (I <= LLength) and not CharInSet(ASql[I], [#10, #13]) do
        Inc(I);
      Continue;
    end;
    if (C = '/') and (I < LLength) and (ASql[I + 1] = '*') then
    begin
      Inc(I, 2);
      while (I < LLength) and not ((ASql[I] = '*') and (ASql[I + 1] = '/')) do
        Inc(I);
      if I >= LLength then
        AReason := 'a comment is not closed';
      Inc(I, 2);
      Continue;
    end;
    // String literals and quoted names (a doubled quote is the quote)
    if CharInSet(C, ['''', '"', '`']) then
    begin
      if LAfterSemicolon then
        AReason := 'it has more than one statement';
      LQuote := C;
      Inc(I);
      while True do
      begin
        if I > LLength then
        begin
          AReason := 'a string or a quoted name is not closed';
          Break;
        end;
        if ASql[I] = LQuote then
        begin
          if (I < LLength) and (ASql[I + 1] = LQuote) then
            Inc(I, 2)
          else
          begin
            Inc(I);
            Break;
          end;
        end
        else
          Inc(I);
      end;
      if LFirst = '' then
        LFirst := '?';
      LPrevious := '';
      Continue;
    end;
    if IsWordChar(C) then
    begin
      LStart := I;
      while (I <= LLength) and IsWordChar(ASql[I]) do
        Inc(I);
      LWord := UpperCase(Copy(ASql, LStart, I - LStart));
      if LAfterSemicolon then
      begin
        AReason := 'it has more than one statement';
        Break;
      end;
      if LFirst = '' then
        LFirst := LWord;
      for J := Low(CWriteWords) to High(CWriteWords) do
        if LWord = CWriteWords[J] then
          AReason := 'it contains ' + LWord;
      if (LPrevious = 'NEXT') and (LWord = 'VALUE') then
        AReason := 'it contains NEXT VALUE';
      LPrevious := LWord;
      Continue;
    end;
    if C = ';' then
      LAfterSemicolon := True
    else if not CharInSet(C, [' ', #9, #10, #13]) then
    begin
      if LAfterSemicolon then
        AReason := 'it has more than one statement'
      else if (LFirst = '') and (C <> '(') then
        LFirst := '?';
    end;
    Inc(I);
  end;
  if (AReason = '') and (LFirst = '') then
    AReason := 'it is empty';
  if (AReason = '') and (LFirst <> 'SELECT') and (LFirst <> 'WITH') then
    AReason := 'it does not start with SELECT or WITH';
  Result := AReason = '';
  if not Result then
    AReason := 'Only one SELECT (or WITH ... SELECT) statement that does not ' +
      'change data can be run to read the columns of a dataset: ' + AReason + '.';
end;

// The type of a column for the cloud: string, integer, float, currency,
// datetime, boolean or blob
function ClientTypeOf(AType: TFieldType): string;
begin
  case AType of
    ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint
{$IFNDEF FPC}, ftShortint, ftByte, ftLongWord{$ENDIF}:
      Result := 'integer';
    ftCurrency:
      Result := 'currency';
    ftFloat, ftBCD, ftFMTBcd{$IFNDEF FPC}, ftExtended, ftSingle{$ENDIF}:
      Result := 'float';
    ftBoolean:
      Result := 'boolean';
    ftDate, ftTime, ftDateTime, ftTimeStamp{$IFNDEF FPC}, ftTimeStampOffset{$ENDIF}:
      Result := 'datetime';
    ftBlob, ftGraphic, ftBytes, ftVarBytes, ftTypedBinary, ftOraBlob:
      Result := 'blob';
  else
    Result := 'string';
  end;
end;

function ClientSizeOf(AType: TFieldType; ASize: Integer): Integer;
begin
  Result := 0;
  if AType in [ftString, ftWideString, ftFixedChar
{$IFNDEF FPC}, ftFixedWideChar{$ENDIF}] then
    Result := ASize;
end;

// The SQL the dataset opens: the substitution parameters replaced, as
// TRpDataInfoItem.Connect does
function FinalSql(AReport: TRpReport; AItem: TRpDataInfoItem): string;
var
  I: Integer;
  LParam: TRpParam;
begin
  Result := AItem.SQL;
  for I := 0 to AReport.Params.Count - 1 do
  begin
    LParam := AReport.Params.Items[I];
    if not (LParam.ParamType in [rpParamSubst, rpParamSubstE, rpParamSubstList,
      rpParamMultiple]) then
      Continue;
    if (LParam.Datasets.IndexOf(AItem.Alias) < 0) or (LParam.Search = '') then
      Continue;
    if LParam.ParamType in [rpParamSubstE, rpParamSubstList] then
      Result := StringReplace(Result, LParam.Search, VarToStr(LParam.LastValue),
        [rfReplaceAll, rfIgnoreCase])
    else
      Result := StringReplace(Result, LParam.Search, VarToStr(LParam.Value),
        [rfReplaceAll, rfIgnoreCase]);
  end;
end;

function DataTypeOfVariant(const AValue: Variant): TFieldType;
begin
{$IFDEF FPC}
  case VarType(AValue) of
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord:
      Result := ftInteger;
    varInt64:
      Result := ftLargeint;
    varSingle, varDouble:
      Result := ftFloat;
    varCurrency:
      Result := ftCurrency;
    varDate:
      Result := ftDateTime;
    varBoolean:
      Result := ftBoolean;
  else
    Result := ftString;
  end;
{$ELSE}
  Result := VarTypeToDataType(VarType(AValue));
  if Result = ftUnknown then
    Result := ftString;
{$ENDIF}
end;

{$IFDEF FPC}
// The parameters of the report that feed the dataset, with the type and the
// value the engine gives them when it opens it
procedure AssignQueryParams(AReport: TRpReport; AItem: TRpDataInfoItem;
  AParams: TParams);
var
  I: Integer;
  LParam: TRpParam;
  LQueryParam: TParam;
  LType: TFieldType;
begin
  for I := 0 to AReport.Params.Count - 1 do
  begin
    LParam := AReport.Params.Items[I];
    if LParam.ParamType in [rpParamSubst, rpParamSubstE, rpParamSubstList,
      rpParamMultiple] then
      Continue;
    if LParam.Datasets.IndexOf(AItem.Alias) < 0 then
      Continue;
    LType := rpparams.ParamTypeToDataType(LParam.ParamType);
    if (LType = ftUnknown) or (LParam.ParamType = rpParamExpreB) then
      LType := DataTypeOfVariant(LParam.LastValue);
    LQueryParam := AParams.ParamByName(LParam.Name);
    LQueryParam.DataType := LType;
    LQueryParam.Value := LParam.LastValue;
  end;
end;
{$ENDIF}

// Only the field definitions: the statement is prepared, not executed.
// False when the driver can not describe it that way
function DescribeWithoutRows(AReport: TRpReport; AItem: TRpDataInfoItem;
  ADatabase: TRpDatabaseInfoItem; const ASql: string;
  AResult: TRpClientSqlResult): Boolean;
var
  I: Integer;
{$IFDEF FIREDAC}
  LQuery: TFDQuery;
  J: Integer;
  LFDParam: TFDParam;
  LParam: TRpParam;
  LType: TFieldType;
{$ENDIF}
{$IFDEF FPC}
  LQuery: TSQLQuery;
{$ENDIF}
begin
  Result := False;
  if ADatabase.Driver <> rpfiredac then
    Exit;
{$IFDEF FIREDAC}
  if ADatabase.FDConnection = nil then
    Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := ADatabase.FDConnection;
    if ADatabase.FDTransaction <> nil then
      LQuery.Transaction := ADatabase.FDTransaction;
    LQuery.ResourceOptions.PreprocessCmdText := False;
    LQuery.ResourceOptions.ParamCreate := True;
    LQuery.ResourceOptions.ParamExpand := True;
    LQuery.ResourceOptions.MacroCreate := False;
    LQuery.ResourceOptions.MacroExpand := False;
    LQuery.ResourceOptions.EscapeExpand := False;
    LQuery.SQL.Text := ASql;
    // TFDParams is not a TParams: as AssignQueryParams
    for J := 0 to AReport.Params.Count - 1 do
    begin
      LParam := AReport.Params.Items[J];
      if (LParam.ParamType in [rpParamSubst, rpParamSubstE, rpParamSubstList,
        rpParamMultiple]) or (LParam.Datasets.IndexOf(AItem.Alias) < 0) then
        Continue;
      LType := rpparams.ParamTypeToDataType(LParam.ParamType);
      if (LType = ftUnknown) or (LParam.ParamType = rpParamExpreB) then
        LType := DataTypeOfVariant(LParam.LastValue);
      LFDParam := LQuery.ParamByName(LParam.Name);
      LFDParam.DataType := LType;
      LFDParam.Value := LParam.LastValue;
    end;
    LQuery.Prepare;
    LQuery.FieldDefs.Update;
    for I := 0 to LQuery.FieldDefs.Count - 1 do
      AResult.AddColumn(LQuery.FieldDefs[I].Name,
        ClientTypeOf(LQuery.FieldDefs[I].DataType),
        ClientSizeOf(LQuery.FieldDefs[I].DataType, LQuery.FieldDefs[I].Size));
    Result := LQuery.FieldDefs.Count > 0;
    LQuery.Unprepare;
  finally
    LQuery.Free;
  end;
{$ENDIF}
{$IFDEF FPC}
  if ADatabase.SQLDBConnection = nil then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := ADatabase.SQLDBConnection;
    LQuery.Transaction := ADatabase.SQLDBTransaction;
    LQuery.SQL.Text := ASql;
    AssignQueryParams(AReport, AItem, LQuery.Params);
    LQuery.Prepare;
    LQuery.FieldDefs.Update;
    for I := 0 to LQuery.FieldDefs.Count - 1 do
      AResult.AddColumn(LQuery.FieldDefs[I].Name,
        ClientTypeOf(LQuery.FieldDefs[I].DataType),
        ClientSizeOf(LQuery.FieldDefs[I].DataType, LQuery.FieldDefs[I].Size));
    Result := LQuery.FieldDefs.Count > 0;
    LQuery.UnPrepare;
  finally
    LQuery.Free;
  end;
{$ENDIF}
  if not Result then
    AResult.Columns.Clear;
end;

// The transaction of the probe: started now (read only where the driver
// has it), always rolled back by RollbackProbeTransaction
procedure BeginProbeTransaction(ADatabase: TRpDatabaseInfoItem);
begin
  case ADatabase.Driver of
    rpfiredac:
      begin
{$IFDEF FIREDAC}
        if ADatabase.FDTransaction <> nil then
        begin
          if ADatabase.FDTransaction.Active then
            ADatabase.FDTransaction.Rollback;
          ADatabase.FDTransaction.Options.DisconnectAction := xdRollback;
          ADatabase.FDTransaction.Options.ReadOnly := True;
          try
            ADatabase.FDTransaction.StartTransaction;
          except
            // A server without read only transactions
            ADatabase.FDTransaction.Options.ReadOnly := False;
            ADatabase.FDTransaction.StartTransaction;
          end;
        end;
        // When it has to open the dataset, no rows are fetched
        if ADatabase.FDConnection <> nil then
          ADatabase.FDConnection.FetchOptions.Mode := fmManual;
{$ENDIF}
{$IFDEF FPC}
        if (ADatabase.SQLDBTransaction <> nil) and
          not ADatabase.SQLDBTransaction.Active then
          ADatabase.SQLDBTransaction.StartTransaction;
{$ENDIF}
      end;
    rpdataibx:
      begin
{$IFDEF USEIBX}
        if (ADatabase.IBTransaction <> nil) and
          not ADatabase.IBTransaction.InTransaction then
          ADatabase.IBTransaction.StartTransaction;
{$ENDIF}
      end;
    rpdatazeos:
      begin
{$IFDEF USEZEOS}
        if (ADatabase.ZConnection <> nil) and
          not ADatabase.ZConnection.InTransaction then
          ADatabase.ZConnection.StartTransaction;
{$ENDIF}
      end;
    rpdataado:
      begin
{$IFDEF USEADO}
        if not ADatabase.ADOConnection.InTransaction then
          ADatabase.ADOConnection.BeginTrans;
{$ENDIF}
      end;
  end;
end;

procedure RollbackProbeTransaction(ADatabase: TRpDatabaseInfoItem);
begin
  case ADatabase.Driver of
    rpfiredac:
      begin
{$IFDEF FIREDAC}
        if (ADatabase.FDTransaction <> nil) and ADatabase.FDTransaction.Active then
          ADatabase.FDTransaction.Rollback;
{$ENDIF}
{$IFDEF FPC}
        if (ADatabase.SQLDBTransaction <> nil) and ADatabase.SQLDBTransaction.Active then
          ADatabase.SQLDBTransaction.Rollback;
{$ENDIF}
      end;
    rpdataibx:
      begin
{$IFDEF USEIBX}
        if (ADatabase.IBTransaction <> nil) and ADatabase.IBTransaction.InTransaction then
          ADatabase.IBTransaction.Rollback;
{$ENDIF}
      end;
    rpdatazeos:
      begin
{$IFDEF USEZEOS}
        if (ADatabase.ZConnection <> nil) and ADatabase.ZConnection.InTransaction then
          ADatabase.ZConnection.Rollback;
{$ENDIF}
      end;
    rpdataado:
      begin
{$IFDEF USEADO}
        if ADatabase.ADOConnection.InTransaction then
          ADatabase.ADOConnection.RollbackTrans;
{$ENDIF}
      end;
  end;
end;

procedure ProbeColumns(AReport: TRpReport; ARequest: TRpClientSqlRequest;
  AResult: TRpClientSqlResult);
var
  I, LIndex: Integer;
  LAlias, LReason, LSql: string;
  LDatabase: TRpDatabaseInfoItem;
  LDataset: TDataSet;
  LItem: TRpDataInfoItem;
{$IFDEF MSWINDOWS}
  LComInitialized: Boolean;
{$ENDIF}
begin
  if Trim(ARequest.Sql) = '' then
    raise Exception.Create('The dataset has no SQL');
  if not RpCheckClientSql(ARequest.Sql, LReason) then
    raise Exception.Create(LReason);
  LIndex := AReport.DatabaseInfo.IndexOf(ARequest.DatabaseAlias);
  if LIndex < 0 then
    raise Exception.Create('The report has no connection ' + ARequest.DatabaseAlias);
  LDatabase := AReport.DatabaseInfo.Items[LIndex];
  LAlias := 'COPILOT_PROBE';
  I := 1;
  while AReport.DataInfo.IndexOf(LAlias) >= 0 do
  begin
    LAlias := 'COPILOT_PROBE' + IntToStr(I);
    Inc(I);
  end;
  LItem := AReport.DataInfo.Add(LAlias);
  LItem.DatabaseAlias := ARequest.DatabaseAlias;
  LItem.SQL := ARequest.Sql;
  for I := 0 to ARequest.Parameters.Count - 1 do
    LinkParameter(AReport, LItem.Alias,
      TRpClientSqlParameter(ARequest.Parameters[I]));
  PrepareParams(AReport);
  LIndex := AReport.DataInfo.IndexOf(LItem.Alias);
  TRpBaseReportAccess(TRpBaseReport(AReport)).UpdateParamsBeforeOpen(LIndex, True);
  // The text the database receives (the substitution parameters of the
  // report replaced) passes the same check
  LSql := FinalSql(AReport, LItem);
  if not RpCheckClientSql(LSql, LReason) then
    raise Exception.Create(LReason);
{$IFDEF MSWINDOWS}
  // ADO in the worker thread of the chat
  LComInitialized := (LDatabase.Driver = rpdataado) and Succeeded(CoInitialize(nil));
{$ENDIF}
  try
    try
      LDatabase.Connect(AReport.Params);
      BeginProbeTransaction(LDatabase);
      try
        AResult.Columns.Clear;
        if not DescribeWithoutRows(AReport, LItem, LDatabase, LSql, AResult) then
        begin
          LItem.Connect(AReport.DatabaseInfo, AReport.Params);
          LDataset := LItem.Dataset;
          if LDataset = nil then
            raise Exception.Create('The dataset did not open');
          for I := 0 to LDataset.FieldCount - 1 do
            AResult.AddColumn(LDataset.Fields[I].FieldName,
              ClientTypeOf(LDataset.Fields[I].DataType),
              ClientSizeOf(LDataset.Fields[I].DataType, LDataset.Fields[I].Size));
        end;
      finally
        // Never committed: the engine commits an active transaction when
        // it disconnects
        try
          LItem.Disconnect;
        finally
          RollbackProbeTransaction(LDatabase);
        end;
      end;
    finally
      AReport.DeActivateDatasets;
    end;
  finally
{$IFDEF MSWINDOWS}
    if LComInitialized then
      CoUninitialize;
{$ENDIF}
  end;
end;

function RpProbeClientSql(AReport: TRpReport;
  ARequest: TRpClientSqlRequest): TRpClientSqlResult;
begin
  Result := TRpClientSqlResult.Create;
  Result.Id := ARequest.Id;
  try
    ProbeColumns(AReport, ARequest, Result);
    Result.Success := True;
    Result.ErrorMessage := '';
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Columns.Clear;
      Result.ErrorMessage := Trim(E.Message);
      if Result.ErrorMessage = '' then
        Result.ErrorMessage := E.ClassName;
    end;
  end;
end;

function RpProbeClientSql(const AReportDocument: string;
  ARequest: TRpClientSqlRequest): TRpClientSqlResult;
var
  LReport: TRpReport;
begin
  try
    LReport := RpLoadReportDocument(AReportDocument);
  except
    on E: Exception do
    begin
      Result := TRpClientSqlResult.Create;
      Result.Id := ARequest.Id;
      Result.Success := False;
      Result.ErrorMessage := 'The report document could not be loaded: ' + E.Message;
      Exit;
    end;
  end;
  try
    Result := RpProbeClientSql(LReport, ARequest);
  finally
    LReport.Free;
  end;
end;

{ The inline schema }

procedure RpResolveLocalSchemaConfig(AConfig: TRpApiDatabaseConfig;
  AReport: TRpReport);
var
  LIndex: Integer;
begin
  if (AConfig = nil) or (Trim(AConfig.LocalAlias) = '') or
    AConfig.HasInlineSchema then
    Exit;
  LIndex := AReport.DatabaseInfo.IndexOf(AConfig.LocalAlias);
  if LIndex < 0 then
    raise Exception.Create('The report has no connection ' + AConfig.LocalAlias);
  RpResolveLocalSchemaConfig(AConfig, AReport.DatabaseInfo.Items[LIndex],
    AReport.Params);
end;

procedure RpResolveLocalSchemaConfig(AConfig: TRpApiDatabaseConfig;
  ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList);
var
  LDatabase: TRpDatabaseInfoItem;
  LFile: TRpLocalSchemaFile;
  LSchemaName, LTables: string;
begin
  if (AConfig = nil) or (ADatabase = nil) or AConfig.HasInlineSchema then
    Exit;
  LDatabase := ADatabase;
  // No subschema chosen: nothing to read (the file is not even generated)
  if Trim(AConfig.LocalSchemaName) = '' then
    raise Exception.Create(RpSubSchemaRequiredMessage(LDatabase.Alias));
  try
    LFile := RpLoadLocalSchema(LDatabase, AParams, True, False);
  finally
    LDatabase.DisConnect;
  end;
  try
    // The subschema travels with its tables (the cloud gives it to the
    // datasets it makes); one gone from the file raises, it never sends the
    // whole dictionary
    LTables := RpSubSchemaTablesJson(LFile, LDatabase.Alias,
      AConfig.LocalSchemaName, LSchemaName);
    AConfig.Name := LDatabase.Alias;
    AConfig.Dialect := LFile.CloudDialect;
    AConfig.SchemaTablesJson := LTables;
    AConfig.SchemaName := LSchemaName;
    // A schema without tables would not be usable: the cloud says why
    AConfig.HubDatabaseId := 0;
    AConfig.HubSchemaId := 0;
  finally
    LFile.Free;
  end;
end;

procedure RpResolveLocalSchemaConfig(AConfig: TRpApiDatabaseConfig;
  const AReportDocument: string);
var
  LReport: TRpReport;
begin
  if (AConfig = nil) or (Trim(AConfig.LocalAlias) = '') or
    AConfig.HasInlineSchema then
    Exit;
  LReport := RpLoadReportDocument(AReportDocument);
  try
    RpResolveLocalSchemaConfig(AConfig, LReport);
  finally
    LReport.Free;
  end;
end;

{ The turns }

procedure Progress(Sender: TObject; AOnProgress: TRpExpressionStreamProgressEvent;
  const AText: string);
begin
  if Assigned(AOnProgress) then
    AOnProgress(Sender, 'System', 'SendingRequest', 'Full', AText, 0, 0, '', 0);
end;

function RpModifyReportWithClientSql(AHttp: TRpDatabaseHttp;
  ARequest: TRpApiModifyReportRequest; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TRpApiModifyReportResult;
var
  I, LTurn: Integer;
  LAnswer: TRpClientSqlResult;
  LNames, LOriginalDocument, LSentDocument: string;
  LRequest: TRpApiModifyReportRequest;
  LSqlRequest: TRpClientSqlRequest;
  LSteps: TObjectList;
  LWaiting: TRpModifyReportResult;
  LCredits: Integer;
  LHasCredits: Boolean;
begin
  ARequest.ClientExecutesSql := True;
  LCredits := 0;
  LHasCredits := False;
  if (Trim(ARequest.Config.LocalAlias) <> '') and
    not ARequest.Config.HasInlineSchema then
  begin
    Progress(Sender, AOnProgress, Format(TranslateStr(1980,
      'Reading the schema of the connection %s'), [ARequest.Config.LocalAlias]));
    RpResolveLocalSchemaConfig(ARequest.Config, ARequest.ReportDocument);
  end;
  LOriginalDocument := ARequest.ReportDocument;
  LSentDocument := LOriginalDocument;
  LRequest := nil;
  LSteps := TObjectList.Create(True);
  try
    Result := AHttp.ModifyReport(ARequest, Sender, AOnProgress, ACancel);
    LTurn := 0;
    while (Result <> nil) and (Trim(Result.ErrorMessage) = '') and
      Result.ResultData.NeedsClientSqlResults do
    begin
      if Assigned(ACancel) and ACancel(Sender) then
      begin
        FreeAndNil(Result);
        Exit;
      end;
      Inc(LTurn);
      if LTurn > RP_MAX_CLIENT_SQL_TURNS then
        Break;
      // The tokens of every turn are reported at the end, and the credits
      // charged for each one
      while Result.Steps.Count > 0 do
        LSteps.Add(Result.Steps.Extract(Result.Steps[0]));
      if Result.HasCreditsConsumed then
      begin
        LHasCredits := True;
        Inc(LCredits, Result.CreditsConsumed);
      end;
      LWaiting := Result.ResultData;
      if Trim(LWaiting.ModifiedReportDocument) <> '' then
        LSentDocument := LWaiting.ModifiedReportDocument;
      if LRequest = nil then
      begin
        LRequest := TRpApiModifyReportRequest.Create;
        LRequest.Assign(ARequest);
      end;
      LRequest.ClientSqlResults.Clear;
      LNames := '';
      for I := 0 to LWaiting.ClientSqlRequests.Count - 1 do
      begin
        LSqlRequest := TRpClientSqlRequest(LWaiting.ClientSqlRequests[I]);
        if LNames <> '' then
          LNames := LNames + ', ';
        if LSqlRequest.DatasetAlias <> '' then
          LNames := LNames + LSqlRequest.DatasetAlias
        else
          LNames := LNames + LSqlRequest.DatabaseAlias;
      end;
      Progress(Sender, AOnProgress, Format(TranslateStr(1981,
        'Running the SQL on the connection of the report: %s'), [LNames]));
      for I := 0 to LWaiting.ClientSqlRequests.Count - 1 do
      begin
        LSqlRequest := TRpClientSqlRequest(LWaiting.ClientSqlRequests[I]);
        LAnswer := RpProbeClientSql(LSentDocument, LSqlRequest);
        LRequest.ClientSqlResults.Add(LAnswer);
        if LAnswer.Success then
          Progress(Sender, AOnProgress, Format(TranslateStr(1982, '%s: %s columns'),
            [LSqlRequest.DatasetAlias, IntToStr(LAnswer.Columns.Count)]))
        else
          Progress(Sender, AOnProgress, LSqlRequest.DatasetAlias + ': ' +
            LAnswer.ErrorMessage);
      end;
      LRequest.ReportDocument := LSentDocument;
      LRequest.ExistingContextJson := LWaiting.WorkingContextJson;
      LRequest.Continuation := LWaiting.Continuation;
      FreeAndNil(Result);
      Result := AHttp.ModifyReport(LRequest, Sender, AOnProgress, ACancel);
    end;
    if Result = nil then
      Exit;
    for I := LSteps.Count - 1 downto 0 do
      Result.Steps.Insert(0, LSteps.Extract(LSteps[I]));
    if LHasCredits then
    begin
      Result.CreditsConsumed := Result.CreditsConsumed + LCredits;
      Result.HasCreditsConsumed := True;
    end;
    if (Trim(Result.ErrorMessage) = '') and Result.ResultData.NeedsClientSqlResults then
    begin
      Result.ResultData.ErrorMessage := TranslateStr(1983,
        'The assistant asked to run SQL too many times: the request was stopped.');
      Result.ResultData.ModifiedReportDocument := '';
    end
    else if (Trim(Result.ErrorMessage) = '') and Result.ResultData.Success and
      (Trim(Result.ResultData.ModifiedReportDocument) = '') and
      (LSentDocument <> LOriginalDocument) then
      // After turns an empty document is the last one sent: it carries the
      // datasets made on the way
      Result.ResultData.ModifiedReportDocument := LSentDocument;
  finally
    LSteps.Free;
    LRequest.Free;
  end;
end;

{ Generate with AI }

procedure TRpSchemaGenerationRequest.Assign(Source: TPersistent);
var
  LSource: TRpSchemaGenerationRequest;
begin
  if Source is TRpSchemaGenerationRequest then
  begin
    LSource := TRpSchemaGenerationRequest(Source);
    FDomain := LSource.Domain;
    FSchemaName := LSource.SchemaName;
    FAITier := LSource.AITier;
    FAIMode := LSource.AIMode;
    FAgentSecret := LSource.AgentSecret;
    FAgentAiId := LSource.AgentAiId;
    FLanguageIso := LSource.LanguageIso;
  end
  else
    inherited Assign(Source);
end;

function JsonValueText(AObject: TJSONObject; const AName: string): string;
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

function JsonValueInt(AObject: TJSONObject; const AName: string): Integer;
begin
  Result := StrToIntDef(JsonValueText(AObject, AName), 0);
end;

function JsonObjectOf(AObject: TJSONObject; const AName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  LValue := AObject.Values[AName];
  if LValue is TJSONObject then
    Result := TJSONObject(LValue);
end;

function JsonArrayOf(AObject: TJSONObject; const AName: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  LValue := AObject.Values[AName];
  if LValue is TJSONArray then
    Result := TJSONArray(LValue);
end;

// A pair replaced (or added)
procedure PutPair(AObject: TJSONObject; const AName: string; AValue: TJSONValue);
var
  LPair: TJSONPair;
begin
  LPair := AObject.RemovePair(AName);
  LPair.Free;
  AObject.AddPair(AName, AValue);
end;

procedure RemoveJsonPair(AObject: TJSONObject; const AName: string);
var
  LPair: TJSONPair;
begin
  LPair := AObject.RemovePair(AName);
  LPair.Free;
end;

// The names of a request as the catalog spells them (one it does not have
// as it came: its read gives nothing)
procedure SpellTables(AArray: TJSONArray; ACatalog, ASpelled: TStrings);
var
  I, LIndex: Integer;
  LName: string;
begin
  ASpelled.Clear;
  if AArray = nil then
    Exit;
  for I := 0 to AArray.Count - 1 do
  begin
    LName := Trim(AArray.Items[I].Value);
    if LName = '' then
      Continue;
    LIndex := ACatalog.IndexOf(LName);
    if LIndex >= 0 then
      LName := ACatalog[LIndex];
    ASpelled.Add(LName);
  end;
end;

// 'NUMERIC(18,2)': NUMERIC, 18 and 2
procedure SplitDeclaredType(const AType: string; out ABase: string;
  out AFirst, ASecond: Integer);
var
  LClose, LComma, LOpen: Integer;
  LInside: string;
begin
  ABase := UpperCase(Trim(AType));
  AFirst := 0;
  ASecond := 0;
  LOpen := Pos('(', ABase);
  if LOpen <= 0 then
    Exit;
  LClose := Pos(')', ABase);
  if LClose < LOpen then
    LClose := Length(ABase) + 1;
  LInside := Copy(ABase, LOpen + 1, LClose - LOpen - 1);
  ABase := Trim(Copy(ABase, 1, LOpen - 1));
  LComma := Pos(',', LInside);
  if LComma > 0 then
  begin
    AFirst := StrToIntDef(Trim(Copy(LInside, 1, LComma - 1)), 0);
    ASecond := StrToIntDef(Trim(Copy(LInside, LComma + 1, MaxInt)), 0);
  end
  else
    AFirst := StrToIntDef(Trim(LInside), 0);
end;

// The .NET type of a column of the catalog (the cloud's dataType and the
// declared type), as an ADO.NET reader would say it
function NetTypeOf(const ACloudType, ABase: string): string;

  function Has(const APart: string): Boolean;
  begin
    Result := Pos(APart, ABase) > 0;
  end;

begin
  if SameText(ACloudType, 'Integer') then
  begin
    if Has('BIGINT') or Has('INT64') or Has('INT128') or (ABase = 'INT8') or
      Has('BIGSERIAL') or (ABase = 'NUMBER') then
      Result := 'System.Int64'
    else if Has('SMALLINT') or (ABase = 'INT2') or Has('SMALLSERIAL') then
      Result := 'System.Int16'
    else if Has('TINYINT') then
      Result := 'System.Byte'
    else
      Result := 'System.Int32';
  end
  else if SameText(ACloudType, 'Numeric') then
  begin
    if Has('DOUBLE') or Has('FLOAT8') or Has('BINARY_DOUBLE') then
      Result := 'System.Double'
    else if Has('FLOAT') or Has('REAL') or Has('BINARY_FLOAT') then
      Result := 'System.Single'
    else
      Result := 'System.Decimal';
  end
  else if SameText(ACloudType, 'Currency') then
    Result := 'System.Decimal'
  else if SameText(ACloudType, 'Date') then
    Result := 'System.DateTime'
  else if SameText(ACloudType, 'TimeStamp') then
  begin
    if (Copy(ABase, 1, 4) = 'TIME') and (Copy(ABase, 1, 9) <> 'TIMESTAMP') then
      Result := 'System.TimeSpan'
    else
      Result := 'System.DateTime';
  end
  else if SameText(ACloudType, 'Boolean') then
    Result := 'System.Boolean'
  else if SameText(ACloudType, 'TextLong') then
    Result := 'System.String'
  else if Has('BLOB') or Has('BINARY') or Has('BYTEA') or Has('IMAGE') or
    Has('RAW') then
    Result := 'System.Byte[]'
  else
    Result := 'System.String';
end;

// A column of the catalog (the format of the schema file) as the cloud's
// DiscoveredColumn
function DiscoveredColumnJson(AColumn: TJSONObject; APosition: Integer): TJSONObject;
var
  LBase, LCloudType, LDeclared: string;
  LFirst, LSecond: Integer;
begin
  LCloudType := JsonValueText(AColumn, 'dataType');
  LDeclared := JsonValueText(AColumn, 'detectedType');
  SplitDeclaredType(LDeclared, LBase, LFirst, LSecond);
  Result := TJSONObject.Create;
  Result.AddPair('name', JsonValueText(AColumn, 'name'));
  Result.AddPair('isPrimaryKey', TJSONBool.Create(SameText(
    JsonValueText(AColumn, 'isPrimaryKey'), 'true')));
  Result.AddPair('detectedNetType', NetTypeOf(LCloudType, LBase));
  Result.AddPair('declaredDbType', LDeclared);
  Result.AddPair('ordinalPosition', TJSONNumber.Create(APosition));
  if SameText(LCloudType, 'Numeric') or SameText(LCloudType, 'Currency') or
    SameText(LCloudType, 'Integer') then
  begin
    Result.AddPair('numericPrecision', TJSONNumber.Create(LFirst));
    Result.AddPair('numericScale', TJSONNumber.Create(LSecond));
  end
  else
    Result.AddPair('size', TJSONNumber.Create(LFirst));
end;

// A cell for the AI: numbers and booleans as they are, dates in ISO, a
// BLOB as (BLOB) and long texts cut
function SampleCellJson(AField: TField): TJSONValue;
const
  CMaxText = 300;
var
  LText: string;
  LValue: TDateTime;
begin
  if AField.IsNull then
    Exit(TJSONNull.Create);
  case AField.DataType of
    ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint
{$IFNDEF FPC}, ftShortint, ftByte, ftLongWord{$ENDIF}:
      Result := TJSONNumber.Create(AField.AsLargeInt);
    ftFloat, ftCurrency, ftBCD, ftFMTBcd{$IFNDEF FPC}, ftExtended, ftSingle{$ENDIF}:
      Result := TJSONNumber.Create(AField.AsFloat);
    ftBoolean:
      Result := TJSONBool.Create(AField.AsBoolean);
    ftDate:
      Result := TJSONString.Create(FormatDateTime('yyyy"-"mm"-"dd', AField.AsDateTime));
    ftTime:
      Result := TJSONString.Create(FormatDateTime('hh":"nn":"ss', AField.AsDateTime));
    ftDateTime, ftTimeStamp:
      begin
        LValue := AField.AsDateTime;
        if Frac(LValue) = 0 then
          Result := TJSONString.Create(FormatDateTime('yyyy"-"mm"-"dd', LValue))
        else
          Result := TJSONString.Create(FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', LValue));
      end;
  else
    begin
      if AField.IsBlob and not (AField.DataType in [ftMemo, ftWideMemo, ftFmtMemo]) then
        LText := '(BLOB)'
      else
      begin
        LText := AField.AsString;
        if Length(LText) > CMaxText then
          LText := Copy(LText, 1, CMaxText) + '...';
      end;
      Result := TJSONString.Create(LText);
    end;
  end;
end;

// The first rows of a table with the preview of the local schema screens
// (the dialect of the connection: FIRST, TOP, LIMIT, ROWNUM)
function SampleRowsJson(ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList;
  const ADialect, ATable: string; AMaxRows: Integer): TJSONObject;
var
  I: Integer;
  LColumns, LRow, LRows: TJSONArray;
  LData: TDataSet;
  LMessage: string;
begin
  Result := TJSONObject.Create;
  LColumns := TJSONArray.Create;
  Result.AddPair('columns', LColumns);
  LRows := TJSONArray.Create;
  Result.AddPair('rows', LRows);
  try
    ADatabase.Connect(AParams);
    LData := ADatabase.OpenDatasetFromSQL(RpLocalSchemaPreviewSql(ADialect,
      ATable, AMaxRows), nil, False, AParams);
    try
      for I := 0 to LData.FieldCount - 1 do
        LColumns.Add(LData.Fields[I].FieldName);
      while (not LData.Eof) and (LRows.Count < AMaxRows) do
      begin
        LRow := TJSONArray.Create;
        LRows.AddElement(LRow);
        for I := 0 to LData.FieldCount - 1 do
          LRow.AddElement(SampleCellJson(LData.Fields[I]));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
    on E: Exception do
    begin
      LMessage := Trim(E.Message);
      if LMessage = '' then
        LMessage := E.ClassName;
      Result.AddPair('error', LMessage);
    end;
  end;
end;

function RpAnswerSchemaRequest(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; const ADialect: string; ATableNames: TStrings;
  ARequest: TJSONObject): TJSONObject;
var
  I, J, K, LMaxRows: Integer;
  LAsked, LKind, LMessage, LUnusedDialect: string;
  LCatalog, LSpelled: TStringList;
  LColumns, LRead, LRelations: TJSONArray;
  LByTable, LRows, LTable: TJSONObject;
  LIncoming: Boolean;
  LList: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', JsonValueText(ARequest, 'id'));
  LKind := JsonValueText(ARequest, 'kind');
  LCatalog := TStringList.Create;
  LSpelled := TStringList.Create;
  try
    try
      if ATableNames.Count = 0 then
        RpReadLocalSchemaTableNames(ADatabase, AParams, ATableNames, LUnusedDialect);
      LCatalog.CaseSensitive := False;
      LCatalog.Assign(ATableNames);
      LCatalog.Sorted := True;
      SpellTables(JsonArrayOf(ARequest, 'tables'), LCatalog, LSpelled);
      if SameText(LKind, 'Tables') then
      begin
        LList := TJSONArray.Create;
        Result.AddPair('tables', LList);
        for I := 0 to ATableNames.Count - 1 do
          LList.Add(ATableNames[I]);
      end
      else if SameText(LKind, 'Columns') then
      begin
        LByTable := TJSONObject.Create;
        Result.AddPair('columns', LByTable);
        LRead := RpReadLocalSchemaColumns(ADatabase, AParams, LSpelled);
        try
          // By the name asked, as the cloud looks for it; a table that is not
          // there has no columns
          for I := 0 to LSpelled.Count - 1 do
          begin
            LList := TJSONArray.Create;
            LAsked := LSpelled[I];
            LByTable.AddPair(LAsked, LList);
            for J := 0 to LRead.Count - 1 do
            begin
              if not (LRead.Items[J] is TJSONObject) then
                Continue;
              LTable := TJSONObject(LRead.Items[J]);
              if not SameText(JsonValueText(LTable, 'name'), LAsked) then
                Continue;
              LColumns := JsonArrayOf(LTable, 'columns');
              if LColumns <> nil then
                for K := 0 to LColumns.Count - 1 do
                  if LColumns.Items[K] is TJSONObject then
                    LList.AddElement(DiscoveredColumnJson(
                      TJSONObject(LColumns.Items[K]), K + 1));
              Break;
            end;
          end;
        finally
          LRead.Free;
        end;
      end
      else if SameText(LKind, 'Relations') then
      begin
        LRelations := RpReadLocalSchemaRelations(ADatabase, AParams, LSpelled,
          LIncoming);
        Result.AddPair('relations', LRelations);
        Result.AddPair('includesIncoming', TJSONBool.Create(LIncoming));
      end
      else if SameText(LKind, 'Rows') then
      begin
        LMaxRows := JsonValueInt(ARequest, 'maxRows');
        if (LMaxRows <= 0) or (LMaxRows > RP_SCHEMA_GENERATION_MAX_ROWS) then
          LMaxRows := RP_SCHEMA_GENERATION_MAX_ROWS;
        LRows := TJSONObject.Create;
        Result.AddPair('rows', LRows);
        for I := 0 to LSpelled.Count - 1 do
          LRows.AddPair(LSpelled[I], SampleRowsJson(ADatabase, AParams,
            ADialect, LSpelled[I], LMaxRows));
      end
      else
        raise Exception.Create('Unknown request of the schema generator: ' + LKind);
      Result.AddPair('success', TJSONBool.Create(True));
      Result.AddPair('errorMessage', '');
    except
      on E: Exception do
      begin
        LMessage := Trim(E.Message);
        if LMessage = '' then
          LMessage := E.ClassName;
        RemoveJsonPair(Result, 'tables');
        RemoveJsonPair(Result, 'columns');
        RemoveJsonPair(Result, 'relations');
        RemoveJsonPair(Result, 'includesIncoming');
        RemoveJsonPair(Result, 'rows');
        PutPair(Result, 'success', TJSONBool.Create(False));
        PutPair(Result, 'errorMessage', TJSONString.Create(LMessage));
      end;
    end;
  finally
    LSpelled.Free;
    LCatalog.Free;
  end;
end;

// The DatabaseProvider of the cloud for a dialect of the catalog
function ProviderOfDialect(const ADialect: string;
  ADatabase: TRpDatabaseInfoItem): string;
begin
  if Pos('firebird', LowerCase(ADialect)) = 1 then
    Result := 'Firebird'
  else if SameText(ADialect, 'SQLServer') or SameText(ADialect, 'MySQL') or
    SameText(ADialect, 'PostgreSQL') or SameText(ADialect, 'Oracle') or
    SameText(ADialect, 'SQLite') then
    Result := ADialect
  else if ADatabase.Driver = rpdataado then
    Result := 'OLEDB'
  else
    Result := 'ODBC';
end;

procedure GenerationProgress(Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent; const AText: string);
begin
  if Assigned(AOnProgress) then
    AOnProgress(Sender, 'System', 'ClientRead', 'Full', AText, 0, 0, '', 0);
end;

function RequestsText(ARequests: TJSONArray): string;
var
  I: Integer;
  LRequest: TJSONObject;
  LTables: TJSONArray;
  J: Integer;
  LNames: string;
begin
  Result := '';
  for I := 0 to ARequests.Count - 1 do
  begin
    if not (ARequests.Items[I] is TJSONObject) then
      Continue;
    LRequest := TJSONObject(ARequests.Items[I]);
    LNames := '';
    LTables := JsonArrayOf(LRequest, 'tables');
    if LTables <> nil then
      for J := 0 to LTables.Count - 1 do
      begin
        if LNames <> '' then
          LNames := LNames + ', ';
        LNames := LNames + LTables.Items[J].Value;
      end;
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + JsonValueText(LRequest, 'kind');
    if LNames <> '' then
      Result := Result + ' (' + LNames + ')';
  end;
end;

function RpGenerateSchema(AHttp: TRpDatabaseHttp;
  ARequest: TRpSchemaGenerationRequest; ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TJSONObject;
var
  I, LCall: Integer;
  LAnswers, LInitial, LRequests: TJSONArray;
  LApiKey, LDialect: string;
  LBody, LConfig, LFrame, LResult: TJSONObject;
  LClientMode: Boolean;
  LHubDatabaseId: Int64;
  LNames: TStringList;
begin
  Result := nil;
  if ADatabase = nil then
    raise Exception.Create('No connection');
  if Trim(ARequest.Domain) = '' then
    raise Exception.Create('The domain of the schema is empty');
  // An Agent connection is read by the cloud through the Hub
  LClientMode := ADatabase.Driver <> rpdbHttp;
  LNames := TStringList.Create;
  LBody := TJSONObject.Create;
  try
    if Trim(ARequest.AITier) <> '' then
      LBody.AddPair('aiTier', ARequest.AITier)
    else
      LBody.AddPair('aiTier', 'Standard');
    if SameText(Trim(ARequest.AIMode), 'Reasoning') then
      LBody.AddPair('mode', 'Reasoning')
    else
      LBody.AddPair('mode', 'Fast');
    if ARequest.AgentSecret <> '' then
      LBody.AddPair('agentSecret', ARequest.AgentSecret);
    if ARequest.AgentAiId <> 0 then
      LBody.AddPair('agentAiId', TJSONNumber.Create(ARequest.AgentAiId));
    // The AI of an Agent gets the short prompt, as in the chat
    if SameText(ARequest.AITier, 'LocalAgent') then
      LBody.AddPair('simplifiedPrompt', TJSONBool.Create(True));
    LBody.AddPair('domain', Trim(ARequest.Domain));
    if Trim(ARequest.SchemaName) <> '' then
      LBody.AddPair('schemaName', Trim(ARequest.SchemaName));
    if Trim(ARequest.LanguageIso) <> '' then
      LBody.AddPair('languageCodeIso', Trim(ARequest.LanguageIso));
    LConfig := TJSONObject.Create;
    LBody.AddPair('config', LConfig);
    LConfig.AddPair('name', ADatabase.Alias);
    if LClientMode then
    begin
      // The names go in the first call: the AI does not spend a turn on them
      GenerationProgress(Sender, AOnProgress, 'Reading the tables of ' +
        ADatabase.Alias);
      RpReadLocalSchemaTableNames(ADatabase, AParams, LNames, LDialect);
      GenerationProgress(Sender, AOnProgress, IntToStr(LNames.Count) +
        ' tables, ' + LDialect);
      LConfig.AddPair('provider', ProviderOfDialect(LDialect, ADatabase));
      LConfig.AddPair('dialect', LDialect);
      LBody.AddPair('clientExecutes', TJSONBool.Create(True));
      LInitial := TJSONArray.Create;
      LBody.AddPair('initialTables', LInitial);
      for I := 0 to LNames.Count - 1 do
        LInitial.Add(LNames[I]);
    end
    else
    begin
      RpLocalHubDatabase(ADatabase, AParams, LHubDatabaseId, LApiKey);
      if LHubDatabaseId <= 0 then
        raise ERpAgentConnectionError.CreateFor(Format(SRpAgentNotConfigured,
          [ADatabase.Alias]), ADatabase.Alias);
      LConfig.AddPair('hubDatabaseId', TJSONNumber.Create(LHubDatabaseId));
      LBody.AddPair('clientExecutes', TJSONBool.Create(False));
      // An Agent database of another account needs its API key
      if (LApiKey <> '') and (AHttp.ApiKey = '') then
        AHttp.ApiKey := LApiKey;
    end;
    LCall := 0;
    while True do
    begin
      if Assigned(ACancel) and ACancel(Sender) then
        Exit;
      Inc(LCall);
      LFrame := AHttp.GenerateSchemaStream(LBody, Sender, AOnProgress, ACancel);
      // Cancelled
      if LFrame = nil then
        Exit;
      LResult := JsonObjectOf(LFrame, 'result');
      if (Trim(JsonValueText(LFrame, 'errorMessage')) <> '') or (LResult = nil) or
        not LClientMode or
        not SameText(JsonValueText(LResult, 'status'), 'NeedsClientResults') then
      begin
        Result := LFrame;
        Exit;
      end;
      if LCall >= RP_MAX_SCHEMA_GENERATION_CALLS then
      begin
        PutPair(LFrame, 'errorMessage', TJSONString.Create(
          'The schema generator asked this computer too many times: it was stopped.'));
        Result := LFrame;
        Exit;
      end;
      try
        LRequests := JsonArrayOf(LResult, 'clientRequests');
        if LRequests = nil then
          raise Exception.Create('The schema generator asked nothing to read');
        GenerationProgress(Sender, AOnProgress, 'Answering ' + RequestsText(LRequests));
        LAnswers := TJSONArray.Create;
        try
          for I := 0 to LRequests.Count - 1 do
          begin
            if Assigned(ACancel) and ACancel(Sender) then
              Exit;
            if LRequests.Items[I] is TJSONObject then
              LAnswers.AddElement(RpAnswerSchemaRequest(ADatabase, AParams,
                LDialect, LNames, TJSONObject(LRequests.Items[I])));
          end;
          // The next call: the same request with the continuation and what
          // was read (the names went in the first one)
          RemoveJsonPair(LBody, 'initialTables');
          PutPair(LBody, 'continuation', TJSONString.Create(
            JsonValueText(LResult, 'continuation')));
          PutPair(LBody, 'clientResults', LAnswers);
          LAnswers := nil;
        finally
          LAnswers.Free;
        end;
      finally
        LFrame.Free;
      end;
    end;
  finally
    LBody.Free;
    LNames.Free;
  end;
end;

function RpGeneratedSchemaJson(AFrame: TJSONObject; const ADefaultName: string;
  out ATables, ARelations: Integer): string;
var
  I: Integer;
  LResult, LSchema, LCopy: TJSONObject;
  LTables, LKeys: TJSONArray;
begin
  Result := '';
  ATables := 0;
  ARelations := 0;
  LResult := JsonObjectOf(AFrame, 'result');
  if (LResult = nil) or not SameText(JsonValueText(LResult, 'status'), 'Completed') then
    Exit;
  LSchema := JsonObjectOf(LResult, 'schema');
  if LSchema = nil then
    Exit;
  LTables := JsonArrayOf(LSchema, 'schemaTables');
  if LTables = nil then
    Exit;
  for I := 0 to LTables.Count - 1 do
    if LTables.Items[I] is TJSONObject then
    begin
      Inc(ATables);
      LKeys := JsonArrayOf(TJSONObject(LTables.Items[I]), 'foreignKeys');
      if LKeys <> nil then
        Inc(ARelations, LKeys.Count);
    end;
  LCopy := TJSONObject.Create;
  try
    if Trim(JsonValueText(LSchema, 'name')) <> '' then
      LCopy.AddPair('name', Trim(JsonValueText(LSchema, 'name')))
    else
      LCopy.AddPair('name', Trim(ADefaultName));
    LCopy.AddPair('schemaTables', TJSONArray(LTables.Clone));
    Result := LCopy.ToJSON;
  finally
    LCopy.Free;
  end;
end;

procedure RpGeneratedSchemaInfo(AFrame: TJSONObject; out AError,
  AExplanation: string; AWarnings: TStrings; out ACredits, ATurns: Integer);
var
  I: Integer;
  LResult: TJSONObject;
  LWarnings: TJSONArray;
begin
  AError := Trim(JsonValueText(AFrame, 'errorMessage'));
  AExplanation := '';
  ACredits := 0;
  ATurns := 0;
  LResult := JsonObjectOf(AFrame, 'result');
  if LResult = nil then
    Exit;
  AExplanation := JsonValueText(LResult, 'explanation');
  ACredits := JsonValueInt(LResult, 'creditsConsumed');
  ATurns := JsonValueInt(LResult, 'turns');
  LWarnings := JsonArrayOf(LResult, 'warnings');
  if (AWarnings <> nil) and (LWarnings <> nil) then
    for I := 0 to LWarnings.Count - 1 do
      if Trim(LWarnings.Items[I].Value) <> '' then
        AWarnings.Add(Trim(LWarnings.Items[I].Value));
end;

{ Generate with AI in a thread }

type
  TRpSchemaGeneration = class(TInterfacedObject, IRpSchemaGeneration)
  private
    FLock: TCriticalSection;
    FState: TRpSchemaGenerationState;
    FLines: TStringList;
    FCancelRequested: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Cancel;
    function GetState: TRpSchemaGenerationState;
    procedure TakeLines(ALines: TStrings);
    function CancelRequested: Boolean;
    // The events of the stream (the worker thread)
    function StreamCancel(Sender: TObject): Boolean;
    procedure StreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    procedure Finish(const AResultJson, AErrorMessage: string;
      ACancelled: Boolean);
  end;

  TRpSchemaGenerationThread = class(TThread)
  private
    // Keeps the task alive while the thread runs
    FTask: IRpSchemaGeneration;
    FGeneration: TRpSchemaGeneration;
    FRequest: TRpSchemaGenerationRequest;
    FDatabases: TRpDatabaseInfoList;
    FParams: TRpParamList;
    FToken: string;
    FInstallId: string;
  protected
    procedure Execute; override;
  public
    constructor CreateFor(AGeneration: TRpSchemaGeneration;
      ARequest: TRpSchemaGenerationRequest; ADatabase: TRpDatabaseInfoItem;
      AParams: TRpParamList);
    destructor Destroy; override;
  end;

constructor TRpSchemaGeneration.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FLines := TStringList.Create;
end;

destructor TRpSchemaGeneration.Destroy;
begin
  FLines.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TRpSchemaGeneration.Cancel;
begin
  FLock.Enter;
  try
    FCancelRequested := True;
  finally
    FLock.Leave;
  end;
end;

function TRpSchemaGeneration.CancelRequested: Boolean;
begin
  FLock.Enter;
  try
    Result := FCancelRequested;
  finally
    FLock.Leave;
  end;
end;

function TRpSchemaGeneration.GetState: TRpSchemaGenerationState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

procedure TRpSchemaGeneration.TakeLines(ALines: TStrings);
begin
  FLock.Enter;
  try
    ALines.AddStrings(FLines);
    FLines.Clear;
  finally
    FLock.Leave;
  end;
end;

function TRpSchemaGeneration.StreamCancel(Sender: TObject): Boolean;
begin
  Result := CancelRequested;
end;

procedure TRpSchemaGeneration.StreamProgress(Sender: TObject; const AActor,
  AStage, AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
begin
  FLock.Enter;
  try
    if AInputTokens > 0 then
      FState.InputTokens := AInputTokens;
    if AOutputTokens > 0 then
      FState.OutputTokens := AOutputTokens;
    // The lines the cloud writes for the user
    if SameText(AActor, 'System') and SameText(AStage, 'ParsingResult') and
      (Trim(AChunk) <> '') then
      FLines.Add(Trim(AChunk));
  finally
    FLock.Leave;
  end;
end;

procedure TRpSchemaGeneration.Finish(const AResultJson, AErrorMessage: string;
  ACancelled: Boolean);
begin
  FLock.Enter;
  try
    FState.ResultJson := AResultJson;
    FState.ErrorMessage := AErrorMessage;
    FState.Cancelled := ACancelled or FCancelRequested;
    FState.Finished := True;
  finally
    FLock.Leave;
  end;
end;

constructor TRpSchemaGenerationThread.CreateFor(AGeneration: TRpSchemaGeneration;
  ARequest: TRpSchemaGenerationRequest; ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FGeneration := AGeneration;
  FTask := AGeneration;
  FRequest := TRpSchemaGenerationRequest.Create;
  FRequest.Assign(ARequest);
  // A copy of the connection and of the parameters: the screen may be
  // closed while the thread reads
  FDatabases := RpCopyDatabaseInfo(ADatabase);
  FParams := TRpParamList.Create(nil);
  if AParams <> nil then
    FParams.Assign(AParams);
  // The session is read here, in the thread of the screen
  FToken := TRpAuthManager.Instance.Token;
  FInstallId := TRpAuthManager.Instance.InstallId;
end;

destructor TRpSchemaGenerationThread.Destroy;
begin
  if FDatabases <> nil then
  begin
    try
      FDatabases.Items[0].DisConnect;
    except
      // Its last connection, closed as it can
    end;
    FDatabases.Free;
  end;
  FParams.Free;
  FRequest.Free;
  FTask := nil;
  inherited Destroy;
end;

procedure TRpSchemaGenerationThread.Execute;
var
  LHttp: TRpDatabaseHttp;
  LResult: TJSONObject;
{$IFDEF MSWINDOWS}
  LComInitialized: Boolean;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  // ADO is COM: its objects are made and used here
  LComInitialized := Succeeded(CoInitialize(nil));
{$ENDIF}
  try
    LResult := nil;
    LHttp := nil;
    try
      try
        LHttp := TRpDatabaseHttp.Create;
        LHttp.Token := FToken;
        LHttp.InstallId := FInstallId;
        LHttp.AITier := FRequest.AITier;
        LHttp.AgentSecret := FRequest.AgentSecret;
        LHttp.AgentAiId := FRequest.AgentAiId;
        LResult := RpGenerateSchema(LHttp, FRequest, FDatabases.Items[0],
          FParams, FGeneration, FGeneration.StreamProgress,
          FGeneration.StreamCancel);
        if LResult = nil then
          FGeneration.Finish('', '', True)
        else
          FGeneration.Finish(LResult.ToJSON, '', False);
      finally
        LResult.Free;
        LHttp.Free;
      end;
    except
      on E: Exception do
        FGeneration.Finish('', E.Message, FGeneration.CancelRequested);
    end;
  finally
    try
      FDatabases.Items[0].DisConnect;
    except
      // Closed as it can
    end;
{$IFDEF MSWINDOWS}
    if LComInitialized then
      CoUninitialize;
{$ENDIF}
  end;
end;

function RpStartSchemaGeneration(ARequest: TRpSchemaGenerationRequest;
  ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList): IRpSchemaGeneration;
var
  LGeneration: TRpSchemaGeneration;
  LThread: TRpSchemaGenerationThread;
begin
  LGeneration := TRpSchemaGeneration.Create;
  Result := LGeneration;
  LThread := TRpSchemaGenerationThread.CreateFor(LGeneration, ARequest,
    ADatabase, AParams);
  LThread.Start;
end;

initialization
  GReadErrorIgnorer := TRpReadErrorIgnorer.Create;

finalization
  FreeAndNil(GReadErrorIgnorer);

end.

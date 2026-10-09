{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpreportdesignercontracts                       }
{                                                       }
{       Shared contracts for ReportDesigner API         }
{                                                       }
{*******************************************************}
unit rpreportdesignercontracts;

interface

{$I rpconf.inc}

uses
{$IFDEF FPC}
  // No generics used here; in FPC Generics.Collections.TObjectList<T> would
  // hide Contnrs.TObjectList
  SysUtils, Classes, Contnrs, Variants, rpjsonfpc;
{$ELSE}
  SysUtils, Classes, Contnrs, Variants, System.Generics.Collections, System.JSON;
{$ENDIF}

const
  // ModifyReport turn status: the cloud waits for the columns of SQL that
  // only the client can run (docs: copiloto-sql-en-el-cliente-plan, 2.1)
  RP_MODIFY_STATUS_NEEDS_CLIENT_SQL = 'NeedsClientSqlResults';
  // errorCode of a schema larger than the plan of who pays allows with the
  // AI in the cloud: the message carries the numbers and the way out
  RP_ERROR_SCHEMA_TOO_LARGE_FOR_TIER = 'SchemaTooLargeForTier';

type
  TRpReportDesignerMode = (rdmFast, rdmReasoning);
  TRpReportDocumentFormat = (rdfJson, rdfXml);
  TRpAITierType = (ratStandard, ratPrecision, ratLocalAgent);

  // The database the AI writes SQL for: a Hub database and schema, or a
  // direct connection of the report whose schema travels inline (Name is the
  // connection alias, SchemaTablesJson the JSON array of its tables)
  TRpApiDatabaseConfig = class(TPersistent)
  private
    FDialect: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FLocalAlias: string;
    FLocalSchemaName: string;
    FName: string;
    FSchemaName: string;
    FSchemaTablesJson: string;
  public
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    function HasInlineSchema: Boolean;
    property Dialect: string read FDialect write FDialect;
    property HubDatabaseId: Int64 read FHubDatabaseId write FHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write FHubSchemaId;
    // Not sent: the direct connection (and its local subschema, '' = all
    // the tables) whose schema file fills Name, Dialect and SchemaTablesJson
    // before the request is sent (rpdesignerclientsql)
    property LocalAlias: string read FLocalAlias write FLocalAlias;
    property LocalSchemaName: string read FLocalSchemaName write FLocalSchemaName;
    property Name: string read FName write FName;
    // The local subschema of the inline schema (schemaName, sent with
    // schemaTables): the cloud gives it to the datasets it makes on the
    // connection. '' = all the tables
    property SchemaName: string read FSchemaName write FSchemaName;
    property SchemaTablesJson: string read FSchemaTablesJson write FSchemaTablesJson;
  end;

  // A parameter of a SQL the client has to run (System.Data.DbParameterInfo)
  TRpClientSqlParameter = class(TPersistent)
  private
    FDbType: Integer;
    FHasDbType: Boolean;
    FName: string;
    FValue: Variant;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property DbType: Integer read FDbType write FDbType;
    property HasDbType: Boolean read FHasDbType write FHasDbType;
    property Name: string read FName write FName;
    property Value: Variant read FValue write FValue;
  end;

  // A dataset SQL the cloud can not run (the database is not in the Hub):
  // the client opens it without rows on DatabaseAlias and answers with its
  // columns
  TRpClientSqlRequest = class(TPersistent)
  private
    FDatabaseAlias: string;
    FDatasetAlias: string;
    FId: string;
    FParameters: TObjectList;
    FSql: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property DatabaseAlias: string read FDatabaseAlias write FDatabaseAlias;
    property DatasetAlias: string read FDatasetAlias write FDatasetAlias;
    property Id: string read FId write FId;
    property Parameters: TObjectList read FParameters;
    property Sql: string read FSql write FSql;
  end;

  TRpClientSqlColumn = class(TPersistent)
  private
    FDataType: string;
    FName: string;
    FSize: Integer;
  public
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    // string, integer, float, currency, datetime, boolean or blob
    property DataType: string read FDataType write FDataType;
    property Name: string read FName write FName;
    property Size: Integer read FSize write FSize;
  end;

  // The answer to a TRpClientSqlRequest: its columns, or the message of the
  // database
  TRpClientSqlResult = class(TPersistent)
  private
    FColumns: TObjectList;
    FErrorMessage: string;
    FId: string;
    FSuccess: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    function AddColumn(const AName, ADataType: string; ASize: Integer): TRpClientSqlColumn;
    property Columns: TObjectList read FColumns;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property Id: string read FId write FId;
    property Success: Boolean read FSuccess write FSuccess;
  end;

  TRpTokenUsage = class(TPersistent)
  private
    FInputTokens: Integer;
    FModelName: string;
    FOutputTokens: Integer;
    FThinkingTokens: Integer;
    function GetTotalTokens: Integer;
  public
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property InputTokens: Integer read FInputTokens write FInputTokens;
    property ModelName: string read FModelName write FModelName;
    property OutputTokens: Integer read FOutputTokens write FOutputTokens;
    property ThinkingTokens: Integer read FThinkingTokens write FThinkingTokens;
    property TotalTokens: Integer read GetTotalTokens;
  end;

  TRpModifyReportRequest = class(TPersistent)
  private
    FExistingContextJson: string;
    FExistingOperationsJson: string;
    FReportDocument: string;
    FReportFormat: TRpReportDocumentFormat;
    FReturnModifiedDocument: Boolean;
    FUserInstructions: TStringList;
    FUserLanguage: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property ExistingContextJson: string read FExistingContextJson write FExistingContextJson;
    property ExistingOperationsJson: string read FExistingOperationsJson write FExistingOperationsJson;
    property ReportDocument: string read FReportDocument write FReportDocument;
    property ReportFormat: TRpReportDocumentFormat read FReportFormat write FReportFormat;
    property ReturnModifiedDocument: Boolean read FReturnModifiedDocument write FReturnModifiedDocument;
    property UserInstructions: TStringList read FUserInstructions;
    property UserLanguage: string read FUserLanguage write FUserLanguage;
  end;

  TRpModifyReportResult = class(TPersistent)
  private
    FClientSqlRequests: TObjectList;
    FContextJson: string;
    FContinuation: string;
    FErrorMessage: string;
    FExplanation: string;
    FModifiedReportDocument: string;
    FOperationsJson: string;
    FReportFormat: TRpReportDocumentFormat;
    FStatus: string;
    FWorkingContextJson: string;
    function GetSuccess: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    // The turn ended waiting for the columns of ClientSqlRequests
    function NeedsClientSqlResults: Boolean;
    property ClientSqlRequests: TObjectList read FClientSqlRequests;
    property ContextJson: string read FContextJson write FContextJson;
    property Continuation: string read FContinuation write FContinuation;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property Explanation: string read FExplanation write FExplanation;
    property ModifiedReportDocument: string read FModifiedReportDocument write FModifiedReportDocument;
    property OperationsJson: string read FOperationsJson write FOperationsJson;
    property ReportFormat: TRpReportDocumentFormat read FReportFormat write FReportFormat;
    property Status: string read FStatus write FStatus;
    property Success: Boolean read GetSuccess;
    property WorkingContextJson: string read FWorkingContextJson write FWorkingContextJson;
  end;

  TRpApiModifyReportRequest = class(TPersistent)
  private
    FAgentAiId: Int64;
    FAgentSecret: string;
    FAITier: TRpAITierType;
    FApiKey: string;
    FClientExecutesSql: Boolean;
    FClientSqlResults: TObjectList;
    FConfig: TRpApiDatabaseConfig;
    FContinuation: string;
    FExistingContextJson: string;
    FExistingOperationsJson: string;
    FHasAgentAiId: Boolean;
    FMode: TRpReportDesignerMode;
    FReportDocument: string;
    FReportFormat: TRpReportDocumentFormat;
    FReturnModifiedDocument: Boolean;
    FSimplifiedPrompt: Boolean;
    FUserInstructions: TStringList;
    FUserLanguage: string;
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    procedure SetHubDatabaseId(const Value: Int64);
    procedure SetHubSchemaId(const Value: Int64);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AssignSharedRequest(ASource: TRpModifyReportRequest);
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property AgentAiId: Int64 read FAgentAiId write FAgentAiId;
    property AgentSecret: string read FAgentSecret write FAgentSecret;
    property AITier: TRpAITierType read FAITier write FAITier;
    property ApiKey: string read FApiKey write FApiKey;
    // The client runs the SQL of databases that are not in the Hub
    property ClientExecutesSql: Boolean read FClientExecutesSql write FClientExecutesSql;
    // TRpClientSqlResult: the answers to the ClientSqlRequests of the turn
    // whose Continuation is sent
    property ClientSqlResults: TObjectList read FClientSqlResults;
    property Config: TRpApiDatabaseConfig read FConfig;
    property Continuation: string read FContinuation write FContinuation;
    property ExistingContextJson: string read FExistingContextJson write FExistingContextJson;
    property ExistingOperationsJson: string read FExistingOperationsJson write FExistingOperationsJson;
    property HasAgentAiId: Boolean read FHasAgentAiId write FHasAgentAiId;
    property HubDatabaseId: Int64 read GetHubDatabaseId write SetHubDatabaseId;
    property HubSchemaId: Int64 read GetHubSchemaId write SetHubSchemaId;
    property Mode: TRpReportDesignerMode read FMode write FMode;
    property ReportDocument: string read FReportDocument write FReportDocument;
    property ReportFormat: TRpReportDocumentFormat read FReportFormat write FReportFormat;
    property ReturnModifiedDocument: Boolean read FReturnModifiedDocument write FReturnModifiedDocument;
    property SimplifiedPrompt: Boolean read FSimplifiedPrompt write FSimplifiedPrompt;
    property UserInstructions: TStringList read FUserInstructions;
    property UserLanguage: string read FUserLanguage write FUserLanguage;
  end;

  TRpApiModifyReportResult = class(TPersistent)
  private
    FCreditsConsumed: Integer;
    FDebugDetails: string;
    FErrorCode: string;
    FErrorMessage: string;
    FHasCreditsConsumed: Boolean;
    FResult: TRpModifyReportResult;
    FSteps: TObjectList;
    FUserProfileJson: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure ClearSteps;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property CreditsConsumed: Integer read FCreditsConsumed write FCreditsConsumed;
    property DebugDetails: string read FDebugDetails write FDebugDetails;
    // A code for the errors a client handles on its own
    // (RP_ERROR_SCHEMA_TOO_LARGE_FOR_TIER); '' for the rest
    property ErrorCode: string read FErrorCode write FErrorCode;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property HasCreditsConsumed: Boolean read FHasCreditsConsumed write FHasCreditsConsumed;
    property ResultData: TRpModifyReportResult read FResult;
    property Steps: TObjectList read FSteps;
    property UserProfileJson: string read FUserProfileJson write FUserProfileJson;
  end;

  TRpApiPreprocessSqlContextDataSource = class(TPersistent)
  private
    FConfig: TRpApiDatabaseConfig;
    FDataInfoName: string;
    FDatabaseAlias: string;
    FSql: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property Config: TRpApiDatabaseConfig read FConfig;
    property DataInfoName: string read FDataInfoName write FDataInfoName;
    property DatabaseAlias: string read FDatabaseAlias write FDatabaseAlias;
    property Sql: string read FSql write FSql;
  end;

  TRpApiPreprocessSqlContextDataSourceResult = class(TPersistent)
  private
    FDataInfoName: string;
    FErrorMessage: string;
    FSqlExplanation: string;
  public
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property DataInfoName: string read FDataInfoName write FDataInfoName;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property SqlExplanation: string read FSqlExplanation write FSqlExplanation;
  end;

  TRpApiPreprocessSqlContextRequest = class(TPersistent)
  private
    FAgentAiId: Int64;
    FAgentSecret: string;
    FAITier: TRpAITierType;
    FApiKey: string;
    FConfig: TRpApiDatabaseConfig;
    FDataSources: TObjectList;
    FHasAgentAiId: Boolean;
    FMode: TRpReportDesignerMode;
    FUserLanguage: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property AgentAiId: Int64 read FAgentAiId write FAgentAiId;
    property AgentSecret: string read FAgentSecret write FAgentSecret;
    property AITier: TRpAITierType read FAITier write FAITier;
    property ApiKey: string read FApiKey write FApiKey;
    property Config: TRpApiDatabaseConfig read FConfig;
    property DataSources: TObjectList read FDataSources;
    property HasAgentAiId: Boolean read FHasAgentAiId write FHasAgentAiId;
    property Mode: TRpReportDesignerMode read FMode write FMode;
    property UserLanguage: string read FUserLanguage write FUserLanguage;
  end;

  TRpApiPreprocessSqlContextResult = class(TPersistent)
  private
    FCreditsConsumed: Integer;
    FDataSources: TObjectList;
    FDebugDetails: string;
    FErrorCode: string;
    FErrorMessage: string;
    FHasCreditsConsumed: Boolean;
    FSteps: TObjectList;
    FUserProfileJson: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure ClearDataSources;
    procedure ClearSteps;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property CreditsConsumed: Integer read FCreditsConsumed write FCreditsConsumed;
    property DataSources: TObjectList read FDataSources;
    property DebugDetails: string read FDebugDetails write FDebugDetails;
    // As TRpApiModifyReportResult.ErrorCode
    property ErrorCode: string read FErrorCode write FErrorCode;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property HasCreditsConsumed: Boolean read FHasCreditsConsumed write FHasCreditsConsumed;
    property Steps: TObjectList read FSteps;
    property UserProfileJson: string read FUserProfileJson write FUserProfileJson;
  end;

  // The tokens and the time of the model calls of an AI request, for its
  // log (the AI log tab of the chats): a call is a progress id, timed from
  // its first frame to its last
  TRpInferenceLogMeter = class(TObject)
  private
    FCalls: TStringList;
    FRequestStart: TDateTime;
    procedure ClearCalls;
  public
    constructor Create;
    destructor Destroy; override;
    // A new request: its clock starts, the calls still open are dropped
    procedure BeginRequest;
    // A frame of the call AProgressId ('' is ignored) with its tokens so
    // far (the largest ones are kept)
    procedure Frame(const AProgressId: string; AInputTokens: Integer = 0;
      AOutputTokens: Integer = 0);
    // The last frame of the call: its log line ('' for an unknown id)
    function FinishCall(const AProgressId: string): string;
    // Seconds since BeginRequest
    function ElapsedSeconds: Double;
  end;

function RpReportDesignerModeToString(AMode: TRpReportDesignerMode): string;
function RpReportDesignerModeFromString(const AValue: string): TRpReportDesignerMode;
function RpReportDocumentFormatToString(AFormat: TRpReportDocumentFormat): string;
function RpReportDocumentFormatFromString(const AValue: string): TRpReportDocumentFormat;
function RpAITierTypeToString(ATier: TRpAITierType): string;
function RpAITierTypeFromString(const AValue: string): TRpAITierType;
function RpComposeApiErrorMessage(const AErrorMessage, ADebugDetails: string): string; overload;
// The same with the errorCode of the answer: the plan error is shown as the
// cloud says it (its numbers and the way out), without the debug details
function RpComposeApiErrorMessage(const AErrorMessage, AErrorCode,
  ADebugDetails: string): string; overload;
// The log line of a model call, '#7 . 1200 -> 340 tok . 4.2 s . 81.0 tok/s'
// with a middle dot and an arrow (without the speed under 0.1 s)
function RpFormatInferenceCallLog(const AProgressId: string; AInputTokens,
  AOutputTokens: Integer; ASeconds: Double): string;
// Adds the TRpTokenUsage of ASteps (nil = none) to the totals; the model
// names, each once, separated by ', '
procedure RpSumTokenUsage(ASteps: TObjectList; var AInputTokens,
  AOutputTokens, AThinkingTokens: Integer; var AModelNames: string);
// The log line of the totals of a request,
// 'Total . 1200 -> 340 tok . 85 thinking tok . m1, m2 . 9.8 s . 3 credits'
// (the thinking tokens, the models and the credits when there are)
function RpFormatInferenceTotalsLog(AInputTokens, AOutputTokens,
  AThinkingTokens: Integer; const AModelNames: string; ASeconds: Double;
  AHasCredits: Boolean; ACredits: Integer): string;

implementation

function JsonValueToBoolean(AValue: TJSONValue; ADefault: Boolean): Boolean; forward;
function JsonValueToInt(AValue: TJSONValue; ADefault: Integer): Integer; forward;
function JsonValueToInt64(AValue: TJSONValue; ADefault: Int64): Int64; forward;
function JsonValueToString(AValue: TJSONValue; const ADefault: string): string; forward;

procedure TRpApiDatabaseConfig.Assign(Source: TPersistent);
var
  LSource: TRpApiDatabaseConfig;
begin
  if Source is TRpApiDatabaseConfig then
  begin
    LSource := TRpApiDatabaseConfig(Source);
    FHubDatabaseId := LSource.HubDatabaseId;
    FHubSchemaId := LSource.HubSchemaId;
    FName := LSource.Name;
    FDialect := LSource.Dialect;
    FSchemaTablesJson := LSource.SchemaTablesJson;
    FSchemaName := LSource.SchemaName;
    FLocalAlias := LSource.LocalAlias;
    FLocalSchemaName := LSource.LocalSchemaName;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiDatabaseConfig.FromJsonObject(AObject: TJSONObject);
var
  LTables: TJSONValue;
begin
  FName := '';
  FDialect := '';
  FSchemaName := '';
  FSchemaTablesJson := '';
  if AObject = nil then
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    Exit;
  end;
  FHubDatabaseId := JsonValueToInt64(AObject.Values['hubDatabaseId'], 0);
  FHubSchemaId := JsonValueToInt64(AObject.Values['hubSchemaId'], 0);
  LTables := AObject.Values['schemaTables'];
  if (LTables <> nil) and (LTables is TJSONArray) then
  begin
    FSchemaTablesJson := LTables.ToJSON;
    FName := JsonValueToString(AObject.Values['name'], '');
    FDialect := JsonValueToString(AObject.Values['dialect'], '');
    if (AObject.Values['schemaName'] <> nil) and
      not (AObject.Values['schemaName'] is TJSONNull) then
      FSchemaName := AObject.Values['schemaName'].Value;
  end;
end;

function TRpApiDatabaseConfig.HasInlineSchema: Boolean;
begin
  Result := Trim(FSchemaTablesJson) <> '';
end;

function TRpApiDatabaseConfig.ToJsonObject: TJSONObject;
var
  LTables: TJSONValue;
begin
  Result := TJSONObject.Create;
  if HasInlineSchema then
  begin
    // A direct connection: the cloud puts new datasets on the connection of
    // the report named as the config, and asks the client for the columns
    Result.AddPair('name', FName);
    if FDialect <> '' then
      Result.AddPair('dialect', FDialect);
    LTables := TJSONObject.ParseJSONValue(FSchemaTablesJson);
    if (LTables <> nil) and not (LTables is TJSONArray) then
      FreeAndNil(LTables);
    if LTables = nil then
      LTables := TJSONArray.Create;
    Result.AddPair('schemaTables', LTables);
    if FSchemaName <> '' then
      Result.AddPair('schemaName', FSchemaName);
    Result.AddPair('hubDatabaseId', TJSONNumber.Create(0));
    Result.AddPair('hubSchemaId', TJSONNumber.Create(0));
    Exit;
  end;
  if FHubDatabaseId <> 0 then
    Result.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
  if FHubSchemaId <> 0 then
    Result.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
end;

{ TRpClientSqlParameter }

constructor TRpClientSqlParameter.Create;
begin
  inherited Create;
  FValue := Null;
end;

procedure TRpClientSqlParameter.Assign(Source: TPersistent);
var
  LSource: TRpClientSqlParameter;
begin
  if Source is TRpClientSqlParameter then
  begin
    LSource := TRpClientSqlParameter(Source);
    FName := LSource.Name;
    FValue := LSource.Value;
    FDbType := LSource.DbType;
    FHasDbType := LSource.HasDbType;
  end
  else
    inherited Assign(Source);
end;

function JsonNumberTextToVariant(const AText: string): Variant;
var
  LFormat: TFormatSettings;
  LInt: Int64;
  LDouble: Double;
begin
  if TryStrToInt64(AText, LInt) then
    Exit(LInt);
  LFormat := FormatSettings;
  LFormat.DecimalSeparator := '.';
  LFormat.ThousandSeparator := ',';
  if TryStrToFloat(AText, LDouble, LFormat) then
    Result := LDouble
  else
    Result := AText;
end;

procedure TRpClientSqlParameter.FromJsonObject(AObject: TJSONObject);
var
  LValue: TJSONValue;
begin
  FValue := Null;
  FHasDbType := False;
  FDbType := 0;
  if AObject = nil then
    Exit;
  FName := JsonValueToString(AObject.Values['name'], '');
  LValue := AObject.Values['value'];
  if (LValue = nil) or (LValue is TJSONNull) then
    FValue := Null
  else if LValue is TJSONBool then
    FValue := SameText(LValue.Value, 'true')
  else if LValue is TJSONNumber then
    FValue := JsonNumberTextToVariant(LValue.Value)
  else if LValue is TJSONString then
    FValue := LValue.Value
  else
    FValue := LValue.ToJSON;
  LValue := AObject.Values['dbType'];
  if (LValue <> nil) and not (LValue is TJSONNull) then
  begin
    FHasDbType := True;
    FDbType := StrToIntDef(LValue.Value, 0);
  end;
end;

function TRpClientSqlParameter.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  case VarType(FValue) of
    varEmpty, varNull:
      Result.AddPair('value', TJSONNull.Create);
    varBoolean:
      Result.AddPair('value', TJSONBool.Create(Boolean(FValue)));
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord,
    varInt64:
      Result.AddPair('value', TJSONNumber.Create(Int64(FValue)));
    varSingle, varDouble, varCurrency:
      Result.AddPair('value', TJSONNumber.Create(Double(FValue)));
  else
    Result.AddPair('value', VarToStr(FValue));
  end;
  if FHasDbType then
    Result.AddPair('dbType', TJSONNumber.Create(FDbType))
  else
    Result.AddPair('dbType', TJSONNull.Create);
end;

{ TRpClientSqlRequest }

constructor TRpClientSqlRequest.Create;
begin
  inherited Create;
  FParameters := TObjectList.Create(True);
end;

destructor TRpClientSqlRequest.Destroy;
begin
  FParameters.Free;
  inherited Destroy;
end;

procedure TRpClientSqlRequest.Assign(Source: TPersistent);
var
  I: Integer;
  LParameter: TRpClientSqlParameter;
  LSource: TRpClientSqlRequest;
begin
  if Source is TRpClientSqlRequest then
  begin
    LSource := TRpClientSqlRequest(Source);
    FId := LSource.Id;
    FDatasetAlias := LSource.DatasetAlias;
    FDatabaseAlias := LSource.DatabaseAlias;
    FSql := LSource.Sql;
    FParameters.Clear;
    for I := 0 to LSource.Parameters.Count - 1 do
    begin
      LParameter := TRpClientSqlParameter.Create;
      LParameter.Assign(TRpClientSqlParameter(LSource.Parameters[I]));
      FParameters.Add(LParameter);
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TRpClientSqlRequest.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LParameter: TRpClientSqlParameter;
  LValue: TJSONValue;
begin
  FParameters.Clear;
  if AObject = nil then
    Exit;
  FId := JsonValueToString(AObject.Values['id'], '');
  FDatasetAlias := JsonValueToString(AObject.Values['datasetAlias'], '');
  FDatabaseAlias := JsonValueToString(AObject.Values['databaseAlias'], '');
  FSql := JsonValueToString(AObject.Values['sql'], '');
  LValue := AObject.Values['parameters'];
  if (LValue <> nil) and (LValue is TJSONArray) then
  begin
    LArray := TJSONArray(LValue);
    for I := 0 to LArray.Count - 1 do
    begin
      if not (LArray.Items[I] is TJSONObject) then
        Continue;
      LParameter := TRpClientSqlParameter.Create;
      LParameter.FromJsonObject(TJSONObject(LArray.Items[I]));
      FParameters.Add(LParameter);
    end;
  end;
end;

function TRpClientSqlRequest.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('datasetAlias', FDatasetAlias);
  Result.AddPair('databaseAlias', FDatabaseAlias);
  Result.AddPair('sql', FSql);
  LArray := TJSONArray.Create;
  for I := 0 to FParameters.Count - 1 do
    LArray.AddElement(TRpClientSqlParameter(FParameters[I]).ToJsonObject);
  Result.AddPair('parameters', LArray);
end;

{ TRpClientSqlColumn }

procedure TRpClientSqlColumn.Assign(Source: TPersistent);
begin
  if Source is TRpClientSqlColumn then
  begin
    FName := TRpClientSqlColumn(Source).Name;
    FDataType := TRpClientSqlColumn(Source).DataType;
    FSize := TRpClientSqlColumn(Source).Size;
  end
  else
    inherited Assign(Source);
end;

procedure TRpClientSqlColumn.FromJsonObject(AObject: TJSONObject);
begin
  if AObject = nil then
    Exit;
  FName := JsonValueToString(AObject.Values['name'], '');
  FDataType := JsonValueToString(AObject.Values['dataType'], '');
  FSize := JsonValueToInt(AObject.Values['size'], 0);
end;

function TRpClientSqlColumn.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  Result.AddPair('dataType', FDataType);
  Result.AddPair('size', TJSONNumber.Create(FSize));
end;

{ TRpClientSqlResult }

constructor TRpClientSqlResult.Create;
begin
  inherited Create;
  FColumns := TObjectList.Create(True);
end;

destructor TRpClientSqlResult.Destroy;
begin
  FColumns.Free;
  inherited Destroy;
end;

function TRpClientSqlResult.AddColumn(const AName, ADataType: string;
  ASize: Integer): TRpClientSqlColumn;
begin
  Result := TRpClientSqlColumn.Create;
  Result.Name := AName;
  Result.DataType := ADataType;
  Result.Size := ASize;
  FColumns.Add(Result);
end;

procedure TRpClientSqlResult.Assign(Source: TPersistent);
var
  I: Integer;
  LColumn: TRpClientSqlColumn;
  LSource: TRpClientSqlResult;
begin
  if Source is TRpClientSqlResult then
  begin
    LSource := TRpClientSqlResult(Source);
    FId := LSource.Id;
    FSuccess := LSource.Success;
    FErrorMessage := LSource.ErrorMessage;
    FColumns.Clear;
    for I := 0 to LSource.Columns.Count - 1 do
    begin
      LColumn := TRpClientSqlColumn.Create;
      LColumn.Assign(TRpClientSqlColumn(LSource.Columns[I]));
      FColumns.Add(LColumn);
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TRpClientSqlResult.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LColumn: TRpClientSqlColumn;
  LValue: TJSONValue;
begin
  FColumns.Clear;
  if AObject = nil then
    Exit;
  FId := JsonValueToString(AObject.Values['id'], '');
  FSuccess := JsonValueToBoolean(AObject.Values['success'], False);
  FErrorMessage := JsonValueToString(AObject.Values['errorMessage'], '');
  LValue := AObject.Values['columns'];
  if (LValue <> nil) and (LValue is TJSONArray) then
  begin
    LArray := TJSONArray(LValue);
    for I := 0 to LArray.Count - 1 do
    begin
      if not (LArray.Items[I] is TJSONObject) then
        Continue;
      LColumn := TRpClientSqlColumn.Create;
      LColumn.FromJsonObject(TJSONObject(LArray.Items[I]));
      FColumns.Add(LColumn);
    end;
  end;
end;

function TRpClientSqlResult.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('success', TJSONBool.Create(FSuccess));
  if FSuccess then
  begin
    LArray := TJSONArray.Create;
    for I := 0 to FColumns.Count - 1 do
      LArray.AddElement(TRpClientSqlColumn(FColumns[I]).ToJsonObject);
    Result.AddPair('columns', LArray);
  end
  else
    Result.AddPair('errorMessage', FErrorMessage);
end;

function JsonValueToBoolean(AValue: TJSONValue; ADefault: Boolean): Boolean;
begin
  if AValue = nil then
    Exit(ADefault);
  Result := SameText(AValue.Value, 'true') or (AValue.Value = '1');
end;

function JsonValueToInt(AValue: TJSONValue; ADefault: Integer): Integer;
begin
  if AValue = nil then
    Exit(ADefault);
  Result := StrToIntDef(AValue.Value, ADefault);
end;

function JsonValueToInt64(AValue: TJSONValue; ADefault: Int64): Int64;
begin
  if AValue = nil then
    Exit(ADefault);
  Result := StrToInt64Def(AValue.Value, ADefault);
end;

function JsonValueToString(AValue: TJSONValue; const ADefault: string): string;
begin
  if AValue = nil then
    Exit(ADefault);
  Result := AValue.Value;
end;

procedure LoadStringsFromJsonArray(AStrings: TStrings; AArray: TJSONArray);
var
  I: Integer;
  LValue: TJSONValue;
begin
  AStrings.Clear;
  if AArray = nil then
    Exit;
  for I := 0 to AArray.Count - 1 do
  begin
    LValue := AArray.Items[I];
    if LValue <> nil then
      AStrings.Add(LValue.Value);
  end;
end;

function StringsToJsonArray(AStrings: TStrings): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to AStrings.Count - 1 do
    Result.Add(AStrings[I]);
end;

function RpReportDesignerModeToString(AMode: TRpReportDesignerMode): string;
begin
  case AMode of
    rdmReasoning:
      Result := 'Reasoning';
  else
    Result := 'Fast';
  end;
end;

function RpReportDesignerModeFromString(const AValue: string): TRpReportDesignerMode;
begin
  if SameText(AValue, 'Reasoning') then
    Result := rdmReasoning
  else
    Result := rdmFast;
end;

function RpReportDocumentFormatToString(AFormat: TRpReportDocumentFormat): string;
begin
  case AFormat of
    rdfXml:
      Result := 'Xml';
  else
    Result := 'Json';
  end;
end;

function RpReportDocumentFormatFromString(const AValue: string): TRpReportDocumentFormat;
begin
  if SameText(AValue, 'Xml') then
    Result := rdfXml
  else
    Result := rdfJson;
end;

function RpAITierTypeToString(ATier: TRpAITierType): string;
begin
  case ATier of
    ratPrecision:
      Result := 'Precision';
    ratLocalAgent:
      Result := 'LocalAgent';
  else
    Result := 'Standard';
  end;
end;

function RpAITierTypeFromString(const AValue: string): TRpAITierType;
begin
  if SameText(AValue, 'Precision') then
    Result := ratPrecision
  else if SameText(AValue, 'LocalAgent') then
    Result := ratLocalAgent
  else
    Result := ratStandard;
end;

function RpComposeApiErrorMessage(const AErrorMessage, ADebugDetails: string): string;
begin
  Result := Trim(AErrorMessage);
  if Trim(ADebugDetails) = '' then
    Exit;

  if Result <> '' then
    Result := Result + sLineBreak + sLineBreak + Trim(ADebugDetails)
  else
    Result := Trim(ADebugDetails);
end;

function RpComposeApiErrorMessage(const AErrorMessage, AErrorCode,
  ADebugDetails: string): string;
begin
  if SameText(AErrorCode, RP_ERROR_SCHEMA_TOO_LARGE_FOR_TIER) and
    (Trim(AErrorMessage) <> '') then
    Result := Trim(AErrorMessage)
  else
    Result := RpComposeApiErrorMessage(AErrorMessage, ADebugDetails);
end;

procedure TRpTokenUsage.Assign(Source: TPersistent);
var
  LSource: TRpTokenUsage;
begin
  if Source is TRpTokenUsage then
  begin
    LSource := TRpTokenUsage(Source);
    FInputTokens := LSource.InputTokens;
    FModelName := LSource.ModelName;
    FOutputTokens := LSource.OutputTokens;
    FThinkingTokens := LSource.ThinkingTokens;
  end
  else
    inherited Assign(Source);
end;

procedure TRpTokenUsage.FromJsonObject(AObject: TJSONObject);
begin
  if AObject = nil then
    Exit;
  FInputTokens := JsonValueToInt(AObject.Values['inputTokens'], 0);
  FModelName := JsonValueToString(AObject.Values['modelName'], '');
  FOutputTokens := JsonValueToInt(AObject.Values['outputTokens'], 0);
  FThinkingTokens := JsonValueToInt(AObject.Values['thinkingTokens'], 0);
end;

function TRpTokenUsage.GetTotalTokens: Integer;
begin
  Result := FInputTokens + FOutputTokens;
end;

function TRpTokenUsage.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('inputTokens', TJSONNumber.Create(FInputTokens));
  Result.AddPair('modelName', FModelName);
  Result.AddPair('outputTokens', TJSONNumber.Create(FOutputTokens));
  Result.AddPair('thinkingTokens', TJSONNumber.Create(FThinkingTokens));
end;

constructor TRpModifyReportRequest.Create;
begin
  inherited Create;
  FUserInstructions := TStringList.Create;
  FReportFormat := rdfXml;
  FReturnModifiedDocument := True;
end;

destructor TRpModifyReportRequest.Destroy;
begin
  FUserInstructions.Free;
  inherited Destroy;
end;

procedure TRpModifyReportRequest.Assign(Source: TPersistent);
var
  LSource: TRpModifyReportRequest;
begin
  if Source is TRpModifyReportRequest then
  begin
    LSource := TRpModifyReportRequest(Source);
    FExistingContextJson := LSource.ExistingContextJson;
    FExistingOperationsJson := LSource.ExistingOperationsJson;
    FReportDocument := LSource.ReportDocument;
    FReportFormat := LSource.ReportFormat;
    FReturnModifiedDocument := LSource.ReturnModifiedDocument;
    FUserLanguage := LSource.UserLanguage;
    FUserInstructions.Assign(LSource.UserInstructions);
  end
  else
    inherited Assign(Source);
end;

procedure TRpModifyReportRequest.FromJsonObject(AObject: TJSONObject);
begin
  if AObject = nil then
    Exit;
  FReportDocument := JsonValueToString(AObject.Values['reportDocument'], '');
  FReportFormat := RpReportDocumentFormatFromString(JsonValueToString(AObject.Values['reportFormat'], 'Xml'));
  LoadStringsFromJsonArray(FUserInstructions, AObject.Values['userInstructions'] as TJSONArray);
  FUserLanguage := JsonValueToString(AObject.Values['userLanguage'], '');
  FExistingOperationsJson := JsonValueToString(AObject.Values['existingOperationsJson'], '');
  FExistingContextJson := JsonValueToString(AObject.Values['existingContextJson'], '');
  FReturnModifiedDocument := JsonValueToBoolean(AObject.Values['returnModifiedDocument'], True);
end;

function TRpModifyReportRequest.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('reportDocument', FReportDocument);
  Result.AddPair('reportFormat', RpReportDocumentFormatToString(FReportFormat));
  Result.AddPair('userInstructions', StringsToJsonArray(FUserInstructions));
  Result.AddPair('userLanguage', FUserLanguage);
  Result.AddPair('existingOperationsJson', FExistingOperationsJson);
  Result.AddPair('existingContextJson', FExistingContextJson);
  Result.AddPair('returnModifiedDocument', TJSONBool.Create(FReturnModifiedDocument));
end;

constructor TRpModifyReportResult.Create;
begin
  inherited Create;
  FClientSqlRequests := TObjectList.Create(True);
end;

destructor TRpModifyReportResult.Destroy;
begin
  FClientSqlRequests.Free;
  inherited Destroy;
end;

procedure TRpModifyReportResult.Assign(Source: TPersistent);
var
  I: Integer;
  LRequest: TRpClientSqlRequest;
  LSource: TRpModifyReportResult;
begin
  if Source is TRpModifyReportResult then
  begin
    LSource := TRpModifyReportResult(Source);
    FContextJson := LSource.ContextJson;
    FErrorMessage := LSource.ErrorMessage;
    FExplanation := LSource.Explanation;
    FModifiedReportDocument := LSource.ModifiedReportDocument;
    FOperationsJson := LSource.OperationsJson;
    FReportFormat := LSource.ReportFormat;
    FStatus := LSource.Status;
    FWorkingContextJson := LSource.WorkingContextJson;
    FContinuation := LSource.Continuation;
    FClientSqlRequests.Clear;
    for I := 0 to LSource.ClientSqlRequests.Count - 1 do
    begin
      LRequest := TRpClientSqlRequest.Create;
      LRequest.Assign(TRpClientSqlRequest(LSource.ClientSqlRequests[I]));
      FClientSqlRequests.Add(LRequest);
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TRpModifyReportResult.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LRequest: TRpClientSqlRequest;
  LValue: TJSONValue;
begin
  FClientSqlRequests.Clear;
  if AObject = nil then
    Exit;
  FContextJson := JsonValueToString(AObject.Values['contextJson'], '');
  FOperationsJson := JsonValueToString(AObject.Values['operationsJson'], '');
  FModifiedReportDocument := JsonValueToString(AObject.Values['modifiedReportDocument'], '');
  FExplanation := JsonValueToString(AObject.Values['explanation'], '');
  FErrorMessage := JsonValueToString(AObject.Values['errorMessage'], '');
  FReportFormat := RpReportDocumentFormatFromString(JsonValueToString(AObject.Values['reportFormat'], 'Xml'));
  FStatus := JsonValueToString(AObject.Values['status'], '');
  FWorkingContextJson := JsonValueToString(AObject.Values['workingContextJson'], '');
  FContinuation := JsonValueToString(AObject.Values['continuation'], '');
  LValue := AObject.Values['clientSqlRequests'];
  if (LValue <> nil) and (LValue is TJSONArray) then
  begin
    LArray := TJSONArray(LValue);
    for I := 0 to LArray.Count - 1 do
    begin
      if not (LArray.Items[I] is TJSONObject) then
        Continue;
      LRequest := TRpClientSqlRequest.Create;
      LRequest.FromJsonObject(TJSONObject(LArray.Items[I]));
      FClientSqlRequests.Add(LRequest);
    end;
  end;
end;

function TRpModifyReportResult.GetSuccess: Boolean;
begin
  Result := Trim(FErrorMessage) = '';
end;

function TRpModifyReportResult.NeedsClientSqlResults: Boolean;
begin
  Result := SameText(FStatus, RP_MODIFY_STATUS_NEEDS_CLIENT_SQL);
end;

function TRpModifyReportResult.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('contextJson', FContextJson);
  Result.AddPair('operationsJson', FOperationsJson);
  Result.AddPair('modifiedReportDocument', FModifiedReportDocument);
  Result.AddPair('explanation', FExplanation);
  Result.AddPair('errorMessage', FErrorMessage);
  Result.AddPair('reportFormat', RpReportDocumentFormatToString(FReportFormat));
  Result.AddPair('success', TJSONBool.Create(Success));
  if FStatus <> '' then
    Result.AddPair('status', FStatus);
  if FWorkingContextJson <> '' then
    Result.AddPair('workingContextJson', FWorkingContextJson);
  if FContinuation <> '' then
    Result.AddPair('continuation', FContinuation);
  if FClientSqlRequests.Count > 0 then
  begin
    LArray := TJSONArray.Create;
    for I := 0 to FClientSqlRequests.Count - 1 do
      LArray.AddElement(TRpClientSqlRequest(FClientSqlRequests[I]).ToJsonObject);
    Result.AddPair('clientSqlRequests', LArray);
  end;
end;

constructor TRpApiModifyReportRequest.Create;
begin
  inherited Create;
  FConfig := TRpApiDatabaseConfig.Create;
  FUserInstructions := TStringList.Create;
  FClientSqlResults := TObjectList.Create(True);
  FMode := rdmFast;
  FReportFormat := rdfXml;
  FReturnModifiedDocument := True;
  FAITier := ratStandard;
  FHasAgentAiId := False;
end;

destructor TRpApiModifyReportRequest.Destroy;
begin
  FClientSqlResults.Free;
  FConfig.Free;
  FUserInstructions.Free;
  inherited Destroy;
end;

procedure TRpApiModifyReportRequest.Assign(Source: TPersistent);
var
  I: Integer;
  LResult: TRpClientSqlResult;
  LSource: TRpApiModifyReportRequest;
begin
  if Source is TRpApiModifyReportRequest then
  begin
    LSource := TRpApiModifyReportRequest(Source);
    FAgentAiId := LSource.AgentAiId;
    FAgentSecret := LSource.AgentSecret;
    FAITier := LSource.AITier;
    FApiKey := LSource.ApiKey;
    FConfig.Assign(LSource.Config);
    FClientExecutesSql := LSource.ClientExecutesSql;
    FContinuation := LSource.Continuation;
    FClientSqlResults.Clear;
    for I := 0 to LSource.ClientSqlResults.Count - 1 do
    begin
      LResult := TRpClientSqlResult.Create;
      LResult.Assign(TRpClientSqlResult(LSource.ClientSqlResults[I]));
      FClientSqlResults.Add(LResult);
    end;
    FExistingContextJson := LSource.ExistingContextJson;
    FExistingOperationsJson := LSource.ExistingOperationsJson;
    FHasAgentAiId := LSource.HasAgentAiId;
    FMode := LSource.Mode;
    FReportDocument := LSource.ReportDocument;
    FReportFormat := LSource.ReportFormat;
    FReturnModifiedDocument := LSource.ReturnModifiedDocument;
    FSimplifiedPrompt := LSource.SimplifiedPrompt;
    FUserLanguage := LSource.UserLanguage;
    FUserInstructions.Assign(LSource.UserInstructions);
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiModifyReportRequest.AssignSharedRequest(ASource: TRpModifyReportRequest);
begin
  if ASource = nil then
    Exit;
  FExistingContextJson := ASource.ExistingContextJson;
  FExistingOperationsJson := ASource.ExistingOperationsJson;
  FReportDocument := ASource.ReportDocument;
  FReportFormat := ASource.ReportFormat;
  FReturnModifiedDocument := ASource.ReturnModifiedDocument;
  FUserLanguage := ASource.UserLanguage;
  FUserInstructions.Assign(ASource.UserInstructions);
end;

procedure TRpApiModifyReportRequest.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LConfig: TJSONObject;
  LResult: TRpClientSqlResult;
  LValue: TJSONValue;
begin
  FClientSqlResults.Clear;
  if AObject = nil then
    Exit;
  FClientExecutesSql := JsonValueToBoolean(AObject.Values['clientExecutesSql'], False);
  FContinuation := JsonValueToString(AObject.Values['continuation'], '');
  LValue := AObject.Values['clientSqlResults'];
  if (LValue <> nil) and (LValue is TJSONArray) then
  begin
    LArray := TJSONArray(LValue);
    for I := 0 to LArray.Count - 1 do
    begin
      if not (LArray.Items[I] is TJSONObject) then
        Continue;
      LResult := TRpClientSqlResult.Create;
      LResult.FromJsonObject(TJSONObject(LArray.Items[I]));
      FClientSqlResults.Add(LResult);
    end;
  end;
  LConfig := AObject.Values['config'] as TJSONObject;
  FAITier := RpAITierTypeFromString(JsonValueToString(AObject.Values['aiTier'], 'Standard'));
  FMode := RpReportDesignerModeFromString(JsonValueToString(AObject.Values['mode'], 'Fast'));
  FSimplifiedPrompt := JsonValueToBoolean(AObject.Values['simplifiedPrompt'], False);
  FApiKey := JsonValueToString(AObject.Values['apiKey'], '');
  FAgentSecret := JsonValueToString(AObject.Values['agentSecret'], '');
  FHasAgentAiId := AObject.Values['agentAiId'] <> nil;
  FAgentAiId := JsonValueToInt64(AObject.Values['agentAiId'], 0);
  FConfig.FromJsonObject(LConfig);
  FReportDocument := JsonValueToString(AObject.Values['reportDocument'], '');
  FReportFormat := RpReportDocumentFormatFromString(JsonValueToString(AObject.Values['reportFormat'], 'Xml'));
  LoadStringsFromJsonArray(FUserInstructions, AObject.Values['userInstructions'] as TJSONArray);
  FUserLanguage := JsonValueToString(AObject.Values['userLanguage'], '');
  FExistingOperationsJson := JsonValueToString(AObject.Values['existingOperationsJson'], '');
  FExistingContextJson := JsonValueToString(AObject.Values['existingContextJson'], '');
  FReturnModifiedDocument := JsonValueToBoolean(AObject.Values['returnModifiedDocument'], True);
end;

function TRpApiModifyReportRequest.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('aiTier', RpAITierTypeToString(FAITier));
  Result.AddPair('mode', RpReportDesignerModeToString(FMode));
  Result.AddPair('simplifiedPrompt', TJSONBool.Create(FSimplifiedPrompt));
  if FApiKey <> '' then
    Result.AddPair('apiKey', FApiKey);
  if FAgentSecret <> '' then
    Result.AddPair('agentSecret', FAgentSecret);
  if FHasAgentAiId then
    Result.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
  Result.AddPair('config', FConfig.ToJsonObject);
  Result.AddPair('reportDocument', FReportDocument);
  Result.AddPair('reportFormat', RpReportDocumentFormatToString(FReportFormat));
  Result.AddPair('userInstructions', StringsToJsonArray(FUserInstructions));
  Result.AddPair('userLanguage', FUserLanguage);
  Result.AddPair('existingOperationsJson', FExistingOperationsJson);
  Result.AddPair('existingContextJson', FExistingContextJson);
  Result.AddPair('returnModifiedDocument', TJSONBool.Create(FReturnModifiedDocument));
  if FClientExecutesSql then
    Result.AddPair('clientExecutesSql', TJSONBool.Create(True));
  if FContinuation <> '' then
    Result.AddPair('continuation', FContinuation);
  if FClientSqlResults.Count > 0 then
  begin
    LArray := TJSONArray.Create;
    for I := 0 to FClientSqlResults.Count - 1 do
      LArray.AddElement(TRpClientSqlResult(FClientSqlResults[I]).ToJsonObject);
    Result.AddPair('clientSqlResults', LArray);
  end;
end;

function TRpApiModifyReportRequest.GetHubDatabaseId: Int64;
begin
  Result := FConfig.HubDatabaseId;
end;

function TRpApiModifyReportRequest.GetHubSchemaId: Int64;
begin
  Result := FConfig.HubSchemaId;
end;

procedure TRpApiModifyReportRequest.SetHubDatabaseId(const Value: Int64);
begin
  FConfig.HubDatabaseId := Value;
end;

procedure TRpApiModifyReportRequest.SetHubSchemaId(const Value: Int64);
begin
  FConfig.HubSchemaId := Value;
end;

constructor TRpApiModifyReportResult.Create;
begin
  inherited Create;
  FResult := TRpModifyReportResult.Create;
  FSteps := TObjectList.Create(True);
  FHasCreditsConsumed := False;
end;

destructor TRpApiModifyReportResult.Destroy;
begin
  FSteps.Free;
  FResult.Free;
  inherited Destroy;
end;

procedure TRpApiModifyReportResult.Assign(Source: TPersistent);
var
  I: Integer;
  LSource: TRpApiModifyReportResult;
  LStep: TRpTokenUsage;
begin
  if Source is TRpApiModifyReportResult then
  begin
    LSource := TRpApiModifyReportResult(Source);
    FCreditsConsumed := LSource.CreditsConsumed;
    FDebugDetails := LSource.DebugDetails;
    FErrorCode := LSource.ErrorCode;
    FErrorMessage := LSource.ErrorMessage;
    FHasCreditsConsumed := LSource.HasCreditsConsumed;
    FUserProfileJson := LSource.UserProfileJson;
    FResult.Assign(LSource.ResultData);
    ClearSteps;
    for I := 0 to LSource.Steps.Count - 1 do
    begin
      LStep := TRpTokenUsage.Create;
      LStep.Assign(TRpTokenUsage(LSource.Steps[I]));
      FSteps.Add(LStep);
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiModifyReportResult.ClearSteps;
begin
  FSteps.Clear;
end;

procedure TRpApiModifyReportResult.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LObject: TJSONObject;
  LStep: TRpTokenUsage;
  LUserProfile: TJSONValue;
begin
  if AObject = nil then
    Exit;
  FResult.FromJsonObject(AObject.Values['result'] as TJSONObject);
  ClearSteps;
  LArray := AObject.Values['steps'] as TJSONArray;
  if LArray <> nil then
  begin
    for I := 0 to LArray.Count - 1 do
    begin
      LObject := LArray.Items[I] as TJSONObject;
      if LObject <> nil then
      begin
        LStep := TRpTokenUsage.Create;
        LStep.FromJsonObject(LObject);
        FSteps.Add(LStep);
      end;
    end;
  end;
  FHasCreditsConsumed := AObject.Values['creditsConsumed'] <> nil;
  FCreditsConsumed := JsonValueToInt(AObject.Values['creditsConsumed'], 0);
  FDebugDetails := JsonValueToString(AObject.Values['debugDetails'], '');
  FErrorCode := '';
  if (AObject.Values['errorCode'] <> nil) and
    not (AObject.Values['errorCode'] is TJSONNull) then
    FErrorCode := AObject.Values['errorCode'].Value;
  FErrorMessage := JsonValueToString(AObject.Values['errorMessage'], '');
  LUserProfile := AObject.Values['userProfile'];
  if (LUserProfile <> nil) and (LUserProfile is TJSONObject) then
    FUserProfileJson := LUserProfile.ToJSON
  else
    FUserProfileJson := '';
end;

function TRpApiModifyReportResult.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
  LProfileValue: TJSONValue;
begin
  Result := TJSONObject.Create;
  Result.AddPair('result', FResult.ToJsonObject);
  LArray := TJSONArray.Create;
  for I := 0 to FSteps.Count - 1 do
    LArray.AddElement(TRpTokenUsage(FSteps[I]).ToJsonObject);
  Result.AddPair('steps', LArray);
  if FHasCreditsConsumed then
    Result.AddPair('creditsConsumed', TJSONNumber.Create(FCreditsConsumed));
  Result.AddPair('debugDetails', FDebugDetails);
  if FErrorCode <> '' then
    Result.AddPair('errorCode', FErrorCode);
  Result.AddPair('errorMessage', FErrorMessage);
  if (FUserProfileJson <> '') and (not SameText(Trim(FUserProfileJson), 'null')) then
  begin
    LProfileValue := TJSONObject.ParseJSONValue(FUserProfileJson);
    if (LProfileValue <> nil) and (LProfileValue is TJSONObject) then
      Result.AddPair('userProfile', LProfileValue);
  end;
end;

constructor TRpApiPreprocessSqlContextDataSource.Create;
begin
  inherited Create;
  FConfig := TRpApiDatabaseConfig.Create;
end;

destructor TRpApiPreprocessSqlContextDataSource.Destroy;
begin
  FConfig.Free;
  inherited Destroy;
end;

procedure TRpApiPreprocessSqlContextDataSource.Assign(Source: TPersistent);
var
  LSource: TRpApiPreprocessSqlContextDataSource;
begin
  if Source is TRpApiPreprocessSqlContextDataSource then
  begin
    LSource := TRpApiPreprocessSqlContextDataSource(Source);
    FConfig.Assign(LSource.Config);
    FDataInfoName := LSource.DataInfoName;
    FDatabaseAlias := LSource.DatabaseAlias;
    FSql := LSource.Sql;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiPreprocessSqlContextDataSource.FromJsonObject(AObject: TJSONObject);
var
  LConfig: TJSONObject;
begin
  if AObject = nil then
    Exit;
  FDataInfoName := JsonValueToString(AObject.Values['dataInfoName'], '');
  FDatabaseAlias := JsonValueToString(AObject.Values['databaseAlias'], '');
  FSql := JsonValueToString(AObject.Values['sql'], '');
  LConfig := AObject.Values['config'] as TJSONObject;
  FConfig.FromJsonObject(LConfig);
end;

function TRpApiPreprocessSqlContextDataSource.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('dataInfoName', FDataInfoName);
  Result.AddPair('databaseAlias', FDatabaseAlias);
  Result.AddPair('sql', FSql);
  if (FConfig.HubDatabaseId <> 0) or (FConfig.HubSchemaId <> 0) or
    FConfig.HasInlineSchema then
    Result.AddPair('config', FConfig.ToJsonObject);
end;

procedure TRpApiPreprocessSqlContextDataSourceResult.Assign(Source: TPersistent);
var
  LSource: TRpApiPreprocessSqlContextDataSourceResult;
begin
  if Source is TRpApiPreprocessSqlContextDataSourceResult then
  begin
    LSource := TRpApiPreprocessSqlContextDataSourceResult(Source);
    FDataInfoName := LSource.DataInfoName;
    FErrorMessage := LSource.ErrorMessage;
    FSqlExplanation := LSource.SqlExplanation;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiPreprocessSqlContextDataSourceResult.FromJsonObject(AObject: TJSONObject);
begin
  if AObject = nil then
    Exit;
  FDataInfoName := JsonValueToString(AObject.Values['dataInfoName'], '');
  FSqlExplanation := JsonValueToString(AObject.Values['sqlExplanation'], '');
  FErrorMessage := JsonValueToString(AObject.Values['errorMessage'], '');
end;

function TRpApiPreprocessSqlContextDataSourceResult.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('dataInfoName', FDataInfoName);
  Result.AddPair('sqlExplanation', FSqlExplanation);
  Result.AddPair('errorMessage', FErrorMessage);
end;

constructor TRpApiPreprocessSqlContextRequest.Create;
begin
  inherited Create;
  FConfig := TRpApiDatabaseConfig.Create;
  FDataSources := TObjectList.Create(True);
  FAITier := ratStandard;
  FMode := rdmFast;
  FHasAgentAiId := False;
end;

destructor TRpApiPreprocessSqlContextRequest.Destroy;
begin
  FDataSources.Free;
  FConfig.Free;
  inherited Destroy;
end;

procedure TRpApiPreprocessSqlContextRequest.Assign(Source: TPersistent);
var
  I: Integer;
  LItem: TRpApiPreprocessSqlContextDataSource;
  LSource: TRpApiPreprocessSqlContextRequest;
begin
  if Source is TRpApiPreprocessSqlContextRequest then
  begin
    LSource := TRpApiPreprocessSqlContextRequest(Source);
    FAgentAiId := LSource.AgentAiId;
    FAgentSecret := LSource.AgentSecret;
    FAITier := LSource.AITier;
    FApiKey := LSource.ApiKey;
    FConfig.Assign(LSource.Config);
    FHasAgentAiId := LSource.HasAgentAiId;
    FMode := LSource.Mode;
    FUserLanguage := LSource.UserLanguage;
    FDataSources.Clear;
    for I := 0 to LSource.DataSources.Count - 1 do
    begin
      LItem := TRpApiPreprocessSqlContextDataSource.Create;
      LItem.Assign(TRpApiPreprocessSqlContextDataSource(LSource.DataSources[I]));
      FDataSources.Add(LItem);
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiPreprocessSqlContextRequest.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LConfig: TJSONObject;
  LItem: TRpApiPreprocessSqlContextDataSource;
  LObject: TJSONObject;
begin
  if AObject = nil then
    Exit;
  FAITier := RpAITierTypeFromString(JsonValueToString(AObject.Values['aiTier'], 'Standard'));
  FMode := RpReportDesignerModeFromString(JsonValueToString(AObject.Values['mode'], 'Fast'));
  FApiKey := JsonValueToString(AObject.Values['apiKey'], '');
  FAgentSecret := JsonValueToString(AObject.Values['agentSecret'], '');
  FHasAgentAiId := AObject.Values['agentAiId'] <> nil;
  FAgentAiId := JsonValueToInt64(AObject.Values['agentAiId'], 0);
  FUserLanguage := JsonValueToString(AObject.Values['userLanguage'], '');
  LConfig := AObject.Values['config'] as TJSONObject;
  FConfig.FromJsonObject(LConfig);
  FDataSources.Clear;
  LArray := AObject.Values['dataSources'] as TJSONArray;
  if LArray <> nil then
  begin
    for I := 0 to LArray.Count - 1 do
    begin
      LObject := LArray.Items[I] as TJSONObject;
      if LObject <> nil then
      begin
        LItem := TRpApiPreprocessSqlContextDataSource.Create;
        LItem.FromJsonObject(LObject);
        FDataSources.Add(LItem);
      end;
    end;
  end;
end;

function TRpApiPreprocessSqlContextRequest.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('aiTier', RpAITierTypeToString(FAITier));
  Result.AddPair('mode', RpReportDesignerModeToString(FMode));
  if FApiKey <> '' then
    Result.AddPair('apiKey', FApiKey);
  if FAgentSecret <> '' then
    Result.AddPair('agentSecret', FAgentSecret);
  if FHasAgentAiId then
    Result.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
  Result.AddPair('config', FConfig.ToJsonObject);
  Result.AddPair('userLanguage', FUserLanguage);
  LArray := TJSONArray.Create;
  for I := 0 to FDataSources.Count - 1 do
    LArray.AddElement(TRpApiPreprocessSqlContextDataSource(FDataSources[I]).ToJsonObject);
  Result.AddPair('dataSources', LArray);
end;

constructor TRpApiPreprocessSqlContextResult.Create;
begin
  inherited Create;
  FDataSources := TObjectList.Create(True);
  FSteps := TObjectList.Create(True);
  FHasCreditsConsumed := False;
end;

destructor TRpApiPreprocessSqlContextResult.Destroy;
begin
  FSteps.Free;
  FDataSources.Free;
  inherited Destroy;
end;

procedure TRpApiPreprocessSqlContextResult.Assign(Source: TPersistent);
var
  I: Integer;
  LDataSource: TRpApiPreprocessSqlContextDataSourceResult;
  LSource: TRpApiPreprocessSqlContextResult;
  LStep: TRpTokenUsage;
begin
  if Source is TRpApiPreprocessSqlContextResult then
  begin
    LSource := TRpApiPreprocessSqlContextResult(Source);
    FCreditsConsumed := LSource.CreditsConsumed;
    FDebugDetails := LSource.DebugDetails;
    FErrorCode := LSource.ErrorCode;
    FErrorMessage := LSource.ErrorMessage;
    FHasCreditsConsumed := LSource.HasCreditsConsumed;
    FUserProfileJson := LSource.UserProfileJson;
    ClearDataSources;
    for I := 0 to LSource.DataSources.Count - 1 do
    begin
      LDataSource := TRpApiPreprocessSqlContextDataSourceResult.Create;
      LDataSource.Assign(TRpApiPreprocessSqlContextDataSourceResult(LSource.DataSources[I]));
      FDataSources.Add(LDataSource);
    end;
    ClearSteps;
    for I := 0 to LSource.Steps.Count - 1 do
    begin
      LStep := TRpTokenUsage.Create;
      LStep.Assign(TRpTokenUsage(LSource.Steps[I]));
      FSteps.Add(LStep);
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiPreprocessSqlContextResult.ClearDataSources;
begin
  FDataSources.Clear;
end;

procedure TRpApiPreprocessSqlContextResult.ClearSteps;
begin
  FSteps.Clear;
end;

procedure TRpApiPreprocessSqlContextResult.FromJsonObject(AObject: TJSONObject);
var
  I: Integer;
  LArray: TJSONArray;
  LDataObject: TJSONObject;
  LItem: TRpApiPreprocessSqlContextDataSourceResult;
  LResultObject: TJSONObject;
  LStep: TRpTokenUsage;
  LStepObject: TJSONObject;
  LUserProfile: TJSONValue;
begin
  if AObject = nil then
    Exit;
  ClearDataSources;
  LResultObject := AObject.Values['result'] as TJSONObject;
  if LResultObject <> nil then
  begin
    LArray := LResultObject.Values['dataSources'] as TJSONArray;
    if LArray <> nil then
    begin
      for I := 0 to LArray.Count - 1 do
      begin
        LDataObject := LArray.Items[I] as TJSONObject;
        if LDataObject <> nil then
        begin
          LItem := TRpApiPreprocessSqlContextDataSourceResult.Create;
          LItem.FromJsonObject(LDataObject);
          FDataSources.Add(LItem);
        end;
      end;
    end;
  end;
  ClearSteps;
  LArray := AObject.Values['steps'] as TJSONArray;
  if LArray <> nil then
  begin
    for I := 0 to LArray.Count - 1 do
    begin
      LStepObject := LArray.Items[I] as TJSONObject;
      if LStepObject <> nil then
      begin
        LStep := TRpTokenUsage.Create;
        LStep.FromJsonObject(LStepObject);
        FSteps.Add(LStep);
      end;
    end;
  end;
  FHasCreditsConsumed := AObject.Values['creditsConsumed'] <> nil;
  FCreditsConsumed := JsonValueToInt(AObject.Values['creditsConsumed'], 0);
  FDebugDetails := JsonValueToString(AObject.Values['debugDetails'], '');
  FErrorCode := '';
  if (AObject.Values['errorCode'] <> nil) and
    not (AObject.Values['errorCode'] is TJSONNull) then
    FErrorCode := AObject.Values['errorCode'].Value;
  FErrorMessage := JsonValueToString(AObject.Values['errorMessage'], '');
  LUserProfile := AObject.Values['userProfile'];
  if (LUserProfile <> nil) and (LUserProfile is TJSONObject) then
    FUserProfileJson := LUserProfile.ToJSON
  else
    FUserProfileJson := '';
end;

function TRpApiPreprocessSqlContextResult.ToJsonObject: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
  LProfileValue: TJSONValue;
  LResultObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  LResultObject := TJSONObject.Create;
  LArray := TJSONArray.Create;
  for I := 0 to FDataSources.Count - 1 do
    LArray.AddElement(TRpApiPreprocessSqlContextDataSourceResult(FDataSources[I]).ToJsonObject);
  LResultObject.AddPair('dataSources', LArray);
  Result.AddPair('result', LResultObject);

  LArray := TJSONArray.Create;
  for I := 0 to FSteps.Count - 1 do
    LArray.AddElement(TRpTokenUsage(FSteps[I]).ToJsonObject);
  Result.AddPair('steps', LArray);
  if FHasCreditsConsumed then
    Result.AddPair('creditsConsumed', TJSONNumber.Create(FCreditsConsumed));
  Result.AddPair('debugDetails', FDebugDetails);
  if FErrorCode <> '' then
    Result.AddPair('errorCode', FErrorCode);
  Result.AddPair('errorMessage', FErrorMessage);
  if (FUserProfileJson <> '') and (not SameText(Trim(FUserProfileJson), 'null')) then
  begin
    LProfileValue := TJSONObject.ParseJSONValue(FUserProfileJson);
    if (LProfileValue <> nil) and (LProfileValue is TJSONObject) then
      Result.AddPair('userProfile', LProfileValue);
  end;
end;

const
{$IFDEF FPC}
  // UTF-8, the encoding of the LCL strings
  RpLogSeparator = ' '#$C2#$B7' ';
  RpLogArrow = ' '#$E2#$86#$92' ';
{$ELSE}
  RpLogSeparator = ' '#$00B7' ';
  RpLogArrow = ' '#$2192' ';
{$ENDIF}

type
  TRpInferenceLogCall = class(TObject)
  public
    StartTime: TDateTime;
    InputTokens: Integer;
    OutputTokens: Integer;
  end;

// One decimal and a point, whatever the regional settings: '4.2'
function FormatTenths(AValue: Double): string;
var
  LTenths: Int64;
begin
  if AValue < 0 then
    AValue := 0;
  LTenths := Round(AValue * 10);
  Result := IntToStr(LTenths div 10) + '.' + IntToStr(LTenths mod 10);
end;

function RpFormatInferenceCallLog(const AProgressId: string; AInputTokens,
  AOutputTokens: Integer; ASeconds: Double): string;
begin
  Result := '#' + AProgressId + RpLogSeparator + IntToStr(AInputTokens) +
    RpLogArrow + IntToStr(AOutputTokens) + ' tok' + RpLogSeparator +
    FormatTenths(ASeconds) + ' s';
  if Round(ASeconds * 10) > 0 then
    Result := Result + RpLogSeparator + FormatTenths(AOutputTokens / ASeconds) +
      ' tok/s';
end;

procedure RpSumTokenUsage(ASteps: TObjectList; var AInputTokens,
  AOutputTokens, AThinkingTokens: Integer; var AModelNames: string);
var
  I: Integer;
  LUsage: TRpTokenUsage;
  LModel: string;
begin
  if ASteps = nil then
    Exit;
  for I := 0 to ASteps.Count - 1 do
  begin
    if not (ASteps[I] is TRpTokenUsage) then
      Continue;
    LUsage := TRpTokenUsage(ASteps[I]);
    Inc(AInputTokens, LUsage.InputTokens);
    Inc(AOutputTokens, LUsage.OutputTokens);
    Inc(AThinkingTokens, LUsage.ThinkingTokens);
    LModel := Trim(LUsage.ModelName);
    if (LModel <> '') and
      (Pos(', ' + LModel + ', ', ', ' + AModelNames + ', ') = 0) then
    begin
      if AModelNames <> '' then
        AModelNames := AModelNames + ', ';
      AModelNames := AModelNames + LModel;
    end;
  end;
end;

function RpFormatInferenceTotalsLog(AInputTokens, AOutputTokens,
  AThinkingTokens: Integer; const AModelNames: string; ASeconds: Double;
  AHasCredits: Boolean; ACredits: Integer): string;
begin
  Result := 'Total' + RpLogSeparator + IntToStr(AInputTokens) + RpLogArrow +
    IntToStr(AOutputTokens) + ' tok';
  if AThinkingTokens > 0 then
    Result := Result + RpLogSeparator + IntToStr(AThinkingTokens) +
      ' thinking tok';
  if Trim(AModelNames) <> '' then
    Result := Result + RpLogSeparator + Trim(AModelNames);
  Result := Result + RpLogSeparator + FormatTenths(ASeconds) + ' s';
  if AHasCredits then
    Result := Result + RpLogSeparator + IntToStr(ACredits) + ' credits';
end;

constructor TRpInferenceLogMeter.Create;
begin
  inherited Create;
  FCalls := TStringList.Create;
  FRequestStart := Now;
end;

destructor TRpInferenceLogMeter.Destroy;
begin
  ClearCalls;
  FCalls.Free;
  inherited Destroy;
end;

procedure TRpInferenceLogMeter.ClearCalls;
var
  I: Integer;
begin
  for I := 0 to FCalls.Count - 1 do
    FCalls.Objects[I].Free;
  FCalls.Clear;
end;

procedure TRpInferenceLogMeter.BeginRequest;
begin
  ClearCalls;
  FRequestStart := Now;
end;

procedure TRpInferenceLogMeter.Frame(const AProgressId: string;
  AInputTokens: Integer; AOutputTokens: Integer);
var
  LIndex: Integer;
  LCall: TRpInferenceLogCall;
  LKey: string;
begin
  LKey := Trim(AProgressId);
  if LKey = '' then
    Exit;
  LIndex := FCalls.IndexOf(LKey);
  if LIndex >= 0 then
    LCall := TRpInferenceLogCall(FCalls.Objects[LIndex])
  else
  begin
    LCall := TRpInferenceLogCall.Create;
    LCall.StartTime := Now;
    FCalls.AddObject(LKey, LCall);
  end;
  if AInputTokens > LCall.InputTokens then
    LCall.InputTokens := AInputTokens;
  if AOutputTokens > LCall.OutputTokens then
    LCall.OutputTokens := AOutputTokens;
end;

function TRpInferenceLogMeter.FinishCall(const AProgressId: string): string;
var
  LIndex: Integer;
  LCall: TRpInferenceLogCall;
  LKey: string;
begin
  Result := '';
  LKey := Trim(AProgressId);
  if LKey = '' then
    Exit;
  LIndex := FCalls.IndexOf(LKey);
  if LIndex < 0 then
    Exit;
  LCall := TRpInferenceLogCall(FCalls.Objects[LIndex]);
  FCalls.Delete(LIndex);
  try
    Result := RpFormatInferenceCallLog(LKey, LCall.InputTokens,
      LCall.OutputTokens, (Now - LCall.StartTime) * SecsPerDay);
  finally
    LCall.Free;
  end;
end;

function TRpInferenceLogMeter.ElapsedSeconds: Double;
begin
  Result := (Now - FRequestStart) * SecsPerDay;
end;

end.
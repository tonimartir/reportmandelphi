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
  SysUtils, Classes, Contnrs, System.JSON;

type
  TRpReportDesignerMode = (rdmFast, rdmReasoning);
  TRpReportDocumentFormat = (rdfJson, rdfXml);
  TRpAITierType = (ratStandard, ratPrecision, ratLocalAgent);

  TRpApiDatabaseConfig = class(TPersistent)
  private
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
  public
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property HubDatabaseId: Int64 read FHubDatabaseId write FHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write FHubSchemaId;
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
    FContextJson: string;
    FErrorMessage: string;
    FExplanation: string;
    FModifiedReportDocument: string;
    FOperationsJson: string;
    FReportFormat: TRpReportDocumentFormat;
    function GetSuccess: Boolean;
  public
    procedure Assign(Source: TPersistent); override;
    procedure FromJsonObject(AObject: TJSONObject);
    function ToJsonObject: TJSONObject;
    property ContextJson: string read FContextJson write FContextJson;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property Explanation: string read FExplanation write FExplanation;
    property ModifiedReportDocument: string read FModifiedReportDocument write FModifiedReportDocument;
    property OperationsJson: string read FOperationsJson write FOperationsJson;
    property ReportFormat: TRpReportDocumentFormat read FReportFormat write FReportFormat;
    property Success: Boolean read GetSuccess;
  end;

  TRpApiModifyReportRequest = class(TPersistent)
  private
    FAgentAiId: Int64;
    FAgentSecret: string;
    FAITier: TRpAITierType;
    FApiKey: string;
    FConfig: TRpApiDatabaseConfig;
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
    property Config: TRpApiDatabaseConfig read FConfig;
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
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property HasCreditsConsumed: Boolean read FHasCreditsConsumed write FHasCreditsConsumed;
    property Steps: TObjectList read FSteps;
    property UserProfileJson: string read FUserProfileJson write FUserProfileJson;
  end;

function RpReportDesignerModeToString(AMode: TRpReportDesignerMode): string;
function RpReportDesignerModeFromString(const AValue: string): TRpReportDesignerMode;
function RpReportDocumentFormatToString(AFormat: TRpReportDocumentFormat): string;
function RpReportDocumentFormatFromString(const AValue: string): TRpReportDocumentFormat;
function RpAITierTypeToString(ATier: TRpAITierType): string;
function RpAITierTypeFromString(const AValue: string): TRpAITierType;
function RpComposeApiErrorMessage(const AErrorMessage, ADebugDetails: string): string;

implementation

function JsonValueToBoolean(AValue: TJSONValue; ADefault: Boolean): Boolean; forward;
function JsonValueToInt(AValue: TJSONValue; ADefault: Integer): Integer; forward;
function JsonValueToInt64(AValue: TJSONValue; ADefault: Int64): Int64; forward;
function JsonValueToString(AValue: TJSONValue; const ADefault: string): string; forward;

procedure TRpApiDatabaseConfig.Assign(Source: TPersistent);
begin
  if Source is TRpApiDatabaseConfig then
  begin
    FHubDatabaseId := TRpApiDatabaseConfig(Source).HubDatabaseId;
    FHubSchemaId := TRpApiDatabaseConfig(Source).HubSchemaId;
  end
  else
    inherited Assign(Source);
end;

procedure TRpApiDatabaseConfig.FromJsonObject(AObject: TJSONObject);
begin
  if AObject = nil then
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    Exit;
  end;
  FHubDatabaseId := JsonValueToInt64(AObject.Values['hubDatabaseId'], 0);
  FHubSchemaId := JsonValueToInt64(AObject.Values['hubSchemaId'], 0);
end;

function TRpApiDatabaseConfig.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  if FHubDatabaseId <> 0 then
    Result.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
  if FHubSchemaId <> 0 then
    Result.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
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

procedure TRpModifyReportResult.Assign(Source: TPersistent);
var
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
  end
  else
    inherited Assign(Source);
end;

procedure TRpModifyReportResult.FromJsonObject(AObject: TJSONObject);
begin
  if AObject = nil then
    Exit;
  FContextJson := JsonValueToString(AObject.Values['contextJson'], '');
  FOperationsJson := JsonValueToString(AObject.Values['operationsJson'], '');
  FModifiedReportDocument := JsonValueToString(AObject.Values['modifiedReportDocument'], '');
  FExplanation := JsonValueToString(AObject.Values['explanation'], '');
  FErrorMessage := JsonValueToString(AObject.Values['errorMessage'], '');
  FReportFormat := RpReportDocumentFormatFromString(JsonValueToString(AObject.Values['reportFormat'], 'Xml'));
end;

function TRpModifyReportResult.GetSuccess: Boolean;
begin
  Result := Trim(FErrorMessage) = '';
end;

function TRpModifyReportResult.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('contextJson', FContextJson);
  Result.AddPair('operationsJson', FOperationsJson);
  Result.AddPair('modifiedReportDocument', FModifiedReportDocument);
  Result.AddPair('explanation', FExplanation);
  Result.AddPair('errorMessage', FErrorMessage);
  Result.AddPair('reportFormat', RpReportDocumentFormatToString(FReportFormat));
  Result.AddPair('success', TJSONBool.Create(Success));
end;

constructor TRpApiModifyReportRequest.Create;
begin
  inherited Create;
  FConfig := TRpApiDatabaseConfig.Create;
  FUserInstructions := TStringList.Create;
  FMode := rdmFast;
  FReportFormat := rdfXml;
  FReturnModifiedDocument := True;
  FAITier := ratStandard;
  FHasAgentAiId := False;
end;

destructor TRpApiModifyReportRequest.Destroy;
begin
  FConfig.Free;
  FUserInstructions.Free;
  inherited Destroy;
end;

procedure TRpApiModifyReportRequest.Assign(Source: TPersistent);
var
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
  LConfig: TJSONObject;
begin
  if AObject = nil then
    Exit;
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
  if (FConfig.HubDatabaseId <> 0) or (FConfig.HubSchemaId <> 0) then
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
  Result.AddPair('errorMessage', FErrorMessage);
  if (FUserProfileJson <> '') and (not SameText(Trim(FUserProfileJson), 'null')) then
  begin
    LProfileValue := TJSONObject.ParseJSONValue(FUserProfileJson);
    if (LProfileValue <> nil) and (LProfileValue is TJSONObject) then
      Result.AddPair('userProfile', LProfileValue);
  end;
end;

end.
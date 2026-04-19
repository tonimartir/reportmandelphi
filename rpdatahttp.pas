{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpdatahttp                                      }
{       Remote HTTP Hub-Agent Driver                    }
{                                                       }
{       Copyright (c) 1994-2025 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}
unit rpdatahttp;
interface
{$I rpconf.inc}


uses
  SysUtils, Classes, DB, StrUtils, System.IOUtils,
{$IFDEF FIREDAC}
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
{$ELSE}
  // Fallback to Indy if TNetHTTPClient is not available
  IdHTTP, IdSSLOpenSSL,
{$ENDIF}
  System.JSON,
  System.DateUtils,
  System.NetEncoding,
{$IFDEF USERPDATASET}
  DBClient,
{$ENDIF}
  rptypes, rpmdconsts, rpauthmanager, rpreportdesignercontracts,
  rpaireportcontracts;
type
  TRpExpressionStreamProgressEvent = procedure(Sender: TObject; const AStage,
    AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer) of object;
  TRpExpressionStreamResultEvent = procedure(Sender: TObject;
    AResultJson: TJSONObject; const AErrorMessage: string) of object;
  TRpExpressionStreamCancelEvent = function(Sender: TObject): Boolean of object;

  { TRpDatabaseHttp }
  TRpDatabaseHttp = class(TObject)
  private
    FApiKey: string;
    FToken: string;
    FInstallId: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FAITier: string;
    FAgentSecret: string;
    FAgentAiId: Int64;
    FConnected: Boolean;
    procedure SetConnected(Value: Boolean);
  public
    class function GetHubDatabases(const AApiKey: string; AList: TStrings): Boolean;
    constructor Create;
    function TestConnection: Boolean;
    property ApiKey: string read FApiKey write FApiKey;
    property Token: string read FToken write FToken;
    property InstallId: string read FInstallId write FInstallId;
    property HubDatabaseId: Int64 read FHubDatabaseId write FHubDatabaseId;
    property HubSchemaId: Int64 read FHubSchemaId write FHubSchemaId;
    property AITier: string read FAITier write FAITier;
    property AgentSecret: string read FAgentSecret write FAgentSecret;
    property AgentAiId: Int64 read FAgentAiId write FAgentAiId;
    property Connected: Boolean read FConnected write SetConnected;
    function SuggestSql(const ASql: string; ACursorPosition: Integer; AMode: string;
      Sender: TObject = nil;
      AOnProgress: TRpExpressionStreamProgressEvent = nil;
      ACancel: TRpExpressionStreamCancelEvent = nil): TJSONObject;
    function TranslateToSql(const AUserPrompt, ASqlToRefine, AMode,
      AUserLanguage: string;
      Sender: TObject = nil;
      AOnProgress: TRpExpressionStreamProgressEvent = nil;
      ACancel: TRpExpressionStreamCancelEvent = nil): TJSONObject;
    function ExplainSql(const ASql: string; const AMode, AUserLanguage: string;
      Sender: TObject = nil;
      AOnProgress: TRpExpressionStreamProgressEvent = nil;
      ACancel: TRpExpressionStreamCancelEvent = nil): TJSONObject;
    function GetTableSchema(const ASql: string): TJSONObject;
    function ModifyReport(ARequest: TRpApiModifyReportRequest;
      Sender: TObject = nil;
      AOnProgress: TRpExpressionStreamProgressEvent = nil;
      ACancel: TRpExpressionStreamCancelEvent = nil): TRpApiModifyReportResult;
    function PreprocessSqlContext(ARequest: TRpApiPreprocessSqlContextRequest;
      Sender: TObject = nil;
      AOnProgress: TRpExpressionStreamProgressEvent = nil;
      ACancel: TRpExpressionStreamCancelEvent = nil): TRpApiPreprocessSqlContextResult;
    function SubmitAIReport(AReport: TRpAIReport): Boolean;
    function SuggestExpressionStream(const APrompt, ACurrentExpression: string;
      ACursorPosition: Integer; const AMode: string; AFix: Boolean;
      const ASemanticContextJson: string; Sender: TObject;
      AOnProgress: TRpExpressionStreamProgressEvent;
      AOnResult: TRpExpressionStreamResultEvent;
      ACancel: TRpExpressionStreamCancelEvent): Boolean;
    function GetSchemas(AList: TStrings): Boolean;
    function GetUserSchemas(AList: TStrings): Boolean;
    function GetUserAgents(AList: TStrings): Boolean;
    function InternalRequest(const AAction: string; const RequestBody: TJSONObject; ResponseStream: TStream): Boolean;
    function InternalGetRequest(const AAction: string; ResponseStream: TStream): Boolean;
  end;
  { TRpDatasetHttp }
  TRpDatasetHttp = class(TPersistent)
  private
    FDatabase: TRpDatabaseHttp;
    FSql: string;
    FDataset: TClientDataSet;
  public
    constructor Create(ADatabase: TRpDatabaseHttp; ADataset: TClientDataSet);
    destructor Destroy; override;
    procedure Open;
    property Sql: string read FSql write FSql;
    property Dataset: TClientDataSet read FDataset;
  end;

// HUB_API_URL constants moved to rptypes.pas

implementation

const
  MODIFY_REPORT_TIMEOUT_MS = 10 * 60 * 1000;

function NormalizeUserLanguage(const AUserLanguage: string): string;
var
  LValue: string;
begin
  LValue := Trim(AUserLanguage);
  if LValue = '' then
    Exit('English');

  if SameText(LValue, 'English') or SameText(LValue, 'en') or
    SameText(LValue, 'en-US') or SameText(LValue, 'en-GB') then
    Exit('English');
  if SameText(LValue, 'Spanish') or SameText(LValue, 'es') or
    SameText(LValue, 'es-ES') then
    Exit('Spanish');
  if SameText(LValue, 'Italian') or SameText(LValue, 'it') or
    SameText(LValue, 'it-IT') then
    Exit('Italian');
  if SameText(LValue, 'French') or SameText(LValue, 'fr') or
    SameText(LValue, 'fr-FR') then
    Exit('French');
  if SameText(LValue, 'German') or SameText(LValue, 'de') or
    SameText(LValue, 'de-DE') then
    Exit('German');
  if SameText(LValue, 'Portuguese') or SameText(LValue, 'pt') or
    SameText(LValue, 'pt-PT') or SameText(LValue, 'pt-BR') then
    Exit('Portuguese');
  if SameText(LValue, 'Chinese') or SameText(LValue, 'zh') or
    SameText(LValue, 'zh-CN') or SameText(LValue, 'zh-TW') then
    Exit('Chinese');
  if SameText(LValue, 'Catalan') or SameText(LValue, 'ca') or
    SameText(LValue, 'ca-ES') then
    Exit('Catalan');

  Result := 'English';
end;

function ResolveTranscribeLanguage(const AUserLanguage: string): string;
begin
  Result := NormalizeUserLanguage(AUserLanguage);
  if Trim(Result) = '' then
    Result := 'Auto';
end;

type
  TRpExpressionStreamContext = class
  private
    FCancelled: Boolean;
    FLastReadPos: Int64;
    FPendingBytes: TBytes;
    FResponseStream: TMemoryStream;
    FSender: TObject;
    FOnCancel: TRpExpressionStreamCancelEvent;
    FOnProgress: TRpExpressionStreamProgressEvent;
    FOnResult: TRpExpressionStreamResultEvent;
    procedure AppendBytes(const ASource: TBytes; ACount: Integer);
    procedure DispatchDone;
    procedure DispatchJson(const AJsonText: string);
    procedure ProcessPendingBytes;
  public
    constructor Create(AResponseStream: TMemoryStream; ASender: TObject;
      AOnProgress: TRpExpressionStreamProgressEvent;
      AOnResult: TRpExpressionStreamResultEvent;
      AOnCancel: TRpExpressionStreamCancelEvent);
    procedure HandleReceiveData(const SenderHttp: TObject; AContentLength,
      AReadCount: Int64; var Abort: Boolean);
    procedure ReadNewBytes;
    property Cancelled: Boolean read FCancelled;
  end;

  TRpApiStreamCapture = class
  private
    FErrorMessage: string;
    FForwardCancel: TRpExpressionStreamCancelEvent;
    FForwardProgress: TRpExpressionStreamProgressEvent;
    FResultJson: TJSONObject;
    FSender: TObject;
  public
    constructor Create(ASender: TObject;
      AOnProgress: TRpExpressionStreamProgressEvent;
      AOnCancel: TRpExpressionStreamCancelEvent);
    destructor Destroy; override;
    function HandleCancel(Sender: TObject): Boolean;
    procedure HandleProgress(Sender: TObject; const AStage, AChunkType,
      AChunk: string; AInputTokens, AOutputTokens: Integer);
    procedure HandleResult(Sender: TObject; AResultJson: TJSONObject;
      const AErrorMessage: string);
    function TakeResultJson: TJSONObject;
    property ErrorMessage: string read FErrorMessage;
  end;

{ TRpDatabaseHttp }

constructor TRpExpressionStreamContext.Create(AResponseStream: TMemoryStream;
  ASender: TObject; AOnProgress: TRpExpressionStreamProgressEvent;
  AOnResult: TRpExpressionStreamResultEvent;
  AOnCancel: TRpExpressionStreamCancelEvent);
begin
  inherited Create;
  FResponseStream := AResponseStream;
  FSender := ASender;
  FOnProgress := AOnProgress;
  FOnResult := AOnResult;
  FOnCancel := AOnCancel;
  FCancelled := False;
  FLastReadPos := 0;
  SetLength(FPendingBytes, 0);
end;

procedure TRpExpressionStreamContext.AppendBytes(const ASource: TBytes;
  ACount: Integer);
var
  LOldLen: Integer;
begin
  if ACount <= 0 then
    Exit;
  LOldLen := Length(FPendingBytes);
  SetLength(FPendingBytes, LOldLen + ACount);
  Move(ASource[0], FPendingBytes[LOldLen], ACount);
end;

procedure TRpExpressionStreamContext.DispatchDone;
begin
  if Assigned(FOnResult) then
    FOnResult(FSender, nil, '');
end;

procedure TRpExpressionStreamContext.DispatchJson(const AJsonText: string);
var
  LJson: TJSONObject;
  LStage: string;
  LChunkType: string;
  LChunk: string;
  LInputTokens: Integer;
  LOutputTokens: Integer;
  LVal: TJSONValue;
begin
  try
    try
      LJson := TJSONObject.ParseJSONValue(AJsonText) as TJSONObject;
      if LJson = nil then
      begin
        TFile.AppendAllText(ExtractFilePath(ParamStr(0)) + 'sse_debug.log', 'FAILED TO PARSE JSON' + #13#10);
        Exit;
      end;
      
      try
        if (LJson.Values['actor'] <> nil) and (LJson.Values['stage'] <> nil) then
        begin
          if Assigned(FOnProgress) then
          begin
            LStage := LJson.Values['stage'].Value;
            if LJson.Values['chunkType'] <> nil then
              LChunkType := LJson.Values['chunkType'].Value
            else
              LChunkType := '';
            if LJson.Values['chunk'] <> nil then
              LChunk := LJson.Values['chunk'].Value
            else
              LChunk := '';
              
            LVal := LJson.Values['inputTokens'];
            if (LVal <> nil) and not (LVal is TJSONNull) then
            begin
              try
                LInputTokens := StrToIntDef(LVal.Value, 0);
              except
                LInputTokens := 0;
              end;
            end
            else
              LInputTokens := 0;

            LVal := LJson.Values['outputTokens'];
            if (LVal <> nil) and not (LVal is TJSONNull) then
            begin
              try
                LOutputTokens := StrToIntDef(LVal.Value, 0);
              except
                LOutputTokens := 0;
              end;
            end
            else
              LOutputTokens := 0;
              
            FOnProgress(FSender, LStage, LChunkType, LChunk, LInputTokens, LOutputTokens);
          end;
        end
        else if (LJson.Values['result'] <> nil) or (LJson.Values['errorMessage'] <> nil) then
        begin
          if Assigned(FOnResult) then
            FOnResult(FSender, TJSONObject(LJson.Clone), '');
        end;
      finally
        LJson.Free;
      end;
    except
      on E: Exception do
        TFile.AppendAllText(ExtractFilePath(ParamStr(0)) + 'sse_debug.log', 'EXCEPTION in DispatchJson: ' + E.Message + #13#10);
    end;
  except
  end;
end;

procedure TRpExpressionStreamContext.ProcessPendingBytes;
var
  I: Integer;
  LLineBytes: TBytes;
  LLineText: string;
  LRemaining: TBytes;
  LLineLen: Integer;
begin
  I := 0;
  while I < Length(FPendingBytes) do
  begin
    if FPendingBytes[I] = 10 then
    begin
      LLineLen := I;
      if (LLineLen > 0) and (FPendingBytes[LLineLen - 1] = 13) then
        Dec(LLineLen);
      SetLength(LLineBytes, LLineLen);
      if LLineLen > 0 then
        Move(FPendingBytes[0], LLineBytes[0], LLineLen);
      LLineText := TEncoding.UTF8.GetString(LLineBytes);

      if StartsText('data: ', LLineText) then
      begin
        LLineText := Copy(LLineText, 7, MaxInt);
        if LLineText = '[DONE]' then
          DispatchDone
        else if LLineText <> '' then
          DispatchJson(LLineText);
      end;

      SetLength(LRemaining, Length(FPendingBytes) - (I + 1));
      if Length(LRemaining) > 0 then
        Move(FPendingBytes[I + 1], LRemaining[0], Length(LRemaining));
      FPendingBytes := LRemaining;
      I := 0;
    end
    else
      Inc(I);
  end;
end;

procedure TRpExpressionStreamContext.ReadNewBytes;
var
  LNewSize: Int64;
  LChunkBytes: TBytes;
  LChunkCount: Integer;
begin
  LNewSize := FResponseStream.Size - FLastReadPos;
  if LNewSize <= 0 then
    Exit;

  SetLength(LChunkBytes, LNewSize);
  FResponseStream.Position := FLastReadPos;
  LChunkCount := FResponseStream.Read(LChunkBytes[0], LNewSize);
  if LChunkCount > 0 then
  begin
    AppendBytes(LChunkBytes, LChunkCount);
    Inc(FLastReadPos, LChunkCount);
    ProcessPendingBytes;
  end;
end;

procedure TRpExpressionStreamContext.HandleReceiveData(const SenderHttp: TObject;
  AContentLength, AReadCount: Int64; var Abort: Boolean);
begin
  FCancelled := Assigned(FOnCancel) and FOnCancel(FSender);
  if FCancelled then
  begin
    Abort := True;
    Exit;
  end;
  ReadNewBytes;
end;

constructor TRpApiStreamCapture.Create(ASender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  AOnCancel: TRpExpressionStreamCancelEvent);
begin
  inherited Create;
  FSender := ASender;
  FForwardProgress := AOnProgress;
  FForwardCancel := AOnCancel;
  FResultJson := nil;
  FErrorMessage := '';
end;

destructor TRpApiStreamCapture.Destroy;
begin
  FResultJson.Free;
  inherited Destroy;
end;

function TRpApiStreamCapture.HandleCancel(Sender: TObject): Boolean;
begin
  Result := Assigned(FForwardCancel) and FForwardCancel(FSender);
end;

procedure TRpApiStreamCapture.HandleProgress(Sender: TObject; const AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
begin
  if Assigned(FForwardProgress) then
    FForwardProgress(FSender, AStage, AChunkType, AChunk, AInputTokens,
      AOutputTokens);
end;

procedure TRpApiStreamCapture.HandleResult(Sender: TObject;
  AResultJson: TJSONObject; const AErrorMessage: string);
begin
  if AErrorMessage <> '' then
    FErrorMessage := AErrorMessage;
  if AResultJson <> nil then
  begin
    FreeAndNil(FResultJson);
    FResultJson := AResultJson;
  end;
end;

function TRpApiStreamCapture.TakeResultJson: TJSONObject;
begin
  Result := FResultJson;
  FResultJson := nil;
end;

{$IFDEF FIREDAC}
function StreamJsonRequest(AClient: TRpDatabaseHttp; const AAction: string;
  const RequestBody: TJSONObject; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TJSONObject;
var
  LCapture: TRpApiStreamCapture;
  LContext: TRpExpressionStreamContext;
  LHttpClient: TNetHTTPClient;
  LRequestStream: TStringStream;
  LResponse: IHTTPResponse;
  LResponseStream: TMemoryStream;
  LUrl: string;
  LStartedAt: TDateTime;
begin
  Result := nil;
  LHttpClient := TNetHTTPClient.Create(nil);
  LResponseStream := TMemoryStream.Create;
  LCapture := TRpApiStreamCapture.Create(Sender, AOnProgress, ACancel);
  LContext := TRpExpressionStreamContext.Create(LResponseStream, LCapture,
    LCapture.HandleProgress, LCapture.HandleResult, LCapture.HandleCancel);
  try
    TRpAuthManager.Instance.ConfigureDebugHttpClient(LHttpClient);
    if SameText(AAction, 'ReportDesigner/ModifyReportStream') then
    begin
      LHttpClient.ConnectionTimeout := MODIFY_REPORT_TIMEOUT_MS;
      LHttpClient.ResponseTimeout := MODIFY_REPORT_TIMEOUT_MS;
      TRpAuthManager.Instance.Log('HTTP Request Body: ' + RequestBody.ToJSON);
    end;

    LRequestStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      LHttpClient.ContentType := 'application/json';
      LHttpClient.Accept := 'text/event-stream';

      if AClient.ApiKey <> '' then
        LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := AClient.ApiKey;

      if AClient.Token <> '' then
        LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AClient.Token;

      if AClient.InstallId <> '' then
        LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := AClient.InstallId;

      LUrl := HUB_API_URL;
      if not LUrl.EndsWith('/') then
        LUrl := LUrl + '/';
      LUrl := LUrl + AAction;
      TRpAuthManager.Instance.Log('HTTP Request: POST ' + LUrl);

      LHttpClient.OnReceiveData := LContext.HandleReceiveData;
      LStartedAt := Now;
      LResponse := LHttpClient.Post(LUrl, LRequestStream, LResponseStream);
      LContext.ReadNewBytes;

      TRpAuthManager.Instance.Log('HTTP Response Status: ' +
        IntToStr(LResponse.StatusCode) + ' (' +
        IntToStr(MilliSecondsBetween(Now, LStartedAt)) + ' ms)');

      if LContext.Cancelled then
        Exit(nil);

      if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 300) then
      begin
        LResponseStream.Position := 0;
        raise Exception.CreateFmt('HTTP Error %d: %s',
          [LResponse.StatusCode, LResponse.StatusText]);
      end;

      if LCapture.ErrorMessage <> '' then
        raise Exception.Create(LCapture.ErrorMessage);

      Result := LCapture.TakeResultJson;
    finally
      LRequestStream.Free;
    end;
  finally
    LContext.Free;
    LCapture.Free;
    LResponseStream.Free;
    LHttpClient.Free;
  end;
end;
{$ENDIF}

constructor TRpDatabaseHttp.Create;
begin
  inherited Create;
  FConnected := False;
  FInstallId := TRpAuthManager.Instance.InstallId;
  ;
  FAITier := 'Standard';
end;
procedure TRpDatabaseHttp.SetConnected(Value: Boolean);
begin
  if Value <> FConnected then
  begin
    if Value then
    begin
      if not TestConnection then
         raise Exception.Create(SRpConnectionFailed);
    end;
    FConnected := Value;
  end;
end;
function TRpDatabaseHttp.TestConnection: Boolean;
var
  LRequestBody: TJSONObject;
  LResponseStream: TMemoryStream;
begin
  Result := False;
  LRequestBody := TJSONObject.Create;
  try
    LRequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    LResponseStream := TMemoryStream.Create;
    try
      // The endpoint is as defined in HubApiClient.Sql.cs
      Result := InternalRequest('api/agent/testconnection', LRequestBody, LResponseStream);
      // We could also parse the response to check { success: true, message: ... }
      // But InternalRequest already checks for HTTP 200/201
    finally
      LResponseStream.Free;
    end;
  finally
    LRequestBody.Free;
  end;
end;
function TRpDatabaseHttp.SuggestSql(const ASql: string;
  ACursorPosition: Integer; AMode: string; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TJSONObject;
var
  LRequest, LConfig: TJSONObject;
{$IFNDEF FIREDAC}
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
{$ENDIF}
begin
  Result := nil;
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('sql', ASql);
    LRequest.AddPair('cursorPosition', TJSONNumber.Create(ACursorPosition));
    LRequest.AddPair('mode', AMode);
    LRequest.AddPair('aiTier', FAITier);
    if FAgentSecret <> '' then
      LRequest.AddPair('agentSecret', FAgentSecret);
    if FAgentAiId <> 0 then
      LRequest.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
    if FApiKey <> '' then
      LRequest.AddPair('apiKey', FApiKey);
    
    // Config sub-object
    LConfig := TJSONObject.Create;
    LConfig.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    if FHubSchemaId <> 0 then
      LConfig.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
    LRequest.AddPair('config', LConfig);

{$IFDEF FIREDAC}
    Result := StreamJsonRequest(Self, 'NlToSql/SuggestSqlCodeStream', LRequest,
      Sender, AOnProgress, ACancel);
{$ELSE}
    LResponseStream := TStringStream.Create;
    try
      if InternalRequest('NlToSql/SuggestSqlCode', LRequest, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        if LResponseJson <> nil then
          Result := LResponseJson; // Caller owns it
      end;
    finally
      LResponseStream.Free;
    end;
{$ENDIF}
  finally
    LRequest.Free;
  end;
end;

function TRpDatabaseHttp.TranslateToSql(const AUserPrompt, ASqlToRefine,
  AMode, AUserLanguage: string; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TJSONObject;
var
  LRequest, LConfig: TJSONObject;
  LQueries: TJSONArray;
{$IFNDEF FIREDAC}
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
{$ENDIF}
begin
  Result := nil;
  LRequest := TJSONObject.Create;
  try
    LQueries := TJSONArray.Create;
    LQueries.Add(AUserPrompt);
    LRequest.AddPair('userQuery', LQueries);
    LRequest.AddPair('sqlToRefine', ASqlToRefine);
    LRequest.AddPair('mode', AMode);
    LRequest.AddPair('complex', TJSONBool.Create(False));
    LRequest.AddPair('transcribeLanguage',
      ResolveTranscribeLanguage(AUserLanguage));
    LRequest.AddPair('aiTier', FAITier);
    if FAgentSecret <> '' then
      LRequest.AddPair('agentSecret', FAgentSecret);
    if FAgentAiId <> 0 then
      LRequest.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
    if FApiKey <> '' then
      LRequest.AddPair('apiKey', FApiKey);

    LConfig := TJSONObject.Create;
    LConfig.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    if FHubSchemaId <> 0 then
      LConfig.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
    LRequest.AddPair('config', LConfig);

{$IFDEF FIREDAC}
    Result := StreamJsonRequest(Self, 'NlToSql/TranslateToSQLStream', LRequest,
      Sender, AOnProgress, ACancel);
{$ELSE}
    LResponseStream := TStringStream.Create;
    try
      if InternalRequest('NlToSql/TranslateToSQL', LRequest, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        if LResponseJson <> nil then
          Result := LResponseJson;
      end;
    finally
      LResponseStream.Free;
    end;
{$ENDIF}
  finally
    LRequest.Free;
  end;
end;

function TRpDatabaseHttp.ExplainSql(const ASql: string; const AMode,
  AUserLanguage: string; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TJSONObject;
var
  LRequest, LConfig: TJSONObject;
{$IFNDEF FIREDAC}
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
{$ENDIF}
begin
  Result := nil;
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('sqlToExplain', ASql);
    LRequest.AddPair('mode', AMode);
    LRequest.AddPair('aiTier', FAITier);
    LRequest.AddPair('transcribeLanguage',
      ResolveTranscribeLanguage(AUserLanguage));
    if Trim(AUserLanguage) <> '' then
      LRequest.AddPair('userLanguage',
        NormalizeUserLanguage(AUserLanguage));
    if FAgentSecret <> '' then
      LRequest.AddPair('agentSecret', FAgentSecret);
    if FAgentAiId <> 0 then
      LRequest.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
    if FApiKey <> '' then
      LRequest.AddPair('apiKey', FApiKey);

    LConfig := TJSONObject.Create;
    LConfig.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    if FHubSchemaId <> 0 then
      LConfig.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
    LRequest.AddPair('config', LConfig);

{$IFDEF FIREDAC}
    Result := StreamJsonRequest(Self, 'NlToSql/ExplainSQLStream', LRequest,
      Sender, AOnProgress, ACancel);
{$ELSE}
    LResponseStream := TStringStream.Create;
    try
      if InternalRequest('NlToSql/ExplainSQL', LRequest, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        if LResponseJson <> nil then
          Result := LResponseJson;
      end;
    finally
      LResponseStream.Free;
    end;
{$ENDIF}
  finally
    LRequest.Free;
  end;
end;

function TRpDatabaseHttp.GetTableSchema(const ASql: string): TJSONObject;
var
  LRequest: TJSONObject;
  LResponseStream: TStringStream;
begin
  Result := nil;
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('sql', ASql);
    if FHubDatabaseId <> 0 then
      LRequest.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    LResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      if InternalRequest('api/agent/gettableschema', LRequest, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        Result := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
      end;
    finally
      LResponseStream.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

function TRpDatabaseHttp.ModifyReport(
  ARequest: TRpApiModifyReportRequest; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TRpApiModifyReportResult;
var
  LRequestJson: TJSONObject;
  LResponseJson: TJSONObject;
{$IFNDEF FIREDAC}
  LResponseStream: TStringStream;
{$ENDIF}
begin
  Result := nil;
  if ARequest = nil then
    raise Exception.Create('ModifyReport request not assigned');

  LRequestJson := ARequest.ToJsonObject;
  try
{$IFDEF FIREDAC}
    LResponseJson := StreamJsonRequest(Self, 'ReportDesigner/ModifyReportStream',
      LRequestJson, Sender, AOnProgress, ACancel);
    try
      if LResponseJson <> nil then
      begin
        Result := TRpApiModifyReportResult.Create;
        try
          Result.FromJsonObject(LResponseJson);
        except
          Result.Free;
          raise;
        end;
      end;
    finally
      LResponseJson.Free;
    end;
{$ELSE}
    LResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      if InternalRequest('ReportDesigner/ModifyReport', LRequestJson, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        try
          if LResponseJson = nil then
            raise Exception.Create('Invalid JSON response from ReportDesigner/ModifyReport');

          Result := TRpApiModifyReportResult.Create;
          try
            Result.FromJsonObject(LResponseJson);
          except
            Result.Free;
            raise;
          end;
        finally
          LResponseJson.Free;
        end;
      end;
    finally
      LResponseStream.Free;
    end;
{$ENDIF}
  finally
    LRequestJson.Free;
  end;
end;

function TRpDatabaseHttp.PreprocessSqlContext(
  ARequest: TRpApiPreprocessSqlContextRequest; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  ACancel: TRpExpressionStreamCancelEvent): TRpApiPreprocessSqlContextResult;
var
  LRequestJson: TJSONObject;
  LResponseJson: TJSONObject;
{$IFNDEF FIREDAC}
  LResponseStream: TStringStream;
{$ENDIF}
begin
  Result := nil;
  if ARequest = nil then
    raise Exception.Create('PreprocessSqlContext request not assigned');

  LRequestJson := ARequest.ToJsonObject;
  try
{$IFDEF FIREDAC}
    LResponseJson := StreamJsonRequest(Self, 'ReportDesigner/PreprocessSqlContextStream',
      LRequestJson, Sender, AOnProgress, ACancel);
    try
      if LResponseJson <> nil then
      begin
        Result := TRpApiPreprocessSqlContextResult.Create;
        try
          Result.FromJsonObject(LResponseJson);
        except
          Result.Free;
          raise;
        end;
      end;
    finally
      LResponseJson.Free;
    end;
{$ELSE}
    LResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      if InternalRequest('ReportDesigner/PreprocessSqlContext', LRequestJson, LResponseStream) then
      begin
        LResponseStream.Position := 0;
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        try
          if LResponseJson = nil then
            raise Exception.Create('Invalid JSON response from ReportDesigner/PreprocessSqlContext');

          Result := TRpApiPreprocessSqlContextResult.Create;
          try
            Result.FromJsonObject(LResponseJson);
          except
            Result.Free;
            raise;
          end;
        finally
          LResponseJson.Free;
        end;
      end;
    finally
      LResponseStream.Free;
    end;
{$ENDIF}
  finally
    LRequestJson.Free;
  end;
end;

function TRpDatabaseHttp.SubmitAIReport(AReport: TRpAIReport): Boolean;
var
  LRequestJson: TJSONObject;
  LResponseStream: TStringStream;
begin
  Result := False;
  if AReport = nil then
    raise Exception.Create('AI report not assigned');

  LRequestJson := AReport.ToJsonObject;
  try
    LResponseStream := TStringStream.Create('', TEncoding.UTF8);
    try
      Result := InternalRequest('api/aireport', LRequestJson, LResponseStream);
    finally
      LResponseStream.Free;
    end;
  finally
    LRequestJson.Free;
  end;
end;

function TRpDatabaseHttp.SuggestExpressionStream(const APrompt,
  ACurrentExpression: string; ACursorPosition: Integer; const AMode: string;
  AFix: Boolean; const ASemanticContextJson: string; Sender: TObject;
  AOnProgress: TRpExpressionStreamProgressEvent;
  AOnResult: TRpExpressionStreamResultEvent;
  ACancel: TRpExpressionStreamCancelEvent): Boolean;
{$IFDEF FIREDAC}
var
  LHttpClient: TNetHTTPClient;
  LContext: TRpExpressionStreamContext;
  LRequestStream: TStringStream;
  LResponseStream: TMemoryStream;
  LResponse: IHTTPResponse;
  LRequest: TJSONObject;
  LConfig: TJSONObject;
  LUserQuery: TJSONArray;
  LUrl: string;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  LResponseStream := TMemoryStream.Create;
  LContext := TRpExpressionStreamContext.Create(LResponseStream, Sender,
    AOnProgress, AOnResult, ACancel);
  LRequest := TJSONObject.Create;
  try
    TRpAuthManager.Instance.ConfigureDebugHttpClient(LHttpClient);
    LRequest.AddPair('currentExpression', ACurrentExpression);
    LRequest.AddPair('fix', TJSONBool.Create(AFix));
    LRequest.AddPair('cursorPosition', TJSONNumber.Create(ACursorPosition));
    LRequest.AddPair('aiTier', FAITier);
    LRequest.AddPair('mode', AMode);
    LRequest.AddPair('semanticContextJson', ASemanticContextJson);
    if FAgentSecret <> '' then
      LRequest.AddPair('agentSecret', FAgentSecret);
    if FAgentAiId <> 0 then
      LRequest.AddPair('agentAiId', TJSONNumber.Create(FAgentAiId));
    if FApiKey <> '' then
      LRequest.AddPair('apiKey', FApiKey);

    LUserQuery := TJSONArray.Create;
    LUserQuery.Add(APrompt);
    LRequest.AddPair('userQuery', LUserQuery);

    LConfig := TJSONObject.Create;
    if FHubDatabaseId <> 0 then
      LConfig.AddPair('hubDatabaseId', TJSONNumber.Create(FHubDatabaseId));
    if FHubSchemaId <> 0 then
      LConfig.AddPair('hubSchemaId', TJSONNumber.Create(FHubSchemaId));
    LRequest.AddPair('config', LConfig);

    LRequestStream := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
    try
      LHttpClient.ContentType := 'application/json';
      LHttpClient.Accept := 'text/event-stream';
      if FApiKey <> '' then
        LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := FApiKey;
      if FToken <> '' then
        LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
      if FInstallId <> '' then
        LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;

      LHttpClient.OnReceiveData := LContext.HandleReceiveData;
      LUrl := HUB_API_URL;
      if not LUrl.EndsWith('/') then
        LUrl := LUrl + '/';
      LUrl := LUrl + 'ReportmanExpression/SuggestExpressionStream';

      TRpAuthManager.Instance.Log('HTTP Request: POST ' + LUrl);
      LResponse := LHttpClient.Post(LUrl, LRequestStream, LResponseStream);
      LContext.ReadNewBytes;

      if LContext.Cancelled then
        Exit(False);

      if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
        Result := True
      else
        raise Exception.CreateFmt('HTTP Error %d: %s', [LResponse.StatusCode, LResponse.StatusText]);
    finally
      LRequestStream.Free;
    end;
  finally
    LRequest.Free;
    LContext.Free;
    LResponseStream.Free;
    LHttpClient.Free;
  end;
end;
{$ELSE}
var
  LRequest: TJSONObject;
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
begin
  Result := False;
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('currentExpression', ACurrentExpression);
    LRequest.AddPair('fix', TJSONBool.Create(AFix));
    LRequest.AddPair('cursorPosition', TJSONNumber.Create(ACursorPosition));
    LRequest.AddPair('aiTier', FAITier);
    LRequest.AddPair('mode', AMode);
    LRequest.AddPair('semanticContextJson', ASemanticContextJson);
    LRequest.AddPair('userQuery', TJSONArray.Create(APrompt));
    LRequest.AddPair('config', TJSONObject.Create);
    LResponseStream := TStringStream.Create;
    try
      Result := InternalRequest('ReportmanExpression/SuggestExpression', LRequest, LResponseStream);
      if Result and Assigned(AOnResult) then
      begin
        LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
        if LResponseJson <> nil then
          AOnResult(Sender, LResponseJson, '')
        else
          AOnResult(Sender, nil, 'Invalid JSON response');
      end;
    finally
      LResponseStream.Free;
    end;
  finally
    LRequest.Free;
  end;
end;
{$ENDIF}

function TRpDatabaseHttp.GetSchemas(AList: TStrings): Boolean;
var
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
  LDataArray: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
begin
  Result := False;
  AList.Clear;
  LResponseStream := TStringStream.Create;
  try
    // api/agent/databases returns all schemas/databases
    if InternalRequest('api/agent/databases', nil, LResponseStream) then
    begin
       LResponseStream.Position := 0;
       LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
       try
         if LResponseJson <> nil then
         begin
            LDataArray := LResponseJson.Values['data'] as TJSONArray;
            if LDataArray <> nil then
            begin
               for I := 0 to LDataArray.Count - 1 do
               begin
                  LItem := LDataArray.Items[I] as TJSONObject;
                  AList.Add(LItem.Values['displayName'].Value);
               end;
               Result := True;
            end;
         end;
       finally
         LResponseJson.Free;
       end;
    end;
  finally
    LResponseStream.Free;
  end;
end;
function TRpDatabaseHttp.InternalRequest(const AAction: string; const RequestBody: TJSONObject; ResponseStream: TStream): Boolean;
{$IFDEF FIREDAC}
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LSourceStream: TStringStream;
  LErrorStream: TStringStream;
  LUrl: string;
  LStartedAt: TDateTime;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    TRpAuthManager.Instance.ConfigureDebugHttpClient(LHttpClient);
    if SameText(AAction, 'ReportDesigner/ModifyReport') then
    begin
      LHttpClient.ConnectionTimeout := MODIFY_REPORT_TIMEOUT_MS;
      LHttpClient.ResponseTimeout := MODIFY_REPORT_TIMEOUT_MS;
    end;

    LSourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      LHttpClient.ContentType := 'application/json';
      if SameText(AAction, 'ReportDesigner/ModifyReport') then
        TRpAuthManager.Instance.Log('HTTP Request Body: ' + RequestBody.ToJSON);
      
      // Authentication Headers - Match AgentController.cs / TokenAuthenticationMiddleware.cs
      if FApiKey <> '' then
        LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := FApiKey;
      
      if FToken <> '' then
        LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
      
      if FInstallId <> '' then
        LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
      LUrl := HUB_API_URL;
      if not LUrl.EndsWith('/') then LUrl := LUrl + '/';
      LUrl := LUrl + AAction;
      TRpAuthManager.Instance.Log('HTTP Request: POST ' + LUrl);
      LStartedAt := Now;
      LResponse := LHttpClient.Post(LUrl, LSourceStream, ResponseStream);
      TRpAuthManager.Instance.Log('HTTP Response Status: ' + IntToStr(LResponse.StatusCode) +
        ' (' + IntToStr(MilliSecondsBetween(Now, LStartedAt)) + ' ms)');
      
      if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
         Result := True
      else
      begin
         LErrorStream := TStringStream.Create;
         try
           ResponseStream.Position := 0;
           LErrorStream.CopyFrom(ResponseStream, 0);
           TRpAuthManager.Instance.Log('HTTP Error Body: ' + LErrorStream.DataString);
           
           if LResponse.StatusCode = 401 then
           begin
             TRpAuthManager.Instance.Log('Unauthorized (401) detected in InternalRequest. Logging out.');
             TRpAuthManager.Instance.Logout;
           end;

           raise Exception.CreateFmt('HTTP Error %d: %s'#13#10'%s', [LResponse.StatusCode, LResponse.StatusText, LErrorStream.DataString]);
         finally
           LErrorStream.Free;
         end;
      end;
    finally
      LSourceStream.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;
{$ELSE}
var
  LIdHttp: TIdHTTP;
  LSourceStream: TStringStream;
  LErrorStream: TStringStream;
  LUrl: string;
begin
  Result := False;
  LIdHttp := TIdHTTP.Create(nil);
  try
    if SameText(AAction, 'ReportDesigner/ModifyReport') then
    begin
      LIdHttp.ConnectTimeout := MODIFY_REPORT_TIMEOUT_MS;
      LIdHttp.ReadTimeout := MODIFY_REPORT_TIMEOUT_MS;
    end;

    LSourceStream := TStringStream.Create(RequestBody.ToJSON, TEncoding.UTF8);
    try
      LIdHttp.Request.ContentType := 'application/json';
      
      if FApiKey <> '' then
        LIdHttp.Request.CustomHeaders.Values['X-Reportman-ApiKey'] := FApiKey;
      
      if FToken <> '' then
        LIdHttp.Request.CustomHeaders.Values['Authorization'] := 'Bearer ' + FToken;
      
      if FInstallId <> '' then
        LIdHttp.Request.CustomHeaders.Values['X-Reportman-WebInstallId'] := FInstallId;
      LUrl := HUB_API_URL;
      if not LUrl.EndsWith('/') then LUrl := LUrl + '/';
      LUrl := LUrl + AAction;
      LIdHttp.Post(LUrl, LSourceStream, ResponseStream);
      
      if (LIdHttp.ResponseCode >= 200) and (LIdHttp.ResponseCode < 300) then
         Result := True
      else
      begin
         LErrorStream := TStringStream.Create;
         try
           ResponseStream.Position := 0;
           LErrorStream.CopyFrom(ResponseStream, 0);
           raise Exception.CreateFmt('HTTP Error %d: %s'#13#10'%s', [LIdHttp.ResponseCode, LIdHttp.ResponseText, LErrorStream.DataString]);
         finally
           LErrorStream.Free;
         end;
      end;
    finally
      LSourceStream.Free;
    end;
  finally
    LIdHttp.Free;
  end;
end;
{$ENDIF}
{ TRpDatasetHttp }
constructor TRpDatasetHttp.Create(ADatabase: TRpDatabaseHttp; ADataset: TClientDataSet);
begin
  inherited Create;
  FDatabase := ADatabase;
  FDataset := ADataset;
end;
destructor TRpDatasetHttp.Destroy;
begin
  inherited Destroy;
end;
procedure TRpDatasetHttp.Open;
var
  ColType, ColName: string;
  FDef: TFieldDef;
  Field: TField;
  RowData: TJSONArray;
  Val: TJSONValue;
  Buffer: TBytes;
  RequestBody: TJSONObject;
  ResponseStream: TMemoryStream;
  ResponseJson: TJSONObject;
  Columns, Rows: TJSONArray;
  I, J: Integer;
  ColObj: TJSONObject;
  LData: TJSONObject;
  jsonString: String;
  LFloatValue: Double;
  LDateTimeValue: TDateTime;
  LBlobBytes: TBytes;
  LBlobStream: TBytesStream;
  LByteIndex: Integer;
  LInvariantFormatSettings: TFormatSettings;
begin
  if FDatabase = nil then
    raise Exception.Create('Database not assigned');
  LInvariantFormatSettings := TFormatSettings.Invariant;
  RequestBody := TJSONObject.Create;
  try
    RequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(FDatabase.HubDatabaseId));
    RequestBody.AddPair('sql', FSql);
    // Parameters support
    RequestBody.AddPair('parameters', TJSONArray.Create); 
    ResponseStream := TMemoryStream.Create;
    try
      if FDatabase.InternalRequest('api/agent/execute', RequestBody, ResponseStream) then
      begin
        ResponseStream.Position := 0;
        SetLength(Buffer, ResponseStream.Size);
        if ResponseStream.Size > 0 then
          ResponseStream.Read(Buffer[0], ResponseStream.Size);
        jsonString:=TEncoding.UTF8.GetString(Buffer);
        ResponseJson := TJSONObject.ParseJSONValue(jsonString) as TJSONObject;
      try
        if ResponseJson = nil then
          raise Exception.Create('Invalid JSON response from Hub');
        if (ResponseJson.Values['success'] <> nil) and (not (ResponseJson.Values['success'] as TJSONBool).AsBoolean) then
        begin
             if ResponseJson.Values['error'] <> nil then
                raise Exception.Create(ResponseJson.Values['error'].Value)
             else
                raise Exception.Create('Request failed');
        end;
        LData := ResponseJson.GetValue('data') as TJSONObject;
        if not Assigned(LData) then
           raise Exception.Create('No data property in result');
        Columns := LData.GetValue('columns') as TJSONArray;
        if not Assigned(Columns) then
           raise Exception.Create('No columns in the result');
        Rows := LData.GetValue('rows') as TJSONArray;
        if not Assigned(Rows) then
           raise Exception.Create('No rows in result');
        if not Assigned(FDataset) then
        begin
          FDataset:=TClientDataSet.Create(nil);
        end;
        FDataset.Close;
        FDataset.FieldDefs.Clear;
        
        // Setup fields
        for I := 0 to Columns.Count - 1 do
        begin
          ColObj := Columns.Items[I] as TJSONObject;
          ColName := ColObj.Values['name'].Value;
          ColType := ColObj.Values['dataType'].Value;
          
          FDef := FDataset.FieldDefs.AddFieldDef;
          FDef.Name := ColName;
          
          // Map .NET types to Delphi TFieldType
          if ColType = 'Int32' then
            FDef.DataType := ftInteger
          else if ColType = 'Int64' then
            FDef.DataType := ftLargeint
          else if (ColType = 'Double') or (ColType = 'Decimal') or (ColType = 'Single') then
            FDef.DataType := ftFloat
          else if (ColType = 'DateTime') then
            FDef.DataType := ftDateTime
          else if (ColType = 'Boolean') then
            FDef.DataType := ftBoolean
          else if (ColType = 'Byte[]') then
            FDef.DataType := ftBlob
          else
          begin
            FDef.DataType := ftString;
            FDef.Size := 255;
          end;
        end;
        FDataset.CreateDataSet;
        // Populate rows
        for I := 0 to Rows.Count - 1 do
        begin
          FDataset.Append;
          RowData := Rows.Items[I] as TJSONArray;
          for J := 0 to Columns.Count - 1 do
          begin
            Val := RowData.Items[J];
            Field := FDataset.Fields[J];
            if Val is TJSONNull then
              Field.Clear
            else
            begin
              case Field.DataType of
                ftSmallint, ftInteger, ftWord, ftAutoInc:
                  Field.AsInteger := StrToIntDef(Val.Value, 0);
                ftLargeint:
                  Field.AsLargeInt := StrToInt64Def(Val.Value, 0);
                ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
                  begin
                    if Val is TJSONNumber then
                      Field.AsFloat := TJSONNumber(Val).AsDouble
                    else if TryStrToFloat(Val.Value, LFloatValue, LInvariantFormatSettings) then
                      Field.AsFloat := LFloatValue
                    else
                      raise Exception.CreateFmt('Invalid floating point value ''%s'' for field ''%s''', [Val.Value, Field.FieldName]);
                  end;
                ftDate, ftTime, ftDateTime, ftTimeStamp:
                  begin
                    if not TryISO8601ToDate(Val.Value, LDateTimeValue, True) then
                      raise Exception.CreateFmt('Invalid datetime value ''%s'' for field ''%s''', [Val.Value, Field.FieldName]);
                    Field.AsDateTime := LDateTimeValue;
                  end;
                ftBoolean:
                  begin
                    if SameText(Val.Value, 'true') then
                      Field.AsBoolean := True
                    else if SameText(Val.Value, 'false') then
                      Field.AsBoolean := False
                    else
                      Field.AsBoolean := StrToIntDef(Val.Value, 0) <> 0;
                  end;
                ftBlob:
                  begin
                    if Val is TJSONString then
                      LBlobBytes := TNetEncoding.Base64.DecodeStringToBytes(Val.Value)
                    else if Val is TJSONArray then
                    begin
                      SetLength(LBlobBytes, TJSONArray(Val).Count);
                      for LByteIndex := 0 to TJSONArray(Val).Count - 1 do
                        LBlobBytes[LByteIndex] := Byte(StrToIntDef(TJSONArray(Val).Items[LByteIndex].Value, 0));
                    end
                    else
                      raise Exception.CreateFmt('Invalid binary value for field ''%s''', [Field.FieldName]);

                    LBlobStream := TBytesStream.Create(LBlobBytes);
                    try
                      TBlobField(Field).LoadFromStream(LBlobStream);
                    finally
                      LBlobStream.Free;
                    end;
                  end;
              else
                Field.AsString := Val.Value;
              end;
            end;
          end;
          FDataset.Post;
        end;
        FDataset.First;
        
      finally
        ResponseJson.Free;
      end;
    end;
    finally
      ResponseStream.Free;
    end;
  finally
    RequestBody.Free;
  end;
end;

class function TRpDatabaseHttp.GetHubDatabases(const AApiKey: string;
  AList: TStrings): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LResponseStream: TMemoryStream;
  LJson: TJSONObject;
  LDatabases: TJSONArray;
  LItem: TJSONObject;
  LBuffer: TBytes;
  i: Integer;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  LResponseStream := TMemoryStream.Create;
  try
    TRpAuthManager.Instance.ConfigureDebugHttpClient(LHttpClient);
    LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := AApiKey;
    if TRpAuthManager.Instance.Token <> '' then
      LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + TRpAuthManager.Instance.Token;
    if TRpAuthManager.Instance.InstallId <> '' then
      LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := TRpAuthManager.Instance.InstallId;
    // Use the compiled URL for discovery
    try
      LResponse := LHttpClient.Get(HUB_API_URL + '/api/agent/databases', LResponseStream);
      if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) then
      begin
        LResponseStream.Position := 0;
        SetLength(LBuffer, LResponseStream.Size);
        if LResponseStream.Size > 0 then
          LResponseStream.Read(LBuffer[0], LResponseStream.Size);
        LJson := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LBuffer)) as TJSONObject;
        if Assigned(LJson) then
        try
          LDatabases := LJson.GetValue('databases') as TJSONArray;
          if Assigned(LDatabases) then
          begin
            AList.Clear;
            for i := 0 to LDatabases.Count - 1 do
            begin
              LItem := LDatabases.Items[i] as TJSONObject;
              AList.Add(LItem.GetValue('displayName').Value + '=' + LItem.GetValue('hubDatabaseId').Value);
            end;
            Result := True;
          end;
        finally
          LJson.Free;
        end;
      end;
    except
      // Handle connection errors
    end;
  finally
    LResponseStream.Free;
    LHttpClient.Free;
  end;
end;
function TRpDatabaseHttp.InternalGetRequest(const AAction: string; ResponseStream: TStream): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LUrl: string;
  LStartedAt: TDateTime;
begin
  Result := False;
  LHttpClient := TNetHTTPClient.Create(nil);
  try
    TRpAuthManager.Instance.ConfigureDebugHttpClient(LHttpClient);
    LHttpClient.ContentType := 'application/json';
    if FApiKey <> '' then
      LHttpClient.CustomHeaders['X-Reportman-ApiKey'] := FApiKey;
    if FToken <> '' then
      LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FToken;
    if FInstallId <> '' then
      LHttpClient.CustomHeaders['X-Reportman-WebInstallId'] := FInstallId;
    LUrl := HUB_API_URL;
    if not LUrl.EndsWith('/') then LUrl := LUrl + '/';
    LUrl := LUrl + AAction;
    TRpAuthManager.Instance.Log('HTTP Request: GET ' + LUrl);
    LStartedAt := Now;
    LResponse := LHttpClient.Get(LUrl, ResponseStream);
    TRpAuthManager.Instance.Log('HTTP Response Status: ' + IntToStr(LResponse.StatusCode) +
      ' (' + IntToStr(MilliSecondsBetween(Now, LStartedAt)) + ' ms)');
    Result := (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300);
  finally
    LHttpClient.Free;
  end;
end;
function TRpDatabaseHttp.GetUserSchemas(AList: TStrings): Boolean;
var
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
  LDatabases: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
  LDisplayName: string;
  LValue: TJSONValue;
begin
  Result := False;
  AList.Clear;
  LResponseStream := TStringStream.Create;
  try
    if InternalGetRequest('api/agent/databases', LResponseStream) then
    begin
      LResponseStream.Position := 0;
      LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
      if LResponseJson <> nil then
      try
        if LResponseJson.Values['databases'] is TJSONArray then
        begin
          LDatabases := LResponseJson.Values['databases'] as TJSONArray;
          for I := 0 to LDatabases.Count - 1 do
          begin
            LItem := LDatabases.Items[I] as TJSONObject;
            LValue := LItem.Values['displayName'];
            if (LValue <> nil) and (LValue.Value <> '') then
              LDisplayName := StringReplace(LValue.Value, ' - ', ' / ', [])
            else
              LDisplayName := LItem.Values['name'].Value;

            AList.Add(LDisplayName + '=' +
              LItem.Values['hubDatabaseId'].Value + '|' +
              LItem.Values['hubSchemaId'].Value);
          end;
          Result := True;
        end;
      finally
        LResponseJson.Free;
      end;
    end;
  finally
    LResponseStream.Free;
  end;
end;
function TRpDatabaseHttp.GetUserAgents(AList: TStrings): Boolean;
var
  LResponseStream: TStringStream;
  LResponseJson: TJSONObject;
  LAiEndpoints: TJSONArray;
  I: Integer;
  LItem: TJSONObject;
  LName: string;
  LAgentName: string;
  LIsOnline: string;
  LIsOnlineValue: TJSONValue;
begin
  Result := False;
  AList.Clear;
  LResponseStream := TStringStream.Create;
  try
    if InternalGetRequest('api/agent/databases', LResponseStream) then
    begin
      LResponseStream.Position := 0;
      LResponseJson := TJSONObject.ParseJSONValue(LResponseStream.DataString) as TJSONObject;
      if LResponseJson <> nil then
      try
        if LResponseJson.Values['aiEndpoints'] is TJSONArray then
        begin
          LAiEndpoints := LResponseJson.Values['aiEndpoints'] as TJSONArray;
          for I := 0 to LAiEndpoints.Count - 1 do
          begin
            LItem := LAiEndpoints.Items[I] as TJSONObject;
            if LItem.Values['name'] <> nil then
              LName := LItem.Values['name'].Value
            else
              LName := 'Agent';

            if LItem.Values['agentName'] <> nil then
              LAgentName := LItem.Values['agentName'].Value
            else
              LAgentName := 'Agent';

            LIsOnlineValue := LItem.Values['isOnline'];
            if (LIsOnlineValue is TJSONBool) and TJSONBool(LIsOnlineValue).AsBoolean then
              LIsOnline := '1'
            else if Assigned(LIsOnlineValue) and SameText(LIsOnlineValue.Value, 'true') then
              LIsOnline := '1'
            else
              LIsOnline := '0';

            AList.Add(Format('%s (%s)=%s|%s|%s', [
              LName,
              LAgentName,
              LItem.Values['id'].Value,
              LItem.Values['agentSecret'].Value,
              LIsOnline
            ]));
          end;
          Result := True;
        end;
      finally
        LResponseJson.Free;
      end;
    end;
  finally
    LResponseStream.Free;
  end;
end;
end.

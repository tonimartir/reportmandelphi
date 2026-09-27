{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmchatlcl                                    }
{       Common chat of the AI assistants                }
{       (LCL port of rpfrmchatvcl)                      }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmchatlcl;

{ TFRpChatFrame with the public API of the VCL one (rpfrmchatvcl): the same
  methods, events and payload types, so the SQL, expression and design
  assistants can mirror their VCL hosts. Differences:

  - A panel, not a TFrame (LCL frames need a form resource), laid out in
    code; the tabs are the native ones of the widgetset (the VCL draws them).
  - The chat, AI log and Net log views are TRpWebMarkdownView of
    rpwebmarkdownlcl: WebMarkdown in WebView2 on Windows, the native IPro
    renderer elsewhere.
  - Threads: the VCL anonymous threads are TRpAsyncWorker subclasses and the
    WM_USER payloads are delivered by a TRpAsyncMailbox (rpaithreadslcl).
    The rpdatahttp streaming callbacks of the design request run in the
    worker and post TRpQueuedDesignChatPayload messages; OnBuildDesignRequest,
    OnApplyPreprocessSqlContextResult and OnDesignInferenceBegin/End run in
    the main thread (TThread.Synchronize), as in the VCL. Stop and the
    destruction of the frame cancel the stream (IRpAsyncCancel) instead of
    the worker reading a field of the frame.
  - Auth and log events arrive through RpAuthEvents in the main thread. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Types, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ComCtrls, LCLType, rpjsonfpc, rpauthmanager, rpdatahttp,
  rpreportdesignercontracts, rpaithreadslcl, rpchatmodernstylelcl,
  rpfrmaiselectionlcl, rpfrmloginframelcl, rpwebmarkdownlcl;

const
  CRpStartupNetworkDelayMs = 0;
  CRpChatEnableLoginFrame = True;
  CRpChatEnableAISelection = True;
  CRpChatEnableSchemaSelector = True;
  CRpChatEnableOnlineInitialization = True;
  CRpChatEnableAuthListener = True;

type
  TSchemaComboItem = class(TObject)
  public
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64; const AApiKey: string);
  end;

  TChatSendEvent = procedure(Sender: TObject; const APrompt, AExpression: string) of object;
  TChatApplyEvent = procedure(Sender: TObject; const AExpression: string) of object;
  TChatStopEvent = procedure(Sender: TObject) of object;
  TChatRefreshEvent = procedure(Sender: TObject) of object;
  TChatSchemaChangedEvent = procedure(Sender: TObject) of object;
  TDesignInferenceEvent = procedure(Sender: TObject) of object;
  TBuildDesignRequestEvent = function(Sender: TObject;
    const APrompt: string): TRpApiModifyReportRequest of object;
  TBuildPreprocessSqlContextRequestEvent = function(Sender: TObject):
    TRpApiPreprocessSqlContextRequest of object;
  TApplyDesignResultEvent = procedure(Sender: TObject;
    const AModifiedReportDocument: string) of object;
  TApplyPreprocessSqlContextResultEvent = procedure(Sender: TObject;
    AResult: TRpApiPreprocessSqlContextResult) of object;

  TExpressionChatSendEvent = TChatSendEvent;
  TExpressionChatApplyEvent = TChatApplyEvent;
  TExpressionChatStopEvent = TChatStopEvent;

  TRpQueuedAgentsPayload = class(TRpAsyncMessage)
  public
    Agents: TStringList;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    ReloadVersion: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TRpQueuedLogPayload = class(TRpAsyncMessage)
  public
    Text: string;
  end;

  { TFRpChatFrame }

  TFRpChatFrame = class(TCustomPanel)
  private
    FAISelection: TFRpAISelectionLCL;
    FBusy: Boolean;
    FConversationBlocks: TStringList;
    FCurrentExpression: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FLoginFrame: TFRpLoginFrameLCL;
    FLoadingSchemas: Boolean;
    FOnApplyDesignResult: TApplyDesignResultEvent;
    FOnApplyPreprocessSqlContextResult: TApplyPreprocessSqlContextResultEvent;
    FOnApplySuggestion: TChatApplyEvent;
    FOnBuildDesignRequest: TBuildDesignRequestEvent;
    FOnBuildPreprocessSqlContextRequest: TBuildPreprocessSqlContextRequestEvent;
    FOnDesignInferenceBegin: TDesignInferenceEvent;
    FOnDesignInferenceEnd: TDesignInferenceEvent;
    FOnRefreshContext: TChatRefreshEvent;
    FOnSchemaChanged: TChatSchemaChangedEvent;
    FOnSendPrompt: TChatSendEvent;
    FOnStopRequest: TChatStopEvent;
    FSchemaApiKey: string;
    FSuggestedExpression: string;
    FStreamingActive: Boolean;
    FStreamingPrefillPercent: Integer;
    FStreamingText: string;
    FProgressActive: Boolean;
    FProgressTitle: string;
    FProgressText: string;
    FOnlineInitializationQueued: Boolean;
    FLastAssistantMessage: string;
    FShowSchemaSelector: Boolean;
    FSchemaConfigButton: TRpChatIconButton;
    FUserAgentsReloadVersion: Integer;
    FUserSchemasReloadVersion: Integer;
    FUseRefreshAction: Boolean;
    FDesignRequestVersion: Integer;
    FDesignCancel: IRpAsyncCancel;
    FAuthListenerRegistered: Boolean;
    FLogListenerRegistered: Boolean;
    FWebChat: TRpWebMarkdownView;
    FWebLog: TRpWebMarkdownView;
    FWebNetLog: TRpWebMarkdownView;
    FLastLogActor: string;
    FLastProgressId: string;
    FLoginPreferredHeight: Integer;
    FInitialLayoutDone: Boolean;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    procedure BuildControls;
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
    procedure DeferredLayout(Data: PtrInt);
    procedure ApplyLoadedUserAgents(ALoadedAgents: TStringList;
      const ASelectedTier: string; ASelectedAgentAiId: Int64;
      AReloadVersion: Integer);
    procedure ApplyLoadedSchemas(ALoadedSchemas: TStringList;
      AReloadVersion: Integer);
    procedure HandleDesignChatPayload(APayload: TObject);
    procedure AuthLog(const AMsg: string);
    procedure AuthChanged(ASuccess: Boolean);
    procedure AppendMessage(const ATitle, AText: string);
    procedure ClearSchemaItems;
    procedure ComboSchemaChange(Sender: TObject);
    procedure LoadSchemas(ADelayBeforeRequestMs: Cardinal = 0);
    procedure LoadUserAgents(ADelayBeforeRequestMs: Cardinal = 0);
    procedure SchemaConfigClick(Sender: TObject);
    procedure EnsureTopStackLayout;
    function GetLoginHostPreferredHeight: Integer;
    procedure EnsureAISelectionAutoHeight;
    function GetSchemaHostPreferredHeight: Integer;
    procedure LayoutSchemaControls;
    procedure RefreshTopLayout;
    procedure RebuildConversation;
    procedure SelectCurrentSchema;
    procedure StopDesignPrompt;
    procedure UpdateButtons;
    procedure AppendNetLogLine(const AText: string);
    procedure ApplyModernStyling;
  protected
    procedure Resize; override;
    procedure CreateWnd; override;
  public
    PRoot: TPanel;
    PTop: TPanel;
    PLoginHost: TPanel;
    PAISelectionHost: TPanel;
    PSchemaHost: TPanel;
    LSchema: TLabel;
    PSchemaConfigHost: TPanel;
    BRefreshSchemas: TButton;
    ComboSchema: TComboBox;
    PControl: TPageControl;
    TabChat: TTabSheet;
    TabLog: TTabSheet;
    PLogTop: TPanel;
    BClearLog: TButton;
    BReportAI: TButton;
    TabNetLog: TTabSheet;
    PNetLogTop: TPanel;
    BClearNetLog: TButton;
    PBottom: TPanel;
    MemoPrompt: TMemo;
    PButtons: TPanel;
    BSend: TButton;
    BApply: TButton;
    BClear: TButton;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BApplyClick(Sender: TObject);
    procedure BClearClick(Sender: TObject);
    procedure BClearLogClick(Sender: TObject);
    procedure BClearNetLogClick(Sender: TObject);
    procedure BReportAIClick(Sender: TObject);
    procedure BRefreshSchemasClick(Sender: TObject);
    procedure BSendClick(Sender: TObject);
    procedure MemoPromptChange(Sender: TObject);
    procedure MemoPromptKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    // Public API of the VCL TFRpChatFrame
    procedure AISelectionStopRequest(Sender: TObject);
    procedure AddAssistantMessage(const AText: string);
    procedure AddUserMessage(const AText: string);
    procedure BeginStreamingResponse;
    procedure ClearConversation;
    procedure FinishStreamingResponse;
    procedure Initialize(const ACurrentExpression, AInitialAssistantMessage: string);
    procedure StartOnlineInitialization;
    procedure StartDesignPrompt(const APrompt: string);
    procedure RefreshLayout;
    procedure SetCurrentExpression(const AExpression: string);
    procedure SetBusy(AValue: Boolean);
    procedure SetInferenceProgress(AValue: Boolean);
    procedure SetShowSchemaSelector(AValue: Boolean);
    procedure SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    procedure SetSuggestedContent(const AContent, AMessage,
      ACaptionLabel: string);
    procedure AppendLogLine(const AText: string);
    procedure AppendLogChunk(const AChunk: string;
      AAppendLineBreak: Boolean = False);
    procedure UpdateStreamingTokens(AInTokens, AOutTokens: Integer;
      const AProgressId: string = ''; APrefillPercent: Integer = 0);
    procedure CompleteStreamingProgress(const AActor, AChunkType,
      AProgressId: string);
    procedure BeginProgress(const ATitle, AText: string);
    procedure UpdateProgress(const AText: string);
    procedure FinishProgress;
    procedure SetRefreshAction(AValue: Boolean);
    procedure SetSuggestedExpression(const AExpression, AMessage: string);
    procedure UpdateStreamingResponse(const AActor, AChunkType, AChunk: string;
      APrefillPercent: Integer; const ALogChunk: string = '';
      const AProgressId: string = '');
    procedure UpdateUserProfile(AProfile: TJSONObject);
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
    // LCL additions (state for hosts and tests)
    function ConversationText: string;
    property Busy: Boolean read FBusy;
    property StreamingActive: Boolean read FStreamingActive;
    property ProgressActive: Boolean read FProgressActive;
    property StreamingText: string read FStreamingText;
    property LoadingSchemas: Boolean read FLoadingSchemas;
    property ShowSchemaSelector: Boolean read FShowSchemaSelector;
    property SuggestedExpression: string read FSuggestedExpression;
    property LastAssistantMessage: string read FLastAssistantMessage;
    property AISelection: TFRpAISelectionLCL read FAISelection;
    property LoginFrame: TFRpLoginFrameLCL read FLoginFrame;
    property SchemaConfigButton: TRpChatIconButton read FSchemaConfigButton;
    property ChatView: TRpWebMarkdownView read FWebChat;
    property LogView: TRpWebMarkdownView read FWebLog;
    property NetLogView: TRpWebMarkdownView read FWebNetLog;
  published
    property OnApplyDesignResult: TApplyDesignResultEvent read FOnApplyDesignResult write FOnApplyDesignResult;
    property OnApplyPreprocessSqlContextResult: TApplyPreprocessSqlContextResultEvent read FOnApplyPreprocessSqlContextResult write FOnApplyPreprocessSqlContextResult;
    property OnApplySuggestion: TChatApplyEvent read FOnApplySuggestion write FOnApplySuggestion;
    property OnBuildDesignRequest: TBuildDesignRequestEvent read FOnBuildDesignRequest write FOnBuildDesignRequest;
    property OnBuildPreprocessSqlContextRequest: TBuildPreprocessSqlContextRequestEvent read FOnBuildPreprocessSqlContextRequest write FOnBuildPreprocessSqlContextRequest;
    property OnDesignInferenceBegin: TDesignInferenceEvent read FOnDesignInferenceBegin write FOnDesignInferenceBegin;
    property OnDesignInferenceEnd: TDesignInferenceEvent read FOnDesignInferenceEnd write FOnDesignInferenceEnd;
    property OnRefreshContext: TChatRefreshEvent read FOnRefreshContext write FOnRefreshContext;
    property OnSchemaChanged: TChatSchemaChangedEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnSendPrompt: TChatSendEvent read FOnSendPrompt write FOnSendPrompt;
    property OnStopRequest: TChatStopEvent read FOnStopRequest write FOnStopRequest;
  end;

  TFRpExpressionChatFrame = TFRpChatFrame;

implementation

uses
  rpdatainfo, rpmdconsts, LazUTF8, rpfrmaireportlcl;

type
  TRpQueuedSchemasPayload = class(TRpAsyncMessage)
  public
    ReloadVersion: Integer;
    Schemas: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TRpQueuedDesignChatPayloadKind = (
    rpqdcUpdateStreamingResponse,
    rpqdcAddAssistantMessage,
    rpqdcApplyDesignResult
  );

  TRpQueuedDesignChatPayload = class(TRpAsyncMessage)
  public
    Kind: TRpQueuedDesignChatPayloadKind;
    RequestVersion: Integer;
    Actor1: string;
    ProgressId1: string;
    ChunkType1: string;
    Text1: string;
    LogText1: string;
    Text2: string;
    PrefillPercent: Integer;
    InputTokens: Integer;
    OutputTokens: Integer;
    UserProfileJson: string;
  end;

  { Workers (the anonymous threads of the VCL frame) }

  TRpChatAgentsWorker = class(TRpAsyncWorker)
  public
    DelayMs: Cardinal;
    Token: string;
    InstallId: string;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    ReloadVersion: Integer;
  protected
    procedure Run; override;
  end;

  TRpChatSchemasWorker = class(TRpAsyncWorker)
  public
    DelayMs: Cardinal;
    Token: string;
    InstallId: string;
    ReloadVersion: Integer;
  protected
    procedure Run; override;
    function LoadUserSchemas(AList: TStrings): Boolean;
    function LoadConfiguredApiKeySchemas(AList: TStrings): Boolean;
  end;

  TRpChatDesignWorker = class(TRpAsyncWorker)
  private
    FSyncPreprocessResponse: TRpApiPreprocessSqlContextResult;
  public
    Frame: TFRpChatFrame;
    Cancel: IRpAsyncCancel;
    Prompt: string;
    Request: TRpApiModifyReportRequest;
    PreprocessRequest: TRpApiPreprocessSqlContextRequest;
    RequestVersion: Integer;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    Token: string;
    InstallId: string;
    NotifyInference: Boolean;
    destructor Destroy; override;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
    function Cancelled: Boolean;
    procedure PostAssistantMessage(const AText: string);
    // Main thread (Synchronize); they check OwnerGone first
    procedure SyncApplyPreprocess;
    procedure SyncInferenceBegin;
    procedure SyncInferenceEnd;
    // rpdatahttp streaming callbacks (worker thread)
    procedure StreamProgress(Sender: TObject; const AActor, AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    function StreamCancelRequested(Sender: TObject): Boolean;
  end;

function GetDesignPrefillPercent(const AStage, AChunkType: string): Integer;
begin
  if SameText(AStage, 'PreparingContext') then
    Result := 15
  else if SameText(AStage, 'SendingRequest') then
    Result := 45
  else if SameText(AStage, 'ReceivingResponse') then
  begin
    if SameText(AChunkType, 'Start') then
      Result := 70
    else
      Result := 100;
  end
  else if SameText(AStage, 'ApplyingOperations') then
    Result := 95
  else
    Result := 100;
end;

{ TSchemaComboItem }

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
  ApiKey := AApiKey;
end;

{ Payloads }

constructor TRpQueuedAgentsPayload.Create;
begin
  inherited Create;
  Agents := TStringList.Create;
end;

destructor TRpQueuedAgentsPayload.Destroy;
begin
  Agents.Free;
  inherited Destroy;
end;

constructor TRpQueuedSchemasPayload.Create;
begin
  inherited Create;
  Schemas := TStringList.Create;
end;

destructor TRpQueuedSchemasPayload.Destroy;
begin
  Schemas.Free;
  inherited Destroy;
end;

{ TRpChatAgentsWorker }

procedure TRpChatAgentsWorker.Run;
var
  LPayload: TRpQueuedAgentsPayload;
  LHttp: TRpDatabaseHttp;
begin
  LPayload := TRpQueuedAgentsPayload.Create;
  try
    try
      LHttp := TRpDatabaseHttp.Create;
      try
        if DelayMs > 0 then
        begin
          TRpAuthManager.Instance.Log(
            'LoadUserAgents: delaying startup agent request by ' +
            IntToStr(DelayMs) + ' ms for testing.');
          Sleep(DelayMs);
        end;
        LHttp.Token := Token;
        LHttp.InstallId := InstallId;
        if not LHttp.GetUserAgents(LPayload.Agents) then
          LPayload.Agents.Clear;
      finally
        LHttp.Free;
      end;
    except
      LPayload.Agents.Clear;
    end;
    LPayload.SelectedTier := SelectedTier;
    LPayload.SelectedAgentAiId := SelectedAgentAiId;
    LPayload.ReloadVersion := ReloadVersion;
    Post(LPayload);
    LPayload := nil;
  finally
    LPayload.Free;
  end;
end;

{ TRpChatSchemasWorker }

function TRpChatSchemasWorker.LoadUserSchemas(AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  if Token = '' then
    Exit;
  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    Result := LHttp.GetUserSchemas(AList);
  finally
    LHttp.Free;
  end;
end;

function TRpChatSchemasWorker.LoadConfiguredApiKeySchemas(AList: TStrings): Boolean;
var
  I, J: Integer;
  LApiKey, LSchemaValue, LSchemaKey: string;
  LConAdmin: TRpConnAdmin;
  LConnectionNames, LParams, LRawSchemas, LSeenApiKeys: TStringList;
  LHttp: TRpDatabaseHttp;
begin
  // The schemas visible with the API key of every configured connection
  Result := False;
  AList.Clear;
  LConAdmin := TRpConnAdmin.Create;
  LConnectionNames := TStringList.Create;
  LParams := TStringList.Create;
  LRawSchemas := TStringList.Create;
  LSeenApiKeys := TStringList.Create;
  try
    LSeenApiKeys.Sorted := True;
    LSeenApiKeys.Duplicates := dupIgnore;
    LConAdmin.GetConnectionNames(LConnectionNames, '');
    for I := 0 to LConnectionNames.Count - 1 do
    begin
      LParams.Clear;
      LConAdmin.GetConnectionParams(LConnectionNames[I], LParams);
      LApiKey := Trim(LParams.Values['ApiKey']);
      if (LApiKey = '') or (LSeenApiKeys.IndexOf(LApiKey) >= 0) then
        Continue;
      LSeenApiKeys.Add(LApiKey);
      LHttp := TRpDatabaseHttp.Create;
      try
        LHttp.ApiKey := LApiKey;
        LHttp.Token := Token;
        LHttp.InstallId := InstallId;
        LRawSchemas.Clear;
        if LHttp.GetUserSchemas(LRawSchemas) then
        begin
          Result := True;
          for J := 0 to LRawSchemas.Count - 1 do
          begin
            LSchemaValue := LRawSchemas.ValueFromIndex[J];
            if Pos('|', LSchemaValue) > 0 then
              LSchemaKey := LSchemaValue
            else
              LSchemaKey := '0|' + LSchemaValue;
            AList.Add(LRawSchemas.Names[J] + '=' + LSchemaKey + '|' + LApiKey);
          end;
        end;
      finally
        LHttp.Free;
      end;
    end;
  finally
    LSeenApiKeys.Free;
    LRawSchemas.Free;
    LParams.Free;
    LConnectionNames.Free;
    LConAdmin.Free;
  end;
end;

procedure TRpChatSchemasWorker.Run;
var
  I, LPosSep: Integer;
  LPayload: TRpQueuedSchemasPayload;
  LUserSchemas, LApiKeySchemas, LSeenSchemaKeys: TStringList;
  LValue, LSchemaKey: string;
begin
  LPayload := TRpQueuedSchemasPayload.Create;
  LUserSchemas := TStringList.Create;
  LApiKeySchemas := TStringList.Create;
  LSeenSchemaKeys := TStringList.Create;
  try
    LSeenSchemaKeys.Sorted := True;
    LSeenSchemaKeys.Duplicates := dupIgnore;
    if DelayMs > 0 then
    begin
      TRpAuthManager.Instance.Log('LoadSchemas: delaying startup schema request by ' +
        IntToStr(DelayMs) + ' ms for testing.');
      Sleep(DelayMs);
    end;
    try
      LoadUserSchemas(LUserSchemas);
    except
      LUserSchemas.Clear;
    end;
    try
      LoadConfiguredApiKeySchemas(LApiKeySchemas);
    except
      LApiKeySchemas.Clear;
    end;
    for I := 0 to LUserSchemas.Count - 1 do
    begin
      LValue := LUserSchemas.ValueFromIndex[I];
      if LSeenSchemaKeys.IndexOf(LValue) >= 0 then
        Continue;
      LSeenSchemaKeys.Add(LValue);
      LPayload.Schemas.Add(LUserSchemas.Names[I] + '=' + LValue + '|');
    end;
    for I := 0 to LApiKeySchemas.Count - 1 do
    begin
      LValue := LApiKeySchemas.ValueFromIndex[I];
      LPosSep := LastDelimiter('|', LValue);
      if LPosSep > 0 then
        LSchemaKey := Copy(LValue, 1, LPosSep - 1)
      else
        LSchemaKey := LValue;
      if LSeenSchemaKeys.IndexOf(LSchemaKey) >= 0 then
        Continue;
      LSeenSchemaKeys.Add(LSchemaKey);
      LPayload.Schemas.Add(LApiKeySchemas.Names[I] + '=' + LValue);
    end;
    LPayload.ReloadVersion := ReloadVersion;
    Post(LPayload);
    LPayload := nil;
  finally
    LPayload.Free;
    LSeenSchemaKeys.Free;
    LApiKeySchemas.Free;
    LUserSchemas.Free;
  end;
end;

{ TRpChatDesignWorker }

destructor TRpChatDesignWorker.Destroy;
begin
  PreprocessRequest.Free;
  Request.Free;
  inherited Destroy;
end;

function TRpChatDesignWorker.Cancelled: Boolean;
begin
  Result := OwnerGone or ((Cancel <> nil) and Cancel.Cancelled);
end;

procedure TRpChatDesignWorker.PostAssistantMessage(const AText: string);
var
  LPayload: TRpQueuedDesignChatPayload;
begin
  LPayload := TRpQueuedDesignChatPayload.Create;
  LPayload.Kind := rpqdcAddAssistantMessage;
  LPayload.RequestVersion := RequestVersion;
  LPayload.Text1 := AText;
  Post(LPayload);
end;

procedure TRpChatDesignWorker.StreamProgress(Sender: TObject; const AActor, AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LPayload: TRpQueuedDesignChatPayload;
begin
  if Cancelled then
    Exit;
  LPayload := TRpQueuedDesignChatPayload.Create;
  LPayload.Kind := rpqdcUpdateStreamingResponse;
  LPayload.RequestVersion := RequestVersion;
  LPayload.Actor1 := AActor;
  LPayload.ProgressId1 := AProgressId;
  LPayload.ChunkType1 := AChunkType;
  if SameText(AStage, 'ReceivingResponse') and SameText(AChunkType, 'Partial') then
    LPayload.Text1 := AChunk;
  LPayload.LogText1 := AChunk;
  if APrefillPercent > 0 then
    LPayload.PrefillPercent := APrefillPercent
  else if SameText(AActor, 'AI') and (Trim(AProgressId) <> '') then
    LPayload.PrefillPercent := 0
  else
    LPayload.PrefillPercent := GetDesignPrefillPercent(AStage, AChunkType);
  LPayload.InputTokens := AInputTokens;
  LPayload.OutputTokens := AOutputTokens;
  Post(LPayload);
end;

function TRpChatDesignWorker.StreamCancelRequested(Sender: TObject): Boolean;
begin
  Result := Cancelled;
end;

procedure TRpChatDesignWorker.SyncApplyPreprocess;
var
  LUpdatedRequest: TRpApiModifyReportRequest;
begin
  if OwnerGone then
  begin
    Request.ReportDocument := '';
    Exit;
  end;
  if Assigned(Frame.FOnApplyPreprocessSqlContextResult) then
    Frame.FOnApplyPreprocessSqlContextResult(Frame, FSyncPreprocessResponse);
  LUpdatedRequest := nil;
  try
    if Assigned(Frame.FOnBuildDesignRequest) then
      LUpdatedRequest := Frame.FOnBuildDesignRequest(Frame, Prompt);
    if LUpdatedRequest <> nil then
      Request.Assign(LUpdatedRequest)
    else
      Request.ReportDocument := '';
  finally
    LUpdatedRequest.Free;
  end;
end;

procedure TRpChatDesignWorker.SyncInferenceBegin;
begin
  if OwnerGone then
    Exit;
  if Assigned(Frame.FOnDesignInferenceBegin) then
    Frame.FOnDesignInferenceBegin(Frame);
end;

procedure TRpChatDesignWorker.SyncInferenceEnd;
begin
  if OwnerGone then
    Exit;
  if Assigned(Frame.FOnDesignInferenceEnd) then
    Frame.FOnDesignInferenceEnd(Frame);
end;

procedure TRpChatDesignWorker.HandleError(E: Exception);
begin
  if not Cancelled then
    PostAssistantMessage(E.Message);
end;

procedure TRpChatDesignWorker.Run;
var
  I: Integer;
  LHttp: TRpDatabaseHttp;
  LPayload: TRpQueuedDesignChatPayload;
  LPreprocessResponse: TRpApiPreprocessSqlContextResult;
  LPreprocessUserProfileJson: string;
  LResponse: TRpApiModifyReportResult;
  LInferenceActive: Boolean;
begin
  LHttp := TRpDatabaseHttp.Create;
  LPreprocessResponse := nil;
  LPreprocessUserProfileJson := '';
  LResponse := nil;
  LInferenceActive := False;
  try
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    LHttp.AITier := RpAITierTypeToString(Request.AITier);
    LHttp.HubDatabaseId := HubDatabaseId;
    LHttp.HubSchemaId := HubSchemaId;
    LHttp.AgentSecret := Request.AgentSecret;
    if Request.HasAgentAiId then
      LHttp.AgentAiId := Request.AgentAiId;

    if PreprocessRequest <> nil then
    begin
      LPreprocessResponse := LHttp.PreprocessSqlContext(PreprocessRequest, Self,
        StreamProgress, StreamCancelRequested);
      if Cancelled then
        Exit;
      if (LPreprocessResponse <> nil) and (Trim(LPreprocessResponse.ErrorMessage) <> '') then
        raise Exception.Create(RpComposeApiErrorMessage(LPreprocessResponse.ErrorMessage,
          LPreprocessResponse.DebugDetails));
      FSyncPreprocessResponse := LPreprocessResponse;
      SyncCall(SyncApplyPreprocess);
      if Cancelled then
        Exit;
      if Trim(Request.ReportDocument) = '' then
        raise Exception.Create('Unable to serialize the current report to XML after preprocessing SQL context.');
      if LPreprocessResponse <> nil then
        LPreprocessUserProfileJson := LPreprocessResponse.UserProfileJson;
    end;

    if NotifyInference then
    begin
      SyncCall(SyncInferenceBegin);
      LInferenceActive := True;
    end;
    try
      LResponse := LHttp.ModifyReport(Request, Self, StreamProgress, StreamCancelRequested);
    finally
      if LInferenceActive then
        SyncCall(SyncInferenceEnd);
    end;

    if Cancelled then
      Exit;
    if LResponse = nil then
    begin
      PostAssistantMessage('No response received from the server.');
      Exit;
    end;
    if Trim(LResponse.ErrorMessage) <> '' then
    begin
      PostAssistantMessage(RpComposeApiErrorMessage(LResponse.ErrorMessage,
        LResponse.DebugDetails));
      Exit;
    end;
    if Assigned(LResponse.ResultData) and (Trim(LResponse.ResultData.ErrorMessage) <> '') then
    begin
      PostAssistantMessage(LResponse.ResultData.ErrorMessage);
      Exit;
    end;

    LPayload := TRpQueuedDesignChatPayload.Create;
    LPayload.Kind := rpqdcApplyDesignResult;
    LPayload.RequestVersion := RequestVersion;
    if LPreprocessResponse <> nil then
      for I := 0 to LPreprocessResponse.Steps.Count - 1 do
        if LPreprocessResponse.Steps[I] is TRpTokenUsage then
        begin
          Inc(LPayload.InputTokens, TRpTokenUsage(LPreprocessResponse.Steps[I]).InputTokens);
          Inc(LPayload.OutputTokens, TRpTokenUsage(LPreprocessResponse.Steps[I]).OutputTokens);
        end;
    if Assigned(LResponse.ResultData) then
    begin
      LPayload.Text1 := LResponse.ResultData.ModifiedReportDocument;
      LPayload.Text2 := LResponse.ResultData.Explanation;
    end;
    LPayload.UserProfileJson := LResponse.UserProfileJson;
    for I := 0 to LResponse.Steps.Count - 1 do
      if LResponse.Steps[I] is TRpTokenUsage then
      begin
        Inc(LPayload.InputTokens, TRpTokenUsage(LResponse.Steps[I]).InputTokens);
        Inc(LPayload.OutputTokens, TRpTokenUsage(LResponse.Steps[I]).OutputTokens);
      end;
    if Trim(LPayload.UserProfileJson) = '' then
      LPayload.UserProfileJson := LPreprocessUserProfileJson;
    Post(LPayload);
  finally
    LPreprocessResponse.Free;
    LResponse.Free;
    LHttp.Free;
  end;
end;

{ TFRpChatFrame }

constructor TFRpChatFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Width := Scale(400);
  Height := Scale(560);
  FMailbox := TRpAsyncMailbox.Create(HandleAsyncMessage);
  FMailboxRef := FMailbox;
  FConversationBlocks := TStringList.Create;
  FLogListenerRegistered := False;
  FLoginPreferredHeight := Scale(40);
  BuildControls;

  if CRpChatEnableLoginFrame then
  begin
    FLoginFrame := TFRpLoginFrameLCL.Create(Self);
    FLoginPreferredHeight := FLoginFrame.Height;
    FLoginFrame.Parent := PLoginHost;
    FLoginFrame.Align := alClient;
  end
  else
  begin
    PLoginHost.Visible := False;
    PLoginHost.Height := 0;
  end;

  if CRpChatEnableAISelection then
  begin
    FAISelection := TFRpAISelectionLCL.Create(Self);
    PAISelectionHost.Height := FAISelection.PreferredHeight;
    FAISelection.Parent := PAISelectionHost;
    FAISelection.Align := alClient;
    FAISelection.OnStopRequest := AISelectionStopRequest;
  end
  else
  begin
    PAISelectionHost.Visible := False;
    PAISelectionHost.Height := 0;
  end;

  FHubDatabaseId := 0;
  FHubSchemaId := 0;
  FSchemaApiKey := '';
  FShowSchemaSelector := CRpChatEnableSchemaSelector;
  FLoadingSchemas := False;
  if not CRpChatEnableSchemaSelector then
  begin
    PSchemaHost.Visible := False;
    PSchemaHost.Height := 0;
  end;

  FAuthListenerRegistered := False;
  if CRpChatEnableAuthListener then
  begin
    RpAuthEvents.AddAuthListener(AuthChanged);
    FAuthListenerRegistered := True;
  end;

  // Markdown views of the three tabs
  FWebChat := TRpWebMarkdownView.Create(Self);
  FWebChat.Parent := TabChat;
  FWebChat.Align := alClient;

  FWebLog := TRpWebMarkdownView.Create(Self);
  FWebLog.Parent := TabLog;
  FWebLog.Align := alClient;

  FWebNetLog := TRpWebMarkdownView.Create(Self);
  FWebNetLog.Parent := TabNetLog;
  FWebNetLog.Align := alClient;

  MemoPrompt.Clear;
  RpAuthEvents.AddLogListener(AuthLog);
  FLogListenerRegistered := True;
  FBusy := False;
  FLastAssistantMessage := '';
  FSuggestedExpression := '';
  FStreamingActive := False;
  FStreamingPrefillPercent := 0;
  FStreamingText := '';
  FProgressActive := False;
  FProgressTitle := '';
  FProgressText := '';
  FOnlineInitializationQueued := False;
  FUserAgentsReloadVersion := 0;
  FUserSchemasReloadVersion := 0;
  FUseRefreshAction := False;
  FDesignRequestVersion := 0;
  ApplyModernStyling;
  Initialize('', '');
  RefreshTopLayout;
end;

destructor TFRpChatFrame.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  // Workers still running drop their results; the design stream stops
  FMailbox.Detach;
  if FDesignCancel <> nil then
    FDesignCancel.Cancel;
  FDesignCancel := nil;
  if FLogListenerRegistered then
    RpAuthEvents.RemoveLogListener(AuthLog);
  if FAuthListenerRegistered then
    RpAuthEvents.RemoveAuthListener(AuthChanged);
  FLogListenerRegistered := False;
  FAuthListenerRegistered := False;
  ClearSchemaItems;
  FConversationBlocks.Free;
  FMailboxRef := nil;
  inherited Destroy;
end;

procedure TFRpChatFrame.BuildControls;

  function NewPanel(AParent: TWinControl; AAlign: TAlign): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Parent := AParent;
    Result.BevelOuter := bvNone;
    Result.Caption := '';
    Result.Align := AAlign;
  end;

  function NewButton(AParent: TWinControl; const ACaption: string;
    AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.OnClick := AClick;
  end;

begin
  PRoot := NewPanel(Self, alClient);

  PTop := NewPanel(PRoot, alTop);
  PTop.Height := Scale(166);
  PLoginHost := NewPanel(PTop, alNone);
  PAISelectionHost := NewPanel(PTop, alNone);
  PSchemaHost := NewPanel(PTop, alNone);

  LSchema := TLabel.Create(Self);
  LSchema.Parent := PSchemaHost;
  LSchema.Caption := UTF8UpperCase(TranslateStr(1528, 'Schema'));
  LSchema.Layout := tlBottom;
  LSchema.AutoSize := False;

  ComboSchema := TComboBox.Create(Self);
  ComboSchema.Parent := PSchemaHost;
  ComboSchema.Style := csDropDownList;
  ComboSchema.OnChange := ComboSchemaChange;

  PSchemaConfigHost := NewPanel(PSchemaHost, alNone);
  FSchemaConfigButton := TRpChatIconButton.Create(Self);
  FSchemaConfigButton.Parent := PSchemaConfigHost;
  FSchemaConfigButton.Align := alClient;
  FSchemaConfigButton.Kind := rpikCog;
  FSchemaConfigButton.Hint := TranslateStr(1496, 'Configure DB Schemas');
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.OnClick := SchemaConfigClick;

  BRefreshSchemas := NewButton(PSchemaHost, TranslateStr(1149, 'Refresh'),
    BRefreshSchemasClick);
  BRefreshSchemas.Hint := TranslateStr(1149, 'Refresh');
  BRefreshSchemas.ShowHint := True;

  PBottom := NewPanel(PRoot, alBottom);
  PBottom.Height := Scale(110);
  PBottom.BorderSpacing.Around := Scale(8);

  PButtons := NewPanel(PBottom, alRight);
  PButtons.Width := Scale(103);
  PButtons.BorderSpacing.Left := Scale(8);
  BSend := NewButton(PButtons, TranslateStr(1534, 'Send'), BSendClick);
  BSend.Align := alTop;
  BSend.Height := Scale(30);
  BApply := NewButton(PButtons, TranslateStr(1535, 'Apply'), BApplyClick);
  BApply.Top := Scale(30);
  BApply.Align := alTop;
  BApply.Height := Scale(30);
  BApply.BorderSpacing.Top := Scale(2);
  BClear := NewButton(PButtons, TranslateStr(1532, 'Clear'), BClearClick);
  BClear.Top := Scale(62);
  BClear.Align := alTop;
  BClear.Height := Scale(30);
  BClear.BorderSpacing.Top := Scale(2);

  MemoPrompt := TMemo.Create(Self);
  MemoPrompt.Parent := PBottom;
  MemoPrompt.Align := alClient;
  MemoPrompt.ScrollBars := ssAutoVertical;
  MemoPrompt.WordWrap := True;
  MemoPrompt.WantReturns := True;
  MemoPrompt.OnChange := MemoPromptChange;
  MemoPrompt.OnKeyDown := MemoPromptKeyDown;

  PControl := TPageControl.Create(Self);
  PControl.Parent := PRoot;
  PControl.Align := alClient;

  TabChat := TTabSheet.Create(PControl);
  TabChat.PageControl := PControl;
  TabChat.Caption := TranslateStr(1529, 'Chat');

  TabLog := TTabSheet.Create(PControl);
  TabLog.PageControl := PControl;
  TabLog.Caption := TranslateStr(1530, 'AI Log');
  PLogTop := NewPanel(TabLog, alTop);
  PLogTop.Height := Scale(38);
  PLogTop.ChildSizing.LeftRightSpacing := Scale(8);
  PLogTop.ChildSizing.TopBottomSpacing := Scale(4);
  PLogTop.ChildSizing.HorizontalSpacing := Scale(8);
  PLogTop.ChildSizing.Layout := cclLeftToRightThenTopToBottom;
  BClearLog := NewButton(PLogTop, TranslateStr(1532, 'Clear'), BClearLogClick);
  BClearLog.AutoSize := True;
  BReportAI := NewButton(PLogTop, TranslateStr(1533, 'Report content'), BReportAIClick);
  BReportAI.AutoSize := True;

  TabNetLog := TTabSheet.Create(PControl);
  TabNetLog.PageControl := PControl;
  TabNetLog.Caption := TranslateStr(1531, 'Net Log');
  PNetLogTop := NewPanel(TabNetLog, alTop);
  PNetLogTop.Height := Scale(38);
  PNetLogTop.ChildSizing.LeftRightSpacing := Scale(8);
  PNetLogTop.ChildSizing.TopBottomSpacing := Scale(4);
  PNetLogTop.ChildSizing.Layout := cclLeftToRightThenTopToBottom;
  BClearNetLog := NewButton(PNetLogTop, TranslateStr(1532, 'Clear'), BClearNetLogClick);
  BClearNetLog.AutoSize := True;

  PControl.ActivePage := TabChat;
end;

procedure TFRpChatFrame.ApplyModernStyling;
begin
  // Fonts are inherited from the host form, as in the VCL
  TRpChatStyle.StylePanelBg(PRoot);
  TRpChatStyle.StylePanelBg(PTop);
  TRpChatStyle.StylePanelBg(PBottom);
  TRpChatStyle.StylePanelBg(PLoginHost);
  TRpChatStyle.StylePanelBg(PAISelectionHost);
  TRpChatStyle.StylePanelBg(PSchemaHost);
  TRpChatStyle.StylePanelBg(PSchemaConfigHost);
  TRpChatStyle.StylePanelBg(PLogTop);
  TRpChatStyle.StylePanelBg(PNetLogTop);
  TRpChatStyle.StylePanelBg(PButtons);
  TRpChatStyle.StyleInputControl(ComboSchema);
  TRpChatStyle.StyleInputControl(BRefreshSchemas);
  MemoPrompt.Color := ClrSurface;
  MemoPrompt.BorderStyle := bsSingle;
  TRpChatStyle.StyleInputControl(MemoPrompt);
  PSchemaHost.Height := GetSchemaHostPreferredHeight;
  PLoginHost.Height := GetLoginHostPreferredHeight;
  LayoutSchemaControls;
end;

procedure TFRpChatFrame.Resize;
begin
  inherited Resize;
  if PTop <> nil then
    RefreshTopLayout;
end;

procedure TFRpChatFrame.CreateWnd;
begin
  inherited CreateWnd;
  // The first layout again once the parent has aligned (the VCL posts
  // WM_USER+212 from CM_SHOWINGCHANGED for the same reason)
  if not FInitialLayoutDone then
    Application.QueueAsyncCall(DeferredLayout, 0);
end;

procedure TFRpChatFrame.DeferredLayout(Data: PtrInt);
begin
  if FInitialLayoutDone or (csDestroying in ComponentState) then
    Exit;
  FInitialLayoutDone := True;
  RefreshTopLayout;
  if FAISelection <> nil then
    FAISelection.RefreshLayout;
  if FLoginFrame <> nil then
    FLoginFrame.RefreshLayout;
end;

procedure TFRpChatFrame.EnsureAISelectionAutoHeight;
begin
  if (FAISelection = nil) or (PAISelectionHost = nil) then
    Exit;
  if PAISelectionHost.Height <> FAISelection.PreferredHeight then
    RefreshTopLayout;
end;

procedure TFRpChatFrame.EnsureTopStackLayout;
begin
  // The VCL removes a TGridPanel here; the LCL hosts are stacked in code
  PLoginHost.Align := alNone;
  PAISelectionHost.Align := alNone;
  PSchemaHost.Align := alNone;
end;

function TFRpChatFrame.GetSchemaHostPreferredHeight: Integer;
var
  LLabelHeight, LControlsHeight, LConfigButtonSize: Integer;
begin
  LLabelHeight := 0;
  if LSchema.Visible then
    LLabelHeight := TRpChatStyle.TextHeightOf(LSchema.Font) + Scale(2);
  LControlsHeight := ComboSchema.Height + Scale(8);
  LConfigButtonSize := MulDiv(ComboSchema.Height, 110, 100);
  if LConfigButtonSize + Scale(8) > LControlsHeight then
    LControlsHeight := LConfigButtonSize + Scale(8);
  if LControlsHeight <= 0 then
    LControlsHeight := Scale(32);
  Result := LLabelHeight + LControlsHeight;
end;

function TFRpChatFrame.GetLoginHostPreferredHeight: Integer;
begin
  Result := FLoginPreferredHeight;
  if Result <= 0 then
    Result := Scale(40);
end;

procedure TFRpChatFrame.LayoutSchemaControls;
const
  RowGap = 4;
var
  LClientWidth, LConfigButtonSize, LConfigLeft, LConfigTop, LControlsHeight,
    LRefreshTop, LLabelHeight, LRefreshLeft, LRefreshWidth, LRowHeight,
    LSchemaWidth: Integer;
begin
  LClientWidth := PSchemaHost.ClientWidth;
  if LClientWidth <= 0 then
    Exit;
  LLabelHeight := 0;
  if LSchema.Visible then
  begin
    LLabelHeight := TRpChatStyle.TextHeightOf(LSchema.Font) + Scale(2);
    LSchema.SetBounds(0, 0, LClientWidth, LLabelHeight);
  end;
  // The combo height of the widgetset sets the row height
  LRowHeight := ComboSchema.Height;
  if LRowHeight <= 0 then
    LRowHeight := Scale(24);
  LConfigButtonSize := MulDiv(LRowHeight, 110, 100);
  if LConfigButtonSize <= 0 then
    LConfigButtonSize := LRowHeight;
  LControlsHeight := LRowHeight;
  if LConfigButtonSize > LControlsHeight then
    LControlsHeight := LConfigButtonSize;

  LRefreshTop := LLabelHeight + Scale(4) + ((LControlsHeight - LRowHeight) div 2);
  LConfigTop := LLabelHeight + Scale(4) + ((LControlsHeight - LConfigButtonSize) div 2);

  if BRefreshSchemas.Visible then
  begin
    LRefreshWidth := TRpChatStyle.TextWidthOf(BRefreshSchemas.Font,
      TranslateStr(1149, 'Refresh')) + Scale(24);
    if LRefreshWidth < Scale(64) then
      LRefreshWidth := Scale(64);
    LRefreshLeft := LClientWidth - LRefreshWidth;
    if LRefreshLeft < 0 then
      LRefreshLeft := 0;
    BRefreshSchemas.SetBounds(LRefreshLeft, LRefreshTop, LRefreshWidth, LRowHeight);
  end
  else
    LRefreshLeft := LClientWidth;

  LConfigLeft := LRefreshLeft;
  if PSchemaConfigHost.Visible then
  begin
    LConfigLeft := LRefreshLeft - Scale(RowGap) - LConfigButtonSize;
    if LConfigLeft < 0 then
      LConfigLeft := 0;
    PSchemaConfigHost.SetBounds(LConfigLeft, LConfigTop, LConfigButtonSize, LConfigButtonSize);
  end;

  LSchemaWidth := LConfigLeft - Scale(RowGap);
  if LSchemaWidth < 0 then
    LSchemaWidth := 0;
  ComboSchema.SetBounds(0, LRefreshTop, LSchemaWidth, ComboSchema.Height);
end;

procedure TFRpChatFrame.RefreshTopLayout;
var
  LLoginHeight, LAISelectionHeight, LSchemaHeight, LTop: Integer;
begin
  if PTop = nil then
    Exit;
  DisableAlign;
  try
    EnsureTopStackLayout;
    LLoginHeight := 0;
    if PLoginHost.Visible or (FLoginFrame <> nil) then
      if FLoginFrame <> nil then
        LLoginHeight := GetLoginHostPreferredHeight;

    LAISelectionHeight := 0;
    if FAISelection <> nil then
      LAISelectionHeight := FAISelection.PreferredHeight;

    if FShowSchemaSelector then
      LSchemaHeight := GetSchemaHostPreferredHeight
    else
      LSchemaHeight := 0;
    PSchemaHost.Visible := FShowSchemaSelector;

    LTop := 0;
    PLoginHost.Visible := LLoginHeight > 0;
    PLoginHost.SetBounds(0, LTop, PTop.ClientWidth, LLoginHeight);
    if PLoginHost.Visible then
      Inc(LTop, LLoginHeight);

    PAISelectionHost.Visible := LAISelectionHeight > 0;
    PAISelectionHost.SetBounds(0, LTop, PTop.ClientWidth, LAISelectionHeight);
    if PAISelectionHost.Visible then
      Inc(LTop, LAISelectionHeight);

    PSchemaHost.SetBounds(0, LTop, PTop.ClientWidth, LSchemaHeight);
    LayoutSchemaControls;
    if PSchemaHost.Visible then
      Inc(LTop, LSchemaHeight);

    PTop.Height := LTop + Scale(4);
  finally
    EnableAlign;
  end;
  if FLoginFrame <> nil then
    FLoginFrame.RefreshLayout;
  if FAISelection <> nil then
    FAISelection.RefreshLayout;
end;

procedure TFRpChatFrame.RefreshLayout;
begin
  RefreshTopLayout;
  UpdateButtons;
end;

procedure TFRpChatFrame.AuthChanged(ASuccess: Boolean);
begin
  if not FAuthListenerRegistered then
    Exit;
  if FAISelection <> nil then
  begin
    FAISelection.RefreshState;
    LoadUserAgents;
  end;
  if FShowSchemaSelector then
    LoadSchemas;
end;

procedure TFRpChatFrame.SchemaConfigClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl('https://app.reportman.es/database-config');
end;

procedure TFRpChatFrame.AppendMessage(const ATitle, AText: string);
begin
  FConversationBlocks.Add(ATitle + sLineBreak + AText);
  RebuildConversation;
end;

procedure TFRpChatFrame.RebuildConversation;
var
  I, LPos: Integer;
  LBlock, LTitle, LBody, LRole: string;
begin
  if FWebChat = nil then
    Exit;
  FWebChat.ClearAll;
  for I := 0 to FConversationBlocks.Count - 1 do
  begin
    LBlock := FConversationBlocks[I];
    LPos := Pos(sLineBreak, LBlock);
    if LPos > 0 then
    begin
      LTitle := Copy(LBlock, 1, LPos - 1);
      LBody := Copy(LBlock, LPos + Length(sLineBreak), MaxInt);
    end
    else
    begin
      LTitle := LBlock;
      LBody := '';
    end;
    if SameText(Trim(LTitle), 'You') then
      LRole := 'user'
    else if SameText(Trim(LTitle), 'Assistant') then
      LRole := 'assistant'
    else
      LRole := 'system';
    FWebChat.AppendMessage(LRole, LBody);
  end;
  if FProgressActive then
    FWebChat.AppendMessage('system', '**' + FProgressTitle + '**' + sLineBreak + FProgressText);
  FWebChat.ScrollToEnd;
end;

function TFRpChatFrame.ConversationText: string;
begin
  Result := FConversationBlocks.Text;
end;

procedure TFRpChatFrame.LoadUserAgents(ADelayBeforeRequestMs: Cardinal);
var
  LWorker: TRpChatAgentsWorker;
  LSelectedTier: string;
  LSelectedAgentAiId: Int64;
begin
  if FAISelection = nil then
    Exit;
  Inc(FUserAgentsReloadVersion);
  LSelectedTier := FAISelection.AITier;
  LSelectedAgentAiId := FAISelection.AgentAiId;
  FAISelection.ClearAgentEndpoints;
  if TRpAuthManager.Instance.Token = '' then
  begin
    FAISelection.RestoreProviderSelection(LSelectedTier, LSelectedAgentAiId);
    Exit;
  end;
  LWorker := TRpChatAgentsWorker.Create(FMailboxRef);
  LWorker.DelayMs := ADelayBeforeRequestMs;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.SelectedTier := LSelectedTier;
  LWorker.SelectedAgentAiId := LSelectedAgentAiId;
  LWorker.ReloadVersion := FUserAgentsReloadVersion;
  LWorker.Start;
end;

procedure TFRpChatFrame.ClearSchemaItems;
var
  I: Integer;
begin
  for I := 0 to ComboSchema.Items.Count - 1 do
    ComboSchema.Items.Objects[I].Free;
  ComboSchema.Clear;
end;

procedure TFRpChatFrame.LoadSchemas(ADelayBeforeRequestMs: Cardinal);
var
  LWorker: TRpChatSchemasWorker;
begin
  Inc(FUserSchemasReloadVersion);
  FLoadingSchemas := True;
  UpdateButtons;
  LWorker := TRpChatSchemasWorker.Create(FMailboxRef);
  LWorker.DelayMs := ADelayBeforeRequestMs;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.ReloadVersion := FUserSchemasReloadVersion;
  LWorker.Start;
end;

procedure TFRpChatFrame.HandleAsyncMessage(AMessage: TRpAsyncMessage);
var
  LAgents: TRpQueuedAgentsPayload;
  LSchemas: TRpQueuedSchemasPayload;
begin
  if AMessage is TRpQueuedAgentsPayload then
  begin
    LAgents := TRpQueuedAgentsPayload(AMessage);
    ApplyLoadedUserAgents(LAgents.Agents, LAgents.SelectedTier,
      LAgents.SelectedAgentAiId, LAgents.ReloadVersion);
  end
  else if AMessage is TRpQueuedSchemasPayload then
  begin
    LSchemas := TRpQueuedSchemasPayload(AMessage);
    ApplyLoadedSchemas(LSchemas.Schemas, LSchemas.ReloadVersion);
  end
  else if AMessage is TRpQueuedDesignChatPayload then
    HandleDesignChatPayload(AMessage)
  else if AMessage is TRpQueuedLogPayload then
    AppendNetLogLine(FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' +
      TRpQueuedLogPayload(AMessage).Text);
end;

procedure TFRpChatFrame.ApplyLoadedUserAgents(ALoadedAgents: TStringList;
  const ASelectedTier: string; ASelectedAgentAiId: Int64; AReloadVersion: Integer);
var
  I: Integer;
  LParts: TStringList;
begin
  // The payload owns the list (the VCL handler frees it here)
  if FAISelection = nil then
    Exit;
  if AReloadVersion <> FUserAgentsReloadVersion then
    Exit;
  FAISelection.ClearAgentEndpoints;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    for I := 0 to ALoadedAgents.Count - 1 do
    begin
      LParts.DelimitedText := ALoadedAgents.ValueFromIndex[I];
      // Only the online agents can answer
      if (LParts.Count >= 3) and (LParts[2] = '1') then
        FAISelection.AddAgentEndpoint(StrToInt64Def(LParts[0], 0), LParts[1],
          ALoadedAgents.Names[I], True);
    end;
  finally
    LParts.Free;
  end;
  FAISelection.RestoreProviderSelection(ASelectedTier, ASelectedAgentAiId);
end;

procedure TFRpChatFrame.SelectCurrentSchema;
var
  I: Integer;
  LItem: TSchemaComboItem;
  LFound: Boolean;
begin
  if ComboSchema.Items.Count = 0 then
    Exit;
  LFound := False;
  // A specific HubSchemaId first
  if FHubSchemaId <> 0 then
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubSchemaId = FHubSchemaId) then
      begin
        ComboSchema.ItemIndex := I;
        FHubDatabaseId := LItem.HubDatabaseId;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  // Then the first schema of the connection
  if (not LFound) and (FHubDatabaseId <> 0) then
    for I := 1 to ComboSchema.Items.Count - 1 do
    begin
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[I]);
      if (LItem <> nil) and (LItem.HubDatabaseId = FHubDatabaseId) then
      begin
        ComboSchema.ItemIndex := I;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
        LFound := True;
        Break;
      end;
    end;
  // Else the very first schema
  if not LFound then
  begin
    if ComboSchema.Items.Count > 1 then
    begin
      ComboSchema.ItemIndex := 1;
      LItem := TSchemaComboItem(ComboSchema.Items.Objects[1]);
      if LItem <> nil then
      begin
        FHubDatabaseId := LItem.HubDatabaseId;
        FHubSchemaId := LItem.HubSchemaId;
        FSchemaApiKey := LItem.ApiKey;
      end;
    end
    else
    begin
      ComboSchema.ItemIndex := 0;
      FHubDatabaseId := 0;
      FHubSchemaId := 0;
      FSchemaApiKey := '';
    end;
  end;
end;

procedure TFRpChatFrame.ApplyLoadedSchemas(ALoadedSchemas: TStringList;
  AReloadVersion: Integer);
var
  I: Integer;
  LDisplayName, LValue, LApiKey: string;
  LParts: TStringList;
  LHubDatabaseId, LHubSchemaId: Int64;
begin
  if AReloadVersion <> FUserSchemasReloadVersion then
    Exit;
  ComboSchema.Items.BeginUpdate;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '|';
    LParts.StrictDelimiter := True;
    ClearSchemaItems;
    ComboSchema.Items.Add('');
    for I := 0 to ALoadedSchemas.Count - 1 do
    begin
      LDisplayName := ALoadedSchemas.Names[I];
      LValue := ALoadedSchemas.ValueFromIndex[I];
      LParts.DelimitedText := LValue;
      if LParts.Count >= 2 then
      begin
        LHubDatabaseId := StrToInt64Def(LParts[0], 0);
        LHubSchemaId := StrToInt64Def(LParts[1], 0);
      end
      else
      begin
        LHubDatabaseId := 0;
        LHubSchemaId := 0;
      end;
      if LParts.Count >= 3 then
        LApiKey := LParts[2]
      else
        LApiKey := '';
      TRpAuthManager.Instance.Log('ApplyLoadedSchemas: DisplayName=' + LDisplayName +
        ' RawValue=' + LValue + ' ParsedHubDatabaseId=' + IntToStr(LHubDatabaseId) +
        ' ParsedHubSchemaId=' + IntToStr(LHubSchemaId) + ' ApiKey=' + LApiKey);
      ComboSchema.Items.AddObject(LDisplayName,
        TSchemaComboItem.Create(LHubDatabaseId, LHubSchemaId, LApiKey));
    end;
    SelectCurrentSchema;
  finally
    LParts.Free;
    ComboSchema.Items.EndUpdate;
    FLoadingSchemas := False;
    ComboSchemaChange(ComboSchema);
    TRpAuthManager.Instance.Log('ApplyLoadedSchemas: FinalItemIndex=' +
      IntToStr(ComboSchema.ItemIndex) + ' FinalHubDatabaseId=' + IntToStr(GetHubDatabaseId) +
      ' FinalHubSchemaId=' + IntToStr(GetHubSchemaId) + ' FinalApiKey=' + GetSchemaApiKey);
    UpdateButtons;
  end;
end;

procedure TFRpChatFrame.ComboSchemaChange(Sender: TObject);
var
  LItem: TSchemaComboItem;
begin
  if FLoadingSchemas then
    Exit;
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
    begin
      FHubDatabaseId := LItem.HubDatabaseId;
      FHubSchemaId := LItem.HubSchemaId;
      FSchemaApiKey := LItem.ApiKey;
      TRpAuthManager.Instance.Log('ComboSchemaChange: ItemIndex=' +
        IntToStr(ComboSchema.ItemIndex) + ' HubDatabaseId=' + IntToStr(FHubDatabaseId) +
        ' HubSchemaId=' + IntToStr(FHubSchemaId) + ' ApiKey=' + FSchemaApiKey);
    end;
  end
  else
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
    TRpAuthManager.Instance.Log('ComboSchemaChange: ItemIndex=0 HubDatabaseId=0 HubSchemaId=0 ApiKey=');
  end;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

procedure TFRpChatFrame.AddAssistantMessage(const AText: string);
begin
  FLastAssistantMessage := Trim(AText);
  AppendMessage('Assistant', AText);
  UpdateButtons;
end;

procedure TFRpChatFrame.AddUserMessage(const AText: string);
begin
  AppendMessage('You', AText);
end;

procedure TFRpChatFrame.AISelectionStopRequest(Sender: TObject);
begin
  if Assigned(FOnBuildDesignRequest) and Assigned(FOnApplyDesignResult) then
  begin
    StopDesignPrompt;
    if Assigned(FOnStopRequest) then
      FOnStopRequest(Self);
    Exit;
  end;
  if Assigned(FOnStopRequest) then
    FOnStopRequest(Self);
end;

procedure TFRpChatFrame.BeginStreamingResponse;
begin
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := True;
  FProgressActive := False;
  FProgressTitle := '';
  FProgressText := '';
  if FWebLog <> nil then
  begin
    FLastLogActor := '';
    FLastProgressId := '';
    FWebLog.AppendLogLine('');
  end;
  SetBusy(True);
  EnsureAISelectionAutoHeight;
  PControl.ActivePage := TabLog;
  RebuildConversation;
end;

procedure TFRpChatFrame.ClearConversation;
begin
  FConversationBlocks.Clear;
  FLastAssistantMessage := '';
  MemoPrompt.Clear;
  if FWebLog <> nil then
    FWebLog.ClearAll;
  if FWebChat <> nil then
    FWebChat.ClearAll;
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := False;
  FProgressActive := False;
  FProgressTitle := '';
  FProgressText := '';
  EnsureAISelectionAutoHeight;
  UpdateButtons;
  RebuildConversation;
end;

procedure TFRpChatFrame.FinishStreamingResponse;
begin
  FStreamingActive := False;
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  EnsureAISelectionAutoHeight;
  SetBusy(False);
  PControl.ActivePage := TabChat;
  RebuildConversation;
end;

procedure TFRpChatFrame.Initialize(const ACurrentExpression,
  AInitialAssistantMessage: string);
begin
  FCurrentExpression := ACurrentExpression;
  FConversationBlocks.Clear;
  FLastAssistantMessage := '';
  MemoPrompt.Clear;
  if FWebChat <> nil then
    FWebChat.ClearAll;
  if FWebLog <> nil then
    FWebLog.ClearAll;
  if FWebNetLog <> nil then
    FWebNetLog.ClearAll;
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := False;
  FProgressActive := False;
  FProgressTitle := '';
  FProgressText := '';
  SetBusy(False);
  RebuildConversation;
  if AInitialAssistantMessage <> '' then
    AddAssistantMessage(AInitialAssistantMessage);
end;

procedure TFRpChatFrame.StartDesignPrompt(const APrompt: string);
var
  LPreprocessRequest: TRpApiPreprocessSqlContextRequest;
  LRequest: TRpApiModifyReportRequest;
  LWorker: TRpChatDesignWorker;
begin
  if not Assigned(FOnBuildDesignRequest) then
    Exit;
  LPreprocessRequest := nil;
  if Assigned(FOnBuildPreprocessSqlContextRequest) then
    LPreprocessRequest := FOnBuildPreprocessSqlContextRequest(Self);
  LRequest := FOnBuildDesignRequest(Self, APrompt);
  if LRequest = nil then
  begin
    LPreprocessRequest.Free;
    Exit;
  end;
  if Trim(LRequest.ReportDocument) = '' then
  begin
    LPreprocessRequest.Free;
    LRequest.Free;
    AddAssistantMessage('Unable to serialize the current report to XML.');
    Exit;
  end;

  // A new request cancels the previous one
  if FDesignCancel <> nil then
    FDesignCancel.Cancel;
  FDesignCancel := TRpAsyncCancel.Create;
  Inc(FDesignRequestVersion);
  BeginStreamingResponse;
  SetBusy(True);

  LWorker := TRpChatDesignWorker.Create(FMailboxRef);
  LWorker.Frame := Self;
  LWorker.Cancel := FDesignCancel;
  LWorker.Prompt := APrompt;
  LWorker.Request := LRequest;
  LWorker.PreprocessRequest := LPreprocessRequest;
  LWorker.RequestVersion := FDesignRequestVersion;
  LWorker.HubDatabaseId := GetHubDatabaseId;
  LWorker.HubSchemaId := GetHubSchemaId;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.NotifyInference := Assigned(FOnDesignInferenceBegin) or
    Assigned(FOnDesignInferenceEnd);
  LWorker.Start;
end;

procedure TFRpChatFrame.StartOnlineInitialization;
var
  LNeedsSchemas, LNeedsAgents: Boolean;
begin
  if not CRpChatEnableOnlineInitialization then
    Exit;
  LNeedsSchemas := FShowSchemaSelector and (ComboSchema.Items.Count = 0);
  LNeedsAgents := (FAISelection <> nil) and (FAISelection.AgentEndpointCount = 0);
  if FOnlineInitializationQueued and not (LNeedsSchemas or LNeedsAgents) then
    Exit;
  FOnlineInitializationQueued := True;
  if (FAISelection <> nil) and (Trim(TRpAuthManager.Instance.Token) <> '') then
  begin
    // CheckStatus validates the token; its auth event loads agents/schemas
    TRpAuthManager.Instance.Log(
      'StartOnlineInitialization: validating token with CheckStatus before loading agents/schemas.');
    FAISelection.RefreshStatusInBackground(CRpStartupNetworkDelayMs);
    Exit;
  end;
  if LNeedsSchemas then
    LoadSchemas(CRpStartupNetworkDelayMs);
  if LNeedsAgents then
    LoadUserAgents(CRpStartupNetworkDelayMs);
  if FAISelection <> nil then
    FAISelection.RefreshStatusInBackground(CRpStartupNetworkDelayMs);
end;

procedure TFRpChatFrame.SetCurrentExpression(const AExpression: string);
begin
  FCurrentExpression := AExpression;
end;

procedure TFRpChatFrame.StopDesignPrompt;
begin
  Inc(FDesignRequestVersion);
  if FDesignCancel <> nil then
    FDesignCancel.Cancel;
  FinishStreamingResponse;
  SetBusy(False);
  AddAssistantMessage(TranslateStr(1536, 'Generation stopped.'));
end;

procedure TFRpChatFrame.SetBusy(AValue: Boolean);
begin
  FBusy := AValue;
  if FAISelection <> nil then
    FAISelection.SetInferenceProgress(AValue);
  EnsureAISelectionAutoHeight;
  if FBusy then
    BClear.Caption := TranslateStr(1522, 'Stop')
  else
    BClear.Caption := TranslateStr(1532, 'Clear');
  UpdateButtons;
end;

procedure TFRpChatFrame.SetInferenceProgress(AValue: Boolean);
begin
  if FAISelection <> nil then
    FAISelection.SetInferenceProgress(AValue);
  EnsureAISelectionAutoHeight;
end;

procedure TFRpChatFrame.SetShowSchemaSelector(AValue: Boolean);
begin
  if FShowSchemaSelector = AValue then
    Exit;
  FShowSchemaSelector := AValue;
  if not FShowSchemaSelector then
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
    ClearSchemaItems;
  end;
  RefreshLayout;
end;

procedure TFRpChatFrame.SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
begin
  FHubDatabaseId := AHubDatabaseId;
  FHubSchemaId := AHubSchemaId;
  FSchemaApiKey := ASchemaApiKey;
  SelectCurrentSchema;
end;

procedure TFRpChatFrame.AppendLogLine(const AText: string);
begin
  if FWebLog <> nil then
    FWebLog.AppendLogLine(AText);
end;

procedure TFRpChatFrame.AppendNetLogLine(const AText: string);
begin
  if FWebNetLog <> nil then
    FWebNetLog.AppendLogLine(AText);
end;

procedure TFRpChatFrame.AuthLog(const AMsg: string);
begin
  // RpAuthEvents delivers it in the main thread
  AppendNetLogLine(FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + AMsg);
end;

procedure TFRpChatFrame.AppendLogChunk(const AChunk: string; AAppendLineBreak: Boolean);
begin
  if (FWebLog = nil) or (AChunk = '') then
    Exit;
  FWebLog.AppendLogChunk(AChunk);
  if AAppendLineBreak then
    FWebLog.EndLogChunk;
end;

procedure TFRpChatFrame.UpdateStreamingTokens(AInTokens, AOutTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
begin
  if FAISelection <> nil then
    FAISelection.UpdateTokens(AInTokens, AOutTokens, AProgressId, APrefillPercent);
  EnsureAISelectionAutoHeight;
end;

procedure TFRpChatFrame.CompleteStreamingProgress(const AActor, AChunkType,
  AProgressId: string);
begin
  if (FAISelection <> nil) and SameText(AActor, 'AI') and
    (SameText(AChunkType, 'End') or SameText(AChunkType, 'Full')) then
    FAISelection.FinishProgressToken(AProgressId);
  EnsureAISelectionAutoHeight;
end;

procedure TFRpChatFrame.BeginProgress(const ATitle, AText: string);
begin
  FProgressActive := True;
  if Trim(ATitle) <> '' then
    FProgressTitle := ATitle
  else
    FProgressTitle := 'System';
  FProgressText := AText;
  SetBusy(True);
  RebuildConversation;
end;

procedure TFRpChatFrame.UpdateProgress(const AText: string);
begin
  if not FProgressActive then
    BeginProgress('System', AText)
  else
  begin
    FProgressText := AText;
    RebuildConversation;
  end;
end;

procedure TFRpChatFrame.FinishProgress;
begin
  FProgressActive := False;
  FProgressTitle := '';
  FProgressText := '';
  SetBusy(False);
  RebuildConversation;
end;

procedure TFRpChatFrame.SetSuggestedContent(const AContent, AMessage, ACaptionLabel: string);
begin
  FinishStreamingResponse;
  FSuggestedExpression := AContent;
  if AMessage <> '' then
    AddAssistantMessage(AMessage + sLineBreak + sLineBreak + ACaptionLabel + ':' +
      sLineBreak + AContent)
  else
    AddAssistantMessage(ACaptionLabel + ':' + sLineBreak + AContent);
  UpdateButtons;
end;

procedure TFRpChatFrame.SetRefreshAction(AValue: Boolean);
begin
  FUseRefreshAction := AValue;
  if FUseRefreshAction then
    BApply.Caption := TranslateStr(1149, 'Refresh')
  else
    BApply.Caption := TranslateStr(1535, 'Apply');
  UpdateButtons;
end;

procedure TFRpChatFrame.SetSuggestedExpression(const AExpression, AMessage: string);
begin
  SetSuggestedContent(AExpression, AMessage, TranslateStr(1538, 'Suggested expression'));
end;

procedure TFRpChatFrame.UpdateButtons;
begin
  BSend.Enabled := (not FBusy) and (Trim(MemoPrompt.Text) <> '');
  if FUseRefreshAction then
    BApply.Enabled := (not FBusy) and Assigned(FOnRefreshContext)
  else
    BApply.Enabled := (not FBusy) and (Trim(FSuggestedExpression) <> '');
  BReportAI.Enabled := (not FBusy) and (Trim(FLastAssistantMessage) <> '');
  BRefreshSchemas.Enabled := not FLoadingSchemas;
  if FLoadingSchemas then
    BRefreshSchemas.Caption := '...'
  else
    BRefreshSchemas.Caption := TranslateStr(1149, 'Refresh');
end;

procedure TFRpChatFrame.UpdateStreamingResponse(const AActor, AChunkType,
  AChunk: string; APrefillPercent: Integer; const ALogChunk: string;
  const AProgressId: string);
var
  LLogChunk, LLogKey: string;
begin
  if not FStreamingActive then
    BeginStreamingResponse;
  if APrefillPercent > FStreamingPrefillPercent then
    FStreamingPrefillPercent := APrefillPercent;
  if (FAISelection <> nil) and SameText(AActor, 'AI') and (Trim(AProgressId) <> '') then
  begin
    FAISelection.TouchProgressToken(AProgressId);
    EnsureAISelectionAutoHeight;
  end;
  LLogChunk := ALogChunk;
  if LLogChunk = '' then
    LLogChunk := AChunk;
  LLogKey := Trim(AProgressId);
  if AChunk <> '' then
    FStreamingText := FStreamingText + AChunk;
  if FWebLog <> nil then
  begin
    if SameText(AChunkType, 'Full') or SameText(AChunkType, 'End') then
    begin
      if LLogChunk <> '' then
        FWebLog.AppendLogChunkKey(LLogKey, LLogChunk);
      FWebLog.EndLogChunkKey(LLogKey);
    end
    else if LLogChunk <> '' then
      FWebLog.AppendLogChunkKey(LLogKey, LLogChunk);
  end;
end;

procedure TFRpChatFrame.UpdateUserProfile(AProfile: TJSONObject);
begin
  if (FAISelection <> nil) and (AProfile <> nil) then
    FAISelection.UpdateFromUserProfile(AProfile);
end;

procedure TFRpChatFrame.HandleDesignChatPayload(APayload: TObject);
var
  LPayload: TRpQueuedDesignChatPayload;
  LMessage: string;
  LProfile: TJSONValue;
begin
  LPayload := TRpQueuedDesignChatPayload(APayload);
  if LPayload.RequestVersion <> FDesignRequestVersion then
    Exit;
  case LPayload.Kind of
    rpqdcUpdateStreamingResponse:
      begin
        UpdateStreamingResponse(LPayload.Actor1, LPayload.ChunkType1,
          LPayload.Text1, LPayload.PrefillPercent, LPayload.LogText1,
          LPayload.ProgressId1);
        if SameText(LPayload.Actor1, 'AI') then
          UpdateStreamingTokens(LPayload.InputTokens, LPayload.OutputTokens,
            LPayload.ProgressId1, LPayload.PrefillPercent);
        CompleteStreamingProgress(LPayload.Actor1, LPayload.ChunkType1,
          LPayload.ProgressId1);
        Exit;
      end;
    rpqdcAddAssistantMessage:
      begin
        FinishStreamingResponse;
        SetBusy(False);
        AddAssistantMessage(LPayload.Text1);
        Exit;
      end;
  end;

  if (LPayload.InputTokens > 0) or (LPayload.OutputTokens > 0) then
    UpdateStreamingTokens(LPayload.InputTokens, LPayload.OutputTokens);
  FinishStreamingResponse;
  SetBusy(False);

  if (Trim(LPayload.UserProfileJson) <> '') and
    (not SameText(Trim(LPayload.UserProfileJson), 'null')) then
  begin
    LProfile := TJSONObject.ParseJSONValue(LPayload.UserProfileJson);
    try
      if LProfile is TJSONObject then
        UpdateUserProfile(TJSONObject(LProfile));
    finally
      LProfile.Free;
    end;
  end;

  if Trim(LPayload.Text1) <> '' then
  begin
    if Assigned(FOnApplyDesignResult) then
    begin
      try
        FOnApplyDesignResult(Self, LPayload.Text1);
      except
        on E: Exception do
        begin
          AddAssistantMessage('The server returned a modified report, but it could not be loaded: ' +
            E.Message);
          Exit;
        end;
      end;
    end
    else
      AddAssistantMessage('A design result was received, but no apply handler is connected.');
  end;

  LMessage := Trim(LPayload.Text2);
  if LMessage = '' then
  begin
    if Trim(LPayload.Text1) <> '' then
      LMessage := TranslateStr(1539, 'Report updated.')
    else
      LMessage := TranslateStr(1540, 'No report changes were returned.');
  end;
  AddAssistantMessage(LMessage);
end;

function TFRpChatFrame.GetAITier: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AITier
  else
    Result := 'standard';
end;

function TFRpChatFrame.GetAIMode: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AIMode
  else
    Result := 'fast';
end;

function TFRpChatFrame.GetAgentSecret: string;
begin
  if FAISelection <> nil then
    Result := FAISelection.AgentSecret
  else
    Result := '';
end;

function TFRpChatFrame.GetAgentAiId: Int64;
begin
  if FAISelection <> nil then
    Result := FAISelection.AgentAiId
  else
    Result := 0;
end;

function TFRpChatFrame.GetHubDatabaseId: Int64;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.HubDatabaseId);
  end;
  Result := FHubDatabaseId;
end;

function TFRpChatFrame.GetHubSchemaId: Int64;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.HubSchemaId);
  end;
  Result := FHubSchemaId;
end;

function TFRpChatFrame.GetSchemaApiKey: string;
var
  LItem: TSchemaComboItem;
begin
  if ComboSchema.ItemIndex > 0 then
  begin
    LItem := TSchemaComboItem(ComboSchema.Items.Objects[ComboSchema.ItemIndex]);
    if LItem <> nil then
      Exit(LItem.ApiKey);
  end;
  Result := FSchemaApiKey;
end;

procedure TFRpChatFrame.BRefreshSchemasClick(Sender: TObject);
begin
  if FLoadingSchemas then
    Exit;
  LoadSchemas;
end;

procedure TFRpChatFrame.BSendClick(Sender: TObject);
var
  LPrompt: string;
begin
  LPrompt := Trim(MemoPrompt.Text);
  if LPrompt = '' then
  begin
    UpdateButtons;
    Exit;
  end;
  AddUserMessage(LPrompt);
  MemoPrompt.Clear;
  UpdateButtons;
  if Assigned(FOnBuildDesignRequest) and Assigned(FOnApplyDesignResult) then
    StartDesignPrompt(LPrompt)
  else if Assigned(FOnSendPrompt) then
    FOnSendPrompt(Self, LPrompt, FCurrentExpression)
  else
    AddAssistantMessage(TranslateStr(1537, 'Chat UI is ready, but no AI handler is connected yet.'));
end;

procedure TFRpChatFrame.MemoPromptChange(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TFRpChatFrame.MemoPromptKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // Enter sends, Shift+Enter is a new line
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    if (not FBusy) and (Trim(MemoPrompt.Text) <> '') then
      BSendClick(Self);
  end;
end;

procedure TFRpChatFrame.BApplyClick(Sender: TObject);
begin
  if FUseRefreshAction then
  begin
    if Assigned(FOnRefreshContext) then
      FOnRefreshContext(Self);
    Exit;
  end;
  if Trim(FSuggestedExpression) = '' then
    Exit;
  if Assigned(FOnApplySuggestion) then
    FOnApplySuggestion(Self, FSuggestedExpression);
end;

procedure TFRpChatFrame.BClearClick(Sender: TObject);
begin
  if FBusy then
    AISelectionStopRequest(Self)
  else
    ClearConversation;
end;

procedure TFRpChatFrame.BClearLogClick(Sender: TObject);
begin
  if FWebLog <> nil then
    FWebLog.ClearAll;
end;

procedure TFRpChatFrame.BClearNetLogClick(Sender: TObject);
begin
  if FWebNetLog <> nil then
    FWebNetLog.ClearAll;
end;

procedure TFRpChatFrame.BReportAIClick(Sender: TObject);
begin
  if FBusy or (Trim(FLastAssistantMessage) = '') then
  begin
    UpdateButtons;
    Exit;
  end;
  ExecuteAIReportDialog(GetParentForm(Self), FLastAssistantMessage,
    TRpAuthManager.Instance.Token, TRpAuthManager.Instance.InstallId,
    GetSchemaApiKey);
  UpdateButtons;
end;

end.

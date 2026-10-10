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
  ComCtrls, LCLType, Menus, rpjsonfpc, rpauthmanager, rpdatahttp,
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
  // The entries of the schema list: the schemas the AI can use (a Hub one or
  // a local one), the group headers and the two actions at the end
  TSchemaComboItemKind = (sckHub, sckLocal, sckHeader, sckNewLocal, sckNewCloud);

  TSchemaComboItem = class(TObject)
  public
    Kind: TSchemaComboItemKind;
    ApiKey: string;
    HubDatabaseId: Int64;
    HubSchemaId: Int64;
    // A direct connection of the report: a subschema of its local schema
    // file (dbxschemas/<ALIAS>.json); never all the tables, only a
    // subschema goes to the AI
    LocalAlias: string;
    LocalSchemaName: string;
    // The text without the icon and the warning of the plan
    Caption: string;
    // The tables that would travel (-1 = not known) and the columns of the
    // widest one
    Tables: Integer;
    WidestColumns: Integer;
    constructor Create(AHubDatabaseId, AHubSchemaId: Int64; const AApiKey: string);
    constructor CreateLocal(const ALocalAlias, ALocalSchemaName: string);
    constructor CreateKind(AKind: TSchemaComboItemKind; const ACaption: string);
    // A schema the AI can use, not a header or an action
    function IsSchema: Boolean;
  end;

  // The local schema utility of a direct connection: AAddNew starts adding
  // a subschema ("New local schema..."). The host reloads the list
  // (SetLocalSchemas) and selects the subschema saved (SelectLocalSchema)
  TChatConfigureLocalSchemasEvent = procedure(Sender: TObject;
    const AAlias, ASchemaName: string; AAddNew: Boolean) of object;

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
    FSchemaChangeFromLoad: Boolean;
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
    // Tokens and time of each model call of the request, for the AI log
    FInferenceLog: TRpInferenceLogMeter;
    FLoginPreferredHeight: Integer;
    FInitialLayoutDone: Boolean;
    FInTopLayout: Boolean;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    FLocalAlias: string;
    FLocalSchemaName: string;
    FLocalSchemas: TStringList;
    // The size of each entry of FLocalSchemas: '<tables>,<widest>' or ''
    FLocalSizes: TStringList;
    // The Hub schemas as loaded ('Name=db|schema|apikey') and their sizes
    // ('<schema>=<tables>,<widest>')
    FHubSchemaLines: TStringList;
    FHubSizes: TStringList;
    FHubSchemasLoaded: Boolean;
    // The Hub database of the context (SetHubContext): "New cloud schema..."
    FContextHubDatabaseId: Int64;
    FPreferredLocalAlias: string;
    FOnConfigureLocalSchemas: TChatConfigureLocalSchemasEvent;
    // The list is being changed by code: no change of the user
    FSelectingSchema: Boolean;
    FLastSchemaIndex: Integer;
    // The open list was just closed (ComboSchemaCloseUp)
    FSchemaListClosing: Boolean;
    // The texts changed while the list was open: refreshed when it closes
    FSchemaCaptionsPending: Boolean;
    FSchemaConfigMenu: TPopupMenu;
    FMenuLocalSchemas: TMenuItem;
    FMenuCloudSchemas: TMenuItem;
    procedure RebuildSchemaItems;
    procedure RefreshSchemaCaptions;
    function SchemaItem(AIndex: Integer): TSchemaComboItem;
    function SelectedSchemaItem: TSchemaComboItem;
    function SchemaItemText(AItem: TSchemaComboItem): string;
    function SchemaItemExceedsPlan(AItem: TSchemaComboItem): Boolean;
    function LocalSchemaTargetAlias: string;
    function NewCloudSchemaEnabled: Boolean;
    procedure ApplySelectedSchemaItem;
    procedure RememberSchemaChoice;
    procedure RunConfigureLocalSchemas(const AAlias, ASchemaName: string;
      AAddNew: Boolean);
    procedure RunSchemaAction(Data: PtrInt);
    procedure SchemaListClosed(Data: PtrInt);
    procedure ComboSchemaCloseUp(Sender: TObject);
    procedure ComboSchemaDropDown(Sender: TObject);
    procedure AISelectionProviderChange(Sender: TObject);
    procedure MenuLocalSchemasClick(Sender: TObject);
    procedure MenuCloudSchemasClick(Sender: TObject);
    procedure BuildControls;
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
    procedure DeferredLayout(Data: PtrInt);
    procedure ApplyLoadedUserAgents(ALoadedAgents: TStringList;
      const ASelectedTier: string; ASelectedAgentAiId: Int64;
      AReloadVersion: Integer);
    procedure ApplyLoadedSchemas(ALoadedSchemas, ASizes: TStringList;
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
    procedure LogTopResize(Sender: TObject);
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
    // The totals line of the request in the AI log: tokens, models, time
    // since BeginStreamingResponse and credits
    procedure AppendRequestTotals(AInputTokens, AOutputTokens,
      AThinkingTokens: Integer; const AModelNames: string;
      AHasCredits: Boolean; ACredits: Integer);
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
    // The Hub database of a schema of the schema list (0 when not listed)
    function HubDatabaseOfSchema(AHubSchemaId: Int64): Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
    // The subschemas of the direct connections of the report the chat offers
    // next to the Hub schemas: lines ALIAS=<subschema>, with the size of
    // each one in ASizes ('<tables>,<widest columns>', '' = not known; see
    // RpListLocalSchemaEntries); an ALIAS= line (all the tables) is not
    // listed, only a subschema goes to the AI. APreferredAlias is the direct
    // connection of the report: without a Hub schema of the report, its
    // subschema is selected (SelectCurrentSchema), or none when it has none
    procedure SetLocalSchemas(AEntries: TStrings; const APreferredAlias: string;
      ASizes: TStrings = nil);
    // A subschema of a direct connection: '' selects the one chosen before in
    // this session, else the first one of the connection, else none
    procedure SelectLocalSchema(const AAlias, ASchemaName: string);
    // The direct connection selected ('' = a Hub schema) and its subschema
    // ('' = none)
    function GetLocalSchemaAlias: string;
    function GetLocalSchemaName: string;
    // The list has a schema the AI can use (Hub or local)
    function HasSchemaItems: Boolean;
    // Why a request can not go to the AI with the schema of the list ('' =
    // it can): a direct connection without a subschema (1984), or a schema
    // bigger than the plan with the AI in the cloud (1844). The cloud is not
    // called then; the Hub connections and the reports without a connection
    // go as they did
    function SchemaSendRefusal: string;
    // "Local schemas..." of the configuration button and "New local
    // schema..." of the list: the local schema utility of a direct connection
    property OnConfigureLocalSchemas: TChatConfigureLocalSchemasEvent
      read FOnConfigureLocalSchemas write FOnConfigureLocalSchemas;
    // The menu of the configuration button (tests)
    property SchemaConfigMenu: TPopupMenu read FSchemaConfigMenu;
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
    // True during the OnSchemaChanged that follows the loading of the schema
    // list: the chat selected the schema itself (the one of its context, or
    // a fallback when the list does not have it), not the user
    property SchemaChangeFromLoad: Boolean read FSchemaChangeFromLoad;
    property OnSendPrompt: TChatSendEvent read FOnSendPrompt write FOnSendPrompt;
    property OnStopRequest: TChatStopEvent read FOnStopRequest write FOnStopRequest;
  end;

  TFRpExpressionChatFrame = TFRpChatFrame;

implementation

uses
  rpdatainfo, rpmdconsts, LazUTF8, rpfrmaireportlcl, rpdesignerclientsql,
  rplocalschemas;

const
  // The text of the schema list (UTF-8, the encoding of the LCL strings)
  CSchemaSeparator = ' '#$C2#$B7' ';
  CSchemaWarning = #$E2#$9A#$A0' ';
  // In front of each schema (and of its warning): local and in the cloud
  CSchemaLocalIcon = #$E2#$9B#$81' ';
  CSchemaCloudIcon = #$E2#$98#$81' ';
  CSchemaRule = #$E2#$94#$80#$E2#$94#$80;
  CNewCloudSchemaUrl = 'https://app.reportman.es/database-config?new=1';
  CCloudSchemasUrl = 'https://app.reportman.es/database-config';

type
  TRpQueuedSchemasPayload = class(TRpAsyncMessage)
  public
    ReloadVersion: Integer;
    Schemas: TStringList;
    // '<hubSchemaId>=<tables>,<widest columns>'
    Sizes: TStringList;
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
    // The totals of the request for the AI log (FillDesignPayloadTotals)
    HasTotals: Boolean;
    ThinkingTokens: Integer;
    ModelNames: string;
    HasCredits: Boolean;
    Credits: Integer;
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
    function LoadUserSchemas(AList, ASizes: TStrings): Boolean;
    function LoadConfiguredApiKeySchemas(AList, ASizes: TStrings): Boolean;
  end;

  TRpChatDesignWorker = class(TRpAsyncWorker)
  private
    FSyncPreprocessResponse: TRpApiPreprocessSqlContextResult;
    // The responses received, freed with the worker: an error message
    // (HandleError too) carries their totals to the AI log
    FPreprocessResponse: TRpApiPreprocessSqlContextResult;
    FResponse: TRpApiModifyReportResult;
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

// The totals of a design request: the token steps of the SQL context and of
// the design responses (nil = none), their models and their credits
procedure FillDesignPayloadTotals(APayload: TRpQueuedDesignChatPayload;
  APreprocess: TRpApiPreprocessSqlContextResult;
  AResponse: TRpApiModifyReportResult);
begin
  APayload.HasTotals := True;
  if APreprocess <> nil then
  begin
    RpSumTokenUsage(APreprocess.Steps, APayload.InputTokens,
      APayload.OutputTokens, APayload.ThinkingTokens, APayload.ModelNames);
    if APreprocess.HasCreditsConsumed then
    begin
      APayload.HasCredits := True;
      Inc(APayload.Credits, APreprocess.CreditsConsumed);
    end;
  end;
  if AResponse <> nil then
  begin
    RpSumTokenUsage(AResponse.Steps, APayload.InputTokens,
      APayload.OutputTokens, APayload.ThinkingTokens, APayload.ModelNames);
    if AResponse.HasCreditsConsumed then
    begin
      APayload.HasCredits := True;
      Inc(APayload.Credits, AResponse.CreditsConsumed);
    end;
  end;
end;

var
  // The schema chosen for each connection in this session:
  // 'L:<ALIAS>=<subschema>' and 'H:<hubDatabaseId>=<hubSchemaId>'
  GSchemaChoices: TStringList = nil;

procedure RememberChoice(const AKey, AValue: string);
begin
  if GSchemaChoices = nil then
    GSchemaChoices := TStringList.Create;
  GSchemaChoices.Values[AKey] := AValue;
end;

function RememberedChoice(const AKey: string): string;
begin
  Result := '';
  if GSchemaChoices <> nil then
    Result := GSchemaChoices.Values[AKey];
end;

// ' (N)': the tables that would travel, when known
function SchemaSizeSuffix(ATables: Integer): string;
begin
  if ATables >= 0 then
    Result := ' (' + IntToStr(ATables) + ')'
  else
    Result := '';
end;

// '<tables>,<widest>' to the two numbers; False when not known
function ParseSchemaSize(const AText: string; out ATables,
  AWidest: Integer): Boolean;
var
  LPos: Integer;
begin
  ATables := -1;
  AWidest := 0;
  LPos := Pos(',', AText);
  Result := LPos > 0;
  if not Result then
    Exit;
  ATables := StrToIntDef(Copy(AText, 1, LPos - 1), -1);
  AWidest := StrToIntDef(Copy(AText, LPos + 1, MaxInt), 0);
  Result := ATables >= 0;
end;

{ TSchemaComboItem }

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  Kind := sckHub;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
  ApiKey := AApiKey;
  Tables := -1;
end;

constructor TSchemaComboItem.CreateLocal(const ALocalAlias,
  ALocalSchemaName: string);
begin
  inherited Create;
  Kind := sckLocal;
  LocalAlias := ALocalAlias;
  LocalSchemaName := ALocalSchemaName;
  Tables := -1;
end;

constructor TSchemaComboItem.CreateKind(AKind: TSchemaComboItemKind;
  const ACaption: string);
begin
  inherited Create;
  Kind := AKind;
  Caption := ACaption;
  Tables := -1;
end;

function TSchemaComboItem.IsSchema: Boolean;
begin
  Result := Kind in [sckHub, sckLocal];
end;

// '<ALIAS> . <subschema>'
function LocalSchemaCaption(const AAlias, ASchemaName: string): string;
begin
  Result := AAlias + CSchemaSeparator + ASchemaName;
end;

function SchemaHeaderCaption(const AText: string): string;
begin
  Result := CSchemaRule + ' ' + AText + ' ' + CSchemaRule;
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
  Sizes := TStringList.Create;
end;

destructor TRpQueuedSchemasPayload.Destroy;
begin
  Schemas.Free;
  Sizes.Free;
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

function TRpChatSchemasWorker.LoadUserSchemas(AList, ASizes: TStrings): Boolean;
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
    Result := LHttp.GetUserSchemas(AList, ASizes);
  finally
    LHttp.Free;
  end;
end;

function TRpChatSchemasWorker.LoadConfiguredApiKeySchemas(AList, ASizes: TStrings): Boolean;
var
  I, J: Integer;
  LApiKey, LSchemaValue, LSchemaKey: string;
  LConAdmin: TRpConnAdmin;
  LConnectionNames, LParams, LRawSchemas, LRawSizes, LSeenApiKeys: TStringList;
  LHttp: TRpDatabaseHttp;
begin
  // The schemas visible with the API key of every configured connection
  Result := False;
  AList.Clear;
  LConAdmin := TRpConnAdmin.Create;
  LConnectionNames := TStringList.Create;
  LParams := TStringList.Create;
  LRawSchemas := TStringList.Create;
  LRawSizes := TStringList.Create;
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
        if LHttp.GetUserSchemas(LRawSchemas, LRawSizes) then
        begin
          Result := True;
          if ASizes <> nil then
            ASizes.AddStrings(LRawSizes);
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
    LRawSizes.Free;
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
      LoadUserSchemas(LUserSchemas, LPayload.Sizes);
    except
      LUserSchemas.Clear;
    end;
    try
      LoadConfiguredApiKeySchemas(LApiKeySchemas, LPayload.Sizes);
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
  FPreprocessResponse.Free;
  FResponse.Free;
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
  // The request ends: the totals of what was received go to the AI log
  FillDesignPayloadTotals(LPayload, FPreprocessResponse, FResponse);
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
  LHttp: TRpDatabaseHttp;
  LPayload: TRpQueuedDesignChatPayload;
  LPreprocessUserProfileJson: string;
  LInferenceActive: Boolean;
begin
  LHttp := TRpDatabaseHttp.Create;
  LPreprocessUserProfileJson := '';
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
      // A direct connection: its schema travels inline (the schema file is
      // generated the first time)
      if Trim(Request.Config.LocalAlias) <> '' then
      begin
        RpResolveLocalSchemaConfig(Request.Config, Request.ReportDocument);
        PreprocessRequest.Config.Assign(Request.Config);
      end;
      FPreprocessResponse := LHttp.PreprocessSqlContext(PreprocessRequest, Self,
        StreamProgress, StreamCancelRequested);
      if Cancelled then
        Exit;
      if (FPreprocessResponse <> nil) and (Trim(FPreprocessResponse.ErrorMessage) <> '') then
        raise Exception.Create(RpComposeApiErrorMessage(FPreprocessResponse.ErrorMessage,
          FPreprocessResponse.ErrorCode, FPreprocessResponse.DebugDetails));
      FSyncPreprocessResponse := FPreprocessResponse;
      SyncCall(SyncApplyPreprocess);
      if Cancelled then
        Exit;
      if Trim(Request.ReportDocument) = '' then
        raise Exception.Create('Unable to serialize the current report to XML after preprocessing SQL context.');
      if FPreprocessResponse <> nil then
        LPreprocessUserProfileJson := FPreprocessResponse.UserProfileJson;
    end;

    if NotifyInference then
    begin
      SyncCall(SyncInferenceBegin);
      LInferenceActive := True;
    end;
    try
      // With the turns in which the SQL of a database that is not in the Hub
      // runs here (rpdesignerclientsql)
      FResponse := RpModifyReportWithClientSql(LHttp, Request, Self,
        StreamProgress, StreamCancelRequested);
    finally
      if LInferenceActive then
        SyncCall(SyncInferenceEnd);
    end;

    if Cancelled then
      Exit;
    if FResponse = nil then
    begin
      PostAssistantMessage('No response received from the server.');
      Exit;
    end;
    if Trim(FResponse.ErrorMessage) <> '' then
    begin
      // The plan error (errorCode) as the cloud says it: its numbers and the
      // way out
      PostAssistantMessage(RpComposeApiErrorMessage(FResponse.ErrorMessage,
        FResponse.ErrorCode, FResponse.DebugDetails));
      Exit;
    end;
    if Assigned(FResponse.ResultData) and (Trim(FResponse.ResultData.ErrorMessage) <> '') then
    begin
      PostAssistantMessage(FResponse.ResultData.ErrorMessage);
      Exit;
    end;

    LPayload := TRpQueuedDesignChatPayload.Create;
    LPayload.Kind := rpqdcApplyDesignResult;
    LPayload.RequestVersion := RequestVersion;
    // The tokens of the SQL context and of the design (and the totals of the
    // AI log)
    FillDesignPayloadTotals(LPayload, FPreprocessResponse, FResponse);
    if Assigned(FResponse.ResultData) then
    begin
      LPayload.Text1 := FResponse.ResultData.ModifiedReportDocument;
      LPayload.Text2 := FResponse.ResultData.Explanation;
    end;
    LPayload.UserProfileJson := FResponse.UserProfileJson;
    if Trim(LPayload.UserProfileJson) = '' then
      LPayload.UserProfileJson := LPreprocessUserProfileJson;
    Post(LPayload);
  finally
    // The responses are freed with the worker (see FPreprocessResponse)
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
  FLocalSchemas := TStringList.Create;
  FLocalSizes := TStringList.Create;
  FHubSchemaLines := TStringList.Create;
  FHubSizes := TStringList.Create;
  FLastSchemaIndex := -1;
  FInferenceLog := TRpInferenceLogMeter.Create;
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
    // alTop as in the VCL: the selection sets its own height (alClient
    // makes the host and the frame fight over it on GTK2: layout loop)
    FAISelection.Align := alTop;
    FAISelection.OnStopRequest := AISelectionStopRequest;
    // No warning of the plan with the AI of an Agent
    FAISelection.OnProviderChange := AISelectionProviderChange;
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
  FLocalSchemas.Free;
  FLocalSizes.Free;
  FHubSchemaLines.Free;
  FHubSizes.Free;
  FreeAndNil(FInferenceLog);
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
  // Laid out in LayoutSchemaControls: anchored on both sides its width is
  // fixed and AutoSize only sets the height (Cocoa gives the combo a
  // preferred width, that AutoSize would set back on every Resize)
  ComboSchema.Anchors := [akLeft, akTop, akRight];
  ComboSchema.Style := csDropDownList;
  ComboSchema.OnChange := ComboSchemaChange;
  ComboSchema.OnCloseUp := ComboSchemaCloseUp;
  ComboSchema.OnDropDown := ComboSchemaDropDown;
  ComboSchema.ShowHint := True;

  PSchemaConfigHost := NewPanel(PSchemaHost, alNone);
  FSchemaConfigButton := TRpChatIconButton.Create(Self);
  FSchemaConfigButton.Parent := PSchemaConfigHost;
  FSchemaConfigButton.Align := alClient;
  FSchemaConfigButton.Kind := rpikCog;
  FSchemaConfigButton.Hint := TranslateStr(1496, 'Configure DB Schemas');
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.OnClick := SchemaConfigClick;
  // A dropdown: the local schemas and the ones in the cloud
  FSchemaConfigMenu := TPopupMenu.Create(Self);
  FMenuLocalSchemas := TMenuItem.Create(FSchemaConfigMenu);
  FMenuLocalSchemas.Caption := TranslateStr(1840, 'Local schemas...');
  FMenuLocalSchemas.OnClick := MenuLocalSchemasClick;
  FSchemaConfigMenu.Items.Add(FMenuLocalSchemas);
  FMenuCloudSchemas := TMenuItem.Create(FSchemaConfigMenu);
  FMenuCloudSchemas.Caption := TranslateStr(1841, 'Cloud schemas...');
  FMenuCloudSchemas.OnClick := MenuCloudSchemasClick;
  FSchemaConfigMenu.Items.Add(FMenuCloudSchemas);

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
  // Both buttons in a row (without it the second one went to a second row
  // that the panel cut); the panel takes the height of its row
  PLogTop.ChildSizing.ControlsPerLine := 2;
  PLogTop.AutoSize := True;
  BClearLog := NewButton(PLogTop, TranslateStr(1532, 'Clear'), BClearLogClick);
  BClearLog.AutoSize := True;
  BReportAI := NewButton(PLogTop, TranslateStr(1533, 'Report content'), BReportAIClick);
  BReportAI.AutoSize := True;
  // A narrow chat (small screen, splitter) puts them one below the other
  PLogTop.OnResize := LogTopResize;

  TabNetLog := TTabSheet.Create(PControl);
  TabNetLog.PageControl := PControl;
  TabNetLog.Caption := TranslateStr(1531, 'Net Log');
  PNetLogTop := NewPanel(TabNetLog, alTop);
  PNetLogTop.Height := Scale(38);
  PNetLogTop.ChildSizing.LeftRightSpacing := Scale(8);
  PNetLogTop.ChildSizing.TopBottomSpacing := Scale(4);
  PNetLogTop.ChildSizing.Layout := cclLeftToRightThenTopToBottom;
  PNetLogTop.ChildSizing.ControlsPerLine := 1;
  PNetLogTop.AutoSize := True;
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
  // The SetBounds below resize the frame children and come back here
  if (PTop = nil) or FInTopLayout then
    Exit;
  FInTopLayout := True;
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
    FInTopLayout := False;
  end;
  if FLoginFrame <> nil then
    FLoginFrame.RefreshLayout;
  if FAISelection <> nil then
  begin
    FAISelection.RefreshLayout;
    // Its height depends on the widgetset combo height, known now
    if FAISelection.Height <> PAISelectionHost.Height then
    begin
      FInTopLayout := True;
      try
        LAISelectionHeight := FAISelection.Height;
        LTop := PAISelectionHost.Top + LAISelectionHeight;
        PAISelectionHost.Height := LAISelectionHeight;
        PSchemaHost.Top := LTop;
        if PSchemaHost.Visible then
          Inc(LTop, PSchemaHost.Height);
        PTop.Height := LTop + Scale(4);
      finally
        FInTopLayout := False;
      end;
    end;
  end;
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
  // Another account, another plan: its warnings
  RefreshSchemaCaptions;
  if FShowSchemaSelector then
    LoadSchemas;
end;

procedure TFRpChatFrame.SchemaConfigClick(Sender: TObject);
var
  LPoint: TPoint;
begin
  // A dropdown: the local schema utility and the schemas in the cloud
  FMenuLocalSchemas.Enabled := (LocalSchemaTargetAlias <> '') and
    Assigned(FOnConfigureLocalSchemas);
  LPoint := FSchemaConfigButton.ClientToScreen(
    Point(0, FSchemaConfigButton.Height));
  FSchemaConfigMenu.PopUp(LPoint.X, LPoint.Y);
end;

procedure TFRpChatFrame.MenuLocalSchemasClick(Sender: TObject);
var
  LAlias, LSchemaName: string;
begin
  LAlias := LocalSchemaTargetAlias;
  if LAlias = '' then
    Exit;
  LSchemaName := '';
  if SameText(LAlias, FLocalAlias) then
    LSchemaName := FLocalSchemaName;
  RunConfigureLocalSchemas(LAlias, LSchemaName, False);
end;

procedure TFRpChatFrame.MenuCloudSchemasClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenUrl(CCloudSchemasUrl);
end;

// The direct connection of "New local schema..." and "Local schemas...":
// the one selected, else the one of the report
function TFRpChatFrame.LocalSchemaTargetAlias: string;
begin
  Result := FLocalAlias;
  if Result = '' then
    Result := FPreferredLocalAlias;
  if (Result = '') and (FLocalSchemas.Count > 0) then
    Result := FLocalSchemas.Names[0];
end;

// "New cloud schema...": not with a direct connection (it is not in the Hub)
function TFRpChatFrame.NewCloudSchemaEnabled: Boolean;
begin
  Result := FLocalAlias = '';
end;

procedure TFRpChatFrame.RunConfigureLocalSchemas(const AAlias,
  ASchemaName: string; AAddNew: Boolean);
var
  LAlias, LSchemaName: string;
  LHubSchemaId: Int64;
begin
  if (AAlias = '') or not Assigned(FOnConfigureLocalSchemas) then
    Exit;
  LAlias := FLocalAlias;
  LSchemaName := FLocalSchemaName;
  LHubSchemaId := FHubSchemaId;
  FOnConfigureLocalSchemas(Self, AAlias, ASchemaName, AAddNew);
  // The host reloaded the list and selected the subschema saved: a choice
  // of the user
  if (not SameText(LAlias, FLocalAlias)) or
    (not SameText(LSchemaName, FLocalSchemaName)) or
    (LHubSchemaId <> FHubSchemaId) then
  begin
    RememberSchemaChoice;
    if Assigned(FOnSchemaChanged) then
      FOnSchemaChanged(Self);
  end;
end;

procedure TFRpChatFrame.RunSchemaAction(Data: PtrInt);
var
  LHubDatabaseId: Int64;
  LUrl: string;
begin
  if csDestroying in ComponentState then
    Exit;
  case TSchemaComboItemKind(Data) of
    sckNewLocal:
      RunConfigureLocalSchemas(LocalSchemaTargetAlias, '', True);
    sckNewCloud:
      begin
        if not NewCloudSchemaEnabled then
          Exit;
        // On the Hub database of the schema chosen, or of the Agent
        // connection of the report
        LHubDatabaseId := GetHubDatabaseId;
        if LHubDatabaseId <= 0 then
          LHubDatabaseId := FContextHubDatabaseId;
        LUrl := CNewCloudSchemaUrl;
        if LHubDatabaseId > 0 then
          LUrl := LUrl + '&hubDatabaseId=' + IntToStr(LHubDatabaseId);
        TRpAuthManager.Instance.OpenUrl(LUrl);
      end;
  end;
end;

function TFRpChatFrame.SchemaItem(AIndex: Integer): TSchemaComboItem;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < ComboSchema.Items.Count) then
    Result := TSchemaComboItem(ComboSchema.Items.Objects[AIndex]);
end;

function TFRpChatFrame.SelectedSchemaItem: TSchemaComboItem;
begin
  Result := SchemaItem(ComboSchema.ItemIndex);
  if (Result <> nil) and not Result.IsSchema then
    Result := nil;
end;

function TFRpChatFrame.HasSchemaItems: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to ComboSchema.Items.Count - 1 do
    if (SchemaItem(I) <> nil) and SchemaItem(I).IsSchema then
      Exit(True);
end;

// More than the plan allows with the AI in the cloud (not with an Agent)
function TFRpChatFrame.SchemaItemExceedsPlan(AItem: TSchemaComboItem): Boolean;
begin
  Result := (AItem <> nil) and AItem.IsSchema and (AItem.Tables >= 0) and
    (not SameText(GetAITier, 'LocalAgent')) and
    TRpAuthManager.Instance.SchemaExceedsTier(AItem.Tables, AItem.WidestColumns);
end;

// The icon of the schema, then the warning of the plan, then its text
function TFRpChatFrame.SchemaItemText(AItem: TSchemaComboItem): string;
begin
  Result := AItem.Caption;
  if SchemaItemExceedsPlan(AItem) then
    Result := CSchemaWarning + Result
  else if (AItem.Kind = sckNewCloud) and not NewCloudSchemaEnabled then
    Result := Result + ' (' + TranslateStr(1842,
      'This connection is not in the Hub') + ')';
  case AItem.Kind of
    sckLocal:
      Result := CSchemaLocalIcon + Result;
    sckHub:
      Result := CSchemaCloudIcon + Result;
  end;
end;

function TFRpChatFrame.SchemaSendRefusal: string;
var
  LItem: TSchemaComboItem;
  LAlias: string;
begin
  Result := '';
  // The expression chat has no schema
  if not FShowSchemaSelector then
    Exit;
  LItem := SelectedSchemaItem;
  if LItem = nil then
  begin
    // Nothing chosen on a direct connection (none of its subschemas, or the
    // one chosen is gone); a Hub context waiting for its list goes as it did
    if (FHubDatabaseId <> 0) or (FHubSchemaId <> 0) then
      Exit;
    LAlias := LocalSchemaTargetAlias;
    if LAlias <> '' then
      Result := RpSubSchemaRequiredMessage(LAlias);
  end
  else if (LItem.Kind = sckLocal) and (Trim(LItem.LocalSchemaName) = '') then
    Result := RpSubSchemaRequiredMessage(LItem.LocalAlias)
  // The AI of an Agent has no limit (SchemaItemExceedsPlan); the AI.Api
  // still decides with the plan of who pays
  else if SchemaItemExceedsPlan(LItem) then
    Result := string(TranslateStr(1844, 'More than your plan allows with ' +
      'the AI in the cloud: choose a smaller schema or use the AI on your Agent.'));
end;

// The warnings of the plan (the tier, the provider) and "New cloud
// schema..." (the selection) change without rebuilding the list
procedure TFRpChatFrame.RefreshSchemaCaptions;
var
  I, LIndex: Integer;
  LItem: TSchemaComboItem;
  LText: string;
begin
  FSchemaCaptionsPending := False;
  LIndex := ComboSchema.ItemIndex;
  FSelectingSchema := True;
  try
    for I := 0 to ComboSchema.Items.Count - 1 do
    begin
      LItem := SchemaItem(I);
      if LItem = nil then
        Continue;
      LText := SchemaItemText(LItem);
      if ComboSchema.Items[I] <> LText then
        ComboSchema.Items[I] := LText;
    end;
    if ComboSchema.ItemIndex <> LIndex then
      ComboSchema.ItemIndex := LIndex;
  finally
    FSelectingSchema := False;
  end;
  if SchemaItemExceedsPlan(SelectedSchemaItem) then
    ComboSchema.Hint := TranslateStr(1844, 'More than your plan allows with ' +
      'the AI in the cloud: choose a smaller schema or use the AI on your Agent.')
  else
    ComboSchema.Hint := '';
end;

// The list: the local subschemas, the schemas in the cloud and the two
// actions. All the tables of a direct connection (its dictionary) are never
// offered: only a subschema goes to the AI
procedure TFRpChatFrame.RebuildSchemaItems;
var
  I, LTables, LWidest: Integer;
  LAlias, LSchemaName, LDisplayName, LValue: string;
  LItem: TSchemaComboItem;
  LParts: TStringList;
  LHubDatabaseId, LHubSchemaId: Int64;
  LHasLocal: Boolean;
begin
  ComboSchema.Items.BeginUpdate;
  LParts := TStringList.Create;
  FSelectingSchema := True;
  try
    ClearSchemaItems;
    LHasLocal := False;
    for I := 0 to FLocalSchemas.Count - 1 do
      if (FLocalSchemas.Names[I] <> '') and
        (Trim(FLocalSchemas.ValueFromIndex[I]) <> '') then
        LHasLocal := True;
    if LHasLocal then
    begin
      LItem := TSchemaComboItem.CreateKind(sckHeader,
        SchemaHeaderCaption(TranslateStr(1836, 'Local')));
      ComboSchema.Items.AddObject(LItem.Caption, LItem);
      for I := 0 to FLocalSchemas.Count - 1 do
      begin
        LAlias := FLocalSchemas.Names[I];
        LSchemaName := FLocalSchemas.ValueFromIndex[I];
        if (LAlias = '') or (Trim(LSchemaName) = '') then
          Continue;
        LItem := TSchemaComboItem.CreateLocal(LAlias, LSchemaName);
        if I < FLocalSizes.Count then
          ParseSchemaSize(FLocalSizes[I], LItem.Tables, LItem.WidestColumns);
        LItem.Caption := LocalSchemaCaption(LAlias, LSchemaName) +
          SchemaSizeSuffix(LItem.Tables);
        ComboSchema.Items.AddObject(SchemaItemText(LItem), LItem);
      end;
    end;
    if FHubSchemaLines.Count > 0 then
    begin
      LItem := TSchemaComboItem.CreateKind(sckHeader,
        SchemaHeaderCaption(TranslateStr(1837, 'In the cloud')));
      ComboSchema.Items.AddObject(LItem.Caption, LItem);
      LParts.Delimiter := '|';
      LParts.StrictDelimiter := True;
      for I := 0 to FHubSchemaLines.Count - 1 do
      begin
        LDisplayName := FHubSchemaLines.Names[I];
        LValue := FHubSchemaLines.ValueFromIndex[I];
        LParts.DelimitedText := LValue;
        LHubDatabaseId := 0;
        LHubSchemaId := 0;
        if LParts.Count >= 2 then
        begin
          LHubDatabaseId := StrToInt64Def(LParts[0], 0);
          LHubSchemaId := StrToInt64Def(LParts[1], 0);
        end;
        if LParts.Count >= 3 then
          LItem := TSchemaComboItem.Create(LHubDatabaseId, LHubSchemaId, LParts[2])
        else
          LItem := TSchemaComboItem.Create(LHubDatabaseId, LHubSchemaId, '');
        if ParseSchemaSize(FHubSizes.Values[IntToStr(LHubSchemaId)], LTables,
          LWidest) then
        begin
          LItem.Tables := LTables;
          LItem.WidestColumns := LWidest;
        end;
        LItem.Caption := LDisplayName + SchemaSizeSuffix(LItem.Tables);
        ComboSchema.Items.AddObject(SchemaItemText(LItem), LItem);
      end;
    end;
    if ComboSchema.Items.Count > 0 then
    begin
      LItem := TSchemaComboItem.CreateKind(sckHeader, CSchemaRule + CSchemaRule +
        CSchemaRule + CSchemaRule + CSchemaRule);
      ComboSchema.Items.AddObject(LItem.Caption, LItem);
    end;
    LItem := TSchemaComboItem.CreateKind(sckNewLocal,
      TranslateStr(1838, 'New local schema...'));
    ComboSchema.Items.AddObject(LItem.Caption, LItem);
    LItem := TSchemaComboItem.CreateKind(sckNewCloud,
      TranslateStr(1839, 'New cloud schema...'));
    ComboSchema.Items.AddObject(LItem.Caption, LItem);
  finally
    FSelectingSchema := False;
    LParts.Free;
    ComboSchema.Items.EndUpdate;
  end;
  SelectCurrentSchema;
end;

procedure TFRpChatFrame.SetLocalSchemas(AEntries: TStrings;
  const APreferredAlias: string; ASizes: TStrings);
var
  I: Integer;
  LAliasKnown, LKnown: Boolean;
begin
  FLocalSchemas.Clear;
  FLocalSizes.Clear;
  if AEntries <> nil then
    FLocalSchemas.Assign(AEntries);
  if ASizes <> nil then
    FLocalSizes.Assign(ASizes);
  FPreferredLocalAlias := APreferredAlias;
  // The selected direct connection may be gone, or only its subschema (then
  // the one chosen before, its first one or none: SelectCurrentSchema). A
  // connection without subschemas has no line: it stays while it is the one
  // of the report
  LAliasKnown := SameText(FLocalAlias, FPreferredLocalAlias);
  LKnown := False;
  for I := 0 to FLocalSchemas.Count - 1 do
    if SameText(FLocalSchemas.Names[I], FLocalAlias) then
    begin
      LAliasKnown := True;
      if SameText(FLocalSchemas.ValueFromIndex[I], FLocalSchemaName) then
        LKnown := True;
    end;
  if not LAliasKnown then
    FLocalAlias := '';
  if not LKnown then
    FLocalSchemaName := '';
  RebuildSchemaItems;
end;

procedure TFRpChatFrame.SelectLocalSchema(const AAlias, ASchemaName: string);
begin
  FLocalAlias := AAlias;
  FLocalSchemaName := ASchemaName;
  if AAlias <> '' then
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
  end;
  SelectCurrentSchema;
end;

function TFRpChatFrame.GetLocalSchemaAlias: string;
begin
  Result := FLocalAlias;
end;

function TFRpChatFrame.GetLocalSchemaName: string;
begin
  Result := FLocalSchemaName;
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
    ApplyLoadedSchemas(LSchemas.Schemas, LSchemas.Sizes, LSchemas.ReloadVersion);
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
  LFound: Boolean;
  LRemembered: Int64;
  LLocalAlias: string;

  // ASchemaName '' = the first subschema of the connection
  function SelectLocalItem(const AAlias, ASchemaName: string;
    AFirst: Boolean = False): Boolean;
  var
    J: Integer;
    LLocal: TSchemaComboItem;
  begin
    Result := False;
    if (not AFirst) and (Trim(ASchemaName) = '') then
      Exit;
    for J := 0 to ComboSchema.Items.Count - 1 do
    begin
      LLocal := SchemaItem(J);
      if (LLocal <> nil) and (LLocal.Kind = sckLocal) and
        SameText(LLocal.LocalAlias, AAlias) and
        (AFirst or SameText(LLocal.LocalSchemaName, ASchemaName)) then
      begin
        ComboSchema.ItemIndex := J;
        FLocalAlias := LLocal.LocalAlias;
        FLocalSchemaName := LLocal.LocalSchemaName;
        FHubDatabaseId := 0;
        FHubSchemaId := 0;
        FSchemaApiKey := '';
        Exit(True);
      end;
    end;
  end;

  function SelectHubItem(AHubDatabaseId, AHubSchemaId: Int64): Boolean;
  var
    J: Integer;
    LHub: TSchemaComboItem;
  begin
    Result := False;
    for J := 0 to ComboSchema.Items.Count - 1 do
    begin
      LHub := SchemaItem(J);
      if (LHub <> nil) and (LHub.Kind = sckHub) and
        ((AHubSchemaId = 0) or (LHub.HubSchemaId = AHubSchemaId)) and
        ((AHubDatabaseId = 0) or (LHub.HubDatabaseId = AHubDatabaseId)) then
      begin
        ComboSchema.ItemIndex := J;
        FHubDatabaseId := LHub.HubDatabaseId;
        FHubSchemaId := LHub.HubSchemaId;
        FSchemaApiKey := LHub.ApiKey;
        Exit(True);
      end;
    end;
  end;

begin
  // Nothing listed yet: the context waits for the list
  if ComboSchema.Items.Count = 0 then
    Exit;
  FSelectingSchema := True;
  try
    LFound := False;
    // A direct connection (the one chosen, else the one of a report without
    // a Hub context), so the new datasets go there and not to a Reportman AI
    // Agent one: the subschema of a dataset or chosen (FLocalSchemaName),
    // else the one chosen before in this session, else its first one; none
    // without subschemas, the chat asks for one when sending
    LLocalAlias := FLocalAlias;
    if (LLocalAlias = '') and (FHubSchemaId = 0) and (FHubDatabaseId = 0) then
      LLocalAlias := FPreferredLocalAlias;
    if LLocalAlias <> '' then
    begin
      LFound := (SameText(LLocalAlias, FLocalAlias) and
        SelectLocalItem(LLocalAlias, FLocalSchemaName)) or
        SelectLocalItem(LLocalAlias,
        RememberedChoice('L:' + UpperCase(LLocalAlias))) or
        SelectLocalItem(LLocalAlias, '', True);
      if not LFound then
      begin
        // Not a Hub schema instead (below, LLocalAlias <> '')
        ComboSchema.ItemIndex := -1;
        FLocalSchemaName := '';
        FHubDatabaseId := 0;
        FHubSchemaId := 0;
        FSchemaApiKey := '';
      end;
    end;
    // A specific Hub schema first
    if (not LFound) and (FHubSchemaId <> 0) then
      LFound := SelectHubItem(0, FHubSchemaId);
    // Then the schema of the connection chosen before in this session, or its
    // first one
    if (not LFound) and (FHubDatabaseId <> 0) then
    begin
      LRemembered := StrToInt64Def(
        RememberedChoice('H:' + IntToStr(FHubDatabaseId)), 0);
      LFound := ((LRemembered <> 0) and SelectHubItem(FHubDatabaseId, LRemembered)) or
        SelectHubItem(FHubDatabaseId, 0);
    end;
    // Else the very first Hub schema (a report without a connection); the
    // Hub schema of the context waits for the Hub list
    if (not LFound) and (LLocalAlias = '') then
    begin
      if (not FHubSchemasLoaded) and ((FHubSchemaId <> 0) or
        (FHubDatabaseId <> 0)) then
        ComboSchema.ItemIndex := -1
      else
      begin
        LFound := SelectHubItem(0, 0);
        if not LFound then
        begin
          ComboSchema.ItemIndex := -1;
          FHubDatabaseId := 0;
          FHubSchemaId := 0;
          FSchemaApiKey := '';
        end;
      end;
    end;
  finally
    FSelectingSchema := False;
  end;
  FLastSchemaIndex := ComboSchema.ItemIndex;
  RefreshSchemaCaptions;
end;

procedure TFRpChatFrame.ApplyLoadedSchemas(ALoadedSchemas, ASizes: TStringList;
  AReloadVersion: Integer);
var
  I: Integer;
begin
  // The payload owns the lists
  if AReloadVersion <> FUserSchemasReloadVersion then
    Exit;
  try
    for I := 0 to ALoadedSchemas.Count - 1 do
      TRpAuthManager.Instance.Log('ApplyLoadedSchemas: DisplayName=' +
        ALoadedSchemas.Names[I] + ' DatabaseAndSchema=' +
        Copy(ALoadedSchemas.ValueFromIndex[I], 1,
        LastDelimiter('|', ALoadedSchemas.ValueFromIndex[I]) - 1));
    // The Hub schemas with the local ones of the report
    FHubSchemaLines.Assign(ALoadedSchemas);
    FHubSizes.Assign(ASizes);
    FHubSchemasLoaded := True;
    RebuildSchemaItems;
  finally
    FLoadingSchemas := False;
    FSchemaChangeFromLoad := True;
    try
      ComboSchemaChange(ComboSchema);
    finally
      FSchemaChangeFromLoad := False;
    end;
    TRpAuthManager.Instance.Log('ApplyLoadedSchemas: FinalItemIndex=' +
      IntToStr(ComboSchema.ItemIndex) + ' FinalHubDatabaseId=' + IntToStr(GetHubDatabaseId) +
      ' FinalHubSchemaId=' + IntToStr(GetHubSchemaId) + ' FinalApiKey=' + RpMaskSecret(GetSchemaApiKey));
    UpdateButtons;
  end;
end;

// The schema of the item selected (none: no schema)
procedure TFRpChatFrame.ApplySelectedSchemaItem;
var
  LItem: TSchemaComboItem;
begin
  LItem := SelectedSchemaItem;
  if LItem <> nil then
  begin
    FHubDatabaseId := LItem.HubDatabaseId;
    FHubSchemaId := LItem.HubSchemaId;
    FSchemaApiKey := LItem.ApiKey;
    FLocalAlias := LItem.LocalAlias;
    FLocalSchemaName := LItem.LocalSchemaName;
  end
  else
  begin
    FHubDatabaseId := 0;
    FHubSchemaId := 0;
    FSchemaApiKey := '';
    FLocalAlias := '';
    FLocalSchemaName := '';
  end;
  FLastSchemaIndex := ComboSchema.ItemIndex;
  TRpAuthManager.Instance.Log('ComboSchemaChange: ItemIndex=' +
    IntToStr(ComboSchema.ItemIndex) + ' HubDatabaseId=' + IntToStr(FHubDatabaseId) +
    ' HubSchemaId=' + IntToStr(FHubSchemaId) + ' LocalAlias=' + FLocalAlias +
    ' LocalSchema=' + FLocalSchemaName + ' ApiKey=' + RpMaskSecret(FSchemaApiKey));
end;

// The schema chosen for its connection, for the rest of the session
procedure TFRpChatFrame.RememberSchemaChoice;
begin
  if FLocalAlias <> '' then
    RememberChoice('L:' + UpperCase(FLocalAlias), FLocalSchemaName)
  else if (FHubDatabaseId <> 0) and (FHubSchemaId <> 0) then
    RememberChoice('H:' + IntToStr(FHubDatabaseId), IntToStr(FHubSchemaId));
end;

procedure TFRpChatFrame.ComboSchemaChange(Sender: TObject);
var
  LItem: TSchemaComboItem;
  LIndex, LStep: Integer;
begin
  if FLoadingSchemas or FSelectingSchema then
    Exit;
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if (LItem <> nil) and not LItem.IsSchema then
  begin
    // In the open list the click decides (ComboSchemaCloseUp)
    if ComboSchema.DroppedDown then
      Exit;
    // The selection of the list just closed (it may come after the close):
    // back to the schema chosen and the action runs
    if FSchemaListClosing then
    begin
      ComboSchemaCloseUp(ComboSchema);
      Exit;
    end;
    // The keys of the closed list skip a header and do not run an action
    LIndex := -1;
    if LItem.Kind = sckHeader then
    begin
      if ComboSchema.ItemIndex > FLastSchemaIndex then
        LStep := 1
      else
        LStep := -1;
      LIndex := ComboSchema.ItemIndex;
      while (LIndex >= 0) and (LIndex < ComboSchema.Items.Count) and
        not SchemaItem(LIndex).IsSchema do
        Inc(LIndex, LStep);
      if (LIndex < 0) or (LIndex >= ComboSchema.Items.Count) then
        LIndex := -1;
    end;
    if LIndex < 0 then
    begin
      SelectCurrentSchema;
      Exit;
    end;
    FSelectingSchema := True;
    try
      ComboSchema.ItemIndex := LIndex;
    finally
      FSelectingSchema := False;
    end;
  end;
  ApplySelectedSchemaItem;
  if not FSchemaChangeFromLoad then
    RememberSchemaChoice;
  // Not in the open list (the keys move through it): when it closes
  if ComboSchema.DroppedDown then
    FSchemaCaptionsPending := True
  else
    RefreshSchemaCaptions;
  if Assigned(FOnSchemaChanged) then
    FOnSchemaChanged(Self);
end;

// A header or an action clicked in the open list: back to the schema chosen,
// and the action runs once the list is closed
procedure TFRpChatFrame.ComboSchemaCloseUp(Sender: TObject);
var
  LItem: TSchemaComboItem;
begin
  if FSchemaCaptionsPending then
    RefreshSchemaCaptions;
  LItem := SchemaItem(ComboSchema.ItemIndex);
  if (LItem = nil) or LItem.IsSchema then
  begin
    // The selection may come after the close: until the messages of this
    // click are handled (SchemaListClosed)
    if not FSchemaListClosing then
    begin
      FSchemaListClosing := True;
      Application.QueueAsyncCall(SchemaListClosed, 0);
    end;
    Exit;
  end;
  FSchemaListClosing := False;
  SelectCurrentSchema;
  if LItem.Kind in [sckNewLocal, sckNewCloud] then
    Application.QueueAsyncCall(RunSchemaAction, PtrInt(Ord(LItem.Kind)));
end;

procedure TFRpChatFrame.SchemaListClosed(Data: PtrInt);
begin
  FSchemaListClosing := False;
end;

procedure TFRpChatFrame.ComboSchemaDropDown(Sender: TObject);
begin
  RefreshSchemaCaptions;
end;

procedure TFRpChatFrame.AISelectionProviderChange(Sender: TObject);
begin
  RefreshSchemaCaptions;
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
  if FInferenceLog <> nil then
    FInferenceLog.BeginRequest;
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
  LRefusal: string;
begin
  if not Assigned(FOnBuildDesignRequest) then
    Exit;
  // Without a subschema of a direct connection, or with a schema bigger
  // than the plan, the cloud is not called (before the datasets are opened)
  LRefusal := SchemaSendRefusal;
  if LRefusal <> '' then
  begin
    AddAssistantMessage(LRefusal);
    Exit;
  end;
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
  LNeedsSchemas := FShowSchemaSelector and not FHubSchemasLoaded;
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
    FLocalAlias := '';
    FLocalSchemaName := '';
    FHubSchemaLines.Clear;
    FHubSizes.Clear;
    FHubSchemasLoaded := False;
    ClearSchemaItems;
    FLastSchemaIndex := -1;
  end;
  RefreshLayout;
end;

procedure TFRpChatFrame.SetHubContext(AHubDatabaseId, AHubSchemaId: Int64;
  const ASchemaApiKey: string);
begin
  FHubDatabaseId := AHubDatabaseId;
  FHubSchemaId := AHubSchemaId;
  FSchemaApiKey := ASchemaApiKey;
  FContextHubDatabaseId := AHubDatabaseId;
  // A Hub context of the report wins over a direct connection chosen before
  if (AHubDatabaseId <> 0) or (AHubSchemaId <> 0) then
  begin
    FLocalAlias := '';
    FLocalSchemaName := '';
  end;
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
  if FInferenceLog <> nil then
    FInferenceLog.Frame(AProgressId, AInTokens, AOutTokens);
  EnsureAISelectionAutoHeight;
end;

procedure TFRpChatFrame.CompleteStreamingProgress(const AActor, AChunkType,
  AProgressId: string);
var
  LLine: string;
begin
  if SameText(AActor, 'AI') and
    (SameText(AChunkType, 'End') or SameText(AChunkType, 'Full')) then
  begin
    if FAISelection <> nil then
      FAISelection.FinishProgressToken(AProgressId);
    // The model call ended: its tokens and time stay in the AI log
    if FInferenceLog <> nil then
    begin
      LLine := FInferenceLog.FinishCall(AProgressId);
      if LLine <> '' then
        AppendLogLine(LLine);
    end;
  end;
  EnsureAISelectionAutoHeight;
end;

procedure TFRpChatFrame.AppendRequestTotals(AInputTokens, AOutputTokens,
  AThinkingTokens: Integer; const AModelNames: string; AHasCredits: Boolean;
  ACredits: Integer);
var
  LSeconds: Double;
begin
  LSeconds := 0;
  if FInferenceLog <> nil then
    LSeconds := FInferenceLog.ElapsedSeconds;
  AppendLogLine(RpFormatInferenceTotalsLog(AInputTokens, AOutputTokens,
    AThinkingTokens, AModelNames, LSeconds, AHasCredits, ACredits));
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
  // The first frame of a model call starts its clock
  if (FInferenceLog <> nil) and SameText(AActor, 'AI') then
    FInferenceLog.Frame(AProgressId);
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
  // The plan may have changed: its warnings
  RefreshSchemaCaptions;
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
        if LPayload.HasTotals then
          AppendRequestTotals(LPayload.InputTokens, LPayload.OutputTokens,
            LPayload.ThinkingTokens, LPayload.ModelNames, LPayload.HasCredits,
            LPayload.Credits);
        FinishStreamingResponse;
        SetBusy(False);
        AddAssistantMessage(LPayload.Text1);
        Exit;
      end;
  end;

  if (LPayload.InputTokens > 0) or (LPayload.OutputTokens > 0) then
    UpdateStreamingTokens(LPayload.InputTokens, LPayload.OutputTokens);
  // The totals stay in the AI log (the progress panel hides them)
  if LPayload.HasTotals then
    AppendRequestTotals(LPayload.InputTokens, LPayload.OutputTokens,
      LPayload.ThinkingTokens, LPayload.ModelNames, LPayload.HasCredits,
      LPayload.Credits);
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

function TFRpChatFrame.HubDatabaseOfSchema(AHubSchemaId: Int64): Int64;
var
  I: Integer;
  LItem: TSchemaComboItem;
begin
  Result := 0;
  if AHubSchemaId <= 0 then
    Exit;
  for I := 0 to ComboSchema.Items.Count - 1 do
  begin
    LItem := SchemaItem(I);
    if (LItem <> nil) and (LItem.Kind = sckHub) and
      (LItem.HubSchemaId = AHubSchemaId) then
      Exit(LItem.HubDatabaseId);
  end;
end;

function TFRpChatFrame.GetHubDatabaseId: Int64;
var
  LItem: TSchemaComboItem;
begin
  LItem := SelectedSchemaItem;
  if LItem <> nil then
    Exit(LItem.HubDatabaseId);
  Result := FHubDatabaseId;
end;

function TFRpChatFrame.GetHubSchemaId: Int64;
var
  LItem: TSchemaComboItem;
begin
  LItem := SelectedSchemaItem;
  if LItem <> nil then
    Exit(LItem.HubSchemaId);
  Result := FHubSchemaId;
end;

function TFRpChatFrame.GetSchemaApiKey: string;
var
  LItem: TSchemaComboItem;
begin
  LItem := SelectedSchemaItem;
  if LItem <> nil then
    Exit(LItem.ApiKey);
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
  LPrompt, LRefusal: string;
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
  begin
    // The SQL of a dataset (NL to SQL): the same rule as the design
    LRefusal := SchemaSendRefusal;
    if LRefusal <> '' then
      AddAssistantMessage(LRefusal)
    else
      FOnSendPrompt(Self, LPrompt, FCurrentExpression);
  end
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

// Both buttons of the AI log in a row when they fit; the panel takes the
// height of the rows
procedure TFRpChatFrame.LogTopResize(Sender: TObject);
var
  LNeeded: Integer;
begin
  LNeeded := BClearLog.Width + BReportAI.Width + PLogTop.ChildSizing.HorizontalSpacing +
    2 * PLogTop.ChildSizing.LeftRightSpacing;
  if PLogTop.ClientWidth >= LNeeded then
    PLogTop.ChildSizing.ControlsPerLine := 2
  else
    PLogTop.ChildSizing.ControlsPerLine := 1;
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

initialization

finalization
  FreeAndNil(GSchemaChoices);

end.

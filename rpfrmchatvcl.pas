unit rpfrmchatvcl;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, Buttons, System.JSON,
  rpauthmanager, rpfrmaiselectionvcl, rpfrmloginframevcl, rpdatahttp,
  rpreportdesignercontracts, rpfrmaireportvcl;

type
  TConfigIconButton = class(TSpeedButton)
  protected
    procedure Paint; override;
  end;

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

  TRpQueuedAgentsPayload = class(TObject)
  public
    Agents: TStringList;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    ReloadVersion: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TFRpChatFrame = class(TFrame)
    PRoot: TPanel;
    PTop: TPanel;
    GridTop: TGridPanel;
    PLoginHost: TPanel;
    PAISelectionHost: TPanel;
    PSchemaHost: TPanel;
    LSchema: TLabel;
    PSchemaConfigHost: TPanel;
    BRefreshSchemas: TButton;
    ComboSchema: TComboBox;
    PControl: TPageControl;
    TabChat: TTabSheet;
    MemoConversation: TMemo;
    TabLog: TTabSheet;
    PLogTop: TPanel;
    BClearLog: TButton;
    BReportAI: TButton;
    MemoLog: TMemo;
    PBottom: TPanel;
    MemoPrompt: TMemo;
    PButtons: TPanel;
    BSend: TButton;
    BApply: TButton;
    BClear: TButton;
    procedure BApplyClick(Sender: TObject);
    procedure BClearClick(Sender: TObject);
    procedure BClearLogClick(Sender: TObject);
    procedure BReportAIClick(Sender: TObject);
    procedure BRefreshSchemasClick(Sender: TObject);
    procedure BSendClick(Sender: TObject);
    procedure MemoPromptChange(Sender: TObject);
    procedure MemoPromptKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    FAISelection: TFRpAISelectionVCL;
    FBusy: Boolean;
    FConversationBlocks: TStringList;
    FCurrentExpression: string;
    FHubDatabaseId: Int64;
    FHubSchemaId: Int64;
    FLoginFrame: TFRpLoginFrameVCL;
    FLoadingSchemas: Boolean;
    FOnApplyDesignResult: TApplyDesignResultEvent;
    FOnApplyPreprocessSqlContextResult: TApplyPreprocessSqlContextResultEvent;
    FOnApplySuggestion: TChatApplyEvent;
    FOnBuildDesignRequest: TBuildDesignRequestEvent;
    FOnBuildPreprocessSqlContextRequest: TBuildPreprocessSqlContextRequestEvent;
    FOnRefreshContext: TChatRefreshEvent;
    FOnSchemaChanged: TChatSchemaChangedEvent;
    FOnSendPrompt: TChatSendEvent;
    FOnStopRequest: TChatStopEvent;
    FSchemaApiKey: string;
    FSuggestedExpression: string;
    FStreamingActive: Boolean;
    FStreamingPrefillPercent: Integer;
    FStreamingText: string;
    FOnlineInitializationQueued: Boolean;
    FLastAssistantMessage: string;
    FShowSchemaSelector: Boolean;
    FSchemaConfigButton: TConfigIconButton;
    FUserAgentsReloadVersion: Integer;
    FUserSchemasReloadVersion: Integer;
    FUseRefreshAction: Boolean;
    FDesignRequestVersion: Integer;
    procedure WMApplyLoadedUserAgents(var Message: TMessage); message WM_USER + 202;
    procedure WMApplyLoadedSchemas(var Message: TMessage); message WM_USER + 203;
    procedure WMHandleDesignChatPayload(var Message: TMessage); message WM_USER + 208;
    procedure ApplyLoadedUserAgents(ALoadedAgents: TStringList;
      const ASelectedTier: string; ASelectedAgentAiId: Int64;
      AReloadVersion: Integer);
    procedure ApplyLoadedSchemas(ALoadedSchemas: TStringList;
      AReloadVersion: Integer);
    procedure AuthChanged(ASuccess: Boolean);
    procedure AppendMessage(const ATitle, AText: string);
    procedure ClearSchemaItems;
    procedure ComboSchemaChange(Sender: TObject);
    function LoadConfiguredApiKeySchemas(AList: TStrings): Boolean;
    procedure LoadSchemas;
    function LoadUserSchemas(AList: TStrings): Boolean;
    procedure LoadUserAgents;
    function GetDesignPrefillPercent(const AStage, AChunkType: string): Integer;
    procedure PostDesignChatPayload(APayload: TObject);
    procedure SchemaConfigClick(Sender: TObject);
    procedure DesignStreamProgress(Sender: TObject; const AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
    function DesignStreamCancelRequested(Sender: TObject): Boolean;
    procedure RefreshTopLayout;
    procedure RebuildConversation;
    procedure SelectCurrentSchema;
    procedure ScrollConversationToEnd;
    procedure StopDesignPrompt;
    procedure UpdateButtons;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Resize; override;
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
    procedure UpdateStreamingTokens(AInTokens, AOutTokens: Integer);
    procedure SetRefreshAction(AValue: Boolean);
    procedure SetSuggestedExpression(const AExpression, AMessage: string);
    procedure UpdateStreamingResponse(const AChunk: string; APrefillPercent: Integer);
    procedure UpdateUserProfile(AProfile: TJSONObject);
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
    function GetHubDatabaseId: Int64;
    function GetHubSchemaId: Int64;
    function GetSchemaApiKey: string;
  published
    property OnApplyDesignResult: TApplyDesignResultEvent read FOnApplyDesignResult write FOnApplyDesignResult;
    property OnApplyPreprocessSqlContextResult: TApplyPreprocessSqlContextResultEvent read FOnApplyPreprocessSqlContextResult write FOnApplyPreprocessSqlContextResult;
    property OnApplySuggestion: TChatApplyEvent read FOnApplySuggestion write FOnApplySuggestion;
    property OnBuildDesignRequest: TBuildDesignRequestEvent read FOnBuildDesignRequest write FOnBuildDesignRequest;
    property OnBuildPreprocessSqlContextRequest: TBuildPreprocessSqlContextRequestEvent read FOnBuildPreprocessSqlContextRequest write FOnBuildPreprocessSqlContextRequest;
    property OnRefreshContext: TChatRefreshEvent read FOnRefreshContext write FOnRefreshContext;
    property OnSchemaChanged: TChatSchemaChangedEvent read FOnSchemaChanged write FOnSchemaChanged;
    property OnSendPrompt: TChatSendEvent read FOnSendPrompt write FOnSendPrompt;
    property OnStopRequest: TChatStopEvent read FOnStopRequest write FOnStopRequest;
  end;

  TFRpExpressionChatFrame = TFRpChatFrame;

implementation

{$R *.dfm}

uses
  rpdatainfo;

procedure TConfigIconButton.Paint;
var
  R: TRect;
  CX, CY: Integer;
  OuterRadius, InnerRadius, CenterRadius: Integer;
  FontColor: TColor;

  procedure DrawSpoke(const DX1, DY1, DX2, DY2: Integer);
  begin
    Canvas.MoveTo(CX + DX1, CY + DY1);
    Canvas.LineTo(CX + DX2, CY + DY2);
  end;
begin
  R := ClientRect;

  if not Enabled then
    FontColor := clGrayText
  else
    FontColor := clBtnText;

  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(R);
  DrawEdge(Canvas.Handle, R, BDR_RAISEDINNER, BF_RECT);

  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  if Width < Height then
    OuterRadius := Width div 4
  else
    OuterRadius := Height div 4;
  if OuterRadius < 6 then
    OuterRadius := 6;
  InnerRadius := OuterRadius - 3;
  if InnerRadius < 3 then
    InnerRadius := 3;
  CenterRadius := InnerRadius - 3;
  if CenterRadius < 2 then
    CenterRadius := 2;

  Canvas.Pen.Color := FontColor;
  Canvas.Pen.Width := 2;
  DrawSpoke(0, -OuterRadius, 0, -InnerRadius);
  DrawSpoke(0, InnerRadius, 0, OuterRadius);
  DrawSpoke(-OuterRadius, 0, -InnerRadius, 0);
  DrawSpoke(InnerRadius, 0, OuterRadius, 0);
  DrawSpoke(-OuterRadius + 2, -OuterRadius + 2, -InnerRadius, -InnerRadius);
  DrawSpoke(OuterRadius - 2, -OuterRadius + 2, InnerRadius, -InnerRadius);
  DrawSpoke(-OuterRadius + 2, OuterRadius - 2, -InnerRadius, InnerRadius);
  DrawSpoke(OuterRadius - 2, OuterRadius - 2, InnerRadius, InnerRadius);

  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(CX - InnerRadius, CY - InnerRadius, CX + InnerRadius, CY + InnerRadius);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FontColor;
  Canvas.Ellipse(CX - CenterRadius, CY - CenterRadius, CX + CenterRadius, CY + CenterRadius);
end;

type
  TRpQueuedSchemasPayload = class(TObject)
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

  TRpQueuedDesignChatPayload = class(TObject)
  public
    Kind: TRpQueuedDesignChatPayloadKind;
    RequestVersion: Integer;
    Text1: string;
    Text2: string;
    PrefillPercent: Integer;
    InputTokens: Integer;
    OutputTokens: Integer;
    UserProfileJson: string;
  end;

  TRpDesignChatStreamContext = class(TObject)
  public
    RequestVersion: Integer;
  end;

constructor TSchemaComboItem.Create(AHubDatabaseId, AHubSchemaId: Int64;
  const AApiKey: string);
begin
  inherited Create;
  HubDatabaseId := AHubDatabaseId;
  HubSchemaId := AHubSchemaId;
  ApiKey := AApiKey;
end;

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

constructor TFRpChatFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConversationBlocks := TStringList.Create;
  FLoginFrame := TFRpLoginFrameVCL.Create(Self);
  FLoginFrame.Parent := PLoginHost;
  FLoginFrame.Align := alClient;

  FAISelection := TFRpAISelectionVCL.Create(Self);
  FAISelection.Parent := PAISelectionHost;
  FAISelection.Align := alClient;
  FAISelection.Constraints.MinHeight := 63;
  FAISelection.Constraints.MaxHeight := 63;
  FAISelection.OnStopRequest := AISelectionStopRequest;

  ComboSchema.Style := csDropDownList;
  ComboSchema.OnChange := ComboSchemaChange;
  FHubDatabaseId := 0;
  FHubSchemaId := 0;
  FSchemaApiKey := '';
  FShowSchemaSelector := True;
  FLoadingSchemas := False;

  TRpAuthManager.Instance.RegisterAuthListener(AuthChanged);

  MemoConversation.Clear;
  MemoPrompt.Clear;
  if MemoLog <> nil then
  begin
    MemoLog.HandleNeeded;
    MemoLog.WordWrap := True;
    MemoLog.ScrollBars := ssVertical;
    MemoLog.Clear;
  end;
  FBusy := False;
  FLastAssistantMessage := '';
  FSuggestedExpression := '';
  FStreamingActive := False;
  FStreamingPrefillPercent := 0;
  FStreamingText := '';
  FOnlineInitializationQueued := False;
  FUserAgentsReloadVersion := 0;
  FUserSchemasReloadVersion := 0;
  FUseRefreshAction := False;
  FDesignRequestVersion := 0;
  MemoPrompt.WantReturns := True;
  MemoPrompt.OnKeyDown := MemoPromptKeyDown;
  FSchemaConfigButton := TConfigIconButton.Create(Self);
  FSchemaConfigButton.Parent := PSchemaConfigHost;
  FSchemaConfigButton.Align := alClient;
  FSchemaConfigButton.Flat := False;
  FSchemaConfigButton.Hint := 'Open schema configuration on the web';
  FSchemaConfigButton.ShowHint := True;
  FSchemaConfigButton.Cursor := crHandPoint;
  FSchemaConfigButton.OnClick := SchemaConfigClick;
  Initialize('', '');
  RefreshTopLayout;
end;

destructor TFRpChatFrame.Destroy;
begin
  ClearSchemaItems;
  FConversationBlocks.Free;
  TRpAuthManager.Instance.UnregisterAuthListener(AuthChanged);
  inherited Destroy;
end;

procedure TFRpChatFrame.Resize;
begin
  inherited;
  RefreshTopLayout;
end;

procedure TFRpChatFrame.RefreshTopLayout;
var
  LSchemaHeight: Integer;
begin
  DisableAlign;
  try
  if FShowSchemaSelector then
    LSchemaHeight := PSchemaHost.Height
  else
    LSchemaHeight := 0;
  if GridTop <> nil then
  begin
    if GridTop.RowCollection.Count > 0 then
    begin
      GridTop.RowCollection[0].SizeStyle := ssAbsolute;
      GridTop.RowCollection[0].Value := PLoginHost.Height;
    end;
    if GridTop.RowCollection.Count > 1 then
    begin
      GridTop.RowCollection[1].SizeStyle := ssAbsolute;
      GridTop.RowCollection[1].Value := PAISelectionHost.Height;
    end;
    if GridTop.RowCollection.Count > 2 then
    begin
      GridTop.RowCollection[2].SizeStyle := ssAbsolute;
      GridTop.RowCollection[2].Value := LSchemaHeight;
    end;
  end;
  if PSchemaHost <> nil then
    PSchemaHost.Visible := FShowSchemaSelector;
  if PTop <> nil then
    PTop.Height := PLoginHost.Height + PAISelectionHost.Height + LSchemaHeight;
  if PTop <> nil then
    PTop.SetBounds(0, 0, PRoot.ClientWidth, PTop.Height);
  if GridTop <> nil then
    GridTop.SetBounds(0, 0, PTop.ClientWidth, PTop.ClientHeight);
  if GridTop <> nil then
    GridTop.Realign;
  if PTop <> nil then
    PTop.Realign;
  if PLoginHost <> nil then
    PLoginHost.Realign;
  if PAISelectionHost <> nil then
    PAISelectionHost.Realign;
  if PSchemaHost <> nil then
    PSchemaHost.Realign;
  if FLoginFrame <> nil then
  begin
    FLoginFrame.SetBounds(0, 0, PLoginHost.ClientWidth, PLoginHost.ClientHeight);
    FLoginFrame.RefreshLayout;
  end;
  if FAISelection <> nil then
  begin
    FAISelection.SetBounds(0, 0, PAISelectionHost.ClientWidth,
      PAISelectionHost.ClientHeight);
    FAISelection.RefreshLayout;
  end;
  if PSchemaHost <> nil then
    PSchemaHost.Realign;
  finally
    EnableAlign;
  end;
  if PRoot <> nil then
    PRoot.Realign;
  Invalidate;
end;

procedure TFRpChatFrame.RefreshLayout;
begin
  RefreshTopLayout;
  UpdateButtons;
end;

procedure TFRpChatFrame.AuthChanged(ASuccess: Boolean);
begin
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
  I: Integer;
  LText: string;
begin
  LText := '';
  for I := 0 to FConversationBlocks.Count - 1 do
  begin
    if LText <> '' then
      LText := LText + sLineBreak + sLineBreak;
    LText := LText + FConversationBlocks[I];
  end;

  if FStreamingActive then
  begin
    if LText <> '' then
      LText := LText + sLineBreak + sLineBreak;
    LText := LText + 'Assistant' + sLineBreak +
      'Prefill ' + IntToStr(FStreamingPrefillPercent) + '%' + sLineBreak +
      FStreamingText;
  end;

  MemoConversation.Lines.Text := LText;
  ScrollConversationToEnd;
end;

procedure TFRpChatFrame.ScrollConversationToEnd;
begin
  MemoConversation.SelLength := 0;
  MemoConversation.SelStart := Length(MemoConversation.Text);
  MemoConversation.Perform(EM_SCROLLCARET, 0, 0);
  MemoConversation.Perform(WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TFRpChatFrame.LoadUserAgents;
var
  LInstallId: string;
  LPayload: TRpQueuedAgentsPayload;
  LReloadVersion: Integer;
  LSelectedTier: string;
  LSelectedAgentAiId: Int64;
  LToken: string;
  LWorker: TThread;
begin
  if FAISelection = nil then
    Exit;

  Inc(FUserAgentsReloadVersion);
  LReloadVersion := FUserAgentsReloadVersion;
  LSelectedTier := FAISelection.AITier;
  LSelectedAgentAiId := FAISelection.AgentAiId;
  LToken := TRpAuthManager.Instance.Token;
  LInstallId := TRpAuthManager.Instance.InstallId;
  FAISelection.ClearAgentEndpoints;

  if LToken = '' then
  begin
    FAISelection.RestoreProviderSelection(LSelectedTier, LSelectedAgentAiId);
    Exit;
  end;

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LAgents: TStringList;
      LHttp: TRpDatabaseHttp;
    begin
      LAgents := TStringList.Create;
      try
        try
          LHttp := TRpDatabaseHttp.Create;
          try
            LHttp.Token := LToken;
            LHttp.InstallId := LInstallId;
            if not LHttp.GetUserAgents(LAgents) then
              LAgents.Clear;
          finally
            LHttp.Free;
          end;
        except
          LAgents.Clear;
        end;

        LPayload := TRpQueuedAgentsPayload.Create;
        LPayload.Agents.Assign(LAgents);
        LPayload.SelectedTier := LSelectedTier;
        LPayload.SelectedAgentAiId := LSelectedAgentAiId;
        LPayload.ReloadVersion := LReloadVersion;
        if HandleAllocated then
          PostMessage(Handle, WM_USER + 202, WPARAM(LPayload), 0)
        else
          LPayload.Free;
      except
        LAgents.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
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

function TFRpChatFrame.LoadUserSchemas(AList: TStrings): Boolean;
var
  LHttp: TRpDatabaseHttp;
begin
  Result := False;
  if TRpAuthManager.Instance.Token = '' then
    Exit;

  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := TRpAuthManager.Instance.Token;
    LHttp.InstallId := TRpAuthManager.Instance.InstallId;
    Result := LHttp.GetUserSchemas(AList);
  finally
    LHttp.Free;
  end;
end;

function TFRpChatFrame.LoadConfiguredApiKeySchemas(AList: TStrings): Boolean;
var
  I, J, LPosSep: Integer;
  LApiKey: string;
  LConAdmin: TRpConnAdmin;
  LConnectionNames: TStringList;
  LParams: TStringList;
  LRawSchemas: TStringList;
  LSeenApiKeys: TStringList;
  LHttp: TRpDatabaseHttp;
  LSchemaDisplayName: string;
  LSchemaValue: string;
  LSchemaKey: string;
begin
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
      if LApiKey = '' then
        Continue;
      if LSeenApiKeys.IndexOf(LApiKey) >= 0 then
        Continue;
      LSeenApiKeys.Add(LApiKey);

      LHttp := TRpDatabaseHttp.Create;
      try
        LHttp.ApiKey := LApiKey;
        LHttp.Token := TRpAuthManager.Instance.Token;
        LHttp.InstallId := TRpAuthManager.Instance.InstallId;
        LRawSchemas.Clear;
        if LHttp.GetUserSchemas(LRawSchemas) then
        begin
          Result := True;
          for J := 0 to LRawSchemas.Count - 1 do
          begin
            LSchemaDisplayName := LRawSchemas.Names[J];
            LSchemaValue := LRawSchemas.ValueFromIndex[J];
            LPosSep := Pos('|', LSchemaValue);
            if LPosSep > 0 then
              LSchemaKey := LSchemaValue
            else
              LSchemaKey := '0|' + LSchemaValue;
            AList.Add(LSchemaDisplayName + '=' + LSchemaKey + '|' + LApiKey);
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

procedure TFRpChatFrame.LoadSchemas;
var
  LReloadVersion: Integer;
  LWorker: TThread;
begin
  Inc(FUserSchemasReloadVersion);
  LReloadVersion := FUserSchemasReloadVersion;
  FLoadingSchemas := True;
  UpdateButtons;

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      I, LPosSep: Integer;
      LPayload: TRpQueuedSchemasPayload;
      LUserSchemas: TStringList;
      LApiKeySchemas: TStringList;
      LSeenSchemaKeys: TStringList;
      LDisplayName: string;
      LValue: string;
      LSchemaKey: string;
    begin
      LPayload := TRpQueuedSchemasPayload.Create;
      LUserSchemas := TStringList.Create;
      LApiKeySchemas := TStringList.Create;
      LSeenSchemaKeys := TStringList.Create;
      try
        LSeenSchemaKeys.Sorted := True;
        LSeenSchemaKeys.Duplicates := dupIgnore;
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
          LDisplayName := LUserSchemas.Names[I];
          LValue := LUserSchemas.ValueFromIndex[I];
          LSchemaKey := LValue;
          if LSeenSchemaKeys.IndexOf(LSchemaKey) >= 0 then
            Continue;
          LSeenSchemaKeys.Add(LSchemaKey);
          LPayload.Schemas.Add(LDisplayName + '=' + LValue + '|');
        end;

        for I := 0 to LApiKeySchemas.Count - 1 do
        begin
          LDisplayName := LApiKeySchemas.Names[I];
          LValue := LApiKeySchemas.ValueFromIndex[I];
          LPosSep := LastDelimiter('|', LValue);
          if LPosSep > 0 then
            LSchemaKey := Copy(LValue, 1, LPosSep - 1)
          else
            LSchemaKey := LValue;
          if LSeenSchemaKeys.IndexOf(LSchemaKey) >= 0 then
            Continue;
          LSeenSchemaKeys.Add(LSchemaKey);
          LPayload.Schemas.Add(LDisplayName + '=' + LValue);
        end;

        LPayload.ReloadVersion := LReloadVersion;
        if HandleAllocated then
          PostMessage(Handle, WM_USER + 203, WPARAM(LPayload), 0)
        else
          LPayload.Free;
      finally
        LSeenSchemaKeys.Free;
        LApiKeySchemas.Free;
        LUserSchemas.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpChatFrame.WMApplyLoadedUserAgents(var Message: TMessage);
var
  LPayload: TRpQueuedAgentsPayload;
begin
  LPayload := TRpQueuedAgentsPayload(Message.WParam);
  try
    if LPayload = nil then
      Exit;
    ApplyLoadedUserAgents(LPayload.Agents, LPayload.SelectedTier,
      LPayload.SelectedAgentAiId, LPayload.ReloadVersion);
    LPayload.Agents := nil;
  finally
    LPayload.Free;
  end;
end;

procedure TFRpChatFrame.WMApplyLoadedSchemas(var Message: TMessage);
var
  LPayload: TRpQueuedSchemasPayload;
begin
  LPayload := TRpQueuedSchemasPayload(Message.WParam);
  try
    if LPayload = nil then
      Exit;
    ApplyLoadedSchemas(LPayload.Schemas, LPayload.ReloadVersion);
    LPayload.Schemas := nil;
  finally
    LPayload.Free;
  end;
end;

procedure TFRpChatFrame.ApplyLoadedUserAgents(
  ALoadedAgents: TStringList; const ASelectedTier: string;
  ASelectedAgentAiId: Int64; AReloadVersion: Integer);
var
  I: Integer;
  LAgentAiId: Int64;
  LAgentName: string;
  LAgentOnline: Boolean;
  LAgentSecret: string;
  LAgentValue: string;
  LParts: TStringList;
begin
  try
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
        LAgentName := ALoadedAgents.Names[I];
        LAgentValue := ALoadedAgents.ValueFromIndex[I];
        LParts.DelimitedText := LAgentValue;
        if LParts.Count >= 2 then
        begin
          LAgentAiId := StrToInt64Def(LParts[0], 0);
          LAgentSecret := LParts[1];
          LAgentOnline := (LParts.Count >= 3) and (LParts[2] = '1');
          if LAgentOnline then
            FAISelection.AddAgentEndpoint(LAgentAiId, LAgentSecret, LAgentName, True);
        end;
      end;
    finally
      LParts.Free;
    end;

    FAISelection.RestoreProviderSelection(ASelectedTier, ASelectedAgentAiId);
  finally
    ALoadedAgents.Free;
  end;
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
  // If we have a specific HubSchemaId, search for it first
  if FHubSchemaId <> 0 then
  begin
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
  end;

  // If no schema found yet but we have a connection ID, pick the first schema for that connection
  if (not LFound) and (FHubDatabaseId <> 0) then
  begin
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
  end;

  // Final fallback: pick the very first available schema if nothing else found
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
  LDisplayName: string;
  LValue: string;
  LParts: TStringList;
  LHubDatabaseId: Int64;
  LHubSchemaId: Int64;
  LApiKey: string;
begin
  try
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

        TRpAuthManager.Instance.Log(
          'ApplyLoadedSchemas: DisplayName=' + LDisplayName +
          ' RawValue=' + LValue +
          ' ParsedHubDatabaseId=' + IntToStr(LHubDatabaseId) +
          ' ParsedHubSchemaId=' + IntToStr(LHubSchemaId) +
          ' ApiKey=' + LApiKey);

        ComboSchema.Items.AddObject(LDisplayName,
          TSchemaComboItem.Create(LHubDatabaseId, LHubSchemaId, LApiKey));
      end;
      SelectCurrentSchema;
    finally
      LParts.Free;
      ComboSchema.Items.EndUpdate;
      FLoadingSchemas := False;
      ComboSchemaChange(ComboSchema);
      TRpAuthManager.Instance.Log(
        'ApplyLoadedSchemas: FinalItemIndex=' + IntToStr(ComboSchema.ItemIndex) +
        ' FinalHubDatabaseId=' + IntToStr(GetHubDatabaseId) +
        ' FinalHubSchemaId=' + IntToStr(GetHubSchemaId) +
        ' FinalApiKey=' + GetSchemaApiKey);
      UpdateButtons;
    end;
  finally
    ALoadedSchemas.Free;
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
      TRpAuthManager.Instance.Log(
        'ComboSchemaChange: ItemIndex=' + IntToStr(ComboSchema.ItemIndex) +
        ' HubDatabaseId=' + IntToStr(FHubDatabaseId) +
        ' HubSchemaId=' + IntToStr(FHubSchemaId) +
        ' ApiKey=' + FSchemaApiKey);
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

function TFRpChatFrame.GetDesignPrefillPercent(const AStage,
  AChunkType: string): Integer;
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

procedure TFRpChatFrame.PostDesignChatPayload(APayload: TObject);
begin
  if APayload = nil then
    Exit;
  if HandleAllocated then
    PostMessage(Handle, WM_USER + 208, WPARAM(APayload), 0)
  else
    APayload.Free;
end;

procedure TFRpChatFrame.DesignStreamProgress(Sender: TObject; const AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
var
  LPayload: TRpQueuedDesignChatPayload;
  LChunk: string;
begin
  LChunk := '';
  if Trim(AChunk) <> '' then
  begin
    if SameText(AStage, 'ReceivingResponse') then
      LChunk := AChunk
    else
      LChunk := '[' + AStage + '] ' + AChunk + sLineBreak;
  end;

  LPayload := TRpQueuedDesignChatPayload.Create;
  LPayload.Kind := rpqdcUpdateStreamingResponse;
  if Sender is TRpDesignChatStreamContext then
    LPayload.RequestVersion := TRpDesignChatStreamContext(Sender).RequestVersion;
  LPayload.Text1 := LChunk;
  LPayload.PrefillPercent := GetDesignPrefillPercent(AStage, AChunkType);
  LPayload.InputTokens := AInputTokens;
  LPayload.OutputTokens := AOutputTokens;
  PostDesignChatPayload(LPayload);
end;

function TFRpChatFrame.DesignStreamCancelRequested(Sender: TObject): Boolean;
begin
  Result := False;
  if Sender is TRpDesignChatStreamContext then
    Result := TRpDesignChatStreamContext(Sender).RequestVersion <> FDesignRequestVersion;
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
  
  if MemoLog.Lines.Count > 0 then
    MemoLog.Lines.Add('');
  MemoLog.Lines.Add('actor: Assistant');
  
  SetBusy(True);
  RebuildConversation;
end;

procedure TFRpChatFrame.ClearConversation;
begin
  FConversationBlocks.Clear;
  FLastAssistantMessage := '';
  MemoPrompt.Clear;
  MemoLog.Clear;
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := False;
  UpdateButtons;
  RebuildConversation;
end;

procedure TFRpChatFrame.FinishStreamingResponse;
begin
  FStreamingActive := False;
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  SetBusy(False);
  RebuildConversation;
end;

procedure TFRpChatFrame.Initialize(const ACurrentExpression,
  AInitialAssistantMessage: string);
begin
  FCurrentExpression := ACurrentExpression;
  FConversationBlocks.Clear;
  FLastAssistantMessage := '';
  MemoPrompt.Clear;
  MemoConversation.Clear;
  MemoLog.Clear;
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := False;
  SetBusy(False);
  RebuildConversation;
  if AInitialAssistantMessage <> '' then
    AddAssistantMessage(AInitialAssistantMessage);
end;

procedure TFRpChatFrame.StartDesignPrompt(const APrompt: string);
var
  LPreprocessRequest: TRpApiPreprocessSqlContextRequest;
  LRequest: TRpApiModifyReportRequest;
  LRequestVersion: Integer;
  LSelectedHubDatabaseId: Int64;
  LSelectedHubSchemaId: Int64;
  LWorker: TThread;
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

  Inc(FDesignRequestVersion);
  LRequestVersion := FDesignRequestVersion;
  LSelectedHubDatabaseId := GetHubDatabaseId;
  LSelectedHubSchemaId := GetHubSchemaId;
  BeginStreamingResponse;
  SetBusy(True);

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
      LHttp: TRpDatabaseHttp;
      LPayload: TRpQueuedDesignChatPayload;
      LPreprocessResponse: TRpApiPreprocessSqlContextResult;
      LPreprocessUserProfileJson: string;
      LResponse: TRpApiModifyReportResult;
      LStreamContext: TRpDesignChatStreamContext;
    begin
      LHttp := TRpDatabaseHttp.Create;
      LPreprocessResponse := nil;
      LPreprocessUserProfileJson := '';
      LResponse := nil;
      LStreamContext := TRpDesignChatStreamContext.Create;
      LStreamContext.RequestVersion := LRequestVersion;
      try
        try
          LHttp.Token := TRpAuthManager.Instance.Token;
          LHttp.InstallId := TRpAuthManager.Instance.InstallId;
          LHttp.AITier := RpAITierTypeToString(LRequest.AITier);
          LHttp.HubDatabaseId := LSelectedHubDatabaseId;
          LHttp.HubSchemaId := LSelectedHubSchemaId;
          LHttp.AgentSecret := LRequest.AgentSecret;
          if LRequest.HasAgentAiId then
            LHttp.AgentAiId := LRequest.AgentAiId;

          if LPreprocessRequest <> nil then
          begin
            LPreprocessResponse := LHttp.PreprocessSqlContext(LPreprocessRequest,
              LStreamContext, DesignStreamProgress, DesignStreamCancelRequested);

            if LRequestVersion <> FDesignRequestVersion then
              Exit;

            if (LPreprocessResponse <> nil) and
              (Trim(LPreprocessResponse.ErrorMessage) <> '') then
              raise Exception.Create(LPreprocessResponse.ErrorMessage);

            TThread.Synchronize(nil,
              procedure
              var
                LUpdatedRequest: TRpApiModifyReportRequest;
              begin
                if Assigned(FOnApplyPreprocessSqlContextResult) then
                  FOnApplyPreprocessSqlContextResult(Self, LPreprocessResponse);

                LUpdatedRequest := nil;
                try
                  LUpdatedRequest := FOnBuildDesignRequest(Self, APrompt);
                  if LUpdatedRequest <> nil then
                    LRequest.Assign(LUpdatedRequest)
                  else
                    LRequest.ReportDocument := '';
                finally
                  LUpdatedRequest.Free;
                end;
              end);

            if Trim(LRequest.ReportDocument) = '' then
              raise Exception.Create('Unable to serialize the current report to XML after preprocessing SQL context.');

            LPreprocessUserProfileJson := LPreprocessResponse.UserProfileJson;
          end;

          LResponse := LHttp.ModifyReport(LRequest, LStreamContext,
            DesignStreamProgress, DesignStreamCancelRequested);

          if LRequestVersion <> FDesignRequestVersion then
            Exit;

          if (LResponse <> nil) and (Trim(LResponse.ErrorMessage) <> '') then
          begin
            LPayload := TRpQueuedDesignChatPayload.Create;
            LPayload.Kind := rpqdcAddAssistantMessage;
            LPayload.RequestVersion := LRequestVersion;
            LPayload.Text1 := LResponse.ErrorMessage;
            PostDesignChatPayload(LPayload);
            Exit;
          end;

          if (LResponse <> nil) and Assigned(LResponse.ResultData) and
            (Trim(LResponse.ResultData.ErrorMessage) <> '') then
          begin
            LPayload := TRpQueuedDesignChatPayload.Create;
            LPayload.Kind := rpqdcAddAssistantMessage;
            LPayload.RequestVersion := LRequestVersion;
            LPayload.Text1 := LResponse.ResultData.ErrorMessage;
            PostDesignChatPayload(LPayload);
            Exit;
          end;

          LPayload := TRpQueuedDesignChatPayload.Create;
          LPayload.Kind := rpqdcApplyDesignResult;
          LPayload.RequestVersion := LRequestVersion;
          if LPreprocessResponse <> nil then
          begin
            for I := 0 to LPreprocessResponse.Steps.Count - 1 do
            begin
              if LPreprocessResponse.Steps[I] is TRpTokenUsage then
              begin
                Inc(LPayload.InputTokens,
                  TRpTokenUsage(LPreprocessResponse.Steps[I]).InputTokens);
                Inc(LPayload.OutputTokens,
                  TRpTokenUsage(LPreprocessResponse.Steps[I]).OutputTokens);
              end;
            end;
          end;
          if LResponse <> nil then
          begin
            if Assigned(LResponse.ResultData) then
            begin
              LPayload.Text1 := LResponse.ResultData.ModifiedReportDocument;
              LPayload.Text2 := LResponse.ResultData.Explanation;
            end;
            LPayload.UserProfileJson := LResponse.UserProfileJson;
            for I := 0 to LResponse.Steps.Count - 1 do
            begin
              if LResponse.Steps[I] is TRpTokenUsage then
              begin
                Inc(LPayload.InputTokens,
                  TRpTokenUsage(LResponse.Steps[I]).InputTokens);
                Inc(LPayload.OutputTokens,
                  TRpTokenUsage(LResponse.Steps[I]).OutputTokens);
              end;
            end;
          end;
          if Trim(LPayload.UserProfileJson) = '' then
            LPayload.UserProfileJson := LPreprocessUserProfileJson;
          PostDesignChatPayload(LPayload);
        except
          on E: Exception do
          begin
            LPayload := TRpQueuedDesignChatPayload.Create;
            LPayload.Kind := rpqdcAddAssistantMessage;
            LPayload.RequestVersion := LRequestVersion;
            LPayload.Text1 := E.Message;
            PostDesignChatPayload(LPayload);
          end;
        end;
      finally
        LPreprocessResponse.Free;
        LStreamContext.Free;
        LResponse.Free;
        LHttp.Free;
        LPreprocessRequest.Free;
        LRequest.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpChatFrame.StartOnlineInitialization;
var
  LNeedsSchemas: Boolean;
  LNeedsAgents: Boolean;
begin
  LNeedsSchemas := FShowSchemaSelector and (ComboSchema.Items.Count = 0);
  LNeedsAgents := (FAISelection <> nil) and (FAISelection.AgentEndpointCount = 0);

  if FOnlineInitializationQueued and not (LNeedsSchemas or LNeedsAgents) then
    Exit;

  FOnlineInitializationQueued := True;
  if LNeedsSchemas then
    LoadSchemas;
  if LNeedsAgents then
    LoadUserAgents;
  if FAISelection <> nil then
    FAISelection.RefreshStatusInBackground;
end;

procedure TFRpChatFrame.SetCurrentExpression(const AExpression: string);
begin
  FCurrentExpression := AExpression;
end;

procedure TFRpChatFrame.StopDesignPrompt;
begin
  Inc(FDesignRequestVersion);
  FinishStreamingResponse;
  SetBusy(False);
  AddAssistantMessage('Generation stopped.');
end;

procedure TFRpChatFrame.SetBusy(AValue: Boolean);
begin
  FBusy := AValue;
  if FAISelection <> nil then
    FAISelection.SetInferenceProgress(AValue);
  if FBusy then
    BClear.Caption := 'Stop'
  else
    BClear.Caption := 'Clear';
  UpdateButtons;
end;

procedure TFRpChatFrame.SetInferenceProgress(AValue: Boolean);
begin
  if FAISelection <> nil then
    FAISelection.SetInferenceProgress(AValue);
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
  if MemoLog = nil then
    Exit;
  MemoLog.Lines.Add(AText);
end;

procedure TFRpChatFrame.AppendLogChunk(const AChunk: string;
  AAppendLineBreak: Boolean);
begin
  if (MemoLog = nil) or (AChunk = '') then
    Exit;

  MemoLog.HandleNeeded;
  SendMessage(MemoLog.Handle, EM_SETSEL, WPARAM(MAXINT), LPARAM(MAXINT));
  SendMessage(MemoLog.Handle, EM_REPLACESEL, 0, NativeInt(PChar(AChunk)));
  if AAppendLineBreak then
    MemoLog.Lines.Add('');
end;

procedure TFRpChatFrame.UpdateStreamingTokens(AInTokens, AOutTokens: Integer);
begin
  if FAISelection <> nil then
    FAISelection.UpdateTokens(AInTokens, AOutTokens);
end;

procedure TFRpChatFrame.SetSuggestedContent(const AContent, AMessage,
  ACaptionLabel: string);
begin
  FinishStreamingResponse;
  FSuggestedExpression := AContent;
  if AMessage <> '' then
    AddAssistantMessage(AMessage + sLineBreak + sLineBreak + ACaptionLabel + ':' + sLineBreak + AContent)
  else
    AddAssistantMessage(ACaptionLabel + ':' + sLineBreak + AContent);
  UpdateButtons;
end;

procedure TFRpChatFrame.SetRefreshAction(AValue: Boolean);
begin
  FUseRefreshAction := AValue;
  if FUseRefreshAction then
    BApply.Caption := 'Refresh'
  else
    BApply.Caption := 'Apply';
  UpdateButtons;
end;

procedure TFRpChatFrame.SetSuggestedExpression(const AExpression, AMessage: string);
begin
  SetSuggestedContent(AExpression, AMessage, 'Suggested expression');
end;

procedure TFRpChatFrame.UpdateButtons;
begin
  BSend.Enabled := (not FBusy) and (Trim(MemoPrompt.Text) <> '');
  if FUseRefreshAction then
    BApply.Enabled := (not FBusy) and Assigned(FOnRefreshContext)
  else
    BApply.Enabled := (not FBusy) and (Trim(FSuggestedExpression) <> '');
  if BReportAI <> nil then
    BReportAI.Enabled := (not FBusy) and (Trim(FLastAssistantMessage) <> '');
  BRefreshSchemas.Enabled := not FLoadingSchemas;
  if FLoadingSchemas then
    BRefreshSchemas.Caption := '...'
  else
    BRefreshSchemas.Caption := 'Refresh';
end;

procedure TFRpChatFrame.UpdateStreamingResponse(const AChunk: string;
  APrefillPercent: Integer);
begin
  if not FStreamingActive then
    BeginStreamingResponse;
  if APrefillPercent > FStreamingPrefillPercent then
    FStreamingPrefillPercent := APrefillPercent;
  if AChunk <> '' then
  begin
    FStreamingText := FStreamingText + AChunk;
    if MemoLog <> nil then
    begin
      MemoLog.HandleNeeded;
      SendMessage(MemoLog.Handle, EM_SETSEL, WPARAM(MAXINT), LPARAM(MAXINT));
      SendMessage(MemoLog.Handle, EM_REPLACESEL, 0, NativeInt(PChar(AChunk)));
    end;
  end;
  RebuildConversation;
end;

procedure TFRpChatFrame.UpdateUserProfile(AProfile: TJSONObject);
begin
  if (FAISelection <> nil) and (AProfile <> nil) then
    FAISelection.UpdateFromUserProfile(AProfile);
end;

procedure TFRpChatFrame.WMHandleDesignChatPayload(var Message: TMessage);
var
  LPayload: TRpQueuedDesignChatPayload;
  LMessage: string;
  LProfile: TJSONObject;
begin
  LPayload := TRpQueuedDesignChatPayload(Message.WParam);
  try
    if LPayload = nil then
      Exit;
    if LPayload.RequestVersion <> FDesignRequestVersion then
      Exit;

    case LPayload.Kind of
      rpqdcUpdateStreamingResponse:
        begin
          UpdateStreamingResponse(LPayload.Text1, LPayload.PrefillPercent);
          UpdateStreamingTokens(LPayload.InputTokens, LPayload.OutputTokens);
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
      LProfile := TJSONObject.ParseJSONValue(LPayload.UserProfileJson) as TJSONObject;
      try
        if LProfile <> nil then
          UpdateUserProfile(LProfile);
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
            AddAssistantMessage('The server returned a modified report, but it could not be loaded: ' + E.Message);
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
        LMessage := 'Report updated.'
      else
        LMessage := 'No report changes were returned.';
    end;

    AddAssistantMessage(LMessage);
  finally
    LPayload.Free;
  end;
end;

function TFRpChatFrame.GetAITier: string;
begin
  Result := FAISelection.AITier;
end;

function TFRpChatFrame.GetAIMode: string;
begin
  Result := FAISelection.AIMode;
end;

function TFRpChatFrame.GetAgentSecret: string;
begin
  Result := FAISelection.AgentSecret;
end;

function TFRpChatFrame.GetAgentAiId: Int64;
begin
  Result := FAISelection.AgentAiId;
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
    AddAssistantMessage('Chat UI is ready, but no AI handler is connected yet.');
end;

procedure TFRpChatFrame.MemoPromptChange(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TFRpChatFrame.MemoPromptKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
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
  begin
    AISelectionStopRequest(Self);
  end
  else
    ClearConversation;
end;

procedure TFRpChatFrame.BClearLogClick(Sender: TObject);
begin
  if MemoLog <> nil then
    MemoLog.Clear;
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
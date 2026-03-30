unit rpfrmexpressionchatvcl;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, System.JSON,
  rpauthmanager, rpfrmaiselectionvcl, rpfrmloginframevcl, rpdatahttp;

type
  TExpressionChatSendEvent = procedure(Sender: TObject; const APrompt, AExpression: string) of object;
  TExpressionChatApplyEvent = procedure(Sender: TObject; const AExpression: string) of object;
  TExpressionChatStopEvent = procedure(Sender: TObject) of object;

  TRpQueuedAgentsPayload = class(TObject)
  public
    Agents: TStringList;
    SelectedTier: string;
    SelectedAgentAiId: Int64;
    ReloadVersion: Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TFRpExpressionChatFrame = class(TFrame)
    PRoot: TPanel;
    PTop: TPanel;
    GridTop: TGridPanel;
    PLoginHost: TPanel;
    PAISelectionHost: TPanel;
    MemoConversation: TMemo;
    PBottom: TPanel;
    MemoPrompt: TMemo;
    PButtons: TPanel;
    BSend: TButton;
    BApply: TButton;
    BClear: TButton;
    procedure BApplyClick(Sender: TObject);
    procedure BClearClick(Sender: TObject);
    procedure BSendClick(Sender: TObject);
    procedure MemoPromptChange(Sender: TObject);
    procedure MemoPromptKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    FAISelection: TFRpAISelectionVCL;
    FBusy: Boolean;
    FConversationBlocks: TStringList;
    FCurrentExpression: string;
    FLoginFrame: TFRpLoginFrameVCL;
    FOnApplySuggestion: TExpressionChatApplyEvent;
    FOnSendPrompt: TExpressionChatSendEvent;
    FOnStopRequest: TExpressionChatStopEvent;
    FSuggestedExpression: string;
    FStreamingActive: Boolean;
    FStreamingPrefillPercent: Integer;
    FStreamingText: string;
    FOnlineInitializationQueued: Boolean;
    FUserAgentsReloadVersion: Integer;
    procedure WMApplyLoadedUserAgents(var Message: TMessage); message WM_USER + 202;
    procedure ApplyLoadedUserAgents(ALoadedAgents: TStringList;
      const ASelectedTier: string; ASelectedAgentAiId: Int64;
      AReloadVersion: Integer);
    procedure AuthChanged(ASuccess: Boolean);
    procedure AppendMessage(const ATitle, AText: string);
    procedure LoadUserAgents;
    procedure RebuildConversation;
    procedure UpdateButtons;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddAssistantMessage(const AText: string);
    procedure AddUserMessage(const AText: string);
    procedure BeginStreamingResponse;
    procedure ClearConversation;
    procedure FinishStreamingResponse;
    procedure Initialize(const ACurrentExpression, AInitialAssistantMessage: string);
    procedure StartOnlineInitialization;
    procedure SetCurrentExpression(const AExpression: string);
    procedure SetBusy(AValue: Boolean);
    procedure SetSuggestedExpression(const AExpression, AMessage: string);
    procedure UpdateStreamingResponse(const AChunk: string; APrefillPercent: Integer);
    procedure UpdateUserProfile(AProfile: TJSONObject);
    function GetAITier: string;
    function GetAIMode: string;
    function GetAgentSecret: string;
    function GetAgentAiId: Int64;
  published
    property OnApplySuggestion: TExpressionChatApplyEvent read FOnApplySuggestion write FOnApplySuggestion;
    property OnSendPrompt: TExpressionChatSendEvent read FOnSendPrompt write FOnSendPrompt;
    property OnStopRequest: TExpressionChatStopEvent read FOnStopRequest write FOnStopRequest;
  end;

implementation

{$R *.dfm}

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

constructor TFRpExpressionChatFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConversationBlocks := TStringList.Create;
  FLoginFrame := TFRpLoginFrameVCL.Create(Self);
  FLoginFrame.Parent := PLoginHost;
  FLoginFrame.Align := alClient;

  FAISelection := TFRpAISelectionVCL.Create(Self);
  FAISelection.Parent := PAISelectionHost;
  FAISelection.Align := alClient;
  FAISelection.Constraints.MinHeight := 50;
  FAISelection.Constraints.MaxHeight := 50;

  TRpAuthManager.Instance.RegisterAuthListener(AuthChanged);

  MemoConversation.Clear;
  MemoPrompt.Clear;
  FBusy := False;
  FSuggestedExpression := '';
  FStreamingActive := False;
  FStreamingPrefillPercent := 0;
  FStreamingText := '';
  FOnlineInitializationQueued := False;
  FUserAgentsReloadVersion := 0;
  MemoPrompt.OnKeyDown := MemoPromptKeyDown;
  Initialize('', '');
end;

destructor TFRpExpressionChatFrame.Destroy;
begin
  FConversationBlocks.Free;
  TRpAuthManager.Instance.UnregisterAuthListener(AuthChanged);
  inherited Destroy;
end;

procedure TFRpExpressionChatFrame.AuthChanged(ASuccess: Boolean);
begin
  if FAISelection <> nil then
  begin
    FAISelection.RefreshState;
    LoadUserAgents;
  end;
end;

procedure TFRpExpressionChatFrame.AppendMessage(const ATitle, AText: string);
begin
  FConversationBlocks.Add(ATitle + sLineBreak + AText);
  RebuildConversation;
end;

procedure TFRpExpressionChatFrame.RebuildConversation;
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
  MemoConversation.SelStart := Length(MemoConversation.Text);
end;

procedure TFRpExpressionChatFrame.LoadUserAgents;
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

procedure TFRpExpressionChatFrame.WMApplyLoadedUserAgents(var Message: TMessage);
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

procedure TFRpExpressionChatFrame.ApplyLoadedUserAgents(
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

procedure TFRpExpressionChatFrame.AddAssistantMessage(const AText: string);
begin
  AppendMessage('Assistant', AText);
end;

procedure TFRpExpressionChatFrame.AddUserMessage(const AText: string);
begin
  AppendMessage('You', AText);
end;

procedure TFRpExpressionChatFrame.BeginStreamingResponse;
begin
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := True;
  SetBusy(True);
  RebuildConversation;
end;

procedure TFRpExpressionChatFrame.ClearConversation;
begin
  FConversationBlocks.Clear;
  MemoPrompt.Clear;
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := False;
  UpdateButtons;
  RebuildConversation;
end;

procedure TFRpExpressionChatFrame.FinishStreamingResponse;
begin
  FStreamingActive := False;
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  SetBusy(False);
  RebuildConversation;
end;

procedure TFRpExpressionChatFrame.Initialize(const ACurrentExpression,
  AInitialAssistantMessage: string);
begin
  FCurrentExpression := ACurrentExpression;
  FConversationBlocks.Clear;
  MemoPrompt.Clear;
  MemoConversation.Clear;
  FSuggestedExpression := '';
  FStreamingText := '';
  FStreamingPrefillPercent := 0;
  FStreamingActive := False;
  SetBusy(False);
  RebuildConversation;
  if AInitialAssistantMessage <> '' then
    AddAssistantMessage(AInitialAssistantMessage);
end;

procedure TFRpExpressionChatFrame.StartOnlineInitialization;
begin
  if FOnlineInitializationQueued then
    Exit;

  FOnlineInitializationQueued := True;
  LoadUserAgents;
  if FAISelection <> nil then
    FAISelection.RefreshStatusInBackground;
end;

procedure TFRpExpressionChatFrame.SetCurrentExpression(const AExpression: string);
begin
  FCurrentExpression := AExpression;
end;

procedure TFRpExpressionChatFrame.SetBusy(AValue: Boolean);
begin
  FBusy := AValue;
  if FBusy then
    BClear.Caption := 'Stop'
  else
    BClear.Caption := 'Clear';
  UpdateButtons;
end;

procedure TFRpExpressionChatFrame.SetSuggestedExpression(const AExpression, AMessage: string);
begin
  FinishStreamingResponse;
  FSuggestedExpression := AExpression;
  if AMessage <> '' then
    AddAssistantMessage(AMessage + sLineBreak + sLineBreak + 'Suggested expression:' + sLineBreak + AExpression)
  else
    AddAssistantMessage('Suggested expression:' + sLineBreak + AExpression);
  UpdateButtons;
end;

procedure TFRpExpressionChatFrame.UpdateButtons;
begin
  BSend.Enabled := (not FBusy) and (Trim(MemoPrompt.Text) <> '');
  BApply.Enabled := (not FBusy) and (Trim(FSuggestedExpression) <> '');
end;

procedure TFRpExpressionChatFrame.UpdateStreamingResponse(const AChunk: string;
  APrefillPercent: Integer);
begin
  if not FStreamingActive then
    BeginStreamingResponse;
  if APrefillPercent > FStreamingPrefillPercent then
    FStreamingPrefillPercent := APrefillPercent;
  if AChunk <> '' then
    FStreamingText := FStreamingText + AChunk;
  RebuildConversation;
end;

procedure TFRpExpressionChatFrame.UpdateUserProfile(AProfile: TJSONObject);
begin
  if (FAISelection <> nil) and (AProfile <> nil) then
    FAISelection.UpdateFromUserProfile(AProfile);
end;

function TFRpExpressionChatFrame.GetAITier: string;
begin
  Result := FAISelection.AITier;
end;

function TFRpExpressionChatFrame.GetAIMode: string;
begin
  Result := FAISelection.AIMode;
end;

function TFRpExpressionChatFrame.GetAgentSecret: string;
begin
  Result := FAISelection.AgentSecret;
end;

function TFRpExpressionChatFrame.GetAgentAiId: Int64;
begin
  Result := FAISelection.AgentAiId;
end;

procedure TFRpExpressionChatFrame.BSendClick(Sender: TObject);
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

  if Assigned(FOnSendPrompt) then
    FOnSendPrompt(Self, LPrompt, FCurrentExpression)
  else
    AddAssistantMessage('Chat UI is ready, but no AI handler is connected yet.');
end;

procedure TFRpExpressionChatFrame.MemoPromptChange(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TFRpExpressionChatFrame.MemoPromptKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    if (not FBusy) and (Trim(MemoPrompt.Text) <> '') then
      BSendClick(Self);
  end;
end;

procedure TFRpExpressionChatFrame.BApplyClick(Sender: TObject);
begin
  if Trim(FSuggestedExpression) = '' then
    Exit;

  if Assigned(FOnApplySuggestion) then
    FOnApplySuggestion(Self, FSuggestedExpression);
end;

procedure TFRpExpressionChatFrame.BClearClick(Sender: TObject);
begin
  if FBusy then
  begin
    if Assigned(FOnStopRequest) then
      FOnStopRequest(Self);
  end
  else
    ClearConversation;
end;

end.
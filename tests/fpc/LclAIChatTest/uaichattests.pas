{ Phase 7.2 tests: the LCL foundation of the AI assistants against a local
  fake Hub (no external network). HUB_API_URL is rewritten to the fake Hub
  (RpHttpSetUrlRewrite) and the OAuth browser is simulated (RpOpenUrlHook).

  Covers the Markdown converter and the native viewer, the account card and
  the login dialog, the model selection, the schema selectors, the chat
  frame (a design request streamed by the frame itself, stop in the middle,
  busy/progress state, a host streaming through its own mailbox as the SQL
  and expression assistants will do), the AI report dialog, the chat panel
  of the main designer window and, on Windows, the WebView2 viewer. }
unit uaichattests;

{$mode delphi}{$H+}
{$modeswitch nestedprocvars}

interface

// AShotsDir: screenshots are saved there when not empty
procedure RunAIChatTests(const AShotsDir: string);

implementation

uses
  SysUtils, Classes, Types, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Menus, ComCtrls, LCLType, LCLIntf, IntfGraphics, FPImage, fphttpserver, httpdefs,
  rpjsonfpc, rphttpclientfpc, rptypes, rpdatainfo, rpdatahttp, rpauthmanager,
  rpreportdesignercontracts, rpaithreadslcl, rpmarkdownlcl, rpwebmarkdownlcl,
  rpchatmodernstylelcl, rpfrmloginframelcl, rpfrmloginlcl, rpfrmaiselectionlcl,
  rpfrmaischemaselectorlcl, rpfrmaireportlcl, rpfrmchatlcl, rpmdfmainlcl,
  rplclwebview, rpmdconsts, utestutil, ufakeserver;

const
  BS = #92; // backslash: no tool turns \u escapes into characters
  // UTF-8 of the non ASCII letters used by the tests
  U_NTILDE_UP = #$C3#$91;  // N with tilde
  U_NTILDE = #$C3#$B1;
  U_UACUTE = #$C3#$BA;

type
  TCondition = function: Boolean is nested;

  { TFakeHub: canned answers of the Hub endpoints }

  TFakeHub = class
  public
    ModifyCalls: Integer;
    SlowStarted: Boolean;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
  end;

  { Host streaming messages (as the SQL/expression hosts will use them) }

  THostStreamMessage = class(TRpAsyncMessage)
  public
    Kind: Integer; // 0 progress, 1 result, 2 error
    Actor, ChunkType, Chunk, ProgressId: string;
    InTokens, OutTokens, Prefill: Integer;
    Expression, Explanation: string;
  end;

  THostStreamWorker = class(TRpAsyncWorker)
  public
    Prompt: string;
    Token, InstallId: string;
    ResultExpression: string;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
    procedure Progress(Sender: TObject; const AActor, AStage, AChunkType,
      AChunk: string; AInputTokens, AOutputTokens: Integer;
      const AProgressId: string; APrefillPercent: Integer);
    procedure ResultArrived(Sender: TObject; AResultJson: TJSONObject;
      const AErrorMessage: string);
    function CancelAsked(Sender: TObject): Boolean;
  end;

  { TAIChatTests }

  TAIChatTests = class
  private
    FShotsDir: string;
    FHub: TFakeServer;
    FHubHandler: TFakeHub;
    FTimer: TTimer;
    FStep: Integer;
    FStepStart: QWord;
    FDialog: TForm;
    FDialogResult: Integer;
    // Chat events
    FApplied: string;
    FApplyCount: Integer;
    FInferenceBegin: Integer;
    FInferenceEnd: Integer;
    FStopCount: Integer;
    FSuggestion: string;
    FAuthChanged: Integer;
    FSchemaChanged: Integer;
    FHostChat: TFRpChatFrame;
    FHostMailbox: TRpAsyncMailbox;
    FHostMailboxRef: IRpAsyncMailbox;
    FWebDump: string;
    FScript: TNotifyEvent;
    FInScript: Boolean;
    // Chat frame whose state is printed when a wait times out
    FDiagChat: TFRpChatFrame;
    procedure WebMessage(Sender: TObject; const AMessage: string);
    // Runs FScript from the timer, never nested (Shot processes messages)
    procedure ScriptTick(Sender: TObject);
    procedure StartScript(AScript: TNotifyEvent);
    procedure StopScript;
    procedure WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal; const AWhat: string);
    procedure Pump(AMs: Cardinal);
    function NewForm(AWidth, AHeight: Integer): TForm;
    procedure Shot(AControl: TWinControl; const AName: string);
    procedure ScreenShot(AControl: TWinControl; const AName: string);
    function PixelsWithColor(AControl: TWinControl; AColor: TColor): Integer;
    procedure LoginWithCode;
    // Events
    function BuildDesignRequest(Sender: TObject; const APrompt: string): TRpApiModifyReportRequest;
    procedure ApplyDesignResult(Sender: TObject; const AModifiedReportDocument: string);
    procedure InferenceBegin(Sender: TObject);
    procedure InferenceEnd(Sender: TObject);
    procedure StopRequest(Sender: TObject);
    procedure ApplySuggestion(Sender: TObject; const AExpression: string);
    procedure HostSendPrompt(Sender: TObject; const APrompt, AExpression: string);
    procedure HostMessage(AMessage: TRpAsyncMessage);
    procedure LoginFrameAuthChanged(Sender: TObject);
    procedure SchemaChanged(Sender: TObject);
    procedure LoginDialogScript(Sender: TObject);
    procedure OAuthDialogScript(Sender: TObject);
    procedure ReportDialogScript(Sender: TObject);
    // Tests
    procedure TestMarkdown;
    procedure TestNativeViewer;
    procedure TestLoginFrame;
    procedure TestLoginDialog;
    procedure TestOAuthDialog;
    procedure TestAISelection;
    procedure TestSchemaSelector;
    procedure TestChatOnline;
    procedure TestChatDesignStream;
    procedure TestChatStop;
    procedure TestChatHostStream;
    procedure TestChatProgressAndMisc;
    procedure TestReportDialog;
    procedure TestMainForm;
    procedure TestWebView2;
    procedure Screenshots;
  public
    constructor Create(const AShotsDir: string);
    destructor Destroy; override;
    procedure Run;
  end;

var
  GHubBaseUrl: string;

{ Fake Hub }

function ProfileJson(const ATierName: string): string;
begin
  Result := '{"userId":7,"email":"ana@example.com","userName":"Ana ' + BS + 'u00d1",' +
    '"profileImageUrl":"","accountType":1,"tierId":4,' +
    '"tierName":"' + ATierName + '","dailyMax":1000,"dailyConsumed":250,"freeInitial":100,' +
    '"freeRemaining":40,"serverDay":"2026-09-27T00:00:00Z","credits":5}';
end;

function TiersJson: string;
begin
  Result := '[{"id":1,"name":"Free","monthlyPrice":0,"yearlyPrice":0,"maxCreditsDay":10,' +
    '"maxFreeCredits":100,"maxConnections":1,"maxTables":10,"maxColumnsPerTable":20,"maxKpis":1}]';
end;

function LoginJson(const AToken: string): string;
begin
  Result := '{"token":"' + AToken + '","profile":' + ProfileJson('Pro') + ',"tiers":' + TiersJson + '}';
end;

function ProgressEvent(const AChunkType, AChunk, AId: string): string;
begin
  Result := '{"actor":"AI","stage":"ReceivingResponse","chunkType":"' + AChunkType +
    '","chunk":"' + AChunk + '","id":"' + AId + '","inputTokens":120,"outputTokens":7,' +
    '"prefillPercentage":0}';
end;

function ModifyResultJson: string;
begin
  Result := '{"result":{"contextJson":"{}","operationsJson":"[]",' +
    '"modifiedReportDocument":"<report/>","explanation":"Hecho ' + BS + 'u00f1: **title** added",' +
    '"errorMessage":"","reportFormat":"Xml","success":true},' +
    '"steps":[{"inputTokens":10,"modelName":"m1","outputTokens":20,"thinkingTokens":5}],' +
    '"creditsConsumed":42,"debugDetails":"","errorMessage":"",' +
    '"userProfile":{"userId":7,"email":"ana@example.com","tierName":"Pro","tierId":4,' +
    '"dailyMax":1000,"dailyConsumed":300}}';
end;

function BodyJson(ARequest: TFPHTTPConnectionRequest): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(ARequest.Content);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue)
  else
  begin
    LValue.Free;
    Result := TJSONObject.Create;
  end;
end;

function JsonText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AName);
  if LValue = nil then
    Result := ''
  else
    Result := LValue.Value;
end;

procedure TFakeHub.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P, LApiKey: string;
  LBody: TJSONObject;
  LEvents: array of string;
  I: Integer;
begin
  P := ARequest.PathInfo;
  LBody := BodyJson(ARequest);
  try
    if P = '/api/userprofile/status' then
    begin
      if Pos('Bearer tok', ARequest.Authorization) = 1 then
        SendJson(AResponse, 200, '{"profile":' + ProfileJson('Pro') + ',"tiers":' + TiersJson + '}')
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/LoginResend/send' then
      SendJson(AResponse, 200, '{}')
    else if P = '/api/Login/email' then
    begin
      if JsonText(LBody, 'emailCode') = '123456' then
        SendJson(AResponse, 200, LoginJson('tok123'))
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/Login/google' then
    begin
      if JsonText(LBody, 'code') = 'gcode 1' then
        SendJson(AResponse, 200, LoginJson('tokG'))
      else
        SendJson(AResponse, 400, '{"error":"bad code"}');
    end
    else if P = '/api/agent/databases' then
    begin
      // Answers depend on the credentials, so that the connections of the
      // machine (other API keys) never change the result
      LApiKey := ARequest.CustomHeaders.Values['X-Reportman-ApiKey'];
      if LApiKey = 'test-key' then
        SendJson(AResponse, 200, '{"databases":[' +
          '{"displayName":"Stock","name":"stock","hubDatabaseId":78,"hubSchemaId":6},' +
          '{"displayName":"Sales - Main","name":"sales","hubDatabaseId":77,"hubSchemaId":5}],' +
          '"aiEndpoints":[]}')
      else if (LApiKey = '') and (Pos('Bearer tok', ARequest.Authorization) = 1) then
        SendJson(AResponse, 200, '{"databases":[' +
          '{"displayName":"Sales - Main","name":"sales","hubDatabaseId":77,"hubSchemaId":5},' +
          '{"displayName":"HR","name":"hr","hubDatabaseId":79,"hubSchemaId":7}],' +
          '"aiEndpoints":[{"id":3,"name":"Local","agentName":"pc1","agentSecret":"s3","isOnline":true},' +
          '{"id":4,"name":"Cloud","agentName":"srv","agentSecret":"s4","isOnline":false}]}')
      else
        SendJson(AResponse, 200, '{"databases":[],"aiEndpoints":[]}');
    end
    else if P = '/ReportDesigner/ModifyReportStream' then
    begin
      Inc(ModifyCalls);
      if Pos('slow', ARequest.Content) > 0 then
      begin
        SlowStarted := True;
        SetLength(LEvents, 60);
        for I := 0 to High(LEvents) do
          LEvents[I] := ProgressEvent('Partial', 'x' + IntToStr(I) + ' ', 's1');
        SendEvents(AResponse, LEvents, 100, True, True);
      end
      else
      begin
        SetLength(LEvents, 5);
        LEvents[0] := '{"actor":"Designer","stage":"Planning","chunk":"Planning the change"}';
        LEvents[1] := ProgressEvent('Partial', '<rep', 'd1');
        LEvents[2] := ProgressEvent('Partial', 'ort/>', 'd1');
        LEvents[3] := ProgressEvent('End', '', 'd1');
        LEvents[4] := ModifyResultJson;
        SendEvents(AResponse, LEvents, 30, True, True);
      end;
    end
    else if P = '/ReportmanExpression/SuggestExpressionStream' then
    begin
      SetLength(LEvents, 3);
      LEvents[0] := ProgressEvent('Partial', 'SUM(', 'e1');
      LEvents[1] := ProgressEvent('End', 'CLIENTS.BALANCE)', 'e1');
      LEvents[2] := '{"result":{"expression":"SUM(CLIENTS.BALANCE)","explanation":"Uno ' + BS +
        'u00fa"},"errorMessage":""}';
      SendEvents(AResponse, LEvents, 30, True, True);
    end
    else if P = '/api/aireport' then
      SendJson(AResponse, 200, '{}')
    else if P = '/api/Tiers' then
      SendJson(AResponse, 200, TiersJson)
    else
      SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
  finally
    LBody.Free;
  end;
end;

{ Simulated browser of the OAuth login }

type
  TRedirectThread = class(TThread)
  public
    Url: string;
  protected
    procedure Execute; override;
  end;

var
  GRedirect: TRedirectThread;

procedure TRedirectThread.Execute;
var
  LClient: TNetHTTPClient;
  LTry: Integer;
begin
  // The login opens the browser before it listens on the loopback port:
  // retry while the port refuses connections (busy machines)
  LClient := TNetHTTPClient.Create(nil);
  try
    for LTry := 1 to 100 do
    begin
      Sleep(200);
      try
        LClient.Get(Url);
        Break;
      except
      end;
    end;
  finally
    LClient.Free;
  end;
end;

function QueryValue(const AURL, AName: string): string;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.Delimiter := '&';
    LList.StrictDelimiter := True;
    LList.DelimitedText := Copy(AURL, Pos('?', AURL) + 1, MaxInt);
    Result := LList.Values[AName];
  finally
    LList.Free;
  end;
end;

function DecodeUrl(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '%') and (I + 2 <= Length(S)) then
    begin
      Result := Result + Chr(StrToInt('$' + Copy(S, I + 1, 2)));
      Inc(I, 3);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

function FakeBrowser(const AURL: string): Boolean;
var
  LRedirectUri: string;
begin
  // Every other URL (price plans, schema configuration...) is swallowed
  Result := True;
  if Pos('accounts.google.com', AURL) = 0 then
    Exit;
  LRedirectUri := DecodeUrl(QueryValue(AURL, 'redirect_uri'));
  if GRedirect <> nil then
  begin
    GRedirect.WaitFor;
    FreeAndNil(GRedirect);
  end;
  GRedirect := TRedirectThread.Create(True);
  GRedirect.Url := LRedirectUri + '?code=gcode%201&state=' + QueryValue(AURL, 'state');
  GRedirect.Start;
end;

{ THostStreamWorker }

procedure THostStreamWorker.Progress(Sender: TObject; const AActor, AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer;
  const AProgressId: string; APrefillPercent: Integer);
var
  LMsg: THostStreamMessage;
begin
  LMsg := THostStreamMessage.Create;
  LMsg.Kind := 0;
  LMsg.Actor := AActor;
  LMsg.ChunkType := AChunkType;
  LMsg.Chunk := AChunk;
  LMsg.ProgressId := AProgressId;
  LMsg.InTokens := AInputTokens;
  LMsg.OutTokens := AOutputTokens;
  LMsg.Prefill := APrefillPercent;
  Post(LMsg);
end;

procedure THostStreamWorker.ResultArrived(Sender: TObject; AResultJson: TJSONObject;
  const AErrorMessage: string);
var
  LValue: TJSONValue;
begin
  if AResultJson = nil then
    Exit;
  try
    LValue := AResultJson.FindValue('result.expression');
    if LValue <> nil then
      ResultExpression := LValue.Value;
  finally
    AResultJson.Free;
  end;
end;

function THostStreamWorker.CancelAsked(Sender: TObject): Boolean;
begin
  Result := OwnerGone;
end;

procedure THostStreamWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LMsg: THostStreamMessage;
begin
  LHttp := TRpDatabaseHttp.Create;
  try
    LHttp.Token := Token;
    LHttp.InstallId := InstallId;
    LHttp.SuggestExpressionStream(Prompt, '', 0, 'Fast', False, '{}', Self,
      Progress, ResultArrived, CancelAsked);
    LMsg := THostStreamMessage.Create;
    LMsg.Kind := 1;
    LMsg.Expression := ResultExpression;
    LMsg.Explanation := 'Expression generated.';
    Post(LMsg);
  finally
    LHttp.Free;
  end;
end;

procedure THostStreamWorker.HandleError(E: Exception);
var
  LMsg: THostStreamMessage;
begin
  LMsg := THostStreamMessage.Create;
  LMsg.Kind := 2;
  LMsg.Explanation := E.Message;
  Post(LMsg);
end;

{ TAIChatTests }

constructor TAIChatTests.Create(const AShotsDir: string);
begin
  inherited Create;
  FShotsDir := AShotsDir;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 40;
end;

destructor TAIChatTests.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TAIChatTests.Pump(AMs: Cardinal);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  repeat
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  until GetTickCount64 - LStart >= AMs;
end;

procedure TAIChatTests.WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
  const AWhat: string);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  while not ACondition() do
  begin
    if GetTickCount64 - LStart > ATimeoutMs then
    begin
      if FDiagChat <> nil then
      begin
        Log('  diag: busy=' + BoolToStr(FDiagChat.Busy, True) + ' loadingSchemas=' +
          BoolToStr(FDiagChat.LoadingSchemas, True) + ' schemas=' +
          IntToStr(FDiagChat.ComboSchema.Items.Count) + ' agents=' +
          IntToStr(FDiagChat.AISelection.AgentEndpointCount) + ' workers=' +
          IntToStr(RpAsyncActiveWorkers));
        Log('  diag net log:' + LineEnding + FDiagChat.NetLogView.PlainText);
        Log('  diag AI log:' + LineEnding + FDiagChat.LogView.PlainText);
        Log('  diag chat:' + LineEnding + FDiagChat.ConversationText);
      end;
      Fail('timeout waiting for ' + AWhat);
    end;
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  end;
  Pass(AWhat);
end;

function TAIChatTests.NewForm(AWidth, AHeight: Integer): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.SetBounds(40, 40, AWidth, AHeight);
  Result.Position := poDesigned;
  Result.Caption := 'LclAIChatTest';
end;

procedure TAIChatTests.Shot(AControl: TWinControl; const AName: string);
var
  LBitmap: TBitmap;
  LPng: TPortableNetworkGraphic;
begin
  if FShotsDir = '' then
    Exit;
  Pump(150);
  LBitmap := TBitmap.Create;
  LPng := TPortableNetworkGraphic.Create;
  try
    LBitmap.SetSize(AControl.Width, AControl.Height);
    LBitmap.Canvas.Brush.Color := clWhite;
    LBitmap.Canvas.FillRect(Rect(0, 0, LBitmap.Width, LBitmap.Height));
    AControl.PaintTo(LBitmap.Canvas, 0, 0);
    LPng.Assign(LBitmap);
    LPng.SaveToFile(IncludeTrailingPathDelimiter(FShotsDir) + AName + '.png');
    Log('  screenshot ' + AName + '.png');
  finally
    LPng.Free;
    LBitmap.Free;
  end;
end;

procedure TAIChatTests.ScreenShot(AControl: TWinControl; const AName: string);
var
  LBitmap: TBitmap;
  LPng, LWebPng: TPortableNetworkGraphic;
  LStream: TMemoryStream;

  procedure PasteWebViews(AParent: TWinControl);
  var
    I: Integer;
    LWeb: TRpLCLWebView;
    P: TPoint;
  begin
    for I := 0 to AParent.ControlCount - 1 do
    begin
      if not (AParent.Controls[I] is TWinControl) then
        Continue;
      if (AParent.Controls[I] is TRpLCLWebView) and AParent.Controls[I].IsVisible then
      begin
        LWeb := TRpLCLWebView(AParent.Controls[I]);
        LStream.Clear;
        if LWeb.CapturePreviewPng(LStream) and (LStream.Size > 0) then
        begin
          LStream.Position := 0;
          LWebPng.LoadFromStream(LStream);
          P := AControl.ScreenToClient(LWeb.ClientToScreen(Point(0, 0)));
          LBitmap.Canvas.StretchDraw(Rect(P.X, P.Y, P.X + LWeb.Width, P.Y + LWeb.Height), LWebPng);
        end;
      end
      else
        PasteWebViews(TWinControl(AParent.Controls[I]));
    end;
  end;

begin
  // PaintTo does not paint the WebView2 windows: their CapturePreview is
  // drawn over them
  if FShotsDir = '' then
    Exit;
  Pump(300);
  LBitmap := TBitmap.Create;
  LPng := TPortableNetworkGraphic.Create;
  LWebPng := TPortableNetworkGraphic.Create;
  LStream := TMemoryStream.Create;
  try
    LBitmap.SetSize(AControl.Width, AControl.Height);
    LBitmap.Canvas.Brush.Color := clWhite;
    LBitmap.Canvas.FillRect(Rect(0, 0, LBitmap.Width, LBitmap.Height));
    AControl.PaintTo(LBitmap.Canvas, 0, 0);
    PasteWebViews(AControl);
    LPng.Assign(LBitmap);
    LPng.SaveToFile(IncludeTrailingPathDelimiter(FShotsDir) + AName + '.png');
    Log('  screenshot ' + AName + '.png (with WebView2)');
  finally
    LStream.Free;
    LWebPng.Free;
    LPng.Free;
    LBitmap.Free;
  end;
end;

function TAIChatTests.PixelsWithColor(AControl: TWinControl; AColor: TColor): Integer;
var
  LBitmap: TBitmap;
  LImage: TLazIntfImage;
  LWanted, LColor: TFPColor;
  X, Y: Integer;
begin
  // TLazIntfImage: Canvas.Pixels is one X11 round trip per pixel on Linux
  Result := 0;
  LWanted := TColorToFPColor(ColorToRGB(AColor));
  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(AControl.Width, AControl.Height);
    AControl.PaintTo(LBitmap.Canvas, 0, 0);
    LImage := LBitmap.CreateIntfImage;
    try
      for Y := 0 to LImage.Height - 1 do
        for X := 0 to LImage.Width - 1 do
        begin
          LColor := LImage.Colors[X, Y];
          if (LColor.Red shr 8 = LWanted.Red shr 8) and (LColor.Green shr 8 = LWanted.Green shr 8) and
            (LColor.Blue shr 8 = LWanted.Blue shr 8) then
            Inc(Result);
        end;
    finally
      LImage.Free;
    end;
  finally
    LBitmap.Free;
  end;
end;

procedure TAIChatTests.LoginWithCode;
begin
  Check(TRpAuthManager.Instance.LoginWithCode('ana@example.com', '123456'),
    'login with the email code (fake Hub)');
  Pump(50);
end;

{ Events }

function TAIChatTests.BuildDesignRequest(Sender: TObject;
  const APrompt: string): TRpApiModifyReportRequest;
begin
  Result := TRpApiModifyReportRequest.Create;
  Result.ReportDocument := '<report/>';
  Result.UserInstructions.Add(APrompt);
  Result.AITier := RpAITierTypeFromString(TFRpChatFrame(Sender).GetAITier);
end;

procedure TAIChatTests.ApplyDesignResult(Sender: TObject;
  const AModifiedReportDocument: string);
begin
  FApplied := AModifiedReportDocument;
  Inc(FApplyCount);
end;

procedure TAIChatTests.InferenceBegin(Sender: TObject);
begin
  Inc(FInferenceBegin);
end;

procedure TAIChatTests.InferenceEnd(Sender: TObject);
begin
  Inc(FInferenceEnd);
end;

procedure TAIChatTests.StopRequest(Sender: TObject);
begin
  Inc(FStopCount);
end;

procedure TAIChatTests.ApplySuggestion(Sender: TObject; const AExpression: string);
begin
  FSuggestion := AExpression;
end;

procedure TAIChatTests.LoginFrameAuthChanged(Sender: TObject);
begin
  Inc(FAuthChanged);
end;

procedure TAIChatTests.SchemaChanged(Sender: TObject);
begin
  Inc(FSchemaChanged);
end;

procedure TAIChatTests.WebMessage(Sender: TObject; const AMessage: string);
begin
  FWebDump := AMessage;
end;

procedure TAIChatTests.ScriptTick(Sender: TObject);
begin
  if FInScript or not Assigned(FScript) then
    Exit;
  FInScript := True;
  try
    FScript(Sender);
  finally
    FInScript := False;
  end;
end;

procedure TAIChatTests.StartScript(AScript: TNotifyEvent);
begin
  FDialog := nil;
  FScript := AScript;
  FTimer.OnTimer := ScriptTick;
  FTimer.Enabled := True;
end;

procedure TAIChatTests.StopScript;
begin
  FTimer.Enabled := False;
  FScript := nil;
  FDialog := nil;
end;

procedure TAIChatTests.HostSendPrompt(Sender: TObject; const APrompt, AExpression: string);
var
  LWorker: THostStreamWorker;
begin
  // What the expression assistant host will do (rpchatdialogvcl): start the
  // request in a worker and feed the frame from the mailbox
  FHostChat.BeginStreamingResponse;
  LWorker := THostStreamWorker.Create(FHostMailboxRef);
  LWorker.Prompt := APrompt;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.Start;
end;

procedure TAIChatTests.HostMessage(AMessage: TRpAsyncMessage);
var
  LMsg: THostStreamMessage;
begin
  LMsg := AMessage as THostStreamMessage;
  case LMsg.Kind of
    0:
      begin
        FHostChat.UpdateStreamingResponse(LMsg.Actor, LMsg.ChunkType, LMsg.Chunk,
          LMsg.Prefill, '', LMsg.ProgressId);
        FHostChat.UpdateStreamingTokens(LMsg.InTokens, LMsg.OutTokens, LMsg.ProgressId,
          LMsg.Prefill);
        FHostChat.CompleteStreamingProgress(LMsg.Actor, LMsg.ChunkType, LMsg.ProgressId);
      end;
    1:
      FHostChat.SetSuggestedExpression(LMsg.Expression, LMsg.Explanation);
  else
    FHostChat.FinishStreamingResponse;
    FHostChat.AddAssistantMessage(LMsg.Explanation);
  end;
end;

{ Tests }

// The captions follow the language of the machine
function T(AId: Integer; const ADefault: string): string;
begin
  Result := TranslateStr(AId, ADefault);
end;

procedure TAIChatTests.TestMarkdown;
var
  H: string;
begin
  Section('Markdown to HTML (native renderer)');
  CheckEquals('<h1>Title</h1>', RpMarkdownToHtml('# Title'), 'ATX heading');
  CheckEquals('<h2>Sub</h2>', RpMarkdownToHtml('Sub' + LineEnding + '---'), 'setext heading');
  CheckEquals('<p>a <b>bold</b> and <i>it</i> and <code>x&lt;1</code></p>',
    RpMarkdownToHtml('a **bold** and *it* and `x<1`'), 'inline emphasis and code');
  CheckEquals('<p>snake_case_name stays</p>', RpMarkdownToHtml('snake_case_name stays'),
    'no emphasis inside words');
  CheckEquals('<p>one<br>two</p>', RpMarkdownToHtml('one' + LineEnding + 'two'),
    'line breaks (breaks: true)');
  CheckEquals('<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>',
    RpMarkdownToHtml('<script>alert(1)</script>'), 'raw HTML is text');
  H := RpMarkdownToHtml('```sql' + LineEnding + 'SELECT *' + LineEnding + '  FROM T' +
    LineEnding + '```');
  CheckContains('<pre>SELECT *' + #10 + '  FROM T</pre>', H, 'fenced code keeps lines');
  H := RpMarkdownToHtml('- a' + LineEnding + '- b' + LineEnding + '  - c' + LineEnding + '1. x');
  CheckEquals('<ul><li>a</li><li>b<ul><li>c</li></ul></li></ul><ol><li>x</li></ol>', H,
    'nested lists');
  H := RpMarkdownToHtml('| A | B |' + LineEnding + '|---|--:|' + LineEnding + '| 1 | 2 |');
  CheckContains('<th bgcolor="' + MdClrSurface + '" align="left">A</th>', H, 'table header');
  CheckContains('<td align="right">2</td>', H, 'table alignment');
  CheckEquals('<p><a href="https://reportman.es">site</a> and ' +
    '<a href="https://x.org/a">https://x.org/a</a>.</p>',
    RpMarkdownToHtml('[site](https://reportman.es) and https://x.org/a.'), 'links');
  CheckEquals('<p>javascript</p>', RpMarkdownToHtml('[javascript](javascript:alert(1))'),
    'unsafe link scheme dropped');
  CheckEquals('<p>*not em*</p>', RpMarkdownToHtml(BS + '*not em' + BS + '*'), 'escapes');
  CheckEquals('<blockquote><i><p>quote</p></i></blockquote>', RpMarkdownToHtml('> quote'),
    'block quote');
  CheckEquals('<hr>', RpMarkdownToHtml('***'), 'rule');
  CheckContains('Thinking...', RpMarkdownToHtml('<think>plan</think>Answer'), 'think block');
  CheckContains('<p>Answer</p>', RpMarkdownToHtml('<think>plan</think>Answer'),
    'text after the think block');
  CheckContains('Thinking...', RpMarkdownToHtml('<think>still'), 'open think block (streaming)');
  CheckEquals('<p>A' + U_NTILDE + 'o <b>' + U_UACUTE + '</b></p>',
    RpMarkdownToHtml('A' + U_NTILDE + 'o **' + U_UACUTE + '**'), 'UTF-8 text');
end;

procedure TAIChatTests.TestNativeViewer;
var
  LForm: TForm;
  LView: TRpWebMarkdownView;
  I, LRenders: Integer;
  H: string;
begin
  Section('Native Markdown viewer (TRpWebMarkdownView without WebView2)');
  LForm := NewForm(420, 520);
  try
    LView := TRpWebMarkdownView.Create(LForm);
    LView.Parent := LForm;
    LView.Align := alClient;
    LForm.Show;
    Check(not LView.UsingWebView, 'native renderer in use');
    Check(LView.Ready, 'native renderer ready at once');
    Check(LView.NativeView <> nil, 'IPro panel created');

    LView.AppendMessage('user', 'Sum of the **balance** per client');
    LView.AppendMessage('assistant', '# Result' + LineEnding + 'Use `SUM(CLIENTS.BALANCE)`:' +
      LineEnding + LineEnding + '- one' + LineEnding + '- two');
    LView.AppendLogLine('actor: AI');
    LView.AppendLogChunkKey('k1', 'SEL');
    LView.AppendLogChunkKey('k1', 'ECT 1');
    LView.EndLogChunkKey('k1');
    LView.AppendLogChunkKey('k1', 'after end');
    CheckEquals(5, LView.BlockCount, 'blocks: 2 messages, badge and 2 chunks');
    CheckEquals('SELECT 1', LView.Block(3).Raw, 'chunks of one key are merged');
    CheckEquals('after end', LView.Block(4).Raw, 'a new block after EndLogChunkKey');

    LRenders := LView.RenderCount;
    for I := 1 to 40 do
      LView.AppendStreamingChunk('assistant', 'w' + IntToStr(I) + ' ', 0);
    Pump(100);
    Check(LView.RenderCount - LRenders <= 3,
      Format('streaming renders are coalesced (%d renders for 40 chunks)', [LView.RenderCount - LRenders]));
    CheckContains('w40', LView.Block(LView.BlockCount - 1).Raw, 'streamed text accumulated');
    LView.FinishStreaming;
    Check(not LView.Block(LView.BlockCount - 1).Streaming, 'FinishStreaming ends the message');
    LView.FlushRender;
    H := LView.DocumentHtml;
    CheckContains('<b>YOU</b>', H, 'user header');
    CheckContains('<b>ASSISTANT</b>', H, 'assistant header');
    CheckContains('<h1>Result</h1>', H, 'markdown rendered');
    CheckContains('<code>SUM(CLIENTS.BALANCE)</code>', H, 'code span rendered');
    CheckContains('<b>AI</b>', H, 'actor badge');
    Pump(200);
    Check(PixelsWithColor(LView.NativeView, RGBToColor($89, $B4, $FA)) > 50,
      'the user message bar is painted');
    Check(PixelsWithColor(LView.NativeView, RGBToColor($31, $32, $44)) > 500,
      'the user message background is painted');
    Shot(LView, 'native_viewer');
    LView.ClearAll;
    CheckEquals(0, LView.BlockCount, 'ClearAll');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
end;

procedure TAIChatTests.TestLoginFrame;
var
  LForm: TForm;
  LFrame: TFRpLoginFrameLCL;
  function Cond1: Boolean;
  begin
    Result := FAuthChanged > 0;
  end;
  function Cond2: Boolean;
  begin
    Result := FAuthChanged > 0;
  end;

begin
  Section('Account card (TFRpLoginFrameLCL)');
  Check(not TRpAuthManager.Instance.IsLoggedIn, 'not logged in (sandbox settings)');
  LForm := NewForm(320, 80);
  try
    LFrame := TFRpLoginFrameLCL.Create(LForm);
    LFrame.Parent := LForm;
    LFrame.Align := alTop;
    LFrame.OnAuthChanged := LoginFrameAuthChanged;
    LForm.Show;
    Pump(50);
    CheckEquals(T(1498, 'Guest (Login available)'), LFrame.LabelUser.Caption, 'guest caption');
    Check(not LFrame.LabelTier.Visible, 'no tier badge for guests');
    Check(LFrame.MenuItemLogin.Visible, 'menu: login visible');
    Check(not LFrame.MenuItemLogout.Visible, 'menu: logout hidden');
    Shot(LForm, 'login_frame_guest');

    FAuthChanged := 0;
    LoginWithCode;
    WaitUntil(Cond1, 5000,
      'the card is notified of the login');
    CheckEquals('Ana ' + U_NTILDE_UP, LFrame.LabelUser.Caption, 'user name shown');
    Check(LFrame.LabelTier.Visible, 'tier badge shown');
    CheckEquals('PRO', LFrame.LabelTier.Caption, 'tier badge text');
    Check(not LFrame.MenuItemLogin.Visible, 'menu: login hidden');
    Check(LFrame.MenuItemLogout.Visible, 'menu: logout visible');
    CheckContains(TRpAuthManager.GetAILanguageDisplayName(TRpAuthManager.Instance.AILanguage),
      LFrame.MenuItemLanguage.Caption, 'language in the menu');
    Shot(LForm, 'login_frame_user');

    // Language menu
    LFrame.MenuItemLanguage.Items[1].Click;
    CheckEquals('Spanish', TRpAuthManager.Instance.AILanguage, 'language chosen from the menu');
    LFrame.MenuItemLanguage.Items[0].Click;

    FAuthChanged := 0;
    LFrame.MenuItemLogout.Click;
    WaitUntil(Cond2, 5000,
      'the card is notified of the logout');
    CheckEquals(T(1498, 'Guest (Login available)'), LFrame.LabelUser.Caption, 'guest again');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
  Pump(50);
end;

procedure TAIChatTests.LoginDialogScript(Sender: TObject);
var
  LDlg: TFRpLoginLCL;
begin
  if not (FDialog is TFRpLoginLCL) then
  begin
    // Waiting for the dialog to open
    if (Screen.ActiveCustomForm is TFRpLoginLCL) then
    begin
      FDialog := TForm(Screen.ActiveCustomForm);
      FStep := 0;
      FStepStart := GetTickCount64;
    end;
    Exit;
  end;
  LDlg := TFRpLoginLCL(FDialog);
  if GetTickCount64 - FStepStart > 20000 then
    Fail('login dialog script: step ' + IntToStr(FStep) + ' timed out');
  case FStep of
    0:
      begin
        LDlg.BtnEmailClick(nil);
        Check(LDlg.PanelEmail.Visible, 'email panel shown');
        LDlg.EditEmail.Text := 'not-an-email';
        LDlg.BtnSendCodeClick(nil);
        CheckEquals(T(1509, 'Enter a valid email address.'), LDlg.LStatus.Caption, 'email validated');
        LDlg.EditEmail.Text := 'ana@example.com';
        LDlg.BtnSendCodeClick(nil);
        Check(LDlg.Busy, 'busy while the code is sent');
        Check(not LDlg.BtnGoogle.Enabled, 'buttons disabled while busy');
        FStep := 1;
      end;
    1:
      if not LDlg.Busy then
      begin
        CheckEquals(T(1511, 'Code sent! Check your email.'), LDlg.LStatus.Caption, 'code sent');
        LDlg.EditCode.Text := '000000';
        LDlg.BtnLoginCodeClick(nil);
        FStep := 2;
      end;
    2:
      if not LDlg.Busy then
      begin
        CheckEquals(T(1515, 'Invalid code or login failed.'), LDlg.LStatus.Caption, 'wrong code refused');
        CheckContains('Hub API', LDlg.MemoLog.Text + ' Hub API', 'log shown');
        Shot(LDlg, 'login_dialog');
        LDlg.EditCode.Text := '123456';
        LDlg.BtnLoginCodeClick(nil);
        FStep := 3;
      end;
    3:
      ; // The dialog closes with mrOk
  end;
end;

procedure TAIChatTests.TestLoginDialog;
begin
  Section('Login dialog (email code, worker thread)');
  StartScript(LoginDialogScript);
  try
    Check(ShowLoginDialog(nil), 'ShowLoginDialog returns True after the login');
  finally
    StopScript;
  end;
  Check(TRpAuthManager.Instance.IsLoggedIn, 'logged in');
  CheckEquals('tok123', TRpAuthManager.Instance.Token, 'token of the email login');
  TRpAuthManager.Instance.Logout;
  Pump(50);
end;

procedure TAIChatTests.OAuthDialogScript(Sender: TObject);
var
  LDlg: TFRpLoginLCL;
begin
  if not (FDialog is TFRpLoginLCL) then
  begin
    if Screen.ActiveCustomForm is TFRpLoginLCL then
    begin
      FDialog := TForm(Screen.ActiveCustomForm);
      FStep := 0;
      FStepStart := GetTickCount64;
    end;
    Exit;
  end;
  LDlg := TFRpLoginLCL(FDialog);
  if GetTickCount64 - FStepStart > 20000 then
    Fail('OAuth dialog script timed out');
  if FStep = 0 then
  begin
    LDlg.BtnGoogleClick(nil);
    // The OAuth wait runs in the worker: the dialog keeps processing messages
    Check(LDlg.Busy, 'Google login running in the background');
    FStep := 1;
  end;
end;

procedure TAIChatTests.TestOAuthDialog;
begin
  Section('Login dialog (Google OAuth with a simulated browser)');
  RpOpenUrlHook := FakeBrowser;
  StartScript(OAuthDialogScript);
  try
    Check(ShowLoginDialog(nil), 'Google login through the dialog');
  finally
    StopScript;
    if GRedirect <> nil then
    begin
      GRedirect.WaitFor;
      FreeAndNil(GRedirect);
    end;
  end;
  CheckEquals('tokG', TRpAuthManager.Instance.Token, 'Google token');
  // Keep this session for the next tests (the Hub accepts tok*)
  Pump(50);
end;

procedure TAIChatTests.TestAISelection;
var
  LForm: TForm;
  LSel: TFRpAISelectionLCL;
begin
  Section('Model selection (TFRpAISelectionLCL)');
  LForm := NewForm(420, 120);
  try
    LSel := TFRpAISelectionLCL.Create(LForm);
    LSel.Parent := LForm;
    LSel.Align := alTop;
    LSel.OnStopRequest := StopRequest;
    LForm.Show;
    Pump(50);
    CheckEquals('Standard', LSel.AITier, 'default provider');
    CheckEquals('Fast', LSel.AIMode, 'default mode');
    Check(LSel.PGaugeHost.Visible, 'credit gauge for the Hub models');
    LSel.RefreshState;
    CheckContains(T(1525, 'Daily Credit Usage'), LSel.PaintBoxGauge.Hint, 'gauge hint (paid tier)');
    CheckContains(T(1526, 'Used') + ': 250 (25%)', LSel.PaintBoxGauge.Hint, 'credits used');
    Check(Abs(LSel.GaugeValue - 0.25) < 0.001, 'gauge value');
    Shot(LForm, 'ai_selection');

    LSel.ComboAIProvider.ItemIndex := 1;
    LSel.ComboAIProviderChange(nil);
    CheckEquals('Precision', LSel.AITier, 'precision provider');
    LSel.ComboAIMode.ItemIndex := 1;
    CheckEquals('Reasoning', LSel.AIMode, 'reasoning mode');

    LSel.AddAgentEndpoint(3, 's3', 'Local (pc1)', True);
    LSel.AddAgentEndpoint(9, 's9', 'Other (pc9)', True);
    CheckEquals(2, LSel.AgentEndpointCount, 'agents added');
    LSel.RestoreProviderSelection('LocalAgent', 9);
    CheckEquals('LocalAgent', LSel.AITier, 'agent provider');
    CheckEquals('s9', LSel.AgentSecret, 'agent secret');
    CheckEquals(9, LSel.AgentAiId, 'agent id');
    Check(not LSel.PGaugeHost.Visible, 'no credit gauge for local agents');
    LSel.ClearAgentEndpoints;
    CheckEquals('Standard', LSel.AITier, 'back to Standard when the agents go');
    Check(LSel.PGaugeHost.Visible, 'gauge visible again');
    LSel.RestoreProviderSelection('Precision', 0);
    CheckEquals('Precision', LSel.AITier, 'provider restored');

    // Inference progress
    LSel.SetInferenceProgress(True);
    Check(LSel.InferenceActive and LSel.BStopInference.Visible, 'progress panel with Stop');
    Check(LSel.SpinnerTimer.Enabled, 'spinner animated');
    LSel.UpdateTokens(120, 7, 'abc');
    LSel.UpdateTokens(0, 0, 'def', 40);
    CheckContains('Input/Output: 120 / 7  #abc', LSel.ProgressTokensText, 'token row');
    CheckContains('40% prefill', LSel.ProgressTokensText, 'prefill row');
    Check(LSel.PreferredHeight >= Scale(50), 'preferred height grows with rows');
    Shot(LForm, 'ai_selection_progress');
    LSel.FinishProgressToken('abc');
    Check(Pos('#abc', LSel.ProgressTokensText) = 0, 'finished row removed');
    FStopCount := 0;
    LSel.BStopInference.Click;
    CheckEquals(1, FStopCount, 'Stop raises OnStopRequest');
    LSel.SetInferenceProgress(False);
    Check(not LSel.InferenceActive, 'progress panel hidden');
    Check(not LSel.SpinnerTimer.Enabled, 'spinner stopped');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
end;

procedure TAIChatTests.TestSchemaSelector;
var
  LForm: TForm;
  LSel: TFRpAISchemaSelectorLCL;
  function Cond3: Boolean;
  begin
    Result := not LSel.Loading;
  end;

begin
  Section('Schema selector (TFRpAISchemaSelectorLCL)');
  LForm := NewForm(420, 160);
  try
    LSel := TFRpAISchemaSelectorLCL.Create(LForm);
    LSel.Parent := LForm;
    LSel.Align := alTop;
    LSel.OnSchemaChanged := SchemaChanged;
    LForm.Show;
    Check(LSel.LoginFrame <> nil, 'account card inside');
    LSel.SetPreferredConnection(78, 'test-key');
    FSchemaChanged := 0;
    LSel.LoadSchemas;
    Check(LSel.Loading, 'loading in the background');
    CheckEquals('...', LSel.BRefreshSchemas.Caption, 'refresh button shows the load');
    WaitUntil(Cond3, 10000,
      'schemas loaded');
    Check(LSel.LastLoadOk, 'the Hub answered');
    // '' + API key schemas (preferred database first) + account schemas
    CheckEquals(4, LSel.ComboSchema.Items.Count, 'schemas merged without duplicates');
    CheckEquals('Stock', LSel.ComboSchema.Items[1], 'preferred database first');
    CheckEquals('Sales / Main', LSel.ComboSchema.Items[2], 'API key schema');
    CheckEquals('HR', LSel.ComboSchema.Items[3], 'account schema');
    CheckEquals(78, LSel.GetHubDatabaseId, 'preferred database selected');
    CheckEquals(6, LSel.GetHubSchemaId, 'its schema');
    CheckEquals('test-key', LSel.GetSchemaApiKey, 'API key of the schema');
    Check(FSchemaChanged > 0, 'OnSchemaChanged');
    LSel.SetHubContext(79, 7);
    CheckEquals(3, LSel.ComboSchema.ItemIndex, 'SetHubContext selects the schema');
    CheckEquals('', LSel.GetSchemaApiKey, 'account schema has no API key');
    Shot(LForm, 'schema_selector');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAIChatTests.TestChatOnline;
var
  LForm: TForm;
  LChat: TFRpChatFrame;

  function OnlineLoaded: Boolean;
  begin
    Result := (LChat.AISelection.AgentEndpointCount > 0) and
      (LChat.ComboSchema.Items.Count > 1) and not LChat.LoadingSchemas;
  end;

begin
  Section('Chat frame: online initialization (agents and schemas)');
  LForm := NewForm(420, 640);
  try
    LChat := TFRpChatFrame.Create(LForm);
    FDiagChat := LChat;
    LChat.Parent := LForm;
    LChat.Align := alClient;
    LForm.Show;
    Pump(50);
    CheckEquals('Ana ' + U_NTILDE_UP, LChat.LoginFrame.LabelUser.Caption, 'account card in the chat');
    Check(not LChat.BSend.Enabled, 'Send disabled without a prompt');
    LChat.SetHubContext(79, 7, '');
    LChat.StartOnlineInitialization;
    // CheckStatus -> auth event -> agents and schemas
    WaitUntil(OnlineLoaded, 10000, 'agents and schemas loaded');
    CheckEquals(1, LChat.AISelection.AgentEndpointCount, 'only the online agent');
    CheckEquals('Local (pc1)', LChat.AISelection.ComboAIProvider.Items[2], 'agent name');
    CheckEquals('HR', LChat.ComboSchema.Text, 'SetHubContext schema selected after the load');
    CheckEquals(79, LChat.GetHubDatabaseId, 'hub database of the selection');
    CheckEquals(7, LChat.GetHubSchemaId, 'hub schema of the selection');
    Check(Pos('CheckStatus', LChat.NetLogView.PlainText) > 0, 'net log receives the Hub log');
    Check(RpAsyncWaitIdle(10000), 'workers finished');
    LChat.SetShowSchemaSelector(False);
    Check(not LChat.PSchemaHost.Visible, 'schema selector can be hidden');
    CheckEquals(0, LChat.GetHubSchemaId, 'no schema when hidden');
    LChat.SetShowSchemaSelector(True);
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
end;

procedure TAIChatTests.TestChatDesignStream;
var
  LForm: TForm;
  LChat: TFRpChatFrame;
  function Cond4: Boolean;
  begin
    Result := Pos('<rep', LChat.LogView.PlainText) > 0;
  end;
  function Cond5: Boolean;
  begin
    Result := not LChat.Busy;
  end;

begin
  Section('Chat frame: design request streamed by the frame');
  LForm := NewForm(420, 640);
  try
    LChat := TFRpChatFrame.Create(LForm);
    FDiagChat := LChat;
    LChat.Parent := LForm;
    LChat.Align := alClient;
    LChat.OnBuildDesignRequest := BuildDesignRequest;
    LChat.OnApplyDesignResult := ApplyDesignResult;
    LChat.OnDesignInferenceBegin := InferenceBegin;
    LChat.OnDesignInferenceEnd := InferenceEnd;
    LChat.Initialize('', 'Describe report changes here.');
    LForm.Show;
    Pump(50);
    FApplied := '';
    FApplyCount := 0;
    FInferenceBegin := 0;
    FInferenceEnd := 0;
    LChat.MemoPrompt.Text := 'Add a title';
    Check(LChat.BSend.Enabled, 'Send enabled with a prompt');
    LChat.BSendClick(nil);
    Check(LChat.Busy, 'busy while streaming');
    CheckEquals(T(1522, 'Stop'), LChat.BClear.Caption, 'Clear becomes Stop');
    Check(not LChat.BSend.Enabled, 'Send disabled while busy');
    Check(LChat.AISelection.InferenceActive, 'inference progress shown');
    Check(LChat.PControl.ActivePage = LChat.TabLog, 'AI log tab while streaming');
    CheckContains('Add a title', LChat.ConversationText, 'user message in the chat');
    WaitUntil(Cond4,
      5000, 'streamed chunk in the AI log');
    WaitUntil(Cond5, 10000,
      'request finished');
    CheckEquals(1, FApplyCount, 'OnApplyDesignResult once');
    CheckEquals('<report/>', FApplied, 'modified document applied');
    CheckEquals(1, FInferenceBegin, 'OnDesignInferenceBegin');
    CheckEquals(1, FInferenceEnd, 'OnDesignInferenceEnd');
    CheckContains('Hecho ' + U_NTILDE + ': **title** added', LChat.ConversationText,
      'explanation added to the chat');
    CheckEquals('Hecho ' + U_NTILDE + ': **title** added', LChat.LastAssistantMessage,
      'last assistant message');
    Check(LChat.PControl.ActivePage = LChat.TabChat, 'back to the chat tab');
    CheckEquals(T(1532, 'Clear'), LChat.BClear.Caption, 'Stop becomes Clear');
    Check(not LChat.AISelection.InferenceActive, 'progress hidden');
    Check(LChat.BReportAI.Enabled, 'report content enabled with an answer');
    CheckEquals(300, TRpAuthManager.Instance.Profile.DailyConsumed,
      'profile of the answer applied (credits)');
    LChat.ChatView.FlushRender;
    CheckContains('<b>title</b>', LChat.ChatView.DocumentHtml, 'markdown of the answer rendered');
    Shot(LChat, 'chat_frame');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAIChatTests.TestChatStop;
var
  LForm: TForm;
  LChat: TFRpChatFrame;
  LStart: QWord;
  LChunks: Integer;
  function Cond6: Boolean;
  begin
    Result := Pos('x2 ', LChat.LogView.PlainText) > 0;
  end;
  function Cond7: Boolean;
  begin
    Result := Pos('x1 ', LChat.LogView.PlainText) > 0;
  end;

begin
  Section('Chat frame: stop in the middle of a stream, frame destroyed while streaming');
  LForm := NewForm(420, 640);
  try
    LChat := TFRpChatFrame.Create(LForm);
    FDiagChat := LChat;
    LChat.Parent := LForm;
    LChat.Align := alClient;
    LChat.OnBuildDesignRequest := BuildDesignRequest;
    LChat.OnApplyDesignResult := ApplyDesignResult;
    LChat.OnStopRequest := StopRequest;
    LForm.Show;
    FApplyCount := 0;
    FStopCount := 0;
    FHubHandler.SlowStarted := False;
    LChat.MemoPrompt.Text := 'slow';
    LChat.BSendClick(nil);
    WaitUntil(Cond6,
      10000, 'the slow stream is running');
    Check(LChat.AISelection.ProgressTokensText <> '', 'token rows while streaming');
    LChat.BClearClick(nil);
    Check(not LChat.Busy, 'Stop ends the busy state at once');
    CheckEquals(1, FStopCount, 'OnStopRequest');
    CheckContains(T(1536, 'Generation stopped.'), LChat.ConversationText, 'stop message');
    LChunks := Length(LChat.LogView.PlainText);
    LStart := GetTickCount64;
    Check(RpAsyncWaitIdle(3000), 'the worker ends soon after the stop');
    Check(ElapsedMs(LStart) < 2500, Format('cancel is prompt (%d ms; the stream lasts 6 s)',
      [ElapsedMs(LStart)]));
    Pump(200);
    CheckEquals(LChunks, Length(LChat.LogView.PlainText), 'no chunk after the stop');
    CheckEquals(0, FApplyCount, 'nothing applied');

    // Destroyed while streaming: the worker stops and its messages are dropped
    LChat.MemoPrompt.Text := 'slow';
    LChat.BSendClick(nil);
    WaitUntil(Cond7,
      10000, 'second slow stream running');
    FDiagChat := nil;
    FreeAndNil(LChat);
    Check(RpAsyncWaitIdle(3000), 'worker of a destroyed frame ends');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
end;

procedure TAIChatTests.TestChatHostStream;
var
  LForm: TForm;
  function Cond8: Boolean;
  begin
    Result := FHostChat.SuggestedExpression <> '';
  end;

begin
  Section('Chat frame: a host streaming with its own mailbox (SQL/expression pattern)');
  LForm := NewForm(420, 640);
  FHostMailbox := TRpAsyncMailbox.Create(HostMessage);
  FHostMailboxRef := FHostMailbox;
  try
    FHostChat := TFRpChatFrame.Create(LForm);
    FDiagChat := FHostChat;
    FHostChat.Parent := LForm;
    FHostChat.Align := alClient;
    FHostChat.SetShowSchemaSelector(False);
    FHostChat.OnSendPrompt := HostSendPrompt;
    FHostChat.OnApplySuggestion := ApplySuggestion;
    FHostChat.Initialize('SUM(', 'Ask for an expression.');
    LForm.Show;
    FSuggestion := '';
    FHostChat.MemoPrompt.Text := 'sum of balance';
    FHostChat.BSendClick(nil);
    Check(FHostChat.Busy, 'busy while the host streams');
    WaitUntil(Cond8, 10000,
      'suggestion received');
    Check(not FHostChat.Busy, 'not busy after the suggestion');
    CheckEquals('SUM(CLIENTS.BALANCE)', FHostChat.SuggestedExpression, 'suggested expression');
    CheckContains('SUM(', FHostChat.LogView.PlainText, 'stream in the AI log');
    CheckContains(T(1538, 'Suggested expression') + ':', FHostChat.ConversationText, 'suggestion in the chat');
    Check(FHostChat.BApply.Enabled, 'Apply enabled');
    FHostChat.BApplyClick(nil);
    CheckEquals('SUM(CLIENTS.BALANCE)', FSuggestion, 'OnApplySuggestion');
    Check(RpAsyncWaitIdle(10000), 'workers finished');
  finally
    FHostMailbox.Detach;
    FHostMailboxRef := nil;
    FHostChat := nil;
    FDiagChat := nil;
    LForm.Free;
  end;
end;

procedure TAIChatTests.TestChatProgressAndMisc;
var
  LForm: TForm;
  LChat: TFRpChatFrame;
begin
  Section('Chat frame: progress, refresh action, no handler');
  LForm := NewForm(420, 640);
  try
    LChat := TFRpChatFrame.Create(LForm);
    FDiagChat := LChat;
    LChat.Parent := LForm;
    LChat.Align := alClient;
    LForm.Show;
    LChat.BeginProgress('Datasets', 'Opening CLIENTS');
    Check(LChat.Busy and LChat.ProgressActive, 'progress makes the chat busy');
    LChat.UpdateProgress('Opening ORDERS');
    LChat.ChatView.FlushRender;
    CheckContains('Opening ORDERS', LChat.ChatView.PlainText, 'progress text shown');
    LChat.FinishProgress;
    Check(not LChat.Busy and not LChat.ProgressActive, 'progress finished');
    Check(Pos('Opening ORDERS', LChat.ChatView.PlainText) = 0, 'progress block removed');

    LChat.SetRefreshAction(True);
    CheckEquals(T(1149, 'Refresh'), LChat.BApply.Caption, 'refresh action caption');
    Check(not LChat.BApply.Enabled, 'refresh disabled without OnRefreshContext');
    LChat.SetRefreshAction(False);
    CheckEquals(T(1535, 'Apply'), LChat.BApply.Caption, 'apply caption');

    LChat.MemoPrompt.Text := 'hello';
    LChat.BSendClick(nil);
    CheckContains(T(1537, 'Chat UI is ready, but no AI handler is connected yet.'), LChat.ConversationText,
      'message when no handler is connected');
    LChat.BClearClick(nil);
    CheckEquals('', Trim(LChat.ConversationText), 'Clear empties the conversation');

    LChat.AppendLogLine('actor: AI');
    LChat.AppendLogChunk('abc', True);
    // Clear emptied the log: the badge and the chunk
    CheckEquals(2, LChat.LogView.BlockCount, 'AppendLogLine/AppendLogChunk');
    CheckEquals('abc', LChat.LogView.Block(1).Raw, 'log chunk text');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;
end;

procedure TAIChatTests.ReportDialogScript(Sender: TObject);
var
  LDlg: TFRpAIReportLCL;
begin
  if not (FDialog is TFRpAIReportLCL) then
  begin
    if Screen.ActiveCustomForm is TFRpAIReportLCL then
    begin
      FDialog := TForm(Screen.ActiveCustomForm);
      FStep := 0;
      FStepStart := GetTickCount64;
    end;
    Exit;
  end;
  LDlg := TFRpAIReportLCL(FDialog);
  if GetTickCount64 - FStepStart > 20000 then
    Fail('AI report dialog script timed out');
  if FStep = 0 then
  begin
    CheckContains('Hecho', LDlg.MemoAIContent.Text, 'AI content in the report dialog');
    LDlg.ComboProblem.ItemIndex := 1;
    LDlg.MemoDetails.Text := 'wrong column';
    Shot(LDlg, 'ai_report_dialog');
    LDlg.BSendClick(nil);
    Check(LDlg.IsSending, 'sending in the background');
    FStep := 1;
  end;
end;

procedure TAIChatTests.TestReportDialog;
begin
  Section('AI report dialog');
  StartScript(ReportDialogScript);
  try
    Check(ExecuteAIReportDialog(nil, 'Hecho: SELECT 2', TRpAuthManager.Instance.Token,
      TRpAuthManager.Instance.InstallId, ''), 'report sent, dialog closed with OK');
  finally
    StopScript;
  end;
  CheckContains('{"errorType":"InaccurateContent","userComments":"wrong column",' +
    '"aiContent":"Hecho: SELECT 2', FHub.LastBody, 'report body');
end;

procedure TAIChatTests.TestMainForm;
var
  LMain: TFRpMainFLCL;
  function Cond9: Boolean;
  begin
    Result := LMain.ChatFrame.ComboSchema.Items.Count > 1;
  end;

begin
  Section('Designer main window: AI chat panel');
  LMain := TFRpMainFLCL.Create(nil);
  try
    LMain.Show;
    Pump(100);
    Check(LMain.ChatFrame <> nil, 'chat frame in the main window');
    FDiagChat := LMain.ChatFrame;
    Check(LMain.AIChatPanel.Visible, 'AI panel visible by default (as the VCL)');
    Check(LMain.ChatFrame.LoginFrame <> nil, 'account card at the top of the panel');
    CheckEquals('Ana ' + U_NTILDE_UP, LMain.ChatFrame.LoginFrame.LabelUser.Caption,
      'logged in user shown');
    Check(LMain.AIChatPanel.Left > LMain.DesignerFrame.Left, 'panel at the right');
    WaitUntil(Cond9,
      10000, 'schemas loaded by the main window');
    Shot(LMain, 'main_window');
    Check(RpAsyncWaitIdle(10000), 'workers finished');
  finally
    FDiagChat := nil;
    LMain.Free;
  end;
end;

procedure TAIChatTests.TestWebView2;
{$IFDEF MSWINDOWS}
var
  LForm: TForm;
  LView: TRpWebMarkdownView;
  LSaved: Boolean;
  LDump: string;
  LStream: TMemoryStream;
  LChat: TFRpChatFrame;

  function ChatWebReady: Boolean;
  begin
    Result := LChat.ChatView.Ready;
  end;
  function Cond10: Boolean;
  begin
    Result := LView.Ready;
  end;
  function Cond11: Boolean;
  begin
    Result := FWebDump <> '';
  end;
  function Cond12: Boolean;
  begin
    Result := FWebDump <> '';
  end;
{$ENDIF}

begin
{$IFDEF MSWINDOWS}
  Section('WebView2 Markdown viewer (Windows)');
  LSaved := RpWebMarkdownForceNative;
  RpWebMarkdownForceNative := False;
  LForm := NewForm(460, 520);
  try
    LView := TRpWebMarkdownView.Create(LForm);
    LView.Parent := LForm;
    LView.Align := alClient;
    LForm.Show;
    Check(LView.UsingWebView, 'WebView2 renderer selected');
    LView.AppendMessage('user', 'Sum of the **balance**');
    LView.AppendMessage('assistant', '# Result' + LineEnding + 'Use `SUM(CLIENTS.BALANCE)`');
    WaitUntil(Cond10, 30000,
      'WebView2 ready (or fallback)');
    if not LView.UsingWebView then
    begin
      Skip('WebView2 not available here: ' + LView.FallbackReason);
      Exit;
    end;
    // The page posts its HTML back through window.chrome.webview
    FWebDump := '';
    LView.OnWebMessage := WebMessage;
    LView.WebView.ExecuteScript('window.chrome.webview.postMessage(' +
      'document.getElementById("messages").innerHTML);');
    WaitUntil(Cond11, 10000,
      'HTML of the page received');
    LDump := FWebDump;
    CheckContains('<strong>balance</strong>', LDump, 'markdown-it rendered the user message');
    CheckContains('<h1>Result</h1>', LDump, 'heading rendered');
    CheckContains('<code>SUM(CLIENTS.BALANCE)</code>', LDump, 'code rendered');
    // Streaming chunks through appendMessageChunk (the VCL name is wrong)
    FWebDump := '';
    LView.AppendStreamingChunk('assistant', 'stream **ok**', 30);
    LView.FinishStreaming;
    LView.WebView.ExecuteScript('window.chrome.webview.postMessage(' +
      'document.getElementById("messages").innerHTML);');
    WaitUntil(Cond12, 10000,
      'HTML after the streamed message');
    CheckContains('stream <strong>ok</strong>', FWebDump, 'streamed message rendered');
    LStream := TMemoryStream.Create;
    try
      Check(LView.WebView.CapturePreviewPng(LStream) and (LStream.Size > 100),
        'CapturePreview of the page');
    finally
      LStream.Free;
    end;
    ScreenShot(LView, 'webview2_viewer');
  finally
    FDiagChat := nil;
    LForm.Free;
  end;

  // The chat frame as the Windows designer shows it
  LForm := NewForm(420, 640);
  try
    LChat := TFRpChatFrame.Create(LForm);
    LChat.Parent := LForm;
    LChat.Align := alClient;
    LChat.Initialize('', 'Describe report changes here or ask for assistance. Any change can be undone.');
    LChat.AddUserMessage('Add a **title** with the company name');
    LChat.AddAssistantMessage('Done: the title uses `COMPANY.NAME` in the page header.' +
      LineEnding + LineEnding + '- Font: **Arial 14**' + LineEnding + '- Aligned to the center');
    LForm.Show;
    WaitUntil(ChatWebReady, 30000, 'chat views ready');
    Check(LChat.ChatView.UsingWebView, 'the chat uses WebView2 on Windows');
    Pump(500);
    ScreenShot(LChat, 'chat_frame_webview2');
  finally
    LForm.Free;
    RpWebMarkdownForceNative := LSaved;
  end;
{$ENDIF}
end;

procedure TAIChatTests.Screenshots;
begin
  // Covered by the Shot calls of the tests
end;

procedure TAIChatTests.Run;
var
  LIni: TStringList;
  LSandbox: string;
begin
  LSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rpaichattest', LSandbox) = 0 then
    Fail('the tests must run in the sandbox (LOCALAPPDATA=' + LSandbox + ')');
  // Connections of the sandbox (the chat reads their API keys)
  LIni := TStringList.Create;
  try
    LIni.Add('[HUBTEST]');
    LIni.Add('ApiKey=test-key');
    LIni.Add('HubDatabaseId=78');
    LIni.SaveToFile(IncludeTrailingPathDelimiter(LSandbox) + 'dbxconnections.ini');
  finally
    LIni.Free;
  end;
  DBXConnectionsFileOverride := IncludeTrailingPathDelimiter(LSandbox) + 'dbxconnections.ini';
  // Native viewer for the deterministic checks; WebView2 has its own test
  RpWebMarkdownForceNative := True;

  FHubHandler := TFakeHub.Create;
  FHub := TFakeServer.Create(FHubHandler.Handle);
  try
    FHub.Start;
    GHubBaseUrl := FHub.BaseURL;
    Log('  fake Hub on ' + FHub.BaseURL + ' for ' + HUB_API_URL);
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
    RpOpenUrlHook := FakeBrowser;
    try
      TestMarkdown;
      TestNativeViewer;
      TestLoginFrame;
      TestLoginDialog;
      TestOAuthDialog;
      TestAISelection;
      TestSchemaSelector;
      TestChatOnline;
      TestChatDesignStream;
      TestChatStop;
      TestChatHostStream;
      TestChatProgressAndMisc;
      TestReportDialog;
      TestMainForm;
      TestWebView2;
      TRpAuthManager.Instance.Logout;
      Check(RpAsyncWaitIdle(10000), 'all workers finished');
    finally
      RpOpenUrlHook := nil;
      RpHttpSetUrlRewrite('', '');
    end;
  finally
    FHub.Free;
    FHubHandler.Free;
  end;
  Pump(100);
end;

procedure RunAIChatTests(const AShotsDir: string);
var
  LTests: TAIChatTests;
begin
  LTests := TAIChatTests.Create(AShotsDir);
  try
    LTests.Run;
  finally
    LTests.Free;
  end;
end;

end.

{ Phase 7.4 tests: the AI expression assistant of the LCL expression editor
  (rpexpredlglcl) against a local fake Hub (no external network).

  Covers the classic editor without a Hub session and with the Hub
  unreachable, the dataset refresh of a report (a MyBase dataset and an
  Agent dataset whose columns come from the Hub), the semantic context sent
  with a prompt (columns, parameters, functions), a prompt streamed and
  validated (valid, invalid then fixed, still invalid, errors of the
  server), Apply, Stop, the dialog destroyed while streaming, the modal
  dialog through TRpExpreDialogLCL.Execute (the object inspector path) and
  the context of the design assistant. }
unit uaiexprtests;

{$mode delphi}{$H+}
{$modeswitch nestedprocvars}

interface

// AShotsDir: screenshots are saved there when not empty
procedure RunAIExprTests(const AShotsDir: string);

implementation

uses
  SysUtils, Classes, Types, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  LCLIntf, fphttpserver, httpdefs, rpjsonfpc, rphttpclientfpc, rptypes, rpdatainfo,
  rpauthmanager, rpparams, rpreport, rpeval, rpalias, rpaithreadslcl,
  rpfrmchatlcl, rpwebmarkdownlcl, rplclwebview, rpexpredlglcl, rpmdconsts,
  utestutil, ufakeserver;

const
  // Columns of ORDERS (an Agent dataset) in the schema answer of the Hub
  SchemaAnswer = '{"data":{"columns":[{"name":"ColumnName"},{"name":"DataType"}],' +
    '"rows":[["ID","System.Int32"],["TOTAL","System.Decimal"],' +
    '["ORDERDATE","System.DateTime"]]}}';
  // Fields of the test report: CLIENTS (MyBase) and ORDERS (Agent)
  ReportFields: array[0..5] of string = ('CLIENTS.ID', 'CLIENTS.NAME',
    'CLIENTS.BALANCE', 'ORDERS.ID', 'ORDERS.TOTAL', 'ORDERS.ORDERDATE');

type
  TCondition = function: Boolean is nested;

  { TExprFakeHub: the Hub endpoints used by the expression editor }

  TExprFakeHub = class
  private
    FLock: TRTLCriticalSection;
    FSuggestBodies: TStringList;
    FSchemaBodies: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
    procedure Clear;
    function SuggestCount: Integer;
    function SuggestBody(AIndex: Integer): string;
    function SuggestHeaders(AIndex: Integer): string;
    function SchemaCount: Integer;
    function SchemaBody(AIndex: Integer): string;
  end;

  { TAIExprTests }

  TAIExprTests = class
  private
    FShotsDir: string;
    FHub: TFakeServer;
    FHubHandler: TExprFakeHub;
    FTimer: TTimer;
    FScript: TNotifyEvent;
    FInScript: Boolean;
    FStep: Integer;
    FStepStart: QWord;
    FDialog: TFRpExpreDialogLCL;
    FDataDir: string;
    FConnectionsFile: string;
    FDriversFile: string;
    FClientsFile: string;
    FReport: TRpReport;
    procedure Pump(AMs: Cardinal);
    procedure WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
      const AWhat: string; ADialog: TFRpExpreDialogLCL = nil);
    procedure Shot(AControl: TWinControl; const AName: string);
    procedure ScreenShot(AControl: TWinControl; const AName: string);
    procedure Capture(AControl: TWinControl; const AName: string; APasteWebViews: Boolean);
    procedure ScriptTick(Sender: TObject);
    procedure StartScript(AScript: TNotifyEvent);
    procedure StopScript;
    procedure WriteTestData;
    function CreateReport: TRpReport;
    function NewDialog(AReport: TRpReport; const AExpression: string): TFRpExpreDialogLCL;
    function SendPrompt(ADialog: TFRpExpreDialogLCL; const APrompt: string): Boolean;
    procedure LoginWithCode;
    procedure ModalScript(Sender: TObject);
    // Tests
    procedure TestNoSession;
    procedure TestUnreachable;
    procedure TestRefreshAndContext;
    procedure TestPrompts;
    procedure TestStop;
    procedure TestModalExecute;
    procedure TestDesignContext;
    procedure TestWebView2Shot;
  public
    constructor Create(const AShotsDir: string);
    destructor Destroy; override;
    procedure Run;
  end;

// The captions follow the language of the machine
function T(AId: Integer; const ADefault: string): string;
begin
  Result := TranslateStr(AId, ADefault);
end;

function ProfileJson: string;
begin
  Result := '{"userId":9,"email":"eva@example.com","userName":"Eva",' +
    '"profileImageUrl":"","accountType":1,"tierId":4,"tierName":"Pro",' +
    '"dailyMax":1000,"dailyConsumed":250,"freeInitial":100,"freeRemaining":40,' +
    '"serverDay":"2026-09-27T00:00:00Z","credits":5}';
end;

function TiersJson: string;
begin
  Result := '[{"id":1,"name":"Free","monthlyPrice":0,"yearlyPrice":0,"maxCreditsDay":10,' +
    '"maxFreeCredits":100,"maxConnections":1,"maxTables":10,"maxColumnsPerTable":20,"maxKpis":1}]';
end;

function ProgressEvent(const AChunkType, AChunk, AId: string): string;
begin
  Result := '{"actor":"AI","stage":"ReceivingResponse","chunkType":"' + AChunkType +
    '","chunk":"' + AChunk + '","id":"' + AId + '","inputTokens":90,"outputTokens":6,' +
    '"prefillPercentage":0}';
end;

function ExpressionResult(const AExpression, AExplanation: string): string;
begin
  Result := '{"result":{"expression":"' + AExpression + '","explanation":"' +
    AExplanation + '"},"errorMessage":"",' +
    '"userProfile":{"userId":9,"email":"eva@example.com","tierName":"Pro","tierId":4,' +
    '"dailyMax":1000,"dailyConsumed":310}}';
end;

function ParseObject(const AText: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AText);
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

{ TExprFakeHub }

constructor TExprFakeHub.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FSuggestBodies := TStringList.Create;
  FSchemaBodies := TStringList.Create;
end;

destructor TExprFakeHub.Destroy;
begin
  Clear;
  FSuggestBodies.Free;
  FSchemaBodies.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TExprFakeHub.Clear;
var
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    // Each request keeps its headers in a list
    for I := 0 to FSuggestBodies.Count - 1 do
      FSuggestBodies.Objects[I].Free;
    FSuggestBodies.Clear;
    FSchemaBodies.Clear;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TExprFakeHub.SuggestCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FSuggestBodies.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TExprFakeHub.SuggestBody(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    if (AIndex >= 0) and (AIndex < FSuggestBodies.Count) then
      Result := FSuggestBodies[AIndex]
    else
      Result := '';
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TExprFakeHub.SuggestHeaders(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    if (AIndex >= 0) and (AIndex < FSuggestBodies.Count) then
      Result := TStringList(FSuggestBodies.Objects[AIndex]).Text
    else
      Result := '';
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TExprFakeHub.SchemaCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FSchemaBodies.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TExprFakeHub.SchemaBody(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    if (AIndex >= 0) and (AIndex < FSchemaBodies.Count) then
      Result := FSchemaBodies[AIndex]
    else
      Result := '';
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TExprFakeHub.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P, LPrompt: string;
  LBody: TJSONObject;
  LQuery: TJSONValue;
  LFix: Boolean;
  LEvents: array of string;
  I: Integer;
begin
  P := ARequest.PathInfo;
  LBody := ParseObject(ARequest.Content);
  try
    if P = '/api/userprofile/status' then
    begin
      if Pos('Bearer tokE', ARequest.Authorization) = 1 then
        SendJson(AResponse, 200, '{"profile":' + ProfileJson + ',"tiers":' + TiersJson + '}')
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/Login/email' then
    begin
      if JsonText(LBody, 'emailCode') = '654321' then
        SendJson(AResponse, 200, '{"token":"tokE","profile":' + ProfileJson +
          ',"tiers":' + TiersJson + '}')
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/LoginResend/send' then
      SendJson(AResponse, 200, '{}')
    else if P = '/api/agent/databases' then
      SendJson(AResponse, 200, '{"databases":[],"aiEndpoints":[]}')
    else if P = '/api/agent/testconnection' then
      SendJson(AResponse, 200, '{"success":true,"message":"Connected"}')
    else if P = '/api/agent/execute' then
      // The Agent dataset does not open: its columns come from the schema
      SendJson(AResponse, 200, '{"success":false,"error":"Agent offline"}')
    else if P = '/api/agent/gettableschema' then
    begin
      EnterCriticalSection(FLock);
      try
        FSchemaBodies.Add(ARequest.Content + ' apikey=' +
          ARequest.CustomHeaders.Values['X-Reportman-ApiKey']);
      finally
        LeaveCriticalSection(FLock);
      end;
      SendJson(AResponse, 200, SchemaAnswer);
    end
    else if (P = '/ReportmanExpression/SuggestExpressionStream') and
      (Pos('Bearer tokE', ARequest.Authorization) <> 1) then
      SendJson(AResponse, 401, '{"error":"Login required"}')
    else if P = '/ReportmanExpression/SuggestExpressionStream' then
    begin
      EnterCriticalSection(FLock);
      try
        FSuggestBodies.AddObject(ARequest.Content, TStringList.Create);
        TStringList(FSuggestBodies.Objects[FSuggestBodies.Count - 1]).Add(
          'authorization=' + ARequest.Authorization);
      finally
        LeaveCriticalSection(FLock);
      end;
      LPrompt := '';
      LQuery := LBody.GetValue('userQuery');
      if (LQuery is TJSONArray) and (TJSONArray(LQuery).Count > 0) then
        LPrompt := TJSONArray(LQuery).Items[0].Value;
      LFix := JsonText(LBody, 'fix') = 'true';
      if LPrompt = 'slow' then
      begin
        SetLength(LEvents, 60);
        for I := 0 to High(LEvents) do
          LEvents[I] := ProgressEvent('Partial', 'x' + IntToStr(I) + ' ', 's1');
        SendEvents(AResponse, LEvents, 100, True, True);
        Exit;
      end;
      SetLength(LEvents, 3);
      if LPrompt = 'fail' then
      begin
        SetLength(LEvents, 1);
        LEvents[0] := '{"errorMessage":"No credits left"}';
      end
      else if LPrompt = 'empty' then
      begin
        SetLength(LEvents, 1);
        LEvents[0] := '{"result":{"expression":"","explanation":""},"errorMessage":""}';
      end
      else if LPrompt = 'fixme' then
      begin
        LEvents[0] := ProgressEvent('Partial', 'UPPERCASE(', 'f1');
        if LFix then
        begin
          LEvents[1] := ProgressEvent('End', 'CLIENTS.NAME)', 'f1');
          LEvents[2] := ExpressionResult('UPPERCASE(CLIENTS.NAME)', 'Closed the parenthesis');
        end
        else
        begin
          LEvents[1] := ProgressEvent('End', 'CLIENTS.NAME', 'f1');
          LEvents[2] := ExpressionResult('UPPERCASE(CLIENTS.NAME', 'First try');
        end;
      end
      else if LPrompt = 'broken' then
      begin
        LEvents[0] := ProgressEvent('Partial', 'CLIENTS', 'b1');
        LEvents[1] := ProgressEvent('End', '.NAME +', 'b1');
        LEvents[2] := ExpressionResult('CLIENTS.NAME +', 'Best effort');
      end
      else
      begin
        LEvents[0] := ProgressEvent('Partial', 'UPPERCASE(', 'v1');
        LEvents[1] := ProgressEvent('End', 'CLIENTS.NAME)', 'v1');
        LEvents[2] := ExpressionResult('UPPERCASE(CLIENTS.NAME)', 'Upper case name');
      end;
      SendEvents(AResponse, LEvents, 30, True, True);
    end
    else if P = '/api/Tiers' then
      SendJson(AResponse, 200, TiersJson)
    else
      SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
  finally
    LBody.Free;
  end;
end;

{ TAIExprTests }

constructor TAIExprTests.Create(const AShotsDir: string);
begin
  inherited Create;
  FShotsDir := AShotsDir;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 40;
end;

destructor TAIExprTests.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TAIExprTests.Pump(AMs: Cardinal);
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

procedure TAIExprTests.WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
  const AWhat: string; ADialog: TFRpExpreDialogLCL);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  while not ACondition() do
  begin
    if GetTickCount64 - LStart > ATimeoutMs then
    begin
      if (ADialog <> nil) and (ADialog.Chat <> nil) then
      begin
        Log('  diag: busy=' + BoolToStr(ADialog.Chat.Busy, True) + ' refreshing=' +
          BoolToStr(ADialog.RefreshRunning, True) + ' workers=' +
          IntToStr(RpAsyncActiveWorkers));
        Log('  diag AI log:' + LineEnding + ADialog.Chat.LogView.PlainText);
        Log('  diag chat:' + LineEnding + ADialog.Chat.ConversationText);
      end;
      Fail('timeout waiting for ' + AWhat);
    end;
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  end;
  Pass(AWhat);
end;

procedure TAIExprTests.Shot(AControl: TWinControl; const AName: string);
begin
  Capture(AControl, AName, False);
end;

procedure TAIExprTests.ScreenShot(AControl: TWinControl; const AName: string);
begin
  // PaintTo does not paint the WebView2 windows: their CapturePreview is
  // drawn over them
  Capture(AControl, AName, True);
end;

procedure TAIExprTests.Capture(AControl: TWinControl; const AName: string;
  APasteWebViews: Boolean);
var
  LBitmap: TBitmap;
  LPng, LWebPng: TPortableNetworkGraphic;
  LStream: TMemoryStream;
  LOrigin: TPoint;
  LSize: TPoint;
{$IFDEF MSWINDOWS}
  R: TRect;
{$ENDIF}

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
          P := LWeb.ClientToScreen(Point(0, 0));
          P := Point(P.X - LOrigin.X, P.Y - LOrigin.Y);
          LBitmap.Canvas.StretchDraw(Rect(P.X, P.Y, P.X + LWeb.Width, P.Y + LWeb.Height), LWebPng);
        end;
      end
      else
        PasteWebViews(TWinControl(AParent.Controls[I]));
    end;
  end;

begin
  if FShotsDir = '' then
    Exit;
  Pump(300);
  // The image of PaintTo starts at the client area, except for a form on
  // Windows (the whole window with its title bar)
  LOrigin := AControl.ClientToScreen(Point(0, 0));
  LSize := Point(AControl.Width, AControl.Height);
{$IFDEF MSWINDOWS}
  R := Rect(0, 0, 0, 0);
  if (AControl is TCustomForm) and (GetWindowRect(AControl.Handle, R) <> 0) then
  begin
    LOrigin := R.TopLeft;
    LSize := Point(R.Right - R.Left, R.Bottom - R.Top);
  end;
{$ENDIF}
  LBitmap := TBitmap.Create;
  LPng := TPortableNetworkGraphic.Create;
  LWebPng := TPortableNetworkGraphic.Create;
  LStream := TMemoryStream.Create;
  try
    LBitmap.SetSize(LSize.X, LSize.Y);
    LBitmap.Canvas.Brush.Color := clWhite;
    LBitmap.Canvas.FillRect(Rect(0, 0, LBitmap.Width, LBitmap.Height));
    AControl.PaintTo(LBitmap.Canvas, 0, 0);
    if APasteWebViews then
      PasteWebViews(AControl);
    LPng.Assign(LBitmap);
    LPng.SaveToFile(IncludeTrailingPathDelimiter(FShotsDir) + AName + '.png');
    if APasteWebViews then
      Log('  screenshot ' + AName + '.png (with WebView2)')
    else
      Log('  screenshot ' + AName + '.png');
  finally
    LStream.Free;
    LWebPng.Free;
    LPng.Free;
    LBitmap.Free;
  end;
end;

procedure TAIExprTests.ScriptTick(Sender: TObject);
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

procedure TAIExprTests.StartScript(AScript: TNotifyEvent);
begin
  FDialog := nil;
  FStep := 0;
  FStepStart := GetTickCount64;
  FScript := AScript;
  FTimer.OnTimer := ScriptTick;
  FTimer.Enabled := True;
end;

procedure TAIExprTests.StopScript;
begin
  FTimer.Enabled := False;
  FScript := nil;
  FDialog := nil;
end;

procedure TAIExprTests.LoginWithCode;
begin
  Check(TRpAuthManager.Instance.LoginWithCode('eva@example.com', '654321'),
    'login with the email code (fake Hub)');
  Pump(50);
  Check(TRpAuthManager.Instance.IsLoggedIn, 'Hub session open');
end;

procedure TAIExprTests.WriteTestData;
var
  LText: TStringList;
begin
  FDataDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
    'exprtest';
  ForceDirectories(FDataDir);
  LText := TStringList.Create;
  try
    // A MyBase (MIDAS XML) dataset: opens without a database server
    LText.Add('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    LText.Add('<DATAPACKET Version="2.0"><METADATA><FIELDS>' +
      '<FIELD attrname="ID" fieldtype="i4"/>' +
      '<FIELD attrname="NAME" fieldtype="string" WIDTH="30"/>' +
      '<FIELD attrname="BALANCE" fieldtype="r8"/>' +
      '</FIELDS><PARAMS/></METADATA><ROWDATA>' +
      '<ROW ID="1" NAME="Ana" BALANCE="10.5"/>' +
      '<ROW ID="2" NAME="Pau" BALANCE="-2"/>' +
      '</ROWDATA></DATAPACKET>');
    FClientsFile := IncludeTrailingPathDelimiter(FDataDir) + 'clients.xml';
    LText.SaveToFile(FClientsFile);
    // Connection of the Agent dataset (the report points to these files
    // with its DBXCONNECTIONS / DBXDRIVERS parameters)
    LText.Clear;
    LText.Add('[EXPRHUB]');
    LText.Add('ApiKey=expr-key');
    LText.Add('HubDatabaseId=91');
    FConnectionsFile := IncludeTrailingPathDelimiter(FDataDir) + 'dbxconnections.ini';
    LText.SaveToFile(FConnectionsFile);
    LText.Clear;
    LText.Add('[Installed Drivers]');
    FDriversFile := IncludeTrailingPathDelimiter(FDataDir) + 'dbxdrivers.ini';
    LText.SaveToFile(FDriversFile);
  finally
    LText.Free;
  end;
end;

function TAIExprTests.CreateReport: TRpReport;
var
  LParam: TRpParam;
  LDb: TRpDatabaseInfoItem;
  LData: TRpDataInfoItem;
begin
  Result := TRpReport.Create(nil);
  Result.AddSubReport;
  LParam := Result.Params.Add('DBXCONNECTIONS');
  LParam.ParamType := rpParamString;
  LParam.Value := FConnectionsFile;
  LParam := Result.Params.Add('DBXDRIVERS');
  LParam.ParamType := rpParamString;
  LParam.Value := FDriversFile;
  LParam := Result.Params.Add('MINBALANCE');
  LParam.ParamType := rpParamDouble;
  LParam.Value := 5.0;
  LParam.Description := 'Minimum balance';
  LParam.Datasets.Add('CLIENTS');

  LDb := Result.DatabaseInfo.Add('LOCALXML');
  LDb.Driver := rpdatamybase;
  LDb.LoadParams := False;
  LDb := Result.DatabaseInfo.Add('EXPRHUB');
  LDb.Driver := rpdbHttp;
  LDb.LoadParams := True;

  LData := Result.DataInfo.Add('CLIENTS');
  LData.DatabaseAlias := 'LOCALXML';
  LData.MyBaseFilename := FClientsFile;
  LData := Result.DataInfo.Add('ORDERS');
  LData.DatabaseAlias := 'EXPRHUB';
  LData.SQL := 'SELECT * FROM ORDERS';
end;

function TAIExprTests.NewDialog(AReport: TRpReport;
  const AExpression: string): TFRpExpreDialogLCL;
begin
  Result := TFRpExpreDialogLCL.Create(nil);
  Result.Position := poDesigned;
  Result.SetBounds(30, 30, Result.Width, Result.Height);
  Result.InitializeDialog(AExpression, TRpEvaluator.Create(nil), True, False, True);
  Result.ConfigureReportRefresh(AReport, nil, nil);
end;

// Sends a prompt as the user does and waits for the end of the request
function TAIExprTests.SendPrompt(ADialog: TFRpExpreDialogLCL;
  const APrompt: string): Boolean;

  function Finished: Boolean;
  begin
    Result := not ADialog.Chat.Busy;
  end;

begin
  ADialog.Chat.MemoPrompt.Text := APrompt;
  Check(ADialog.Chat.BSend.Enabled, 'Send enabled with the prompt "' + APrompt + '"');
  ADialog.Chat.BSendClick(nil);
  Check(ADialog.Chat.Busy, 'busy while "' + APrompt + '" streams');
  WaitUntil(Finished, 15000, 'request "' + APrompt + '" finished', ADialog);
  Result := RpAsyncWaitIdle(10000);
  Check(Result, 'worker of "' + APrompt + '" finished');
end;

procedure TAIExprTests.TestNoSession;
var
  LDia: TFRpExpreDialogLCL;
  LExternal: TRpEvaluator;
  LError: string;
  LValid, LInvalid: Boolean;
begin
  Section('Expression editor without a Hub session');
  Check(not TRpAuthManager.Instance.IsLoggedIn, 'no Hub session');
  FHubHandler.Clear;
  LDia := TFRpExpreDialogLCL.Create(nil);
  try
    LDia.InitializeDialog('1 + 2', TRpEvaluator.Create(nil), True, False, True);
    LDia.ConfigureReportRefresh(nil, nil, nil);
    LDia.Show;
    Pump(200);
    Check(LDia.Chat <> nil, 'chat in the expression editor');
    Check(not LDia.Chat.ShowSchemaSelector and not LDia.Chat.PSchemaHost.Visible,
      'no schema selector (as the VCL)');
    Check(not LDia.RefreshButton.Visible, 'no Refresh button without a report');
    CheckEquals(T(1498, 'Guest (Login available)'), LDia.Chat.LoginFrame.LabelUser.Caption,
      'the account card offers the login');
    Check(LDia.Chat.LoginFrame.MenuItemLogin.Visible, 'login item in the account menu');
    CheckContains(T(1600, SExpressionChatInitialMessage), LDia.Chat.ConversationText,
      'initial message of the assistant');
    Check(not LDia.Chat.BApply.Enabled, 'Apply disabled without a suggestion');

    // The classic editor
    LValid := LDia.ValidateExpressionText('1 + 2', LError);
    Check(LValid, 'valid expression');
    LInvalid := not LDia.ValidateExpressionText('1 +', LError);
    Check(LInvalid and (LError <> ''), 'invalid expression: ' + LError);
    CheckEquals('1 + 2', LDia.MemoExpre.Text, 'validation keeps the memo');
    LDia.CategoryList.ItemIndex := 1;
    LDia.LCategoryClick(nil);
    LDia.OperationList.ItemIndex := LDia.OperationList.Items.IndexOf('UPPERCASE');
    Check(LDia.OperationList.ItemIndex >= 0, 'UPPERCASE in the functions');
    LDia.MemoExpre.SelStart := 0;
    LDia.MemoExpre.SelLength := 0;
    LDia.BAddClick(nil);
    CheckEquals('UPPERCASE1 + 2', LDia.MemoExpre.Text,
      'Add selection inserts the name at the cursor');
    LDia.MemoExpre.Text := '1 + 2';

    // The Hub refuses the prompt without a session: an error in the chat
    SendPrompt(LDia, 'valid');
    CheckContains('401', LDia.Chat.LastAssistantMessage, 'error of the Hub in the chat');
    CheckEquals('', LDia.Chat.SuggestedExpression, 'no suggestion');
    CheckEquals('1 + 2', LDia.MemoExpre.Text, 'the expression is not touched');
    CheckEquals(0, FHubHandler.SuggestCount, 'nothing answered without a session');
    LDia.BOKClick(nil);
    Check(LDia.DoOk, 'OK accepted');

    // An evaluator set by the caller replaces (and frees) the owned one and
    // is not freed with the dialog
    LExternal := TRpEvaluator.Create(nil);
    try
      Check(LDia.OwnsEvaluator, 'the dialog owns the evaluator of InitializeDialog');
      LDia.Evaluator := LExternal;
      Check(not LDia.OwnsEvaluator, 'an evaluator of the caller is not owned');
      Check(LDia.HelpList(1).IndexOf('UPPERCASE') >= 0, 'lists of the new evaluator');
      FreeAndNil(LDia);
      LExternal.Expression := '1 + 1';
      LExternal.Evaluate;
      CheckEquals('2', LExternal.EvalResultString, 'the evaluator of the caller survives the dialog');
    finally
      LExternal.Free;
    end;
  finally
    LDia.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAIExprTests.TestUnreachable;
var
  LDia: TFRpExpreDialogLCL;
  LError: string;
  LStart: QWord;
begin
  // A closed local port. On Windows FPC 3.2.2 waits for the whole connect
  // timeout (60 s) on a refused connection (ssockets passes no except set to
  // select); on Linux the request fails at once. The dialog must not wait.
  Section('Expression editor with the Hub unreachable');
  RpHttpSetUrlRewrite(HUB_API_URL, 'http://127.0.0.1:9');
  try
    LDia := NewDialog(nil, 'CLIENTS.NAME');
    try
      LDia.Show;
      Pump(100);
      LDia.Chat.MemoPrompt.Text := 'valid';
      LDia.Chat.BSendClick(nil);
      Check(LDia.Chat.Busy, 'busy while the request tries to connect');
      Pump(300);
      // The classic editor keeps working meanwhile
      LDia.MemoExpre.Text := '2 * 3';
      Check(LDia.ValidateExpressionText(LDia.MemoExpre.Text, LError),
        'the evaluator works while the request is pending');
      if LDia.Chat.Busy then
      begin
        LDia.Chat.BClearClick(nil);
        Check(not LDia.Chat.Busy, 'Stop frees the chat at once');
        CheckContains(T(1536, 'Generation stopped.'), LDia.Chat.ConversationText,
          'stop message');
      end
      else
        Check(LDia.Chat.LastAssistantMessage <> '', 'connection error in the chat: ' +
          LDia.Chat.LastAssistantMessage);
      LStart := GetTickCount64;
    finally
      LDia.Free;
    end;
    Check(ElapsedMs(LStart) < 1000, 'closing does not wait for the request');
    LStart := GetTickCount64;
    Check(RpAsyncWaitIdle(90000), 'the request ends');
    Log(Format('  the connection to the closed port failed after %d ms', [ElapsedMs(LStart)]));
  finally
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
  end;
end;

procedure TAIExprTests.TestRefreshAndContext;
var
  LDia: TFRpExpreDialogLCL;
  LFields: TStrings;
  LContext: TJSONObject;
  LBlocks, LFunctions, LConstants: TJSONArray;
  LText: string;
  I: Integer;

  function Refreshed: Boolean;
  begin
    Result := (not LDia.RefreshRunning) and LDia.AliasReady;
  end;

  function ArrayText(AArray: TJSONArray): string;
  begin
    if AArray = nil then
      Result := ''
    else
      Result := AArray.ToJSON;
  end;

begin
  Section('Expression editor with a report: dataset refresh and semantic context');
  FHubHandler.Clear;
  LDia := NewDialog(FReport, 'CLIENTS.NAME');
  try
    Check(LDia.RefreshButton.Visible, 'Refresh button with a report');
    Check(not LDia.AliasReady, 'fields pending until the refresh');
    LDia.Show;
    Check(LDia.RefreshRunning, 'the datasets open in the background when shown');
    CheckEquals(T(1609, 'Refreshing...'), LDia.RefreshButton.Caption, 'Refreshing caption');
    WaitUntil(Refreshed, 20000, 'dataset refresh', LDia);
    CheckEquals(T(1149, 'Refresh'), LDia.RefreshButton.Caption, 'Refresh caption again');
    Check(not LDia.OwnsEvaluator, 'the dialog uses the report evaluator after the refresh');
    Check(LDia.Evaluator = FReport.Evaluator, 'report evaluator');
    Check(FReport.DataInfo.Items[0].Dataset.Active, 'CLIENTS (MyBase) is open');

    // Agent dataset: columns from the Hub
    CheckEquals(1, FHubHandler.SchemaCount, 'schema of the Agent dataset asked to the Hub');
    CheckContains('"sql":"SELECT * FROM ORDERS"', FHubHandler.SchemaBody(0), 'schema request sql');
    CheckContains('"hubDatabaseId":91', FHubHandler.SchemaBody(0), 'schema request database');
    CheckContains('apikey=expr-key', FHubHandler.SchemaBody(0), 'schema request API key');
    CheckEquals(3, LDia.SchemaOnlyFields.Count, 'three columns of ORDERS');
    CheckEquals('ORDERS', SchemaFieldEntryAlias(LDia.SchemaOnlyFields[1]), 'entry alias');
    CheckEquals('TOTAL', SchemaFieldEntryFieldName(LDia.SchemaOnlyFields[1]), 'entry field');
    CheckEquals('float', SchemaFieldEntryDataType(LDia.SchemaOnlyFields[1]), 'System.Decimal -> float');

    // Field list of the classic editor
    LFields := LDia.HelpList(0);
    for I := Low(ReportFields) to High(ReportFields) do
      Check(LFields.IndexOf(ReportFields[I]) >= 0, 'field ' + ReportFields[I] + ' in the list');
    I := LFields.IndexOf('ORDERS.TOTAL');
    CheckEquals(T(1611, 'Field from dataset') + ' ORDERS', TRpRecHelp(LFields.Objects[I]).Help,
      'help of an Agent column');
    CheckEquals('ORDERS.TOTAL:float', TRpRecHelp(LFields.Objects[I]).Model, 'model of an Agent column');
    Check(LDia.ValidateExpressionText('UPPERCASE(CLIENTS.NAME)', LText),
      'a field of the report validates');
    Check(not LDia.ValidateExpressionText('UPPERCASE(CLIENTS.NAME', LText),
      'a broken expression does not');

    // Semantic context (the one sent with a prompt)
    LContext := ParseObject(LDia.BuildExpressionSemanticContextJson);
    try
      LBlocks := LContext.GetValue('datasetColumnsBlocks') as TJSONArray;
      Check(LBlocks <> nil, 'datasetColumnsBlocks');
      CheckEquals(2, LBlocks.Count, 'a block per dataset');
      CheckEquals('[DATASET_COLUMNS CLIENTS columns]' + sLineBreak + 'ID:integer' + sLineBreak +
        'NAME:string' + sLineBreak + 'BALANCE:float' + sLineBreak + '[/DATASET_COLUMNS]',
        LBlocks.Items[0].Value, 'live columns of CLIENTS');
      CheckEquals('[DATASET_COLUMNS ORDERS columns]' + sLineBreak + 'ID:integer' + sLineBreak +
        'TOTAL:float' + sLineBreak + 'ORDERDATE:datetime' + sLineBreak + '[/DATASET_COLUMNS]',
        LBlocks.Items[1].Value, 'Agent columns of ORDERS');
      CheckEquals('[MEMORY_VARIABLES]' + sLineBreak + 'M.DBXCONNECTIONS:string' + sLineBreak +
        'M.DBXDRIVERS:string' + sLineBreak + 'M.MINBALANCE:float' + sLineBreak +
        '[/MEMORY_VARIABLES]', JsonText(LContext, 'memoryVariablesBlock'), 'report parameters');
      LFunctions := LContext.GetValue('functions') as TJSONArray;
      LConstants := LContext.GetValue('constants') as TJSONArray;
      CheckContains('{"model":"function Uppercase(s:string):string","help":' +
        '"Converts a string to uppercase, input type must be string"}', ArrayText(LFunctions),
        'functions with their AI help');
      CheckContains('"help":"Literal identifier for true boolean value"', ArrayText(LConstants),
        'constants with their AI help');
      CheckContains('{"model":"M.PAGE","help":"Global page number"}', ArrayText(LFunctions),
        'report variables with an AI help (as the VCL)');
      Check(Pos('FREE_SPACE', ArrayText(LFunctions) + ArrayText(LConstants)) = 0,
        'identifiers without an AI help are not sent');
    finally
      LContext.Free;
    end;

    // Refresh again with the button
    LDia.BRefreshClick(nil);
    Check(LDia.RefreshRunning and LDia.OwnsEvaluator,
      'Refresh reopens the datasets with a copy of the evaluator meanwhile');
    Check(LDia.HelpList(1).IndexOf('UPPERCASE') >= 0, 'functions available during the refresh');
    WaitUntil(Refreshed, 20000, 'second refresh', LDia);
    CheckEquals(2, FHubHandler.SchemaCount, 'schema asked again');
    // The fields category with a column of the Agent dataset selected
    LDia.CategoryList.ItemIndex := 0;
    LDia.LCategoryClick(nil);
    LDia.OperationList.ItemIndex := LDia.OperationList.Items.IndexOf('ORDERS.TOTAL');
    LDia.LOperationClick(nil);
    Shot(LDia, 'expression_editor_fields');
  finally
    LDia.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAIExprTests.TestPrompts;
var
  LDia: TFRpExpreDialogLCL;
  LBody, LContext: TJSONObject;
  LText: string;

  function Refreshed: Boolean;
  begin
    Result := (not LDia.RefreshRunning) and LDia.AliasReady;
  end;

begin
  Section('Expression assistant: prompt, stream, validation, Apply');
  FHubHandler.Clear;
  LDia := NewDialog(FReport, 'CLIENTS.NAME');
  try
    LDia.Show;
    WaitUntil(Refreshed, 20000, 'dataset refresh', LDia);
    Pump(100);
    CheckEquals('Eva', LDia.Chat.LoginFrame.LabelUser.Caption, 'account card with the session');

    // 1. Valid answer
    LDia.MemoExpre.SelStart := 3;
    LDia.MemoExpre.SelLength := 0;
    LDia.MemoExpre.OnClick(LDia.MemoExpre);
    SendPrompt(LDia, 'valid');
    CheckEquals(1, FHubHandler.SuggestCount, 'one request');
    CheckEquals('UPPERCASE(CLIENTS.NAME)', LDia.Chat.SuggestedExpression, 'suggested expression');
    CheckContains('Upper case name', LDia.Chat.ConversationText, 'explanation in the chat');
    CheckContains(T(1538, 'Suggested expression') + ':', LDia.Chat.ConversationText,
      'suggestion in the chat');
    CheckContains('UPPERCASE(', LDia.Chat.LogView.PlainText, 'stream in the AI log');
    Check(LDia.Chat.BApply.Enabled, 'Apply enabled');
    CheckEquals(310, TRpAuthManager.Instance.Profile.DailyConsumed,
      'profile of the answer applied (credits)');
    LBody := ParseObject(FHubHandler.SuggestBody(0));
    try
      CheckEquals('["valid"]', LBody.GetValue('userQuery').ToJSON, 'prompt sent');
      CheckEquals('CLIENTS.NAME', JsonText(LBody, 'currentExpression'), 'current expression sent');
      CheckEquals('3', JsonText(LBody, 'cursorPosition'), 'cursor position sent');
      CheckEquals('false', JsonText(LBody, 'fix'), 'first request is not a fix');
      CheckEquals(LDia.Chat.GetAIMode, JsonText(LBody, 'mode'), 'mode of the model selection');
      CheckEquals(LDia.Chat.GetAITier, JsonText(LBody, 'aiTier'), 'tier of the model selection');
      LContext := ParseObject(JsonText(LBody, 'semanticContextJson'));
      try
        CheckContains('[DATASET_COLUMNS CLIENTS columns]', LContext.GetValue('datasetColumnsBlocks').ToJSON,
          'context sent: live columns');
        CheckContains('TOTAL:float', LContext.GetValue('datasetColumnsBlocks').ToJSON,
          'context sent: Agent columns');
        CheckContains('M.MINBALANCE:float', JsonText(LContext, 'memoryVariablesBlock'),
          'context sent: parameters');
        CheckContains('function Uppercase(s:string):string', LContext.GetValue('functions').ToJSON,
          'context sent: functions');
      finally
        LContext.Free;
      end;
    finally
      LBody.Free;
    end;
    CheckContains('authorization=Bearer tokE', FHubHandler.SuggestHeaders(0), 'session token sent');
    LDia.Chat.BApplyClick(nil);
    CheckEquals('UPPERCASE(CLIENTS.NAME)', LDia.MemoExpre.Text, 'Apply replaces the expression');

    // 2. Invalid, then fixed by the automatic retry
    FHubHandler.Clear;
    SendPrompt(LDia, 'fixme');
    CheckEquals(2, FHubHandler.SuggestCount, 'invalid answer: one automatic fix');
    LBody := ParseObject(FHubHandler.SuggestBody(1));
    try
      CheckEquals('true', JsonText(LBody, 'fix'), 'the retry asks for a fix');
      CheckEquals('UPPERCASE(CLIENTS.NAME', JsonText(LBody, 'currentExpression'),
        'the retry sends the invalid expression');
    finally
      LBody.Free;
    end;
    LText := LDia.Chat.ConversationText;
    CheckContains(T(1601, 'Local validation failed. Running one automatic fix.'), LText,
      'retry announced');
    CheckContains(T(1604, 'Expression fixed after local validation.'), LText, 'fixed message');
    CheckContains('Closed the parenthesis', LText, 'explanation of the fix');
    CheckEquals('UPPERCASE(CLIENTS.NAME)', LDia.Chat.SuggestedExpression, 'fixed suggestion');

    // 3. Still invalid after the fix: suggested anyway
    FHubHandler.Clear;
    SendPrompt(LDia, 'broken');
    CheckEquals(2, FHubHandler.SuggestCount, 'still invalid: only one fix');
    LText := LDia.Chat.ConversationText;
    CheckContains(T(1602, 'Generated expression is still invalid after one automatic fix:'),
      LText, 'still invalid message');
    CheckContains(T(1603, 'You can still apply it and edit it manually.'), LText,
      'it can be applied anyway');
    CheckContains('Best effort', LText, 'explanation of the server');
    CheckEquals('CLIENTS.NAME +', LDia.Chat.SuggestedExpression, 'invalid suggestion kept');
    Check(LDia.Chat.BApply.Enabled, 'Apply enabled for the invalid suggestion');
    LDia.Chat.BApplyClick(nil);
    CheckEquals('CLIENTS.NAME +', LDia.MemoExpre.Text, 'applied to be edited');

    // 4. Errors of the server
    SendPrompt(LDia, 'fail');
    CheckEquals('No credits left', LDia.Chat.LastAssistantMessage, 'error of the server');
    CheckEquals('', LDia.Chat.SuggestedExpression, 'no suggestion after an error');
    Check(not LDia.Chat.BApply.Enabled, 'Apply disabled after an error');
    SendPrompt(LDia, 'empty');
    CheckEquals(T(1608, 'Empty expression returned'), LDia.Chat.LastAssistantMessage,
      'empty expression');
    CheckEquals('CLIENTS.NAME +', LDia.MemoExpre.Text, 'errors do not touch the expression');
    Shot(LDia, 'expression_editor_assistant');
  finally
    LDia.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAIExprTests.TestStop;
var
  LDia: TFRpExpreDialogLCL;
  LStart: QWord;
  LChunks: Integer;

  function Streaming2: Boolean;
  begin
    Result := Pos('x2 ', LDia.Chat.LogView.PlainText) > 0;
  end;

  function Streaming1: Boolean;
  begin
    Result := Pos('x1 ', LDia.Chat.LogView.PlainText) > 0;
  end;

begin
  Section('Expression assistant: Stop, dialog destroyed while streaming');
  LDia := NewDialog(nil, 'CLIENTS.NAME');
  try
    LDia.Show;
    LDia.Chat.MemoPrompt.Text := 'slow';
    LDia.Chat.BSendClick(nil);
    WaitUntil(Streaming2, 10000, 'the slow stream is running', LDia);
    CheckEquals(T(1522, 'Stop'), LDia.Chat.BClear.Caption, 'Clear becomes Stop');
    LDia.Chat.BClearClick(nil);
    Check(not LDia.Chat.Busy, 'Stop ends the busy state at once');
    CheckContains(T(1536, 'Generation stopped.'), LDia.Chat.ConversationText, 'stop message');
    LChunks := Length(LDia.Chat.LogView.PlainText);
    LStart := GetTickCount64;
    Check(RpAsyncWaitIdle(3000), 'the worker ends soon after the stop');
    Check(ElapsedMs(LStart) < 2500, Format('cancel is prompt (%d ms; the stream lasts 6 s)',
      [ElapsedMs(LStart)]));
    Pump(200);
    CheckEquals(LChunks, Length(LDia.Chat.LogView.PlainText), 'no chunk after the stop');
    CheckEquals('', LDia.Chat.SuggestedExpression, 'nothing suggested');

    // Destroyed while streaming: the worker stops and its messages are dropped
    LDia.Chat.MemoPrompt.Text := 'slow';
    LDia.Chat.BSendClick(nil);
    WaitUntil(Streaming1, 10000, 'second slow stream running', LDia);
  finally
    FreeAndNil(LDia);
  end;
  LStart := GetTickCount64;
  Check(RpAsyncWaitIdle(3000), 'worker of a destroyed dialog ends');
  Check(ElapsedMs(LStart) < 2500, 'and soon');
end;

procedure TAIExprTests.ModalScript(Sender: TObject);
begin
  if FDialog = nil then
  begin
    if Screen.ActiveCustomForm is TFRpExpreDialogLCL then
    begin
      FDialog := TFRpExpreDialogLCL(Screen.ActiveCustomForm);
      FStep := 0;
      FStepStart := GetTickCount64;
    end;
    Exit;
  end;
  if GetTickCount64 - FStepStart > 30000 then
    Fail('modal expression dialog script timed out at step ' + IntToStr(FStep));
  case FStep of
    0:
      if (not FDialog.RefreshRunning) and FDialog.AliasReady then
      begin
        Check(FDialog.HelpList(0).IndexOf('CLIENTS.NAME') >= 0,
          'fields of the report in the modal dialog');
        CheckEquals('CLIENTS.NAME', Trim(FDialog.MemoExpre.Text), 'expression of the component');
        FDialog.Chat.MemoPrompt.Text := 'valid';
        FDialog.Chat.BSendClick(nil);
        FStep := 1;
      end;
    1:
      if (not FDialog.Chat.Busy) and (FDialog.Chat.SuggestedExpression <> '') then
      begin
        Shot(FDialog, 'expression_dialog_modal');
        FDialog.Chat.BApplyClick(nil);
        FDialog.BOKClick(nil);
        FStep := 2;
      end;
  end;
end;

procedure TAIExprTests.TestModalExecute;
var
  LComp: TRpExpreDialogLCL;
  LResult: Boolean;
begin
  Section('TRpExpreDialogLCL.Execute with a report (object inspector path)');
  LComp := TRpExpreDialogLCL.Create(nil);
  try
    LComp.Report := FReport;
    LComp.Expression.Text := 'CLIENTS.NAME';
    StartScript(ModalScript);
    try
      LResult := LComp.Execute;
    finally
      StopScript;
    end;
    Check(LResult, 'Execute returns True after OK');
    CheckEquals('UPPERCASE(CLIENTS.NAME)', Trim(LComp.Expression.Text),
      'the applied suggestion is the new expression');
  finally
    LComp.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAIExprTests.TestDesignContext;
var
  LFields, LErrors, LOpenErrors: TStringList;
  LJson, LErrorMessage: string;
  LRoot: TJSONObject;
  LSources: TJSONArray;
  LOldAlias: TRpAlias;
begin
  Section('Context builders: Agent columns and design context');
  LFields := TStringList.Create;
  LErrors := TStringList.Create;
  LOpenErrors := TStringList.Create;
  try
    CollectAgentSchemaOnlyContext(FReport, LFields, LErrors);
    CheckEquals(3, LFields.Count, 'CollectAgentSchemaOnlyContext: three columns');
    CheckEquals(0, LErrors.Count, 'no schema errors');
    FReport.PrepareLiveContext(LOpenErrors);
    CheckContains('Agent offline', LOpenErrors.Values['ORDERS'], 'open error of the Agent dataset');
    LOldAlias := FReport.Evaluator.Rpalias;
    LJson := BuildDesignExpressionContextJson(FReport, nil, LOpenErrors, LFields, LErrors,
      LErrorMessage);
    CheckEquals('', LErrorMessage, 'no error');
    Check(FReport.Evaluator.Rpalias = LOldAlias,
      'the report evaluator keeps its alias (no alias freed under it)');
    LRoot := ParseObject(LJson);
    try
      CheckContains('M.MINBALANCE:float', LRoot.GetValue('expressionContext').ToJSON,
        'expression context of the report');
      LSources := LRoot.GetValue('runtimeDataSources') as TJSONArray;
      CheckEquals(2, LSources.Count, 'a runtime source per dataset');
      CheckContains('"status":"live_context","source":"delphi_evaluator"',
        LSources.Items[0].ToJSON, 'CLIENTS live');
      CheckContains('"status":"refresh_failed","source":"agent_schema_only"',
        LSources.Items[1].ToJSON, 'ORDERS failed to open, columns from the Hub');
      CheckContains('datasource_schema_failed', LSources.Items[1].ToJSON, 'issue of ORDERS');
      CheckContains('TOTAL:float', LSources.Items[1].ToJSON, 'Agent columns in the source');
    finally
      LRoot.Free;
    end;
  finally
    LOpenErrors.Free;
    LErrors.Free;
    LFields.Free;
  end;
end;

procedure TAIExprTests.TestWebView2Shot;
{$IFDEF MSWINDOWS}
var
  LDia: TFRpExpreDialogLCL;
  LSaved: Boolean;

  function Ready: Boolean;
  begin
    Result := (not LDia.RefreshRunning) and LDia.AliasReady and LDia.Chat.ChatView.Ready and
      LDia.Chat.LogView.Ready;
  end;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  // The editor as the Windows designer shows it (chat in WebView2)
  if FShotsDir = '' then
    Exit;
  Section('Screenshot of the expression editor with WebView2 (Windows)');
  LSaved := RpWebMarkdownForceNative;
  RpWebMarkdownForceNative := False;
  LDia := NewDialog(FReport, 'CLIENTS.NAME');
  try
    LDia.Show;
    WaitUntil(Ready, 30000, 'refresh and chat views ready', LDia);
    if not LDia.Chat.ChatView.UsingWebView then
      Skip('WebView2 not available here')
    else
    begin
      SendPrompt(LDia, 'valid');
      Pump(800);
      ScreenShot(LDia, 'expression_editor_webview2');
    end;
  finally
    LDia.Free;
    RpWebMarkdownForceNative := LSaved;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
{$ENDIF}
end;

procedure TAIExprTests.Run;
var
  LSandbox: string;
begin
  LSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rpaichattest', LSandbox) = 0 then
    Fail('the tests must run in the sandbox (LOCALAPPDATA=' + LSandbox + ')');
  WriteTestData;
  // Native viewer for the deterministic checks
  RpWebMarkdownForceNative := True;
  TRpAuthManager.Instance.Logout;
  Pump(50);

  FHubHandler := TExprFakeHub.Create;
  FHub := TFakeServer.Create(FHubHandler.Handle);
  try
    FHub.Start;
    Log('  fake Hub (expressions) on ' + FHub.BaseURL + ' for ' + HUB_API_URL);
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
    try
      TestNoSession;
      LoginWithCode;
      FReport := CreateReport;
      try
        TestRefreshAndContext;
        TestPrompts;
        TestStop;
        TestModalExecute;
        TestDesignContext;
        TestWebView2Shot;
      finally
        FreeAndNil(FReport);
      end;
      TestUnreachable;
      TRpAuthManager.Instance.Logout;
      Check(RpAsyncWaitIdle(10000), 'all workers finished');
    finally
      RpHttpSetUrlRewrite('', '');
    end;
  finally
    FHub.Free;
    FHubHandler.Free;
  end;
  Pump(100);
end;

procedure RunAIExprTests(const AShotsDir: string);
var
  LTests: TAIExprTests;
begin
  LTests := TAIExprTests.Create(AShotsDir);
  try
    LTests.Run;
  finally
    LTests.Free;
  end;
end;

end.

{ Phase 7.3 tests: the SQL assistant of the LCL designer against a local
  fake Hub (no external network).

  Covers the SQL completion engine (tables after FROM/JOIN, columns after an
  alias, UTF-16 offsets of Monaco), the schema tables loaded from
  api/agent/databases, the Monaco bridge of TFRpMonacoEditorLCL driven
  without WebView2 (00:/01:/02:/03: messages and the scripts it answers
  with, AI completions superseded and cancelled), the SynEdit fallback editor
  (highlighter tables, completion popup, accepting an item, undoable apply,
  theme), the AI inline completion of the fallback editor (a comment turned
  into SQL: request after the debounce with the UTF-16 caret offset, ghost
  text, Tab, Esc, dismissed by typing or moving the caret, stale answers,
  AI disabled), the SQL assistant of the data configuration dialog (a prompt
  streamed and applied to the editor and the working copy, an error, Stop,
  the audit, the schema of the dataset, OK recorded in the undo cue) and, on
  Windows, the real Monaco page in WebView2 (injected completion provider,
  AI completion round trip, screenshots). }
unit uaisqltests;

{$mode delphi}{$H+}
{$modeswitch nestedprocvars}

interface

// AShotsDir: screenshots are saved there when not empty
procedure RunAISqlTests(const AShotsDir: string);

implementation

uses
  SysUtils, Classes, Types, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, LCLType, LCLIntf, fphttpserver, httpdefs, SynEdit, SynCompletion,
  SynHighlighterSQL, SynEditKeyCmds,
  rpjsonfpc, rphttpclientfpc, rptypes, rpdatainfo, rpreport, rpauthmanager,
  rpaithreadslcl, rpwebmarkdownlcl, rpfrmchatlcl, rpfrmmonacoeditorlcl,
  rpmdfdinfolcl, rpmdundocuelcl, rplclwebview, rpmdconsts, utestutil, ufakeserver;

const
  BS = #92; // backslash
  SUGGESTED_SQL = 'SELECT NAME, BALANCE FROM CLIENTS WHERE BALANCE > 1000';
  // Inline completion for a comment of the fallback editor
  COMMENT_SQL1 = 'SELECT NAME, BALANCE';
  COMMENT_SQL2 = 'FROM CLIENTS';
  COMMENT_SQL3 = 'WHERE BALANCE > 1000';
  AUDIT_TEXT = 'Lists the clients with their balance.';

type
  TCondition = function: Boolean is nested;

  { TSqlFakeHub: canned answers of the Hub endpoints of the SQL assistant }

  TSqlFakeHub = class
  public
    TranslateCalls: Integer;
    SuggestCalls: Integer;
    ExplainCalls: Integer;
    LastTranslateBody: string;
    LastSuggestBody: string;
    LastExplainBody: string;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
  end;

  { TAISqlTests }

  TAISqlTests = class
  private
    FShotsDir: string;
    FHub: TFakeServer;
    FHubHandler: TSqlFakeHub;
    FScripts: TStringList;
    FContentChanges: Integer;
    FSchemaTablesLoaded: Integer;
    FWebMessages: TStringList;
    procedure Pump(AMs: Cardinal);
    procedure WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal; const AWhat: string);
    function NewForm(AWidth, AHeight: Integer): TForm;
    procedure Shot(AControl: TWinControl; const AName: string);
    procedure ScreenShot(AControl: TWinControl; const AName: string);
    function LastScript(const AContains: string): string;
    function NewReport: TRpReport;
    // Events
    procedure EditorScript(Sender: TObject; const AScript: string);
    procedure EditorContentChanged(Sender: TObject);
    procedure EditorSchemaTablesLoaded(Sender: TObject);
    procedure EditorWebMessage(Sender: TObject; const AMessage: string);
    // Tests
    procedure TestEngine;
    procedure TestMonacoBridge;
    procedure TestFallbackEditor;
    procedure TestFallbackAISuggestion;
    procedure TestDataDialog;
    procedure TestWebView2;
  public
    constructor Create(const AShotsDir: string);
    destructor Destroy; override;
    procedure Run;
  end;

{ Fake Hub }

function ProfileJson: string;
begin
  Result := '{"userId":7,"email":"ana@example.com","userName":"Ana",' +
    '"profileImageUrl":"","accountType":1,"tierId":4,' +
    '"tierName":"Pro","dailyMax":1000,"dailyConsumed":250,"freeInitial":100,' +
    '"freeRemaining":40,"serverDay":"2026-09-27T00:00:00Z","credits":5}';
end;

function TiersJson: string;
begin
  Result := '[{"id":1,"name":"Free","monthlyPrice":0,"yearlyPrice":0,"maxCreditsDay":10,' +
    '"maxFreeCredits":100,"maxConnections":1,"maxTables":10,"maxColumnsPerTable":20,"maxKpis":1}]';
end;

function SalesTablesJson: string;
begin
  // The schemaTables the user defined on app.reportman.es (dataType as the
  // JsonStringEnumConverter of the Hub writes it; one old numeric answer)
  Result := '[{"name":"CLIENTS","context":"Customers","columns":[' +
    '{"name":"ID","dataType":"Integer","isPrimaryKey":true},' +
    '{"name":"NAME","dataType":"String","isPrimaryKey":false},' +
    '{"name":"BALANCE","dataType":"Currency"},' +
    '{"name":"CITY","dataType":"String"}],"foreignKeys":[]},' +
    '{"name":"ORDERS","context":"","columns":[' +
    '{"name":"ORDER_ID","dataType":"Integer","isPrimaryKey":true},' +
    '{"name":"CLIENT_ID","dataType":4,"detectedType":"System.Int64"},' +
    '{"name":"TOTAL","dataType":"Numeric"},' +
    '{"name":"ORDER_DATE","dataType":"Date"}],' +
    '"foreignKeys":[{"targetTable":"CLIENTS","sourceColumns":["CLIENT_ID"],"targetColumns":["ID"]}]}]';
end;

function ArchiveTablesJson: string;
begin
  Result := '[{"name":"OLD_ORDERS","columns":[{"name":"YEAR","dataType":"Integer"}]}]';
end;

function ProgressEvent(const AChunkType, AChunk, AId: string): string;
begin
  Result := '{"actor":"AI","stage":"ReceivingResponse","chunkType":"' + AChunkType +
    '","chunk":"' + AChunk + '","id":"' + AId + '","inputTokens":120,"outputTokens":7,' +
    '"prefillPercentage":0}';
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

procedure TSqlFakeHub.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P, LApiKey, LContent: string;
  LBody: TJSONObject;
  LEvents: array of string;
  I: Integer;
begin
  P := ARequest.PathInfo;
  LContent := ARequest.Content;
  LBody := BodyJson(ARequest);
  try
    if P = '/api/userprofile/status' then
    begin
      if Pos('Bearer tok', ARequest.Authorization) = 1 then
        SendJson(AResponse, 200, '{"profile":' + ProfileJson + ',"tiers":' + TiersJson + '}')
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/Login/email' then
    begin
      if JsonText(LBody, 'emailCode') = '123456' then
        SendJson(AResponse, 200, '{"token":"tok123","profile":' + ProfileJson +
          ',"tiers":' + TiersJson + '}')
      else
        SendJson(AResponse, 401, '{}');
    end
    else if P = '/api/agent/databases' then
    begin
      LApiKey := ARequest.CustomHeaders.Values['X-Reportman-ApiKey'];
      if LApiKey = 'sql-key' then
        SendJson(AResponse, 200, '{"databases":[' +
          '{"displayName":"Sales - Main","name":"main","hubDatabaseId":77,"hubSchemaId":5,' +
          '"schemaTables":' + SalesTablesJson + '},' +
          '{"displayName":"Sales - Archive","name":"archive","hubDatabaseId":77,"hubSchemaId":8,' +
          '"schemaTables":' + ArchiveTablesJson + '}],"aiEndpoints":[]}')
      else if (LApiKey = '') and (Pos('Bearer tok', ARequest.Authorization) = 1) then
        SendJson(AResponse, 200, '{"databases":[' +
          '{"displayName":"Sales - Main","name":"main","hubDatabaseId":77,"hubSchemaId":5,' +
          '"schemaTables":' + SalesTablesJson + '},' +
          '{"displayName":"HR","name":"hr","hubDatabaseId":79,"hubSchemaId":7,' +
          '"schemaTables":[{"name":"EMPLOYEES","columns":[{"name":"EMP_NAME","dataType":"String"}]}]}],' +
          '"aiEndpoints":[]}')
      else
        SendJson(AResponse, 200, '{"databases":[],"aiEndpoints":[]}');
    end
    else if P = '/NlToSql/TranslateToSQLStream' then
    begin
      Inc(TranslateCalls);
      LastTranslateBody := LContent;
      if Pos('slow', LContent) > 0 then
      begin
        SetLength(LEvents, 60);
        for I := 0 to High(LEvents) do
          LEvents[I] := ProgressEvent('Partial', 'x' + IntToStr(I) + ' ', 's1');
        SendEvents(AResponse, LEvents, 100, True, True);
      end
      else if Pos('fail', LContent) > 0 then
      begin
        SetLength(LEvents, 1);
        LEvents[0] := '{"result":null,"errorMessage":"The model could not answer"}';
        SendEvents(AResponse, LEvents, 10, True, True);
      end
      else
      begin
        SetLength(LEvents, 5);
        LEvents[0] := '{"actor":"Hub","stage":"PreparingContext","chunk":"Reading the schema"}';
        LEvents[1] := ProgressEvent('Partial', 'SELECT NAME', 't1');
        LEvents[2] := ProgressEvent('Partial', ', BALANCE FROM CLIENTS', 't1');
        LEvents[3] := ProgressEvent('End', '', 't1');
        LEvents[4] := '{"result":{"sql":"' + SUGGESTED_SQL + '","explanation":"Clientes con ' +
          'saldo ' + BS + 'u00ab1000' + BS + 'u00bb"},"errorMessage":"",' +
          '"userProfile":{"userId":7,"email":"ana@example.com","tierName":"Pro","tierId":4,' +
          '"dailyMax":1000,"dailyConsumed":260}}';
        SendEvents(AResponse, LEvents, 30, True, True);
      end;
    end
    else if P = '/NlToSql/ExplainSQLStream' then
    begin
      Inc(ExplainCalls);
      LastExplainBody := LContent;
      if Pos('slow', LContent) > 0 then
      begin
        SetLength(LEvents, 40);
        for I := 0 to High(LEvents) do
          LEvents[I] := ProgressEvent('Partial', 'e' + IntToStr(I) + ' ', 'x3');
        SendEvents(AResponse, LEvents, 100, True, True);
        Exit;
      end;
      SetLength(LEvents, 3);
      LEvents[0] := ProgressEvent('Partial', 'Lists the clients', 'x1');
      LEvents[1] := ProgressEvent('End', ' with their balance.', 'x1');
      LEvents[2] := '{"result":{"explanation":"' + AUDIT_TEXT + '",' +
        '"tokenUsage":{"inputTokens":50,"outputTokens":12}},"errorMessage":""}';
      SendEvents(AResponse, LEvents, 20, True, True);
    end
    else if P = '/NlToSql/SuggestSqlCodeStream' then
    begin
      Inc(SuggestCalls);
      LastSuggestBody := LContent;
      if Pos('slow', LContent) > 0 then
      begin
        SetLength(LEvents, 40);
        for I := 0 to High(LEvents) do
          LEvents[I] := ProgressEvent('Partial', 'y' + IntToStr(I), 'a1');
        SendEvents(AResponse, LEvents, 100, True, True);
      end
      else if Pos('clientes con saldo', LContent) > 0 then
      begin
        // A comment in natural language: the SQL that implements it
        SetLength(LEvents, 2);
        LEvents[0] := ProgressEvent('End', 'SELECT', 'a3');
        LEvents[1] := '{"result":{"autoComplete":{"inlineCompletions":["' + COMMENT_SQL1 +
          BS + 'n' + COMMENT_SQL2 + BS + 'r' + BS + 'n' + COMMENT_SQL3 + '"],' +
          '"listCompletions":[]},"tokenUsage":{"inputTokens":40,"outputTokens":15}},' +
          '"errorMessage":""}';
        SendEvents(AResponse, LEvents, 20, True, True);
      end
      else
      begin
        SetLength(LEvents, 3);
        LEvents[0] := ProgressEvent('Partial', 'NAME FROM', 'a2');
        LEvents[1] := ProgressEvent('End', ' CLIENTS', 'a2');
        LEvents[2] := '{"result":{"autoComplete":{"inlineCompletions":["NAME FROM CLIENTS"],' +
          '"listCompletions":["CLIENTS","ORDERS"]},' +
          '"tokenUsage":{"inputTokens":30,"outputTokens":4}},"errorMessage":""}';
        SendEvents(AResponse, LEvents, 20, True, True);
      end;
    end
    else
      SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
  finally
    LBody.Free;
  end;
end;

{ Helpers }

function T(AId: Integer; const ADefault: string): string;
begin
  Result := TranslateStr(AId, ADefault);
end;

function ItemTexts(const AItems: TRpSqlCompletionItems): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AItems) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + AItems[I].Text;
  end;
end;

function NewTestSchema: TRpSqlSchema;
var
  LJson: TJSONValue;
begin
  Result := TRpSqlSchema.Create;
  LJson := TJSONObject.ParseJSONValue(SalesTablesJson);
  try
    Result.LoadFromJson(LJson as TJSONArray);
  finally
    LJson.Free;
  end;
end;

{ TAISqlTests }

constructor TAISqlTests.Create(const AShotsDir: string);
begin
  inherited Create;
  FShotsDir := AShotsDir;
  FScripts := TStringList.Create;
  FWebMessages := TStringList.Create;
end;

destructor TAISqlTests.Destroy;
begin
  FWebMessages.Free;
  FScripts.Free;
  inherited Destroy;
end;

procedure TAISqlTests.Pump(AMs: Cardinal);
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

procedure TAISqlTests.WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
  const AWhat: string);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  while not ACondition() do
  begin
    if GetTickCount64 - LStart > ATimeoutMs then
    begin
      Log('  diag: workers=' + IntToStr(RpAsyncActiveWorkers) + ' hub requests: ' +
        FHub.RequestLog);
      Fail('timeout waiting for ' + AWhat);
    end;
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  end;
  Pass(AWhat);
end;

function TAISqlTests.NewForm(AWidth, AHeight: Integer): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.SetBounds(40, 40, AWidth, AHeight);
  Result.Position := poDesigned;
  Result.Caption := 'LclAIChatTest SQL';
end;

// PaintTo of a form paints its frame too on win32: the size of the window,
// and where its client area starts in it
function ShotRect(AControl: TWinControl; out AClientOffset: TPoint): TRect;
var
  LOrigin: TPoint;
begin
  Result := Rect(0, 0, AControl.Width, AControl.Height);
  AClientOffset := Types.Point(0, 0);
{$IFDEF MSWINDOWS}
  if (AControl is TCustomForm) and AControl.HandleAllocated and
    (GetWindowRect(AControl.Handle, Result) <> 0) then
  begin
    LOrigin := AControl.ClientOrigin;
    AClientOffset := Types.Point(LOrigin.X - Result.Left, LOrigin.Y - Result.Top);
    Result := Rect(0, 0, Result.Right - Result.Left, Result.Bottom - Result.Top);
  end;
{$ELSE}
  LOrigin := Types.Point(0, 0);
{$ENDIF}
end;

procedure TAISqlTests.Shot(AControl: TWinControl; const AName: string);
var
  LBitmap: TBitmap;
  LPng: TPortableNetworkGraphic;
  LRect: TRect;
  LOffset: TPoint;
begin
  if FShotsDir = '' then
    Exit;
  Pump(150);
  LBitmap := TBitmap.Create;
  LPng := TPortableNetworkGraphic.Create;
  try
    LRect := ShotRect(AControl, LOffset);
    LBitmap.SetSize(LRect.Right, LRect.Bottom);
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

procedure TAISqlTests.ScreenShot(AControl: TWinControl; const AName: string);
var
  LBitmap: TBitmap;
  LPng, LWebPng: TPortableNetworkGraphic;
  LStream: TMemoryStream;
  LRect: TRect;
  LOffset: TPoint;

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
          P := AControl.ScreenToClient(LWeb.ClientToScreen(Types.Point(0, 0)));
          Inc(P.X, LOffset.X);
          Inc(P.Y, LOffset.Y);
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
    LRect := ShotRect(AControl, LOffset);
    LBitmap.SetSize(LRect.Right, LRect.Bottom);
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

function TAISqlTests.LastScript(const AContains: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := FScripts.Count - 1 downto 0 do
    if Pos(AContains, FScripts[I]) > 0 then
      Exit(FScripts[I]);
end;

function TAISqlTests.NewReport: TRpReport;
var
  LConn: TRpDatabaseInfoItem;
  LData: TRpDataInfoItem;
begin
  Result := TRpReport.Create(nil);
  Result.CreateNew;
  Result.UndoCue := TUndoCue.Create(Result);
  LConn := Result.DatabaseInfo.Add('HUBSQL');
  LConn.Driver := rpdbHttp;
  LData := Result.DataInfo.Add('CLIENTS');
  LData.DatabaseAlias := 'HUBSQL';
  LData.SQL := 'SELECT * FROM CLIENTS';
  LData.HubSchemaId := 5;
  LData := Result.DataInfo.Add('ORDERS');
  LData.DatabaseAlias := 'HUBSQL';
  LData.SQL := 'SELECT * FROM ORDERS';
  TUndoCue(Result.UndoCue).MarkClean;
end;

procedure TAISqlTests.EditorScript(Sender: TObject; const AScript: string);
begin
  FScripts.Add(AScript);
end;

procedure TAISqlTests.EditorContentChanged(Sender: TObject);
begin
  Inc(FContentChanges);
end;

procedure TAISqlTests.EditorSchemaTablesLoaded(Sender: TObject);
begin
  Inc(FSchemaTablesLoaded);
end;

procedure TAISqlTests.EditorWebMessage(Sender: TObject; const AMessage: string);
begin
  FWebMessages.Add(AMessage);
end;

{ Tests }

procedure TAISqlTests.TestEngine;
var
  LSchema: TRpSqlSchema;
  LItems: TRpSqlCompletionItems;
  S: string;
begin
  Section('SQL completion engine (tables and columns of the schema)');
  LSchema := NewTestSchema;
  try
    CheckEquals(2, LSchema.TableCount, 'schemaTables loaded');
    CheckEquals(4, LSchema.FindTable('clients').ColumnCount, 'columns of a table');
    Check(LSchema.FindTable('CLIENTS').Column(0).IsPrimaryKey, 'primary key read');
    CheckEquals('Currency', LSchema.FindTable('CLIENTS').Column(2).DataType, 'enum data type');
    CheckEquals('System.Int64', LSchema.FindTable('ORDERS').Column(1).DataType,
      'numeric data type: the detected type instead');
    Check(LSchema.FindTable('dbo.ORDERS') <> nil, 'table found with a schema prefix');

    S := 'SELECT * FROM ';
    LItems := RpSqlCompletionItems(LSchema, S, Length(S), False, False);
    CheckEquals('CLIENTS,ORDERS', ItemTexts(LItems), 'tables after FROM');
    Check(LItems[0].Kind = rsckTable, 'table kind');
    S := 'SELECT * FROM CLIENTS C INNER JOIN ';
    CheckEquals('CLIENTS,ORDERS', ItemTexts(RpSqlCompletionItems(LSchema, S, Length(S), False, False)),
      'tables after JOIN');
    S := 'SELECT * FROM CLIENTS, ';
    CheckEquals('CLIENTS,ORDERS', ItemTexts(RpSqlCompletionItems(LSchema, S, Length(S), False, False)),
      'tables after a comma of the FROM list');
    S := 'SELECT A, ';
    CheckEquals('', ItemTexts(RpSqlCompletionItems(LSchema, S, Length(S), False, False)),
      'nothing after a comma of the SELECT list (not asked)');

    S := 'SELECT C.NA FROM CLIENTS AS C';
    LItems := RpSqlCompletionItems(LSchema, S, 11, False, False);
    CheckEquals('ID,NAME,BALANCE,CITY', ItemTexts(LItems), 'columns after an alias');
    Check(LItems[1].Kind = rsckColumn, 'column kind');
    CheckEquals('CLIENTS String', LItems[1].Detail, 'column detail: table and type');
    CheckEquals('NA', RpSqlCompletionPrefix(S, 11), 'identifier being typed');
    S := 'SELECT O. FROM dbo.ORDERS O WHERE 1=1';
    CheckEquals('ORDER_ID,CLIENT_ID,TOTAL,ORDER_DATE',
      ItemTexts(RpSqlCompletionItems(LSchema, S, 9, False, False)),
      'alias of a table with a schema prefix');
    S := 'SELECT ORDERS. FROM ORDERS';
    CheckEquals('ORDER_ID,CLIENT_ID,TOTAL,ORDER_DATE',
      ItemTexts(RpSqlCompletionItems(LSchema, S, 14, False, False)), 'columns after a table name');
    S := 'SELECT X. FROM ORDERS';
    CheckEquals('', ItemTexts(RpSqlCompletionItems(LSchema, S, 9, False, False)),
      'unknown qualifier: nothing');
    S := 'SELECT * FROM CLIENTS C /* FROM ORDERS O */ WHERE C.';
    CheckEquals('ID,NAME,BALANCE,CITY',
      ItemTexts(RpSqlCompletionItems(LSchema, S, Length(S), False, False)), 'comments skipped');
    S := 'SELECT * FROM (SELECT 1 FROM ORDERS) X, CLIENTS K WHERE K.';
    CheckEquals('ID,NAME,BALANCE,CITY',
      ItemTexts(RpSqlCompletionItems(LSchema, S, Length(S), False, False)), 'derived table skipped');

    S := 'SELECT ';
    CheckEquals('', ItemTexts(RpSqlCompletionItems(LSchema, S, Length(S), False, False)),
      'not asked, no context: nothing (the AI completes there)');
    S := 'SELECT  FROM ORDERS O';
    LItems := RpSqlCompletionItems(LSchema, S, 7, True, True);
    CheckEquals('ORDER_ID', LItems[0].Text, 'asked: the columns of the statement first');
    Check(Pos(',CLIENTS,ORDERS,SELECT,', ',' + ItemTexts(LItems) + ',') > 0,
      'then the tables and the keywords');
    Check(Pos('NAME', ItemTexts(LItems)) = 0, 'columns of other tables not listed');
    CheckEquals('', ItemTexts(RpSqlCompletionItems(nil, 'SELECT * FROM ', 14, True, False)),
      'no schema: no tables');
    Check(Length(RpSqlCompletionItems(nil, 'SEL', 3, True, True)) > 30, 'no schema: keywords');

    CheckEquals(2, RpUtf16OffsetToByteOffset(#$C3#$91'A', 1), 'UTF-16 offset of a 2 byte letter');
    CheckEquals(4, RpUtf16OffsetToByteOffset(#$F0#$9F#$98#$80'A', 2), 'surrogate pair');
    CheckEquals(3, RpUtf16OffsetToByteOffset('ABC', 10), 'offset past the end');
    CheckEquals(1, RpByteOffsetToUtf16Offset(#$C3#$91'A', 2), 'byte offset of a 2 byte letter');
    CheckEquals(2, RpByteOffsetToUtf16Offset(#$F0#$9F#$98#$80'A', 4), 'byte offset: surrogate pair');
    CheckEquals(3, RpByteOffsetToUtf16Offset('ABC', 10), 'byte offset past the end');
    CheckEquals(0, RpByteOffsetToUtf16Offset('ABC', 0), 'byte offset 0');
  finally
    LSchema.Free;
  end;
end;

procedure TAISqlTests.TestMonacoBridge;
var
  LEditor: TFRpMonacoEditorLCL;
  LScript: string;
  LStart: QWord;

  function TablesLoaded: Boolean;
  begin
    Result := LEditor.LoadedSchemaTablesId = 5;
  end;
  function SchemasLoaded: Boolean;
  begin
    Result := LEditor.ComboSchema.Items.Count > 1;
  end;
  function Answered1: Boolean;
  begin
    Result := LEditor.AICompletionCount >= 1;
  end;
  function SlowRunning: Boolean;
  begin
    Result := LEditor.InferenceRunning and (FHubHandler.SuggestCalls >= 2);
  end;
  function Answered5: Boolean;
  begin
    Result := LastScript('"ai_5"') <> '';
  end;
  function SlowRunning6: Boolean;
  begin
    Result := LEditor.InferenceRunning and (FHubHandler.SuggestCalls >= 4);
  end;
  function Answered6: Boolean;
  begin
    Result := LastScript('"ai_6"') <> '';
  end;

begin
  Section('Monaco bridge: messages of the page handled without WebView2');
  FScripts.Clear;
  FContentChanges := 0;
  FSchemaTablesLoaded := 0;
  TRpAuthManager.Instance.AIEnabled := True;
  // Not parented: no window, no WebView2; the page is simulated
  LEditor := TFRpMonacoEditorLCL.Create(nil);
  try
    LEditor.OnScript := EditorScript;
    LEditor.OnContentChanged := EditorContentChanged;
    LEditor.OnSchemaTablesLoaded := EditorSchemaTablesLoaded;
    LEditor.DebounceTimer.Interval := 30;
    Check(not LEditor.UseFallback, 'Monaco mode');
    Check(LEditor.AIButton.Down, 'AI toggle follows the preferences');
    LEditor.SetHubContext(77, 5, 'sql-key');
    LEditor.RuntimeDb := 'ADO_Net';
    WaitUntil(SchemasLoaded, 10000, 'schemas of the API key and the account loaded');
    CheckEquals('Sales / Main', LEditor.ComboSchema.Text, 'schema of the dataset selected');
    CheckEquals(5, LEditor.HubSchemaId, 'hub schema');
    WaitUntil(TablesLoaded, 10000, 'tables of the schema loaded');
    CheckEquals(2, LEditor.SqlSchema.TableCount, 'two tables');
    Check(FSchemaTablesLoaded > 0, 'OnSchemaTablesLoaded');

    // 00: ready: the SQL and the schema completion provider go to the page
    LEditor.SQL := 'SELECT 1';
    LEditor.ProcessWebMessage('00:');
    Check(LEditor.EditorReady, 'editor ready after 00:');
    CheckContains('window.rpReceiveSchemaCompletions', LastScript('rpSchemaBridge'),
      'schema completion provider installed');
    CheckContains('registerCompletionItemProvider', LastScript('rpSchemaBridge'),
      'as a Monaco completion provider');
    CheckContains('window.editor.setValue("SELECT 1")', LastScript('setValue'), 'SQL pushed');

    // 01: content changed (\n to \r\n)
    LEditor.ProcessWebMessage('01:SELECT *' + #10 + 'FROM CLIENTS');
    CheckEquals('SELECT *' + #13#10 + 'FROM CLIENTS', LEditor.SQL, '01: updates the SQL');
    CheckEquals(1, FContentChanges, 'OnContentChanged');

    // 03: schema completion requested by the injected provider
    LEditor.ProcessWebMessage('03:sc_1:14:0' + #10 + 'SELECT * FROM ');
    LScript := LastScript('rpReceiveSchemaCompletions("sc_1"');
    CheckContains('{"label":"CLIENTS","kind":"table","detail":"table"}', LScript,
      'tables answered to the page');
    CheckContains('"label":"ORDERS"', LScript, 'every table');
    LEditor.ProcessWebMessage('03:sc_2:9:0' + #10 + 'SELECT C. FROM CLIENTS C');
    LScript := LastScript('rpReceiveSchemaCompletions("sc_2"');
    CheckContains('{"label":"BALANCE","kind":"column","detail":"CLIENTS Currency"}', LScript,
      'columns of the alias answered');
    // Offsets in UTF-16 units: one character, two bytes
    LEditor.ProcessWebMessage('03:sc_3:16:0' + #10 + 'SELECT ''' + #$C3#$91 + ''' FROM ');
    CheckContains('"label":"CLIENTS"', LastScript('rpReceiveSchemaCompletions("sc_3"'),
      'UTF-16 offset converted');
    LEditor.ProcessWebMessage('03:sc_4:7:0' + #10 + 'SELECT ');
    CheckContains('rpReceiveSchemaCompletions("sc_4", [])', LastScript('"sc_4"'),
      'no context and not asked: empty answer');

    // 02: AI completion, as the VCL (SuggestSql after the debounce)
    FHubHandler.SuggestCalls := 0;
    LEditor.ProcessWebMessage('02:ai_1:7' + #10 + 'SELECT ');
    Check(LEditor.DebounceTimer.Enabled, 'debounced');
    WaitUntil(Answered1, 10000, 'AI completion answered to the page');
    LScript := LastScript('receiveAICompletions("ai_1"');
    CheckContains('"inlineItems":[{"insertText":"NAME FROM CLIENTS"}]', LScript, 'inline items');
    CheckContains('{"label":"CLIENTS","insertText":"CLIENTS","detail":"AI"}', LScript,
      'dropdown items');
    CheckEquals(1, FHubHandler.SuggestCalls, 'one SuggestSqlCodeStream request');
    CheckContains('"cursorPosition":7', FHubHandler.LastSuggestBody, 'cursor position sent');
    CheckContains('"hubSchemaId":5', FHubHandler.LastSuggestBody, 'schema of the editor sent');
    CheckContains('"hubDatabaseId":77', FHubHandler.LastSuggestBody, 'hub database sent');
    CheckContains('"apiKey":"sql-key"', FHubHandler.LastSuggestBody, 'API key of the schema sent');
    CheckContains('"runtime":"ADO_Net"', FHubHandler.LastSuggestBody, 'runtime sent');
    Check(not LEditor.InferenceRunning, 'inference finished');
    // The same text again (the cursor moved): empty answer, no request
    LEditor.ProcessWebMessage('02:ai_2:3' + #10 + 'SELECT ');
    CheckContains('receiveAICompletions("ai_2", {"inlineItems":[],"completionItems":[]})',
      LastScript('"ai_2"'), 'same text: empty answer at once');
    // AI disabled: empty answer
    TRpAuthManager.Instance.AIEnabled := False;
    LEditor.ProcessWebMessage('02:ai_3:8' + #10 + 'SELECT X');
    CheckContains('{"inlineItems":[],"completionItems":[]}', LastScript('"ai_3"'),
      'AI disabled: empty answer');
    TRpAuthManager.Instance.AIEnabled := True;
    Pump(100);
    CheckEquals(1, FHubHandler.SuggestCalls, 'no request for the empty answers');

    // A new request while one runs: the running stream is cancelled and the
    // new one starts when it ends (VCL FRestartPendingInference)
    LEditor.ProcessWebMessage('02:ai_4:11' + #10 + 'SELECT slow');
    WaitUntil(SlowRunning, 10000, 'slow AI completion running');
    LStart := GetTickCount64;
    LEditor.ProcessWebMessage('02:ai_5:11' + #10 + 'SELECT fast');
    WaitUntil(Answered5, 10000, 'the newer request answered');
    Check(ElapsedMs(LStart) < 3000, Format('the superseded stream stopped at once (%d ms)',
      [ElapsedMs(LStart)]));
    CheckEquals('', LastScript('"ai_4"'), 'no answer for the superseded request');
    CheckEquals(3, FHubHandler.SuggestCalls, 'three requests in total');
    Check(RpAsyncWaitIdle(10000), 'workers finished');
    // Stop of the model selection: the completion stream ends, empty answer
    LEditor.ProcessWebMessage('02:ai_6:12' + #10 + 'SELECT slow2');
    WaitUntil(SlowRunning6, 10000, 'another slow AI completion running');
    Check(LEditor.AISelection.InferenceActive, 'inference progress shown');
    LStart := GetTickCount64;
    LEditor.AISelection.BStopInferenceClick(nil);
    WaitUntil(Answered6, 10000, 'stopped request answered');
    Check(ElapsedMs(LStart) < 3000, Format('stopped at once (%d ms)', [ElapsedMs(LStart)]));
    CheckContains('{"inlineItems":[],"completionItems":[]}', LastScript('"ai_6"'),
      'empty answer after the stop');
    Check(not LEditor.InferenceRunning, 'no inference running');
    Check(not LEditor.AISelection.InferenceActive, 'progress hidden');
    Check(RpAsyncWaitIdle(10000), 'workers finished');

    // Undoable apply: executeEdits instead of setValue
    LEditor.ApplySQL('SELECT 2');
    CheckContains('executeEdits', LastScript('executeEdits'), 'apply as an edit of Monaco');
    CheckEquals('SELECT 2', LEditor.SQL, 'SQL of the apply');
    LEditor.SetTheme('vs-dark');
    CheckContains('setEditorTheme("vs-dark")', LastScript('setEditorTheme'), 'theme to the page');

    // A schema chosen in the combo of the editor
    LEditor.ComboSchema.ItemIndex := LEditor.ComboSchema.Items.IndexOf('Sales / Archive');
    Check(LEditor.ComboSchema.ItemIndex > 0, 'second schema listed (API key)');
    LEditor.ComboSchema.OnChange(LEditor.ComboSchema);
    CheckEquals(8, LEditor.HubSchemaId, 'schema of the combo');
    CheckEquals(8, LEditor.LoadedSchemaTablesId, 'its tables from the cache');
    CheckEquals('OLD_ORDERS', LEditor.SqlSchema.Table(0).Name, 'tables of the other schema');
  finally
    LEditor.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAISqlTests.TestFallbackEditor;
var
  LForm: TForm;
  LEditor: TFRpMonacoEditorLCL;
  LCompletion: TSynCompletion;
  LText: string;

  function TablesLoaded: Boolean;
  begin
    Result := LEditor.LoadedSchemaTablesId = 5;
  end;

  procedure SetTextAndCaret(const AText: string; X, Y: Integer);
  begin
    LEditor.SQL := AText;
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(X, Y);
  end;

  function Items: string;
  begin
    Result := StringReplace(Trim(LCompletion.ItemList.Text), LineEnding, ',', [rfReplaceAll]);
  end;

begin
  Section('Fallback editor: SynEdit with the schema completion');
  LForm := NewForm(760, 420);
  try
    LEditor := TFRpMonacoEditorLCL.Create(LForm);
    LEditor.OnContentChanged := EditorContentChanged;
    // As without WebView2 (Linux, old Windows)
    LEditor.ActivateFallback('test');
    LEditor.Parent := LForm;
    LEditor.Align := alClient;
    LForm.Show;
    Pump(100);
    Check(LEditor.UseFallback, 'fallback editor in use');
    Check(LEditor.FallbackEditor.Visible, 'SynEdit visible');
    Check(not LEditor.WebView.Visible, 'WebView hidden');
    // SynEdit's own default is fqNonAntialiased (aliased text with Qt6)
    Check(LEditor.FallbackEditor.Font.Quality = fqDefault, 'antialiased as the desktop');
    LCompletion := LEditor.Completion;
    LEditor.SetHubContext(77, 5, 'sql-key');
    WaitUntil(TablesLoaded, 10000, 'tables of the schema loaded');
    Check(LEditor.FallbackEditor.Highlighter is TSynSQLSyn, 'SQL highlighter');
    Check(TSynSQLSyn(LEditor.FallbackEditor.Highlighter).TableNames.IndexOf('CLIENTS') >= 0,
      'schema tables highlighted as table names');

    // Tables after FROM
    FContentChanges := 0;
    SetTextAndCaret('SELECT * FROM ', 15, 1);
    LEditor.ExecuteFallbackCompletion(True);
    Check(LCompletion.IsActive, 'completion popup open');
    CheckEquals('CLIENTS,ORDERS', Items, 'tables listed');
    Shot(LForm, 'sql_fallback_editor');
    if LCompletion.TheForm.Visible then
      Shot(LCompletion.TheForm, 'sql_fallback_completion');
    LCompletion.CurrentString := 'OR';
    CheckEquals('ORDERS', Items, 'filtered while typing');
    LCompletion.OnValidate(LCompletion.TheForm, '', []);
    LCompletion.Deactivate;
    CheckEquals('SELECT * FROM ORDERS', LEditor.FallbackEditor.Lines[0], 'item inserted');
    CheckEquals('SELECT * FROM ORDERS', LEditor.SQL, 'SQL of the editor updated');
    Check(FContentChanges > 0, 'OnContentChanged');

    // Columns after an alias, the typed part replaced
    SetTextAndCaret('SELECT C.BA' + #13#10 + 'FROM CLIENTS C', 12, 1);
    LEditor.ExecuteFallbackCompletion(True);
    CheckEquals('BALANCE', Items, 'columns of the alias starting with BA');
    LCompletion.OnValidate(LCompletion.TheForm, '', []);
    LCompletion.Deactivate;
    CheckEquals('SELECT C.BALANCE' + #13#10 + 'FROM CLIENTS C', LEditor.SQL,
      'column inserted, lines joined with CRLF');

    // Asked elsewhere: the columns of the statement, tables, keywords
    SetTextAndCaret('SELECT  FROM ORDERS O', 8, 1);
    LEditor.ExecuteFallbackCompletion(True);
    CheckEquals('ORDER_ID', LCompletion.ItemList[0], 'columns of the statement first');
    Check(LCompletion.ItemList.IndexOf('WHERE') >= 0, 'SQL keywords');
    LCompletion.Deactivate;

    // Automatic popup: only with something to complete
    SetTextAndCaret('SELECT ', 8, 1);
    LEditor.ExecuteFallbackCompletion(False);
    Check(not LCompletion.IsActive, 'no automatic popup without context');
    LEditor.FallbackEditor.SetFocus;
    Pump(50);
    if LEditor.FallbackEditor.Focused then
    begin
      SetTextAndCaret('SELECT C' + #13#10 + 'FROM CLIENTS C', 9, 1);
      LEditor.FallbackEditor.CommandProcessor(ecChar, '.', nil);
      LText := LEditor.FallbackEditor.Lines[0];
      CheckEquals('SELECT C.', LText, '"." typed');
      Pump(150);
      Check(LCompletion.IsActive, 'popup opens on its own after "."');
      Check(LCompletion.ItemList.IndexOf('NAME') >= 0, 'with the columns of the alias');
      LCompletion.Deactivate;
      // The user types in the editor: the focus is back there
      LEditor.FallbackEditor.SetFocus;
      Pump(50);
      SetTextAndCaret('SELECT 1 FROM', 14, 1);
      LEditor.FallbackEditor.CommandProcessor(ecChar, ' ', nil);
      Pump(150);
      Check(LCompletion.IsActive, 'popup opens on its own after "FROM "');
      CheckEquals('CLIENTS,ORDERS', Items, 'with the tables');
      LCompletion.Deactivate;
      LEditor.FallbackEditor.SetFocus;
      Pump(50);
      SetTextAndCaret('SELECT 1', 9, 1);
      LEditor.FallbackEditor.CommandProcessor(ecChar, ' ', nil);
      Pump(150);
      Check(not LCompletion.IsActive, 'no popup after other words');
    end
    else
      Skip('the editor can not take the focus here (automatic popup)');
    LCompletion.Deactivate;

    // Apply as one undoable edit
    SetTextAndCaret('SELECT 1', 1, 1);
    LEditor.ApplySQL('SELECT NAME' + #10 + 'FROM CLIENTS');
    CheckEquals('SELECT NAME' + #13#10 + 'FROM CLIENTS', LEditor.SQL, 'applied SQL');
    CheckEquals(2, LEditor.FallbackEditor.Lines.Count, 'two lines');
    LEditor.FallbackEditor.Undo;
    CheckEquals('SELECT 1', Trim(LEditor.FallbackEditor.Text), 'Ctrl+Z restores the text');
    CheckEquals('SELECT 1', LEditor.SQL, 'and the SQL of the editor');

    LEditor.SetTheme('vs-dark');
    CheckEquals($1E1E1E, LEditor.FallbackEditor.Color, 'dark theme');
    Shot(LForm, 'sql_fallback_dark');
    LEditor.SetTheme('vs');
    CheckEquals(clWhite, LEditor.FallbackEditor.Color, 'light theme');
  finally
    LForm.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

type
  // KeyDown of the editor (protected): the keys go through its handlers
  TSynEditKeys = class(TSynEdit);

procedure TAISqlTests.TestFallbackAISuggestion;
var
  LForm: TForm;
  LEditor: TFRpMonacoEditorLCL;
  LCalls, LAnswers: Integer;
  LKey: Word;

  function Suggested: Boolean;
  begin
    Result := LEditor.AISuggestion <> '';
  end;

  function AnsweredAgain: Boolean;
  begin
    Result := (LEditor.AICompletionCount > LAnswers) and (not LEditor.InferenceRunning) and
      (not LEditor.DebounceTimer.Enabled);
  end;

  procedure TypeText(const AText: string);
  var
    I: Integer;
  begin
    for I := 1 to Length(AText) do
      LEditor.FallbackEditor.CommandProcessor(ecChar, AText[I], nil);
  end;

  procedure PressKey(AKey: Word);
  begin
    LKey := AKey;
    TSynEditKeys(LEditor.FallbackEditor).KeyDown(LKey, []);
  end;

  procedure WaitSuggestion(const AWhat: string);
  begin
    LCalls := FHubHandler.SuggestCalls;
    WaitUntil(Suggested, 10000, AWhat);
    CheckEquals(LCalls + 1, FHubHandler.SuggestCalls, AWhat + ': one request');
  end;

begin
  Section('Fallback editor: AI inline completion (comment to SQL)');
  TRpAuthManager.Instance.AIEnabled := True;
  LForm := NewForm(760, 420);
  try
    LEditor := TFRpMonacoEditorLCL.Create(LForm);
    LEditor.ActivateFallback('test');
    LEditor.Parent := LForm;
    LEditor.Align := alClient;
    LEditor.DebounceTimer.Interval := 30;
    LForm.Show;
    LEditor.SetHubContext(77, 5, 'sql-key');
    LEditor.RuntimeDb := 'ADO_Net';
    Pump(100);
    LEditor.FallbackEditor.SetFocus;
    Pump(50);

    // A comment and a line break: one request after the debounce
    LEditor.SQL := '';
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(1, 1);
    LCalls := FHubHandler.SuggestCalls;
    TypeText('-- clientes con saldo');
    LEditor.FallbackEditor.CommandProcessor(ecLineBreak, '', nil);
    Check(LEditor.DebounceTimer.Enabled, 'request debounced while typing');
    WaitUntil(Suggested, 10000, 'AI suggestion shown');
    CheckEquals(LCalls + 1, FHubHandler.SuggestCalls, 'one SuggestSqlCodeStream request');
    CheckContains('"sql":"-- clientes con saldo' + BS + 'r' + BS + 'n"',
      FHubHandler.LastSuggestBody, 'the text as the page sends it (CRLF)');
    CheckContains('"cursorPosition":23', FHubHandler.LastSuggestBody,
      'caret offset after the line break');
    CheckContains('"hubSchemaId":5', FHubHandler.LastSuggestBody, 'schema of the editor');
    CheckContains('"apiKey":"sql-key"', FHubHandler.LastSuggestBody, 'API key of the schema');
    CheckEquals(COMMENT_SQL1 + LineEnding + COMMENT_SQL2 + LineEnding + COMMENT_SQL3,
      LEditor.AISuggestion, 'first inline item, line breaks of the editor');
    Check(LEditor.AISuggestionShown, 'ghost text at the caret');
    CheckEquals('-- clientes con saldo' + #13#10, LEditor.SQL, 'the ghost text is not in the SQL');
    LEditor.FallbackEditor.Repaint;
    Shot(LForm, 'sql_fallback_ai_suggestion');

    // Tab: inserted as one undo step, the caret after it, no new request
    LCalls := FHubHandler.SuggestCalls;
    PressKey(VK_TAB);
    CheckEquals(0, LKey, 'Tab taken by the suggestion');
    CheckEquals('', LEditor.AISuggestion, 'suggestion accepted');
    CheckEquals('-- clientes con saldo' + #13#10 + COMMENT_SQL1 + #13#10 + COMMENT_SQL2 +
      #13#10 + COMMENT_SQL3, LEditor.SQL, 'SQL inserted at the caret');
    CheckEquals(Length(COMMENT_SQL3) + 1, LEditor.FallbackEditor.LogicalCaretXY.X, 'caret column after it');
    CheckEquals(4, LEditor.FallbackEditor.LogicalCaretXY.Y, 'caret line after it');
    Pump(200);
    CheckEquals(LCalls, FHubHandler.SuggestCalls, 'no request for the accepted text');
    Shot(LForm, 'sql_fallback_ai_accepted');
    LEditor.FallbackEditor.Undo;
    CheckEquals('-- clientes con saldo' + #13#10, LEditor.SQL, 'one Ctrl+Z removes it');
    Pump(200);
    CheckEquals(LCalls, FHubHandler.SuggestCalls, 'undo: no request');
    LEditor.FallbackEditor.Redo;
    Pump(200);
    CheckEquals(LCalls, FHubHandler.SuggestCalls, 'redo: no request');
    LEditor.FallbackEditor.Undo;
    // Tab without a suggestion: the tab of the editor (two spaces)
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(1, 2);
    PressKey(VK_TAB);
    CheckEquals(3, LEditor.FallbackEditor.LogicalCaretXY.X, 'Tab left to the editor without a suggestion');

    // Esc dismisses it
    LEditor.SQL := '-- clientes con saldo' + #13#10;
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(1, 2);
    TypeText('x');
    WaitSuggestion('suggestion for the new text');
    PressKey(VK_ESCAPE);
    CheckEquals(0, LKey, 'Esc taken by the suggestion');
    CheckEquals('', LEditor.AISuggestion, 'Esc dismisses the suggestion');
    Check(Pos(COMMENT_SQL1, LEditor.SQL) = 0, 'nothing inserted');

    // Moving the caret dismisses it
    TypeText('y');
    WaitSuggestion('suggestion again');
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(1, 1);
    CheckEquals('', LEditor.AISuggestion, 'caret moved: dismissed');
    Check(not LEditor.AcceptAISuggestion, 'nothing to accept');

    // Typing dismisses it and asks again
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(3, 2);
    TypeText('z');
    WaitSuggestion('suggestion for xyz');
    TypeText('w');
    CheckEquals('', LEditor.AISuggestion, 'typing dismisses it');
    Check(LEditor.DebounceTimer.Enabled, 'and asks again');
    WaitSuggestion('suggestion for xyzw');

    // An answer for a caret that moved meanwhile is not shown
    LAnswers := LEditor.AICompletionCount;
    TypeText('v');
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(1, 1);
    WaitUntil(AnsweredAgain, 10000, 'answer of the moved caret');
    CheckEquals('', LEditor.AISuggestion, 'stale answer not shown');

    // Backspace is an edit of the user as well
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(6, 2);
    LCalls := FHubHandler.SuggestCalls;
    LEditor.FallbackEditor.CommandProcessor(ecDeleteLastChar, '', nil);
    WaitUntil(Suggested, 10000, 'suggestion after a backspace');
    CheckEquals(LCalls + 1, FHubHandler.SuggestCalls, 'backspace: one request');

    // Non ASCII text: the offset counts UTF-16 units
    LEditor.SQL := '';
    LEditor.FallbackEditor.LogicalCaretXY := Types.Point(1, 1);
    LAnswers := LEditor.AICompletionCount;
    LEditor.FallbackEditor.CommandProcessor(ecChar, #$C3#$91, nil);
    WaitUntil(AnsweredAgain, 10000, 'answer for a two byte letter');
    CheckContains('"cursorPosition":1,', FHubHandler.LastSuggestBody, 'UTF-16 offset of the caret');

    // AI disabled: no request, no suggestion
    TRpAuthManager.Instance.AIEnabled := False;
    LCalls := FHubHandler.SuggestCalls;
    TypeText('-- clientes con saldo');
    Pump(200);
    CheckEquals(LCalls, FHubHandler.SuggestCalls, 'AI disabled: no request');
    CheckEquals('', LEditor.AISuggestion, 'AI disabled: no suggestion');
  finally
    TRpAuthManager.Instance.AIEnabled := True;
    LForm.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAISqlTests.TestDataDialog;
var
  LReport: TRpReport;
  LDlg: TFRpDInfoLCL;
  LCue: TUndoCue;
  LChunks, nOps, I: Integer;
  LStart: QWord;

  function ChatReady: Boolean;
  begin
    Result := LDlg.Chat.HasSchemaItems and (not LDlg.Chat.LoadingSchemas) and
      (LDlg.MonacoEditor.ComboSchema.Items.Count > 1) and
      (LDlg.MonacoEditor.LoadedSchemaTablesId = 5);
  end;
  function Suggested: Boolean;
  begin
    Result := LDlg.Chat.SuggestedExpression <> '';
  end;
  function NotBusy: Boolean;
  begin
    Result := not LDlg.Chat.Busy;
  end;
  function SlowRunning: Boolean;
  begin
    Result := Pos('x2 ', LDlg.Chat.LogView.PlainText) > 0;
  end;
  function AuditDone: Boolean;
  begin
    Result := LDlg.MonacoEditor.AuditButton.Enabled;
  end;
  function AuditStreaming: Boolean;
  begin
    Result := Pos('e2 ', LDlg.Chat.LogView.PlainText) > 0;
  end;
  function ChatSchemasLoaded: Boolean;
  begin
    Result := (not LDlg.Chat.LoadingSchemas) and LDlg.Chat.HasSchemaItems;
  end;
  // The entry of a Hub schema in the list of the chat (its text carries the
  // number of tables, and a warning when the plan is smaller)
  function ChatItemOfSchema(AHubSchemaId: Int64): Integer;
  var
    J: Integer;
    LItem: rpfrmchatlcl.TSchemaComboItem;
  begin
    Result := -1;
    for J := 0 to LDlg.Chat.ComboSchema.Items.Count - 1 do
    begin
      LItem := rpfrmchatlcl.TSchemaComboItem(LDlg.Chat.ComboSchema.Items.Objects[J]);
      if (LItem <> nil) and (LItem.Kind = sckHub) and
        (LItem.HubSchemaId = AHubSchemaId) then
        Exit(J);
    end;
  end;

begin
  Section('SQL assistant of the data configuration dialog');
  TRpAuthManager.Instance.AIEnabled := True;
  LReport := NewReport;
  LDlg := TFRpDInfoLCL.Create(nil);
  try
    LCue := TUndoCue(LReport.UndoCue);
    // Deterministic editor: the fallback one (WebView2 has its own test)
    LDlg.MonacoEditor.ActivateFallback('test');
    LDlg.Report := LReport;
    LDlg.Show;
    Pump(100);
    Check(LDlg.Chat <> nil, 'chat of the SQL assistant created with the dataset');
    Check(LDlg.Chat.Parent <> nil, 'hosted in the dialog');
    Check(LDlg.Chat.ClientToScreen(Types.Point(0, 0)).X >
      LDlg.MonacoEditor.ClientToScreen(Types.Point(0, 0)).X + LDlg.MonacoEditor.Width div 2,
      'at the right of the SQL editor');
    CheckEquals(0, LDlg.ActiveDatasetIndex, 'first dataset');
    CheckEquals(77, LDlg.MonacoEditor.HubDatabaseId, 'hub database of the connection (params)');
    CheckEquals(5, LDlg.MonacoEditor.HubSchemaId, 'hub schema of the dataset');
    CheckEquals('ADO_Net', LDlg.MonacoEditor.RuntimeDb, 'runtime of a Hub connection');
    CheckContains(T(1556, 'Write your query in natural language'), LDlg.Chat.ConversationText,
      'initial message of the SQL chat');
    WaitUntil(ChatReady, 15000, 'schemas of the chat and the editor loaded');
    CheckEquals(5, LDlg.Chat.GetHubSchemaId, 'the chat uses the schema of the dataset');
    CheckEquals(77, LDlg.Chat.GetHubDatabaseId, 'and its hub database');
    CheckEquals(5, LDlg.WorkReport.DataInfo[0].HubSchemaId, 'dataset schema kept');

    // Prompt -> streamed -> suggested SQL
    FHubHandler.TranslateCalls := 0;
    LDlg.Chat.MemoPrompt.Text := 'clients with a balance over 1000';
    LDlg.Chat.BSendClick(nil);
    Check(LDlg.Chat.Busy, 'busy while the SQL is generated');
    WaitUntil(Suggested, 10000, 'SQL suggested');
    Check(not LDlg.Chat.Busy, 'not busy after the answer');
    CheckEquals(SUGGESTED_SQL, LDlg.Chat.SuggestedExpression, 'suggested SQL');
    CheckContains(T(1559, 'Suggested SQL') + ':', LDlg.Chat.ConversationText,
      'suggestion in the chat');
    CheckContains('Clientes con saldo ' + #$C2#$AB + '1000' + #$C2#$BB, LDlg.Chat.ConversationText,
      'explanation in the chat');
    CheckContains('SELECT NAME, BALANCE FROM CLIENTS', LDlg.Chat.LogView.PlainText,
      'stream in the AI log');
    CheckContains('[PreparingContext] Reading the schema', LDlg.Chat.LogView.PlainText,
      'stages in the AI log');
    CheckEquals(1, FHubHandler.TranslateCalls, 'one TranslateToSQLStream request');
    CheckContains('"sqlToRefine":"SELECT * FROM CLIENTS"', FHubHandler.LastTranslateBody,
      'the SQL of the dataset is refined');
    CheckContains('"userQuery":["clients with a balance over 1000"]',
      FHubHandler.LastTranslateBody, 'prompt sent');
    CheckContains('"hubDatabaseId":77', FHubHandler.LastTranslateBody, 'hub database sent');
    CheckContains('"hubSchemaId":5', FHubHandler.LastTranslateBody, 'hub schema sent');
    CheckContains('"runtime":"ADO_Net"', FHubHandler.LastTranslateBody, 'runtime sent');
    CheckEquals(260, TRpAuthManager.Instance.Profile.DailyConsumed, 'credits of the answer');

    // Apply: editor, text memo and working copy; not the report yet
    Check(LDlg.Chat.BApply.Enabled, 'Apply enabled');
    LDlg.Chat.BApplyClick(nil);
    CheckEquals(SUGGESTED_SQL, LDlg.MonacoEditor.SQL, 'SQL applied to the editor');
    CheckEquals(SUGGESTED_SQL, Trim(LDlg.MonacoEditor.FallbackEditor.Text), 'shown in the editor');
    CheckEquals(SUGGESTED_SQL, Trim(LDlg.SQLMemo.Text), 'and in the text editor');
    CheckEquals(SUGGESTED_SQL, LDlg.WorkReport.DataInfo[0].SQL, 'working copy updated');
    CheckEquals('SELECT * FROM CLIENTS', LReport.DataInfo[0].SQL, 'report untouched until OK');
    CheckContains(T(1557, 'SQL applied to the editor.'), LDlg.Chat.ConversationText,
      'apply confirmed in the chat');
    // Undo in the editor and again
    LDlg.MonacoEditor.FallbackEditor.Undo;
    CheckEquals('SELECT * FROM CLIENTS', LDlg.MonacoEditor.SQL, 'Ctrl+Z in the editor undoes the apply');
    LDlg.MonacoEditor.FallbackEditor.Redo;
    CheckEquals(SUGGESTED_SQL, LDlg.MonacoEditor.SQL, 'and redo applies it again');
    Shot(LDlg, 'sql_assistant_dialog');

    // An error of the service
    LDlg.Chat.MemoPrompt.Text := 'fail please';
    LDlg.Chat.BSendClick(nil);
    WaitUntil(NotBusy, 10000, 'error answered');
    CheckEquals('The model could not answer', LDlg.Chat.LastAssistantMessage, 'error in the chat');
    CheckEquals('', LDlg.Chat.SuggestedExpression, 'no suggestion');

    // Stop in the middle of the stream
    LDlg.Chat.MemoPrompt.Text := 'slow please';
    LDlg.Chat.BSendClick(nil);
    WaitUntil(SlowRunning, 10000, 'slow stream running');
    LDlg.Chat.BClearClick(nil);
    Check(not LDlg.Chat.Busy, 'Stop ends the busy state at once');
    CheckEquals(T(1536, 'Generation stopped.'), LDlg.Chat.LastAssistantMessage, 'stop message');
    LChunks := Length(LDlg.Chat.LogView.PlainText);
    LStart := GetTickCount64;
    Check(RpAsyncWaitIdle(3000), 'the worker ends soon after the stop');
    Check(ElapsedMs(LStart) < 2500, Format('cancel is prompt (%d ms; the stream lasts 6 s)',
      [ElapsedMs(LStart)]));
    Pump(200);
    CheckEquals(LChunks, Length(LDlg.Chat.LogView.PlainText), 'no chunk after the stop');
    CheckEquals('', LDlg.Chat.SuggestedExpression, 'nothing suggested');
    CheckEquals(T(1536, 'Generation stopped.'), LDlg.Chat.LastAssistantMessage,
      'no message after the stop');

    // Audit (explain) of the SQL
    LDlg.MonacoEditor.AuditButton.Click;
    Check(LDlg.MonacoEditor.PageControl.ActivePage = LDlg.MonacoEditor.TabAudit, 'audit page shown');
    Check(not LDlg.MonacoEditor.AuditButton.Enabled, 'audit busy');
    WaitUntil(AuditDone, 10000, 'audit finished');
    CheckEquals(AUDIT_TEXT, Trim(LDlg.MonacoEditor.MemoAudit.Text), 'explanation shown');
    CheckEquals(AUDIT_TEXT, LDlg.WorkReport.DataInfo[0].SQLExplanation,
      'explanation kept in the dataset');
    CheckContains('"sqlToExplain":"' + SUGGESTED_SQL + '"', FHubHandler.LastExplainBody,
      'the SQL of the editor is explained');
    CheckContains('Audit SQL complete. Input Tokens: 50 Output Tokens: 12',
      LDlg.Chat.LogView.PlainText, 'audit log in the chat');

    // The Stop of the model selection of the editor stops the audit
    LDlg.MonacoEditor.SQL := 'SELECT slow FROM CLIENTS';
    LDlg.MonacoEditor.AuditButton.Click;
    WaitUntil(AuditStreaming, 10000, 'slow audit running');
    Check(not LDlg.MonacoEditor.AuditButton.Enabled, 'slow audit busy');
    LStart := GetTickCount64;
    LDlg.MonacoEditor.AISelection.BStopInferenceClick(nil);
    Check(LDlg.MonacoEditor.AuditButton.Enabled, 'Stop ends the audit at once');
    CheckContains('Audit SQL stopped.', LDlg.Chat.LogView.PlainText, 'stop in the log');
    Check(RpAsyncWaitIdle(3000), 'the audit worker ends soon after the stop');
    Check(ElapsedMs(LStart) < 2500, Format('audit cancel is prompt (%d ms; the stream lasts 4 s)',
      [ElapsedMs(LStart)]));
    Pump(200);
    CheckEquals(AUDIT_TEXT, LDlg.WorkReport.DataInfo[0].SQLExplanation,
      'the stopped audit stores nothing');
    LDlg.MonacoEditor.SQL := SUGGESTED_SQL;
    LDlg.MonacoEditor.PageControl.ActivePage := LDlg.MonacoEditor.TabSQL;

    // Schema chosen in the editor: kept in the dataset, the chat follows
    I := LDlg.MonacoEditor.ComboSchema.Items.IndexOf('Sales / Archive');
    Check(I > 0, 'second schema of the connection listed');
    LDlg.MonacoEditor.ComboSchema.ItemIndex := I;
    LDlg.MonacoEditor.ComboSchema.OnChange(LDlg.MonacoEditor.ComboSchema);
    CheckEquals(8, LDlg.WorkReport.DataInfo[0].HubSchemaId, 'dataset schema from the editor');
    CheckEquals(8, LDlg.Chat.GetHubSchemaId, 'the chat follows (SetHubContext)');

    // Second dataset: its own SQL and the Hub database of the connection
    // (its schema, 99, is not in the lists: another account, no access)
    LDlg.WorkReport.DataInfo[1].HubSchemaId := 99;
    LDlg.DatasetList.ItemIndex := 1;
    LDlg.DatasetList.OnClick(LDlg.DatasetList);
    CheckEquals(1, LDlg.ActiveDatasetIndex, 'second dataset selected');
    CheckEquals(77, LDlg.MonacoEditor.HubDatabaseId, 'same Hub database');
    CheckEquals('SELECT * FROM ORDERS', LDlg.MonacoEditor.SQL, 'its SQL in the editor');
    CheckEquals(SUGGESTED_SQL, LDlg.WorkReport.DataInfo[0].SQL, 'first dataset keeps the applied SQL');

    // The chat reloads its list: it falls back to a schema of the connection,
    // but that is not a choice of the user and the dataset keeps its own
    LDlg.Chat.BRefreshSchemasClick(nil);
    WaitUntil(ChatSchemasLoaded, 10000, 'schemas of the chat reloaded');
    Pump(100);
    Check(LDlg.Chat.GetHubSchemaId <> 99, 'the chat falls back to a listed schema');
    CheckEquals(99, LDlg.WorkReport.DataInfo[1].HubSchemaId,
      'the fallback of the list does not replace the schema of the dataset');
    // A schema chosen by the user in the chat is kept
    I := ChatItemOfSchema(5);
    Check(I > 0, 'schema listed in the chat');
    CheckContains('Sales / Main', LDlg.Chat.ComboSchema.Items[I],
      'with its name (and its tables)');
    LDlg.Chat.ComboSchema.ItemIndex := I;
    LDlg.Chat.ComboSchema.OnChange(LDlg.Chat.ComboSchema);
    CheckEquals(5, LDlg.WorkReport.DataInfo[1].HubSchemaId, 'the choice of the user is kept');

    // OK: recorded in the undo cue as one group
    nOps := LCue.UndoOperations.Count;
    Check(LDlg.ApplyChanges, 'OK applies');
    CheckEquals(SUGGESTED_SQL, LReport.DataInfo[0].SQL, 'report SQL applied');
    CheckEquals(8, LReport.DataInfo[0].HubSchemaId, 'report schema applied');
    CheckEquals(AUDIT_TEXT, LReport.DataInfo[0].SQLExplanation, 'report explanation applied');
    Check(LCue.UndoOperations.Count > nOps, 'undo operations recorded');
    Check(LReport.Modified, 'report modified');
    LCue.Undo.Free;
    CheckEquals('SELECT * FROM CLIENTS', LReport.DataInfo[0].SQL, 'undo restores the SQL');
    CheckEquals(5, LReport.DataInfo[0].HubSchemaId, 'undo restores the schema');
    LCue.Redo.Free;
    CheckEquals(SUGGESTED_SQL, LReport.DataInfo[0].SQL, 'redo applies the SQL again');
  finally
    LDlg.Free;
    LReport.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
end;

procedure TAISqlTests.TestWebView2;
{$IFDEF MSWINDOWS}
var
  LForm: TForm;
  LEditor: TFRpMonacoEditorLCL;
  LDlg: TFRpDInfoLCL;
  LReport: TRpReport;
  LMsg: string;
  I: Integer;

  function Ready: Boolean;
  begin
    Result := LEditor.EditorReady or LEditor.UseFallback;
  end;
  function TablesLoaded: Boolean;
  begin
    Result := LEditor.LoadedSchemaTablesId = 5;
  end;
  function MessageWith(const APrefix: string): string;
  var
    J: Integer;
  begin
    Result := '';
    for J := FWebMessages.Count - 1 downto 0 do
      if Copy(FWebMessages[J], 1, Length(APrefix)) = APrefix then
        Exit(FWebMessages[J]);
  end;
  function Got99: Boolean;
  begin
    Result := MessageWith('99:') <> '';
  end;
  function Got98: Boolean;
  begin
    Result := MessageWith('98:') <> '';
  end;
  function Got97: Boolean;
  begin
    Result := MessageWith('97:') <> '';
  end;
  function Got96: Boolean;
  begin
    Result := Pos('CLIENTS', MessageWith('96:')) > 0;
  end;
  function DialogReady: Boolean;
  begin
    Result := (LDlg.MonacoEditor.EditorReady or LDlg.MonacoEditor.UseFallback) and
      (LDlg.Chat.ComboSchema.Items.Count > 1) and (LDlg.MonacoEditor.LoadedSchemaTablesId = 5);
  end;
  function Suggested: Boolean;
  begin
    Result := LDlg.Chat.SuggestedExpression <> '';
  end;
  function Applied: Boolean;
  begin
    Result := Pos('WHERE BALANCE', MessageWith('95:')) > 0;
  end;
{$ENDIF}

begin
{$IFDEF MSWINDOWS}
  Section('Monaco in WebView2 (Windows): schema and AI completion in the page');
  RpWebMarkdownForceNative := False;
  LForm := NewForm(820, 460);
  try
    LEditor := TFRpMonacoEditorLCL.Create(LForm);
    LEditor.OnWebMessage := EditorWebMessage;
    LEditor.Parent := LForm;
    LEditor.Align := alClient;
    LEditor.SetHubContext(77, 5, 'sql-key');
    LEditor.SQL := 'SELECT * FROM CLIENTS C WHERE C.BALANCE > 0';
    LForm.Show;
    WaitUntil(Ready, 30000, 'Monaco ready (or fallback)');
    if LEditor.UseFallback then
    begin
      Skip('WebView2 not available here');
      Exit;
    end;
    WaitUntil(TablesLoaded, 10000, 'tables of the schema loaded');
    FWebMessages.Clear;
    LEditor.WebView.ExecuteScript('window.chrome.webview.postMessage("98:" + ' +
      '(typeof window.rpReceiveSchemaCompletions) + ":" + (window.rpSchemaBridge === true));');
    WaitUntil(Got98, 10000, 'state of the page');
    CheckEquals('98:function:true', MessageWith('98:'), 'schema provider installed in the page');
    // Round trip: page -> 03: -> Pascal -> rpReceiveSchemaCompletions
    LEditor.WebView.ExecuteScript('window.rpSchemaRequests["t1"] = function (items) {' +
      ' window.chrome.webview.postMessage("99:" + JSON.stringify(items)); };' +
      ' window.chrome.webview.postMessage("03:t1:14:1\nSELECT * FROM ");');
    WaitUntil(Got99, 10000, 'schema completion round trip');
    CheckContains('"label":"CLIENTS"', MessageWith('99:'), 'tables received by the page');
    // AI completion round trip (02: -> SuggestSql -> receiveAICompletions)
    TRpAuthManager.Instance.AIEnabled := True;
    LEditor.DebounceTimer.Interval := 30;
    LEditor.WebView.ExecuteScript('window.pendingCompletionRequests["x1"] = function (r) {' +
      ' window.chrome.webview.postMessage("97:" + JSON.stringify(r)); };' +
      ' window.chrome.webview.postMessage("02:x1:9\nSELECT N ");');
    WaitUntil(Got97, 15000, 'AI completion round trip');
    CheckContains('"insertText":"NAME FROM CLIENTS"', MessageWith('97:'), 'AI items received');
    // The real suggest widget of Monaco with the provider (AI off: only the schema)
    TRpAuthManager.Instance.AIEnabled := False;
    LEditor.WebView.ExecuteScript('window.editor.setValue("SELECT * FROM ");' +
      ' window.editor.setPosition({ lineNumber: 1, column: 15 }); window.editor.focus();' +
      ' window.editor.trigger("test", "editor.action.triggerSuggest", {});');
    for I := 1 to 25 do
    begin
      Pump(200);
      LEditor.WebView.ExecuteScript('window.chrome.webview.postMessage("96:" + ' +
        'Array.prototype.map.call(document.querySelectorAll(".suggest-widget .monaco-list-row"),' +
        ' function (e) { return e.getAttribute("aria-label") || e.textContent; }).join("|"));');
      Pump(100);
      if Got96 then
        Break;
    end;
    if Got96 then
    begin
      Pass('Monaco suggest widget lists the schema tables');
      CheckContains('ORDERS', MessageWith('96:'), 'both tables in the widget');
      ScreenShot(LForm, 'sql_monaco_completion');
    end
    else
      Skip('the suggest widget did not open here: ' + MessageWith('96:'));
    TRpAuthManager.Instance.AIEnabled := True;
  finally
    LForm.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');

  // The dialog as the Windows designer shows it
  LReport := NewReport;
  LDlg := TFRpDInfoLCL.Create(nil);
  try
    LDlg.Report := LReport;
    LDlg.MonacoEditor.OnWebMessage := EditorWebMessage;
    LDlg.Show;
    WaitUntil(DialogReady, 30000, 'dialog with Monaco ready');
    if not LDlg.MonacoEditor.UseFallback then
    begin
      LDlg.Chat.MemoPrompt.Text := 'clients with a balance over 1000';
      LDlg.Chat.BSendClick(nil);
      WaitUntil(Suggested, 10000, 'SQL suggested');
      LDlg.Chat.BApplyClick(nil);
      FWebMessages.Clear;
      LDlg.MonacoEditor.WebView.ExecuteScript('window.chrome.webview.postMessage("95:" + ' +
        'window.editor.getValue());');
      WaitUntil(Applied, 10000, 'applied SQL in Monaco');
      LMsg := MessageWith('95:');
      CheckEquals('95:' + SUGGESTED_SQL, LMsg, 'Monaco shows the applied SQL');
      ScreenShot(LDlg, 'sql_assistant_monaco');
    end;
  finally
    LDlg.Free;
    LReport.Free;
    RpWebMarkdownForceNative := True;
  end;
  Check(RpAsyncWaitIdle(10000), 'workers finished');
{$ENDIF}
end;

procedure TAISqlTests.Run;
var
  LIni: TStringList;
  LSandbox: string;
begin
  LSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rpaichattest', LSandbox) = 0 then
    Fail('the tests must run in the sandbox (LOCALAPPDATA=' + LSandbox + ')');
  // Connection of the datasets: its Hub database and API key
  LIni := TStringList.Create;
  try
    LIni.Add('[HUBSQL]');
    LIni.Add('ApiKey=sql-key');
    LIni.Add('HubDatabaseId=77');
    LIni.SaveToFile(IncludeTrailingPathDelimiter(LSandbox) + 'dbxconnections_sql.ini');
  finally
    LIni.Free;
  end;
  DBXConnectionsFileOverride := IncludeTrailingPathDelimiter(LSandbox) + 'dbxconnections_sql.ini';
  RpWebMarkdownForceNative := True;

  FHubHandler := TSqlFakeHub.Create;
  FHub := TFakeServer.Create(FHubHandler.Handle);
  try
    FHub.Start;
    Log('  fake Hub (SQL) on ' + FHub.BaseURL + ' for ' + HUB_API_URL);
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
    try
      TestEngine;
      Check(TRpAuthManager.Instance.LoginWithCode('ana@example.com', '123456'),
        'login with the email code (fake Hub)');
      Pump(50);
      TestMonacoBridge;
      TestFallbackEditor;
      TestFallbackAISuggestion;
      TestDataDialog;
      TestWebView2;
      TRpAuthManager.Instance.Logout;
      Check(RpAsyncWaitIdle(10000), 'all workers finished');
    finally
      RpHttpSetUrlRewrite('', '');
    end;
  finally
    FHub.Free;
    FHubHandler.Free;
  end;
  // TFPHttpServer counts a connection as closed before its thread object
  // (FreeOnTerminate) is freed: give the last ones time before heaptrc
  // checks the memory at exit
  Pump(500);
end;

procedure RunAISqlTests(const AShotsDir: string);
var
  LTests: TAISqlTests;
begin
  LTests := TAISqlTests.Create(AShotsDir);
  try
    LTests.Run;
  finally
    LTests.Free;
  end;
end;

end.

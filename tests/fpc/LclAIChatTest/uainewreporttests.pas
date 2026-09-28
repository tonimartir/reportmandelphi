{ Phase 8 tests: File > New of the LCL designer runs the new report wizard
  (rpmdfnewreportwizardlcl, port of rpmdfnewreportwizardvcl) with its
  connections in dbxconnections (rpdbxadminlcl), against a local fake Hub (no
  external network) and a dbxconnections file of the sandbox.

  Covers the connection functions (create, parameters with their editors,
  save, tests of SQLite, Zeos and Agent connections); the routes of the
  wizard driven on a shown form: no connection, Reportman AI with a new
  connection (API key login, Hub databases, failed and good connection test
  in worker threads, schema), Reportman AI with an existing connection,
  direct SQLite with a Hub schema and a new connection with its parameters,
  direct Zeos without schema and the prompt question; the layout on an
  800x600 screen; and File > New of the designer with the modal wizard
  driven by a timer: Cancel keeps the report, the finished wizard installs
  the new report, the design chat gets the Hub context of the wizard and
  sends its prompt (showing the hidden AI panel), and the classic blank
  report without the wizard. }
unit uainewreporttests;

{$mode delphi}{$H+}
{$modeswitch nestedprocvars}

interface

// AShotsDir: screenshots of the wizard pages are saved there when not empty
procedure RunAINewReportTests(const AShotsDir: string);

implementation

uses
  SysUtils, Classes, Types, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  IniFiles, Generics.Collections, fphttpserver, httpdefs, rpjsonfpc, rphttpclientfpc, rptypes, rpreport, rpsubreport, rpsection,
  rpdatainfo, rpauthmanager, rpaithreadslcl, rpwebmarkdownlcl, rpmdfmainlcl,
  rpgraphutilslcl, rpmdconsts, rpdbxadminlcl, rpmdfnewreportwizardlcl,
  utestutil, ufakeserver;

const
  ANSWERED_TAG = $8008;
  KEY_OK = 'key-ok';
  KEY_EXIST = 'key-exist';
  KEY_BAD = 'key-bad';
  PROMPT_AGENT = 'Sales by customer with a group total';
  PROMPT_DESIGNER = 'Add a title with the report name';

type
  TCondition = function: Boolean is nested;

  { TNewReportFakeHub: the Hub endpoints used by the wizard and the design
    chat. API key key-ok sees two databases (the test of database 22
    fails), key-exist one, key-bad none (401); the session sees the
    databases of the account. }

  TNewReportFakeHub = class
  private
    FLock: TRTLCriticalSection;
    FTestRequests: TStringList;
    FModifyBodies: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
    procedure ClearRequests;
    function TestCount: Integer;
    // "hubDatabaseId|X-Reportman-ApiKey" of a api/agent/testconnection
    function TestRequest(AIndex: Integer): string;
    function LastTestRequest: string;
    function ModifyCount: Integer;
    function ModifyBody(AIndex: Integer): string;
  end;

  { Answers the RpMessageBox dialogs (TFRpMessageDlgVCL) from a timer, also
    inside their modal loop, and keeps their texts }

  TDialogAnswerer = class
  private
    FTimer: TTimer;
    procedure Tick(Sender: TObject);
  public
    Answer: TMessageButton;
    Answered: Integer;
    LastText: string;
    constructor Create;
    destructor Destroy; override;
    procedure Arm(AAnswer: TMessageButton);
  end;

  TDriverScript = (dsNone, dsCancel, dsAgentPrompt);

  { TAINewReportTests }

  TAINewReportTests = class
  private
    FShotsDir: string;
    FSandbox: string;
    FConnFile: string;
    FHub: TFakeServer;
    FHubHandler: TNewReportFakeHub;
    FAnswerer: TDialogAnswerer;
    FSqliteAvailable: Boolean;
    // Driver of the modal wizard of File > New
    FDriverTimer: TTimer;
    FDriverScript: TDriverScript;
    FDriverStep: Integer;
    FDriverStart: QWord;
    FDriverError: string;
    FDriverWizardSeen: Boolean;
    procedure DriverTick(Sender: TObject);
    procedure DriveAgentPrompt(AWizard: TFRpNewReportWizardLCL);
    procedure StartDriver(AScript: TDriverScript);
    procedure CheckDriverDone(const AContext: string);
    procedure Pump(AMs: Cardinal);
    procedure WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal; const AWhat: string);
    procedure Shot(AControl: TWinControl; const AName: string);
    function NewWizard(out AReport: TRpReport): TFRpNewReportWizardLCL;
    procedure FreeWizard(var AWizard: TFRpNewReportWizardLCL; var AReport: TRpReport);
    procedure WaitIdle(AWizard: TFRpNewReportWizardLCL; const AWhat: string);
    procedure CheckPage(AWizard: TFRpNewReportWizardLCL; APage: TRpWizardPage;
      const AContext: string);
    function IniValue(const ASection, AKey: string): string;
    function IniHasKey(const ASection, AKey: string): Boolean;
    function IniKeyCount(const ASection: string): Integer;
    procedure WriteConnectionsFile;
    function CheckSqliteAvailable: Boolean;
    procedure CheckNewReportSections(AReport: TRpReport; const AContext: string);
    procedure TestAdmin;
    procedure TestLayout;
    procedure TestRouteNoConnection;
    procedure TestAgentNewConnection;
    procedure TestAgentExistingConnection;
    procedure TestDirectSqlite;
    procedure TestDirectZeos;
    procedure TestDesignerFileNew;
  public
    constructor Create(const AShotsDir: string);
    destructor Destroy; override;
    procedure Run;
  end;

{ Helpers }

function T(AId: Integer; const ADefault: string): string;
begin
  Result := string(TranslateStr(AId, WideString(ADefault)));
end;

function ProfileJson: string;
begin
  Result := '{"userId":7,"email":"ana@example.com","userName":"Ana",' +
    '"profileImageUrl":"","accountType":1,"tierId":4,"tierName":"Pro",' +
    '"dailyMax":1000,"dailyConsumed":250,"freeInitial":100,"freeRemaining":40,' +
    '"serverDay":"2026-09-27T00:00:00Z","credits":5}';
end;

function ProgressEvent(const AChunkType, AChunk, AId: string): string;
begin
  Result := '{"actor":"AI","stage":"ReceivingResponse","chunkType":"' + AChunkType +
    '","chunk":"' + AChunk + '","id":"' + AId + '","inputTokens":120,"outputTokens":7,' +
    '"prefillPercentage":0}';
end;

// The final event of ModifyReportStream with the modified document
function ModifyResultJson(const ADocument: string): string;
var
  LRoot, LResult, LProfile: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LResult := TJSONObject.Create;
    LResult.AddPair('contextJson', '{}');
    LResult.AddPair('operationsJson', '[]');
    LResult.AddPair('modifiedReportDocument', ADocument);
    LResult.AddPair('explanation', 'Report designed');
    LResult.AddPair('errorMessage', '');
    LResult.AddPair('reportFormat', 'Xml');
    LResult.AddPair('success', TJSONBool.Create(True));
    LRoot.AddPair('result', LResult);
    LRoot.AddPair('steps', TJSONArray.Create);
    LRoot.AddPair('creditsConsumed', TJSONNumber.Create(12));
    LRoot.AddPair('debugDetails', '');
    LRoot.AddPair('errorMessage', '');
    LProfile := TJSONObject.ParseJSONValue(ProfileJson) as TJSONObject;
    LRoot.AddPair('userProfile', LProfile);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

// A value of a JSON document by its path (a.b.c), '' when it is not there
function JsonPath(const AJson, APath: string): string;
var
  LRoot, LValue: TJSONValue;
  LParts: TStringList;
  I: Integer;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AJson);
  if LRoot = nil then
    Exit;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '.';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := APath;
    LValue := LRoot;
    for I := 0 to LParts.Count - 1 do
    begin
      if LValue is TJSONObject then
        LValue := TJSONObject(LValue).Values[LParts[I]]
      else if LValue is TJSONArray then
        LValue := TJSONArray(LValue).Items[StrToIntDef(LParts[I], 0)]
      else
        LValue := nil;
      if LValue = nil then
        Exit;
    end;
    Result := LValue.Value;
  finally
    LParts.Free;
    LRoot.Free;
  end;
end;

function DatabasesJson(const AItems: array of string): string;
var
  I: Integer;
begin
  // AItems: display name, hubDatabaseId, hubSchemaId, ...
  Result := '{"databases":[';
  I := 0;
  while I + 2 <= High(AItems) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + '{"displayName":"' + AItems[I] + '","name":"' +
      LowerCase(AItems[I]) + '","hubDatabaseId":' + AItems[I + 1] +
      ',"hubSchemaId":' + AItems[I + 2] + '}';
    Inc(I, 3);
  end;
  Result := Result + '],"aiEndpoints":[]}';
end;

{ TNewReportFakeHub }

constructor TNewReportFakeHub.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FTestRequests := TStringList.Create;
  FModifyBodies := TStringList.Create;
end;

destructor TNewReportFakeHub.Destroy;
begin
  FModifyBodies.Free;
  FTestRequests.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TNewReportFakeHub.Handle(AServer: TFakeServer;
  ARequest: TFPHTTPConnectionRequest; AResponse: TFPHTTPConnectionResponse);
var
  P, LBody, LKey, LId: string;
  LEvents: array of string;
begin
  P := ARequest.PathInfo;
  LBody := ARequest.Content;
  LKey := ARequest.GetCustomHeader('X-Reportman-ApiKey');
  if P = '/api/userprofile/status' then
  begin
    if Pos('Bearer tok', ARequest.Authorization) = 1 then
      SendJson(AResponse, 200, '{"profile":' + ProfileJson + ',"tiers":[]}')
    else
      SendJson(AResponse, 401, '{}');
  end
  else if P = '/api/Login/email' then
    SendJson(AResponse, 200, '{"token":"toknewreport","profile":' + ProfileJson +
      ',"tiers":[]}')
  else if P = '/api/Tiers' then
    SendJson(AResponse, 200, '[]')
  else if P = '/api/agent/databases' then
  begin
    if LKey = KEY_OK then
      SendJson(AResponse, 200, DatabasesJson(['Sales DB', '21', '31', 'HR DB', '22', '32']))
    else if LKey = KEY_EXIST then
      SendJson(AResponse, 200, DatabasesJson(['Existing DB', '11', '41']))
    else if LKey <> '' then
      SendJson(AResponse, 401, '{"message":"Invalid API key"}')
    else if Pos('Bearer tok', ARequest.Authorization) = 1 then
      SendJson(AResponse, 200, DatabasesJson(['Account DB', '51', '61']))
    else
      SendJson(AResponse, 200, '{"databases":[],"aiEndpoints":[]}');
  end
  else if P = '/api/agent/testconnection' then
  begin
    LId := JsonPath(LBody, 'hubDatabaseId');
    EnterCriticalSection(FLock);
    try
      FTestRequests.Add(LId + '|' + LKey);
    finally
      LeaveCriticalSection(FLock);
    end;
    if LId = '22' then
      SendJson(AResponse, 500, '{"message":"Database offline"}')
    else
      SendJson(AResponse, 200, '{"success":true,"data":{"message":' +
        '"Agent Connection: Success, database ' + LId + '"}}');
  end
  else if P = '/ReportDesigner/PreprocessSqlContextStream' then
  begin
    SetLength(LEvents, 1);
    LEvents[0] := '{"result":{"dataSources":[]},"steps":[],"creditsConsumed":0,' +
      '"debugDetails":"","errorMessage":""}';
    SendEvents(AResponse, LEvents, 10, True, True);
  end
  else if P = '/ReportDesigner/ModifyReportStream' then
  begin
    EnterCriticalSection(FLock);
    try
      FModifyBodies.Add(LBody);
    finally
      LeaveCriticalSection(FLock);
    end;
    // The report it received, as the designed one
    SetLength(LEvents, 4);
    LEvents[0] := '{"actor":"Designer","stage":"Planning","chunk":"Planning the report"}';
    LEvents[1] := ProgressEvent('Partial', 'Designing', 'd1');
    LEvents[2] := ProgressEvent('End', '', 'd1');
    LEvents[3] := ModifyResultJson(JsonPath(LBody, 'reportDocument'));
    SendEvents(AResponse, LEvents, 20, True, True);
  end
  else
    SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
end;

procedure TNewReportFakeHub.ClearRequests;
begin
  EnterCriticalSection(FLock);
  try
    FTestRequests.Clear;
    FModifyBodies.Clear;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TNewReportFakeHub.TestCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FTestRequests.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TNewReportFakeHub.TestRequest(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FTestRequests[AIndex];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TNewReportFakeHub.LastTestRequest: string;
begin
  EnterCriticalSection(FLock);
  try
    if FTestRequests.Count = 0 then
      Result := ''
    else
      Result := FTestRequests[FTestRequests.Count - 1];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TNewReportFakeHub.ModifyCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FModifyBodies.Count;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TNewReportFakeHub.ModifyBody(AIndex: Integer): string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FModifyBodies[AIndex];
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ TDialogAnswerer }

constructor TDialogAnswerer.Create;
begin
  inherited Create;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 30;
  FTimer.OnTimer := Tick;
  FTimer.Enabled := True;
  Answer := smbOK;
end;

destructor TDialogAnswerer.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TDialogAnswerer.Arm(AAnswer: TMessageButton);
begin
  Answer := AAnswer;
end;

procedure TDialogAnswerer.Tick(Sender: TObject);
var
  I: Integer;
  LForm: TCustomForm;
  LDialog: TFRpMessageDlgVCL;
  LButton: TButton;
begin
  for I := 0 to Screen.CustomFormCount - 1 do
  begin
    LForm := Screen.CustomForms[I];
    // Tag: answered already (closing a modal form is not immediate on every
    // widgetset)
    if (LForm is TFRpMessageDlgVCL) and LForm.Visible and (fsModal in LForm.FormState) and
       (LForm.Tag <> ANSWERED_TAG) then
    begin
      LForm.Tag := ANSWERED_TAG;
      LDialog := TFRpMessageDlgVCL(LForm);
      LastText := LDialog.LMessage.Caption;
      Inc(Answered);
      case Answer of
        smbYes: LButton := LDialog.BYes;
        smbNo: LButton := LDialog.BNo;
        smbCancel: LButton := LDialog.BCancel;
      else
        LButton := LDialog.BOk;
      end;
      // A dialog without that button: OK
      if not LButton.Visible then
        LButton := LDialog.BOk;
      Log('  answering "' + Copy(StringReplace(LastText, LineEnding, ' ', [rfReplaceAll]),
        1, 70) + '..." with ' + LButton.Caption);
      LDialog.BYesClick(LButton);
      Exit;
    end;
  end;
end;

{ TAINewReportTests }

constructor TAINewReportTests.Create(const AShotsDir: string);
begin
  inherited Create;
  FShotsDir := AShotsDir;
end;

destructor TAINewReportTests.Destroy;
begin
  inherited Destroy;
end;

procedure TAINewReportTests.Pump(AMs: Cardinal);
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

procedure TAINewReportTests.WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
  const AWhat: string);
var
  LStart: QWord;
begin
  LStart := GetTickCount64;
  while not ACondition() do
  begin
    if GetTickCount64 - LStart > ATimeoutMs then
      Fail('timeout waiting for ' + AWhat + ' (Hub requests: ' + FHub.RequestLog + ')');
    Application.ProcessMessages;
    CheckSynchronize(0);
    Sleep(5);
  end;
  Pass(AWhat);
end;

procedure TAINewReportTests.Shot(AControl: TWinControl; const AName: string);
var
  LBitmap: TBitmap;
  LPng: TPortableNetworkGraphic;
begin
  if FShotsDir = '' then
    Exit;
  Pump(300);
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

function TAINewReportTests.NewWizard(out AReport: TRpReport): TFRpNewReportWizardLCL;
begin
  // As NewModernReportWizard, shown without its modal loop
  AReport := TRpReport.Create(nil);
  RpPrepareModernNewReport(AReport);
  Result := TFRpNewReportWizardLCL.Create(nil);
  Result.DestReport := AReport;
  Result.Show;
  Pump(150);
end;

procedure TAINewReportTests.FreeWizard(var AWizard: TFRpNewReportWizardLCL;
  var AReport: TRpReport);
begin
  FreeAndNil(AWizard);
  FreeAndNil(AReport);
  Check(RpAsyncWaitIdle(15000), 'workers of the wizard finished');
end;

procedure TAINewReportTests.WaitIdle(AWizard: TFRpNewReportWizardLCL; const AWhat: string);

  function Idle: Boolean;
  begin
    Result := AWizard.Operation = woNone;
  end;

begin
  WaitUntil(Idle, 20000, AWhat);
  // The dialog of the result is answered inside the delivery
  Pump(50);
end;

procedure TAINewReportTests.CheckPage(AWizard: TFRpNewReportWizardLCL;
  APage: TRpWizardPage; const AContext: string);
begin
  CheckEquals(Ord(APage), Ord(AWizard.CurrentPage), AContext);
end;

function TAINewReportTests.IniValue(const ASection, AKey: string): string;
var
  LIni: TMemIniFile;
begin
  LIni := TMemIniFile.Create(FConnFile);
  try
    Result := LIni.ReadString(ASection, AKey, '');
  finally
    LIni.Free;
  end;
end;

function TAINewReportTests.IniHasKey(const ASection, AKey: string): Boolean;
var
  LIni: TMemIniFile;
begin
  LIni := TMemIniFile.Create(FConnFile);
  try
    Result := LIni.ValueExists(ASection, AKey);
  finally
    LIni.Free;
  end;
end;

function TAINewReportTests.IniKeyCount(const ASection: string): Integer;
var
  LIni: TMemIniFile;
  LKeys: TStringList;
begin
  LIni := TMemIniFile.Create(FConnFile);
  LKeys := TStringList.Create;
  try
    LIni.ReadSection(ASection, LKeys);
    Result := LKeys.Count;
  finally
    LKeys.Free;
    LIni.Free;
  end;
end;

procedure TAINewReportTests.WriteConnectionsFile;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Add('[AGENT_EXIST]');
    L.Add('DriverName=Reportman AI Agent');
    L.Add('ApiKey=' + KEY_EXIST);
    L.Add('HubDatabaseId=11');
    L.Add('[SQLITE_EXIST]');
    L.Add('DriverName=Sqlite');
    L.Add('Database=' + IncludeTrailingPathDelimiter(FSandbox) + 'exist.db');
    L.Add('[FIREDAC_FB]');
    L.Add('DriverName=FireDac');
    L.Add('DriverID=FB');
    L.Add('Database=x.fdb');
    L.Add('[ZEOS_EXIST]');
    L.Add('DriverName=ZeosLib');
    L.Add('Database Protocol=sqlite');
    L.Add('Database=' + IncludeTrailingPathDelimiter(FSandbox) + 'zeosexist.db');
    L.Add('[DBX_IB]');
    L.Add('DriverName=Interbase');
    L.Add('Database=x.gdb');
    L.SaveToFile(FConnFile);
  finally
    L.Free;
  end;
end;

function TAINewReportTests.CheckSqliteAvailable: Boolean;
var
  LParams: TStringList;
  LResult: TRpDbxConnectionTestResult;
begin
  // The SQLite client library (sqlite3.dll / libsqlite3.so.0), loaded as the
  // FireDAC driver of the FPC engine does
  LParams := TStringList.Create;
  try
    LParams.Values['DriverName'] := 'Sqlite';
    LParams.Values['Database'] := IncludeTrailingPathDelimiter(FSandbox) + 'probe.db';
    LResult := RpExecuteConnectionTest('SQLITE_PROBE', LParams, '');
    Result := LResult.Success;
    if not Result then
      Log('  SQLite client library not available: ' + LResult.MessageText);
  finally
    LParams.Free;
  end;
end;

procedure TAINewReportTests.CheckNewReportSections(AReport: TRpReport;
  const AContext: string);
var
  LSub: TRpSubReport;
  I: Integer;
  LAll275, LTotal: Boolean;
begin
  // rpmdfnewreportwizardvcl: CreateNew, a TOTAL group, sections of 275
  CheckEquals(1, AReport.SubReports.Count, AContext + ': one subreport');
  LSub := AReport.SubReports[0].SubReport;
  CheckEquals(1, LSub.GroupCount, AContext + ': one group');
  CheckEquals(3, LSub.Sections.Count, AContext + ': group header, detail, group footer');
  LAll275 := True;
  LTotal := False;
  for I := 0 to LSub.Sections.Count - 1 do
  begin
    if LSub.Sections[I].Section.Height <> 275 then
      LAll275 := False;
    if SameText(LSub.Sections[I].Section.GroupName, 'TOTAL') then
      LTotal := True;
  end;
  Check(LTotal, AContext + ': the group is TOTAL');
  Check(LAll275, AContext + ': sections of 275 twips');
end;

{ Connections }

procedure TAINewReportTests.TestAdmin;
var
  LAdmin: TRpDbxAdminLCL;
  LParams: TList<TRpDbxConnectionParam>;
  LValues, LTest: TStringList;
  LResult: TRpDbxConnectionTestResult;
  LRaised: Boolean;
  LDbFile: string;

  function ParamIndex(const AName: string): Integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := 0 to LParams.Count - 1 do
      if SameText(LParams[I].Name, AName) then
        Exit(I);
  end;

begin
  Section('New report wizard: connections of dbxconnections (rpdbxadminlcl)');
  LAdmin := TRpDbxAdminLCL.Create;
  LParams := TList<TRpDbxConnectionParam>.Create;
  LValues := TStringList.Create;
  LTest := TStringList.Create;
  try
    Check(LAdmin.ConnectionExists('AGENT_EXIST') and LAdmin.ConnectionExists('agent_exist'),
      'existing connections of the sandbox (names without case)');
    Check(not LAdmin.ConnectionExists('NOPE'), 'unknown connection');

    // SQLite: the FireDAC connections of the FPC engine
    LAdmin.CreateConnection('ADM_SQLITE', RP_DBX_DRIVER_SQLITE);
    CheckEquals('Sqlite', IniValue('ADM_SQLITE', 'DriverName'),
      'SQLite connection: DriverName that the FPC FireDAC driver opens');
    Check(IniHasKey('ADM_SQLITE', 'Database'), 'SQLite connection: Database');
    CheckEquals(2, IniKeyCount('ADM_SQLITE'), 'SQLite connection: no dbExpress loader keys');
    LAdmin.GetConnectionParams('ADM_SQLITE', LParams);
    CheckEquals(2, LParams.Count, 'SQLite parameters: DriverName and Database');
    CheckEquals('DriverName', LParams[0].Name, 'DriverName first');
    Check(LParams[0].EditorKind = weCombo, 'DriverName: closed list');
    Check(ParamIndex('Database') = 1, 'Database parameter');
    Check(LParams[1].EditorKind = weText, 'Database: text');

    // Zeos with its protocol
    LAdmin.CreateConnection('ADM_ZEOS', RP_DBX_DRIVER_FAMILY_ZEOS, 'postgresql');
    CheckEquals('ZeosLib', IniValue('ADM_ZEOS', 'DriverName'), 'Zeos connection: ZeosLib');
    CheckEquals('postgresql', IniValue('ADM_ZEOS', 'Database Protocol'),
      'Zeos connection: the protocol where rpdatainfo reads it');
    Check(not IniHasKey('ADM_ZEOS', 'GetDriverFunc') and not IniHasKey('ADM_ZEOS', 'LibraryName'),
      'Zeos connection: no driver library keys (TRpConnAdmin.AddConnection)');
    Check(IniHasKey('ADM_ZEOS', 'HostName'), 'Zeos connection: defaults of [ZeosLib]');
    LAdmin.GetConnectionParams('ADM_ZEOS', LParams);
    Check(ParamIndex('Database Protocol') >= 0, 'Zeos parameters: Database Protocol');
    Check(LParams[ParamIndex('Database Protocol')].EditorKind = weCombo,
      'Database Protocol: closed list');
    Check(LParams[ParamIndex('Database Protocol')].Options.IndexOf('sqlite') >= 0,
      'Database Protocol: the protocols of dbxdrivers');
    CheckEquals('postgresql', LParams[ParamIndex('Database Protocol')].Value,
      'Database Protocol: the stored value');
    Check(LParams[ParamIndex('Password')].EditorKind = wePassword, 'Password: hidden');
    Check(LParams[ParamIndex('Zeos TransIsolation')].EditorKind = weCombo,
      'Zeos TransIsolation: closed list');
    Check(LParams[ParamIndex('HostName')].EditorKind = weText, 'HostName: text');
    Check((ParamIndex('GetDriverFunc') < 0) and (ParamIndex('VendorLib') < 0),
      'no loader parameters');
    // Only the parameters of the driver are saved
    LValues.Values['HostName'] := 'db.example.com';
    LValues.Values['Password'] := 'secret';
    LValues.Values['Unknown'] := '1';
    LAdmin.UpdateConnectionParams('ADM_ZEOS', LValues);
    CheckEquals('db.example.com', IniValue('ADM_ZEOS', 'HostName'), 'saved: HostName');
    CheckEquals('secret', IniValue('ADM_ZEOS', 'Password'), 'saved: Password');
    Check(not IniHasKey('ADM_ZEOS', 'Unknown'), 'not saved: a parameter of no driver');
    RpFreeConnectionParams(LParams);

    // Reportman AI Agent
    LAdmin.CreateConnection('ADM_AGENT', RP_DBX_DRIVER_FAMILY_AGENT);
    CheckEquals(RP_DBX_DRIVER_FAMILY_AGENT, IniValue('ADM_AGENT', 'DriverName'),
      'Agent connection');
    Check(IniHasKey('ADM_AGENT', 'ApiKey') and IniHasKey('ADM_AGENT', 'HubDatabaseId'),
      'Agent connection: ApiKey and HubDatabaseId');
    LValues.Clear;
    LValues.Values['ApiKey'] := KEY_OK;
    LValues.Values['HubDatabaseId'] := '21';
    LAdmin.UpdateConnectionParams('ADM_AGENT', LValues);
    CheckEquals(KEY_OK, IniValue('ADM_AGENT', 'ApiKey'), 'saved: ApiKey');
    CheckEquals('21', IniValue('ADM_AGENT', 'HubDatabaseId'), 'saved: HubDatabaseId');
    LAdmin.GetTestValues('ADM_AGENT', nil, LTest);
    FHubHandler.ClearRequests;
    LResult := RpExecuteConnectionTest('ADM_AGENT', LTest, '');
    Check(LResult.Success, 'Agent test: success');
    CheckContains('database 21', LResult.MessageText, 'Agent test: the message of the Hub');
    CheckEquals('21|' + KEY_OK, FHubHandler.LastTestRequest,
      'Agent test: api/agent/testconnection with the database and the API key');
    LValues.Clear;
    LValues.Values['HubDatabaseId'] := '22';
    LAdmin.GetTestValues('ADM_AGENT', LValues, LTest);
    CheckEquals(KEY_OK, LTest.Values['ApiKey'], 'test values: stored ApiKey');
    CheckEquals('22', LTest.Values['HubDatabaseId'], 'test values: edited value on top');
    LResult := RpExecuteConnectionTest('ADM_AGENT', LTest, '');
    Check(not LResult.Success, 'Agent test: failure');
    CheckContains('Database offline', LResult.MessageText, 'Agent test: the error of the Hub');
    CheckContains('Agent Connection: Fail', LResult.MessageText,
      'Agent test: the message of rpwebdbxadmin');

    // Invalid names and drivers
    LRaised := False;
    try
      LAdmin.CreateConnection('BAD=NAME', RP_DBX_DRIVER_SQLITE);
    except
      LRaised := True;
    end;
    Check(LRaised, 'a name with = is refused');
    LRaised := False;
    try
      LAdmin.CreateConnection('ADM_DBX', 'Interbase');
    except
      LRaised := True;
    end;
    Check(LRaised and not LAdmin.ConnectionExists('ADM_DBX'),
      'a dbExpress driver is not available in the FPC engine');
    Check(RpDbxEngineDriver('Sqlite') = rpfiredac, 'Sqlite: FireDAC driver of the engine');
    Check(RpDbxEngineDriver('FireDac') = rpfiredac, 'FireDac: FireDAC driver');
    Check(RpDbxEngineDriver('ZeosLib') = rpdatazeos, 'ZeosLib: Zeos driver');
    Check(RpDbxEngineDriver('Reportman AI Agent') = rpdbHttp, 'Agent: rpdbHttp');

    // A SQLite test opens (and creates) the database file
    LDbFile := IncludeTrailingPathDelimiter(FSandbox) + 'adm.db';
    LValues.Clear;
    LValues.Values['Database'] := LDbFile;
    LAdmin.GetTestValues('ADM_SQLITE', LValues, LTest);
    LResult := RpExecuteConnectionTest('ADM_SQLITE', LTest, '');
    if FSqliteAvailable then
    begin
      Check(LResult.Success, 'SQLite test: success (' + LResult.MessageText + ')');
      Check(FileExists(LDbFile), 'SQLite test: the database file');
    end
    else
    begin
      Check(not LResult.Success and (LResult.MessageText <> ''), 'SQLite test: the error');
      Skip('SQLite test: no SQLite client library');
    end;
  finally
    RpFreeConnectionParams(LParams);
    LTest.Free;
    LValues.Free;
    LParams.Free;
    LAdmin.Free;
  end;
end;

{ Layout }

procedure TAINewReportTests.TestLayout;
var
  W: TFRpNewReportWizardLCL;
  LRep: TRpReport;

  procedure CheckButtons(const AContext: string);
  begin
    Check(W.BCancel.Left + W.BCancel.Width <= W.BBack.Left, AContext + ': Cancel and Back apart');
    Check(W.BBack.Left + W.BBack.Width <= W.BNext.Left, AContext + ': Back and Next apart');
    Check(W.BNext.Left + W.BNext.Width <= W.PBottom.ClientWidth,
      AContext + ': Next inside the window');
    Check(W.BNext.Width >= W.Canvas.TextWidth(T(1747, 'Finish Connection')),
      AContext + ': Next fits its longest caption');
  end;

  procedure CheckPageFits(const AContext: string);
  var
    I, LBottom: Integer;
  begin
    LBottom := 0;
    for I := 0 to W.PContent.ControlCount - 1 do
      if W.PContent.Controls[I].Visible and
        (W.PContent.Controls[I].Top + W.PContent.Controls[I].Height > LBottom) then
        LBottom := W.PContent.Controls[I].Top + W.PContent.Controls[I].Height;
    Check(LBottom <= W.PContent.ClientHeight, AContext + ': the page fits (' +
      IntToStr(LBottom) + ' <= ' + IntToStr(W.PContent.ClientHeight) + ')');
  end;

begin
  Section('New report wizard: layout on an 800x600 screen');
  W := NewWizard(LRep);
  try
    Check(W.Width <= W.Scale96ToScreen(800), 'wizard width fits 800 pixels');
    Check(W.Height <= W.Scale96ToScreen(560), 'wizard height fits 600 pixels with a task bar');
    CheckButtons('route page');
    CheckPageFits('route page');
    Check(W.LStepHelper.Height > W.LStepTitle.Height, 'helper text wrapped under the title');
    Shot(W, 'newreport_route');
    // Narrower (large fonts, small screen): fixed width buttons, no loop
    W.Width := W.Scale96ToScreen(560);
    Pump(150);
    CheckButtons('narrow window');
    CheckPageFits('narrow window');
    W.RbDirect.Checked := True;
    W.BNextClick(nil);
    CheckPage(W, wpDirectSchemaQuestion, 'narrow window: schema question');
    CheckPageFits('schema question page');
  finally
    FreeWizard(W, LRep);
  end;
end;

{ Routes }

procedure TAINewReportTests.TestRouteNoConnection;
var
  W: TFRpNewReportWizardLCL;
  LRep: TRpReport;
begin
  Section('New report wizard: continue with no connection');
  W := NewWizard(LRep);
  try
    CheckPage(W, wpRoute, 'first page: connection route');
    CheckEquals(T(1710, 'Connection Route'), W.LStepTitle.Caption, 'title of the route page');
    CheckContains(T(1711, 'Choose how this report'), W.LStepHelper.Caption, 'helper of the route page');
    Check(not W.BBack.Enabled, 'Back disabled on the first page');
    Check(W.BNext.Visible and not W.BFinish.Visible, 'Next visible, Finish hidden');
    CheckEquals(T(933, 'Next'), W.BNext.Caption, 'Next caption');
    FAnswerer.Arm(smbOK);
    // GTK always checks one radio button of a group (the first one)
    if not W.RbAgent.Checked and not W.RbDirect.Checked and not W.RbNoConnection.Checked then
    begin
      Pass('no route chosen');
      W.BNextClick(nil);
      CheckContains(T(1753, 'Please choose a connection route.'), FAnswerer.LastText,
        'a route is required');
      CheckPage(W, wpRoute, 'still on the route page');
    end
    else
      Skip('no route chosen: the widgetset checks the first radio button');
    W.RbNoConnection.Checked := True;
    CheckEquals(T(935, 'Finish'), W.BNext.Caption, 'no connection: Next becomes Finish');
    W.RbAgent.Checked := True;
    CheckEquals(T(933, 'Next'), W.BNext.Caption, 'another route: Next again');
    W.RbNoConnection.Checked := True;
    // A connection that the wizard removes
    LRep.DatabaseInfo.Add('OLDCONN');
    W.BNextClick(nil);
    Check(W.Committed, 'finished at once');
    Check(not W.Visible, 'wizard closed');
    CheckEquals('', W.PendingPrompt, 'no prompt');
    CheckEquals(0, LRep.DatabaseInfo.Count, 'the report has no connection');
    CheckEquals(0, W.State.HubSchemaId, 'no schema');
    CheckNewReportSections(LRep, 'report of the wizard');
  finally
    FreeWizard(W, LRep);
  end;

  // Cancel
  W := NewWizard(LRep);
  try
    W.RbNoConnection.Checked := True;
    W.BCancelClick(nil);
    Check(not W.Committed and not W.Visible, 'Cancel closes without a result');
  finally
    FreeWizard(W, LRep);
  end;
end;

procedure TAINewReportTests.TestAgentNewConnection;
var
  W: TFRpNewReportWizardLCL;
  LRep: TRpReport;
  LItem: TRpDatabaseInfoItem;

  function SchemasLoaded: Boolean;
  begin
    Result := (W.AISchemaSelector <> nil) and not W.AISchemaSelector.Loading;
  end;

  function OnSchemaPage: Boolean;
  begin
    Result := (W.CurrentPage = wpAgentSchema) and (W.Operation = woNone);
  end;

begin
  Section('New report wizard: Reportman AI route with a new connection');
  W := NewWizard(LRep);
  try
    FAnswerer.Arm(smbOK);
    W.RbAgent.Checked := True;
    W.BNextClick(nil);
    CheckPage(W, wpConnName, 'Agent route: connection name page');
    Check(W.BBack.Enabled, 'Back enabled');
    Check(W.RbExisting.Checked, 'existing connection by default');
    Check(W.CbExistingConn.Items.IndexOf('AGENT_EXIST') >= 0, 'existing Agent connection listed');
    Check((W.CbExistingConn.Items.IndexOf('SQLITE_EXIST') < 0) and
      (W.CbExistingConn.Items.IndexOf('ZEOS_EXIST') < 0) and
      (W.CbExistingConn.Items.IndexOf('DBX_IB') < 0), 'only Agent connections listed');
    Check(not W.LblExistingConnDriver.Visible, 'no driver hint on the Agent route');
    W.RbNew.Checked := True;
    Check(not W.CbExistingConn.Enabled and W.EdNewConnName.Enabled and
      not W.BtnTestExisting.Enabled, 'new connection: name enabled, list disabled');
    W.EdNewConnName.Text := 'AGENT_EXIST';
    W.BNextClick(nil);
    CheckContains(T(1765, 'This connection name already exists'), FAnswerer.LastText,
      'an existing name is refused');
    W.EdNewConnName.Text := '  ';
    W.BNextClick(nil);
    CheckContains(T(1764, 'Please enter a connection name.'), FAnswerer.LastText,
      'a name is required');
    W.EdNewConnName.Text := 'AGENT_NEW';
    W.BNextClick(nil);
    CheckPage(W, wpAgentLogin, 'new connection: Agent login page');
    CheckEquals(T(1712, 'Reportman AI Connection'), W.LStepTitle.Caption, 'login page title');
    Check(IniKeyCount('AGENT_NEW') = 0, 'the connection is created after the login');
    Shot(W, 'newreport_agent_login');

    W.BNextClick(nil);
    CheckContains(T(1754, 'Please log in to Reportman AI'), FAnswerer.LastText,
      'login required before continuing');
    W.EdHubApiKey.Text := '';
    W.BtnHubLogin.Click;
    CheckContains(T(1777, 'Please enter your Reportman AI API key.'), FAnswerer.LastText,
      'an API key is required');

    // A key that the Hub refuses
    W.EdHubApiKey.Text := KEY_BAD;
    W.BtnHubLogin.Click;
    Check(W.Operation = woHubLogin, 'the Hub request runs in a worker thread');
    Check(not W.BNext.Enabled and not W.BBack.Enabled and not W.BtnHubLogin.Enabled,
      'navigation and login wait for the request');
    CheckEquals(T(1782, 'Contacting Reportman AI...'), W.LStatus.Caption, 'status of the request');
    WaitIdle(W, 'Hub request with a refused key answered');
    CheckContains(T(1779, 'Could not contact Reportman AI Web'), FAnswerer.LastText,
      'refused key: the error');
    Check(not W.State.HubLoggedIn, 'refused key: not logged in');
    CheckEquals('', W.LStatus.Caption, 'status cleared');
    Check(W.BNext.Enabled and W.BBack.Enabled, 'navigation enabled again');

    // The good key: the Hub databases
    W.EdHubApiKey.Text := KEY_OK;
    W.BtnHubLogin.Click;
    WaitIdle(W, 'Hub databases of the API key');
    CheckContains(Format(T(1780, 'Logged in. Loaded %d connections.'), [2]),
      FAnswerer.LastText, 'logged in with the number of connections');
    Check(W.State.HubLoggedIn, 'logged in');
    CheckEquals(KEY_OK, W.State.HubApiKey, 'API key kept');
    CheckEquals(2, W.CbHubDatabase.Items.Count, 'two Hub databases');
    CheckEquals('Sales DB', W.CbHubDatabase.Items[0], 'database names in the list');
    CheckEquals('HR DB', W.CbHubDatabase.Items[1], 'second database');
    CheckEquals(0, W.CbHubDatabase.ItemIndex, 'first database selected');

    // A database whose test fails: the page stays
    FHubHandler.ClearRequests;
    W.CbHubDatabase.ItemIndex := 1;
    W.BNextClick(nil);
    Check(W.Operation = woAgentConnection, 'the connection test runs in a worker thread');
    CheckEquals(T(1781, 'Testing connection...'), W.LStatus.Caption, 'status of the test');
    WaitIdle(W, 'test of the new connection answered');
    CheckContains(T(1757, 'Could not validate the new Reportman AI connection: '),
      FAnswerer.LastText, 'failed test: the error');
    CheckContains('Database offline', FAnswerer.LastText, 'failed test: the message of the Hub');
    CheckPage(W, wpAgentLogin, 'failed test: still on the login page');
    CheckEquals('22|' + KEY_OK, FHubHandler.LastTestRequest, 'test of database 22 with the key');
    CheckEquals(RP_DBX_DRIVER_FAMILY_AGENT, IniValue('AGENT_NEW', 'DriverName'),
      'Agent connection created');
    CheckEquals(KEY_OK, IniValue('AGENT_NEW', 'ApiKey'), 'connection: API key');
    CheckEquals('22', IniValue('AGENT_NEW', 'HubDatabaseId'), 'connection: Hub database');

    // Back to the name: the connection created by this wizard keeps its name
    // (the VCL refuses it), and the login page loads the databases again
    W.BBackClick(nil);
    CheckPage(W, wpConnName, 'Back: connection name page');
    Check(W.RbNew.Checked and (W.EdNewConnName.Text = 'AGENT_NEW'), 'the new connection kept');
    W.BNextClick(nil);
    CheckPage(W, wpAgentLogin, 'the name of the connection of this wizard is accepted');
    CheckEquals(KEY_OK, W.EdHubApiKey.Text, 'the API key kept');
    WaitIdle(W, 'Hub databases loaded again');
    CheckContains(Format(T(1780, 'Logged in. Loaded %d connections.'), [2]),
      FAnswerer.LastText, 'databases loaded again (as the VCL)');
    CheckEquals(2, W.CbHubDatabase.Items.Count, 'the databases again');

    // The good database
    W.CbHubDatabase.ItemIndex := 0;
    W.BNextClick(nil);
    WaitUntil(OnSchemaPage, 20000, 'good test: schema page');
    CheckEquals('21|' + KEY_OK, FHubHandler.LastTestRequest, 'test of database 21');
    CheckEquals('21', IniValue('AGENT_NEW', 'HubDatabaseId'), 'connection: database 21');
    CheckEquals('Sales DB', W.State.HubDatabaseName, 'state: database name');
    CheckEquals(21, W.State.HubDatabaseId, 'state: database id');
    CheckEquals(T(1528, 'Schema'), W.LStepTitle.Caption, 'schema page title');
    CheckContains('AGENT_NEW', W.PContent.Controls[0].Caption,
      'schema page: the selected connection');
    WaitUntil(SchemasLoaded, 20000, 'schemas of the API key and of the account loaded');
    CheckEquals(4, W.AISchemaSelector.ComboSchema.Items.Count,
      'schemas: none, 2 of the API key, 1 of the account');
    CheckEquals('Sales DB', W.AISchemaSelector.ComboSchema.Items[1],
      'the schema of the chosen database first');
    CheckEquals(31, W.AISchemaSelector.GetHubSchemaId, 'schema of database 21 selected');
    Shot(W, 'newreport_agent_schema');
    W.BNextClick(nil);
    CheckPage(W, wpFinish, 'schema chosen: finish page');
    CheckEquals(31, W.State.HubSchemaId, 'state: schema');
    CheckEquals(KEY_OK, W.State.HubApiKey, 'state: API key of the schema');
    CheckEquals('21', IniValue('AGENT_NEW', 'HubDatabaseId'), 'connection saved with the schema database');
    Check(W.BFinish.Visible and not W.BNext.Visible and W.BFinish.Default,
      'Finish button on the last page');
    CheckContains(T(1722, 'Sales by customer'), W.PContent.Controls[0].Caption,
      'the example prompt');

    // Back and forth keeps the choice
    W.BBackClick(nil);
    CheckPage(W, wpAgentSchema, 'Back: schema page');
    WaitUntil(SchemasLoaded, 20000, 'schemas loaded again');
    CheckEquals(31, W.AISchemaSelector.GetHubSchemaId, 'Back: the chosen schema');
    W.BNextClick(nil);
    CheckPage(W, wpFinish, 'Next: finish page');

    W.MemoFinishPrompt.Text := PROMPT_AGENT;
    Shot(W, 'newreport_finish');
    W.BFinishClick(nil);
    Check(W.Committed, 'wizard finished');
    CheckEquals(PROMPT_AGENT, W.PendingPrompt, 'prompt for the design chat');
    CheckEquals(21, W.State.HubDatabaseId, 'result: Hub database');
    CheckEquals(31, W.State.HubSchemaId, 'result: Hub schema');
    CheckEquals(KEY_OK, W.State.HubApiKey, 'result: API key');
    CheckEquals(1, LRep.DatabaseInfo.Count, 'the report has the connection');
    LItem := LRep.DatabaseInfo.Items[0];
    CheckEquals('AGENT_NEW', LItem.Alias, 'connection alias');
    Check(LItem.Driver = rpdbHttp, 'Reportman AI Agent driver (rpdbHttp)');
  finally
    FreeWizard(W, LRep);
  end;
end;

procedure TAINewReportTests.TestAgentExistingConnection;
var
  W: TFRpNewReportWizardLCL;
  LRep: TRpReport;

  function SchemasLoaded: Boolean;
  begin
    Result := (W.AISchemaSelector <> nil) and not W.AISchemaSelector.Loading;
  end;

begin
  Section('New report wizard: Reportman AI route with an existing connection');
  W := NewWizard(LRep);
  try
    FAnswerer.Arm(smbOK);
    W.RbAgent.Checked := True;
    W.BNextClick(nil);
    W.CbExistingConn.ItemIndex := W.CbExistingConn.Items.IndexOf('AGENT_EXIST');
    FHubHandler.ClearRequests;
    W.BtnTestExisting.Click;
    Check(W.Operation = woTestExisting, 'Test Connection runs in a worker thread');
    WaitIdle(W, 'test of the existing connection answered');
    CheckContains(T(1772, 'Connection succeeded.'), FAnswerer.LastText, 'test succeeded');
    CheckEquals('11|' + KEY_EXIST, FHubHandler.LastTestRequest,
      'test with the database and key of the connection');
    CheckEquals(T(1747, 'Finish Connection'), W.BNext.Caption, 'Next caption after a good test');
    W.BNextClick(nil);
    CheckPage(W, wpAgentSchema, 'existing connection: schema page (no login)');
    CheckEquals(11, W.State.HubDatabaseId, 'state: database of the connection');
    CheckEquals(KEY_EXIST, W.State.HubApiKey, 'state: API key of the connection');
    WaitUntil(SchemasLoaded, 20000, 'schemas loaded');
    CheckEquals('Existing DB', W.AISchemaSelector.ComboSchema.Items[1],
      'the schema of the connection database first');
    CheckEquals(41, W.AISchemaSelector.GetHubSchemaId, 'its schema selected');
    W.BNextClick(nil);
    CheckPage(W, wpFinish, 'finish page');
    W.BFinishClick(nil);
    Check(W.Committed, 'finished without a prompt');
    CheckEquals('', W.PendingPrompt, 'no prompt');
    CheckEquals(41, W.State.HubSchemaId, 'result: schema');
    CheckEquals(11, W.State.HubDatabaseId, 'result: database');
    CheckEquals(KEY_EXIST, W.State.HubApiKey, 'result: API key');
    CheckEquals('AGENT_EXIST', LRep.DatabaseInfo.Items[0].Alias, 'report connection');
    Check(LRep.DatabaseInfo.Items[0].Driver = rpdbHttp, 'rpdbHttp driver');
    CheckEquals(KEY_EXIST, IniValue('AGENT_EXIST', 'ApiKey'), 'existing connection not changed');
  finally
    FreeWizard(W, LRep);
  end;
end;

procedure TAINewReportTests.TestDirectSqlite;
var
  W: TFRpNewReportWizardLCL;
  LRep: TRpReport;
  LDbFile: string;
  LEditor: TWinControl;

  function SchemasLoaded: Boolean;
  begin
    Result := (W.AISchemaSelector <> nil) and not W.AISchemaSelector.Loading;
  end;

begin
  Section('New report wizard: direct SQLite connection with a schema');
  LDbFile := IncludeTrailingPathDelimiter(FSandbox) + 'wizard.db';
  W := NewWizard(LRep);
  try
    FAnswerer.Arm(smbOK);
    W.RbDirect.Checked := True;
    W.BNextClick(nil);
    CheckPage(W, wpDirectSchemaQuestion, 'direct route: schema question');
    if not W.RbHasSchema.Checked and not W.RbNoSchema.Checked then
    begin
      W.BNextClick(nil);
      CheckContains(T(1760, 'Please choose Yes or No.'), FAnswerer.LastText,
        'an answer is required');
    end
    else
      Skip('schema question: the widgetset checks the first radio button');
    W.RbHasSchema.Checked := True;
    W.BNextClick(nil);
    CheckPage(W, wpDirectSchema, 'has schema: schema page');
    WaitUntil(SchemasLoaded, 20000, 'schemas of the account loaded');
    CheckEquals(2, W.AISchemaSelector.ComboSchema.Items.Count, 'the schema of the account');
    CheckEquals(61, W.AISchemaSelector.GetHubSchemaId, 'first schema selected');
    W.BNextClick(nil);
    CheckPage(W, wpDriver, 'driver page');
    CheckEquals(51, W.State.HubDatabaseId, 'state: database of the schema');
    CheckEquals(61, W.State.HubSchemaId, 'state: schema');
    CheckEquals(2, W.CbFamily.Items.Count, 'families of the FPC engine: FireDAC (SQLite) and Zeos');
    CheckEquals(0, W.CbFamily.ItemIndex, 'FireDAC by default');
    CheckEquals(T(1742, 'FireDAC DriverID'), W.LblConcrete.Caption, 'FireDAC driver label');
    CheckEquals('SQLite', W.CbConcrete.Text, 'the only FireDAC driver chosen');
    Shot(W, 'newreport_driver');
    // Zeos, then back to FireDAC
    W.CbFamily.ItemIndex := 1;
    W.CbFamily.OnChange(W.CbFamily);
    CheckEquals(T(1743, 'Zeos protocol'), W.LblConcrete.Caption, 'Zeos protocol label');
    Check((W.CbConcrete.Items.IndexOf('sqlite') >= 0) and
      (W.CbConcrete.Items.IndexOf('firebird') >= 0) and
      (W.CbConcrete.Items.IndexOf('postgresql') >= 0), 'Zeos protocols');
    CheckEquals('', W.CbConcrete.Text, 'protocol to choose');
    W.BNextClick(nil);
    CheckContains(T(1762, 'Please choose a specific driver.'), FAnswerer.LastText,
      'a driver is required');
    W.CbFamily.ItemIndex := 0;
    W.CbFamily.OnChange(W.CbFamily);
    CheckEquals('SQLite', W.CbConcrete.Text, 'FireDAC: SQLite again');
    W.BNextClick(nil);
    CheckPage(W, wpConnName, 'connection name page');
    CheckEquals(T(400, 'Connection Name'), W.LStepTitle.Caption, 'connection name title');
    Check((W.CbExistingConn.Items.IndexOf('SQLITE_EXIST') >= 0) and
      (W.CbExistingConn.Items.IndexOf('ADM_SQLITE') >= 0), 'SQLite connections listed');
    Check((W.CbExistingConn.Items.IndexOf('FIREDAC_FB') < 0) and
      (W.CbExistingConn.Items.IndexOf('ZEOS_EXIST') < 0) and
      (W.CbExistingConn.Items.IndexOf('AGENT_EXIST') < 0) and
      (W.CbExistingConn.Items.IndexOf('DBX_IB') < 0),
      'no Firebird FireDAC, Zeos, Agent or dbExpress connections');
    W.CbExistingConn.ItemIndex := W.CbExistingConn.Items.IndexOf('SQLITE_EXIST');
    W.CbExistingConn.OnChange(W.CbExistingConn);
    Check(W.LblExistingConnDriver.Visible, 'driver hint of the existing connection');
    CheckEquals('FireDAC - SQLite', W.LblExistingConnDriver.Caption, 'driver hint');
    Shot(W, 'newreport_connection');
    W.RbNew.Checked := True;
    Check(not W.LblExistingConnDriver.Visible, 'new connection: no hint');
    W.EdNewConnName.Text := 'SQLITE_EXIST';
    W.BNextClick(nil);
    CheckContains(T(1765, 'This connection name already exists'), FAnswerer.LastText,
      'an existing name is refused');
    W.EdNewConnName.Text := 'SQLITE_NEW';
    W.BNextClick(nil);
    CheckPage(W, wpParams, 'new connection: parameters page');
    CheckEquals('Sqlite', IniValue('SQLITE_NEW', 'DriverName'), 'SQLite connection created');
    CheckContains('SQLITE_NEW', W.LblParamsCaption.Caption, 'parameters of the new connection');
    LEditor := W.ParamEditor('DriverName');
    Check((LEditor is TEdit) and TEdit(LEditor).ReadOnly, 'DriverName read only');
    CheckEquals('Sqlite', TEdit(LEditor).Text, 'DriverName value');
    LEditor := W.ParamEditor('Database');
    Check((LEditor is TEdit) and not TEdit(LEditor).ReadOnly, 'Database editable');
    Check(LEditor.Left + LEditor.Width <= W.ParamsScroll.ClientWidth,
      'Database editor inside the page');
    TEdit(LEditor).Text := LDbFile;
    Shot(W, 'newreport_params');
    W.BtnParamsTest.Click;
    Check(W.Operation = woTestParams, 'parameters test in a worker thread');
    WaitIdle(W, 'parameters test answered');
    if FSqliteAvailable then
    begin
      CheckContains(T(1772, 'Connection succeeded.'), FAnswerer.LastText,
        'the edited database opens');
      Check(FileExists(LDbFile), 'the test used the edited (not saved) database');
    end
    else
    begin
      CheckContains(T(1774, 'Connection failed: '), FAnswerer.LastText, 'test failed');
      Skip('SQLite parameters test: no SQLite client library');
    end;
    CheckEquals('', IniValue('SQLITE_NEW', 'Database'), 'the test does not save');
    W.BNextClick(nil);
    CheckPage(W, wpFinish, 'parameters saved: finish page');
    CheckEquals(LDbFile, IniValue('SQLITE_NEW', 'Database'), 'Database saved');

    // Back to the connection name: the connection of this wizard is kept
    W.BBackClick(nil);
    CheckPage(W, wpParams, 'Back: parameters page');
    CheckEquals(LDbFile, TEdit(W.ParamEditor('Database')).Text, 'the saved database');
    W.BBackClick(nil);
    CheckPage(W, wpConnName, 'Back: connection name page');
    Check(W.RbNew.Checked, 'new connection still chosen');
    CheckEquals('SQLITE_NEW', W.EdNewConnName.Text, 'its name');
    W.BNextClick(nil);
    CheckPage(W, wpParams, 'the connection created by this wizard is accepted');
    CheckEquals(LDbFile, TEdit(W.ParamEditor('Database')).Text, 'and not created again');
    W.BNextClick(nil);
    CheckPage(W, wpFinish, 'finish page');

    W.MemoFinishPrompt.Text := 'List the customers';
    W.BFinishClick(nil);
    Check(W.Committed, 'finished');
    CheckEquals('List the customers', W.PendingPrompt, 'prompt with the Hub schema');
    CheckEquals(61, W.State.HubSchemaId, 'result: schema of the direct connection');
    CheckEquals(51, W.State.HubDatabaseId, 'result: Hub database of the schema');
    CheckEquals(1, LRep.DatabaseInfo.Count, 'one connection');
    CheckEquals('SQLITE_NEW', LRep.DatabaseInfo.Items[0].Alias, 'connection alias');
    Check(LRep.DatabaseInfo.Items[0].Driver = rpfiredac, 'FireDAC driver (SQLite in FPC)');
  finally
    FreeWizard(W, LRep);
  end;
end;

procedure TAINewReportTests.TestDirectZeos;
var
  W: TFRpNewReportWizardLCL;
  LRep: TRpReport;
  LEditor: TWinControl;
begin
  Section('New report wizard: direct Zeos connection without schema');
  W := NewWizard(LRep);
  try
    FAnswerer.Arm(smbOK);
    W.RbDirect.Checked := True;
    W.BNextClick(nil);
    W.RbNoSchema.Checked := True;
    W.BNextClick(nil);
    CheckPage(W, wpDriver, 'no schema: driver page');
    W.CbFamily.ItemIndex := 1;
    W.CbFamily.OnChange(W.CbFamily);
    W.CbConcrete.Text := 'sqlite';
    W.BNextClick(nil);
    CheckPage(W, wpConnName, 'connection name page');
    Check((W.CbExistingConn.Items.IndexOf('ZEOS_EXIST') >= 0) and
      (W.CbExistingConn.Items.IndexOf('ADM_ZEOS') >= 0), 'Zeos connections listed');
    Check(W.CbExistingConn.Items.IndexOf('SQLITE_EXIST') < 0, 'no SQLite connections');
    W.CbExistingConn.ItemIndex := W.CbExistingConn.Items.IndexOf('ZEOS_EXIST');
    W.CbExistingConn.OnChange(W.CbExistingConn);
    CheckEquals('Zeos - sqlite', W.LblExistingConnDriver.Caption, 'Zeos driver hint');
    W.BtnTestExisting.Click;
    WaitIdle(W, 'test of the Zeos connection answered');
    if Pos(T(1772, 'Connection succeeded.'), FAnswerer.LastText) > 0 then
    begin
      Pass('Zeos sqlite connection opened');
      CheckEquals(T(1747, 'Finish Connection'), W.BNext.Caption, 'caption after a good test');
    end
    else
    begin
      CheckContains(T(1774, 'Connection failed: '), FAnswerer.LastText, 'Zeos test: the error');
      CheckEquals(T(1748, 'Edit Connection'), W.BNext.Caption, 'caption after a failed test');
      Skip('Zeos sqlite test: ' + FAnswerer.LastText);
    end;
    W.RbNew.Checked := True;
    W.EdNewConnName.Text := 'ZEOS_NEW';
    W.BNextClick(nil);
    CheckPage(W, wpParams, 'parameters of the new Zeos connection');
    CheckEquals('ZeosLib', IniValue('ZEOS_NEW', 'DriverName'), 'ZeosLib connection');
    CheckEquals('sqlite', IniValue('ZEOS_NEW', 'Database Protocol'),
      'the protocol chosen in the wizard');
    LEditor := W.ParamEditor('Database Protocol');
    Check((LEditor is TComboBox) and (TComboBox(LEditor).Style = csDropDownList),
      'protocol: closed list');
    CheckEquals('sqlite', TComboBox(LEditor).Text, 'protocol value');
    LEditor := W.ParamEditor('Password');
    Check((LEditor is TEdit) and (TEdit(LEditor).PasswordChar = '*'), 'password hidden');
    // Another protocol for the connection of this wizard: created again
    W.BBackClick(nil);
    W.BBackClick(nil);
    CheckPage(W, wpDriver, 'Back to the driver page');
    CheckEquals('sqlite', W.CbConcrete.Text, 'the chosen protocol kept');
    W.CbConcrete.Text := 'firebird';
    W.BNextClick(nil);
    W.BNextClick(nil);
    CheckPage(W, wpParams, 'the same name with another protocol');
    CheckEquals('firebird', IniValue('ZEOS_NEW', 'Database Protocol'),
      'connection created again with the new protocol');
    W.BBackClick(nil);
    W.BBackClick(nil);
    W.CbConcrete.Text := 'sqlite';
    W.BNextClick(nil);
    W.BNextClick(nil);
    CheckPage(W, wpParams, 'back to sqlite');
    CheckEquals('sqlite', IniValue('ZEOS_NEW', 'Database Protocol'), 'sqlite protocol again');
    TEdit(W.ParamEditor('Database')).Text := IncludeTrailingPathDelimiter(FSandbox) + 'zeoswiz.db';
    TEdit(W.ParamEditor('HostName')).Text := '';
    W.BNextClick(nil);
    CheckPage(W, wpFinish, 'finish page');
    CheckEquals(IncludeTrailingPathDelimiter(FSandbox) + 'zeoswiz.db',
      IniValue('ZEOS_NEW', 'Database'), 'Database saved');

    // A prompt without a Hub schema
    W.MemoFinishPrompt.Text := 'Orders by month';
    FAnswerer.Arm(smbNo);
    W.BFinishClick(nil);
    CheckContains(T(1751, 'You provided a prompt for AI but no Reportman AI schema'),
      FAnswerer.LastText, 'a prompt without schema asks to continue without AI');
    Check(not W.Committed, 'answer No: the wizard stays');
    CheckPage(W, wpFinish, 'still on the finish page');
    FAnswerer.Arm(smbYes);
    W.BFinishClick(nil);
    Check(W.Committed, 'answer Yes: finished without AI');
    CheckEquals('', W.PendingPrompt, 'the prompt is dropped');
    CheckEquals('ZEOS_NEW', LRep.DatabaseInfo.Items[0].Alias, 'connection alias');
    Check(LRep.DatabaseInfo.Items[0].Driver = rpdatazeos, 'Zeos driver');
  finally
    FAnswerer.Arm(smbOK);
    FreeWizard(W, LRep);
  end;
end;

{ File > New of the designer }

procedure TAINewReportTests.StartDriver(AScript: TDriverScript);
begin
  FDriverScript := AScript;
  FDriverStep := 0;
  FDriverError := '';
  FDriverWizardSeen := False;
  FDriverStart := GetTickCount64;
  FDriverTimer.Enabled := True;
end;

procedure TAINewReportTests.CheckDriverDone(const AContext: string);
begin
  FDriverTimer.Enabled := False;
  if FDriverError <> '' then
    Fail(AContext + ': ' + FDriverError);
  Check(FDriverScript = dsNone, AContext + ': wizard driven to the end');
end;

procedure TAINewReportTests.DriveAgentPrompt(AWizard: TFRpNewReportWizardLCL);
begin
  case FDriverStep of
    0:
      begin
        AWizard.RbAgent.Checked := True;
        AWizard.BNextClick(nil);
        if AWizard.CurrentPage <> wpConnName then
          FDriverError := 'the Agent route did not go to the connection name page';
        FDriverStep := 1;
      end;
    1:
      begin
        AWizard.RbExisting.Checked := True;
        AWizard.CbExistingConn.ItemIndex := AWizard.CbExistingConn.Items.IndexOf('AGENT_EXIST');
        AWizard.BNextClick(nil);
        if AWizard.CurrentPage <> wpAgentSchema then
          FDriverError := 'the existing connection did not go to the schema page';
        FDriverStep := 2;
      end;
    2:
      // The schemas load in the background
      if (AWizard.AISchemaSelector <> nil) and not AWizard.AISchemaSelector.Loading then
      begin
        AWizard.BNextClick(nil);
        if AWizard.CurrentPage <> wpFinish then
          FDriverError := 'the schema did not go to the finish page';
        FDriverStep := 3;
      end;
    3:
      begin
        AWizard.MemoFinishPrompt.Text := PROMPT_DESIGNER;
        AWizard.BFinishClick(nil);
        FDriverScript := dsNone;
      end;
  end;
end;

procedure TAINewReportTests.DriverTick(Sender: TObject);
var
  I: Integer;
  LWizard: TFRpNewReportWizardLCL;
begin
  if FDriverScript = dsNone then
    Exit;
  LWizard := nil;
  for I := 0 to Screen.CustomFormCount - 1 do
  begin
    // A message box is answered by the dialog answerer
    if (Screen.CustomForms[I] is TFRpMessageDlgVCL) and Screen.CustomForms[I].Visible then
      Exit;
    if (Screen.CustomForms[I] is TFRpNewReportWizardLCL) and Screen.CustomForms[I].Visible and
      (fsModal in Screen.CustomForms[I].FormState) then
      LWizard := TFRpNewReportWizardLCL(Screen.CustomForms[I]);
  end;
  if LWizard = nil then
    Exit;
  FDriverWizardSeen := True;
  if LWizard.Operation <> woNone then
    Exit;
  FDriverTimer.Enabled := False;
  try
    if GetTickCount64 - FDriverStart > 40000 then
    begin
      FDriverError := 'timeout driving the wizard (step ' + IntToStr(FDriverStep) + ')';
      FDriverScript := dsCancel;
    end;
    if FDriverError <> '' then
      FDriverScript := dsCancel;
    case FDriverScript of
      dsCancel:
        begin
          LWizard.BCancelClick(nil);
          FDriverScript := dsNone;
        end;
      dsAgentPrompt:
        DriveAgentPrompt(LWizard);
    end;
  finally
    FDriverTimer.Enabled := FDriverScript <> dsNone;
  end;
end;

procedure TAINewReportTests.TestDesignerFileNew;
var
  LMain: TFRpMainFLCL;
  LOld: TRpReport;
  LBody: string;
  LIni: TIniFile;

  function Modified: Boolean;
  begin
    Result := FHubHandler.ModifyCount > 0;
  end;

  function Applied: Boolean;
  begin
    Result := LMain.DesignApplyCount > 0;
  end;

  function Idle: Boolean;
  begin
    Result := not LMain.ChatFrame.Busy and not LMain.DesignContextRefreshRunning;
  end;

begin
  Section('File > New of the designer: the new report wizard');
  LMain := TFRpMainFLCL.Create(nil);
  try
    LMain.SetBounds(20, 20, 1260, 720);
    LMain.Show;
    Pump(200);
    LOld := LMain.Report;
    CheckEquals(0, LOld.SubReports[0].SubReport.GroupCount,
      'the designer starts with a blank report (no wizard)');

    // Cancel keeps the current report
    StartDriver(dsCancel);
    Check(not LMain.NewReportFromWizard, 'canceled wizard: no new report');
    CheckDriverDone('cancel');
    Check(FDriverWizardSeen, 'the wizard was shown');
    Check(LMain.Report = LOld, 'canceled wizard: the current report stays');

    // Without the wizard: the classic blank report
    RpDesignerLCLNewReportWizard := False;
    try
      StartDriver(dsCancel);
      LMain.BtnNew.Click;
      FDriverTimer.Enabled := False;
      FDriverScript := dsNone;
      Check(not FDriverWizardSeen, 'RpDesignerLCLNewReportWizard=False: no wizard');
      Check(LMain.Report <> LOld, 'a new blank report');
      CheckEquals(0, LMain.Report.SubReports[0].SubReport.GroupCount, 'blank report');
    finally
      RpDesignerLCLNewReportWizard := True;
    end;

    // The wizard with an Agent connection, its schema and a prompt; the AI
    // panel hidden
    LMain.ShowAIChat := False;
    Check(not LMain.AIChatPanel.Visible, 'AI panel hidden');
    FHubHandler.ClearRequests;
    LOld := LMain.Report;
    StartDriver(dsAgentPrompt);
    LMain.BtnNew.Click;
    CheckDriverDone('File > New');
    Check(LMain.Report <> LOld, 'the report of the wizard installed');
    CheckNewReportSections(LMain.Report, 'File > New');
    CheckEquals(1, LMain.Report.DatabaseInfo.Count, 'the connection of the wizard');
    CheckEquals('AGENT_EXIST', LMain.Report.DatabaseInfo.Items[0].Alias, 'Agent connection');
    Check(LMain.Report.DatabaseInfo.Items[0].Driver = rpdbHttp, 'rpdbHttp driver');
    CheckEquals('', LMain.FileName, 'new report without a file');
    CheckContains(T(501, 'Untitled'), LMain.Caption, 'untitled');
    // The design chat: Hub context of the wizard, the prompt sent
    CheckEquals(11, LMain.ChatFrame.GetHubDatabaseId, 'chat: Hub database of the wizard');
    CheckEquals(41, LMain.ChatFrame.GetHubSchemaId, 'chat: schema of the wizard');
    CheckEquals(KEY_EXIST, LMain.ChatFrame.GetSchemaApiKey, 'chat: API key of the wizard');
    Check(LMain.AIChatPanel.Visible, 'a prompt shows the AI panel');
    LIni := TIniFile.Create(RpDesignerLCLConfigFile);
    try
      Check(not LIni.ReadBool('Preferences', 'ShowAIChat', True),
        'the saved View > AI chat preference does not change');
    finally
      LIni.Free;
    end;
    CheckContains(PROMPT_DESIGNER, LMain.ChatFrame.ConversationText, 'the prompt in the chat');
    WaitUntil(Modified, 20000, 'design request sent to the Hub');
    LBody := FHubHandler.ModifyBody(0);
    CheckEquals(PROMPT_DESIGNER, JsonPath(LBody, 'userInstructions.0'), 'request: the prompt');
    CheckEquals('41', JsonPath(LBody, 'config.hubSchemaId'), 'request: the schema');
    CheckEquals('11', JsonPath(LBody, 'config.hubDatabaseId'), 'request: the database');
    CheckEquals(KEY_EXIST, JsonPath(LBody, 'apiKey'), 'request: the API key');
    CheckContains('AGENT_EXIST', JsonPath(LBody, 'reportDocument'),
      'request: the report of the wizard');
    WaitUntil(Applied, 20000, 'design result applied');
    WaitUntil(Idle, 20000, 'chat idle');
    CheckEquals(1, FHubHandler.ModifyCount, 'one design request');
    Shot(LMain, 'newreport_designer');
    LMain.ShowAIChat := True;
  finally
    FDriverTimer.Enabled := False;
    FDriverScript := dsNone;
    FreeAndNil(LMain);
    Check(RpAsyncWaitIdle(15000), 'workers of the designer finished');
  end;
end;

procedure TAINewReportTests.Run;
begin
  FSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rpaichattest', FSandbox) = 0 then
    Fail('the tests must run in the sandbox (LOCALAPPDATA=' + FSandbox + ')');
  FConnFile := IncludeTrailingPathDelimiter(FSandbox) + 'dbxconnections_newreport.ini';
  WriteConnectionsFile;
  // The designer preferences of the sandbox (also when this series runs alone)
  if RpDesignerLCLConfigFile = '' then
    RpDesignerLCLConfigFile := IncludeTrailingPathDelimiter(FSandbox) + 'repmand_newreport.ini';
  DBXConnectionsFileOverride := FConnFile;
  RpWebMarkdownForceNative := True;
  FSqliteAvailable := CheckSqliteAvailable;

  FHubHandler := TNewReportFakeHub.Create;
  FHub := TFakeServer.Create(FHubHandler.Handle);
  FAnswerer := TDialogAnswerer.Create;
  FDriverTimer := TTimer.Create(nil);
  FDriverTimer.Enabled := False;
  FDriverTimer.Interval := 40;
  FDriverTimer.OnTimer := DriverTick;
  try
    FHub.Start;
    Log('  fake Hub (new report) on ' + FHub.BaseURL);
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
    try
      Check(TRpAuthManager.Instance.LoginWithCode('ana@example.com', '123456'),
        'login with the email code (fake Hub)');
      Pump(50);
      TestAdmin;
      TestLayout;
      TestRouteNoConnection;
      TestAgentNewConnection;
      TestAgentExistingConnection;
      TestDirectSqlite;
      TestDirectZeos;
      TestDesignerFileNew;
      TRpAuthManager.Instance.Logout;
      Check(RpAsyncWaitIdle(10000), 'all workers finished');
    finally
      RpHttpSetUrlRewrite('', '');
      DBXConnectionsFileOverride := '';
    end;
  finally
    FDriverTimer.Free;
    FAnswerer.Free;
    FHub.Free;
    FHubHandler.Free;
  end;
  Pump(100);
end;

procedure RunAINewReportTests(const AShotsDir: string);
var
  LTests: TAINewReportTests;
begin
  LTests := TAINewReportTests.Create(AShotsDir);
  try
    LTests.Run;
  finally
    LTests.Free;
  end;
end;

end.

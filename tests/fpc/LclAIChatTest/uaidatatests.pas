{ Phase 8 tests of the data access configuration against a local fake Hub
  (no external network).

  Covers the connections file dialog (rpdbxconfiglcl, port of
  TFRpDBXConfigVCL) on a temporary connections file: entries listed by
  driver, added with the parameters of their driver, parameters written as
  they are edited (edits, combos, read only DriverName, password), dropped;
  the Hub databases of an API key (Select Connection...: no API key, the menu
  and the database chosen from it, no databases, a Hub error, a request
  superseded by another entry, the dialog destroyed while it runs); the
  Connect test of the Reportman AI Agent entries (the message of the Hub, the
  default one, a failure) and of the other drivers in a worker thread; and
  the Connect test of the data configuration dialog with the Agent driver;
  the explanation of the Reportman Agent and its download link. }
unit uaidatatests;

{$mode delphi}{$H+}
{$modeswitch nestedprocvars}

interface

// AShotsDir: screenshots are saved there when not empty
procedure RunAIDataTests(const AShotsDir: string);

implementation

uses
  SysUtils, Classes, Forms, Controls, Graphics, StdCtrls, Menus, IniFiles,
  fphttpserver, httpdefs,
  rpjsonfpc, rphttpclientfpc, rptypes, rpdatainfo, rpreport, rpmdconsts,
  rpaithreadslcl, rpdbxconfiglcl, rpmdfdinfolcl, rpauthmanager, rpmdfnewreportwizardlcl,
  utestutil, ufakeserver;

const
  AGENT_OK_MESSAGE = 'Agent Connection: Success' + #10 + 'Database Connection: Success (fake)';

type
  TCondition = function: Boolean is nested;

  { TDataFakeHub: the Hub endpoints of the Agent connections }

  TDataFakeHub = class
  private
    FLock: TRTLCriticalSection;
    FDatabasesCalls: Integer;
    FTestCalls: Integer;
    FLastTestBody: string;
    FLastTestApiKey: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
    function DatabasesCalls: Integer;
    function TestCalls: Integer;
    function LastTestBody: string;
    function LastTestApiKey: string;
  end;

  { TAIDataTests }

  TAIDataTests = class
  private
    FShotsDir: string;
    FHub: TFakeServer;
    FHubHandler: TDataFakeHub;
    FDir: string;
    FIniFile: string;
    procedure Pump(AMs: Cardinal);
    procedure WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal; const AWhat: string);
    function IniValue(const ASection, AName: string): string;
    function IniHasSection(const ASection: string): Boolean;
    procedure Shot(AForm: TForm; const AName: string);
    procedure TestEntries;
    procedure TestHubDiscovery;
    procedure TestConnectionTest;
    procedure TestDataDialogAgent;
    procedure TestDataDialogLayout;
    procedure TestAgentInfo;
    procedure TestDataDialogWizard;
  public
    constructor Create(const AShotsDir: string);
    procedure Run;
  end;

{ TDataFakeHub }

constructor TDataFakeHub.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
end;

destructor TDataFakeHub.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TDataFakeHub.DatabasesCalls: Integer;
begin
  EnterCriticalSection(FLock);
  Result := FDatabasesCalls;
  LeaveCriticalSection(FLock);
end;

function TDataFakeHub.TestCalls: Integer;
begin
  EnterCriticalSection(FLock);
  Result := FTestCalls;
  LeaveCriticalSection(FLock);
end;

function TDataFakeHub.LastTestBody: string;
begin
  EnterCriticalSection(FLock);
  Result := FLastTestBody;
  LeaveCriticalSection(FLock);
end;

function TDataFakeHub.LastTestApiKey: string;
begin
  EnterCriticalSection(FLock);
  Result := FLastTestApiKey;
  LeaveCriticalSection(FLock);
end;

procedure TDataFakeHub.Handle(AServer: TFakeServer; ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  P, LApiKey, LBody: string;
begin
  P := ARequest.PathInfo;
  LApiKey := ARequest.CustomHeaders.Values['X-Reportman-ApiKey'];
  if P = '/api/agent/databases' then
  begin
    EnterCriticalSection(FLock);
    Inc(FDatabasesCalls);
    LeaveCriticalSection(FLock);
    if LApiKey = 'slow-key' then
      Sleep(1500);
    if (LApiKey = 'hub-key') or (LApiKey = 'slow-key') then
      SendJson(AResponse, 200, '{"databases":[' +
        '{"displayName":"Sales - Main","name":"main","hubDatabaseId":77,"hubSchemaId":5},' +
        '{"displayName":"HR","name":"hr","hubDatabaseId":78,"hubSchemaId":7}],' +
        '"aiEndpoints":[]}')
    else if LApiKey = 'fail-key' then
      SendJson(AResponse, 500, '{"message":"Internal error"}')
    else
      SendJson(AResponse, 200, '{"databases":[],"aiEndpoints":[]}');
  end
  else if P = '/api/agent/testconnection' then
  begin
    LBody := ARequest.Content;
    EnterCriticalSection(FLock);
    Inc(FTestCalls);
    FLastTestBody := LBody;
    FLastTestApiKey := LApiKey;
    LeaveCriticalSection(FLock);
    if (Pos('"hubDatabaseId":77', LBody) > 0) or (Pos('"hubDatabaseId":78', LBody) > 0) then
      SendJson(AResponse, 200, '{"success":true,"data":{"message":"Agent Connection: Success' +
        '\nDatabase Connection: Success (fake)"}}')
    else if Pos('"hubDatabaseId":79', LBody) > 0 then
      SendJson(AResponse, 200, '{"success":true}')
    else
      SendJson(AResponse, 500, '{"message":"Database not found"}');
  end
  else
    SendText(AResponse, 404, 'text/plain', 'Unknown endpoint ' + P);
end;

{ TAIDataTests }

constructor TAIDataTests.Create(const AShotsDir: string);
begin
  inherited Create;
  FShotsDir := AShotsDir;
end;

procedure TAIDataTests.Pump(AMs: Cardinal);
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

procedure TAIDataTests.WaitUntil(ACondition: TCondition; ATimeoutMs: Cardinal;
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

function TAIDataTests.IniValue(const ASection, AName: string): string;
var
  LIni: TMemIniFile;
begin
  LIni := TMemIniFile.Create(FIniFile);
  try
    Result := LIni.ReadString(ASection, AName, '');
  finally
    LIni.Free;
  end;
end;

function TAIDataTests.IniHasSection(const ASection: string): Boolean;
var
  LIni: TMemIniFile;
begin
  LIni := TMemIniFile.Create(FIniFile);
  try
    Result := LIni.SectionExists(ASection);
  finally
    LIni.Free;
  end;
end;

procedure TAIDataTests.Shot(AForm: TForm; const AName: string);
var
  LBitmap: TBitmap;
begin
  if FShotsDir = '' then
    Exit;
  ForceDirectories(FShotsDir);
  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(AForm.ClientWidth, AForm.ClientHeight);
    LBitmap.Canvas.Brush.Color := clBtnFace;
    LBitmap.Canvas.FillRect(0, 0, LBitmap.Width, LBitmap.Height);
    AForm.PaintTo(LBitmap.Canvas, 0, 0);
    LBitmap.SaveToFile(IncludeTrailingPathDelimiter(FShotsDir) + AName + '.bmp');
  finally
    LBitmap.Free;
  end;
end;

procedure TAIDataTests.TestEntries;
var
  LDlg: TFRpDBXConfigLCL;
  LRaised: Boolean;
  LEditor: TWinControl;
begin
  Section('Connections file dialog: entries of a temporary connections file');
  LDlg := TFRpDBXConfigLCL.Create(nil);
  try
    LDlg.Interactive := False;
    LDlg.ConnectionsFile := FIniFile;
    CheckEquals(FIniFile, LDlg.ConAdmin.configfilename, 'the dialog edits the given file');
    CheckEquals(string(SRpAllDriver), LDlg.ComboDrivers.Items[0], 'first driver: all');
    Check(LDlg.ComboDrivers.Items.IndexOf('ZeosLib') > 0, 'drivers of the drivers file');
    Check(LDlg.ComboDrivers.Items.IndexOf('Reportman AI Agent') > 0, 'Agent driver listed');
    CheckEquals(2, LDlg.LConnections.Items.Count, 'the entries of the file');
    CheckEquals(0, LDlg.LConnections.ItemIndex, 'first entry selected');
    Check(LDlg.ScrollParams.Visible, 'parameters of the selected entry');
    Check(LDlg.ParamEditor('Database') <> nil, 'an editor for each parameter');
    LDlg.SelectDriver('ZeosLib');
    CheckEquals(1, LDlg.LConnections.Items.Count, 'the entries of the driver');
    CheckEquals('ZCONN', LDlg.LConnections.Items[0], 'Zeos entry');
    // Adding needs a driver
    LDlg.SelectDriver('');
    LRaised := False;
    try
      LDlg.AddConnection('NOPE');
    except
      LRaised := True;
    end;
    Check(LRaised, 'adding without a driver raises');
    Check(not IniHasSection('NOPE'), 'nothing written without a driver');
    // Add
    LDlg.SelectDriver('ZeosLib');
    Check(LDlg.AddConnection('newconn'), 'entry added');
    CheckEquals('NEWCONN', LDlg.LConnections.Items[LDlg.LConnections.ItemIndex],
      'new entry selected (upper case)');
    CheckEquals('ZeosLib', IniValue('NEWCONN', 'DriverName'), 'written with its driver');
    Check(IniValue('NEWCONN', 'User_Name') <> '', 'parameters of the driver copied');
    Check(IniValue('NEWCONN', 'LibraryName') = '', 'library names not copied');
    LEditor := LDlg.ParamEditor('DriverName');
    Check((LEditor is TEdit) and TEdit(LEditor).ReadOnly, 'DriverName is read only');
    Check(LDlg.ParamEditor('Zeos TransIsolation') is TComboBox,
      'a combo for a parameter with a section in the drivers file');
    Check(TEdit(LDlg.ParamEditor('Password')).PasswordChar = '*', 'password hidden');
    Check(LDlg.HubButton = nil, 'no Hub button for Zeos');
    // Parameters are written at once
    LDlg.SetParamValue('Database', 'C:\data\new.fdb');
    CheckEquals('C:\data\new.fdb', IniValue('NEWCONN', 'Database'), 'edit written to the file');
    LDlg.SetParamValue('Zeos TransIsolation', 'ReadCommited');
    CheckEquals('ReadCommited', IniValue('NEWCONN', 'Zeos TransIsolation'),
      'combo written to the file');
    LDlg.SetParamValue('HostName', '');
    Check(IniHasSection('NEWCONN') and (IniValue('NEWCONN', 'HostName') = ''),
      'an empty value is written');
    // Another entry and back: the values read again
    LDlg.SelectDriver('');
    LDlg.SelectConnection('NEWCONN');
    CheckEquals('C:\data\new.fdb', TEdit(LDlg.ParamEditor('Database')).Text, 'value read again');
    CheckEquals('ReadCommited', TComboBox(LDlg.ParamEditor('Zeos TransIsolation')).Text,
      'combo value read again');
    if FShotsDir <> '' then
    begin
      LDlg.Show;
      Pump(200);
      Shot(LDlg, 'dbxconfig_entry');
      LDlg.Hide;
    end;
    // Drop
    LDlg.DropConnection('NEWCONN');
    Check(not IniHasSection('NEWCONN'), 'entry dropped from the file');
    CheckEquals(-1, LDlg.LConnections.Items.IndexOf('NEWCONN'), 'entry dropped from the list');
    CheckEquals('C:\data\zdb.fdb', IniValue('ZCONN', 'Database'), 'the other entries kept');
  finally
    LDlg.Free;
  end;
  Check(RpAsyncWaitIdle(5000), 'no worker left');
end;

procedure TAIDataTests.TestHubDiscovery;
var
  LDlg: TFRpDBXConfigLCL;
  LCalls: Integer;

  function DiscoveryDone: Boolean;
  begin
    Result := not LDlg.HubDiscoveryRunning;
  end;
  function MessageArrived: Boolean;
  begin
    Result := LDlg.MessageCount > 0;
  end;

begin
  Section('Connections file dialog: Hub databases of an API key');
  LDlg := TFRpDBXConfigLCL.Create(nil);
  try
    LDlg.Interactive := False;
    LDlg.ConnectionsFile := FIniFile;
    LDlg.SelectConnection('HUBCONN');
    Check(LDlg.HubButton <> nil, 'Select Connection button for HubDatabaseId');
    CheckEquals(string(TranslateStr(1671, 'Select Connection...')), LDlg.HubButton.Caption,
      'button caption');
    Check(LDlg.HubButton.Width >= RpCaptionWidth(LDlg.HubButton,
      [LDlg.HubButton.Caption, TranslateStr(1672, 'Loading...')]),
      'the captions fit the button');
    // Without API key: a message and no request
    LCalls := FHubHandler.DatabasesCalls;
    LDlg.SetParamValue('ApiKey', '');
    LDlg.StartHubDiscovery;
    CheckEquals(string(TranslateStr(1673, 'Please enter a valid API Key first.')),
      LDlg.LastMessage, 'an API key is needed');
    Check(not LDlg.HubDiscoveryRunning, 'no discovery without API key');
    CheckEquals(LCalls, FHubHandler.DatabasesCalls, 'no request without API key');
    // The databases of the key
    LDlg.SetParamValue('ApiKey', 'hub-key');
    CheckEquals('hub-key', IniValue('HUBCONN', 'ApiKey'), 'API key written');
    LDlg.StartHubDiscovery;
    Check(LDlg.HubDiscoveryRunning, 'discovery running');
    Check(not LDlg.HubButton.Enabled, 'button disabled while loading');
    CheckEquals(string(TranslateStr(1672, 'Loading...')), LDlg.HubButton.Caption,
      'button caption while loading');
    WaitUntil(DiscoveryDone, 15000, 'Hub databases received');
    Check(LDlg.HubButton.Enabled, 'button enabled again');
    CheckEquals(string(TranslateStr(1671, 'Select Connection...')), LDlg.HubButton.Caption,
      'button caption again');
    CheckEquals(2, LDlg.HubMenu.Items.Count, 'a menu item per database');
    CheckEquals('Sales - Main', LDlg.HubMenu.Items[0].Caption, 'database name');
    CheckEquals('HR', LDlg.HubMenu.Items[1].Caption, 'second database name');
    // Choosing a database writes its id
    LDlg.HubMenu.Items[1].Click;
    CheckEquals('78', TEdit(LDlg.ParamEditor('HubDatabaseId')).Text, 'HubDatabaseId set');
    CheckEquals('78', IniValue('HUBCONN', 'HubDatabaseId'), 'HubDatabaseId written');
    // No databases
    LDlg.SetParamValue('ApiKey', 'empty-key');
    LDlg.StartHubDiscovery;
    WaitUntil(DiscoveryDone, 15000, 'empty answer received');
    CheckEquals(string(TranslateStr(1675, 'No databases found for this API Key.')),
      LDlg.LastMessage, 'no databases message');
    CheckEquals(0, LDlg.HubMenu.Items.Count, 'no menu items');
    // An error of the Hub
    LDlg.SetParamValue('ApiKey', 'fail-key');
    LDlg.StartHubDiscovery;
    WaitUntil(DiscoveryDone, 15000, 'Hub error received');
    CheckContains(string(TranslateStr(1674, 'Failed to connect to Hub for discovery')),
      LDlg.LastMessage, 'discovery error message');
    // Superseded by another entry: the answer is dropped
    LDlg.SetParamValue('ApiKey', 'slow-key');
    LDlg.StartHubDiscovery;
    LCalls := LDlg.MessageCount;
    LDlg.SelectConnection('ZCONN');
    Check(LDlg.HubButton = nil, 'another entry selected');
    Check(RpAsyncWaitIdle(10000), 'superseded discovery finished');
    Pump(50);
    CheckEquals(LCalls, LDlg.MessageCount, 'superseded discovery: no message');
    CheckEquals(0, LDlg.HubMenu.Items.Count, 'superseded discovery: no menu');
    // Destroyed while running
    LDlg.SelectConnection('HUBCONN');
    LDlg.StartHubDiscovery;
    Check(LDlg.HubDiscoveryRunning, 'slow discovery running');
  finally
    LDlg.Free;
  end;
  Check(RpAsyncWaitIdle(10000), 'discovery of a destroyed dialog finished');
  Pump(50);
  // Keep the entry as it was
  with TMemIniFile.Create(FIniFile) do
  try
    WriteString('HUBCONN', 'ApiKey', 'hub-key');
    WriteString('HUBCONN', 'HubDatabaseId', '77');
    UpdateFile;
  finally
    Free;
  end;
end;

procedure TAIDataTests.TestConnectionTest;
var
  LDlg: TFRpDBXConfigLCL;
  LCount: Integer;

  function TestDone: Boolean;
  begin
    Result := (not LDlg.ConnectionTestRunning) and (LDlg.MessageCount > LCount);
  end;

begin
  Section('Connections file dialog: Connect');
  LDlg := TFRpDBXConfigLCL.Create(nil);
  try
    LDlg.Interactive := False;
    LDlg.ConnectionsFile := FIniFile;
    // Agent entry: the message of the Hub
    LDlg.SelectConnection('HUBCONN');
    LCount := LDlg.MessageCount;
    LDlg.StartConnectionTest;
    Check(LDlg.ConnectionTestRunning, 'Connect running');
    WaitUntil(TestDone, 15000, 'Agent connection tested');
    CheckEquals(AGENT_OK_MESSAGE, AdjustLineBreaks(LDlg.LastMessage, tlbsLF),
      'the message of the Hub');
    CheckContains('"hubDatabaseId":77', FHubHandler.LastTestBody, 'database of the entry sent');
    CheckEquals('hub-key', FHubHandler.LastTestApiKey, 'API key of the entry sent');
    // No message from the Hub: the default one
    LDlg.SetParamValue('HubDatabaseId', '79');
    LCount := LDlg.MessageCount;
    LDlg.StartConnectionTest;
    WaitUntil(TestDone, 15000, 'Agent connection tested (no message)');
    CheckEquals(string(TranslateStr(1676, 'Agent Connection: Success')) + LineEnding +
      string(TranslateStr(1677, 'Database Connection: Success')), LDlg.LastMessage,
      'default success message');
    // A failure
    LDlg.SetParamValue('HubDatabaseId', '0');
    LCount := LDlg.MessageCount;
    LDlg.StartConnectionTest;
    WaitUntil(TestDone, 15000, 'Agent connection failure');
    CheckContains(string(TranslateStr(1678, 'Agent Connection: Fail')), LDlg.LastMessage,
      'failure message');
    CheckContains('Database not found', LDlg.LastMessage, 'error of the Hub in the message');
    LDlg.SetParamValue('HubDatabaseId', '77');
    // Another driver: connects in the worker (a Zeos entry without server)
    LDlg.SelectConnection('ZCONN');
    LCount := LDlg.MessageCount;
    LDlg.StartConnectionTest;
    WaitUntil(TestDone, 30000, 'Zeos connection tested');
    Check(LDlg.LastMessage <> string(SRpConnectionOk), 'Zeos entry without server fails: ' +
      LDlg.LastMessage);
    // Destroyed while testing
    LDlg.SelectConnection('HUBCONN');
    LDlg.StartConnectionTest;
  finally
    LDlg.Free;
  end;
  Check(RpAsyncWaitIdle(15000), 'test of a destroyed dialog finished');
  Pump(50);
end;

procedure TAIDataTests.TestDataDialogAgent;
var
  LReport: TRpReport;
  LDlg: TFRpDInfoLCL;
  LOverride: string;
  LCount: Integer;

  function TestDone: Boolean;
  begin
    Result := (not LDlg.ConnectionTestRunning) and (LDlg.MessageCount > LCount);
  end;

begin
  Section('Data configuration dialog: Connect with the Reportman AI Agent driver');
  LOverride := DBXConnectionsFileOverride;
  DBXConnectionsFileOverride := FIniFile;
  LReport := TRpReport.Create(nil);
  try
    LReport.DatabaseInfo.Add('HUBCONN').Driver := rpdbHttp;
    LReport.DatabaseInfo.Add('BADHUB').Driver := rpdbHttp;
    LDlg := TFRpDInfoLCL.Create(nil);
    try
      LDlg.Interactive := False;
      LDlg.Report := LReport;
      CheckEquals(FpcDriverName(rpdbHttp), LDlg.DriverCombo.Text, 'Agent driver shown');
      CheckEquals('ZCONN', Trim(LDlg.AvailableConnections.Text),
        'connections of the file for the Zeos driver of the list');
      LDlg.SelectListDriver(rpdbHttp);
      CheckEquals('HUBCONN', Trim(LDlg.AvailableConnections.Text),
        'connections of the file for the Agent driver');
      LCount := LDlg.MessageCount;
      LDlg.StartConnectionTest;
      WaitUntil(TestDone, 15000, 'Agent connection of the report tested');
      CheckEquals(string(SRpConnectionOk), LDlg.LastMessage, 'connection test passed');
      CheckContains('"hubDatabaseId":77', FHubHandler.LastTestBody,
        'database of the connections file sent');
      // A connection without entry in the file: the error of the Hub
      LDlg.ConnectionList.ItemIndex := 1;
      LDlg.ConnectionList.OnClick(LDlg.ConnectionList);
      LCount := LDlg.MessageCount;
      LDlg.StartConnectionTest;
      WaitUntil(TestDone, 15000, 'Agent connection without entry tested');
      Check(LDlg.LastMessage <> string(SRpConnectionOk), 'failure reported: ' + LDlg.LastMessage);
    finally
      LDlg.Free;
    end;
  finally
    LReport.Free;
    DBXConnectionsFileOverride := LOverride;
  end;
  Check(RpAsyncWaitIdle(10000), 'no worker left');
end;

procedure TAIDataTests.TestDataDialogLayout;
var
  LReport: TRpReport;
  LDlg: TFRpDInfoLCL;
  LDS: TRpDataInfoItem;
  LOverride: string;

  function BottomIn(AControl: TControl; AParent: TWinControl): Boolean;
  begin
    Result := AControl.Top + AControl.Height <= AParent.ClientHeight;
  end;

  function RightIn(AControl: TControl; AParent: TWinControl): Boolean;
  begin
    Result := AControl.Left + AControl.Width <= AParent.ClientWidth;
  end;

begin
  Section('Data configuration dialog: layout on a 800x600 screen');
  LOverride := DBXConnectionsFileOverride;
  DBXConnectionsFileOverride := FIniFile;
  LReport := TRpReport.Create(nil);
  try
    LReport.DatabaseInfo.Add('MYB').Driver := rpdatamybase;
    LReport.DatabaseInfo.Add('ZCONN').Driver := rpdatazeos;
    LDS := LReport.DataInfo.Add('CUSTOMERS');
    LDS.DatabaseAlias := 'MYB';
    LDS.MyBaseFilename := 'customers.txt';
    LDS.MyBaseFields := 'customers.ini';
    LDS.DataUnions.Add('ORDERS');
    LDS := LReport.DataInfo.Add('ORDERS');
    LDS.DatabaseAlias := 'ZCONN';
    LDS.SQL := 'SELECT * FROM ORDERS';
    LDlg := TFRpDInfoLCL.Create(nil);
    try
      LDlg.Interactive := False;
      // Deterministic editor (WebView2 has its own tests)
      LDlg.MonacoEditor.ActivateFallback('test');
      LDlg.Report := LReport;
      LDlg.SetBounds(0, 0, 780, 560);
      LDlg.Show;
      LDlg.PageControl.ActivePage := LDlg.ConnectionsTab;
      Pump(200);
      Check(LDlg.DriverHelp.Width > 100, 'driver description visible');
      Check(LDlg.DriverList.Height > 40, 'driver list visible');
      Check(BottomIn(LDlg.TestConnectionButton, LDlg.TestConnectionButton.Parent),
        'Connect button inside the connection properties');
      Check(BottomIn(LDlg.LoadDriverParamsCheck, LDlg.LoadDriverParamsCheck.Parent),
        'Load driver params inside the connection properties');
      Check(RightIn(LDlg.DriverCombo, LDlg.DriverCombo.Parent), 'driver combo fits');
      Shot(LDlg, 'data_connections');
      LDlg.PageControl.ActivePage := LDlg.DatasetsTab;
      Pump(200);
      Check(LDlg.MyBaseArea.Visible and not LDlg.SQLArea.Visible, 'MyBase page of CUSTOMERS');
      Check(RightIn(LDlg.BShowData, LDlg.BShowData.Parent), 'Show data fits the toolbar');
      Check(LDlg.MyBaseFileEdit.Width > 100, 'MyBase file edit visible');
      Check(LDlg.UnionsList.Width > 100, 'unions list visible');
      Check(LDlg.UnionsList.Height > 30, 'unions list height');
      CheckEquals('ORDERS', Trim(LDlg.UnionsList.Items.Text), 'unions of CUSTOMERS shown');
      Shot(LDlg, 'data_mybase');
      LDlg.DatasetList.ItemIndex := 1;
      LDlg.DatasetList.OnClick(LDlg.DatasetList);
      Pump(100);
      Check(LDlg.SQLArea.Visible and not LDlg.MyBaseArea.Visible, 'SQL page of ORDERS');
      Shot(LDlg, 'data_sql');
      LDlg.Hide;
    finally
      LDlg.Free;
    end;
  finally
    LReport.Free;
    DBXConnectionsFileOverride := LOverride;
  end;
  Check(RpAsyncWaitIdle(10000), 'no worker left');
end;

var
  GOpenedUrl: string;

// The browser: keeps the URL instead of opening it
function CaptureUrl(const AURL: string): Boolean;
begin
  GOpenedUrl := AURL;
  Result := True;
end;

procedure TAIDataTests.TestAgentInfo;
var
  LDlg: TFRpDBXConfigLCL;
  LFile, LOldLanguage: string;
begin
  Section('Connections file dialog: what the Reportman Agent is and its download link');
  // A file without Agent entries
  LFile := FDir + 'dbxconnections_noagent.ini';
  with TStringList.Create do
  try
    Add('[ZCONN]');
    Add('DriverName=ZeosLib');
    Add('Database=C:\data\zdb.fdb');
    SaveToFile(LFile);
  finally
    Free;
  end;
  LOldLanguage := TRpAuthManager.Instance.AILanguage;
  LDlg := TFRpDBXConfigLCL.Create(nil);
  try
    LDlg.Interactive := False;
    LDlg.ConnectionsFile := FIniFile;
    LDlg.SelectConnection('ZCONN');
    Check(LDlg.AgentInfo = nil, 'no Agent explanation for a Zeos entry');
    LDlg.SelectConnection('HUBCONN');
    Check(LDlg.AgentInfo <> nil, 'the Agent explained with an Agent entry');
    Check(LDlg.AgentInfo.Top > LDlg.ParamEditor('HubDatabaseId').Top,
      'under the parameters');
    CheckEquals(string(TranslateStr(1822, 'Download Reportman Agent')),
      LDlg.AgentLink.Caption, 'download link');
    // The page in the language of the AI
    RpOpenUrlHook := CaptureUrl;
    try
      TRpAuthManager.Instance.AILanguage := 'Spanish';
      GOpenedUrl := '';
      LDlg.AgentLink.OnClick(LDlg.AgentLink);
      CheckEquals('https://ai.reportman.es/es/download', GOpenedUrl, 'Spanish download page');
      TRpAuthManager.Instance.AILanguage := 'English';
      LDlg.AgentLink.OnClick(LDlg.AgentLink);
      CheckEquals('https://ai.reportman.es/download', GOpenedUrl, 'English download page');
    finally
      RpOpenUrlHook := nil;
      TRpAuthManager.Instance.AILanguage := LOldLanguage;
    end;
    // No Agent entry yet: the explanation alone
    LDlg.ConnectionsFile := LFile;
    LDlg.SelectDriver('Reportman AI Agent');
    CheckEquals(0, LDlg.LConnections.Items.Count, 'no Agent entries in the file');
    Check(LDlg.ScrollParams.Visible and (LDlg.AgentInfo <> nil),
      'the explanation alone when the Agent driver has no entries');
    if FShotsDir <> '' then
    begin
      LDlg.Show;
      Pump(200);
      Shot(LDlg, 'dbxconfig_agent_info');
      LDlg.Hide;
    end;
    LDlg.SelectDriver('ZeosLib');
    Check(LDlg.AgentInfo = nil, 'not with the other drivers');
  finally
    LDlg.Free;
  end;
end;

var
  GDataWizardCalls: Integer;
  GDataWizardName: string;
  GDataWizardFile: string;

// The connection wizard: a new connection is WIZCONN; both are written to the
// connections file with the Hub database of HUBCONN
function DataFakeWizard(const AFixedName: string; APreferredHubDatabaseId: Int64;
  out AConnectionName: string; out ADriver: TRpDbDriver): Boolean;
var
  LIni: TMemIniFile;
begin
  Inc(GDataWizardCalls);
  GDataWizardName := AFixedName;
  if AFixedName = '' then
    AConnectionName := 'WIZCONN'
  else
    AConnectionName := AFixedName;
  LIni := TMemIniFile.Create(GDataWizardFile);
  try
    LIni.WriteString(AConnectionName, 'DriverName', 'Reportman AI Agent');
    LIni.WriteString(AConnectionName, 'ApiKey', 'hub-key');
    LIni.WriteString(AConnectionName, 'HubDatabaseId', '77');
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
  ADriver := rpdbHttp;
  Result := True;
end;

procedure TAIDataTests.TestDataDialogWizard;
var
  LReport: TRpReport;
  LDlg: TFRpDInfoLCL;
  LOverride: string;
  LOld: TRpShowConnectionWizardFunc;
  LIni: TMemIniFile;
begin
  Section('Data configuration dialog: the connection wizard');
  LOverride := DBXConnectionsFileOverride;
  DBXConnectionsFileOverride := FIniFile;
  LOld := RpConnectionWizardFunc;
  RpConnectionWizardFunc := DataFakeWizard;
  GDataWizardCalls := 0;
  GDataWizardFile := FIniFile;
  LReport := TRpReport.Create(nil);
  try
    LDlg := TFRpDInfoLCL.Create(nil);
    try
      LDlg.Interactive := False;
      LDlg.Report := LReport;
      Check(LDlg.EmptyConnectionsPanel.Visible,
        'no connections: the wizard in the middle of the tab');
      CheckContains(string(TranslateStr(1826, 'Add connection')),
        LDlg.AddConnectionWizardButton.Caption, 'Add connection button');
      Check(not LDlg.AddConnectionWizardButton.Glyph.Empty, 'with the magic wand');
      if FShotsDir <> '' then
      begin
        LDlg.Show;
        Pump(200);
        Shot(LDlg, 'data_connections_empty');
      end;
      LDlg.AddConnectionWizardButton.Click;
      CheckEquals(1, GDataWizardCalls, 'the connection wizard');
      CheckEquals('', GDataWizardName, 'for a new connection');
      CheckEquals(1, LDlg.ConnectionList.Count, 'the connection of the wizard added');
      CheckEquals('WIZCONN', LDlg.ConnectionList.Items[0], 'its name');
      Check(LDlg.WorkReport.DatabaseInfo.Items[0].Driver = rpdbHttp, 'its driver');
      Check(not LDlg.EmptyConnectionsPanel.Visible, 'the empty tab hidden');
      Check(not LDlg.AgentProblemLabel.Visible and not LDlg.ConfigureWizardButton.Visible,
        'configured: no warning');
      // An Agent connection that the connections file does not have
      LDlg.SelectListDriver(rpdbHttp);
      LDlg.AddAvailableConnection('NOTHERE');
      Check(LDlg.AgentProblemLabel.Visible and LDlg.ConfigureWizardButton.Visible,
        'not configured here: warning and "Configure with the wizard"');
      CheckContains('NOTHERE', LDlg.AgentProblemLabel.Caption, 'the warning names it');
      CheckEquals(string(TranslateStr(1829, 'Configure with the wizard')),
        LDlg.ConfigureWizardButton.Caption, 'the configure button');
      if FShotsDir <> '' then
      begin
        Pump(200);
        Shot(LDlg, 'data_connections_agent_problem');
      end;
      LDlg.ConfigureWizardButton.Click;
      CheckEquals(2, GDataWizardCalls, 'the connection wizard again');
      CheckEquals('NOTHERE', GDataWizardName, 'for that connection');
      Check(not LDlg.AgentProblemLabel.Visible and not LDlg.ConfigureWizardButton.Visible,
        'configured: the warning goes away');
      LDlg.Hide;
    finally
      LDlg.Free;
    end;
  finally
    LReport.Free;
    RpConnectionWizardFunc := LOld;
    DBXConnectionsFileOverride := LOverride;
    LIni := TMemIniFile.Create(FIniFile);
    try
      LIni.EraseSection('WIZCONN');
      LIni.EraseSection('NOTHERE');
      LIni.UpdateFile;
    finally
      LIni.Free;
    end;
  end;
end;

procedure TAIDataTests.Run;
var
  LSandbox: string;
begin
  LSandbox := GetEnvironmentVariable('LOCALAPPDATA');
  if Pos('rpaichattest', LSandbox) = 0 then
    Fail('the tests must run in the sandbox (LOCALAPPDATA=' + LSandbox + ')');
  FDir := IncludeTrailingPathDelimiter(LSandbox) + 'datatests' + PathDelim;
  ForceDirectories(FDir);
  FIniFile := FDir + 'dbxconnections_data.ini';
  with TStringList.Create do
  try
    Add('[ZCONN]');
    Add('DriverName=ZeosLib');
    Add('Database Protocol=firebird');
    Add('HostName=127.0.0.1');
    Add('Port=9');
    Add('Database=C:\data\zdb.fdb');
    Add('User_Name=sysdba');
    Add('Password=masterkey');
    Add('[HUBCONN]');
    Add('DriverName=Reportman AI Agent');
    Add('ApiKey=hub-key');
    Add('HubDatabaseId=77');
    SaveToFile(FIniFile);
  finally
    Free;
  end;

  FHubHandler := TDataFakeHub.Create;
  FHub := TFakeServer.Create(FHubHandler.Handle);
  try
    FHub.Start;
    Log('  fake Hub (data) on ' + FHub.BaseURL + ' for ' + HUB_API_URL);
    RpHttpSetUrlRewrite(HUB_API_URL, FHub.BaseURL);
    try
      TestEntries;
      TestHubDiscovery;
      TestConnectionTest;
      TestDataDialogAgent;
      TestDataDialogLayout;
      TestAgentInfo;
      TestDataDialogWizard;
      Check(RpAsyncWaitIdle(10000), 'all the data workers finished');
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

procedure RunAIDataTests(const AShotsDir: string);
var
  LTests: TAIDataTests;
begin
  LTests := TAIDataTests.Create(AShotsDir);
  try
    LTests.Run;
  finally
    LTests.Free;
  end;
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpdbxconfiglcl                                  }
{       Configuration dialog for connections            }
{       it stores all info in config files              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpdbxconfiglcl;

{ Port of rpdbxconfigvcl (TFRpDBXConfigVCL): add and drop the entries of the
  connections file (dbxconnections), edit their parameters (a combo when the
  drivers file has a section with the name of the parameter), test them
  (Connect) and, for the Reportman AI Agent entries, pick the Hub database of
  the API key (Select Connection...).

  Differences with the VCL:
  - The network work (Hub discovery, connection test) runs in worker threads
    (TRpAsyncWorker); the VCL tests the connection in the UI thread.
  - ShowDBXConfig(ConnectionsFile) edits that file (the VCL only shows it).
  - Drivers of the FPC build: the entries are opened with the driver that
    ResolveFpcConnectionDriver gives (the VCL ResolveDbxConnectionDriver maps
    unknown drivers to dbExpress, not available with FPC).
  - No FireDAC connection editor (FireDAC is not available with FPC) and no
    reset of the WebRTC channel pool (Windows/Delphi only). }

{$mode delphi}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  ComCtrls, Menus, IniFiles,
  rpdatainfo, rpreport, rpmdconsts, rpaithreadslcl;

type
  // Result of a connection test (worker thread -> UI)
  TRpConnectionTestResult = class(TRpAsyncMessage)
  public
    Session: Integer;
    RequestVersion: Integer;
    Success: Boolean;
    MessageText: string;
  end;

  // Tests a connection in a worker thread (the worker owns Report and
  // HttpParams). With HttpParams it asks the Hub about a Reportman AI Agent
  // entry of the connections file (VCL ExecuteHttpConnectionTest); otherwise
  // it connects the first connection of Report with the report parameters and
  // disconnects it (VCL BConnectClick, TFRpConnectionVCL.BTestClick).
  TRpConnectionTestWorker = class(TRpAsyncWorker)
  public
    Session: Integer;
    RequestVersion: Integer;
    Report: TRpReport;
    HttpParams: TStringList;
    Token: string;
    destructor Destroy; override;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

  { TFRpDBXConfigLCL }

  TFRpDBXConfigLCL = class(TForm)
  private
    FConAdmin: TRpConnAdmin;
    FParams: TStringList;
    FConnectionName: string;
    FDriversFile: string;
    FConnectionsFile: string;
    FInteractive: Boolean;
    FLastMessage: string;
    FMessageCount: Integer;
    FUpdatingParams: Boolean;
    FHubDiscoveryRequestVersion: Integer;
    FHubDiscoveryRunning: Boolean;
    FHubCancel: IRpAsyncCancel;
    FTestRequestVersion: Integer;
    FTestRunning: Boolean;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    FImages: TImageList;
    FHubButton: TButton;
    FHubMenu: TPopupMenu;
    FAgentInfo: TLabel;
    FAgentLink: TLabel;
    // Controls
    PTop: TPanel;
    LDriversFile: TLabel;
    LConnsFile: TLabel;
    EDriversFile: TEdit;
    EConnectionsFile: TEdit;
    PLeft: TPanel;
    ToolBar1: TToolBar;
    BAdd: TToolButton;
    BDelete: TToolButton;
    BShowProps: TToolButton;
    BConnect: TToolButton;
    BClose: TToolButton;
    PDriver: TPanel;
    LShowDriver: TLabel;
    FComboDrivers: TComboBox;
    FLConnections: TListBox;
    FScrollParams: TScrollBox;
    procedure BuildControls;
    procedure LoadConfig;
    procedure FreeParamsControls;
    procedure CreateParamsControls;
    procedure AddAgentInfo(ATop: Integer);
    procedure AgentLinkClick(Sender: TObject);
    procedure ComboDriversClick(Sender: TObject);
    procedure LConnectionsClick(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BShowPropsClick(Sender: TObject);
    procedure BConnectClick(Sender: TObject);
    procedure BCloseClick(Sender: TObject);
    procedure BSelectHubConnectionClick(Sender: TObject);
    procedure HubConnectionMenuItemClick(Sender: TObject);
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
    procedure ShowInfo(const AText: string);
    procedure UpdateHubButton;
    function GetParamValue(const AParamName: string): string;
    procedure SetConnectionsFile(const AValue: string);
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Operations of the buttons without their prompts (the tests use them)
    // Adds an entry of the selected driver; False when the name is empty
    function AddConnection(const AName: string): Boolean;
    // Drops an entry without asking
    procedure DropConnection(const AName: string);
    // Shows the entries of a driver ('' or SRpAllDriver: all)
    procedure SelectDriver(const ADriverName: string);
    procedure SelectConnection(const AName: string);
    // The editor of a parameter of the selected entry (nil if there is none)
    function ParamEditor(const AParamName: string): TWinControl;
    // Sets a parameter of the selected entry as typing it in its editor
    procedure SetParamValue(const AParamName, AValue: string);
    procedure StartHubDiscovery;
    procedure StartConnectionTest;
    // Writes the connections file (what closing the dialog does)
    procedure SaveConfig;
    // The file edited (default: the one of TRpConnAdmin)
    property ConnectionsFile: string read FConnectionsFile write SetConnectionsFile;
    property DriversFile: string read FDriversFile;
    property ConAdmin: TRpConnAdmin read FConAdmin;
    property ComboDrivers: TComboBox read FComboDrivers;
    property LConnections: TListBox read FLConnections;
    property ScrollParams: TScrollBox read FScrollParams;
    // Button of the HubDatabaseId parameter (nil when the entry has none)
    property HubButton: TButton read FHubButton;
    // What the Reportman Agent is and its download link, under the
    // parameters of an Agent entry or alone when the list of the Agent
    // driver is empty (nil otherwise)
    property AgentInfo: TLabel read FAgentInfo;
    property AgentLink: TLabel read FAgentLink;
    // Hub databases of the last discovery (name, Hint = hubDatabaseId)
    property HubMenu: TPopupMenu read FHubMenu;
    property HubDiscoveryRunning: Boolean read FHubDiscoveryRunning;
    property ConnectionTestRunning: Boolean read FTestRunning;
    // False: messages and the Hub menu are not shown (tests), the messages
    // are only kept in LastMessage
    property Interactive: Boolean read FInteractive write FInteractive;
    property LastMessage: string read FLastMessage;
    property MessageCount: Integer read FMessageCount;
  end;

// Shows the configuration dialog of the connections file (the default one of
// TRpConnAdmin when ConnectionsFile is empty)
procedure ShowDBXConfig(ConnectionsFile: string = '');

// The driver that opens an entry of the connections file in the FPC build:
// FireDac and SQLite entries use the SQLite driver of the FireDAC shim, the
// Reportman AI Agent ones the Hub driver, the other dbExpress drivers Zeos
// (it takes DriverName as protocol); ADefault when there is no DriverName
function ResolveFpcConnectionDriver(const ADriverName: string;
  ADefault: TRpDbDriver): TRpDbDriver;
// Drivers that can open connections in the FPC build
function IsFpcDriverAvailable(ADriver: TRpDbDriver): Boolean;
// Names of the drivers of the FPC build (GetRpDatabaseDrivers), with the
// driver in Objects
procedure GetFpcDatabaseDrivers(AList: TStrings);
function FpcDriverName(ADriver: TRpDbDriver): string;
// Driver description (VCL TFRpConnectionVCL.GDriverClick)
function FpcDriverDescription(ADriver: TRpDbDriver): string;
// VCL ExecuteHttpConnectionTest: asks the Hub about the database of an Agent
// entry (params ApiKey, HubDatabaseId); runs in a worker thread
function ExecuteHttpConnectionTest(AParams: TStrings; const AToken: string;
  out AMessageText: string): Boolean;
// Width that fits the longest caption (fixed width buttons: AutoSize
// buttons aligned to the sides loop when they do not fit)
function RpCaptionWidth(AControl: TControl; const ACaptions: array of string;
  AMinWidth: Integer = 75): Integer;

implementation

uses
  rpjsonfpc, rpdatahttp, rpauthmanager, rpgraphutilslcl, rpmdimageslcl, rplcllayout;

const
  CONTROL_DISTANCEY = 5;
  CONTROL_DISTANCEX = 10;
  CONTROL_DISTANCEX2 = 150;
  LABEL_INCY = 4;
  HTTP_TEST_CONNECTION_TIMEOUT_MS = 10000;
  AGENT_DRIVER_NAME = 'Reportman AI Agent';

type
  // Hub databases of an API key (worker thread -> UI)
  TRpHubDiscoveryResult = class(TRpAsyncMessage)
  public
    RequestVersion: Integer;
    Databases: TStringList;
    ErrorMessage: string;
    constructor Create;
    destructor Destroy; override;
  end;

  // VCL BSelectHubConnectionClick (anonymous thread)
  TRpHubDiscoveryWorker = class(TRpAsyncWorker)
  public
    RequestVersion: Integer;
    ApiKey: string;
    Cancel: IRpAsyncCancel;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

function TextHubSelect: string;
begin
  Result := TranslateStr(1671, 'Select Connection...');
end;

function TextHubLoading: string;
begin
  Result := TranslateStr(1672, 'Loading...');
end;

function RpCaptionWidth(AControl: TControl; const ACaptions: array of string;
  AMinWidth: Integer): Integer;
var
  LBitmap: TBitmap;
  I: Integer;
begin
  Result := (AMinWidth * Screen.PixelsPerInch) div 96;
  LBitmap := TBitmap.Create;
  try
    if AControl <> nil then
      LBitmap.Canvas.Font := AControl.Font;
    for I := 0 to High(ACaptions) do
      Result := Max(Result, LBitmap.Canvas.TextWidth(ACaptions[I]) +
        (24 * Screen.PixelsPerInch) div 96);
  finally
    LBitmap.Free;
  end;
end;

function ResolveFpcConnectionDriver(const ADriverName: string;
  ADefault: TRpDbDriver): TRpDbDriver;
var
  LName: string;
begin
  LName := Trim(ADriverName);
  if LName = '' then
    Result := ADefault
  else if SameText(LName, 'FireDac') or SameText(LName, 'SQLite') then
    Result := rpfiredac
  else if SameText(LName, AGENT_DRIVER_NAME) then
    Result := rpdbHttp
  else
    Result := rpdatazeos;
end;

function IsFpcDriverAvailable(ADriver: TRpDbDriver): Boolean;
begin
  Result := ADriver in [rpdatamybase, rpdatazeos, rpfiredac, rpdbHttp];
end;

function FpcDriverName(ADriver: TRpDbDriver): string;
var
  LNames: TStringList;
begin
  LNames := TStringList.Create;
  try
    GetRpDatabaseDrivers(LNames);
    if Ord(ADriver) < LNames.Count then
      Result := LNames[Ord(ADriver)]
    else
      Result := IntToStr(Ord(ADriver));
    // The FireDAC shim of the FPC build only opens SQLite databases
    if ADriver = rpfiredac then
      Result := Result + ' (SQLite)';
  finally
    LNames.Free;
  end;
end;

procedure GetFpcDatabaseDrivers(AList: TStrings);
var
  LDriver: TRpDbDriver;
begin
  AList.Clear;
  for LDriver := Low(TRpDbDriver) to High(TRpDbDriver) do
    if IsFpcDriverAvailable(LDriver) then
      AList.AddObject(FpcDriverName(LDriver), TObject(PtrInt(Ord(LDriver))));
end;

function FpcDriverDescription(ADriver: TRpDbDriver): string;
begin
  case ADriver of
    rpdatadbexpress:
      Result := SRpDBExpressDesc;
    rpdatamybase:
      Result := SRpMyBaseDesc;
    rpdataibx:
      Result := SRpIBXDesc;
    rpdatabde:
      Result := SRpBDEDesc;
    rpdataado:
      Result := SRpADODesc;
    rpdataibo:
      Result := SRpIBODesc;
    rpdatazeos:
      Result := SrpDriverZeosDesc;
    rpdatadriver, rpdotnet2driver:
      Result := SRpDriverDotNetDesc;
    rpfiredac:
      Result := SRpFireDacDesc + LineEnding +
        TranslateStr(1680, 'In this version it only opens SQLite databases.');
    rpdbHttp:
      Result := TranslateStr(1670, 'Executes SQL remotely via Reportman AI Agent bridge. ' +
        'Supports secure, non-interactive queries with API Keys.');
  else
    Result := '';
  end;
end;

{ HTTP connection test (VCL rpdbxconfigvcl) }

function JsonText(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.GetValue(AName);
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function ExtractHttpConnectionTestMessage(const AResponseText: string): string;
var
  LResponse: TJSONValue;
  LData: TJSONValue;
begin
  Result := '';
  if Trim(AResponseText) = '' then
    Exit;
  LResponse := TJSONObject.ParseJSONValue(AResponseText);
  try
    if not (LResponse is TJSONObject) then
      Exit;
    LData := TJSONObject(LResponse).GetValue('data');
    if LData is TJSONObject then
    begin
      Result := JsonText(TJSONObject(LData), 'message');
      if Result <> '' then
        Exit;
    end;
    Result := JsonText(TJSONObject(LResponse), 'message');
  finally
    LResponse.Free;
  end;
end;

function BuildHttpConnectionFailureMessage(const AErrorText: string): string;
begin
  Result := TranslateStr(1678, 'Agent Connection: Fail') + LineEnding +
    TranslateStr(1679, 'Database Connection: Fail');
  if Trim(AErrorText) <> '' then
    Result := Result + LineEnding + TranslateStr(355, 'Error') + ': ' + Trim(AErrorText);
end;

function ExecuteHttpConnectionTest(AParams: TStrings; const AToken: string;
  out AMessageText: string): Boolean;
var
  LDatabase: TRpDatabaseHttp;
  LRequestBody: TJSONObject;
  LResponseStream: TStringStream;
begin
  Result := False;
  AMessageText := '';
  LDatabase := TRpDatabaseHttp.Create;
  try
    LDatabase.ApiKey := AParams.Values['ApiKey'];
    LDatabase.HubDatabaseId := StrToInt64Def(AParams.Values['HubDatabaseId'], 0);
    if (LDatabase.ApiKey = '') and (AToken <> '') then
      LDatabase.Token := AToken;
    LRequestBody := TJSONObject.Create;
    try
      LRequestBody.AddPair('hubDatabaseId', TJSONNumber.Create(LDatabase.HubDatabaseId));
      LResponseStream := TStringStream.Create('');
      try
        try
          Result := LDatabase.InternalRequest('api/agent/testconnection',
            LRequestBody, LResponseStream, HTTP_TEST_CONNECTION_TIMEOUT_MS);
          if Result then
          begin
            AMessageText := ExtractHttpConnectionTestMessage(LResponseStream.DataString);
            if Trim(AMessageText) = '' then
              AMessageText := TranslateStr(1676, 'Agent Connection: Success') + LineEnding +
                TranslateStr(1677, 'Database Connection: Success');
          end;
        except
          on E: Exception do
          begin
            Result := False;
            AMessageText := BuildHttpConnectionFailureMessage(E.Message);
          end;
        end;
      finally
        LResponseStream.Free;
      end;
    finally
      LRequestBody.Free;
    end;
  finally
    LDatabase.Free;
  end;
end;

{ TRpConnectionTestWorker }

destructor TRpConnectionTestWorker.Destroy;
begin
  FreeAndNil(Report);
  FreeAndNil(HttpParams);
  inherited Destroy;
end;

procedure TRpConnectionTestWorker.Run;
var
  LMsg: TRpConnectionTestResult;
  LText: string;
  dbinfo: TRpDatabaseInfoItem;
begin
  LMsg := TRpConnectionTestResult.Create;
  try
    LMsg.Session := Session;
    LMsg.RequestVersion := RequestVersion;
    if HttpParams <> nil then
    begin
      LMsg.Success := ExecuteHttpConnectionTest(HttpParams, Token, LText);
      if Trim(LText) = '' then
        LText := SRpConnectionOk;
      LMsg.MessageText := LText;
    end
    else
    begin
      dbinfo := Report.DatabaseInfo.Items[0];
      dbinfo.Connect(Report.Params);
      dbinfo.DisConnect;
      LMsg.Success := True;
      LMsg.MessageText := SRpConnectionOk;
    end;
    Post(LMsg);
    LMsg := nil;
  finally
    LMsg.Free;
  end;
end;

procedure TRpConnectionTestWorker.HandleError(E: Exception);
var
  LMsg: TRpConnectionTestResult;
begin
  LMsg := TRpConnectionTestResult.Create;
  LMsg.Session := Session;
  LMsg.RequestVersion := RequestVersion;
  LMsg.Success := False;
  LMsg.MessageText := E.Message;
  Post(LMsg);
end;

{ TRpHubDiscoveryResult }

constructor TRpHubDiscoveryResult.Create;
begin
  inherited Create;
  Databases := TStringList.Create;
end;

destructor TRpHubDiscoveryResult.Destroy;
begin
  Databases.Free;
  inherited Destroy;
end;

{ TRpHubDiscoveryWorker }

procedure TRpHubDiscoveryWorker.Run;
var
  LMsg: TRpHubDiscoveryResult;
begin
  LMsg := TRpHubDiscoveryResult.Create;
  try
    LMsg.RequestVersion := RequestVersion;
    if not TRpDatabaseHttp.GetHubDatabases(ApiKey, LMsg.Databases) then
      LMsg.ErrorMessage := TranslateStr(1674, 'Failed to connect to Hub for discovery. ' +
        'Check your API Key and internet connection.');
    if (Cancel <> nil) and Cancel.Cancelled then
      Exit;
    Post(LMsg);
    LMsg := nil;
  finally
    LMsg.Free;
  end;
end;

procedure TRpHubDiscoveryWorker.HandleError(E: Exception);
var
  LMsg: TRpHubDiscoveryResult;
begin
  if (Cancel <> nil) and Cancel.Cancelled then
    Exit;
  LMsg := TRpHubDiscoveryResult.Create;
  LMsg.RequestVersion := RequestVersion;
  LMsg.ErrorMessage := E.Message;
  Post(LMsg);
end;

{ ShowDBXConfig }

procedure ShowDBXConfig(ConnectionsFile: string);
var
  dia: TFRpDBXConfigLCL;
begin
  dia := TFRpDBXConfigLCL.Create(Application);
  try
    dia.ConnectionsFile := Trim(ConnectionsFile);
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

{ TFRpDBXConfigLCL }

constructor TFRpDBXConfigLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  FInteractive := True;
  FParams := TStringList.Create;
  FMailbox := TRpAsyncMailbox.Create(HandleAsyncMessage);
  FMailboxRef := FMailbox;
  Caption := TranslateStr(177, 'Database connections configuration');
  Position := poScreenCenter;
  ShowHint := True;
  // Fits a 800x600 screen
  Width := Min(Scale96ToScreen(700), Screen.WorkAreaWidth - 20);
  Height := Min(Scale96ToScreen(480), Screen.WorkAreaHeight - 20);
  BuildControls;
  LoadConfig;
end;

destructor TFRpDBXConfigLCL.Destroy;
begin
  // Running requests drop their answers
  FMailbox.Detach;
  if FHubCancel <> nil then
    FHubCancel.Cancel;
  FHubCancel := nil;
  FMailboxRef := nil;
  FreeAndNil(FParams);
  FreeAndNil(FConAdmin);
  inherited Destroy;
end;

procedure TFRpDBXConfigLCL.BuildControls;

  function NewToolButton(AImageIndex: Integer; const AHint: string;
    AClick: TNotifyEvent): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := ToolBar1;
    Result.ImageIndex := AImageIndex;
    Result.Hint := AHint;
    Result.OnClick := AClick;
  end;

  procedure NewSeparator;
  var
    LSep: TToolButton;
  begin
    LSep := TToolButton.Create(Self);
    LSep.Parent := ToolBar1;
    LSep.Style := tbsSeparator;
    LSep.Width := Scale96ToScreen(8);
  end;

var
  LLabelWidth: Integer;
begin
  FImages := TImageList.Create(Self);
  LoadDesignerImageList(FImages);

  // Drivers and connections files
  PTop := TPanel.Create(Self);
  PTop.Parent := Self;
  PTop.Align := alTop;
  PTop.BevelOuter := bvNone;
  PTop.Height := Scale96ToScreen(64);

  LDriversFile := TLabel.Create(Self);
  LDriversFile.Parent := PTop;
  LDriversFile.Caption := TranslateStr(169, 'Drivers file');
  LConnsFile := TLabel.Create(Self);
  LConnsFile.Parent := PTop;
  LConnsFile.Caption := TranslateStr(170, 'Connections file');
  LLabelWidth := Max(RpCaptionWidth(Self, [LDriversFile.Caption, LConnsFile.Caption], 100),
    Scale96ToScreen(120));
  LDriversFile.SetBounds(Scale96ToScreen(8), Scale96ToScreen(9), LLabelWidth, Scale96ToScreen(18));
  LConnsFile.SetBounds(Scale96ToScreen(8), Scale96ToScreen(37), LLabelWidth, Scale96ToScreen(18));

  EDriversFile := TEdit.Create(Self);
  EDriversFile.Parent := PTop;
  EDriversFile.ReadOnly := True;
  EDriversFile.Color := clBtnFace;
  EDriversFile.Left := Scale96ToScreen(8) + LLabelWidth;
  EDriversFile.Top := Scale96ToScreen(5);
  EDriversFile.AnchorParallel(akRight, Scale96ToScreen(8), PTop);
  EDriversFile.Anchors := [akLeft, akTop, akRight];

  EConnectionsFile := TEdit.Create(Self);
  EConnectionsFile.Parent := PTop;
  EConnectionsFile.ReadOnly := True;
  EConnectionsFile.Color := clBtnFace;
  EConnectionsFile.Left := EDriversFile.Left;
  EConnectionsFile.Top := Scale96ToScreen(33);
  EConnectionsFile.AnchorParallel(akRight, Scale96ToScreen(8), PTop);
  EConnectionsFile.Anchors := [akLeft, akTop, akRight];

  // Entries of the connections file
  PLeft := TPanel.Create(Self);
  PLeft.Parent := Self;
  PLeft.Align := alLeft;
  PLeft.BevelOuter := bvNone;
  PLeft.Width := Scale96ToScreen(210);

  ToolBar1 := TToolBar.Create(Self);
  ToolBar1.Parent := PLeft;
  ToolBar1.Align := alTop;
  ToolBar1.Images := FImages;
  ToolBar1.ShowHint := True;
  ToolBar1.ButtonWidth := Scale96ToScreen(28);
  ToolBar1.ButtonHeight := Scale96ToScreen(28);
  ToolBar1.Height := Scale96ToScreen(30);
  BAdd := NewToolButton(IMG_NEW, TranslateStr(176, 'Adds a connection to the selected driver'),
    BAddClick);
  BDelete := NewToolButton(IMG_DELETE, TranslateStr(175, 'Drops the selected connection'),
    BDeleteClick);
  NewSeparator;
  BShowProps := NewToolButton(IMG_DATACONFIG, TranslateStr(173,
    'Shows properties of the selected driver'), BShowPropsClick);
  NewSeparator;
  BConnect := NewToolButton(IMG_PREVIEW, TranslateStr(174, 'Activates the selected connection'),
    BConnectClick);
  NewSeparator;
  BClose := NewToolButton(IMG_EXIT, TranslateStr(172, 'Closes this configuration window'),
    BCloseClick);

  PDriver := TPanel.Create(Self);
  PDriver.Parent := PLeft;
  PDriver.Align := alTop;
  PDriver.BevelOuter := bvNone;
  PDriver.Height := Scale96ToScreen(52);
  PDriver.Top := ToolBar1.Top + ToolBar1.Height + 1;

  LShowDriver := TLabel.Create(Self);
  LShowDriver.Parent := PDriver;
  LShowDriver.Caption := TranslateStr(171, 'Show driver connections');
  LShowDriver.SetBounds(Scale96ToScreen(4), Scale96ToScreen(4), Scale96ToScreen(200),
    Scale96ToScreen(18));

  FComboDrivers := TComboBox.Create(Self);
  FComboDrivers.Parent := PDriver;
  FComboDrivers.Style := csDropDownList;
  FComboDrivers.Left := Scale96ToScreen(4);
  FComboDrivers.Top := Scale96ToScreen(22);
  FComboDrivers.AnchorParallel(akRight, Scale96ToScreen(4), PDriver);
  FComboDrivers.Anchors := [akLeft, akTop, akRight];
  FComboDrivers.OnChange := ComboDriversClick;

  FLConnections := TListBox.Create(Self);
  FLConnections.Parent := PLeft;
  FLConnections.Align := alClient;
  FLConnections.OnClick := LConnectionsClick;

  // Parameters of the selected entry
  FScrollParams := TScrollBox.Create(Self);
  FScrollParams.Parent := Self;
  FScrollParams.Align := alClient;
  FScrollParams.Visible := False;
  FScrollParams.HorzScrollBar.Visible := False;

  FHubMenu := TPopupMenu.Create(Self);
end;

procedure TFRpDBXConfigLCL.LoadConfig;
begin
  FreeAndNil(FConAdmin);
  FConAdmin := TRpConnAdmin.Create;
  if FConnectionsFile <> '' then
  begin
    // The file to edit (the VCL dialog only shows it)
    FConAdmin.DBXConnectionsOverride := FConnectionsFile;
    FConAdmin.LoadConfig;
  end;
  FDriversFile := FConAdmin.driverfilename;
  EDriversFile.Text := FDriversFile;
  if FConnectionsFile = '' then
    EConnectionsFile.Text := FConAdmin.configfilename
  else
    EConnectionsFile.Text := FConnectionsFile;
  FConAdmin.GetDriverNames(FComboDrivers.Items);
  FComboDrivers.Items.Insert(0, SRpAllDriver);
  FComboDrivers.ItemIndex := 0;
  ComboDriversClick(Self);
end;

procedure TFRpDBXConfigLCL.SetConnectionsFile(const AValue: string);
begin
  if FConnectionsFile = AValue then
    Exit;
  FConnectionsFile := AValue;
  LoadConfig;
end;

procedure TFRpDBXConfigLCL.ShowInfo(const AText: string);
begin
  FLastMessage := AText;
  Inc(FMessageCount);
  if FInteractive then
    RpShowMessage(AText);
end;

procedure TFRpDBXConfigLCL.ComboDriversClick(Sender: TObject);
var
  drivername: string;
begin
  // Load the connections
  if not Assigned(FConAdmin) then
    Exit;
  drivername := FComboDrivers.Text;
  if (FComboDrivers.ItemIndex <= 0) or (drivername = SRpAllDriver) then
    drivername := '';
  FConAdmin.GetConnectionNames(FLConnections.Items, drivername);
  if FLConnections.Items.Count > 0 then
    FLConnections.ItemIndex := 0
  else
    FLConnections.ItemIndex := -1;
  LConnectionsClick(Self);
end;

procedure TFRpDBXConfigLCL.SelectDriver(const ADriverName: string);
var
  LIndex: Integer;
begin
  if (ADriverName = '') or (ADriverName = SRpAllDriver) then
    LIndex := 0
  else
    LIndex := FComboDrivers.Items.IndexOf(ADriverName);
  if LIndex < 0 then
    raise Exception.Create(SRpSelectDriver + ': ' + ADriverName);
  FComboDrivers.ItemIndex := LIndex;
  ComboDriversClick(Self);
end;

procedure TFRpDBXConfigLCL.SelectConnection(const AName: string);
begin
  FLConnections.ItemIndex := FLConnections.Items.IndexOf(AName);
  LConnectionsClick(Self);
end;

procedure TFRpDBXConfigLCL.FreeParamsControls;
begin
  FHubButton := nil;
  FAgentInfo := nil;
  FAgentLink := nil;
  while FScrollParams.ControlCount > 0 do
    FScrollParams.Controls[0].Free;
end;

procedure TFRpDBXConfigLCL.CreateParamsControls;
var
  i, index, top: Integer;
  label1: TLabel;
  Edit1: TWinControl;
  alist: TStringList;
  LButton: TButton;
  LParamName: string;
begin
  if not Assigned(FConAdmin) then
    Exit;
  FUpdatingParams := True;
  FScrollParams.DisableAutoSizing;
  alist := TStringList.Create;
  try
    FConAdmin.Drivers.ReadSections(alist);
    top := Scale96ToScreen(CONTROL_DISTANCEY);
    FConAdmin.GetConnectionParams(FConnectionName, FParams);
    for i := 0 to FParams.Count - 1 do
    begin
      LParamName := FParams.Names[i];
      label1 := TLabel.Create(Self);
      label1.Parent := FScrollParams;
      label1.Caption := LParamName;
      label1.SetBounds(Scale96ToScreen(CONTROL_DISTANCEX), top + Scale96ToScreen(LABEL_INCY),
        Scale96ToScreen(CONTROL_DISTANCEX2 - CONTROL_DISTANCEX - 4), Scale96ToScreen(18));
      LButton := nil;
      // It can be a combo with different options
      index := alist.IndexOf(LParamName);
      if index < 0 then
      begin
        Edit1 := TEdit.Create(Self);
        Edit1.Parent := FScrollParams;
        TEdit(Edit1).Text := FParams.Values[LParamName];
        if AnsiUpperCase(LParamName) = 'DRIVERNAME' then
        begin
          TEdit(Edit1).ReadOnly := True;
          TEdit(Edit1).Color := clBtnFace;
        end
        else
          TEdit(Edit1).OnChange := Edit1Change;
        if AnsiUpperCase(LParamName) = 'PASSWORD' then
          TEdit(Edit1).PasswordChar := '*';
        // Discovery button for HubDatabaseId
        if AnsiUpperCase(LParamName) = 'HUBDATABASEID' then
        begin
          LButton := TButton.Create(Self);
          LButton.Parent := FScrollParams;
          LButton.Caption := TextHubSelect;
          LButton.Width := RpCaptionWidth(LButton, [TextHubSelect, TextHubLoading], 130);
          LButton.Tag := i;
          LButton.OnClick := BSelectHubConnectionClick;
          FHubButton := LButton;
        end;
      end
      else
      begin
        Edit1 := TComboBox.Create(Self);
        Edit1.Parent := FScrollParams;
        TComboBox(Edit1).Style := csDropDownList;
        FConAdmin.Drivers.ReadSection(alist[index], TComboBox(Edit1).Items);
        TComboBox(Edit1).ItemIndex :=
          TComboBox(Edit1).Items.IndexOf(FParams.Values[LParamName]);
        TComboBox(Edit1).OnChange := Edit1Change;
      end;
      Edit1.Tag := i;
      Edit1.Left := Scale96ToScreen(CONTROL_DISTANCEX2);
      Edit1.Top := top;
      if LButton <> nil then
      begin
        LButton.Top := top;
        LButton.AnchorParallel(akRight, Scale96ToScreen(6), FScrollParams);
        LButton.Anchors := [akTop, akRight];
        Edit1.AnchorToNeighbour(akRight, Scale96ToScreen(6), LButton);
      end
      else
        Edit1.AnchorParallel(akRight, Scale96ToScreen(10), FScrollParams);
      Edit1.Anchors := [akLeft, akTop, akRight];
      if LButton <> nil then
        LButton.Height := Edit1.Height;
      top := top + Edit1.Height + Scale96ToScreen(CONTROL_DISTANCEY);
    end;
    if SameText(FParams.Values['DriverName'], AGENT_DRIVER_NAME) then
      AddAgentInfo(top);
  finally
    alist.Free;
    FScrollParams.EnableAutoSizing;
    FUpdatingParams := False;
  end;
  UpdateHubButton;
end;

procedure TFRpDBXConfigLCL.AddAgentInfo(ATop: Integer);
begin
  FAgentInfo := TLabel.Create(Self);
  FAgentInfo.Parent := FScrollParams;
  FAgentInfo.WordWrap := True;
  FAgentInfo.ShowAccelChar := False;
  FAgentInfo.Caption := TranslateStr(1823, 'The Reportman Agent is installed as a service ' +
    'on a Windows or Linux computer that can reach your database and gives the designer ' +
    'secure access to it through ai.reportman.es.');
  FAgentInfo.Left := Scale96ToScreen(CONTROL_DISTANCEX);
  FAgentInfo.Top := ATop + Scale96ToScreen(8);
  // Both sides anchored: the autosize only sets the height of the lines
  FAgentInfo.AnchorParallel(akRight, Scale96ToScreen(10), FScrollParams);
  FAgentInfo.Anchors := [akLeft, akTop, akRight];

  FAgentLink := TLabel.Create(Self);
  FAgentLink.Parent := FScrollParams;
  FAgentLink.ShowAccelChar := False;
  FAgentLink.Caption := TranslateStr(1822, 'Download Reportman Agent');
  FAgentLink.Cursor := crHandPoint;
  FAgentLink.Font.Color := clBlue;
  FAgentLink.Font.Style := [fsUnderline];
  FAgentLink.OnClick := AgentLinkClick;
  FAgentLink.Left := FAgentInfo.Left;
  FAgentLink.AnchorToNeighbour(akTop, Scale96ToScreen(4), FAgentInfo);
end;

procedure TFRpDBXConfigLCL.AgentLinkClick(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenAgentDownloadPage;
end;

procedure TFRpDBXConfigLCL.LConnectionsClick(Sender: TObject);
begin
  // A running discovery belongs to the previous entry
  Inc(FHubDiscoveryRequestVersion);
  FHubDiscoveryRunning := False;
  if FHubCancel <> nil then
    FHubCancel.Cancel;
  FHubCancel := nil;
  FreeParamsControls;
  if FLConnections.ItemIndex < 0 then
  begin
    FConnectionName := '';
    FParams.Clear;
    // No Agent entry yet: tell where the Agent comes from
    FScrollParams.Visible := (FComboDrivers.ItemIndex > 0) and
      SameText(FComboDrivers.Text, AGENT_DRIVER_NAME);
    if FScrollParams.Visible then
      AddAgentInfo(0);
    Exit;
  end;
  FScrollParams.Visible := True;
  FConnectionName := FLConnections.Items[FLConnections.ItemIndex];
  CreateParamsControls;
end;

function TFRpDBXConfigLCL.ParamEditor(const AParamName: string): TWinControl;
var
  i: Integer;
  LControl: TControl;
begin
  Result := nil;
  for i := 0 to FScrollParams.ControlCount - 1 do
  begin
    LControl := FScrollParams.Controls[i];
    if ((LControl is TEdit) or (LControl is TComboBox)) and
      (LControl.Tag >= 0) and (LControl.Tag < FParams.Count) and
      SameText(FParams.Names[LControl.Tag], AParamName) then
      Exit(TWinControl(LControl));
  end;
end;

function TFRpDBXConfigLCL.GetParamValue(const AParamName: string): string;
var
  LEditor: TWinControl;
begin
  LEditor := ParamEditor(AParamName);
  if LEditor is TEdit then
    Result := TEdit(LEditor).Text
  else if LEditor is TComboBox then
    Result := TComboBox(LEditor).Text
  else
    Result := FParams.Values[AParamName];
end;

procedure TFRpDBXConfigLCL.SetParamValue(const AParamName, AValue: string);
var
  LEditor: TWinControl;
begin
  LEditor := ParamEditor(AParamName);
  if LEditor = nil then
    raise Exception.Create('Unknown parameter ' + AParamName);
  FUpdatingParams := True;
  try
    if LEditor is TEdit then
      TEdit(LEditor).Text := AValue
    else
      TComboBox(LEditor).ItemIndex := TComboBox(LEditor).Items.IndexOf(AValue);
  finally
    FUpdatingParams := False;
  end;
  Edit1Change(LEditor);
end;

procedure TFRpDBXConfigLCL.Edit1Change(Sender: TObject);
var
  paramvalue, paramname, conname: string;
  index: Integer;
begin
  if FUpdatingParams or (not Assigned(FConAdmin)) or (FConnectionName = '') then
    Exit;
  if (TControl(Sender).Tag < 0) or (TControl(Sender).Tag >= FParams.Count) then
    Exit;
  conname := FConnectionName;
  paramname := FParams.Names[TControl(Sender).Tag];
  if Sender is TComboBox then
    paramvalue := TComboBox(Sender).Text
  else
    paramvalue := TEdit(Sender).Text;
  if Length(paramvalue) = 0 then
  begin
    index := FParams.IndexOfName(paramname);
    if index >= 0 then
      FParams.Strings[index] := paramname + '=';
  end
  else
    FParams.Values[paramname] := paramvalue;
  FConAdmin.config.WriteString(conname, paramname, paramvalue);
  FConAdmin.config.UpdateFile;
  if SameText(paramname, 'ApiKey') then
    UpdateHubButton;
end;

function TFRpDBXConfigLCL.AddConnection(const AName: string): Boolean;
var
  newname: string;
begin
  Result := False;
  if not Assigned(FConAdmin) then
    Exit;
  if FComboDrivers.ItemIndex <= 0 then
    raise Exception.Create(SRpSelectDriver);
  newname := UpperCase(Trim(AName));
  if Length(newname) < 1 then
    Exit;
  FConAdmin.AddConnection(newname, FComboDrivers.Text);
  FConAdmin.config.UpdateFile;
  ComboDriversClick(Self);
  SelectConnection(newname);
  Result := True;
end;

procedure TFRpDBXConfigLCL.DropConnection(const AName: string);
begin
  if not Assigned(FConAdmin) then
    Exit;
  FConAdmin.DeleteConnection(AName);
  FConAdmin.config.UpdateFile;
  ComboDriversClick(Self);
end;

procedure TFRpDBXConfigLCL.BAddClick(Sender: TObject);
begin
  if not Assigned(FConAdmin) then
    Exit;
  if FComboDrivers.ItemIndex <= 0 then
    raise Exception.Create(SRpSelectDriver);
  AddConnection(RpInputBox(SRpNewConnection, SRpConnectionName, ''));
end;

procedure TFRpDBXConfigLCL.BDeleteClick(Sender: TObject);
var
  conname: string;
begin
  if not Assigned(FConAdmin) then
    Exit;
  if FLConnections.ItemIndex < 0 then
    Exit;
  conname := FLConnections.Items[FLConnections.ItemIndex];
  if smbOK = RpMessageBox(SRpSureDropConnection + conname, SRpDropConnection,
    [smbOK, smbCancel], smsWarning, smbCancel) then
    DropConnection(conname);
end;

procedure TFRpDBXConfigLCL.BShowPropsClick(Sender: TObject);
var
  VendorLib, LibraryName: string;
begin
  if not Assigned(FConAdmin) then
    Exit;
  if FComboDrivers.ItemIndex <= 0 then
    raise Exception.Create(SRpSelectDriver);
  // No FireDAC connection editor in the FPC build: the library names for all
  FConAdmin.GetDriverLibNames(FComboDrivers.Text, LibraryName, VendorLib);
  ShowInfo(SRpVendorLib + ':' + VendorLib + LineEnding + SRpLibraryName + ':' + LibraryName);
end;

procedure TFRpDBXConfigLCL.StartConnectionTest;
var
  conname, drivername: string;
  alist: TStringList;
  report: TRpReport;
  dbinfo: TRpDatabaseInfoItem;
  LWorker: TRpConnectionTestWorker;
begin
  if not Assigned(FConAdmin) then
    Exit;
  if FLConnections.ItemIndex < 0 then
    raise Exception.Create(SRpSelectConnectionFirst);
  if FTestRunning then
    Exit;
  conname := FLConnections.Items[FLConnections.ItemIndex];
  LWorker := TRpConnectionTestWorker.Create(FMailboxRef);
  try
    alist := TStringList.Create;
    try
      FConAdmin.GetConnectionParams(conname, alist);
      drivername := Trim(alist.Values['DriverName']);
      if SameText(drivername, AGENT_DRIVER_NAME) then
      begin
        LWorker.HttpParams := alist;
        alist := nil;
        LWorker.Token := TRpAuthManager.Instance.Token;
      end;
    finally
      alist.Free;
    end;
    if LWorker.HttpParams = nil then
    begin
      report := TRpReport.Create(nil);
      LWorker.Report := report;
      if Length(Trim(EConnectionsFile.Text)) > 0 then
        report.Params.Add('DBXCONNECTIONS').AsString := Trim(EConnectionsFile.Text);
      if Length(Trim(FDriversFile)) > 0 then
        report.Params.Add('DBXDRIVERS').AsString := Trim(FDriversFile);
      dbinfo := report.DatabaseInfo.Add(conname);
      dbinfo.Driver := ResolveFpcConnectionDriver(drivername, rpdatazeos);
      dbinfo.LoginPrompt := False;
    end;
  except
    LWorker.Free;
    raise;
  end;
  Inc(FTestRequestVersion);
  LWorker.RequestVersion := FTestRequestVersion;
  FTestRunning := True;
  BConnect.Enabled := False;
  LWorker.Start;
end;

procedure TFRpDBXConfigLCL.BConnectClick(Sender: TObject);
begin
  StartConnectionTest;
end;

procedure TFRpDBXConfigLCL.SaveConfig;
begin
  if Assigned(FConAdmin) then
    FConAdmin.Config.UpdateFile;
end;

procedure TFRpDBXConfigLCL.DoClose(var CloseAction: TCloseAction);
begin
  inherited DoClose(CloseAction);
  try
    SaveConfig;
  except
    on E: Exception do
      ShowInfo(E.Message);
  end;
end;

procedure TFRpDBXConfigLCL.BCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFRpDBXConfigLCL.UpdateHubButton;
begin
  if FHubButton = nil then
    Exit;
  if FHubDiscoveryRunning then
  begin
    FHubButton.Enabled := False;
    FHubButton.Caption := TextHubLoading;
  end
  else
  begin
    FHubButton.Enabled := True;
    FHubButton.Caption := TextHubSelect;
  end;
end;

procedure TFRpDBXConfigLCL.StartHubDiscovery;
var
  LApiKey: string;
  LWorker: TRpHubDiscoveryWorker;
begin
  LApiKey := Trim(GetParamValue('ApiKey'));
  if Length(LApiKey) < 5 then
  begin
    ShowInfo(TranslateStr(1673, 'Please enter a valid API Key first.'));
    Exit;
  end;
  Inc(FHubDiscoveryRequestVersion);
  if FHubCancel <> nil then
    FHubCancel.Cancel;
  FHubCancel := TRpAsyncCancel.Create;
  FHubDiscoveryRunning := True;
  UpdateHubButton;
  LWorker := TRpHubDiscoveryWorker.Create(FMailboxRef);
  LWorker.RequestVersion := FHubDiscoveryRequestVersion;
  LWorker.ApiKey := LApiKey;
  LWorker.Cancel := FHubCancel;
  LWorker.Start;
end;

procedure TFRpDBXConfigLCL.BSelectHubConnectionClick(Sender: TObject);
begin
  StartHubDiscovery;
end;

procedure TFRpDBXConfigLCL.HubConnectionMenuItemClick(Sender: TObject);
var
  LEditor: TWinControl;
begin
  LEditor := ParamEditor('HubDatabaseId');
  if LEditor = nil then
    Exit;
  // The id is in the Hint: Tag is 32 bits on 32 bit targets
  SetParamValue('HubDatabaseId', IntToStr(StrToInt64Def(TMenuItem(Sender).Hint, 0)));
end;

procedure TFRpDBXConfigLCL.HandleAsyncMessage(AMessage: TRpAsyncMessage);
var
  LDiscovery: TRpHubDiscoveryResult;
  LTest: TRpConnectionTestResult;
  LItem: TMenuItem;
  LPoint: TPoint;
  i: Integer;
begin
  if AMessage is TRpHubDiscoveryResult then
  begin
    // VCL WMHubDiscoveryComplete
    LDiscovery := TRpHubDiscoveryResult(AMessage);
    if LDiscovery.RequestVersion <> FHubDiscoveryRequestVersion then
      Exit;
    FHubDiscoveryRunning := False;
    FHubCancel := nil;
    UpdateHubButton;
    FHubMenu.Items.Clear;
    if LDiscovery.ErrorMessage <> '' then
    begin
      ShowInfo(LDiscovery.ErrorMessage);
      Exit;
    end;
    if LDiscovery.Databases.Count = 0 then
    begin
      ShowInfo(TranslateStr(1675, 'No databases found for this API Key.'));
      Exit;
    end;
    for i := 0 to LDiscovery.Databases.Count - 1 do
    begin
      LItem := TMenuItem.Create(FHubMenu);
      LItem.Caption := LDiscovery.Databases.Names[i];
      LItem.Hint := LDiscovery.Databases.ValueFromIndex[i];
      LItem.OnClick := HubConnectionMenuItemClick;
      FHubMenu.Items.Add(LItem);
    end;
    if FInteractive and (FHubButton <> nil) and FHubButton.HandleAllocated then
    begin
      LPoint := FHubButton.ClientToScreen(Point(0, FHubButton.Height));
      FHubMenu.PopUp(LPoint.X, LPoint.Y);
    end;
  end
  else if AMessage is TRpConnectionTestResult then
  begin
    LTest := TRpConnectionTestResult(AMessage);
    if LTest.RequestVersion <> FTestRequestVersion then
      Exit;
    FTestRunning := False;
    BConnect.Enabled := True;
    ShowInfo(LTest.MessageText);
  end;
end;

end.

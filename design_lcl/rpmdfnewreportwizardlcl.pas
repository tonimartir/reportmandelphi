{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfnewreportwizardlcl                         }
{       New report wizard with data connection and AI   }
{       prompt (LCL port of rpmdfnewreportwizardvcl)    }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfnewreportwizardlcl;

{ File > New of the designer, as TFRpNewReportWizardVCL: the connection route
  (Reportman AI Agent, direct database or no connection), the Agent API key
  and distributed connection, the driver family and driver, an existing or
  new connection of dbxconnections with its parameters and tests, the
  schema for the AI and the prompt for the design assistant. The result is
  the same: the report with its connection, and the prompt, Hub database,
  schema and API key (or the local subschema) that the designer gives to the
  design chat.

  The schema for the AI (docs/esquemas-locales-pantalla-plan.md 5.7.1 B) is
  the list of the copilot, after the connection: the subschemas of the local
  schema file of a direct connection (generated from the catalog the first
  time) and the schemas in the cloud (on the Agent route, the ones of its
  Hub database), with "New local schema..." and "New cloud schema...".
  Choosing one is optional; a prompt without one asks to go on without the
  AI. Routes: direct = route, driver, connection (and parameters), schema,
  finish; Agent = route, connection (and API key), schema, finish.

  Differences with the VCL form:
  - The Hub and connection tests run in worker threads (TRpAsyncWorker) and
    their results come back through a TRpAsyncMailbox; the navigation waits
    while one runs. The VCL runs them in the main thread.
  - Driver families: the ones of the FPC engine. FireDAC is the SQLite
    driver of the FPC engine (SQLdb) and Zeos keeps its protocols;
    dbExpress, BDE and Microsoft DAO (ADO) are not in the FPC engine, so
    their choices and the ADO connection string page are not shown. The
    connections go through rpdbxadminlcl (the FPC part of rpwebdbxadmin).
  - A new Zeos connection is a ZeosLib connection with the chosen protocol
    (the VCL creates an Interbase dbExpress connection and drops the
    protocol).
  - Going back keeps the connection this wizard created (the VCL refuses its
    name then), and the Hub databases combo shows their names (the VCL, the
    name=id lines).
  - The captions are translatable (TranslateStr) and the pages chain their
    controls with anchors, so they fit small screens and long translations. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  Generics.Collections,
  rpreport, rpdatainfo, rpmdconsts, rpgraphutilslcl, rpaithreadslcl,
  rpfrmaischemaselectorlcl, rpdbxadminlcl;

type
  TRpWizardRoute = (wrUndefined, wrAgent, wrDirect, wrNoConnection);
  // dfDbExpress only classifies the connections of other drivers
  TRpWizardDriverFamily = (dfUndefined, dfFireDac, dfZeos, dfDbExpress);
  TRpWizardConnMode = (cnUndefined, cnExisting, cnNew);

  // wpAgentSchema and wpDirectSchema are the same page (the schema for the
  // AI) at the end of each route
  TRpWizardPage = (
    wpRoute,
    wpAgentLogin,
    wpAgentSchema,
    wpDirectSchema,
    wpDriver,
    wpConnName,
    wpParams,
    wpFinish
  );

  // Work of the wizard running in a worker thread
  TRpWizardOperation = (
    woNone,
    woHubLogin,          // Hub databases of the API key
    woAgentConnection,   // test of a new Reportman AI connection
    woTestExisting,      // Test Connection of an existing connection
    woTestParams         // Test Connection of the parameters page
  );

  TRpWizardState = record
    Route: TRpWizardRoute;
    HubApiKey: string;
    HubLoggedIn: Boolean;
    HubDatabaseId: Int64;
    HubDatabaseName: string;
    HubSchemaId: Int64;
    HubSchemaName: string;
    // The subschema of the local schema file of the direct connection
    LocalSchemaName: string;
    DriverFamily: TRpWizardDriverFamily;
    DriverConcrete: string;     // FireDAC DriverID or Zeos protocol
    ConnMode: TRpWizardConnMode;
    ConnName: string;
  end;

  { TFRpNewReportWizardLCL }

  TFRpNewReportWizardLCL = class(TForm)
  private
    FState: TRpWizardState;
    FCurrentPage: TRpWizardPage;
    FHistory: TList<TRpWizardPage>;
    FCommitted: Boolean;
    FPendingPrompt: string;
    FAdmin: TRpDbxAdminLCL;
    FDestReport: TRpReport;
    FMailbox: TRpAsyncMailbox;
    FMailboxRef: IRpAsyncMailbox;
    FOperation: TRpWizardOperation;
    FOperationVersion: Integer;
    // The last control stacked in the page
    FLastStacked: TControl;
    // Hub databases of the API key (display name=HubDatabaseId)
    FHubDatabases: TStringList;
    // Families of the items of the family combo
    FFamilies: array of TRpWizardDriverFamily;
    // The connection this wizard created (it can go back and keep it)
    FCreatedConnection: string;
    FCreatedConnectionDriver: string;
    FParamsList: TList<TRpDbxConnectionParam>;
    FParamEditors: TList<TWinControl>;
    // Connection wizard (StartConnectionMode): only the connection pages
    FConnectionMode: Boolean;
    FFixedName: string;
    FPreferredHubDatabaseId: Int64;
    FResultConnection: string;
    FResultDriver: TRpDbDriver;
    // The Hub databases load of the API key page on entering it: without
    // the "Logged in" message
    FQuietHubLoad: Boolean;

    procedure BuildControls;
    procedure HandleAsyncMessage(AMessage: TRpAsyncMessage);
    procedure ClearPanel;
    procedure GoTo_Page(APage: TRpWizardPage; APushHistory: Boolean);
    function NextPageFor(APage: TRpWizardPage): TRpWizardPage;
    procedure UpdateHeader(APage: TRpWizardPage);
    procedure UpdateNavButtons;
    procedure UpdatePageButtons;

    // Stacked page controls
    function Px(AValue: Integer): Integer;
    function ButtonWidth(const ACaptions: array of string): Integer;
    procedure StackControl(AControl: TControl; AIndent, AGap: Integer;
      AFullWidth: Boolean);
    function NewLabel(const ACaption: string; AIndent, AGap: Integer;
      ABold: Boolean = False): TLabel;
    function NewHyperlinkLabel(const ACaption: string; AGap: Integer;
      AClick: TNotifyEvent): TLabel;
    function NewRadio(const ACaption: string; AIndent, AGap: Integer): TRadioButton;
    function NewRow(AIndent, AGap: Integer): TPanel;
    function NewRowButton(ARow: TPanel; const ACaptions: array of string;
      AClick: TNotifyEvent): TButton;
    function NewRowEdit(ARow: TPanel): TEdit;
    function NewRowCombo(ARow: TPanel; AStyle: TComboBoxStyle): TComboBox;

    // Page builders
    procedure BuildPageRoute;
    procedure BuildPageAgentLogin;
    // The schema for the AI (wpAgentSchema, wpDirectSchema)
    procedure BuildPageSchema;
    procedure BuildPageDriver;
    procedure BuildPageConnName;
    procedure BuildPageParams;
    procedure BuildPageFinish;

    function ValidateAndAdvance: Boolean;

    // Helpers
    procedure DoHubLogin(Sender: TObject);
    procedure DoHubRefresh(Sender: TObject);
    procedure DoTestExistingConn(Sender: TObject);
    procedure DoFamilyChange(Sender: TObject);
    procedure DoConnNameModeChange(Sender: TObject);
    procedure DoExistingConnChange(Sender: TObject);
    procedure DoParamsTest(Sender: TObject);
    procedure DoRouteChange(Sender: TObject);
    procedure DoSchemasLoaded(Sender: TObject);
    // "New local schema...": the local schema screen of the connection
    procedure DoNewLocalSchema(Sender: TObject);
    procedure OpenAgentDownloadLink(Sender: TObject);
    // The subschemas of the direct connection in the list of the schema
    // page (the schema file is generated the first time)
    procedure LoadLocalSchemas;

    // AQuiet: without the "Logged in" message (entering the page)
    procedure LoadHubDatabases(AQuiet: Boolean = False);
    procedure ApplyHubDatabases(AOk: Boolean; ADatabases: TStrings);
    // A Reportman AI session: the API key of an Agent connection is optional
    function HasHubSession: Boolean;
    procedure FillHubDatabaseCombo;
    procedure RefreshConcreteDriver;
    procedure RefreshExistingConnections;
    procedure UpdateExistingConnDriverHint;
    procedure LoadParamsFromAdminService;
    procedure CommitParamsFromEditors(AValues: TStrings);

    procedure BeginOperation(AOperation: TRpWizardOperation; const AStatus: string);
    procedure EndOperation;
    procedure StartConnectionTest(AOperation: TRpWizardOperation;
      const AConnectionName: string; AValues: TStrings);
    procedure AgentConnectionTested(ASuccess: Boolean; const AMessage: string);
    procedure ExistingConnectionTested(ASuccess: Boolean; const AMessage: string);
    procedure ParamsTested(ASuccess: Boolean; const AMessage: string);

    function FamilyDriverName: string;
    function FamilyAcceptsParamStep: Boolean;
    function HasReportmanAiSchema: Boolean;
    function ConnectionExists(const AConnectionName: string): Boolean;
    // The connection created by this wizard run
    function IsWizardConnection(const AConnectionName: string): Boolean;
    procedure PrepareWizardConnection(const AConnectionName, ADriverName,
      AProtocol: string);
    function TryGetConnectionDetails(const AConnectionName: string;
      out AFamily: TRpWizardDriverFamily; out ADriverHint: string;
      out AHubDatabaseId, AHubSchemaId: Int64; out AApiKey: string): Boolean;
    procedure CommitConnectionToReport;
    function IsImmediateFinishRouteSelected: Boolean;
    procedure FinishWizard;
    // Connection mode: the page that ends the wizard, and its end
    function IsLastConnectionStep: Boolean;
    procedure FinishConnection;
  public
    // Frame
    PHeader: TPanel;
    LStepTitle: TLabel;
    LStepHelper: TLabel;
    PBottom: TPanel;
    LStatus: TLabel;
    BCancel: TButton;
    BBack: TButton;
    BNext: TButton;
    BFinish: TButton;
    PContent: TPanel;
    // Controls of the current page (nil on the others)
    RbAgent, RbDirect, RbNoConnection: TRadioButton;
    LnkAgentDownload: TLabel;
    EdHubApiKey: TEdit;
    BtnHubLogin: TButton;
    // Under the API key: optional with a session, required without one
    LblHubKeyNote: TLabel;
    BtnHubRefresh: TButton;
    CbHubDatabase: TComboBox;
    // Why the subschemas of the direct connection could not be read
    LblLocalSchemaError: TLabel;
    CbFamily: TComboBox;
    CbConcrete: TComboBox;
    LblConcrete: TLabel;
    RbExisting, RbNew: TRadioButton;
    CbExistingConn: TComboBox;
    LblExistingConnDriver: TLabel;
    EdNewConnName: TEdit;
    BtnTestExisting: TButton;
    ParamsScroll: TScrollBox;
    BtnParamsTest: TButton;
    LblParamsCaption: TLabel;
    MemoFinishPrompt: TMemo;
    AISchemaSelector: TFRpAISchemaSelectorLCL;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // The navigation buttons (public for the tests)
    procedure BCancelClick(Sender: TObject);
    procedure BBackClick(Sender: TObject);
    procedure BNextClick(Sender: TObject);
    procedure BFinishClick(Sender: TObject);
    // The editor of a parameter of the parameters page (nil elsewhere)
    function ParamEditor(const AName: string): TWinControl;
    // Turns the wizard into the connection wizard (before showing it): the
    // connection pages without the schema and the prompt; the report is not
    // changed (ResultConnection and ResultDriver add the connection).
    // AFixedName configures the Reportman AI Agent connection with that name
    // (a connection of a report not configured on this computer);
    // APreferredHubDatabaseId is selected when the API key lists it.
    procedure StartConnectionMode(const AFixedName: string;
      APreferredHubDatabaseId: Int64);

    // The report that receives the connection
    property DestReport: TRpReport read FDestReport write FDestReport;
    property CurrentPage: TRpWizardPage read FCurrentPage;
    // Work running in a worker thread (navigation disabled)
    property Operation: TRpWizardOperation read FOperation;
    property Committed: Boolean read FCommitted;
    property PendingPrompt: string read FPendingPrompt;
    property State: TRpWizardState read FState;
    property HubDatabases: TStringList read FHubDatabases;
    property ConnectionMode: Boolean read FConnectionMode;
    // Connection mode, after finishing: the connection and its driver
    property ResultConnection: string read FResultConnection;
    property ResultDriver: TRpDbDriver read FResultDriver;
  end;

// The new report of NewModernReportWizard: one subreport with a TOTAL group
procedure RpPrepareModernNewReport(AReport: TRpReport);

// File > New of the designer (rpmdfnewreportwizardvcl). True when the user
// finished the wizard: the report has the chosen connection, and the prompt
// and Hub context are for the design chat; ALocalAlias and ALocalSchemaName
// are the subschema of the direct connection chosen ('' = none), which the
// chat selects before the prompt
function NewModernReportWizard(report: TRpReport;
  out APendingPrompt: string;
  out AHubDatabaseId: Int64;
  out AHubSchemaId: Int64;
  out AHubApiKey: string;
  out ALocalAlias: string;
  out ALocalSchemaName: string): Boolean;

// The connection wizard (Data configuration > Add connection, a connection
// of a report not configured on this computer), see StartConnectionMode.
// True when the user finished it: the connection is in the connections file.
function ShowConnectionWizard(const AFixedName: string;
  APreferredHubDatabaseId: Int64; out AConnectionName: string;
  out ADriver: TRpDbDriver): Boolean;

type
  TRpShowConnectionWizardFunc = function(const AFixedName: string;
    APreferredHubDatabaseId: Int64; out AConnectionName: string;
    out ADriver: TRpDbDriver): Boolean;
  // The Hub database of a Reportman AI schema when the designer knows it
  // (the schemas of the design chat), 0 otherwise
  TRpHubDatabaseOfSchema = function(AHubSchemaId: Int64): Int64 of object;

var
  // The connection wizard of RpCheckAgentConnections (the tests replace it)
  RpConnectionWizardFunc: TRpShowConnectionWizardFunc = nil;

// Before opening the data (preview, Show data): each Reportman AI Agent
// connection of the datasets (the ones opened on start, or AOnlyDataset) that
// can not be opened on this computer is offered to the connection wizard,
// with the Hub database of the schema of its datasets. False when the user
// did not configure one: the data would not open.
function RpCheckAgentConnections(ADatabases: TRpDatabaseInfoList;
  ADataInfo: TRpDataInfoList; AOnlyDataset: TRpDataInfoItem = nil;
  AHubDatabaseOfSchema: TRpHubDatabaseOfSchema = nil): Boolean;

implementation

uses
  rpauthmanager, rpdatahttp, rpjsonfpc, rplcllayout, rpsqldbconnfpc,
  rplocalschemas, rpfrmlocalschemaslcl;

const
  SExamplePrompt = 'Sales by customer with a group total and a grand total';
  SAgentDriverHint = 'Reportman AI Agent';
  SSqliteDriverId = 'SQLite';

type
  { The Hub databases of an API key (LoadHubDatabases of the VCL) }

  TRpWizardHubPayload = class(TRpAsyncMessage)
  public
    Version: Integer;
    Ok: Boolean;
    Databases: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TRpWizardHubWorker = class(TRpAsyncWorker)
  public
    Version: Integer;
    ApiKey: string;
    Token: string;
    InstallId: string;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

  { A connection test (TestConnection / TestConnectionValues of the VCL) }

  TRpWizardTestPayload = class(TRpAsyncMessage)
  public
    Version: Integer;
    Success: Boolean;
    MessageText: string;
  end;

  TRpWizardTestWorker = class(TRpAsyncWorker)
  public
    Version: Integer;
    ConnectionName: string;
    Params: TStringList;
    Token: string;
    constructor Create(const AMailbox: IRpAsyncMailbox);
    destructor Destroy; override;
  protected
    procedure Run; override;
    procedure HandleError(E: Exception); override;
  end;

function TR(AId: Integer; const ADefault: string): string;
begin
  Result := string(TranslateStr(AId, WideString(ADefault)));
end;

procedure ShowInfo(const AText: string);
begin
  RpMessageBox(WideString(AText), WideString(TR(1131, 'New Report')), [smbOK],
    smsInformation, smbOK, smbOK);
end;

procedure ShowCritical(const AText: string);
begin
  RpMessageBox(WideString(AText), WideString(TR(1131, 'New Report')), [smbOK],
    smsCritical, smbOK, smbOK);
end;

{ TRpWizardHubPayload }

constructor TRpWizardHubPayload.Create;
begin
  inherited Create;
  Databases := TStringList.Create;
end;

destructor TRpWizardHubPayload.Destroy;
begin
  Databases.Free;
  inherited Destroy;
end;

{ TRpWizardHubWorker }

procedure TRpWizardHubWorker.Run;
var
  LHttp: TRpDatabaseHttp;
  LStream: TStringStream;
  LValue: TJSONValue;
  LDatabases: TJSONArray;
  LItem: TJSONObject;
  LName, LId: string;
  LPayload: TRpWizardHubPayload;
  I: Integer;
begin
  // TRpDatabaseHttp.GetHubDatabases with the session copied in the main
  // thread: GET api/agent/databases with the API key, "name=hubDatabaseId"
  LPayload := TRpWizardHubPayload.Create;
  try
    LPayload.Version := Version;
    LHttp := TRpDatabaseHttp.Create;
    LStream := TStringStream.Create('');
    try
      LHttp.ApiKey := ApiKey;
      LHttp.Token := Token;
      LHttp.InstallId := InstallId;
      try
        if LHttp.InternalGetRequest('api/agent/databases', LStream) then
        begin
          LValue := TJSONObject.ParseJSONValue(LStream.DataString);
          try
            if (LValue is TJSONObject) and
              (TJSONObject(LValue).Values['databases'] is TJSONArray) then
            begin
              LDatabases := TJSONArray(TJSONObject(LValue).Values['databases']);
              for I := 0 to LDatabases.Count - 1 do
              begin
                if not (LDatabases.Items[I] is TJSONObject) then
                  Continue;
                LItem := TJSONObject(LDatabases.Items[I]);
                LName := '';
                if LItem.Values['displayName'] <> nil then
                  LName := LItem.Values['displayName'].Value;
                if (LName = '') and (LItem.Values['name'] <> nil) then
                  LName := LItem.Values['name'].Value;
                LId := '';
                if LItem.Values['hubDatabaseId'] <> nil then
                  LId := LItem.Values['hubDatabaseId'].Value;
                LPayload.Databases.Add(LName + '=' + LId);
              end;
              LPayload.Ok := True;
            end;
          finally
            LValue.Free;
          end;
        end;
      except
        // Connection errors: not logged in (as GetHubDatabases)
        LPayload.Ok := False;
        LPayload.Databases.Clear;
      end;
    finally
      LStream.Free;
      LHttp.Free;
    end;
    Post(LPayload);
    LPayload := nil;
  finally
    LPayload.Free;
  end;
end;

procedure TRpWizardHubWorker.HandleError(E: Exception);
var
  LPayload: TRpWizardHubPayload;
begin
  LPayload := TRpWizardHubPayload.Create;
  LPayload.Version := Version;
  Post(LPayload);
end;

{ TRpWizardTestWorker }

constructor TRpWizardTestWorker.Create(const AMailbox: IRpAsyncMailbox);
begin
  inherited Create(AMailbox);
  Params := TStringList.Create;
end;

destructor TRpWizardTestWorker.Destroy;
begin
  Params.Free;
  inherited Destroy;
end;

procedure TRpWizardTestWorker.Run;
var
  LResult: TRpDbxConnectionTestResult;
  LPayload: TRpWizardTestPayload;
begin
  LResult := RpExecuteConnectionTest(ConnectionName, Params, Token);
  LPayload := TRpWizardTestPayload.Create;
  LPayload.Version := Version;
  LPayload.Success := LResult.Success;
  LPayload.MessageText := LResult.MessageText;
  Post(LPayload);
end;

procedure TRpWizardTestWorker.HandleError(E: Exception);
var
  LPayload: TRpWizardTestPayload;
begin
  LPayload := TRpWizardTestPayload.Create;
  LPayload.Version := Version;
  LPayload.MessageText := E.Message;
  Post(LPayload);
end;

{ NewModernReportWizard }

procedure RpPrepareModernNewReport(AReport: TRpReport);
var
  I: Integer;
begin
  AReport.CreateNew;
  AReport.SubReports[0].SubReport.AddGroup('TOTAL');
  for I := 0 to AReport.SubReports[0].SubReport.Sections.Count - 1 do
    AReport.SubReports[0].SubReport.Sections[I].Section.Height := 275;
end;

function NewModernReportWizard(report: TRpReport;
  out APendingPrompt: string;
  out AHubDatabaseId: Int64;
  out AHubSchemaId: Int64;
  out AHubApiKey: string;
  out ALocalAlias: string;
  out ALocalSchemaName: string): Boolean;
var
  dia: TFRpNewReportWizardLCL;
begin
  APendingPrompt := '';
  AHubDatabaseId := 0;
  AHubSchemaId := 0;
  AHubApiKey := '';
  ALocalAlias := '';
  ALocalSchemaName := '';
  dia := TFRpNewReportWizardLCL.Create(Application);
  try
    RpPrepareModernNewReport(report);
    dia.DestReport := report;
    dia.ShowModal;
    Result := dia.Committed;
    if Result then
    begin
      APendingPrompt := Trim(dia.PendingPrompt);
      AHubDatabaseId := dia.State.HubDatabaseId;
      AHubSchemaId := dia.State.HubSchemaId;
      AHubApiKey := dia.State.HubApiKey;
      // The subschema of the direct connection of the report
      if (dia.State.LocalSchemaName <> '') and (report.DatabaseInfo.Count > 0) then
      begin
        ALocalAlias := report.DatabaseInfo.Items[0].Alias;
        ALocalSchemaName := dia.State.LocalSchemaName;
      end;
      if report.DataInfo.Count > 0 then
        report.SubReports[0].SubReport.Alias := report.DataInfo.Items[0].Alias;
    end;
  finally
    dia.Free;
  end;
end;

function ShowConnectionWizard(const AFixedName: string;
  APreferredHubDatabaseId: Int64; out AConnectionName: string;
  out ADriver: TRpDbDriver): Boolean;
var
  dia: TFRpNewReportWizardLCL;
begin
  AConnectionName := '';
  ADriver := rpdbHttp;
  dia := TFRpNewReportWizardLCL.Create(Application);
  try
    dia.StartConnectionMode(AFixedName, APreferredHubDatabaseId);
    dia.ShowModal;
    Result := dia.Committed;
    if Result then
    begin
      AConnectionName := dia.ResultConnection;
      ADriver := dia.ResultDriver;
    end;
  finally
    dia.Free;
  end;
end;

function RpCheckAgentConnections(ADatabases: TRpDatabaseInfoList;
  ADataInfo: TRpDataInfoList; AOnlyDataset: TRpDataInfoItem;
  AHubDatabaseOfSchema: TRpHubDatabaseOfSchema): Boolean;
var
  I, J, LIndex: Integer;
  LData: TRpDataInfoItem;
  LDatabase: TRpDatabaseInfoItem;
  LMessage, LName: string;
  LDriver: TRpDbDriver;
  LPreferred: Int64;
  LChecked: TStringList;
begin
  Result := True;
  LChecked := TStringList.Create;
  try
    for I := 0 to ADataInfo.Count - 1 do
    begin
      LData := ADataInfo.Items[I];
      if AOnlyDataset <> nil then
      begin
        if LData <> AOnlyDataset then
          Continue;
      end
      else if not LData.OpenOnStart then
        Continue;
      LIndex := ADatabases.IndexOf(LData.DatabaseAlias);
      if (LIndex < 0) or (LChecked.IndexOf(LData.DatabaseAlias) >= 0) then
        Continue;
      LChecked.Add(LData.DatabaseAlias);
      LDatabase := ADatabases.Items[LIndex];
      if not RpAgentConnectionProblem(LDatabase, LMessage) then
        Continue;
      if RpMessageBox(WideString(LMessage + LineEnding + LineEnding +
        TR(1830, 'Configure the connection now?')), WideString(TR(1778, 'Reportman AI')),
        [smbYes, smbNo], smsWarning, smbYes, smbNo) <> smbYes then
        Exit(False);
      // The Hub database of the schema of a dataset of this connection
      LPreferred := 0;
      if Assigned(AHubDatabaseOfSchema) then
        for J := 0 to ADataInfo.Count - 1 do
          if SameText(ADataInfo.Items[J].DatabaseAlias, LDatabase.Alias) and
            (ADataInfo.Items[J].HubSchemaId > 0) then
          begin
            LPreferred := AHubDatabaseOfSchema(ADataInfo.Items[J].HubSchemaId);
            if LPreferred > 0 then
              Break;
          end;
      if not RpConnectionWizardFunc(LDatabase.Alias, LPreferred, LName, LDriver) then
        Exit(False);
      // The next Connect reads the new settings
      LDatabase.UpdateConAdmin;
      LDatabase.DisConnect;
    end;
  finally
    LChecked.Free;
  end;
end;

{ TFRpNewReportWizardLCL }

constructor TFRpNewReportWizardLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  Caption := TR(1131, 'New Report');
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  // 720x540 in the VCL: smaller so that it fits an 800x600 screen
  ClientWidth := Px(700);
  ClientHeight := Px(500);
  if Width > Screen.WorkAreaWidth then
    Width := Screen.WorkAreaWidth;
  if Height > Screen.WorkAreaHeight then
    Height := Screen.WorkAreaHeight;

  FHistory := TList<TRpWizardPage>.Create;
  FParamsList := TList<TRpDbxConnectionParam>.Create;
  FParamEditors := TList<TWinControl>.Create;
  FHubDatabases := TStringList.Create;
  FAdmin := TRpDbxAdminLCL.Create;
  FMailbox := TRpAsyncMailbox.Create(HandleAsyncMessage);
  FMailboxRef := FMailbox;
  FState.Route := wrUndefined;
  FState.DriverFamily := dfUndefined;
  FState.ConnMode := cnUndefined;
  FCommitted := False;
  BuildControls;
  GoTo_Page(wpRoute, False);
end;

destructor TFRpNewReportWizardLCL.Destroy;
begin
  // A test or a Hub request still running drops its result
  if Assigned(FMailbox) then
    FMailbox.Detach;
  FMailboxRef := nil;
  FMailbox := nil;
  if Assigned(PContent) then
    ClearPanel;
  RpFreeConnectionParams(FParamsList);
  FParamsList.Free;
  FParamEditors.Free;
  FHistory.Free;
  FHubDatabases.Free;
  FAdmin.Free;
  inherited Destroy;
end;

function TFRpNewReportWizardLCL.Px(AValue: Integer): Integer;
begin
  Result := Scale96ToScreen(AValue);
end;

procedure TFRpNewReportWizardLCL.StartConnectionMode(const AFixedName: string;
  APreferredHubDatabaseId: Int64);
var
  LFamily: TRpWizardDriverFamily;
  LDriverHint, LApiKey: string;
  LHubDatabaseId, LHubSchemaId: Int64;
begin
  FConnectionMode := True;
  FFixedName := Trim(AFixedName);
  FPreferredHubDatabaseId := APreferredHubDatabaseId;
  FHistory.Clear;
  if FFixedName <> '' then
  begin
    // A Reportman AI Agent connection of the report: its API key and Hub
    // database, under the same name
    Caption := Format(TR(1827, 'Configure the connection "%s"'), [FFixedName]);
    FState.Route := wrAgent;
    FState.ConnMode := cnNew;
    FState.ConnName := FFixedName;
    // The API key it may already have in the connections file is kept
    if ConnectionExists(FFixedName) and TryGetConnectionDetails(FFixedName,
      LFamily, LDriverHint, LHubDatabaseId, LHubSchemaId, LApiKey) then
      FState.HubApiKey := LApiKey;
    GoTo_Page(wpAgentLogin, False);
  end
  else
  begin
    Caption := TR(1826, 'Add connection');
    GoTo_Page(wpRoute, False);
  end;
end;

function TFRpNewReportWizardLCL.IsLastConnectionStep: Boolean;
begin
  Result := False;
  if not FConnectionMode then
    Exit;
  case FCurrentPage of
    wpAgentLogin, wpParams:
      Result := True;
    wpConnName:
      // An existing connection is added as it is
      Result := (Assigned(RbExisting) and RbExisting.Checked) or
        ((FState.Route = wrDirect) and not FamilyAcceptsParamStep);
  end;
end;

procedure TFRpNewReportWizardLCL.FinishConnection;
begin
  FResultConnection := FState.ConnName;
  if FState.Route = wrAgent then
    FResultDriver := rpdbHttp
  else if FState.DriverFamily = dfZeos then
    FResultDriver := rpdatazeos
  else
    FResultDriver := rpfiredac;
  FCommitted := True;
  if fsModal in FormState then
    ModalResult := mrOk
  else
    Close;
end;

// The width of the longest caption: AutoSize buttons aligned to the sides
// fight the alignment when they do not fit (narrow window, small screen)
// and the LCL raises "InvalidatePreferredSize loop detected"
function TFRpNewReportWizardLCL.ButtonWidth(const ACaptions: array of string): Integer;
var
  LBitmap: TBitmap;
  I: Integer;
begin
  Result := Px(90);
  LBitmap := TBitmap.Create;
  try
    LBitmap.Canvas.Font := Font;
    for I := 0 to High(ACaptions) do
      if LBitmap.Canvas.TextWidth(ACaptions[I]) + Px(24) > Result then
        Result := LBitmap.Canvas.TextWidth(ACaptions[I]) + Px(24);
  finally
    LBitmap.Free;
  end;
end;

procedure TFRpNewReportWizardLCL.BuildControls;

  function NavButton(const ACaptions: array of string; ALeft: Integer;
    AAlign: TAlign; AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := PBottom;
    Result.Caption := ACaptions[0];
    // alRight controls are ordered by Left
    Result.SetBounds(ALeft, 0, ButtonWidth(ACaptions), Px(30));
    Result.BorderSpacing.Around := Px(8);
    Result.Align := AAlign;
    Result.OnClick := AClick;
  end;

begin
  PHeader := TPanel.Create(Self);
  PHeader.Parent := Self;
  PHeader.Align := alTop;
  PHeader.BevelOuter := bvNone;
  PHeader.Caption := '';
  PHeader.ParentColor := False;
  PHeader.Color := clWindow;
  PHeader.AutoSize := True;

  LStepTitle := TLabel.Create(Self);
  LStepTitle.Parent := PHeader;
  LStepTitle.Font.Size := 12;
  LStepTitle.Font.Style := [fsBold];
  LStepTitle.Font.Color := clWindowText;
  LStepTitle.ShowAccelChar := False;
  LStepTitle.AnchorSide[akLeft].Control := PHeader;
  LStepTitle.AnchorSide[akLeft].Side := asrLeft;
  LStepTitle.AnchorSide[akRight].Control := PHeader;
  LStepTitle.AnchorSide[akRight].Side := asrRight;
  LStepTitle.AnchorSide[akTop].Control := PHeader;
  LStepTitle.AnchorSide[akTop].Side := asrTop;
  LStepTitle.BorderSpacing.Left := Px(16);
  LStepTitle.BorderSpacing.Right := Px(16);
  LStepTitle.BorderSpacing.Top := Px(12);
  LStepTitle.Anchors := [akLeft, akTop, akRight];

  LStepHelper := TLabel.Create(Self);
  LStepHelper.Parent := PHeader;
  LStepHelper.WordWrap := True;
  LStepHelper.Font.Color := clWindowText;
  LStepHelper.ShowAccelChar := False;
  LStepHelper.AnchorSide[akLeft].Control := PHeader;
  LStepHelper.AnchorSide[akLeft].Side := asrLeft;
  LStepHelper.AnchorSide[akRight].Control := PHeader;
  LStepHelper.AnchorSide[akRight].Side := asrRight;
  LStepHelper.AnchorSide[akTop].Control := LStepTitle;
  LStepHelper.AnchorSide[akTop].Side := asrBottom;
  LStepHelper.BorderSpacing.Left := Px(16);
  LStepHelper.BorderSpacing.Right := Px(16);
  LStepHelper.BorderSpacing.Top := Px(4);
  LStepHelper.BorderSpacing.Bottom := Px(12);
  LStepHelper.Anchors := [akLeft, akTop, akRight];

  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := Px(48);
  PBottom.BevelOuter := bvNone;
  PBottom.Caption := '';

  BCancel := NavButton([TR(94, 'Cancel')], 0, alLeft, BCancelClick);
  BCancel.Cancel := True;
  BBack := NavButton([TR(934, 'Back')], 10000, alRight, BBackClick);
  BNext := NavButton([TR(933, 'Next'), TR(935, 'Finish'),
    TR(1747, 'Finish Connection'), TR(1748, 'Edit Connection')], 20000, alRight,
    BNextClick);
  BFinish := NavButton([TR(935, 'Finish')], 30000, alRight, BFinishClick);

  LStatus := TLabel.Create(Self);
  LStatus.Parent := PBottom;
  LStatus.AutoSize := False;
  LStatus.Align := alClient;
  LStatus.Layout := tlCenter;
  LStatus.BorderSpacing.Left := Px(8);
  LStatus.ShowAccelChar := False;
  LStatus.Caption := '';

  PContent := TPanel.Create(Self);
  PContent.Parent := Self;
  PContent.Align := alClient;
  PContent.BevelOuter := bvNone;
  PContent.Caption := '';
end;

{ Stacked page controls: each one is anchored under the previous one (the
  order of alTop controls changes when a label autosizes: the LCL aligns the
  control that requested the alignment first) }

procedure TFRpNewReportWizardLCL.StackControl(AControl: TControl; AIndent,
  AGap: Integer; AFullWidth: Boolean);
begin
  AControl.AnchorSide[akLeft].Control := PContent;
  AControl.AnchorSide[akLeft].Side := asrLeft;
  AControl.BorderSpacing.Left := Px(24 + AIndent);
  if AFullWidth then
  begin
    AControl.AnchorSide[akRight].Control := PContent;
    AControl.AnchorSide[akRight].Side := asrRight;
    AControl.BorderSpacing.Right := Px(24);
  end;
  if FLastStacked = nil then
  begin
    AControl.AnchorSide[akTop].Control := PContent;
    AControl.AnchorSide[akTop].Side := asrTop;
  end
  else
  begin
    // A hidden control passes the anchor to the one above it
    AControl.AnchorSide[akTop].Control := FLastStacked;
    AControl.AnchorSide[akTop].Side := asrBottom;
  end;
  AControl.BorderSpacing.Top := Px(AGap);
  if AFullWidth then
    AControl.Anchors := [akLeft, akTop, akRight]
  else
    AControl.Anchors := [akLeft, akTop];
  FLastStacked := AControl;
end;

function TFRpNewReportWizardLCL.NewLabel(const ACaption: string; AIndent,
  AGap: Integer; ABold: Boolean): TLabel;
begin
  Result := TLabel.Create(PContent);
  Result.Parent := PContent;
  Result.WordWrap := True;
  Result.ShowAccelChar := False;
  Result.Caption := ACaption;
  if ABold then
    Result.Font.Style := [fsBold];
  StackControl(Result, AIndent, AGap, True);
end;

function TFRpNewReportWizardLCL.NewHyperlinkLabel(const ACaption: string;
  AGap: Integer; AClick: TNotifyEvent): TLabel;
begin
  // Only the text is the link
  Result := TLabel.Create(PContent);
  Result.Parent := PContent;
  Result.ShowAccelChar := False;
  Result.Caption := ACaption;
  Result.Cursor := crHandPoint;
  Result.Font.Color := clBlue;
  Result.Font.Style := [fsUnderline];
  Result.OnClick := AClick;
  StackControl(Result, 0, AGap, False);
end;

function TFRpNewReportWizardLCL.NewRadio(const ACaption: string; AIndent,
  AGap: Integer): TRadioButton;
begin
  Result := TRadioButton.Create(PContent);
  Result.Parent := PContent;
  Result.Caption := ACaption;
  StackControl(Result, AIndent, AGap, True);
end;

function TFRpNewReportWizardLCL.NewRow(AIndent, AGap: Integer): TPanel;
begin
  Result := TPanel.Create(PContent);
  Result.Parent := PContent;
  Result.BevelOuter := bvNone;
  Result.Caption := '';
  Result.AutoSize := True;
  StackControl(Result, AIndent, AGap, True);
end;

function TFRpNewReportWizardLCL.NewRowButton(ARow: TPanel;
  const ACaptions: array of string; AClick: TNotifyEvent): TButton;
begin
  // Fixed width (see ButtonWidth)
  Result := TButton.Create(PContent);
  Result.Parent := ARow;
  Result.Caption := ACaptions[0];
  Result.SetBounds(10000, 0, ButtonWidth(ACaptions), Px(28));
  Result.Align := alRight;
  Result.BorderSpacing.Left := Px(10);
  Result.OnClick := AClick;
end;

function TFRpNewReportWizardLCL.NewRowEdit(ARow: TPanel): TEdit;
begin
  Result := TEdit.Create(PContent);
  Result.Parent := ARow;
  Result.Align := alClient;
end;

function TFRpNewReportWizardLCL.NewRowCombo(ARow: TPanel;
  AStyle: TComboBoxStyle): TComboBox;
begin
  Result := TComboBox.Create(PContent);
  Result.Parent := ARow;
  Result.Align := alClient;
  Result.Style := AStyle;
end;

{ Navigation }

procedure TFRpNewReportWizardLCL.BCancelClick(Sender: TObject);
begin
  FCommitted := False;
  if fsModal in FormState then
    ModalResult := mrCancel
  else
    Close;
end;

procedure TFRpNewReportWizardLCL.BBackClick(Sender: TObject);
var
  prev: TRpWizardPage;
begin
  if (FHistory.Count = 0) or (FOperation <> woNone) then
    Exit;
  prev := FHistory[FHistory.Count - 1];
  FHistory.Delete(FHistory.Count - 1);
  GoTo_Page(prev, False);
end;

procedure TFRpNewReportWizardLCL.BNextClick(Sender: TObject);
begin
  if FOperation <> woNone then
    Exit;
  ValidateAndAdvance;
end;

procedure TFRpNewReportWizardLCL.BFinishClick(Sender: TObject);
begin
  if FOperation <> woNone then
    Exit;
  if FCurrentPage <> wpFinish then
  begin
    if not ValidateAndAdvance then
      Exit;
    if FCurrentPage <> wpFinish then
      Exit;
  end;
  FinishWizard;
end;

procedure TFRpNewReportWizardLCL.FinishWizard;
begin
  if FCurrentPage = wpFinish then
    FPendingPrompt := Trim(MemoFinishPrompt.Lines.Text)
  else
    FPendingPrompt := '';
  // A subschema is only for a direct connection (the route may have changed
  // after choosing one)
  if FState.Route <> wrDirect then
    FState.LocalSchemaName := '';
  // A local subschema or a cloud schema: either one lets the AI design
  if (FPendingPrompt <> '') and not HasReportmanAiSchema then
  begin
    if RpMessageBox(WideString(TR(1992, 'You wrote a text for the AI but ' +
      'chose no schema, and the AI needs one. Continue without the AI ' +
      '(design by hand)?')),
      WideString(TR(1752, 'Schema required')), [smbYes, smbNo], smsWarning,
      smbNo, smbNo) <> smbYes then
      Exit;
    FPendingPrompt := '';
  end;
  CommitConnectionToReport;
  FCommitted := True;
  if fsModal in FormState then
    ModalResult := mrOk
  else
    Close;
end;

procedure TFRpNewReportWizardLCL.ClearPanel;
begin
  // The controls of the page are owned by PContent (the LCL does not free
  // the children of a freed parent: the controls in the rows go too)
  while PContent.ComponentCount > 0 do
    PContent.Components[PContent.ComponentCount - 1].Free;
  FLastStacked := nil;
  RbAgent := nil; RbDirect := nil; RbNoConnection := nil;
  LnkAgentDownload := nil;
  EdHubApiKey := nil; BtnHubLogin := nil; LblHubKeyNote := nil;
  BtnHubRefresh := nil;
  CbHubDatabase := nil;
  LblLocalSchemaError := nil;
  CbFamily := nil; CbConcrete := nil; LblConcrete := nil;
  RbExisting := nil; RbNew := nil; CbExistingConn := nil;
  LblExistingConnDriver := nil;
  EdNewConnName := nil; BtnTestExisting := nil;
  ParamsScroll := nil; BtnParamsTest := nil; LblParamsCaption := nil;
  MemoFinishPrompt := nil;
  AISchemaSelector := nil;
  FParamEditors.Clear;
  RpFreeConnectionParams(FParamsList);
end;

procedure TFRpNewReportWizardLCL.GoTo_Page(APage: TRpWizardPage; APushHistory: Boolean);
begin
  if APushHistory then
    FHistory.Add(FCurrentPage);
  FCurrentPage := APage;
  PContent.DisableAlign;
  try
    ClearPanel;
    case APage of
      wpRoute:                 BuildPageRoute;
      wpAgentLogin:            BuildPageAgentLogin;
      wpAgentSchema,
      wpDirectSchema:          BuildPageSchema;
      wpDriver:                BuildPageDriver;
      wpConnName:              BuildPageConnName;
      wpParams:                BuildPageParams;
      wpFinish:                BuildPageFinish;
    end;
  finally
    PContent.EnableAlign;
  end;
  // The parameters are laid out on the aligned scroll box
  if APage = wpParams then
    LoadParamsFromAdminService;
  UpdateHeader(APage);
  UpdateNavButtons;
  UpdatePageButtons;
end;

procedure TFRpNewReportWizardLCL.UpdateHeader(APage: TRpWizardPage);
begin
  case APage of
    wpRoute:
      begin
        LStepTitle.Caption := TR(1710, 'Connection Route');
        LStepHelper.Caption := TR(1711, 'Choose how this report will get its data. ' +
          'You can connect through Reportman AI for distributed access or directly ' +
          'to a local database.');
      end;
    wpAgentLogin:
      begin
        LStepTitle.Caption := TR(1712, 'Reportman AI Connection');
        LStepHelper.Caption := TR(1713, 'Provide your Reportman AI API key and pick ' +
          'the distributed connection to use.');
      end;
    wpAgentSchema, wpDirectSchema:
      begin
        LStepTitle.Caption := TR(1990, 'Schema for the AI');
        LStepHelper.Caption := TR(1991, 'The AI designs with a subschema of this ' +
          'connection or with a schema in the cloud. Without a schema, the report ' +
          'is designed by hand.');
      end;
    wpDriver:
      begin
        LStepTitle.Caption := TR(1101, 'Database Driver');
        LStepHelper.Caption := TR(1717, 'Choose the driver family and the specific ' +
          'database driver for this direct database connection.');
      end;
    wpConnName:
      begin
        LStepTitle.Caption := TR(400, 'Connection Name');
        LStepHelper.Caption := TR(1718, 'Pick an existing connection or create a new ' +
          'one for this driver.');
      end;
    wpParams:
      begin
        LStepTitle.Caption := TR(1719, 'Connection Parameters');
        LStepHelper.Caption := TR(1720, 'Edit the connection parameters and test the ' +
          'connection before continuing.');
      end;
    wpFinish:
      begin
        LStepTitle.Caption := TR(935, 'Finish');
        LStepHelper.Caption := TR(1721, 'Describe the report so AI can design it for ' +
          'you. If you selected a schema, AI will obtain the data for you. Leave this ' +
          'text blank if you want to create the report manually.');
      end;
  end;
end;

procedure TFRpNewReportWizardLCL.UpdateNavButtons;
var
  LIdle: Boolean;
begin
  LIdle := FOperation = woNone;
  BBack.Enabled := (FHistory.Count > 0) and LIdle;
  BFinish.Visible := FCurrentPage = wpFinish;
  BFinish.Default := FCurrentPage = wpFinish;
  BFinish.Enabled := LIdle;
  BNext.Visible := FCurrentPage <> wpFinish;
  BNext.Default := FCurrentPage <> wpFinish;
  BNext.Enabled := LIdle;
  if FCurrentPage = wpRoute then
  begin
    if IsImmediateFinishRouteSelected then
      BNext.Caption := TR(935, 'Finish')
    else
      BNext.Caption := TR(933, 'Next');
  end
  else if IsLastConnectionStep then
    BNext.Caption := TR(935, 'Finish')
  else if BNext.Caption = TR(935, 'Finish') then
    BNext.Caption := TR(933, 'Next');
end;

// The actions of the page wait for the running work
procedure TFRpNewReportWizardLCL.UpdatePageButtons;
var
  LIdle: Boolean;
begin
  LIdle := FOperation = woNone;
  if Assigned(BtnHubLogin) then
    BtnHubLogin.Enabled := LIdle;
  if Assigned(BtnHubRefresh) then
    BtnHubRefresh.Enabled := LIdle;
  if Assigned(BtnTestExisting) then
    BtnTestExisting.Enabled := LIdle and Assigned(RbExisting) and RbExisting.Checked;
  if Assigned(BtnParamsTest) then
    BtnParamsTest.Enabled := LIdle;
end;

function TFRpNewReportWizardLCL.NextPageFor(APage: TRpWizardPage): TRpWizardPage;
begin
  // The connection wizard: no schema and no prompt (wpFinish ends it)
  if FConnectionMode then
  begin
    case APage of
      wpRoute:
        if FState.Route = wrAgent then Result := wpConnName
        else Result := wpDriver;
      wpDriver:
        Result := wpConnName;
      wpConnName:
        if FState.ConnMode = cnExisting then
          Result := wpFinish
        else if FState.Route = wrAgent then
          Result := wpAgentLogin
        else if FamilyAcceptsParamStep then
          Result := wpParams
        else
          Result := wpFinish;
    else
      Result := wpFinish;
    end;
    Exit;
  end;
  // The schema for the AI comes once the connection is known: the local
  // subschemas need it (5.7.1 B1, B2)
  case APage of
    wpRoute:
      if FState.Route = wrAgent then Result := wpConnName
      else if FState.Route = wrDirect then Result := wpDriver
      else Result := wpFinish;
    wpAgentLogin:                    Result := wpAgentSchema;
    wpAgentSchema:                   Result := wpFinish;
    wpDirectSchema:                  Result := wpFinish;
    wpDriver:                        Result := wpConnName;
    wpConnName:
      begin
        if FState.Route = wrAgent then
        begin
          if FState.ConnMode = cnNew then
            Result := wpAgentLogin
          else
            Result := wpAgentSchema;
        end
        else if (FState.ConnMode = cnExisting) and FamilyAcceptsParamStep then
          Result := wpDirectSchema // existing connection, user already tested - skip params
        else if FamilyAcceptsParamStep then
          Result := wpParams
        else
          Result := wpDirectSchema;
      end;
    wpParams:                        Result := wpDirectSchema;
    wpFinish:                        Result := wpFinish;
  else
    Result := wpFinish;
  end;
end;

function TFRpNewReportWizardLCL.ValidateAndAdvance: Boolean;
var
  next: TRpWizardPage;
  trimmedName: string;
  values, testValues: TStringList;
  detectedFamily: TRpWizardDriverFamily;
  driverHint: string;
  hubDatabaseId: Int64;
  hubSchemaId: Int64;
  schemaApiKey: string;
begin
  Result := False;
  case FCurrentPage of
    wpRoute:
      begin
        if Assigned(RbAgent) and RbAgent.Checked then FState.Route := wrAgent
        else if Assigned(RbDirect) and RbDirect.Checked then FState.Route := wrDirect
        else if Assigned(RbNoConnection) and RbNoConnection.Checked then FState.Route := wrNoConnection
        else
        begin
          ShowInfo(TR(1753, 'Please choose a connection route.'));
          Exit;
        end;
        if FState.Route = wrNoConnection then
        begin
          FinishWizard;
          Result := True;
          Exit;
        end;
      end;
    wpAgentLogin:
      begin
        // The key as it is typed (also without "Log in"): the connection
        // test validates it. Without a session it is required.
        if Assigned(EdHubApiKey) then
          FState.HubApiKey := Trim(EdHubApiKey.Text);
        if (FState.HubApiKey = '') and not HasHubSession then
        begin
          ShowInfo(TR(1777, 'Please enter your Reportman AI API key.'));
          Exit;
        end;
        if not FState.HubLoggedIn then
        begin
          ShowInfo(TR(1754, 'Please log in to Reportman AI before continuing.'));
          Exit;
        end;
        if FState.ConnMode = cnExisting then
        begin
          if FState.ConnName = '' then
          begin
            ShowInfo(TR(1755, 'Please choose an existing Reportman AI connection.'));
            Exit;
          end;
        end
        else if (CbHubDatabase = nil) or (CbHubDatabase.ItemIndex < 0) or
          (CbHubDatabase.ItemIndex >= FHubDatabases.Count) then
        begin
          ShowInfo(TR(1756, 'Please choose a Reportman AI connection.'));
          Exit;
        end;
        if FState.ConnMode = cnNew then
        begin
          FState.HubDatabaseName := FHubDatabases.Names[CbHubDatabase.ItemIndex];
          FState.HubDatabaseId := StrToInt64Def(
            FHubDatabases.ValueFromIndex[CbHubDatabase.ItemIndex], 0);
          values := TStringList.Create;
          testValues := TStringList.Create;
          try
            try
              if (not ConnectionExists(FState.ConnName)) or
                IsWizardConnection(FState.ConnName) then
                PrepareWizardConnection(FState.ConnName, RP_DBX_DRIVER_FAMILY_AGENT, '');
              values.Values['ApiKey'] := FState.HubApiKey;
              values.Values['HubDatabaseId'] := IntToStr(FState.HubDatabaseId);
              FAdmin.UpdateConnectionParams(FState.ConnName, values);
              FAdmin.GetTestValues(FState.ConnName, nil, testValues);
            except
              on E: Exception do
              begin
                ShowCritical(TR(1758, 'Could not save Reportman AI connection: ') +
                  E.Message);
                Exit;
              end;
            end;
            // The next page comes when the test answers (AgentConnectionTested)
            StartConnectionTest(woAgentConnection, FState.ConnName, testValues);
          finally
            testValues.Free;
            values.Free;
          end;
          Exit;
        end;
      end;
    wpAgentSchema, wpDirectSchema:
      begin
        // Choosing a schema is optional (the finish page asks when there is
        // a prompt without one); the Hub database of an Agent connection
        // stays without a cloud schema
        FState.HubSchemaId := 0;
        FState.HubSchemaName := '';
        FState.LocalSchemaName := '';
        if AISchemaSelector <> nil then
        begin
          if AISchemaSelector.GetHubSchemaId <> 0 then
          begin
            FState.HubDatabaseId := AISchemaSelector.GetHubDatabaseId;
            FState.HubSchemaId := AISchemaSelector.GetHubSchemaId;
            FState.HubApiKey := AISchemaSelector.GetSchemaApiKey;
            FState.HubSchemaName := AISchemaSelector.ComboSchema.Text;
          end;
          if FState.Route = wrDirect then
            FState.LocalSchemaName := AISchemaSelector.GetLocalSchemaName;
        end;
        // A direct connection has a Hub database only through a cloud schema
        if (FState.Route = wrDirect) and (FState.HubSchemaId = 0) then
        begin
          FState.HubDatabaseId := 0;
          FState.HubApiKey := '';
        end;

        if FState.Route = wrAgent then
        begin
          values := TStringList.Create;
          try
            try
              if (FState.ConnMode = cnNew) and ((not ConnectionExists(FState.ConnName)) or
                IsWizardConnection(FState.ConnName)) then
                PrepareWizardConnection(FState.ConnName, RP_DBX_DRIVER_FAMILY_AGENT, '');
              if Trim(FState.HubApiKey) <> '' then
                values.Values['ApiKey'] := FState.HubApiKey;
              values.Values['HubDatabaseId'] := IntToStr(FState.HubDatabaseId);
              if FState.ConnMode = cnNew then
                FAdmin.UpdateConnectionParams(FState.ConnName, values);
            except
              on E: Exception do
              begin
                ShowCritical(TR(1758, 'Could not save Reportman AI connection: ') +
                  E.Message);
                Exit;
              end;
            end;
          finally
            values.Free;
          end;
        end;
      end;
    wpDriver:
      begin
        if FState.DriverFamily = dfUndefined then
        begin
          ShowInfo(TR(1761, 'Please choose a driver family.'));
          Exit;
        end;
        if (CbConcrete = nil) or (Trim(CbConcrete.Text) = '') then
        begin
          ShowInfo(TR(1762, 'Please choose a specific driver.'));
          Exit;
        end;
        FState.DriverConcrete := Trim(CbConcrete.Text);
      end;
    wpConnName:
      begin
        if (FState.Route = wrAgent) and Assigned(RbExisting) and RbExisting.Checked then
        begin
          FState.ConnMode := cnExisting;
          if (CbExistingConn.ItemIndex < 0) then
          begin
            ShowInfo(TR(1755, 'Please choose an existing Reportman AI connection.'));
            Exit;
          end;
          FState.ConnName := Trim(CbExistingConn.Text);
          if not TryGetConnectionDetails(FState.ConnName, detectedFamily,
            driverHint, hubDatabaseId, hubSchemaId, schemaApiKey) then
          begin
            ShowCritical(TR(1763, 'Could not read the selected Reportman AI connection.'));
            Exit;
          end;
          FState.HubDatabaseId := hubDatabaseId;
          FState.HubSchemaId := hubSchemaId;
          FState.HubApiKey := schemaApiKey;
          FState.HubDatabaseName := FState.ConnName;
        end
        else if (FState.Route = wrAgent) and Assigned(RbNew) and RbNew.Checked then
        begin
          FState.ConnMode := cnNew;
          trimmedName := Trim(EdNewConnName.Text);
          if trimmedName = '' then
          begin
            ShowInfo(TR(1764, 'Please enter a connection name.'));
            Exit;
          end;
          // A connection created before by this wizard (Back) can be used
          if ConnectionExists(trimmedName) and not IsWizardConnection(trimmedName) then
          begin
            ShowInfo(TR(1765, 'This connection name already exists. Choose a different name.'));
            Exit;
          end;
          FState.ConnName := trimmedName;
        end
        else if Assigned(RbExisting) and RbExisting.Checked then
        begin
          FState.ConnMode := cnExisting;
          if (CbExistingConn.ItemIndex < 0) then
          begin
            ShowInfo(TR(1766, 'Please choose an existing connection.'));
            Exit;
          end;
          FState.ConnName := Trim(CbExistingConn.Text);
        end
        else if Assigned(RbNew) and RbNew.Checked then
        begin
          FState.ConnMode := cnNew;
          trimmedName := Trim(EdNewConnName.Text);
          if trimmedName = '' then
          begin
            ShowInfo(TR(1764, 'Please enter a connection name.'));
            Exit;
          end;
          // A connection created before by this wizard (Back) can be used
          if ConnectionExists(trimmedName) and not IsWizardConnection(trimmedName) then
          begin
            ShowInfo(TR(1765, 'This connection name already exists. Choose a different name.'));
            Exit;
          end;
          // create the new connection in dbxconnections (kept when this
          // wizard created it with the same driver)
          try
            PrepareWizardConnection(trimmedName, FamilyDriverName, FState.DriverConcrete);
          except
            on E: Exception do
            begin
              ShowCritical(TR(1767, 'Could not create connection: ') + E.Message);
              Exit;
            end;
          end;
          FState.ConnName := trimmedName;
        end
        else
        begin
          ShowInfo(TR(1768, 'Please choose Existing or New connection.'));
          Exit;
        end;
      end;
    wpParams:
      begin
        // Persist edited values into dbxconnections
        values := TStringList.Create;
        try
          CommitParamsFromEditors(values);
          try
            FAdmin.UpdateConnectionParams(FState.ConnName, values);
          except
            on E: Exception do
            begin
              ShowCritical(TR(1769, 'Could not save connection parameters: ') + E.Message);
              Exit;
            end;
          end;
        finally
          values.Free;
        end;
      end;
  end;

  next := NextPageFor(FCurrentPage);
  if FConnectionMode and (next = wpFinish) then
  begin
    FinishConnection;
    Result := True;
    Exit;
  end;
  GoTo_Page(next, True);
  Result := True;
end;

// A schema for the AI: a cloud schema or a local subschema
function TFRpNewReportWizardLCL.HasReportmanAiSchema: Boolean;
begin
  Result := (FState.HubSchemaId <> 0) or (FState.LocalSchemaName <> '');
end;

function TFRpNewReportWizardLCL.ConnectionExists(
  const AConnectionName: string): Boolean;
begin
  Result := FAdmin.ConnectionExists(AConnectionName);
end;

function TFRpNewReportWizardLCL.IsWizardConnection(const AConnectionName: string): Boolean;
begin
  Result := (FCreatedConnection <> '') and SameText(FCreatedConnection, Trim(AConnectionName));
end;

procedure TFRpNewReportWizardLCL.PrepareWizardConnection(const AConnectionName,
  ADriverName, AProtocol: string);
var
  LDriverKey: string;
begin
  // The VCL creates the connection again when the user comes back to the
  // page, and then refuses its name: this wizard keeps its own connection
  // (with its edited parameters) while the driver is the same
  LDriverKey := ADriverName + '/' + AProtocol;
  if IsWizardConnection(AConnectionName) and SameText(FCreatedConnectionDriver, LDriverKey) and
    ConnectionExists(AConnectionName) then
    Exit;
  FAdmin.CreateConnection(AConnectionName, ADriverName, AProtocol);
  FCreatedConnection := Trim(AConnectionName);
  FCreatedConnectionDriver := LDriverKey;
end;

function TFRpNewReportWizardLCL.TryGetConnectionDetails(
  const AConnectionName: string; out AFamily: TRpWizardDriverFamily;
  out ADriverHint: string; out AHubDatabaseId, AHubSchemaId: Int64;
  out AApiKey: string): Boolean;
var
  values: TStringList;
  driverName: string;
  protocolName: string;
  driverId: string;
begin
  Result := False;
  AFamily := dfUndefined;
  ADriverHint := '';
  AHubDatabaseId := 0;
  AHubSchemaId := 0;
  AApiKey := '';
  values := TStringList.Create;
  try
    FAdmin.GetConnectionValues(AConnectionName, values);
    if values.Count = 0 then
      Exit;
    driverName := Trim(values.Values['DriverName']);
    protocolName := Trim(values.Values[RP_DBX_ZEOS_PROTOCOL_PARAM]);
    if protocolName = '' then
      protocolName := Trim(values.Values['Protocol']);
    driverId := Trim(values.Values['DriverID']);
    AHubDatabaseId := StrToInt64Def(Trim(values.Values['HubDatabaseId']), 0);
    AHubSchemaId := StrToInt64Def(Trim(values.Values['HubSchemaId']), 0);
    AApiKey := Trim(values.Values['ApiKey']);

    if SameText(driverName, RP_DBX_DRIVER_FAMILY_AGENT) then
    begin
      ADriverHint := SAgentDriverHint;
      Result := True;
      Exit;
    end;

    if SameText(driverName, RP_DBX_DRIVER_FAMILY_FIREDAC) then
    begin
      ADriverHint := 'FireDAC';
      if driverId <> '' then
        ADriverHint := ADriverHint + ' - ' + driverId;
      // The FireDAC drivers that SQLdb opens in the FPC engine
      if RpSQLDBDriverId(driverId) <> '' then
        AFamily := dfFireDac;
      Result := True;
      Exit;
    end;

    if SameText(driverName, RP_DBX_DRIVER_SQLITE) then
    begin
      AFamily := dfFireDac;
      ADriverHint := 'FireDAC - ' + SSqliteDriverId;
      Result := True;
      Exit;
    end;

    if SameText(driverName, RP_DBX_DRIVER_FAMILY_ZEOS) or
      (((SameText(driverName, 'Interbase')) or SameText(driverName, 'Firebird')) and
       (protocolName <> '')) then
    begin
      AFamily := dfZeos;
      ADriverHint := 'Zeos';
      if protocolName <> '' then
        ADriverHint := ADriverHint + ' - ' + protocolName;
      Result := True;
      Exit;
    end;

    if driverName <> '' then
    begin
      AFamily := dfDbExpress;
      ADriverHint := 'DBExpress - ' + driverName;
      Result := True;
    end;
  finally
    values.Free;
  end;
end;

function TFRpNewReportWizardLCL.FamilyDriverName: string;
begin
  case FState.DriverFamily of
    // DriverName=FireDac and the DriverID, as Delphi writes the connection
    dfFireDac: Result := RP_DBX_DRIVER_FAMILY_FIREDAC;
    dfZeos:    Result := RP_DBX_DRIVER_FAMILY_ZEOS;
  else
    Result := '';
  end;
end;

function TFRpNewReportWizardLCL.FamilyAcceptsParamStep: Boolean;
begin
  Result := FState.DriverFamily in [dfFireDac, dfZeos];
end;

procedure TFRpNewReportWizardLCL.OpenAgentDownloadLink(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenAgentDownloadPage;
end;

{ Pages }

procedure TFRpNewReportWizardLCL.BuildPageRoute;
begin
  RbAgent := NewRadio(TR(1724, 'Reportman AI / DB Agent (distributed connection)'), 0, 16);
  RbAgent.Checked := FState.Route = wrAgent;
  RbAgent.OnClick := DoRouteChange;
  NewLabel(TR(1725, 'Use a Reportman AI database connection. Recommended when the ' +
    'database is reachable through Reportman AI Web.'), 24, 2);
  // Where the Agent comes from, for those who do not have it yet
  NewLabel(TR(1823, 'The Reportman Agent is installed as a service on a Windows or Linux ' +
    'computer that can reach your database and gives the designer secure access to it ' +
    'through ai.reportman.es.'), 24, 6);
  LnkAgentDownload := NewHyperlinkLabel(TR(1822, 'Download Reportman Agent'), 2,
    OpenAgentDownloadLink);
  // Aligned with the descriptions
  LnkAgentDownload.BorderSpacing.Left := Px(24 + 24);

  RbDirect := NewRadio(TR(1726, 'Direct database connection'), 0, 18);
  RbDirect.Checked := FState.Route = wrDirect;
  RbDirect.OnClick := DoRouteChange;
  NewLabel(TR(1727, 'Connect directly using a local driver (FireDAC SQLite or Zeos).'),
    24, 2);

  // The connection wizard adds a connection: no "no connection" route
  if FConnectionMode then
  begin
    UpdateNavButtons;
    Exit;
  end;

  RbNoConnection := NewRadio(TR(1728, 'Continue with no connection'), 0, 18);
  RbNoConnection.Checked := FState.Route = wrNoConnection;
  RbNoConnection.OnClick := DoRouteChange;
  NewLabel(TR(1729, 'Create a blank report and finish the wizard without selecting ' +
    'or creating any data connection.'), 24, 2);

  UpdateNavButtons;
end;

procedure TFRpNewReportWizardLCL.DoRouteChange(Sender: TObject);
begin
  UpdateNavButtons;
end;

function TFRpNewReportWizardLCL.IsImmediateFinishRouteSelected: Boolean;
begin
  Result := (FCurrentPage = wpRoute) and Assigned(RbNoConnection) and
    RbNoConnection.Checked;
end;

procedure TFRpNewReportWizardLCL.BuildPageAgentLogin;
var
  LRow: TPanel;
begin
  if FState.ConnMode = cnExisting then
  begin
    NewLabel(Format(TR(1730, 'Existing Reportman AI connection: %s'), [FState.ConnName]),
      0, 16, True);
    NewLabel(TR(1731, 'Enter your API key to authenticate and load available schemas ' +
      'for this connection.'), 0, 8);
    NewLabel(TR(1732, 'Reportman AI API key'), 0, 16);
    LRow := NewRow(0, 4);
    BtnHubLogin := NewRowButton(LRow, [TR(1783, 'Log in')], DoHubLogin);
    EdHubApiKey := NewRowEdit(LRow);
    EdHubApiKey.Text := FState.HubApiKey;
    EdHubApiKey.PasswordChar := '*';
    Exit;
  end;

  // Connection wizard for a connection of the report: its name
  if FFixedName <> '' then
    NewLabel(Format(TR(1736, 'Selected Reportman AI connection: %s'), [FFixedName]),
      0, 12, True);
  NewLabel(TR(1732, 'Reportman AI API key'), 0, 16);
  LRow := NewRow(0, 4);
  BtnHubLogin := NewRowButton(LRow, [TR(1783, 'Log in'), TR(1149, 'Refresh')], DoHubLogin);
  EdHubApiKey := NewRowEdit(LRow);
  EdHubApiKey.Text := FState.HubApiKey;
  EdHubApiKey.PasswordChar := '*';
  // With a session the key is optional, but the report needs it to run
  // unattended (printreptopdf, server): the engine uses the session otherwise
  if HasHubSession then
    LblHubKeyNote := NewLabel(TR(1831, 'You are signed in to Reportman AI: the API ' +
      'key is optional. Without it the connection uses your session, and the ' +
      'report cannot run unattended on this computer (printreptopdf, server, ' +
      'scheduled tasks).'), 0, 6)
  else
    LblHubKeyNote := NewLabel(TR(1832, 'You are not signed in to Reportman AI: ' +
      'the API key is required.'), 0, 6);
  LblHubKeyNote.Font.Color := clGrayText;

  NewLabel(TR(1712, 'Reportman AI Connection'), 0, 16);
  LRow := NewRow(0, 4);
  BtnHubRefresh := NewRowButton(LRow, [TR(1149, 'Refresh'), TR(1783, 'Log in')], DoHubRefresh);
  CbHubDatabase := NewRowCombo(LRow, csDropDownList);
  FillHubDatabaseCombo;

  // The databases of the session, or of the key of a previous visit
  if HasHubSession or (FState.HubLoggedIn and (Trim(FState.HubApiKey) <> '')) then
    LoadHubDatabases(True);
end;

procedure TFRpNewReportWizardLCL.BuildPageSchema;
begin
  if (FState.Route = wrAgent) and (Trim(FState.ConnName) <> '') then
    NewLabel(Format(TR(1736, 'Selected Reportman AI connection: %s'), [FState.ConnName]),
      0, 12, True)
  else if Trim(FState.ConnName) <> '' then
    NewLabel(TR(154, 'Connection') + ': ' + FState.ConnName, 0, 12, True);

  // The list of the copilot: the account card, the subschemas of a direct
  // connection and the schemas in the cloud of the account and of the API
  // key (loaded in the background); on the Agent route, the ones of its Hub
  // database
  AISchemaSelector := TFRpAISchemaSelectorLCL.Create(PContent);
  AISchemaSelector.Parent := PContent;
  StackControl(AISchemaSelector, 0, 8, True);
  AISchemaSelector.OnSchemasLoaded := DoSchemasLoaded;
  AISchemaSelector.OnNewLocalSchema := DoNewLocalSchema;
  if FState.Route = wrAgent then
    AISchemaSelector.CloudDatabaseFilter := FState.HubDatabaseId;
  AISchemaSelector.SetPreferredConnection(FState.HubDatabaseId, FState.HubApiKey);
  AISchemaSelector.SetHubContext(FState.HubDatabaseId, FState.HubSchemaId,
    FState.HubApiKey);

  LblLocalSchemaError := NewLabel('', 0, 4);
  LblLocalSchemaError.Font.Color := clRed;
  LblLocalSchemaError.Visible := False;
  if FState.Route = wrDirect then
  begin
    LoadLocalSchemas;
    // The subschema chosen before (Back)
    if FState.LocalSchemaName <> '' then
      AISchemaSelector.SelectLocalSchema(FState.LocalSchemaName);
  end;
  AISchemaSelector.LoadSchemas;

  if FState.Route = wrAgent then
    NewHyperlinkLabel(TR(1738, 'Install Reportman AI Agent to create new connections'),
      16, OpenAgentDownloadLink);
end;

procedure TFRpNewReportWizardLCL.LoadLocalSchemas;
var
  I, LTables, LWidest: Integer;
  LAlias: string;
  LCursor: TCursor;
  LDatabase: TRpDatabaseInfoItem;
  LDatabases: TRpDatabaseInfoList;
  LFile: TRpLocalSchemaFile;
  LNames, LSizes: TStringList;
begin
  if AISchemaSelector = nil then
    Exit;
  // The connection goes to the report now: its schema file and the local
  // schema screen read it there (Finish commits it again)
  CommitConnectionToReport;
  LDatabase := nil;
  if (FDestReport <> nil) and (FDestReport.DatabaseInfo.Count > 0) then
    LDatabase := FDestReport.DatabaseInfo.Items[0];
  if not RpIsLocalSqlDatabase(LDatabase) then
  begin
    AISchemaSelector.SetLocalSchemas('', nil, nil);
    Exit;
  end;
  LAlias := LDatabase.Alias;
  LNames := TStringList.Create;
  LSizes := TStringList.Create;
  LCursor := Screen.Cursor;
  try
    if LblLocalSchemaError <> nil then
      LblLocalSchemaError.Visible := False;
    try
      // A copy that reads the same connections file; generated from the
      // catalog the first time, as the copilot does
      LDatabases := RpCopyDatabaseInfo(LDatabase);
      try
        Screen.Cursor := crHourGlass;
        LFile := RpLoadLocalSchema(LDatabases.Items[0], FDestReport.Params,
          True, False);
        try
          for I := 0 to LFile.SchemaCount - 1 do
          begin
            LNames.Add(LFile.Schemas[I].Name);
            LFile.GetSchemaSize(LFile.Schemas[I].Name, LTables, LWidest);
            LSizes.Add(IntToStr(LTables) + ',' + IntToStr(LWidest));
          end;
        finally
          LFile.Free;
        end;
      finally
        LDatabases.Items[0].DisConnect;
        LDatabases.Free;
      end;
    except
      on E: Exception do
      begin
        // The database could not be read: the cloud schemas and the local
        // schema screen are still there
        LNames.Clear;
        LSizes.Clear;
        if LblLocalSchemaError <> nil then
        begin
          LblLocalSchemaError.Caption := E.Message;
          LblLocalSchemaError.Visible := True;
        end;
      end;
    end;
    AISchemaSelector.SetLocalSchemas(LAlias, LNames, LSizes);
  finally
    Screen.Cursor := LCursor;
    LSizes.Free;
    LNames.Free;
  end;
end;

procedure TFRpNewReportWizardLCL.DoNewLocalSchema(Sender: TObject);
var
  LSchemaName: string;
  LSaved: Boolean;
begin
  if (FDestReport = nil) or (FDestReport.DatabaseInfo.Count = 0) or
    (AISchemaSelector = nil) then
    Exit;
  LSchemaName := '';
  try
    LSaved := RpShowLocalSchemasDialog(FDestReport,
      FDestReport.DatabaseInfo.Items[0].Alias, LSchemaName, True, nil);
  except
    on E: Exception do
    begin
      ShowCritical(E.Message);
      Exit;
    end;
  end;
  // The list again, with the subschema saved chosen
  LoadLocalSchemas;
  if LSaved and (LSchemaName <> '') then
    AISchemaSelector.SelectLocalSchema(LSchemaName);
end;

procedure TFRpNewReportWizardLCL.DoSchemasLoaded(Sender: TObject);
begin
  UpdateNavButtons;
end;

procedure TFRpNewReportWizardLCL.BuildPageDriver;
var
  LRow: TPanel;
  I: Integer;
begin
  NewLabel(TR(1739, 'Driver Family'), 0, 16);
  LRow := NewRow(0, 4);
  CbFamily := NewRowCombo(LRow, csDropDownList);
  // The families of the FPC engine
  SetLength(FFamilies, 2);
  FFamilies[0] := dfFireDac;
  FFamilies[1] := dfZeos;
  CbFamily.Items.Add(TR(1740, 'FireDAC / SQLdb (Cross-platform) - Recommended'));
  CbFamily.Items.Add(TR(1741, 'Zeos (Cross-platform)'));
  CbFamily.ItemIndex := -1;
  for I := 0 to High(FFamilies) do
    if FFamilies[I] = FState.DriverFamily then
      CbFamily.ItemIndex := I;
  if CbFamily.ItemIndex < 0 then
  begin
    CbFamily.ItemIndex := 0;
    FState.DriverFamily := FFamilies[0];
  end;
  CbFamily.OnChange := DoFamilyChange;

  LblConcrete := NewLabel(TR(147, 'Driver'), 0, 16);
  LRow := NewRow(0, 4);
  CbConcrete := NewRowCombo(LRow, csDropDown);

  RefreshConcreteDriver;
end;

procedure TFRpNewReportWizardLCL.DoFamilyChange(Sender: TObject);
begin
  if (CbFamily.ItemIndex >= 0) and (CbFamily.ItemIndex <= High(FFamilies)) then
    FState.DriverFamily := FFamilies[CbFamily.ItemIndex];
  FState.DriverConcrete := '';
  if Assigned(CbConcrete) then
    CbConcrete.Text := '';
  RefreshConcreteDriver;
end;

procedure TFRpNewReportWizardLCL.RefreshConcreteDriver;
begin
  if CbConcrete = nil then
    Exit;
  CbConcrete.Items.Clear;
  case FState.DriverFamily of
    dfFireDac:
      begin
        LblConcrete.Caption := TR(1742, 'FireDAC DriverID');
        // The FireDAC drivers that SQLdb opens in the FPC engine
        RpSQLDBDriverIds(CbConcrete.Items);
      end;
    dfZeos:
      begin
        LblConcrete.Caption := TR(1743, 'Zeos protocol');
        CbConcrete.Items.CommaText :=
          'firebird,interbase,mysql,postgresql,sqlite,oracle,mssql,sybase'
          {$IFDEF MSWINDOWS} + ',ado'{$ENDIF};
      end;
  end;
  CbConcrete.Enabled := True;
  // The choice made before (Back), the only driver of the family, or
  // SQLite, the one of FireDAC / SQLdb that needs no server
  if FState.DriverConcrete <> '' then
    CbConcrete.Text := FState.DriverConcrete
  else if (CbConcrete.Items.Count = 1) or (FState.DriverFamily = dfFireDac) then
    CbConcrete.ItemIndex := 0;
end;

procedure TFRpNewReportWizardLCL.BuildPageConnName;
var
  LRow: TPanel;
begin
  RbExisting := NewRadio(TR(1744, 'Existing Connection'), 0, 12);
  RbExisting.Checked := FState.ConnMode <> cnNew;
  RbExisting.OnClick := DoConnNameModeChange;

  if FState.Route = wrAgent then
    NewLabel(TR(1712, 'Reportman AI Connection'), 24, 8)
  else
    NewLabel(TR(1745, 'DBX Connection'), 24, 8);
  LRow := NewRow(24, 4);
  BtnTestExisting := NewRowButton(LRow, [TR(1746, 'Test Connection')], DoTestExistingConn);
  CbExistingConn := NewRowCombo(LRow, csDropDownList);
  CbExistingConn.OnChange := DoExistingConnChange;

  LblExistingConnDriver := NewLabel('', 24, 4);
  LblExistingConnDriver.Font.Color := clBlue;
  LblExistingConnDriver.Visible := False;
  RefreshExistingConnections;

  RbNew := NewRadio(TR(1102, 'New Connection'), 0, 20);
  RbNew.Checked := FState.ConnMode = cnNew;
  RbNew.OnClick := DoConnNameModeChange;

  NewLabel(TR(400, 'Connection Name'), 24, 8);
  LRow := NewRow(24, 4);
  EdNewConnName := NewRowEdit(LRow);
  if FState.ConnMode = cnNew then
    EdNewConnName.Text := FState.ConnName;

  DoConnNameModeChange(nil);
end;

procedure TFRpNewReportWizardLCL.RefreshExistingConnections;
var
  names: TStringList;
  i: Integer;
  detectedFamily: TRpWizardDriverFamily;
  driverHint: string;
  hubDatabaseId: Int64;
  hubSchemaId: Int64;
  schemaApiKey: string;
begin
  if CbExistingConn = nil then
    Exit;
  CbExistingConn.Items.Clear;
  names := TStringList.Create;
  try
    FAdmin.GetConnectionNames(names);
    for i := 0 to names.Count - 1 do
    begin
      if not TryGetConnectionDetails(names[i], detectedFamily, driverHint,
        hubDatabaseId, hubSchemaId, schemaApiKey) then
        Continue;
      if FState.Route = wrAgent then
      begin
        if SameText(driverHint, SAgentDriverHint) then
          CbExistingConn.Items.Add(names[i]);
      end
      else if (detectedFamily <> dfUndefined) and
        (detectedFamily = FState.DriverFamily) then
        CbExistingConn.Items.Add(names[i]);
    end;
    if FState.ConnName <> '' then
      CbExistingConn.ItemIndex := CbExistingConn.Items.IndexOf(FState.ConnName);
    if (CbExistingConn.ItemIndex < 0) and (CbExistingConn.Items.Count > 0) then
      CbExistingConn.ItemIndex := 0;
  finally
    names.Free;
  end;
  UpdateExistingConnDriverHint;
end;

procedure TFRpNewReportWizardLCL.DoConnNameModeChange(Sender: TObject);
var
  isExisting: Boolean;
begin
  if (RbExisting = nil) or (RbNew = nil) then Exit;
  isExisting := RbExisting.Checked;
  if Assigned(CbExistingConn) then CbExistingConn.Enabled := isExisting;
  if Assigned(BtnTestExisting) then
    BtnTestExisting.Enabled := isExisting and (FOperation = woNone);
  if Assigned(LblExistingConnDriver) then
    LblExistingConnDriver.Visible := isExisting and (FState.Route = wrDirect);
  if Assigned(EdNewConnName) then EdNewConnName.Enabled := not isExisting;
  UpdateExistingConnDriverHint;
  // Connection wizard: Finish with an existing connection
  UpdateNavButtons;
end;

procedure TFRpNewReportWizardLCL.DoExistingConnChange(Sender: TObject);
begin
  UpdateExistingConnDriverHint;
end;

procedure TFRpNewReportWizardLCL.UpdateExistingConnDriverHint;
var
  detectedFamily: TRpWizardDriverFamily;
  driverHint: string;
  hubDatabaseId: Int64;
  hubSchemaId: Int64;
  schemaApiKey: string;
begin
  if LblExistingConnDriver = nil then
    Exit;
  if (FState.Route <> wrDirect) or (RbExisting = nil) or not RbExisting.Checked or
    (CbExistingConn = nil) or (CbExistingConn.ItemIndex < 0) then
  begin
    LblExistingConnDriver.Caption := '';
    LblExistingConnDriver.Visible := False;
    Exit;
  end;
  if TryGetConnectionDetails(CbExistingConn.Text, detectedFamily, driverHint,
    hubDatabaseId, hubSchemaId, schemaApiKey) then
  begin
    LblExistingConnDriver.Caption := driverHint;
    LblExistingConnDriver.Visible := True;
  end
  else
  begin
    LblExistingConnDriver.Caption := '';
    LblExistingConnDriver.Visible := False;
  end;
end;

procedure TFRpNewReportWizardLCL.DoTestExistingConn(Sender: TObject);
var
  values: TStringList;
begin
  if FOperation <> woNone then
    Exit;
  if (CbExistingConn = nil) or (CbExistingConn.ItemIndex < 0) then
  begin
    RpMessageBox(WideString(TR(1770, 'Please choose a connection first.')),
      WideString(TR(1771, 'Connection Test')), [smbOK], smsInformation, smbOK, smbOK);
    Exit;
  end;
  values := TStringList.Create;
  try
    try
      FAdmin.GetTestValues(CbExistingConn.Text, nil, values);
    except
      on E: Exception do
      begin
        ExistingConnectionTested(False, E.Message);
        Exit;
      end;
    end;
    StartConnectionTest(woTestExisting, CbExistingConn.Text, values);
  finally
    values.Free;
  end;
end;

procedure TFRpNewReportWizardLCL.ExistingConnectionTested(ASuccess: Boolean;
  const AMessage: string);
begin
  if ASuccess then
  begin
    RpMessageBox(WideString(TR(1772, 'Connection succeeded.')),
      WideString(TR(1773, 'Success')), [smbOK], smsInformation, smbOK, smbOK);
    BNext.Caption := TR(1747, 'Finish Connection');
  end
  else
  begin
    RpMessageBox(WideString(TR(1774, 'Connection failed: ') + AMessage),
      WideString(TR(1775, 'Connection Error')), [smbOK], smsCritical, smbOK, smbOK);
    BNext.Caption := TR(1748, 'Edit Connection');
  end;
end;

procedure TFRpNewReportWizardLCL.BuildPageParams;
var
  LRow: TPanel;
begin
  // Aligned: the scroll box takes the rest of the page
  LblParamsCaption := TLabel.Create(PContent);
  LblParamsCaption.Parent := PContent;
  LblParamsCaption.Align := alTop;
  LblParamsCaption.ShowAccelChar := False;
  LblParamsCaption.Font.Style := [fsBold];
  LblParamsCaption.BorderSpacing.Left := Px(16);
  LblParamsCaption.BorderSpacing.Right := Px(16);
  LblParamsCaption.BorderSpacing.Top := Px(8);
  if FState.ConnMode = cnNew then
    LblParamsCaption.Caption := Format(TR(1749, 'New Connection "%s"'), [FState.ConnName])
  else
    LblParamsCaption.Caption := Format(TR(1750, 'Edit Connection "%s"'), [FState.ConnName]);

  LRow := TPanel.Create(PContent);
  LRow.Parent := PContent;
  LRow.Align := alBottom;
  LRow.BevelOuter := bvNone;
  LRow.Caption := '';
  LRow.Height := Px(44);
  BtnParamsTest := TButton.Create(PContent);
  BtnParamsTest.Parent := LRow;
  BtnParamsTest.Caption := TR(1746, 'Test Connection');
  BtnParamsTest.SetBounds(0, 0, ButtonWidth([BtnParamsTest.Caption]), Px(30));
  BtnParamsTest.BorderSpacing.Left := Px(16);
  BtnParamsTest.BorderSpacing.Top := Px(6);
  BtnParamsTest.BorderSpacing.Bottom := Px(8);
  BtnParamsTest.Align := alLeft;
  BtnParamsTest.OnClick := DoParamsTest;

  ParamsScroll := TScrollBox.Create(PContent);
  ParamsScroll.Parent := PContent;
  ParamsScroll.Align := alClient;
  ParamsScroll.BorderSpacing.Left := Px(16);
  ParamsScroll.BorderSpacing.Right := Px(16);
  ParamsScroll.BorderSpacing.Top := Px(8);
  ParamsScroll.BorderStyle := bsNone;
  ParamsScroll.HorzScrollBar.Visible := False;
  ParamsScroll.VertScrollBar.Tracking := True;
end;

procedure TFRpNewReportWizardLCL.LoadParamsFromAdminService;
var
  i: Integer;
  ed: TWinControl;
  edEdit: TEdit;
  edCb: TComboBox;
  edMemo: TMemo;
  yPos, LLeft, LWidth: Integer;
  LAnchorRight: Boolean;
  lblName: TLabel;
  param: TRpDbxConnectionParam;
begin
  if ParamsScroll = nil then
    Exit;
  RpFreeConnectionParams(FParamsList);
  FParamEditors.Clear;
  for i := ParamsScroll.ControlCount - 1 downto 0 do
    ParamsScroll.Controls[i].Free;

  // New connections: the parameters of the driver chosen in the earlier
  // steps (dbxdrivers section, or the database of a SQLite connection)
  try
    FAdmin.GetConnectionParams(FState.ConnName, FParamsList, nil);
  except
    on E: Exception do
    begin
      RpMessageBox(WideString(TR(1776, 'Could not load connection parameters: ') +
        E.Message), WideString(TR(1719, 'Connection Parameters')), [smbOK],
        smsCritical, smbOK, smbOK);
      Exit;
    end;
  end;

  LLeft := Px(188);
  LWidth := ParamsScroll.ClientWidth;
  // The editors follow the width of the scroll box once it is laid out
  LAnchorRight := LWidth >= Px(300);
  if not LAnchorRight then
    LWidth := PContent.ClientWidth - Px(32);
  LWidth := LWidth - LLeft - Px(8);
  if LWidth < Px(120) then
    LWidth := Px(120);
  yPos := Px(4);
  for i := 0 to FParamsList.Count - 1 do
  begin
    param := FParamsList[i];

    // For new connections, the driver family and concrete driver were already
    // chosen in earlier steps; the parameter list shown here is generated by
    // the driver itself, so DriverName/DriverID/DBXDriverName must NOT be
    // editable here -- changing them would invalidate the param set.
    if (FState.ConnMode = cnNew) and
      (SameText(param.Name, 'DriverName') or
       SameText(param.Name, 'DriverID') or
       SameText(param.Name, 'DBXDriverName')) then
    begin
      edEdit := TEdit.Create(ParamsScroll);
      edEdit.Parent := ParamsScroll;
      edEdit.ReadOnly := True;
      edEdit.Color := clBtnFace;
      edEdit.TabStop := False;
      edEdit.Text := param.Value;
      ed := edEdit;
    end
    else
    begin
      case param.EditorKind of
        weCombo:
          begin
            edCb := TComboBox.Create(ParamsScroll);
            edCb.Parent := ParamsScroll;
            edCb.Style := csDropDownList;
            if Assigned(param.Options) then
              edCb.Items.Assign(param.Options);
            if edCb.Items.IndexOf(param.Value) < 0 then
              edCb.Items.Add(param.Value);
            edCb.ItemIndex := edCb.Items.IndexOf(param.Value);
            ed := edCb;
          end;
        weComboEditable:
          begin
            edCb := TComboBox.Create(ParamsScroll);
            edCb.Parent := ParamsScroll;
            edCb.Style := csDropDown;
            if Assigned(param.Options) then
              edCb.Items.Assign(param.Options);
            edCb.Text := param.Value;
            ed := edCb;
          end;
        wePassword:
          begin
            edEdit := TEdit.Create(ParamsScroll);
            edEdit.Parent := ParamsScroll;
            edEdit.PasswordChar := '*';
            edEdit.Text := param.Value;
            ed := edEdit;
          end;
        weTextArea:
          begin
            edMemo := TMemo.Create(ParamsScroll);
            edMemo.Parent := ParamsScroll;
            edMemo.Height := Px(60);
            edMemo.ScrollBars := ssVertical;
            edMemo.Text := param.Value;
            ed := edMemo;
          end;
        weReadOnly:
          begin
            edEdit := TEdit.Create(ParamsScroll);
            edEdit.Parent := ParamsScroll;
            edEdit.ReadOnly := True;
            edEdit.Color := clBtnFace;
            edEdit.Text := param.Value;
            ed := edEdit;
          end;
      else
        begin
          edEdit := TEdit.Create(ParamsScroll);
          edEdit.Parent := ParamsScroll;
          edEdit.Text := param.Value;
          ed := edEdit;
        end;
      end;
    end;
    ed.SetBounds(LLeft, yPos, LWidth, ed.Height);
    if LAnchorRight then
      ed.Anchors := [akLeft, akTop, akRight];

    lblName := TLabel.Create(ParamsScroll);
    lblName.Parent := ParamsScroll;
    lblName.AutoSize := False;
    lblName.ShowAccelChar := False;
    lblName.Caption := param.Name;
    lblName.SetBounds(0, yPos, LLeft - Px(8), ed.Height);
    lblName.Layout := tlCenter;
    if ed is TMemo then
      lblName.Layout := tlTop;

    FParamEditors.Add(ed);
    Inc(yPos, ed.Height + Px(6));
  end;
end;

procedure TFRpNewReportWizardLCL.CommitParamsFromEditors(AValues: TStrings);
var
  i: Integer;
  ed: TWinControl;
  param: TRpDbxConnectionParam;
  v: string;
begin
  AValues.Clear;
  for i := 0 to FParamsList.Count - 1 do
  begin
    param := FParamsList[i];
    if i < FParamEditors.Count then
      ed := FParamEditors[i]
    else
      ed := nil;
    if ed is TComboBox then v := TComboBox(ed).Text
    else if ed is TMemo then v := TMemo(ed).Lines.Text
    else if ed is TEdit then v := TEdit(ed).Text
    else v := param.Value;
    AValues.Values[param.Name] := v;
  end;
end;

function TFRpNewReportWizardLCL.ParamEditor(const AName: string): TWinControl;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FParamsList.Count - 1 do
    if SameText(FParamsList[i].Name, AName) and (i < FParamEditors.Count) then
      Exit(FParamEditors[i]);
end;

procedure TFRpNewReportWizardLCL.DoParamsTest(Sender: TObject);
var
  values, testValues: TStringList;
begin
  if FOperation <> woNone then
    Exit;
  values := TStringList.Create;
  testValues := TStringList.Create;
  try
    CommitParamsFromEditors(values);
    try
      FAdmin.GetTestValues(FState.ConnName, values, testValues);
    except
      on E: Exception do
      begin
        ParamsTested(False, E.Message);
        Exit;
      end;
    end;
    StartConnectionTest(woTestParams, FState.ConnName, testValues);
  finally
    testValues.Free;
    values.Free;
  end;
end;

procedure TFRpNewReportWizardLCL.ParamsTested(ASuccess: Boolean;
  const AMessage: string);
begin
  if ASuccess then
    RpMessageBox(WideString(TR(1772, 'Connection succeeded.')),
      WideString(TR(1773, 'Success')), [smbOK], smsInformation, smbOK, smbOK)
  else
    RpMessageBox(WideString(TR(1774, 'Connection failed: ') + AMessage),
      WideString(TR(1775, 'Connection Error')), [smbOK], smsCritical, smbOK, smbOK);
end;

procedure TFRpNewReportWizardLCL.DoHubLogin(Sender: TObject);
begin
  if FOperation <> woNone then
    Exit;
  FState.HubApiKey := Trim(EdHubApiKey.Text);
  // With a session, no key: the databases of the account
  if (FState.HubApiKey = '') and not HasHubSession then
  begin
    RpMessageBox(WideString(TR(1777, 'Please enter your Reportman AI API key.')),
      WideString(TR(1778, 'Reportman AI')), [smbOK], smsInformation, smbOK, smbOK);
    Exit;
  end;
  LoadHubDatabases;
end;

function TFRpNewReportWizardLCL.HasHubSession: Boolean;
begin
  // As the engine: the token of the session goes when there is no key
  Result := TRpAuthManager.Instance.Token <> '';
end;

procedure TFRpNewReportWizardLCL.DoHubRefresh(Sender: TObject);
begin
  DoHubLogin(Sender);
end;

procedure TFRpNewReportWizardLCL.LoadHubDatabases(AQuiet: Boolean);
var
  LWorker: TRpWizardHubWorker;
begin
  FQuietHubLoad := AQuiet;
  BeginOperation(woHubLogin, TR(1782, 'Contacting Reportman AI...'));
  LWorker := TRpWizardHubWorker.Create(FMailboxRef);
  LWorker.Version := FOperationVersion;
  LWorker.ApiKey := FState.HubApiKey;
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.InstallId := TRpAuthManager.Instance.InstallId;
  LWorker.Start;
end;

procedure TFRpNewReportWizardLCL.FillHubDatabaseCombo;
var
  I: Integer;
begin
  if CbHubDatabase = nil then
    Exit;
  // The names (the VCL shows the name=id lines)
  CbHubDatabase.Items.BeginUpdate;
  try
    CbHubDatabase.Items.Clear;
    for I := 0 to FHubDatabases.Count - 1 do
      CbHubDatabase.Items.Add(FHubDatabases.Names[I]);
  finally
    CbHubDatabase.Items.EndUpdate;
  end;
  if CbHubDatabase.Items.Count > 0 then
    CbHubDatabase.ItemIndex := 0;
end;

procedure TFRpNewReportWizardLCL.ApplyHubDatabases(AOk: Boolean;
  ADatabases: TStrings);
var
  I: Integer;
begin
  if not AOk then
  begin
    RpMessageBox(WideString(TR(1779, 'Could not contact Reportman AI Web. Verify your ' +
      'API key and try again.')), WideString(TR(1778, 'Reportman AI')), [smbOK],
      smsCritical, smbOK, smbOK);
    Exit;
  end;
  FState.HubLoggedIn := True;
  FHubDatabases.Assign(ADatabases);
  FillHubDatabaseCombo;
  // Connection wizard: the Hub database of the report connection
  if (FPreferredHubDatabaseId > 0) and Assigned(CbHubDatabase) then
    for I := 0 to FHubDatabases.Count - 1 do
      if StrToInt64Def(FHubDatabases.ValueFromIndex[I], 0) = FPreferredHubDatabaseId then
        CbHubDatabase.ItemIndex := I;
  if not FQuietHubLoad then
    RpMessageBox(WideString(Format(TR(1780, 'Logged in. Loaded %d connections.'),
      [ADatabases.Count])), WideString(TR(1778, 'Reportman AI')), [smbOK],
      smsInformation, smbOK, smbOK);
end;

procedure TFRpNewReportWizardLCL.BuildPageFinish;
var
  L: TLabel;
begin
  L := NewLabel(Format(TR(1723, 'Example: %s'),
    [TR(1722, SExamplePrompt)]), 0, 12);
  L.Font.Color := clGrayText;

  // Under the example, down to the bottom of the page
  MemoFinishPrompt := TMemo.Create(PContent);
  MemoFinishPrompt.Parent := PContent;
  StackControl(MemoFinishPrompt, 0, 8, True);
  MemoFinishPrompt.AnchorSide[akBottom].Control := PContent;
  MemoFinishPrompt.AnchorSide[akBottom].Side := asrBottom;
  MemoFinishPrompt.BorderSpacing.Bottom := Px(12);
  MemoFinishPrompt.Anchors := [akLeft, akTop, akRight, akBottom];
  MemoFinishPrompt.ScrollBars := ssVertical;
  MemoFinishPrompt.WordWrap := True;
  MemoFinishPrompt.Text := FPendingPrompt;
end;

{ Work in worker threads }

procedure TFRpNewReportWizardLCL.BeginOperation(AOperation: TRpWizardOperation;
  const AStatus: string);
begin
  FOperation := AOperation;
  Inc(FOperationVersion);
  LStatus.Caption := AStatus;
  UpdateNavButtons;
  UpdatePageButtons;
end;

procedure TFRpNewReportWizardLCL.EndOperation;
begin
  FOperation := woNone;
  LStatus.Caption := '';
  UpdateNavButtons;
  UpdatePageButtons;
end;

procedure TFRpNewReportWizardLCL.StartConnectionTest(AOperation: TRpWizardOperation;
  const AConnectionName: string; AValues: TStrings);
var
  LWorker: TRpWizardTestWorker;
begin
  BeginOperation(AOperation, TR(1781, 'Testing connection...'));
  LWorker := TRpWizardTestWorker.Create(FMailboxRef);
  LWorker.Version := FOperationVersion;
  LWorker.ConnectionName := AConnectionName;
  LWorker.Params.Assign(AValues);
  LWorker.Token := TRpAuthManager.Instance.Token;
  LWorker.Start;
end;

procedure TFRpNewReportWizardLCL.HandleAsyncMessage(AMessage: TRpAsyncMessage);
var
  LHub: TRpWizardHubPayload;
  LTest: TRpWizardTestPayload;
  LOperation: TRpWizardOperation;
begin
  if AMessage is TRpWizardHubPayload then
  begin
    LHub := TRpWizardHubPayload(AMessage);
    if (FOperation <> woHubLogin) or (LHub.Version <> FOperationVersion) then
      Exit;
    EndOperation;
    ApplyHubDatabases(LHub.Ok, LHub.Databases);
  end
  else if AMessage is TRpWizardTestPayload then
  begin
    LTest := TRpWizardTestPayload(AMessage);
    if (FOperation = woNone) or (LTest.Version <> FOperationVersion) then
      Exit;
    LOperation := FOperation;
    EndOperation;
    case LOperation of
      woAgentConnection: AgentConnectionTested(LTest.Success, LTest.MessageText);
      woTestExisting: ExistingConnectionTested(LTest.Success, LTest.MessageText);
      woTestParams: ParamsTested(LTest.Success, LTest.MessageText);
    end;
  end;
end;

procedure TFRpNewReportWizardLCL.AgentConnectionTested(ASuccess: Boolean;
  const AMessage: string);
begin
  if not ASuccess then
  begin
    ShowCritical(TR(1757, 'Could not validate the new Reportman AI connection: ') +
      AMessage);
    Exit;
  end;
  if FCurrentPage = wpAgentLogin then
  begin
    if FConnectionMode then
      FinishConnection
    else
      GoTo_Page(NextPageFor(wpAgentLogin), True);
  end;
end;

procedure TFRpNewReportWizardLCL.CommitConnectionToReport;
var
  item: TRpDatabaseInfoItem;
  connectionAlias: string;
begin
  if FDestReport = nil then Exit;
  while FDestReport.DatabaseInfo.Count > 0 do
    FDestReport.DatabaseInfo.Delete(0);

  if FState.Route = wrNoConnection then
    Exit
  else if FState.Route = wrAgent then
  begin
    connectionAlias := Trim(FState.ConnName);
    if connectionAlias = '' then
      connectionAlias := Trim(FState.HubDatabaseName);
    item := FDestReport.DatabaseInfo.Add(connectionAlias);
    item.Driver := rpdbHttp;
    item.Alias := connectionAlias;
  end
  else
  begin
    case FState.DriverFamily of
      dfFireDac:
        begin
          item := FDestReport.DatabaseInfo.Add(FState.ConnName);
          item.Driver := rpfiredac;
          item.Alias := FState.ConnName;
        end;
      dfZeos:
        begin
          item := FDestReport.DatabaseInfo.Add(FState.ConnName);
          item.Driver := rpdatazeos;
          item.Alias := FState.ConnName;
        end;
    end;
  end;
end;

initialization
  RpConnectionWizardFunc := ShowConnectionWizard;
end.

{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfnewreportwizardvcl                         }
{                                                       }
{       Modern New Report wizard                        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfnewreportwizardvcl;

{ File > New of the designer: the connection route (Reportman AI Agent,
  direct database or no connection), the connection, the schema for the AI
  and the prompt for the design assistant.

  The schema for the AI (docs/esquemas-locales-pantalla-plan.md 5.7.1 B) is
  the list of the copilot, after the connection: the subschemas of the local
  schema file of a direct connection (generated from the catalog the first
  time) and the schemas in the cloud (on the Agent route, the ones of its
  Hub database), with "New local schema..." and "New cloud schema...".
  Choosing one is optional; a prompt without one asks to go on without the
  AI. Routes: direct = route, driver, connection (and parameters or ADO
  string), schema, finish; Agent = route, connection (and API key), schema,
  finish.

  The texts are translated with the keys of the Lazarus twin
  (rpmdfnewreportwizardlcl); the ones only the VCL has (dbExpress, BDE,
  Microsoft DAO and its page) stay in English. }

{$I rpconf.inc}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Generics.Collections,
  rptypes, rpreport, rpdatainfo, rpmdconsts, rpgraphutilsvcl,
  rpwebdbxadmin, rpfrmaischemaselectorvcl, rpauthmanager
{$IFDEF USEBDE}
  , dbtables
{$ENDIF}
{$IFDEF USEADO}
  , Data.Win.AdoDb
{$ENDIF}
  ;

type
  TRpWizardRoute = (wrUndefined, wrAgent, wrDirect, wrNoConnection);
  TRpWizardDriverFamily = (
    dfUndefined,
    dfFireDac,
    dfZeos,
    dfDbExpress,
    dfBde,
    dfDao
  );
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
    wpDaoConn,
    wpParams,
    wpFinish
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
    DriverConcrete: string;     // FireDAC DriverID, DBExpress driver, Zeos protocol or BDE alias
    ConnMode: TRpWizardConnMode;
    ConnName: string;
    AdoConnectionString: string;
  end;

  TFRpNewReportWizardVCL = class(TForm)
    PHeader: TPanel;
    LStepTitle: TLabel;
    LStepHelper: TLabel;
    PBottom: TPanel;
    BCancel: TButton;
    BBack: TButton;
    BNext: TButton;
    BFinish: TButton;
    PContent: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure BBackClick(Sender: TObject);
    procedure BNextClick(Sender: TObject);
    procedure BFinishClick(Sender: TObject);
  private
    FState: TRpWizardState;
    FCurrentPage: TRpWizardPage;
    FHistory: TList<TRpWizardPage>;
    FCommitted: Boolean;
    FPendingPrompt: string;
    // The connection this wizard created, and its driver: going Back and
    // Next again reuses it instead of refusing the name as existing
    FCreatedConnName: string;
    FCreatedConnKind: string;
    // Hub databases of the API key (name=id), the combo shows the names
    FHubDatabases: TStringList;
    FAdminService: TRpWebDbxAdminService;
    FDestReport: TRpReport;
    FConnAdmin: TRpConnAdmin;
    // Connection wizard (StartConnectionMode): only the connection pages
    FConnectionMode: Boolean;
    FFixedName: string;
    FPreferredHubDatabaseId: Int64;
    FResultConnection: string;
    FResultDriver: TRpDbDriver;

    // dynamic controls per page
    FCurrentPanel: TPanel;
    // route page
    FRbAgent, FRbDirect, FRbNoConnection: TRadioButton;
    // agent login page
    FEdHubApiKey: TEdit;
    FBtnHubLogin: TButton;
    FBtnHubRefresh: TButton;
    FCbHubDatabase: TComboBox;
    // schema page: why the subschemas of the direct connection could not be
    // read
    FLblLocalSchemaError: TLabel;
    // driver page
    FCbFamily: TComboBox;
    FCbConcrete: TComboBox;
    FLblConcrete: TLabel;
    // conn name page
    FRbExisting, FRbNew: TRadioButton;
    FCbExistingConn: TComboBox;
    FLblExistingConnDriver: TLabel;
    FEdNewConnName: TEdit;
    FBtnTestExisting: TButton;
    // dao page
    FEdAdoConnString: TEdit;
    FBtnDaoBuild: TButton;
    FBtnDaoTest: TButton;
    // params page
    FParamsScroll: TScrollBox;
    FParamsList: TList<TRpWebConnectionParam>;
    FParamEditors: TList<TWinControl>;
    FBtnParamsTest: TButton;
    FLblParamsCaption: TLabel;
    // finish page
    FMemoFinishPrompt: TMemo;
    FAISchemaSelector: TFRpAISchemaSelectorVCL;

    procedure ClearPanel;
    procedure GoTo_Page(APage: TRpWizardPage; APushHistory: Boolean);
    function NextPageFor(APage: TRpWizardPage): TRpWizardPage;
    procedure UpdateNavButtons;
    procedure UpdateHeader(APage: TRpWizardPage);

    // page builders
    procedure BuildPageRoute;
    procedure BuildPageAgentLogin;
    // The schema for the AI (wpAgentSchema, wpDirectSchema)
    procedure BuildPageSchema;
    procedure BuildPageDriver;
    procedure BuildPageConnName;
    procedure BuildPageDaoConn;
    procedure BuildPageParams;
    procedure BuildPageFinish;

    // page validators
    function ValidateAndAdvance: Boolean;

    // helpers
    procedure DoHubLogin(Sender: TObject);
    procedure DoHubRefresh(Sender: TObject);
    procedure DoTestExistingConn(Sender: TObject);
    procedure DoFamilyChange(Sender: TObject);
    procedure DoConnNameModeChange(Sender: TObject);
    procedure DoExistingConnChange(Sender: TObject);
    procedure DoDaoBuild(Sender: TObject);
    procedure DoDaoTest(Sender: TObject);
    procedure DoParamsTest(Sender: TObject);

    // AQuiet: without the "Logged in" message (entering the page)
    procedure LoadHubDatabases(AQuiet: Boolean = False);
    // A Reportman AI session: the API key of an Agent connection is optional
    function HasHubSession: Boolean;
    procedure RefreshConcreteDriver;
    procedure RefreshExistingConnections;
    procedure UpdateExistingConnDriverHint;
    procedure LoadParamsFromAdminService;
    procedure CommitParamsFromEditors(AValues: TStrings);

    function FamilyDriverName: string;
    function FamilyAcceptsParamStep: Boolean;
    function HasReportmanAiSchema: Boolean;
    function ConnectionExists(const AConnectionName: string): Boolean;
    function OwnConnection(const AConnectionName: string): Boolean;
    function TryGetConnectionDetails(const AConnectionName: string;
      out AFamily: TRpWizardDriverFamily; out ADriverHint: string;
      out AHubDatabaseId, AHubSchemaId: Int64; out AApiKey: string): Boolean;
    procedure CommitConnectionToReport;
    function CreateLabel(AOwner: TWinControl; const ACaption: string;
      ALeft, ATop: Integer): TLabel;
    function CreateHyperlinkLabel(AOwner: TWinControl; const ACaption: string;
      ALeft, ATop: Integer; AClick: TNotifyEvent): TLabel;
    procedure OpenAgentDownloadLink(Sender: TObject);
    // "New local schema...": the local schema screen of the connection
    procedure DoNewLocalSchema(Sender: TObject);
    // The subschemas of the direct connection in the list of the schema
    // page (the schema file is generated the first time)
    procedure LoadLocalSchemas;
    procedure DoRouteChange(Sender: TObject);
    function IsImmediateFinishRouteSelected: Boolean;
    procedure FinishWizard;
    // Connection mode: the page that ends the wizard, and its end
    function IsLastConnectionStep: Boolean;
    procedure FinishConnection;
  public
    // Turns the wizard into the connection wizard (before showing it): the
    // connection pages without the schema and the prompt; the report is not
    // changed. AFixedName configures the Reportman AI Agent connection with
    // that name (a connection of a report not configured on this computer);
    // APreferredHubDatabaseId is selected when the API key lists it.
    procedure StartConnectionMode(const AFixedName: string;
      APreferredHubDatabaseId: Int64);
    property PendingPrompt: string read FPendingPrompt;
    property State: TRpWizardState read FState;
  end;

  TRpShowConnectionWizardFunc = function(const AFixedName: string;
    APreferredHubDatabaseId: Int64; out AConnectionName: string;
    out ADriver: TRpDbDriver; out AAdoConnectionString: string): Boolean;
  // The Hub database of a Reportman AI schema when the designer knows it
  // (the schemas of the design chat), 0 otherwise
  TRpHubDatabaseOfSchema = function(AHubSchemaId: Int64): Int64 of object;

// File > New of the designer. True when the user finished the wizard: the
// report has the chosen connection, and the prompt and Hub context are for
// the design chat; ALocalAlias and ALocalSchemaName are the subschema of the
// direct connection chosen ('' = none), which the chat selects before the
// prompt
function NewModernReportWizard(report: TRpReport;
  out APendingPrompt: string;
  out AHubDatabaseId: Int64;
  out AHubSchemaId: Int64;
  out AHubApiKey: string;
  out ALocalAlias: string;
  out ALocalSchemaName: string): Boolean;

// The connection wizard (Data configuration > Add connection, a connection
// of a report not configured on this computer), see StartConnectionMode.
// True when the user finished it: the connection is in the connections file
// (an ADO connection has its connection string instead).
function ShowConnectionWizard(const AFixedName: string;
  APreferredHubDatabaseId: Int64; out AConnectionName: string;
  out ADriver: TRpDbDriver; out AAdoConnectionString: string): Boolean;

var
  // The connection wizard of RpCheckAgentConnections and the data
  // configuration (tests can replace it)
  RpConnectionWizardFunc: TRpShowConnectionWizardFunc = nil;

// Before opening the data (preview, print, Show data): each Reportman AI
// Agent connection of the datasets (the ones opened on start, or
// AOnlyDataset) that can not be opened on this computer is offered to the
// connection wizard, with the Hub database of the schema of its datasets.
// False when the user did not configure one: the data would not open.
function RpCheckAgentConnections(ADatabases: TRpDatabaseInfoList;
  ADataInfo: TRpDataInfoList; AOnlyDataset: TRpDataInfoItem = nil;
  AHubDatabaseOfSchema: TRpHubDatabaseOfSchema = nil): Boolean;

implementation

{$R *.dfm}

uses
  rpdatahttp, rplocalschemas, rpfrmlocalschemasvcl;

const
  // The pages only the VCL has (no key in the Lazarus twin)
  STEP_TITLE_DAO                  = 'ADO Connection String';
  STEP_HELPER_DAO                 = 'Edit the ADO connection string directly or use the builder to generate it.';

  EXAMPLE_PROMPT = 'Sales by customer with a group total and a grand total';

  AGENT_DRIVER_NAME = 'Reportman AI Agent';

// A text of the wizard, with the keys of the Lazarus twin
function TR(AId: Integer; const ADefault: string): string;
begin
  Result := string(TranslateStr(AId, ADefault));
end;

function NewReportTitle: string;
begin
  Result := TR(1131, 'New Report');
end;

function NewModernReportWizard(report: TRpReport;
  out APendingPrompt: string;
  out AHubDatabaseId: Int64;
  out AHubSchemaId: Int64;
  out AHubApiKey: string;
  out ALocalAlias: string;
  out ALocalSchemaName: string): Boolean;
var
  dia: TFRpNewReportWizardVCL;
  i: Integer;
begin
  APendingPrompt := '';
  AHubDatabaseId := 0;
  AHubSchemaId := 0;
  AHubApiKey := '';
  ALocalAlias := '';
  ALocalSchemaName := '';
  dia := TFRpNewReportWizardVCL.Create(Application);
  try
    report.CreateNew;
    report.SubReports[0].SubReport.AddGroup('TOTAL');
    for i := 0 to report.SubReports[0].SubReport.Sections.Count - 1 do
    begin
      report.SubReports[0].SubReport.Sections[i].Section.Height := 275;
    end;
    dia.FDestReport := report;
    dia.ShowModal;
    Result := dia.FCommitted;
    if Result then
    begin
      APendingPrompt := Trim(dia.FPendingPrompt);
      AHubDatabaseId := dia.FState.HubDatabaseId;
      AHubSchemaId := dia.FState.HubSchemaId;
      AHubApiKey := dia.FState.HubApiKey;
      // The subschema of the direct connection of the report
      if (dia.FState.LocalSchemaName <> '') and (report.DatabaseInfo.Count > 0) then
      begin
        ALocalAlias := report.DatabaseInfo.Items[0].Alias;
        ALocalSchemaName := dia.FState.LocalSchemaName;
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
  out ADriver: TRpDbDriver; out AAdoConnectionString: string): Boolean;
var
  dia: TFRpNewReportWizardVCL;
begin
  AConnectionName := '';
  ADriver := rpdbHttp;
  AAdoConnectionString := '';
  dia := TFRpNewReportWizardVCL.Create(Application);
  try
    dia.StartConnectionMode(AFixedName, APreferredHubDatabaseId);
    dia.ShowModal;
    Result := dia.FCommitted;
    if Result then
    begin
      AConnectionName := dia.FResultConnection;
      ADriver := dia.FResultDriver;
      AAdoConnectionString := dia.FState.AdoConnectionString;
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
  LMessage, LName, LAdo: string;
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
      if RpMessageBox(LMessage + sLineBreak + sLineBreak +
        TranslateStr(1830, 'Configure the connection now?'), TR(1778, 'Reportman AI'),
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
      if not RpConnectionWizardFunc(LDatabase.Alias, LPreferred, LName, LDriver,
        LAdo) then
        Exit(False);
      // The next Connect reads the new settings
      LDatabase.UpdateConAdmin;
      LDatabase.DisConnect;
    end;
  finally
    LChecked.Free;
  end;
end;

{ TFRpNewReportWizardVCL }

procedure TFRpNewReportWizardVCL.FormCreate(Sender: TObject);
begin
  FHistory := TList<TRpWizardPage>.Create;
  FHubDatabases := TStringList.Create;
  FParamsList := TList<TRpWebConnectionParam>.Create;
  FParamEditors := TList<TWinControl>.Create;
  FAdminService := TRpWebDbxAdminService.Create;
  FConnAdmin := TRpConnAdmin.Create;
  FState.Route := wrUndefined;
  FState.DriverFamily := dfUndefined;
  FState.ConnMode := cnUndefined;
  FCommitted := False;
  // The texts of the form file, translated as the Lazarus twin
  Caption := NewReportTitle;
  BCancel.Caption := TR(94, 'Cancel');
  BBack.Caption := TR(934, 'Back');
  BNext.Caption := TR(933, 'Next');
  BFinish.Caption := TR(935, 'Finish');
  GoTo_Page(wpRoute, False);
end;

procedure TFRpNewReportWizardVCL.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to FParamsList.Count - 1 do
    if Assigned(FParamsList[i].Options) then
      FParamsList[i].Options.Free;
  FParamsList.Free;
  FParamEditors.Free;
  FHistory.Free;
  FHubDatabases.Free;
  FAdminService.Free;
  FConnAdmin.Free;
end;

procedure TFRpNewReportWizardVCL.StartConnectionMode(const AFixedName: string;
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

function TFRpNewReportWizardVCL.IsLastConnectionStep: Boolean;
begin
  Result := False;
  if not FConnectionMode then
    Exit;
  case FCurrentPage of
    wpAgentLogin, wpParams, wpDaoConn:
      Result := True;
    wpConnName:
      // An existing connection is added as it is
      Result := (Assigned(FRbExisting) and FRbExisting.Checked) or
        ((FState.Route = wrDirect) and ((FState.DriverFamily = dfBde) or
        not FamilyAcceptsParamStep));
  end;
end;

procedure TFRpNewReportWizardVCL.FinishConnection;
begin
  FResultConnection := FState.ConnName;
  if FState.Route = wrAgent then
    FResultDriver := rpdbHttp
  else
  begin
    case FState.DriverFamily of
      dfZeos:
        FResultDriver := rpdatazeos;
      dfDbExpress:
        FResultDriver := rpdatadbexpress;
      dfBde:
        begin
          FResultDriver := rpdatabde;
          FResultConnection := FState.DriverConcrete;
        end;
      dfDao:
        begin
          FResultDriver := rpdataado;
          FResultConnection := 'ADO';
        end;
    else
      FResultDriver := rpfiredac;
    end;
  end;
  FCommitted := True;
  Close;
end;

procedure TFRpNewReportWizardVCL.BCancelClick(Sender: TObject);
begin
  FCommitted := False;
  Close;
end;

procedure TFRpNewReportWizardVCL.BBackClick(Sender: TObject);
var
  prev: TRpWizardPage;
begin
  if FHistory.Count = 0 then
    Exit;
  prev := FHistory[FHistory.Count - 1];
  FHistory.Delete(FHistory.Count - 1);
  GoTo_Page(prev, False);
end;

procedure TFRpNewReportWizardVCL.BNextClick(Sender: TObject);
begin
  if not ValidateAndAdvance then
    Exit;
end;

procedure TFRpNewReportWizardVCL.BFinishClick(Sender: TObject);
begin
  if FCurrentPage <> wpFinish then
  begin
    if not ValidateAndAdvance then
      Exit;
    if FCurrentPage <> wpFinish then
      Exit;
  end;
  FinishWizard;
end;

procedure TFRpNewReportWizardVCL.FinishWizard;
begin
  if FCurrentPage = wpFinish then
    FPendingPrompt := Trim(FMemoFinishPrompt.Lines.Text)
  else
    FPendingPrompt := '';
  // A subschema is only for a direct connection (the route may have changed
  // after choosing one)
  if FState.Route <> wrDirect then
    FState.LocalSchemaName := '';
  // A local subschema or a cloud schema: either one lets the AI design
  if (FPendingPrompt <> '') and not HasReportmanAiSchema then
  begin
    if RpMessageBox(TR(1992, 'You wrote a text for the AI but chose no ' +
      'schema, and the AI needs one. Continue without the AI (design by hand)?'),
      TR(1752, 'Schema required'), [smbYes, smbNo], smsWarning, smbNo,
      smbNo) <> smbYes then
      Exit;
    FPendingPrompt := '';
  end;
  CommitConnectionToReport;
  FCommitted := True;
  Close;
end;

procedure TFRpNewReportWizardVCL.ClearPanel;
var
  i: Integer;
begin
  for i := PContent.ControlCount - 1 downto 0 do
    PContent.Controls[i].Free;
  FCurrentPanel := nil;
  FRbAgent := nil; FRbDirect := nil; FRbNoConnection := nil;
  FEdHubApiKey := nil; FBtnHubLogin := nil;
  FBtnHubRefresh := nil;
  FCbHubDatabase := nil;
  FLblLocalSchemaError := nil;
  FCbFamily := nil; FCbConcrete := nil; FLblConcrete := nil;
  FRbExisting := nil; FRbNew := nil; FCbExistingConn := nil;
  FLblExistingConnDriver := nil;
  FEdNewConnName := nil; FBtnTestExisting := nil;
  FEdAdoConnString := nil; FBtnDaoBuild := nil; FBtnDaoTest := nil;
  FParamsScroll := nil; FBtnParamsTest := nil; FLblParamsCaption := nil;
  FMemoFinishPrompt := nil;
  FAISchemaSelector := nil;
  FParamEditors.Clear;
end;

procedure TFRpNewReportWizardVCL.GoTo_Page(APage: TRpWizardPage; APushHistory: Boolean);
begin
  if APushHistory then
    FHistory.Add(FCurrentPage);
  FCurrentPage := APage;
  ClearPanel;
  case APage of
    wpRoute:                 BuildPageRoute;
    wpAgentLogin:            BuildPageAgentLogin;
    wpAgentSchema,
    wpDirectSchema:          BuildPageSchema;
    wpDriver:                BuildPageDriver;
    wpConnName:              BuildPageConnName;
    wpDaoConn:               BuildPageDaoConn;
    wpParams:                BuildPageParams;
    wpFinish:                BuildPageFinish;
  end;
  UpdateHeader(APage);
  UpdateNavButtons;
end;

procedure TFRpNewReportWizardVCL.UpdateHeader(APage: TRpWizardPage);
begin
  case APage of
    wpRoute:
      begin
        LStepTitle.Caption := TR(1710, 'Connection Route');
        LStepHelper.Caption := TR(1711, 'Choose how this report will get its ' +
          'data. You can connect through Reportman AI for distributed access ' +
          'or directly to a local database.');
      end;
    wpAgentLogin:
      begin
        LStepTitle.Caption := TR(1712, 'Reportman AI Connection');
        LStepHelper.Caption := TR(1713, 'Provide your Reportman AI API key and ' +
          'pick the distributed connection to use.');
      end;
    wpAgentSchema, wpDirectSchema:
      begin
        LStepTitle.Caption := TR(1990, 'Schema for the AI');
        LStepHelper.Caption := TR(1991, 'The AI designs with a subschema of ' +
          'this connection or with a schema in the cloud. Without a schema, ' +
          'the report is designed by hand.');
      end;
    wpDriver:
      begin
        LStepTitle.Caption := TR(1101, 'Database Driver');
        LStepHelper.Caption := TR(1717, 'Choose the driver family and the ' +
          'specific database driver for this direct database connection.');
      end;
    wpConnName:
      begin
        LStepTitle.Caption := TR(400, 'Connection Name');
        LStepHelper.Caption := TR(1718, 'Pick an existing connection or create ' +
          'a new one for this driver.');
      end;
    wpDaoConn:
      begin
        LStepTitle.Caption := TR(1998, STEP_TITLE_DAO);
        LStepHelper.Caption := TR(1999, STEP_HELPER_DAO);
      end;
    wpParams:
      begin
        LStepTitle.Caption := TR(1719, 'Connection Parameters');
        LStepHelper.Caption := TR(1720, 'Edit the connection parameters and ' +
          'test the connection before continuing.');
      end;
    wpFinish:
      begin
        LStepTitle.Caption := TR(935, 'Finish');
        LStepHelper.Caption := TR(1721, 'Describe the report so AI can design ' +
          'it for you. If you selected a schema, AI will obtain the data for ' +
          'you. Leave this text blank if you want to create the report manually.');
      end;
  end;
  // A long helper (the translations are longer than the English) wraps and
  // the header grows to show it whole
  LStepHelper.AutoSize := False;
  LStepHelper.WordWrap := True;
  LStepHelper.Width := PHeader.ClientWidth - 2 * LStepHelper.Left;
  LStepHelper.AutoSize := True;
  PHeader.Height := LStepHelper.Top + LStepHelper.Height + LStepTitle.Top;
end;

procedure TFRpNewReportWizardVCL.UpdateNavButtons;
begin
  BBack.Enabled := FHistory.Count > 0;
  BFinish.Visible := FCurrentPage = wpFinish;
  BFinish.Default := FCurrentPage = wpFinish;
  BNext.Visible := FCurrentPage <> wpFinish;
  BNext.Default := FCurrentPage <> wpFinish;
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

function TFRpNewReportWizardVCL.NextPageFor(APage: TRpWizardPage): TRpWizardPage;
begin
  // The connection wizard: no schema and no prompt (wpFinish ends it)
  if FConnectionMode then
  begin
    case APage of
      wpRoute:
        if FState.Route = wrAgent then Result := wpConnName
        else Result := wpDriver;
      wpDriver:
        if FState.DriverFamily = dfDao then Result := wpDaoConn
        else Result := wpConnName;
      wpConnName:
        if FState.ConnMode = cnExisting then
          Result := wpFinish
        else if FState.Route = wrAgent then
          Result := wpAgentLogin
        else if (FState.DriverFamily <> dfBde) and FamilyAcceptsParamStep then
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
    wpDriver:
      if FState.DriverFamily = dfDao then Result := wpDaoConn
      else                                Result := wpConnName;
    wpConnName:
      begin
        if FState.Route = wrAgent then
        begin
          if FState.ConnMode = cnNew then
            Result := wpAgentLogin
          else
            Result := wpAgentSchema;
        end
        else if FState.DriverFamily = dfBde then
          Result := wpDirectSchema
        else if (FState.ConnMode = cnExisting) and FamilyAcceptsParamStep then
          Result := wpDirectSchema // existing connection, user already tested - skip params
        else if FamilyAcceptsParamStep then
          Result := wpParams
        else
          Result := wpDirectSchema;
      end;
    wpDaoConn:                       Result := wpDirectSchema;
    wpParams:                        Result := wpDirectSchema;
    wpFinish:                        Result := wpFinish;
  else
    Result := wpFinish;
  end;
end;

function TFRpNewReportWizardVCL.ValidateAndAdvance: Boolean;
var
  next: TRpWizardPage;
  trimmedName: string;
  existing: TStringList;
  values: TStringList;
  detectedFamily: TRpWizardDriverFamily;
  driverHint: string;
  hubDatabaseId: Int64;
  hubSchemaId: Int64;
  schemaApiKey: string;
  i: Integer;
  testResult: TRpWebConnectionTestResult;
  newkind: string;
  zeosvalues: TStringList;

  procedure Info(const AText: string);
  begin
    RpMessageBox(AText, NewReportTitle, [smbOK], smsInformation, smbOK, smbOK);
  end;

  procedure Critical(const AText: string);
  begin
    RpMessageBox(AText, NewReportTitle, [smbOK], smsCritical, smbOK, smbOK);
  end;

begin
  Result := False;
  case FCurrentPage of
    wpRoute:
      begin
        if Assigned(FRbAgent) and FRbAgent.Checked then FState.Route := wrAgent
        else if Assigned(FRbDirect) and FRbDirect.Checked then FState.Route := wrDirect
        else if Assigned(FRbNoConnection) and FRbNoConnection.Checked then FState.Route := wrNoConnection
        else
        begin
          Info(TR(1753, 'Please choose a connection route.'));
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
        if Assigned(FEdHubApiKey) then
          FState.HubApiKey := Trim(FEdHubApiKey.Text);
        if (FState.HubApiKey = '') and not HasHubSession then
        begin
          Info(TR(1777, 'Please enter your Reportman AI API key.'));
          Exit;
        end;
        if not FState.HubLoggedIn then
        begin
          Info(TR(1754, 'Please log in to Reportman AI before continuing.'));
          Exit;
        end;
        if FState.ConnMode = cnExisting then
        begin
          if FState.ConnName = '' then
          begin
            Info(TR(1755, 'Please choose an existing Reportman AI connection.'));
            Exit;
          end;
        end
        else if (FCbHubDatabase.ItemIndex < 0) then
        begin
          Info(TR(1756, 'Please choose a Reportman AI connection.'));
          Exit;
        end;
        if FState.ConnMode = cnNew then
        begin
          FState.HubDatabaseName := FHubDatabases.Names[FCbHubDatabase.ItemIndex];
          FState.HubDatabaseId := StrToInt64Def(FHubDatabases.ValueFromIndex[FCbHubDatabase.ItemIndex], 0);
          values := TStringList.Create;
          try
            // A connection of another driver created by this wizard with the
            // same name (Back to the route page) is replaced
            if OwnConnection(FState.ConnName) and
              (not SameText(FCreatedConnKind, AGENT_DRIVER_NAME)) then
            begin
              FAdminService.DeleteConnection(FState.ConnName);
              FCreatedConnName := '';
            end;
            if not ConnectionExists(FState.ConnName) then
            begin
              FAdminService.CreateConnection(FState.ConnName, AGENT_DRIVER_NAME);
              FCreatedConnName := FState.ConnName;
              FCreatedConnKind := AGENT_DRIVER_NAME;
            end;
            values.Values['ApiKey'] := FState.HubApiKey;
            values.Values['HubDatabaseId'] := IntToStr(FState.HubDatabaseId);
            FAdminService.UpdateConnectionParams(FState.ConnName, values);
            testResult := FAdminService.TestConnection(FState.ConnName);
            if not testResult.Success then
            begin
              Critical(TR(1757, 'Could not validate the new Reportman AI connection: ') +
                testResult.MessageText);
              Exit;
            end;
          except
            on E: Exception do
            begin
              values.Free;
              Critical(TR(1758, 'Could not save Reportman AI connection: ') + E.Message);
              Exit;
            end;
          end;
          values.Free;
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
        if FAISchemaSelector <> nil then
        begin
          if FAISchemaSelector.GetHubSchemaId <> 0 then
          begin
            FState.HubDatabaseId := FAISchemaSelector.GetHubDatabaseId;
            FState.HubSchemaId := FAISchemaSelector.GetHubSchemaId;
            FState.HubApiKey := FAISchemaSelector.GetSchemaApiKey;
          end;
          if FState.Route = wrDirect then
            FState.LocalSchemaName := FAISchemaSelector.GetLocalSchemaName;
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
            if (FState.ConnMode = cnNew) and not ConnectionExists(FState.ConnName) then
              FAdminService.CreateConnection(FState.ConnName, AGENT_DRIVER_NAME);
            if Trim(FState.HubApiKey) <> '' then
              values.Values['ApiKey'] := FState.HubApiKey;
            values.Values['HubDatabaseId'] := IntToStr(FState.HubDatabaseId);
            if FState.ConnMode = cnNew then
              FAdminService.UpdateConnectionParams(FState.ConnName, values);
          except
            on E: Exception do
            begin
              values.Free;
              Critical(TR(1758, 'Could not save Reportman AI connection: ') + E.Message);
              Exit;
            end;
          end;
          values.Free;
        end;
      end;
    wpDriver:
      begin
        if FState.DriverFamily = dfUndefined then
        begin
          Info(TR(1761, 'Please choose a driver family.'));
          Exit;
        end;
        if (FState.DriverFamily <> dfDao) then
        begin
          if (FCbConcrete = nil) or (Trim(FCbConcrete.Text) = '') then
          begin
            Info(TR(1762, 'Please choose a specific driver.'));
            Exit;
          end;
          FState.DriverConcrete := Trim(FCbConcrete.Text);
        end;
      end;
    wpConnName:
      begin
        if (FState.Route = wrAgent) and Assigned(FRbExisting) and FRbExisting.Checked then
        begin
          FState.ConnMode := cnExisting;
          if (FCbExistingConn.ItemIndex < 0) then
          begin
            Info(TR(1755, 'Please choose an existing Reportman AI connection.'));
            Exit;
          end;
          FState.ConnName := Trim(FCbExistingConn.Text);
          if not TryGetConnectionDetails(FState.ConnName, detectedFamily,
            driverHint, hubDatabaseId, hubSchemaId, schemaApiKey) then
          begin
            Critical(TR(1763, 'Could not read the selected Reportman AI connection.'));
            Exit;
          end;
          FState.HubDatabaseId := hubDatabaseId;
          FState.HubSchemaId := hubSchemaId;
          FState.HubApiKey := schemaApiKey;
          FState.HubDatabaseName := FState.ConnName;
        end
        else if (FState.Route = wrAgent) and Assigned(FRbNew) and FRbNew.Checked then
        begin
          FState.ConnMode := cnNew;
          trimmedName := Trim(FEdNewConnName.Text);
          if trimmedName = '' then
          begin
            Info(TR(1764, 'Please enter a connection name.'));
            Exit;
          end;
          if ConnectionExists(trimmedName) and (not OwnConnection(trimmedName)) then
          begin
            Info(TR(1765, 'This connection name already exists. Choose a different name.'));
            Exit;
          end;
          FState.ConnName := trimmedName;
        end
        else if Assigned(FRbExisting) and FRbExisting.Checked then
        begin
          FState.ConnMode := cnExisting;
          if (FCbExistingConn.ItemIndex < 0) then
          begin
            Info(TR(1766, 'Please choose an existing connection.'));
            Exit;
          end;
          FState.ConnName := Trim(FCbExistingConn.Text);
        end
        else if Assigned(FRbNew) and FRbNew.Checked then
        begin
          FState.ConnMode := cnNew;
          trimmedName := Trim(FEdNewConnName.Text);
          if trimmedName = '' then
          begin
            Info(TR(1764, 'Please enter a connection name.'));
            Exit;
          end;
          existing := TStringList.Create;
          try
            FConnAdmin.GetConnectionNames(existing, '');
            for i := 0 to existing.Count - 1 do
              if SameText(existing[i], trimmedName) and
                (not OwnConnection(trimmedName)) then
              begin
                Info(TR(1765, 'This connection name already exists. Choose a different name.'));
                Exit;
              end;
          finally
            existing.Free;
          end;
          // create the new connection in DBXConnections (the one created
          // before with this name and the same driver is kept)
          try
            newkind := FamilyDriverName + '/' + FState.DriverConcrete;
            if OwnConnection(trimmedName) and
              (not SameText(FCreatedConnKind, newkind)) then
            begin
              FAdminService.DeleteConnection(trimmedName);
              FCreatedConnName := '';
            end;
            if not OwnConnection(trimmedName) then
            begin
              FAdminService.CreateConnection(trimmedName, FamilyDriverName, FState.DriverConcrete);
              FCreatedConnName := trimmedName;
              FCreatedConnKind := newkind;
              // Zeos: the chosen protocol (the ZeosLib driver defaults to
              // firebird-1.0)
              if FState.DriverFamily = dfZeos then
              begin
                zeosvalues := TStringList.Create;
                try
                  zeosvalues.Values['Database Protocol'] := FState.DriverConcrete;
                  FAdminService.UpdateConnectionParams(trimmedName, zeosvalues);
                finally
                  zeosvalues.Free;
                end;
              end;
            end;
          except
            on E: Exception do
            begin
              Critical(TR(1767, 'Could not create connection: ') + E.Message);
              Exit;
            end;
          end;
          FState.ConnName := trimmedName;
        end
        else
        begin
          Info(TR(1768, 'Please choose Existing or New connection.'));
          Exit;
        end;
      end;
    wpDaoConn:
      begin
        FState.AdoConnectionString := Trim(FEdAdoConnString.Text);
        if FState.AdoConnectionString = '' then
        begin
          Info(TR(2000, 'Please provide an ADO connection string or use Build connection string.'));
          Exit;
        end;
      end;
    wpParams:
      begin
        // Persist edited values into DBXConnections
        values := TStringList.Create;
        try
          CommitParamsFromEditors(values);
          try
            FAdminService.UpdateConnectionParams(FState.ConnName, values);
          except
            on E: Exception do
            begin
              Critical(TR(1769, 'Could not save connection parameters: ') + E.Message);
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
function TFRpNewReportWizardVCL.HasReportmanAiSchema: Boolean;
begin
  Result := (FState.HubSchemaId <> 0) or (FState.LocalSchemaName <> '');
end;

function TFRpNewReportWizardVCL.ConnectionExists(
  const AConnectionName: string): Boolean;
var
  existing: TStringList;
begin
  existing := TStringList.Create;
  try
    FConnAdmin.GetConnectionNames(existing, '');
    Result := existing.IndexOf(Trim(AConnectionName)) >= 0;
  finally
    existing.Free;
  end;
end;

function TFRpNewReportWizardVCL.OwnConnection(
  const AConnectionName: string): Boolean;
begin
  Result := (FCreatedConnName <> '') and
    SameText(Trim(AConnectionName), FCreatedConnName);
end;

function TFRpNewReportWizardVCL.TryGetConnectionDetails(
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
    FConnAdmin.GetConnectionParams(AConnectionName, values);
    if values.Count = 0 then
      Exit;
    driverName := Trim(values.Values['DriverName']);
    protocolName := Trim(values.Values['Protocol']);
    driverId := Trim(values.Values['DriverID']);
    AHubDatabaseId := StrToInt64Def(Trim(values.Values['HubDatabaseId']), 0);
    AHubSchemaId := StrToInt64Def(Trim(values.Values['HubSchemaId']), 0);
    AApiKey := Trim(values.Values['ApiKey']);

    if SameText(driverName, AGENT_DRIVER_NAME) then
    begin
      ADriverHint := 'Reportman AI Agent';
      Result := True;
      Exit;
    end;

    if SameText(driverName, 'FireDac') then
    begin
      AFamily := dfFireDac;
      ADriverHint := 'FireDAC';
      if driverId <> '' then
        ADriverHint := ADriverHint + ' - ' + driverId;
      Result := True;
      Exit;
    end;

    if SameText(driverName, 'ZeosLib') or
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

function TFRpNewReportWizardVCL.FamilyDriverName: string;
begin
  case FState.DriverFamily of
    dfFireDac:   Result := 'FireDac';
    // The Zeos connections are ZeosLib ones (dbxdrivers [ZeosLib], with the
    // Database Protocol): an Interbase one had no protocol and did not open
    dfZeos:      Result := 'ZeosLib';
    dfDbExpress: Result := 'DBExpress';
    dfBde:       Result := 'BDE';
    dfDao:       Result := 'ADO';
  else
    Result := '';
  end;
end;

function TFRpNewReportWizardVCL.FamilyAcceptsParamStep: Boolean;
begin
  Result := FState.DriverFamily in [dfFireDac, dfZeos, dfDbExpress];
end;

function TFRpNewReportWizardVCL.CreateLabel(AOwner: TWinControl;
  const ACaption: string; ALeft, ATop: Integer): TLabel;
begin
  Result := TLabel.Create(AOwner);
  Result.Parent := AOwner;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Caption := ACaption;
end;

function TFRpNewReportWizardVCL.CreateHyperlinkLabel(AOwner: TWinControl;
  const ACaption: string; ALeft, ATop: Integer; AClick: TNotifyEvent): TLabel;
begin
  Result := CreateLabel(AOwner, ACaption, ALeft, ATop);
  Result.Cursor := crHandPoint;
  Result.Font.Color := clBlue;
  Result.Font.Style := [fsUnderline];
  Result.ParentFont := False;
  Result.Transparent := True;
  Result.OnClick := AClick;
end;

procedure TFRpNewReportWizardVCL.OpenAgentDownloadLink(Sender: TObject);
begin
  TRpAuthManager.Instance.OpenAgentDownloadPage;
end;

procedure TFRpNewReportWizardVCL.BuildPageRoute;
var
  L: TLabel;
begin
  FRbAgent := TRadioButton.Create(PContent);
  FRbAgent.Parent := PContent;
  FRbAgent.Left := 24; FRbAgent.Top := 24;
  FRbAgent.Width := 660; FRbAgent.Height := 22;
  FRbAgent.Caption := TR(1724, 'Reportman AI / DB Agent (distributed connection)');
  FRbAgent.Checked := FState.Route = wrAgent;
  FRbAgent.OnClick := DoRouteChange;

  L := CreateLabel(PContent, TR(1725, 'Use a Reportman AI database connection. ' +
    'Recommended when the database is reachable through Reportman AI Web.'),
    48, 50);
  L.Width := 620; L.WordWrap := True;

  // Where the Agent comes from, for those who do not have it yet
  L := CreateLabel(PContent, TR(1823, 'The Reportman Agent is installed as a ' +
    'service on a Windows or Linux computer that can reach your database and ' +
    'gives the designer secure access to it through ai.reportman.es.'),
    48, 86);
  L.Width := 620; L.WordWrap := True;
  CreateHyperlinkLabel(PContent, TR(1822, 'Download Reportman Agent'), 48, 122,
    OpenAgentDownloadLink);

  FRbDirect := TRadioButton.Create(PContent);
  FRbDirect.Parent := PContent;
  FRbDirect.Left := 24; FRbDirect.Top := 156;
  FRbDirect.Width := 660; FRbDirect.Height := 22;
  FRbDirect.Caption := TR(1726, 'Direct database connection');
  FRbDirect.Checked := FState.Route = wrDirect;
  FRbDirect.OnClick := DoRouteChange;

  // The drivers of the VCL (the text of the Lazarus twin names its own)
  L := CreateLabel(PContent,
    TR(1995, 'Connect directly using a local driver (FireDAC, Zeos, DBExpress, BDE or Microsoft DAO).'),
    48, 182);
  L.Width := 620; L.WordWrap := True;

  // The connection wizard adds a connection: no "no connection" route
  if FConnectionMode then
  begin
    UpdateNavButtons;
    Exit;
  end;

  FRbNoConnection := TRadioButton.Create(PContent);
  FRbNoConnection.Parent := PContent;
  FRbNoConnection.Left := 24; FRbNoConnection.Top := 242;
  FRbNoConnection.Width := 660; FRbNoConnection.Height := 22;
  FRbNoConnection.Caption := TR(1728, 'Continue with no connection');
  FRbNoConnection.Checked := FState.Route = wrNoConnection;
  FRbNoConnection.OnClick := DoRouteChange;

  L := CreateLabel(PContent, TR(1729, 'Create a blank report and finish the ' +
    'wizard without selecting or creating any data connection.'),
    48, 268);
  L.Width := 620; L.WordWrap := True;

  UpdateNavButtons;
end;

procedure TFRpNewReportWizardVCL.DoRouteChange(Sender: TObject);
begin
  UpdateNavButtons;
end;

function TFRpNewReportWizardVCL.IsImmediateFinishRouteSelected: Boolean;
begin
  Result := (FCurrentPage = wpRoute) and Assigned(FRbNoConnection) and
    FRbNoConnection.Checked;
end;

procedure TFRpNewReportWizardVCL.BuildPageAgentLogin;
var
  L: TLabel;
  LTop: Integer;
begin
  if FState.ConnMode = cnExisting then
  begin
    L := CreateLabel(PContent,
      Format(TR(1730, 'Existing Reportman AI connection: %s'), [FState.ConnName]),
      24, 24);
    L.Width := 620;
    L.Font.Style := [fsBold];

    L := CreateLabel(PContent, TR(1731, 'Enter your API key to authenticate ' +
      'and load available schemas for this connection.'), 24, 52);
    L.Width := 620;
    L.WordWrap := True;

    CreateLabel(PContent, TR(1732, 'Reportman AI API key'), 24, 104);
    FEdHubApiKey := TEdit.Create(PContent);
    FEdHubApiKey.Parent := PContent;
    FEdHubApiKey.Left := 24; FEdHubApiKey.Top := 124;
    FEdHubApiKey.Width := 480;
    FEdHubApiKey.Text := FState.HubApiKey;
    FEdHubApiKey.PasswordChar := '*';

    FBtnHubLogin := TButton.Create(PContent);
    FBtnHubLogin.Parent := PContent;
    FBtnHubLogin.Left := 514; FBtnHubLogin.Top := 122;
    FBtnHubLogin.Width := 130; FBtnHubLogin.Height := 28;
    FBtnHubLogin.Caption := TR(1783, 'Log in');
    FBtnHubLogin.OnClick := DoHubLogin;
    Exit;
  end;

  // Connection wizard for a connection of the report: its name
  if FFixedName <> '' then
  begin
    L := CreateLabel(PContent, Format(TR(1736,
      'Selected Reportman AI connection: %s'), [FFixedName]), 24, 4);
    L.Font.Style := [fsBold];
  end;
  CreateLabel(PContent, TR(1732, 'Reportman AI API key'), 24, 24);
  FEdHubApiKey := TEdit.Create(PContent);
  FEdHubApiKey.Parent := PContent;
  FEdHubApiKey.Left := 24; FEdHubApiKey.Top := 44;
  FEdHubApiKey.Width := 480;
  FEdHubApiKey.Text := FState.HubApiKey;
  FEdHubApiKey.PasswordChar := '*';

  FBtnHubLogin := TButton.Create(PContent);
  FBtnHubLogin.Parent := PContent;
  FBtnHubLogin.Left := 514; FBtnHubLogin.Top := 42;
  FBtnHubLogin.Width := 130; FBtnHubLogin.Height := 28;
  FBtnHubLogin.Caption := TR(1783, 'Log in');
  FBtnHubLogin.OnClick := DoHubLogin;

  // With a session the key is optional, but the report needs it to run
  // unattended (printreptopdf, server): the engine uses the session otherwise
  if HasHubSession then
    L := CreateLabel(PContent, TR(1831, 'You are signed in to Reportman AI: ' +
      'the API key is optional. Without it the connection uses your session, ' +
      'and the report cannot run unattended on this computer (printreptopdf, ' +
      'server, scheduled tasks).'), 24, 76)
  else
    L := CreateLabel(PContent, TR(1832, 'You are not signed in to Reportman ' +
      'AI: the API key is required.'), 24, 76);
  L.Font.Color := clGrayText;
  L.Width := 620;
  L.WordWrap := True;
  LTop := L.Top + L.Height + 14;

  CreateLabel(PContent, TR(1712, 'Reportman AI Connection'), 24, LTop);
  FCbHubDatabase := TComboBox.Create(PContent);
  FCbHubDatabase.Parent := PContent;
  FCbHubDatabase.Left := 24; FCbHubDatabase.Top := LTop + 20;
  FCbHubDatabase.Width := 480;
  FCbHubDatabase.Style := csDropDownList;

  FBtnHubRefresh := TButton.Create(PContent);
  FBtnHubRefresh.Parent := PContent;
  FBtnHubRefresh.Left := 514; FBtnHubRefresh.Top := LTop + 18;
  FBtnHubRefresh.Width := 130; FBtnHubRefresh.Height := 28;
  FBtnHubRefresh.Caption := TR(1149, 'Refresh');
  FBtnHubRefresh.OnClick := DoHubRefresh;

  // The databases of the session, or of the key of a previous visit
  if HasHubSession or (FState.HubLoggedIn and (Trim(FState.HubApiKey) <> '')) then
    LoadHubDatabases(True);
end;

procedure TFRpNewReportWizardVCL.BuildPageSchema;
var
  LInfo: TLabel;
  LTop: Integer;
begin
  LInfo := nil;
  if (FState.Route = wrAgent) and (Trim(FState.ConnName) <> '') then
    LInfo := CreateLabel(PContent, Format(TR(1736,
      'Selected Reportman AI connection: %s'), [FState.ConnName]), 24, 12)
  else if Trim(FState.ConnName) <> '' then
    LInfo := CreateLabel(PContent, TR(154, 'Connection') + ': ' +
      FState.ConnName, 24, 12);
  if LInfo <> nil then
  begin
    LInfo.Width := 640;
    LInfo.Font.Style := [fsBold];
  end;

  // The list of the copilot: the account card, the subschemas of a direct
  // connection and the schemas in the cloud of the account and of the API
  // key; on the Agent route, the ones of its Hub database
  FAISchemaSelector := TFRpAISchemaSelectorVCL.Create(PContent);
  FAISchemaSelector.Parent := PContent;
  FAISchemaSelector.Align := alTop;
  FAISchemaSelector.AlignWithMargins := True;
  FAISchemaSelector.Margins.Left := 0;
  FAISchemaSelector.Margins.Top := 36;
  FAISchemaSelector.Margins.Right := 0;
  FAISchemaSelector.Margins.Bottom := 24;
  FAISchemaSelector.OnNewLocalSchema := DoNewLocalSchema;
  if FState.Route = wrAgent then
    FAISchemaSelector.CloudDatabaseFilter := FState.HubDatabaseId;
  FAISchemaSelector.SetPreferredConnection(FState.HubDatabaseId, FState.HubApiKey);
  FAISchemaSelector.SetHubContext(FState.HubDatabaseId, FState.HubSchemaId,
    FState.HubApiKey);

  LTop := FAISchemaSelector.Top + FAISchemaSelector.Height + 8;
  FLblLocalSchemaError := CreateLabel(PContent, '', 24, LTop);
  FLblLocalSchemaError.Width := 640;
  FLblLocalSchemaError.WordWrap := True;
  FLblLocalSchemaError.Font.Color := clRed;
  FLblLocalSchemaError.Visible := False;
  if FState.Route = wrDirect then
  begin
    LoadLocalSchemas;
    // The subschema chosen before (Back)
    if FState.LocalSchemaName <> '' then
      FAISchemaSelector.SelectLocalSchema(FState.LocalSchemaName);
  end;
  FAISchemaSelector.LoadSchemas;

  LTop := FAISchemaSelector.Top + FAISchemaSelector.Height + 8;
  FLblLocalSchemaError.Top := LTop;
  if FState.Route = wrAgent then
    CreateHyperlinkLabel(PContent, TR(1738,
      'Install Reportman AI Agent to create new connections'), 24, LTop + 22,
      OpenAgentDownloadLink);
end;

procedure TFRpNewReportWizardVCL.LoadLocalSchemas;
var
  I, LTables, LWidest: Integer;
  LAlias: string;
  LCursor: TCursor;
  LDatabase: TRpDatabaseInfoItem;
  LDatabases: TRpDatabaseInfoList;
  LFile: TRpLocalSchemaFile;
  LNames, LSizes: TStringList;
begin
  if FAISchemaSelector = nil then
    Exit;
  // The connection goes to the report now: its schema file and the local
  // schema screen read it there (Finish commits it again)
  CommitConnectionToReport;
  LDatabase := nil;
  if (FDestReport <> nil) and (FDestReport.DatabaseInfo.Count > 0) then
    LDatabase := FDestReport.DatabaseInfo.Items[0];
  if not RpIsLocalSqlDatabase(LDatabase) then
  begin
    FAISchemaSelector.SetLocalSchemas('', nil, nil);
    Exit;
  end;
  LAlias := LDatabase.Alias;
  LNames := TStringList.Create;
  LSizes := TStringList.Create;
  LCursor := Screen.Cursor;
  try
    if FLblLocalSchemaError <> nil then
      FLblLocalSchemaError.Visible := False;
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
        if FLblLocalSchemaError <> nil then
        begin
          FLblLocalSchemaError.Caption := E.Message;
          FLblLocalSchemaError.Visible := True;
        end;
      end;
    end;
    FAISchemaSelector.SetLocalSchemas(LAlias, LNames, LSizes);
  finally
    Screen.Cursor := LCursor;
    LSizes.Free;
    LNames.Free;
  end;
end;

procedure TFRpNewReportWizardVCL.DoNewLocalSchema(Sender: TObject);
var
  LSchemaName: string;
  LSaved: Boolean;
begin
  if (FDestReport = nil) or (FDestReport.DatabaseInfo.Count = 0) or
    (FAISchemaSelector = nil) then
    Exit;
  LSchemaName := '';
  try
    LSaved := RpShowLocalSchemasDialog(FDestReport,
      FDestReport.DatabaseInfo.Items[0].Alias, LSchemaName, True, nil);
  except
    on E: Exception do
    begin
      RpMessageBox(E.Message, NewReportTitle, [smbOK], smsCritical, smbOK, smbOK);
      Exit;
    end;
  end;
  // The list again, with the subschema saved chosen
  LoadLocalSchemas;
  if LSaved and (LSchemaName <> '') then
    FAISchemaSelector.SelectLocalSchema(LSchemaName);
end;

procedure TFRpNewReportWizardVCL.BuildPageDriver;
begin
  CreateLabel(PContent, TR(1739, 'Driver Family'), 24, 24);
  FCbFamily := TComboBox.Create(PContent);
  FCbFamily.Parent := PContent;
  FCbFamily.Left := 24; FCbFamily.Top := 44;
  FCbFamily.Width := 480;
  FCbFamily.Style := csDropDownList;
  // FireDAC of Delphi (the text of the Lazarus twin names SQLdb)
  FCbFamily.Items.Add(TR(1996, 'FireDAC (Cross-platform) - Recommended'));
  FCbFamily.Items.Add(TR(1741, 'Zeos (Cross-platform)'));
  FCbFamily.Items.Add('DBExpress');
  FCbFamily.Items.Add(TR(1997, 'Borland Database Engine (32-bit only)'));
  FCbFamily.Items.Add('Microsoft DAO');
  case FState.DriverFamily of
    dfFireDac:   FCbFamily.ItemIndex := 0;
    dfZeos:      FCbFamily.ItemIndex := 1;
    dfDbExpress: FCbFamily.ItemIndex := 2;
    dfBde:       FCbFamily.ItemIndex := 3;
    dfDao:       FCbFamily.ItemIndex := 4;
  else
    FCbFamily.ItemIndex := 0;
    FState.DriverFamily := dfFireDac;
  end;
  FCbFamily.OnChange := DoFamilyChange;

  FLblConcrete := CreateLabel(PContent, TR(147, 'Driver'), 24, 92);
  FCbConcrete := TComboBox.Create(PContent);
  FCbConcrete.Parent := PContent;
  FCbConcrete.Left := 24; FCbConcrete.Top := 112;
  FCbConcrete.Width := 480;
  FCbConcrete.Style := csDropDown;
  FCbConcrete.Text := FState.DriverConcrete;

  RefreshConcreteDriver;
end;

procedure TFRpNewReportWizardVCL.DoFamilyChange(Sender: TObject);
begin
  case FCbFamily.ItemIndex of
    0: FState.DriverFamily := dfFireDac;
    1: FState.DriverFamily := dfZeos;
    2: FState.DriverFamily := dfDbExpress;
    3: FState.DriverFamily := dfBde;
    4: FState.DriverFamily := dfDao;
  end;
  FState.DriverConcrete := '';
  if Assigned(FCbConcrete) then
    FCbConcrete.Text := '';
  RefreshConcreteDriver;
end;

procedure TFRpNewReportWizardVCL.RefreshConcreteDriver;
{$IFDEF USEBDE}
var
  aliases: TStringList;
{$ENDIF}
begin
  if FCbConcrete = nil then
    Exit;
  FCbConcrete.Items.Clear;
  case FState.DriverFamily of
    dfFireDac:
      begin
        FLblConcrete.Caption := TR(1742, 'FireDAC DriverID');
        FCbConcrete.Items.CommaText :=
          'MSSQL,MySQL,PG,FB,IB,Ora,SQLite,ASA,DB2,Informix,Teradata,MongoDB,ODBC';
      end;
    dfZeos:
      begin
        FLblConcrete.Caption := TR(1743, 'Zeos protocol');
        FCbConcrete.Items.CommaText :=
          'firebird,interbase,mysql,postgresql,sqlite,oracle,mssql,sybase,ado';
      end;
    dfDbExpress:
      begin
        FLblConcrete.Caption := 'DBExpress driver';
        FAdminService.ListDbExpressDrivers(FCbConcrete.Items);
      end;
    dfBde:
      begin
        FLblConcrete.Caption := 'BDE Alias';
{$IFDEF USEBDE}
        aliases := TStringList.Create;
        try
          Session.GetAliasNames(aliases);
          FCbConcrete.Items.Assign(aliases);
        finally
          aliases.Free;
        end;
{$ENDIF}
      end;
    dfDao:
      begin
        FLblConcrete.Caption := TR(2001, 'No driver selection required for Microsoft DAO');
        FCbConcrete.Enabled := False;
      end;
  end;
  if FState.DriverFamily <> dfDao then
    FCbConcrete.Enabled := True;
end;

procedure TFRpNewReportWizardVCL.BuildPageConnName;
begin
  FRbExisting := TRadioButton.Create(PContent);
  FRbExisting.Parent := PContent;
  FRbExisting.Left := 24; FRbExisting.Top := 16;
  FRbExisting.Width := 660;
  FRbExisting.Caption := TR(1744, 'Existing Connection');
  FRbExisting.Checked := FState.ConnMode <> cnNew;
  FRbExisting.OnClick := DoConnNameModeChange;

  if FState.Route = wrAgent then
    CreateLabel(PContent, TR(1712, 'Reportman AI Connection'), 48, 44)
  else
    CreateLabel(PContent, TR(1745, 'DBX Connection'), 48, 44);
  FCbExistingConn := TComboBox.Create(PContent);
  FCbExistingConn.Parent := PContent;
  FCbExistingConn.Left := 48; FCbExistingConn.Top := 64;
  FCbExistingConn.Width := 460;
  FCbExistingConn.Style := csDropDownList;
  FCbExistingConn.OnChange := DoExistingConnChange;
  RefreshExistingConnections;

  FLblExistingConnDriver := TLabel.Create(PContent);
  FLblExistingConnDriver.Parent := PContent;
  FLblExistingConnDriver.Left := 48;
  FLblExistingConnDriver.Top := 94;
  FLblExistingConnDriver.Width := 460;
  FLblExistingConnDriver.Font.Color := clBlue;
  FLblExistingConnDriver.Visible := False;

  FBtnTestExisting := TButton.Create(PContent);
  FBtnTestExisting.Parent := PContent;
  FBtnTestExisting.Left := 520; FBtnTestExisting.Top := 62;
  FBtnTestExisting.Width := 140; FBtnTestExisting.Height := 28;
  FBtnTestExisting.Caption := TR(1746, 'Test Connection');
  FBtnTestExisting.OnClick := DoTestExistingConn;

  FRbNew := TRadioButton.Create(PContent);
  FRbNew.Parent := PContent;
  FRbNew.Left := 24; FRbNew.Top := 124;
  FRbNew.Width := 660;
  FRbNew.Caption := TR(1102, 'New Connection');
  FRbNew.Checked := FState.ConnMode = cnNew;
  FRbNew.OnClick := DoConnNameModeChange;

  CreateLabel(PContent, TR(400, 'Connection Name'), 48, 152);
  FEdNewConnName := TEdit.Create(PContent);
  FEdNewConnName.Parent := PContent;
  FEdNewConnName.Left := 48; FEdNewConnName.Top := 172;
  FEdNewConnName.Width := 460;
  if FState.ConnMode = cnNew then
    FEdNewConnName.Text := FState.ConnName;

  DoConnNameModeChange(nil);
end;

procedure TFRpNewReportWizardVCL.RefreshExistingConnections;
var
  names: TStringList;
  i: Integer;
  detectedFamily: TRpWizardDriverFamily;
  driverHint: string;
  hubDatabaseId: Int64;
  hubSchemaId: Int64;
  schemaApiKey: string;
begin
  if FCbExistingConn = nil then
    Exit;
  FCbExistingConn.Items.Clear;
  names := TStringList.Create;
  try
    FConnAdmin.GetConnectionNames(names, '');
    for i := 0 to names.Count - 1 do
    begin
      if not TryGetConnectionDetails(names[i], detectedFamily, driverHint,
        hubDatabaseId, hubSchemaId, schemaApiKey) then
        Continue;
      if FState.Route = wrAgent then
      begin
        if SameText(driverHint, 'Reportman AI Agent') then
          FCbExistingConn.Items.Add(names[i]);
      end
      else if detectedFamily = FState.DriverFamily then
        FCbExistingConn.Items.Add(names[i]);
    end;
    if FState.ConnName <> '' then
      FCbExistingConn.ItemIndex := FCbExistingConn.Items.IndexOf(FState.ConnName);
    if (FCbExistingConn.ItemIndex < 0) and (FCbExistingConn.Items.Count > 0) then
      FCbExistingConn.ItemIndex := 0;
  finally
    names.Free;
  end;
  UpdateExistingConnDriverHint;
end;

procedure TFRpNewReportWizardVCL.DoConnNameModeChange(Sender: TObject);
var
  isExisting: Boolean;
begin
  if (FRbExisting = nil) or (FRbNew = nil) then Exit;
  isExisting := FRbExisting.Checked;
  if Assigned(FCbExistingConn) then FCbExistingConn.Enabled := isExisting;
  if Assigned(FBtnTestExisting) then FBtnTestExisting.Enabled := isExisting;
  if Assigned(FLblExistingConnDriver) then
    FLblExistingConnDriver.Visible := isExisting and (FState.Route = wrDirect);
  if Assigned(FEdNewConnName) then FEdNewConnName.Enabled := not isExisting;
  UpdateExistingConnDriverHint;
  // Connection wizard: Finish with an existing connection
  UpdateNavButtons;
end;

procedure TFRpNewReportWizardVCL.DoExistingConnChange(Sender: TObject);
begin
  UpdateExistingConnDriverHint;
end;

procedure TFRpNewReportWizardVCL.UpdateExistingConnDriverHint;
var
  detectedFamily: TRpWizardDriverFamily;
  driverHint: string;
  hubDatabaseId: Int64;
  hubSchemaId: Int64;
  schemaApiKey: string;
begin
  if FLblExistingConnDriver = nil then
    Exit;
  if (FState.Route <> wrDirect) or (FRbExisting = nil) or not FRbExisting.Checked or
    (FCbExistingConn = nil) or (FCbExistingConn.ItemIndex < 0) then
  begin
    FLblExistingConnDriver.Caption := '';
    FLblExistingConnDriver.Visible := False;
    Exit;
  end;
  if TryGetConnectionDetails(FCbExistingConn.Text, detectedFamily, driverHint,
    hubDatabaseId, hubSchemaId, schemaApiKey) then
  begin
    FLblExistingConnDriver.Caption := driverHint;
    FLblExistingConnDriver.Visible := True;
  end
  else
  begin
    FLblExistingConnDriver.Caption := '';
    FLblExistingConnDriver.Visible := False;
  end;
end;

procedure TFRpNewReportWizardVCL.DoTestExistingConn(Sender: TObject);
var
  res: TRpWebConnectionTestResult;
begin
  if (FCbExistingConn = nil) or (FCbExistingConn.ItemIndex < 0) then
  begin
    RpMessageBox(TR(1770, 'Please choose a connection first.'),
      TR(1771, 'Connection Test'), [smbOK], smsInformation, smbOK, smbOK);
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    res := FAdminService.TestConnection(FCbExistingConn.Text);
  finally
    Screen.Cursor := crDefault;
  end;
  if res.Success then
  begin
    RpMessageBox(TR(1772, 'Connection succeeded.'), TR(1773, 'Success'),
      [smbOK], smsInformation, smbOK, smbOK);
    BNext.Caption := TR(1747, 'Finish Connection');
  end
  else
  begin
    RpMessageBox(TR(1774, 'Connection failed: ') + res.MessageText,
      TR(1775, 'Connection Error'), [smbOK], smsCritical, smbOK, smbOK);
    BNext.Caption := TR(1748, 'Edit Connection');
  end;
end;

procedure TFRpNewReportWizardVCL.BuildPageDaoConn;
begin
  CreateLabel(PContent, 'ADO Connection String', 24, 24);
  FEdAdoConnString := TEdit.Create(PContent);
  FEdAdoConnString.Parent := PContent;
  FEdAdoConnString.Left := 24; FEdAdoConnString.Top := 44;
  FEdAdoConnString.Width := 660;
  FEdAdoConnString.Text := FState.AdoConnectionString;

  FBtnDaoBuild := TButton.Create(PContent);
  FBtnDaoBuild.Parent := PContent;
  FBtnDaoBuild.Left := 24; FBtnDaoBuild.Top := 84;
  FBtnDaoBuild.Width := 220; FBtnDaoBuild.Height := 30;
  FBtnDaoBuild.Caption := TR(2002, 'Build Connection String');
  FBtnDaoBuild.OnClick := DoDaoBuild;

  FBtnDaoTest := TButton.Create(PContent);
  FBtnDaoTest.Parent := PContent;
  FBtnDaoTest.Left := 256; FBtnDaoTest.Top := 84;
  FBtnDaoTest.Width := 160; FBtnDaoTest.Height := 30;
  FBtnDaoTest.Caption := TR(1746, 'Test Connection');
  FBtnDaoTest.OnClick := DoDaoTest;
end;

procedure TFRpNewReportWizardVCL.DoDaoBuild(Sender: TObject);
{$IFDEF USEADO}
var
  newstring: string;
{$ENDIF}
begin
{$IFDEF USEADO}
  newstring := PromptDataSource(0, FEdAdoConnString.Text);
  if Trim(newstring) <> '' then
    FEdAdoConnString.Text := newstring;
{$ELSE}
  RpMessageBox(TR(2003, 'ADO support is not available in this build.'), TR(2002, 'Build Connection String'),
    [smbOK], smsInformation, smbOK, smbOK);
{$ENDIF}
end;

procedure TFRpNewReportWizardVCL.DoDaoTest(Sender: TObject);
{$IFDEF USEADO}
var
  cn: TADOConnection;
{$ENDIF}
begin
{$IFDEF USEADO}
  cn := TADOConnection.Create(nil);
  try
    cn.LoginPrompt := False;
    try
      cn.ConnectionString := FEdAdoConnString.Text;
      cn.Open;
      cn.Close;
      RpMessageBox(TR(1772, 'Connection succeeded.'), TR(1773, 'Success'),
        [smbOK], smsInformation, smbOK, smbOK);
    except
      on E: Exception do
        RpMessageBox(TR(1774, 'Connection failed: ') + E.Message,
          TR(1775, 'Connection Error'), [smbOK], smsCritical, smbOK, smbOK);
    end;
  finally
    cn.Free;
  end;
{$ELSE}
  RpMessageBox('ADO support is not available in this build.',
    TR(1771, 'Connection Test'), [smbOK], smsInformation, smbOK, smbOK);
{$ENDIF}
end;

procedure TFRpNewReportWizardVCL.BuildPageParams;
begin
  if FState.ConnMode = cnNew then
    FLblParamsCaption := CreateLabel(PContent,
      Format(TR(1749, 'New Connection "%s"'), [FState.ConnName]), 16, 8)
  else
    FLblParamsCaption := CreateLabel(PContent,
      Format(TR(1750, 'Edit Connection "%s"'), [FState.ConnName]), 16, 8);
  FLblParamsCaption.Font.Style := [fsBold];

  FParamsScroll := TScrollBox.Create(PContent);
  FParamsScroll.Parent := PContent;
  FParamsScroll.Align := alClient;
  FParamsScroll.AlignWithMargins := True;
  FParamsScroll.Margins.Top := 32;
  FParamsScroll.Margins.Bottom := 48;
  FParamsScroll.BorderStyle := bsNone;

  FBtnParamsTest := TButton.Create(PContent);
  FBtnParamsTest.Parent := PContent;
  FBtnParamsTest.Align := alBottom;
  FBtnParamsTest.AlignWithMargins := True;
  FBtnParamsTest.Height := 30;
  FBtnParamsTest.Caption := TR(1746, 'Test Connection');
  FBtnParamsTest.OnClick := DoParamsTest;

  LoadParamsFromAdminService;
end;

procedure TFRpNewReportWizardVCL.LoadParamsFromAdminService;
var
  i: Integer;
  ed: TWinControl;
  edEdit: TEdit;
  edCb: TComboBox;
  edMemo: TMemo;
  yPos: Integer;
  lblName: TLabel;
  param: TRpWebConnectionParam;
  overrides: TStringList;
begin
  // free previous Options lists
  for i := 0 to FParamsList.Count - 1 do
    if Assigned(FParamsList[i].Options) then
      FParamsList[i].Options.Free;
  FParamsList.Clear;
  FParamEditors.Clear;
  for i := FParamsScroll.ControlCount - 1 downto 0 do
    FParamsScroll.Controls[i].Free;

  // For new FireDAC connections we must reseed the param list using the
  // chosen DriverID so FireDAC itself reports the driver-specific parameters
  // (Server, Database, Port, Protocol, etc.). For DBExpress, CreateConnection
  // already stored the concrete driver, so dbxdrivers.ini drives the params.
  // For Zeos, GetConnectionParams uses the stored Protocol.
  overrides := nil;
  try
    if (FState.ConnMode = cnNew) and (FState.DriverFamily = dfFireDac) and
      (Trim(FState.DriverConcrete) <> '') then
    begin
      overrides := TStringList.Create;
      overrides.Values['DriverID'] := FState.DriverConcrete;
    end;
    try
      FAdminService.GetConnectionParams(FState.ConnName, FParamsList, overrides);
    except
      on E: Exception do
      begin
        RpMessageBox(TR(1776, 'Could not load connection parameters: ') +
          E.Message, TR(1719, 'Connection Parameters'), [smbOK], smsCritical,
          smbOK, smbOK);
        Exit;
      end;
    end;
  finally
    overrides.Free;
  end;

  yPos := 8;
  for i := 0 to FParamsList.Count - 1 do
  begin
    param := FParamsList[i];
    lblName := TLabel.Create(FParamsScroll);
    lblName.Parent := FParamsScroll;
    lblName.Left := 8; lblName.Top := yPos + 4;
    lblName.Width := 180;
    lblName.Caption := param.Name;

    // For new connections, the driver family and concrete driver were already
    // chosen in earlier steps; the parameter list shown here is generated by
    // the driver itself (FireDAC/DBX/Zeos), so DriverName/DriverID/DBXDriverName
    // must NOT be editable here -- changing them would invalidate the param set.
    if (FState.ConnMode = cnNew) and
      (SameText(param.Name, 'DriverName') or
       SameText(param.Name, 'DriverID') or
       SameText(param.Name, 'DBXDriverName')) then
    begin
      edEdit := TEdit.Create(FParamsScroll);
      edEdit.Parent := FParamsScroll;
      edEdit.Left := 196; edEdit.Top := yPos;
      edEdit.Width := 460;
      edEdit.ReadOnly := True;
      edEdit.Color := clBtnFace;
      edEdit.TabStop := False;
      edEdit.Text := param.Value;
      ed := edEdit;
      FParamEditors.Add(ed);
      Inc(yPos, 28);
      Continue;
    end;

    case param.EditorKind of
      weCombo:
        begin
          edCb := TComboBox.Create(FParamsScroll);
          edCb.Parent := FParamsScroll;
          edCb.Left := 196; edCb.Top := yPos;
          edCb.Width := 460;
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
          edCb := TComboBox.Create(FParamsScroll);
          edCb.Parent := FParamsScroll;
          edCb.Left := 196; edCb.Top := yPos;
          edCb.Width := 460;
          edCb.Style := csDropDown;
          if Assigned(param.Options) then
            edCb.Items.Assign(param.Options);
          edCb.Text := param.Value;
          ed := edCb;
        end;
      wePassword:
        begin
          edEdit := TEdit.Create(FParamsScroll);
          edEdit.Parent := FParamsScroll;
          edEdit.Left := 196; edEdit.Top := yPos;
          edEdit.Width := 460;
          edEdit.PasswordChar := '*';
          edEdit.Text := param.Value;
          ed := edEdit;
        end;
      weTextArea:
        begin
          edMemo := TMemo.Create(FParamsScroll);
          edMemo.Parent := FParamsScroll;
          edMemo.Left := 196; edMemo.Top := yPos;
          edMemo.Width := 460; edMemo.Height := 60;
          edMemo.ScrollBars := ssVertical;
          edMemo.Text := param.Value;
          ed := edMemo;
        end;
      weReadOnly:
        begin
          edEdit := TEdit.Create(FParamsScroll);
          edEdit.Parent := FParamsScroll;
          edEdit.Left := 196; edEdit.Top := yPos;
          edEdit.Width := 460;
          edEdit.ReadOnly := True;
          edEdit.Color := clBtnFace;
          edEdit.Text := param.Value;
          ed := edEdit;
        end;
    else
      begin
        edEdit := TEdit.Create(FParamsScroll);
        edEdit.Parent := FParamsScroll;
        edEdit.Left := 196; edEdit.Top := yPos;
        edEdit.Width := 460;
        edEdit.Text := param.Value;
        ed := edEdit;
      end;
    end;
    FParamEditors.Add(ed);
    if ed is TMemo then Inc(yPos, 68) else Inc(yPos, 28);
  end;
end;

procedure TFRpNewReportWizardVCL.CommitParamsFromEditors(AValues: TStrings);
var
  i: Integer;
  ed: TWinControl;
  param: TRpWebConnectionParam;
  v: string;
begin
  AValues.Clear;
  for i := 0 to FParamsList.Count - 1 do
  begin
    param := FParamsList[i];
    ed := FParamEditors[i];
    if ed is TComboBox then v := TComboBox(ed).Text
    else if ed is TMemo then v := TMemo(ed).Lines.Text
    else if ed is TEdit then v := TEdit(ed).Text
    else v := param.Value;
    AValues.Values[param.Name] := v;
  end;
end;

procedure TFRpNewReportWizardVCL.DoParamsTest(Sender: TObject);
var
  values: TStringList;
  res: TRpWebConnectionTestResult;
begin
  values := TStringList.Create;
  try
    CommitParamsFromEditors(values);
    Screen.Cursor := crHourGlass;
    try
      res := FAdminService.TestConnectionValues(FState.ConnName, values);
    finally
      Screen.Cursor := crDefault;
    end;
    if res.Success then
      RpMessageBox(TR(1772, 'Connection succeeded.'), TR(1773, 'Success'),
        [smbOK], smsInformation, smbOK, smbOK)
    else
      RpMessageBox(TR(1774, 'Connection failed: ') + res.MessageText,
        TR(1775, 'Connection Error'), [smbOK], smsCritical, smbOK, smbOK);
  finally
    values.Free;
  end;
end;

procedure TFRpNewReportWizardVCL.DoHubLogin(Sender: TObject);
begin
  FState.HubApiKey := Trim(FEdHubApiKey.Text);
  // With a session, no key: the databases of the account
  if (FState.HubApiKey = '') and not HasHubSession then
  begin
    RpMessageBox(TR(1777, 'Please enter your Reportman AI API key.'),
      TR(1778, 'Reportman AI'), [smbOK], smsInformation, smbOK, smbOK);
    Exit;
  end;
  LoadHubDatabases;
end;

function TFRpNewReportWizardVCL.HasHubSession: Boolean;
begin
  // As the engine: the token of the session goes when there is no key
  Result := TRpAuthManager.Instance.Token <> '';
end;

procedure TFRpNewReportWizardVCL.DoHubRefresh(Sender: TObject);
begin
  DoHubLogin(Sender);
end;

procedure TFRpNewReportWizardVCL.LoadHubDatabases(AQuiet: Boolean);
var
  list: TStringList;
  i: Integer;
begin
  list := TStringList.Create;
  try
    Screen.Cursor := crHourGlass;
    try
      if not TRpDatabaseHttp.GetHubDatabases(FState.HubApiKey, list) then
      begin
        RpMessageBox(TR(1779, 'Could not contact Reportman AI Web. Verify ' +
          'your API key and try again.'), TR(1778, 'Reportman AI'), [smbOK],
          smsCritical, smbOK, smbOK);
        Exit;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    FState.HubLoggedIn := True;
    FHubDatabases.Assign(list);
    if Assigned(FCbHubDatabase) then
    begin
      // The names (the list has name=id lines)
      FCbHubDatabase.Items.Clear;
      for i := 0 to list.Count - 1 do
        FCbHubDatabase.Items.Add(list.Names[i]);
      if FCbHubDatabase.Items.Count > 0 then
        FCbHubDatabase.ItemIndex := 0;
      // Connection wizard: the Hub database of the report connection
      if FPreferredHubDatabaseId > 0 then
        for i := 0 to list.Count - 1 do
          if StrToInt64Def(list.ValueFromIndex[i], 0) = FPreferredHubDatabaseId then
            FCbHubDatabase.ItemIndex := i;
    end;
    if not AQuiet then
      RpMessageBox(Format(TR(1780, 'Logged in. Loaded %d connections.'),
        [list.Count]), TR(1778, 'Reportman AI'), [smbOK], smsInformation,
        smbOK, smbOK);
  finally
    list.Free;
  end;
end;

procedure TFRpNewReportWizardVCL.BuildPageFinish;
var
  L: TLabel;
begin
  L := CreateLabel(PContent, Format(TR(1723, 'Example: %s'),
    [TR(1722, EXAMPLE_PROMPT)]), 24, 16);
  L.Font.Color := clGrayText;
  L.Width := 660; L.WordWrap := True;

  FMemoFinishPrompt := TMemo.Create(PContent);
  FMemoFinishPrompt.Parent := PContent;
  FMemoFinishPrompt.Left := 24; FMemoFinishPrompt.Top := 48;
  FMemoFinishPrompt.Width := 660;
  FMemoFinishPrompt.Height := 320;
  FMemoFinishPrompt.Anchors := [akLeft, akTop, akRight, akBottom];
  FMemoFinishPrompt.ScrollBars := ssVertical;
  FMemoFinishPrompt.Text := FPendingPrompt;
end;

procedure TFRpNewReportWizardVCL.CommitConnectionToReport;
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
      dfDbExpress:
        begin
          item := FDestReport.DatabaseInfo.Add(FState.ConnName);
          item.Driver := rpdatadbexpress;
          item.Alias := FState.ConnName;
        end;
      dfBde:
        begin
          item := FDestReport.DatabaseInfo.Add(FState.DriverConcrete);
          item.Driver := rpdatabde;
          item.Alias := FState.DriverConcrete;
        end;
      dfDao:
        begin
          item := FDestReport.DatabaseInfo.Add('ADO');
          item.Driver := rpdataado;
          item.ADOConnectionString := FState.AdoConnectionString;
        end;
    end;
  end;
end;

initialization
  RpConnectionWizardFunc := ShowConnectionWizard;
end.

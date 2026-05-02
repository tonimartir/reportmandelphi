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

{$I rpconf.inc}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Generics.Collections,
  rptypes, rpreport, rpdatainfo, rpmdconsts, rpgraphutilsvcl,
  rpwebdbxadmin, rpfrmaischemaselectorvcl
{$IFDEF USEBDE}
  , dbtables
{$ENDIF}
{$IFDEF USEADO}
  , Data.Win.AdoDb
{$ENDIF}
  ;

type
  TRpWizardRoute = (wrUndefined, wrAgent, wrDirect);
  TRpWizardDriverFamily = (
    dfUndefined,
    dfFireDac,
    dfZeos,
    dfDbExpress,
    dfBde,
    dfDao
  );
  TRpWizardSchemaMode = (smNotChosen, smHasSchema, smNoSchema);
  TRpWizardConnMode = (cnUndefined, cnExisting, cnNew);

  TRpWizardPage = (
    wpRoute,
    wpAgentLogin,
    wpAgentSchema,
    wpDirectSchemaQuestion,
    wpDirectSchemaLogin,
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
    SchemaMode: TRpWizardSchemaMode;
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
    FAdminService: TRpWebDbxAdminService;
    FDestReport: TRpReport;
    FConnAdmin: TRpConnAdmin;

    // dynamic controls per page
    FCurrentPanel: TPanel;
    // route page
    FRbAgent, FRbDirect: TRadioButton;
    // agent / direct schema pages
    FEdHubApiKey: TEdit;
    FBtnHubLogin: TButton;
    FCbHubDatabase: TComboBox;
    FCbHubSchema: TComboBox;
    // schema question
    FRbHasSchema, FRbNoSchema: TRadioButton;
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
    procedure BuildPageAgentSchema;
    procedure BuildPageDirectSchemaQuestion;
    procedure BuildPageDirectSchemaLogin;
    procedure BuildPageDirectSchema;
    procedure BuildPageSharedSchemaSelector;
    procedure BuildPageDriver;
    procedure BuildPageConnName;
    procedure BuildPageDaoConn;
    procedure BuildPageParams;
    procedure BuildPageFinish;

    // page validators
    function ValidateAndAdvance: Boolean;

    // helpers
    procedure DoHubLogin(Sender: TObject);
    procedure DoTestExistingConn(Sender: TObject);
    procedure DoFamilyChange(Sender: TObject);
    procedure DoConnNameModeChange(Sender: TObject);
    procedure DoExistingConnChange(Sender: TObject);
    procedure DoDaoBuild(Sender: TObject);
    procedure DoDaoTest(Sender: TObject);
    procedure DoParamsTest(Sender: TObject);

    procedure LoadHubDatabases;
    procedure LoadUserSchemas;
    procedure ParseHubSchemaValue(const AValue: string;
      out ADatabaseId, ASchemaId: Int64);
    procedure RefreshConcreteDriver;
    procedure RefreshExistingConnections;
    procedure UpdateExistingConnDriverHint;
    procedure LoadParamsFromAdminService;
    procedure CommitParamsFromEditors(AValues: TStrings);

    function FamilyDriverName: string;
    function FamilyAcceptsParamStep: Boolean;
    function HasReportmanAiSchema: Boolean;
    function ConnectionExists(const AConnectionName: string): Boolean;
    function TryGetConnectionDetails(const AConnectionName: string;
      out AFamily: TRpWizardDriverFamily; out ADriverHint: string;
      out AHubDatabaseId, AHubSchemaId: Int64; out AApiKey: string): Boolean;
    procedure CommitConnectionToReport;
    function CreateLabel(AOwner: TWinControl; const ACaption: string;
      ALeft, ATop: Integer): TLabel;
  public
    property PendingPrompt: string read FPendingPrompt;
    property State: TRpWizardState read FState;
  end;

function NewModernReportWizard(report: TRpReport;
  out APendingPrompt: string;
  out AHubDatabaseId: Int64;
  out AHubSchemaId: Int64;
  out AHubApiKey: string): Boolean;

implementation

{$R *.dfm}

uses
  rpdatahttp;

const
  // English captions follow the persisted plan exactly.
  STEP_TITLE_ROUTE                = 'Connection Route';
  STEP_HELPER_ROUTE               = 'Choose how this report will get its data. You can connect through Reportman AI for distributed access or directly to a local database.';
  STEP_TITLE_AGENT_LOGIN          = 'Reportman AI Connection';
  STEP_HELPER_AGENT_LOGIN         = 'Provide your Reportman AI API key and pick the distributed connection to use.';
  STEP_TITLE_AGENT_SCHEMA         = 'Schema';
  STEP_HELPER_AGENT_SCHEMA        = 'Pick the schema for the selected Reportman AI connection. Schemas are managed in Reportman AI Web database schemas.';
  STEP_TITLE_DIRECT_SCHEMAQ       = 'Schema';
  STEP_HELPER_DIRECT_SCHEMAQ      = 'Does this direct database connection already have a schema defined in Reportman AI?';
  STEP_TITLE_DIRECT_SCHEMALOGIN   = 'Schema';
  STEP_HELPER_DIRECT_SCHEMALOGIN  = 'Provide your Reportman AI API key to load the schema for this direct connection.';
  STEP_TITLE_DRIVER               = 'Database Driver';
  STEP_HELPER_DRIVER              = 'Choose the driver family and the specific database driver for this direct database connection.';
  STEP_TITLE_CONNNAME             = 'Connection Name';
  STEP_HELPER_CONNNAME            = 'Pick an existing connection or create a new one for this driver.';
  STEP_TITLE_DAO                  = 'ADO Connection String';
  STEP_HELPER_DAO                 = 'Edit the ADO connection string directly or use the builder to generate it.';
  STEP_TITLE_PARAMS               = 'Connection Parameters';
  STEP_HELPER_PARAMS              = 'Edit the connection parameters and test the connection before continuing.';
  STEP_TITLE_FINISH               = 'Finish';
  STEP_HELPER_FINISH              = 'Describe the report so AI can design it for you. If you selected a schema, AI will obtain the data for you. Leave this text blank if you want to create the report manually.';

  EXAMPLE_PROMPT = 'Sales by customer with a group total and a grand total';

  AGENT_DRIVER_NAME = 'Reportman AI Agent';

function NewModernReportWizard(report: TRpReport;
  out APendingPrompt: string;
  out AHubDatabaseId: Int64;
  out AHubSchemaId: Int64;
  out AHubApiKey: string): Boolean;
var
  dia: TFRpNewReportWizardVCL;
  i: Integer;
begin
  APendingPrompt := '';
  AHubDatabaseId := 0;
  AHubSchemaId := 0;
  AHubApiKey := '';
  Result := False;
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
      if report.DataInfo.Count > 0 then
        report.SubReports[0].SubReport.Alias := report.DataInfo.Items[0].Alias;
    end;
  finally
    dia.Free;
  end;
end;

{ TFRpNewReportWizardVCL }

procedure TFRpNewReportWizardVCL.FormCreate(Sender: TObject);
begin
  FHistory := TList<TRpWizardPage>.Create;
  FParamsList := TList<TRpWebConnectionParam>.Create;
  FParamEditors := TList<TWinControl>.Create;
  FAdminService := TRpWebDbxAdminService.Create;
  FConnAdmin := TRpConnAdmin.Create;
  FState.Route := wrUndefined;
  FState.SchemaMode := smNotChosen;
  FState.DriverFamily := dfUndefined;
  FState.ConnMode := cnUndefined;
  FCommitted := False;
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
  FAdminService.Free;
  FConnAdmin.Free;
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
  FPendingPrompt := Trim(FMemoFinishPrompt.Lines.Text);
  if (FPendingPrompt <> '') and not HasReportmanAiSchema then
  begin
    if RpMessageBox(
      'You provided a prompt for AI but no Reportman AI schema is selected. AI generation requires a schema. Continue without AI (manual design)?',
      'Schema required', [smbYes, smbNo], smsWarning, smbNo, smbNo) <> smbYes then
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
  FRbAgent := nil; FRbDirect := nil;
  FEdHubApiKey := nil; FBtnHubLogin := nil;
  FCbHubDatabase := nil; FCbHubSchema := nil;
  FRbHasSchema := nil; FRbNoSchema := nil;
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
    wpAgentSchema:           BuildPageAgentSchema;
    wpDirectSchemaQuestion:  BuildPageDirectSchemaQuestion;
    wpDirectSchemaLogin:     BuildPageDirectSchemaLogin;
    wpDirectSchema:          BuildPageDirectSchema;
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
      begin LStepTitle.Caption := STEP_TITLE_ROUTE;
            LStepHelper.Caption := STEP_HELPER_ROUTE; end;
    wpAgentLogin:
      begin LStepTitle.Caption := STEP_TITLE_AGENT_LOGIN;
            LStepHelper.Caption := STEP_HELPER_AGENT_LOGIN; end;
    wpAgentSchema:
      begin LStepTitle.Caption := STEP_TITLE_AGENT_SCHEMA;
            LStepHelper.Caption := STEP_HELPER_AGENT_SCHEMA; end;
    wpDirectSchemaQuestion:
      begin LStepTitle.Caption := STEP_TITLE_DIRECT_SCHEMAQ;
            LStepHelper.Caption := STEP_HELPER_DIRECT_SCHEMAQ; end;
    wpDirectSchemaLogin:
      begin LStepTitle.Caption := STEP_TITLE_DIRECT_SCHEMALOGIN;
            LStepHelper.Caption := STEP_HELPER_DIRECT_SCHEMALOGIN; end;
    wpDirectSchema:
      begin LStepTitle.Caption := STEP_TITLE_AGENT_SCHEMA;
            LStepHelper.Caption := STEP_HELPER_AGENT_SCHEMA; end;
    wpDriver:
      begin LStepTitle.Caption := STEP_TITLE_DRIVER;
            LStepHelper.Caption := STEP_HELPER_DRIVER; end;
    wpConnName:
      begin LStepTitle.Caption := STEP_TITLE_CONNNAME;
            LStepHelper.Caption := STEP_HELPER_CONNNAME; end;
    wpDaoConn:
      begin LStepTitle.Caption := STEP_TITLE_DAO;
            LStepHelper.Caption := STEP_HELPER_DAO; end;
    wpParams:
      begin LStepTitle.Caption := STEP_TITLE_PARAMS;
            LStepHelper.Caption := STEP_HELPER_PARAMS; end;
    wpFinish:
      begin LStepTitle.Caption := STEP_TITLE_FINISH;
            LStepHelper.Caption := STEP_HELPER_FINISH; end;
  end;
end;

procedure TFRpNewReportWizardVCL.UpdateNavButtons;
begin
  BBack.Enabled := FHistory.Count > 0;
  BFinish.Visible := FCurrentPage = wpFinish;
  BFinish.Default := FCurrentPage = wpFinish;
  BNext.Visible := FCurrentPage <> wpFinish;
  BNext.Default := FCurrentPage <> wpFinish;
end;

function TFRpNewReportWizardVCL.NextPageFor(APage: TRpWizardPage): TRpWizardPage;
begin
  case APage of
    wpRoute:
      if FState.Route = wrAgent then Result := wpConnName
      else                           Result := wpDirectSchemaQuestion;
    wpAgentLogin:                    Result := wpAgentSchema;
    wpAgentSchema:                   Result := wpFinish;
    wpDirectSchemaQuestion:
      if FState.SchemaMode = smHasSchema then Result := wpDirectSchema
      else                                    Result := wpDriver;
    wpDirectSchemaLogin:             Result := wpDirectSchema;
    wpDirectSchema:                  Result := wpDriver;
    wpDriver:
      if FState.DriverFamily = dfDao then Result := wpDaoConn
      else                                Result := wpConnName;
    wpConnName:
      begin
        if FState.Route = wrAgent then
        begin
          Result := wpAgentSchema;
        end
        else if FState.DriverFamily = dfBde then
          Result := wpFinish
        else if (FState.ConnMode = cnExisting) and FamilyAcceptsParamStep then
          Result := wpFinish // existing connection, user already tested - skip params
        else if FamilyAcceptsParamStep then
          Result := wpParams
        else
          Result := wpFinish;
      end;
    wpDaoConn:                       Result := wpFinish;
    wpParams:                        Result := wpFinish;
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
begin
  Result := False;
  case FCurrentPage of
    wpRoute:
      begin
        if Assigned(FRbAgent) and FRbAgent.Checked then FState.Route := wrAgent
        else if Assigned(FRbDirect) and FRbDirect.Checked then FState.Route := wrDirect
        else
        begin
          RpMessageBox('Please choose a connection route.', 'New Report',
            [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
      end;
    wpAgentLogin:
      begin
        if not FState.HubLoggedIn then
        begin
          RpMessageBox('Please log in to Reportman AI before continuing.',
            'New Report', [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
        if FState.ConnMode = cnExisting then
        begin
          if FState.ConnName = '' then
          begin
            RpMessageBox('Please choose an existing Reportman AI connection.',
              'New Report', [smbOK], smsInformation, smbOK, smbOK);
            Exit;
          end;
        end
        else if (FCbHubDatabase.ItemIndex < 0) then
        begin
          RpMessageBox('Please choose a Reportman AI connection.',
            'New Report', [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
        if FState.ConnMode = cnNew then
        begin
          FState.HubDatabaseName := FCbHubDatabase.Items.Names[FCbHubDatabase.ItemIndex];
          FState.HubDatabaseId := StrToInt64Def(FCbHubDatabase.Items.ValueFromIndex[FCbHubDatabase.ItemIndex], 0);
          values := TStringList.Create;
          try
            if not ConnectionExists(FState.ConnName) then
              FAdminService.CreateConnection(FState.ConnName, AGENT_DRIVER_NAME);
            values.Values['ApiKey'] := FState.HubApiKey;
            values.Values['HubDatabaseId'] := IntToStr(FState.HubDatabaseId);
            FAdminService.UpdateConnectionParams(FState.ConnName, values);
          except
            on E: Exception do
            begin
              values.Free;
              RpMessageBox('Could not save Reportman AI connection: ' + E.Message,
                'New Report', [smbOK], smsCritical, smbOK, smbOK);
              Exit;
            end;
          end;
          values.Free;
        end;
      end;
    wpAgentSchema, wpDirectSchema:
      begin
        if (FAISchemaSelector = nil) or (FAISchemaSelector.GetHubSchemaId = 0) then
        begin
          RpMessageBox('Please choose a schema.', 'New Report',
            [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
        FState.HubDatabaseId := FAISchemaSelector.GetHubDatabaseId;
        FState.HubSchemaId := FAISchemaSelector.GetHubSchemaId;
        FState.HubApiKey := FAISchemaSelector.GetSchemaApiKey;

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
              RpMessageBox('Could not save Reportman AI connection: ' + E.Message,
                'New Report', [smbOK], smsCritical, smbOK, smbOK);
              Exit;
            end;
          end;
          values.Free;
        end;
      end;
    wpDirectSchemaQuestion:
      begin
        if Assigned(FRbHasSchema) and FRbHasSchema.Checked then FState.SchemaMode := smHasSchema
        else if Assigned(FRbNoSchema) and FRbNoSchema.Checked then FState.SchemaMode := smNoSchema
        else
        begin
          RpMessageBox('Please choose Yes or No.', 'New Report',
            [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
      end;
    wpDirectSchemaLogin:
      begin
        if not FState.HubLoggedIn then
        begin
          RpMessageBox('Please log in to Reportman AI before continuing.',
            'New Report', [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
      end;
    wpDriver:
      begin
        if FState.DriverFamily = dfUndefined then
        begin
          RpMessageBox('Please choose a driver family.', 'New Report',
            [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
        if (FState.DriverFamily <> dfDao) then
        begin
          if (FCbConcrete = nil) or (Trim(FCbConcrete.Text) = '') then
          begin
            RpMessageBox('Please choose a specific driver.', 'New Report',
              [smbOK], smsInformation, smbOK, smbOK);
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
            RpMessageBox('Please choose an existing Reportman AI connection.',
              'New Report', [smbOK], smsInformation, smbOK, smbOK);
            Exit;
          end;
          FState.ConnName := Trim(FCbExistingConn.Text);
          if not TryGetConnectionDetails(FState.ConnName, detectedFamily,
            driverHint, hubDatabaseId, hubSchemaId, schemaApiKey) then
          begin
            RpMessageBox('Could not read the selected Reportman AI connection.',
              'New Report', [smbOK], smsCritical, smbOK, smbOK);
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
            RpMessageBox('Please enter a connection name.', 'New Report',
              [smbOK], smsInformation, smbOK, smbOK);
            Exit;
          end;
          if ConnectionExists(trimmedName) then
          begin
            RpMessageBox('This connection name already exists. Choose a different name.',
              'New Report', [smbOK], smsInformation, smbOK, smbOK);
            Exit;
          end;
          FState.ConnName := trimmedName;
        end
        else if Assigned(FRbExisting) and FRbExisting.Checked then
        begin
          FState.ConnMode := cnExisting;
          if (FCbExistingConn.ItemIndex < 0) then
          begin
            RpMessageBox('Please choose an existing connection.',
              'New Report', [smbOK], smsInformation, smbOK, smbOK);
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
            RpMessageBox('Please enter a connection name.', 'New Report',
              [smbOK], smsInformation, smbOK, smbOK);
            Exit;
          end;
          existing := TStringList.Create;
          try
            FConnAdmin.GetConnectionNames(existing, '');
            for i := 0 to existing.Count - 1 do
              if SameText(existing[i], trimmedName) then
              begin
                RpMessageBox('This connection name already exists. Choose a different name.',
                  'New Report', [smbOK], smsInformation, smbOK, smbOK);
                Exit;
              end;
          finally
            existing.Free;
          end;
          // create the new connection in DBXConnections
          try
            FAdminService.CreateConnection(trimmedName, FamilyDriverName, FState.DriverConcrete);
          except
            on E: Exception do
            begin
              RpMessageBox('Could not create connection: ' + E.Message,
                'New Report', [smbOK], smsCritical, smbOK, smbOK);
              Exit;
            end;
          end;
          FState.ConnName := trimmedName;
        end
        else
        begin
          RpMessageBox('Please choose Existing or New connection.',
            'New Report', [smbOK], smsInformation, smbOK, smbOK);
          Exit;
        end;
      end;
    wpDaoConn:
      begin
        FState.AdoConnectionString := Trim(FEdAdoConnString.Text);
        if FState.AdoConnectionString = '' then
        begin
          RpMessageBox('Please provide an ADO connection string or use Build connection string.',
            'New Report', [smbOK], smsInformation, smbOK, smbOK);
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
              RpMessageBox('Could not save connection parameters: ' + E.Message,
                'New Report', [smbOK], smsCritical, smbOK, smbOK);
              Exit;
            end;
          end;
        finally
          values.Free;
        end;
      end;
  end;

  next := NextPageFor(FCurrentPage);
  GoTo_Page(next, True);
  Result := True;
end;

function TFRpNewReportWizardVCL.HasReportmanAiSchema: Boolean;
begin
  Result := (FState.HubSchemaId <> 0);
end;

function TFRpNewReportWizardVCL.ConnectionExists(
  const AConnectionName: string): Boolean;
var
  existing: TStringList;
begin
  Result := False;
  existing := TStringList.Create;
  try
    FConnAdmin.GetConnectionNames(existing, '');
    Result := existing.IndexOf(Trim(AConnectionName)) >= 0;
  finally
    existing.Free;
  end;
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
    dfZeos:      Result := 'Interbase';   // Zeos shares semantics with Interbase family in this codebase
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

procedure TFRpNewReportWizardVCL.BuildPageRoute;
var
  L: TLabel;
begin
  FRbAgent := TRadioButton.Create(PContent);
  FRbAgent.Parent := PContent;
  FRbAgent.Left := 24; FRbAgent.Top := 24;
  FRbAgent.Width := 660; FRbAgent.Height := 22;
  FRbAgent.Caption := 'Reportman AI / DB Agent (distributed connection)';
  FRbAgent.Checked := FState.Route = wrAgent;

  L := CreateLabel(PContent,
    'Use a Reportman AI database connection. Recommended when the database is reachable through Reportman AI Web.',
    48, 50);
  L.Width := 620; L.WordWrap := True;

  FRbDirect := TRadioButton.Create(PContent);
  FRbDirect.Parent := PContent;
  FRbDirect.Left := 24; FRbDirect.Top := 110;
  FRbDirect.Width := 660; FRbDirect.Height := 22;
  FRbDirect.Caption := 'Direct database connection';
  FRbDirect.Checked := FState.Route = wrDirect;

  L := CreateLabel(PContent,
    'Connect directly using a local driver (FireDAC, Zeos, DBExpress, BDE or Microsoft DAO).',
    48, 136);
  L.Width := 620; L.WordWrap := True;
end;

procedure TFRpNewReportWizardVCL.BuildPageAgentLogin;
var
  L: TLabel;
begin
  if FState.ConnMode = cnExisting then
  begin
    L := CreateLabel(PContent,
      Format('Existing Reportman AI connection: %s', [FState.ConnName]),
      24, 24);
    L.Width := 620;
    L.Font.Style := [fsBold];

    L := CreateLabel(PContent,
      'Enter your API key to authenticate and load available schemas for this connection.',
      24, 52);
    L.Width := 620;
    L.WordWrap := True;

    CreateLabel(PContent, 'Reportman AI API key', 24, 104);
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
    FBtnHubLogin.Caption := 'Log in';
    FBtnHubLogin.OnClick := DoHubLogin;
    Exit;
  end;

  CreateLabel(PContent, 'Reportman AI API key', 24, 24);
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
  FBtnHubLogin.Caption := 'Log in';
  FBtnHubLogin.OnClick := DoHubLogin;

  CreateLabel(PContent, 'Reportman AI connection', 24, 92);
  FCbHubDatabase := TComboBox.Create(PContent);
  FCbHubDatabase.Parent := PContent;
  FCbHubDatabase.Left := 24; FCbHubDatabase.Top := 112;
  FCbHubDatabase.Width := 620;
  FCbHubDatabase.Style := csDropDownList;
end;

procedure TFRpNewReportWizardVCL.BuildPageAgentSchema;
begin
  BuildPageSharedSchemaSelector;
end;

procedure TFRpNewReportWizardVCL.BuildPageDirectSchemaQuestion;
var
  L: TLabel;
begin
  FRbHasSchema := TRadioButton.Create(PContent);
  FRbHasSchema.Parent := PContent;
  FRbHasSchema.Left := 24; FRbHasSchema.Top := 24;
  FRbHasSchema.Width := 660;
  FRbHasSchema.Caption := 'Yes, this connection has a schema in Reportman AI';
  FRbHasSchema.Checked := FState.SchemaMode = smHasSchema;

  FRbNoSchema := TRadioButton.Create(PContent);
  FRbNoSchema.Parent := PContent;
  FRbNoSchema.Left := 24; FRbNoSchema.Top := 60;
  FRbNoSchema.Width := 660;
  FRbNoSchema.Caption := 'No, design the report manually';
  FRbNoSchema.Checked := FState.SchemaMode = smNoSchema;

  L := CreateLabel(PContent,
    'AI generation requires a Reportman AI schema. Without a schema, the report can still be designed manually.',
    24, 110);
  L.Width := 660; L.WordWrap := True;
end;

procedure TFRpNewReportWizardVCL.BuildPageDirectSchemaLogin;
begin
  CreateLabel(PContent, 'Reportman AI API key', 24, 24);
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
  FBtnHubLogin.Caption := 'Log in';
  FBtnHubLogin.OnClick := DoHubLogin;
end;

procedure TFRpNewReportWizardVCL.BuildPageDirectSchema;
begin
  BuildPageSharedSchemaSelector;
end;

procedure TFRpNewReportWizardVCL.BuildPageSharedSchemaSelector;
var
  LInfo: TLabel;
begin
  if (FState.Route = wrAgent) and (Trim(FState.ConnName) <> '') then
  begin
    LInfo := CreateLabel(PContent,
      Format('Selected Reportman AI connection: %s', [FState.ConnName]),
      24, 12);
    LInfo.Width := 640;
    LInfo.Font.Style := [fsBold];
  end;

  FAISchemaSelector := TFRpAISchemaSelectorVCL.Create(PContent);
  FAISchemaSelector.Parent := PContent;
  FAISchemaSelector.Align := alClient;
  FAISchemaSelector.AlignWithMargins := True;
  FAISchemaSelector.Margins.Left := 0;
  FAISchemaSelector.Margins.Top := 36;
  FAISchemaSelector.Margins.Right := 0;
  FAISchemaSelector.Margins.Bottom := 0;
  FAISchemaSelector.SetPreferredConnection(FState.HubDatabaseId, FState.HubApiKey);
  FAISchemaSelector.SetHubContext(FState.HubDatabaseId, FState.HubSchemaId,
    FState.HubApiKey);
  FAISchemaSelector.LoadSchemas;
end;

procedure TFRpNewReportWizardVCL.BuildPageDriver;
begin
  CreateLabel(PContent, 'Driver Family', 24, 24);
  FCbFamily := TComboBox.Create(PContent);
  FCbFamily.Parent := PContent;
  FCbFamily.Left := 24; FCbFamily.Top := 44;
  FCbFamily.Width := 480;
  FCbFamily.Style := csDropDownList;
  FCbFamily.Items.Add('FireDAC (Cross-platform) - Recommended');
  FCbFamily.Items.Add('Zeos (Cross-platform)');
  FCbFamily.Items.Add('DBExpress');
  FCbFamily.Items.Add('Borland Database Engine (32-bit only)');
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

  FLblConcrete := CreateLabel(PContent, 'Driver', 24, 92);
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
  i: Integer;
  aliases: TStringList;
{$ENDIF}
begin
  if FCbConcrete = nil then
    Exit;
  FCbConcrete.Items.Clear;
  case FState.DriverFamily of
    dfFireDac:
      begin
        FLblConcrete.Caption := 'FireDAC DriverID';
        FCbConcrete.Items.CommaText :=
          'MSSQL,MySQL,PG,FB,IB,Ora,SQLite,ASA,DB2,Informix,Teradata,MongoDB,ODBC';
      end;
    dfZeos:
      begin
        FLblConcrete.Caption := 'Zeos protocol';
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
        FLblConcrete.Caption := 'No driver selection required for Microsoft DAO';
        FCbConcrete.Enabled := False;
      end;
  end;
  if FState.DriverFamily <> dfDao then
    FCbConcrete.Enabled := True;
end;

procedure TFRpNewReportWizardVCL.BuildPageConnName;
var
  L: TLabel;
begin
  FRbExisting := TRadioButton.Create(PContent);
  FRbExisting.Parent := PContent;
  FRbExisting.Left := 24; FRbExisting.Top := 16;
  FRbExisting.Width := 660;
  FRbExisting.Caption := 'Existing Connection';
  FRbExisting.Checked := FState.ConnMode <> cnNew;
  FRbExisting.OnClick := DoConnNameModeChange;

  if FState.Route = wrAgent then
    L := CreateLabel(PContent, 'Reportman AI Connection', 48, 44)
  else
    L := CreateLabel(PContent, 'DBX Connection', 48, 44);
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
  FBtnTestExisting.Caption := 'Test Connection';
  FBtnTestExisting.OnClick := DoTestExistingConn;

  FRbNew := TRadioButton.Create(PContent);
  FRbNew.Parent := PContent;
  FRbNew.Left := 24; FRbNew.Top := 124;
  FRbNew.Width := 660;
  FRbNew.Caption := 'New Connection';
  FRbNew.Checked := FState.ConnMode = cnNew;
  FRbNew.OnClick := DoConnNameModeChange;

  CreateLabel(PContent, 'Connection Name', 48, 152);
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
    RpMessageBox('Please choose a connection first.', 'Connection Test',
      [smbOK], smsInformation, smbOK, smbOK);
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
    RpMessageBox('Connection succeeded.', 'Success',
      [smbOK], smsInformation, smbOK, smbOK);
    BNext.Caption := 'Finish Connection';
  end
  else
  begin
    RpMessageBox('Connection failed: ' + res.MessageText, 'Connection Error',
      [smbOK], smsCritical, smbOK, smbOK);
    BNext.Caption := 'Edit Connection';
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
  FBtnDaoBuild.Caption := 'Build Connection String';
  FBtnDaoBuild.OnClick := DoDaoBuild;

  FBtnDaoTest := TButton.Create(PContent);
  FBtnDaoTest.Parent := PContent;
  FBtnDaoTest.Left := 256; FBtnDaoTest.Top := 84;
  FBtnDaoTest.Width := 160; FBtnDaoTest.Height := 30;
  FBtnDaoTest.Caption := 'Test Connection';
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
  RpMessageBox('ADO support is not available in this build.', 'Build Connection String',
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
      RpMessageBox('Connection succeeded.', 'Success',
        [smbOK], smsInformation, smbOK, smbOK);
    except
      on E: Exception do
        RpMessageBox('Connection failed: ' + E.Message, 'Connection Error',
          [smbOK], smsCritical, smbOK, smbOK);
    end;
  finally
    cn.Free;
  end;
{$ELSE}
  RpMessageBox('ADO support is not available in this build.', 'Connection Test',
    [smbOK], smsInformation, smbOK, smbOK);
{$ENDIF}
end;

procedure TFRpNewReportWizardVCL.BuildPageParams;
begin
  if FState.ConnMode = cnNew then
    FLblParamsCaption := CreateLabel(PContent,
      Format('New Connection "%s"', [FState.ConnName]), 16, 8)
  else
    FLblParamsCaption := CreateLabel(PContent,
      Format('Edit Connection "%s"', [FState.ConnName]), 16, 8);
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
  FBtnParamsTest.Caption := 'Test Connection';
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
        RpMessageBox('Could not load connection parameters: ' + E.Message,
          'Connection Parameters', [smbOK], smsCritical, smbOK, smbOK);
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
      RpMessageBox('Connection succeeded.', 'Success',
        [smbOK], smsInformation, smbOK, smbOK)
    else
      RpMessageBox('Connection failed: ' + res.MessageText, 'Connection Error',
        [smbOK], smsCritical, smbOK, smbOK);
  finally
    values.Free;
  end;
end;

procedure TFRpNewReportWizardVCL.DoHubLogin(Sender: TObject);
var
  list: TStringList;
begin
  FState.HubApiKey := Trim(FEdHubApiKey.Text);
  if FState.HubApiKey = '' then
  begin
    RpMessageBox('Please enter your Reportman AI API key.', 'Reportman AI',
      [smbOK], smsInformation, smbOK, smbOK);
    Exit;
  end;
  list := TStringList.Create;
  try
    Screen.Cursor := crHourGlass;
    try
      if not TRpDatabaseHttp.GetHubDatabases(FState.HubApiKey, list) then
      begin
        RpMessageBox('Could not contact Reportman AI Web. Verify your API key and try again.',
          'Reportman AI', [smbOK], smsCritical, smbOK, smbOK);
        Exit;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    FState.HubLoggedIn := True;
    if Assigned(FCbHubDatabase) then
    begin
      FCbHubDatabase.Items.Assign(list);
      if FCbHubDatabase.Items.Count > 0 then
        FCbHubDatabase.ItemIndex := 0;
    end;
    RpMessageBox('Logged in. Loaded ' + IntToStr(list.Count) + ' connections.',
      'Reportman AI', [smbOK], smsInformation, smbOK, smbOK);
  finally
    list.Free;
  end;
end;

procedure TFRpNewReportWizardVCL.LoadHubDatabases;
begin
  // Reserved for future refresh; populated in DoHubLogin.
end;

procedure TFRpNewReportWizardVCL.LoadUserSchemas;
var
  http: TRpDatabaseHttp;
  list: TStringList;
begin
  if FCbHubSchema = nil then Exit;
  list := TStringList.Create;
  http := TRpDatabaseHttp.Create;
  try
    http.ApiKey := FState.HubApiKey;
    Screen.Cursor := crHourGlass;
    try
      if not http.GetUserSchemas(list) then
      begin
        RpMessageBox('Could not load schemas from Reportman AI Web.',
          'Schemas', [smbOK], smsCritical, smbOK, smbOK);
        Exit;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    FCbHubSchema.Items.Assign(list);
    if FCbHubSchema.Items.Count > 0 then
      FCbHubSchema.ItemIndex := 0;
  finally
    list.Free;
    http.Free;
  end;
end;

procedure TFRpNewReportWizardVCL.ParseHubSchemaValue(const AValue: string;
  out ADatabaseId, ASchemaId: Int64);
var
  LSep: Integer;
begin
  ADatabaseId := 0;
  ASchemaId := 0;
  LSep := Pos('|', AValue);
  if LSep > 0 then
  begin
    ADatabaseId := StrToInt64Def(Copy(AValue, 1, LSep - 1), 0);
    ASchemaId := StrToInt64Def(Copy(AValue, LSep + 1, MaxInt), 0);
  end
  else
    ASchemaId := StrToInt64Def(AValue, 0);
end;

procedure TFRpNewReportWizardVCL.BuildPageFinish;
var
  L: TLabel;
begin
  L := CreateLabel(PContent, 'Example: ' + EXAMPLE_PROMPT, 24, 16);
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

  if FState.Route = wrAgent then
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

end.

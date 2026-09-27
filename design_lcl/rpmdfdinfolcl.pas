{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfdinfolcl                                   }
{       Database connections and datasets configuration }
{                                                       }
{*******************************************************}

unit rpmdfdinfolcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Variants,
  rpreport, rpdatainfo, rpparams, rpmdconsts, rptypes, rpbasereport, rpxmlstream,
  rpfrmmonacoeditorlcl, rpmdimageslcl, rpmdundocuelcl, rpmdfparamslcl,
  rpgraphutilslcl;

type
  { TFRpDInfoLCL }

  // The dialog edits working copies of the report connections, datasets and
  // parameters (held by FWork). The report is only modified when OK is
  // pressed: the differences are recorded in the undo cue and then applied,
  // Cancel discards everything (same model as rpmdfdinfovcl).
  TFRpDInfoLCL = class(TForm)
  private
    FReport: TRpReport;
    FWork: TRpReport;
    FOrigDatabaseInfo: TRpDatabaseInfoList;
    FOrigDataInfo: TRpDataInfoList;
    FOrigParams: TRpParamList;
    FApplied: Boolean;
    FActiveConnIndex: Integer;
    FActiveDSIndex: Integer;
    FUpdatingControls: Boolean;
    FImageList: TImageList;
    FTabImageList: TImageList;

    // Bottom controls
    PBottom: TPanel;
    BOk: TButton;
    BCancel: TButton;

    // Tabs
    PControl: TPageControl;
    TabConnections: TTabSheet;
    TabDatasets: TTabSheet;

    // Connection controls
    PConnClient: TPanel;
    LConnections: TListBox;
    SplitterConn: TSplitter;
    PConnProps: TPanel;
    LabelConnAlias: TLabel;
    EConnAlias: TEdit;
    LabelConnDriver: TLabel;
    ComboDriver: TComboBox;
    LabelConfigFile: TLabel;
    EConfigFile: TEdit;
    BBrowseFile: TButton;
    CheckLoginPrompt: TCheckBox;
    OpenDialog1: TOpenDialog;

    PDSClient: TPanel;
    PDSTopArea: TPanel;
    LDatasets: TListBox;
    SplitterDS: TSplitter;
    PDSProps: TPanel;
    LabelDSAlias: TLabel;
    EDSAlias: TEdit;
    LabelDSConn: TLabel;
    ComboDSConn: TComboBox;
    LabelDSMaster: TLabel;
    ComboDSMaster: TComboBox;
    CheckOpenOnStart: TCheckBox;
    SplitterSQL: TSplitter;
    PSQLArea: TPanel;
    PSQLTop: TPanel;
    LabelSQL: TLabel;
    BMonacoToggle: TButton;
    BThemeToggle: TButton;
    MSQL: TMemo;
    FMonacoEditor: TFRpMonacoEditorLCL;
    FIsDarkTheme: Boolean;

    procedure BuildControls;
    procedure SetReport(Value: TRpReport);
    procedure SaveActiveConn;
    procedure SaveActiveDS;
    procedure LoadConnDetails(Index: Integer);
    procedure LoadDSDetails(Index: Integer);
    procedure RefreshConnList;
    procedure RefreshDSList;
    procedure RefreshConnCombos;
    function UniqueItemName(const APrefix: string): string;
    function CheckCanModify: Boolean;
    function HasPendingChanges: Boolean;
    function OrderChanged: Boolean;
    procedure RecordUndoChanges;

    procedure LConnectionsClick(Sender: TObject);
    procedure LDatasetsClick(Sender: TObject);
    procedure BNewConnClick(Sender: TObject);
    procedure BDelConnClick(Sender: TObject);
    procedure BBrowseFileClick(Sender: TObject);
    procedure BNewDSClick(Sender: TObject);
    procedure BtnUpDSClick(Sender: TObject);
    procedure BtnDownDSClick(Sender: TObject);
    procedure BDelDSClick(Sender: TObject);
    procedure BtnRenameDSClick(Sender: TObject);
    procedure BParamsClick(Sender: TObject);
    procedure BMonacoToggleClick(Sender: TObject);
    procedure BThemeToggleClick(Sender: TObject);
    procedure MonacoContentChanged(Sender: TObject);
    procedure BOkClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
  public
    // Toolbar controls
    ToolBarConn: TToolBar;
    BNewConn: TToolButton;
    SepConn: TToolButton;
    BDelConn: TToolButton;

    ToolBarDS: TToolBar;
    BNewDS: TToolButton;
    BtnUpDS: TToolButton;
    BtnDownDS: TToolButton;
    SepDS1: TToolButton;
    BDelDS: TToolButton;
    SepDS2: TToolButton;
    BtnRenameDS: TToolButton;
    BParams: TButton;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Applies the working copies to the report (what OK does). Returns False
    // when the report can not be modified; the dialog stays open then.
    function ApplyChanges: Boolean;
    property Report: TRpReport read FReport write SetReport;
    // Working copies edited by the dialog (not the report lists)
    property WorkReport: TRpReport read FWork;
    // True when OK applied changes to the report
    property Applied: Boolean read FApplied;
    property MonacoEditor: TFRpMonacoEditorLCL read FMonacoEditor;
  end;

// Shows the data configuration dialog. Returns True when the report was
// modified (changes are recorded in the undo cue).
function ShowDataConfig(report: TRpReport): Boolean;

implementation

{$R *.lfm}

var
  GDataConfigDialog: TFRpDInfoLCL = nil;

function ShowDataConfig(report: TRpReport): Boolean;
begin
  Result := False;
  if not Assigned(report) then Exit;
  if GDataConfigDialog = nil then
    GDataConfigDialog := TFRpDInfoLCL.Create(Application);
  GDataConfigDialog.Report := report;
  GDataConfigDialog.ShowModal;
  Result := GDataConfigDialog.Applied;
end;

function SameStringLists(AList, BList: TStrings): Boolean;
begin
  if (AList = nil) or (BList = nil) then
    Result := AList = BList
  else
    Result := AList.Text = BList.Text;
end;

function SameDatabaseInfoItem(AItem, BItem: TRpDatabaseInfoItem): Boolean;
begin
  Result := Assigned(AItem) and Assigned(BItem) and
    (AItem.Name = BItem.Name) and
    (AItem.Alias = BItem.Alias) and
    (Integer(AItem.Driver) = Integer(BItem.Driver)) and
    (AItem.ConfigFile = BItem.ConfigFile) and
    (AItem.LoginPrompt = BItem.LoginPrompt) and
    (AItem.LoadParams = BItem.LoadParams) and
    (AItem.LoadDriverParams = BItem.LoadDriverParams) and
    (AItem.ADOConnectionString = BItem.ADOConnectionString) and
    (AItem.ProviderFactory = BItem.ProviderFactory) and
    (AItem.DotNetDriver = BItem.DotNetDriver) and
    (AItem.ReportTable = BItem.ReportTable) and
    (AItem.ReportField = BItem.ReportField) and
    (AItem.ReportSearchField = BItem.ReportSearchField) and
    (AItem.ReportGroupsTable = BItem.ReportGroupsTable);
end;

function SameDatabaseInfoList(AList, BList: TRpDatabaseInfoList): Boolean;
var
  i: Integer;
begin
  Result := Assigned(AList) and Assigned(BList) and (AList.Count = BList.Count);
  if not Result then
    Exit;
  for i := 0 to AList.Count - 1 do
  begin
    if not SameDatabaseInfoItem(AList.Items[i], BList.Items[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function SameDataInfoItem(AItem, BItem: TRpDataInfoItem): Boolean;
begin
  Result := Assigned(AItem) and Assigned(BItem) and
    (AItem.Name = BItem.Name) and
    (AItem.Alias = BItem.Alias) and
    (AItem.DatabaseAlias = BItem.DatabaseAlias) and
    (AItem.DataSource = BItem.DataSource) and
    (AItem.SQL = BItem.SQL) and
    (AItem.HubSchemaId = BItem.HubSchemaId) and
    (AItem.GroupUnion = BItem.GroupUnion) and
    (AItem.OpenOnStart = BItem.OpenOnStart) and
    (AItem.ParallelUnion = BItem.ParallelUnion) and
    SameStringLists(AItem.DataUnions, BItem.DataUnions);
end;

function SameDataInfoList(AList, BList: TRpDataInfoList): Boolean;
var
  i: Integer;
begin
  Result := Assigned(AList) and Assigned(BList) and (AList.Count = BList.Count);
  if not Result then
    Exit;
  for i := 0 to AList.Count - 1 do
  begin
    if not SameDataInfoItem(AList.Items[i], BList.Items[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function SameParamItem(AItem, BItem: TRpParam): Boolean;
begin
  Result := Assigned(AItem) and Assigned(BItem) and
    (AItem.Name = BItem.Name) and
    (AItem.IntName = BItem.IntName) and
    (AItem.Visible = BItem.Visible) and
    (AItem.NeverVisible = BItem.NeverVisible) and
    (AItem.IsReadOnly = BItem.IsReadOnly) and
    (AItem.AllowNulls = BItem.AllowNulls) and
    (Integer(AItem.ParamType) = Integer(BItem.ParamType)) and
    (AItem.Descriptions = BItem.Descriptions) and
    (AItem.Hints = BItem.Hints) and
    (AItem.Validation = BItem.Validation) and
    (AItem.ErrorMessages = BItem.ErrorMessages) and
    (AItem.Search = BItem.Search) and
    (AItem.LookupDataset = BItem.LookupDataset) and
    (AItem.SearchDataset = BItem.SearchDataset) and
    (AItem.SearchParam = BItem.SearchParam) and
    ParamValuesEqual(AItem.Value, BItem.Value) and
    SameStringLists(AItem.Datasets, BItem.Datasets) and
    SameStringLists(AItem.Items, BItem.Items) and
    SameStringLists(AItem.Values, BItem.Values) and
    SameStringLists(AItem.Selected, BItem.Selected);
end;

function SameParamList(AList, BList: TRpParamList): Boolean;
var
  i: Integer;
begin
  Result := Assigned(AList) and Assigned(BList) and (AList.Count = BList.Count);
  if not Result then
    Exit;
  for i := 0 to AList.Count - 1 do
  begin
    if not SameParamItem(AList.Items[i], BList.Items[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

constructor TFRpDInfoLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActiveConnIndex := -1;
  FActiveDSIndex := -1;
  FUpdatingControls := False;
  FApplied := False;

  FWork := TRpReport.Create(Self);
  FOrigDatabaseInfo := TRpDatabaseInfoList.Create(nil);
  FOrigDataInfo := TRpDataInfoList.Create(nil);
  FOrigParams := TRpParamList.Create(nil);

  Caption := TranslateStr(1097, 'Database connections and datasets');
  Position := poScreenCenter;
  Width := 740;
  Height := 540;

  BuildControls;
end;

destructor TFRpDInfoLCL.Destroy;
begin
  if GDataConfigDialog = Self then
    GDataConfigDialog := nil;
  FreeAndNil(FOrigDatabaseInfo);
  FreeAndNil(FOrigDataInfo);
  FreeAndNil(FOrigParams);
  inherited Destroy;
end;

procedure TFRpDInfoLCL.BuildControls;
begin
  OpenDialog1 := TOpenDialog.Create(Self);
  OpenDialog1.Filter := 'All files (*.*)|*.*|SQLite databases (*.db;*.sqlite;*.sqlite3)|*.db;*.sqlite;*.sqlite3|XML/ClientDataset (*.xml;*.cds)|*.xml;*.cds';

  // Bottom buttons panel
  PBottom := TPanel.Create(Self);
  PBottom.Align := alBottom;
  PBottom.Height := 44;
  PBottom.BevelOuter := bvNone;
  PBottom.Parent := Self;

  // No ModalResult on the OK button: BOkClick decides whether the dialog can
  // close (the report may refuse modifications)
  BOk := TButton.Create(PBottom);
  BOk.Parent := PBottom;
  BOk.Caption := TranslateStr(93, 'OK');
  BOk.Default := True;
  BOk.SetBounds(PBottom.Width - 210, 8, 95, 28);
  BOk.Anchors := [akTop, akRight];
  BOk.OnClick := BOkClick;

  BCancel := TButton.Create(PBottom);
  BCancel.Parent := PBottom;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.ModalResult := mrCancel;
  BCancel.Cancel := True;
  BCancel.SetBounds(PBottom.Width - 105, 8, 95, 28);
  BCancel.Anchors := [akTop, akRight];
  BCancel.OnClick := BCancelClick;

  // PageControl
  PControl := TPageControl.Create(Self);
  PControl.Align := alClient;
  PControl.Parent := Self;

  FTabImageList := TImageList.Create(Self);
  LoadDBBrowserImageList(FTabImageList);
  PControl.Images := FTabImageList;

  FImageList := TImageList.Create(Self);
  LoadDataConfigImageList(FImageList);

  // -------------------------------------------------------------
  // TAB 1: Connections
  // -------------------------------------------------------------
  TabConnections := TTabSheet.Create(PControl);
  TabConnections.PageControl := PControl;
  TabConnections.Caption := TranslateStr(142, 'Database connections');
  TabConnections.ImageIndex := 0;

  ToolBarConn := TToolBar.Create(TabConnections);
  ToolBarConn.Parent := TabConnections;
  ToolBarConn.Align := alTop;
  ToolBarConn.Height := 28;
  ToolBarConn.ButtonWidth := 26;
  ToolBarConn.ButtonHeight := 26;
  ToolBarConn.Flat := True;
  ToolBarConn.ShowHint := True;
  ToolBarConn.Images := FImageList;

  BNewConn := TToolButton.Create(ToolBarConn);
  BNewConn.Parent := ToolBarConn;
  BNewConn.ImageIndex := IMG_DC_NEW;
  BNewConn.Hint := TranslateStr(1103, 'Adds a new connection');
  BNewConn.OnClick := BNewConnClick;

  SepConn := TToolButton.Create(ToolBarConn);
  SepConn.Parent := ToolBarConn;
  SepConn.Style := tbsSeparator;
  SepConn.Width := 8;

  BDelConn := TToolButton.Create(ToolBarConn);
  BDelConn.Parent := ToolBarConn;
  BDelConn.ImageIndex := IMG_DC_DELETE;
  BDelConn.Hint := TranslateStr(1105, 'Deletes the selected connection');
  BDelConn.OnClick := BDelConnClick;

  PConnClient := TPanel.Create(TabConnections);
  PConnClient.Align := alClient;
  PConnClient.BevelOuter := bvNone;
  PConnClient.Parent := TabConnections;

  LConnections := TListBox.Create(PConnClient);
  LConnections.Align := alLeft;
  LConnections.Width := 210;
  LConnections.Parent := PConnClient;
  LConnections.OnClick := LConnectionsClick;

  SplitterConn := TSplitter.Create(PConnClient);
  SplitterConn.Align := alLeft;
  SplitterConn.Width := 5;
  SplitterConn.Parent := PConnClient;

  PConnProps := TPanel.Create(PConnClient);
  PConnProps.Align := alClient;
  PConnProps.BevelOuter := bvNone;
  PConnProps.BorderWidth := 10;
  PConnProps.Parent := PConnClient;

  LabelConnAlias := TLabel.Create(PConnProps);
  LabelConnAlias.Parent := PConnProps;
  LabelConnAlias.Caption := 'Connection Name / Alias:';
  LabelConnAlias.SetBounds(10, 12, 200, 16);

  EConnAlias := TEdit.Create(PConnProps);
  EConnAlias.Parent := PConnProps;
  EConnAlias.SetBounds(10, 32, 380, 24);
  EConnAlias.Anchors := [akLeft, akTop, akRight];

  LabelConnDriver := TLabel.Create(PConnProps);
  LabelConnDriver.Parent := PConnProps;
  LabelConnDriver.Caption := 'Database Driver:';
  LabelConnDriver.SetBounds(10, 68, 200, 16);

  ComboDriver := TComboBox.Create(PConnProps);
  ComboDriver.Parent := PConnProps;
  ComboDriver.Style := csDropDownList;
  ComboDriver.SetBounds(10, 88, 380, 24);
  ComboDriver.Anchors := [akLeft, akTop, akRight];
  ComboDriver.Items.Add('0 - dbExpress / SQLDB');
  ComboDriver.Items.Add('1 - MyBase / Memory');
  ComboDriver.Items.Add('2 - IBX / Firebird');
  ComboDriver.Items.Add('3 - BDE');
  ComboDriver.Items.Add('4 - ADO / ODBC');
  ComboDriver.Items.Add('5 - IBO');
  ComboDriver.Items.Add('6 - ZeosDBO');
  ComboDriver.Items.Add('7 - Native Driver / SQLite');
  ComboDriver.Items.Add('8 - .NET Driver');
  ComboDriver.Items.Add('9 - FireDAC');
  ComboDriver.Items.Add('10 - HTTP / Cloud');

  LabelConfigFile := TLabel.Create(PConnProps);
  LabelConfigFile.Parent := PConnProps;
  LabelConfigFile.Caption := 'Config / Database File:';
  LabelConfigFile.SetBounds(10, 124, 200, 16);

  EConfigFile := TEdit.Create(PConnProps);
  EConfigFile.Parent := PConnProps;
  EConfigFile.SetBounds(10, 144, 340, 24);
  EConfigFile.Anchors := [akLeft, akTop, akRight];

  BBrowseFile := TButton.Create(PConnProps);
  BBrowseFile.Parent := PConnProps;
  BBrowseFile.Caption := '...';
  BBrowseFile.SetBounds(355, 144, 35, 24);
  BBrowseFile.Anchors := [akTop, akRight];
  BBrowseFile.OnClick := BBrowseFileClick;

  CheckLoginPrompt := TCheckBox.Create(PConnProps);
  CheckLoginPrompt.Parent := PConnProps;
  CheckLoginPrompt.Caption := 'Prompt for login credentials';
  CheckLoginPrompt.SetBounds(10, 180, 250, 20);

  // -------------------------------------------------------------
  // TAB 2: Datasets
  // -------------------------------------------------------------
  TabDatasets := TTabSheet.Create(PControl);
  TabDatasets.PageControl := PControl;
  TabDatasets.Caption := TranslateStr(148, 'Report datasets');
  TabDatasets.ImageIndex := 1;

  ToolBarDS := TToolBar.Create(TabDatasets);
  ToolBarDS.Parent := TabDatasets;
  ToolBarDS.Align := alTop;
  ToolBarDS.Height := 28;
  ToolBarDS.ButtonWidth := 26;
  ToolBarDS.ButtonHeight := 26;
  ToolBarDS.Flat := True;
  ToolBarDS.ShowHint := True;
  ToolBarDS.Images := FImageList;

  BNewDS := TToolButton.Create(ToolBarDS);
  BNewDS.Parent := ToolBarDS;
  BNewDS.ImageIndex := IMG_DC_NEW;
  BNewDS.Hint := TranslateStr(539, 'New dataset');
  BNewDS.OnClick := BNewDSClick;

  BtnUpDS := TToolButton.Create(ToolBarDS);
  BtnUpDS.Parent := ToolBarDS;
  BtnUpDS.ImageIndex := IMG_DC_UP;
  BtnUpDS.Hint := TranslateStr(190, 'Up');
  BtnUpDS.OnClick := BtnUpDSClick;

  BtnDownDS := TToolButton.Create(ToolBarDS);
  BtnDownDS.Parent := ToolBarDS;
  BtnDownDS.ImageIndex := IMG_DC_DOWN;
  BtnDownDS.Hint := TranslateStr(191, 'Down');
  BtnDownDS.OnClick := BtnDownDSClick;

  SepDS1 := TToolButton.Create(ToolBarDS);
  SepDS1.Parent := ToolBarDS;
  SepDS1.Style := tbsSeparator;
  SepDS1.Width := 8;

  BDelDS := TToolButton.Create(ToolBarDS);
  BDelDS.Parent := ToolBarDS;
  BDelDS.ImageIndex := IMG_DC_DELETE;
  BDelDS.Hint := TranslateStr(150, 'Delete');
  BDelDS.OnClick := BDelDSClick;

  SepDS2 := TToolButton.Create(ToolBarDS);
  SepDS2.Parent := ToolBarDS;
  SepDS2.Style := tbsSeparator;
  SepDS2.Width := 8;

  BtnRenameDS := TToolButton.Create(ToolBarDS);
  BtnRenameDS.Parent := ToolBarDS;
  BtnRenameDS.ImageIndex := IMG_DC_RENAME;
  BtnRenameDS.Hint := TranslateStr(540, 'Rename dataset');
  BtnRenameDS.OnClick := BtnRenameDSClick;

  PDSClient := TPanel.Create(TabDatasets);
  PDSClient.Align := alClient;
  PDSClient.BevelOuter := bvNone;
  PDSClient.Parent := TabDatasets;

  PDSTopArea := TPanel.Create(PDSClient);
  PDSTopArea.Align := alTop;
  PDSTopArea.Height := 170;
  PDSTopArea.BevelOuter := bvNone;
  PDSTopArea.Parent := PDSClient;

  LDatasets := TListBox.Create(PDSTopArea);
  LDatasets.Align := alLeft;
  LDatasets.Width := 210;
  LDatasets.Parent := PDSTopArea;
  LDatasets.OnClick := LDatasetsClick;

  SplitterDS := TSplitter.Create(PDSTopArea);
  SplitterDS.Align := alLeft;
  SplitterDS.Width := 5;
  SplitterDS.Parent := PDSTopArea;

  PDSProps := TPanel.Create(PDSTopArea);
  PDSProps.Align := alClient;
  PDSProps.BevelOuter := bvNone;
  PDSProps.BorderWidth := 6;
  PDSProps.Parent := PDSTopArea;

  LabelDSAlias := TLabel.Create(PDSProps);
  LabelDSAlias.Parent := PDSProps;
  LabelDSAlias.Caption := 'Dataset Name / Alias:';
  LabelDSAlias.SetBounds(10, 6, 160, 16);

  EDSAlias := TEdit.Create(PDSProps);
  EDSAlias.Parent := PDSProps;
  EDSAlias.SetBounds(10, 24, 380, 24);
  EDSAlias.Anchors := [akLeft, akTop, akRight];

  LabelDSConn := TLabel.Create(PDSProps);
  LabelDSConn.Parent := PDSProps;
  LabelDSConn.Caption := 'Database Connection:';
  LabelDSConn.SetBounds(10, 54, 160, 16);

  ComboDSConn := TComboBox.Create(PDSProps);
  ComboDSConn.Parent := PDSProps;
  ComboDSConn.Style := csDropDownList;
  ComboDSConn.SetBounds(10, 72, 380, 24);
  ComboDSConn.Anchors := [akLeft, akTop, akRight];

  LabelDSMaster := TLabel.Create(PDSProps);
  LabelDSMaster.Parent := PDSProps;
  LabelDSMaster.Caption := 'Master DataSource:';
  LabelDSMaster.SetBounds(10, 102, 160, 16);

  ComboDSMaster := TComboBox.Create(PDSProps);
  ComboDSMaster.Parent := PDSProps;
  ComboDSMaster.Style := csDropDownList;
  ComboDSMaster.SetBounds(10, 120, 240, 24);

  CheckOpenOnStart := TCheckBox.Create(PDSProps);
  CheckOpenOnStart.Parent := PDSProps;
  CheckOpenOnStart.Caption := 'Open on start';
  CheckOpenOnStart.SetBounds(270, 122, 120, 20);
  CheckOpenOnStart.Anchors := [akTop, akRight];

  SplitterSQL := TSplitter.Create(PDSClient);
  SplitterSQL.Align := alTop;
  SplitterSQL.Height := 5;
  SplitterSQL.Parent := PDSClient;

  PSQLArea := TPanel.Create(PDSClient);
  PSQLArea.Align := alClient;
  PSQLArea.BevelOuter := bvNone;
  PSQLArea.BorderWidth := 4;
  PSQLArea.Parent := PDSClient;

  PSQLTop := TPanel.Create(PSQLArea);
  PSQLTop.Align := alTop;
  PSQLTop.Height := 28;
  PSQLTop.BevelOuter := bvNone;
  PSQLTop.Parent := PSQLArea;

  LabelSQL := TLabel.Create(PSQLTop);
  LabelSQL.Caption := ' Consulta SQL:';
  LabelSQL.SetBounds(4, 6, 100, 18);
  LabelSQL.Parent := PSQLTop;

  BMonacoToggle := TButton.Create(PSQLTop);
  BMonacoToggle.Parent := PSQLTop;
  BMonacoToggle.Caption := 'Alternar Monaco / Texto';
  BMonacoToggle.SetBounds(110, 2, 160, 24);
  BMonacoToggle.OnClick := BMonacoToggleClick;

  BThemeToggle := TButton.Create(PSQLTop);
  BThemeToggle.Parent := PSQLTop;
  BThemeToggle.Caption := 'Tema Claro / Oscuro';
  BThemeToggle.SetBounds(276, 2, 140, 24);
  BThemeToggle.OnClick := BThemeToggleClick;
  FIsDarkTheme := False;

  // Report parameters (VCL: TFRpDatasetsVCL.BParams)
  BParams := TButton.Create(PSQLTop);
  BParams.Parent := PSQLTop;
  BParams.Caption := TranslateStr(152, 'Parameters');
  BParams.Hint := BParams.Caption;
  BParams.SetBounds(422, 2, 120, 24);
  BParams.OnClick := BParamsClick;

  MSQL := TMemo.Create(PSQLArea);
  MSQL.Align := alClient;
  MSQL.Font.Name := 'Courier New';
  MSQL.Font.Size := 9;
  MSQL.ScrollBars := ssBoth;
  MSQL.WordWrap := False;
  MSQL.Visible := False;
  MSQL.Parent := PSQLArea;

  FMonacoEditor := TFRpMonacoEditorLCL.Create(PSQLArea);
  FMonacoEditor.Align := alClient;
  FMonacoEditor.Parent := PSQLArea;
  FMonacoEditor.Visible := True;
  FMonacoEditor.OnContentChanged := MonacoContentChanged;
end;

procedure TFRpDInfoLCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  FApplied := False;
  FActiveConnIndex := -1;
  FActiveDSIndex := -1;

  FWork.DatabaseInfo.Clear;
  FWork.DataInfo.Clear;
  FWork.Params.Clear;
  FOrigDatabaseInfo.Clear;
  FOrigDataInfo.Clear;
  FOrigParams.Clear;
  if Assigned(FReport) then
  begin
    // Undo operations identify items by name
    EnsureReportItemNames(FReport);
    // Snapshot of the originals (undo comparison) and working copies
    FOrigDatabaseInfo.Assign(FReport.DatabaseInfo);
    FOrigDataInfo.Assign(FReport.DataInfo);
    FOrigParams.Assign(FReport.Params);
    FWork.DatabaseInfo.Assign(FReport.DatabaseInfo);
    FWork.DataInfo.Assign(FReport.DataInfo);
    FWork.Params.Assign(FReport.Params);
  end;

  RefreshConnList;
  RefreshDSList;

  if FWork.DataInfo.Count > 0 then
    PControl.ActivePage := TabDatasets
  else
    PControl.ActivePage := TabConnections;
end;

function TFRpDInfoLCL.UniqueItemName(const APrefix: string): string;
var
  n: Integer;
begin
  // Unique in the working copies and in the report (an item removed in this
  // session must not lend its name to a new one, undo would mix them)
  n := 1;
  repeat
    Result := APrefix + IntToStr(n);
    Inc(n);
  until (FWork.FindReporItemByName(Result) = nil) and
    ((not Assigned(FReport)) or (FReport.FindReporItemByName(Result) = nil));
end;

function TFRpDInfoLCL.CheckCanModify: Boolean;
begin
  Result := (not Assigned(FReport)) or FReport.CanModify('Database configuration');
end;

procedure TFRpDInfoLCL.RefreshConnList;
var
  i: Integer;
begin
  LConnections.Items.BeginUpdate;
  try
    LConnections.Clear;
    for i := 0 to FWork.DatabaseInfo.Count - 1 do
      LConnections.Items.Add(FWork.DatabaseInfo[i].Alias);
  finally
    LConnections.Items.EndUpdate;
  end;

  if LConnections.Count > 0 then
  begin
    LConnections.ItemIndex := 0;
    LoadConnDetails(0);
  end
  else
    LoadConnDetails(-1);
end;

procedure TFRpDInfoLCL.RefreshDSList;
var
  i: Integer;
begin
  LDatasets.Items.BeginUpdate;
  try
    LDatasets.Clear;
    for i := 0 to FWork.DataInfo.Count - 1 do
      LDatasets.Items.Add(FWork.DataInfo[i].Alias);
  finally
    LDatasets.Items.EndUpdate;
  end;

  if LDatasets.Count > 0 then
  begin
    LDatasets.ItemIndex := 0;
    LoadDSDetails(0);
  end
  else
    LoadDSDetails(-1);
end;

procedure TFRpDInfoLCL.RefreshConnCombos;
var
  i: Integer;
  curDSConn, curDSMaster: string;
begin
  curDSConn := ComboDSConn.Text;
  curDSMaster := ComboDSMaster.Text;

  ComboDSConn.Items.BeginUpdate;
  try
    ComboDSConn.Clear;
    ComboDSConn.Items.Add('');
    for i := 0 to FWork.DatabaseInfo.Count - 1 do
      ComboDSConn.Items.Add(FWork.DatabaseInfo[i].Alias);
  finally
    ComboDSConn.Items.EndUpdate;
  end;
  ComboDSConn.ItemIndex := ComboDSConn.Items.IndexOf(curDSConn);

  ComboDSMaster.Items.BeginUpdate;
  try
    ComboDSMaster.Clear;
    ComboDSMaster.Items.Add('');
    for i := 0 to FWork.DataInfo.Count - 1 do
    begin
      if (FActiveDSIndex < 0) or (i <> FActiveDSIndex) then
        ComboDSMaster.Items.Add(FWork.DataInfo[i].Alias);
    end;
  finally
    ComboDSMaster.Items.EndUpdate;
  end;
  ComboDSMaster.ItemIndex := ComboDSMaster.Items.IndexOf(curDSMaster);
end;

procedure TFRpDInfoLCL.SaveActiveConn;
var
  item: TRpDatabaseInfoItem;
  driverIdx: Integer;
begin
  if (FActiveConnIndex < 0) or (FActiveConnIndex >= FWork.DatabaseInfo.Count) then
    Exit;

  item := FWork.DatabaseInfo[FActiveConnIndex];
  if Trim(EConnAlias.Text) <> '' then
  begin
    item.Alias := Trim(EConnAlias.Text);
    if (FActiveConnIndex < LConnections.Count) and
       (LConnections.Items[FActiveConnIndex] <> item.Alias) then
      LConnections.Items[FActiveConnIndex] := item.Alias;
  end;

  driverIdx := ComboDriver.ItemIndex;
  if driverIdx >= 0 then
    item.Driver := TRpDbDriver(driverIdx);

  item.ConfigFile := EConfigFile.Text;
  item.LoginPrompt := CheckLoginPrompt.Checked;
end;

procedure TFRpDInfoLCL.SaveActiveDS;
var
  item: TRpDataInfoItem;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then
    Exit;

  item := FWork.DataInfo[FActiveDSIndex];
  if Trim(EDSAlias.Text) <> '' then
  begin
    item.Alias := Trim(EDSAlias.Text);
    if (FActiveDSIndex < LDatasets.Count) and
       (LDatasets.Items[FActiveDSIndex] <> item.Alias) then
      LDatasets.Items[FActiveDSIndex] := item.Alias;
  end;

  item.DatabaseAlias := ComboDSConn.Text;
  item.DataSource := ComboDSMaster.Text;
  item.OpenOnStart := CheckOpenOnStart.Checked;
  if Assigned(FMonacoEditor) and FMonacoEditor.Visible then
    item.SQL := FMonacoEditor.SQL
  else
    item.SQL := MSQL.Text;
end;

procedure TFRpDInfoLCL.MonacoContentChanged(Sender: TObject);
begin
  if FUpdatingControls then Exit;
  if Assigned(FMonacoEditor) then
    MSQL.Text := FMonacoEditor.SQL;
end;

procedure TFRpDInfoLCL.BMonacoToggleClick(Sender: TObject);
begin
  if Assigned(FMonacoEditor) and FMonacoEditor.Visible then
  begin
    MSQL.Text := FMonacoEditor.SQL;
    FMonacoEditor.Visible := False;
    MSQL.Visible := True;
  end
  else
  begin
    if Assigned(FMonacoEditor) then
      FMonacoEditor.SQL := MSQL.Text;
    MSQL.Visible := False;
    if Assigned(FMonacoEditor) then
      FMonacoEditor.Visible := True;
  end;
end;

procedure TFRpDInfoLCL.BThemeToggleClick(Sender: TObject);
begin
  FIsDarkTheme := not FIsDarkTheme;
  if Assigned(FMonacoEditor) then
  begin
    if FIsDarkTheme then
      FMonacoEditor.SetTheme('vs-dark')
    else
      FMonacoEditor.SetTheme('vs');
  end;
end;

procedure TFRpDInfoLCL.LoadConnDetails(Index: Integer);
var
  item: TRpDatabaseInfoItem;
begin
  FUpdatingControls := True;
  try
    FActiveConnIndex := Index;
    if (Index < 0) or (Index >= FWork.DatabaseInfo.Count) then
    begin
      FActiveConnIndex := -1;
      EConnAlias.Text := '';
      ComboDriver.ItemIndex := -1;
      EConfigFile.Text := '';
      CheckLoginPrompt.Checked := False;
      PConnProps.Enabled := False;
      BDelConn.Enabled := False;
      Exit;
    end;

    PConnProps.Enabled := True;
    BDelConn.Enabled := True;
    item := FWork.DatabaseInfo[Index];
    EConnAlias.Text := item.Alias;
    ComboDriver.ItemIndex := Integer(item.Driver);
    EConfigFile.Text := item.ConfigFile;
    CheckLoginPrompt.Checked := item.LoginPrompt;
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFRpDInfoLCL.LoadDSDetails(Index: Integer);
var
  item: TRpDataInfoItem;
begin
  FUpdatingControls := True;
  try
    FActiveDSIndex := Index;
    if (Index < 0) or (Index >= FWork.DataInfo.Count) then
      FActiveDSIndex := -1;
    RefreshConnCombos;

    if FActiveDSIndex < 0 then
    begin
      EDSAlias.Text := '';
      ComboDSConn.ItemIndex := -1;
      ComboDSMaster.ItemIndex := -1;
      CheckOpenOnStart.Checked := True;
      MSQL.Clear;
      if Assigned(FMonacoEditor) then
        FMonacoEditor.SQL := '';
      PDSProps.Enabled := False;
      PSQLArea.Enabled := False;
      BDelDS.Enabled := False;
      BtnUpDS.Enabled := False;
      BtnDownDS.Enabled := False;
      BtnRenameDS.Enabled := False;
      // The parameters button stays usable without datasets
      BParams.Enabled := True;
      Exit;
    end;

    PDSProps.Enabled := True;
    PSQLArea.Enabled := True;
    BDelDS.Enabled := True;
    BtnUpDS.Enabled := (Index > 0);
    BtnDownDS.Enabled := (Index < FWork.DataInfo.Count - 1);
    BtnRenameDS.Enabled := True;
    item := FWork.DataInfo[Index];
    EDSAlias.Text := item.Alias;
    ComboDSConn.ItemIndex := ComboDSConn.Items.IndexOf(item.DatabaseAlias);
    ComboDSMaster.ItemIndex := ComboDSMaster.Items.IndexOf(item.DataSource);
    CheckOpenOnStart.Checked := item.OpenOnStart;
    MSQL.Text := item.SQL;
    if Assigned(FMonacoEditor) then
      FMonacoEditor.SQL := item.SQL;
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFRpDInfoLCL.LConnectionsClick(Sender: TObject);
begin
  if FUpdatingControls then Exit;
  SaveActiveConn;
  LoadConnDetails(LConnections.ItemIndex);
end;

procedure TFRpDInfoLCL.LDatasetsClick(Sender: TObject);
begin
  if FUpdatingControls then Exit;
  SaveActiveDS;
  LoadDSDetails(LDatasets.ItemIndex);
end;

procedure TFRpDInfoLCL.BNewConnClick(Sender: TObject);
var
  newAlias: string;
  n: Integer;
  item: TRpDatabaseInfoItem;
begin
  if not CheckCanModify then Exit;
  SaveActiveConn;

  n := FWork.DatabaseInfo.Count + 1;
  repeat
    newAlias := 'CONNECTION' + IntToStr(n);
    Inc(n);
  until FWork.DatabaseInfo.IndexOf(newAlias) < 0;

  item := FWork.DatabaseInfo.Add(newAlias);
  item.Name := UniqueItemName('TRPDATABASEINFOITEM');
  item.Driver := rpdatadriver;

  LConnections.Items.Add(newAlias);
  LConnections.ItemIndex := LConnections.Count - 1;
  LoadConnDetails(LConnections.ItemIndex);
  if EConnAlias.CanFocus then
  begin
    EConnAlias.SetFocus;
    EConnAlias.SelectAll;
  end;
end;

procedure TFRpDInfoLCL.BDelConnClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveConnIndex < 0) or (FActiveConnIndex >= FWork.DatabaseInfo.Count) then
    Exit;
  if not CheckCanModify then Exit;

  idx := FActiveConnIndex;
  FActiveConnIndex := -1;
  FWork.DatabaseInfo.Delete(idx);
  LConnections.Items.Delete(idx);

  if idx >= LConnections.Count then
    idx := LConnections.Count - 1;
  if idx >= 0 then
    LConnections.ItemIndex := idx;
  LoadConnDetails(idx);
end;

procedure TFRpDInfoLCL.BBrowseFileClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    EConfigFile.Text := OpenDialog1.FileName;
end;

procedure TFRpDInfoLCL.BNewDSClick(Sender: TObject);
var
  newAlias: string;
  n: Integer;
  item: TRpDataInfoItem;
begin
  if not CheckCanModify then Exit;
  SaveActiveDS;

  n := FWork.DataInfo.Count + 1;
  repeat
    newAlias := 'DATASET' + IntToStr(n);
    Inc(n);
  until FWork.DataInfo.IndexOf(newAlias) < 0;

  item := FWork.DataInfo.Add(newAlias);
  item.Name := UniqueItemName('TRPDATAINFOITEM');
  item.OpenOnStart := True;
  if FWork.DatabaseInfo.Count > 0 then
    item.DatabaseAlias := FWork.DatabaseInfo[0].Alias;

  LDatasets.Items.Add(newAlias);
  LDatasets.ItemIndex := LDatasets.Count - 1;
  LoadDSDetails(LDatasets.ItemIndex);
  if EDSAlias.CanFocus then
  begin
    EDSAlias.SetFocus;
    EDSAlias.SelectAll;
  end;
end;

procedure TFRpDInfoLCL.BDelDSClick(Sender: TObject);
var
  idx, i: Integer;
  oldAlias: string;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then
    Exit;
  if not CheckCanModify then Exit;

  idx := FActiveDSIndex;
  FActiveDSIndex := -1;
  oldAlias := FWork.DataInfo[idx].Alias;
  FWork.DataInfo.Delete(idx);
  // Remove dependences (VCL TFRpDatasetsVCL.Removedependences)
  for i := 0 to FWork.DataInfo.Count - 1 do
  begin
    if AnsiUpperCase(oldAlias) = AnsiUpperCase(FWork.DataInfo[i].DataSource) then
      FWork.DataInfo[i].DataSource := '';
  end;
  LDatasets.Items.Delete(idx);

  if idx >= LDatasets.Count then
    idx := LDatasets.Count - 1;
  if idx >= 0 then
    LDatasets.ItemIndex := idx;
  LoadDSDetails(idx);
end;

procedure TFRpDInfoLCL.BtnUpDSClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveDSIndex <= 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then Exit;
  if not CheckCanModify then Exit;
  SaveActiveDS;
  idx := FActiveDSIndex;
  FWork.DataInfo.Swap(idx, idx - 1);
  RefreshDSList;
  if idx - 1 < LDatasets.Items.Count then
  begin
    LDatasets.ItemIndex := idx - 1;
    LoadDSDetails(idx - 1);
  end;
end;

procedure TFRpDInfoLCL.BtnDownDSClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count - 1) then Exit;
  if not CheckCanModify then Exit;
  SaveActiveDS;
  idx := FActiveDSIndex;
  FWork.DataInfo.Swap(idx, idx + 1);
  RefreshDSList;
  if idx + 1 < LDatasets.Items.Count then
  begin
    LDatasets.ItemIndex := idx + 1;
    LoadDSDetails(idx + 1);
  end;
end;

procedure TFRpDInfoLCL.BtnRenameDSClick(Sender: TObject);
var
  oldAlias, newAlias: string;
  item: TRpDataInfoItem;
begin
  if (FActiveDSIndex < 0) or (FActiveDSIndex >= FWork.DataInfo.Count) then Exit;
  SaveActiveDS;
  item := FWork.DataInfo[FActiveDSIndex];
  oldAlias := item.Alias;
  newAlias := Trim(RpInputBox(SrpRenameDataset, SRpAliasName, oldAlias));
  if (newAlias = '') or SameText(newAlias, oldAlias) then Exit;
  if FWork.DataInfo.IndexOf(newAlias) >= 0 then
    raise Exception.Create(SRpAliasExists);
  if not CheckCanModify then Exit;
  item.Alias := newAlias;
  EDSAlias.Text := item.Alias;
  RefreshDSList;
  LDatasets.ItemIndex := FWork.DataInfo.IndexOf(newAlias);
  LoadDSDetails(LDatasets.ItemIndex);
end;

procedure TFRpDInfoLCL.BParamsClick(Sender: TObject);
var
  current: Integer;
begin
  // VCL TFRpDatasetsVCL.BParamsClick: edit the working parameters, the undo
  // operations are recorded when the whole dialog is accepted
  if not CheckCanModify then Exit;
  SaveActiveConn;
  SaveActiveDS;
  current := FActiveDSIndex;
  ShowParamDef(FWork.Params, FWork.DataInfo, FWork, True);
  if current >= 0 then
    LoadDSDetails(current);
end;

function TFRpDInfoLCL.HasPendingChanges: Boolean;
begin
  Result := (not SameDatabaseInfoList(FOrigDatabaseInfo, FWork.DatabaseInfo)) or
    (not SameDataInfoList(FOrigDataInfo, FWork.DataInfo)) or
    (not SameParamList(FOrigParams, FWork.Params));
end;

function TFRpDInfoLCL.OrderChanged: Boolean;
var
  i, j: Integer;
  lastIndex: Integer;
begin
  // Undo operations restore items by name, not their relative order
  Result := False;
  lastIndex := -1;
  for i := 0 to FWork.DataInfo.Count - 1 do
  begin
    for j := 0 to FOrigDataInfo.Count - 1 do
    begin
      if SameText(FOrigDataInfo.Items[j].Name, FWork.DataInfo.Items[i].Name) then
      begin
        if j < lastIndex then
          Exit(True);
        lastIndex := j;
        Break;
      end;
    end;
  end;
  lastIndex := -1;
  for i := 0 to FWork.DatabaseInfo.Count - 1 do
  begin
    for j := 0 to FOrigDatabaseInfo.Count - 1 do
    begin
      if SameText(FOrigDatabaseInfo.Items[j].Name, FWork.DatabaseInfo.Items[i].Name) then
      begin
        if j < lastIndex then
          Exit(True);
        lastIndex := j;
        Break;
      end;
    end;
  end;
  lastIndex := -1;
  for i := 0 to FWork.Params.Count - 1 do
  begin
    for j := 0 to FOrigParams.Count - 1 do
    begin
      if SameText(FOrigParams.Items[j].IntName, FWork.Params.Items[i].IntName) then
      begin
        if j < lastIndex then
          Exit(True);
        lastIndex := j;
        Break;
      end;
    end;
  end;
end;

procedure TFRpDInfoLCL.RecordUndoChanges;
var
  undoCue: TUndoCue;
  groupId: Integer;
  i: Integer;
  origDB, newDB: TRpDatabaseInfoItem;
  origDS, newDS: TRpDataInfoItem;
  newDBInfo: TRpDatabaseInfoList;
  newDataInfo: TRpDataInfoList;
  op: TChangeObjectOperation;

  function FindDatabaseInfoByComponentName(infoList: TRpDatabaseInfoList;
    const componentName: string): TRpDatabaseInfoItem;
  var
    itemIndex: Integer;
  begin
    Result := nil;
    for itemIndex := 0 to infoList.Count - 1 do
    begin
      if SameText(infoList.Items[itemIndex].Name, componentName) then
      begin
        Result := infoList.Items[itemIndex];
        Exit;
      end;
    end;
  end;

  function FindDataInfoByComponentName(infoList: TRpDataInfoList;
    const componentName: string): TRpDataInfoItem;
  var
    itemIndex: Integer;
  begin
    Result := nil;
    for itemIndex := 0 to infoList.Count - 1 do
    begin
      if SameText(infoList.Items[itemIndex].Name, componentName) then
      begin
        Result := infoList.Items[itemIndex];
        Exit;
      end;
    end;
  end;

begin
  // Port of TFRpDInfoVCL.RecordUndoChanges
  if not Assigned(FReport) then
    Exit;
  if not Assigned(FReport.UndoCue) then
    FReport.UndoCue := TUndoCue.Create(FReport);
  undoCue := TUndoCue(FReport.UndoCue);
  groupId := undoCue.GetGroupId;
  newDBInfo := FWork.DatabaseInfo;
  newDataInfo := FWork.DataInfo;
  // DatabaseInfo changes
  for i := 0 to FOrigDatabaseInfo.Count - 1 do
  begin
    origDB := FOrigDatabaseInfo.Items[i];
    if FindDatabaseInfoByComponentName(newDBInfo, origDB.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otRemove, groupId);
      op.componentName := origDB.Name;
      op.componentClass := 'TRPDATABASEINFOITEM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, origDB.Alias, Null);
      op.AddProperty('driver', ptInteger, Integer(origDB.Driver), Null);
      op.AddProperty('configFile', ptString, origDB.ConfigFile, Null);
      op.AddProperty('loginPrompt', ptBoolean, origDB.LoginPrompt, Null);
      op.AddProperty('loadParams', ptBoolean, origDB.LoadParams, Null);
      op.AddProperty('loadDriverParams', ptBoolean, origDB.LoadDriverParams, Null);
      op.AddProperty('connectionString', ptString, origDB.ADOConnectionString, Null);
      op.AddProperty('providerFactory', ptString, origDB.ProviderFactory, Null);
      op.AddProperty('dotNetDriver', ptInteger, origDB.DotNetDriver, Null);
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDBInfo.Count - 1 do
  begin
    newDB := newDBInfo.Items[i];
    if FindDatabaseInfoByComponentName(FOrigDatabaseInfo, newDB.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otAdd, groupId);
      op.componentName := newDB.Name;
      op.componentClass := 'TRPDATABASEINFOITEM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, Null, newDB.Alias);
      op.AddProperty('driver', ptInteger, Null, Integer(newDB.Driver));
      op.AddProperty('configFile', ptString, Null, newDB.ConfigFile);
      op.AddProperty('loginPrompt', ptBoolean, Null, newDB.LoginPrompt);
      op.AddProperty('loadParams', ptBoolean, Null, newDB.LoadParams);
      op.AddProperty('loadDriverParams', ptBoolean, Null, newDB.LoadDriverParams);
      op.AddProperty('connectionString', ptString, Null, newDB.ADOConnectionString);
      op.AddProperty('providerFactory', ptString, Null, newDB.ProviderFactory);
      op.AddProperty('dotNetDriver', ptInteger, Null, newDB.DotNetDriver);
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDBInfo.Count - 1 do
  begin
    newDB := newDBInfo.Items[i];
    origDB := FindDatabaseInfoByComponentName(FOrigDatabaseInfo, newDB.Name);
    if Assigned(origDB) then
    begin
      op := TChangeObjectOperation.Create(otModify, groupId);
      op.componentName := newDB.Name;
      op.componentClass := 'TRPDATABASEINFOITEM';
      if origDB.Alias <> newDB.Alias then
        op.AddProperty('alias', ptString, origDB.Alias, newDB.Alias);
      if Integer(origDB.Driver) <> Integer(newDB.Driver) then
        op.AddProperty('driver', ptInteger, Integer(origDB.Driver), Integer(newDB.Driver));
      if origDB.ConfigFile <> newDB.ConfigFile then
        op.AddProperty('configFile', ptString, origDB.ConfigFile, newDB.ConfigFile);
      if origDB.LoginPrompt <> newDB.LoginPrompt then
        op.AddProperty('loginPrompt', ptBoolean, origDB.LoginPrompt, newDB.LoginPrompt);
      if origDB.LoadParams <> newDB.LoadParams then
        op.AddProperty('loadParams', ptBoolean, origDB.LoadParams, newDB.LoadParams);
      if origDB.LoadDriverParams <> newDB.LoadDriverParams then
        op.AddProperty('loadDriverParams', ptBoolean, origDB.LoadDriverParams, newDB.LoadDriverParams);
      if origDB.ADOConnectionString <> newDB.ADOConnectionString then
        op.AddProperty('connectionString', ptString, origDB.ADOConnectionString, newDB.ADOConnectionString);
      if origDB.ProviderFactory <> newDB.ProviderFactory then
        op.AddProperty('providerFactory', ptString, origDB.ProviderFactory, newDB.ProviderFactory);
      if origDB.DotNetDriver <> newDB.DotNetDriver then
        op.AddProperty('dotNetDriver', ptInteger, origDB.DotNetDriver, newDB.DotNetDriver);
      if op.properties.Count > 0 then
        undoCue.AddOperation(op)
      else
        op.Free;
    end;
  end;
  // DataInfo changes
  for i := 0 to FOrigDataInfo.Count - 1 do
  begin
    origDS := FOrigDataInfo.Items[i];
    if FindDataInfoByComponentName(newDataInfo, origDS.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otRemove, groupId);
      op.componentName := origDS.Name;
      op.componentClass := 'TRPDATAINFOITEM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, origDS.Alias, Null);
      op.AddProperty('databaseAlias', ptString, origDS.DatabaseAlias, Null);
      op.AddProperty('sql', ptString, origDS.SQL, Null);
      op.AddProperty('hubSchemaId', ptInteger, origDS.HubSchemaId, Null);
      op.AddProperty('dataSource', ptString, origDS.DataSource, Null);
      op.AddProperty('groupUnion', ptBoolean, origDS.GroupUnion, Null);
      op.AddProperty('openOnStart', ptBoolean, origDS.OpenOnStart, Null);
      op.AddProperty('parallelUnion', ptBoolean, origDS.ParallelUnion, Null);
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDataInfo.Count - 1 do
  begin
    newDS := newDataInfo.Items[i];
    if FindDataInfoByComponentName(FOrigDataInfo, newDS.Name) = nil then
    begin
      op := TChangeObjectOperation.Create(otAdd, groupId);
      op.componentName := newDS.Name;
      op.componentClass := 'TRPDATAINFOITEM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, Null, newDS.Alias);
      op.AddProperty('databaseAlias', ptString, Null, newDS.DatabaseAlias);
      op.AddProperty('sql', ptString, Null, newDS.SQL);
      op.AddProperty('hubSchemaId', ptInteger, Null, newDS.HubSchemaId);
      op.AddProperty('dataSource', ptString, Null, newDS.DataSource);
      op.AddProperty('groupUnion', ptBoolean, Null, newDS.GroupUnion);
      op.AddProperty('openOnStart', ptBoolean, Null, newDS.OpenOnStart);
      op.AddProperty('parallelUnion', ptBoolean, Null, newDS.ParallelUnion);
      undoCue.AddOperation(op);
    end;
  end;
  for i := 0 to newDataInfo.Count - 1 do
  begin
    newDS := newDataInfo.Items[i];
    origDS := FindDataInfoByComponentName(FOrigDataInfo, newDS.Name);
    if Assigned(origDS) then
    begin
      op := TChangeObjectOperation.Create(otModify, groupId);
      op.componentName := newDS.Name;
      op.componentClass := 'TRPDATAINFOITEM';
      if origDS.Alias <> newDS.Alias then
        op.AddProperty('alias', ptString, origDS.Alias, newDS.Alias);
      if origDS.DatabaseAlias <> newDS.DatabaseAlias then
        op.AddProperty('databaseAlias', ptString, origDS.DatabaseAlias, newDS.DatabaseAlias);
      if origDS.SQL <> newDS.SQL then
        op.AddProperty('sql', ptString, origDS.SQL, newDS.SQL);
      if origDS.HubSchemaId <> newDS.HubSchemaId then
        op.AddProperty('hubSchemaId', ptInteger, origDS.HubSchemaId, newDS.HubSchemaId);
      if origDS.DataSource <> newDS.DataSource then
        op.AddProperty('dataSource', ptString, origDS.DataSource, newDS.DataSource);
      if origDS.GroupUnion <> newDS.GroupUnion then
        op.AddProperty('groupUnion', ptBoolean, origDS.GroupUnion, newDS.GroupUnion);
      if origDS.OpenOnStart <> newDS.OpenOnStart then
        op.AddProperty('openOnStart', ptBoolean, origDS.OpenOnStart, newDS.OpenOnStart);
      if origDS.ParallelUnion <> newDS.ParallelUnion then
        op.AddProperty('parallelUnion', ptBoolean, origDS.ParallelUnion, newDS.ParallelUnion);
      if op.properties.Count > 0 then
        undoCue.AddOperation(op)
      else
        op.Free;
    end;
  end;
  RecordParamUndoChanges(FOrigParams, FWork.Params, FReport, groupId);
end;

function TFRpDInfoLCL.ApplyChanges: Boolean;
var
  needsExternalMark: Boolean;
begin
  Result := True;
  SaveActiveConn;
  SaveActiveDS;
  if (not Assigned(FReport)) or (not HasPendingChanges) then
    Exit;
  if not FReport.CanModify('Database configuration') then
  begin
    Result := False;
    Exit;
  end;
  // Relative order changes (dataset up/down) can not be restored by the
  // name based undo operations: keep the report dirty for them
  needsExternalMark := OrderChanged;
  RecordUndoChanges;
  FReport.DatabaseInfo.Assign(FWork.DatabaseInfo);
  FReport.DataInfo.Assign(FWork.DataInfo);
  FReport.Params.Assign(FWork.Params);
  if needsExternalMark then
    TUndoCue(FReport.UndoCue).MarkExternalChange;
  FApplied := True;
  // Next edits start from the applied state
  FOrigDatabaseInfo.Assign(FReport.DatabaseInfo);
  FOrigDataInfo.Assign(FReport.DataInfo);
  FOrigParams.Assign(FReport.Params);
end;

procedure TFRpDInfoLCL.BOkClick(Sender: TObject);
begin
  if ApplyChanges then
    ModalResult := mrOk;
end;

procedure TFRpDInfoLCL.BCancelClick(Sender: TObject);
begin
  // Working copies are discarded, the report was never touched
  ModalResult := mrCancel;
end;

end.

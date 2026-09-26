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
  StdCtrls, ExtCtrls, ComCtrls,
  rpreport, rpdatainfo, rpmdconsts, rptypes, rpfrmmonacoeditorlcl, rpmdimageslcl;

type
  TFRpDInfoLCL = class(TForm)
  private
    FReport: TRpReport;
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

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Report: TRpReport read FReport write SetReport;
    property MonacoEditor: TFRpMonacoEditorLCL read FMonacoEditor;
  end;

procedure ShowDataConfig(report: TRpReport);

implementation

{$R *.lfm}

var
  GDataConfigDialog: TFRpDInfoLCL = nil;

procedure ShowDataConfig(report: TRpReport);
begin
  if not Assigned(report) then Exit;
  if GDataConfigDialog = nil then
    GDataConfigDialog := TFRpDInfoLCL.Create(Application);
  GDataConfigDialog.Report := report;
  GDataConfigDialog.ShowModal;
end;

constructor TFRpDInfoLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActiveConnIndex := -1;
  FActiveDSIndex := -1;
  FUpdatingControls := False;

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

  BOk := TButton.Create(PBottom);
  BOk.Parent := PBottom;
  BOk.Caption := TranslateStr(93, 'OK');
  BOk.ModalResult := mrOk;
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
  TabConnections.Caption := TranslateStr(142, 'Connections');
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
  BNewConn.Hint := TranslateStr(734, 'New Connection');
  BNewConn.OnClick := BNewConnClick;

  SepConn := TToolButton.Create(ToolBarConn);
  SepConn.Parent := ToolBarConn;
  SepConn.Style := tbsSeparator;
  SepConn.Width := 8;

  BDelConn := TToolButton.Create(ToolBarConn);
  BDelConn.Parent := ToolBarConn;
  BDelConn.ImageIndex := IMG_DC_DELETE;
  BDelConn.Hint := TranslateStr(138, 'Delete');
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
  TabDatasets.Caption := TranslateStr(148, 'Datasets');
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
  BNewDS.Hint := TranslateStr(734, 'New Dataset');
  BNewDS.OnClick := BNewDSClick;

  BtnUpDS := TToolButton.Create(ToolBarDS);
  BtnUpDS.Parent := ToolBarDS;
  BtnUpDS.ImageIndex := IMG_DC_UP;
  BtnUpDS.Hint := TranslateStr(139, 'Up');
  BtnUpDS.OnClick := BtnUpDSClick;

  BtnDownDS := TToolButton.Create(ToolBarDS);
  BtnDownDS.Parent := ToolBarDS;
  BtnDownDS.ImageIndex := IMG_DC_DOWN;
  BtnDownDS.Hint := TranslateStr(140, 'Down');
  BtnDownDS.OnClick := BtnDownDSClick;

  SepDS1 := TToolButton.Create(ToolBarDS);
  SepDS1.Parent := ToolBarDS;
  SepDS1.Style := tbsSeparator;
  SepDS1.Width := 8;

  BDelDS := TToolButton.Create(ToolBarDS);
  BDelDS.Parent := ToolBarDS;
  BDelDS.ImageIndex := IMG_DC_DELETE;
  BDelDS.Hint := TranslateStr(138, 'Delete');
  BDelDS.OnClick := BDelDSClick;

  SepDS2 := TToolButton.Create(ToolBarDS);
  SepDS2.Parent := ToolBarDS;
  SepDS2.Style := tbsSeparator;
  SepDS2.Width := 8;

  BtnRenameDS := TToolButton.Create(ToolBarDS);
  BtnRenameDS.Parent := ToolBarDS;
  BtnRenameDS.ImageIndex := IMG_DC_RENAME;
  BtnRenameDS.Hint := TranslateStr(141, 'Rename');
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
  FActiveConnIndex := -1;
  FActiveDSIndex := -1;

  RefreshConnList;
  RefreshDSList;

  if (FReport.DatabaseInfo.Count = 0) and (FReport.DataInfo.Count = 0) then
    PControl.ActivePage := TabConnections
  else if FReport.DataInfo.Count > 0 then
    PControl.ActivePage := TabDatasets
  else
    PControl.ActivePage := TabConnections;
end;

procedure TFRpDInfoLCL.RefreshConnList;
var
  i: Integer;
begin
  LConnections.Items.BeginUpdate;
  try
    LConnections.Clear;
    if Assigned(FReport) then
    begin
      for i := 0 to FReport.DatabaseInfo.Count - 1 do
        LConnections.Items.Add(FReport.DatabaseInfo[i].Alias);
    end;
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
    if Assigned(FReport) then
    begin
      for i := 0 to FReport.DataInfo.Count - 1 do
        LDatasets.Items.Add(FReport.DataInfo[i].Alias);
    end;
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
    if Assigned(FReport) then
    begin
      for i := 0 to FReport.DatabaseInfo.Count - 1 do
        ComboDSConn.Items.Add(FReport.DatabaseInfo[i].Alias);
    end;
  finally
    ComboDSConn.Items.EndUpdate;
  end;
  ComboDSConn.ItemIndex := ComboDSConn.Items.IndexOf(curDSConn);

  ComboDSMaster.Items.BeginUpdate;
  try
    ComboDSMaster.Clear;
    ComboDSMaster.Items.Add('');
    if Assigned(FReport) then
    begin
      for i := 0 to FReport.DataInfo.Count - 1 do
      begin
        if (FActiveDSIndex < 0) or (i <> FActiveDSIndex) then
          ComboDSMaster.Items.Add(FReport.DataInfo[i].Alias);
      end;
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
  if (FActiveConnIndex < 0) or not Assigned(FReport) or
     (FActiveConnIndex >= FReport.DatabaseInfo.Count) then
    Exit;

  item := FReport.DatabaseInfo[FActiveConnIndex];
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
  if (FActiveDSIndex < 0) or not Assigned(FReport) or
     (FActiveDSIndex >= FReport.DataInfo.Count) then
    Exit;

  item := FReport.DataInfo[FActiveDSIndex];
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
    if (Index < 0) or not Assigned(FReport) or (Index >= FReport.DatabaseInfo.Count) then
    begin
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
    item := FReport.DatabaseInfo[Index];
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
    RefreshConnCombos;

    if (Index < 0) or not Assigned(FReport) or (Index >= FReport.DataInfo.Count) then
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
      Exit;
    end;

    PDSProps.Enabled := True;
    PSQLArea.Enabled := True;
    BDelDS.Enabled := True;
    BtnUpDS.Enabled := (Index > 0);
    BtnDownDS.Enabled := (Index < FReport.DataInfo.Count - 1);
    BtnRenameDS.Enabled := True;
    item := FReport.DataInfo[Index];
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
  if not Assigned(FReport) then Exit;
  SaveActiveConn;

  n := FReport.DatabaseInfo.Count + 1;
  repeat
    newAlias := 'CONNECTION' + IntToStr(n);
    Inc(n);
  until FReport.DatabaseInfo.IndexOf(newAlias) < 0;

  item := FReport.DatabaseInfo.Add(newAlias);
  item.Driver := rpdatadriver;

  LConnections.Items.Add(newAlias);
  LConnections.ItemIndex := LConnections.Count - 1;
  LoadConnDetails(LConnections.ItemIndex);
  EConnAlias.SetFocus;
  EConnAlias.SelectAll;
end;

procedure TFRpDInfoLCL.BDelConnClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveConnIndex < 0) or not Assigned(FReport) or
     (FActiveConnIndex >= FReport.DatabaseInfo.Count) then
    Exit;

  idx := FActiveConnIndex;
  FActiveConnIndex := -1;
  FReport.DatabaseInfo.Delete(idx);
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
  if not Assigned(FReport) then Exit;
  SaveActiveDS;

  n := FReport.DataInfo.Count + 1;
  repeat
    newAlias := 'DATASET' + IntToStr(n);
    Inc(n);
  until FReport.DataInfo.IndexOf(newAlias) < 0;

  item := FReport.DataInfo.Add(newAlias);
  item.OpenOnStart := True;
  if FReport.DatabaseInfo.Count > 0 then
    item.DatabaseAlias := FReport.DatabaseInfo[0].Alias;

  LDatasets.Items.Add(newAlias);
  LDatasets.ItemIndex := LDatasets.Count - 1;
  LoadDSDetails(LDatasets.ItemIndex);
  EDSAlias.SetFocus;
  EDSAlias.SelectAll;
end;

procedure TFRpDInfoLCL.BDelDSClick(Sender: TObject);
var
  idx: Integer;
begin
  if (FActiveDSIndex < 0) or not Assigned(FReport) or
     (FActiveDSIndex >= FReport.DataInfo.Count) then
    Exit;

  idx := FActiveDSIndex;
  FActiveDSIndex := -1;
  FReport.DataInfo.Delete(idx);
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
  if not Assigned(FReport) or (FActiveDSIndex <= 0) or (FActiveDSIndex >= FReport.DataInfo.Count) then Exit;
  SaveActiveDS;
  idx := FActiveDSIndex;
  FReport.DataInfo.Swap(idx, idx - 1);
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
  if not Assigned(FReport) or (FActiveDSIndex < 0) or (FActiveDSIndex >= FReport.DataInfo.Count - 1) then Exit;
  SaveActiveDS;
  idx := FActiveDSIndex;
  FReport.DataInfo.Swap(idx, idx + 1);
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
  if not Assigned(FReport) or (FActiveDSIndex < 0) or (FActiveDSIndex >= FReport.DataInfo.Count) then Exit;
  item := FReport.DataInfo[FActiveDSIndex];
  oldAlias := item.Alias;
  newAlias := Trim(InputBox(TranslateStr(141, 'Rename dataset'), TranslateStr(137, 'Alias:'), oldAlias));
  if (newAlias = '') or (newAlias = oldAlias) then Exit;
  if FReport.DataInfo.IndexOf(newAlias) >= 0 then
  begin
    ShowMessage(TranslateStr(143, 'Alias already exists'));
    Exit;
  end;
  item.Alias := newAlias;
  EDSAlias.Text := newAlias;
  RefreshDSList;
  LDatasets.ItemIndex := FReport.DataInfo.IndexOf(newAlias);
  LoadDSDetails(LDatasets.ItemIndex);
end;

procedure TFRpDInfoLCL.BOkClick(Sender: TObject);
begin
  SaveActiveConn;
  SaveActiveDS;
  if Assigned(FReport) then
    FReport.Modified := True;
  ModalResult := mrOk;
end;

procedure TFRpDInfoLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.

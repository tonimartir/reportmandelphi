{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfwizardlcl                                  }
{       Wizard to create new reports for LCL            }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfwizardlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, Buttons,
  rptypes, rpreport, rpdatainfo, rpmdconsts, rpcolumnar,
  rppagesetuplcl, rpmdfdinfolcl, rpmdfselectfieldslcl, rpmdundocuelcl;

type
  { TFRpWizardLCL }

  TFRpWizardLCL = class(TForm)
  private
    FReport: TRpReport;
    FCreated: Boolean;
    FFromTemplate: Boolean;

    PControl: TPageControl;
    TabInstructions: TTabSheet;
    TabData: TTabSheet;
    TabFields: TTabSheet;

    // Instructions page controls
    LTitle: TLabel;
    LPass1: TLabel;
    BPageSetup: TButton;
    LPass2: TLabel;
    BConfigData: TButton;
    LPass3: TLabel;
    LBegin: TLabel;

    // Data page controls
    LDataInfo: TLabel;
    LConnectionsSummary: TLabel;
    LDatasetsSummary: TLabel;
    BOpenDataConfig: TButton;

    // Fields page frame
    FSelFrame: TFRpSelectFieldsLCL;

    // Bottom navigation panel
    PBottom: TPanel;
    BBack: TButton;
    BNext: TButton;
    BFinish: TButton;
    BCancel: TButton;

    procedure BuildControls;
    procedure BBackClick(Sender: TObject);
    procedure BNextClick(Sender: TObject);
    procedure BFinishClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure BPageSetupClick(Sender: TObject);
    procedure BConfigDataClick(Sender: TObject);
    procedure PControlChange(Sender: TObject);
    procedure UpdateDataSummary;
  public
    constructor Create(AOwner: TComponent); override;

    property Report: TRpReport read FReport write FReport;
    property Created: Boolean read FCreated;
    property FromTemplate: Boolean read FFromTemplate write FFromTemplate;
    property SelFrame: TFRpSelectFieldsLCL read FSelFrame;
  end;

function NewReportWizard(report: TRpReport; fromtemplate: Boolean): Boolean;

implementation

function NewReportWizard(report: TRpReport; fromtemplate: Boolean): Boolean;
var
  dia: TFRpWizardLCL;
  i: Integer;
begin
  Result := False;
  if not Assigned(report) then Exit;

  dia := TFRpWizardLCL.Create(Application);
  try
    dia.FromTemplate := fromtemplate;
    if not fromtemplate then
    begin
      report.CreateNew;
      report.SubReports[0].SubReport.AddGroup('TOTAL');
      for i := 0 to report.SubReports[0].SubReport.Sections.Count - 1 do
        report.SubReports[0].SubReport.Sections[i].Section.Height := 275;
    end;

    dia.Report := report;
    dia.ShowModal;
    Result := dia.Created;

    if Result and (not fromtemplate) and (report.DataInfo.Count > 0) then
      report.SubReports[0].SubReport.Alias := report.DataInfo.Items[0].Alias;
  finally
    dia.Free;
  end;
end;

{ TFRpWizardLCL }

constructor TFRpWizardLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := TranslateStr(935, 'New Report Wizard');
  Width := 600;
  Height := 460;
  Position := poScreenCenter;
  BorderStyle := bsDialog;

  FCreated := False;
  FFromTemplate := False;

  BuildControls;
end;

procedure TFRpWizardLCL.BuildControls;
begin
  // Bottom Navigation Panel
  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := 48;
  PBottom.BevelOuter := bvNone;

  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.Left := PBottom.Width - 90;
  BCancel.Top := 10;
  BCancel.Width := 80;
  BCancel.Height := 28;
  BCancel.Anchors := [akTop, akRight];
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;

  BFinish := TButton.Create(Self);
  BFinish.Parent := PBottom;
  BFinish.Caption := TranslateStr(935, 'Finish');
  BFinish.Left := PBottom.Width - 180;
  BFinish.Top := 10;
  BFinish.Width := 80;
  BFinish.Height := 28;
  BFinish.Anchors := [akTop, akRight];
  BFinish.OnClick := BFinishClick;

  BNext := TButton.Create(Self);
  BNext.Parent := PBottom;
  BNext.Caption := TranslateStr(933, 'Next');
  BNext.Left := PBottom.Width - 270;
  BNext.Top := 10;
  BNext.Width := 80;
  BNext.Height := 28;
  BNext.Anchors := [akTop, akRight];
  BNext.Default := True;
  BNext.OnClick := BNextClick;

  BBack := TButton.Create(Self);
  BBack.Parent := PBottom;
  BBack.Caption := TranslateStr(934, 'Back');
  BBack.Left := PBottom.Width - 360;
  BBack.Top := 10;
  BBack.Width := 80;
  BBack.Height := 28;
  BBack.Anchors := [akTop, akRight];
  BBack.OnClick := BBackClick;

  // PageControl
  PControl := TPageControl.Create(Self);
  PControl.Parent := Self;
  PControl.Align := alClient;
  PControl.OnChange := PControlChange;

  // Tab 1: Instructions
  TabInstructions := TTabSheet.Create(PControl);
  TabInstructions.PageControl := PControl;
  TabInstructions.Caption := TranslateStr(875, 'Instructions');

  LTitle := TLabel.Create(TabInstructions);
  LTitle.Parent := TabInstructions;
  LTitle.Caption := TranslateStr(869, 'To design a report with this wizard you must follow this steps');
  LTitle.Font.Size := 12;
  LTitle.Font.Style := [fsBold];
  LTitle.Left := 24;
  LTitle.Top := 20;

  LPass1 := TLabel.Create(TabInstructions);
  LPass1.Parent := TabInstructions;
  LPass1.Caption := '1. Set report page orientation and margins.';
  LPass1.Left := 24;
  LPass1.Top := 60;

  BPageSetup := TButton.Create(TabInstructions);
  BPageSetup.Parent := TabInstructions;
  BPageSetup.Caption := TranslateStr(50, 'Page setup...');
  BPageSetup.Left := 24;
  BPageSetup.Top := 82;
  BPageSetup.Width := 150;
  BPageSetup.Height := 28;
  BPageSetup.OnClick := BPageSetupClick;

  LPass2 := TLabel.Create(TabInstructions);
  LPass2.Parent := TabInstructions;
  LPass2.Caption := '2. Configure database connections and SQL datasets.';
  LPass2.Left := 24;
  LPass2.Top := 130;

  BConfigData := TButton.Create(TabInstructions);
  BConfigData.Parent := TabInstructions;
  BConfigData.Caption := TranslateStr(131, 'Data access configuration');
  BConfigData.Left := 24;
  BConfigData.Top := 152;
  BConfigData.Width := 150;
  BConfigData.Height := 28;
  BConfigData.OnClick := BConfigDataClick;

  LPass3 := TLabel.Create(TabInstructions);
  LPass3.Parent := TabInstructions;
  LPass3.Caption := TranslateStr(872, '3. Select dataset fields to print, follow instructions at select fields page');
  LPass3.Left := 24;
  LPass3.Top := 200;

  LBegin := TLabel.Create(TabInstructions);
  LBegin.Parent := TabInstructions;
  LBegin.Caption := TranslateStr(874, 'To begin the wizard click Next button');
  LBegin.Font.Color := clGrayText;
  LBegin.Left := 24;
  LBegin.Top := 250;

  // Tab 2: Data Access Summary & Config
  TabData := TTabSheet.Create(PControl);
  TabData.PageControl := PControl;
  TabData.Caption := TranslateStr(142, 'Database connections');

  LDataInfo := TLabel.Create(TabData);
  LDataInfo.Parent := TabData;
  LDataInfo.Caption := 'Configuración de acceso a base de datos del informe:';
  LDataInfo.Font.Style := [fsBold];
  LDataInfo.Left := 24;
  LDataInfo.Top := 20;

  LConnectionsSummary := TLabel.Create(TabData);
  LConnectionsSummary.Parent := TabData;
  LConnectionsSummary.Caption := 'Conexiones: (ninguna)';
  LConnectionsSummary.Left := 24;
  LConnectionsSummary.Top := 55;

  LDatasetsSummary := TLabel.Create(TabData);
  LDatasetsSummary.Parent := TabData;
  LDatasetsSummary.Caption := 'Datasets / Consultas: (ninguno)';
  LDatasetsSummary.Left := 24;
  LDatasetsSummary.Top := 90;

  BOpenDataConfig := TButton.Create(TabData);
  BOpenDataConfig.Parent := TabData;
  BOpenDataConfig.Caption := 'Abrir editor de conexiones y consultas SQL...';
  BOpenDataConfig.Left := 24;
  BOpenDataConfig.Top := 135;
  BOpenDataConfig.Width := 280;
  BOpenDataConfig.Height := 32;
  BOpenDataConfig.OnClick := BConfigDataClick;

  // Tab 3: Fields Selection
  TabFields := TTabSheet.Create(PControl);
  TabFields.PageControl := PControl;
  TabFields.Caption := TranslateStr(877, 'Fields');

  FSelFrame := TFRpSelectFieldsLCL.Create(TabFields);
  FSelFrame.Parent := TabFields;

  PControl.ActivePageIndex := 0;
  PControlChange(PControl);
end;

procedure TFRpWizardLCL.UpdateDataSummary;
var
  i: Integer;
  connStr, dsStr: string;
begin
  if not Assigned(FReport) then Exit;

  if FReport.DatabaseInfo.Count = 0 then
    connStr := 'Conexiones configuradas: 0'
  else
  begin
    connStr := 'Conexiones configuradas (' + IntToStr(FReport.DatabaseInfo.Count) + '): ';
    for i := 0 to FReport.DatabaseInfo.Count - 1 do
    begin
      if i > 0 then connStr := connStr + ', ';
      connStr := connStr + FReport.DatabaseInfo.Items[i].Alias;
    end;
  end;
  LConnectionsSummary.Caption := connStr;

  if FReport.DataInfo.Count = 0 then
    dsStr := 'Datasets / Consultas configuradas: 0'
  else
  begin
    dsStr := 'Datasets / Consultas configuradas (' + IntToStr(FReport.DataInfo.Count) + '): ';
    for i := 0 to FReport.DataInfo.Count - 1 do
    begin
      if i > 0 then dsStr := dsStr + ', ';
      dsStr := dsStr + FReport.DataInfo.Items[i].Alias;
    end;
  end;
  LDatasetsSummary.Caption := dsStr;
end;

procedure TFRpWizardLCL.PControlChange(Sender: TObject);
begin
  BBack.Enabled := PControl.ActivePageIndex > 0;
  BNext.Enabled := PControl.ActivePageIndex < PControl.PageCount - 1;
  BFinish.Enabled := PControl.ActivePageIndex = PControl.PageCount - 1;

  if PControl.ActivePage = TabData then
    UpdateDataSummary;

  if PControl.ActivePage = TabFields then
  begin
    FSelFrame.Report := FReport;
    FSelFrame.UpdateDatasets;
  end;
end;

procedure TFRpWizardLCL.BBackClick(Sender: TObject);
begin
  if PControl.ActivePageIndex > 0 then
  begin
    PControl.ActivePageIndex := PControl.ActivePageIndex - 1;
    PControlChange(PControl);
  end;
end;

procedure TFRpWizardLCL.BNextClick(Sender: TObject);
begin
  if PControl.ActivePageIndex < PControl.PageCount - 1 then
  begin
    PControl.ActivePageIndex := PControl.ActivePageIndex + 1;
    PControlChange(PControl);
  end;
end;

procedure TFRpWizardLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
  Close;
end;

procedure TFRpWizardLCL.BPageSetupClick(Sender: TObject);
begin
  if not Assigned(FReport) then
    Exit;
  // The page setup is applied to the report even if the wizard is cancelled
  // later: never lose the dirty state
  if ExecutePageSetup(FReport) then
  begin
    if not Assigned(FReport.UndoCue) then
      FReport.UndoCue := TUndoCue.Create(FReport);
    TUndoCue(FReport.UndoCue).MarkExternalChange;
  end;
end;

procedure TFRpWizardLCL.BConfigDataClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  // Changes are applied (and recorded in the undo cue) only on OK
  ShowDataConfig(FReport);
  UpdateDataSummary;
end;

procedure TFRpWizardLCL.BFinishClick(Sender: TObject);
var
  colrep: TRpColumnar;
  i, w: Integer;
  expression, sumexpr: string;
begin
  if not Assigned(FReport) then
  begin
    Close;
    Exit;
  end;

  colrep := TRpColumnar.Create;
  try
    colrep.Report := FReport;
    colrep.CutColumns := not FSelFrame.CheckProportional.Checked;
    for i := 0 to FSelFrame.LSelected.Items.Count - 1 do
    begin
      expression := FSelFrame.LSelected.Items.Strings[i];
      if FSelFrame.LSelected.Checked[i] then
        sumexpr := expression
      else
        sumexpr := '';

      w := 10;
      if i < FSelFrame.widths.Count then
        w := StrToIntDef(FSelFrame.widths.Strings[i], 10);

      colrep.AddColumn(w, expression, '', FSelFrame.fieldlabels.Strings[i], '', sumexpr, '');
    end;
  finally
    colrep.Free;
  end;

  FCreated := True;
  ModalResult := mrOk;
  Close;
end;

end.

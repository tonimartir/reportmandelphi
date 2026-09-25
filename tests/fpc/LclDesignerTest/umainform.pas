unit umainform;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, ComCtrls,
  rpreport, rpsubreport, rpmdfdesignlcl, rprulerlcl, rpmunits;

type
  TMainForm = class(TForm)
    PTop: TPanel;
    PClient: TPanel;
    StatusBar: TStatusBar;
    BtnOpen: TButton;
    BtnSample4: TButton;
    BtnBold: TButton;
    BtnHtml: TButton;
    LblSubrep: TLabel;
    CbSubreport: TComboBox;
    LblZoom: TLabel;
    BtnZoom50: TButton;
    BtnZoom75: TButton;
    BtnZoom100: TButton;
    BtnZoom150: TButton;
    ChkGrid: TCheckBox;
    CbUnits: TComboBox;
    OpenDialog: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnSample4Click(Sender: TObject);
    procedure BtnBoldClick(Sender: TObject);
    procedure BtnHtmlClick(Sender: TObject);
    procedure CbSubreportChange(Sender: TObject);
    procedure BtnZoomClick(Sender: TObject);
    procedure ChkGridChange(Sender: TObject);
    procedure CbUnitsChange(Sender: TObject);
  private
    FReport: TRpReport;
    FDesignerFrame: TFRpDesignFrameLCL;
    FCurrentFileName: string;
    FAutoTestMode: Boolean;
    function FindSampleFile(const AName: string): string;
    procedure RefreshSubreportList;
    procedure UpdateStatus;
    procedure RunSelfTest(Data: PtrInt);
  public
    procedure LoadReportFile(const AFileName: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

procedure TMainForm.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  FAutoTestMode := False;
  for i := 1 to Application.ParamCount do
  begin
    if (Application.Params[i] = '--selftest') or
       (Application.Params[i] = '--run-and-exit') then
      FAutoTestMode := True;
  end;

  FDesignerFrame := TFRpDesignFrameLCL.Create(Self);
  FDesignerFrame.Parent := PClient;
  FDesignerFrame.Align := alClient;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FReport);
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  samplePath: string;
begin
  if FAutoTestMode then
    Application.QueueAsyncCall(RunSelfTest, 0)
  else
  begin
    samplePath := FindSampleFile('sample4.rep');
    if FileExists(samplePath) then
      LoadReportFile(samplePath);
  end;
end;

function TMainForm.FindSampleFile(const AName: string): string;
var
  p: string;
begin
  Result := '';
  p := ExtractFilePath(Application.ExeName) + '..\..\..\repman\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := ExtractFilePath(Application.ExeName) + '..\..\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := 'repman\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));

  p := 'C:\desarrollo\prog\toni\reportman\repman\repsamples\' + AName;
  if FileExists(p) then Exit(ExpandFileName(p));
end;

procedure TMainForm.LoadReportFile(const AFileName: string);
begin
  if not FileExists(AFileName) then
  begin
    ShowMessage('Archivo no encontrado: ' + AFileName);
    Exit;
  end;

  FreeAndNil(FReport);
  FReport := TRpReport.Create(Self);
  try
    FReport.LoadFromFile(AFileName);
    FCurrentFileName := AFileName;
    FDesignerFrame.Report := FReport;
    RefreshSubreportList;
    UpdateStatus;
  except
    on E: Exception do
    begin
      FreeAndNil(FReport);
      FDesignerFrame.Report := nil;
      ShowMessage('Error cargando reporte: ' + E.Message);
    end;
  end;
end;

procedure TMainForm.RefreshSubreportList;
var
  i: Integer;
begin
  CbSubreport.Items.Clear;
  if Assigned(FReport) then
  begin
    for i := 0 to FReport.SubReports.Count - 1 do
      CbSubreport.Items.Add('SubReport ' + IntToStr(i + 1));
    if CbSubreport.Items.Count > 0 then
      CbSubreport.ItemIndex := 0;
  end;
end;

procedure TMainForm.UpdateStatus;
var
  secCount: Integer;
  subName: string;
begin
  if Assigned(FReport) then
  begin
    StatusBar.Panels[0].Text := 'Reporte: ' + ExtractFileName(FCurrentFileName);
    secCount := 0;
    subName := '-';
    if Assigned(FDesignerFrame.CurrentSubreport) then
    begin
      secCount := FDesignerFrame.CurrentSubreport.Sections.Count;
      subName := 'SubReport (' + IntToStr(secCount) + ' secciones)';
    end;
    StatusBar.Panels[1].Text := subName;
    StatusBar.Panels[2].Text := 'Zoom: ' + IntToStr(Round(FDesignerFrame.Scale * 100)) + '%';
    StatusBar.Panels[3].Text := 'Listo';
  end
  else
  begin
    StatusBar.Panels[0].Text := 'Reporte: Ninguno';
    StatusBar.Panels[1].Text := '-';
    StatusBar.Panels[2].Text := 'Zoom: 100%';
    StatusBar.Panels[3].Text := 'Listo';
  end;
end;

procedure TMainForm.BtnOpenClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    LoadReportFile(OpenDialog.FileName);
end;

procedure TMainForm.BtnSample4Click(Sender: TObject);
var
  p: string;
begin
  p := FindSampleFile('sample4.rep');
  if Length(p) > 0 then
    LoadReportFile(p)
  else
    ShowMessage('No se pudo encontrar sample4.rep');
end;

procedure TMainForm.BtnBoldClick(Sender: TObject);
var
  p: string;
begin
  p := FindSampleFile('bold.rep');
  if Length(p) > 0 then
    LoadReportFile(p)
  else
    ShowMessage('No se pudo encontrar bold.rep');
end;

procedure TMainForm.BtnHtmlClick(Sender: TObject);
var
  p: string;
begin
  p := FindSampleFile('htmltest.rep');
  if Length(p) > 0 then
    LoadReportFile(p)
  else
    ShowMessage('No se pudo encontrar htmltest.rep');
end;

procedure TMainForm.CbSubreportChange(Sender: TObject);
begin
  if Assigned(FReport) and (CbSubreport.ItemIndex >= 0) and
     (CbSubreport.ItemIndex < FReport.SubReports.Count) then
  begin
    FDesignerFrame.SelectSubReport(FReport.SubReports[CbSubreport.ItemIndex].SubReport);
    UpdateStatus;
  end;
end;

procedure TMainForm.BtnZoomClick(Sender: TObject);
var
  nScale: Double;
begin
  nScale := TButton(Sender).Tag / 100.0;
  if nScale > 0 then
  begin
    FDesignerFrame.Scale := nScale;
    UpdateStatus;
  end;
end;

procedure TMainForm.ChkGridChange(Sender: TObject);
begin
  if Assigned(FReport) then
  begin
    FReport.GridVisible := ChkGrid.Checked;
    FDesignerFrame.UpdateInterface(False);
  end;
end;

procedure TMainForm.CbUnitsChange(Sender: TObject);
begin
  if CbUnits.ItemIndex = 0 then
  begin
    rpmunits.defaultunit := rpUnitCms;
    FDesignerFrame.TopRuler.Metrics := rCms;
  end
  else
  begin
    rpmunits.defaultunit := rpUnitInchess;
    FDesignerFrame.TopRuler.Metrics := rInchess;
  end;
  FDesignerFrame.UpdateInterface(False);
end;

procedure TMainForm.RunSelfTest(Data: PtrInt);
var
  samplePath: string;
  ok: Boolean;
begin
  ok := False;
  try
    samplePath := FindSampleFile('sample4.rep');
    if not FileExists(samplePath) then
    begin
      WriteLn('[TEST_FAILED] sample4.rep not found');
      Halt(1);
    end;

    LoadReportFile(samplePath);

    if not Assigned(FReport) then
    begin
      WriteLn('[TEST_FAILED] Failed to load FReport');
      Halt(1);
    end;

    if FDesignerFrame.secinterfaces.Count = 0 then
    begin
      WriteLn('[TEST_FAILED] No section interfaces created in designer frame');
      Halt(1);
    end;

    // Test Zoom / Scale
    FDesignerFrame.Scale := 1.5;
    FDesignerFrame.UpdateInterface(True);
    FDesignerFrame.Scale := 1.0;
    FDesignerFrame.UpdateInterface(True);

    // Test Units
    FDesignerFrame.TopRuler.Metrics := rInchess;
    FDesignerFrame.TopRuler.Metrics := rCms;

    // Test other sample
    samplePath := FindSampleFile('bold.rep');
    if FileExists(samplePath) then
    begin
      LoadReportFile(samplePath);
      if FDesignerFrame.secinterfaces.Count = 0 then
      begin
        WriteLn('[TEST_FAILED] Failed on bold.rep');
        Halt(1);
      end;
    end;

    ok := True;
    WriteLn('[TEST_PASSED] LCL Designer Test OK');
  except
    on E: Exception do
      WriteLn('[TEST_FAILED] Exception: ' + E.Message);
  end;

  if ok then
    Halt(0)
  else
    Halt(1);
end;

end.

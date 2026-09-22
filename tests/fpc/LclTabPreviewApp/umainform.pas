unit umainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  ExtCtrls, rpreport, rpmetafile, rppreviewcontrol, rppreviewmetalcl;

type

  { TMainForm }

  TMainForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    pnlSetup: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    lblReport: TLabel;
    cbReports: TComboBox;
    btnPreview: TButton;
    memoInfo: TMemo;
    pnlToolbar: TPanel;
    btnBack: TButton;
    btnFirst: TButton;
    btnPrior: TButton;
    lblPage: TLabel;
    btnNext: TButton;
    btnLast: TButton;
    btnFitWidth: TButton;
    btnFitPage: TButton;
    btnRealSize: TButton;
    btnZoomIn: TButton;
    btnZoomOut: TButton;
    pnlPreviewHost: TPanel;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnPreviewClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure btnFirstClick(Sender: TObject);
    procedure btnPriorClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnLastClick(Sender: TObject);
    procedure btnFitWidthClick(Sender: TObject);
    procedure btnFitPageClick(Sender: TObject);
    procedure btnRealSizeClick(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
  private
    FReport: TRpReport;
    FPreview: TRpPreviewControl;
    function FindReportFile(const AFileName: string): string;
    procedure UpdatePageStatus;
    procedure OnPreviewPageDrawn(prm: TRpPreviewMeta);
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet1;

  // Crear el control de previsualización LCL dinámicamente en TabSheet2
  FPreview := TRpPreviewControl.Create(Self);
  FPreview.Parent := pnlPreviewHost;
  FPreview.Align := alClient;
  FPreview.AutoScale := AScaleWide;
  FPreview.OnPageDrawn := @OnPreviewPageDrawn;

  UpdatePageStatus;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if Assigned(FReport) then
  begin
    FPreview.Report := nil;
    FreeAndNil(FReport);
  end;
end;

function TMainForm.FindReportFile(const AFileName: string): string;
var
  candidates: array[0..5] of string;
  appDir: string;
  i: Integer;
begin
  appDir := ExtractFilePath(Application.ExeName);
  candidates[0] := AFileName;
  candidates[1] := appDir + AFileName;
  candidates[2] := appDir + '..' + PathDelim + '..' + PathDelim + '..' + PathDelim + 'repman' + PathDelim + 'repsamples' + PathDelim + AFileName;
  candidates[3] := appDir + '..' + PathDelim + '..' + PathDelim + 'repman' + PathDelim + 'repsamples' + PathDelim + AFileName;
  candidates[4] := 'C:\desarrollo\prog\toni\reportman\repman\repsamples\' + AFileName;
  candidates[5] := '/mnt/c/desarrollo/prog/toni/reportman/repman/repsamples/' + AFileName;

  for i := 0 to High(candidates) do
  begin
    if (candidates[i] <> '') and FileExists(candidates[i]) then
      Exit(candidates[i]);
  end;
  Result := AFileName;
end;

procedure TMainForm.UpdatePageStatus;
var
  curPage, totalPages: Integer;
begin
  if Assigned(FPreview) and Assigned(FPreview.Metafile) then
  begin
    curPage := FPreview.Page + 1;
    totalPages := FPreview.Metafile.CurrentPageCount;
    if totalPages < 1 then
      totalPages := 1;
    lblPage.Caption := Format('Página: %d / %d', [curPage, totalPages]);
    btnFirst.Enabled := (curPage > 1);
    btnPrior.Enabled := (curPage > 1);
    btnNext.Enabled := (curPage < totalPages);
    btnLast.Enabled := (curPage < totalPages);
  end
  else
  begin
    lblPage.Caption := 'Página: - / -';
    btnFirst.Enabled := False;
    btnPrior.Enabled := False;
    btnNext.Enabled := False;
    btnLast.Enabled := False;
  end;
end;

procedure TMainForm.OnPreviewPageDrawn(prm: TRpPreviewMeta);
begin
  UpdatePageStatus;
end;

procedure TMainForm.btnPreviewClick(Sender: TObject);
var
  repFile, repPath: string;
begin
  repFile := cbReports.Text;
  if Trim(repFile) = '' then
    repFile := 'sample4.rep';

  repPath := FindReportFile(repFile);
  if not FileExists(repPath) then
  begin
    ShowMessage('No se ha encontrado el archivo de informe:' + sLineBreak + repPath);
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    if Assigned(FReport) then
    begin
      FPreview.Report := nil;
      FreeAndNil(FReport);
    end;

    FReport := TRpReport.Create(Self);
    FReport.LoadFromFile(repPath);

    // Asignar el informe al control de previsualización LCL
    FPreview.Report := FReport;
    FPreview.AutoScale := AScaleWide;
    FPreview.FirstPage;

    // Cambiar a la segunda pestaña (Vista Previa)
    PageControl1.ActivePage := TabSheet2;
    UpdatePageStatus;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.btnBackClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabSheet1;
end;

procedure TMainForm.btnFirstClick(Sender: TObject);
begin
  if Assigned(FPreview) then
  begin
    FPreview.FirstPage;
    UpdatePageStatus;
  end;
end;

procedure TMainForm.btnPriorClick(Sender: TObject);
begin
  if Assigned(FPreview) then
  begin
    FPreview.PriorPage;
    UpdatePageStatus;
  end;
end;

procedure TMainForm.btnNextClick(Sender: TObject);
begin
  if Assigned(FPreview) then
  begin
    FPreview.NextPage;
    UpdatePageStatus;
  end;
end;

procedure TMainForm.btnLastClick(Sender: TObject);
begin
  if Assigned(FPreview) then
  begin
    FPreview.LastPage;
    UpdatePageStatus;
  end;
end;

procedure TMainForm.btnFitWidthClick(Sender: TObject);
begin
  if Assigned(FPreview) then
    FPreview.AutoScale := AScaleWide;
end;

procedure TMainForm.btnFitPageClick(Sender: TObject);
begin
  if Assigned(FPreview) then
    FPreview.AutoScale := AScaleEntirePage;
end;

procedure TMainForm.btnRealSizeClick(Sender: TObject);
begin
  if Assigned(FPreview) then
    FPreview.AutoScale := AScaleReal;
end;

procedure TMainForm.btnZoomInClick(Sender: TObject);
begin
  if Assigned(FPreview) then
    FPreview.PreviewScale := FPreview.PreviewScale * 1.25;
end;

procedure TMainForm.btnZoomOutClick(Sender: TObject);
begin
  if Assigned(FPreview) then
    FPreview.PreviewScale := FPreview.PreviewScale * 0.8;
end;

end.

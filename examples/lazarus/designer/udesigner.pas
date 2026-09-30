unit udesigner;

{ Report Manager example: the report designer inside an LCL application, so
  its users can change their reports.

  RpDesignerLCL1 (TRpDesignerLCL, package reportman_designlcl) opens the
  designer on a copy of ../sales.rep in the configuration folder of the
  application; LCLReport1 (TLCLReport) previews the saved report. The
  designer gets the same data as the report, so its own preview works too. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, BufDataset,
  rplclreport, rpmdesignerlcl;

type

  { TFDesigner }

  TFDesigner = class(TForm)
    RpDesignerLCL1: TRpDesignerLCL;
    LCLReport1: TLCLReport;
    LInfo: TLabel;
    BDesign: TButton;
    BPreview: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BDesignClick(Sender: TObject);
    procedure BPreviewClick(Sender: TObject);
  private
    FData: TBufDataset;
    FReportFile: string;
  end;

var
  FDesigner: TFDesigner;

implementation

uses
  FileUtil, salesdata;

{$R *.lfm}

{ TFDesigner }

procedure TFDesigner.FormCreate(Sender: TObject);
begin
  FData := CreateSalesData(Self);
  // The user edits a copy: the report of the example stays as it is
  FReportFile := GetAppConfigDir(False) + 'sales.rep';
  if not FileExists(FReportFile) then
  begin
    ForceDirectories(ExtractFilePath(FReportFile));
    CopyFile(SalesReportFile, FReportFile);
  end;
  LInfo.Caption := 'Report: ' + FReportFile;
end;

procedure TFDesigner.BDesignClick(Sender: TObject);
begin
  // The designer saves the report to Filename when the user saves it
  RpDesignerLCL1.Filename := FReportFile;
  RpDesignerLCL1.LoadFromFile(FReportFile);
  RpDesignerLCL1.Report.DataInfo.ItemByName('SALES').Dataset := FData;
  RpDesignerLCL1.Execute;
end;

procedure TFDesigner.BPreviewClick(Sender: TObject);
begin
  // The report as the user saved it, with the data of the application
  LCLReport1.LoadFromFile(FReportFile);
  LCLReport1.Report.DataInfo.ItemByName('SALES').Dataset := FData;
  LCLReport1.Preview := True;
  LCLReport1.Execute;
end;

end.

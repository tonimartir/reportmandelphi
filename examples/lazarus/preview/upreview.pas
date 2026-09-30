unit upreview;

{ Report Manager example: preview, print and PDF export of ../sales.rep from
  an LCL application.

  LCLReport1 is a TLCLReport, dropped on the form from the Reportman page of
  the component palette (package reportman_lcl). The form gives the report
  its data (salesdata.pas) and calls Execute. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, BufDataset,
  rplclreport;

type

  { TFPreview }

  TFPreview = class(TForm)
    LCLReport1: TLCLReport;
    LInfo: TLabel;
    BPreview: TButton;
    BPrint: TButton;
    BPDF: TButton;
    SaveDialog1: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure BPreviewClick(Sender: TObject);
    procedure BPrintClick(Sender: TObject);
    procedure BPDFClick(Sender: TObject);
  private
    FData: TBufDataset;
  end;

var
  FPreview: TFPreview;

implementation

uses
  salesdata;

{$R *.lfm}

{ TFPreview }

procedure TFPreview.FormCreate(Sender: TObject);
begin
  FData := CreateSalesData(Self);
  LCLReport1.Filename := SalesReportFile;
  // The report prints its dataset SALES: the application provides the data
  LCLReport1.Report.DataInfo.ItemByName('SALES').Dataset := FData;
  LInfo.Caption := 'Report: ' + LCLReport1.Filename;
end;

procedure TFPreview.BPreviewClick(Sender: TObject);
begin
  // The preview window can also print and export
  LCLReport1.Preview := True;
  LCLReport1.Execute;
end;

procedure TFPreview.BPrintClick(Sender: TObject);
begin
  // Straight to the printer, after the print dialog
  LCLReport1.Preview := False;
  LCLReport1.ShowPrintDialog := True;
  LCLReport1.Execute;
end;

procedure TFPreview.BPDFClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
  begin
    LCLReport1.SaveToPDF(SaveDialog1.FileName, True);
    ShowMessage('Written ' + SaveDialog1.FileName);
  end;
end;

end.

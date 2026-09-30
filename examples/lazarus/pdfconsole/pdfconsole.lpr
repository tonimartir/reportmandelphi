program pdfconsole;

{ Report Manager example: writes sales.pdf from the report ../sales.rep in a
  console program. It needs only the reportman_rtl package (the engine and
  the PDF export, no LCL), which is what a service, a web server or a command
  line tool uses. }

{$mode objfpc}{$H+}

uses
  SysUtils, BufDataset, rppdfreport, salesdata;

var
  Data: TBufDataset;
  Report: TPDFReport;
begin
  Data := CreateSalesData(nil);
  Report := TPDFReport.Create(nil);
  try
    Report.Filename := SalesReportFile;
    // The report prints its dataset SALES: this program provides the data
    Report.Report.DataInfo.ItemByName('SALES').Dataset := Data;
    Report.PDFFilename := ExpandFileName('sales.pdf');
    Report.ShowProgress := False;
    Report.Execute;
    WriteLn('Written ', Report.PDFFilename);
  finally
    Report.Free;
    Data.Free;
  end;
end.

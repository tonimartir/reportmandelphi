program PdfTest;

{ delphi}

uses
  Classes, SysUtils,
  rpreport, rppdfdriver, rppdfreport;

var
  repFile, pdfFile: string;
  report: TRpReport;
  success: Boolean;
  f: file of Byte;
  sz: Int64;
begin
  WriteLn('==================================================');
  WriteLn('Report Manager FPC PDF Test');
  WriteLn('==================================================');

  // Determine report file path
  if ParamCount >= 1 then
    repFile := ParamStr(1)
  else
  begin
    if FileExists('..\..\..\repman\repsamples\htmltest.rep') then
      repFile := '..\..\..\repman\repsamples\htmltest.rep'
    else if FileExists('C:\desarrollo\prog\toni\reportman\repman\repsamples\htmltest.rep') then
      repFile := 'C:\desarrollo\prog\toni\reportman\repman\repsamples\htmltest.rep'
    else if FileExists('htmltest.rep') then
      repFile := 'htmltest.rep'
    else
      repFile := 'htmltest.rep';
  end;

  if ParamCount >= 2 then
    pdfFile := ParamStr(2)
  else
    pdfFile := 'htmltest.pdf';

  WriteLn('Input report : ', repFile);
  WriteLn('Output PDF   : ', pdfFile);

  if not FileExists(repFile) then
  begin
    WriteLn('ERROR: Report file does not exist: ', repFile);
    Halt(1);
  end;

  try
    WriteLn('1. Instantiating TRpReport...');
    report := TRpReport.Create(nil);
    try
      WriteLn('2. Loading report from file...');
      report.LoadFromFile(repFile);
      WriteLn('   Report loaded. Title: ', report.DocTitle, ', Page size: ', report.PageWidth, 'x', report.PageHeight);

      WriteLn('3. Generating PDF with PrintReportPDF...');
      success := PrintReportPDF(report, '', False, True, 1, 99999, 1, pdfFile, True, False, False);

      if success then
      begin
        WriteLn('4. SUCCESS! PDF generated: ', pdfFile);
        if FileExists(pdfFile) then
        begin
          AssignFile(f, pdfFile);
          Reset(f);
          sz := FileSize(f);
          CloseFile(f);
          WriteLn('   PDF File Size: ', sz, ' bytes');
        end;
      end
      else
      begin
        WriteLn('4. FAILED: PrintReportPDF returned False.');
        Halt(2);
      end;
    finally
      report.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      Halt(3);
    end;
  end;

  WriteLn('==================================================');
  WriteLn('PDF Test finished successfully!');
  WriteLn('==================================================');
end.

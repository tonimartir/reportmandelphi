program PdfTest;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  rpreport, rppdfdriver, rppdfreport;

function FindReportFile(const AFileName: string): string;
begin
  if FileExists(AFileName) then
    Result := AFileName
  else if FileExists('..\..\..\repman\repsamples\' + AFileName) then
    Result := '..\..\..\repman\repsamples\' + AFileName
  else if FileExists('C:\desarrollo\prog\toni\reportman\repman\repsamples\' + AFileName) then
    Result := 'C:\desarrollo\prog\toni\reportman\repman\repsamples\' + AFileName
  else
    Result := AFileName;
end;

function TestOneReport(const ARepFileName, APdfFileName: string): Boolean;
var
  repFile: string;
  report: TRpReport;
  f: file of Byte;
  sz: Int64;
begin
  Result := False;
  repFile := FindReportFile(ARepFileName);

  WriteLn('--------------------------------------------------');
  WriteLn('Testing Report: ', ARepFileName);
  WriteLn('Input path    : ', repFile);
  WriteLn('Output PDF    : ', APdfFileName);
  WriteLn('--------------------------------------------------');

  if not FileExists(repFile) then
  begin
    WriteLn('ERROR: Report file does not exist: ', repFile);
    Exit;
  end;

  // Delete previous output if present
  if FileExists(APdfFileName) then
    DeleteFile(APdfFileName);

  try
    WriteLn('1. Instantiating TRpReport...');
    report := TRpReport.Create(nil);
    try
      WriteLn('2. Loading report from file...');
      report.LoadFromFile(repFile);
      WriteLn('   Report loaded. Title: ', report.DocTitle, ', Page size: ', report.PageWidth, 'x', report.PageHeight);

      WriteLn('3. Generating PDF with PrintReportPDF...');
      Result := PrintReportPDF(report, '', False, True, 1, 99999, 1, APdfFileName, True, False, False);

      if Result then
      begin
        WriteLn('4. SUCCESS! PDF generated: ', APdfFileName);
        if FileExists(APdfFileName) then
        begin
          AssignFile(f, APdfFileName);
          Reset(f);
          sz := FileSize(f);
          CloseFile(f);
          WriteLn('   PDF File Size: ', sz, ' bytes');
        end;
      end
      else
      begin
        WriteLn('4. FAILED: PrintReportPDF returned False.');
      end;
    finally
      report.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      Result := False;
    end;
  end;
  WriteLn;
end;

var
  allOk: Boolean;
begin
  WriteLn('==================================================');
  WriteLn('Report Manager FPC PDF Test Suite');
  WriteLn('==================================================');

  if ParamCount >= 1 then
  begin
    if ParamCount >= 2 then
      allOk := TestOneReport(ParamStr(1), ParamStr(2))
    else
      allOk := TestOneReport(ParamStr(1), ChangeFileExt(ExtractFileName(ParamStr(1)), '.pdf'));
  end
  else
  begin
    allOk := True;
    if not TestOneReport('htmltest.rep', 'htmltest.pdf') then
      allOk := False;

    if not TestOneReport('arab2wordwrap.rep', 'arab2wordwrap.pdf') then
      allOk := False;

    if not TestOneReport('bold.rep', 'bold.pdf') then
      allOk := False;
  end;

  WriteLn('==================================================');
  if allOk then
  begin
    WriteLn('ALL TESTS FINISHED SUCCESSFULLY!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('TEST SUITE FAILED!');
    ExitCode := 1;
  end;
  WriteLn('==================================================');
end.

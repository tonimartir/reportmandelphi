program pgreport;

{ Report Manager example: two reports that read the PostgreSQL sample
  database (createdb.sh), each one with a direct driver of the FPC engine,
  written as PDF by this console program:

    sales_sqldb.rep  connection RPSAMPLE_SQLDB, driver FireDAC: the FPC engine
                     opens it with SQLdb (TPQConnection, included in FPC)
    sales_zeos.rep   connection RPSAMPLE_ZEOS, driver Zeos (ZeosLib)

  The reports open their connections and run their SQL themselves: the
  program only says where the connections are, the file dbxconnections.ini
  of this folder or the file given as the first parameter. }

{$mode objfpc}{$H+}

uses
  // On Linux and other Unix systems, the threads and the conversion of
  // Unicode strings of the system (text with accents, other alphabets)
  {$IFDEF UNIX}
  cthreads, cwstring,
  {$ENDIF}
  SysUtils, rpdatainfo, rppdfreport;

// The folder of the reports, the folder of the project
function ExampleDir: string;
begin
  Result := ExtractFilePath(ExpandFileName(ParamStr(0)));
end;

procedure WritePDF(const AName: string);
var
  Report: TPDFReport;
begin
  Report := TPDFReport.Create(nil);
  try
    Report.Filename := ExampleDir + AName + '.rep';
    Report.PDFFilename := ExpandFileName(AName + '.pdf');
    Report.ShowProgress := False;
    Report.Execute;
    WriteLn('Written ', Report.PDFFilename);
  finally
    Report.Free;
  end;
end;

begin
  if ParamCount > 0 then
    DBXConnectionsFileOverride := ExpandFileName(ParamStr(1))
  else
    DBXConnectionsFileOverride := ExampleDir + 'dbxconnections.ini';
  try
    WritePDF('sales_sqldb');
    WritePDF('sales_zeos');
  except
    on E: Exception do
    begin
      WriteLn(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

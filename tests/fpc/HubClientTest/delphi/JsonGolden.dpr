{ Writes golden\json_delphi.txt: what Delphi's System.JSON (and the shared AI
  contract units) produce for the cases in ..\ujsoncases.pas. The FPC test
  HubClientTest compares the JSON shim (rtl_fpc\rpjsonfpc.pas) with it.
  Build and run with makegolden.bat. }
program JsonGolden;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes,
  ujsoncases in '..\ujsoncases.pas';

var
  LLines: TStringList;
  LFileName: string;
begin
  try
    LLines := TStringList.Create;
    try
      RunJsonCases(LLines);
      if ParamCount > 0 then
        LFileName := ParamStr(1)
      else
        LFileName := ExtractFilePath(ParamStr(0)) + '..\golden\json_delphi.txt';
      LLines.WriteBOM := False;
      LLines.LineBreak := #10;
      LLines.SaveToFile(LFileName, TEncoding.ASCII);
      Writeln(LLines.Count, ' cases written to ', LFileName);
    finally
      LLines.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

program aligntest;

// Diagnostic tool: loads a .rep and dumps the Alignment of every text component,
// to verify the XML loader applies ALIGNMENT.

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  rptypes,
  rpprintitem,
  rplabelitem,
  rpsection,
  rpsubreport,
  rpreport;

var
  rep: TRpReport;
  i, j, k: integer;
  sec: TRpSection;
  comp: TComponent;
begin
  try
    if ParamCount < 1 then
    begin
      WriteLn('Usage: aligntest <file.rep>');
      Halt(2);
    end;
    rep := TRpReport.Create(nil);
    try
      rep.LoadFromFile(ParamStr(1));
      for i := 0 to rep.SubReports.Count - 1 do
        for j := 0 to rep.SubReports.Items[i].SubReport.Sections.Count - 1 do
        begin
          sec := rep.SubReports.Items[i].SubReport.Sections.Items[j].Section;
          for k := 0 to sec.Components.Count - 1 do
          begin
            comp := sec.Components.Items[k].Component;
            if comp is TRpGenTextComponent then
              WriteLn(comp.ClassName, ' ', comp.Name,
                ' Alignment=', TRpGenTextComponent(comp).Alignment,
                ' WordWrap=', TRpGenTextComponent(comp).WordWrap,
                ' IsHtml=', TRpGenTextComponent(comp).IsHtml);
          end;
        end;
    finally
      rep.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.

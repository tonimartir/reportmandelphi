program metadump;

// Diagnostic tool: loads a Report Metafile and dumps version-related fields,
// to verify the 4.1 format round trip (PrinterFonts persistence).

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  rptypes,
  rpmetafile,
  rppdfdriver;

var
  meta: TRpMetafileReport;
begin
  try
    if ParamCount < 1 then
    begin
      WriteLn('Usage: metadump <file.rpmf> [out.pdf]');
      Halt(2);
    end;
    meta := TRpMetafileReport.Create(nil);
    try
      meta.LoadFromFile(ParamStr(1));
      WriteLn('PrinterFonts=', Integer(meta.PrinterFonts),
        ' Pages=', meta.CurrentPageCount,
        ' CustomX=', meta.CustomX, ' CustomY=', meta.CustomY);
      if ParamCount >= 2 then
      begin
        // Exercises TRpPDFDriver.NewDocument auto-activation from the metafile
        SaveMetafileToPDF(meta, ParamStr(2), false, false);
        WriteLn('PDF saved: ', ParamStr(2));
      end;
    finally
      meta.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.

program preview;

{ Report Manager example: preview, print and PDF export from an LCL
  application (packages reportman_rtl and reportman_lcl). }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms, upreview;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFPreview, FPreview);
  Application.Run;
end.

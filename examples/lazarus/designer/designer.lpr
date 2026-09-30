program designer;

{ Report Manager example: the report designer inside an LCL application
  (packages reportman_rtl, reportman_lcl and reportman_designlcl). }

{$mode objfpc}{$H+}

uses
  // On Linux and other Unix systems, the threads and the conversion of
  // Unicode strings of the system (text with accents, other alphabets)
  {$IFDEF UNIX}
  cthreads, cwstring,
  {$ENDIF}
  Interfaces, Forms, udesigner;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFDesigner, FDesigner);
  Application.Run;
end.

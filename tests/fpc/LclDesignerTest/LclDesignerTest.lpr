program LclDesignerTest;

{$mode delphi}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Interfaces,
  Forms,
  umainform;

{$R *.res}

var
  i: Integer;
  selfTestMode: Boolean;
begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  selfTestMode := False;
  for i := 1 to ParamCount do
    if (ParamStr(i) = '--selftest') or (ParamStr(i) = '--run-and-exit') then
      selfTestMode := True;

  Application.CreateForm(TMainForm, MainForm);

  if selfTestMode then
  begin
    MainForm.RunSelfTest(0);
    Exit;
  end;

  Application.Run;
end.

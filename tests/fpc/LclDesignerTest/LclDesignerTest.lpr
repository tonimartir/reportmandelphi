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
  LogMsg('LclDesignerTest: Application starting');
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  LogMsg('LclDesignerTest: Application.Initialize done');
  selfTestMode := False;
  for i := 1 to ParamCount do
    if (ParamStr(i) = '--selftest') or (ParamStr(i) = '--run-and-exit') then
      selfTestMode := True;

  LogMsg('LclDesignerTest: Creating MainForm');
  Application.CreateForm(TMainForm, MainForm);
  LogMsg('LclDesignerTest: MainForm created');

  if selfTestMode then
  begin
    LogMsg('LclDesignerTest: Executing RunSelfTest');
    MainForm.RunSelfTest(0);
    LogMsg('LclDesignerTest: RunSelfTest finished');
    Exit;
  end;

  Application.Run;
end.

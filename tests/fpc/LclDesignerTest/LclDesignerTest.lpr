program LclDesignerTest;

{$mode delphi}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Interfaces,
  Forms,
  rptypes, rphttpclientfpc, rpwebmarkdownlcl,
  umainform;

{$R *.res}

var
  i: Integer;
  selfTestMode: Boolean;
begin
  LogMsg('LclDesignerTest: Application starting');
  // The AI panel of the designer windows talks to the Hub when they open:
  // no real network in the tests (a closed local port), and the native
  // chat viewer instead of one WebView2 per window (LclAIChatTest covers
  // the AI panel against a fake Hub)
  RpHttpSetUrlRewrite(HUB_API_URL, 'http://127.0.0.1:9');
  RpWebMarkdownForceNative := True;
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

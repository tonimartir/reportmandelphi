library activex_ai;

uses
  System.Win.ComObj,System.Win.ComServ,
  activex_ai_TLB in 'activex_ai_TLB.pas',
  rpaxaiimp in 'rpaxaiimp.pas' {ReportmanAIActiveX: CoClass},
  rpaiactivexcontrol in 'rpaiactivexcontrol.pas';

{$E ocx}

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

{$R *.TLB}
{$R *.RES}
{$R activex_ai_loader.res}

begin
end.
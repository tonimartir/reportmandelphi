// JCL_DEBUG_EXPERT_INSERTJDBG OFF
program repwebexe;

{$APPTYPE CONSOLE}

{$I rpconf.inc}

uses
  SysUtils,
  WebBroker,
  CGIApp,
{$IFDEF MSWINDOWS}
{$IFNDEF MIDASOUT}
  midaslib,
{$ENDIF}
{$ENDIF}
  rpwebmodule in 'rpwebmodule.pas' {repwebmod: TWebModule},
  rpwebpages in 'rpwebpages.pas',
  rpwebselfhosted in 'rpwebselfhosted.pas';

{$R *.res}

begin
  Application.Initialize;
  if FindCmdLineSwitch('selfhosted', True) then
  begin
    RunSelfHosted;
    Exit;
  end;
  Application.CreateForm(Trepwebmod, repwebmod);
  Application.Run;
end.


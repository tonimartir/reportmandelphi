// JCL_DEBUG_EXPERT_INSERTJDBG OFF
library ReportMan;

{$I rpconf.inc}



uses
  ComServ,
  DBPwdlg,
  MidasLib,
  reportman_TLB in 'reportman_TLB.pas',
  rpaxreportimp in 'rpaxreportimp.pas' {ReportManX: CoClass},
  aboutrpax in 'aboutrpax.pas' {ReportManXAbout},
  rpdllutil in '..\rpdllutil.pas',
  rpactivexreport in '..\rpactivexreport.pas',
  rpaxreportreport in 'rpaxreportreport.pas' {ReportReport: CoClass},
  rpaxreportparameters in 'rpaxreportparameters.pas' {ReportParameters: CoClass},
  rpaxreportparam in 'rpaxreportparam.pas' {ReportParam: CoClass},
  rpaspserver in 'rpaspserver.pas' {ReportmanXAServer: CoClass},
  rpvpreview in '..\rpvpreview.pas' {FRpVPreview},
  rppreviewformax in 'rppreviewformax.pas' {PreviewControl: TActiveForm} {PreviewControl: CoClass};

{$E ocx}

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer,
  rp_new,
  rp_open,
  rp_close,
  rp_execute,
  rp_lasterror,
  rp_executeremote,
  rp_executeremote_report,
  rp_setparamvalue,
  rp_setparamvaluevar,
  rp_getparamname,
  rp_getparamcount,
  rp_getremoteparams,
  rp_setadoconnectionstring,
  rp_getdefaultprinter,
  rp_getprinters,
  rp_setdefaultprinter,
  rp_executew,
  rp_lasterrorw,
  rp_setparamvaluew,
  rp_setparamvaluevarw,
  rp_getparamnamew,
  rp_getremoteparamsw,
  rp_setadoconnectionstringw,
  rp_getdefaultprinterw,
  rp_getprintersw,
  rp_setdefaultprinterw;

{$R *.TLB}

{$R *.RES}

begin
end.

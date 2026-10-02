{*******************************************************}
{                                                       }
{       Rpmreg                                          }
{                                                       }
{       Units that registers the reportmanager engine   }
{       into the Delphi component palette               }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmreg;

interface

{$I rpconf.inc}

uses
  Classes,rpcompobase,
  rpparser,rpeval,rpreport,rppdfreport,rptranslator,
  rpevalfunc,rptypes,rpdatainfo,rpalias,rptypeval,
{$IFNDEF DISABLERPCLIENT}
{$IFNDEF FPC}
  rpclientdataset,
{$ENDIF}
{$ENDIF}
{$IFNDEF FPC}
{$IFNDEF USEVARIANTS}
  rpvclreport,rpmaskedit,rppreviewcontrol,rpdbdatetimepicker,
  {$IFNDEF BUILDER4}
   rprulervcl,rpmdesignervcl,rpdbgridvcl,
{$IFDEF USEINDY}
   rptwaincomp,
{$ENDIF}
  {$ENDIF}
   DsgnIntf,
{$ENDIF}
{$ENDIF}
  rplastsav;

procedure Register;

implementation

{$IFDEF FPC}
// The icons of the Lazarus component palette in 24, 36 and 48 pixels
// (packages/icons/make_icons.sh); the Delphi ones are the .dcr of each unit
{$R rtl_fpc/rpmregicons.res}
{$ENDIF}

procedure Register;
begin
  RegisterComponents('Reportman', [TRpEvaluator]);
  RegisterComponents('Reportman', [TRpAlias]);
  RegisterComponents('Reportman', [TRpLastUsedStrings]);
  RegisterComponents('Reportman', [TRpTranslator]);
  RegisterComponents('Reportman', [TPDFReport]);
{$IFNDEF DISABLERPCLIENT}
{$IFNDEF FPC}
  RegisterComponents('Reportman', [TRpClientDataset]);
{$ENDIF}
{$ENDIF}
{$IFNDEF FPC}
{$IFNDEF USEVARIANTS}
  RegisterComponents('Reportman', [TVCLReport]);
  RegisterComponents('Reportman', [TRpDateTimePicker]);
  RegisterComponents('Reportman', [TRpPreviewControl]);
  RegisterComponents('Reportman', [TRpMaskEdit]);
  {$IFNDEF BUILDER4}
   RegisterComponents('Reportman', [TRpRulerVCL]);
   RegisterComponents('Reportman', [TRpDesignerVCL]);
   RegisterComponents('Reportman', [TRpGrid]);
  {$IFDEF USEINDY}
   RegisterComponents('Reportman', [TRpTwainWeb]);
  {$ENDIF}
  {$ENDIF}
{$ENDIF}
{$ENDIF}


end;

end.

{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmregdesignlcl                                 }
{       Units that registers Report Manager Designer    }
{       into the Lazarus / LCL component palette        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmregdesignlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils,
  rpmdesignerlcl, rprulerlcl,
  { Non-visual components from reportman_rtl }
  rppdfreport, rpeval, rpalias, rplastsav, rptranslator;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Reportman', [TRpDesignerLCL]);
  RegisterComponents('Reportman', [TRpRulerLCL]);
  { Non-visual components }
  RegisterComponents('Reportman', [TPDFReport]);
  RegisterComponents('Reportman', [TRpEvaluator]);
  RegisterComponents('Reportman', [TRpAlias]);
  RegisterComponents('Reportman', [TRpLastUsedStrings]);
  RegisterComponents('Reportman', [TRpTranslator]);
end;

end.

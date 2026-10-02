{*******************************************************}
{                                                       }
{       Rpregvcl                                        }
{                                                       }
{       Units that registers the reportmanager engine   }
{       vcl version Delphi 6 component palette          }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}


unit rpreglcl;

interface

{$I rpconf.inc}

uses
  Classes,Graphics,LResources,rpmaskedit,
  rppreviewcontrol,rplclreport;


procedure Register;

implementation


procedure Register;
begin
  RegisterComponents('Reportman', [TLCLReport]);
//  RegisterComponents('Reportman', [TRpExpreDialogVCL]);
  RegisterComponents('Reportman', [TRpMaskEdit]);
//  RegisterComponents('Reportman', [TRpGrid]);
  RegisterComponents('Reportman', [TRpPreviewControl]);
//  RegisterComponents('Reportman', [TRpDateTimePicker]);
  // TRpActiveXReport is a Wrapper to generate the ActiveX version
  // with Delphi 6 Active X Control Wizard
end;

initialization
  // The palette icons in 24, 36 and 48 pixels (packages/icons/make_icons.sh)
  {$I rpreglcl.lrs}

end.

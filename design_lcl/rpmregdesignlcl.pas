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
  Classes, SysUtils, LResources,
  rpmdesignerlcl, rprulerlcl;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Reportman', [TRpDesignerLCL]);
  RegisterComponents('Reportman', [TRpRulerLCL]);
end;

initialization
  // The palette icons in 24, 36 and 48 pixels (packages/icons/make_icons.sh)
  {$I rpmregdesignlcl.lrs}

end.

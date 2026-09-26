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
  {$I rpmregdesignlcl.lrs}

end.

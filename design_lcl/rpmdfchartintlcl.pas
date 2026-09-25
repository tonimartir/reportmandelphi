{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfchartintlcl                                }
{       Chart designer interface for LCL                }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfchartintlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Types,
  Graphics, Forms, Controls,
  rpprintitem, rpmdchart, rpmdobinsintlcl, rpmdconsts,
  rpgraphutilslcl, rptypes;

type
  TRpChartInterface = class(TRpSizePosInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
  end;

implementation

constructor TRpChartInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if not (pritem is TRpChart) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

class procedure TRpChartInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpChartInterface');
end;

procedure TRpChartInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  achart: TRpChart;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  achart := TRpChart(printitem);
  lnames.Add(SrpSExpression);
  ltypes.Add(SRpSExpression);
  lhints.Add('refchart.html');
  lcat.Add(SRpChartData);
  if Assigned(lvalues) then lvalues.Add(achart.ValueExpression);
end;

procedure TRpChartInterface.SetProperty(pname: string; value: WideString);
var
  achart: TRpChart;
begin
  achart := TRpChart(printitem);
  if pname = SrpSExpression then
  begin
    achart.ValueExpression := value;
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpChartInterface.GetProperty(pname: string): WideString;
var
  achart: TRpChart;
begin
  achart := TRpChart(printitem);
  if pname = SrpSExpression then Result := achart.ValueExpression
  else Result := inherited GetProperty(pname);
end;

procedure TRpChartInterface.Paint;
var
  achart: TRpChart;
  sText: string;
begin
  achart := TRpChart(printitem);
  if not Assigned(achart) or (csDestroying in achart.ComponentState) then
    Exit;

  Canvas.Pen.Color := clTeal;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);

  Canvas.Font.Size := 8;
  Canvas.Font.Color := clTeal;
  sText := '[Chart] ' + achart.ValueExpression;
  Canvas.TextOut(4, 4, sText);

  DrawSelected;
end;

end.

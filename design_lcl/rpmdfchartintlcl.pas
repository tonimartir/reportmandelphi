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
  Graphics, Forms, Controls, LCLIntf, LCLType,
  rpprintitem, rpmdchart, rpmdcharttypes, rpmdobinsintlcl, rpmdconsts,
  rpgraphutilslcl, rptypes;

type
  TRpChartInterface = class(TRpGenTextInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: WideString; value: WideString); override;
    function GetProperty(pname: WideString): WideString; override;
    procedure GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings); override;
  end;

implementation

constructor TRpChartInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if Assigned(pritem) and not (pritem is TRpChart) then
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

  procedure AddProp(const AName, AType, ACat: WideString);
  begin
    lnames.Add(AName);
    ltypes.Add(AType);
    lhints.Add('refchart.html');
    lcat.Add(ACat);
    if Assigned(lvalues) and Assigned(achart) then
      lvalues.Add(GetProperty(AName));
  end;

begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  achart := TRpChart(printitem);
  // Same order, types and categories as the VCL designer
  AddProp(SrpSExpression, SRpSExpression, SRpChartData);
  AddProp(SrpSIdentifier, SRpSString, SRpChartData);
  AddProp(SrpSChartType, SRpSList, SRpChartAspect);
  AddProp(SrpSGetValueCondition, SRpSExpression, SRpChartData);
  AddProp(SrpSChangeSerieExp, SRpSExpression, SRpChartData);
  AddProp(SrpSChangeSerieBool, SRpSBool, SRpChartData);
  AddProp(SrpSClearExpChart, SRpSExpression, SRpChartData);
  AddProp(SrpSBoolClearExp, SRpSBool, SRpChartData);
  AddProp(SrpSCaptionExp, SRpSExpression, SRpChartData);
  AddProp(SrpSExpression + ' X', SRpSExpression, SRpChartData);
  AddProp(SrpSSerieCaptionExp, SRpSExpression, SRpChartData);
  AddProp(SrpSDriver, SRpSList, SRpChartAspect);
  AddProp(SRpSView3D, SRpSBool, SRpChartAspect);
  AddProp(SRpSView3DWalls, SRpSBool, SRpChartAspect);
  AddProp(SRpSPerspective, SRpSInteger, SRpChartAspect);
  AddProp(SRpSElevation, SRpSInteger, SRpChartAspect);
  AddProp(SRpSRotation, SRpSInteger, SRpChartAspect);
  AddProp(SRpSOrthogonal, SRpSBool, SRpChartAspect);
  AddProp(SRpSZoom, SRpSInteger, SRpChartAspect);
  AddProp(SRpSHOffset, SRpSInteger, SRpChartAspect);
  AddProp(SRpSVOffset, SRpSInteger, SRpChartAspect);
  AddProp(SRpSTilt, SRpSInteger, SRpChartAspect);
  AddProp(SRpDPIRes, SRpSInteger, SRpChartAspect);
  AddProp(SRpSMultibar, SRpSList, SRpChartAspect);
  AddProp(SrpChartHint, SRpSBool, SRpChartAspect);
  AddProp(SrpChartLegend, SRpSBool, SRpChartAspect);
  AddProp(SRpMarkType, SRpSList, SRpChartAspect);
  AddProp(SRpSVertAxisFSize, SRpSInteger, SRpChartAspect);
  AddProp(SRpSHorzAxisFSize, SRpSInteger, SRpChartAspect);
  AddProp(SRpSVertAxisFRot, SRpSInteger, SRpChartAspect);
  AddProp(SRpSHorzAxisFRot, SRpSInteger, SRpChartAspect);
  AddProp(SrpSValueColor, SRpSExpression, SRpChartData);
  AddProp(SrpSSerieColor, SRpSExpression, SRpChartData);
  AddProp(SRpAutoRange, SRpSList, SRpChartAspect);
  AddProp(SRpAutoRangeYMin, SRpSCurrency, SRpChartAspect);
  AddProp(SRpAutoRangeYMax, SRpSCurrency, SRpChartAspect);
end;

procedure TRpChartInterface.SetProperty(pname: WideString; value: WideString);
var
  achart: TRpChart;
  cvalue: Currency;
begin
  achart := TRpChart(printitem);
  if not Assigned(achart) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;
  // Numbers and booleans being typed keep the current value until valid
  if pname = SrpSExpression then
  begin
    achart.ValueExpression := value;
    Invalidate;
    Exit;
  end;
  if pname = SrpSExpression + ' X' then
  begin
    achart.ValueXExpression := value;
    Exit;
  end;
  if pname = SrpSIdentifier then
  begin
    achart.Identifier := value;
    Exit;
  end;
  if pname = SrpSChartType then
  begin
    achart.ChartType := StringToRpChartType(value);
    Invalidate;
    Exit;
  end;
  if pname = SrpSGetValueCondition then
  begin
    achart.GetValueCondition := value;
    Exit;
  end;
  if pname = SrpSChangeSerieExp then
  begin
    achart.ChangeSerieExpression := value;
    Exit;
  end;
  if pname = SrpSChangeSerieBool then
  begin
    achart.ChangeSerieBool := StrToBoolDef(value, achart.ChangeSerieBool);
    Exit;
  end;
  if pname = SrpSClearExpChart then
  begin
    achart.ClearExpression := value;
    Exit;
  end;
  if pname = SrpSBoolClearExp then
  begin
    achart.ClearExpressionBool := StrToBoolDef(value, achart.ClearExpressionBool);
    Exit;
  end;
  if pname = SrpSCaptionExp then
  begin
    achart.CaptionExpression := value;
    Exit;
  end;
  if pname = SrpSSerieCaptionExp then
  begin
    achart.SerieCaption := value;
    Exit;
  end;
  if pname = SrpSDriver then
  begin
    achart.Driver := StringToRpChartDriver(value);
    Exit;
  end;
  if pname = SrpSView3D then
  begin
    achart.View3d := StrToBoolDef(value, achart.View3d);
    Exit;
  end;
  if pname = SrpSView3DWalls then
  begin
    achart.View3dWalls := StrToBoolDef(value, achart.View3dWalls);
    Exit;
  end;
  if pname = SrpSPerspective then
  begin
    achart.Perspective := StrToIntDef(value, achart.Perspective);
    Exit;
  end;
  if pname = SrpSElevation then
  begin
    achart.Elevation := StrToIntDef(value, achart.Elevation);
    Exit;
  end;
  if pname = SrpSRotation then
  begin
    achart.Rotation := StrToIntDef(value, achart.Rotation);
    Exit;
  end;
  if pname = SrpSOrthogonal then
  begin
    achart.Orthogonal := StrToBoolDef(value, achart.Orthogonal);
    Exit;
  end;
  if pname = SrpSZoom then
  begin
    achart.Zoom := StrToIntDef(value, achart.Zoom);
    Exit;
  end;
  if pname = SrpSHOffset then
  begin
    achart.HorzOffset := StrToIntDef(value, achart.HorzOffset);
    Exit;
  end;
  if pname = SrpSVOffset then
  begin
    achart.VertOffset := StrToIntDef(value, achart.VertOffset);
    Exit;
  end;
  if pname = SrpSTilt then
  begin
    achart.Tilt := StrToIntDef(value, achart.Tilt);
    Exit;
  end;
  if pname = SRpDPIRes then
  begin
    achart.Resolution := StrToIntDef(value, achart.Resolution);
    Exit;
  end;
  if pname = SrpSMultibar then
  begin
    achart.Multibar := StringToRpMultibar(value);
    Exit;
  end;
  if pname = SrpChartHint then
  begin
    achart.ShowHint := StrToBoolDef(value, achart.ShowHint);
    Exit;
  end;
  if pname = SrpChartLegend then
  begin
    achart.ShowLegend := StrToBoolDef(value, achart.ShowLegend);
    Exit;
  end;
  if pname = SRpMarkType then
  begin
    achart.MarkStyle := StringToRpMarkType(value);
    Exit;
  end;
  if pname = SRpSVertAxisFSize then
  begin
    achart.VertFontSize := StrToIntDef(value, achart.VertFontSize);
    Exit;
  end;
  if pname = SRpSHorzAxisFSize then
  begin
    achart.HorzFontSize := StrToIntDef(value, achart.HorzFontSize);
    Exit;
  end;
  if pname = SRpSVertAxisFRot then
  begin
    achart.VertFontRotation := StrToIntDef(value, achart.VertFontRotation);
    Exit;
  end;
  if pname = SRpSHorzAxisFRot then
  begin
    achart.HorzFontRotation := StrToIntDef(value, achart.HorzFontRotation);
    Exit;
  end;
  if pname = SRpSValueColor then
  begin
    achart.ColorExpression := value;
    Exit;
  end;
  if pname = SRpSSerieColor then
  begin
    achart.SerieColorExpression := value;
    Exit;
  end;
  if pname = SRpAutoRange then
  begin
    achart.AutoRange := StringToRpAutoRange(value);
    Exit;
  end;
  if pname = SRpAutoRangeYMin then
  begin
    if TryStrToCurr(value, cvalue) then
      achart.YMin := cvalue;
    Exit;
  end;
  if pname = SRpAutoRangeYMax then
  begin
    if TryStrToCurr(value, cvalue) then
      achart.YMax := cvalue;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpChartInterface.GetProperty(pname: WideString): WideString;
var
  achart: TRpChart;
begin
  achart := TRpChart(printitem);
  if not Assigned(achart) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;
  if pname = SrpSExpression then Result := achart.ValueExpression
  else if pname = SrpSExpression + ' X' then Result := achart.ValueXExpression
  else if pname = SrpSIdentifier then Result := achart.Identifier
  else if pname = SrpSChartType then Result := RpChartTypeToString(achart.ChartType)
  else if pname = SrpSGetValueCondition then Result := achart.GetValueCondition
  else if pname = SrpSChangeSerieExp then Result := achart.ChangeSerieExpression
  else if pname = SrpSChangeSerieBool then Result := BoolToStr(achart.ChangeSerieBool, True)
  else if pname = SrpSClearExpChart then Result := achart.ClearExpression
  else if pname = SrpSBoolClearExp then Result := BoolToStr(achart.ClearExpressionBool, True)
  else if pname = SrpSCaptionExp then Result := achart.CaptionExpression
  else if pname = SrpSSerieCaptionExp then Result := achart.SerieCaption
  else if pname = SrpSDriver then Result := RpChartDriverToString(achart.Driver)
  else if pname = SrpSView3D then Result := BoolToStr(achart.View3D, True)
  else if pname = SrpSView3DWalls then Result := BoolToStr(achart.View3DWalls, True)
  else if pname = SrpSPerspective then Result := IntToStr(achart.Perspective)
  else if pname = SrpSElevation then Result := IntToStr(achart.Elevation)
  else if pname = SrpSRotation then Result := IntToStr(achart.Rotation)
  else if pname = SrpSOrthogonal then Result := BoolToStr(achart.Orthogonal, True)
  else if pname = SrpSZoom then Result := IntToStr(achart.Zoom)
  else if pname = SrpSHOffset then Result := IntToStr(achart.HorzOffset)
  else if pname = SrpSVOffset then Result := IntToStr(achart.VertOffset)
  else if pname = SrpSTilt then Result := IntToStr(achart.Tilt)
  else if pname = SRpDPIRes then Result := IntToStr(achart.Resolution)
  else if pname = SrpSMultibar then Result := RpMultiBarToString(achart.Multibar)
  else if pname = SrpChartHint then Result := BoolToStr(achart.ShowHint, True)
  else if pname = SrpChartLegend then Result := BoolToStr(achart.ShowLegend, True)
  else if pname = SRpMarkType then Result := RpMarkTypeToString(achart.MarkStyle)
  else if pname = SRpSVertAxisFSize then Result := IntToStr(achart.VertFontSize)
  else if pname = SRpSHorzAxisFSize then Result := IntToStr(achart.HorzFontSize)
  else if pname = SRpSVertAxisFRot then Result := IntToStr(achart.VertFontRotation)
  else if pname = SRpSHorzAxisFRot then Result := IntToStr(achart.HorzFontRotation)
  else if pname = SRpSValueColor then Result := achart.ColorExpression
  else if pname = SRpSSerieColor then Result := achart.SerieColorExpression
  else if pname = SRpAutoRange then Result := RpAutoRangeAxisToString(achart.AutoRange)
  else if pname = SRpAutoRangeYMin then Result := FormatCurr('#####0.00', achart.YMin)
  else if pname = SRpAutoRangeYMax then Result := FormatCurr('#####0.00', achart.YMax)
  else Result := inherited GetProperty(pname);
end;

procedure TRpChartInterface.GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings);
begin
  if pname = SRpSChartType then
  begin
    lpossiblevalues.Clear;
    GetRpChartTypePossibleValues(lpossiblevalues);
    Exit;
  end;
  if pname = SRpSDriver then
  begin
    lpossiblevalues.Clear;
    GetRpChartDriverPossibleValues(lpossiblevalues);
    Exit;
  end;
  if pname = SRpSMultibar then
  begin
    lpossiblevalues.Clear;
    GetRpMultiBarPossibleValues(lpossiblevalues);
    Exit;
  end;
  if pname = SRpMarkType then
  begin
    lpossiblevalues.Clear;
    GetRpMarTypePossibleValues(lpossiblevalues);
    Exit;
  end;
  if pname = SRpAutoRange then
  begin
    lpossiblevalues.Clear;
    GetRpAutoRangePossibleValues(lpossiblevalues);
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

procedure TRpChartInterface.Paint;
var
  achart: TRpChart;
  rec: TRect;
  aalign: Cardinal;
  eAlignment: Integer;
  atext: string;
begin
  achart := TRpChart(printitem);
  if not Assigned(achart) or (csDestroying in achart.ComponentState) then
    Exit;

  // Draws the value expression with the chart font (as the VCL designer)
  Canvas.Font.Name := achart.WFontName;
  Canvas.Font.Color := achart.FontColor;
  Canvas.Font.Size := achart.FontSize;
  Canvas.Font.Style := CLXIntegerToFontStyle(achart.FontStyle);

  rec.Top := 0;
  rec.Left := 0;
  rec.Right := Width - 1;
  rec.Bottom := Height - 1;
  if achart.Transparent then
    Canvas.Brush.Style := bsClear
  else
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := achart.BackColor;
    Canvas.FillRect(rec);
  end;
  aalign := DT_NOPREFIX;
  eAlignment := achart.PrintAlignment;
  if (eAlignment and AlignmentFlags_AlignHCenter) > 0 then
    aalign := aalign or DT_CENTER;
  if (eAlignment and AlignmentFlags_SingleLine) > 0 then
    aalign := aalign or DT_SINGLELINE;
  if (eAlignment and AlignmentFlags_AlignLeft) > 0 then
    aalign := aalign or DT_LEFT;
  if (eAlignment and AlignmentFlags_AlignRight) > 0 then
    aalign := aalign or DT_RIGHT;
  if achart.WordWrap then
    aalign := aalign or DT_WORDBREAK;
  if not achart.CutText then
    aalign := aalign or DT_NOCLIP;
  atext := achart.ValueExpression;
  DrawText(Canvas.Handle, PChar(atext), Length(atext), rec, aalign);

  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psDashDot;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  DrawSelected;
end;

end.

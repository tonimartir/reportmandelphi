{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdflabelintlcl                                }
{       Label and Expression designer items for LCL     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdflabelintlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Types,
  Graphics, Forms, Controls, LCLIntf, LCLType,
  rpmdobinsintlcl, rpprintitem, rplabelitem, rphtmlparser,
  rpmdconsts, rpgraphutilslcl, rptypes, rpparams;

type
  TRpLabelInterface = class(TRpGenTextInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: WideString; value: WideString); override;
    function GetProperty(pname: WideString): WideString; override;
  end;

  TRpExpressionInterface = class(TRpGenTextInterface)
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

// Display names of the aggregate and aggregate type of an expression
function AggregateToString(Value: TRpAggregate): WideString;
function StringToAggregate(const Value: WideString): TRpAggregate;
function AgeTypeToString(Value: TRpAggregateType): WideString;
function StringToAgeType(const Value: WideString): TRpAggregateType;

implementation

function AggregateToString(Value: TRpAggregate): WideString;
begin
  case Value of
    rpAgGroup: Result := SRpGroup;
    rpAgPage: Result := SRpPage;
    rpAgGeneral: Result := SRpGeneral;
  else
    Result := SRpNone;
  end;
end;

function StringToAggregate(const Value: WideString): TRpAggregate;
var
  i: TRpAggregate;
begin
  Result := rpAgNone;
  for i := rpAgNone to rpAgGeneral do
  begin
    if AggregateToString(i) = Value then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function AgeTypeToString(Value: TRpAggregateType): WideString;
begin
  case Value of
    rpagMin: Result := SrpMin;
    rpagMax: Result := SrpMax;
    rpagAvg: Result := SrpAvg;
    rpagStdDev: Result := SrpStdDev;
  else
    Result := SrpSum;
  end;
end;

function StringToAgeType(const Value: WideString): TRpAggregateType;
var
  i: TRpAggregateType;
begin
  Result := rpagSum;
  for i := rpagSum to rpagStdDev do
  begin
    if AgeTypeToString(i) = Value then
    begin
      Result := i;
      Break;
    end;
  end;
end;

// Draws atext in the client rectangle of a text item as the VCL designer
procedure DrawItemText(ACanvas: TCanvas; titem: TRpGenTextComponent;
  const atext: string; AWidth, AHeight: Integer);
var
  rec, arec: TRect;
  aalign: Cardinal;
  lalignment: Integer;
  alvcenter, alvbottom, calcrect: Boolean;
  Segments: THtmlSegmentList;
  Seg: THtmlSegment;
  X, Y: Integer;
begin
  rec.Left := 0;
  rec.Top := 0;
  rec.Right := AWidth;
  rec.Bottom := AHeight;

  if not titem.Transparent then
  begin
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := titem.BackColor;
    ACanvas.FillRect(rec);
  end
  else
    ACanvas.Brush.Style := bsClear;

  lalignment := titem.PrintAlignment;
  aalign := DT_NOPREFIX;
  if (lalignment and AlignmentFlags_AlignHCenter) > 0 then
    aalign := aalign or DT_CENTER;
  if (lalignment and AlignmentFlags_SingleLine) > 0 then
    aalign := aalign or DT_SINGLELINE;
  if (lalignment and AlignmentFlags_AlignLeft) > 0 then
    aalign := aalign or DT_LEFT;
  if (lalignment and AlignmentFlags_AlignRight) > 0 then
    aalign := aalign or DT_RIGHT;
  if titem.WordWrap then
    aalign := aalign or DT_WORDBREAK;
  if not titem.CutText then
    aalign := aalign or DT_NOCLIP;
  if titem.RightToLeft then
    aalign := aalign or DT_RTLREADING;

  if titem.IsHtml then
  begin
    Segments := ParseHtml(atext);
    try
      X := rec.Left;
      Y := rec.Top;
      if (lalignment and AlignmentFlags_SingleLine) > 0 then
      begin
        if (titem.VAlignment and AlignmentFlags_AlignVCenter) > 0 then
          Y := Y + (rec.Bottom - rec.Top - ACanvas.TextHeight('Wg')) div 2;
      end;

      for Seg in Segments do
      begin
        ACanvas.Font.Style := CLXIntegerToFontStyle(titem.FontStyle);
        if hsBold in Seg.Styles then ACanvas.Font.Style := ACanvas.Font.Style + [fsBold];
        if hsItalic in Seg.Styles then ACanvas.Font.Style := ACanvas.Font.Style + [fsItalic];
        if hsUnderline in Seg.Styles then ACanvas.Font.Style := ACanvas.Font.Style + [fsUnderline];
        if hsStrikeOut in Seg.Styles then ACanvas.Font.Style := ACanvas.Font.Style + [fsStrikeOut];

        if (Seg.Text = #13#10) or (Seg.Text = #10) then
        begin
          Y := Y + ACanvas.TextHeight('Wg');
          X := rec.Left;
        end
        else
        begin
          ACanvas.TextOut(X, Y, Seg.Text);
          X := X + ACanvas.TextWidth(Seg.Text);
        end;
      end;
    finally
      Segments.Free;
    end;
  end
  else
  begin
    alvbottom := (titem.VAlignment and AlignmentFlags_AlignBottom) > 0;
    alvcenter := (titem.VAlignment and AlignmentFlags_AlignVCenter) > 0;
    calcrect := (not titem.Transparent) or alvbottom or alvcenter;
    arec := rec;
    if calcrect then
      DrawText(ACanvas.Handle, PChar(atext), Length(atext), arec, aalign or DT_CALCRECT);
    if alvbottom then
      rec.Top := rec.Top + (rec.Bottom - arec.Bottom);
    if alvcenter then
      rec.Top := rec.Top + ((rec.Bottom - arec.Bottom) div 2);

    DrawText(ACanvas.Handle, PChar(atext), Length(atext), rec, aalign);
  end;
end;

{ TRpLabelInterface }

constructor TRpLabelInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if Assigned(pritem) and not (pritem is TRpLabel) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

class procedure TRpLabelInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpLabelInterface');
end;

procedure TRpLabelInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  alabel: TRpLabel;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  alabel := TRpLabel(printitem);
  // Text
  lnames.Add(SrpSText);
  ltypes.Add(SRpSString);
  lhints.Add('reflabel.html');
  lcat.Add(SRpLabel);
  if Assigned(lvalues) and Assigned(alabel) then lvalues.Add(alabel.Text);
  // Html
  lnames.Add(SRpIsHtml);
  ltypes.Add(SRpSBool);
  lhints.Add('reflabel.html');
  lcat.Add(SRpLabel);
  if Assigned(lvalues) and Assigned(alabel) then lvalues.Add(BoolToStr(alabel.IsHtml, True));
end;

procedure TRpLabelInterface.SetProperty(pname: WideString; value: WideString);
var
  alabel: TRpLabel;
begin
  alabel := TRpLabel(printitem);
  if not Assigned(alabel) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;
  if pname = SrpSText then
  begin
    alabel.Text := value;
    Invalidate;
    Exit;
  end;
  if pname = SRpIsHtml then
  begin
    alabel.IsHtml := StrToBoolDef(value, alabel.IsHtml);
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpLabelInterface.GetProperty(pname: WideString): WideString;
var
  alabel: TRpLabel;
begin
  alabel := TRpLabel(printitem);
  if not Assigned(alabel) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;
  if pname = SrpSText then Result := alabel.Text
  else if pname = SRpIsHtml then Result := BoolToStr(alabel.IsHtml, True)
  else Result := inherited GetProperty(pname);
end;

procedure TRpLabelInterface.Paint;
var
  alabel: TRpLabel;
begin
  alabel := TRpLabel(printitem);
  if not Assigned(alabel) or (csDestroying in alabel.ComponentState) then
    Exit;

  Canvas.Font.Name := alabel.WFontName;
  Canvas.Font.Color := alabel.FontColor;
  Canvas.Font.Size := Round(alabel.FontSize * Scale);
  Canvas.Font.Style := CLXIntegerToFontStyle(alabel.FontStyle);
  DrawItemText(Canvas, alabel, alabel.Text, Width, Height);

  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  DrawSelected;
end;

{ TRpExpressionInterface }

constructor TRpExpressionInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if Assigned(pritem) and not (pritem is TRpExpression) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

class procedure TRpExpressionInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpExpressionInterface');
end;

procedure TRpExpressionInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  aexp: TRpExpression;

  procedure AddProp(const AName, AType: WideString; const AValue: WideString);
  begin
    lnames.Add(AName);
    ltypes.Add(AType);
    lhints.Add('refexpression.html');
    lcat.Add(SRpExpression);
    if Assigned(lvalues) and Assigned(aexp) then
      lvalues.Add(AValue);
  end;

begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  aexp := TRpExpression(printitem);
  if not Assigned(aexp) then
  begin
    // Property descriptions only (no values)
    AddProp(SrpSExpression, SRpSExpression, '');
    AddProp(SRpIsHtml, SRpSBool, '');
    AddProp(SRpSDataType, SRpSList, '');
    AddProp(SrpSDisplayFormat, SRpSString, '');
    AddProp(SRpMultiPage, SRpSBool, '');
    AddProp(SRpPrintNulls, SRpSBool, '');
    AddProp(SrpSIdentifier, SRpSString, '');
    AddProp(SrpSAggregate, SRpSList, '');
    AddProp(SrpSAgeGroup, SRpGroup, '');
    AddProp(SrpSAgeType, SRpSList, '');
    AddProp(SrpSIniValue, SRpSExpression, '');
    AddProp(SRpSOnlyOne, SRpSBool, '');
    AddProp(SRpSExportExpression, SRpSExpression, '');
    AddProp(SRpSExportFormat, SRpSString, '');
    AddProp(SRpSExportLine, SRpSInteger, '');
    AddProp(SRpSExportPos, SRpSInteger, '');
    AddProp(SRpSExportSize, SRpSInteger, '');
    AddProp(SRpSExportDoNewLine, SRpSBool, '');
    Exit;
  end;
  // Expression
  AddProp(SrpSExpression, SRpSExpression, aexp.Expression);
  AddProp(SRpIsHtml, SRpSBool, BoolToStr(aexp.IsHtml, True));
  // Data Type
  AddProp(SRpSDataType, SRpSList, ParamTypeToString(aexp.DataType));
  // Display format
  AddProp(SrpSDisplayFormat, SRpSString, aexp.DisplayFormat);
  // Multipage
  AddProp(SRpMultiPage, SRpSBool, BoolToStr(aexp.MultiPage, True));
  AddProp(SRpPrintNulls, SRpSBool, BoolToStr(aexp.PrintNulls, True));
  // Identifier
  AddProp(SrpSIdentifier, SRpSString, aexp.Identifier);
  // Aggregate
  AddProp(SrpSAggregate, SRpSList, AggregateToString(aexp.Aggregate));
  // Aggregate group
  AddProp(SrpSAgeGroup, SRpGroup, aexp.GroupName);
  // Aggregate type
  AddProp(SrpSAgeType, SRpSList, AgeTypeToString(aexp.AgType));
  // Aggregate Ini value
  AddProp(SrpSIniValue, SRpSExpression, aexp.AgIniValue);
  // Print Only One
  AddProp(SRpSOnlyOne, SRpSBool, BoolToStr(aexp.PrintOnlyOne, True));
  // Export Expression
  AddProp(SRpSExportExpression, SRpSExpression, aexp.ExportExpression);
  // Export Display format
  AddProp(SRpSExportFormat, SRpSString, aexp.ExportDisplayFormat);
  // Export Line
  AddProp(SRpSExportLine, SRpSInteger, IntToStr(aexp.ExportLine));
  // Export Position
  AddProp(SRpSExportPos, SRpSInteger, IntToStr(aexp.ExportPosition));
  // Export Size
  AddProp(SRpSExportSize, SRpSInteger, IntToStr(aexp.ExportSize));
  // Export Do New Line
  AddProp(SRpSExportDoNewLine, SRpSBool, BoolToStr(aexp.ExportDoNewLine, True));
end;

procedure TRpExpressionInterface.SetProperty(pname: WideString; value: WideString);
var
  aexp: TRpExpression;
begin
  aexp := TRpExpression(printitem);
  if not Assigned(aexp) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;
  if pname = SrpSExpression then
  begin
    aexp.Expression := value;
    Invalidate;
    Exit;
  end;
  if pname = SRpIsHtml then
  begin
    aexp.IsHtml := StrToBoolDef(value, aexp.IsHtml);
    Invalidate;
    Exit;
  end;
  if pname = SRpSDataType then
  begin
    aexp.DataType := StringToParamType(value);
    Exit;
  end;
  if pname = SrpSDisplayFormat then
  begin
    aexp.DisplayFormat := value;
    Exit;
  end;
  if pname = SRpMultiPage then
  begin
    aexp.MultiPage := StrToBoolDef(value, aexp.MultiPage);
    Exit;
  end;
  if pname = SRpPrintNulls then
  begin
    aexp.PrintNulls := StrToBoolDef(value, aexp.PrintNulls);
    Exit;
  end;
  if pname = SrpSIdentifier then
  begin
    aexp.Identifier := value;
    Exit;
  end;
  if pname = SrpSAggregate then
  begin
    aexp.Aggregate := StringToAggregate(value);
    Exit;
  end;
  if pname = SrpSAgeGroup then
  begin
    aexp.GroupName := value;
    Exit;
  end;
  if pname = SrpSAgeType then
  begin
    aexp.AgType := StringToAgeType(value);
    Exit;
  end;
  if pname = SrpSIniValue then
  begin
    aexp.AgIniValue := value;
    Exit;
  end;
  if pname = SrpSOnlyOne then
  begin
    aexp.PrintOnlyOne := StrToBoolDef(value, aexp.PrintOnlyOne);
    Exit;
  end;
  if pname = SRpSExportExpression then
  begin
    aexp.ExportExpression := value;
    Exit;
  end;
  if pname = SRpSExportFormat then
  begin
    aexp.ExportDisplayFormat := value;
    Exit;
  end;
  if pname = SRpSExportLine then
  begin
    aexp.ExportLine := StrToIntDef(value, aexp.ExportLine);
    Exit;
  end;
  if pname = SRpSExportPos then
  begin
    aexp.ExportPosition := StrToIntDef(value, aexp.ExportPosition);
    Exit;
  end;
  if pname = SRpSExportSize then
  begin
    aexp.ExportSize := StrToIntDef(value, aexp.ExportSize);
    Exit;
  end;
  if pname = SRpSExportDoNewLine then
  begin
    aexp.ExportDoNewLine := StrToBoolDef(value, aexp.ExportDoNewLine);
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpExpressionInterface.GetProperty(pname: WideString): WideString;
var
  aexp: TRpExpression;
begin
  aexp := TRpExpression(printitem);
  if not Assigned(aexp) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;
  if pname = SrpSExpression then Result := aexp.Expression
  else if pname = SRpIsHtml then Result := BoolToStr(aexp.IsHtml, True)
  else if pname = SRpSDataType then Result := ParamTypeToString(aexp.DataType)
  else if pname = SrpSDisplayFormat then Result := aexp.DisplayFormat
  else if pname = SRpMultiPage then Result := BoolToStr(aexp.MultiPage, True)
  else if pname = SRpPrintNulls then Result := BoolToStr(aexp.PrintNulls, True)
  else if pname = SrpSIdentifier then Result := aexp.Identifier
  else if pname = SrpSAggregate then Result := AggregateToString(aexp.Aggregate)
  else if pname = SrpSAgeGroup then Result := aexp.GroupName
  else if pname = SrpSAgeType then Result := AgeTypeToString(aexp.AgType)
  else if pname = SrpSIniValue then Result := aexp.AgIniValue
  else if pname = SrpSOnlyOne then Result := BoolToStr(aexp.PrintOnlyOne, True)
  else if pname = SrpSExportExpression then Result := aexp.ExportExpression
  else if pname = SRpSExportFormat then Result := aexp.ExportDisplayFormat
  else if pname = SRpSExportLine then Result := IntToStr(aexp.ExportLine)
  else if pname = SRpSExportPos then Result := IntToStr(aexp.ExportPosition)
  else if pname = SRpSExportSize then Result := IntToStr(aexp.ExportSize)
  else if pname = SRpSExportDoNewLine then Result := BoolToStr(aexp.ExportDoNewLine, True)
  else Result := inherited GetProperty(pname);
end;

procedure TRpExpressionInterface.GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings);
var
  i: TRpAggregate;
  it: TRpAggregateType;
begin
  if pname = SRpSAgeType then
  begin
    lpossiblevalues.Clear;
    for it := rpagSum to rpagStdDev do
      lpossiblevalues.Add(AgeTypeToString(it));
    Exit;
  end;
  if pname = SRpSDataType then
  begin
    lpossiblevalues.Clear;
    GetPossibleDataTypesRuntime(lpossiblevalues);
    Exit;
  end;
  if pname = SRpSAggregate then
  begin
    lpossiblevalues.Clear;
    for i := rpAgNone to rpAgGeneral do
      lpossiblevalues.Add(AggregateToString(i));
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

procedure TRpExpressionInterface.Paint;
var
  aexp: TRpExpression;
begin
  aexp := TRpExpression(printitem);
  if not Assigned(aexp) or (csDestroying in aexp.ComponentState) then
    Exit;

  Canvas.Font.Name := aexp.WFontName;
  Canvas.Font.Color := aexp.FontColor;
  Canvas.Font.Size := Round(aexp.FontSize * Scale);
  Canvas.Font.Style := CLXIntegerToFontStyle(aexp.FontStyle);
  DrawItemText(Canvas, aexp, aexp.Expression, Width, Height);

  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psDashDot;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  DrawSelected;
end;

end.

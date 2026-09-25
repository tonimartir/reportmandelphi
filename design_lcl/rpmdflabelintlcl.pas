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
  rpmdconsts, rpgraphutilslcl, rptypes;

type
  TRpLabelInterface = class(TRpGenTextInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
  end;

  TRpExpressionInterface = class(TRpGenTextInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
    procedure GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings); override;
  end;

implementation

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
  lnames.Add(SrpSText);
  ltypes.Add(SRpSMemo);
  lhints.Add('reflabel.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) and Assigned(alabel) then lvalues.Add(alabel.Text);
end;

procedure TRpLabelInterface.SetProperty(pname: string; value: WideString);
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
  inherited SetProperty(pname, value);
end;

function TRpLabelInterface.GetProperty(pname: string): WideString;
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
  else Result := inherited GetProperty(pname);
end;

procedure TRpLabelInterface.Paint;
var
  alabel: TRpLabel;
  rec, arec: TRect;
  aalign: Cardinal;
  lalignment: Integer;
  alvcenter, alvbottom, calcrect: Boolean;
  Segments: THtmlSegmentList;
  Seg: THtmlSegment;
  X, Y: Integer;
  sText: string;
begin
  alabel := TRpLabel(printitem);
  if not Assigned(alabel) or (csDestroying in alabel.ComponentState) then
    Exit;

  Canvas.Font.Name := alabel.WFontName;
  Canvas.Font.Color := alabel.FontColor;
  Canvas.Font.Size := Round(alabel.FontSize * Scale);
  Canvas.Font.Style := CLXIntegerToFontStyle(alabel.FontStyle);

  rec.Left := 0;
  rec.Top := 0;
  rec.Right := Width;
  rec.Bottom := Height;

  if not alabel.Transparent then
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := alabel.BackColor;
    Canvas.FillRect(rec);
  end
  else
    Canvas.Brush.Style := bsClear;

  lalignment := alabel.PrintAlignment;
  aalign := DT_NOPREFIX;
  if (lalignment and AlignmentFlags_AlignHCenter) > 0 then
    aalign := aalign or DT_CENTER;
  if (lalignment and AlignmentFlags_SingleLine) > 0 then
    aalign := aalign or DT_SINGLELINE;
  if (lalignment and AlignmentFlags_AlignLeft) > 0 then
    aalign := aalign or DT_LEFT;
  if (lalignment and AlignmentFlags_AlignRight) > 0 then
    aalign := aalign or DT_RIGHT;
  if alabel.WordWrap then
    aalign := aalign or DT_WORDBREAK;
  if not alabel.CutText then
    aalign := aalign or DT_NOCLIP;

  sText := alabel.Text;
  if alabel.IsHtml then
  begin
    Segments := ParseHtml(sText);
    try
      X := rec.Left;
      Y := rec.Top;
      if (lalignment and AlignmentFlags_SingleLine) > 0 then
      begin
        if (alabel.VAlignment and AlignmentFlags_AlignVCenter) > 0 then
          Y := Y + (rec.Bottom - rec.Top - Canvas.TextHeight('Wg')) div 2;
      end;

      for Seg in Segments do
      begin
        Canvas.Font.Style := CLXIntegerToFontStyle(alabel.FontStyle);
        if hsBold in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsBold];
        if hsItalic in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsItalic];
        if hsUnderline in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
        if hsStrikeOut in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsStrikeOut];

        if (Seg.Text = #13#10) or (Seg.Text = #10) then
        begin
          Y := Y + Canvas.TextHeight('Wg');
          X := rec.Left;
        end
        else
        begin
          Canvas.TextOut(X, Y, Seg.Text);
          X := X + Canvas.TextWidth(Seg.Text);
        end;
      end;
    finally
      Segments.Free;
    end;
  end
  else
  begin
    alvbottom := (alabel.VAlignment and AlignmentFlags_AlignBottom) > 0;
    alvcenter := (alabel.VAlignment and AlignmentFlags_AlignVCenter) > 0;
    calcrect := (not alabel.Transparent) or alvbottom or alvcenter;
    arec := rec;
    if calcrect then
      DrawText(Canvas.Handle, PChar(sText), Length(sText), arec, aalign or DT_CALCRECT);
    if alvbottom then
      rec.Top := rec.Top + (rec.Bottom - arec.Bottom);
    if alvcenter then
      rec.Top := rec.Top + ((rec.Bottom - arec.Bottom) div 2);

    DrawText(Canvas.Handle, PChar(sText), Length(sText), rec, aalign);
  end;

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
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  aexp := TRpExpression(printitem);
  lnames.Add(SrpSExpression);
  ltypes.Add(SRpSExpression);
  lhints.Add('refexpression.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) and Assigned(aexp) then lvalues.Add(aexp.Expression);

  lnames.Add(SrpSDisplayFormat);
  ltypes.Add(SRpSString);
  lhints.Add('refexpression.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) and Assigned(aexp) then lvalues.Add(aexp.DisplayFormat);
end;

procedure TRpExpressionInterface.SetProperty(pname: string; value: WideString);
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
  if pname = SrpSDisplayFormat then
  begin
    aexp.DisplayFormat := value;
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpExpressionInterface.GetProperty(pname: string): WideString;
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
  else if pname = SrpSDisplayFormat then Result := aexp.DisplayFormat
  else Result := inherited GetProperty(pname);
end;

procedure TRpExpressionInterface.GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings);
begin
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

procedure TRpExpressionInterface.Paint;
var
  aexp: TRpExpression;
  rec, arec: TRect;
  aalign: Cardinal;
  lalignment: Integer;
  alvcenter, alvbottom, calcrect: Boolean;
  Segments: THtmlSegmentList;
  Seg: THtmlSegment;
  X, Y: Integer;
  sText: string;
begin
  aexp := TRpExpression(printitem);
  if not Assigned(aexp) or (csDestroying in aexp.ComponentState) then
    Exit;

  Canvas.Font.Name := aexp.WFontName;
  Canvas.Font.Color := aexp.FontColor;
  Canvas.Font.Size := Round(aexp.FontSize * Scale);
  Canvas.Font.Style := CLXIntegerToFontStyle(aexp.FontStyle);

  rec.Left := 0;
  rec.Top := 0;
  rec.Right := Width;
  rec.Bottom := Height;

  if not aexp.Transparent then
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := aexp.BackColor;
    Canvas.FillRect(rec);
  end
  else
    Canvas.Brush.Style := bsClear;

  lalignment := aexp.PrintAlignment;
  aalign := DT_NOPREFIX;
  if (lalignment and AlignmentFlags_AlignHCenter) > 0 then
    aalign := aalign or DT_CENTER;
  if (lalignment and AlignmentFlags_SingleLine) > 0 then
    aalign := aalign or DT_SINGLELINE;
  if (lalignment and AlignmentFlags_AlignLeft) > 0 then
    aalign := aalign or DT_LEFT;
  if (lalignment and AlignmentFlags_AlignRight) > 0 then
    aalign := aalign or DT_RIGHT;
  if aexp.WordWrap then
    aalign := aalign or DT_WORDBREAK;
  if not aexp.CutText then
    aalign := aalign or DT_NOCLIP;

  sText := aexp.Expression;
  if aexp.IsHtml then
  begin
    Segments := ParseHtml(sText);
    try
      X := rec.Left;
      Y := rec.Top;
      if (lalignment and AlignmentFlags_SingleLine) > 0 then
      begin
        if (aexp.VAlignment and AlignmentFlags_AlignVCenter) > 0 then
          Y := Y + (rec.Bottom - rec.Top - Canvas.TextHeight('Wg')) div 2;
      end;

      for Seg in Segments do
      begin
        Canvas.Font.Style := CLXIntegerToFontStyle(aexp.FontStyle);
        if hsBold in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsBold];
        if hsItalic in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsItalic];
        if hsUnderline in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
        if hsStrikeOut in Seg.Styles then Canvas.Font.Style := Canvas.Font.Style + [fsStrikeOut];

        if (Seg.Text = #13#10) or (Seg.Text = #10) then
        begin
          Y := Y + Canvas.TextHeight('Wg');
          X := rec.Left;
        end
        else
        begin
          Canvas.TextOut(X, Y, Seg.Text);
          X := X + Canvas.TextWidth(Seg.Text);
        end;
      end;
    finally
      Segments.Free;
    end;
  end
  else
  begin
    alvbottom := (aexp.VAlignment and AlignmentFlags_AlignBottom) > 0;
    alvcenter := (aexp.VAlignment and AlignmentFlags_AlignVCenter) > 0;
    calcrect := (not aexp.Transparent) or alvbottom or alvcenter;
    arec := rec;
    if calcrect then
      DrawText(Canvas.Handle, PChar(sText), Length(sText), arec, aalign or DT_CALCRECT);
    if alvbottom then
      rec.Top := rec.Top + (rec.Bottom - arec.Bottom);
    if alvcenter then
      rec.Top := rec.Top + ((rec.Bottom - arec.Bottom) div 2);

    DrawText(Canvas.Handle, PChar(sText), Length(sText), rec, aalign);
  end;

  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psDashDot;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  DrawSelected;
end;

end.

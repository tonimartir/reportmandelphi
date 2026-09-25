{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfdrawintlcl                                 }
{       Shape and Image designer items for LCL          }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfdrawintlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Types,
  Graphics, Forms, Controls, Dialogs,
  rpmdobinsintlcl, rpprintitem, rpdrawitem, rpmdconsts,
  rpgraphutilslcl, rpmunits, rptypes;

type
  TRpDrawInterface = class(TRpSizePosInterface)
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

  TRpImageInterface = class(TRpSizePosInterface)
  private
    FBitmap: TBitmap;
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    destructor Destroy; override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
  end;

implementation

{ TRpDrawInterface }

constructor TRpDrawInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if not (pritem is TRpShape) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

class procedure TRpDrawInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpDrawInterface');
end;

procedure TRpDrawInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  ashape: TRpShape;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  ashape := TRpShape(printitem);

  lnames.Add(SrpSShape);
  ltypes.Add(SRpSList);
  lhints.Add('refdraw.html');
  lcat.Add(SRpShape);
  if Assigned(lvalues) then lvalues.Add(IntToStr(Integer(ashape.Shape)));

  lnames.Add(SrpSPenColor);
  ltypes.Add(SRpSColor);
  lhints.Add('refdraw.html');
  lcat.Add(SRpShape);
  if Assigned(lvalues) then lvalues.Add(IntToStr(ashape.PenColor));

  lnames.Add(SrpSBrushColor);
  ltypes.Add(SRpSColor);
  lhints.Add('refdraw.html');
  lcat.Add(SRpShape);
  if Assigned(lvalues) then lvalues.Add(IntToStr(ashape.BrushColor));
end;

procedure TRpDrawInterface.SetProperty(pname: string; value: WideString);
var
  ashape: TRpShape;
begin
  ashape := TRpShape(printitem);
  if pname = SrpSPenColor then
  begin
    ashape.PenColor := StrToIntDef(value, 0);
    Invalidate;
    Exit;
  end;
  if pname = SrpSBrushColor then
  begin
    ashape.BrushColor := StrToIntDef(value, 0);
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpDrawInterface.GetProperty(pname: string): WideString;
var
  ashape: TRpShape;
begin
  ashape := TRpShape(printitem);
  if pname = SrpSPenColor then Result := IntToStr(ashape.PenColor)
  else if pname = SrpSBrushColor then Result := IntToStr(ashape.BrushColor)
  else Result := inherited GetProperty(pname);
end;

procedure TRpDrawInterface.GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings);
begin
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

procedure TRpDrawInterface.Paint;
var
  ashape: TRpShape;
  X, Y, W, H, S: Integer;
begin
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psDashDot;
  Canvas.Pen.Width := 0;
  Canvas.Pen.Color := clGray;
  Canvas.Rectangle(0, 0, Width, Height);

  ashape := TRpShape(printitem);
  if not Assigned(ashape) or (csDestroying in ashape.ComponentState) then
    Exit;

  Canvas.Brush.Color := ashape.BrushColor;
  Canvas.Brush.Style := TBrushStyle(ashape.BrushStyle);
  Canvas.Pen.Style := TPenStyle(ashape.PenStyle);
  Canvas.Pen.Color := ashape.PenColor;
  Canvas.Pen.Width := Round(Screen.PixelsPerInch * ashape.PenWidth / TWIPS_PER_INCHESS);
  if Canvas.Pen.Width < 1 then Canvas.Pen.Width := 1;

  X := Canvas.Pen.Width div 2;
  Y := X;
  W := Width - Canvas.Pen.Width;
  H := Height - Canvas.Pen.Width;
  if W < 1 then W := 1;
  if H < 1 then H := 1;

  if W < H then S := W else S := H;
  if ashape.Shape in [rpsSquare, rpsRoundSquare, rpsCircle] then
  begin
    Inc(X, (W - S) div 2);
    Inc(Y, (H - S) div 2);
    W := S;
    H := S;
  end;

  case ashape.Shape of
    rpsRectangle, rpsSquare:
      Canvas.Rectangle(X, Y, X + W, Y + H);
    rpsRoundRect, rpsRoundSquare:
      Canvas.RoundRect(X, Y, X + W, Y + H, S div 4, S div 4);
    rpsCircle, rpsEllipse:
      Canvas.Ellipse(X, Y, X + W, Y + H);
    rpsHorzLine:
    begin
      Canvas.MoveTo(0, Height div 2);
      Canvas.LineTo(Width, Height div 2);
    end;
    rpsVertLine:
    begin
      Canvas.MoveTo(Width div 2, 0);
      Canvas.LineTo(Width div 2, Height);
    end;
    rpsOblique1:
    begin
      Canvas.MoveTo(0, 0);
      Canvas.LineTo(Width, Height);
    end;
    rpsOblique2:
    begin
      Canvas.MoveTo(0, Height);
      Canvas.LineTo(Width, 0);
    end;
  end;

  DrawSelected;
end;

{ TRpImageInterface }

constructor TRpImageInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if not (pritem is TRpImage) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

destructor TRpImageInterface.Destroy;
begin
  FreeAndNil(FBitmap);
  inherited Destroy;
end;

class procedure TRpImageInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpImageInterface');
end;

procedure TRpImageInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  aimage: TRpImage;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  aimage := TRpImage(printitem);
  lnames.Add(SrpSExpression);
  ltypes.Add(SRpSExpression);
  lhints.Add('refimage.html');
  lcat.Add(SRpImage);
  if Assigned(lvalues) then lvalues.Add(aimage.Expression);
end;

procedure TRpImageInterface.SetProperty(pname: string; value: WideString);
var
  aimage: TRpImage;
begin
  aimage := TRpImage(printitem);
  if pname = SrpSExpression then
  begin
    aimage.Expression := value;
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpImageInterface.GetProperty(pname: string): WideString;
var
  aimage: TRpImage;
begin
  aimage := TRpImage(printitem);
  if pname = SrpSExpression then Result := aimage.Expression
  else Result := inherited GetProperty(pname);
end;

procedure TRpImageInterface.Paint;
var
  aimage: TRpImage;
  sText: string;
begin
  aimage := TRpImage(printitem);
  if not Assigned(aimage) or (csDestroying in aimage.ComponentState) then
    Exit;

  Canvas.Pen.Color := clNavy;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);

  Canvas.Font.Size := 8;
  Canvas.Font.Color := clNavy;
  sText := '[Image]';
  if Length(aimage.Expression) > 0 then
    sText := aimage.Expression;
  Canvas.TextOut(4, 4, sText);

  DrawSelected;
end;

end.

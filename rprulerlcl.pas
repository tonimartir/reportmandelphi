{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rprulerlcl                                      }
{       A Display ruler that can be horizontal or       }
{       vertical, in cms or inches for LCL              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rprulerlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Types,
  Graphics, Controls, Forms,
  rpmunits, rpgraphutilslcl, rpmdconsts;

const
  CMAXHEIGHT = 5800;

type
  TRprulertype = (rHorizontal, rVertical);
  TRprulermetric = (rCms, rInchess);

  TRpRulerLCL = class(TCustomControl)
  private
    Updated: Boolean;
    FRType: TRprulertype;
    FBorderStyle: TBorderStyle;
    FMetrics: TRprulermetric;
    FScale: Double;
    procedure SetRType(value: TRprulertype);
    procedure SetMetrics(Value: TRprulermetric);
    procedure SetScale(nvalue: Double);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
  published
    property BorderStyle: TBorderStyle read FBorderStyle write FBorderStyle default bsSingle;
    property RType: TRprulertype read FRType write SetRType default rVertical;
    property Align;
    property Scale: Double read FScale write SetScale;
    property Metrics: TRprulermetric read FMetrics write SetMetrics default rCms;
    property Visible;
    property Color;
    property Font;
  end;

  // Compatibility alias
  TRpRuler = TRpRulerLCL;

function PaintRuler(metrics: TRprulermetric; scale: Double; RType: TRpRulerType;
  Color: TColor; Width, Height: Integer): TBitmap;

implementation

var
  bitmapHcm: TBitmap;
  bitscaleHcm: Double;
  bitmapVcm: TBitmap;
  bitscaleVcm: Double;
  bitmapHin: TBitmap;
  bitscaleHin: Double;
  bitmapVin: TBitmap;
  bitscaleVin: Double;

constructor TRpRulerLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBorderStyle := bsSingle;
  FRType := rVertical;
  Color := clWhite;
  FMetrics := rCms;
  FScale := 1.0;
  Width := 20;
  Updated := False;
end;

destructor TRpRulerLCL.Destroy;
begin
  inherited Destroy;
end;

procedure TRpRulerLCL.SetScale(nvalue: Double);
begin
  if FScale = nvalue then
    Exit;
  FScale := nvalue;
  Invalidate;
end;

procedure TRpRulerLCL.SetRType(value: TRprulertype);
begin
  if (value <> FRType) and Updated then
    Exit;
  Updated := False;
  FRType := value;
  Invalidate;
end;

procedure TRpRulerLCL.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
end;

procedure TRpRulerLCL.SetMetrics(Value: TRprulermetric);
begin
  if value = FMetrics then
    Exit;
  FMetrics := Value;
  Invalidate;
end;

procedure TRpRulerLCL.Paint;
var
  bit: TBitmap;
begin
  bit := PaintRuler(FMetrics, FScale, FRType, Color, Width, Height);
  if Assigned(bit) then
    Canvas.Draw(0, 0, bit);
  if BorderStyle = bsSingle then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := clBlack;
    Canvas.Pen.Style := psSolid;
    Canvas.Rectangle(0, 0, Width, Height);
  end;
end;

function LogicalPointToDevicePoint(origin, destination, value: TPoint): TPoint;
begin
  Result := value;
  if (origin.X = 0) or (origin.Y = 0) then
    Exit;
  Result.X := Round(value.X * (destination.X / origin.X));
  Result.Y := Round(value.Y * (destination.Y / origin.Y));
end;

function PaintRuler(metrics: TRprulermetric; scale: Double; RType: TRpRulerType;
  Color: TColor; Width, Height: Integer): TBitmap;
var
  rect: TRect;
  value, Clength, CHeight: Integer;
  bitmap: TBitmap;
  pixelsperinchx, pixelsperinchy: Integer;
  windowwidth, windowheight: Integer;
  h1, h2, h3, x: Integer;
  i, onethousand, onecent: Double;
  bwidth, bheight: Integer;
  origin, destination, avalue: TPoint;
  sText: string;
begin
  if scale <= 0 then
    scale := 1.0;
  Bitmap := nil;
  bwidth := ScaleDpi(2500);
  bheight := ScaleDpi(2500);

  if metrics = rCms then
  begin
    if RType = rHorizontal then
    begin
      if Assigned(bitmapHcm) then
      begin
        if (Width > bitmapHcm.Width) or (bitscaleHcm <> scale) then
        begin
          bwidth := Width;
          bitscaleHcm := scale;
          FreeAndNil(bitmapHcm);
        end
        else
          Bitmap := bitmapHcm;
      end;
    end
    else
    begin
      if Assigned(bitmapVcm) then
      begin
        if (Height > bitmapVcm.Height) or (bitscaleVcm <> scale) then
        begin
          bheight := Height;
          bitscaleVcm := scale;
          FreeAndNil(bitmapVcm);
        end
        else
          Bitmap := bitmapVcm;
      end;
    end;
  end
  else
  begin
    if RType = rHorizontal then
    begin
      if Assigned(bitmapHin) then
      begin
        if (Width > bitmapHin.Width) or (bitscaleHin <> scale) then
        begin
          bwidth := Width;
          bitscaleHin := scale;
          FreeAndNil(bitmapHin);
        end
        else
          Bitmap := bitmapHin;
      end;
    end
    else
    begin
      if Assigned(bitmapVin) then
      begin
        if (Height > bitmapVin.Height) or (bitscaleVin <> scale) then
        begin
          bheight := Height;
          bitscaleVin := scale;
          FreeAndNil(bitmapVin);
        end
        else
          Bitmap := bitmapVin;
      end;
    end;
  end;

  if Assigned(Bitmap) then
  begin
    Result := Bitmap;
    Exit;
  end;

  Bitmap := TBitmap.Create;
  if metrics = rCms then
  begin
    if RType = rHorizontal then
      bitmapHcm := Bitmap
    else
      bitmapVcm := Bitmap;
  end
  else
  begin
    if RType = rHorizontal then
      bitmapHin := Bitmap
    else
      bitmapVin := Bitmap;
  end;

  Bitmap.PixelFormat := pf32bit;
  if RType = rHorizontal then
  begin
    Bitmap.Width := bwidth;
    Bitmap.Height := ScaleDpi(20);
  end
  else
  begin
    Bitmap.Width := ScaleDpi(20);
    Bitmap.Height := bheight;
  end;

  Bitmap.Canvas.Brush.Color := Color;
  Bitmap.Canvas.Brush.Style := bsSolid;
  Bitmap.Canvas.Pen.Style := psSolid;
  Bitmap.Canvas.Pen.Color := clBlack;
  Bitmap.Canvas.Font.Size := 7;
  Bitmap.Canvas.Font.Color := clBlack;

  rect.Left := 0;
  rect.Top := 0;
  rect.Right := Bitmap.Width;
  rect.Bottom := Bitmap.Height;

  pixelsperinchx := Round(Screen.PixelsPerInch * scale);
  pixelsperinchy := Round(Screen.PixelsPerInch * scale);
  if pixelsperinchx <= 0 then pixelsperinchx := 96;
  if pixelsperinchy <= 0 then pixelsperinchy := 96;

  Bitmap.Canvas.Rectangle(rect.Left, rect.Top, rect.Right, rect.Bottom);

  if metrics = rCms then
  begin
    onecent := 100.0 / CMS_PER_INCHESS;
    onethousand := onecent * 10.0;
  end
  else
  begin
    onethousand := 1000.0;
    onecent := 100.0;
  end;

  windowwidth := Round(1000.0 * rect.Right / pixelsperinchx);
  windowheight := Round(1000.0 * rect.Bottom / pixelsperinchy);

  if scale >= 1.0 then
  begin
    h1 := Round(120.0 / scale * 1.5);
    h2 := Round(60.0 / scale * 1.5);
    h3 := Round(30.0 / scale * 1.5);
  end
  else
  begin
    h1 := 240;
    h2 := 120;
    h3 := 60;
  end;

  origin.X := windowwidth;
  origin.Y := windowheight;
  destination.X := rect.Right;
  destination.Y := rect.Bottom;

  if RType = rHorizontal then
  begin
    i := 0;
    Clength := windowwidth;
    CHeight := windowheight;
    x := 0;
    while i < Clength do
    begin
      value := x mod 10;
      if value = 0 then
      begin
        avalue.X := Round(i);
        avalue.Y := 0;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        sText := IntToStr(Round(i / onethousand));
        Bitmap.Canvas.Brush.Style := bsClear;
        Bitmap.Canvas.TextOut(avalue.X + 1, avalue.Y, sText);

        avalue.X := Round(i);
        avalue.Y := CHeight;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.MoveTo(avalue.X, avalue.Y);
        avalue.X := Round(i);
        avalue.Y := CHeight - h1;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.LineTo(avalue.X, avalue.Y);
      end
      else if value = 5 then
      begin
        avalue.X := Round(i);
        avalue.Y := CHeight;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.MoveTo(avalue.X, avalue.Y);
        avalue.X := Round(i);
        avalue.Y := CHeight - h2;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.LineTo(avalue.X, avalue.Y);
      end
      else
      begin
        avalue.X := Round(i);
        avalue.Y := CHeight;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.MoveTo(avalue.X, avalue.Y);
        avalue.X := Round(i);
        avalue.Y := CHeight - h3;
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.LineTo(avalue.X, avalue.Y);
      end;
      i := i + onecent;
      Inc(x);
    end;
  end
  else
  begin
    i := 0;
    Clength := windowheight;
    CHeight := windowwidth;
    x := 0;
    while i < Clength do
    begin
      value := x mod 10;
      if value = 0 then
      begin
        avalue.X := 0;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        sText := IntToStr(Round(i / onethousand));
        Bitmap.Canvas.Brush.Style := bsClear;
        Bitmap.Canvas.TextOut(avalue.X + 1, avalue.Y, sText);

        avalue.X := CHeight;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.MoveTo(avalue.X, avalue.Y);
        avalue.X := CHeight - h1;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.LineTo(avalue.X, avalue.Y);
      end
      else if value = 5 then
      begin
        avalue.X := CHeight;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.MoveTo(avalue.X, avalue.Y);
        avalue.X := CHeight - h2;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.LineTo(avalue.X, avalue.Y);
      end
      else
      begin
        avalue.X := CHeight;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.MoveTo(avalue.X, avalue.Y);
        avalue.X := CHeight - h3;
        avalue.Y := Round(i);
        avalue := LogicalPointToDevicePoint(origin, destination, avalue);
        Bitmap.Canvas.LineTo(avalue.X, avalue.Y);
      end;
      i := i + onecent;
      Inc(x);
    end;
  end;

  Result := Bitmap;
end;

initialization
  bitmapHcm := nil;
  bitmapVcm := nil;
  bitmapHin := nil;
  bitmapVin := nil;

finalization
  FreeAndNil(bitmapHcm);
  FreeAndNil(bitmapVcm);
  FreeAndNil(bitmapHin);
  FreeAndNil(bitmapVin);

end.

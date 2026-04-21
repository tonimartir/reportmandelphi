{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpchatmodernstyle                               }
{       Modern flat styling primitives for AI chat UI   }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpchatmodernstyle;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls;

const
  // Neutral corporate palette, light only
  ClrSurface       : TColor = $FFFFFF; // white
  ClrBg            : TColor = $FAF8F7; // F7F8FA -> BGR
  ClrBorder        : TColor = $E8E4E1; // E1E4E8
  ClrBorderStrong  : TColor = $DED7D0; // D0D7DE
  ClrText          : TColor = $28231F; // 1F2328
  ClrSubText       : TColor = $81776E; // 6E7781
  ClrMuted         : TColor = $B0A69C; // 9CA6B0
  ClrHover         : TColor = $F4F3F3; // F3F4F6
  ClrActive        : TColor = $EBE7E4; // E4E7EB
  ClrAccent        : TColor = $EB6F1F; // 1F6FEB -> RGB reversed for TColor
  ClrAccentHover   : TColor = $C45818; // 1858C4
  ClrAccentSoft    : TColor = $FFEBDD; // DDEBFF
  ClrDanger        : TColor = $2E22CF; // CF222E
  ClrDangerHover   : TColor = $231BA3; // A31B23
  ClrDangerSoft    : TColor = $DCDCFF; // FFDCDC
  ClrSuccess       : TColor = $57A83A; // 3AA857

  FontNameUi       = 'Segoe UI';
  FontSizeUi       = 9;
  FontSizeMicro    = 7;
  FontSizeLabel    = 8;
  FontSizeHeading  = 10;

type
  TRpIconKind = (rpikRefresh, rpikCog, rpikChevronDown, rpikStop, rpikSignIn,
    rpikPerson);

  TRpChatStyle = class
  public
    class procedure SetupFont(AFont: TFont; APointSize: Integer = FontSizeUi;
      ABold: Boolean = False; AColor: TColor = clNone); static;
    class procedure StylePanelSurface(APanel: TPanel); static;
    class procedure StylePanelBg(APanel: TPanel); static;

    class procedure DrawFlatRect(ACanvas: TCanvas; const ARect: TRect;
      ABgColor, ABorderColor: TColor); static;
    class procedure DrawRoundRectFlat(ACanvas: TCanvas; const ARect: TRect;
      ARadius: Integer; ABgColor, ABorderColor: TColor); static;
    class procedure DrawChip(ACanvas: TCanvas; const ARect: TRect;
      const ACaption: string; ABgColor, ATextColor: TColor;
      ABold: Boolean = True); static;
    class procedure DrawAvatarCircle(ACanvas: TCanvas; const ARect: TRect;
      ABitmap: TGraphic; ABorderColor: TColor); static;
    class procedure DrawAvatarInitial(ACanvas: TCanvas; const ARect: TRect;
      const AInitial: string; ABgColor, ATextColor: TColor); static;
    class procedure DrawUnderlineTab(ACanvas: TCanvas; const ARect: TRect;
      const ACaption: string; AActive, AHover: Boolean); static;
    class procedure DrawIconButton(ACanvas: TCanvas; const ARect: TRect;
      AKind: TRpIconKind; AEnabled, AHover, APressed: Boolean); static;
    class procedure DrawIcon(ACanvas: TCanvas; const ARect: TRect;
      AKind: TRpIconKind; AColor: TColor); static;

    class procedure DrawCircularGauge(ACanvas: TCanvas; const ARect: TRect;
      ARatio: Double; const ALabel: string; ATrackColor,
      AProgressColor, ATextColor: TColor); static;

    // Smooth antialiased arc using GDI polyline
    class procedure DrawAntialiasedArc(ACanvas: TCanvas; const ARect: TRect;
      AStartDeg, ASweepDeg: Double; AColor: TColor; APenWidth: Integer); static;
  end;

function Scale(AValue: Integer; ADpi: Integer = 96): Integer; inline;

implementation

function Scale(AValue: Integer; ADpi: Integer = 96): Integer;
begin
  Result := MulDiv(AValue, Screen.PixelsPerInch, 96);
end;

{ TRpChatStyle }

class procedure TRpChatStyle.SetupFont(AFont: TFont; APointSize: Integer;
  ABold: Boolean; AColor: TColor);
begin
  if AFont = nil then
    Exit;
  AFont.Name := FontNameUi;
  AFont.Size := APointSize;
  if ABold then
    AFont.Style := AFont.Style + [fsBold]
  else
    AFont.Style := AFont.Style - [fsBold];
  if AColor <> clNone then
    AFont.Color := AColor;
end;

class procedure TRpChatStyle.StylePanelSurface(APanel: TPanel);
begin
  if APanel = nil then Exit;
  APanel.BevelOuter := bvNone;
  APanel.BevelInner := bvNone;
  APanel.ParentBackground := False;
  APanel.ParentColor := False;
  APanel.Color := ClrSurface;
  APanel.DoubleBuffered := True;
end;

class procedure TRpChatStyle.StylePanelBg(APanel: TPanel);
begin
  if APanel = nil then Exit;
  APanel.BevelOuter := bvNone;
  APanel.BevelInner := bvNone;
  APanel.ParentBackground := False;
  APanel.ParentColor := False;
  APanel.Color := ClrBg;
  APanel.DoubleBuffered := True;
end;

class procedure TRpChatStyle.DrawFlatRect(ACanvas: TCanvas; const ARect: TRect;
  ABgColor, ABorderColor: TColor);
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.FillRect(ARect);
  if ABorderColor <> clNone then
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.Pen.Color := ABorderColor;
    ACanvas.Pen.Width := 1;
    ACanvas.Pen.Style := psSolid;
    ACanvas.Rectangle(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom);
    ACanvas.Brush.Style := bsSolid;
  end;
end;

class procedure TRpChatStyle.DrawRoundRectFlat(ACanvas: TCanvas;
  const ARect: TRect; ARadius: Integer; ABgColor, ABorderColor: TColor);
begin
  if ARadius <= 0 then
  begin
    DrawFlatRect(ACanvas, ARect, ABgColor, ABorderColor);
    Exit;
  end;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  if ABorderColor = clNone then
  begin
    ACanvas.Pen.Color := ABgColor;
    ACanvas.Pen.Style := psClear;
  end
  else
  begin
    ACanvas.Pen.Color := ABorderColor;
    ACanvas.Pen.Width := 1;
    ACanvas.Pen.Style := psSolid;
  end;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom,
    ARadius * 2, ARadius * 2);
end;

class procedure TRpChatStyle.DrawChip(ACanvas: TCanvas; const ARect: TRect;
  const ACaption: string; ABgColor, ATextColor: TColor; ABold: Boolean);
var
  LRect: TRect;
  LTxt: string;
begin
  LRect := ARect;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Color := ABgColor;
  ACanvas.Pen.Width := 1;
  ACanvas.RoundRect(LRect.Left, LRect.Top, LRect.Right, LRect.Bottom,
    LRect.Height, LRect.Height);

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := FontNameUi;
  ACanvas.Font.Size := FontSizeMicro;
  if ABold then
    ACanvas.Font.Style := [fsBold]
  else
    ACanvas.Font.Style := [];
  ACanvas.Font.Color := ATextColor;

  LTxt := ACaption;
  DrawText(ACanvas.Handle, PChar(LTxt), Length(LTxt), LRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS);
end;

class procedure TRpChatStyle.DrawAvatarCircle(ACanvas: TCanvas;
  const ARect: TRect; ABitmap: TGraphic; ABorderColor: TColor);
var
  LRgn: HRGN;
  LRect: TRect;
  LBmp: TBitmap;
begin
  LRect := ARect;
  LRgn := CreateEllipticRgn(LRect.Left, LRect.Top, LRect.Right, LRect.Bottom);
  try
    SelectClipRgn(ACanvas.Handle, LRgn);
    ACanvas.Brush.Color := ClrActive;
    ACanvas.FillRect(LRect);
    if (ABitmap <> nil) and (not ABitmap.Empty) then
    begin
      LBmp := TBitmap.Create;
      try
        LBmp.SetSize(LRect.Width, LRect.Height);
        LBmp.Canvas.Brush.Color := ClrActive;
        LBmp.Canvas.FillRect(Rect(0, 0, LBmp.Width, LBmp.Height));
        LBmp.Canvas.StretchDraw(Rect(0, 0, LBmp.Width, LBmp.Height), ABitmap);
        ACanvas.Draw(LRect.Left, LRect.Top, LBmp);
      finally
        LBmp.Free;
      end;
    end;
    SelectClipRgn(ACanvas.Handle, 0);
  finally
    DeleteObject(LRgn);
  end;
  if ABorderColor <> clNone then
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.Pen.Color := ABorderColor;
    ACanvas.Pen.Width := 1;
    ACanvas.Ellipse(LRect);
    ACanvas.Brush.Style := bsSolid;
  end;
end;

class procedure TRpChatStyle.DrawAvatarInitial(ACanvas: TCanvas;
  const ARect: TRect; const AInitial: string; ABgColor, ATextColor: TColor);
var
  LRect: TRect;
  LSize: Integer;
begin
  LRect := ARect;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Color := ABgColor;
  ACanvas.Ellipse(LRect);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := FontNameUi;
  LSize := LRect.Height div 2;
  if LSize < 8 then LSize := 8;
  ACanvas.Font.Size := LSize - 2;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := ATextColor;
  DrawText(ACanvas.Handle, PChar(AInitial), Length(AInitial), LRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

class procedure TRpChatStyle.DrawUnderlineTab(ACanvas: TCanvas;
  const ARect: TRect; const ACaption: string; AActive, AHover: Boolean);
var
  LRect, LTextRect, LUnderline: TRect;
  LBg, LText: TColor;
  LUnderH: Integer;
begin
  LRect := ARect;
  LUnderH := 2;

  // Background
  if AHover and not AActive then
    LBg := ClrHover
  else
    LBg := ClrBg;
  ACanvas.Brush.Color := LBg;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.FillRect(LRect);

  // Text
  if AActive then
    LText := ClrText
  else if AHover then
    LText := ClrText
  else
    LText := ClrSubText;

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := FontNameUi;
  ACanvas.Font.Size := FontSizeUi;
  if AActive then
    ACanvas.Font.Style := [fsBold]
  else
    ACanvas.Font.Style := [];
  ACanvas.Font.Color := LText;

  LTextRect := LRect;
  Dec(LTextRect.Bottom, LUnderH);
  DrawText(ACanvas.Handle, PChar(ACaption), Length(ACaption), LTextRect,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);

  // Underline for active tab
  if AActive then
  begin
    LUnderline := Rect(LRect.Left + 8, LRect.Bottom - LUnderH,
      LRect.Right - 8, LRect.Bottom);
    ACanvas.Brush.Color := ClrAccent;
    ACanvas.Brush.Style := bsSolid;
    ACanvas.FillRect(LUnderline);
  end;

  // Bottom baseline
  ACanvas.Pen.Color := ClrBorder;
  ACanvas.Pen.Width := 1;
  ACanvas.MoveTo(LRect.Left, LRect.Bottom - 1);
  ACanvas.LineTo(LRect.Right, LRect.Bottom - 1);
end;

class procedure TRpChatStyle.DrawIcon(ACanvas: TCanvas; const ARect: TRect;
  AKind: TRpIconKind; AColor: TColor);
var
  R: TRect;
  CX, CY, RR: Integer;
  Pts: array of TPoint;

  procedure LineXY(X1, Y1, X2, Y2: Integer);
  begin
    ACanvas.MoveTo(X1, Y1);
    ACanvas.LineTo(X2, Y2);
  end;

begin
  R := ARect;
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  if R.Width < R.Height then
    RR := R.Width div 2
  else
    RR := R.Height div 2;
  Dec(RR, 2);
  if RR < 4 then RR := 4;

  ACanvas.Pen.Color := AColor;
  ACanvas.Brush.Color := AColor;
  ACanvas.Pen.Width := 2;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Brush.Style := bsClear;

  case AKind of
    rpikRefresh:
      begin
        // Circular arc ~270 deg + arrow head
        DrawAntialiasedArc(ACanvas, Rect(CX - RR, CY - RR, CX + RR, CY + RR),
          30, 260, AColor, 2);
        // Arrow head at angle 30 (start of arc)
        ACanvas.Brush.Color := AColor;
        ACanvas.Brush.Style := bsSolid;
        SetLength(Pts, 3);
        Pts[0] := Point(CX + RR, CY - Round(RR * 0.5));
        Pts[1] := Point(CX + RR + 4, CY - Round(RR * 0.5) - 4);
        Pts[2] := Point(CX + RR - 4, CY - Round(RR * 0.5) - 4);
        ACanvas.Polygon(Pts);
      end;

    rpikCog:
      begin
        ACanvas.Pen.Width := 2;
        ACanvas.Brush.Style := bsClear;
        // 8 spokes
        LineXY(CX, CY - RR, CX, CY - RR + 3);
        LineXY(CX, CY + RR, CX, CY + RR - 3);
        LineXY(CX - RR, CY, CX - RR + 3, CY);
        LineXY(CX + RR, CY, CX + RR - 3, CY);
        LineXY(CX - RR + 2, CY - RR + 2, CX - RR + 4, CY - RR + 4);
        LineXY(CX + RR - 2, CY - RR + 2, CX + RR - 4, CY - RR + 4);
        LineXY(CX - RR + 2, CY + RR - 2, CX - RR + 4, CY + RR - 4);
        LineXY(CX + RR - 2, CY + RR - 2, CX + RR - 4, CY + RR - 4);
        // Outer ring
        ACanvas.Ellipse(CX - RR + 3, CY - RR + 3, CX + RR - 3, CY + RR - 3);
        // Center dot
        ACanvas.Brush.Color := AColor;
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Ellipse(CX - 2, CY - 2, CX + 2, CY + 2);
      end;

    rpikChevronDown:
      begin
        ACanvas.Pen.Width := 2;
        LineXY(CX - 4, CY - 2, CX, CY + 2);
        LineXY(CX, CY + 2, CX + 4, CY - 2);
      end;

    rpikStop:
      begin
        ACanvas.Brush.Color := AColor;
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Pen.Color := AColor;
        ACanvas.Rectangle(CX - RR + 1, CY - RR + 1, CX + RR - 1, CY + RR - 1);
      end;

    rpikSignIn:
      begin
        // Arrow pointing right into a box
        ACanvas.Pen.Width := 2;
        LineXY(CX - RR, CY, CX + 2, CY);
        LineXY(CX - 2, CY - 4, CX + 2, CY);
        LineXY(CX - 2, CY + 4, CX + 2, CY);
        ACanvas.Rectangle(CX + 2, CY - RR, CX + RR, CY + RR);
      end;

    rpikPerson:
      begin
        ACanvas.Brush.Color := AColor;
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Pen.Color := AColor;
        // Head
        ACanvas.Ellipse(CX - 4, CY - RR, CX + 4, CY - RR + 8);
        // Shoulders
        ACanvas.Chord(CX - RR, CY - RR + 6, CX + RR, CY + RR + 6,
          CX + RR, CY + 1, CX - RR, CY + 1);
      end;
  end;
end;

class procedure TRpChatStyle.DrawIconButton(ACanvas: TCanvas; const ARect: TRect;
  AKind: TRpIconKind; AEnabled, AHover, APressed: Boolean);
var
  LBg, LBorder, LIconColor: TColor;
begin
  if not AEnabled then
  begin
    LBg := ClrBg;
    LBorder := ClrBorder;
    LIconColor := ClrMuted;
  end
  else if APressed then
  begin
    LBg := ClrActive;
    LBorder := ClrBorderStrong;
    LIconColor := ClrText;
  end
  else if AHover then
  begin
    LBg := ClrHover;
    LBorder := ClrBorderStrong;
    LIconColor := ClrText;
  end
  else
  begin
    LBg := ClrSurface;
    LBorder := ClrBorder;
    LIconColor := ClrSubText;
  end;

  DrawRoundRectFlat(ACanvas, ARect, 4, LBg, LBorder);
  DrawIcon(ACanvas, ARect, AKind, LIconColor);
end;

class procedure TRpChatStyle.DrawAntialiasedArc(ACanvas: TCanvas;
  const ARect: TRect; AStartDeg, ASweepDeg: Double; AColor: TColor;
  APenWidth: Integer);
var
  PointCount, I: Integer;
  AngleStep, Angle, Rad: Double;
  RX, RY, CXp, CYp: Integer;
  Pts: array of TPoint;
begin
  if (ARect.Width < 4) or (ARect.Height < 4) then Exit;
  PointCount := Round(Abs(ASweepDeg) / 3) + 2;
  if PointCount < 2 then PointCount := 2;
  SetLength(Pts, PointCount);
  AngleStep := ASweepDeg / (PointCount - 1);
  Angle := AStartDeg;
  RX := ARect.Width div 2;
  RY := ARect.Height div 2;
  CXp := ARect.Left + RX;
  CYp := ARect.Top + RY;
  for I := 0 to PointCount - 1 do
  begin
    Rad := Angle * PI / 180.0;
    Pts[I].X := Round(CXp + RX * Cos(Rad));
    Pts[I].Y := Round(CYp - RY * Sin(Rad));
    Angle := Angle + AngleStep;
  end;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := APenWidth;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Polyline(Pts);
end;

class procedure TRpChatStyle.DrawCircularGauge(ACanvas: TCanvas;
  const ARect: TRect; ARatio: Double; const ALabel: string;
  ATrackColor, AProgressColor, ATextColor: TColor);
var
  R: TRect;
  Txt: string;
  PenW: Integer;
begin
  R := ARect;
  InflateRect(R, -2, -2);
  PenW := 3;

  // Track
  DrawAntialiasedArc(ACanvas, R, 0, 360, ATrackColor, PenW);

  // Progress
  if ARatio > 0 then
  begin
    if ARatio > 1 then ARatio := 1;
    DrawAntialiasedArc(ACanvas, R, 90, -(ARatio * 360), AProgressColor, PenW);
  end;

  // Label
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := FontNameUi;
  ACanvas.Font.Size := FontSizeMicro;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := ATextColor;
  Txt := ALabel;
  DrawText(ACanvas.Handle, PChar(Txt), Length(Txt), R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

end.

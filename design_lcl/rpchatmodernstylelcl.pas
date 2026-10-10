{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpchatmodernstylelcl                            }
{       Modern flat styling primitives for AI chat UI   }
{       (LCL port of rpchatmodernstyle)                 }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpchatmodernstylelcl;

{ Same palette and drawing helpers as the VCL rpchatmodernstyle, drawn with
  the LCL canvas only (TextRect instead of DrawText, LCLIntf regions), so
  they work with every widgetset. The VCL StyleElements (IDE styles) do not
  exist in the LCL. TRpChatIconButton is new: a flat icon button drawn with
  DrawIconButton (the VCL uses a TButton with an image collection). }

{$mode delphi}

interface

uses
  SysUtils, Classes, Types, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  LCLType, LCLIntf;

const
  // Neutral corporate palette, light only (TColor is BGR)
  ClrSurface       : TColor = $FFFFFF; // white
  ClrBg            : TColor = $FAF8F7; // F7F8FA -> BGR
  ClrBorder        : TColor = $E8E4E1; // E1E4E8
  ClrBorderStrong  : TColor = $DED7D0; // D0D7DE
  ClrText          : TColor = $28231F; // 1F2328
  ClrSubText       : TColor = $81776E; // 6E7781
  ClrMuted         : TColor = $B0A69C; // 9CA6B0
  ClrHover         : TColor = $F4F3F3; // F3F4F6
  ClrActive        : TColor = $EBE7E4; // E4E7EB
  ClrAccent        : TColor = $EB6F1F; // 1F6FEB
  ClrAccentHover   : TColor = $C45818; // 1858C4
  ClrAccentSoft    : TColor = $FFEBDD; // DDEBFF
  ClrDanger        : TColor = $2E22CF; // CF222E
  ClrDangerHover   : TColor = $231BA3; // A31B23
  ClrDangerSoft    : TColor = $DCDCFF; // FFDCDC
  ClrSuccess       : TColor = $57A83A; // 3AA857

{$IFDEF MSWINDOWS}
  FontNameUi       = 'Segoe UI';
{$ELSE}
  // The widgetset default font (Qt/GTK theme)
  FontNameUi       = 'default';
{$ENDIF}
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
    class procedure StyleInputControl(AControl: TWinControl); static;
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

    // Smooth arc drawn as a polyline
    class procedure DrawAntialiasedArc(ACanvas: TCanvas; const ARect: TRect;
      AStartDeg, ASweepDeg: Double; AColor: TColor; APenWidth: Integer); static;

    // Text in a rectangle (the VCL DrawText with DT_SINGLELINE/DT_NOPREFIX)
    class procedure DrawTextIn(ACanvas: TCanvas; const ARect: TRect;
      const AText: string; AAlignment: TAlignment = taCenter;
      ALayout: TTextLayout = tlCenter; AEllipsis: Boolean = False); static;
    // Text size with a font, without a control handle (memory bitmap)
    class function TextWidthOf(AFont: TFont; const AText: string): Integer; static;
    class function TextHeightOf(AFont: TFont): Integer; static;

    // The lists of the cloud schemas and of the Hub databases draw a red dot
    // before the name of one whose Agent is not connected (DrawComboItem).
    // It needs an owner-drawn combo, and only the Windows widgetset draws
    // the items of one: elsewhere the lists say it in the text (OfflineText)
    class function CanDrawComboDot: Boolean; static;
    // Such a combo: owner-drawn with AOnDrawItem and the height of its text
    // where the dot can be drawn, csDropDownList elsewhere; the hint on
    class procedure SetupDotCombo(ACombo: TComboBox;
      AOnDrawItem: TDrawItemEvent); static;
    // ' (not connected)' after the name of an Agent that is not connected
    // where the dot can not be drawn, '' otherwise
    class function OfflineText(AOffline: Boolean): string; static;
    // An item of such a combo as the LCL draws it (the combo sets the
    // colours of its state): AText, with the red dot after its first ADotAt
    // characters (the icons, so the dot is right before the name); -1 = no
    // dot
    class procedure DrawComboItem(ACanvas: TCanvas; const ARect: TRect;
      AState: TOwnerDrawState; const AText: string; ADotAt: Integer); static;
    // The open list as wide as its longest text and the dot: at least the
    // combo, at most 600 pixels or the screen (ItemWidth, CB_SETDROPPEDWIDTH
    // of the Windows widgetset; the others size their lists themselves)
    class procedure FitComboDropDownWidth(ACombo: TComboBox); static;
  end;

  { TRpChatIconButton: flat icon button (hover and pressed states) }

  TRpChatIconButton = class(TGraphicControl)
  private
    FKind: TRpIconKind;
    FHover: Boolean;
    FPressed: Boolean;
    procedure SetKind(AValue: TRpIconKind);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Kind: TRpIconKind read FKind write SetKind default rpikCog;
    property Align;
    property Enabled;
    property Hint;
    property ShowHint;
    property ParentShowHint;
    property Visible;
    property OnClick;
  end;

function Scale(AValue: Integer; ADpi: Integer = 96): Integer; inline;

implementation

uses
  InterfaceBase, LCLPlatformDef, rpmdconsts;

function Scale(AValue: Integer; ADpi: Integer = 96): Integer;
begin
  Result := MulDiv(AValue, Screen.PixelsPerInch, 96);
end;

{ TRpChatStyle }

class procedure TRpChatStyle.DrawTextIn(ACanvas: TCanvas; const ARect: TRect;
  const AText: string; AAlignment: TAlignment; ALayout: TTextLayout;
  AEllipsis: Boolean);
var
  LStyle: TTextStyle;
begin
  LStyle := ACanvas.TextStyle;
  LStyle.Alignment := AAlignment;
  LStyle.Layout := ALayout;
  LStyle.SingleLine := True;
  LStyle.Wordbreak := False;
  LStyle.Clipping := True;
  LStyle.ShowPrefix := False;
  LStyle.Opaque := False;
  LStyle.EndEllipsis := AEllipsis;
  ACanvas.TextRect(ARect, ARect.Left, ARect.Top, AText, LStyle);
end;

var
  MeasureBitmap: TBitmap = nil;
  MeasureDefaultFont: TFont = nil;

// One bitmap measures every text: the layouts measure on every Resize, and a
// bitmap per call costs a graphics context each time (with Cocoa they pile up
// in the autorelease pool until the event loop turns)
function MeasureCanvas(AFont: TFont): TCanvas;
begin
  if MeasureBitmap = nil then
  begin
    MeasureBitmap := TBitmap.Create;
    MeasureBitmap.SetSize(1, 1);
    MeasureDefaultFont := TFont.Create;
  end;
  Result := MeasureBitmap.Canvas;
  if AFont <> nil then
    Result.Font.Assign(AFont)
  else
    Result.Font.Assign(MeasureDefaultFont);
end;

class function TRpChatStyle.TextWidthOf(AFont: TFont; const AText: string): Integer;
begin
  Result := MeasureCanvas(AFont).TextWidth(AText);
end;

class function TRpChatStyle.TextHeightOf(AFont: TFont): Integer;
begin
  Result := MeasureCanvas(AFont).TextHeight('Mg');
end;

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

class procedure TRpChatStyle.StyleInputControl(AControl: TWinControl);
begin
  // The VCL defeats the IDE visual styles here (StyleElements) and derives
  // the combo height from the font; the LCL widgetsets size their combos
  // themselves, so the font is inherited and nothing else is needed.
  if AControl = nil then
    Exit;
end;

class procedure TRpChatStyle.StylePanelSurface(APanel: TPanel);
begin
  if APanel = nil then
    Exit;
  APanel.BevelOuter := bvNone;
  APanel.BevelInner := bvNone;
  APanel.ParentBackground := False;
  APanel.ParentColor := False;
  APanel.Color := ClrSurface;
end;

class procedure TRpChatStyle.StylePanelBg(APanel: TPanel);
begin
  if APanel = nil then
    Exit;
  APanel.BevelOuter := bvNone;
  APanel.BevelInner := bvNone;
  APanel.ParentBackground := False;
  APanel.ParentColor := False;
  APanel.Color := ClrBg;
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
  ACanvas.Pen.Style := psSolid;
end;

class procedure TRpChatStyle.DrawChip(ACanvas: TCanvas; const ARect: TRect;
  const ACaption: string; ABgColor, ATextColor: TColor; ABold: Boolean);
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Color := ABgColor;
  ACanvas.Pen.Width := 1;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom,
    ARect.Height, ARect.Height);

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := FontNameUi;
  ACanvas.Font.Size := FontSizeMicro;
  if ABold then
    ACanvas.Font.Style := [fsBold]
  else
    ACanvas.Font.Style := [];
  ACanvas.Font.Color := ATextColor;
  DrawTextIn(ACanvas, ARect, ACaption, taCenter, tlCenter, True);
end;

class procedure TRpChatStyle.DrawAvatarCircle(ACanvas: TCanvas;
  const ARect: TRect; ABitmap: TGraphic; ABorderColor: TColor);
var
  LRgn: HRGN;
begin
  LRgn := CreateEllipticRgn(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom);
  try
    SelectClipRGN(ACanvas.Handle, LRgn);
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := ClrActive;
    ACanvas.FillRect(ARect);
    if (ABitmap <> nil) and (not ABitmap.Empty) then
      ACanvas.StretchDraw(ARect, ABitmap);
    SelectClipRGN(ACanvas.Handle, 0);
  finally
    DeleteObject(LRgn);
  end;
  if ABorderColor <> clNone then
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.Pen.Color := ABorderColor;
    ACanvas.Pen.Width := 1;
    ACanvas.Ellipse(ARect);
    ACanvas.Brush.Style := bsSolid;
  end;
end;

class procedure TRpChatStyle.DrawAvatarInitial(ACanvas: TCanvas;
  const ARect: TRect; const AInitial: string; ABgColor, ATextColor: TColor);
var
  LSize: Integer;
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Color := ABgColor;
  ACanvas.Ellipse(ARect);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := FontNameUi;
  LSize := ARect.Height div 2;
  if LSize < 8 then
    LSize := 8;
  ACanvas.Font.Size := LSize - 2;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := ATextColor;
  DrawTextIn(ACanvas, ARect, AInitial);
end;

class procedure TRpChatStyle.DrawUnderlineTab(ACanvas: TCanvas;
  const ARect: TRect; const ACaption: string; AActive, AHover: Boolean);
var
  LTextRect, LUnderline: TRect;
  LBg, LText: TColor;
  LUnderH: Integer;
begin
  LUnderH := 2;
  if AHover and not AActive then
    LBg := ClrHover
  else
    LBg := ClrBg;
  ACanvas.Brush.Color := LBg;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.FillRect(ARect);

  if AActive or AHover then
    LText := ClrText
  else
    LText := ClrSubText;

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Size := FontSizeUi;
  if AActive then
    ACanvas.Font.Style := [fsBold]
  else
    ACanvas.Font.Style := [];
  ACanvas.Font.Color := LText;

  LTextRect := ARect;
  Dec(LTextRect.Bottom, LUnderH);
  DrawTextIn(ACanvas, LTextRect, ACaption);

  if AActive then
  begin
    LUnderline := Rect(ARect.Left + 8, ARect.Bottom - LUnderH,
      ARect.Right - 8, ARect.Bottom);
    ACanvas.Brush.Color := ClrAccent;
    ACanvas.Brush.Style := bsSolid;
    ACanvas.FillRect(LUnderline);
  end;

  ACanvas.Pen.Color := ClrBorder;
  ACanvas.Pen.Width := 1;
  ACanvas.MoveTo(ARect.Left, ARect.Bottom - 1);
  ACanvas.LineTo(ARect.Right, ARect.Bottom - 1);
end;

class procedure TRpChatStyle.DrawIcon(ACanvas: TCanvas; const ARect: TRect;
  AKind: TRpIconKind; AColor: TColor);
var
  CX, CY, RR: Integer;
  Pts: array of TPoint;

  procedure LineXY(X1, Y1, X2, Y2: Integer);
  begin
    ACanvas.MoveTo(X1, Y1);
    ACanvas.LineTo(X2, Y2);
  end;

begin
  CX := (ARect.Left + ARect.Right) div 2;
  CY := (ARect.Top + ARect.Bottom) div 2;
  if ARect.Width < ARect.Height then
    RR := ARect.Width div 2
  else
    RR := ARect.Height div 2;
  Dec(RR, 2);
  if RR < 4 then
    RR := 4;

  ACanvas.Pen.Color := AColor;
  ACanvas.Brush.Color := AColor;
  ACanvas.Pen.Width := 2;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Brush.Style := bsClear;

  case AKind of
    rpikRefresh:
      begin
        DrawAntialiasedArc(ACanvas, Rect(CX - RR, CY - RR, CX + RR, CY + RR),
          30, 260, AColor, 2);
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
        LineXY(CX, CY - RR, CX, CY - RR + 3);
        LineXY(CX, CY + RR, CX, CY + RR - 3);
        LineXY(CX - RR, CY, CX - RR + 3, CY);
        LineXY(CX + RR, CY, CX + RR - 3, CY);
        LineXY(CX - RR + 2, CY - RR + 2, CX - RR + 4, CY - RR + 4);
        LineXY(CX + RR - 2, CY - RR + 2, CX + RR - 4, CY - RR + 4);
        LineXY(CX - RR + 2, CY + RR - 2, CX - RR + 4, CY + RR - 4);
        LineXY(CX + RR - 2, CY + RR - 2, CX + RR - 4, CY + RR - 4);
        ACanvas.Ellipse(CX - RR + 3, CY - RR + 3, CX + RR - 3, CY + RR - 3);
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
        ACanvas.Ellipse(CX - 4, CY - RR, CX + 4, CY - RR + 8);
        ACanvas.Chord(CX - RR, CY - RR + 6, CX + RR, CY + RR + 6,
          CX + RR, CY + 1, CX - RR, CY + 1);
      end;
  end;
  ACanvas.Pen.Width := 1;
  ACanvas.Brush.Style := bsSolid;
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
  if (ARect.Width < 4) or (ARect.Height < 4) then
    Exit;
  PointCount := Round(Abs(ASweepDeg) / 3) + 2;
  if PointCount < 2 then
    PointCount := 2;
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
  ACanvas.Pen.Width := 1;
end;

class procedure TRpChatStyle.DrawCircularGauge(ACanvas: TCanvas;
  const ARect: TRect; ARatio: Double; const ALabel: string;
  ATrackColor, AProgressColor, ATextColor: TColor);
var
  R: TRect;
  PenW: Integer;
begin
  R := ARect;
  InflateRect(R, -2, -2);
  PenW := 3;

  DrawAntialiasedArc(ACanvas, R, 0, 360, ATrackColor, PenW);
  if ARatio > 0 then
  begin
    if ARatio > 1 then
      ARatio := 1;
    DrawAntialiasedArc(ACanvas, R, 90, -(ARatio * 360), AProgressColor, PenW);
  end;

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Size := FontSizeMicro;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := ATextColor;
  DrawTextIn(ACanvas, R, ALabel);
end;

{ TRpChatIconButton }

constructor TRpChatIconButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKind := rpikCog;
  Cursor := crHandPoint;
  SetInitialBounds(0, 0, 26, 26);
end;

procedure TRpChatIconButton.SetKind(AValue: TRpIconKind);
begin
  if FKind = AValue then
    Exit;
  FKind := AValue;
  Invalidate;
end;

procedure TRpChatIconButton.Paint;
begin
  // Parent background around the rounded corners
  Canvas.Brush.Style := bsSolid;
  if Parent <> nil then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := ClrBg;
  Canvas.FillRect(ClientRect);
  TRpChatStyle.DrawIconButton(Canvas, Rect(0, 0, Width - 1, Height - 1), FKind,
    Enabled, FHover, FPressed);
end;

procedure TRpChatIconButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TRpChatIconButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  FPressed := False;
  Invalidate;
end;

procedure TRpChatIconButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FPressed := True;
    Invalidate;
  end;
end;

procedure TRpChatIconButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  FPressed := False;
  Invalidate;
  inherited MouseUp(Button, Shift, X, Y);
end;

{ The combos with the red dot }

// The red dot of DrawComboItem for the height of the text, and the room it
// takes with the gap after it
function ComboDotSize(ATextHeight: Integer): Integer;
begin
  Result := ATextHeight * 2 div 5;
  if Result < 5 then
    Result := 5;
end;

function ComboDotRoom(ATextHeight: Integer): Integer;
begin
  Result := ComboDotSize(ATextHeight);
  Result := Result + Result div 2 + 1;
end;

class function TRpChatStyle.CanDrawComboDot: Boolean;
begin
  Result := WidgetSet.LCLPlatform = lpWin32;
end;

class procedure TRpChatStyle.SetupDotCombo(ACombo: TComboBox;
  AOnDrawItem: TDrawItemEvent);
begin
  if CanDrawComboDot then
  begin
    ACombo.Style := csOwnerDrawFixed;
    ACombo.ItemHeight := TextHeightOf(ACombo.Font) + Scale(2);
    ACombo.OnDrawItem := AOnDrawItem;
  end
  else
    ACombo.Style := csDropDownList;
  ACombo.ShowHint := True;
end;

class function TRpChatStyle.OfflineText(AOffline: Boolean): string;
begin
  Result := '';
  if AOffline and not CanDrawComboDot then
    Result := ' ' + string(TranslateStr(2005, '(not connected)'));
end;

class procedure TRpChatStyle.DrawComboItem(ACanvas: TCanvas;
  const ARect: TRect; AState: TOwnerDrawState; const AText: string;
  ADotAt: Integer);
var
  LRect: TRect;
  LTextHeight, LSize, LDotTop: Integer;
  LBrushColor, LPenColor: TColor;
  LPrefix: string;
begin
  if not (odBackgroundPainted in AState) then
    ACanvas.FillRect(ARect);
  // 2 pixels in, as the LCL draws an item
  LRect := ARect;
  Inc(LRect.Left, 2);
  if ADotAt < 0 then
  begin
    DrawTextIn(ACanvas, LRect, AText, taLeftJustify, tlCenter);
    Exit;
  end;
  LPrefix := Copy(AText, 1, ADotAt);
  if LPrefix <> '' then
  begin
    DrawTextIn(ACanvas, LRect, LPrefix, taLeftJustify, tlCenter);
    Inc(LRect.Left, ACanvas.TextWidth(LPrefix));
  end;
  LTextHeight := ACanvas.TextHeight('Mg');
  LSize := ComboDotSize(LTextHeight);
  LDotTop := ARect.Top + (ARect.Bottom - ARect.Top - LSize) div 2;
  LBrushColor := ACanvas.Brush.Color;
  LPenColor := ACanvas.Pen.Color;
  ACanvas.Brush.Color := ClrDanger;
  ACanvas.Pen.Color := ClrDanger;
  ACanvas.Ellipse(LRect.Left, LDotTop, LRect.Left + LSize, LDotTop + LSize);
  ACanvas.Brush.Color := LBrushColor;
  ACanvas.Pen.Color := LPenColor;
  Inc(LRect.Left, ComboDotRoom(LTextHeight));
  DrawTextIn(ACanvas, LRect, Copy(AText, ADotAt + 1, MaxInt), taLeftJustify,
    tlCenter);
end;

class procedure TRpChatStyle.FitComboDropDownWidth(ACombo: TComboBox);
var
  I, LWidth, LMaxWidth: Integer;
begin
  if (ACombo = nil) or not CanDrawComboDot then
    Exit;
  LWidth := 0;
  for I := 0 to ACombo.Items.Count - 1 do
    if TextWidthOf(ACombo.Font, ACombo.Items[I]) > LWidth then
      LWidth := TextWidthOf(ACombo.Font, ACombo.Items[I]);
  // The margins, the dot and the scroll bar
  Inc(LWidth, Scale(8) + ComboDotRoom(TextHeightOf(ACombo.Font)));
  if ACombo.Items.Count > ACombo.DropDownCount then
    Inc(LWidth, GetSystemMetrics(SM_CXVSCROLL));
  LMaxWidth := Scale(600);
  if LMaxWidth > Screen.Width then
    LMaxWidth := Screen.Width;
  if LWidth > LMaxWidth then
    LWidth := LMaxWidth;
  if LWidth < ACombo.Width then
    LWidth := ACombo.Width;
  ACombo.ItemWidth := LWidth;
end;

finalization
  FreeAndNil(MeasureBitmap);
  FreeAndNil(MeasureDefaultFont);

end.

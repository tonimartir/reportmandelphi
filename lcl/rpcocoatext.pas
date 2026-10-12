{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpcocoatext                                     }
{       Painting with LCL Cocoa (macOS) the glyphs      }
{       the Core Text provider laid out                 }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

{ The counterpart of the Cairo painting of GTK2 in rplcldriver for LCL Cocoa:
  when the text is measured by the Core Text provider (rpinfoprovct), its
  glyphs (the numbers Core Text chose, ligatures and joined Arabic forms
  included) are painted at the positions of the layout, with the same
  CTFont, on the CGContext of the canvas: the bitmap of the preview and the
  PDF context of Printer4Lazarus alike. Nothing is shaped again, so the
  preview and the print are the PDF.

  In its own unit because MacOSAll would hide names of rplcldriver (Rect,
  Point...). Elsewhere (and with other widgetsets) RpCocoaCanPaint is False. }

unit rpcocoatext;

{$mode objfpc}{$H+}

interface

// True when the text of this provider is measured by Core Text and the
// canvas handle is a context of LCL Cocoa: then RpCocoaDrawGlyphs paints it
function RpCocoaCanPaint(AProvider: TObject; ACanvasHandle: PtrUInt): Boolean;

// The glyph of a character in the face of a family (or '@' + PostScript
// name) and style, as the Core Text provider resolves it; 0 when none
function RpCocoaGlyphForChar(const AFamily: string; ABold, AItalic: Boolean;
  ACh: System.WideChar): Cardinal;

// Paints glyphs on the canvas: the positions are the origins of the glyphs
// in pixels of the canvas, ASizePx the font size in pixels (vertical),
// AScaleX the horizontal over vertical resolution, AAngle the rotation
// (radians, counterclockwise) and AColor an RGB of the LCL ($00BBGGRR)
procedure RpCocoaDrawGlyphs(ACanvasHandle: PtrUInt; const AFamily: string;
  ABold, AItalic: Boolean; ASizePx, AScaleX, AAngle: Double; AColor: LongInt;
  const AGlyphs: array of Cardinal; const AX, AY: array of Double; ACount: Integer);

implementation

{$IF DEFINED(DARWIN) AND DEFINED(LCLCOCOA)}
uses
  MacOSAll, CocoaGDIObjects, rpinfoprovct;

function RpCocoaCanPaint(AProvider: TObject; ACanvasHandle: PtrUInt): Boolean;
begin
  Result := (AProvider is TRpCTInfoProvider) and (ACanvasHandle <> 0) and
    (TObject(ACanvasHandle) is TCocoaContext) and
    (TCocoaContext(TObject(ACanvasHandle)).CGContext <> nil);
end;

function RpCocoaGlyphForChar(const AFamily: string; ABold, AItalic: Boolean;
  ACh: System.WideChar): Cardinal;
var
  face: TRpCTFace;
  ch: UniChar;
  glyph: CGGlyph;
begin
  Result := 0;
  face := RpCTFace(AFamily, ABold, AItalic);
  if face = nil then
    Exit;
  ch := UniChar(Ord(ACh));
  glyph := 0;
  CTFontGetGlyphsForCharacters(face.Font, @ch, @glyph, 1);
  Result := glyph;
end;

procedure RpCocoaDrawGlyphs(ACanvasHandle: PtrUInt; const AFamily: string;
  ABold, AItalic: Boolean; ASizePx, AScaleX, AAngle: Double; AColor: LongInt;
  const AGlyphs: array of Cardinal; const AX, AY: array of Double; ACount: Integer);
var
  ctx: CGContextRef;
  face: TRpCTFace;
  font: CTFontRef;
  m: CGAffineTransform;
  c, s: Double;
  i: Integer;
  g: CGGlyph;
  origin: CGPoint;
begin
  if (ACount <= 0) or (ASizePx <= 0) then
    Exit;
  ctx := TCocoaContext(TObject(ACanvasHandle)).CGContext;
  face := RpCTFace(AFamily, ABold, AItalic);
  if (ctx = nil) or (face = nil) then
    Exit;
  font := CTFontCreateCopyWithAttributes(face.Font, ASizePx, nil, nil);
  if font = nil then
    Exit;
  try
    CGContextSaveGState(ctx);
    try
      CGContextSetRGBFillColor(ctx, (AColor and $FF) / 255, ((AColor shr 8) and $FF) / 255,
        ((AColor shr 16) and $FF) / 255, 1);
      // Text space (y up) to the space of the canvas (y down): the baseline
      // turned AAngle counterclockwise on the page, x scaled as the device
      c := Cos(AAngle);
      s := Sin(AAngle);
      m.a := c * AScaleX;
      m.b := -s * AScaleX;
      m.c := -s;
      m.d := -c;
      m.tx := 0;
      m.ty := 0;
      origin.x := 0;
      origin.y := 0;
      // Each glyph at its origin: the coordinates move there and the glyph is
      // drawn at 0,0, so the position does not depend on how Core Text
      // combines its positions with the text matrix
      for i := 0 to ACount - 1 do
      begin
        if AGlyphs[i] = 0 then
          Continue;
        g := CGGlyph(AGlyphs[i]);
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, AX[i], AY[i]);
        CGContextSetTextMatrix(ctx, m);
        CTFontDrawGlyphs(font, @g, @origin, 1, ctx);
        CGContextRestoreGState(ctx);
      end;
    finally
      CGContextRestoreGState(ctx);
    end;
  finally
    CFRelease(font);
  end;
end;

{$ELSE}

function RpCocoaCanPaint(AProvider: TObject; ACanvasHandle: PtrUInt): Boolean;
begin
  Result := False;
end;

function RpCocoaGlyphForChar(const AFamily: string; ABold, AItalic: Boolean;
  ACh: System.WideChar): Cardinal;
begin
  Result := 0;
end;

procedure RpCocoaDrawGlyphs(ACanvasHandle: PtrUInt; const AFamily: string;
  ABold, AItalic: Boolean; ASizePx, AScaleX, AAngle: Double; AColor: LongInt;
  const AGlyphs: array of Cardinal; const AX, AY: array of Double; ACount: Integer);
begin
end;

{$IFEND}

end.

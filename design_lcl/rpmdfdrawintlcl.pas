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
  Graphics, Forms, Controls, Dialogs, Menus, Clipbrd,
  rpmdobinsintlcl, rpprintitem, rpdrawitem, rpmdconsts,
  rpgraphutilslcl, rpmunits, rptypes, rptranslator;

type
  TRpDrawInterface = class(TRpSizePosInterface)
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

  TRpImageInterface = class(TRpSizePosInterface)
  private
    // Decoded image and the model stream it was decoded from
    FBitmap: TBitmap;
    FBitmapSource: TMemoryStream;
    FBitmapError: Boolean;
    mimage, mcut, mcopy, mpaste, mopen: TMenuItem;
    procedure CutImageClick(Sender: TObject);
    procedure CopyImageClick(Sender: TObject);
    procedure PasteImageClick(Sender: TObject);
    procedure LoadImageClick(Sender: TObject);
  protected
    procedure Paint; override;
    procedure InitPopUpMenu; override;
    procedure PopUpContextMenu; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    destructor Destroy; override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: WideString; value: WideString); overload; override;
    function GetProperty(pname: WideString): WideString; overload; override;
    procedure GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings); override;
    procedure SetProperty(pname: WideString; stream: TMemoryStream); overload; override;
    procedure GetProperty(pname: WideString; var Stream: TMemoryStream); overload; override;
    // Decoded image of the model stream (nil if there is none or it is not
    // a valid image)
    function DesignBitmap: TBitmap;
    // Draws the item as the design surface shows it
    procedure DrawImageTo(ACanvas: TCanvas; AWidth, AHeight: Integer);
    // Context menu actions (recorded in the undo cue)
    procedure LoadImageFromFile(const AFileName: string);
    procedure ClearImage;
    procedure CopyImageToClipboard;
    procedure PasteImageFromClipboard;
  end;

var
  // Display names indexed by the model value (VCL TPenStyle ordinals, the
  // LCL enumeration has other values)
  StringPenStyle: array[0..5] of WideString;
  StringBrushStyle: array[rpbsSolid..rpbsDense7] of WideString;
  StringShapeType: array[rpsRectangle..rpsOblique2] of WideString;

function StringPenStyleToInt(Value: WideString): Integer;
function StringBrushStyleToInt(Value: WideString): Integer;
function StringShapeTypeToShape(Value: WideString): TRpShapeType;
// LCL pen and brush styles of the model values
function RpPenStyleToPenStyle(Value: Integer): TPenStyle;
function RpBrushStyleToBrushStyle(Value: Integer): TBrushStyle;
// Open dialog filter for images
function ImageFileFilter: string;
// Loads an image file as the image stream of a report item: bitmaps, JPEG
// and PNG files are kept as they are, other formats are converted to JPEG
procedure LoadImageFileToStream(const AFileName: string; AStream: TMemoryStream);
// Decodes a report image stream (compressed or not) into ABitmap
function DecodeImageStream(AStream: TMemoryStream; ABitmap: TBitmap): Boolean;
// Draws abitmap in rec with an image draw style (design surface)
procedure DrawStyledBitmap(ACanvas: TCanvas; ABitmap: TBitmap; rec: TRect;
  AStyle: TRpImageDrawStyle; ADpiRes: Integer; AScale: Double);

implementation

function StringPenStyleToInt(Value: WideString): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := Low(StringPenStyle) to High(StringPenStyle) do
  begin
    if Value = StringPenStyle[i] then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function StringShapeTypeToShape(Value: WideString): TRpShapeType;
var
  i: TRpShapeType;
begin
  Result := rpsRectangle;
  for i := rpsRectangle to rpsOblique2 do
  begin
    if Value = StringShapeType[i] then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function StringBrushStyleToInt(Value: WideString): Integer;
var
  i: TRpBrushStyle;
begin
  Result := 0;
  for i := rpbsSolid to rpbsDense7 do
  begin
    if Value = StringBrushStyle[i] then
    begin
      Result := Integer(i);
      Break;
    end;
  end;
end;

function PenStyleText(Value: Integer): WideString;
begin
  if (Value >= Low(StringPenStyle)) and (Value <= High(StringPenStyle)) then
    Result := StringPenStyle[Value]
  else
    Result := '';
end;

function BrushStyleText(Value: Integer): WideString;
begin
  if (Value >= Ord(Low(TRpBrushStyle))) and (Value <= Ord(High(TRpBrushStyle))) then
    Result := StringBrushStyle[TRpBrushStyle(Value)]
  else
    Result := '';
end;

function RpPenStyleToPenStyle(Value: Integer): TPenStyle;
begin
  case Value of
    1: Result := psDash;
    2: Result := psDot;
    3: Result := psDashDot;
    4: Result := psDashDotDot;
    5: Result := psClear;
  else
    Result := psSolid;
  end;
end;

function RpBrushStyleToBrushStyle(Value: Integer): TBrushStyle;
begin
  // The dense styles have no LCL brush (as the LCL print driver)
  case TRpBrushStyle(Value) of
    rpbsSolid: Result := bsSolid;
    rpbsClear: Result := bsClear;
    rpbsHorizontal: Result := bsHorizontal;
    rpbsVertical: Result := bsVertical;
    rpbsFDiagonal: Result := bsFDiagonal;
    rpbsBDiagonal: Result := bsBDiagonal;
    rpbsCross: Result := bsCross;
  else
    Result := bsDiagCross;
  end;
end;

function ImageFileFilter: string;
begin
  Result := SRpBitmapImages + '|*.bmp|' +
    SRpSJpegImages + '|*.jpg;*.jpeg|' +
    SRpSPNGImages + '|*.png|' +
    GraphicFilter(TGraphic);
end;

function StreamKind(AStream: TStream): string;
var
  buf: array[0..3] of Byte;
  n: Integer;
begin
  Result := '';
  AStream.Position := 0;
  n := AStream.Read(buf[0], 4);
  AStream.Position := 0;
  if n < 2 then
    Exit;
  if (buf[0] = $42) and (buf[1] = $4D) then
    Result := 'BMP'
  else if (buf[0] = $FF) and (buf[1] = $D8) then
    Result := 'JPEG'
  else if (n = 4) and (buf[0] = $89) and (buf[1] = $50) and (buf[2] = $4E) and (buf[3] = $47) then
    Result := 'PNG';
end;

procedure LoadImageFileToStream(const AFileName: string; AStream: TMemoryStream);
var
  pic: TPicture;
  jpeg: TJPEGImage;
  bmp: TBitmap;
begin
  AStream.Clear;
  AStream.LoadFromFile(AFileName);
  if StreamKind(AStream) <> '' then
  begin
    AStream.Position := 0;
    Exit;
  end;
  // Any other registered format is stored as a JPEG (as the VCL designer)
  pic := TPicture.Create;
  try
    pic.LoadFromFile(AFileName);
    bmp := TBitmap.Create;
    try
      bmp.SetSize(pic.Width, pic.Height);
      bmp.Canvas.Brush.Color := clWhite;
      bmp.Canvas.FillRect(0, 0, bmp.Width, bmp.Height);
      bmp.Canvas.Draw(0, 0, pic.Graphic);
      jpeg := TJPEGImage.Create;
      try
        jpeg.CompressionQuality := 100;
        jpeg.Assign(bmp);
        AStream.Clear;
        jpeg.SaveToStream(AStream);
      finally
        jpeg.Free;
      end;
    finally
      bmp.Free;
    end;
  finally
    pic.Free;
  end;
  AStream.Position := 0;
end;

function DecodeImageStream(AStream: TMemoryStream; ABitmap: TBitmap): Boolean;
var
  source: TMemoryStream;
  decomp: TMemoryStream;
  jpeg: TJPEGImage;
  png: TPortableNetworkGraphic;
  pic: TPicture;
  kind: string;
begin
  Result := False;
  if not Assigned(AStream) or (AStream.Size = 0) then
    Exit;
  decomp := nil;
  try
    source := AStream;
    if IsCompressed(AStream) then
    begin
      decomp := TMemoryStream.Create;
      DecompressStream(AStream, decomp);
      source := decomp;
    end;
    source.Position := 0;
    kind := StreamKind(source);
    if kind = 'JPEG' then
    begin
      jpeg := TJPEGImage.Create;
      try
        jpeg.LoadFromStream(source);
        ABitmap.Assign(jpeg);
      finally
        jpeg.Free;
      end;
    end
    else if kind = 'PNG' then
    begin
      png := TPortableNetworkGraphic.Create;
      try
        png.LoadFromStream(source);
        ABitmap.Assign(png);
      finally
        png.Free;
      end;
    end
    else if kind = 'BMP' then
      ABitmap.LoadFromStream(source)
    else
    begin
      // All other formats
      pic := TPicture.Create;
      try
        pic.LoadFromStream(source);
        ABitmap.SetSize(pic.Width, pic.Height);
        ABitmap.Canvas.Draw(0, 0, pic.Graphic);
      finally
        pic.Free;
      end;
    end;
    Result := (ABitmap.Width > 0) and (ABitmap.Height > 0);
  finally
    decomp.Free;
    AStream.Position := 0;
  end;
end;

procedure DrawStyledBitmap(ACanvas: TCanvas; ABitmap: TBitmap; rec: TRect;
  AStyle: TRpImageDrawStyle; ADpiRes: Integer; AScale: Double);
var
  recsrc: TRect;
  propx, propy: Double;
  H, W, dpi, tilew, tileh, x, y: Integer;
  tiles: TBitmap;
begin
  if (ABitmap.Width <= 0) or (ABitmap.Height <= 0) then
    Exit;
  if ADpiRes <= 0 then
    ADpiRes := DEFAULT_DPI;
  dpi := Round(Screen.PixelsPerInch * AScale);
  case AStyle of
    rpDrawStretch:
      ACanvas.StretchDraw(rec, ABitmap);
    rpDrawCrop:
      begin
        // Keeps the proportions, centered (as the VCL designer)
        recsrc := Rect(0, 0, ABitmap.Width, ABitmap.Height);
        propx := (rec.Right - rec.Left) / ABitmap.Width;
        propy := (rec.Bottom - rec.Top) / ABitmap.Height;
        if propy > propx then
        begin
          H := Round((rec.Bottom - rec.Top) * propx / propy);
          rec.Top := rec.Top + ((rec.Bottom - rec.Top) - H) div 2;
          rec.Bottom := rec.Top + H;
        end
        else
        begin
          W := Round((rec.Right - rec.Left) * propy / propx);
          rec.Left := rec.Left + ((rec.Right - rec.Left) - W) div 2;
          rec.Right := rec.Left + W;
        end;
        DrawBitmap(ACanvas, ABitmap, rec, recsrc);
      end;
    rpDrawFull:
      begin
        rec.Bottom := rec.Top + Round(ABitmap.Height / ADpiRes * dpi);
        rec.Right := rec.Left + Round(ABitmap.Width / ADpiRes * dpi);
        ACanvas.StretchDraw(rec, ABitmap);
      end;
    rpDrawTile, rpDrawTiledpi:
      begin
        if AStyle = rpDrawTile then
        begin
          tilew := ABitmap.Width;
          tileh := ABitmap.Height;
        end
        else
        begin
          tilew := Round(ABitmap.Width / ADpiRes * dpi);
          tileh := Round(ABitmap.Height / ADpiRes * dpi);
        end;
        if (tilew <= 0) or (tileh <= 0) or (rec.Right <= rec.Left) or (rec.Bottom <= rec.Top) then
          Exit;
        // Tiles drawn in a bitmap of the rectangle size: clipped to it
        tiles := TBitmap.Create;
        try
          tiles.SetSize(rec.Right - rec.Left, rec.Bottom - rec.Top);
          y := 0;
          while y < tiles.Height do
          begin
            x := 0;
            while x < tiles.Width do
            begin
              tiles.Canvas.StretchDraw(Rect(x, y, x + tilew, y + tileh), ABitmap);
              Inc(x, tilew);
            end;
            Inc(y, tileh);
          end;
          ACanvas.Draw(rec.Left, rec.Top, tiles);
        finally
          tiles.Free;
        end;
      end;
  end;
end;

{ TRpDrawInterface }

constructor TRpDrawInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if Assigned(pritem) and not (pritem is TRpShape) then
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

  procedure AddProp(const AName, AType: WideString);
  begin
    lnames.Add(AName);
    ltypes.Add(AType);
    lhints.Add('refdraw.html');
    lcat.Add(SRpShape);
    if Assigned(lvalues) and Assigned(ashape) then
      lvalues.Add(GetProperty(AName));
  end;

begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  ashape := TRpShape(printitem);
  AddProp(SrpSShape, SRpSList);
  AddProp(SrpSPenStyle, SRpSList);
  AddProp(SrpSPenColor, SRpSColor);
  AddProp(SrpSPenWidth, SRpSString);
  AddProp(SrpSBrushStyle, SRpSList);
  AddProp(SrpSBrushColor, SRpSColor);
end;

procedure TRpDrawInterface.SetProperty(pname: WideString; value: WideString);
var
  ashape: TRpShape;
begin
  ashape := TRpShape(printitem);
  if not Assigned(ashape) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;
  if pname = SrpSShape then
  begin
    ashape.Shape := StringShapeTypeToShape(value);
    Invalidate;
    Exit;
  end;
  if pname = SrpSPenStyle then
  begin
    ashape.PenStyle := StringPenStyleToInt(value);
    Invalidate;
    Exit;
  end;
  if pname = SrpSPenColor then
  begin
    ashape.PenColor := StrToIntDef(value, ashape.PenColor);
    Invalidate;
    Exit;
  end;
  if pname = SrpSPenWidth then
  begin
    ashape.PenWidth := gettwipsfromtext(value);
    Invalidate;
    Exit;
  end;
  if pname = SrpSBrushStyle then
  begin
    ashape.BrushStyle := StringBrushStyleToInt(value);
    Invalidate;
    Exit;
  end;
  if pname = SrpSBrushColor then
  begin
    ashape.BrushColor := StrToIntDef(value, ashape.BrushColor);
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpDrawInterface.GetProperty(pname: WideString): WideString;
var
  ashape: TRpShape;
begin
  ashape := TRpShape(printitem);
  if not Assigned(ashape) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;
  if pname = SrpSShape then Result := StringShapeType[ashape.Shape]
  else if pname = SrpSPenStyle then Result := PenStyleText(ashape.PenStyle)
  else if pname = SrpSPenColor then Result := IntToStr(ashape.PenColor)
  else if pname = SrpSPenWidth then Result := gettextfromtwips(ashape.PenWidth)
  else if pname = SrpSBrushStyle then Result := BrushStyleText(ashape.BrushStyle)
  else if pname = SrpSBrushColor then Result := IntToStr(ashape.BrushColor)
  else Result := inherited GetProperty(pname);
end;

procedure TRpDrawInterface.GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings);
var
  pi: Integer;
  bi: TRpBrushStyle;
  shi: TRpShapeType;
begin
  if pname = SrpSShape then
  begin
    lpossiblevalues.Clear;
    for shi := rpsRectangle to rpsOblique2 do
      lpossiblevalues.Add(StringShapeType[shi]);
    Exit;
  end;
  if pname = SrpSPenStyle then
  begin
    lpossiblevalues.Clear;
    for pi := Low(StringPenStyle) to High(StringPenStyle) do
      lpossiblevalues.Add(StringPenStyle[pi]);
    Exit;
  end;
  if pname = SrpSBrushStyle then
  begin
    lpossiblevalues.Clear;
    for bi := rpbsSolid to rpbsDense7 do
      lpossiblevalues.Add(StringBrushStyle[bi]);
    Exit;
  end;
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
  Canvas.Pen.Color := clBlack;
  Canvas.Rectangle(0, 0, Width, Height);

  ashape := TRpShape(printitem);
  if not Assigned(ashape) or (csDestroying in ashape.ComponentState) then
    Exit;

  Canvas.Brush.Color := ashape.BrushColor;
  Canvas.Brush.Style := RpBrushStyleToBrushStyle(ashape.BrushStyle);
  Canvas.Pen.Style := RpPenStyleToPenStyle(ashape.PenStyle);
  Canvas.Pen.Color := ashape.PenColor;
  Canvas.Pen.Width := Round(Screen.PixelsPerInch * ashape.PenWidth / TWIPS_PER_INCHESS);

  // Same geometry as the VCL designer
  X := Canvas.Pen.Width div 2;
  Y := X;
  W := Width - Canvas.Pen.Width + 1;
  H := Height - Canvas.Pen.Width + 1;
  if Canvas.Pen.Width = 0 then
  begin
    Dec(W);
    Dec(H);
  end;
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
      Canvas.MoveTo(0, 0);
      Canvas.LineTo(X + W, 0);
    end;
    rpsVertLine:
    begin
      Canvas.MoveTo(0, 0);
      Canvas.LineTo(0, Y + H);
    end;
    rpsOblique1:
    begin
      Canvas.MoveTo(0, 0);
      Canvas.LineTo(X + W, Y + H);
    end;
    rpsOblique2:
    begin
      Canvas.MoveTo(0, Y + H);
      Canvas.LineTo(X + W, 0);
    end;
  end;

  DrawSelected;
end;

{ TRpImageInterface }

constructor TRpImageInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if Assigned(pritem) and not (pritem is TRpImage) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
  FBitmapSource := TMemoryStream.Create;
end;

destructor TRpImageInterface.Destroy;
begin
  FreeAndNil(FBitmap);
  FreeAndNil(FBitmapSource);
  inherited Destroy;
end;

class procedure TRpImageInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpImageInterface');
end;

function ImageSizeText(aimage: TRpImage): WideString;
begin
  Result := '[' + FormatFloat('###,###0.00', aimage.Stream.Size / 1024) + SRpKbytes + ']';
end;

procedure TRpImageInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  aimage: TRpImage;

  procedure AddProp(const AName, AType: WideString);
  begin
    lnames.Add(AName);
    ltypes.Add(AType);
    lhints.Add('refimage.html');
    lcat.Add(SRpImage);
    if Assigned(lvalues) and Assigned(aimage) then
      lvalues.Add(GetProperty(AName));
  end;

begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  aimage := TRpImage(printitem);
  // Same order and types as the VCL designer
  AddProp(SRpDrawStyle, SRpSList);
  AddProp(SrpSExpression, SRpSExpression);
  AddProp(SrpSImage, SRpSImage);
  AddProp(SRpDPIRes, SRpSString);
  AddProp(SRpCached, SRpSList);
end;

procedure TRpImageInterface.SetProperty(pname: WideString; value: WideString);
var
  aimage: TRpImage;
begin
  aimage := TRpImage(printitem);
  if not Assigned(aimage) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;
  if pname = SrpSExpression then
  begin
    aimage.Expression := value;
    // An image expression replaces the stored image
    if Length(Trim(value)) > 0 then
      aimage.Stream.SetSize(0);
    Invalidate;
    Exit;
  end;
  if pname = SRpDrawStyle then
  begin
    aimage.DrawStyle := StringDrawStyleToDrawStyle(value);
    Invalidate;
    Exit;
  end;
  if pname = SRpDPIRes then
  begin
    aimage.DPIRes := StrToIntDef(value, aimage.DPIRes);
    if aimage.DPIRes <= 0 then
      aimage.DPIRes := DEFAULT_DPI;
    Invalidate;
    Exit;
  end;
  if pname = SRpCached then
  begin
    aimage.CachedImage := StringCachedImageToCachedImage(value);
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpImageInterface.GetProperty(pname: WideString): WideString;
var
  aimage: TRpImage;
begin
  aimage := TRpImage(printitem);
  if not Assigned(aimage) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;
  if pname = SrpSExpression then Result := aimage.Expression
  else if pname = SRpDrawStyle then Result := RpDrawStyleToString(aimage.DrawStyle)
  else if pname = SRpDPIRes then Result := IntToStr(aimage.DPIRes)
  else if pname = SrpSImage then Result := ImageSizeText(aimage)
  else if pname = SRpCached then Result := RpCachedImageToString(aimage.CachedImage)
  else Result := inherited GetProperty(pname);
end;

procedure TRpImageInterface.SetProperty(pname: WideString; stream: TMemoryStream);
var
  aimage: TRpImage;
begin
  aimage := TRpImage(printitem);
  if Assigned(aimage) and (pname = SrpSImage) then
  begin
    aimage.Stream := stream;
    if aimage.Stream.Size > 0 then
      aimage.Expression := '';
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, stream);
end;

procedure TRpImageInterface.GetProperty(pname: WideString; var Stream: TMemoryStream);
begin
  if Assigned(printitem) and (pname = SrpSImage) then
  begin
    Stream := TRpImage(printitem).Stream;
    Exit;
  end;
  inherited GetProperty(pname, Stream);
end;

procedure TRpImageInterface.GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings);
begin
  if pname = SRpDrawStyle then
  begin
    lpossiblevalues.Clear;
    GetDrawStyleDescriptions(lpossiblevalues);
    Exit;
  end;
  if pname = SRpCached then
  begin
    lpossiblevalues.Clear;
    GetCachedImageDescriptions(lpossiblevalues);
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

function TRpImageInterface.DesignBitmap: TBitmap;
var
  aimage: TRpImage;
begin
  Result := nil;
  aimage := TRpImage(printitem);
  if not Assigned(aimage) or (aimage.Stream.Size = 0) then
    Exit;
  // Decoded again only when the model stream changed (inspector, context
  // menu, undo/redo...)
  if (FBitmapSource.Size <> aimage.Stream.Size) or
     not CompareMem(FBitmapSource.Memory, aimage.Stream.Memory, aimage.Stream.Size) then
  begin
    FreeAndNil(FBitmap);
    FBitmapError := False;
    FBitmapSource.Clear;
    FBitmapSource.CopyFrom(aimage.Stream, 0);
    aimage.Stream.Position := 0;
    FBitmap := TBitmap.Create;
    try
      FBitmapError := not DecodeImageStream(aimage.Stream, FBitmap);
    except
      FBitmapError := True;
    end;
    if FBitmapError then
      FreeAndNil(FBitmap);
  end;
  Result := FBitmap;
end;

procedure TRpImageInterface.DrawImageTo(ACanvas: TCanvas; AWidth, AHeight: Integer);
var
  aimage: TRpImage;
  bmp: TBitmap;
begin
  aimage := TRpImage(printitem);
  if not Assigned(aimage) or (csDestroying in aimage.ComponentState) then
    Exit;
  ACanvas.Pen.Color := clBlack;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Width := 1;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(0, 0, AWidth, AHeight);
  bmp := DesignBitmap;
  if Assigned(bmp) then
    DrawStyledBitmap(ACanvas, bmp, Rect(0, 0, AWidth - 1, AHeight - 1),
      aimage.DrawStyle, aimage.DPIRes, Scale);
  // Draws the expression
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(0, 0, AWidth, AHeight);
  if FBitmapError and (aimage.Stream.Size > 0) then
    ACanvas.TextOut(0, 0, SRpInvalidImageFormat)
  else
    ACanvas.TextOut(0, 0, SrpSImage + aimage.Expression);
end;

procedure TRpImageInterface.Paint;
begin
  DrawImageTo(Canvas, Width, Height);
  DrawSelected;
end;

procedure TRpImageInterface.InitPopUpMenu;
begin
  inherited InitPopUpMenu;
  // Image clipboard and file actions of the VCL designer, in a submenu: the
  // designer commands below also have Cut, Copy and Paste (components)
  mimage := TMenuItem.Create(FContextMenu);
  mimage.Caption := SrpSImage;
  FContextMenu.Items.Add(mimage);

  // Cut Image
  mcut := TMenuItem.Create(FContextMenu);
  mcut.Caption := TranslateStr(9, 'Cut');
  mcut.Hint := TranslateStr(12, 'Cut selected object');
  mcut.OnClick := CutImageClick;
  mimage.Add(mcut);

  // Copy Image
  mcopy := TMenuItem.Create(FContextMenu);
  mcopy.Caption := TranslateStr(10, 'Copy');
  mcopy.Hint := TranslateStr(13, 'Copy selected object to clipboard');
  mcopy.OnClick := CopyImageClick;
  mimage.Add(mcopy);

  // Paste Image
  mpaste := TMenuItem.Create(FContextMenu);
  mpaste.Caption := TranslateStr(11, 'Paste');
  mpaste.Hint := TranslateStr(14, 'Paste from clipboard');
  mpaste.OnClick := PasteImageClick;
  mimage.Add(mpaste);

  // Open Image
  mopen := TMenuItem.Create(FContextMenu);
  mopen.Caption := TranslateStr(42, 'Open');
  mopen.OnClick := LoadImageClick;
  mimage.Add(mopen);
end;

procedure TRpImageInterface.PopUpContextMenu;
var
  hasimage: Boolean;
begin
  inherited PopUpContextMenu;
  hasimage := Assigned(printitem) and (TRpImage(printitem).Stream.Size > 0);
  mcut.Enabled := hasimage;
  mcopy.Enabled := hasimage;
  mpaste.Enabled := Clipboard.HasPictureFormat;
end;

procedure TRpImageInterface.ClearImage;
var
  empty: TMemoryStream;
begin
  if not Assigned(printitem) then
    Exit;
  empty := TMemoryStream.Create;
  try
    SetPropertyUndo(SrpSImage, empty);
  finally
    empty.Free;
  end;
end;

procedure TRpImageInterface.LoadImageFromFile(const AFileName: string);
var
  astream: TMemoryStream;
begin
  if not Assigned(printitem) then
    Exit;
  astream := TMemoryStream.Create;
  try
    LoadImageFileToStream(AFileName, astream);
    SetPropertyUndo(SrpSImage, astream);
  finally
    astream.Free;
  end;
end;

procedure TRpImageInterface.CopyImageToClipboard;
var
  bmp: TBitmap;
begin
  bmp := DesignBitmap;
  if Assigned(bmp) then
    Clipboard.Assign(bmp);
end;

procedure TRpImageInterface.PasteImageFromClipboard;
var
  pic: TPicture;
  bmp: TBitmap;
  astream: TMemoryStream;
begin
  if not Assigned(printitem) or not Clipboard.HasPictureFormat then
    Exit;
  pic := TPicture.Create;
  bmp := TBitmap.Create;
  astream := TMemoryStream.Create;
  try
    pic.Assign(Clipboard);
    bmp.SetSize(pic.Width, pic.Height);
    bmp.Canvas.Draw(0, 0, pic.Graphic);
    bmp.SaveToStream(astream);
    astream.Position := 0;
    // Sets the stream and clears the expression
    SetPropertyUndo(SrpSImage, astream);
  finally
    astream.Free;
    bmp.Free;
    pic.Free;
  end;
end;

procedure TRpImageInterface.CutImageClick(Sender: TObject);
begin
  CopyImageToClipboard;
  ClearImage;
end;

procedure TRpImageInterface.CopyImageClick(Sender: TObject);
begin
  CopyImageToClipboard;
end;

procedure TRpImageInterface.PasteImageClick(Sender: TObject);
begin
  PasteImageFromClipboard;
end;

procedure TRpImageInterface.LoadImageClick(Sender: TObject);
var
  dia: TOpenDialog;
begin
  dia := TOpenDialog.Create(Application);
  try
    dia.Filter := ImageFileFilter;
    if dia.Execute then
      LoadImageFromFile(dia.FileName);
  finally
    dia.Free;
  end;
end;

initialization
  StringPenStyle[0] := SRpSPSolid;
  StringPenStyle[1] := SRpSPDash;
  StringPenStyle[2] := SRpSPDot;
  StringPenStyle[3] := SRpSPDashDot;
  StringPenStyle[4] := SRpSPDashDotDot;
  StringPenStyle[5] := SRpSPClear;

  StringBrushStyle[rpbsSolid] := SRpSBSolid;
  StringBrushStyle[rpbsClear] := SRpSBClear;
  StringBrushStyle[rpbsHorizontal] := SRpSBHorizontal;
  StringBrushStyle[rpbsVertical] := SRpSBVertical;
  StringBrushStyle[rpbsFDiagonal] := SRpSBFDiagonal;
  StringBrushStyle[rpbsBDiagonal] := SRpSBBDiagonal;
  StringBrushStyle[rpbsCross] := SRpSBCross;
  StringBrushStyle[rpbsDiagCross] := SRpSBDiagCross;
  StringBrushStyle[rpbsDense1] := SRpSBDense1;
  StringBrushStyle[rpbsDense2] := SRpSBDense2;
  StringBrushStyle[rpbsDense3] := SRpSBDense3;
  StringBrushStyle[rpbsDense4] := SRpSBDense4;
  StringBrushStyle[rpbsDense5] := SRpSBDense5;
  StringBrushStyle[rpbsDense6] := SRpSBDense6;
  StringBrushStyle[rpbsDense7] := SRpSBDense7;

  StringShapeType[rpsRectangle] := SRpsSRectangle;
  StringShapeType[rpsSquare] := SRpsSSquare;
  StringShapeType[rpsRoundRect] := SRpsSRoundRect;
  StringShapeType[rpsRoundSquare] := SRpsSRoundSquare;
  StringShapeType[rpsEllipse] := SRpsSEllipse;
  StringShapeType[rpsCircle] := SRpsSCircle;
  StringShapeType[rpsHorzLine] := SRpSHorzLine;
  StringShapeType[rpsVertLine] := SRpSVertLine;
  StringShapeType[rpsOblique1] := SRpSOblique1;
  StringShapeType[rpsOblique2] := SRpSOblique2;
end.

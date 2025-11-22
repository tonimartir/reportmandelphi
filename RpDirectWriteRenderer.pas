unit RpDirectWriteRenderer;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  Winapi.D2D1, VCL.Direct2D,
  Winapi.Windows,
  rptypes;

// --- Tipos de Puntero ---
type
  TDwriteGlyphRun = DWRITE_GLYPH_RUN;
  TDwriteGlyphRunDescription = DWRITE_GLYPH_RUN_DESCRIPTION;
  TDwriteUnderline = DWRITE_UNDERLINE;
  TDwriteStrikethrough = DWRITE_STRIKETHROUGH;
  TDwriteMatrix = DWRITE_MATRIX;
  PDWRITE_GLYPH_OFFSET = ^DWRITE_GLYPH_OFFSET;

  TGlyphIndexArray = array[0..9999999] of Word;
  TSingleAdvanceArray = array[0..999999] of Single;
  TClusterMapArray = array[0..999999] of Word;
  TGlyphOffsetArray = array[0..999999] of DWRITE_GLYPH_OFFSET;

  PGlyphIndexArray = ^TGlyphIndexArray;
  PSingleAdvanceArray = ^TSingleAdvanceArray;
  PGlyphOffsetArray = ^TGlyphOffsetArray;
  PClusterMapArray = ^TClusterMapArray;

  // --- Estructura para línea de glifos ---
  TGlyphLine = class
  public
    BaselineY: Single;
    Glyphs: TList<TGlyphPos>;
    IsRTL: Boolean;
    constructor Create(aBaselineY: Single; aIsRTL: Boolean);
    destructor Destroy; override;
  end;

  // --- TTextExtentRenderer ---
  TTextExtentRenderer = class(TInterfacedObject, IDWriteTextRenderer)
  private
    FGlyphPositions: TList<TGlyphPos>;
    FTextLayout: IDWriteTextLayout;
    FOriginalText:PWideChar;
    FLines: TList<TGlyphLine>;
    function GetLineByBaseline(baselineY: Single; firstRunIsRTL: Boolean): TGlyphLine;
  public
    FontFace: IDWriteFontFace;
    constructor Create(const TextLayout: IDWriteTextLayout;OriginalText:PWideChar);
    destructor Destroy; override;

    property GlyphPositions: TList<TGlyphPos> read FGlyphPositions;
    property Lines: TList<TGlyphLine> read FLines;

    // IDWritePixelSnapping
    function IsPixelSnappingDisabled(clientDrawingContext: Pointer; var isDisabled: BOOL): HResult; stdcall;
    function GetCurrentTransform(clientDrawingContext: Pointer; var transform: TDwriteMatrix): HResult; stdcall;
    function GetPixelsPerDip(clientDrawingContext: Pointer; var pixelsPerDip: Single): HResult; stdcall;

    // IDWriteTextRenderer
    function DrawGlyphRun(
      clientDrawingContext: Pointer;
      baselineOriginX: Single;
      baselineOriginY: Single;
      measuringMode: TDWriteMeasuringMode;
      var glyphRun: TDwriteGlyphRun;
      var glyphRunDescription: TDwriteGlyphRunDescription;
      const clientDrawingEffect: IUnknown): HResult; stdcall;

    function DrawUnderline(clientDrawingContext: Pointer; baselineOriginX: Single;
      baselineOriginY: Single; var underline: TDwriteUnderline;
      const clientDrawingEffect: IUnknown): HResult; stdcall;

    function DrawStrikethrough(clientDrawingContext: Pointer;
      baselineOriginX: Single; baselineOriginY: Single;
      var strikethrough: TDwriteStrikethrough;
      const clientDrawingEffect: IUnknown): HResult; stdcall;

    function DrawInlineObject(clientDrawingContext: Pointer; originX: Single;
      originY: Single; var inlineObject: IDWriteInlineObject; isSideways: BOOL;
      isRightToLeft: BOOL; const clientDrawingEffect: IUnknown): HResult; stdcall;
  end;

implementation

const
  DIP_TO_TWIPS_FACTOR = 15.0;

{ TGlyphLine }

constructor TGlyphLine.Create(aBaselineY: Single; aIsRTL: Boolean);
begin
  inherited Create;
  BaselineY := aBaselineY;
  IsRTL := aIsRTL;
  Glyphs := TList<TGlyphPos>.Create;
end;

destructor TGlyphLine.Destroy;
begin
  Glyphs.Free;
  inherited;
end;

{ TTextExtentRenderer }

constructor TTextExtentRenderer.Create(const TextLayout: IDWriteTextLayout;OriginalText:PWideChar);
begin
  inherited Create;
  FTextLayout := TextLayout;
  FOriginalText:=OriginalText;
  FGlyphPositions := TList<TGlyphPos>.Create;
  FLines := TList<TGlyphLine>.Create;
end;

destructor TTextExtentRenderer.Destroy;
var
  L: TGlyphLine;
begin
  FGlyphPositions.Free;
  for L in FLines do
    L.Free;
  FLines.Free;
  inherited;
end;

function TTextExtentRenderer.GetLineByBaseline(baselineY: Single; firstRunIsRTL: Boolean): TGlyphLine;
var
  L: TGlyphLine;
begin
  for L in FLines do
    if Abs(L.BaselineY - baselineY) < 0.01 then
      Exit(L);
  Result := TGlyphLine.Create(baselineY, firstRunIsRTL);
  FLines.Add(Result);
end;

function TTextExtentRenderer.DrawGlyphRun(
  clientDrawingContext: Pointer;
  baselineOriginX, baselineOriginY: Single;
  measuringMode: TDWriteMeasuringMode;
  var glyphRun: TDwriteGlyphRun;
  var glyphRunDescription: TDwriteGlyphRunDescription;
  const clientDrawingEffect: IUnknown): HResult;
var
  i: Integer;
  GlyphPos: TGlyphPos;
  TextPosition: Cardinal;
  IdxArray: PGlyphIndexArray;
  AdvArray: PSingleAdvanceArray;
  OffArray: PGlyphOffsetArray;
  ClusterMapArray: PClusterMapArray;
  Line: TGlyphLine;
  GlyphList: TList<TGlyphPos>;
  runIsRTL: Boolean;
  // trimming
  LastIndex: Integer;
  ch: WideChar;
  isWS: Boolean;
  keepNBSP: Boolean;
begin
  Result := S_OK;
  TextPosition := glyphRunDescription.textPosition;
  runIsRTL := (glyphRun.bidiLevel mod 2) = 1;

  IdxArray := PGlyphIndexArray(glyphRun.glyphIndices);
  AdvArray := PSingleAdvanceArray(glyphRun.glyphAdvances);
  if Assigned(glyphRun.glyphOffsets) then
    OffArray := PGlyphOffsetArray(glyphRun.glyphOffsets)
  else
    OffArray := nil;
  ClusterMapArray := PClusterMapArray(glyphRunDescription.clusterMap);

  Line := GetLineByBaseline(baselineOriginY, runIsRTL);
  GlyphList := TList<TGlyphPos>.Create;
  try
    for i := 0 to Integer(glyphRun.glyphCount) - 1 do
    begin
      FillChar(GlyphPos, SizeOf(TGlyphPos), 0);
      GlyphPos.GlyphIndex := IdxArray[i];
      GlyphPos.XAdvance := Round(AdvArray[i] * DIP_TO_TWIPS_FACTOR);
      GlyphPos.YAdvance := 0;
      if Assigned(OffArray) then
      begin
        var Offset := OffArray[i];
        GlyphPos.XOffset := -Round(Offset.advanceOffset * DIP_TO_TWIPS_FACTOR);
        GlyphPos.YOffset := Round(Offset.ascenderOffset * DIP_TO_TWIPS_FACTOR);
      end
      else
      begin
        GlyphPos.XOffset := 0;
        GlyphPos.YOffset := 0;
      end;
      GlyphPos.Cluster := ClusterMapArray[i];
      GlyphPos.LineCluster := TextPosition + GlyphPos.Cluster;
      GlyphPos.CharCode:=FOriginalText[GlyphPos.LineCluster];

      GlyphList.Add(GlyphPos);
      FGlyphPositions.Add(GlyphPos);
    end;

        // 2) Recortar whitespace final en el orden lógico (preservamos NBSP por defecto)
    keepNBSP := True; // cambia a False si prefieres eliminar NBSP también
    LastIndex := GlyphList.Count - 1;
    while LastIndex >= 0 do
    begin
      ch := GlyphList[LastIndex].CharCode;
      // comprobar whitespace básico (espacio, tab, CR, LF). Añade más códigos si quieres.
      isWS := (ch = WideChar(' ')) or (ch = WideChar(#9)) or (ch = WideChar(#10)) or (ch = WideChar(#13));

      // tratar NBSP (U+00A0)
      if ch = WideChar(#160) then
      begin
        if keepNBSP then
          isWS := False  // conservar NBSP
        else
          isWS := True;  // tratar NBSP como whitespace si keepNBSP = False
      end;

      if not isWS then
        Break;

      // eliminar último glifo lógico (trailing whitespace)
      GlyphList.Delete(LastIndex);
      Dec(LastIndex);
    end;

    // Invertir run si es RTL
    if runIsRTL then
      GlyphList.Reverse;

    // Insertar según dirección dominante de la línea
    if Line.IsRTL then
      Line.Glyphs.InsertRange(0, GlyphList.ToArray)
    else
      Line.Glyphs.AddRange(GlyphList.ToArray);

  finally
    GlyphList.Free;
  end;
end;

function TTextExtentRenderer.DrawUnderline(clientDrawingContext: Pointer;
  baselineOriginX, baselineOriginY: Single; var underline: TDwriteUnderline;
  const clientDrawingEffect: IUnknown): HResult;
begin
  Result := S_OK;
end;

function TTextExtentRenderer.DrawStrikethrough(clientDrawingContext: Pointer;
  baselineOriginX, baselineOriginY: Single; var strikethrough: TDwriteStrikethrough;
  const clientDrawingEffect: IUnknown): HResult;
begin
  Result := S_OK;
end;

function TTextExtentRenderer.DrawInlineObject(clientDrawingContext: Pointer;
  originX, originY: Single; var inlineObject: IDWriteInlineObject; isSideways, isRightToLeft: BOOL;
  const clientDrawingEffect: IUnknown): HResult;
begin
  Result := S_OK;
end;

function TTextExtentRenderer.IsPixelSnappingDisabled(clientDrawingContext: Pointer; var isDisabled: BOOL): HResult;
begin
  isDisabled := False;
  Result := S_OK;
end;

function TTextExtentRenderer.GetCurrentTransform(clientDrawingContext: Pointer; var transform: TDwriteMatrix): HResult;
begin
  FillChar(transform, SizeOf(TDwriteMatrix), 0);
  transform.m11 := 1.0;
  transform.m22 := 1.0;
  Result := S_OK;
end;

function TTextExtentRenderer.GetPixelsPerDip(clientDrawingContext: Pointer; var pixelsPerDip: Single): HResult;
begin
  pixelsPerDip := 1.0;
  Result := S_OK;
end;

end.


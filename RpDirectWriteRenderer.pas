unit RpDirectWriteRenderer;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  Winapi.D2D1, VCL.Direct2D,
  Winapi.Windows,
  rptypes;

// --- Tipos de Puntero (tal como los tenías) ---
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

  // --- Nueva estructura para línea de glifos ---
  TGlyphLine = class
  public
    BaselineY: Single;
    Glyphs: TList<TGlyphPos>;
    constructor Create(aBaselineY: Single);
    destructor Destroy; override;
  end;

// --- TTextExtentRenderer ---
type
  TTextExtentRenderer = class(TInterfacedObject, IDWriteTextRenderer)
  private
    FGlyphPositions: TList<TGlyphPos>;
    FTextLayout: IDWriteTextLayout;
    FLines: TList<TGlyphLine>;
    function GetLineByBaseline(baselineY: Single): TGlyphLine;
  public
    FontFace: IDWriteFontFace;
    constructor Create(const TextLayout: IDWriteTextLayout);
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

{ TGlyphLine }

constructor TGlyphLine.Create(aBaselineY: Single);
begin
  inherited Create;
  BaselineY := aBaselineY;
  Glyphs := TList<TGlyphPos>.Create;
end;

destructor TGlyphLine.Destroy;
begin
  Glyphs.Free;
  inherited;
end;

{ TTextExtentRenderer }

constructor TTextExtentRenderer.Create(const TextLayout: IDWriteTextLayout);
begin
  inherited Create;
  FTextLayout := TextLayout;
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

function TTextExtentRenderer.GetLineByBaseline(baselineY: Single): TGlyphLine;
var
  L: TGlyphLine;
begin
  // Busca línea existente cercana a baselineY
  for L in FLines do
    if Abs(L.BaselineY - baselineY) < 0.01 then
      Exit(L);
  // Si no existe, crear nueva
  Result := TGlyphLine.Create(baselineY);
  FLines.Add(Result);
end;

const
  DIP_TO_TWIPS_FACTOR = 15.0;

function TTextExtentRenderer.DrawGlyphRun(
  clientDrawingContext: Pointer;
  baselineOriginX: Single;
  baselineOriginY: Single;
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
begin
  Result := S_OK;
  TextPosition := glyphRunDescription.textPosition;

  IdxArray := PGlyphIndexArray(glyphRun.glyphIndices);
  AdvArray := PSingleAdvanceArray(glyphRun.glyphAdvances);
  if Assigned(glyphRun.glyphOffsets) then
    OffArray := PGlyphOffsetArray(glyphRun.glyphOffsets)
  else
    OffArray := nil;
  ClusterMapArray := PClusterMapArray(glyphRunDescription.clusterMap);

  // Obtener la línea correspondiente
  Line := GetLineByBaseline(baselineOriginY);
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
        GlyphPos.XOffset := Round(Offset.advanceOffset * DIP_TO_TWIPS_FACTOR);
        GlyphPos.YOffset := Round(Offset.ascenderOffset * DIP_TO_TWIPS_FACTOR);
      end
      else
      begin
        GlyphPos.XOffset := 0;
        GlyphPos.YOffset := 0;
      end;
      GlyphPos.Cluster := ClusterMapArray[i];
      GlyphPos.LineCluster := TextPosition + GlyphPos.Cluster;
      GlyphList.Add(GlyphPos);
      FGlyphPositions.Add(GlyphPos);
    end;

    // Si es RTL, invertir el orden de glifos antes de agregarlos a la línea
    if (glyphRun.bidiLevel mod 2) = 1 then
      GlyphList.Reverse;

    // Agregar glifos a la línea
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


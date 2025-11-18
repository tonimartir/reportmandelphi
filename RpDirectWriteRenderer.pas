unit RpDirectWriteRenderer;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  Winapi.D2D1, VCL.Direct2D,
  Winapi.Windows, // Necesario para BOOL
  // Necesitas asegurar que rptypes contenga TGlyphPos, TDwriteGlyphRun, etc.
  rptypes;

// --- Tipos de Puntero (Se mantienen como referencia) ---
type
  // Definiciones que asumes están completas en rptypes
  TDwriteGlyphRun = DWRITE_GLYPH_RUN;
  TDwriteGlyphRunDescription = DWRITE_GLYPH_RUN_DESCRIPTION;
  TDwriteUnderline = DWRITE_UNDERLINE;
  TDwriteStrikethrough = DWRITE_STRIKETHROUGH;
  TDwriteMatrix = DWRITE_MATRIX; // Asumimos TDwriteMatrix = DWRITE_MATRIX
  PDWRITE_GLYPH_OFFSET = ^DWRITE_GLYPH_OFFSET;
// 1. Tipos de Array (La clave para la indexación P[i])
  TGlyphIndexArray = array[0..9999999] of Word;
  TSingleAdvanceArray = array[0..999999] of Single;
  TClusterMapArray = array[0..999999] of Word;
  TGlyphOffsetArray = array[0..999999] of DWRITE_GLYPH_OFFSET;

  // 2. Tipos de Puntero (Usamos los tipos de array definidos arriba)
  PGlyphIndexArray = ^TGlyphIndexArray;
  PSingleAdvanceArray = ^TSingleAdvanceArray;
  PGlyphOffsetArray = ^TGlyphOffsetArray;
  PClusterMapArray = ^TClusterMapArray;

// --- TTextExtentRenderer Class (Ajuste de Firmas) ---
type
  TTextExtentRenderer = class(TInterfacedObject, IDWriteTextRenderer)
  private
    FGlyphPositions: TList<TGlyphPos>;
    FTextLayout: IDWriteTextLayout;

  public
    public FontFace: IDWriteFontFace;
    constructor Create(const TextLayout: IDWriteTextLayout);
    destructor Destroy; override;

    property GlyphPositions: TList<TGlyphPos> read FGlyphPositions;

    // --- Métodos de IDWritePixelSnapping (HEREDADOS - USANDO VAR) ---
    function IsPixelSnappingDisabled(clientDrawingContext: Pointer; var isDisabled: BOOL): HResult; stdcall;
    function GetCurrentTransform(clientDrawingContext: Pointer; var transform: TDwriteMatrix): HResult; stdcall;
    function GetPixelsPerDip(clientDrawingContext: Pointer; var pixelsPerDip: Single): HResult; stdcall;

    // --- Métodos de IDWriteTextRenderer ---
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

{ TTextExtentRenderer }

constructor TTextExtentRenderer.Create(const TextLayout: IDWriteTextLayout);
begin
  inherited Create;
  FTextLayout := TextLayout;
  FGlyphPositions := TList<TGlyphPos>.Create;
end;

destructor TTextExtentRenderer.Destroy;
begin
  FGlyphPositions.Free;
  inherited;
end;
// Asumiendo que esta constante es accesible o la defines dentro del implementation
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

  for i := 0 to Integer(glyphRun.glyphCount) - 1 do
  begin
    FillChar(GlyphPos, SizeOf(TGlyphPos), 0);
    // ... (Lógica de validación de FontFace omitida por brevedad)

    // Mapeo de Índices...
    GlyphPos.GlyphIndex := IdxArray[i];

    // ************************************************
    //  CORRECCIÓN CLAVE: Conversión de DIPs a TWIPS
    // ************************************************
    // Avance X (Avances se dan en DIPs. Multiplicamos por 15.0 y luego redondeamos)
    GlyphPos.XAdvance := Round(AdvArray[i] * DIP_TO_TWIPS_FACTOR);
    GlyphPos.YAdvance := 0; 

    if Assigned(OffArray) then
    begin
        var GlyphOffset := OffArray[i];
        
        // Offset X y Y (Offsets también se dan en DIPs. Multiplicamos por 15.0)
        GlyphPos.XOffset := Round(GlyphOffset.advanceOffset * DIP_TO_TWIPS_FACTOR);
        GlyphPos.YOffset := Round(GlyphOffset.ascenderOffset * DIP_TO_TWIPS_FACTOR);
    end
    else
    begin
      GlyphPos.XOffset := 0;
      GlyphPos.YOffset := 0;
    end;
    
    // Mapeo de Clúster
    GlyphPos.Cluster := ClusterMapArray[i];
    GlyphPos.LineCluster := glyphRunDescription.textPosition + GlyphPos.Cluster;

    FGlyphPositions.Add(GlyphPos);
  end;
end;

function TTextExtentRenderer.DrawUnderline(clientDrawingContext: Pointer; baselineOriginX: Single;
  baselineOriginY: Single; var underline: TDwriteUnderline;
  const clientDrawingEffect: IUnknown): HResult;
begin
  Result := S_OK;
end;

function TTextExtentRenderer.DrawStrikethrough(clientDrawingContext: Pointer;
  baselineOriginX: Single; baselineOriginY: Single;
  var strikethrough: TDwriteStrikethrough;
  const clientDrawingEffect: IUnknown): HResult;
begin
  Result := S_OK;
end;

function TTextExtentRenderer.DrawInlineObject(clientDrawingContext: Pointer; originX: Single;
  originY: Single; var inlineObject: IDWriteInlineObject; isSideways: BOOL;
  isRightToLeft: BOOL; const clientDrawingEffect: IUnknown): HResult;
begin
  Result := S_OK;
end;

// --- Implementaciones de IDWritePixelSnapping (COMPLETAMENTE REVISADAS) ---

function TTextExtentRenderer.IsPixelSnappingDisabled(clientDrawingContext: Pointer; var isDisabled: BOOL): HResult;
begin
  // No queremos desactivar el pixel snapping, así que retornamos FALSE.
  isDisabled := False;
  Result := S_OK;
end;

function TTextExtentRenderer.GetCurrentTransform(clientDrawingContext: Pointer; var transform: TDwriteMatrix): HResult;
begin
  // Retornamos la matriz de identidad (sin transformación)
  FillChar(transform, SizeOf(TDwriteMatrix), 0);
  transform.m11 := 1.0;
  transform.m22 := 1.0;
  Result := S_OK;
end;

function TTextExtentRenderer.GetPixelsPerDip(clientDrawingContext: Pointer; var pixelsPerDip: Single): HResult;
begin
  // Asumimos 96 DPI (1 DIP = 1 píxel)
  pixelsPerDip := 1.0;
  Result := S_OK;
end;

end.

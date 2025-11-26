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

  TFontFaceCache = class(TDictionary<Pointer, WideString>);

  // --- TTextExtentRenderer ---
  TTextExtentRenderer = class(TInterfacedObject, IDWriteTextRenderer)
  private
    FGlyphPositions: TList<TGlyphPos>;
    FTextLayout: IDWriteTextLayout;
    FOriginalText:PWideChar;
    FLines: TList<TGlyphLine>;
    FFontFamilyCache: TFontFaceCache;
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
    function GetFontFamily(FontFace: IDWriteFontFace): WideString;


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
  FFontFamilyCache:=TFontFaceCache.Create;
end;

destructor TTextExtentRenderer.Destroy;
var
  L: TGlyphLine;
begin
  FGlyphPositions.Free;
  for L in FLines do
    L.Free;
  FLines.Free;
  FFontFamilyCache.Free;
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



function MakeOpenTypeTag(a, b, c, d: AnsiChar): Cardinal;
begin
  Result := (Cardinal(Byte(a)) shl 24) or
            (Cardinal(Byte(b)) shl 16) or
            (Cardinal(Byte(c)) shl 8)  or
            Cardinal(Byte(d));
end;

function GetFontFamilyFromFontFace(FontFace: IDWriteFontFace): WideString;
type
  // Definiciones de tipos para punteros (si no est�n globales)
  PTNameTableHeader = ^TNameTableHeader;
  PTNameRecord = ^TNameRecord;

  TNameTableHeader = packed record
    formatSelector: Word;
    count: Word;
    stringOffset: Word;
  end;

  TNameRecord = packed record
    platformID: Word;
    encodingID: Word;
    languageID: Word;
    nameID: Word;
    length: Word;
    offset: Word;
  end;
const
  // Usamos el tag invertido que ha funcionado en la prueba (el valor decimal es 1699901549)
  NAME_TABLE_TAG = Cardinal($656D616E); // 'eman' (tag invertido para TryGetFontTable)

  // Tag correcto (6E616D65) si el binding lo pidiera en orden nativo
  // NAME_TABLE_TAG_BIG_ENDIAN = Cardinal($6E616D65); // 'name'

  // --- Funciones Auxiliares ---

  function SwapWord(Value: Word): Word;
  begin
    Result := ((Value and $FF) shl 8) or (Value shr 8);
  end;

  // NECESARIA: Funci�n para invertir los bytes de la cadena UTF-16
  procedure SwapUTF16Bytes(P: Pointer; LengthInBytes: Integer);
  var
    WPtr: PWord;
    i: Integer;
  begin
    WPtr := PWord(P);
    for i := 0 to (LengthInBytes div 2) - 1 do
    begin
      WPtr^ := SwapWord(WPtr^);
      Inc(WPtr);
    end;
  end;

var
  tableData: Pointer;
  tableSize: Cardinal;
  tableContext: Pointer;
  exists: BOOL;
  header: PTNameTableHeader;
  recordsBasePtr: PByte;
  currentRecordPtr: PTNameRecord;
  i: Integer;
  strPtr: PByte;
  candidate: WideString;
  recordCount: Word;
  stringOffset: Word;
  lengthInBytes: Integer;
  lengthInChars: Integer;
  tempPtr: PByte; // Para la copia temporal y la inversi�n de endianness
begin
  Result := '';
  if FontFace = nil then Exit;

  // Utilizamos el tag invertido que has confirmado que funciona
  if Succeeded(FontFace.TryGetFontTable(NAME_TABLE_TAG, tableData, tableSize, tableContext, exists)) and exists then
  begin
    try
      if tableSize < SizeOf(TNameTableHeader) then Exit;

      // 1. Asignar encabezado y corregir el orden de bytes (Big Endian)
      header := PTNameTableHeader(tableData);
      recordCount := SwapWord(header.count);
      stringOffset := SwapWord(header.stringOffset);

      // 2. Calcular la posici�n inicial de los registros
      recordsBasePtr := PByte(NativeUInt(tableData) + SizeOf(TNameTableHeader));

      // 3. Iterar sobre los registros
      for i := 0 to recordCount - 1 do
      begin
        // a. Calcular el puntero del registro actual
        currentRecordPtr := PTNameRecord(NativeUInt(recordsBasePtr) + i * SizeOf(TNameRecord));

        // b. Validaci�n de l�mites (simplificada)
        if NativeUInt(currentRecordPtr) + SizeOf(TNameRecord) > NativeUInt(tableData) + tableSize then
          Break;

        // c. Comprobar NameID = 1 (Familia) y los IDs de Plataforma/Codificaci�n
        if SwapWord(currentRecordPtr.nameID) = 1 then // NameID=1 -> Font Family
        begin
          // Preferir Unicode (Platform 0) o Windows Unicode (Platform 3, Encoding 1 o 10)
          if not ((SwapWord(currentRecordPtr.platformID) = 0) or
             ((SwapWord(currentRecordPtr.platformID) = 3) and
              ((SwapWord(currentRecordPtr.encodingID) = 1) or
               (SwapWord(currentRecordPtr.encodingID) = 10)))) then
            Continue;

          // d. Calcular la posici�n de la cadena
          strPtr := PByte(NativeUInt(tableData) + stringOffset + SwapWord(currentRecordPtr.offset));

          // e. Obtener longitud en bytes y validar l�mites
          lengthInBytes := SwapWord(currentRecordPtr.length);
          lengthInChars := lengthInBytes div 2;

          if NativeUInt(strPtr) + lengthInBytes > NativeUInt(tableData) + tableSize then
            Continue;

          // f. Copiar y corregir Endianness

          // 1. Crear una copia temporal de los datos del nombre
          tempPtr := AllocMem(lengthInBytes);
          try
            Move(strPtr^, tempPtr^, lengthInBytes);

            // 2. INVERTIR los bytes (Big Endian -> Little Endian)
            SwapUTF16Bytes(tempPtr, lengthInBytes);

            // 3. Establecer la cadena a partir de la copia invertida
            SetString(candidate, PWideChar(tempPtr), lengthInChars);

            Result := candidate;
            Exit;
          finally
            FreeMem(tempPtr);
          end;
        end;
      end;

    finally
      FontFace.ReleaseFontTable(tableContext);
    end;
  end;
end;

function TTextExtentRenderer.GetFontFamily(FontFace: IDWriteFontFace): WideString;
var
  FacePtr: Pointer;
begin
  Result := '';
  if FontFace = nil then Exit;

  // 1. OBTENER LA CLAVE: El puntero de la interfaz (direcci�n del objeto COM)
  FacePtr := Pointer(FontFace);

  // 2. Comprobar la cach� de esta instancia
  if FFontFamilyCache.TryGetValue(FacePtr, Result) then
    Exit; // �Encontrado en cach�!

  // 3. Si no est�, decodificar la tabla 'name' (la operaci�n costosa)
  // [Importante] Asumimos que GetFontFamilyFromFontFaceNoCache es la funci�n
  // que hace el parsing binario de la tabla 'name' que ya corregimos.
  Result := GetFontFamilyFromFontFace(FontFace);

  // 4. Guardar en la cach�
  FFontFamilyCache.Add(FacePtr, Result);
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
      if (glyphrun.FontFace <> FontFace) then
        Glyphpos.FontFamily:=GetFontFamily(glyphrun.fontFace);

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


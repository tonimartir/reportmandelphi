{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       TRpInfoProvider GDI                             }
{       Provides information about fonts                }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{                                                       }
{*******************************************************}

unit rpinfoprovgdi;

{$I rpconf.inc}


interface

uses Classes,SysUtils,Windows,rpinfoprovid,SyncObjs,rptypes,rpmunits,
{$IFDEF DOTNETD}
 System.Runtime.InteropServices,
{$ENDIF}
{$IFDEF WINDOWS_USEHARFBUZZ}
 rpICU,rpHarfBuzz,rpfreetype2,
{$ELSE}
 ActiveX,Vcl.Direct2D,WinAPi.D2D1,ComObj,rpdirectwriterenderer,
{$ENDIF}
    rpmdconsts, rptruetype, System.Generics.Collections;

const
 MAXKERNINGS=10000;

type

 //TGetCharPlac=function (DC: HDC; p2: PWideChar; p3, p4:integer;
 //  var p5: TGCPResults; p6: DWORD): DWORD;stdcall;
 // external 'gdi32.dll' name 'GetCharacterPlacementW'
 TRpGDIInfoProvider=class(TRpInfoProvider)
  adc:HDC;
  fonthandle:THandle;
  //bitmap: VCL.Graphics.TBitmap;
  currentname:String;
  currentstyle:integer;
  //GetCharPlac:TGetCharPlac;
  //gdilib:THandle;
  procedure SelectFont(pdffont:TRpPDFFOnt);
  procedure FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData);override;
  function NFCNormalize(astring:WideString):WideString;override;
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;override;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;override;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;override;
  function  GetFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;override;
  function TextExtent(const Text:WideString;
     var Rect:TRect;adata: TRpTTFontData;pdfFOnt:TRpPDFFont;
     wordwrap:boolean;singleline:boolean;FontSize:double): TRpLineInfoArray;override;
  function  GetFontStreamNative(data: TRpTTFontData): TMemoryStream;
{$IFDEF WINDOWS_USEHARFBUZZ}
  function CalcGlyphPositions(astring:WideString;adata:TRpTTFontData;pdffont:TRpPDFFont;direction: TRpBiDiDirection;
    script: string;FontSize:double):TGlyphPosArray;
{$ENDIF}
  constructor Create;
  destructor Destroy;override;
 end;




{$IFDEF WINDOWS_USEHARFBUZZ}
 var
  ftlibrary:FT_Library;
  initialized:boolean = false;
{$ENDIF}

implementation

//var
// adc:ThAndle;
// critsec:TCriticalSection;
const
 TTF_PRECISION=1000;



// typedef enum _NORM_FORM {
//  NormalizationOther = 0,
//  NormalizationC     = 1,  // Canonical Composition (NFC)
//  NormalizationD     = 2,  // Canonical Decomposition (NFD)
//  NormalizationKC    = 5,  // Compatibility Composition (NFKC)
//  NormalizationKD    = 6   // Compatibility Decomposition (NFKD)
//} NORM_FORM;

function NormalizeString(
  NormForm: DWORD;
  lpSrcString: LPCWSTR;
  cwSrcLength: Integer;
  lpDstString: LPWSTR;
  cwDstLength: Integer
): Integer; stdcall; external 'kernel32.dll';


function NormalizeToNFC(const S: UnicodeString): UnicodeString;
const
  NormalizationC = 1; // NFC
var
  requiredChars: Integer;
  writtenChars: Integer;
  buffer: PWideChar;
begin
  if S = '' then
    Exit('');

  // 1) pedir tamaño (devuelve número de caracteres necesarios, incluye terminador)
  //    Usamos Length(S) para no depender de terminadores NUL en la entrada.
  requiredChars := NormalizeString(NormalizationC, PWideChar(S), Length(S), nil, 0);
  if requiredChars = 0 then
    RaiseLastOSError;

  // Reservar buffer (requiredChars es cantidad de WCHARs, incluye espacio para terminador)
  GetMem(buffer, requiredChars * SizeOf(WideChar));
  try
    // 2) normalizar: escribirá writtenChars (sin incluir el terminador)
    writtenChars := NormalizeString(NormalizationC, PWideChar(S), Length(S), buffer, requiredChars);
    if writtenChars = 0 then
      RaiseLastOSError;

    // 3) construir el UnicodeString a partir del buffer (writtenChars no incluye el NUL)
    SetString(Result, buffer, writtenChars);
  finally
    FreeMem(buffer);
  end;
end;

constructor TRpGDIInfoProvider.Create;
var
 ddc:THandle;
begin
 inherited Create;
 currentname:='';
 currentstyle:=0;
 fonthandle:=0;
//  gdilib:=LoadLibrary('gdi32.dll');
//  if gdilib=0 then
//   RaiseLastOsError;
//  GetCharPlac:=GetProcAddress(gdilib,'GetCharacterPlacementW');
//  if not Assigned(GetCharPlac) then
//   RaiseLastOsError;
// bitmap:=VCL.Graphics.TBitmap.Create;
// bitmap.PixelFormat:=pf32bit;
// bitmap.Width:=10;
// bitmap.Height:=10;
 adc:=GetDc(0);
// adc:=bitmap.Canvas.Handle;

{$IFDEF WINDOWS_USEHARFBUZZ}
  if (not initialized) then
  begin
   CheckFreeTypeLoaded;
   CheckFreeType(FT_Init_FreeType(ftlibrary));
   InitICU;
   InitHarfBuzz;
   initialized:=true;
  end;
{$ELSE}
 // Inicializar COM
 CoInitialize(nil);
{$ENDIF}
end;
{$IFNDEF WINDOWS_USEHARFBUZZ}
function TRpGDIInfoProvider.TextExtent(
  const Text: WideString;
  var Rect: TRect;
  adata: TRpTTFontData;
  pdfFont: TRpPDFFont;
  wordwrap: Boolean;
  singleline: Boolean;
  FontSize: Double
): TRpLineInfoArray;
const
  DIP_TO_TWIPS_FACTOR = 15.0;
  POINTS_TO_DIPS_FACTOR = 4.0 / 3.0;
var
  Factory: IDWriteFactory;
  TextFormat: IDWriteTextFormat;
  TextLayout: IDWriteTextLayout;
  Renderer: TTextExtentRenderer;
  MaxLineWidth: Single;
  FontSizeInDips: Single;
  RectTopTwips: Single;
  i,j: Integer;
  LineInfo: TRpLineInfo;
  Line: TGlyphLine;
  Glyph: TGlyphPos;
  TotalWidth: Single;
  FamilyNameWide: WideString;
  FontWeight: DWRITE_FONT_WEIGHT;
  FontStyle: DWRITE_FONT_STYLE;
  FontCollection: IDWriteFontCollection;
  FontFamily: IDWriteFontFamily;
  Font: IDWriteFont;
  FontFace: IDWriteFontFace;
  Index: Cardinal;
  Exists: BOOL;
  FontMetrics: DWRITE_FONT_METRICS;
  scale: Single;
  tr: TDWriteTextRange;
  ascentSpacing:integer;
  PWideChartext: PWideChar;
  minLineCluster:integer;
  maxLineCluster:integer;
  lineCluster:integer;
  rectHeight:integer;
begin
  tr.startPosition := 0;
  tr.length := Length(Text);
  Result := nil;
  Factory := VCL.Direct2D.DWriteFactory;
  if not Assigned(Factory) then Exit;

  FamilyNameWide := WideString(adata.FamilyName);

  if pdfFont.Bold then
    FontWeight := DWRITE_FONT_WEIGHT_BOLD
  else
    FontWeight := DWRITE_FONT_WEIGHT_NORMAL;

  if pdfFont.Italic then
    FontStyle := DWRITE_FONT_STYLE_ITALIC
  else
    FontStyle := DWRITE_FONT_STYLE_NORMAL;

  MaxLineWidth := Rect.Right - Rect.Left;
  FontSizeInDips := FontSize * POINTS_TO_DIPS_FACTOR;
  Rect.Left:=0;
  Rect.Width:=Round(MaxLineWidth);
  rectheight:=Rect.Bottom-Rect.Top;
  Rect.Top:=0;
  Rect.Height:=rectheight;




  // --- Obtener FontFace ---
  FontFace := nil;
  Factory.GetSystemFontCollection(FontCollection, False);
  FontCollection.FindFamilyName(PWideChar(FamilyNameWide), Index, Exists);
  if Exists then
  begin
    FontCollection.GetFontFamily(Index, FontFamily);
    FontFamily.GetFirstMatchingFont(FontWeight, DWRITE_FONT_STRETCH_NORMAL, FontStyle, Font);
    Font.CreateFontFace(FontFace);
  end;

  // --- Crear TextFormat ---
  Factory.CreateTextFormat(
    PWideChar(FamilyNameWide),
    nil,
    FontWeight,
    FontStyle,
    DWRITE_FONT_STRETCH_NORMAL,
    FontSizeInDips,
    '',
    TextFormat
  );

  PWideCharText:=PWideChar(Text);
  // --- Crear TextLayout ---
  Factory.CreateTextLayout(
    PWideChartext,
    Length(Text),
    TextFormat,
    MaxLineWidth / DIP_TO_TWIPS_FACTOR,
    0,
    TextLayout
  );

  // --- Obtener métricas de la fuente ---
  FontFace.GetMetrics(FontMetrics);
  scale := FontSizeInDips / FontMetrics.DesignUnitsPerEm;

  // --- Crear Renderer y disparar layout ---
  Renderer := TTextExtentRenderer.Create(TextLayout,PWideChartext);
  try
    Renderer.FontFace := FontFace;
    TextLayout.Draw(nil, Renderer, 0, 0);

    SetLength(Result, Renderer.Lines.Count);
    RectTopTwips := 0;
    ascentSpacing:=Round(FontMetrics.ascent*scale*15);
    RectTopTwips:=RectTopTwips+ascentSpacing;

    TotalWidth := 0;

    // --- Iterar líneas ---
    for i := 0 to Renderer.Lines.Count - 1 do
    begin
      minLineCluster:=MaxInt;
      maxLineCluster:=-1;
      Line := Renderer.Lines[i];
      LineInfo.Glyphs := TGlyphPosArray(Line.Glyphs.ToArray);
      LineInfo.Width := 0;
      for j:=0 to Length(LineInfo.Glyphs)-1 do
      begin
        LineCluster:=LineInfo.Glyphs[j].LineCluster;
        Glyph:=Line.Glyphs[j];
        LineInfo.Width := LineInfo.Width + Line.Glyphs[j].XAdvance;
        //LineInfo.Glyphs[j].CharCode:=PWideCharText[LineCluster];
        if (maxLineCluster<LineCluster) then
          maxLineCluster:=LineCluster;
        if (minLineCluster>LineCluster) then
          minLineCluster:=LineCluster;
      end;
      if ((Line.Glyphs.Count > 0)  and (minLineCluster>=0)) then
      begin
        LineInfo.Position := minLineCluster+1;
        LineINfo.Size:=maxLineCluster-minLineCluster+1;
        LineInfo.Text := Copy(Text, LineInfo.Position + 1, LineInfo.Size);
      end
      else
      begin
        LineInfo.Position := 0;
        LineInfo.Size := 0;
        LineInfo.Text := '';
      end;

      LineInfo.TopPos := Round(RectTopTwips);


      // --- Interlineado correcto en TWIPS ---
      LineInfo.LineHeight := Round((FontMetrics.Ascent + FontMetrics.Descent + FontMetrics.LineGap) * scale * DIP_TO_TWIPS_FACTOR);
      LineInfo.Height := Round(LineInfo.LineHeight);
      LineInfo.lastline := (i = Renderer.Lines.Count - 1);

      RectTopTwips := RectTopTwips + LineInfo.LineHeight;

      if LineInfo.Width > TotalWidth then
        TotalWidth := LineInfo.Width;

      Result[i] := LineInfo;
    end;

    // Ajustar rectángulo final
    Rect.Right := Rect.Left + Round(TotalWidth);
    Rect.Bottom := Rect.Top + Round(RectTopTwips - Rect.Top)-ascentSpacing;

  finally
    Renderer.Free;
  end;
end;
{$ENDIF}

{$IFDEF WINDOWS_USEHARFBUZZ}
function TRpGDIInfoProvider.TextExtent(
  const Text: WideString;
  var Rect: TRect;
  adata: TRpTTFontData;
  pdfFont: TRpPDFFont;
  wordwrap: Boolean;
  singleline: Boolean;
  FontSize: Double
): TRpLineInfoArray;
var
  lineSubTexts: TList<TLineSubText>;
  lineSubText: TLineSubText;
  line: string;
  Bidi: TICUBidi;
  logicalRuns: TList<TBidiRun>;
  logicalRun, vRun: TBidiRun;
  direction: TRpBidiDirection;
  positions: TGlyphPosArray;
  lineWidthLimit, posY, maxWidth: Double;
  chunks:TList<TGlyphPosArray>;
  chunk: TGlyphPosArray;
  calculatedLines: TList<TLineGlyphs>;
  calculatedLine:TLineGlyphs;
  j, k: Integer;
  visualRuns: TList<TBidiRun>;
  LineInfo: TRpLineInfo;
  possibleBreaksCharIdx: TDictionary<Integer,Integer>;
  remaining:double;
  g:TGlyphPos;
  runWidth:integer;
  currentChunk: TLineGlyphs;
  visualGlyphs:TList<TGlyphPos>;
  runOffset:integer;
  leading: integer;
  linespacing:integer;
  textHeight:integer;
  ascentSpacing:integer;
begin
  InitICU;
  InitHarfBuzz;

 //linespacing:=adata.Ascent-adata.Descent; // +adata.Leading;
 linespacing:=Round(adata.Ascent-adata.Descent+adata.Leading);
 WriteToStdError(adata.FamilyName +  ' Bidi Ascent-Descent+Leading: '+IntToStr(lineSpacing)+chr(10));
 WriteToStdError(adata.FamilyName +  ' Bidi Ascent: '+IntToStr(adata.Ascent)+chr(10));
 WriteToStdError(adata.FamilyName +  ' Bidi Descent: '+IntToStr(adata.Descent)+chr(10));
 WriteToStdError(adata.FamilyName +  ' Bidi Leading: '+IntToStr(adata.Leading)+chr(10));
 // linespacing:=adata.Height;
 linespacing:=Round(((linespacing)/100000)*1440*FontSize*1.25);
 WriteToStdError(adata.FamilyName +  ' Bidi Font Size: '+IntToStr(Round(FontSize))+ ' LineSpacing: '+IntTostr(linespacing)+chr(10));



 //ascentSpacing:=Round((adata.Ascent-adata.descent)*FontSize/1000*20);
 ascentSpacing:=Round((adata.Ascent)*FontSize/1000*20);
 PosY:=0;
 PosY:=PosY+ascentSpacing;

 lineSubTexts := DividesIntoLines(Text);
  SetLength(Result, 0);
  maxWidth := 0;
  lineWidthLimit := Rect.Right - Rect.Left;

  try
    for lineSubText in lineSubTexts do
    begin
      line := Copy(Text, lineSubText.Position, lineSubText.Length);
      possibleBreaksCharIdx := FillPossibleLineBreaksString(line);
//      possibleBreaksCharIdx := FillPossibleWordBreaksString(line);

      calculatedLines := TList<TLineGlyphs>.Create;

      // -----------------------------
      // PRIMER BUCLE: logical runs → shaping → chunks
      // -----------------------------
      Bidi := TICUBidi.Create;
      logicalRuns := nil;
      try
        if not Bidi.SetPara(line, $FF) then
          raise Exception.Create('Bidi error');
        logicalRuns := Bidi.GetLogicalRuns(line);
      finally
        Bidi.Free;
      end;

      remaining:=lineWidthLimit;

      var textOffset:=lineSubtext.Position-1;
      currentChunk:=TLineGlyphs.Create(textOffset);
      for logicalRun in logicalRuns do
      begin
        if logicalRun.Direction = UBIDI_RTL then
          direction := RP_UBIDI_RTL
        else
          direction := RP_BIDI_LTR;
        runOffset:=logicalRun.LogicalStart;
        positions := CalcGlyphPositions(
          Copy(line, logicalRun.LogicalStart + 1, logicalRun.Length),
          adata,
          pdfFont,
          direction,
          logicalRun.ScriptString,
          FontSize
        );
        runWidth:=0;
        for k:=0 to Length(positions)-1 do
        begin
         runWidth:=runWidth+positions[k].XAdvance;
         positions[k].LineCluster:=positions[k].Cluster+logicalRun.LogicalStart;
        end;
        if ((runWidth<=remaining) or (not WordWrap)) then
        begin
         for g in positions do
         begin
          currentChunk.AddGlyph(g, runOffset);
         end;
         remaining:=remaining-runwidth;
        end
        else
        begin
          if direction = RP_UBIDI_RTL then
            chunks := BreakChunksRTL(positions, remaining, lineWidthLimit ,possibleBreaksCharIdx,line)
          else
            chunks := BreakChunksLTR(positions, remaining, lineWidthLimit ,possibleBreaksCharIdx,line);
          for j:=0 to chunks.Count-1 do
          begin
           chunk:=chunks[j];
           // Primer chunk en el currentchunk actual y completamos la línea
           if (j=0) then
           begin
            for g in chunk do
            begin
              currentChunk.AddGlyph(g,runOffset);
            end;
            calculatedLines.Add(currentChunk);
            currentChunk:=TLineGlyphs.Create(textOffset);
            remaining:=lineWidthLimit;
           end
           else
           // Ultimo chunk calculamos restante y todavia no se completa
           // la línea
           if (j=chunks.Count-1) then
           begin
            remaining:=lineWidthLimit;
            for g in chunk do
            begin
              currentChunk.AddGlyph(g,runOffset);
              remaining:=remaining-g.XAdvance;
            end;
           end
           else
           begin
            // Chunk intermedio, es una linea completa
            for g in chunk do
            begin
              currentChunk.AddGlyph(g,runOffset);
            end;
            remaining:=lineWidthLimit;
            calculatedLines.Add(currentChunk);
            currentChunk:=TLineGlyphs.Create(textOffset);
           end;
          end;
        end
      end;
      if (currentChunk.Glyphs.Count>0) then
      begin
        calculatedLines.Add(currentChunk);
      end;

      // -----------------------------
      // SEGUNDO BUCLE: recorrer chunks → visual runs → LineInfo
      // -----------------------------
      // obtener visual runs de toda la línea
      Bidi := TICUBidi.Create;
      visualRuns := nil;
      try
        if not Bidi.SetPara(line, $FF) then
          raise Exception.Create('VisualRuns error');
        visualRuns := Bidi.GetVisualRuns(line);
      finally
        Bidi.Free;
      end;

      for calculatedLine in calculatedLines do
      begin
        var minCluster:=calculatedline.MinClusterText;
        var maxCluster:=calculatedline.MaxClusterText;

        // Opcional para depuración obtener el texto a partir de indices de
        // línea actual
        //var minCluster:=calculatedline.MinClusterLine;
        //var maxCluster:=calculatedline.MaxClusterLine;
        //chunkText := Copy(line, minCluster, maxCluster - minCluster + 1);

        // construir orderedGlyphs en orden visual
        visualGlyphs:=TList<TGlyphPos>.Create;
        for vRun in visualRuns do
        begin
         if vRun.Direction = UBIDI_RTL then
         begin
          direction := RP_UBIDI_RTL;
          for k:=vRun.LogicalStart+vRun.Length downto vRun.LogicalStart+1  do
          begin
           if (calculatedLine.ClusterMap.ContainsKey(k)) then
           begin
            var lst := calculatedLine.ClusterMap[k];
            for j:=0 to lst.Count-1 do
            begin
             visualGlyphs.Add(calculatedline.Glyphs[lst[j]]);
            end;
           end;
          end;
         end
         else
         begin
          direction := RP_BIDI_LTR;
          for k:=vRun.LogicalStart+1 to vRun.LogicalStart+vRun.Length do
         begin
          if (calculatedLine.ClusterMap.ContainsKey(k)) then
          begin
           var lst := calculatedLine.ClusterMap[k];
           for j:=0 to lst.Count-1 do
           begin
            visualGlyphs.Add(calculatedline.Glyphs[lst[j]]);
           end;
          end;
         end;

         end;
        end;
        LineInfo.Glyphs:=TGlyphPosArray(visualGlyphs.ToArray());

        // rellenar LineInfo
        //LineInfo.Glyphs := Copy(orderedGlyphs, 0, Length(orderedGlyphs));
        LineInfo.Position := minCluster;
        LineInfo.Size := maxCluster - minCluster + 1;
        LineInfo.TopPos := Round(posY);
        LineInfo.Text :=Copy(Text, minCluster, maxCluster - minCluster + 1);

        LineInfo.Width := 0;
        for k := 0 to High(LineInfo.Glyphs) do
          LineInfo.Width := LineInfo.Width + LineInfo.Glyphs[k].XAdvance;

        LineInfo.Height := Round(linespacing);
        LineInfo.LineHeight := linespacing;
        LineInfo.lastline := False;

        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := LineInfo;

        if LineInfo.Width > maxWidth then maxWidth := LineInfo.Width;
        posY := posY + linespacing;
      end;

      calculatedLines.Free;
      possibleBreaksCharIdx.Free;
    end;

    if Length(Result) > 0 then
      Result[High(Result)].lastline := True;

  finally
    lineSubTexts.Free;
  end;

  Rect.Right := Rect.Left + Round(maxWidth);
  //Rect.Bottom := Rect.Top + Round(posY);
  Rect.Bottom := Rect.Top + Round(posY-ascentSpacing);
end;

function TRpGDIInfoProvider.CalcGlyphPositions(
  astring: WideString;
  adata: TRpTTFontData;
  pdffont: TRpPDFFont;
  direction: TRpBiDiDirection;
  script: string;
  FontSize: double): TGlyphPosArray;

var
  Font: THBFont;
  Buf: THBBuffer;
  GlyphInfo: TArray<THBGlyphInfo>;
  GlyphPos: TArray<THBGlyphPosition>;
  i: Integer;
  mem: Pointer;
  shapeData: TShapingData;
  scale:double;
  fontScaleValue: Int32;
begin
  InitHarfBuzz;
  SetLength(Result, 0);
  if astring = '' then Exit;

  if not adata.LoadedFace then
  begin
    shapeData := TShapingData.Create;
    adata.FontData.Fontdata.Position := 0;
    mem := adata.FontData.Fontdata.Memory;
    CheckFreeType(FT_New_Memory_Face(ftlibrary, mem, adata.FontData.Fontdata.Size, 0, shapedata.FreeTypeFace));

    adata.CustomImplementation := shapedata;
    adata.LoadedFace := True;
    shapedata.Font := THBFont.CreateReferenced(shapeData.FreeTypeFace);
    Font := shapedata.Font;

    // Configuramos FreeType con el tamaño en points y DPI 1440
    CheckFreeType(FT_Set_Char_Size(shapedata.FreeTypeFace, 0, 64 * 100, 720, 720));
  end
  else
    shapeData := adata.CustomImplementation as TShapingData;


  Font := shapedata.Font;

  try

    // --- Comentadas las líneas de escala personalizada
    fontScaleValue := Round(FontSize * 20.0);
    Font.PTEM := FontSize;
    Font.SetScale(fontScaleValue, fontScaleValue);
    Font.FTFontSetFuncs;

    // scale:=FontSize*20/adata.UnitsPerEM;
    // scale := 14/72;
    scale:=1;
    Buf := THBBuffer.Create;
    try
      if direction = TRpBiDiDirection.RP_UBIDI_RTL then
        Buf.Direction := hbdRTL
      else
        Buf.Direction := hbdLTR;

      Buf.Script := THBScript.FromString(script);
      if script = 'Arab' then
        Buf.Language := hb_language_from_string('ar', -1);

      Buf.AddUTF16(astring,0,Length(astring));
      Buf.Shape(Font);

      GlyphInfo := Buf.GetGlyphInfos;
      GlyphPos := Buf.GetGlyphPositions;
      SetLength(Result, Length(GlyphInfo));

      for i := 0 to High(GlyphInfo) do
      begin
        Result[i].GlyphIndex := GlyphInfo[i].Codepoint;
        // ahora devuelve la posición en la escala por defecto de HarfBuzz
        Result[i].XAdvance := Round(GlyphPos[i].XAdvance*scale);
        Result[i].XOffset  := Round(GlyphPos[i].XOffset*scale);
        Result[i].YOffset  := Round(GlyphPos[i].YOffset*scale);
        Result[i].CharCode := astring[GlyphInfo[i].Cluster + 1];
        Result[i].Cluster  := GlyphInfo[i].Cluster+1;
      end;
    finally
      Buf.Destroy;
    end;
  finally
    // Font.Destroy; // si lo necesitas
  end;
end;

{$ENDIF}

function TRpGDIInfoProvider.NFCNormalize(astring:WideString):WideString;
begin
 Result:=NormalizeToNFC(astring);
end;

destructor TRpGDIInfoProvider.destroy;
begin
 if fonthandle<>0 then
  DeleteObject(fonthandle);
// if gdilib<>0 then
//  FreeLibrary(gdilib);
// bitmap.Free;
 inherited destroy;
end;

procedure TRpGDIInfoProvider.SelectFont(pdffont:TRpPDFFOnt);
var
 LogFont:TLogFont;
 i:integer;
{$IFDEF DOTNETD}
 afontname:string;
{$ENDIF}
 lastError:Integer;
begin
 if ((currentname=pdffont.WFontName) and (currentstyle=pdffont.Style)) then
  exit;
 currentname:=pdffont.WFontName;
 currentstyle:=pdffont.Style;
 if fonthandle<>0 then
 begin
  DeleteObject(fonthandle);
  fonthandle:=0;
 end;
 LogFont.lfHeight:=Round(-TTF_PRECISION*GetDeviceCaps(adc,LOGPIXELSX)/72);

 LogFont.lfWidth:=0;
 LogFont.lfEscapement:=0;
 LogFont.lfOrientation:=0;

 if (pdffont.style and 1)>0 then
  LogFont.lfWeight:=FW_BOLD
 else
  LogFont.lfWeight:=FW_NORMAL;
 if (pdffont.style and (1 shl 1))>0 then
  LogFont.lfItalic:=1
 else
  LogFont.lfItalic:=0;
 if (pdffont.style and (1 shl 2))>0 then
  LogFont.lfUnderline:=1
 else
  Logfont.lfUnderline:=0;
 if (pdffont.style and (1 shl 3))>0 then
  LogFont.lfStrikeOut:=1
 else
  LogFont.lfStrikeOut:=0;
 LogFont.lfCharSet:=DEFAULT_CHARSET;
 lOGfONT.lfOutPrecision:=OUT_tt_onLy_PRECIS;
 LogFont.lfClipPrecision:=CLIP_DEFAULT_PRECIS;
 LogFont.lfEscapement:=0;
 LogFont.lfOrientation:=0;
 // Low Quality high measurement precision
 // LogFont.lfQuality:=Draft_QUALITY;
 // Improving quality
 LogFont.lfQuality:=PROOF_QUALITY;
 LogFont.lfPitchAndFamily:=FF_DONTCARE or DEFAULT_PITCH;
 for i := 0 to LF_FACESIZE-1 do
 begin
  logfont.lfFaceName[i]:=WideChar(0);
 end;
 StrPCopy(LogFont.lffACEnAME,Copy(pdffont.WFontName,1,LF_FACESIZE));

 Fonthandle:= CreateFontIndirect(LogFont);
 if (FontHandle=0) then
 begin   
  lasterror:=System.GetLastError();
  raise Exception.Create('Error calling CreateFontIndirect for font: ' + pdffont.WFontName +
   ' System Error Code: ' + IntToStr(lasterror));
 end;

 SelectObject(adc,fonthandle);
end;



function  TRpGDIInfoProvider.GetFullFontStream(data: TRpTTFontData): TMemoryStream;
begin
 Result:=data.FontData.Fontdata;
 Result.Position:=0;
end;


{$IFDEF WINDOWS_USEHARFBUZZ_SUBSETFONT}
function FontHasCFF2OrFVAR(face: THBFace): Boolean;
var
  count, i: Cardinal;
  tableCount: Cardinal;
  tableCountTotal: Cardinal;
  tags: array of Cardinal;

  function TAG(a, b, c, d: Char): Cardinal;
  begin
    Result := (Ord(a) shl 24) or (Ord(b) shl 16) or (Ord(c) shl 8) or Ord(d);
  end;
var
  cff2tag, fvartag: Cardinal;
begin
  Result := False;
  cff2tag := TAG('C','F','F','2');
  fvartag := TAG('f','v','a','r');
  setLength(tags,1000);
  tableCount:=1000;
  tableCountTotal:=hb_face_get_table_tags(face, 0, tableCount, @tags[0]);
  if tableCount = 0 then Exit(False);



  // Paso 4: buscar CFF2 o fvar
  for i := 0 to tableCount - 1 do
    if (tags[i] = cff2tag) or (tags[i] = fvartag) then
      Exit(True);
end;

function TRpGDIInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
var
  face, newFace: THBFace;
  blob: Phb_blob_t;
  subsetInput: Phb_subset_input_t;
  glyphsSet: Phb_set_t;
  glyphInfo: TGlyphInfo;
  outData: PByte;
  outSize: Cardinal;
  isVariable: boolean;
  HasCCF2: boolean;
begin

  Result := nil;

  // --- Crear blob desde la fuente ---
  blob := hb_blob_create(@data.FontData.FontData.Memory^, data.FontData.FontData.Size,
                         hbmmReadonly, nil, nil);
  if blob = nil then
    raise Exception.Create('No se pudo crear el blob de la fuente');

  try
    // --- Crear face ---
    subsetInput := hb_subset_input_create_or_fail;
    if subsetInput = nil then
      raise Exception.Create('No se pudo crear el input de subsetting');
    face := hb_face_create(blob, data.FontIndex);
    // --- Crear input de subsetting ---
     try
     isVariable := FontHasCFF2OrFVAR(face);
     if  (isVariable or HasCCF2) then
     begin
      Result:=GetFontStreamNative(data);
     end
     else
     begin
       hb_subset_input_set_flags(subsetInput, HB_SUBSET_FLAGS_DEFAULT);

       // --- Obtener set de glifos y añadirlos ---
       glyphsSet := hb_subset_input_glyph_set(subsetInput);
       for glyphInfo in data.glyphsInfo.Values do
         hb_set_add(glyphsSet, glyphInfo.Glyph);

       // --- Crear fuente subset ---
       newFace := hb_subset_or_fail(face, subsetInput);
       try
         // --- Obtener puntero a los datos de la fuente subset ---
         outData := hb_face_reference_blob(newFace); // referencia interna a blob
         outSize := hb_blob_get_length(hb_face_reference_blob(newFace));

         // --- Copiar a MemoryStream ---
         Result := TMemoryStream.Create;
         Result.SetSize(outSize);
         Move(outData^, Result.Memory^, outSize);
         Result.Position := 0;

       finally
         hb_face_destroy(newFace);
       end;
      end;
    finally
      hb_subset_input_destroy(subsetInput);
      hb_face_destroy(face);
    end;

  finally
    hb_blob_destroy(blob);
  end;
end;
{$ENDIF}
{$IFNDEF WINDOWS_USEHARFBUZZ_SUBSETFONT}
function  TRpGDIInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
begin
 Result:=GetFontStreamNative(data);
end;
{$ENDIF}

function  TRpGDIInfoProvider.GetFontStreamNative(data: TRpTTFontData): TMemoryStream;
var
 subset:TTrueTypeFontSubSet;
 bytes:TBytes;
 GlyphsUsed: TDictionary<Integer, TArray<Integer>>;
 xchar: WideChar;
 ints: TArray<Integer>;
 intChar: Integer;
 glyph: Integer;
 glyphInfo: TGlyphInfo;
begin
     SetLength(bytes, data.FontData.FontData.Size);
     data.fontdata.FontData.ReadBuffer(bytes[0],data.fontdata.FontData.Size);
     GlyphsUsed:=TDictionary<Integer, TArray<Integer>>.Create;
     for glyphInfo in data.glyphsInfo.Values do
     begin
      intChar:=Integer(glyphInfo.Char);
      glyph:=glyphInfo.Glyph;
      if (not GlyphsUsed.ContainsKey(glyph)) then
      begin
       SetLength(ints, 3);
       ints[0]:=glyph;
       ints[1]:=Round(glyphInfo.Width);
       ints[2]:=intChar;
       GlyphsUsed.Add(glyph,ints)
      end;
     end;
     // Creamos el subset de la fuente
     subset := TTrueTypeFontSubSet.Create(data.PostcriptName, bytes,
                GlyphsUsed, data.FontData.DirectoryOffset);
     bytes := subset.Execute();
     Result:=TMemoryStream.Create;
     Result.SetSize(Length(bytes));
     Result.Seek(0,soFromBeginning);
     Result.WriteBuffer(bytes[0],Length(bytes));
     Result.Seek(0,soFromBeginning);
end;


{$IFNDEF DOTNETD}
procedure TRpGDIInfoProvider.FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData);
var
 potm:POUTLINETEXTMETRIC;
 asize:integer;
 embeddable:boolean;
 logx:integer;
 multipli:double;
 apchar:string;
 alog:LOGFONT;
 acomp:byte;
{$IFDEF USEKERNING}
 akernings:array [0..MAXKERNINGS] of KERNINGPAIR;
 numkernings:integer;
 langinfo:DWord;
 i:integer;
 index:integer;
 newsize:integer;
 klist:TStringList;
{$ENDIF}
 fontCollectionBuffer: TBytes;
 header:string;
 dwtable: Cardinal;
 directoryoffset: Cardinal;
begin
   // See if data can be embedded
   embeddable:=false;
   SelectFont(pdffont);
   logx:=GetDeviceCaps(adc,LOGPIXELSX);
   data.postcriptname:=StringReplace(pdfFont.WFontName,' ','',[rfReplaceAll]);
   data.Encoding:='WinAnsiEncoding';
   asize:=GetOutlineTextMetricsW(adc,0,nil);
   if asize>0 then
   begin
    potm:=AllocMem(asize);
    try
     newsize:=GetOutlineTextMetricsW(adc,asize,potm);

     if (newsize<>0) then
     begin
      if (potm^.otmfsType AND $8000)=0 then
       embeddable:=true;
      multipli:=1/logx*72000/TTF_PRECISION;
      data.Ascent:=Round(potm^.otmTextMetrics.tmAscent*multipli);
      data.Descent:=-Round(potm^.otmTextMetrics.tmDescent*multipli);
      data.FontWeight:=potm^.otmTextMetrics.tmWeight;
      data.FontBBox:=potm^.otmrcFontBox;
      data.FontBBox.Left:=Round(data.FontBBox.Left*multipli);
      data.FontBBox.Right:=Round(data.FontBBox.Right*multipli);
      data.FontBBox.Bottom:=Round(data.FontBBox.Bottom*multipli);
      data.FontBBox.Top:=Round(data.FontBBox.Top*multipli);
      // CapHeight is not really correct, where to get?
      data.CapHeight:=Round(potm^.otmAscent*multipli);
      data.StemV:=0;
      data.MaxWidth:=Round(potm^.otmTextMetrics.tmMaxCharWidth*multipli);
      data.AvgWidth:=Round(potm^.otmTextMetrics.tmAveCharWidth*multipli);
      data.UnitsPerEM:=potm^.otmTextMetrics.tmHeight;

      data.Leading:=Round((potm^.otmTextMetrics.tmExternalLeading+potm^.otmTextMetrics.tmInternalLeading)*multipli);
      data.InternalLeading:=Round((potm^.otmTextMetrics.tmInternalLeading)*multipli);
      data.ExternalLeading:=Round((potm^.otmTextMetrics.tmExternalLeading)*multipli);
      //data.Leading:=Round((potm^.otmTextMetrics.tmInternalLeading)*multipli);
      // Windows does not allow Type1 fonts
      data.Type1:=false;

     if (Is64BitPlatform) then
     begin
      apchar:=PWideChar(Long64(potm)+Long64(potm^.otmpFamilyName));
      UniqueString(apchar);
      data.FamilyName:=apchar;
      UniqueString(data.FamilyName);
      apchar:=PWideChar(Long64(potm)+Long64(potm^.otmpFullName));
      UniqueString(apchar);
      data.FullName:=apchar;
      apchar:=PWideChar(Long64(potm)+Long64(potm^.otmpStyleName));
      UniqueString(apchar);
      data.StyleName:=apchar;
      apchar:=PWideChar(Long64(potm)+Long64(potm^.otmpFaceName));
      uniqueString(apchar);
      data.FaceName:=apchar;
     end
     else
     begin
      apchar:=PWideChar(Integer(potm)+Integer(potm^.otmpFamilyName));
      data.FamilyName:=StrPas(PWideChar(apchar));
      apchar:=PWideChar(Integer(potm)+Integer(potm^.otmpFullName));
      data.FullName:=apchar;
      apchar:=PWideChar(Integer(potm)+Integer(potm^.otmpStyleName));
      data.StyleName:=apchar;
      apchar:=PWideChar(Integer(potm)+Integer(potm^.otmpFaceName));
      data.FaceName:=apchar;
     end;


      data.ItalicAngle:=Round(potm^.otmItalicAngle/10);
      if ((potm^.otmTextMetrics.tmPitchAndFamily AND TMPF_TRUETYPE)=0) then
       Raise Exception.Create(SRpNoTrueType+'-'+data.FaceName);
      data.postcriptname:=StringReplace(data.familyname,' ','',[rfReplaceAll]);
      // Italic emulation
      if pdffont.Bold then
        data.postcriptname:=data.postcriptname+',Bold';
      if pdffont.Italic then
//       if data.ItalicAngle=0 then
//       begin
      if pdffont.Bold then
        data.postcriptname:=data.postcriptname+'Italic'
      else
        data.postcriptname:=data.postcriptname+',Italic';
//       end;
      //
      data.Flags:=32;
      // Fixed pitch? Doc says inverse meaning
      if ((potm^.otmTextMetrics.tmPitchAndFamily AND TMPF_FIXED_PITCH)=0) then
       data.Flags:=data.Flags+1;
      if GetObject(FontHandle,sizeof(alog),@alog)>0 then
      begin
       acomp:=(alog.lfPitchAndFamily AND $C0);
       if ((acomp or FF_SCRIPT)=alog.lfPitchAndFamily) then
        data.Flags:=data.Flags+8;
       if ((acomp or FF_ROMAN)=alog.lfPitchAndFamily) then
        data.Flags:=data.Flags+2;
      end;
      if Round(potm^.otmItalicAngle/10)<>0 then
//      if potm^.otmTextMetrics.tmItalic<>0 then
       data.Flags:=data.Flags+64;
      data.FontStretch:='/Normal';
     end;
    finally
     FreeMem(potm);
    end;
{$IFNDEF USEKERNING}
    data.havekerning:=false;
{$ENDIF}
{$IFDEF USEKERNING}
    // Get kerning pairs feature
    langinfo:=GetFontLanguageInfo(adc);
    data.havekerning:=(langinfo AND GCP_USEKERNING)>0;
    numkernings:=0;
    if data.havekerning then
    begin
     numkernings:=GetKerningPairs(adc,MAXKERNINGS,akernings[0]);
     if numkernings<0 then
     begin
      numkernings:=0;
     end;
    end;
    if numkernings>0 then
    begin
     for i:=0 to numkernings-1 do
     begin
      data.loadedk[akernings[i].wFirst]:=true;
      index:=data.kerningsadded.IndexOf(FormatFloat('000000',akernings[i].wFirst));
      if index>=0 then
       klist:=data.loadedkernings[akernings[i].wFirst]
      else
      begin
       klist:=TStringList.Create;
       klist.sorted:=true;
       data.loadedkernings[akernings[i].wFirst]:=klist;
       data.kerningsadded.Add(FormatFloat('000000',akernings[i].wFirst));
      end;
      klist.AddObject(FormatFloat('000000',akernings[i].wSecond),
       TObject(Round(-akernings[i].iKernAmount/logx*72000/TTF_PRECISION)));
     end;
    end;
{$ENDIF}
   end;

   if embeddable then
   begin
    directoryOffset:=0;
    data.FontData.Fontdata.SetSize(4);
    dwtable:=$66637474;
    // Detect font collection
{$R-} // disable range checking
// do non-range-checked operations here
   SetLength(fontCollectionbuffer,4);
   asize:=GetFontData(adc,dwtable,0,fontcollectionbuffer,4);
   header := TEncoding.ASCII.GetString(fontCollectionBuffer);
   if (header <> 'ttcf') then
   begin
     dwTable := 0;
   end;
{$R+} // turn range checking back on
    asize:=GetFontData(adc,dwtable,0,nil,0);
    if asize>0 then
    begin
     // Gets the raw data of the font
     data.FontData.FontData.SetSize(asize);
     data.FontData.DirectoryOffset:=0;
     if GDI_ERROR=GetFontData(adc,dwtable,0,data.FontData.FontData.Memory,asize) then
      RaiseLastOSError;
     data.FontData.Fontdata.Seek(0,soFromBeginning);



    end;
   end;
end;
{$ENDIF}

function TRpGDIInfoProvider.GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;
var
 logx:double;
 ginfo: TGlyphInfo;
   gm: _GLYPHMETRICS;
     mat: MAT2;
       res: DWORD;
   width:integer;
begin
 if data.glyphsInfo.ContainsKey(glyph) then
 begin
  Result:=data.glyphsInfo[glyph].Width;
 end
 else
 begin
     // MAT2 identidad (no escalado): eM11 = 1, eM12 = 0, eM21 = 0, eM22 = 1
    // FIXED fields: .value = integer part, .fract = fractional; ponemos 1 y 0 para identidad
    mat.eM11.value := 1; mat.eM11.fract := 0;
    mat.eM12.value := 0; mat.eM12.fract := 0;
    mat.eM21.value := 0; mat.eM21.fract := 0;
    mat.eM22.value := 1; mat.eM22.fract := 0;
   res:=GetGlyphOutlineW(adc,glyph,GGO_METRICS or GGO_GLYPH_INDEX,gm,0,nil,mat);
   if res = GDI_ERROR then
      width:=0
    else
      width := gm.gmCellIncX; // este es el advance horizontal
    // Get glyph index
    if (not data.glyphsInfo.ContainsKey(glyph)) then
    begin
     ginfo.Glyph := glyph;
     ginfo.Width := width;
     ginfo.Char := charC;
     data.glyphsInfo.Add(glyph,ginfo);
    end;
    Result:=width;
 end;
end;

(*
function TRpGDIInfoProvider.GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;
var
 logx:double;
 aabc:array [1..1] of ABC;
 aint:Word;
 glyphindexes:array[0..5] of UInt;
 glyphindexes2:array[0..1] of DWORD;
{$IFNDEF DELPHI2009UP}
{$IFDEF VER180}
// gcp:windows.tagGCP_RESULTSW;
{$ENDIF}
{$IFNDEF VER180}
// gcp:windows.tagGCP_RESULTSA;
{$ENDIF}
{$ENDIF}
{$IFDEF DELPHI2009UP}
 gcp:windows.tagGCP_RESULTSW;
{$ENDIF}
 astring:WideString;
  ginfo: TGlyphInfo;
 glyphIndex: UInt;
begin
 glyphindex:=0;
 aint:=Ord(charcode);
 if aint>255 then
   data.isunicode:=true;
 if data.loaded[aint] then
 begin
  Result:=data.loadedwidths[aint];
   exit;
 end;
 glyphindexes[0]:=0;
 glyphindexes[1]:=0;
 glyphindexes[2]:=0;
 glyphindexes[3]:=0;
 glyphindexes[4]:=0;
 glyphindexes[5]:=0;
 SelectFont(pdffont);
 logx:=GetDeviceCaps(adc,LOGPIXELSX);
 if not GetCharABCWidthsW(adc,aint,aint,aabc[1]) then
   RaiseLastOSError;
  gcp.lStructSize:=sizeof(gcp);
  gcp.lpOutString:=nil;
  gcp.lpOrder:=nil;
  gcp.lpDx:=nil;
  gcp.lpCaretPos:=nil;
  gcp.lpClass:=nil;
  gcp.lpGlyphs:=@glyphindexes;
  gcp.nGlyphs:=1;
  gcp.nMaxFit:=1;
  astring:='';
  astring:=astring+charcode+Widechar(0);
//  if GetCharPlac(adc,PWideChar(astring),1,0,gcp,GCP_DIACRITIC)=0 then
//   RaiseLastOSError;
  if GetCharacterPlacementW(adc,PWideChar(astring),1,0,gcp,GCP_DIACRITIC)=0 then
  begin
   glyphindexes2[0] := 0;
   glyphindexes2[1] := 0;
   if (GetGlyphIndicesW(adc,PWideChar(astring),Length(astring), @glyphindexes2, GGI_MARK_NONEXISTING_GLYPHS) = 0) then
   begin
    // ussupported glyph
    glyphindexes2[0]:=0;
   end
   else
   begin
     if (glyphindexes2[0] = $ffff) then
     begin
       RaiseLastOSError;
     end
     else
     begin
      glyphindexes[0] := glyphindexes2[0];
     end;
   end;
  end;
  glyphIndex:=glyphindexes[0];
  data.loadedglyphs[aint]:=WideChar(glyphIndex);
  data.glyphs.Add(charcode, glyphIndex);
  data.loadedg[aint]:=true;

//    if not GetCharABCWidthsI(adc,glyphindexes[0],1,nil,aabc[1]) then
//     RaiseLastOSError;

 Result:=
   (aabc[1].abcA+aabc[1].abcB+aabc[1].abcC)/logx*72000.0/TTF_PRECISION;
 data.loadedwidths[aint]:=Result;
 data.widths.Add(charcode, Result);

 data.loaded[aint]:=true;
 if data.firstloaded>aint then
  data.firstloaded:=aint;
 if data.lastloaded<aint then
  data.lastloaded:=aint;
 if (glyphIndex<>0) and  (not data.glyphsInfo.ContainsKey(glyphIndex)) then
 begin
  ginfo.Glyph := glyphIndex;
  ginfo.Width := Result;
  ginfo.Char := charcode;
  data.glyphsInfo.Add(glyphIndex,ginfo);
 end;
end;
*)

function TRpGDIInfoProvider.GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;
var
 logx:double;
 aabc:array [1..1] of ABC;
 aint:Word;
 glyphindexes:array[0..5] of UInt;
 glyphindexes2:array[0..1] of Word;
{$IFNDEF DELPHI2009UP}
{$IFDEF VER180}
// gcp:windows.tagGCP_RESULTSW;
{$ENDIF}
{$IFNDEF VER180}
// gcp:windows.tagGCP_RESULTSA;
{$ENDIF}
{$ENDIF}
{$IFDEF DELPHI2009UP}
 gcp:windows.tagGCP_RESULTSW;
{$ENDIF}
 astring:WideString;
 ginfo: TGlyphInfo;
 glyphIndex: UInt;
begin
 // glyphindex:=0;
 aint:=Ord(charcode);
 if aint>255 then
   data.isunicode:=true;
 if data.loaded[aint] then
 begin
  Result:=data.loadedwidths[aint];
   exit;
 end;
 glyphindexes[0]:=0;
 glyphindexes[1]:=0;
 glyphindexes[2]:=0;
 glyphindexes[3]:=0;
 glyphindexes[4]:=0;
 glyphindexes[5]:=0;
 SelectFont(pdffont);
 logx:=GetDeviceCaps(adc,LOGPIXELSX);
 if not GetCharABCWidthsW(adc,aint,aint,aabc[1]) then
   RaiseLastOSError;
  gcp.lStructSize:=sizeof(gcp);
  gcp.lpOutString:=nil;
  gcp.lpOrder:=nil;
  gcp.lpDx:=nil;
  gcp.lpCaretPos:=nil;
  gcp.lpClass:=nil;
  gcp.lpGlyphs:=@glyphindexes;
  gcp.nGlyphs:=1;
  gcp.nMaxFit:=1;
  astring:='';
  astring:=astring+charcode+Widechar(0);
//  if GetCharPlac(adc,PWideChar(astring),1,0,gcp,GCP_DIACRITIC)=0 then
//   RaiseLastOSError;
  if GetCharacterPlacementW(adc,PWideChar(astring),1,0,gcp,GCP_DIACRITIC or GCP_GLYPHSHAPE)=0 then
  begin
   glyphindexes2[0] := 0;
   glyphindexes2[1] := 0;
   if (GetGlyphIndicesW(adc,PWideChar(astring),Length(astring), @glyphindexes2, GGI_MARK_NONEXISTING_GLYPHS) = 0) then
   begin
    // ussupported glyph
    glyphindexes2[0]:=0;
    Result:=0;
    exit;
   end
   else
   begin
     if ((glyphindexes2[0] and $8000)) = 0 then
     begin
      glyphIndex := glyphindexes2[0];
     end
     else
     begin
      // Unsupported char to glyph-use unscribe instead for complex text shaping
      glyphIndex:=0;
     end;
   end;
  end
  else
  begin
    glyphIndex:=glyphindexes[0];
  end;
  data.loadedglyphs[aint]:=WideChar(glyphIndex);
  data.loadedg[aint]:=true;
  data.glyphs.Add(charcode, glyphindexes[0]);

  data.loaded[aint]:=true;

//    if not GetCharABCWidthsI(adc,glyphindexes[0],1,nil,aabc[1]) then
//     RaiseLastOSError;

 Result:=
   (aabc[1].abcA+aabc[1].abcB+aabc[1].abcC)/logx*72000.0/TTF_PRECISION;
 data.loadedwidths[aint]:=Result;
 data.widths.Add(charcode, Result);

 data.loaded[aint]:=true;
 if data.firstloaded>aint then
  data.firstloaded:=aint;
 if data.lastloaded<aint then
  data.lastloaded:=aint;
 if (True) then

 if (glyphIndex<>0) and  (not data.glyphsInfo.ContainsKey(glyphIndex)) then
 begin
  ginfo.Glyph := glyphIndex;
  ginfo.Width := Result;
  ginfo.Char := charcode;
  data.glyphsInfo.Add(glyphIndex,ginfo);
 end;
end;


function TRpGDIInfoProvider.GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;
{$IFDEF USEKERNING}
var
 index:integer;
 alist:TStringList;
 aint:Integer;
{$ENDIF}
begin
{$IFNDEF USEKERNING}
 Result:=0;
 exit;
{$ENDIF}
{$IFDEF USEKERNING}
 // Looks for the cached kerning
 Result:=0;
 aint:=Integer(leftchar);
 if data.loadedk[aint] then
 begin
  alist:=data.loadedkernings[aint];
  index:=alist.IndexOf(FormatFloat('000000',Integer(rightchar)));
  if index>=0 then
   Result:=Integer(alist.Objects[index])
 end;
{$ENDIF}
end;

initialization
finalization

end.

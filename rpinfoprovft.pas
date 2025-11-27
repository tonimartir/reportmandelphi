{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       TRpInfoProvider Fretype library                 }
{       Provides information about fonts in Linux       }
{       It uses freetype library version 2              }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{                                                       }
{*******************************************************}

unit rpinfoprovft;


interface

{$I rpconf.inc}

uses Classes,SysUtils,rptruetype,rptypes,rpmunits,
{$IFDEF USEVARIANTS}
    Types,
{$ENDIF}
{$IFDEF MSWINDOWS}
    Windows,
{$ENDIF}
    rpinfoprovid,SyncObjs,rpfontconfig,
    rpmdconsts,rpfreetype2,System.Generics.Collections,rpHarfbuzz,rpICU;


type

 TRpLogFont=class(TObject)
  fixedpitch:boolean;
  postcriptname:string;
  familyname:String;
  stylename:string;
  italic:Boolean;
  bold:Boolean;
  filename:String;
  fontIndex:integer;
  ascent:integer;
  descent:integer;
  height:integer;
  weight:integer;
  MaxWidth:integer;
  avCharWidth:Integer;
  Capheight:integer;
  ItalicAngle:double;
  leading:integer;
  BBox:TRect;
  fullinfo:Boolean;
  scalable:Boolean;
  StemV:double;
  ftface:FT_Face;
  faceinit:boolean;
  havekerning:Boolean;
  type1:boolean;
  truetype:boolean;
  convfactor,widthmult:Double;
  LoadedFace:boolean;
  CustomImplementation:TObject;
  data: TRpTTFontData;
  constructor Create;
  destructor Destroy;override;
  procedure OpenFont;
 end;

 TRpLogFontCache = class(TDictionary<string, TRpLogFont>);

 TRpFTInfoProvider=class(TRpInfoProvider)
  currentname:String;
  currentstyle:integer;
  currentfont:TRpLogFont;
  crit:TCriticalSection;
  procedure InitLibrary;
  procedure SelectFont(pdffont:TRpPDFFOnt;content: string;ignoreFamily: boolean);
  function NFCNormalize(astring:WideString):WideString;override;

  function CalcGlyphPositions(astring:WideString;
    direction: TRpBiDiDirection;
    script: string;FontSize:double):TGlyphPosArray;
  procedure FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData;content: string);override;
  procedure FillFontDataInt(data:TRpTTFontData);
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;override;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;override;
  function GetFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetFontStreamNative(data: TRpTTFontData): TMemoryStream;
  function GetFontStreamHarfBuzz(data: TRpTTFontData): TMemoryStream;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;override;
  function GetOrAddLogFont(const FileName: string; FontIndex: Integer): TRpLogFont;
  function TextExtent(
    const Text: WideString;
    var Rect: TRect;
    adata: TRpTTFontData;
    pdfFont: TRpPDFFont;
    wordwrap: Boolean;
    singleline: Boolean;
    FontSize: Double
  ): TRpLineInfoArray;override;
  procedure SelectFontFontConfig(pdffont:TRpPDFFOnt;unicodeContent: string = '');
  procedure SelectFontFontConfigInt(pdffont: TRpPDFFont; unicodeContent: string;removeFamily: boolean);
  constructor Create;
  destructor destroy;override;
 end;

var
  // El diccionario global (una sola instancia)
  GlobalFontCache: TRpLogFontCache;
  critSection:TCriticalSection;



implementation

var
  fontlist:TStringList;
  fontpaths:TStringList;
  fontfiles:TStringList;
  ftlibrary:FT_Library;
  initialized:boolean;
  defaultfont:TRpLogFont;
  defaultfontb:TRpLogFont;
  defaultfontit:TRpLogFont;
  defaultfontbit:TRpLogFont;
  defaultfont_arabic:TRpLogFont;
  defaultfontb_arabic:TRpLogFont;
  defaultfontit_arabic:TRpLogFont;
  defaultfontbit_arabic:TRpLogFont;

const
 TTF_PRECISION=1000;


function GetFontCacheKey(const FileName: string; FontIndex: Integer): string;
begin
  // Usa un separador que no se espera en el nombre de archivo (ej. '|').
  Result := FileName + '|' + IntToStr(FontIndex);
end;

 // --- Inicialización y Finalización ---

procedure InitializeFontCache;
begin
  if not Assigned(GlobalFontCache) then
  begin
    GlobalFontCache := TRpLogFontCache.Create;
    critSection:=TCriticalSection.Create;
  end;
end;

procedure FinalizeFontCache;
begin
  if Assigned(GlobalFontCache) then
  begin
    // Importante: El diccionario es responsable de liberar los objetos TRpLogFont
    GlobalFontCache.Free;
    GlobalFontCache := nil;
  end;
end;

function FillLogFont(filename:string;fontIndex:integer): TRpLogFont;
var aobj: TRpLogFont;
 errorface:FT_Error;
 aface:FT_Face;
 externalLeading:integer;
begin
   Result:=nil;
   errorface:=FT_New_Face(ftlibrary,PAnsiChar(UTF8Encode(filename)),fontIndex,aface);
   //errorface:=FT_New_Memory_Face(ftlibrary,bytes,Length(bytes),0,aface);
   if (errorface<>0) then
    raise Exception.Create('Error Code ' + IntToStr(errorface)+
     ' Opening font:' + filename);

   if (errorface = 0) then
   begin

   try
    // Add it only if it's a TrueType or OpenType font
    // Type1 fonts also supported
    // Some truetype do not set scalable, so add all
     aobj:=TRpLogFont.Create;
     if  (FT_FACE_FLAG_SCALABLE AND aface.face_flags)=0 then
      aobj.scalable:=false
     else
      aobj.scalable:=true;
     Result:=aobj;
      aobj.FullInfo:=false;
      // Fill font properties
      aobj.Type1:=(FT_FACE_FLAG_SFNT AND aface.face_flags)=0;
      aobj.TrueType:=((aface.face_flags and FT_FACE_FLAG_SFNT) <> 0)
            and (FT_Get_Sfnt_Table(aface, FT_SFNT_GLYF) <> nil);
      if aobj.Type1 then
      begin
       aobj.widthmult:=1;
       //aobj.convfactor:=1;
       if (aface.units_per_EM = 0) then
        aobj.convfactor:=1
       else
        aobj.convfactor:=1000/aface.units_per_EM;
      end
      else
      begin
       //aobj.convfactor:=1;
       if (aface.units_per_EM = 0) then
        aobj.convfactor:=1
       else
        aobj.convfactor:=1000/aface.units_per_EM;
       aobj.widthmult:=1;
      end;
      aobj.filename:=filename;
      aobj.postcriptname:='';
      aobj.familyname:='';
      if (aface.family_name<>nil) then
      begin
       aobj.postcriptname:=StringReplace(StrPas(aface.family_name),' ','',[rfReplaceAll]);
       aobj.familyname:=StrPas(aface.family_name);
      end;
      if Pos('ARABIC',UpperCase(aobj.familyname))>0 then
      begin
      aobj.fixedpitch:=(aface.face_flags AND FT_FACE_FLAG_FIXED_WIDTH)<>0;
      end;

      aobj.fixedpitch:=(aface.face_flags AND FT_FACE_FLAG_FIXED_WIDTH)<>0;
      aobj.HaveKerning:=(aface.face_flags AND FT_FACE_FLAG_KERNING)<>0;
      aobj.BBox.Left:=Round(aobj.convfactor*aface.bbox.xMin);
      aobj.BBox.Right:=Round(aobj.convfactor*aface.bbox.xMax);
      aobj.BBox.Top:=Round(aobj.convfactor*aface.bbox.yMax);
      aobj.BBox.Bottom:=Round(aobj.convfactor*aface.bbox.yMin);
      aobj.ascent:=Round(aobj.convfactor*aface.ascender);
      aobj.descent:=Round(aobj.convfactor*aface.descender);
      aobj.height:=Round(aobj.convfactor*aface.height);
      // External leading, same as GDI OUTLINETEXTMETRICS, it's the line gap
      externalLeading := Round(aobj.convfactor*aface.height)-(aobj.ascent-aobj.descent);
      // Internal leading, same as GDI OUTLINETEXTMETRICS, it's the space inside the font
      // reserved for accent marks
      // internalLeading := Round((aobj.ascent - aobj.descent) - aobj.convfactor*aface.units_per_EM);
      aobj.leading := Round((aface.height-(aobj.ascent-aobj.descent))*aobj.convfactor);


      aobj.MaxWidth:=Round(aobj.convfactor*aface.max_advance_width);
      aobj.Capheight:=Round(aobj.convfactor*aface.ascender);
      aobj.stylename:='';
      aobj.bold:=(aface.style_flags AND FT_STYLE_FLAG_BOLD)<>0;
      aobj.italic:=(aface.style_flags AND FT_STYLE_FLAG_ITALIC)<>0;
      if (aface.style_name<>nil) then
      begin
       aobj.stylename:=StrPas(aface.style_name);
       if not aobj.bold then
         aobj.bold :=
              (Pos('BOLD', UpperCase(aobj.stylename)) > 0)
           or (Pos('BOLD', UpperCase(aobj.postcriptname)) > 0)
           or (Pos('BOLD', UpperCase(aobj.filename)) > 0);
       if not aobj.italic then
         aobj.italic :=
             (Pos('ITALIC', UpperCase(aobj.stylename)) > 0)
           or (Pos('OBLIQUE', UpperCase(aobj.stylename)) > 0)
           or (Pos('ITALIC', UpperCase(aobj.postcriptname)) > 0)
           or (Pos('OBLIQUE', UpperCase(aobj.postcriptname)) > 0)
           or (Pos('ITALIC', UpperCase(aobj.filename)) > 0)
           or (Pos('OBLIQUE', UpperCase(aobj.filename)) > 0);
      end;
   finally
     FT_Done_Face(aface);
   end;
  end;
end;

function TRpFTInfoProvider.GetOrAddLogFont(const FileName: string; FontIndex: Integer): TRpLogFont;
var
  Key: string;
  LogFont: TRpLogFont;
begin
  critSection.Enter;
  try
  if not Assigned(GlobalFontCache) then
    InitializeFontCache; // Asegura que el cache esté listo
  Key := GetFontCacheKey(FileName, FontIndex);

  // 1. Intentar obtener de la caché
  if GlobalFontCache.TryGetValue(Key, LogFont) then
  begin
    Result := LogFont;
    Exit;
  end;

  // 2. Si no está en caché, crearlo e inicializarlo

  // NOTA: Aquí es donde integrarías la lógica de Fontconfig/FreeType
  // para rellenar los datos del TRpLogFont (postcriptname, ascent, descent, ftface, etc.)

  LogFont := FillLogFont(filename,fontIndex);
  // 3. Añadir a la caché
  GlobalFontCache.Add(Key, LogFont);
  Result := LogFont;
  finally
    critSection.Leave;
  end;
end;


function TRpFTInfoProvider.NFCNormalize(astring:WideString):WideString;
begin
 InitIcu;
 InitHarfBuzz;
 // Normalize enabled again
 Result:=NormalizeNFC(astring);
end;

function TRpFTInfoProvider.TextExtent(
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
  dofallback:boolean;
  originalFont: TRpLogFont;
  fallbackAscentSpacing: integer;
begin
  InitICU;
  InitHarfBuzz;
 originalFont:=currentfont;
 linespacing:=adata.Ascent-adata.Descent+adata.Leading;
 linespacing:=Round(adata.Ascent-adata.Descent+adata.Leading);
 WriteToStdError(adata.FamilyName +  ' Bidi Ascent-Descent+Leading: '+IntToStr(lineSpacing)+chr(10));
 WriteToStdError(adata.FamilyName +  ' Bidi Ascent: '+IntToStr(adata.Ascent)+chr(10));
 WriteToStdError(adata.FamilyName +  ' Bidi Descent: '+IntToStr(adata.Descent)+chr(10));
 WriteToStdError(adata.FamilyName +  ' Bidi Leading: '+IntToStr(adata.Leading)+chr(10));
 // linespacing:=adata.Height;
 linespacing:=Round(((linespacing)/100000)*1440*FontSize);
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
        currentfont:=originalfont;
        if logicalRun.Direction = UBIDI_RTL then
          direction := RP_UBIDI_RTL
        else
          direction := RP_BIDI_LTR;
        runOffset:=logicalRun.LogicalStart;
        positions := CalcGlyphPositions(
          Copy(line, logicalRun.LogicalStart + 1, logicalRun.Length),
          direction,
          logicalRun.ScriptString,
          FontSize
        );
        dofallback:=false;
        for k:=0 to Length(positions)-1 do
        begin
         if (positions[k].GlyphIndex = 0) then
         begin
          dofallback:=true;
          break;
         end;
        end;
        fallbackAscentSpacing:=ascentSpacing;
        if (dofallback) then
        begin
         SelectFont(pdfFont,Copy(line, logicalRun.LogicalStart + 1, logicalRun.Length),false);
         positions := CalcGlyphPositions(
           Copy(line, logicalRun.LogicalStart + 1, logicalRun.Length),
           direction,
           logicalRun.ScriptString,
           FontSize
         );
         var secondFallback := false;
         for k:=0 to Length(positions)-1 do
         begin
          if (positions[k].GlyphIndex = 0) then
          begin
           secondFallback:=true;
           break;
          end;
         end;
         if (secondFallback) then
         begin
          SelectFont(pdfFont,Copy(line, logicalRun.LogicalStart + 1, logicalRun.Length),true);
           positions := CalcGlyphPositions(
             Copy(line, logicalRun.LogicalStart + 1, logicalRun.Length),
             direction,
             logicalRun.ScriptString,
             FontSize
           );
         end;



         fallbackAscentSpacing:=Round((currentfont.data.Ascent)*FontSize/1000*20);
        end;
        runWidth:=0;
        for k:=0 to Length(positions)-1 do
        begin
         runWidth:=runWidth+positions[k].XAdvance;
         positions[k].LineCluster:=positions[k].Cluster+logicalRun.LogicalStart;
         if (dofallback) then
         begin
          positions[k].FontFamily:=currentfont.familyname;
          // Adjust baseline
          // Not needed adjusted by pdf engine
          if (fallbackAscentSpacing<>ascentSpacing) then
          begin
           // positions[k].YOffset:=positions[k].YOffset+fallbackAscentSpacing-ascentSpacing;
          end;
         end;
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
    currentfont:=originalfont;
  end;

  Rect.Right := Rect.Left + Round(maxWidth);
  //Rect.Bottom := Rect.Top + Round(posY);
  Rect.Bottom := Rect.Top + Round(posY-ascentSpacing);
end;

function TRpFTInfoProvider.CalcGlyphPositions(
  astring: WideString;
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

  if not currentfont.LoadedFace then
  begin
    shapeData := TShapingData.Create;

    currentfont.data.FontData.Fontdata.Position := 0;
    mem := currentfont.data.FontData.Fontdata.Memory;
    CheckFreeType(FT_New_Memory_Face(ftlibrary, mem, currentfont.data.FontData.Fontdata.Size, 0, shapedata.FreeTypeFace));

    currentfont.CustomImplementation := shapedata;
    currentfont.LoadedFace := True;
    shapedata.Font := THBFont.CreateReferenced(shapeData.FreeTypeFace);
    Font := shapedata.Font;

    // Configuramos FreeType con el tamaño en points y DPI 1440
    CheckFreeType(FT_Set_Char_Size(shapedata.FreeTypeFace, 0, 64 * 100, 720, 720));
  end
  else
    shapeData := currentfont.CustomImplementation as TShapingData;


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

      Buf.AddUTF16(astring);
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





// add self directory and subdirectories to the lis
procedure Parsedir(alist:TStringList;adir:string);
var
 f:TSearchRec;
 retvalue:integer;
begin
 adir:=ExpandFileName(adir);
 alist.Add(adir);
 retvalue:=SysUtils.FindFirst(adir+C_DIRSEPARATOR+'*',faDirectory,F);
 if 0=retvalue then
 begin
  try
   while retvalue=0 do
   begin
    if ((F.Name<>'.') AND (F.Name<>'..')) then
    begin
     if (f.Attr AND faDirectory)<>0 then
      Parsedir(alist,adir+C_DIRSEPARATOR+F.Name);
    end;
    retvalue:=SysUtils.FindNext(F);
   end;
  finally
   SysUtils.FindClose(F);
  end;
 end;
end;

// Parses /etc/fonts/fonts.conf for font directories
// also includes subdirectories
procedure GetFontsDirectories(alist:TStringList);
var
{$IFDEF LINUX}
 afile:TStringList;
 astring:String;
 diderror:Boolean;
 apath:String;
 index:integer;
{$ENDIF}
{$IFDEF MSWINDOWS}
  abuf:pchar;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
 abuf:=AllocMem(255);
 try
  GetWindowsDirectory(abuf,255);
  alist.Add(StrPas(abuf)+'\fonts');
 finally
  FreeMem(abuf);
 end;
 exit;
{$ENDIF}
{$IFDEF LINUX}
 // Red hat linux fonts
 alist.Add('/usr/share/fonts');
 // Ubuntu fonts
 // alist.Add('/usr/share/fonts/truetype');
 // alist.Add('/usr/share/fonts/opentype');
 // alist.Add('/usr/share/fonts/type1');
 alist.Add('/usr/local/share/fonts');
(* diderror:=false;
 alist.clear;
 afile:=TStringList.create;
 try
  afile.LoadFromFile('/etc/fonts/fonts.conf');
 except
  afile.free;
  diderror:=true;
 end;
 if diderror then
 begin
  // Default font directories
  ParseDir(alist,'/usr/X11R6/lib/X11/fonts');
  ParseDir(alist,'~/fonts');
  exit;
 end;
 astring:=afile.Text;
 index:=Pos('<dir>',astring);
 while index>0 do
 begin
  astring:=Copy(astring,index+5,Length(astring));
  index:=Pos('</dir>',astring);
  if index>0 then
  begin
   apath:=Copy(astring,1,index-1);
   ParseDir(alist,apath);
   astring:=Copy(astring,index+6,Length(astring));
  end;
  index:=Pos('<dir>',astring);
 end;*)
{$ENDIF}
end;

function FileToBytes(const AName: string; var Bytes: TBytes): Boolean;
var
  Stream: TFileStream;
begin
  if not FileExists(AName) then
  begin
    Result := False;
    Exit;
  end;
  Stream := TFileStream.Create(AName, fmOpenRead);
  try
    SetLength(Bytes, Stream.Size);
    Stream.ReadBuffer(Pointer(Bytes)^, Stream.Size);
  finally
    Stream.Free;
  end;
  Result := True;
end;


procedure TRpFTInfoProvider.InitLibrary;
var
 i:integer;
 f:TSearchRec;
 retvalue:integer;
 aobj:TRpLogFont;
 afilename:string;
 errorface:FT_Error;
 aface:FT_Face;
// afaceRec:FT_FaceRec;
 fontpaths1:TStrings;
 direc:string;
 bytes: TBytes;
 afilename2: AnsiString;
 externalLeading: Integer;
 internalLeading: Integer;
begin
 CheckFreeTypeLoaded;
 CheckFreeType(FT_Init_FreeType(ftlibrary));
 if Assigned(fontlist) or FontConfigAvailable then
  exit;

 InitFontConfig;

 if (FontConfigAvailable) then
 begin
  exit;
 end;



 // reads font directory
 fontlist:=TStringList.Create;
 fontfiles:=TStringList.Create;
 fontfiles.Sorted:=true;
 fontpaths:=TStringList.Create;
 fontpaths1:=TStringList.Create;
 aface:=nil;

(* aface.num_faces:=0;
 aface.face_index:=0;
 aface.face_flags:=0;
 aface.style_flags:=0;
 aface.num_glyphs:=0;
 aface.family_name:=nil;
 aface.style_name:=nil;
 aface.num_fixed_sizes:=0;
 aface.available_sizes:=nil;
 aface.num_charmaps:=0;
 aface.charmaps:=nil;
 aface.generic.data:=nil;
 aface.generic.finalizer:=nil;
 aface.bbox.xMin:=0;
 aface.bbox.yMin:=0;
 aface.bbox.yMax:=0;
 aface.bbox.yMin:=0;
 aface.bbox.yMax:=0;
 aface.units_per_EM:=0;
 aface.ascender:=0;
 aface.descender:=0;
 aface.height:=0;
 aface.max_advance_width:=0;
 aface.max_advance_height:=0;
 aface.underline_position:=0;
 aface.underline_thickness:=0;
 aface.glyph:=nil;
 aface.size:=nil;
 aface.charmap:=nil;
 aface.driver.z:=nil;
 aface.memory.z:=nil;
 aface.sizes_list.z:=nil;
 aface.autohint.data:=nil;
 aface.autohint.finalizer:=nil;
 aface.extensions:=nil;
 aface.internal.z:=nil;    *)


 GetFontsDirectories(fontpaths);
 fontfiles.Clear;
  i:=0;
 while i<fontpaths.Count do
 begin
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)<>0 then
      begin
        direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
        fontpaths.Add(direc);
        fontpaths1.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  Inc(i);
 end;
  i:=0;
 while i<fontpaths1.Count do
 begin
  direc:=fontpaths1.strings[i]+C_DIRSEPARATOR+'*';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)<>0 then
      begin
        direc:=fontpaths1.strings[i]+C_DIRSEPARATOR+F.Name;
        fontpaths.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  Inc(i);
 end;

 for i:=0 to fontpaths.Count-1 do
 begin
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.pf*',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.ttf',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.otf',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  retvalue:=SysUtils.FindFirst(fontpaths.strings[i]+C_DIRSEPARATOR+'*.t1',faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
       fontfiles.Add(fontpaths.strings[i]+C_DIRSEPARATOR+F.Name);
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
{$IFDEF LINUX}
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.TTF';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
      begin
       direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
       fontfiles.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.OTF';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
      begin
       direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
       fontfiles.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
  direc:=fontpaths.strings[i]+C_DIRSEPARATOR+'*.T1';
  retvalue:=SysUtils.FindFirst(direc,faAnyFile,F);
  if 0=retvalue then
  begin
   try
    while retvalue=0 do
    begin
     if ((F.Name<>'.') AND (F.Name<>'..')) then
     begin
      if (f.Attr AND faDirectory)=0 then
      begin
       direc:=fontpaths.strings[i]+C_DIRSEPARATOR+F.Name;
       fontfiles.Add(direc);
      end;
     end;
     retvalue:=SysUtils.FindNext(F);
    end;
   finally
    SysUtils.FindClose(F);
   end;
  end;
{$ENDIF}
 end;
 defaultfont:=nil;
 defaultfontb:=nil;
 defaultfontit:=nil;
 defaultfontbit:=nil;
 defaultfont_arabic:=nil;
 defaultfontb_arabic:=nil;
 defaultfontit_arabic:=nil;
 defaultfontbit_arabic:=nil;
 initialized:=true;

 // Now fill the font list with all font files
 for i:=0 to fontfiles.Count-1 do
 begin
  afilename:=fontfiles.strings[i];
  afilename2:=afilename;
//  FileToBytes(afileName,bytes);
  aface:=nil;
  errorface:=FT_New_Face(ftlibrary,PAnsichar(afilename2),-1,aface);
  if (aface.num_faces>1) then
  begin
    errorface:=FT_New_Face(ftlibrary,PAnsichar(afilename2),-1,aface);
  end;

//  if errorface=0 then
  begin

   errorface:=FT_New_Face(ftlibrary,PAnsichar(afilename2),0,aface);
   //errorface:=FT_New_Memory_Face(ftlibrary,bytes,Length(bytes),0,aface);

   if (errorface = 0) then
   begin

   try
    // Add it only if it's a TrueType or OpenType font
    // Type1 fonts also supported
    // Some truetype do not set scalable, so add all
    aobj:=FillLogFont(afilename2,0);
    // NOn scalable fonts not supported
    if (not aobj.scalable) then
     continue;

    if  Assigned(aobj) then
    begin
      if (Pos('CANTARELL',UpperCase(aobj.familyname))>0) then
      begin
        if ((not aobj.italic) and (not aobj.bold)) then
        begin
         defaultfont:=aobj;
        end
        else
        if ((not aobj.italic) and (aobj.bold)) then
        begin
         defaultfontb:=aobj;
        end
        else
        if ((aobj.italic) and (not aobj.bold)) then
        begin
          defaultfontit:=aobj;
        end
        else
        if ((aobj.italic) and (aobj.bold)) then
        begin
          defaultfontbit:=aobj;
        end;
      end;

      if (Pos('DROID',UpperCase(aobj.familyname))=0) then
      begin
      // Default font configuration, LUXI SANS is default
      if ((not aobj.italic) and (not aobj.bold)) then
      begin
       if not assigned(defaultfont) then
        defaultfont:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfont:=aobj;
        end;
       end;
       if (not assigned(defaultfont_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfont_arabic:=aobj;
       end;
      end
      else
      if ((not aobj.italic) and (aobj.bold)) then
      begin
       if not assigned(defaultfontb) then
        defaultfontb:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfontb:=aobj;
        end;
       end;
       if (not assigned(defaultfontb_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfontb_arabic:=aobj;
       end;
      end
      else
      if ((aobj.italic) and (not aobj.bold)) then
      begin
       if not assigned(defaultfontit) then
        defaultfontit:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfontit:=aobj;
        end;
       end;
       if (not assigned(defaultfontit_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfontit_arabic:=aobj;
       end;
      end
      else
      if ((aobj.italic) and (aobj.bold)) then
      begin
       if not assigned(defaultfontbit) then
        defaultfontbit:=aobj
       else
       begin
        if (UpperCase(aobj.familyname)='LUXI SANS') then
        begin
         defaultfontbit:=aobj;
        end;
       end;
       if (not assigned(defaultfontbit_arabic) and (Pos('ARABIC',UpperCase(aobj.familyname))>0)) then
       begin
        defaultfontbit_arabic:=aobj;
       end;
      end;
      end;

      fontlist.AddObject(UpperCase(aobj.familyname),aobj);
    end;
   finally
    FT_Done_Face(aface);
   end;
   end;
  end;
 end;
end;

constructor TRpFTInfoProvider.Create;
begin
 currentname:='';
 currentstyle:=0;
 crit:=TCriticalSection.Create;
end;


procedure FreeFontList;
var
 i:integer;
begin
 if assigned(fontlist) then
 begin
  for i:=0 to fontlist.count-1 do
  begin
   fontlist.Objects[i].free;
  end;
  fontlist.clear;
  fontlist.free;
  fontlist:=nil;
  fontpaths.free;
  fontfiles.free;
 end;
end;

destructor TRpFTInfoProvider.destroy;
begin
 crit.free;

 inherited destroy;
end;

function isSameFont(fontName,pattern: string): boolean;
begin
 if (pattern=fontName) then
 begin
  Result:=true;
 end
 else
 if ((pattern='HELVETICA') or (pattern='ARIAL')) then
 begin
  if (fontName='CANTARELL') then
  begin
   Result:=true;
  end
 end;
end;


function isSameFont2(fontName,pattern: string): boolean;
begin
 if (pattern=fontName) then
 begin
  Result:=true;
 end
 else
 if ((pattern='HELVETICA') or (pattern='ARIAL')) then
 begin
  if (fontName='NIMBUS SANS') then
  begin
   Result:=true;
  end
  else
  if (fontName='LIBERATION') then
  begin
   Result:=true;
  end
  else
  if (fontName='DEJAVU SANS') then
  begin
   Result:=true;
  end
  else
   Result:=false;
 end
 else
 Result:=false;
end;

procedure TRpFtInfoProvider.SelectFontFontConfig(pdffont: TRpPDFFont; unicodeContent: string = '');
begin
 SelectFontFontConfigInt(pdffont,unicodeContent,false);
 if (not currentFont.scalable) then
  SelectFontFontConfigInt(pdffont,unicodeContent,true)
end;


procedure TRpFtInfoProvider.SelectFontFontConfigInt(pdffont: TRpPDFFont; unicodeContent: string;removeFamily: boolean);
var
  Config: PFcConfig;
  Pattern: PFcPattern;
  Match: PFcPattern;
  FileNamePtr: PChar;
  StyleWeight: Integer;
  StyleSlant: Integer;
  filename: string;
  MatchKind: Integer;
  familyname:string;
  FontIndex:integer;
begin
  filename := '';

  // 1. Verificar si Fontconfig está disponible
  if not FontConfigAvailable then
    raise Exception.Create('No fontconfig installed');

  // 2. Obtener la configuración
  Config := FcConfigGetCurrent();

  // 3. Obtener el patrón de búsqueda
// 2. Crear el patrón de fuente usando el wrapper (FcCreatePattern)
  //    Esto construye el patrón con Family, Weight e Slant.
  familyName:=pdfFont.LFontName;
  if (familyName='Helvetica') then
  begin
    familyName:='Cantarell';
  end;
  if (removeFamily) then
    familyName:='';
  Pattern := rpfontconfig.FcCreatePattern(
    familyName,
    pdffont.Bold,
    pdffont.Italic,
    unicodeContent
  );
  if Pattern = nil then
    Exit; // No se pudo crear el patrón

  try
    // Este paso analiza FC_TEXT y sustituye FC_FAMILY (Helvetica) si no soporta el script.
    //if unicodeContent = '' then
      // Si NO hay contenido, solo sustituir a nivel de FUENTE (evita reemplazar Helvetica)
    //  MatchKind := FC_MATCH_FONT
    //else
      // Si hay contenido, sustituir a nivel de PATRÓN (para forzar el fallback de script/familia)
    MatchKind := FC_MATCH_PATTERN;
    // a) Sustitución predeterminada    FcDefaultSubstitute(Pattern);
     FcDefaultSubstitute(Pattern);
    // b) Sustitución de configuración (aplica reglas de idioma/script)
     FcConfigSubstitute(Config, Pattern, MatchKind); // FC_MATCH_PATTERN = 0
    // 4. Buscar la mejor fuente coincidente
    // La función devuelve el Match en el tercer parámetro (por referencia),
    // pero también lo devuelve como valor de la función si es exitoso.
    Match := FcFontMatch(Config, Pattern, Match);

    if Assigned(Match) then
    begin
      // 5. Extraer el nombre del archivo de la fuente seleccionada
      // El nombre del archivo es la propiedad FC_FILE (índice 0)
      FcPatternGetString(Match, PChar(FC_FILE), 0, FileNamePtr);
      // Verifica si el puntero de salida (la dirección de la cadena) es válido
      if Assigned(FileNamePtr) then
      begin
       // Asignación de la ruta de archivo solo si el puntero no es nil
       filename := UTF8ToString(string(FileNamePtr));
       FontIndex:=0;
       FcPatternGetInteger(Match, PChar(FC_INDEX), 0, FontIndex);
       currentfont:=GetOrAddLogFont(filename,FontIndex);
       if not assigned(currentFont.data) then
       begin
        currentfont.OpenFont;
        if not assigned(currentfont.data) then
        begin
          currentfont.data:=TRpTTFontData.Create;
          currentfont.data.fontdata:=TAdvFontData.Create;
          FillFontDataInt(currentfont.data);
        end;
       end;
      end;
   end;
  finally
    // 6. Limpiar: Liberar el patrón creado (el Match no se libera aquí)
    FcPatternDestroy(Pattern);
  end;
end;

procedure TRpFtInfoProvider.SelectFont(pdffont:TRpPDFFOnt;content: string;ignoreFamily: boolean);
var
 afontname:string;
 isbold:boolean;
 isitalic:boolean;
 i:integer;
 match:boolean;
 afont:TRpLogFont;
 currentFontName:string;
 stylestring:string;
begin
 crit.Enter;
 try
  InitLibrary;
(*{$IFDEF MSWINDOWS}
 afontname:=UpperCase(pdffont.WFontName);
{$ENDIF}
{$IFDEF LINUX}
 afontname:=UpperCase(pdffont.LFontName);
 if (Length(afontname)=0) then
  afontname:='Helvetica';
{$ENDIF}
*)
 afontname:=pdffont.GetFontFamily;
{$IFDEF LINUX}
 if (Length(afontname)=0) then
  afontname:='Helvetica';
{$ENDIF}

 if (FontConfigAvailable) then
 begin
  if (ignoreFamily) then
  begin
    SelectFontFontConfigInt(pdffont,content,true);
  end
  else
    SelectFontFontConfig(pdffont,content);

  exit;
 end;
 if (pdffont.bold and not pdffont.italic) then
 begin
  stylestring:=' bold ';
 end
 else
  if (pdffont.bold and pdffont.italic) then
  begin
   stylestring:=' bold italic ';
  end
  else
  if (pdffont.italic and not pdffont.bold) then
  begin
   stylestring:=' italic ';
  end
  else
   stylestring:=' regular ';
 WriteToStdError('Ask for font family: '+ afontName+ ' style: ' + stylestring+ chr(10));
 if ((currentname=afontname) and (currentstyle=pdffont.Style)) then
  exit;
 currentname:=afontname;
 currentstyle:=pdffont.Style;
 // Selects de font by font matching
 // First exact coincidence of family and style
 isbold:=(pdffont.style and 1)>0;
 isitalic:=(pdffont.style and (1 shl 1))>0;
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if isSameFont(currentFontName,afontname) then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
     WriteToStdError('Step 1: SameFont: FamilyName: '+fontlist.strings[i]+chr(10));
     break;
    end;
  end;
  inc(i);
 end;
 if match then
  exit;
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if isSameFont2(currentFontName,afontname) then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
     WriteToStdError('Step 2: SameFont: FamilyName: '+fontlist.strings[i]+chr(10));
     break;
    end;
  end;
  inc(i);
 end;
 if match then
  exit;
 // If not matching search for similar font name
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if Pos(afontname,currentFontName)>0 then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   if isitalic=afont.italic then
    if isbold=afont.bold then
    begin
     match:=true;
     currentfont:=afont;
     WriteToStdError('Step 3: SimilarFont: FamilyName: '+fontlist.strings[i]+chr(10));
     break;
    end;
  end;
  inc(i);
 end;
 if match then
  exit;
 // Ignoring styles
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  currentFontName:=fontlist.strings[i];
  if currentFontName=afontname then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   match:=true;
   currentfont:=afont;
   WriteToStdError('Step 4: SameFont ignoring styles: FamilyName: '+fontlist.strings[i]+chr(10));
   break;
  end;
  inc(i);
 end;
 if match then
  exit;
 // Ignoring styles partial match
 match:=false;
 i:=0;
 while i<fontlist.Count do
 begin
  if Pos(afontname,fontlist.strings[i])>0 then
  begin
   afont:=TRpLogFont(fontlist.Objects[i]);
   match:=true;
   WriteToStdError('Step 5: Partial ignoring styles: FamilyName: '+fontlist.strings[i]+chr(10));
   currentfont:=afont;
   break;
  end;
  inc(i);
 end;
 if match then
  exit;
 if (Pos('ARABIC',UpperCase(afontname))>0) then
 begin
  if ((not isbold) and (not isitalic)) then
  begin
   currentfont:=defaultfont_arabic;
   WriteToStdError('Default arabic regular '+currentfont.familyname+chr(10));
  end
  else
  if ((isbold) and (not isitalic)) then
  begin
   currentfont:=defaultfontb_arabic;
   WriteToStdError('Default arabic bold '+currentfont.familyname+chr(10));
  end
  else
  if ((not isbold) and (isitalic)) then
  begin
   currentfont:=defaultfontit_arabic;
   WriteToStdError('Default arabic italic '+currentfont.familyname+chr(10));
  end
  else
  begin
   currentfont:=defaultfontbit_arabic;
   WriteToStdError('Default arabic italic bold '+currentfont.familyname+chr(10));
  end;
 end;
 if (currentfont <> nil) then
  exit;
 // Finally gets default font, but applying styles
 if ((not isbold) and (not isitalic)) then
 begin
  currentfont:=defaultfont;
  WriteToStdError('Default regular '+currentfont.familyname+chr(10));
 end
 else
 if ((isbold) and (not isitalic)) then
 begin
  currentfont:=defaultfontb;
  WriteToStdError('Default bold '+currentfont.familyname+chr(10));
 end
 else
 if ((not isbold) and (isitalic)) then
 begin
  currentfont:=defaultfontit;
  WriteToStdError('Default italic '+currentfont.familyname+chr(10));
 end
 else
 begin
  currentfont:=defaultfontbit;
  WriteToStdError('Default bold italic '+currentfont.familyname+chr(10));
 end;

 if not assigned(currentfont) then
  Raise Exception.Create('No active font');
 finally
  crit.Leave;
 end;
end;


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

function TRpFtInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
begin
{$IFDEF LINUX_USEHARFBUZZ_SUBSETFONT}
 if HarfBuzzSubSetImplementation then
 begin
  Result:=GetFontStreamHarfBuzz(data);
 end
 else
 begin
  result:=GetFontStreamNative(data);
 end
{$ELSE}
  result:=GetFontStreamNative(data);
{$ENDIF}
end;

function TRpFtInfoProvider.GetFontStreamHarfBuzz(data: TRpTTFontData): TMemoryStream;
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
      //Result := TMemoryStream.Create;
      //Result.SetSize(data.FontData.FontData.Size);
      //Move(data.FontData.Fontdata.Memory^, Result.Memory^, data.FontData.FontData.Size);
      //Result.Position := 0;
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
         Result.SetSize(LongInt(outSize));
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

function  TRpFTInfoProvider.GetFontStreamNative(data: TRpTTFontData): TMemoryStream;
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
 // For type1 font returns all font stream
 if (data.type1 or (not data.TrueType)) then
 begin
   Result:=GetFullFontStream(data);
   exit;
 end;
     SetLength(bytes, data.FontData.FontData.Size);
     crit.Enter;
     try
      data.FontData.Fontdata.Seek(0, soFromBeginning);
      data.fontdata.FontData.ReadBuffer(bytes[0],data.fontdata.FontData.Size);
     finally
      crit.Leave;
     end;
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
     if (not data.type1) then
     begin
     // Create font subset in true type fonts
          subset := TTrueTypeFontSubSet.Create(data.PostcriptName, bytes,
                GlyphsUsed, data.FontData.DirectoryOffset);
     bytes := subset.Execute();
     end;
     Result:=TMemoryStream.Create;
     Result.SetSize(Int64(Length(bytes)));
     Result.Seek(0,soFromBeginning);
     Result.WriteBuffer(bytes[0],Length(bytes));
     Result.Seek(0,soFromBeginning);
end;

function  TRpFTInfoProvider.GetFullFontStream(data: TRpTTFontData): TMemoryStream;
begin
 Result:=data.FontData.Fontdata;
 Result.Position:=0;
end;


procedure TRpFTInfoProvider.FillFontDataInt(data:TRpTTFontData);
begin
 crit.Enter;
 try
  InitLibrary;
  // See if data can be embedded
  data.fontdata.FontData.Clear;
  data.filename:=currentfont.filename;
  //if not currentfont.type1 then
  data.fontdata.FontData.LoadFromFile(currentfont.filename);
  data.postcriptname:=currentfont.postcriptname;
  data.FamilyName:=currentfont.familyname;
  data.FaceName:=currentfont.familyname;
  data.Ascent:=currentfont.ascent;
  data.Descent:=currentfont.descent;
  data.Leading:=currentfont.leading;
  data.Height:=currentfont.height;
  data.capHeight:=currentfont.Capheight;
  data.Encoding:='WinAnsiEncoding';
  data.FontWeight:=0;
  data.MaxWidth:=currentfont.MaxWidth;
  data.AvgWidth:=currentfont.avCharWidth;
  data.havekerning:=currentfont.havekerning;
  data.StemV:=0;
  data.FontStretch:='/Normal';
  data.fdata:=currentfont;
  data.FontBBox:=currentfont.BBox;

  if currentfont.italic then
   data.ItalicAngle:=-15
  else
   data.ItalicAngle:=0;
  data.StyleName:=currentfont.stylename;
  data.Flags:=32;
  if (currentfont.fixedpitch) then
   data.Flags:=data.Flags+1;
  if currentfont.Bold then
   data.postcriptname:=data.postcriptname+',Bold';
  if currentfont.italic then
    data.Flags:=data.Flags+64;
  if currentfont.Italic then
  begin
   if currentfont.Bold then
    data.postcriptname:=data.postcriptname+'Italic'
   else
     data.postcriptname:=data.postcriptname+',Italic';
  end;
  data.Type1:=currentfont.Type1;
  data.truetype:=currentfont.truetype;
 finally
   crit.Leave;
 end;
end;



procedure TRpFTInfoProvider.FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData;content: string);
begin
 crit.Enter;
 try
  InitLibrary;
 finally
   crit.Leave;
 end;
  // See if data can be embedded
 SelectFont(pdffont, content,false);
 FillFontDataInt(data);
end;


function TRpFTInfoProvider.GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;
var
 awidth:double;
 aint:integer;
 width1,width2:word;
 cfont:TRpLogFont;
 dwidth:double;
 index:integer;
 ginfo: TGlyphInfo;
begin
 aint:=Ord(charcode);
 if aint>255 then
  data.isunicode:=true;
 if data.loaded[aint] then
 begin
  Result:=data.loadedwidths[aint];
 end
 else
 begin
  cfont:=TRpLogFont(data.fdata);
  cfont.OpenFont;
  data.UnitsPerEM:=currentFont.ftface.units_per_EM;
  if (data.UnitsPerEM = 0) then
   data.UnitsPerEM := 1000;
  if 0=FT_Load_Char(cfont.ftface,Cardinal(charcode),FT_LOAD_NO_SCALE) then
  begin
   width1:=word(cfont.ftface.glyph.linearHoriAdvance shr 16);
   width2:=word((cfont.ftface.glyph.linearHoriAdvance shl 16) shr 16);
   dwidth:=width1+width2/65535;
   awidth:=cfont.widthmult*dwidth;
  end
  else
   awidth:=0;
  data.loadedwidths[aint]:=awidth;
  data.loaded[aint]:=true;
  if data.firstloaded>aint then
   data.firstloaded:=aint;
  if data.lastloaded<aint then
   data.lastloaded:=aint;
  data.widths.Add(charcode,awidth);
  Result:=awidth;
  // Get glyph index
  index := FT_Get_Char_Index(cfont.ftface,Cardinal(charcode));
  data.glyphs.Add(charcode,index);
  if (not data.glyphsInfo.ContainsKey(index)) then
  begin
   ginfo.Glyph := index;
   ginfo.Width := awidth;
   ginfo.Char := charcode;
   data.glyphsInfo.Add(index,ginfo);
  end;
  data.loadedglyphs[aint]:=WideChar(index);
  data.loadedg[aint]:=true;
 end;
end;

function TRpFTInfoProvider.GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;
var
 awidth:double;
 width1,width2:word;
 cfont:TRpLogFont;
 dwidth:double;
 ginfo: TGlyphInfo;
begin
 if data.glyphsInfo.ContainsKey(glyph) then
 begin
  Result:=data.glyphsInfo[glyph].Width;
 end
 else
 begin
  cfont:=TRpLogFont(data.fdata);
  cfont.OpenFont;
  if (0 = FT_Load_Glyph(cfont.ftface,glyph,FT_LOAD_NO_SCALE)) then
  begin
   width1:=word(cfont.ftface.glyph.linearHoriAdvance shr 16);
   width2:=word((cfont.ftface.glyph.linearHoriAdvance shl 16) shr 16);
   dwidth:=width1+width2/65535;
   awidth:=cfont.widthmult*dwidth;
  end
  else
   awidth:=0;
  Result:=awidth;
  // Get glyph index
  if (not data.glyphsInfo.ContainsKey(glyph)) then
  begin
   ginfo.Glyph := glyph;
   ginfo.Width := Result;
   ginfo.Char := charC;
   data.glyphsInfo.Add(glyph,ginfo);
  end;
 end;
end;


function TRpFTInfoProvider.GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;
{$IFDEF USEKERNING}
var
 wl,wr:FT_UInt;
 akerning:FT_Vector;
 cfont:TRpLogFont;
{$ENDIF}
begin
{$IFNDEF USEKERNING}
  Result:=0;
  exit;
{$ENDIF}
{$IFDEF USEKERNING}
 REsult:=0;
 cfont:=TRpLogFont(data.fdata);
 if cfont.havekerning then
 begin
  cfont.OpenFont;
  wl:=FT_Get_Char_Index(cfont.ftface,Cardinal(leftchar));
  if wl>0 then
  begin
   wr:=FT_Get_Char_Index(cfont.ftface,Cardinal(rightchar));
   if wr>0 then
   begin
    CheckFreeType(FT_Get_Kerning(cfont.ftface,wl,wr,FT_KERNING_UNSCALED,akerning));
    result:=Round(cfont.widthmult*-akerning.x);
   end;
  end;
 end;
{$ENDIF}
end;

constructor TRpLogFont.Create;
begin
 faceinit:=false;
end;

destructor TRpLogFont.Destroy;
begin
 if faceinit then
  CheckFreeType(FT_Done_Face(ftface));
 inherited destroy;
end;

procedure TRpLogFont.OpenFont;
var
 kerningfile:string;
 filename2:AnsiString;
begin
 if faceinit then
  exit;
 filename2:=filename;
 CheckFreeType(FT_New_Face(ftlibrary,PAnsiChar(filename2),0,ftface));
 faceinit:=true;
 if type1 then
 begin
  // Check for kening file for type1 font
  kerningfile:=ChangeFileExt(filename,'.afm');
  if FileExists(kerningfile) then
  begin
   CheckFreeType(FT_Attach_File(ftface,PAnsichar(kerningfile)));
  end;
 end;
 // Don't need scale, but this is a scale that returns
 // exact width for pdf if you divide the result
 // of Get_Char_Width by 64
 if (scalable) then
   CheckFreeType(FT_Set_Char_Size(ftface,0,64*100,720,720));
end;


initialization
 fontlist:=nil;
 initialized:=false;
 InitializeFontCache;
finalization
 FinalizeFontCache;
 FreeFontList;
 if initialized then
  FT_Done_FreeType(ftlibrary);
end.

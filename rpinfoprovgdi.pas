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

uses Classes,SysUtils,Windows,rpinfoprovid,SyncObjs,rptypes,
{$IFDEF DOTNETD}
 System.Runtime.InteropServices,
{$ENDIF}
 rpICU,rpHarfBuzz,
    rpmdconsts,rpfreetype2, rptruetype, System.Generics.Collections;

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
  function NFCNormalize(astring:WideString):string;override;
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;override;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;override;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;override;
  function  GetFontStream(data: TRpTTFontData): TMemoryStream;override;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;override;
  function TextExtent(const Text:WideString;
     var Rect:TRect;adata: TRpTTFontData;pdfFOnt:TRpPDFFont;
     wordbreak:boolean;singleline:boolean;FontSize:double): TRpLineInfoArray;override;
  function CalcGlyphhPositions(astring:WideString;adata:TRpTTFontData;pdffont:TRpPDFFont;direction: TRpBiDiDirection;
    script: string;FontSize:double):TGlyphPosArray;
  constructor Create;
  destructor Destroy;override;
 end;

 var
  ftlibrary:FT_Library;
  initialized:boolean = false;

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
begin
  if S = '' then
    Exit('');

  // 1) pedir tamaño (incluye terminador)
  requiredChars := NormalizeString(NormalizationC, PWideChar(S), -1, nil, 0);
  if requiredChars = 0 then
    RaiseLastOSError;

  // reservar buffer (requiredChars incluye espacio para el terminador)
  SetLength(Result, requiredChars);

  // 2) normalizar — writtenChars no incluye el terminador
  writtenChars := NormalizeString(NormalizationC, PWideChar(S), -1, PWideChar(Result), requiredChars);
  if writtenChars = 0 then
    RaiseLastOSError;

  // ajustar la longitud real (writtenChars es el nº de caracteres útiles, sin el NUL)
  SetLength(Result, writtenChars);
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

  if (not initialized) then
  begin
   CheckFreeTypeLoaded;
   CheckFreeType(FT_Init_FreeType(ftlibrary));
   InitICU;
   InitHarfBuzz;
   initialized:=true;
  end;
end;


function TRpGDIInfoProvider.TextExtent(const Text: WideString;
  var Rect: TRect; adata: TRpTTFontData; pdfFont: TRpPDFFont;
  wordbreak: boolean; singleline: boolean; FontSize: double): TRpLineInfoArray;
var
  Bidi: TICUBidi;
  Runs: TList<TBidiRun>;
  r: TBidiRun;
  astring: string;
  i, runIndex: Integer;
  scale: Double;
  positions: TGlyphPosArray;
  posX, posY: Double;
  gidHex: string;
  glyphIndex: Integer;
  absX, absY: Double;
  subText: string;
  cursorAdvance: Double;

  // line building
  lines: TRpLineInfoArray;
  curLine: TRpLineInfo;
  curLineGlyphs: TGlyphPosArray;
  curLineStartLogicalIndex: Integer;
  curLineChars: Integer;
  curLineWidth: Double;
  curLineHeight: Double;
  totalHeight: Double;
  maxLineWidth: Double;
  origWidth: Double;
  emptyStep: TRpFontStep;
  possibleBreakNext: Integer;
  canBreakHere: Boolean;
  // helper to push current line to lines array
  procedure FlushCurrentLine(isLast: Boolean);
  var
    idx: Integer;
  begin
    if curLineChars = 0 then
      Exit; // nothing to push
    idx := Length(lines);
    SetLength(lines, idx + 1);
    curLine.Glyphs := Copy(curLineGlyphs, 0, Length(curLineGlyphs));
    curLine.Position := curLineStartLogicalIndex;
    curLine.Size := curLineChars;
    curLine.Width := Round(curLineWidth); // store integer width
    curLine.height := Round(curLineHeight);
    curLine.TopPos := Round(posY+idx*curLineHeight);
    curLine.lastline := isLast;
    curLine.LineHeight := curLineHeight;
    curLine.step := emptyStep;
    lines[idx] := curLine;

    // update totals
    totalHeight:=totalHeight + Round(curLineHeight);
    if curLineWidth > maxLineWidth then
      maxLineWidth := curLineWidth;

    // prepare for next line
    posY := posY + curLineHeight;
    cursorAdvance := 0;
    curLineChars := 0;
    curLineWidth := 0;
    SetLength(curLineGlyphs, 0);
  end;

begin

  SetLength(Result, 0);
  SetLength(lines, 0);
  posX := 0;
  posY := 0;
  cursorAdvance := 0;
  maxLineWidth := 0;
  totalHeight := 0;
  curLineChars := 0;
  curLineStartLogicalIndex := 0;
  curLineWidth := 0;

  // salvar original width
  origWidth := Rect.Right - Rect.Left;

  // initialize empty step
  FillChar(emptyStep, SizeOf(emptyStep), 0);

  // básico: line height estimado (puedes cambiar la fórmula si tienes métricas)
  // He tomado un multiplicador típico de 1.2 * FontSize. Ajusta si tienes métricas reales.
  curLineHeight := FontSize * 1*20;

  //scale := FontSize / 14 / 72*20; // Scale to twips
  //scale := FontSize / 14 / 72*20; // Scale to twips
  scale:=1;

  // get visual runs (tal como ya hacías)
  astring := Text;
  Bidi := TICUBidi.Create;
  Runs := nil;
  try
    if Bidi.SetPara(astring, 2) then
      Runs := Bidi.GetVisualRuns(astring)
    else
      raise Exception.Create('VisualRuns error');
  finally
    Bidi.Free;
  end;

  // recorrer runs -> glyphs
  for runIndex := 0 to Runs.Count - 1 do
  begin
    r := Runs[runIndex];
    subText := Copy(astring, r.LogicalStart + 1, r.Length);
    positions := CalcGlyphhPositions(subText, adata, pdfFont, TRpBidiDirection(r.Direction), r.ScriptString, FontSize);

    // iniciar línea si está vacía
    if curLineChars = 0 then
      curLineStartLogicalIndex := r.LogicalStart; // aproximado al inicio del run

    for i := 0 to High(positions) do
    begin
      var gl: TGlyphPos;
      gl := positions[i];
      // Tratamiento saltos de linea
      if (gl.CharCode = chr(13)) then
      begin
        continue;
      end;
      if (gl.CharCode = chr(10)) then
      begin
        FlushCurrentLine(false);
        continue;
      end;
      // posibilidad de break explícito provisto por getvisualruns
      possibleBreakNext := -1;
      canBreakHere := False;
      try
        if Assigned(r.LineBreaks) and r.LineBreaks.TryGetValue(i, possibleBreakNext) then
          canBreakHere := True
        else if wordbreak and (i < Length(subText)) and (subText[i + 1] = ' ') then
          // si wordbreak y el carácter actual es espacio, permitimos romper después
          canBreakHere := True;
      except
        canBreakHere := False;
      end;

      // calcular advance y offsets escalados
      // guardamos la posición del glyph relativa al inicio de la línea.


      // scaled advance / offsets
      var advX := positions[i].XAdvance * scale;
      var offX := positions[i].XOffset * scale;
      var offY := positions[i].YOffset * scale;

      // si no singleline, comprobar si cabe en el ancho actual del rect
      if (not singleline) and (Round(cursorAdvance + advX) > origWidth) then
      begin
        // intentar romper en un punto anterior permitido si existe (simple heuristic)
        if canBreakHere then
        begin
          // flush current line and start new
          FlushCurrentLine(False);
          // después de break, cur line empty; cursorAdvance already reset in Flush
        end
        else
        begin
          // no break permitido en este punto: forzamos salto de línea antes del glyph actual
          FlushCurrentLine(False);
        end;
      end;

      // añadir glyph a la línea actual (con coordenadas relativas)
      // guardamos offsets y advances escalados transformando a enteros como estaban en tu estructura
      // mantengo los campos en unidades escaladas * 1 (double->integer) redondeando
      SetLength(curLineGlyphs, Length(curLineGlyphs) + 1);
      var idxG := High(curLineGlyphs);
      curLineGlyphs[idxG].GlyphIndex := positions[i].GlyphIndex;
      curLineGlyphs[idxG].XOffset := Round(offX);
      curLineGlyphs[idxG].YOffset := Round(offY);
      curLineGlyphs[idxG].XAdvance := Round(positions[i].XAdvance * scale);
      curLineGlyphs[idxG].YAdvance := Round(positions[i].YAdvance * scale);
      // Cluster/CharCode: intentamos mapear cluster a carácter relativo en el subText
      curLineGlyphs[idxG].Cluster := positions[i].Cluster+1;
      if (i < Length(subText)) then
        curLineGlyphs[idxG].CharCode := subText[i + 1]
      else
        curLineGlyphs[idxG].CharCode := WideChar(0);

      // actualizar contadores de línea
      curLineChars := curLineChars + 1;
      curLineWidth := cursorAdvance + curLineGlyphs[idxG].XAdvance;
      cursorAdvance := cursorAdvance + curLineGlyphs[idxG].XAdvance;

      // Si la posición actual es un posible break *y* cabe en la línea, podemos opcionalmente romper
      if (not singleline) and canBreakHere and (Round(cursorAdvance) <= origWidth) then
      begin
        // romper opcionalmente si la siguiente palabra no cabrá? lo hacemos conservador: si el siguiente glyph no cabe
        if (i < High(positions)) then
        begin
          var nextAdv := positions[i + 1].XAdvance * scale;
          if Round(cursorAdvance + nextAdv) > origWidth then
          begin
            // romper aquí
            FlushCurrentLine(False);
          end;
        end;
      end;
    end; // for glyphs

    // Fin del run: continuar con siguiente run (no forzamos break entre runs)
  end; // for runs

  // flush última línea (si quedó algo)
  FlushCurrentLine(True);

  // construir el resultado
  Result := lines;

  // actualizar Rect: ancho = máximo ancho usado, alto = suma alturas
  // ten en cuenta que Rect.Left/Top se mantienen
  if maxLineWidth < 0 then
    maxLineWidth := 0;
  if totalHeight < Round(curLineHeight) then
    totalHeight := Round(curLineHeight); // al menos una línea

  Rect.Right := Rect.Left + Round(maxLineWidth);
  Rect.Bottom := Rect.Top + Round(totalHeight);

  // Si singleline = true y no hubo saltos, nos aseguramos de devolver ancho original si querías
  // conservar origWidth aparte, lo guardas tú donde estimes conveniente.
end;


function TRpGDIInfoProvider.CalcGlyphhPositions(
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
    CheckFreeType(FT_Set_Char_Size(shapedata.FreeTypeFace, 0, 64 * 100, 1440, 1440));
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


function TRpGDIInfoProvider.NFCNormalize(astring:WideString):string;
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


function  TRpGDIInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
var
 subset:TTrueTypeFontSubSet;
 bytes:TBytes;
 GlyphsUsed: TDictionary<Integer, TArray<Integer>>;
 xchar: WideChar;
 ints: TArray<Integer>;
 intChar: Integer;
 glyph: Integer;
 ginfo: TGlyphInfo;
begin
     SetLength(bytes, data.FontData.FontData.Size);
     data.fontdata.FontData.ReadBuffer(bytes[0],data.fontdata.FontData.Size);
     GlyphsUsed:=TDictionary<Integer, TArray<Integer>>.Create;
     for ginfo in data.glyphsInfo.Values do
     begin
      intChar:=Integer(ginfo.Char);
      glyph:=ginfo.Glyph;
      if (not GlyphsUsed.ContainsKey(glyph)) then
      begin
       SetLength(ints, 3);
       ints[0]:=glyph;
       ints[1]:=Round(ginfo.Width);
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

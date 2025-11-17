{*******************************************************}
{                                                      }
{       Report Manager                                  }
{                                                       }
{       TRpInfoProvider  Base class                     }
{       Provides information about fonts and bitmaps    }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{                                                       }
{*******************************************************}

unit rpinfoprovid;


interface

{$I rpconf.inc}

uses Classes,SysUtils,
{$IFDEF USEVARIANTS}
 Types,
{$ENDIF}
{$IFNDEF USEVARIANTS}
 Windows,
{$ENDIF}
 rptypes, System.Generics.Collections;

type
 TWinAnsiWidthsArray=array [32..255] of integer;
 PWinAnsiWidthsArray= ^TWinAnsiWidthsArray;

 TRpPDFFont=class(TObject)
  public
   Name:TRpType1Font;
   WFontName:WideString;
   LFontName:WideString;
   fontname:String;
   Size:integer;
   Color:integer;
   Style:Integer;
   Italic:Boolean;
   Underline:boolean;
   Bold:boolean;
   StrikeOut:boolean;
   Transparent:boolean;
   BackColor:Integer;
   constructor Create;
  end;


 TAdvFontData=class(TObject)
  public Fontdata:TMemoryStream;
	public DirectoryOffset: integer;
  constructor Create;
  destructor Destroy;
 end;
  TGlyphInfo=record
   Glyph: Integer;
   Char:char;
   Width: double;
 end;



 TRpTTFontData=class(TObject)
  embedded:Boolean;
  postcriptname:String;
  Encoding:String;
  Ascent,Descent,Leading,CapHeight,Flags,FontWeight:integer;
  MaxWidth:integer;
  AvgWidth:integer;
  StemV:double;
  FontFamily:String;
  FontStretch:String;
  ItalicAngle:double;
  FontBBox:TRect;
  FamilyName:String;
  FullName:String;
  FaceName:String;
  StyleName:String;
  type1:boolean;
  truetype:boolean;
  havekerning:Boolean;
  ObjectName:String;
  ObjectIndex:integer;
  ObjectIndexParent:integer;
  DescriptorIndex:Integer;
  ToUnicodeIndex:Integer;
//CIDToGIDMapIndex: Integer;
  loadedkernings:array [0..65535] of TStringList;
  loadedglyphs:array [0..65535] of WideChar;
  loadedg:array [0..65535] of boolean;
  loadedk:array [0..65535] of boolean;
  loadedwidths:array [0..65535] of double;
  loaded:array [0..65535] of boolean;
	glyphs:TDictionary<char, integer>;
	glyphsInfo:TDictionary<integer, TGlyphInfo>;
	widths:TDictionary<char, double>;
  fdata:TObject;
  firstloaded,lastloaded:integer;
  kerningsadded:TStringList;
  IsUnicode:boolean;
  FontData: TAdvFontData;
  filename: string;
  UnitsPerEM: double;
  FontIndex: Integer;
  LoadedFace:boolean;
  CustomImplementation:TObject;
  constructor Create;
  destructor Destroy;override;
 end;

 TRpBiDiDirection = (
    RP_BIDI_LTR = 0,
    RP_UBIDI_RTL = 1,
    RP_UBIDI_MIXED = 2
  );
  TRpTextMeasurement=record
    public LineInfo:array of TRpLineInfo;
    public TotalHeight: double;
    public TotalWidth: double;
  end;

 TRpInfoProvider=class(TObject)
  procedure FillFontData(pdffont:TRpPDFFont;data:TRpTTFontData);virtual;abstract;
  function TextExtent(const Text:WideString;
     var Rect:TRect;adata: TRpTTFontData;pdfFOnt:TRpPDFFont;
     wordbreak:boolean;singleline:boolean;FontSize:double): TRpLineInfoArray;virtual;abstract;
  function NFCNormalize(astring:WideString):WideString;virtual;abstract;
  function GetCharWidth(pdffont:TRpPDFFont;data:TRpTTFontData;charcode:widechar):double;virtual;abstract;
  function GetGlyphWidth(pdffont:TRpPDFFont;data:TRpTTFontData;glyph:Integer;charC: widechar):double;virtual;abstract;
  function GetKerning(pdffont:TRpPDFFont;data:TRpTTFontData;leftchar,rightchar:widechar):integer;virtual;abstract;
  function GetFontStream(data: TRpTTFontData): TMemoryStream;virtual;abstract;
  function GetFullFontStream(data: TRpTTFontData): TMemoryStream;virtual;abstract;
 end;

  TLineGlyphs=class
  public
   Glyphs:TList<TGlyphPos>;
   MinClusterText: integer;
   MaxClusterText: integer;
   MinClusterLine: integer;
   MaxClusterLine: integer;
   Offset:integer;
   ClusterMap: TDictionary<Integer, TList<Integer>>;
   constructor Create(TextOffset: integer);
   destructor Destroy;
   procedure AddGlyph(g: TGlyphPos;rOffset: integer);
 end;

type
 TLineSubText=record
  public
   Position:integer;
   Length: integer;
 end;


function BreakChunksRTL(
  const positions: TGlyphPosArray;
  lineWidthLimit: Double;
  const possibleBreaksCharIdx: TDictionary<Integer,Integer>;Text: string
): TList<TGlyphPosArray>;

function BreakChunksLTR(
  const positions: TGlyphPosArray;
  lineWidthLimit: Double;
  const possibleBreaksCharIdx: TDictionary<Integer,Integer>;Text:string
): TList<TGlyphPosArray>;

function DividesIntoLines(const text: string): TList<TLineSubText>;

implementation



function DividesIntoLines(const text: string): TList<TLineSubText>;
var
  i, lineStart, lineEnd: Integer;
  c: Char;
  lb: TLineSubText;
begin
  Result := TList<TLineSubText>.Create;
  if text = '' then
    Exit;

  lineStart := 1;
  i := 1;
  while i <= Length(text) do
  begin
    c := text[i];
    if c in [#10, #13] then
    begin
      // línea encontrada
      lineEnd := i - 1;
      lb.Position := lineStart;
      lb.Length := lineEnd - lineStart + 1;
      Result.Add(lb);

      // saltos de línea: manejar CR+LF como uno solo
      if (c = #13) and (i < Length(text)) and (text[i + 1] = #10) then
        Inc(i);

      lineStart := i + 1;
    end;
    Inc(i);
  end;
  // agregar última línea si no termina en salto
  if lineStart <= Length(text) then
  begin
    lb.Position := lineStart;
    lb.Length := Length(text) - lineStart + 1;
    Result.Add(lb);
  end;
end;




constructor TLineGlyphs.Create(TextOffset:integer);
begin
  Offset:=TextOffset;
  Glyphs:=TList<TGlyphPos>.Create;
  MinClusterText:=MaxInt;
  MaxClusterText:=-1;
  MinClusterLine:=MaxInt;
  MaxClusterLine:=-1;
  ClusterMap:=TDictionary<Integer, TList<Integer>>.Create;
end;

destructor TLineGlyphs.Destroy;
begin
  Glyphs.free;
  ClusterMap.Free;
  inherited;
end;

procedure TLineGlyphs.AddGlyph(g: TGlyphPos;rOffset: integer);
var
  lst: TList<Integer>;
begin
 Glyphs.Add(g);
 if (g.Cluster+Offset+rOffset<MinClusterText) then
  MinClusterText:=g.Cluster+Offset+rOffset;
 if (g.Cluster+Offset+rOffset>MaxClusterText) then
  MaxClusterText:=g.Cluster+Offset+rOffset;
 if (g.Cluster+rOffset<MinClusterLine) then
  MinClusterLine:=g.Cluster+rOffset;
 if (g.Cluster+rOffset>MaxClusterLine) then
  MaxClusterLine:=g.Cluster+rOffset;

 // Asignar ChunkCluster usando el diccionario
 if not ClusterMap.TryGetValue(g.LineCluster, lst) then
 begin
  lst := TList<Integer>.Create;
  ClusterMap.Add(g.LineCluster, lst);
 end;
 lst.Add(Glyphs.Count-1);
end;


constructor TRpTTFontData.Create;
begin
 inherited Create;

 kerningsadded:=TStringList.Create;
 kerningsadded.sorted:=true;
 firstloaded:=65536;
 lastloaded:=-1;
 glyphs:=TDictionary<char, integer>.Create;
 widths:=TDictionary<char, double>.Create;
 glyphsInfo:=TDictionary<integer, TGlyphInfo>.Create;
end;

destructor TRpTTFontData.Destroy;
var
 i:integer;
begin
 for i:=0 to kerningsadded.count-1 do
 begin
  loadedkernings[StrToInt(kerningsadded.Strings[i])].Free;
 end;
 kerningsadded.free;

 if Assigned(fontData) then
 begin
  // fontData.Free;
 end;
 
 inherited;
end;

constructor TrpPdfFont.Create;
begin
 inherited Create;

 Name:=poCourier;
 Size:=10;
end;

constructor TAdvFontData.Create;
begin
 Fontdata:=TMemoryStream.Create;
end;

destructor TAdvFontData.Destroy;
begin
 Fontdata.free;
end;


// ---------------------------
// BreakChunksLTR
//  - positions: glyphs in visual order (L->R for this run)
//  - lineWidthLimit: max width per line
//  - possibleBreaksCharIdx: keys = character indices in the subText (0-based)
// Returns array of chunks in left->right order (first chunk is leftmost).
// ---------------------------
function BreakChunksLTR(
  const positions: TGlyphPosArray;
  lineWidthLimit: Double;
  const possibleBreaksCharIdx: TDictionary<Integer,Integer>;Text:string
): TList<TGlyphPosArray>;
var
  chunks: TList<TGlyphPosArray>;
  startIdx, j, chunkEnd, k: Integer;
  acc: Double;
  lastBreakGlyphIdx: Integer;
  chunk: TGlyphPosArray;
  // helper: check if glyph j matches any char-index break
  function GlyphHasBreak(j: Integer): Boolean;
  var
    charIdx: Integer;
  begin
    Result := False;
    if possibleBreaksCharIdx = nil then Exit;
    // positions[j].Cluster assumed 0-based char index in subText
    charIdx := positions[j].LineCluster - 1;
    // if your Cluster is 1-based uncomment: // charIdx := positions[j].Cluster - 1;
    Result := possibleBreaksCharIdx.ContainsKey(charIdx);
    if (not Result) then
    begin
     Result:=(Text[charIdx+1]=' ') or (Text[charIdx+1]=chr(10));
    end;
  end;
begin
  chunks := TList<TGlyphPosArray>.Create;

    if Length(positions) = 0 then
    begin
      Result := chunks;
      Exit;
    end;

    startIdx := 0;
    while startIdx <= High(positions) do
    begin
      acc := 0.0;
      lastBreakGlyphIdx := -1;
      j := startIdx;
      while j <= High(positions) do
      begin
        acc := acc + positions[j].XAdvance;
        if GlyphHasBreak(j) then
          lastBreakGlyphIdx := j;
        if acc > lineWidthLimit then
          Break;
        Inc(j);
      end;

      if j > High(positions) then
        // everything from startIdx..High fits
        chunkEnd := High(positions)
      else
      begin
        if lastBreakGlyphIdx <> -1 then
          chunkEnd := lastBreakGlyphIdx
        else
        begin
          if j = startIdx then
            chunkEnd := j // single glyph too big -> take it
          else
            chunkEnd := j - 1;
        end;
      end;

      SetLength(chunk, chunkEnd - startIdx + 1);
      k := 0;
      for j := startIdx to chunkEnd do
      begin
        chunk[k] := positions[j];
        Inc(k);
      end;
      chunks.Add(chunk);

      startIdx := chunkEnd + 1;
    end;

    Result := chunks;

end;

// ---------------------------
// BreakChunksRTL
//  - positions: glyphs in visual order (L->R for this run) BUT we split from the right
//  - lineWidthLimit: max width per line
//  - possibleBreaksCharIdx: keys = character indices in the subText (0-based)
// Returns array of chunks in right->left order: chunks[0] is the rightmost chunk (fits current line).
// ---------------------------
function BreakChunksRTL(
  const positions: TGlyphPosArray;
  lineWidthLimit: Double;
  const possibleBreaksCharIdx: TDictionary<Integer,Integer>;Text:string
): TList<TGlyphPosArray>;
var
  chunks: TList<TGlyphPosArray>;
  endIdx, j, chunkStart, k: Integer;
  acc: Double;
  lastBreakGlyphIdx: Integer;
  chunk: TGlyphPosArray;
  // helper: check if glyph j matches any char-index break
  function GlyphHasBreak(j: Integer): Boolean;
  var
    charIdx: Integer;
  begin
    Result := False;
    if possibleBreaksCharIdx = nil then Exit;
    charIdx := positions[j].LineCluster-1;
    // if your Cluster is 1-based uncomment: // charIdx := positions[j].Cluster - 1;
    Result := possibleBreaksCharIdx.ContainsKey(charIdx);
    if (not Result) then
    begin
     Result:=(Text[charIdx+1]=' ') or (Text[charIdx+1]=chr(10));
    end;
  end;
begin
  chunks := TList<TGlyphPosArray>.Create;
    if Length(positions) = 0 then
    begin
      Result := chunks;
      Exit;
    end;

    endIdx := High(positions);
    while endIdx >= 0 do
    begin
      acc := 0.0;
      lastBreakGlyphIdx := -1;
      j := endIdx;
      while j >= 0 do
      begin
        acc := acc + positions[j].XAdvance;
        if GlyphHasBreak(j) then
          lastBreakGlyphIdx := j;
        if acc > lineWidthLimit then
          Break;
        Dec(j);
      end;

      if j < 0 then
        chunkStart := 0
      else
      begin
        if lastBreakGlyphIdx <> -1 then
          chunkStart := lastBreakGlyphIdx
        else
        begin
          if j = endIdx then
            chunkStart := j
          else
            chunkStart := j + 1;
        end;
      end;

      SetLength(chunk, endIdx - chunkStart + 1);
      k := 0;
      for j := chunkStart to endIdx do
      begin
        chunk[k] := positions[j];
        Inc(k);
      end;
      chunks.Add(chunk);

      endIdx := chunkStart - 1;
    end;

    Result := chunks;

end;




end.

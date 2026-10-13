{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       TRpInfoProvider Core Text                       }
{       Provides information about fonts in macOS       }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpinfoprovct;

{ The text provider of macOS (FPC, Darwin) over Core Text, the text engine of
  the system, as rpinfoprovgdi is over DirectWrite on Windows: the same engine
  chooses the font, measures and lays out the text and (lcl/rplcldriver)
  paints it. See docs/coretext_provider_plan.md.

  - A font of the report is its LFontName (as the FreeType provider on Linux
    and macOS), or its WFontName when the system lacks the first and has the
    second (RpCTBaseFontName), with bold and italic: a Core Text family plus the symbolic
    traits (a PostScript or full name of a face is accepted too: "Helvetica"
    is both a family and the PostScript name of its regular face, so the
    family goes first). The substituted runs of a Core Text line carry
    CRpCTFaceMark and the PostScript name of their face in
    TGlyphPos.FontFamily: that exact face, without the style of the text
    (their nameID 1 can be localized, "蘋方-簡", or lack the weight,
    "Helvetica Neue" for Helvetica Neue Light).
  - Metrics and widths in thousandths of an em, as the other providers: a
    CTFont of size 1000 per face. Ascent, descent and height from the hhea
    table and then OS/2 as DirectWrite does (TRpFTInfoProvider.FillFontDataInt),
    but from the tables of this face: in a collection (.ttc) the FreeType
    provider reads the header of the collection and misses OS/2.
  - Embedding: inherited from TRpFTInfoProvider (subset of HarfBuzz over the
    font file and the index of the face), so the PDF embeds as it did. The
    index of a face inside a .ttc is found by its PostScript name in the
    name table of every face of the file.

  - TextExtent (shaping, bidi, HTML, substitution of fonts, line breaks):
    CTTypesetter, see the comment above its implementation. }

interface

{$I rpconf.inc}

{$IFDEF DARWIN}
uses
  Classes, SysUtils, SyncObjs, Generics.Collections, MacOSAll, Types,
  rptypes, rpinfoprovid, rpinfoprovft;

type
  { One face of a font file, resolved by Core Text }
  TRpCTFace = class(TObject)
  public
    Font: CTFontRef;            // size 1000: advances in thousandths of an em
    PostScriptName: string;
    FamilyName: string;
    StyleName: string;
    FileName: string;
    FaceIndex: Integer;         // inside a collection (.ttc), 0 otherwise
    DirectoryOffset: Cardinal;  // of its table directory in the file
    FaceFound: Boolean;         // False: the face was not found in its file
    // A named instance of a variable face (fvar): the value of each axis
    // (tag, as 'wght'), to embed that instance and not the default one
    Variable: Boolean;
    AxisTags: array of Cardinal;
    AxisValues: array of Double;
    UnitsPerEm: Integer;
    Bold, Italic, FixedPitch: Boolean;
    TrueType, CFF: Boolean;
    // Outlines a PDF can embed: glyf or CFF, not the hvgl of Apple (PingFang
    // in macOS 15) nor CFF2
    Embeddable: Boolean;
    // The substitution list of Core Text for this face without the faces
    // that cannot be embedded (kCTFontCascadeListAttribute); nil until used
    Cascade: CTFontDescriptorRef;
    CascadeBuilt: Boolean;
    Ascent, Descent, Height, Leading, CapHeight, MaxWidth: Integer;
    BBox: TRect;
    HasKerning: Boolean;
    // Pairs of the kern table (format 0): (left shl 16) or right -> value in
    // font units; loaded on first use
    Kernings: TDictionary<Cardinal, SmallInt>;
    KerningsLoaded: Boolean;
    destructor Destroy; override;
  end;

  TRpCTInfoProvider = class(TRpFTInfoProvider)
  private
    function ResolveFace(pdffont: TRpPDFFont): TRpCTFace;
    procedure LoadKernings(AFace: TRpCTFace);
  public
    procedure FillFontData(pdffont: TRpPDFFont; data: TRpTTFontData; content: string); override;
    function NFCNormalize(astring: WideString): WideString; override;
    function GetCharWidth(pdffont: TRpPDFFont; data: TRpTTFontData; charcode: System.WideChar): double; override;
    function GetGlyphWidth(pdffont: TRpPDFFont; data: TRpTTFontData; glyph: Integer; charC: System.WideChar): double; override;
    function GetKerning(pdffont: TRpPDFFont; data: TRpTTFontData; leftchar, rightchar: System.WideChar): integer; override;
    // A named instance of a variable TrueType face is embedded as that
    // instance (the axes pinned); the rest as the FreeType provider does
    function GetFontStream(data: TRpTTFontData): TMemoryStream; override;
    function TextExtent(const Text: WideString; var Rect: TRect; adata: TRpTTFontData;
      pdfFont: TRpPDFFont; wordwrap: Boolean; singleline: Boolean; FontSize: Double;
      IsHtml: Boolean; RightToLeft: Boolean): TRpLineInfoArray; override;
  end;

const
  // Before a PostScript name in TGlyphPos.FontFamily: the exact face Core
  // Text substituted in a run ("@PingFangSC-Regular"), not a family to which
  // the style of the text is applied
  CRpCTFaceMark = '@';

// The face Core Text gives for a family (or a PostScript or full name of a
// face) and style, or for CRpCTFaceMark + a PostScript name; it stays in a
// cache shared by every provider. nil when Core Text gives none.
function RpCTFace(const AName: string; ABold, AItalic: Boolean): TRpCTFace;

// The font of an object: LFontName when the system has it, else WFontName
// when it has that one ("Noto Naskh Arabic" for Linux and "Noto Sans Arabic"
// for Windows), else LFontName for Core Text to choose (its default font)
function RpCTBaseFontName(const ALFontName, AWFontName: WideString): string;
{$ENDIF}

implementation

{$IFDEF DARWIN}

uses
  Math, dynlibs, rphtmlparser, rpHarfBuzz;

{$linkframework CoreText}

var
  GFaces: TObjectDictionary<string, TRpCTFace>;   // owns the faces
  GRequests: TDictionary<string, TRpCTFace>;      // request -> face
  GKnown: TDictionary<string, Boolean>;           // name -> the system has it
  GLock: TCriticalSection;

function CFStr(const S: string): CFStringRef;
begin
  Result := CFStringCreateWithCString(nil, PChar(UTF8String(S)), kCFStringEncodingUTF8);
end;

function PasStr(S: CFStringRef): string;
var
  len, size: CFIndex;
  buf: UTF8String;
begin
  Result := '';
  if S = nil then
    Exit;
  len := CFStringGetLength(S);
  size := CFStringGetMaximumSizeForEncoding(len, kCFStringEncodingUTF8) + 1;
  SetLength(buf, size);
  if CFStringGetCString(S, PChar(buf), size, kCFStringEncodingUTF8) then
    Result := string(PChar(buf));
end;

// The string, released
function TakeStr(S: CFStringRef): string;
begin
  Result := PasStr(S);
  if S <> nil then
    CFRelease(S);
end;

{ Big-endian readers of a table copied by CTFontCopyTable }

type
  TRpTable = record
    Data: CFDataRef;
    P: PByte;
    Len: Integer;
    function Valid(AOff, ASize: Integer): Boolean;
    function U16(AOff: Integer): Word;
    function S16(AOff: Integer): SmallInt;
    function U32(AOff: Integer): Cardinal;
  end;

function TRpTable.Valid(AOff, ASize: Integer): Boolean;
begin
  Result := (P <> nil) and (AOff >= 0) and (AOff + ASize <= Len);
end;

function TRpTable.U16(AOff: Integer): Word;
begin
  Result := (Word(P[AOff]) shl 8) or P[AOff + 1];
end;

function TRpTable.S16(AOff: Integer): SmallInt;
begin
  Result := SmallInt(U16(AOff));
end;

function TRpTable.U32(AOff: Integer): Cardinal;
begin
  Result := (Cardinal(P[AOff]) shl 24) or (Cardinal(P[AOff + 1]) shl 16) or
    (Cardinal(P[AOff + 2]) shl 8) or P[AOff + 3];
end;

function OpenTable(AFont: CTFontRef; ATag: CTFontTableTag): TRpTable;
begin
  Result.Data := CTFontCopyTable(AFont, ATag, kCTFontTableOptionNoOptions);
  if Result.Data <> nil then
  begin
    Result.P := CFDataGetBytePtr(Result.Data);
    Result.Len := CFDataGetLength(Result.Data);
  end
  else
  begin
    Result.P := nil;
    Result.Len := 0;
  end;
end;

procedure CloseTable(var ATable: TRpTable);
begin
  if ATable.Data <> nil then
    CFRelease(ATable.Data);
  ATable.Data := nil;
  ATable.P := nil;
end;

function HasTable(AFont: CTFontRef; ATag: CTFontTableTag): Boolean;
var
  t: TRpTable;
begin
  t := OpenTable(AFont, ATag);
  Result := t.Data <> nil;
  CloseTable(t);
end;

const
  CTagHvgl = $6876676C; // 'hvgl': the variable glyphs of Apple, macOS 15
  CTagCFF2 = $43464632; // 'CFF2'

// Outlines that a PDF can embed: TrueType (glyf) or CFF. The faces of
// PingFang in macOS 15 keep theirs in hvgl, which neither HarfBuzz nor a PDF
// viewer reads, and CFF2 has no place in a PDF font either
function FontEmbeddable(AFont: CTFontRef): Boolean;
begin
  Result := (HasTable(AFont, kCTFontTableGlyf) or HasTable(AFont, kCTFontTableCFF)) and
    not HasTable(AFont, CTagHvgl) and not HasTable(AFont, CTagCFF2);
end;

{ The face of a file with a PostScript name: a font file has one; a
  collection (ttcf) has a table directory per face. The name table is read
  from the file, so the index is the one HarfBuzz and FreeType use. }

function ReadU16(AStream: TStream; AOff: Int64): Word;
var
  b: array[0..1] of Byte;
begin
  AStream.Position := AOff;
  AStream.ReadBuffer(b, 2);
  Result := (Word(b[0]) shl 8) or b[1];
end;

function ReadU32(AStream: TStream; AOff: Int64): Cardinal;
var
  b: array[0..3] of Byte;
begin
  AStream.Position := AOff;
  AStream.ReadBuffer(b, 4);
  Result := (Cardinal(b[0]) shl 24) or (Cardinal(b[1]) shl 16) or (Cardinal(b[2]) shl 8) or b[3];
end;

// A name (nameID) of the face whose table directory starts at ADir: the
// English one of Windows (platform 3, language 0x409) first, then any other
// Unicode one, then the Macintosh Roman one
function FaceName(AStream: TStream; ADir: Cardinal; ANameID: Integer): string;
var
  numTables, i, count, strOff, plat, enc, lang, nameid, len, off, k, rank, best: Integer;
  tag, nameOff: Cardinal;
  w: UnicodeString;
  mac: AnsiString;
begin
  Result := '';
  numTables := ReadU16(AStream, ADir + 4);
  nameOff := 0;
  for i := 0 to numTables - 1 do
  begin
    tag := ReadU32(AStream, ADir + 12 + i * 16);
    if tag = $6E616D65 then // 'name'
    begin
      nameOff := ReadU32(AStream, ADir + 12 + i * 16 + 8);
      Break;
    end;
  end;
  if nameOff = 0 then
    Exit;
  count := ReadU16(AStream, nameOff + 2);
  strOff := ReadU16(AStream, nameOff + 4);
  best := 0;
  for i := 0 to count - 1 do
  begin
    off := nameOff + 6 + i * 12;
    nameid := ReadU16(AStream, off + 6);
    if nameid <> ANameID then
      Continue;
    plat := ReadU16(AStream, off);
    enc := ReadU16(AStream, off + 2);
    lang := ReadU16(AStream, off + 4);
    if (plat = 3) and ((enc = 0) or (enc = 1) or (enc = 10)) and (lang = $409) then
      rank := 3
    else if (plat = 0) or ((plat = 3) and ((enc = 0) or (enc = 1) or (enc = 10))) then
      rank := 2
    else if (plat = 1) and (enc = 0) then
      rank := 1
    else
      rank := 0;
    if rank <= best then
      Continue;
    best := rank;
    len := ReadU16(AStream, off + 8);
    off := nameOff + strOff + ReadU16(AStream, off + 10);
    if rank >= 2 then
    begin
      SetLength(w, len div 2);
      for k := 0 to len div 2 - 1 do
        w[k + 1] := System.WideChar(ReadU16(AStream, off + k * 2));
      Result := UTF8Encode(w);
    end
    else
    begin
      SetLength(mac, len);
      if len > 0 then
      begin
        AStream.Position := off;
        AStream.ReadBuffer(mac[1], len);
      end;
      Result := string(mac);
    end;
    if best = 3 then
      Exit;
  end;
end;

// The face of a font file: by its PostScript name (nameID 6), and if no face
// has it, by its family (typographic family, nameID 16, or nameID 1): the
// named instance of a variable face ("PingFangSC-Regular" is the weight 400
// of the face "PingFang SC", whose default instance is PingFangSC-Medium).
// A single font file is face 0. False when the face is not found.
function FindFaceInFile(const AFileName, APostScriptName, AFamily: string;
  out AIndex: Integer; out ADir: Cardinal): Boolean;
var
  fs: TFileStream;
  numFonts, i, pass: Integer;
  dir: Cardinal;
  family: string;
begin
  Result := False;
  AIndex := 0;
  ADir := 0;
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if (fs.Size < 12) or (ReadU32(fs, 0) <> $74746366) then // not 'ttcf'
      Exit(True);
    numFonts := ReadU32(fs, 8);
    for pass := 0 to 1 do
      for i := 0 to numFonts - 1 do
      begin
        dir := ReadU32(fs, 12 + i * 4);
        if pass = 0 then
        begin
          if FaceName(fs, dir, 6) <> APostScriptName then
            Continue;
        end
        else
        begin
          family := FaceName(fs, dir, 16);
          if family = '' then
            family := FaceName(fs, dir, 1);
          if not SameText(family, AFamily) then
            Continue;
        end;
        AIndex := i;
        ADir := dir;
        Exit(True);
      end;
    // Not found: the first face, as the FreeType provider
    ADir := ReadU32(fs, 12);
  finally
    fs.Free;
  end;
end;

{ TRpCTFace }

destructor TRpCTFace.Destroy;
begin
  if Cascade <> nil then
    CFRelease(Cascade);
  if Font <> nil then
    CFRelease(Font);
  Kernings.Free;
  inherited Destroy;
end;

function FontFileName(AFont: CTFontRef): string;
var
  url: CFURLRef;
begin
  Result := '';
  url := CFURLRef(CTFontCopyAttribute(AFont, kCTFontURLAttribute));
  if url = nil then
    Exit;
  Result := TakeStr(CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle));
  CFRelease(url);
end;

// The axis values of a variable font (CTFontCopyVariation: axis tag -> value)
procedure ReadVariation(AFont: CTFontRef; AFace: TRpCTFace);
var
  dict: CFDictionaryRef;
  n, i: Integer;
  keys, values: array of Pointer;
  tag: SInt64;
  value: Double;
begin
  dict := CTFontCopyVariation(AFont);
  if dict = nil then
    Exit;
  try
    n := CFDictionaryGetCount(dict);
    SetLength(keys, n);
    SetLength(values, n);
    if n > 0 then
      CFDictionaryGetKeysAndValues(dict, @keys[0], @values[0]);
    SetLength(AFace.AxisTags, n);
    SetLength(AFace.AxisValues, n);
    for i := 0 to n - 1 do
    begin
      tag := 0;
      value := 0;
      CFNumberGetValue(CFNumberRef(keys[i]), kCFNumberSInt64Type, @tag);
      CFNumberGetValue(CFNumberRef(values[i]), kCFNumberDoubleType, @value);
      AFace.AxisTags[i] := Cardinal(tag);
      AFace.AxisValues[i] := value;
    end;
  finally
    CFRelease(dict);
  end;
end;

// The data of a face, with its metrics as TRpFTInfoProvider.FillFontDataInt
// computes them (hhea, then OS/2 as DirectWrite)
function NewFace(AFont: CTFontRef): TRpCTFace;
var
  traits: CTFontSymbolicTraits;
  t: TRpTable;
  cf: Double;
  hheaAsc, hheaDesc, hheaGap: Integer;
  typoAsc, typoDesc, typoGap: Integer;
  fsSelection: Word;
begin
  Result := TRpCTFace.Create;
  Result.Font := AFont;
  Result.PostScriptName := TakeStr(CTFontCopyPostScriptName(AFont));
  Result.FamilyName := TakeStr(CTFontCopyFamilyName(AFont));
  Result.StyleName := TakeStr(CTFontCopyName(AFont, kCTFontStyleNameKey));
  Result.FileName := FontFileName(AFont);
  if Result.FileName <> '' then
  try
    Result.FaceFound := FindFaceInFile(Result.FileName, Result.PostScriptName,
      Result.FamilyName, Result.FaceIndex, Result.DirectoryOffset);
  except
    // An unreadable file: the first face, it is embedded as it was
    Result.FaceIndex := 0;
    Result.DirectoryOffset := 0;
  end;
  Result.Variable := HasTable(AFont, kCTFontTableFvar);
  if Result.Variable then
    ReadVariation(AFont, Result);
  Result.UnitsPerEm := CTFontGetUnitsPerEm(AFont);
  if Result.UnitsPerEm <= 0 then
    Result.UnitsPerEm := 1000;
  traits := CTFontGetSymbolicTraits(AFont);
  Result.Bold := (traits and kCTFontBoldTrait) <> 0;
  Result.Italic := (traits and kCTFontItalicTrait) <> 0;
  Result.FixedPitch := (traits and kCTFontMonoSpaceTrait) <> 0;
  Result.CFF := HasTable(AFont, kCTFontTableCFF);
  Result.TrueType := (not Result.CFF) and HasTable(AFont, kCTFontTableGlyf);
  Result.Embeddable := FontEmbeddable(AFont);
  Result.HasKerning := HasTable(AFont, kCTFontTableKern);
  cf := 1000 / Result.UnitsPerEm;

  t := OpenTable(AFont, kCTFontTableHead);
  if t.Valid(36, 8) then
  begin
    Result.BBox.Left := Round(cf * t.S16(36));
    Result.BBox.Bottom := Round(cf * t.S16(38));
    Result.BBox.Right := Round(cf * t.S16(40));
    Result.BBox.Top := Round(cf * t.S16(42));
  end;
  CloseTable(t);

  hheaAsc := 0;
  hheaDesc := 0;
  hheaGap := 0;
  t := OpenTable(AFont, kCTFontTableHhea);
  if t.Valid(4, 8) then
  begin
    hheaAsc := t.S16(4);
    hheaDesc := t.S16(6);
    hheaGap := t.S16(8);
    Result.MaxWidth := Round(cf * t.U16(10));
  end;
  CloseTable(t);
  Result.Ascent := Round(cf * hheaAsc);
  Result.Descent := Round(cf * hheaDesc);
  Result.Height := Round(cf * (hheaAsc - hheaDesc + hheaGap));
  if Result.Height <= 0 then
    Result.Height := Result.Ascent - Result.Descent;
  Result.Leading := Result.Height - (Result.Ascent - Result.Descent);

  // As DirectWrite: with USE_TYPO_METRICS (fsSelection bit 7) the typo
  // metrics, otherwise usWinAscent/usWinDescent and the height of hhea
  t := OpenTable(AFont, kCTFontTableOS2);
  if t.Valid(0, 78) then
  begin
    fsSelection := t.U16(62);
    if (fsSelection and $0080) <> 0 then
    begin
      typoAsc := t.S16(68);
      typoDesc := -t.S16(70);
      typoGap := t.S16(72);
      Result.Ascent := Round(cf * typoAsc);
      Result.Descent := -Round(cf * typoDesc);
      Result.Height := Round(cf * (typoAsc + typoDesc + typoGap));
    end
    else
    begin
      Result.Ascent := Round(cf * t.U16(74));
      Result.Descent := -Round(cf * t.U16(76));
      // DirectWrite: the line gap is what the height of hhea exceeds
      // usWinAscent + usWinDescent, never negative, so a line is at least
      // as high as its glyphs (Helvetica: hhea 1000, win 950 + 225). The
      // FreeType provider keeps the hhea height.
      Result.Height := Max(Result.Height, Result.Ascent - Result.Descent);
    end;
    Result.Leading := Result.Height - Result.Ascent + Result.Descent;
  end;
  CloseTable(t);
  // As the FreeType provider (the ascender)
  Result.CapHeight := Result.Ascent;
end;

function CreateByPostScriptName(const AName: string): CTFontRef;
var
  name: CFStringRef;
begin
  Result := nil;
  if AName = '' then
    Exit;
  name := CFStr(AName);
  try
    Result := CTFontCreateWithName(name, 1000, nil);
    if (Result <> nil) and (TakeStr(CTFontCopyPostScriptName(Result)) <> AName) then
    begin
      CFRelease(Result);
      Result := nil;
    end;
  finally
    CFRelease(name);
  end;
end;

function CreateByFamily(const AName: string; ABold, AItalic: Boolean): CTFontRef;
var
  name: CFStringRef;
  keys: array[0..0] of Pointer;
  values: array[0..0] of Pointer;
  attrs: CFDictionaryRef;
  desc: CTFontDescriptorRef;
  traits, mask: CTFontSymbolicTraits;
  styled: CTFontRef;
begin
  name := CFStr(AName);
  try
    keys[0] := kCTFontFamilyNameAttribute;
    values[0] := name;
    attrs := CFDictionaryCreate(nil, @keys[0], @values[0], 1,
      @kCFTypeDictionaryKeyCallBacks, @kCFTypeDictionaryValueCallBacks);
    desc := CTFontDescriptorCreateWithAttributes(attrs);
    CFRelease(attrs);
    Result := CTFontCreateWithFontDescriptor(desc, 1000, nil);
    CFRelease(desc);
    // Not a family: a PostScript name ("HelveticaNeue-Light") or a full name
    // ("Hiragino Sans W3") of a face
    if (Result <> nil) and
       (not SameText(TakeStr(CTFontCopyFamilyName(Result)), AName)) then
    begin
      styled := CTFontCreateWithName(name, 1000, nil);
      if (styled <> nil) and
         ((TakeStr(CTFontCopyPostScriptName(styled)) = AName) or
          SameText(TakeStr(CTFontCopyName(styled, kCTFontFullNameKey)), AName)) then
      begin
        CFRelease(Result);
        Result := styled;
      end
      else if styled <> nil then
        CFRelease(styled);
    end;
  finally
    CFRelease(name);
  end;
  if Result = nil then
    Exit;
  traits := 0;
  mask := kCTFontBoldTrait or kCTFontItalicTrait;
  if ABold then
    traits := traits or kCTFontBoldTrait;
  if AItalic then
    traits := traits or kCTFontItalicTrait;
  // Only to add a style the face lacks ("Helvetica Neue Light" stays light)
  if (traits and not CTFontGetSymbolicTraits(Result) and mask) <> 0 then
  begin
    // nil when the family has no such face: the face stays
    styled := CTFontCreateCopyWithSymbolicTraits(Result, 0, nil, traits, mask);
    if styled <> nil then
    begin
      CFRelease(Result);
      Result := styled;
    end;
  end;
end;

// COURIER IS DRAWN WITH COURIER NEW (13-10-2026). Courier.ttc of macOS, embedded
// by Quartz in a print job, restarts some printers (HP M477fdw over AirPrint)
// and goes the same way into a PDF/A-3 printed from Preview. Courier New ships
// with macOS, has the same widths and prints. A family name only: a face Core
// Text substituted ('@' and its PostScript name) stays as it is.
function RpCTFamilyAlias(const AName: string): string;
begin
  if SameText(AName, 'Courier') then
    Result := 'Courier New'
  else
    Result := AName;
end;

function RpCTFace(const AName: string; ABold, AItalic: Boolean): TRpCTFace;
var
  key, psname: string;
  font: CTFontRef;
begin
  key := AName + '|' + IntToStr(Ord(ABold)) + IntToStr(Ord(AItalic));
  GLock.Enter;
  try
    if GRequests.TryGetValue(key, Result) then
      Exit;
    // '@' and a PostScript name: the face Core Text substituted in a run,
    // exactly, without the style of the text (it already has its own)
    font := nil;
    if Copy(AName, 1, 1) = CRpCTFaceMark then
      font := CreateByPostScriptName(Copy(AName, 2, MaxInt));
    // A family (or a PostScript or full name) with the style
    if font = nil then
    begin
      if Copy(AName, 1, 1) = CRpCTFaceMark then
        font := CreateByFamily(Copy(AName, 2, MaxInt), ABold, AItalic)
      else
        font := CreateByFamily(RpCTFamilyAlias(AName), ABold, AItalic);
    end;
    Result := nil;
    if font <> nil then
    begin
      psname := TakeStr(CTFontCopyPostScriptName(font));
      if GFaces.TryGetValue(psname, Result) then
        CFRelease(font)
      else
      begin
        Result := NewFace(font);
        GFaces.Add(psname, Result);
      end;
    end;
    GRequests.Add(key, Result);
  finally
    GLock.Leave;
  end;
end;

// Whether a name is a family, a PostScript name or a full name of a font of
// the system (for any other name Core Text gives its default font)
function FontNameExists(const AName: string): Boolean;
var
  font: CTFontRef;
begin
  Result := False;
  if AName = '' then
    Exit;
  GLock.Enter;
  try
    if GKnown.TryGetValue(AName, Result) then
      Exit;
    font := CreateByFamily(AName, False, False);
    if font <> nil then
    begin
      Result := SameText(TakeStr(CTFontCopyFamilyName(font)), AName) or
        (TakeStr(CTFontCopyPostScriptName(font)) = AName) or
        SameText(TakeStr(CTFontCopyName(font, kCTFontFullNameKey)), AName);
      CFRelease(font);
    end;
    GKnown.Add(AName, Result);
  finally
    GLock.Leave;
  end;
end;

// The family of an X11 font name: 'adobe-courier' (foundry-family, as the
// reports made with Kylix and the Qt designers carry them) or a whole XLFD
// ('-adobe-courier-medium-r-normal--12-...'); '' when the name is not one
function RpCTX11Family(const AName: string): string;
var
  rest: string;
  p: Integer;
begin
  Result := '';
  rest := AName;
  // XLFD: -foundry-family-weight-...
  if Copy(rest, 1, 1) = '-' then
    Delete(rest, 1, 1);
  p := Pos('-', rest);
  if p <= 1 then
    Exit;
  Delete(rest, 1, p);
  p := Pos('-', rest);
  if p > 0 then
    rest := Copy(rest, 1, p - 1);
  Result := Trim(rest);
end;

function RpCTBaseFontName(const ALFontName, AWFontName: WideString): string;
var
  lname, wname, x11: string;
begin
  lname := UTF8Encode(ALFontName);
  wname := UTF8Encode(AWFontName);
  // Core Text knows no X11 names: 'adobe-courier' went to the WFontName (Arial)
  if not FontNameExists(lname) then
  begin
    x11 := RpCTX11Family(lname);
    if (x11 <> '') and FontNameExists(x11) then
      lname := x11;
  end;
  if FontNameExists(lname) then
    Result := lname
  else if FontNameExists(wname) then
    Result := wname
  else if lname <> '' then
    Result := lname
  else if wname <> '' then
    Result := wname
  else
    Result := 'Helvetica';
end;

// The substitution list Core Text would use for a face, without the faces a
// PDF cannot embed, as a descriptor to apply to its fonts (it is built once
// per face). The default list puts PingFang (hvgl) before Hiragino Sans GB
// (CFF): with it Chinese would come out in a font that cannot be embedded.
function RpCTCascade(AFace: TRpCTFace): CTFontDescriptorRef;
var
  list: CFArrayRef;
  filtered: CFMutableArrayRef;
  i, n: Integer;
  desc: CTFontDescriptorRef;
  f: CTFontRef;
  keys, values: array[0..0] of Pointer;
  attrs: CFDictionaryRef;
begin
  GLock.Enter;
  try
    if AFace.CascadeBuilt then
      Exit(AFace.Cascade);
    AFace.CascadeBuilt := True;
    AFace.Cascade := nil;
    Result := nil;
    list := CTFontCopyDefaultCascadeListForLanguages(AFace.Font, nil);
    if list = nil then
      Exit;
    filtered := CFArrayCreateMutable(nil, 0, @kCFTypeArrayCallBacks);
    try
      n := CFArrayGetCount(list);
      for i := 0 to n - 1 do
      begin
        desc := CTFontDescriptorRef(CFArrayGetValueAtIndex(list, i));
        f := CTFontCreateWithFontDescriptor(desc, 12, nil);
        if f <> nil then
        begin
          if FontEmbeddable(f) then
            CFArrayAppendValue(filtered, desc);
          CFRelease(f);
        end;
      end;
      keys[0] := kCTFontCascadeListAttribute;
      values[0] := filtered;
      attrs := CFDictionaryCreate(nil, @keys[0], @values[0], 1,
        @kCFTypeDictionaryKeyCallBacks, @kCFTypeDictionaryValueCallBacks);
      AFace.Cascade := CTFontDescriptorCreateWithAttributes(attrs);
      CFRelease(attrs);
    finally
      CFRelease(filtered);
      CFRelease(list);
    end;
    Result := AFace.Cascade;
  finally
    GLock.Leave;
  end;
end;

type
  Thb_subset_input_pin_axis_location = function(input: Phb_subset_input_t;
    face: THBFace; axis_tag: Cardinal; axis_value: Single): LongBool; cdecl;

// A named instance of a variable TrueType face (PingFangSC-Regular is not:
// hvgl): the subset of HarfBuzz with every axis pinned at the value of the
// instance gives a static font with its outlines. nil when it cannot be made.
function SubsetInstance(AData: TRpTTFontData; AFace: TRpCTFace): TMemoryStream;
var
  pin: Thb_subset_input_pin_axis_location;
  blob, outBlob: Phb_blob_t;
  hbface, newFace: THBFace;
  input: Phb_subset_input_t;
  glyphs: Phb_set_t;
  info: TGlyphInfo;
  outData: PByte;
  outSize: Cardinal;
  i: Integer;
  fpuMask: TFPUExceptionMask;
begin
  Result := nil;
  InitHarfBuzz;
  if not HarfBuzzSubSetImplementation then
    Exit;
  pin := Thb_subset_input_pin_axis_location(
    GetProcAddress(HarfBuzzlibSubSet, 'hb_subset_input_pin_axis_location'));
  if not Assigned(pin) then
    Exit;
  fpuMask := GetExceptionMask;
  SetExceptionMask(fpuMask + [exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  blob := hb_blob_create(AData.FontData.FontData.Memory, AData.FontData.FontData.Size,
    hbmmReadonly, nil, nil);
  try
    hbface := hb_face_create(blob, AData.FontIndex);
    input := hb_subset_input_create_or_fail;
    try
      if input = nil then
        Exit;
      hb_subset_input_set_flags(input, HB_SUBSET_FLAGS_RETAIN_GIDS);
      glyphs := hb_subset_input_glyph_set(input);
      for info in AData.glyphsInfo.Values do
        hb_set_add(glyphs, info.Glyph);
      for i := 0 to High(AFace.AxisTags) do
        pin(input, hbface, AFace.AxisTags[i], AFace.AxisValues[i]);
      newFace := hb_subset_or_fail(hbface, input);
      // THBFace wraps the pointer hb_subset_or_fail returns (nil: it failed)
      if PPointer(@newFace)^ = nil then
        Exit;
      try
        outBlob := hb_face_reference_blob(newFace);
        try
          outData := hb_blob_get_data(outBlob, outSize);
          if Assigned(outData) and (outSize > 0) then
          begin
            Result := TMemoryStream.Create;
            Result.SetSize(Int64(outSize));
            Move(outData^, Result.Memory^, outSize);
            Result.Position := 0;
          end;
        finally
          hb_blob_destroy(outBlob);
        end;
      finally
        hb_face_destroy(newFace);
      end;
    finally
      if input <> nil then
        hb_subset_input_destroy(input);
      hb_face_destroy(hbface);
    end;
  finally
    hb_blob_destroy(blob);
    SetExceptionMask(fpuMask);
  end;
end;

{ TRpCTInfoProvider }

function TRpCTInfoProvider.GetFontStream(data: TRpTTFontData): TMemoryStream;
var
  face: TRpCTFace;
begin
  Result := nil;
  if data.fdata is TRpCTFace then
  begin
    face := TRpCTFace(data.fdata);
    if face.Variable and face.TrueType and (Length(face.AxisTags) > 0) then
      Result := SubsetInstance(data, face);
  end;
  if Result = nil then
    Result := inherited GetFontStream(data);
end;

function TRpCTInfoProvider.ResolveFace(pdffont: TRpPDFFont): TRpCTFace;
var
  name: string;
begin
  name := RpCTBaseFontName(pdffont.LFontName, pdffont.WFontName);
  Result := RpCTFace(name, pdffont.Bold, pdffont.Italic);
  if Result = nil then
    raise Exception.Create('Core Text has no font for ' + name);
end;

procedure TRpCTInfoProvider.FillFontData(pdffont: TRpPDFFont; data: TRpTTFontData;
  content: string);
var
  face: TRpCTFace;
begin
  face := ResolveFace(pdffont);
  crit.Enter;
  try
    data.fontdata.FontData.Clear;
    data.filename := face.FileName;
    data.FontIndex := face.FaceIndex;
    data.fontdata.DirectoryOffset := face.DirectoryOffset;
    if face.FileName <> '' then
      data.fontdata.FontData.LoadFromFile(face.FileName);
    data.postcriptname := face.PostScriptName;
    data.FamilyName := face.FamilyName;
    data.FaceName := face.FamilyName;
    data.StyleName := face.StyleName;
    data.Ascent := face.Ascent;
    data.Descent := face.Descent;
    data.Height := face.Height;
    data.Leading := face.Leading;
    data.CapHeight := face.CapHeight;
    data.Encoding := 'WinAnsiEncoding';
    data.FontWeight := 0;
    data.MaxWidth := face.MaxWidth;
    data.AvgWidth := 0;
    data.havekerning := face.HasKerning;
    data.StemV := 0;
    data.FontStretch := '/Normal';
    data.FontBBox := face.BBox;
    data.UnitsPerEM := face.UnitsPerEm;
    data.fdata := face;
    data.Flags := 32;
    if face.FixedPitch then
      data.Flags := data.Flags + 1;
    if face.Italic then
    begin
      data.ItalicAngle := -15;
      data.Flags := data.Flags + 64;
    end
    else
      data.ItalicAngle := 0;
    // The style that the family does not have (the PDF viewer simulates it)
    if pdffont.Bold and not face.Bold then
      data.postcriptname := data.postcriptname + ',Bold';
    if pdffont.Italic and not face.Italic then
    begin
      if pdffont.Bold and not face.Bold then
        data.postcriptname := data.postcriptname + 'Italic'
      else
        data.postcriptname := data.postcriptname + ',Italic';
    end;
    data.Type1 := False;
    data.CFF := face.CFF;
    data.truetype := face.TrueType;
  finally
    crit.Leave;
  end;
end;

function TRpCTInfoProvider.NFCNormalize(astring: WideString): WideString;
var
  s: CFMutableStringRef;
  len: CFIndex;
begin
  Result := astring;
  if astring = '' then
    Exit;
  s := CFStringCreateMutable(nil, 0);
  try
    CFStringAppendCharacters(s, Pointer(PWideChar(astring)), Length(astring));
    CFStringNormalize(s, kCFStringNormalizationFormC);
    len := CFStringGetLength(s);
    SetLength(Result, len);
    if len > 0 then
      CFStringGetCharacters(s, CFRangeMake(0, len), Pointer(PWideChar(Result)));
  finally
    CFRelease(s);
  end;
end;

function TRpCTInfoProvider.GetCharWidth(pdffont: TRpPDFFont; data: TRpTTFontData;
  charcode: System.WideChar): double;
var
  aint: Integer;
  face: TRpCTFace;
  ch: UniChar;
  glyph: CGGlyph;
  adv: CGSize;
  ginfo: TGlyphInfo;
begin
  aint := Ord(charcode);
  if aint > 255 then
    data.isunicode := True;
  if data.loaded[aint] then
    Exit(data.loadedwidths[aint]);
  face := TRpCTFace(data.fdata);
  ch := UniChar(aint);
  glyph := 0;
  Result := 0;
  // A character without glyph gets glyph 0 (.notdef) and its width, as in the
  // FreeType provider; the substitution of fonts is the work of TextExtent
  CTFontGetGlyphsForCharacters(face.Font, @ch, @glyph, 1);
  begin
    CTFontGetAdvancesForGlyphs(face.Font, kCTFontOrientationHorizontal, @glyph, @adv, 1);
    Result := adv.width;
  end;
  data.loadedwidths[aint] := Result;
  data.loaded[aint] := True;
  if data.firstloaded > aint then
    data.firstloaded := aint;
  if data.lastloaded < aint then
    data.lastloaded := aint;
  data.widths.AddOrSetValue(charcode, Result);
  data.glyphs.AddOrSetValue(charcode, glyph);
  if not data.glyphsInfo.ContainsKey(glyph) then
  begin
    ginfo.Glyph := glyph;
    ginfo.Width := Result;
    ginfo.Char := charcode;
    data.glyphsInfo.Add(glyph, ginfo);
  end;
  data.loadedglyphs[aint] := System.WideChar(glyph);
  data.loadedg[aint] := True;
end;

function TRpCTInfoProvider.GetGlyphWidth(pdffont: TRpPDFFont; data: TRpTTFontData;
  glyph: Integer; charC: System.WideChar): double;
var
  face: TRpCTFace;
  g: CGGlyph;
  adv: CGSize;
  ginfo: TGlyphInfo;
begin
  if data.glyphsInfo.ContainsKey(glyph) then
    Exit(data.glyphsInfo[glyph].Width);
  face := TRpCTFace(data.fdata);
  g := CGGlyph(glyph);
  CTFontGetAdvancesForGlyphs(face.Font, kCTFontOrientationHorizontal, @g, @adv, 1);
  Result := adv.width;
  ginfo.Glyph := glyph;
  ginfo.Width := Result;
  ginfo.Char := charC;
  data.glyphsInfo.Add(glyph, ginfo);
end;

// The pairs of the kern table, format 0 (what FreeType's FT_Get_Kerning reads)
procedure TRpCTInfoProvider.LoadKernings(AFace: TRpCTFace);
var
  t: TRpTable;
  nTables, i, off, sublen, coverage, format, nPairs, j, p: Integer;
  version: Word;
begin
  AFace.Kernings := TDictionary<Cardinal, SmallInt>.Create;
  AFace.KerningsLoaded := True;
  if not AFace.HasKerning then
    Exit;
  t := OpenTable(AFace.Font, kCTFontTableKern);
  try
    if not t.Valid(0, 4) then
      Exit;
    version := t.U16(0);
    // Version 0 (Windows); the Apple version 1 has 32-bit headers
    if version <> 0 then
      Exit;
    nTables := t.U16(2);
    off := 4;
    for i := 0 to nTables - 1 do
    begin
      if not t.Valid(off, 14) then
        Break;
      sublen := t.U16(off + 2);
      coverage := t.U16(off + 4);
      format := coverage shr 8;
      // Horizontal, not cross-stream, kerning values (not minimum)
      if (format = 0) and ((coverage and 1) <> 0) and ((coverage and 6) = 0) then
      begin
        nPairs := t.U16(off + 6);
        for j := 0 to nPairs - 1 do
        begin
          p := off + 14 + j * 6;
          if not t.Valid(p, 6) then
            Break;
          AFace.Kernings.AddOrSetValue((Cardinal(t.U16(p)) shl 16) or t.U16(p + 2), t.S16(p + 4));
        end;
      end;
      if sublen <= 0 then
        Break;
      Inc(off, sublen);
    end;
  finally
    CloseTable(t);
  end;
end;

function TRpCTInfoProvider.GetKerning(pdffont: TRpPDFFont; data: TRpTTFontData;
  leftchar, rightchar: System.WideChar): integer;
{$IFDEF USEKERNING}
var
  face: TRpCTFace;
  chars: array[0..1] of UniChar;
  glyphs: array[0..1] of CGGlyph;
  value: SmallInt;
{$ENDIF}
begin
  Result := 0;
{$IFDEF USEKERNING}
  face := TRpCTFace(data.fdata);
  if not face.HasKerning then
    Exit;
  GLock.Enter;
  try
    if not face.KerningsLoaded then
      LoadKernings(face);
  finally
    GLock.Leave;
  end;
  chars[0] := UniChar(Ord(leftchar));
  chars[1] := UniChar(Ord(rightchar));
  glyphs[0] := 0;
  glyphs[1] := 0;
  CTFontGetGlyphsForCharacters(face.Font, @chars[0], @glyphs[0], 2);
  if (glyphs[0] = 0) or (glyphs[1] = 0) then
    Exit;
  if face.Kernings.TryGetValue((Cardinal(glyphs[0]) shl 16) or glyphs[1], value) then
    // Thousandths of an em, positive closes the pair (as the PDF TJ)
    Result := Round(-value * 1000 / face.UnitsPerEm);
{$ENDIF}
end;

{ TextExtent

  The text (HTML segments or plain) is split in paragraphs at CR, LF or CR LF.
  Each paragraph is an attributed string, with a font per segment (its family
  or the LFontName of the report, bold and italic, size) and the direction of
  the paragraph (BidiParagraphLevel: the first strong letter, and with none
  the direction of the object). CTTypesetter shapes it, orders it (bidi),
  substitutes the fonts that lack a character and breaks it in lines by
  width; every CTLine gives its runs and glyphs in visual order with their
  positions. The contract is the one of the other providers:
  - XAdvance, XOffset and YOffset in twips: the PDF places a glyph at the
    origin plus the sum of the previous advances plus XOffset, and YOffset
    up. They are computed from the absolute positions of Core Text, so the
    roundings do not add up along the line.
  - Position (from 1) and Size: the characters of the line in the text, and
    Text that substring; LineCluster, from 0 inside Text, the first
    character of the cluster of the glyph (as the PDF reads it for ToUnicode).
  - FontFamily: the family the glyph was measured with (the one of its
    segment, or LFontName), and for a substituted run CRpCTFaceMark and the PostScript name of
    its face, so that the PDF changes the font resource right there.
  - The white space at the end of a line (and at the start of a wrapped one)
    is removed, and the height of a line and its baseline come from the
    fonts it uses, as in the FreeType and DirectWrite providers.
  - A blank paragraph keeps its height (as DirectWrite). }

type
  TRpCTRange = record
    Start, Len: Integer;      // in the plain text, from 0
    Family: string;           // the name it was asked by (TGlyphPos.FontFamily)
    Face: TRpCTFace;
    Size: Double;
    HasFontSize: Boolean;
    Style: Integer;           // 1 bold, 2 italic, 4 underline, 8 strikeout
    Color: Integer;
    HasColor: Boolean;
  end;

  TRpCTGlyph = record
    Glyph: CGGlyph;
    X, Y, Advance: Double;    // points, from the start of the line
    Pen: Double;              // sum of the previous advances
    Index: Integer;           // character, from 0 in the plain text
    FontName: string;         // PostScript name of the font of the run
  end;

// Strong direction of a character: 1 left to right, 2 right to left, 0 none
function StrongDirection(C: Word; ALetters: CFCharacterSetRef): Integer;
begin
  if ((C >= $0590) and (C <= $08FF)) or ((C >= $FB1D) and (C <= $FDFF)) or
     ((C >= $FE70) and (C <= $FEFF)) or (C = $200F) then
    Result := 2
  else if (C = $200E) or CFCharacterSetIsCharacterMember(ALetters, C) then
    Result := 1
  else
    Result := 0;
end;

// The direction of a paragraph as ICU with BidiParagraphLevel: its first
// strong letter decides; without one, the direction of the object
function ParagraphIsRTL(const AText: UnicodeString; ARightToLeft: Boolean): Boolean;
var
  i, d: Integer;
  letters: CFCharacterSetRef;
begin
  letters := CFCharacterSetGetPredefined(kCFCharacterSetLetter);
  for i := 1 to Length(AText) do
  begin
    d := StrongDirection(Ord(AText[i]), letters);
    if d <> 0 then
      Exit(d = 2);
  end;
  Result := ARightToLeft;
end;

function IsBlank(C: System.WideChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13);
end;

function TRpCTInfoProvider.TextExtent(const Text: WideString; var Rect: TRect;
  adata: TRpTTFontData; pdfFont: TRpPDFFont; wordwrap: Boolean; singleline: Boolean;
  FontSize: Double; IsHtml: Boolean; RightToLeft: Boolean): TRpLineInfoArray;
var
  segs: THtmlSegmentList;
  seg: THtmlSegment;
  plain, segText, paraText: UnicodeString;
  ranges: array of TRpCTRange;
  charRange: array of Integer;
  baseName: string;
  i, r, n, p, paraStart, paraLen, pos, count, lineIdx, k, a, b, minIdx, maxIdx: Integer;
  widthPt: Double;
  rectTop, maxWidth: Double;
  str: CFStringRef;
  mas: CFMutableAttributedStringRef;
  fonts: array of CTFontRef;
  ts: CTTypesetterRef;
  line: CTLineRef;
  runs: CFArrayRef;
  run: CTRunRef;
  runFont: CTFontRef;
  runName: string;
  rtl: Boolean;
  dir: CTWritingDirection;
  setting: CTParagraphStyleSetting;
  pstyle: CTParagraphStyleRef;
  glyphs: array of TRpCTGlyph;
  gl: array of CGGlyph;
  ps: array of CGPoint;
  advs: array of CGSize;
  idx: array of CFIndex;
  pen, penBase, posBase, penRel: Double;
  lineInfo: TRpLineInfo;
  gp: TGlyphPos;
  face: TRpCTFace;
  lineBaseline, lineHeight, gSize, gBase, gHeight: Double;
  fpuMask: TFPUExceptionMask;

  procedure AddRange(const AText: UnicodeString; const AFamily: string;
    ABold, AItalic: Boolean; ASize: Double; AHasSize: Boolean; AStyle, AColor: Integer;
    AHasColor: Boolean);
  var
    q: Integer;
  begin
    if AText = '' then
      Exit;
    q := Length(ranges);
    SetLength(ranges, q + 1);
    ranges[q].Start := Length(plain);
    ranges[q].Len := Length(AText);
    ranges[q].Family := AFamily;
    ranges[q].Face := RpCTFace(AFamily, ABold, AItalic);
    if ranges[q].Face = nil then
      ranges[q].Face := ResolveFace(pdfFont);
    ranges[q].Size := ASize;
    ranges[q].HasFontSize := AHasSize;
    ranges[q].Style := AStyle;
    ranges[q].Color := AColor;
    ranges[q].HasColor := AHasColor;
    plain := plain + AText;
  end;

  // The height and baseline of a font at a size, in twips (as the FreeType
  // provider: baseline = ascent + positive leading, height = line spacing)
  procedure FontLine(AFace: TRpCTFace; ASize: Double; out ABase, AHeight: Double);
  begin
    ABase := (AFace.Ascent + Max(0, AFace.Leading)) / 1000.0 * ASize * 20.0;
    AHeight := AFace.Height / 1000.0 * ASize * 20.0;
  end;

begin
  Result := nil;
  widthPt := (Rect.Right - Rect.Left) / 20.0;
  if singleline then
    wordwrap := False;
  // The rectangle comes back relative: Left/Top 0, Right/Bottom the size
  Rect.Left := 0;
  Rect.Top := 0;
  rectTop := 0;
  maxWidth := 0;
  baseName := RpCTBaseFontName(pdfFont.LFontName, pdfFont.WFontName);
  // Core Text (and HarfBuzz under it) may compute NaN that C ignores; FPC
  // console programs run with the floating point exceptions unmasked
  fpuMask := GetExceptionMask;
  SetExceptionMask(fpuMask + [exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  try
    // The segments, in UTF-16: the parser gives UTF-8 and their lengths are
    // measured in the plain text, which is UTF-16
    plain := '';
    if IsHtml then
    begin
      segs := ParseHtml(UTF8Encode(Text));
      try
        for seg in segs do
        begin
          segText := UTF8Decode(seg.Text);
          p := 0;
          if hsBold in seg.Styles then p := p or 1;
          if hsItalic in seg.Styles then p := p or 2;
          if hsUnderline in seg.Styles then p := p or 4;
          if hsStrikeOut in seg.Styles then p := p or 8;
          if seg.FontFamily <> '' then
            AddRange(segText, seg.FontFamily, pdfFont.Bold or (hsBold in seg.Styles),
              pdfFont.Italic or (hsItalic in seg.Styles),
              IfThen(seg.HasFontSize, seg.FontSize, FontSize), seg.HasFontSize, p,
              seg.Color, seg.HasColor)
          else
            AddRange(segText, baseName, pdfFont.Bold or (hsBold in seg.Styles),
              pdfFont.Italic or (hsItalic in seg.Styles),
              IfThen(seg.HasFontSize, seg.FontSize, FontSize), seg.HasFontSize, p,
              seg.Color, seg.HasColor);
        end;
      finally
        segs.Free;
      end;
    end
    else
      AddRange(Text, baseName, pdfFont.Bold, pdfFont.Italic, FontSize, False, 0, 0, False);
    SetLength(charRange, Length(plain));
    for r := 0 to High(ranges) do
      for i := ranges[r].Start to ranges[r].Start + ranges[r].Len - 1 do
        charRange[i] := r;
    // A CTFont per range, at its size
    SetLength(fonts, Length(ranges));
    for r := 0 to High(ranges) do
      fonts[r] := CTFontCreateCopyWithAttributes(ranges[r].Face.Font, ranges[r].Size, nil,
        RpCTCascade(ranges[r].Face));
    try
      paraStart := 0;
      while paraStart <= Length(plain) do
      begin
        // The paragraph: up to CR, LF or CR LF
        paraLen := 0;
        while (paraStart + paraLen < Length(plain)) and
          not ((plain[paraStart + paraLen + 1] = #13) or (plain[paraStart + paraLen + 1] = #10)) do
          Inc(paraLen);
        if (paraLen = 0) and (paraStart + paraLen >= Length(plain)) then
          Break;
        if paraLen = 0 then
        begin
          // A blank paragraph keeps the height of a line of the base font
          rectTop := rectTop + Round(adata.Height / 1000.0 * FontSize * 20.0);
        end
        else
        begin
          paraText := Copy(plain, paraStart + 1, paraLen);
          str := CFStringCreateWithCharacters(nil, Pointer(PWideChar(paraText)), paraLen);
          mas := CFAttributedStringCreateMutable(nil, 0);
          try
            CFAttributedStringReplaceString(mas, CFRangeMake(0, 0), str);
            CFAttributedStringBeginEditing(mas);
            for r := 0 to High(ranges) do
            begin
              a := Max(ranges[r].Start, paraStart);
              b := Min(ranges[r].Start + ranges[r].Len, paraStart + paraLen);
              if a < b then
                CFAttributedStringSetAttribute(mas, CFRangeMake(a - paraStart, b - a),
                  kCTFontAttributeName, fonts[r]);
            end;
            rtl := ParagraphIsRTL(paraText, RightToLeft);
            if rtl then
              dir := kCTWritingDirectionRightToLeft
            else
              dir := kCTWritingDirectionLeftToRight;
            setting.spec := kCTParagraphStyleSpecifierBaseWritingDirection;
            setting.valueSize := SizeOf(dir);
            setting.value := @dir;
            pstyle := CTParagraphStyleCreate(@setting, 1);
            CFAttributedStringSetAttribute(mas, CFRangeMake(0, paraLen),
              kCTParagraphStyleAttributeName, pstyle);
            CFRelease(pstyle);
            CFAttributedStringEndEditing(mas);
            ts := CTTypesetterCreateWithAttributedString(CFAttributedStringRef(mas));
            try
              pos := 0;
              lineIdx := 0;
              while pos < paraLen do
              begin
                if wordwrap and (widthPt > 0) then
                  count := CTTypesetterSuggestLineBreak(ts, pos, widthPt)
                else
                  count := paraLen - pos;
                if count <= 0 then
                  count := paraLen - pos;
                line := CTTypesetterCreateLine(ts, CFRangeMake(pos, count));
                try
                  // The glyphs of the line in visual order
                  SetLength(glyphs, 0);
                  pen := 0;
                  runs := CTLineGetGlyphRuns(line);
                  for r := 0 to CFArrayGetCount(runs) - 1 do
                  begin
                    run := CTRunRef(CFArrayGetValueAtIndex(runs, r));
                    n := CTRunGetGlyphCount(run);
                    if n <= 0 then
                      Continue;
                    runFont := CTFontRef(CFDictionaryGetValue(CTRunGetAttributes(run),
                      kCTFontAttributeName));
                    runName := TakeStr(CTFontCopyPostScriptName(runFont));
                    SetLength(gl, n);
                    SetLength(ps, n);
                    SetLength(advs, n);
                    SetLength(idx, n);
                    CTRunGetGlyphs(run, CFRangeMake(0, 0), @gl[0]);
                    CTRunGetPositions(run, CFRangeMake(0, 0), @ps[0]);
                    CTRunGetAdvances(run, CFRangeMake(0, 0), @advs[0]);
                    CTRunGetStringIndices(run, CFRangeMake(0, 0), @idx[0]);
                    k := Length(glyphs);
                    SetLength(glyphs, k + n);
                    for i := 0 to n - 1 do
                    begin
                      glyphs[k + i].Glyph := gl[i];
                      glyphs[k + i].X := ps[i].x;
                      glyphs[k + i].Y := ps[i].y;
                      glyphs[k + i].Advance := advs[i].width;
                      glyphs[k + i].Pen := pen;
                      glyphs[k + i].Index := paraStart + idx[i];
                      glyphs[k + i].FontName := runName;
                      pen := pen + advs[i].width;
                    end;
                  end;
                finally
                  CFRelease(line);
                end;
                // White space at the end of the line, and at the start of a
                // wrapped one (visual right and left; mirrored in RTL)
                a := 0;
                b := High(glyphs);
                if not rtl then
                begin
                  while (b >= a) and IsBlank(plain[glyphs[b].Index + 1]) do
                    Dec(b);
                  if lineIdx > 0 then
                    while (a <= b) and IsBlank(plain[glyphs[a].Index + 1]) do
                      Inc(a);
                end
                else
                begin
                  while (a <= b) and IsBlank(plain[glyphs[a].Index + 1]) do
                    Inc(a);
                  if lineIdx > 0 then
                    while (b >= a) and IsBlank(plain[glyphs[b].Index + 1]) do
                      Dec(b);
                end;
                lineInfo := Default(TRpLineInfo);
                SetLength(lineInfo.Glyphs, Max(0, b - a + 1));
                minIdx := MaxInt;
                maxIdx := -1;
                for i := a to b do
                begin
                  if glyphs[i].Index < minIdx then
                    minIdx := glyphs[i].Index;
                  if glyphs[i].Index > maxIdx then
                    maxIdx := glyphs[i].Index;
                end;
                if b >= a then
                begin
                  // The cluster of the last character reaches the next
                  // cluster of the line (a ligature covers more than its
                  // first character), or the end of the line; without the
                  // white space removed above
                  k := paraStart + pos + count;
                  for i := 0 to High(glyphs) do
                    if (glyphs[i].Index > maxIdx) and (glyphs[i].Index < k) then
                      k := glyphs[i].Index;
                  maxIdx := k - 1;
                  while (maxIdx > minIdx) and IsBlank(plain[maxIdx + 1]) do
                    Dec(maxIdx);
                  lineInfo.Position := minIdx + 1;
                  lineInfo.Size := maxIdx - minIdx + 1;
                  lineInfo.Text := UTF8Encode(Copy(plain, lineInfo.Position, lineInfo.Size));
                end;
                // The origin of the line is the first glyph kept, by its
                // advances and by its position: Core Text hangs the white
                // space at the end of an RTL line on the right, so the
                // positions of the glyphs no longer follow the advances
                // from the start of the line
                penBase := 0;
                posBase := 0;
                if b >= a then
                begin
                  penBase := glyphs[a].Pen;
                  posBase := glyphs[a].X;
                end;
                // The base font of the object (as the other providers)
                lineBaseline := (adata.Ascent + Max(0, adata.Leading)) / 1000.0 * FontSize * 20.0;
                lineHeight := adata.Height / 1000.0 * FontSize * 20.0;
                for i := a to b do
                begin
                  r := charRange[glyphs[i].Index];
                  gp := Default(TGlyphPos);
                  gp.GlyphIndex := glyphs[i].Glyph;
                  penRel := glyphs[i].Pen - penBase;
                  gp.XAdvance := Round((penRel + glyphs[i].Advance) * 20) - Round(penRel * 20);
                  gp.XOffset := Round((glyphs[i].X - posBase) * 20) - Round(penRel * 20);
                  gp.YOffset := Round(glyphs[i].Y * 20);
                  gp.YAdvance := 0;
                  gp.CharCode := plain[glyphs[i].Index + 1];
                  gp.Cluster := glyphs[i].Index - paraStart;
                  gp.LineCluster := glyphs[i].Index - minIdx;
                  // The family it was measured with; the PostScript name of
                  // the face Core Text took when it substituted the font
                  if glyphs[i].FontName <> ranges[r].Face.PostScriptName then
                  begin
                    gp.FontFamily := CRpCTFaceMark + glyphs[i].FontName;
                    face := RpCTFace(gp.FontFamily, False, False);
                  end
                  else
                  begin
                    gp.FontFamily := ranges[r].Family;
                    face := ranges[r].Face;
                  end;
                  gp.FontSize := ranges[r].Size;
                  gp.HasFontSize := ranges[r].HasFontSize;
                  gp.Style := ranges[r].Style;
                  gp.Color := ranges[r].Color;
                  gp.HasColor := ranges[r].HasColor;
                  lineInfo.Glyphs[i - a] := gp;
                  if face <> nil then
                  begin
                    if ranges[r].HasFontSize then
                      gSize := ranges[r].Size
                    else
                      gSize := FontSize;
                    FontLine(face, gSize, gBase, gHeight);
                    if gBase > lineBaseline then
                      lineBaseline := gBase;
                    if gHeight > lineHeight then
                      lineHeight := gHeight;
                  end;
                end;
                if b >= a then
                  lineInfo.Width := Round((glyphs[b].Pen + glyphs[b].Advance - penBase) * 20)
                else
                  lineInfo.Width := 0;
                lineInfo.TopPos := Round(rectTop) + Round(lineBaseline);
                lineInfo.Height := Round(lineHeight);
                lineInfo.LineHeight := Round(lineHeight);
                lineInfo.lastline := False;
                SetLength(Result, Length(Result) + 1);
                Result[High(Result)] := lineInfo;
                if lineInfo.Width > maxWidth then
                  maxWidth := lineInfo.Width;
                rectTop := rectTop + Round(lineHeight);
                Inc(lineIdx);
                Inc(pos, count);
              end;
            finally
              CFRelease(ts);
            end;
          finally
            CFRelease(mas);
            CFRelease(str);
          end;
        end;
        // Past the line break (CR LF is one)
        paraStart := paraStart + paraLen;
        if paraStart >= Length(plain) then
          Break;
        if (plain[paraStart + 1] = #13) and (paraStart + 1 < Length(plain)) and
           (plain[paraStart + 2] = #10) then
          Inc(paraStart, 2)
        else
          Inc(paraStart);
      end;
    finally
      for r := 0 to High(fonts) do
        if fonts[r] <> nil then
          CFRelease(fonts[r]);
    end;
  finally
    SetExceptionMask(fpuMask);
  end;
  if Length(Result) > 0 then
    Result[High(Result)].lastline := True;
  Rect.Right := Round(maxWidth);
  Rect.Bottom := Round(rectTop);
end;

initialization
  GLock := TCriticalSection.Create;
  GFaces := TObjectDictionary<string, TRpCTFace>.Create([doOwnsValues]);
  GRequests := TDictionary<string, TRpCTFace>.Create;
  GKnown := TDictionary<string, Boolean>.Create;

finalization
  GKnown.Free;
  GRequests.Free;
  GFaces.Free;
  GLock.Free;

{$ENDIF}
end.

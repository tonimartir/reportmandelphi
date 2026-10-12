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
    and macOS) with bold and italic: a Core Text family plus the symbolic
    traits. A name that is the PostScript name of an existing face is that
    exact face, without applying the traits again: the substituted runs of a
    Core Text line carry the PostScript name of their face in
    TGlyphPos.FontFamily (their nameID 1 can be localized, "蘋方-簡", or lack
    the weight, "Helvetica Neue" for Helvetica Neue Light).
  - Metrics and widths in thousandths of an em, as the other providers: a
    CTFont of size 1000 per face. Ascent, descent and height from the hhea
    table and then OS/2 as DirectWrite does (TRpFTInfoProvider.FillFontDataInt),
    but from the tables of this face: in a collection (.ttc) the FreeType
    provider reads the header of the collection and misses OS/2.
  - Embedding: inherited from TRpFTInfoProvider (subset of HarfBuzz over the
    font file and the index of the face), so the PDF embeds as it did. The
    index of a face inside a .ttc is found by its PostScript name in the
    name table of every face of the file.

  Phase 1 of the plan: fonts, metrics, widths, kerning, embedding and
  normalization (the PDF measures plain text with GetCharWidth). TextExtent
  (RTL, HTML, shaping) comes in phase 2. }

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
    function TextExtent(const Text: WideString; var Rect: TRect; adata: TRpTTFontData;
      pdfFont: TRpPDFFont; wordwrap: Boolean; singleline: Boolean; FontSize: Double;
      IsHtml: Boolean; RightToLeft: Boolean): TRpLineInfoArray; override;
  end;

// The face Core Text gives for a family (or PostScript name) and style; it
// stays in a cache shared by every provider. nil when Core Text gives none.
function RpCTFace(const AName: string; ABold, AItalic: Boolean): TRpCTFace;
{$ENDIF}

implementation

{$IFDEF DARWIN}

{$linkframework CoreText}

var
  GFaces: TObjectDictionary<string, TRpCTFace>;   // owns the faces
  GRequests: TDictionary<string, TRpCTFace>;      // request -> face
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
    // A full name instead of a family ("Hiragino Sans W3")
    if (Result <> nil) and
       (not SameText(TakeStr(CTFontCopyFamilyName(Result)), AName)) then
    begin
      styled := CTFontCreateWithName(name, 1000, nil);
      if (styled <> nil) and
         SameText(TakeStr(CTFontCopyName(styled, kCTFontFullNameKey)), AName) then
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
  if (CTFontGetSymbolicTraits(Result) and mask) <> traits then
  begin
    // nil when the family has no such face: the regular one stays
    styled := CTFontCreateCopyWithSymbolicTraits(Result, 0, nil, traits, mask);
    if styled <> nil then
    begin
      CFRelease(Result);
      Result := styled;
    end;
  end;
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
    // A PostScript name: that face, without the traits (a substituted run)
    font := CreateByPostScriptName(AName);
    if font = nil then
      font := CreateByFamily(AName, ABold, AItalic);
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

{ TRpCTInfoProvider }

function TRpCTInfoProvider.ResolveFace(pdffont: TRpPDFFont): TRpCTFace;
var
  name: string;
begin
  name := UTF8Encode(pdffont.LFontName);
  if name = '' then
    name := UTF8Encode(pdffont.WFontName);
  if name = '' then
    name := 'Helvetica';
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

function TRpCTInfoProvider.TextExtent(const Text: WideString; var Rect: TRect;
  adata: TRpTTFontData; pdfFont: TRpPDFFont; wordwrap: Boolean; singleline: Boolean;
  FontSize: Double; IsHtml: Boolean; RightToLeft: Boolean): TRpLineInfoArray;
begin
  Result := nil;
  raise Exception.Create('Core Text provider: TextExtent is phase 2 (docs/coretext_provider_plan.md)');
end;

initialization
  GLock := TCriticalSection.Create;
  GFaces := TObjectDictionary<string, TRpCTFace>.Create([doOwnsValues]);
  GRequests := TDictionary<string, TRpCTFace>.Create;

finalization
  GRequests.Free;
  GFaces.Free;
  GLock.Free;

{$ENDIF}
end.

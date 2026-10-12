program ctprobe;

{ Phase 0 of the Core Text text provider (docs/coretext_provider_plan.md).
  Lays out difficult texts with Core Text the way the provider would
  (CTTypesetter, line breaks by width, the runs of each line) and dumps what
  TRpLineInfo/TGlyphPos would need: the font of each run (PostScript name,
  family, nameID 1 of its name table, file and face inside a collection),
  direction, glyphs, positions, advances and the UTF-16 string index of every
  glyph. It also checks that a substituted font resolves back to the same face
  from nameID 1 plus bold/italic, as the PDF does with TGlyphPos.FontFamily.

  macOS only: fpc ctprobe.lpr && ./ctprobe }

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  SysUtils, MacOSAll;

type
  TCase = record
    Title: string;
    FontName: string;   // PostScript or full name for CTFontCreateWithName
    Size: Double;
    RightToLeft: Boolean;
    Width: Double;      // line width in points, 0: one line
    Text: string;       // UTF-8
    // Optional second font for a range (an HTML segment)
    Font2: string;
    Range2Start, Range2Len: Integer;
  end;

const
  Cases: array[0..7] of TCase = (
    (Title: 'Arabic line of htmltest (Arial, right to left)'; FontName: 'ArialMT';
     Size: 10; RightToLeft: True; Width: 0;
     Text: 'يسمح محرك Reportman.AI الجديد {{''0.''+''1''}} بـTrue بفضل الاستدلال المحلي، لا تغادر البيانات';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'Arabic wrapped at 220 pt'; FontName: 'ArialMT';
     Size: 10; RightToLeft: True; Width: 220;
     Text: 'بفضل الاستدلال المحلي، لا تغادر البيانات الكمبيوتر أبدا. من الضروري ضمان الخصوصية الكاملة للتقارير التنفيذية.';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'Latin ligatures (Hoefler Text)'; FontName: 'HoeflerText-Regular';
     Size: 12; RightToLeft: False; Width: 0;
     Text: 'office fluffy final';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'A weight that is not bold (Helvetica Neue Light)'; FontName: 'HelveticaNeue-Light';
     Size: 12; RightToLeft: False; Width: 0;
     Text: 'Helvetica Neue Light';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'Emoji (Helvetica, substitution)'; FontName: 'Helvetica';
     Size: 12; RightToLeft: False; Width: 0;
     Text: 'Hola 😀 mundo 👍🏽 fin';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'Chinese and Japanese (Arial, substitution)'; FontName: 'ArialMT';
     Size: 12; RightToLeft: False; Width: 0;
     Text: 'Informe 报表管理器 レポート';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'Digits in a right to left paragraph'; FontName: 'ArialMT';
     Size: 12; RightToLeft: True; Width: 0;
     Text: 'السعر 100 200 USD';
     Font2: ''; Range2Start: 0; Range2Len: 0),
    (Title: 'Two fonts (HTML segment in Courier, wrapped at 160 pt)'; FontName: 'ArialMT';
     Size: 10; RightToLeft: False; Width: 160;
     Text: 'El nuevo motor de Reportman.AI permite una optimización avanzada [LOG: 0x80040154] La arquitectura';
     Font2: 'Courier'; Range2Start: 65; Range2Len: 17)
  );

function CFStr(const S: string): CFStringRef;
begin
  Result := CFStringCreateWithCString(nil, PChar(S), kCFStringEncodingUTF8);
end;

function PasStr(S: CFStringRef): string;
var
  buf: array[0..1023] of Char;
begin
  Result := '';
  if (S <> nil) and CFStringGetCString(S, @buf[0], SizeOf(buf), kCFStringEncodingUTF8) then
    Result := StrPas(@buf[0]);
end;

// nameID 1 of the name table: what Windows takes (GetFontFamilyFromFontFace)
function NameID1(AFont: CTFontRef): string;
var
  data: CFDataRef;
  p: PByte;
  len, count, strOff, i, plat, enc, nameid, l, o, k: Integer;
  macName: string;
  w: UnicodeString;

  function W16(AOff: Integer): Integer;
  begin
    Result := (p[AOff] shl 8) or p[AOff + 1];
  end;

begin
  Result := '';
  macName := '';
  data := CTFontCopyTable(AFont, kCTFontTableName, kCTFontTableOptionNoOptions);
  if data = nil then
    Exit;
  try
    p := CFDataGetBytePtr(data);
    len := CFDataGetLength(data);
    if len < 6 then
      Exit;
    count := W16(2);
    strOff := W16(4);
    for i := 0 to count - 1 do
    begin
      o := 6 + i * 12;
      if o + 12 > len then
        Break;
      plat := W16(o);
      enc := W16(o + 2);
      nameid := W16(o + 6);
      l := W16(o + 8);
      if nameid <> 1 then
        Continue;
      if (plat = 0) or ((plat = 3) and ((enc = 1) or (enc = 10))) then
      begin
        SetLength(w, l div 2);
        for k := 0 to l div 2 - 1 do
          w[k + 1] := System.WideChar(Word(W16(strOff + W16(o + 10) + k * 2)));
        Exit(UTF8Encode(w));
      end;
      if (plat = 1) and (enc = 0) and (macName = '') then
        SetString(macName, PChar(p + strOff + W16(o + 10)), l);
    end;
    Result := macName;
  finally
    CFRelease(data);
  end;
end;

function FontFile(AFont: CTFontRef): string;
var
  url: CFURLRef;
  path: CFStringRef;
begin
  Result := '';
  url := CFURLRef(CTFontCopyAttribute(AFont, kCTFontURLAttribute));
  if url = nil then
    Exit;
  path := CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
  Result := PasStr(path);
  CFRelease(path);
  CFRelease(url);
end;

// Index of the face with that PostScript name inside its file (.ttc: several)
function FaceIndex(AFont: CTFontRef; out AFaces: Integer): Integer;
var
  url: CFURLRef;
  descs: CFArrayRef;
  i: Integer;
  psname, dname: CFStringRef;
begin
  Result := -1;
  AFaces := 0;
  url := CFURLRef(CTFontCopyAttribute(AFont, kCTFontURLAttribute));
  if url = nil then
    Exit;
  psname := CTFontCopyPostScriptName(AFont);
  descs := CTFontManagerCreateFontDescriptorsFromURL(url);
  if descs <> nil then
  begin
    AFaces := CFArrayGetCount(descs);
    for i := 0 to AFaces - 1 do
    begin
      dname := CFStringRef(CTFontDescriptorCopyAttribute(
        CTFontDescriptorRef(CFArrayGetValueAtIndex(descs, i)), kCTFontNameAttribute));
      if (dname <> nil) and (CFStringCompare(dname, psname, 0) = kCFCompareEqualTo) then
        Result := i;
      if dname <> nil then
        CFRelease(dname);
    end;
    CFRelease(descs);
  end;
  CFRelease(psname);
  CFRelease(url);
end;

// The PDF resolves a substituted font from its family (nameID 1) plus the
// bold/italic of the text: does that give the same face?
function ResolvesBack(AFont: CTFontRef; ABold, AItalic: Boolean): string;
var
  fam, ps1, ps2: CFStringRef;
  f, f2: CTFontRef;
  traits: CTFontSymbolicTraits;
begin
  fam := CFStr(NameID1(AFont));
  f := CTFontCreateWithName(fam, CTFontGetSize(AFont), nil);
  traits := 0;
  if ABold then
    traits := traits or kCTFontBoldTrait;
  if AItalic then
    traits := traits or kCTFontItalicTrait;
  if traits <> 0 then
  begin
    f2 := CTFontCreateCopyWithSymbolicTraits(f, 0, nil, traits, traits);
    if f2 <> nil then
    begin
      CFRelease(f);
      f := f2;
    end;
  end;
  ps1 := CTFontCopyPostScriptName(AFont);
  ps2 := CTFontCopyPostScriptName(f);
  if CFStringCompare(ps1, ps2, 0) = kCFCompareEqualTo then
    Result := 'same face'
  else
    Result := 'DIFFERENT: ' + PasStr(ps2);
  CFRelease(ps1);
  CFRelease(ps2);
  CFRelease(f);
  CFRelease(fam);
end;

function CharAt(AStr: CFStringRef; AIndex: CFIndex): string;
var
  c: UniChar;
begin
  c := CFStringGetCharacterAtIndex(AStr, AIndex);
  Result := 'U+' + IntToHex(c, 4);
end;

procedure DumpRun(ARun: CTRunRef; AStr: CFStringRef; ABase: CTFontRef);
var
  n, i, faces, idx: Integer;
  attrs: CFDictionaryRef;
  font: CTFontRef;
  glyphs: array of CGGlyph;
  pos: array of CGPoint;
  adv: array of CGSize;
  sidx: array of CFIndex;
  status: CTRunStatus;
  r: CFRange;
  ps: CFStringRef;
  fam: CFStringRef;
  s: string;
begin
  n := CTRunGetGlyphCount(ARun);
  attrs := CTRunGetAttributes(ARun);
  font := CTFontRef(CFDictionaryGetValue(attrs, kCTFontAttributeName));
  status := CTRunGetStatus(ARun);
  r := CTRunGetStringRange(ARun);
  ps := CTFontCopyPostScriptName(font);
  fam := CTFontCopyFamilyName(font);
  idx := FaceIndex(font, faces);
  s := '';
  if (status and kCTRunStatusRightToLeft) <> 0 then
    s := 'RTL'
  else
    s := 'LTR';
  WriteLn(Format('    run %s text[%d..%d] glyphs=%d font=%s family=%s nameID1="%s"%s',
    [s, r.location, r.location + r.length - 1, n, PasStr(ps), PasStr(fam), NameID1(font),
     BoolToStr(CFEqual(font, ABase), '', ' SUBSTITUTED')]));
  WriteLn(Format('      file=%s face %d of %d', [FontFile(font), idx, faces]));
  if not CFEqual(font, ABase) then
    WriteLn('      resolve back from nameID 1: ', ResolvesBack(font, False, False));
  SetLength(glyphs, n);
  SetLength(pos, n);
  SetLength(adv, n);
  SetLength(sidx, n);
  if n > 0 then
  begin
    CTRunGetGlyphs(ARun, CFRangeMake(0, 0), @glyphs[0]);
    CTRunGetPositions(ARun, CFRangeMake(0, 0), @pos[0]);
    CTRunGetAdvances(ARun, CFRangeMake(0, 0), @adv[0]);
    CTRunGetStringIndices(ARun, CFRangeMake(0, 0), @sidx[0]);
  end;
  for i := 0 to n - 1 do
    WriteLn(Format('      g[%d] glyph=%5d x=%8.2f y=%6.2f adv=%6.2f text[%d]=%s',
      [i, glyphs[i], pos[i].x, pos[i].y, adv[i].width, sidx[i], CharAt(AStr, sidx[i])]));
  CFRelease(ps);
  CFRelease(fam);
end;

procedure RunCase(const C: TCase);
var
  str, fname: CFStringRef;
  mas: CFMutableAttributedStringRef;
  font, font2: CTFontRef;
  ts: CTTypesetterRef;
  line: CTLineRef;
  runs: CFArrayRef;
  total, start, count, nline, i: CFIndex;
  dir: CTWritingDirection;
  setting: CTParagraphStyleSetting;
  pstyle: CTParagraphStyleRef;
  ascent, descent, leading, width: CGFloat;
begin
  WriteLn('== ', C.Title);
  str := CFStr(C.Text);
  total := CFStringGetLength(str);
  fname := CFStr(C.FontName);
  font := CTFontCreateWithName(fname, C.Size, nil);
  CFRelease(fname);
  mas := CFAttributedStringCreateMutable(nil, 0);
  CFAttributedStringReplaceString(mas, CFRangeMake(0, 0), str);
  CFAttributedStringSetAttribute(mas, CFRangeMake(0, total), kCTFontAttributeName, font);
  font2 := nil;
  if C.Font2 <> '' then
  begin
    fname := CFStr(C.Font2);
    font2 := CTFontCreateWithName(fname, C.Size, nil);
    CFRelease(fname);
    CFAttributedStringSetAttribute(mas, CFRangeMake(C.Range2Start, C.Range2Len),
      kCTFontAttributeName, font2);
  end;
  if C.RightToLeft then
  begin
    dir := kCTWritingDirectionRightToLeft;
    setting.spec := kCTParagraphStyleSpecifierBaseWritingDirection;
    setting.valueSize := SizeOf(dir);
    setting.value := @dir;
    pstyle := CTParagraphStyleCreate(@setting, 1);
    CFAttributedStringSetAttribute(mas, CFRangeMake(0, total), kCTParagraphStyleAttributeName, pstyle);
    CFRelease(pstyle);
  end;
  WriteLn(Format('  font %s %.0f pt, %d UTF-16 units, width %.0f', [C.FontName, C.Size, total, C.Width]));
  ts := CTTypesetterCreateWithAttributedString(CFAttributedStringRef(mas));
  start := 0;
  nline := 0;
  while start < total do
  begin
    if C.Width > 0 then
      count := CTTypesetterSuggestLineBreak(ts, start, C.Width)
    else
      count := total - start;
    if count <= 0 then
      Break;
    line := CTTypesetterCreateLine(ts, CFRangeMake(start, count));
    width := CTLineGetTypographicBounds(line, @ascent, @descent, @leading);
    runs := CTLineGetGlyphRuns(line);
    WriteLn(Format('  line %d text[%d..%d] width=%.2f ascent=%.2f descent=%.2f leading=%.2f runs=%d',
      [nline, start, start + count - 1, width, ascent, descent, leading, CFArrayGetCount(runs)]));
    for i := 0 to CFArrayGetCount(runs) - 1 do
      DumpRun(CTRunRef(CFArrayGetValueAtIndex(runs, i)), str, font);
    CFRelease(line);
    Inc(start, count);
    Inc(nline);
  end;
  CFRelease(ts);
  CFRelease(mas);
  if font2 <> nil then
    CFRelease(font2);
  CFRelease(font);
  CFRelease(str);
  WriteLn;
end;

var
  i: Integer;
begin
  for i := Low(Cases) to High(Cases) do
    RunCase(Cases[i]);
end.

program CoreTextProviderTest;

{ The Core Text text provider of macOS (rtl_fpc/rpinfoprovct.pas) against the
  FreeType one, on the same fonts: the face each one chooses, the metrics, the
  widths and the kerning, and the font stream the PDF embeds (it must be a
  valid font of the same face, also inside a collection). Phase 1 of
  docs/coretext_provider_plan.md.

  macOS only. Exit code 0 when every check passes, 1 otherwise. }

{$mode delphi}{$H+}

uses
  cthreads, cwstring,
  Classes, SysUtils, Types, MacOSAll,
  rptypes, rpinfoprovid, rpinfoprovft, rpinfoprovct;

// Core Graphics reads the embedded font back
{$linkframework CoreGraphics}

type
  TFontCase = record
    Name: string;
    Bold, Italic: Boolean;
    // The face Core Text must choose ('' = do not check)
    Expected: string;
  end;

const
  CFonts: array[0..9] of TFontCase = (
    (Name: 'Arial'; Bold: False; Italic: False; Expected: 'ArialMT'),
    (Name: 'Arial'; Bold: True; Italic: False; Expected: 'Arial-BoldMT'),
    (Name: 'Arial'; Bold: False; Italic: True; Expected: 'Arial-ItalicMT'),
    (Name: 'Times New Roman'; Bold: False; Italic: False; Expected: 'TimesNewRomanPSMT'),
    (Name: 'Helvetica'; Bold: False; Italic: False; Expected: 'Helvetica'),
    (Name: 'Helvetica Neue'; Bold: True; Italic: False; Expected: 'HelveticaNeue-Bold'),
    (Name: 'Courier New'; Bold: False; Italic: False; Expected: 'CourierNewPSMT'),
    (Name: 'Geeza Pro'; Bold: False; Italic: False; Expected: 'GeezaPro'),
    // PostScript names: the face of a substituted run, exactly
    (Name: 'HelveticaNeue-Light'; Bold: False; Italic: False; Expected: 'HelveticaNeue-Light'),
    (Name: 'PingFangSC-Regular'; Bold: False; Italic: False; Expected: 'PingFangSC-Regular')
  );

  CSample: UnicodeString = 'AWaj0 Tofi' + #$00E9#$00F1#$20AC;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AText: string);
begin
  if ACondition then
    WriteLn('   [CHECK OK]     ', AText)
  else
  begin
    WriteLn('   [CHECK FAILED] ', AText);
    Inc(Failures);
  end;
end;

function NewData: TRpTTFontData;
begin
  Result := TRpTTFontData.Create;
  Result.fontdata := TAdvFontData.Create;
end;

// The stream the PDF embeds, read by Core Graphics: a valid font, and of the
// same face. The subset of HarfBuzz keeps the glyph numbers (RETAIN_GIDS) but
// not the name, so the face is checked by the advances of the glyphs used:
// another face of the family (bold, light) has other advances.
function StreamMatchesFace(AStream: TMemoryStream; AData: TRpTTFontData;
  out ADetail: string): Boolean;
var
  provider: CGDataProviderRef;
  font: CGFontRef;
  upem, n, bad: Integer;
  info: TGlyphInfo;
  g: CGGlyph;
  adv: Integer;
  w: Double;
begin
  Result := False;
  ADetail := 'empty stream';
  if (AStream = nil) or (AStream.Size = 0) then
    Exit;
  provider := CGDataProviderCreateWithData(nil, AStream.Memory, AStream.Size, nil);
  font := CGFontCreateWithDataProvider(provider);
  CGDataProviderRelease(provider);
  ADetail := 'not a font';
  if font = nil then
    Exit;
  try
    upem := CGFontGetUnitsPerEm(font);
    n := 0;
    bad := 0;
    for info in AData.glyphsInfo.Values do
    begin
      if info.Glyph = 0 then
        Continue;
      g := CGGlyph(info.Glyph);
      adv := 0;
      CGFontGetGlyphAdvances(font, @g, 1, @adv);
      w := adv * 1000 / upem;
      Inc(n);
      if Abs(w - info.Width) > 1 then
        Inc(bad);
    end;
    ADetail := Format('%d glyphs, %d with another advance', [n, bad]);
    Result := (n > 0) and (bad = 0);
  finally
    CGFontRelease(font);
  end;
end;

function YesNo(AValue: Boolean): string;
begin
  if AValue then
    Result := 'yes'
  else
    Result := 'no';
end;

function IfThen(ACond: Boolean; ATrue, AFalse: Integer): Integer;
begin
  if ACond then
    Result := ATrue
  else
    Result := AFalse;
end;

procedure CompareFont(const C: TFontCase; AFt, ACt: TRpInfoProvider);
var
  pdffont: TRpPDFFont;
  dft, dct: TRpTTFontData;
  i: Integer;
  wft, wct, maxdiff: Double;
  stream: TMemoryStream;
  detail, style: string;
  ftok, matches: Boolean;
  face: TRpCTFace;
begin
  style := '';
  if C.Bold then
    style := style + ' bold';
  if C.Italic then
    style := style + ' italic';
  WriteLn('== ', C.Name, style);
  pdffont := TRpPDFFont.Create;
  dft := NewData;
  dct := NewData;
  try
    pdffont.LFontName := WideString(C.Name);
    pdffont.WFontName := WideString(C.Name);
    pdffont.Bold := C.Bold;
    pdffont.Italic := C.Italic;
    pdffont.Size := 10;
    ftok := True;
    try
      AFt.FillFontData(pdffont, dft, '');
    except
      on E: Exception do
      begin
        WriteLn('   FreeType: ', E.Message);
        ftok := False;
      end;
    end;
    ACt.FillFontData(pdffont, dct, '');
    WriteLn(Format('   %-11s %-28s %-28s', ['', 'FreeType', 'Core Text']));
    if ftok then
    begin
      WriteLn(Format('   %-11s %-28s %-28s', ['face', dft.postcriptname, dct.postcriptname]));
      WriteLn(Format('   %-11s %-28s %-28s', ['file', ExtractFileName(dft.filename) + ' #' + IntToStr(dft.FontIndex),
        ExtractFileName(dct.filename) + ' #' + IntToStr(dct.FontIndex)]));
      WriteLn(Format('   %-11s %-28d %-28d', ['ascent', dft.Ascent, dct.Ascent]));
      WriteLn(Format('   %-11s %-28d %-28d', ['descent', dft.Descent, dct.Descent]));
      WriteLn(Format('   %-11s %-28d %-28d', ['height', dft.Height, dct.Height]));
      WriteLn(Format('   %-11s %-28d %-28d', ['leading', dft.Leading, dct.Leading]));
      WriteLn(Format('   %-11s %-28d %-28d', ['maxwidth', dft.MaxWidth, dct.MaxWidth]));
      WriteLn(Format('   %-11s %-28s %-28s', ['bbox',
        Format('%d,%d,%d,%d', [dft.FontBBox.Left, dft.FontBBox.Bottom, dft.FontBBox.Right, dft.FontBBox.Top]),
        Format('%d,%d,%d,%d', [dct.FontBBox.Left, dct.FontBBox.Bottom, dct.FontBBox.Right, dct.FontBBox.Top])]));
      WriteLn(Format('   %-11s %-28d %-28d', ['flags', dft.Flags, dct.Flags]));
    end
    else
      WriteLn(Format('   %-11s %-28s %-28s', ['face', '-', dct.postcriptname]));
    if C.Expected <> '' then
      Check(Copy(dct.postcriptname, 1, Length(C.Expected)) = C.Expected,
        'Core Text chooses ' + C.Expected + ' (' + dct.postcriptname + ')');
    Check(dct.fontdata.FontData.Size > 0, 'The font file is loaded (' + dct.filename + ')');
    // Widths in thousandths of an em
    maxdiff := 0;
    for i := 1 to Length(CSample) do
    begin
      wct := ACt.GetCharWidth(pdffont, dct, CSample[i]);
      if ftok then
      begin
        wft := AFt.GetCharWidth(pdffont, dft, CSample[i]);
        if Abs(wft - wct) > maxdiff then
          maxdiff := Abs(wft - wct);
      end;
    end;
    WriteLn(Format('   widths "%s": max difference %.3f thousandths of an em',
      [UTF8Encode(CSample), maxdiff]));
    if ftok and (dft.filename = dct.filename) and (dft.FontIndex = dct.FontIndex) then
      Check(maxdiff < 0.5, 'Same face, same widths as FreeType');
    WriteLn(Format('   kerning AV: FreeType %d, Core Text %d; To: %d, %d',
      [IfThen(ftok, AFt.GetKerning(pdffont, dft, 'A', 'V'), 0), ACt.GetKerning(pdffont, dct, 'A', 'V'),
       IfThen(ftok, AFt.GetKerning(pdffont, dft, 'T', 'o'), 0), ACt.GetKerning(pdffont, dct, 'T', 'o')]));
    // The stream the PDF embeds: a valid font of this face
    face := TRpCTFace(dct.fdata);
    WriteLn(Format('   face %d of its file (found: %s), variable: %s',
      [face.FaceIndex, YesNo(face.FaceFound), YesNo(face.Variable)]));
    Check(face.FaceFound, 'The face is found in its file (index ' + IntToStr(face.FaceIndex) + ')');
    stream := ACt.GetFontStream(dct);
    try
      matches := StreamMatchesFace(stream, dct, detail);
      WriteLn(Format('   embedded stream: %d bytes, %s', [stream.Size, detail]));
      if face.Variable then
        WriteLn('   [KNOWN, phase 3] a named instance of a variable face: the',
          ' instance is not embedded yet (', 'it matches: ' + YesNo(matches), ')')
      else
        Check(matches, 'The embedded font is this face (' + detail + ')');
    finally
      if stream <> dct.fontdata.FontData then
        stream.Free;
    end;
  finally
    dft.Free;
    dct.Free;
    pdffont.Free;
  end;
end;

var
  ft, ct: TRpInfoProvider;
  i: Integer;
  s: WideString;
begin
  ft := TRpFTInfoProvider.Create;
  ct := TRpCTInfoProvider.Create;
  try
    for i := Low(CFonts) to High(CFonts) do
    begin
      try
        CompareFont(CFonts[i], ft, ct);
      except
        on E: Exception do
          Check(False, CFonts[i].Name + ': ' + E.ClassName + ': ' + E.Message);
      end;
      WriteLn;
    end;
    WriteLn('== NFC normalization');
    s := ct.NFCNormalize('e' + #$0301 + 'n' + #$0303);
    Check(s = #$00E9#$00F1, 'e + combining acute, n + combining tilde -> é ñ');
  finally
    ct.Free;
    ft.Free;
  end;
  WriteLn;
  if Failures = 0 then
  begin
    WriteLn('Core Text provider: all checks passed');
    Halt(0);
  end
  else
  begin
    WriteLn('Core Text provider: ', Failures, ' checks failed');
    Halt(1);
  end;
end.

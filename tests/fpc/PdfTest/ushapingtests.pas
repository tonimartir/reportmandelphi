unit ushapingtests;

{$mode objfpc}{$H+}

// Found with the sample reports (samples/international.rep, 16-10-2026):
// - Plain text (left to right, not HTML) went to the PDF character by
//   character unless the report asked for exact metrics: an Indic word came
//   out with its vowels in the wrong place and its conjuncts broken, Thai with
//   loose marks, and on macOS a script the font of the object lacks not at
//   all (the substitution of fonts happens in the glyph by glyph output).
//   A text of such a script is now laid out and written glyph by glyph
//   (NeedsComplexShaping in rppdffile), with its /ActualText.
// - The image XObjects declared the size of the bitmap as /Length and wrote
//   it compressed: readers reported "Missing 'endstream' or incorrect stream
//   length" (sample4.rep and its 256 colour bitmaps, and every chart).

interface

function RunShapingTests: Boolean;

implementation

uses
  Classes, SysUtils, StrUtils, rptypes, rpreport, rpsubreport, rpsection,
  rplabelitem, rppdfdriver;

var
  GFailed: Integer;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  if ACondition then
    WriteLn('   OK   ', AWhat)
  else
  begin
    WriteLn('   FAIL ', AWhat);
    Inc(GFailed);
  end;
end;

function TempPDF(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + AName + '_' +
    IntToStr(GetProcessID) + '.pdf';
end;

function LoadBytes(const AFile: string): string;
var
  LBytes: TMemoryStream;
begin
  LBytes := TMemoryStream.Create;
  try
    LBytes.LoadFromFile(AFile);
    SetString(Result, PAnsiChar(LBytes.Memory), LBytes.Size);
  finally
    LBytes.Free;
  end;
end;

// A report with one label in an embedded font, printed to an uncompressed
// PDF: its bytes
function PrintLabel(const AText: WideString; const ALFont, AWFont: string): string;
var
  LReport: TRpReport;
  LSub: TRpSubReport;
  LSection: TRpSection;
  LLabel: TRpLabel;
  LFile: string;
begin
  Result := '';
  LFile := TempPDF('rpshapingtest');
  LReport := TRpReport.Create(nil);
  try
    LSub := LReport.AddSubReport;
    LSection := LSub.Sections[LSub.FirstDetail].Section;
    LLabel := TRpLabel.Create(LReport);
    LLabel.Name := 'LTEXT';
    LLabel.Text := AText;
    LLabel.Type1Font := poEmbedded;
    LLabel.LFontName := ALFont;
    LLabel.WFontName := AWFont;
    LLabel.FontSize := 16;
    LLabel.Width := 8000;
    LLabel.Height := 500;
    LSection.ReportComponents.Add.Component := LLabel;
    if PrintReportPDF(LReport, '', False, True, 1, 9999, 1, LFile, False, False, False) then
      Result := LoadBytes(LFile);
  finally
    LReport.Free;
    DeleteFile(LFile);
  end;
end;

procedure TestComplexScripts;
var
  LHindi, LThai, LLatin: WideString;
  LData: string;
begin
  WriteLn('-- Complex scripts in plain text: written glyph by glyph');
  // dhanyavaad (thank you): a conjunct (n + virama + ya) and a vowel sign
  LHindi := WideChar($0927) + WideChar($0928) + WideChar($094D) + WideChar($092F) +
    WideChar($0935) + WideChar($093E) + WideChar($0926);
  // khop khun (thank you): a vowel mark below its consonant
  LThai := WideChar($0E02) + WideChar($0E2D) + WideChar($0E1A) + WideChar($0E04) +
    WideChar($0E38) + WideChar($0E13);
  LLatin := 'Gracias';
  LData := PrintLabel(LHindi, 'Noto Sans Devanagari', 'Nirmala UI');
  Check(LData <> '', 'the Devanagari report printed');
  Check(Pos('/ActualText', LData) > 0, 'Devanagari is shaped (ActualText)');
  LData := PrintLabel(LThai, 'Noto Sans Thai', 'Leelawadee UI');
  Check(LData <> '', 'the Thai report printed');
  Check(Pos('/ActualText', LData) > 0, 'Thai is shaped (ActualText)');
  LData := PrintLabel(LLatin, 'DejaVu Sans', 'Arial');
  Check(LData <> '', 'the Latin report printed');
  Check(Pos('/ActualText', LData) = 0, 'plain Latin text keeps the simple output');
end;

// Every image XObject: its /Length bytes end where endstream starts
procedure CheckImageLengths(const AData, AWhat: string);
var
  p, q, s, len, images, bad: Integer;
  dict, lenText: string;
begin
  images := 0;
  bad := 0;
  p := Pos('/Subtype /Image', AData);
  while p > 0 do
  begin
    Inc(images);
    q := PosEx('stream', AData, p);
    dict := Copy(AData, p, q - p);
    s := Pos('/Length ', dict);
    lenText := '';
    if s > 0 then
    begin
      s := s + Length('/Length ');
      while (s <= Length(dict)) and (dict[s] in ['0'..'9']) do
      begin
        lenText := lenText + dict[s];
        Inc(s);
      end;
    end;
    len := StrToIntDef(lenText, -1);
    // The data starts after 'stream' and its end of line
    s := q + Length('stream');
    if (s <= Length(AData)) and (AData[s] = #13) then
      Inc(s);
    if (s <= Length(AData)) and (AData[s] = #10) then
      Inc(s);
    q := s + len;
    while (q <= Length(AData)) and (AData[q] in [#13, #10]) do
      Inc(q);
    if (len < 0) or (Copy(AData, q, 9) <> 'endstream') then
      Inc(bad);
    p := PosEx('/Subtype /Image', AData, p + 1);
  end;
  Check(images > 0, AWhat + ': ' + IntToStr(images) + ' images');
  Check(bad = 0, AWhat + ': the /Length of every image is its data (' + IntToStr(bad) + ' wrong)');
end;

function FindSample(const AFileName: string): string;
begin
  Result := '..' + PathDelim + '..' + PathDelim + '..' + PathDelim + 'repman' +
    PathDelim + 'repsamples' + PathDelim + AFileName;
  if not FileExists(Result) then
    Result := ExtractFilePath(ParamStr(0)) + Result;
end;

procedure TestImageLengths;
var
  LReport: TRpReport;
  LFile, LRep: string;
  LCompressed: Boolean;
begin
  WriteLn('-- Image XObjects: /Length of the data written');
  LRep := FindSample('sample4.rep');
  if not FileExists(LRep) then
  begin
    Check(False, 'sample4.rep found');
    Exit;
  end;
  for LCompressed := False to True do
  begin
    LFile := TempPDF('rpimagelength');
    LReport := TRpReport.Create(nil);
    try
      LReport.LoadFromFile(LRep);
      if PrintReportPDF(LReport, '', False, True, 1, 9999, 1, LFile, LCompressed, False, False) then
        CheckImageLengths(LoadBytes(LFile), SysUtils.BoolToStr(LCompressed, 'compressed', 'uncompressed'))
      else
        Check(False, 'sample4.rep printed');
    finally
      LReport.Free;
      DeleteFile(LFile);
    end;
  end;
end;

function RunShapingTests: Boolean;
begin
  WriteLn('--------------------------------------------------');
  WriteLn('Shaping of complex scripts and image streams');
  WriteLn('--------------------------------------------------');
  GFailed := 0;
  TestComplexScripts;
  TestImageLengths;
  Result := GFailed = 0;
  WriteLn;
end;

end.

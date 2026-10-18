program html_layout_test;

{ The layout of an HTML text (18-10-2026), the two bugs fixed in the C# port
  the same day (Reportman.Drawing FontInfoFt.cs, Reportman.Reporting
  ExpressionItem.cs), checked in this engine:

  1. An empty line of an HTML text takes its height: "a<br><br>b" is three
     lines. The FreeType provider (rpinfoprovft, Linux) only added a line that
     had glyphs, so the blank one vanished when measuring and drawing, and the
     paragraphs of a contract came out one against the other. Core Text
     (macOS) kept its height but gave it no line, which the split of a
     multipage text counts.
  2. A MultiPage HTML expression in an AutoExpand section is measured at its
     width: TrySplitHtmlForMultipage measured at PrintWidth, which is only set
     once the item has been printed. When the section was measured before
     that, the width was 0, the text never fitted, the section took the rest
     of the page, and what followed it went to the next one.
  3. Measuring an HTML text does not leak: the FreeType layout lost its line
     objects, their lists, the bidi runs and the dictionaries of a font data
     on every measure (fixed the same night).

  Delphi (Windows: DirectWrite) and FPC (Linux: FreeType; macOS: Core Text).
  Exit code 0 when every check passes. }

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}
{$APPTYPE CONSOLE}

uses
{$IFDEF UNIX}
  cwstring,
{$ENDIF}
  SysUtils, Classes, Types,
  rptypes, rpmetafile, rpreport, rpsubreport, rpsection, rplabelitem,
  rppdfdriver;

const
  BoxWidth = 10000;

var
  Failures: Integer;

procedure Check(AOk: Boolean; const AName: string; const ADetail: string = '');
begin
  if AOk then
    WriteLn('[PASS] ', AName)
  else
  begin
    if ADetail <> '' then
      WriteLn('[FAIL] ', AName, ' -> ', ADetail)
    else
      WriteLn('[FAIL] ', AName);
    Inc(Failures);
  end;
end;

function TextObject(const AHtml: WideString): TRpTextObject;
begin
  Result.Text := AHtml;
  Result.LFontName := 'DejaVu Sans';
  Result.WFontName := 'Arial';
  Result.FontSize := 10;
  Result.FontRotation := 0;
  Result.FontStyle := 0;
  Result.FontColor := 0;
  Result.Type1Font := Integer(poEmbedded);
  Result.CutText := False;
  Result.Alignment := 0;
  Result.WordWrap := True;
  Result.RightToLeft := False;
  Result.PrintStep := rpselectsize;
  Result.Annotation := '';
  Result.IsHtml := True;
end;

// The lines of an HTML text 10000 twips wide, and its height
function Measure(const AHtml: WideString; out AHeight: Integer): Integer;
var
  LDriver: TRpPDFDriver;
  LExtent: TPoint;
  LLines: TRpLineInfoArray;
begin
  LDriver := TRpPDFDriver.Create;
  try
    LExtent := Point(BoxWidth, 100000);
    LLines := LDriver.TextExtentLineInfo(TextObject(AHtml), LExtent);
    AHeight := LExtent.Y;
    Result := Length(LLines);
  finally
    LDriver.Free;
  end;
end;

// The sum of the heights of the lines, as TrySplitHtmlForMultipage counts them
function LinesHeight(const AHtml: WideString): Integer;
var
  LDriver: TRpPDFDriver;
  LExtent: TPoint;
  LLines: TRpLineInfoArray;
  I: Integer;
begin
  Result := 0;
  LDriver := TRpPDFDriver.Create;
  try
    LExtent := Point(BoxWidth, 100000);
    LLines := LDriver.TextExtentLineInfo(TextObject(AHtml), LExtent);
    for I := 0 to High(LLines) do
      Result := Result + LLines[I].Height;
  finally
    LDriver.Free;
  end;
end;

// The memory the program holds now, in bytes
function HeapUsed: Int64;
{$IFDEF FPC}
begin
  Result := GetFPCHeapStatus.CurrHeapUsed;
end;
{$ELSE}
var
  LState: TMemoryManagerState;
  I: Integer;
begin
  GetMemoryManagerState(LState);
  Result := Int64(LState.TotalAllocatedMediumBlockSize) + Int64(LState.TotalAllocatedLargeBlockSize);
  for I := Low(LState.SmallBlockTypeStates) to High(LState.SmallBlockTypeStates) do
    Result := Result + Int64(LState.SmallBlockTypeStates[I].UseableBlockSize) *
      Int64(LState.SmallBlockTypeStates[I].AllocatedBlockCount);
end;
{$ENDIF}

// Measuring an HTML text many times holds no more memory than measuring it
// once: styles, a font change, paragraphs, a blank line and lines broken by
// the width (BreakChunks), as wide and as narrow
procedure TestNoLeak;
const
  Html = '<p><b>Paragraph</b> one, <i>some words in italics</i> and <font face="Courier New">' +
    'a change of font</font> that goes on until the line breaks.</p><br><p>Paragraph two ' +
    'after a blank line, long enough to be broken in several lines too.</p>';
  Rounds = 300;
var
  LDriver: TRpPDFDriver;
  LExtent: TPoint;
  I: Integer;
  LBefore, LAfter: Int64;

  procedure MeasureBoth;
  begin
    LExtent := Point(BoxWidth, 100000);
    LDriver.TextExtentLineInfo(TextObject(Html), LExtent);
    LExtent := Point(2500, 100000);
    LDriver.TextExtentLineInfo(TextObject(Html), LExtent);
  end;

begin
  WriteLn('-- Measuring an HTML text does not leak');
  LDriver := TRpPDFDriver.Create;
  try
    // The caches of the fonts fill on the first measures
    for I := 1 to 20 do
      MeasureBoth;
    LBefore := HeapUsed;
    for I := 1 to Rounds do
      MeasureBoth;
    LAfter := HeapUsed;
  finally
    LDriver.Free;
  end;
  Check(LAfter - LBefore < 64 * 1024, Format('%d measures hold no more memory', [2 * Rounds]),
    Format('%d bytes more (%d per measure)', [LAfter - LBefore, (LAfter - LBefore) div (2 * Rounds)]));
end;

procedure TestBlankLines;
var
  LTwo, LThree, LFour, LLine, LSlack, LDummy: Integer;
  LCount2, LCount3, LCount4: Integer;
begin
  WriteLn('-- An empty line of an HTML text takes its height');
  LCount2 := Measure('alpha<br>omega', LTwo);
  LCount3 := Measure('alpha<br><br>omega', LThree);
  LCount4 := Measure('alpha<br><br><br>omega', LFour);
  // The height of one line, and the rounding of the providers (DirectWrite
  // places each line at its rounded baseline)
  LLine := LinesHeight('alpha');
  LSlack := LLine div 20 + 2;
  Check((LTwo > 0) and (LLine > 0), 'two lines have a height', Format('h=%d line=%d', [LTwo, LLine]));
  Check(Abs(LThree - LTwo - LLine) <= LSlack, 'an empty line adds one line of height',
    Format('2 lines=%d 3 lines=%d line=%d', [LTwo, LThree, LLine]));
  Check(Abs(LFour - LTwo - 2 * LLine) <= 2 * LSlack, 'two empty lines add two lines of height',
    Format('2 lines=%d 4 lines=%d line=%d', [LTwo, LFour, LLine]));
  Check((LCount2 = 2) and (LCount3 = 3) and (LCount4 = 4), 'an empty line is a line',
    Format('lines %d, %d, %d (2, 3, 4 expected)', [LCount2, LCount3, LCount4]));
  Check(Abs(LinesHeight('alpha<br><br>omega') - LThree) <= LSlack,
    'the lines add up to the height measured (what the split of a multipage text counts)',
    Format('lines=%d height=%d', [LinesHeight('alpha<br><br>omega'), LThree]));
  // Information only: how a newline of the source between paragraphs is taken
  Measure('<p>alpha</p>'#10'<p>omega</p>', LDummy);
  WriteLn('   (info) "<p>alpha</p>\n<p>omega</p>" measures ', LDummy, ', "alpha<br><br>omega" ', LThree);
end;

function Paragraphs(ACount: Integer): WideString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
    Result := Result + '<p><b>Paragraph ' + IntToStr(I) + ' </b>The provider maintains the software, ' +
      'answers the incidents and delivers the new versions while the contract is in force.</p>';
end;

// The report of a contract: the text in an AutoExpand section, the signatures
// (a label AFTER) in another subreport
function ContractReport(const AHtml: WideString; AMultiPage: Boolean): TRpReport;
var
  LSub: TRpSubReport;
  LSection: TRpSection;
  LExpression: TRpExpression;
  LLabel: TRpLabel;
begin
  Result := TRpReport.Create(nil);
  // Every page stays in the metafile after printing (as PrintReportToMetafile)
  Result.TwoPass := True;
  LSub := Result.AddSubReport;
  LSection := LSub.Sections[LSub.FirstDetail].Section;
  LSection.Height := 600;
  LSection.AutoExpand := True;
  LExpression := TRpExpression.Create(Result);
  LExpression.Name := 'ETEXT';
  LExpression.PosX := 0;
  LExpression.PosY := 100;
  LExpression.Width := BoxWidth;
  LExpression.Height := 400;
  LExpression.LFontName := 'DejaVu Sans';
  LExpression.WFontName := 'Arial';
  LExpression.FontSize := 10;
  LExpression.Type1Font := poEmbedded;
  LExpression.Transparent := True;
  LExpression.WordWrap := True;
  LExpression.CutText := False;
  LExpression.IsHtml := True;
  LExpression.MultiPage := AMultiPage;
  LExpression.Expression := '''' + StringReplace(AHtml, '''', '''''', [rfReplaceAll]) + '''';
  LSection.ReportComponents.Add.Component := LExpression;

  LSub := Result.AddSubReport;
  LSection := LSub.Sections[LSub.FirstDetail].Section;
  LSection.Height := 2000;
  LLabel := TRpLabel.Create(Result);
  LLabel.Name := 'LAFTER';
  LLabel.PosX := 0;
  LLabel.PosY := 0;
  LLabel.Width := BoxWidth;
  LLabel.Height := 300;
  LLabel.LFontName := 'DejaVu Sans';
  LLabel.WFontName := 'Arial';
  LLabel.FontSize := 10;
  LLabel.Type1Font := poEmbedded;
  LLabel.Transparent := True;
  LLabel.Text := 'AFTER';
  LSection.ReportComponents.Add.Component := LLabel;
end;

function TempPdf: string;
begin
  Result := ExtractFilePath(ExpandFileName(ParamStr(0))) + 'html_layout_test_' +
    IntToStr(Random(1000000)) + '.pdf';
end;

// Prints the report to a PDF and returns the page count, the page and top of
// the label AFTER, and every text printed
procedure PrintContract(const AHtml: WideString; AMultiPage: Boolean;
  out APages, APage, ATop: Integer; out AAll: string);
var
  LReport: TRpReport;
  LFile: string;
  P, I: Integer;
  LPage: TRpMetafilePage;
  LText: WideString;
begin
  APages := 0;
  APage := -1;
  ATop := -1;
  AAll := '';
  LFile := TempPdf;
  LReport := ContractReport(AHtml, AMultiPage);
  try
    if not PrintReportPDF(LReport, '', False, True, 1, 9999, 1, LFile, False, False, False) then
      raise Exception.Create('the report did not print');
    APages := LReport.Metafile.CurrentPageCount;
    for P := 0 to LReport.Metafile.CurrentPageCount - 1 do
    begin
      LPage := LReport.Metafile.Pages[P];
      for I := 0 to LPage.ObjectCount - 1 do
        if LPage.Objects[I].Metatype = rpMetaText then
        begin
          LText := LPage.GetText(LPage.Objects[I]);
          AAll := AAll + string(LText) + ' ';
          if (LText = 'AFTER') and (APage < 0) then
          begin
            APage := P;
            ATop := LPage.Objects[I].Top;
          end;
        end;
    end;
  finally
    LReport.Free;
    DeleteFile(LFile);
  end;
end;

procedure TestMultiPageExtent;
var
  LPagesOn, LPageOn, LTopOn, LPagesOff, LPageOff, LTopOff: Integer;
  LPages, LPage, LTop: Integer;
  LAll: string;
begin
  WriteLn('-- A multipage HTML expression in an AutoExpand section measures itself at its width');
  PrintContract(Paragraphs(12), True, LPagesOn, LPageOn, LTopOn, LAll);
  PrintContract(Paragraphs(12), False, LPagesOff, LPageOff, LTopOff, LAll);
  Check((LPagesOff = 1) and (LPageOff = 0), 'without MultiPage the text and what follows fit on one page',
    Format('pages=%d page=%d', [LPagesOff, LPageOff]));
  Check((LPagesOn = 1) and (LPageOn = 0), 'with MultiPage, what follows a text that fits stays on the first page',
    Format('pages=%d page=%d top=%d', [LPagesOn, LPageOn, LTopOn]));
  Check(LTopOn = LTopOff, 'with MultiPage, what follows starts where it starts without MultiPage',
    Format('with=%d without=%d', [LTopOn, LTopOff]));

  PrintContract(Paragraphs(90), True, LPages, LPage, LTop, LAll);
  WriteLn('   (info) long text: ', LPages, ' pages, ', Length(LAll), ' characters printed: ', Copy(LAll, 1, 160));
  Check(LPages > 1, 'a text that does not fit continues on the next page', Format('pages=%d', [LPages]));
  Check((Pos('Paragraph 1 ', LAll) > 0) and (Pos('Paragraph 90 ', LAll) > 0), 'nothing of the long text is lost');
  Check(LPage = LPages - 1, 'what follows the long text comes after it',
    Format('AFTER on page %d of %d', [LPage + 1, LPages]));
end;

begin
  Randomize;
  Failures := 0;
  try
    TestBlankLines;
    TestMultiPageExtent;
    TestNoLeak;
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] exception: ', E.ClassName, ': ', E.Message);
      Inc(Failures);
    end;
  end;
  if Failures = 0 then
    WriteLn('ALL PASS')
  else
    WriteLn(Failures, ' FAILURE(S)');
  ExitCode := Ord(Failures > 0);
end.

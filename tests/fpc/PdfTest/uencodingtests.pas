unit uencodingtests;

{$mode objfpc}{$H+}

// Found with the PostgreSQL example (examples/lazarus/postgresql) on macOS:
// - The PDF standard fonts (Helvetica, Courier, Times) use WinAnsiEncoding,
//   and the FPC strings are UTF-8 on Linux and macOS: an e acute was written
//   as its two UTF-8 bytes, and the reader showed two characters.
// - Zeos gives a numeric without precision (quantity * price) as a
//   TFMTBCDField, whose FMTBcd variant FPC can not add to an integer: the
//   aggregates (they start at 0) raised "Invalid variant operation".

interface

function RunEncodingTests: Boolean;

implementation

uses
  Classes, SysUtils, Variants, DB, BufDataset, FmtBCD, rptypes, rptypeval,
  rpreport, rpsubreport, rpsection, rplabelitem, rppdffile, rppdfdriver;

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

// 'Caf', e acute, euro, left and right double quotes and an em dash: Latin-1
// and four of the characters Windows-1252 places at $80-$9F
function WinAnsiText: WideString;
begin
  Result := 'Caf' + WideChar($00E9) + ' ' + WideChar($20AC) + ' ' +
    WideChar($201C) + 'x' + WideChar($201D) + ' ' + WideChar($2014);
end;

// The bytes outside ASCII as #$xx, to show what was written
function Escaped(const AText: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(AText) do
    if (Ord(AText[i]) < 32) or (Ord(AText[i]) > 126) then
      Result := Result + '#$' + IntToHex(Ord(AText[i]), 2)
    else
      Result := Result + AText[i];
end;

procedure TestCompatibleText;
var
  LText: string;
begin
  WriteLn('-- PDF standard fonts: WinAnsiEncoding bytes');
  LText := PDFCompatibleText(WinAnsiText, nil, nil);
  Check(LText = '(Caf'#$E9' '#$80' '#$93'x'#$94' '#$97')',
    'PDFCompatibleText writes Windows-1252 bytes');
end;

// The same text in a label of a report, printed to an uncompressed PDF
procedure TestReportPDF;
var
  LReport: TRpReport;
  LSub: TRpSubReport;
  LSection: TRpSection;
  LLabel: TRpLabel;
  LFile: string;
  LBytes: TMemoryStream;
  LData: string;
begin
  WriteLn('-- PDF standard fonts: a report with accents and Windows-1252 symbols');
  LFile := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'rpencodingtest_' +
    IntToStr(GetProcessID) + '.pdf';
  LReport := TRpReport.Create(nil);
  LBytes := TMemoryStream.Create;
  try
    LSub := LReport.AddSubReport;
    LSection := LSub.Sections[LSub.FirstDetail].Section;
    LLabel := TRpLabel.Create(LReport);
    LLabel.Name := 'LWINANSI';
    LLabel.Text := WinAnsiText;
    LLabel.Type1Font := poHelvetica;
    LLabel.Width := 6000;
    LLabel.Height := 300;
    LSection.ReportComponents.Add.Component := LLabel;
    Check(PrintReportPDF(LReport, '', False, True, 1, 9999, 1, LFile, False, False, False),
      'report printed');
    LBytes.LoadFromFile(LFile);
    SetString(LData, PAnsiChar(LBytes.Memory), LBytes.Size);
    Check(Pos('/BaseFont /Helvetica', LData) > 0, 'standard font Helvetica');
    Check(Pos('(Caf'#$E9' '#$80' '#$93'x'#$94' '#$97')', LData) > 0,
      'the text is written in Windows-1252: ' + Escaped(Copy(LData, Pos('Caf', LData) - 2, 40)));
    Check(Pos('Caf'#$C3#$A9, LData) = 0, 'no UTF-8 bytes in the text');
  finally
    LBytes.Free;
    LReport.Free;
    DeleteFile(LFile);
  end;
end;

procedure TestFMTBcdField;
var
  LData: TBufDataset;
  LIden: TIdenField;
  LValue, LSum: Variant;
begin
  WriteLn('-- A TFMTBCDField in an expression and an aggregate');
  LData := TBufDataset.Create(nil);
  LIden := TIdenField.CreateField(nil, 'AMOUNT');
  try
    LData.FieldDefs.Add('AMOUNT', ftFMTBcd, 2);
    LData.CreateDataset;
    LData.Append;
    LData.Fields[0].AsBCD := DoubleToBCD(1798.5);
    LData.Post;
    LData.First;
    Check(VarIsFMTBcd(LData.Fields[0].AsVariant), 'the field gives a FMTBcd variant');
    LIden.Field := LData.Fields[0];
    LValue := LIden.Value;
    Check(VarType(LValue) = varDouble, 'the expression value is a Double');
    LSum := 0;
    try
      LSum := LSum + LValue;
      Check(Abs(Double(LSum) - 1798.5) < 0.001, 'added to an integer 0: ' + VarToStr(LSum));
    except
      on E: Exception do
        Check(False, 'added to an integer 0: ' + E.Message);
    end;
  finally
    LIden.Free;
    LData.Free;
  end;
end;

function RunEncodingTests: Boolean;
begin
  WriteLn('==================================================');
  WriteLn('Encodings and field types (PDF standard fonts, FMTBcd)');
  GFailed := 0;
  try
    TestCompatibleText;
    TestReportPDF;
    TestFMTBcdField;
  except
    on E: Exception do
    begin
      WriteLn('   FAIL exception ', E.ClassName, ': ', E.Message);
      Inc(GFailed);
    end;
  end;
  WriteLn('Encodings: ', GFailed, ' failed checks');
  Result := GFailed = 0;
end;

end.

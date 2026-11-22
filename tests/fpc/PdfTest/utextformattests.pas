unit utextformattests;

{$mode objfpc}{$H+}

// The text stream format of the reports (rpStreamText, the default). FPC
// 3.2.2's ObjectBinaryToText raised on Null, Single, Currency and Date
// values (a report with a parameter without value could not be saved) and
// wrote the non ASCII characters of string properties byte by byte; its
// ObjectTextToBinary read Null as an identifier. rpstreamfpc converts them
// as Delphi does, breaks long strings as Delphi (its TParser does not read a
// line of 4096 bytes) and writes the string properties of the binary format
// as Delphi (not the bytes of UTF-8 as a vaString). The files the last two
// tests leave in the temporary folder (rpstreamfpc-*.rep) are for Delphi to
// read them (tools/golden-dfm -xml of the TypeScript engine).

interface

function RunTextFormatTests: Boolean;

implementation

uses
  Classes, SysUtils, Variants, rptypes, rpreport, rpparams, rpstreamfpc;

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

// n with tilde and e acute, built at run time (see uembeddedtests)
function Accented(const APrefix: string): string;
var
  LText: UnicodeString;
begin
  SetLength(LText, 2);
  LText[1] := WideChar($00F1);
  LText[2] := WideChar($00E9);
  Result := APrefix + string(LText);
end;

function SaveAndLoadText(ARep: TRpReport; out AText: string): TRpReport;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    ARep.StreamFormat := rpStreamText;
    ARep.SaveToStream(LStream);
    SetString(AText, PAnsiChar(LStream.Memory), LStream.Size);
    LStream.Position := 0;
    Result := TRpReport.Create(nil);
    try
      Result.LoadFromStream(LStream);
    except
      Result.Free;
      raise;
    end;
  finally
    LStream.Free;
  end;
end;

// FPC 3.2.2 TBinaryObjectWriter.WriteCurrency truncates the value
procedure TestBinaryCurrency;
var
  LRep, LRep2: TRpReport;
  LStream: TMemoryStream;
  LParam: TRpParam;
begin
  WriteLn('-- Binary format: Currency values keep their decimals');
  LRep := TRpReport.Create(nil);
  LStream := TMemoryStream.Create;
  try
    LRep.CreateNew;
    LParam := LRep.Params.Add('PCUR');
    LParam.ParamType := rpParamCurrency;
    LParam.Value := Currency(1234.5678);
    LRep.StreamFormat := rpStreamBinary;
    LRep.SaveToStream(LStream);
    LStream.Position := 0;
    LRep2 := TRpReport.Create(nil);
    try
      LRep2.LoadFromStream(LStream);
      Check(LRep2.Params.ParamByName('PCUR').Value = Currency(1234.5678),
        'Currency parameter read back from the binary format: ' +
        VarToStr(LRep2.Params.ParamByName('PCUR').Value));
    finally
      LRep2.Free;
    end;
  finally
    LStream.Free;
    LRep.Free;
  end;
end;

procedure TestRoundTrip;
var
  LRep, LRep2: TRpReport;
  LText: string;
  LParam: TRpParam;
begin
  WriteLn('-- Text format: Null, Currency, Date values and non ASCII strings');
  LRep := TRpReport.Create(nil);
  try
    LRep.CreateNew;
    // A new parameter has no value (Null)
    LRep.Params.Add('PNULL');
    LParam := LRep.Params.Add('PCUR');
    LParam.ParamType := rpParamCurrency;
    LParam.Value := Currency(1234.5678);
    LParam := LRep.Params.Add('PDATE');
    LParam.ParamType := rpParamDate;
    LParam.Value := VarFromDateTime(EncodeDate(2026, 9, 28));
    LParam := LRep.Params.Add('PSTR');
    LParam.Value := Accented('Valor ');
    LRep.DocAuthor := Accented('Autor ');
    LRep2 := nil;
    try
      LRep2 := SaveAndLoadText(LRep, LText);
      Check(Pos('Null', LText) > 0, 'Null written as Null');
      Check(Pos('12345678c', LText) > 0, 'Currency written in 1/10000 units with c');
      Check(Pos('#241#233', LText) > 0, 'non ASCII characters written as Unicode codes');
      Check(VarIsNull(LRep2.Params.ParamByName('PNULL').Value), 'Null parameter read back');
      Check((VarType(LRep2.Params.ParamByName('PCUR').Value) = varCurrency) and
        (LRep2.Params.ParamByName('PCUR').Value = Currency(1234.5678)), 'Currency parameter read back');
      Check((VarType(LRep2.Params.ParamByName('PDATE').Value) = varDate) and
        (VarToDateTime(LRep2.Params.ParamByName('PDATE').Value) = EncodeDate(2026, 9, 28)),
        'Date parameter read back');
      Check(VarToStr(LRep2.Params.ParamByName('PSTR').Value) = Accented('Valor '),
        'non ASCII parameter value read back');
      Check(LRep2.DocAuthor = Accented('Autor '), 'non ASCII string property read back');
    finally
      LRep2.Free;
    end;
  finally
    LRep.Free;
  end;
end;

// Text written by Delphi: Null, typed floats and Unicode codes
procedure TestDelphiText;
const
  DELPHI_TEXT =
    'object TRpReport' + LineEnding +
    '  Params = <' + LineEnding +
    '    item' + LineEnding +
    '      Name = ''PNULL''' + LineEnding +
    '      Value = Null' + LineEnding +
    '    end' + LineEnding +
    '    item' + LineEnding +
    '      Name = ''PCUR''' + LineEnding +
    '      Value = 12345678c' + LineEnding +
    '      ParamType = rpParamCurrency' + LineEnding +
    '    end' + LineEnding +
    '    item' + LineEnding +
    '      Name = ''PSTR''' + LineEnding +
    '      Value = ''Valor ''#241#233' + LineEnding +
    '    end>' + LineEnding +
    '  DocAuthor = ''Autor ''#241#233' + LineEnding +
    'end' + LineEnding;
var
  LIn, LBin, LText: TMemoryStream;
  LStr: string;
begin
  WriteLn('-- Text format: text in the Delphi form to binary and back');
  LIn := TMemoryStream.Create;
  LBin := TMemoryStream.Create;
  LText := TMemoryStream.Create;
  try
    LStr := DELPHI_TEXT;
    LIn.WriteBuffer(LStr[1], Length(LStr));
    LIn.Position := 0;
    RpObjectTextToBinary(LIn, LBin);
    LBin.Position := 0;
    RpObjectBinaryToText(LBin, LText);
    SetString(LStr, PAnsiChar(LText.Memory), LText.Size);
    Check(Pos('Value = Null', LStr) > 0, 'Null kept');
    Check(Pos('Value = 12345678c', LStr) > 0, 'Currency kept');
    Check(Pos('''Valor ''#241#233', LStr) > 0, 'Unicode codes kept');
    Check(Pos('ParamType = rpParamCurrency', LStr) > 0, 'identifiers kept');
  finally
    LText.Free;
    LBin.Free;
    LIn.Free;
  end;
end;

// The longest line of a text
function LongestLine(const AText: string): Integer;
var
  i, LStart: Integer;
begin
  Result := 0;
  LStart := 1;
  for i := 1 to Length(AText) + 1 do
    if (i > Length(AText)) or (AText[i] = #10) then
    begin
      if i - LStart > Result then
        Result := i - LStart;
      LStart := i + 1;
    end;
end;

function StreamText(AStream: TMemoryStream): string;
begin
  SetString(Result, PAnsiChar(AStream.Memory), AStream.Size);
end;

// A sample report: its text read and written again gives the same binary,
// with every line well under the 4096 bytes TParser of Delphi reads
procedure TestSampleRoundTrip(const ASamplePath: string);
var
  LFile, LBin, LText, LBin2: TMemoryStream;
begin
  WriteLn('-- Text format: a sample report, read and written again');
  if not FileExists(ASamplePath) then
  begin
    WriteLn('   SKIP sample not found: ', ASamplePath);
    Exit;
  end;
  LFile := TMemoryStream.Create;
  LBin := TMemoryStream.Create;
  LText := TMemoryStream.Create;
  LBin2 := TMemoryStream.Create;
  try
    LFile.LoadFromFile(ASamplePath);
    LFile.Position := 0;
    RpObjectTextToBinary(LFile, LBin);
    LBin.Position := 0;
    RpObjectBinaryToText(LBin, LText);
    LText.Position := 0;
    RpObjectTextToBinary(LText, LBin2);
    Check((LBin.Size = LBin2.Size) and CompareMem(LBin.Memory, LBin2.Memory, LBin.Size),
      'the same binary from its text for ' + ExtractFileName(ASamplePath));
    Check(LongestLine(StreamText(LText)) <= 400, 'no line longer than 400 bytes: ' +
      IntToStr(LongestLine(StreamText(LText))));
  finally
    LBin2.Free;
    LText.Free;
    LBin.Free;
    LFile.Free;
  end;
end;

// The code page of an LCL program (LazUTF8), for the strings with
// characters outside the ANSI code page
procedure UseUtf8(out ASaved: TSystemCodePage);
begin
  ASaved := DefaultSystemCodePage;
  DefaultSystemCodePage := CP_UTF8;
end;

// 63 x, an emoji (two UTF-16 code units, split by the line break), a quote,
// n with tilde, the euro sign, 70 y and a line break
function LayoutTitle: UnicodeString;
begin
  Result := UnicodeString(StringOfChar('x', 63)) + WideChar($D83D) + WideChar($DE00) +
    ' a''b ' + WideChar($00F1) + WideChar($20AC) + UnicodeString(StringOfChar('y', 70)) +
    #13#10'z';
end;

// A long string is written as ObjectBinaryToText of Delphi writes it (the
// text below is what Delphi wrote for this DocTitle)
procedure TestDelphiLayout;
var
  LRep, LRep2: TRpReport;
  LText, LExpected: string;
  LSaved: TSystemCodePage;
begin
  WriteLn('-- Text format: a long string is broken as Delphi does');
  UseUtf8(LSaved);
  LRep := TRpReport.Create(nil);
  LRep2 := nil;
  try
    LRep.CreateNew;
    LRep.DocTitle := string(LayoutTitle);
    LRep2 := SaveAndLoadText(LRep, LText);
    LExpected := '  DocTitle = ' + LineEnding +
      '    ''' + StringOfChar('x', 63) + '''#55357 +' + LineEnding +
      '    #56832'' a''#39''b ''#241#8364''' + StringOfChar('y', 56) + ''' +' + LineEnding +
      '    ''' + StringOfChar('y', 14) + '''#13#10''z''' + LineEnding;
    Check(Pos(LExpected, LText) > 0, 'the lines Delphi writes for a string of 145 characters');
    Check(UnicodeString(LRep2.DocTitle) = LayoutTitle, 'the string read back');
  finally
    LRep2.Free;
    LRep.Free;
    DefaultSystemCodePage := LSaved;
  end;
end;

// Where a test leaves the files Delphi has to read (tools/golden-dfm -xml)
function DelphiCheckFile(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + 'rpstreamfpc-' + AName;
end;

// A string far longer than the buffer of TParser of Delphi (a SQL of 6000
// characters), in the text format: short lines, and the same SQL read back
procedure TestLongString;
var
  LRep, LRep2: TRpReport;
  LText: string;
  LSql: UnicodeString;
  i: Integer;
  LSaved: TSystemCodePage;
  LFile: TStringList;
begin
  WriteLn('-- Text format: a string of 6000 characters');
  UseUtf8(LSaved);
  LRep := TRpReport.Create(nil);
  LRep2 := nil;
  try
    LRep.CreateNew;
    LSql := 'select ';
    for i := 1 to 520 do
      LSql := LSql + 'campo' + UnicodeString(IntToStr(i)) + WideChar($00F1) + WideChar($4E2D) + ', ';
    LSql := LSql + '1 from t';
    LRep.DataInfo.Add('DATOS').SQL := LSql;
    LRep2 := SaveAndLoadText(LRep, LText);
    Check(Length(LSql) > 6000, 'the SQL has ' + IntToStr(Length(LSql)) + ' characters');
    Check(LongestLine(LText) <= 400, 'no line longer than 400 bytes: ' + IntToStr(LongestLine(LText)));
    Check(LRep2.DataInfo.Items[0].SQL = LSql, 'the SQL read back');
    LFile := TStringList.Create;
    try
      LFile.Text := LText;
      LFile.SaveToFile(DelphiCheckFile('long.text.rep'));
    finally
      LFile.Free;
    end;
  finally
    LRep2.Free;
    LRep.Free;
    DefaultSystemCodePage := LSaved;
  end;
end;

// The value type of a string in the binary stream (vaString 6,
// vaWString 18, vaUTF8String 20), or -1
function ValueTypeOf(AStream: TMemoryStream; const AUtf8: RawByteString;
  const AWide: UnicodeString): Integer;
var
  LBytes: PByte;
  i: Integer;
begin
  Result := -1;
  LBytes := AStream.Memory;
  for i := 0 to AStream.Size - 6 do
  begin
    if (LBytes[i] = 20) and (PLongInt(@LBytes[i + 1])^ = Length(AUtf8)) and
      (i + 5 + Length(AUtf8) <= AStream.Size) and CompareMem(@LBytes[i + 5], @AUtf8[1], Length(AUtf8)) then
      Exit(20);
    if (LBytes[i] = 18) and (PLongInt(@LBytes[i + 1])^ = Length(AWide)) and
      (i + 5 + 2 * Length(AWide) <= AStream.Size) and CompareMem(@LBytes[i + 5], @AWide[1], 2 * Length(AWide)) then
      Exit(18);
    if (LBytes[i] = 6) and (LBytes[i + 1] = Length(AUtf8)) and
      (i + 2 + Length(AUtf8) <= AStream.Size) and CompareMem(@LBytes[i + 2], @AUtf8[1], Length(AUtf8)) then
      Exit(6);
  end;
end;

// The string properties in the binary format, as Delphi writes them: UTF-8
// when it is shorter than UTF-16, else UTF-16; never the bytes of UTF-8 as
// a vaString, which Delphi reads with the ANSI code page
procedure TestBinaryStrings;
var
  LRep, LRep2: TRpReport;
  LStream: TMemoryStream;
  LLatin, LCjk: UnicodeString;
  LSaved: TSystemCodePage;
begin
  WriteLn('-- Binary format: string properties as Delphi writes them');
  UseUtf8(LSaved);
  LRep := TRpReport.Create(nil);
  LStream := TMemoryStream.Create;
  try
    LRep.CreateNew;
    LLatin := 'A' + WideChar($00F1) + 'o ' + WideChar($20AC) + ' ' + WideChar($D83D) + WideChar($DE00);
    LCjk := WideChar($4E2D) + WideChar($6587) + WideChar($65E5) + WideChar($672C);
    LRep.DocTitle := string(LLatin);
    LRep.DocAuthor := string(LCjk);
    LRep.DocSubject := 'ascii';
    LRep.StreamFormat := rpStreamBinary;
    LRep.SaveToStream(LStream);
    Check(ValueTypeOf(LStream, UTF8Encode(LLatin), LLatin) = 20, 'Latin text and an emoji as vaUTF8String');
    Check(ValueTypeOf(LStream, UTF8Encode(LCjk), LCjk) = 18, 'CJK text as vaWString');
    Check(ValueTypeOf(LStream, 'ascii', 'ascii') = 6, 'ASCII as vaString');
    LStream.SaveToFile(DelphiCheckFile('strings.binary.rep'));
    LStream.Position := 0;
    LRep2 := TRpReport.Create(nil);
    try
      LRep2.LoadFromStream(LStream);
      Check(UnicodeString(LRep2.DocTitle) = LLatin, 'the Latin text read back');
      Check(UnicodeString(LRep2.DocAuthor) = LCjk, 'the CJK text read back');
      Check(LRep2.DocSubject = 'ascii', 'the ASCII text read back');
    finally
      LRep2.Free;
    end;
  finally
    LStream.Free;
    LRep.Free;
    DefaultSystemCodePage := LSaved;
  end;
  // In the ANSI code page of a program without the LCL too
  LRep := TRpReport.Create(nil);
  LStream := TMemoryStream.Create;
  try
    LRep.CreateNew;
    LRep.DocTitle := Accented('Autor ');
    LRep.StreamFormat := rpStreamBinary;
    LRep.SaveToStream(LStream);
    Check(ValueTypeOf(LStream, UTF8Encode(UnicodeString(Accented('Autor '))), UnicodeString(Accented('Autor '))) = 20,
      'an ANSI string as vaUTF8String');
    LStream.Position := 0;
    LRep2 := TRpReport.Create(nil);
    try
      LRep2.LoadFromStream(LStream);
      Check(LRep2.DocTitle = Accented('Autor '), 'the ANSI string read back');
    finally
      LRep2.Free;
    end;
  finally
    LStream.Free;
    LRep.Free;
  end;
end;

// The first byte a report is saved with: '<' XML, 'o' text
function SavedFirstByte(ARep: TRpReport): Char;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    ARep.SaveToStream(LStream);
    Result := PAnsiChar(LStream.Memory)^;
  finally
    LStream.Free;
  end;
end;

// A new report (CreateNew, the designers) is saved as XML; a report that
// is loaded keeps its format
procedure TestDefaultFormat(const ASamplePath: string);
var
  LRep: TRpReport;
begin
  WriteLn('-- Stream format: XML for a new report, the format of the file for a loaded one');
  LRep := TRpReport.Create(nil);
  try
    LRep.CreateNew;
    Check(LRep.StreamFormat = rpStreamXML, 'a new report is XML');
    Check(SavedFirstByte(LRep) = '<', 'a new report is saved as XML');
  finally
    LRep.Free;
  end;
  if not FileExists(ASamplePath) then
    Exit;
  LRep := TRpReport.Create(nil);
  try
    LRep.LoadFromFile(ASamplePath);
    Check(LRep.StreamFormat = rpStreamText, 'a text DFM report keeps its format');
    Check(SavedFirstByte(LRep) = 'o', 'a text DFM report is saved as a text DFM');
  finally
    LRep.Free;
  end;
end;

function RunTextFormatTests: Boolean;
var
  LSample: string;
begin
  WriteLn('==================================================');
  WriteLn('Text stream format (rpstreamfpc)');
  GFailed := 0;
  try
    TestRoundTrip;
    TestBinaryCurrency;
    TestDelphiText;
    LSample := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
      '..' + PathDelim + 'repman' + PathDelim + 'repsamples' + PathDelim + 'sample4.rep';
    TestSampleRoundTrip(LSample);
    TestDelphiLayout;
    TestLongString;
    TestBinaryStrings;
    TestDefaultFormat(LSample);
  except
    on E: Exception do
    begin
      WriteLn('   FAIL exception ', E.ClassName, ': ', E.Message);
      Inc(GFailed);
    end;
  end;
  WriteLn('Text format: ', GFailed, ' failed checks');
  Result := GFailed = 0;
end;

end.

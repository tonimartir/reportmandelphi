unit utextformattests;

{$mode objfpc}{$H+}

// The text stream format of the reports (rpStreamText, the default). FPC
// 3.2.2's ObjectBinaryToText raised on Null, Single, Currency and Date
// values (a report with a parameter without value could not be saved) and
// wrote the non ASCII characters of string properties byte by byte; its
// ObjectTextToBinary read Null as an identifier. rpstreamfpc converts them
// as Delphi does.

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

// The text of a sample report is the same with the FPC conversions (only
// ASCII and Unicode string values): the files do not change
procedure TestSampleUnchanged(const ASamplePath: string);
var
  LFile, LBin, LOld, LNew: TMemoryStream;
begin
  WriteLn('-- Text format: a sample report converts as with the FPC functions');
  if not FileExists(ASamplePath) then
  begin
    WriteLn('   SKIP sample not found: ', ASamplePath);
    Exit;
  end;
  LFile := TMemoryStream.Create;
  LBin := TMemoryStream.Create;
  LOld := TMemoryStream.Create;
  LNew := TMemoryStream.Create;
  try
    LFile.LoadFromFile(ASamplePath);
    LFile.Position := 0;
    RpObjectTextToBinary(LFile, LBin);
    LBin.Position := 0;
    ObjectBinaryToText(LBin, LOld);
    LBin.Position := 0;
    RpObjectBinaryToText(LBin, LNew);
    Check((LOld.Size = LNew.Size) and CompareMem(LOld.Memory, LNew.Memory, LOld.Size),
      'same text as ObjectBinaryToText for ' + ExtractFileName(ASamplePath));
  finally
    LNew.Free;
    LOld.Free;
    LBin.Free;
    LFile.Free;
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
    TestSampleUnchanged(LSample);
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

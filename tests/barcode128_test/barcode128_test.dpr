program barcode128_test;

{ Code 128 and GS1-128 in the engine (rpmdbarcode).

  Writes the bar pattern of every case to barcode128_patterns.txt (name|type|pattern). The .NET
  repository reads that file in tests/Code128Gs1Test (dotnet run -- --delphi <file>): it reads
  the bars with ZXing and checks that both engines draw exactly the same bars.

  Here it checks the structure: 11 modules per symbol plus the 13 of the stop, the start code,
  FNC1 right after the start for GS1 data, and that the FNC1 mark survives the Linux conversion
  (CurrentText holding the two UTF-8 bytes of U+00BF does not change the bars).
  Exit code 0 when everything passes, 1 otherwise. }

{$APPTYPE CONSOLE}

uses
  SysUtils, Classes, rpmdbarcode;

const
  FNC1 = WideChar($BF);
  SSCC = '376104250021234569';

var
  Failures: Integer;
  Lines: TStringList;

procedure Check(Ok: Boolean; const What: string);
begin
  if Ok then
    Writeln('OK   ', What)
  else
  begin
    Writeln('FAIL ', What);
    Inc(Failures);
  end;
end;

// The same conversion as the engine: '211412' to the internal widths
function Pattern(const S: string): string;
var
  I, V: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    V := Ord(S[I]) - Ord('1');
    if Odd(I) then
      Inc(V, 5);
    Result := Result + Chr(Ord('0') + V);
  end;
end;

function Modules(const Bars: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Bars) do
    if Bars[I] >= '5' then
      Inc(Result, Ord(Bars[I]) - Ord('5') + 1)
    else
      Inc(Result, Ord(Bars[I]) - Ord('0') + 1);
end;

function Encode(Typ: TRpBarcodeType; const Text: WideString; const Ansi: AnsiString; UseAnsi: Boolean): string;
var
  B: TRpBarcode;
begin
  B := TRpBarcode.Create(nil);
  try
    B.Typ := Typ;
    B.Modul := 10;
    B.CurrentTextW := Text;
    if UseAnsi then
      B.CurrentText := Ansi
    else
      B.CurrentText := AnsiString(Text);
    Result := string(B.CalculateBarcode);
  finally
    B.Free;
  end;
end;

procedure Test(const Name: string; Typ: TRpBarcodeType; const Text: WideString; const StartCode: string);
var
  Bars: string;
  M: Integer;
begin
  Bars := Encode(Typ, Text, '', False);
  M := Modules(Bars);
  Check((M - 13) mod 11 = 0, Format('%s: %d modules', [Name, M]));
  Check(Copy(Bars, 1, 6) = Pattern(StartCode), Name + ': start code ' + StartCode);
  if (Length(Text) > 0) and (Text[1] = FNC1) then
    Check(Copy(Bars, 7, 6) = Pattern('411131'), Name + ': FNC1 right after the start');
  Lines.Add(Name + '|' + IntToStr(Ord(Typ)) + '|' + Bars);
end;

var
  LinuxBytes: AnsiString;
begin
  Failures := 0;
  Lines := TStringList.Create;
  try
    try
      Test('sscc_auto', bcCode128, FNC1 + '00' + SSCC, '211232');
      Test('sscc_b', bcCode128B, FNC1 + '00' + SSCC, '211214');
      Test('sscc_c', bcCode128C, FNC1 + '00' + SSCC, '211232');
      Test('lote_auto', bcCode128, FNC1 + '10L2511', '211214'); // B and C tie at 7 symbols: B
      Test('lote_b', bcCode128B, FNC1 + '10L2511', '211214');
      Test('sscc_lote_auto', bcCode128, FNC1 + '00' + SSCC + '10L2511', '211232');
      Test('gtin_cantidad_lote_auto', bcCode128, FNC1 + '0208412345678905' + '3724' + FNC1 + '10L2511', '211232');
      Test('impar_auto', bcCode128, FNC1 + '10123', '211214'); // B and C tie at 5 symbols: B
      Test('impar_c', bcCode128C, FNC1 + '10123', '211232');
      Test('numeros_impar_auto', bcCode128, '12345', '211214');
      Test('coma_b', bcCode128B, 'A,B', '211214');
      Test('coma_auto', bcCode128, 'A,B', '211214');
      Test('texto_auto', bcCode128, 'Code-128 abc', '211214');
      Test('control_a', bcCode128A, 'AB'#9'C', '211412');
      Test('control_auto', bcCode128, 'ab'#9'cd', '211214');

      // On Linux AnsiString(CurrentTextW) turns U+00BF into two bytes: the bars must not change
      LinuxBytes := '';
      SetLength(LinuxBytes, 2);
      LinuxBytes[1] := AnsiChar($C2);
      LinuxBytes[2] := AnsiChar($BF);
      LinuxBytes := LinuxBytes + '10L2511';
      Check(Encode(bcCode128, FNC1 + '10L2511', LinuxBytes, True) = Encode(bcCode128, FNC1 + '10L2511', '', False),
        'The UTF-8 bytes of the FNC1 mark in CurrentText do not change the bars');

      Lines.SaveToFile(ExtractFilePath(ParamStr(0)) + 'barcode128_patterns.txt');
      Writeln('Patterns: ', ExtractFilePath(ParamStr(0)) + 'barcode128_patterns.txt');
    except
      on E: Exception do
      begin
        Writeln('FAIL exception: ', E.Message);
        Inc(Failures);
      end;
    end;
  finally
    Lines.Free;
  end;
  if Failures = 0 then
    Writeln('ALL PASSED')
  else
    Writeln(Failures, ' FAILED');
  if Failures > 0 then
    ExitCode := 1;
end.

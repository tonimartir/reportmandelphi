program eval_sum_test;

{ A number plus a text in an expression (18-11-2026).

  Until version 3 the evaluator swallowed the variant conversion error of
  POSTEN+UPOS (POSTEN a number, UPOS a text such as 'a'): the expression gave
  its left operand, 10, when the sum was the last thing in it, and a syntax
  error when anything followed it. Version 4 reports the conversion error.

  Now + joins both texts when one side is a number and the other a text that
  is not a number, the number written as STR() writes it: POSTEN+UPOS is
  '10a', as STR(POSTEN)+UPOS. A text that is a number is still added
  (10+'7' is 17), and a WideString still joins as before, so no expression
  that gave a value before changes it. Booleans and dates with a text, and
  the other operators, still raise the error.

  The same rule is in the C# engine (Reportman.Reporting Variant.cs,
  tests/EvalSumTest).

  Delphi and FPC. Exit code 0 when every check passes. }

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}
{$APPTYPE CONSOLE}

uses
{$IFDEF UNIX}
  cwstring,
{$ENDIF}
  SysUtils, Variants,
  rptypes, rptypeval, rpeval;

var
  Failures: Integer = 0;

procedure Check(Ok: Boolean; const Name, Detail: string);
begin
  if Ok then
    Writeln('[PASS] ', Name)
  else
  begin
    Writeln('[FAIL] ', Name, ' -> ', Detail);
    Inc(Failures);
  end;
end;

function Describe(const V: Variant): string;
begin
  if VarIsNull(V) then
    Result := 'Null'
  else
    Result := VarTypeAsText(VarType(V)) + ' ' + VarToStr(V);
end;

// The result is a text equal to Expected
procedure CheckText(const Name: string; const V: Variant; const Expected: string);
begin
  Check(VarIsStr(V) and (VarToStr(V) = Expected), Name,
    Describe(V) + ', expected the text ''' + Expected + '''');
end;

// The result is a number equal to Expected
procedure CheckNumber(const Name: string; const V: Variant; Expected: Double);
begin
  Check(VarIsNumeric(V) and (VarType(V) <> varBoolean) and
    (Abs(Double(V) - Expected) < 1E-9), Name,
    Describe(V) + ', expected the number ' + FloatToStr(Expected));
end;

function AnsiText(const S: AnsiString): Variant;
begin
  // As a TStringField gives it (varString)
  Result := S;
end;

function UnicodeText(const S: string): Variant;
begin
  // As a string constant of an expression gives it
  Result := S;
end;

function WideText(const S: WideString): Variant;
begin
  // As a TWideStringField gives it (varOleStr)
  Result := S;
end;

function CurrencyValue(C: Currency): Variant;
begin
  Result := C;
end;

function Int64Value(I: Int64): Variant;
begin
  Result := I;
end;

procedure CheckSumRaises(const Name: string; const V1, V2: Variant);
var
  R: Variant;
begin
  try
    R := SumTRpValue(V1, V2);
    Check(False, Name, 'gave ' + Describe(R) + ', expected an error');
  except
    on E: Exception do
      Check(True, Name + ' (' + E.ClassName + ')', '');
  end;
end;

procedure TestSum;
var
  D: Double;
begin
  // A number plus a text that is not a number: both texts joined
  CheckText('Double+AnsiString', SumTRpValue(10.0, AnsiText('a')), '10a');
  CheckText('AnsiString+Double', SumTRpValue(AnsiText('a'), 10.0), 'a10');
  CheckText('Double+UnicodeString', SumTRpValue(10.0, UnicodeText('a')), '10a');
  CheckText('UnicodeString+Double', SumTRpValue(UnicodeText('a'), 10.0), 'a10');
  CheckText('Integer+AnsiString', SumTRpValue(10, AnsiText('a')), '10a');
  CheckText('SmallInt+AnsiString', SumTRpValue(SmallInt(10), AnsiText('a')), '10a');
  CheckText('Int64+AnsiString', SumTRpValue(Int64Value(10), AnsiText('a')), '10a');
  CheckText('Currency+AnsiString', SumTRpValue(CurrencyValue(10), AnsiText('a')), '10a');
  CheckText('Double+empty text', SumTRpValue(10.0, AnsiText('')), '10');
  CheckText('empty text+Double', SumTRpValue(UnicodeText(''), 10.0), '10');
  // The number is written as STR() writes it (the decimal separator of the
  // locale)
  D := 10.5;
  CheckText('Double with decimals+text', SumTRpValue(D, AnsiText('a')),
    String(Variant(D)) + 'a');

  // A text that is a number is still added, as always
  CheckNumber('Double+AnsiString number', SumTRpValue(10.0, AnsiText('7')), 17);
  CheckNumber('AnsiString number+Double', SumTRpValue(AnsiText('7'), 10.0), 17);
  CheckNumber('Integer+UnicodeString number', SumTRpValue(10, UnicodeText('7')), 17);
  CheckNumber('UnicodeString number+Integer', SumTRpValue(UnicodeText('7'), 10), 17);

  // A WideString joins as it already did, even when it is a number
  CheckText('Double+WideString', SumTRpValue(10.0, WideText('a')), '10a');
  CheckText('Double+WideString number', SumTRpValue(10.0, WideText('7')), '107');

  // Unchanged: numbers, texts and nulls
  CheckNumber('Double+Integer', SumTRpValue(10.0, 5), 15);
  CheckText('AnsiString+UnicodeString', SumTRpValue(AnsiText('a'), UnicodeText('b')), 'ab');
  CheckText('Null+text', SumTRpValue(Null, AnsiText('a')), 'a');
  CheckNumber('Double+Null', SumTRpValue(10.0, Null), 10);

  // Booleans and dates with a text still raise the error
  CheckSumRaises('Boolean+text', True, AnsiText('a'));
  CheckSumRaises('text+Boolean', UnicodeText('a'), True);
  CheckSumRaises('Date+text', VarFromDateTime(EncodeDate(2026, 11, 18)), AnsiText('a'));
end;

function Evaluate(Eval: TRpEvaluator; const Expression: string): Variant;
begin
  Result := Eval.EvaluateText(Expression);
end;

procedure CheckEvalRaises(Eval: TRpEvaluator; const Expression: string);
var
  R: Variant;
begin
  try
    R := Evaluate(Eval, Expression);
    Check(False, Expression, 'gave ' + Describe(R) + ', expected an error');
  except
    on E: Exception do
      Check(True, Expression + ' raises: ' + E.Message, '');
  end;
end;

procedure TestExpressions;
var
  Eval: TRpEvaluator;
begin
  Eval := TRpEvaluator.Create(nil);
  try
    CheckText('10+''a''', Evaluate(Eval, '10+''a'''), '10a');
    CheckText('''Pos ''+10', Evaluate(Eval, '''Pos ''+10'), 'Pos 10');
    CheckText('10+''''', Evaluate(Eval, '10+'''''), '10');
    // Anything after the sum: version 3 gave a syntax error here
    CheckText('10+''a''+'' Stk''', Evaluate(Eval, '10+''a''+'' Stk'''), '10a Stk');
    CheckText('(10+''a'')', Evaluate(Eval, '(10+''a'')'), '10a');
    CheckText('TRIM(10+''a'')', Evaluate(Eval, 'TRIM(10+''a'')'), '10a');
    CheckText('IIF(1>0,10+''a'','''')', Evaluate(Eval, 'IIF(1>0,10+''a'','''')'), '10a');
    CheckText('''Pos ''+10+''a''', Evaluate(Eval, '''Pos ''+10+''a'''), 'Pos 10a');
    // From the left: 10+5 is added first
    CheckText('10+5+''a''', Evaluate(Eval, '10+5+''a'''), '15a');
    CheckText('''a''+10+5', Evaluate(Eval, '''a''+10+5'), 'a105');
    // The same text as STR()
    CheckText('10.5+''a'' as STR(10.5)+''a''', Evaluate(Eval, '10.5+''a'''),
      VarToStr(Evaluate(Eval, 'STR(10.5)+''a''')));
    // A text that is a number is still added
    CheckNumber('10+''7''', Evaluate(Eval, '10+''7'''), 17);
    CheckNumber('''7''+10', Evaluate(Eval, '''7''+10'), 17);
    // Only +: the other operators, and Booleans with a text, still raise
    CheckEvalRaises(Eval, '10-''a''');
    CheckEvalRaises(Eval, '10*''a''');
    CheckEvalRaises(Eval, 'TRUE+''a''');
  finally
    Eval.Free;
  end;
end;

begin
  try
    TestSum;
    TestExpressions;
  except
    on E: Exception do
    begin
      Writeln('[FAIL] unexpected ', E.ClassName, ': ', E.Message);
      Inc(Failures);
    end;
  end;
  if Failures = 0 then
    Writeln('All checks passed')
  else
    Writeln(Failures, ' check(s) failed');
  ExitCode := Ord(Failures > 0);
end.

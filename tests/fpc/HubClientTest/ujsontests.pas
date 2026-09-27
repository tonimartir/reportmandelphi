{ Tests of the Delphi compatibility shims that do not need the network:
  - rpjsonfpc, rpnetencodingfpc, rpsysutilsfpc against the output of real
    Delphi (golden/json_delphi.txt, written by delphi/JsonGolden.dpr from the
    same cases in ujsoncases.pas);
  - JSON ownership rules and memory (no leaks);
  - rpioutilsfpc. }
unit ujsontests;

{$mode delphi}{$H+}

interface

procedure RunJsonTests;

implementation

uses
  SysUtils, Classes, rpjsonfpc, rpioutilsfpc, utestutil, ujsoncases;

// Cases where FPC intentionally differs from Delphi, with the FPC result
function KnownDifference(const AId: string; out AExpected: string): Boolean;
begin
  Result := False;
  // A lone surrogate (\ud83d) cannot be stored in a UTF-8 string: FPC keeps
  // U+FFFD, Delphi keeps the lone UTF-16 unit (its Value also becomes U+FFFD
  // when converted to UTF-8)
  if AId = 'parse.43' then
  begin
    AExpected := 'TJSONString "' + #92 + 'uFFFD" value:EFBFBD';
    Result := True;
  end;
end;

procedure GoldenTest;
var
  LGolden, LActual: TStringList;
  LFile, LId, LExpected, LFpcExpected, LActualValue: string;
  I, P, LIndex: Integer;
begin
  Section('JSON, encoding and dates against Delphi (golden file)');
  LFile := ExtractFilePath(ParamStr(0)) + 'golden' + PathDelim + 'json_delphi.txt';
  Check(FileExists(LFile), 'golden file exists: ' + LFile);
  LGolden := TStringList.Create;
  LActual := TStringList.Create;
  try
    LGolden.LoadFromFile(LFile);
    RunJsonCases(LActual);
    CheckEquals(LGolden.Count, LActual.Count, 'same number of cases as Delphi');
    for I := 0 to LGolden.Count - 1 do
    begin
      P := Pos('=', LGolden[I]);
      LId := Copy(LGolden[I], 1, P - 1);
      LExpected := Copy(LGolden[I], P + 1, MaxInt);
      LIndex := -1;
      if (I < LActual.Count) and (Copy(LActual[I], 1, P) = LId + '=') then
        LIndex := I;
      if LIndex < 0 then
        Fail('case ' + LId + ' missing in the FPC output');
      LActualValue := Copy(LActual[LIndex], P + 1, MaxInt);
      if KnownDifference(LId, LFpcExpected) then
        CheckEquals(LFpcExpected, LActualValue, LId + ' (known difference)')
      else
        CheckEquals(LExpected, LActualValue, LId);
    end;
    Log(Format('  %d cases identical to Delphi', [LGolden.Count]));
  finally
    LGolden.Free;
    LActual.Free;
  end;
end;

var
  GDestroyed: Integer = 0;

type
  TCountedString = class(TJSONString)
  public
    destructor Destroy; override;
  end;

destructor TCountedString.Destroy;
begin
  Inc(GDestroyed);
  inherited Destroy;
end;

procedure OwnershipTest;
var
  LObj: TJSONObject;
  LArr: TJSONArray;
  LPair: TJSONPair;
  LValue, LKept: TJSONValue;
begin
  Section('JSON ownership');
  GDestroyed := 0;
  LObj := TJSONObject.Create;
  LObj.AddPair('a', TCountedString.Create('x'));
  LArr := TJSONArray.Create;
  LArr.AddElement(TCountedString.Create('y'));
  LArr.AddElement(TCountedString.Create('z'));
  LObj.AddPair('b', LArr);
  LObj.Free;
  CheckEquals(3, GDestroyed, 'freeing an object frees the values added with AddPair/AddElement');

  GDestroyed := 0;
  LObj := TJSONObject.Create;
  LObj.AddPair('a', TCountedString.Create('x'));
  LPair := LObj.RemovePair('a');
  LObj.Free;
  CheckEquals(0, GDestroyed, 'RemovePair gives the pair back to the caller');
  LPair.Free;
  CheckEquals(1, GDestroyed, 'freeing the removed pair frees its value');

  GDestroyed := 0;
  LArr := TJSONArray.Create;
  LArr.AddElement(TCountedString.Create('x'));
  LValue := LArr.Remove(0);
  LArr.Free;
  CheckEquals(0, GDestroyed, 'TJSONArray.Remove gives the element back');
  LValue.Free;
  CheckEquals(1, GDestroyed, 'freeing the removed element');

  GDestroyed := 0;
  LKept := TCountedString.Create('kept');
  LKept.Owned := False;
  LObj := TJSONObject.Create;
  LObj.AddPair('a', LKept);
  LObj.Free;
  CheckEquals(0, GDestroyed, 'a value with Owned=False is not freed by its container');
  LKept.Free;

  GDestroyed := 0;
  LObj := TJSONObject.Create;
  LObj.AddPair('a', TCountedString.Create('1'));
  LObj.AddPair('a', TCountedString.Create('2'));
  CheckEquals('1', LObj.Values['a'].Value, 'duplicate names: Values returns the first one');
  LObj.Free;
  CheckEquals(2, GDestroyed, 'duplicates are both owned');

  LValue := TJSONObject.ParseJSONValue('{"a":[1,2,{"b":"c"}]}');
  Check(LValue is TJSONObject, 'ParseJSONValue returns the root');
  LObj := TJSONObject(LValue);
  LArr := LObj.Values['a'] as TJSONArray;
  Check(LArr.Items[2] is TJSONObject, 'nested object');
  LValue := TJSONObject(LObj.Clone);
  LObj.Free;
  CheckEquals('{"a":[1,2,{"b":"c"}]}', LValue.ToJSON, 'a clone survives the original');
  LValue.Free;
end;

procedure JsonWorkload(ACount: Integer);
var
  I: Integer;
  LObj, LInner: TJSONObject;
  LArr: TJSONArray;
  LValue: TJSONValue;
  LText: string;
const
  Invalid: array[0..7] of string = ('{"a":[1,2,{"b":', '[1,2,3', '{"a":1,}', '{"a" 1}',
    '[{"x":"\q"}]', '{"a":{"b":{"c":tru}}}', '[1,2]]', '"abc');
begin
  for I := 1 to ACount do
  begin
    LObj := TJSONObject.Create;
    LArr := TJSONArray.Create;
    LInner := TJSONObject.Create;
    LInner.AddPair('n', TJSONNumber.Create(I));
    LInner.AddPair('s', 'text ' + IntToStr(I));
    LInner.AddPair('b', TJSONBool.Create(Odd(I)));
    LInner.AddPair('z', TJSONNull.Create);
    LArr.AddElement(LInner);
    LArr.Add('x').Add(Double(1.5)).Add(True);
    LObj.AddPair('list', LArr);
    LObj.AddPair('nil', TJSONValue(nil));
    LText := LObj.ToJSON;
    LValue := TJSONObject.ParseJSONValue(LText);
    if LValue.ToJSON <> LText then
      Fail('round trip ' + LText);
    LValue.Free;
    LValue := LObj.Clone as TJSONValue;
    LValue.Free;
    LObj.RemovePair('nil').Free;
    LObj.Free;
  end;
  for I := Low(Invalid) to High(Invalid) do
  begin
    LValue := TJSONObject.ParseJSONValue(Invalid[I]);
    if LValue <> nil then
      Fail('invalid JSON accepted: ' + Invalid[I]);
  end;
  try
    TJSONObject.ParseJSONValue('{"a":[1,', False, True).Free;
  except
    on E: EJSONParseException do ;
  end;
end;

procedure LeakTest;
var
  LBefore, LAfter: PtrUInt;
  LLines: TStringList;
begin
  Section('JSON memory (no leaks)');
  // Warm up: the RTL allocates some things once (exception support, format
  // settings, class structures)
  LLines := TStringList.Create;
  try
    RunJsonCases(LLines);
  finally
    LLines.Free;
  end;
  JsonWorkload(2);
  LBefore := HeapUsed;
  JsonWorkload(50);
  LAfter := HeapUsed;
  CheckEquals(LBefore, LAfter, 'heap in use unchanged after building, parsing, cloning and failed parses');
end;

procedure IOUtilsTest;
var
  LDir, LFile: string;
begin
  Section('rpioutilsfpc');
  CheckEquals('a' + PathDelim + 'b', TPath.Combine('a', 'b'), 'TPath.Combine');
  CheckEquals('a' + PathDelim + 'b', TPath.Combine('a' + PathDelim, 'b'), 'TPath.Combine with delimiter');
{$IFDEF MSWINDOWS}
  CheckEquals('C:\x', TPath.Combine('a', 'C:\x'), 'TPath.Combine with a rooted second path');
{$ELSE}
  CheckEquals('/x', TPath.Combine('a', '/x'), 'TPath.Combine with a rooted second path');
{$ENDIF}
  Check(TPath.GetHomePath <> '', 'TPath.GetHomePath');
  LDir := TPath.Combine(TPath.GetTempPath, 'rphubtest_' + IntToStr(GetProcessID));
  TDirectory.CreateDirectory(TPath.Combine(LDir, 'sub'));
  Check(TDirectory.Exists(TPath.Combine(LDir, 'sub')), 'TDirectory.CreateDirectory creates parents');
  LFile := TPath.Combine(LDir, 'log.txt');
  TFile.AppendAllText(LFile, 'one' + #10);
  TFile.AppendAllText(LFile, 'two ' + CP([$F1]) + #10);
  CheckEquals('one' + #10 + 'two ' + CP([$F1]) + #10, TFile.ReadAllText(LFile), 'TFile.AppendAllText appends UTF-8');
  TDirectory.Delete(LDir, True);
  Check(not TDirectory.Exists(LDir), 'TDirectory.Delete recursive');
end;

procedure RunJsonTests;
begin
  GoldenTest;
  OwnershipTest;
  LeakTest;
  IOUtilsTest;
end;

end.

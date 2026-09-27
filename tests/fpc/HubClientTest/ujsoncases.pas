{ JSON and AI contract cases shared by the Delphi golden generator
  (delphi/JsonGolden.dpr, System.JSON) and the FPC test (HubClientTest,
  rpjsonfpc). Each case writes one line "id=result"; the FPC test compares its
  lines with golden/json_delphi.txt, so the shim must produce exactly what
  Delphi produces. Non-ASCII results are written as hex UTF-8 bytes to keep
  the golden file ASCII. }
unit ujsoncases;

{$IFDEF FPC}
{$mode delphi}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes,
{$IFDEF FPC}
  rpjsonfpc, rpnetencodingfpc, DateUtils, rpsysutilsfpc,
{$ELSE}
  System.JSON, System.NetEncoding, System.DateUtils,
{$ENDIF}
  rpreportdesignercontracts, rpaireportcontracts;

procedure RunJsonCases(AOut: TStrings);

// Native string from Unicode code points (UTF-16 in Delphi, UTF-8 in FPC)
function CP(const ACodePoints: array of Cardinal): string;
// Hex dump of the UTF-8 bytes of a native string
function U8Hex(const S: string): string;

implementation

function CP(const ACodePoints: array of Cardinal): string;
var
  I: Integer;
  C: Cardinal;
begin
  Result := '';
  for I := Low(ACodePoints) to High(ACodePoints) do
  begin
    C := ACodePoints[I];
{$IFDEF FPC}
    if C < $80 then
      Result := Result + Chr(C)
    else if C < $800 then
      Result := Result + Chr($C0 or (C shr 6)) + Chr($80 or (C and $3F))
    else if C < $10000 then
      Result := Result + Chr($E0 or (C shr 12)) + Chr($80 or ((C shr 6) and $3F)) +
        Chr($80 or (C and $3F))
    else
      Result := Result + Chr($F0 or (C shr 18)) + Chr($80 or ((C shr 12) and $3F)) +
        Chr($80 or ((C shr 6) and $3F)) + Chr($80 or (C and $3F));
{$ELSE}
    if C < $10000 then
      Result := Result + Char(C)
    else
    begin
      Dec(C, $10000);
      Result := Result + Char($D800 or (C shr 10)) + Char($DC00 or (C and $3FF));
    end;
{$ENDIF}
  end;
end;

function Utf8Bytes(const S: string): TBytes;
begin
{$IFDEF FPC}
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
{$ELSE}
  Result := TEncoding.UTF8.GetBytes(S);
{$ENDIF}
end;

function U8Hex(const S: string): string;
var
  LBytes: TBytes;
  I: Integer;
begin
  LBytes := Utf8Bytes(S);
  Result := '';
  for I := 0 to Length(LBytes) - 1 do
    Result := Result + IntToHex(LBytes[I], 2);
  if Result = '' then
    Result := '-';
end;

// Makes line breaks visible (Format output uses sLineBreak, which differs
// between Windows and Linux) and keeps lines ASCII
function Visible(const S: string): string;
var
  I: Integer;
  LAscii: Boolean;
begin
  Result := StringReplace(S, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  LAscii := True;
  for I := 1 to Length(Result) do
    if Ord(Result[I]) > 127 then
      LAscii := False;
  if not LAscii then
    Result := 'hex:' + U8Hex(Result);
end;

procedure Add(AOut: TStrings; const AId, AValue: string);
begin
  AOut.Add(AId + '=' + AValue);
end;

procedure AddValue(AOut: TStrings; const AId: string; AValue: TJSONAncestor);
begin
  try
    if AValue = nil then
      Add(AOut, AId, 'NIL')
    else
      Add(AOut, AId, AValue.ToJSON);
  finally
    AValue.Free;
  end;
end;

procedure NumberCases(AOut: TStrings);
const
  Doubles: array[0..23] of Double = (0, 1, -1, 0.1, 1.5, 3.14159265358979,
    2 / 3, 1E20, 1.5E-7, 123456789012345678.0, 1E300, 100, 2.5E15, 1234567.125,
    0.0001, 0.00001, 1E15, 1E14, 1E16, 123456.789E3, -0.5, 0.1 + 0.2,
    99999999999999.9, 1E-300);
  Currencies: array[0..5] of Currency = (12.5, 100, 0.0001, -3.25,
    922337203685477.5807, 0);
var
  I: Integer;
begin
  for I := Low(Doubles) to High(Doubles) do
    AddValue(AOut, 'num.double.' + IntToStr(I), TJSONNumber.Create(Doubles[I]));
  for I := Low(Currencies) to High(Currencies) do
    AddValue(AOut, 'num.currency.' + IntToStr(I), TJSONNumber.Create(Currencies[I]));
  AddValue(AOut, 'num.int.0', TJSONNumber.Create(Integer(0)));
  AddValue(AOut, 'num.int.min', TJSONNumber.Create(Integer(-2147483647 - 1)));
  AddValue(AOut, 'num.int.max', TJSONNumber.Create(Integer(2147483647)));
  AddValue(AOut, 'num.int64.max', TJSONNumber.Create(Int64(9223372036854775807)));
  AddValue(AOut, 'num.int64.min', TJSONNumber.Create(Int64(-9223372036854775807 - 1)));
  AddValue(AOut, 'num.const.3', TJSONNumber.Create(3));
  AddValue(AOut, 'num.text', TJSONNumber.Create('1.50'));
  AddValue(AOut, 'num.null', TJSONNumber.Create);
end;

procedure StringCases(AOut: TStrings);
var
  LStrings: array[0..13] of string;
  I: Integer;
  LStr: TJSONString;
begin
  LStrings[0] := '';
  LStrings[1] := 'abc';
  LStrings[2] := 'a"b';
  LStrings[3] := 'a\b';
  LStrings[4] := 'a/b';
  LStrings[5] := #8#9#10#12#13;
  LStrings[6] := #1#31#127;
  LStrings[7] := CP([$F1]);
  LStrings[8] := CP([$20AC]);
  LStrings[9] := CP([$3A9, $E9, $DF]);
  LStrings[10] := CP([$1F600]);
  LStrings[11] := 'Caf' + CP([$E9]) + ' "x" ' + CP([$4E2D, $6587]) + #9 + 'end';
  LStrings[12] := '<script>&amp;</script>';
  LStrings[13] := #0 + 'z';
  for I := Low(LStrings) to High(LStrings) do
  begin
    LStr := TJSONString.Create(LStrings[I]);
    try
      Add(AOut, 'str.tojson.' + IntToStr(I), LStr.ToJSON);
      Add(AOut, 'str.tostring.' + IntToStr(I), U8Hex(LStr.ToString));
      Add(AOut, 'str.value.' + IntToStr(I), U8Hex(LStr.Value));
    finally
      LStr.Free;
    end;
  end;
  AddValue(AOut, 'str.null', TJSONString.Create);
end;

procedure ScalarCases(AOut: TStrings);
var
  LValue: TJSONValue;
begin
  AddValue(AOut, 'bool.true', TJSONBool.Create(True));
  AddValue(AOut, 'bool.false', TJSONBool.Create(False));
  AddValue(AOut, 'null', TJSONNull.Create);
  AddValue(AOut, 'true.class', TJSONTrue.Create);
  AddValue(AOut, 'false.class', TJSONFalse.Create);
  LValue := TJSONBool.Create(True);
  Add(AOut, 'bool.value', LValue.Value + ' ' + BoolToStr(TJSONBool(LValue).AsBoolean, True));
  LValue.Free;
  LValue := TJSONNull.Create;
  Add(AOut, 'null.value', LValue.Value + ' ' + BoolToStr(LValue.Null, True));
  LValue.Free;
  LValue := TJSONObject.Create;
  Add(AOut, 'object.value', '[' + LValue.Value + ']');
  LValue.Free;
  LValue := TJSONArray.Create;
  Add(AOut, 'array.value', '[' + LValue.Value + ']');
  LValue.Free;
end;

function BuildSample: TJSONObject;
var
  LArray, LEmpty: TJSONArray;
  LInner: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('a', TJSONNumber.Create(1));
  Result.AddPair('b', 'x');
  LArray := TJSONArray.Create;
  LArray.Add(1);
  LArray.Add('two');
  LArray.AddElement(TJSONBool.Create(True));
  LArray.AddElement(TJSONNull.Create);
  LInner := TJSONObject.Create;
  LEmpty := TJSONArray.Create;
  LInner.AddPair('d', LEmpty);
  LArray.AddElement(LInner);
  Result.AddPair('c', LArray);
  Result.AddPair('e', TJSONObject.Create);
  Result.AddPair('f', CP([$F1, $20AC]));
  Result.AddPair('g', TJSONValue(nil));
end;

procedure ObjectCases(AOut: TStrings);
var
  LObj, LClone: TJSONObject;
  LArray: TJSONArray;
  LPair: TJSONPair;
  LNames: string;
  LValue: TJSONValue;
begin
  LObj := BuildSample;
  try
    Add(AOut, 'obj.tojson', LObj.ToJSON);
    Add(AOut, 'obj.tostring', Visible(LObj.ToString));
    Add(AOut, 'obj.format2', Visible(LObj.Format(2)));
    Add(AOut, 'obj.format4', Visible(LObj.Format));
    Add(AOut, 'obj.count', IntToStr(LObj.Count));
    Add(AOut, 'obj.values.b', LObj.Values['b'].Value);
    if LObj.Values['B'] = nil then
      Add(AOut, 'obj.values.B', 'NIL')
    else
      Add(AOut, 'obj.values.B', 'FOUND');
    Add(AOut, 'obj.getvalue.g', LObj.GetValue('g').ClassName + ' ' + LObj.GetValue('g').Value);
    LNames := '';
    for LPair in LObj do
      LNames := LNames + LPair.JsonString.Value + ',';
    Add(AOut, 'obj.enum', LNames);
    Add(AOut, 'obj.pairs1', LObj.Pairs[1].JsonString.Value + ':' + LObj.Pairs[1].JsonValue.ToJSON);
    LClone := TJSONObject(LObj.Clone);
    try
      Add(AOut, 'obj.clone', LClone.ToJSON);
    finally
      LClone.Free;
    end;
    LPair := LObj.RemovePair('b');
    Add(AOut, 'obj.removepair', LPair.ToJSON + ' ' + LObj.ToJSON);
    LPair.Free;
    Add(AOut, 'obj.findvalue.c[4].d', LObj.FindValue('c[4].d').ToJSON);
    if LObj.FindValue('c[9]') = nil then
      Add(AOut, 'obj.findvalue.c[9]', 'NIL');
    LArray := LObj.Values['c'] as TJSONArray;
    Add(AOut, 'arr.count', IntToStr(LArray.Count));
    Add(AOut, 'arr.items2', LArray.Items[2].ClassName + ' ' + LArray.Items[2].Value);
    LNames := '';
    for LValue in LArray do
      LNames := LNames + LValue.ToJSON + ';';
    Add(AOut, 'arr.enum', LNames);
    LValue := LArray.Remove(0);
    Add(AOut, 'arr.remove', LValue.ToJSON + ' ' + LArray.ToJSON);
    LValue.Free;
  finally
    LObj.Free;
  end;
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('dup', '1');
    LObj.AddPair('dup', '2');
    Add(AOut, 'obj.duplicates', LObj.ToJSON + ' ' + LObj.Values['dup'].Value);
  finally
    LObj.Free;
  end;
  LArray := TJSONArray.Create;
  try
    LArray.Add('s');
    LArray.Add(Integer(-5));
    LArray.Add(Int64(12345678901234));
    LArray.Add(Double(1.5));
    LArray.Add(True);
    LArray.Add(TJSONObject.Create);
    LArray.Add(TJSONArray.Create);
    Add(AOut, 'arr.add', LArray.ToJSON);
    Add(AOut, 'arr.format', Visible(LArray.Format(1)));
  finally
    LArray.Free;
  end;
  LObj := TJSONObject.Create;
  try
    Add(AOut, 'obj.empty.format', Visible(LObj.Format));
  finally
    LObj.Free;
  end;
end;

procedure ParseCases(AOut: TStrings);
var
  LInputs: TStringList;
  I: Integer;
  LValue: TJSONValue;
  LDeep: string;
begin
  LInputs := TStringList.Create;
  try
    LInputs.Add('{"a":1}');
    LInputs.Add(' {"a":1} ');
    LInputs.Add('{"a":1} x');
    LInputs.Add('[]');
    LInputs.Add('[ ]');
    LInputs.Add('{}');
    LInputs.Add('{ }');
    LInputs.Add('[1,2,3]');
    LInputs.Add('[1,]');
    LInputs.Add('[,1]');
    LInputs.Add('{"a":1,}');
    LInputs.Add('{"a" 1}');
    LInputs.Add('{a:1}');
    LInputs.Add('{''a'':1}');
    LInputs.Add('"abc"');
    LInputs.Add('"abc" ');
    LInputs.Add(' "abc"');
    LInputs.Add('123');
    LInputs.Add('123 ');
    LInputs.Add('-0');
    LInputs.Add('-');
    LInputs.Add('01');
    LInputs.Add('1.');
    LInputs.Add('.5');
    LInputs.Add('1.5');
    LInputs.Add('1e5');
    LInputs.Add('1E+5');
    LInputs.Add('1e-5');
    LInputs.Add('1.5e3');
    LInputs.Add('1e');
    LInputs.Add('-e5');
    LInputs.Add('1.0');
    LInputs.Add('100.50');
    LInputs.Add('1E400');
    LInputs.Add('true');
    LInputs.Add('false');
    LInputs.Add('null');
    LInputs.Add('tru');
    LInputs.Add('nul');
    LInputs.Add('True');
    // #92 is the backslash: \u escapes are written as #92'uXXXX' so that
    // no editor or tool turns them into characters
    LInputs.Add('"'#92'u00f1"');
    LInputs.Add('"'#92'u00F1'#92'u20ac"');
    LInputs.Add('"'#92'ud83d'#92'ude00"');
    LInputs.Add('"'#92'ud83d"');
    LInputs.Add('"\x"');
    LInputs.Add('"\u12"');
    LInputs.Add('"\u12G4"');
    LInputs.Add('"a\/b"');
    LInputs.Add('"line\nbreak\ttab\\ \"q\""');
    LInputs.Add('"a' + #9 + 'b"');
    LInputs.Add('"unterminated');
    LInputs.Add('');
    LInputs.Add('   ');
    LInputs.Add('{"a":[1,{"b":null}],"c":{"d":{"e":[true,false]}}}');
    LInputs.Add('[1 2]');
    LInputs.Add('{"a":1 "b":2}');
    LInputs.Add('[1,[2,[3,[4]]]]');
    LInputs.Add('{"a":1}{"b":2}');
    LInputs.Add('"' + CP([$F1, $20AC, $1F600]) + '"');
    LInputs.Add(CP([$FEFF]) + '{"bom":1}');
    LInputs.Add('{"":""}');
    LInputs.Add('[-1.5E-3,0,-0.0,12345678901234567890]');
    LInputs.Add(#13#10'{'#9'"a"'#13#10':'#10'1'#13'}'#10);
    LDeep := StringOfChar('[', 600) + StringOfChar(']', 600);
    LInputs.Add(LDeep);
    LDeep := StringOfChar('[', 500) + StringOfChar(']', 500);
    LInputs.Add(LDeep);
    for I := 0 to LInputs.Count - 1 do
    begin
      LValue := TJSONObject.ParseJSONValue(LInputs[I]);
      try
        if LValue = nil then
          Add(AOut, 'parse.' + IntToStr(I), 'NIL')
        else
          Add(AOut, 'parse.' + IntToStr(I), LValue.ClassName + ' ' + LValue.ToJSON +
            ' value:' + U8Hex(LValue.Value));
      finally
        LValue.Free;
      end;
    end;
    // UseBool: true/false become TJSONBool
    LValue := TJSONObject.ParseJSONValue('[true,false]', True);
    try
      Add(AOut, 'parse.usebool', (LValue as TJSONArray).Items[0].ClassName + ' ' +
        BoolToStr((LValue as TJSONArray).Items[0] is TJSONBool, True) + ' ' + LValue.ToJSON);
    finally
      LValue.Free;
    end;
    LValue := TJSONObject.ParseJSONValue('[true]');
    try
      Add(AOut, 'parse.bool.is', BoolToStr((LValue as TJSONArray).Items[0] is TJSONBool, True) +
        ' ' + BoolToStr(((LValue as TJSONArray).Items[0] as TJSONBool).AsBoolean, True));
    finally
      LValue.Free;
    end;
    // Numbers keep their text; AsDouble/AsInt64 convert it
    LValue := TJSONObject.ParseJSONValue('[1.50,-7,1e3,9007199254740993]');
    try
      Add(AOut, 'parse.numbers', TJSONNumber(TJSONArray(LValue).Items[0]).Value + ' ' +
        FloatToStr(TJSONNumber(TJSONArray(LValue).Items[0]).AsDouble, GetJSONFormat) + ' ' +
        IntToStr(TJSONNumber(TJSONArray(LValue).Items[1]).AsInt) + ' ' +
        FloatToStr(TJSONNumber(TJSONArray(LValue).Items[2]).AsDouble, GetJSONFormat) + ' ' +
        IntToStr(TJSONNumber(TJSONArray(LValue).Items[3]).AsInt64));
    finally
      LValue.Free;
    end;
    // RaiseExc
    try
      LValue := TJSONObject.ParseJSONValue('{"a":', False, True);
      LValue.Free;
      Add(AOut, 'parse.raise', 'NO EXCEPTION');
    except
      on E: EJSONException do
        Add(AOut, 'parse.raise', 'EJSONException');
    end;
    // Bytes
    LValue := TJSONObject.ParseJSONValue(Utf8Bytes('xx{"k":"' + CP([$E9]) + '"}'), 2);
    try
      if LValue = nil then
        Add(AOut, 'parse.bytes', 'NIL')
      else
        Add(AOut, 'parse.bytes', LValue.ToJSON);
    finally
      LValue.Free;
    end;
  finally
    LInputs.Free;
  end;
end;

procedure ContractCases(AOut: TStrings);
var
  LRequest: TRpApiModifyReportRequest;
  LResult: TRpApiModifyReportResult;
  LPre: TRpApiPreprocessSqlContextRequest;
  LPreResult: TRpApiPreprocessSqlContextResult;
  LSource: TRpApiPreprocessSqlContextDataSource;
  LAIReport: TRpAIReport;
  LUsage: TRpTokenUsage;
  LJson: TJSONObject;
  LValue: TJSONValue;
const
  SampleModifyResult =
    '{"result":{"contextJson":"{\"k\":1}","operationsJson":"[]",' +
    '"modifiedReportDocument":"<report/>","explanation":"Hecho '#92'u00f1",' +
    '"errorMessage":"","reportFormat":"Xml","success":true},' +
    '"steps":[{"inputTokens":10,"modelName":"m1","outputTokens":20,"thinkingTokens":5},' +
    '{"inputTokens":"7","modelName":null,"outputTokens":3}],' +
    '"creditsConsumed":42,"debugDetails":"dbg","errorMessage":"",' +
    '"userProfile":{"userId":7,"email":"a@b.c","tierName":"Pro"}}';
  SamplePreResult =
    '{"result":{"dataSources":[{"dataInfoName":"CLIENTS","sqlExplanation":"x",' +
    '"errorMessage":""},{"dataInfoName":"ORDERS","errorMessage":"bad"}]},' +
    '"steps":[],"debugDetails":"","errorMessage":"warn","userProfile":null}';
begin
  LRequest := TRpApiModifyReportRequest.Create;
  try
    LRequest.AITier := ratPrecision;
    LRequest.Mode := rdmReasoning;
    LRequest.SimplifiedPrompt := True;
    LRequest.ApiKey := 'key-1';
    LRequest.AgentSecret := '';
    LRequest.HasAgentAiId := True;
    LRequest.AgentAiId := 9007199254740993;
    LRequest.HubDatabaseId := 12;
    LRequest.HubSchemaId := 0;
    LRequest.ReportDocument := '<report name="A&B">' + CP([$F1]) + #13#10'</report>';
    LRequest.ReportFormat := rdfXml;
    LRequest.UserInstructions.Add('Add a total');
    LRequest.UserInstructions.Add('Pon el t' + CP([$ED]) + 'tulo "Ventas"');
    LRequest.UserLanguage := 'Spanish';
    LRequest.ExistingOperationsJson := '[{"op":1}]';
    LRequest.ExistingContextJson := '';
    LRequest.ReturnModifiedDocument := False;
    LJson := LRequest.ToJsonObject;
    try
      Add(AOut, 'contract.modifyrequest', LJson.ToJSON);
      LRequest.UserInstructions.Clear;
      LRequest.FromJsonObject(LJson);
      Add(AOut, 'contract.modifyrequest.roundtrip', IntToStr(LRequest.UserInstructions.Count) +
        ' ' + U8Hex(LRequest.UserInstructions[1]) + ' ' + IntToStr(LRequest.AgentAiId) + ' ' +
        IntToStr(LRequest.HubDatabaseId) + ' ' + RpAITierTypeToString(LRequest.AITier) + ' ' +
        BoolToStr(LRequest.ReturnModifiedDocument, True));
    finally
      LJson.Free;
    end;
  finally
    LRequest.Free;
  end;

  LResult := TRpApiModifyReportResult.Create;
  try
    LValue := TJSONObject.ParseJSONValue(SampleModifyResult);
    try
      LResult.FromJsonObject(LValue as TJSONObject);
    finally
      LValue.Free;
    end;
    Add(AOut, 'contract.modifyresult.fields', LResult.ResultData.ModifiedReportDocument + ' ' +
      U8Hex(LResult.ResultData.Explanation) + ' ' + IntToStr(LResult.Steps.Count) + ' ' +
      IntToStr(TRpTokenUsage(LResult.Steps[0]).TotalTokens) + ' ' +
      IntToStr(TRpTokenUsage(LResult.Steps[1]).InputTokens) + ' ' +
      TRpTokenUsage(LResult.Steps[1]).ModelName + ' ' +
      IntToStr(LResult.CreditsConsumed) + ' ' + BoolToStr(LResult.HasCreditsConsumed, True) +
      ' ' + BoolToStr(LResult.ResultData.Success, True));
    Add(AOut, 'contract.modifyresult.profile', LResult.UserProfileJson);
    LJson := LResult.ToJsonObject;
    try
      Add(AOut, 'contract.modifyresult.tojson', LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LResult.Free;
  end;

  LPre := TRpApiPreprocessSqlContextRequest.Create;
  try
    LPre.AITier := ratStandard;
    LPre.Mode := rdmFast;
    LPre.UserLanguage := 'English';
    LPre.Config.HubDatabaseId := 5;
    LPre.Config.HubSchemaId := 6;
    LSource := TRpApiPreprocessSqlContextDataSource.Create;
    LSource.DataInfoName := 'CLIENTS';
    LSource.DatabaseAlias := 'HUB';
    LSource.Sql := 'SELECT * FROM "CLIENTS" WHERE NAME=''a''';
    LSource.Config.HubDatabaseId := 5;
    LPre.DataSources.Add(LSource);
    LSource := TRpApiPreprocessSqlContextDataSource.Create;
    LSource.DataInfoName := 'ORDERS';
    LSource.Sql := 'SELECT 1';
    LPre.DataSources.Add(LSource);
    LJson := LPre.ToJsonObject;
    try
      Add(AOut, 'contract.prerequest', LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LPre.Free;
  end;

  LPreResult := TRpApiPreprocessSqlContextResult.Create;
  try
    LValue := TJSONObject.ParseJSONValue(SamplePreResult);
    try
      LPreResult.FromJsonObject(LValue as TJSONObject);
    finally
      LValue.Free;
    end;
    Add(AOut, 'contract.preresult.fields', IntToStr(LPreResult.DataSources.Count) + ' ' +
      TRpApiPreprocessSqlContextDataSourceResult(LPreResult.DataSources[1]).ErrorMessage +
      ' [' + LPreResult.UserProfileJson + '] ' + BoolToStr(LPreResult.HasCreditsConsumed, True));
    LJson := LPreResult.ToJsonObject;
    try
      Add(AOut, 'contract.preresult.tojson', LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LPreResult.Free;
  end;

  LAIReport := TRpAIReport.Create;
  try
    LAIReport.ErrorType := raetInaccurateContent;
    LAIReport.UserComments := 'Mal ' + CP([$F1]);
    LAIReport.AIContent := 'SELECT 1';
    LJson := LAIReport.ToJsonObject;
    try
      Add(AOut, 'contract.aireport', LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LAIReport.Free;
  end;

  LUsage := TRpTokenUsage.Create;
  try
    LUsage.InputTokens := 1;
    LUsage.OutputTokens := 2;
    LUsage.ThinkingTokens := 3;
    LUsage.ModelName := 'gpt';
    LJson := LUsage.ToJsonObject;
    try
      Add(AOut, 'contract.tokenusage', LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LUsage.Free;
  end;
  Add(AOut, 'contract.composeerror', Visible(RpComposeApiErrorMessage(' Err ', ' Details ')));
end;

function BytesHex(const B: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(B) - 1 do
    Result := Result + IntToHex(B[I], 2);
end;

procedure EncodingCases(AOut: TStrings);
var
  LBytes: TBytes;
  I: Integer;
  LEncoded: string;
begin
  Add(AOut, 'url.encode.redirect', TNetEncoding.URL.Encode('http://localhost:1234/'));
  Add(AOut, 'url.encode.mixed', TNetEncoding.URL.Encode('a b&c=d~*@._-$!''()' + CP([$F1, $20AC])));
  Add(AOut, 'url.decode.mixed', U8Hex(TNetEncoding.URL.Decode('a+b%26c%3Dd%7E%C3%B1%E2%82%AC')));
  Add(AOut, 'url.decode.percent', TNetEncoding.URL.Decode('100%%'));
  try
    TNetEncoding.URL.Decode('bad%G1');
    Add(AOut, 'url.decode.invalid', 'NO EXCEPTION');
  except
    on E: EConvertError do
      Add(AOut, 'url.decode.invalid', 'EConvertError');
  end;
  Add(AOut, 'b64.encode.man', TNetEncoding.Base64.Encode('Man'));
  Add(AOut, 'b64.encode.utf8', TNetEncoding.Base64.Encode(CP([$F1, $20AC])));
  Add(AOut, 'b64.decode.utf8', U8Hex(TNetEncoding.Base64.Decode('w7Higqw=')));
  SetLength(LBytes, 256);
  for I := 0 to 255 do
    LBytes[I] := I;
  LEncoded := TNetEncoding.Base64.EncodeBytesToString(LBytes);
  Add(AOut, 'b64.bytes.encode', Visible(LEncoded));
  Add(AOut, 'b64.bytes.decode', BytesHex(TNetEncoding.Base64.DecodeStringToBytes(LEncoded)));
  Add(AOut, 'b64string.bytes.encode', TNetEncoding.Base64String.EncodeBytesToString(LBytes));
  Add(AOut, 'b64.decode.spaces', BytesHex(TNetEncoding.Base64.DecodeStringToBytes(' AAEC' + #13#10 + '/w== ')));
  Add(AOut, 'html.encode', TNetEncoding.HTML.Encode('<a href="x">&</a>'));
  Add(AOut, 'html.decode', TNetEncoding.HTML.Decode('&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;'));
end;

procedure DateCases(AOut: TStrings);
const
  Inputs: array[0..16] of string = (
    '2024-01-15T10:30:00',
    '2024-01-15T10:30:00Z',
    '2024-01-15T10:30:00.1234567',
    '2024-01-15T10:30:00.5',
    '2024-01-15T10:30:00.05Z',
    '2024-01-15T10:30:00+02:00',
    '2024-01-15T10:30:00-0530',
    '2024-01-15T10:30:00.123+01',
    '2024-01-15',
    '20240115T103000Z',
    '2024-01-15T24:00:00',
    '2024-01-15T10:30',
    '2024-02-30T00:00:00',
    'garbage',
    '2024-01-15 10:30:00',
    '1999-12-31T23:59:59.999Z',
    '2024-01-15T10:30:00Zx');
var
  I: Integer;
  LValue: TDateTime;
  LFloat: Double;
  LSettings: TFormatSettings;
begin
  for I := Low(Inputs) to High(Inputs) do
    if TryISO8601ToDate(Inputs[I], LValue, True) then
      Add(AOut, 'iso8601.' + IntToStr(I), FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', LValue))
    else
      Add(AOut, 'iso8601.' + IntToStr(I), 'FAIL');
  Add(AOut, 'iso8601.raise', FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz',
    ISO8601ToDate('2023-06-01T08:00:00Z')));
  Add(AOut, 'datetoiso8601', DateToISO8601(EncodeDate(2024, 1, 15) +
    EncodeTime(10, 30, 5, 7), True));
  LSettings := TFormatSettings.Invariant;
  Add(AOut, 'invariant.float', FloatToStr(1234567.5, LSettings));
  Add(AOut, 'invariant.formatfloat', FormatFloat('#,##0.00', 1234567.5, LSettings));
  Add(AOut, 'invariant.trystrtofloat', BoolToStr(TryStrToFloat('1.5', LFloat, LSettings), True) +
    ' ' + BoolToStr(TryStrToFloat('1,5', LFloat, LSettings), True));
end;

procedure RunJsonCases(AOut: TStrings);
begin
  NumberCases(AOut);
  StringCases(AOut);
  ScalarCases(AOut);
  ObjectCases(AOut);
  ParseCases(AOut);
  ContractCases(AOut);
  EncodingCases(AOut);
  DateCases(AOut);
end;

end.

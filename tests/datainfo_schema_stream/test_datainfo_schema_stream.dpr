program test_datainfo_schema_stream;

{*******************************************************}
{                                                       }
{   The schema a dataset was made with (D3): the Hub    }
{   schema (HubSchemaId) and the local subschema        }
{   (SchemaName) of TRpDataInfoItem, without a          }
{   database.                                           }
{                                                       }
{   1. A dataset without them is written as before:     }
{      the XML of expected_plain.xml (the version       }
{      before, without the HUBSCHEMAID 0 line it no     }
{      longer writes) and the text of                   }
{      expected_plain.txt (the same as before).         }
{   2. With them, they go and come back in XML, text    }
{      and binary, the Int64 id whole.                  }
{   3. Assign, Get/SetItemProperty and the schemaName   }
{      of the inline config of the design copilot.      }
{                                                       }
{   Delphi: build.bat. Lazarus: test_datainfo_schema_   }
{   stream.lpi (lazbuild). Run:                         }
{                                                       }
{   test_datainfo_schema_stream [-dump <folder>]        }
{                                                       }
{   -dump writes the plain report (plain.xml and        }
{   plain.txt) instead of checking: built with          }
{   -DBEFORE_D3 against the sources before D3 it made   }
{   the expected files. The expected files are next to  }
{   the program's folder (_fpc for Lazarus). Exit code  }
{   0 when every check passes.                          }
{                                                       }
{*******************************************************}

{$IFDEF FPC}
{$MODE DELPHI}
{$ELSE}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  LazUTF8, SysUtils, Classes, rpjsonfpc,
{$ELSE}
  System.SysUtils, System.Classes, System.JSON,
{$ENDIF}
  rptypes, rpdatainfo, rpreport
{$IFNDEF BEFORE_D3}
  , rpreportdesignercontracts
{$ENDIF}
  ;

const
  // Larger than 32 bits: an Integer would cut it
  BIG_ID = 5000000000123;
{$IFDEF FPC}
  // UTF-8, the encoding of the LCL strings: 'Ventas a<n tilde>o <euro>'
  SCHEMA_TEXT = 'Ventas a'#$C3#$B1'o '#$E2#$82#$AC;
  EXPECTED_SUFFIX = '_fpc';
{$ELSE}
  SCHEMA_TEXT = 'Ventas a'#$00F1'o '#$20AC;
  EXPECTED_SUFFIX = '';
{$ENDIF}

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  if ACondition then
    WriteLn('OK   ', AWhat)
  else
  begin
    WriteLn('FAIL ', AWhat);
    Inc(Failures);
  end;
end;

// A report with a connection (not an Agent one: the text format would be
// XML) and two datasets without schema
function NewPlainReport: TRpReport;
var
  LDataset: TRpDataInfoItem;
begin
  Result := TRpReport.Create(nil);
  Result.CreateNew;
  Result.DatabaseInfo.Add('CONN1');
  LDataset := Result.DataInfo.Add('CUSTOMERS');
  LDataset.DatabaseAlias := 'CONN1';
  LDataset.SQL := 'SELECT * FROM CUSTOMERS';
  LDataset := Result.DataInfo.Add('ORDERS');
  LDataset.DatabaseAlias := 'CONN1';
  LDataset.SQL := 'SELECT * FROM ORDERS WHERE CUSTID=:CUSTID';
  LDataset.DataSource := 'CUSTOMERS';
end;

function SaveReport(AReport: TRpReport; AFormat: TRpStreamFormat): TMemoryStream;
begin
  AReport.StreamFormat := AFormat;
  Result := TMemoryStream.Create;
  AReport.SaveToStream(Result);
  Result.Position := 0;
end;

function LoadReport(AStream: TStream): TRpReport;
begin
  Result := TRpReport.Create(nil);
  AStream.Position := 0;
  Result.LoadFromStream(AStream);
end;

function StreamText(AStream: TMemoryStream): string;
var
  LBytes: TBytes;
begin
  SetLength(LBytes, AStream.Size);
  if AStream.Size > 0 then
    Move(AStream.Memory^, LBytes[0], AStream.Size);
  Result := TEncoding.ANSI.GetString(LBytes);
end;

function Occurrences(const ASub, AText: string): Integer;
var
  LRest: string;
  LPos: Integer;
begin
  Result := 0;
  LRest := AText;
  LPos := Pos(ASub, LRest);
  while LPos > 0 do
  begin
    Inc(Result);
    LRest := Copy(LRest, LPos + Length(ASub), MaxInt);
    LPos := Pos(ASub, LRest);
  end;
end;

function SameBytes(AStream: TMemoryStream; const AFileName: string): Boolean;
var
  LFile: TMemoryStream;
begin
  LFile := TMemoryStream.Create;
  try
    LFile.LoadFromFile(AFileName);
    Result := (LFile.Size = AStream.Size) and
      CompareMem(LFile.Memory, AStream.Memory, AStream.Size);
  finally
    LFile.Free;
  end;
end;

procedure Dump(const AFolder: string);
var
  LReport: TRpReport;
  LStream: TMemoryStream;
begin
  ForceDirectories(AFolder);
  LReport := NewPlainReport;
  try
    LStream := SaveReport(LReport, rpStreamXML);
    try
      LStream.SaveToFile(IncludeTrailingPathDelimiter(AFolder) + 'plain.xml');
    finally
      LStream.Free;
    end;
    LStream := SaveReport(LReport, rpStreamText);
    try
      LStream.SaveToFile(IncludeTrailingPathDelimiter(AFolder) + 'plain.txt');
    finally
      LStream.Free;
    end;
  finally
    LReport.Free;
  end;
  WriteLn('Written to ', AFolder);
end;

{$IFNDEF BEFORE_D3}

procedure TestPlain(const AExpectedFolder: string);
var
  LReport: TRpReport;
  LStream: TMemoryStream;
  LText: string;
begin
  LReport := NewPlainReport;
  try
    LStream := SaveReport(LReport, rpStreamXML);
    try
      LText := StreamText(LStream);
      Check(Pos('HUBSCHEMAID', LText) = 0, 'XML without a Hub schema: no HUBSCHEMAID');
      Check(Pos('SCHEMANAME', LText) = 0, 'XML without a subschema: no SCHEMANAME');
      Check(SameBytes(LStream, AExpectedFolder + 'expected_plain.xml'),
        'XML of a dataset without them, byte for byte as before');
    finally
      LStream.Free;
    end;
    LStream := SaveReport(LReport, rpStreamText);
    try
      LText := StreamText(LStream);
      Check((Pos('HubSchemaId', LText) = 0) and (Pos('SchemaName', LText) = 0),
        'text without them: no HubSchemaId nor SchemaName');
      Check(SameBytes(LStream, AExpectedFolder + 'expected_plain' + EXPECTED_SUFFIX + '.txt'),
        'text of a dataset without them, byte for byte as before');
    finally
      LStream.Free;
    end;
  finally
    LReport.Free;
  end;
end;

procedure TestRoundTrip(AFormat: TRpStreamFormat; const AName: string);
var
  LReport, LLoaded: TRpReport;
  LStream: TMemoryStream;
  LText: string;
begin
  LReport := NewPlainReport;
  try
    LReport.DataInfo.Items[0].HubSchemaId := BIG_ID;
    LReport.DataInfo.Items[0].SchemaName := SCHEMA_TEXT;
    // Only one of them in the second one
    LReport.DataInfo.Items[1].SchemaName := 'Orders';
    LStream := SaveReport(LReport, AFormat);
    try
      LText := StreamText(LStream);
      if AFormat = rpStreamXML then
      begin
        Check(Pos('<HUBSCHEMAID type="Integer">5000000000123</HUBSCHEMAID>', LText) > 0,
          AName + ': HUBSCHEMAID written whole');
        Check(Pos('<SCHEMANAME type="WideString">Orders</SCHEMANAME>', LText) > 0,
          AName + ': SCHEMANAME written');
        // The opening and closing tags of the first dataset only
        Check(Occurrences('HUBSCHEMAID', LText) = 2,
          AName + ': no HUBSCHEMAID for a dataset without a Hub schema');
      end
      else if AFormat = rpStreamText then
      begin
        Check(Pos('HubSchemaId = 5000000000123', LText) > 0,
          AName + ': HubSchemaId written whole');
        Check(Pos('SchemaName = ''Orders''', LText) > 0, AName + ': SchemaName written');
        Check(Occurrences('HubSchemaId', LText) = 1,
          AName + ': no HubSchemaId for a dataset without a Hub schema');
      end;
      LLoaded := LoadReport(LStream);
      try
        Check(LLoaded.DataInfo.Items[0].HubSchemaId = BIG_ID,
          AName + ': HubSchemaId read back ' + IntToStr(LLoaded.DataInfo.Items[0].HubSchemaId));
        Check(LLoaded.DataInfo.Items[0].SchemaName = SCHEMA_TEXT,
          AName + ': SchemaName read back (not ASCII) ' + LLoaded.DataInfo.Items[0].SchemaName);
        Check(LLoaded.DataInfo.Items[1].HubSchemaId = 0,
          AName + ': no HubSchemaId stays 0');
        Check(LLoaded.DataInfo.Items[1].SchemaName = 'Orders',
          AName + ': SchemaName alone read back');
        Check((LLoaded.DataInfo.Items[1].SQL = LReport.DataInfo.Items[1].SQL) and
          (LLoaded.DataInfo.Items[1].DataSource = 'CUSTOMERS'),
          AName + ': the rest of the dataset read back');
      finally
        LLoaded.Free;
      end;
    finally
      LStream.Free;
    end;
  finally
    LReport.Free;
  end;
end;

procedure TestItem;
var
  LReport: TRpReport;
  LCopy: TRpDataInfoItem;
begin
  LReport := NewPlainReport;
  try
    LReport.DataInfo.Items[0].SetItemProperty('SchemaName', 'Sales');
    LReport.DataInfo.Items[0].SetItemProperty('HubSchemaId', BIG_ID);
    Check(LReport.DataInfo.Items[0].SchemaName = 'Sales', 'SetItemProperty SchemaName');
    Check(LReport.DataInfo.Items[0].GetItemProperty('SchemaName') = 'Sales',
      'GetItemProperty SchemaName');
    LCopy := LReport.DataInfo.Items[1];
    LCopy.Assign(LReport.DataInfo.Items[0]);
    Check((LCopy.SchemaName = 'Sales') and (LCopy.HubSchemaId = BIG_ID),
      'Assign copies SchemaName and HubSchemaId');
  finally
    LReport.Free;
  end;
end;

procedure TestInlineConfig;
var
  LConfig, LRead: TRpApiDatabaseConfig;
  LJson: TJSONObject;
begin
  LConfig := TRpApiDatabaseConfig.Create;
  LRead := TRpApiDatabaseConfig.Create;
  try
    LConfig.Name := 'FBEXAMPLE';
    LConfig.Dialect := 'Firebird5';
    LConfig.SchemaTablesJson := '[{"name":"SALES","columns":[]}]';
    LConfig.SchemaName := 'Ventas';
    LJson := LConfig.ToJsonObject;
    try
      Check((LJson.Values['schemaName'] <> nil) and
        (LJson.Values['schemaName'].Value = 'Ventas'),
        'the inline config sends schemaName');
      LRead.FromJsonObject(LJson);
      Check(LRead.SchemaName = 'Ventas', 'and reads it back');
    finally
      LJson.Free;
    end;
    LConfig.SchemaName := '';
    LJson := LConfig.ToJsonObject;
    try
      Check(LJson.Values['schemaName'] = nil, 'all the tables: no schemaName');
    finally
      LJson.Free;
    end;
    LConfig.SchemaTablesJson := '';
    LConfig.SchemaName := 'Ventas';
    LConfig.HubDatabaseId := 7;
    LConfig.HubSchemaId := 9;
    LJson := LConfig.ToJsonObject;
    try
      Check(LJson.Values['schemaName'] = nil, 'a Hub schema: no schemaName');
    finally
      LJson.Free;
    end;
    LRead.Assign(LConfig);
    Check(LRead.SchemaName = 'Ventas', 'Assign copies SchemaName');
  finally
    LRead.Free;
    LConfig.Free;
  end;
end;

{$ENDIF}

var
  LExpected: string;
begin
  try
    if (ParamCount >= 2) and SameText(ParamStr(1), '-dump') then
    begin
      Dump(ParamStr(2));
      Exit;
    end;
{$IFDEF BEFORE_D3}
    WriteLn('Built with BEFORE_D3: only -dump');
    ExitCode := 1;
{$ELSE}
    LExpected := IncludeTrailingPathDelimiter(
      ExpandFileName(ExtractFilePath(ParamStr(0)) + '..'));
    TestPlain(LExpected);
    TestRoundTrip(rpStreamXML, 'XML');
    TestRoundTrip(rpStreamText, 'text');
    TestRoundTrip(rpStreamBinary, 'binary');
    TestItem;
    TestInlineConfig;
{$ENDIF}
  except
    on E: Exception do
    begin
      WriteLn('ERROR ', E.ClassName, ': ', E.Message);
      Inc(Failures);
    end;
  end;
{$IFNDEF BEFORE_D3}
  if Failures = 0 then
    WriteLn('All checks passed')
  else
    WriteLn(Failures, ' check(s) failed');
  ExitCode := Failures;
{$ENDIF}
end.

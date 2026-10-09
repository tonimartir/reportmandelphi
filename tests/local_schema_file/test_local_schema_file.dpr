program test_local_schema_file;

{*******************************************************}
{                                                       }
{   The local schema file, version 2 (rplocalschemas),  }
{   without a database: the same fixture the C# tests   }
{   read (Reportman.Server.Tests/Fixtures).             }
{                                                       }
{   1. A file is saved as it was read, with what this   }
{      version does not know (at every level).          }
{   2. A subschema sends the columns it chose, their    }
{      allowed values and the relations whose two ends  }
{      travel; without one, everything.                 }
{   3. Reading the catalog again keeps what people      }
{      wrote and drops the tables and columns gone.     }
{                                                       }
{   Delphi: build.bat. Lazarus: test_local_schema_      }
{   file.lpi (lazbuild). Run:                           }
{                                                       }
{   test_local_schema_file [<fixture.json>] [<saved>]   }
{                                                       }
{   Without arguments, ..\dbxschemas-v2.json next to    }
{   the program's folder. Exit code 0 when every check  }
{   passes.                                             }
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
  rplocalschemas;

var
  Failures: Integer;

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

// Two JSON values are the same: objects whatever the order of their
// properties, arrays in order
function SameJson(A, B: TJSONValue): Boolean;
var
  I: Integer;
  LOther: TJSONValue;
begin
  if (A = nil) or (B = nil) then
    Exit(A = B);
  if (A is TJSONObject) and (B is TJSONObject) then
  begin
    Result := TJSONObject(A).Count = TJSONObject(B).Count;
    if not Result then
      Exit;
    for I := 0 to TJSONObject(A).Count - 1 do
    begin
      LOther := TJSONObject(B).Values[TJSONObject(A).Pairs[I].JsonString.Value];
      if not SameJson(TJSONObject(A).Pairs[I].JsonValue, LOther) then
        Exit(False);
    end;
  end
  else if (A is TJSONArray) and (B is TJSONArray) then
  begin
    Result := TJSONArray(A).Count = TJSONArray(B).Count;
    if not Result then
      Exit;
    for I := 0 to TJSONArray(A).Count - 1 do
      if not SameJson(TJSONArray(A).Items[I], TJSONArray(B).Items[I]) then
        Exit(False);
  end
  else
    Result := (A.ClassType = B.ClassType) and (A.Value = B.Value);
end;

function ReadText(const AFileName: string): string;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.LoadFromFile(AFileName, TEncoding.UTF8);
    Result := LList.Text;
  finally
    LList.Free;
  end;
end;

function FindByName(AArray: TJSONArray; const AName: string): TJSONObject;
var
  I: Integer;
begin
  Result := nil;
  if AArray <> nil then
    for I := 0 to AArray.Count - 1 do
      if (AArray.Items[I] is TJSONObject) and
        SameText(TJSONObject(AArray.Items[I]).Values['name'].Value, AName) then
        Exit(TJSONObject(AArray.Items[I]));
end;

// The names of the objects of an array, joined with commas
function Names(AArray: TJSONArray): string;
var
  I: Integer;
begin
  Result := '';
  if AArray <> nil then
    for I := 0 to AArray.Count - 1 do
    begin
      if Result <> '' then
        Result := Result + ',';
      if AArray.Items[I] is TJSONObject then
        Result := Result + TJSONObject(AArray.Items[I]).Values['name'].Value
      else
        Result := Result + AArray.Items[I].Value;
    end;
end;

function Columns(ATable: TJSONObject): string;
begin
  Result := '';
  if ATable <> nil then
    Result := Names(TJSONArray(ATable.Values['columns']));
end;

function ForeignKeyCount(ATable: TJSONObject): Integer;
begin
  Result := -1;
  if (ATable <> nil) and (ATable.Values['foreignKeys'] is TJSONArray) then
    Result := TJSONArray(ATable.Values['foreignKeys']).Count;
end;

procedure TestRoundTrip(const AFixture, ASaved: string);
var
  LFile: TRpLocalSchemaFile;
  LRead, LWritten: TJSONValue;
begin
  LFile := TRpLocalSchemaFile.Create;
  try
    LFile.LoadFromFile(AFixture);
    LFile.SaveToFile(ASaved);
  finally
    LFile.Free;
  end;
  LRead := TJSONObject.ParseJSONValue(ReadText(AFixture));
  LWritten := TJSONObject.ParseJSONValue(ReadText(ASaved));
  try
    Check(SameJson(LRead, LWritten),
      'a file is saved as it was read, with what this version does not know');
  finally
    LRead.Free;
    LWritten.Free;
  end;
end;

procedure TestSubschemas(const AFixture: string);
var
  LFile: TRpLocalSchemaFile;
  LTables: TJSONArray;
  LState: TJSONObject;
  LCount, LWidest: Integer;
begin
  LFile := TRpLocalSchemaFile.Create;
  try
    LFile.LoadFromFile(AFixture);
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('Ventas')));
    try
      Check(Names(LTables) = 'CUSTOMERS,SALES', 'Ventas takes its tables');
      Check(Columns(FindByName(LTables, 'SALES')) = 'SALEID,CUSTOMERID,TOTAL',
        'Ventas takes the columns it chose of SALES');
      Check(Columns(FindByName(LTables, 'CUSTOMERS')) = 'CUSTOMERID,STATE',
        'a table without columns chosen goes whole');
      LState := FindByName(TJSONArray(FindByName(LTables, 'CUSTOMERS').Values['columns']), 'STATE');
      Check((LState <> nil) and (LState.Values['allowedValues'] is TJSONArray) and
        (TJSONArray(LState.Values['allowedValues']).Count = 2),
        'a column carries its allowed values');
      Check(ForeignKeyCount(FindByName(LTables, 'SALES')) = 1,
        'a relation whose two ends travel travels');
    finally
      LTables.Free;
    end;
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('Solo ventas')));
    try
      Check(ForeignKeyCount(FindByName(LTables, 'SALES')) = 0,
        'a relation to a table that does not travel does not travel');
    finally
      LTables.Free;
    end;
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('')));
    try
      Check((Pos('NOTES', Columns(FindByName(LTables, 'SALES'))) > 0) and
        (ForeignKeyCount(FindByName(LTables, 'SALES')) = 1),
        'without a subschema everything goes');
    finally
      LTables.Free;
    end;
    // The sizes the schema selector of the chat shows and checks against
    // the plan
    LFile.GetSchemaSize('', LCount, LWidest);
    Check((LCount = 3) and (LWidest = 4), 'all the tables: 3 tables, 4 columns the widest');
    LFile.GetSchemaSize('Ventas', LCount, LWidest);
    Check((LCount = 2) and (LWidest = 3),
      'Ventas: 2 tables, the 3 columns it chose of SALES the widest');
    LFile.GetSchemaSize('Productos', LCount, LWidest);
    Check((LCount = 1) and (LWidest = 2), 'Productos: 1 table of 2 columns');
    LFile.GetSchemaSize('Gone', LCount, LWidest);
    Check(LCount = 3, 'a subschema that is not in the file: all the tables');
  finally
    LFile.Free;
  end;
end;

const
  FreshCatalog =
    '[{"name":"CUSTOMERS","context":"","columns":[' +
    '{"name":"CUSTOMERID","dataType":"Integer","context":"","isPrimaryKey":true,"detectedType":"INTEGER"},' +
    '{"name":"STATE","dataType":"String","context":"From the database","isPrimaryKey":false,"detectedType":"CHAR(1)"}],' +
    '"foreignKeys":[]},' +
    '{"name":"SALES","context":"","columns":[' +
    '{"name":"SALEID","dataType":"Integer","context":"","isPrimaryKey":true,"detectedType":"INTEGER"},' +
    '{"name":"customerid","dataType":"Integer","context":"","isPrimaryKey":false,"detectedType":"INTEGER"},' +
    '{"name":"NOTES","dataType":"TextLong","context":"","isPrimaryKey":false,"detectedType":"BLOB"}],' +
    '"foreignKeys":[{"constraintName":"FK_SALES_CUSTOMER","targetTable":"CUSTOMERS",' +
    '"sourceColumns":["customerid"],"targetColumns":["CUSTOMERID"],"relationshipContext":""}]}]';

procedure TestRefresh(const AFixture: string);
var
  LFile: TRpLocalSchemaFile;
  LColumns: TStringList;
  LCustomers, LForeignKey, LRoot, LState: TJSONObject;
  LSchema: TRpLocalSubSchema;
begin
  LFile := TRpLocalSchemaFile.Create;
  LColumns := TStringList.Create;
  try
    LFile.LoadFromFile(AFixture);
    // The database again: SALES lost TOTAL, PRODUCTS is gone
    LFile.SetCatalog(TJSONArray(TJSONObject.ParseJSONValue(FreshCatalog)), 'Firebird5');
    LCustomers := FindByName(LFile.Tables, 'CUSTOMERS');
    Check(LCustomers.Values['context'].Value = 'The customers', 'the context of a table is kept');
    Check(LCustomers.Values['futureTableNote'] <> nil, 'what a table had of a newer version is kept');
    LState := FindByName(TJSONArray(LCustomers.Values['columns']), 'STATE');
    Check(LState.Values['context'].Value = 'Account state', 'what a person wrote beats the comment');
    Check((LState.Values['allowedValues'] is TJSONArray) and
      (TJSONArray(LState.Values['allowedValues']).Count = 2), 'the allowed values are kept');
    Check(LState.Values['futureColumnFlag'] <> nil, 'what a column had of a newer version is kept');
    LForeignKey := TJSONObject(TJSONArray(FindByName(LFile.Tables, 'SALES').Values['foreignKeys']).Items[0]);
    Check((LForeignKey.Values['relationshipContext'].Value = 'Who bought') and
      (LForeignKey.Values['futureFkWeight'] <> nil), 'a relation keeps what it had');
    LSchema := LFile.Schemas[LFile.IndexOfSchema('Ventas')];
    LSchema.GetColumns('SALES', LColumns);
    Check(LColumns.CommaText = 'SALEID,customerid',
      'the columns gone leave the subschema, as the catalog spells them now: ' + LColumns.CommaText);
    Check(LFile.Schemas[LFile.IndexOfSchema('Productos')].Tables.Count = 0,
      'a table gone leaves the subschema');
    LRoot := TJSONObject(TJSONObject.ParseJSONValue(LFile.ToJsonText));
    try
      Check((LRoot.Values['futureRootSetting'] <> nil) and (LRoot.Values['version'].Value = '2'),
        'the file keeps what it had of a newer version, at version 2');
      Check(FindByName(TJSONArray(LRoot.Values['schemas']), 'Ventas').Values['futureSchemaColor'] <> nil,
        'a subschema keeps what it had of a newer version');
    finally
      LRoot.Free;
    end;
  finally
    LColumns.Free;
    LFile.Free;
  end;
end;

var
  LFixture, LSaved: string;
begin
  Failures := 0;
  try
    if ParamCount >= 1 then
      LFixture := ParamStr(1)
    else
      LFixture := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + 'dbxschemas-v2.json');
    if ParamCount >= 2 then
      LSaved := ParamStr(2)
    else
      LSaved := ExtractFilePath(ParamStr(0)) + 'saved-dbxschemas-v2.json';
    TestRoundTrip(LFixture, LSaved);
    TestSubschemas(LFixture);
    TestRefresh(LFixture);
  except
    on E: Exception do
    begin
      WriteLn('ERROR ', E.ClassName, ': ', E.Message);
      Inc(Failures);
    end;
  end;
  if Failures = 0 then
    WriteLn('All checks passed')
  else
    WriteLn(Failures, ' check(s) failed');
  ExitCode := Failures;
end.

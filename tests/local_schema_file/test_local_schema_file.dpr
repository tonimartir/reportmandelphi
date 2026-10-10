program test_local_schema_file;

{*******************************************************}
{                                                       }
{   The local schema file, version 2 (rplocalschemas),  }
{   without a database: the same fixture the C# tests   }
{   read (Reportman.Server.Tests/Fixtures).             }
{                                                       }
{   1. A file is saved as it was read, with what this   }
{      version does not know (at every level).          }
{   2. A subschema sends the columns it chose (only     }
{      the primary key of a table without a list),      }
{      their allowed values and the relations whose     }
{      two ends travel; without one, everything.        }
{   3. Reading the catalog again keeps what people      }
{      wrote (relations by hand included) and drops     }
{      the tables and columns gone.                     }
{   4. What the local schema screens do with the        }
{      dictionary and the subschemas.                   }
{   5. The request of "Analyze with AI".                }
{   6. Export and import with the Reportman AI web.     }
{   7. Only a subschema goes to the AI (F8): never the  }
{      dictionary, and the import from the library.     }
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
  LazUTF8, SysUtils, Classes, Contnrs, rpjsonfpc,
{$ELSE}
  System.SysUtils, System.Classes, System.Contnrs, System.JSON,
{$ENDIF}
  rplocalschemas, rpreportdesignercontracts, rpdatahttp, rpdatainfo,
  rpdesignerclientsql;

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
      // None chosen: only its primary key (people choose the columns and
      // describe them; Toni, 10-10)
      Check(Columns(FindByName(LTables, 'CUSTOMERS')) = 'CUSTOMERID',
        'a table without columns chosen goes with its primary key only');
      Check(ForeignKeyCount(FindByName(LTables, 'SALES')) = 1,
        'a relation whose two ends travel travels');
    finally
      LTables.Free;
    end;
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('Productos')));
    try
      Check(Columns(FindByName(LTables, 'PRODUCTS')) = 'PRODUCTID',
        'Productos: PRODUCTS goes with its primary key only');
    finally
      LTables.Free;
    end;
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('Solo ventas')));
    try
      Check(Columns(FindByName(LTables, 'SALES')) = 'SALEID',
        'Solo ventas: SALES goes with its primary key only');
      Check(ForeignKeyCount(FindByName(LTables, 'SALES')) = 0,
        'a relation to a table that does not travel does not travel');
    finally
      LTables.Free;
    end;
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('')));
    try
      Check((Columns(FindByName(LTables, 'SALES')) = 'SALEID,CUSTOMERID,TOTAL,NOTES') and
        (Columns(FindByName(LTables, 'CUSTOMERS')) = 'CUSTOMERID,STATE') and
        (ForeignKeyCount(FindByName(LTables, 'SALES')) = 1),
        'without a subschema everything goes');
      LState := FindByName(TJSONArray(FindByName(LTables, 'CUSTOMERS').Values['columns']), 'STATE');
      Check((LState <> nil) and (LState.Values['allowedValues'] is TJSONArray) and
        (TJSONArray(LState.Values['allowedValues']).Count = 2),
        'a column carries its allowed values');
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
    Check((LCount = 1) and (LWidest = 1), 'Productos: 1 table, its primary key');
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
  LColumns, LTargetColumns: TStringList;
  LCustomers, LForeignKey, LRoot, LState: TJSONObject;
  LSchema: TRpLocalSubSchema;
begin
  LFile := TRpLocalSchemaFile.Create;
  LColumns := TStringList.Create;
  LTargetColumns := TStringList.Create;
  try
    LFile.LoadFromFile(AFixture);
    // Two relations the database does not declare: one to a table that
    // stays, one to a table that goes
    LColumns.CommaText := 'CUSTOMERID';
    LFile.AddRelation('CUSTOMERS', 'SALES', LColumns, LColumns, 'The sales of the customer');
    LColumns.CommaText := 'SALEID';
    LTargetColumns.CommaText := 'PRODUCTID';
    LFile.AddRelation('SALES', 'PRODUCTS', LColumns, LTargetColumns, 'Gone');
    LColumns.CommaText := 'TOTAL';
    LTargetColumns.CommaText := 'CUSTOMERID';
    LFile.AddRelation('SALES', 'CUSTOMERS', LColumns, LTargetColumns, 'A column gone');
    // The database again: SALES lost TOTAL, PRODUCTS is gone
    LFile.SetCatalog(TJSONArray(TJSONObject.ParseJSONValue(FreshCatalog)), 'Firebird5');
    LCustomers := FindByName(LFile.Tables, 'CUSTOMERS');
    LForeignKey := nil;
    if (LCustomers.Values['foreignKeys'] is TJSONArray) and
      (TJSONArray(LCustomers.Values['foreignKeys']).Count = 1) then
      LForeignKey := TJSONObject(TJSONArray(LCustomers.Values['foreignKeys']).Items[0]);
    Check((LForeignKey <> nil) and (LForeignKey.Values['constraintName'].Value = '') and
      (LForeignKey.Values['relationshipContext'].Value = 'The sales of the customer') and
      (Names(TJSONArray(LForeignKey.Values['targetColumns'])) = 'customerid'),
      'a relation written by hand is kept, as the catalog spells its columns now');
    Check(TJSONArray(FindByName(LFile.Tables, 'SALES').Values['foreignKeys']).Count = 1,
      'a relation written by hand to a table gone, or over a column gone, leaves');
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
    LTargetColumns.Free;
    LColumns.Free;
    LFile.Free;
  end;
end;

// A relation by hand that the database declares later: it is the one of the
// database, with what the person wrote when the database says nothing
procedure TestManualDeclaredLater;
const
  Previous =
    '{"version":2,"alias":"X","dialect":"Firebird5","tables":[' +
    '{"name":"CUSTOMERS","context":"","columns":[{"name":"CUSTOMERID","isPrimaryKey":true},' +
    '{"name":"STATE"}],"foreignKeys":[]},' +
    '{"name":"SALES","context":"","columns":[{"name":"SALEID","isPrimaryKey":true},' +
    '{"name":"CUSTOMERID"},{"name":"NOTES"}],"foreignKeys":[{"constraintName":"",' +
    '"targetTable":"CUSTOMERS","sourceColumns":["CUSTOMERID"],"targetColumns":["CUSTOMERID"],' +
    '"relationshipContext":"Who bought, by hand"}]}],"schemas":[]}';
var
  LFile: TRpLocalSchemaFile;
  LForeignKeys: TJSONArray;
begin
  LFile := TRpLocalSchemaFile.Create;
  try
    LFile.LoadFromJson(Previous);
    LFile.SetCatalog(TJSONArray(TJSONObject.ParseJSONValue(FreshCatalog)), 'Firebird5');
    LForeignKeys := TJSONArray(LFile.FindTable('SALES').Values['foreignKeys']);
    Check((LForeignKeys.Count = 1) and
      (TJSONObject(LForeignKeys.Items[0]).Values['constraintName'].Value = 'FK_SALES_CUSTOMER') and
      (TJSONObject(LForeignKeys.Items[0]).Values['relationshipContext'].Value = 'Who bought, by hand'),
      'a relation by hand the database declares now is the one of the database, with its description');
  finally
    LFile.Free;
  end;
end;

function Joined(AList: TStrings): string;
begin
  Result := AList.CommaText;
end;

procedure TestScreens(const AFixture: string);
var
  LFile: TRpLocalSchemaFile;
  LList, LLabels, LValues: TStringList;
  LRelations: TObjectList;
  LSchema, LCopy, LVentas: TRpLocalSubSchema;
  LTables: TJSONArray;
  LState: TJSONObject;
begin
  LFile := TRpLocalSchemaFile.Create;
  LList := TStringList.Create;
  LValues := TStringList.Create;
  LLabels := TStringList.Create;
  LRelations := TObjectList.Create(True);
  try
    LFile.LoadFromFile(AFixture);
    LVentas := LFile.Schemas[LFile.IndexOfSchema('Ventas')];
    // What travels, as the screens show it
    LFile.GetTravelingColumns(nil, 'SALES', LList);
    Check(Joined(LList) = 'SALEID,CUSTOMERID,TOTAL,NOTES', 'all the tables: every column travels');
    LFile.GetTravelingColumns(LVentas, 'CUSTOMERS', LList);
    Check(Joined(LList) = 'CUSTOMERID', 'Ventas: CUSTOMERS travels with its primary key');
    Check(not LFile.ColumnTravels(LVentas, 'SALES', 'NOTES') and
      LFile.ColumnTravels(LVentas, 'sales', 'total'), 'a column travels when it is chosen');
    // A table enters with its primary key, as a list of its own
    LSchema := LFile.AddSchema('Compras');
    LFile.AddSchemaTable(LSchema, 'sales');
    Check((LSchema.Tables.CommaText = 'SALES') and LSchema.GetColumns('SALES', LList) and
      (Joined(LList) = 'SALEID'), 'a table enters as the catalog spells it, with its primary key: ' +
      Joined(LList));
    LFile.GetSuggestedRelations(LSchema, LRelations);
    Check(LRelations.Count = 1, 'a relation of a chosen table that does not travel is suggested');
    LRelations.Clear;
    LFile.SetColumnChosen(LSchema, 'SALES', 'customerid', True);
    LSchema.GetColumns('SALES', LList);
    Check(Joined(LList) = 'SALEID,CUSTOMERID', 'choosing a column adds it in the order of the catalog');
    // The relation to CUSTOMERS is a suggestion until it is completed
    LFile.GetRelations(LSchema, LRelations);
    Check(LRelations.Count = 0, 'no relation travels while CUSTOMERS is not there');
    LRelations.Clear;
    LFile.GetSuggestedRelations(LSchema, LRelations);
    Check((LRelations.Count = 1) and
      (TRpLocalRelation(LRelations[0]).TargetTable = 'CUSTOMERS'), 'the relation to CUSTOMERS is suggested');
    if LRelations.Count = 1 then
      LFile.CompleteRelation(LSchema, TRpLocalRelation(LRelations[0]));
    LRelations.Clear;
    LFile.GetRelations(LSchema, LRelations);
    Check((LRelations.Count = 1) and (LSchema.Tables.CommaText = 'SALES,CUSTOMERS') and
      (TRpLocalRelation(LRelations[0]).Context = 'Who bought'),
      'Complete adds the target table with its key and the relation travels');
    LRelations.Clear;
    LFile.GetSuggestedRelations(LSchema, LRelations);
    Check(LRelations.Count = 0, 'nothing more to suggest');
    LRelations.Clear;
    LFile.GetRelations(nil, LRelations);
    Check(LRelations.Count = 1, 'all the tables: every relation');
    LRelations.Clear;
    // The same relation by hand: not twice, what was written goes to it
    LList.CommaText := 'customerid';
    LFile.AddRelation('sales', 'customers', LList, LList, 'Who bought it');
    LFile.GetRelations(nil, LRelations);
    Check((LRelations.Count = 1) and not TRpLocalRelation(LRelations[0]).IsManual and
      (TRpLocalRelation(LRelations[0]).Context = 'Who bought it'),
      'a relation that is there is not added twice, it takes the description');
    LRelations.Clear;
    // Leaving the last column: the primary key again
    LFile.SetColumnChosen(LSchema, 'CUSTOMERS', 'CUSTOMERID', False);
    Check(not LSchema.GetColumns('CUSTOMERS', LList) and
      LFile.ColumnTravels(LSchema, 'CUSTOMERS', 'CUSTOMERID'),
      'an empty list is the primary key again');
    // "Also in"
    LFile.GetSchemasWithColumn('SALES', 'TOTAL', LVentas, LList);
    Check(LList.Count = 0, 'TOTAL is in no other subschema');
    LFile.GetSchemasWithColumn('SALES', 'CUSTOMERID', LVentas, LList);
    Check(Joined(LList) = 'Compras', 'CUSTOMERID is also in Compras: ' + Joined(LList));
    LFile.GetSchemasWithColumn('SALES', 'SALEID', nil, LList);
    Check(Joined(LList) = 'Ventas,"Solo ventas",Compras', 'SALEID is in every subschema with SALES');
    // Duplicate and rename
    LCopy := LFile.DuplicateSchema(LFile.IndexOfSchema('Ventas'), 'Ventas 2');
    LCopy.GetColumns('SALES', LList);
    Check((LCopy.Description = 'Sales') and (LCopy.Tables.CommaText = 'SALES,CUSTOMERS') and
      (Joined(LList) = 'SALEID,CUSTOMERID,TOTAL'), 'a copy takes the tables and columns');
    LFile.RenameSchema(LFile.IndexOfSchema('Ventas 2'), 'Ventas copia');
    Check(LFile.IndexOfSchema('Ventas copia') >= 0, 'a subschema is renamed');
    try
      LFile.RenameSchema(LFile.IndexOfSchema('Ventas copia'), 'ventas');
      Check(False, 'two subschemas with the same name');
    except
      on E: Exception do
        Check(Pos('already exists', E.Message) > 0, 'two subschemas can not have the same name');
    end;
    LFile.RemoveSchemaTable(LCopy, 'SALES');
    Check((LCopy.Tables.CommaText = 'CUSTOMERS') and not LCopy.GetColumns('SALES', LList),
      'a table leaves with its columns');
    // The dictionary: written once, the same in every subschema
    LFile.SetColumnContext('SALES', 'SALEID', 'The number of the sale');
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('Solo ventas')));
    try
      Check(FindByName(TJSONArray(FindByName(LTables, 'SALES').Values['columns']),
        'SALEID').Values['context'].Value = 'The number of the sale',
        'the description of a column is the same in every subschema');
    finally
      LTables.Free;
    end;
    LValues.CommaText := 'A,B,C,';
    LLabels.CommaText := 'Active,"Blocked now",Closed,';
    LFile.SetAllowedValues('CUSTOMERS', 'STATE', LValues, LLabels);
    LFile.GetAllowedValues('CUSTOMERS', 'STATE', LValues, LLabels);
    LState := TJSONObject(TJSONArray(LFile.FindColumn('CUSTOMERS', 'STATE').Values['allowedValues']).Items[1]);
    Check((Joined(LValues) = 'A,B,C') and (LLabels[1] = 'Blocked now') and
      (LState.Values['futureColor'] <> nil),
      'the allowed values are written and a value keeps what it had of a newer version');
    LValues.Clear;
    LLabels.Clear;
    LFile.SetAllowedValues('CUSTOMERS', 'STATE', LValues, LLabels);
    Check(LFile.FindColumn('CUSTOMERS', 'STATE').Values['allowedValues'] = nil,
      'no allowed values: the property leaves');
    LFile.SetTableContext('products', 'What we sell');
    Check(LFile.FindTable('PRODUCTS').Values['context'].Value = 'What we sell',
      'the description of a table');
    // A relation by hand, and it can be deleted
    LValues.CommaText := 'SALEID';
    LLabels.CommaText := 'PRODUCTID';
    LFile.AddRelation('SALES', 'PRODUCTS', LValues, LLabels, 'By hand');
    LFile.GetRelations(nil, LRelations);
    Check((LRelations.Count = 2) and TRpLocalRelation(LRelations[1]).IsManual and
      (TRpLocalRelation(LRelations[1]).SourceColumnsText = 'SALEID'), 'a relation by hand is in the dictionary');
    if LRelations.Count = 2 then
    begin
      LFile.DeleteRelation(TRpLocalRelation(LRelations[0]));
      LFile.DeleteRelation(TRpLocalRelation(LRelations[1]));
    end;
    LRelations.Clear;
    LFile.GetRelations(nil, LRelations);
    Check(LRelations.Count = 1, 'a relation by hand is deleted, the one of the database stays');
    try
      LFile.AddRelation('SALES', 'PRODUCTS', LValues, LValues, '');
      Check(False, 'a relation with a column that is not there');
    except
      on E: Exception do
        Check(True, 'a relation with a column that is not there is refused');
    end;
    // The preview of the columns tab
    Check(RpLocalSchemaPreviewSql('Firebird5', 'SALES', 5) = 'SELECT FIRST 5 * FROM SALES', 'preview: Firebird');
    Check(RpLocalSchemaPreviewSql('PostgreSQL', 'sales', 5) = 'SELECT * FROM sales LIMIT 5', 'preview: PostgreSQL');
    Check(RpLocalSchemaPreviewSql('SQLServer', 'SALES', 5) = 'SELECT TOP 5 * FROM SALES', 'preview: SQL Server');
    Check(RpLocalSchemaPreviewSql('Oracle', 'SALES', 5) = 'SELECT * FROM SALES WHERE ROWNUM <= 5', 'preview: Oracle');
    Check(RpLocalSchemaPreviewSql('Default', 'SALES', 5) = 'SELECT * FROM SALES', 'preview: another one');
  finally
    LRelations.Free;
    LLabels.Free;
    LValues.Free;
    LList.Free;
    LFile.Free;
  end;
end;

// A relation travels when its two ends travel by table and by column: with
// both tables chosen and SALES with its primary key only, it is a suggestion
procedure TestSuggestions(const AFixture: string);
var
  LFile: TRpLocalSchemaFile;
  LList: TStringList;
  LRelations: TObjectList;
  LSchema: TRpLocalSubSchema;
  LTables: TJSONArray;
begin
  LFile := TRpLocalSchemaFile.Create;
  LList := TStringList.Create;
  LRelations := TObjectList.Create(True);
  try
    LFile.LoadFromFile(AFixture);
    LSchema := LFile.AddSchema('Both');
    LFile.AddSchemaTable(LSchema, 'SALES');
    LFile.AddSchemaTable(LSchema, 'CUSTOMERS');
    LFile.GetRelations(LSchema, LRelations);
    Check(LRelations.Count = 0, 'both tables chosen, SALES.CUSTOMERID not: the relation does not travel');
    LRelations.Clear;
    LTables := TJSONArray(TJSONObject.ParseJSONValue(LFile.SchemaTablesJson('Both')));
    try
      Check(ForeignKeyCount(FindByName(LTables, 'SALES')) = 0,
        'and the copilot does not send it');
    finally
      LTables.Free;
    end;
    LFile.GetSuggestedRelations(LSchema, LRelations);
    Check(LRelations.Count = 1, 'it is a suggestion although both tables are chosen');
    if LRelations.Count = 1 then
      LFile.CompleteRelation(LSchema, TRpLocalRelation(LRelations[0]));
    LRelations.Clear;
    LSchema.GetColumns('SALES', LList);
    Check(Joined(LList) = 'SALEID,CUSTOMERID',
      'Complete adds the source columns to the list, starting from the primary key');
    LFile.GetRelations(LSchema, LRelations);
    Check(LRelations.Count = 1, 'and then the relation travels');
    LRelations.Clear;
    // A relation by hand in a subschema is completed the same way
    LSchema := LFile.AddSchema('Hand');
    LFile.AddSchemaTable(LSchema, 'CUSTOMERS');
    LList.CommaText := 'CUSTOMERID';
    LRelations.Add(TRpLocalRelation.Create);
    TRpLocalRelation(LRelations[0]).SourceTable := 'CUSTOMERS';
    TRpLocalRelation(LRelations[0]).ForeignKey := LFile.AddRelation('CUSTOMERS',
      'SALES', LList, LList, 'Their sales');
    LFile.CompleteRelation(LSchema, TRpLocalRelation(LRelations[0]));
    LRelations.Clear;
    LSchema.GetColumns('SALES', LList);
    Check((LSchema.Tables.CommaText = 'CUSTOMERS,SALES') and
      (Joined(LList) = 'SALEID,CUSTOMERID'), 'a relation by hand brings its target and columns');
    LFile.GetRelations(LSchema, LRelations);
    Check(LRelations.Count = 2, 'both relations travel: ' + IntToStr(LRelations.Count));
  finally
    LRelations.Free;
    LList.Free;
    LFile.Free;
  end;
end;

procedure TestAnalyzeRequest(const AFixture: string);
var
  LConfig: TRpApiDatabaseConfig;
  LConfigJson, LRequest: TJSONObject;
  LFile: TRpLocalSchemaFile;
  LTables: TJSONArray;
begin
  LFile := TRpLocalSchemaFile.Create;
  LConfig := TRpApiDatabaseConfig.Create;
  try
    LFile.LoadFromFile(AFixture);
    // The inline config the copilot would send for the subschema
    LConfig.Name := 'FBEXAMPLE';
    LConfig.Dialect := LFile.CloudDialect;
    LConfig.SchemaTablesJson := LFile.SchemaTablesJson('ventas');
    LConfig.SchemaName := LFile.SchemaNameOf('ventas');
    LRequest := RpAnalyzeSchemaRequestJson(LConfig, 'Precision', 'reasoning', '', 0, '',
      'Spanish');
    try
      Check((LRequest.Values['aiTier'].Value = 'Precision') and
        (LRequest.Values['mode'].Value = 'Reasoning') and
        (LRequest.Values['languageCodeIso'].Value = 'es') and
        (LRequest.Values['transcribeLanguage'].Value = 'Spanish') and
        (LRequest.Values['agentSecret'] = nil) and (LRequest.Values['agentAiId'] = nil),
        'analyze: the AI and the language of the answer');
      LConfigJson := TJSONObject(LRequest.Values['config']);
      LTables := TJSONArray(LConfigJson.Values['schemaTables']);
      Check((LConfigJson.Values['name'].Value = 'FBEXAMPLE') and
        (LConfigJson.Values['dialect'].Value = 'Firebird5') and
        (LConfigJson.Values['schemaName'].Value = 'Ventas') and
        (LConfigJson.Values['hubDatabaseId'].Value = '0') and
        (LConfigJson.Values['hubSchemaId'].Value = '0') and
        (Names(LTables) = 'CUSTOMERS,SALES') and
        (Columns(FindByName(LTables, 'CUSTOMERS')) = 'CUSTOMERID'),
        'analyze: the inline config is what the copilot sends: ' + LConfigJson.ToJSON);
    finally
      LRequest.Free;
    end;
    LRequest := RpAnalyzeSchemaRequestJson(LConfig, 'LocalAgent', 'Fast', 'secret', 12, '',
      'xx');
    try
      Check((LRequest.Values['aiTier'].Value = 'LocalAgent') and
        (LRequest.Values['agentSecret'].Value = 'secret') and
        (LRequest.Values['agentAiId'].Value = '12') and
        (LRequest.Values['languageCodeIso'].Value = 'en'),
        'analyze: with the AI of an Agent');
    finally
      LRequest.Free;
    end;
  finally
    LConfig.Free;
    LFile.Free;
  end;
end;

// The tables a subschema sends, as JSON
function SchemaTablesOf(AFile: TRpLocalSchemaFile; const ASchemaName: string): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(AFile.SchemaTablesJson(ASchemaName));
end;

// Export and import with the Reportman AI web (docs/esquemas-locales-
// pantalla-plan.md 5.6)
procedure TestExportImport(const AFixture, AFolder: string);
const
  // The old Desktop: PascalCase and numeric data types; a table and two
  // columns that are not in the database
  DesktopFile =
    '{"Name":"Desktop","SchemaTables":[' +
    '{"Name":"sales","Context":"Sales of the old Desktop","Columns":[' +
    '{"Name":"saleid","DataType":1,"Context":"","IsPrimaryKey":true},' +
    '{"Name":"Total","DataType":3,"Context":"Total amount","IsPrimaryKey":false,' +
    '"AllowedValues":[]},' +
    '{"Name":"DISCOUNT","DataType":2}],' +
    '"ForeignKeys":[{"ConstraintName":"FK_SALES_CUSTOMER","TargetTable":"customers",' +
    '"SourceColumns":["CUSTOMERID"],"TargetColumns":["CUSTOMERID"],' +
    '"RelationshipContext":"From the Desktop"}]},' +
    '{"Name":"GONE","Columns":[{"Name":"ID","DataType":1}]},' +
    '{"Name":"products","Columns":[{"Name":"PRICE","DataType":3}]},' +
    '{"Name":"CUSTOMERS","Columns":[{"Name":"STATE","DataType":4,' +
    '"AllowedValues":[{"Value":"X","Label":"Closed"},{"Value":"","Label":""}]}]}]}';
var
  LExporter, LImporter: TRpLocalSchemaFile;
  LList, LValues, LLabels, LSkipped: TStringList;
  LRelations: TObjectList;
  LExported, LSent, LImported: TJSONValue;
  LExport, LName, LPath: string;
  LCount, LSchemas: Integer;
  LSchema: TRpLocalSubSchema;
  LState: TJSONObject;
begin
  LExporter := TRpLocalSchemaFile.Create;
  LImporter := TRpLocalSchemaFile.Create;
  LList := TStringList.Create;
  LValues := TStringList.Create;
  LLabels := TStringList.Create;
  LSkipped := TStringList.Create;
  LRelations := TObjectList.Create(True);
  try
    LExporter.LoadFromFile(AFixture);
    LImporter.LoadFromFile(AFixture);
    // Ventas, described: STATE chosen with three values, a table and a
    // column described, the relation of the database described again and
    // one by hand
    LSchema := LExporter.Schemas[LExporter.IndexOfSchema('Ventas')];
    LExporter.SetColumnChosen(LSchema, 'CUSTOMERS', 'STATE', True);
    LValues.CommaText := 'A,B,C';
    LLabels.CommaText := 'Active,Blocked,Closed';
    LExporter.SetAllowedValues('CUSTOMERS', 'STATE', LValues, LLabels);
    LExporter.SetTableContext('SALES', 'The sales');
    LExporter.SetColumnContext('SALES', 'TOTAL', 'Total with taxes');
    LList.CommaText := 'CUSTOMERID';
    LExporter.AddRelation('SALES', 'CUSTOMERS', LList, LList, 'Who bought it');
    LExporter.AddRelation('CUSTOMERS', 'SALES', LList, LList, 'Their sales');
    // The export is what the copilot sends of the subschema
    LExport := RpExportSchemaJson(LExporter, 'ventas');
    LExported := TJSONObject.ParseJSONValue(LExport);
    LSent := SchemaTablesOf(LExporter, 'Ventas');
    try
      Check((LExported is TJSONObject) and
        (TJSONObject(LExported).Values['name'].Value = 'Ventas') and
        SameJson(TJSONObject(LExported).Values['schemaTables'], LSent),
        'export: what the copilot sends of the subschema, named after it');
      Check(ForeignKeyCount(FindByName(TJSONArray(LSent), 'CUSTOMERS')) = 1,
        'export: the relation by hand travels');
      Check(Pos(#10'  "name"', StringReplace(LExport, #13, '', [rfReplaceAll])) = 2,
        'export: indented with 2 spaces');
    finally
      LSent.Free;
      LExported.Free;
    end;
    Check(RpExportSchemaFileName(LExporter, 'ventas') = 'Ventas_Config.json',
      'export: the file name of the web');
    LExported := TJSONObject.ParseJSONValue(RpExportSchemaJson(LExporter, ''));
    LSent := SchemaTablesOf(LExporter, '');
    try
      Check((LExported is TJSONObject) and
        (TJSONObject(LExported).Values['name'].Value = 'FBEXAMPLE') and
        SameJson(TJSONObject(LExported).Values['schemaTables'], LSent) and
        (TJSONArray(LSent).Count = 3),
        'export: all the tables, named after the alias');
    finally
      LSent.Free;
      LExported.Free;
    end;
    Check(RpExportSchemaFileName(LExporter, '') = 'FBEXAMPLE_Config.json',
      'export: all the tables, the file name of the alias');

    // Imported in the same database without those changes: the subschema
    // comes back, and what it says goes to the dictionary
    LCount := RpImportSchemaJson(LImporter, LExport, 'C:\exports\Ventas_Config.json',
      LName, LSkipped);
    Check((LCount = 2) and (LName = 'Ventas 2') and (LSkipped.Count = 0),
      'import: a new subschema, "Ventas 2" as Ventas exists: ' + LName + ' ' +
      IntToStr(LCount));
    LSent := SchemaTablesOf(LExporter, 'Ventas');
    LImported := SchemaTablesOf(LImporter, 'Ventas 2');
    try
      Check(SameJson(LSent, LImported),
        'import: the export of a subschema recreates it (tables, columns, ' +
        'descriptions, values and relations)');
    finally
      LImported.Free;
      LSent.Free;
    end;
    LSchema := LImporter.Schemas[LImporter.IndexOfSchema('Ventas 2')];
    LSchema.GetColumns('CUSTOMERS', LList);
    // In the order of the file (the export goes in the order of the catalog)
    Check((LSchema.Tables.CommaText = 'CUSTOMERS,SALES') and (Joined(LList) = 'CUSTOMERID,STATE'),
      'import: the tables with the columns of the file as their list: ' +
      LSchema.Tables.CommaText);
    Check((LImporter.FindTable('SALES').Values['context'].Value = 'The sales') and
      (LImporter.FindColumn('SALES', 'TOTAL').Values['context'].Value = 'Total with taxes'),
      'import: the descriptions go to the dictionary');
    LImporter.GetAllowedValues('CUSTOMERS', 'STATE', LValues, LLabels);
    LState := TJSONObject(TJSONArray(LImporter.FindColumn('CUSTOMERS', 'STATE').Values['allowedValues']).Items[1]);
    Check((Joined(LValues) = 'A,B,C') and (Joined(LLabels) = 'Active,Blocked,Closed') and
      (LState.Values['futureColor'] <> nil),
      'import: the allowed values go to the dictionary (a value keeps what it had)');
    LImporter.GetRelations(LSchema, LRelations);
    Check((LRelations.Count = 2) and
      not TRpLocalRelation(LRelations[1]).IsManual and
      (TRpLocalRelation(LRelations[1]).Context = 'Who bought it') and
      TRpLocalRelation(LRelations[0]).IsManual and
      (TRpLocalRelation(LRelations[0]).Context = 'Their sales'),
      'import: the declared relation takes the description, a new one enters by hand');
    LRelations.Clear;
    LImporter.GetRelations(nil, LRelations);
    Check(LRelations.Count = 2, 'import: no relation twice');
    LRelations.Clear;
    // Through a file, again: "Ventas 3"
    LPath := IncludeTrailingPathDelimiter(AFolder) + RpExportSchemaFileName(LExporter, 'Ventas');
    RpExportSchemaToFile(LExporter, 'Ventas', LPath);
    LCount := RpImportSchemaFile(LImporter, LPath, LName, LSkipped);
    Check((LCount = 2) and (LName = 'Ventas 3'), 'import: from a file, "Ventas 3": ' + LName);

    // The old Desktop
    LCount := RpImportSchemaJson(LImporter, DesktopFile, 'desktop.json', LName, LSkipped);
    LSchema := LImporter.Schemas[LImporter.IndexOfSchema(LName)];
    Check((LCount = 3) and (LName = 'Desktop') and
      (LSchema.Tables.CommaText = 'SALES,PRODUCTS,CUSTOMERS'),
      'import: PascalCase and numeric types, the tables as the catalog spells them: ' +
      LSchema.Tables.CommaText);
    LSchema.GetColumns('SALES', LList);
    Check(Joined(LList) = 'SALEID,TOTAL', 'import: the columns of the file that are there');
    LSchema.GetColumns('PRODUCTS', LList);
    Check(Joined(LList) = 'PRODUCTID', 'import: no column left, its primary key');
    Check(LImporter.FindColumn('SALES', 'TOTAL').Values['dataType'].Value = 'Currency',
      'import: the type is the one of the catalog');
    Check((LImporter.FindTable('SALES').Values['context'].Value = 'Sales of the old Desktop') and
      (LImporter.FindColumn('SALES', 'TOTAL').Values['context'].Value = 'Total amount') and
      (LImporter.FindColumn('SALES', 'SALEID').Values['context'].Value = ''),
      'import: what the file describes, read whatever the case of its names');
    LImporter.GetAllowedValues('CUSTOMERS', 'STATE', LValues, LLabels);
    Check((Joined(LValues) = 'X') and (Joined(LLabels) = 'Closed'),
      'import: the allowed values of the file win');
    LImporter.GetRelations(nil, LRelations);
    Check((LRelations.Count = 2) and
      (TRpLocalRelation(LRelations[1]).Context = 'From the Desktop'),
      'import: the relation of the database, described by the old Desktop');
    LRelations.Clear;
    Check(Joined(LSkipped) = 'SALES.DISCOUNT,GONE,PRODUCTS.PRICE',
      'import: what is not in the database is said: ' + Joined(LSkipped));
    Check(RpShortNameList(LSkipped, 2) = 'SALES.DISCOUNT, GONE, ' + {$IFDEF FPC}#$E2#$80#$A6{$ELSE}#$2026{$ENDIF},
      'import: a short list of what was not imported');
    Check(RpShortNameList(LSkipped, 5) = 'SALES.DISCOUNT, GONE, PRODUCTS.PRICE',
      'import: a short list, whole');

    // Without a name: the file name, without "_Config"
    LCount := RpImportSchemaJson(LImporter, '{"name":"","schemaTables":[{"name":"PRODUCTS"}]}',
      'C:\exports\Compras_Config.json', LName, LSkipped);
    Check((LCount = 1) and (LName = 'Compras'), 'import: without a name, the file name: ' + LName);
    LCount := RpImportSchemaJson(LImporter, '{"schemaTables":[]}', 'ventas_config.JSON',
      LName, LSkipped);
    Check((LCount = 0) and (LName = 'ventas 4'), 'import: without a name, numbered: ' + LName);

    // Not a schema
    LSchemas := LImporter.SchemaCount;
    Check((RpImportSchemaJson(LImporter, '{"tables":[]}', 'x.json', LName, LSkipped) = -1) and
      (RpImportSchemaJson(LImporter, 'not json', 'x.json', LName, LSkipped) = -1) and
      (RpImportSchemaJson(LImporter, '[{"name":"SALES"}]', 'x.json', LName, LSkipped) = -1) and
      (RpImportSchemaJson(LImporter, '{"name":"X","schemaTables":{}}', 'x.json', LName, LSkipped) = -1) and
      (LImporter.SchemaCount = LSchemas) and (LName = ''),
      'import: a file that is not a schema is refused, nothing changes');
  finally
    LRelations.Free;
    LSkipped.Free;
    LLabels.Free;
    LValues.Free;
    LList.Free;
    LImporter.Free;
    LExporter.Free;
  end;
end;

// F8 (docs/esquemas-locales-pantalla-plan.md 5.7): what goes to the AI is a
// subschema, never the dictionary; and the import from the library of
// Reportman AI is the import of a file named after the library schema
procedure TestOnlySubschemas(const AFixture: string);
var
  LConfig: TRpApiDatabaseConfig;
  LDatabases: TRpDatabaseInfoList;
  LFile: TRpLocalSchemaFile;
  LSkipped: TStringList;
  LTables, LSent: TJSONValue;
  LJson, LMessage, LName: string;
  LCount, LSchemas: Integer;
  LRaised: Boolean;
begin
  LFile := TRpLocalSchemaFile.Create;
  LSkipped := TStringList.Create;
  try
    LFile.LoadFromFile(AFixture);
    // A subschema: its tables, spelled as the file
    LJson := RpSubSchemaTablesJson(LFile, 'FBEXAMPLE', 'ventas', LName);
    LTables := TJSONObject.ParseJSONValue(LJson);
    LSent := SchemaTablesOf(LFile, 'Ventas');
    try
      Check((LName = 'Ventas') and SameJson(LTables, LSent) and
        (Names(TJSONArray(LTables)) = 'CUSTOMERS,SALES'),
        'to the AI: the tables of the subschema, as the file spells it');
    finally
      LSent.Free;
      LTables.Free;
    end;
    // No subschema, or one gone from the file: nothing, never all the tables
    LRaised := False;
    LMessage := '';
    try
      RpSubSchemaTablesJson(LFile, 'FBEXAMPLE', '', LName);
    except
      on E: Exception do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    Check(LRaised and (LMessage = RpSubSchemaRequiredMessage('FBEXAMPLE')) and
      (Pos('FBEXAMPLE', LMessage) > 0),
      'to the AI: without a subschema it asks for one (1984): ' + LMessage);
    LRaised := False;
    try
      RpSubSchemaTablesJson(LFile, 'FBEXAMPLE', 'Gone', LName);
    except
      on E: Exception do
        LRaised := E.Message = RpSubSchemaRequiredMessage('FBEXAMPLE');
    end;
    Check(LRaised, 'to the AI: a subschema gone from the file is not all the tables');

    // The resolver of the copilot and of the SQL dialog: an empty subschema
    // raises before reading anything (no database here)
    LDatabases := TRpDatabaseInfoList.Create(nil);
    LConfig := TRpApiDatabaseConfig.Create;
    try
      LDatabases.Add('FBEXAMPLE');
      LConfig.LocalAlias := 'FBEXAMPLE';
      LConfig.LocalSchemaName := '';
      LRaised := False;
      LMessage := '';
      try
        RpResolveLocalSchemaConfig(LConfig, LDatabases.Items[0], nil);
      except
        on E: Exception do
        begin
          LRaised := True;
          LMessage := E.Message;
        end;
      end;
      Check(LRaised and (LMessage = RpSubSchemaRequiredMessage('FBEXAMPLE')) and
        not LConfig.HasInlineSchema,
        'resolver: no subschema, no inline schema (1984): ' + LMessage);
    finally
      LConfig.Free;
      LDatabases.Free;
    end;

    // The library: a DatabaseConfig of the web (PascalCase), named after the
    // schema of the library, not after the "name" of the JSON
    LJson := '{"Name":"Config of the web","SchemaTables":[' +
      '{"Name":"sales","Columns":[{"Name":"SALEID"},{"Name":"TOTAL"}]},' +
      '{"Name":"GONE"}]}';
    LCount := RpImportLibrarySchemaJson(LFile, LJson, 'Library sales', LName, LSkipped);
    Check((LCount = 1) and (LName = 'Library sales') and
      (LFile.Schemas[LFile.IndexOfSchema(LName)].Tables.CommaText = 'SALES') and
      (LSkipped.CommaText = 'GONE'),
      'library: the import of a file, named after the library schema: ' + LName);
    LCount := RpImportLibrarySchemaJson(LFile, LJson, 'Library sales', LName, LSkipped);
    Check((LCount = 1) and (LName = 'Library sales 2'),
      'library: imported again, "name 2": ' + LName);
    LCount := RpImportLibrarySchemaJson(LFile, '[{"name":"PRODUCTS"}]', 'Products',
      LName, LSkipped);
    Check((LCount = 1) and (LName = 'Products'),
      'library: the bare array of the tables is a schema too');
    LSchemas := LFile.SchemaCount;
    Check((RpImportLibrarySchemaJson(LFile, '{"tables":[]}', 'X', LName, LSkipped) = -1) and
      (RpImportLibrarySchemaJson(LFile, 'not json', 'X', LName, LSkipped) = -1) and
      (LFile.SchemaCount = LSchemas),
      'library: what is not a schema is refused, nothing changes');
  finally
    LSkipped.Free;
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
    TestManualDeclaredLater;
    TestScreens(LFixture);
    TestSuggestions(LFixture);
    TestAnalyzeRequest(LFixture);
    TestExportImport(LFixture, ExtractFilePath(LSaved));
    TestOnlySubschemas(LFixture);
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

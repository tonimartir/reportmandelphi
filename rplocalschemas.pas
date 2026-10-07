{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rplocalschemas                                  }
{                                                       }
{       The schema of a direct connection for the AI:   }
{       dbxschemas/<ALIAS>.json next to the             }
{       connections file (dbxconnections.ini)           }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rplocalschemas;

(* The AI of the designer writes SQL for a database it knows by its schema.
  A Hub database is described on the web; a direct connection of the
  designer (FireDAC, Zeos, IBX, ADO, dbExpress...) by a file of this
  computer, shared by the Delphi, C# and web designers:

    <folder of dbxconnections.ini>/dbxschemas/<ALIAS>.json

  {
    "version": 1, "alias": "FBEXAMPLE", "dialect": "Firebird5",
    "generatedUtc": "2026-10-08T01:00:00Z",
    "tables": [ { "name", "context", "columns": [ { "name", "dataType",
      "context", "isPrimaryKey", "detectedType" } ], "foreignKeys": [
      { "constraintName", "targetTable", "sourceColumns", "targetColumns",
      "relationshipContext" } ] } ],
    "schemas": [ { "name": "Sales", "description": "", "tables": [...] } ]
  }

  - "tables" is the JSON of the SchemaTable of the Hub and the Desktop, so it
    travels as it is in the inline config of the cloud (schemaTables);
    dataType is one of the cloud's ColumnDataType names (Integer, Numeric,
    Currency, String, TextLong, Date, TimeStamp, Boolean).
  - "All" is not saved: it is every table. "schemas" are the subschemas the
    user defines (a name and a selection of tables).
  - It is generated from the catalog the first time it is needed. A refresh
    reads the catalog again and keeps the context written for the tables,
    columns and foreign keys that still exist, and the subschemas (without
    the tables that are gone). *)

interface

{$I rpconf.inc}

uses
{$IFDEF FPC}
  SysUtils, Classes, Contnrs, DB, Variants, DateUtils, rpjsonfpc,
{$ELSE}
  SysUtils, Classes, Contnrs, DB, Variants, System.JSON, System.DateUtils,
{$ENDIF}
  rpparams, rpdatainfo;

const
  RP_LOCAL_SCHEMA_FOLDER = 'dbxschemas';
  RP_LOCAL_SCHEMA_VERSION = 1;

type
  TRpLocalSubSchema = class(TObject)
  private
    FDescription: string;
    FName: string;
    FTables: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    property Description: string read FDescription write FDescription;
    property Name: string read FName write FName;
    property Tables: TStringList read FTables;
  end;

  TRpLocalSchemaFile = class(TObject)
  private
    FAlias: string;
    FDialect: string;
    FFileName: string;
    FGeneratedUtc: string;
    FSchemas: TObjectList;
    FTables: TJSONArray;
    function GetSchema(Index: Integer): TRpLocalSubSchema;
    function GetSchemaCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromJson(const AText: string);
    function ToJsonText: string;
    // False when the file does not exist
    function LoadFromFile(const AFileName: string): Boolean;
    procedure SaveToFile(const AFileName: string);
    // The tables read from the catalog (owned from now on): the context of
    // what still exists is kept and the subschemas lose the tables that are
    // gone
    procedure SetCatalog(ATables: TJSONArray; const ADialect: string);
    procedure GetTableNames(AList: TStrings);
    function TableCount: Integer;
    function IndexOfSchema(const AName: string): Integer;
    function AddSchema(const AName: string): TRpLocalSubSchema;
    procedure DeleteSchema(AIndex: Integer);
    // The JSON array of the tables of a subschema ('' or an unknown one:
    // all the tables), the schemaTables of the inline config
    function SchemaTablesJson(const ASchemaName: string): string;
    property Alias: string read FAlias write FAlias;
    property Dialect: string read FDialect write FDialect;
    property FileName: string read FFileName;
    property GeneratedUtc: string read FGeneratedUtc;
    property SchemaCount: Integer read GetSchemaCount;
    property Schemas[Index: Integer]: TRpLocalSubSchema read GetSchema;
    property Tables: TJSONArray read FTables;
  end;

// A connection whose SQL this computer runs (not the Reportman AI Agent,
// MyBase files or the .Net drivers)
function RpIsLocalSqlDatabase(ADatabase: TRpDatabaseInfoItem): Boolean;
// dbxschemas/<ALIAS>.json in the folder of the connections file the
// connection reads (the DBXCONNECTIONS parameter of the report included)
function RpLocalSchemaFileName(ADatabase: TRpDatabaseInfoItem): string;
// The cloud's DatabaseDialect name of the connection (Firebird5,
// PostgreSQL...; Default when unknown), from its parameters only
function RpLocalDatabaseDialect(ADatabase: TRpDatabaseInfoItem): string;
// The tables, columns, primary keys and foreign keys of the catalog of the
// connection, in the format of the file (connects the connection)
function RpReadLocalSchemaCatalog(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; out ADialect: string): TJSONArray;
// The schema file of the connection: read; generated from the catalog
// (and saved) when it does not exist and AGenerate, or always with
// ARefresh. nil when it does not exist and is not generated
function RpLoadLocalSchema(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; AGenerate, ARefresh: Boolean): TRpLocalSchemaFile;
// The names of the subschemas of the file of a connection, without
// generating it
procedure RpListLocalSubSchemas(ADatabase: TRpDatabaseInfoItem; AList: TStrings);
// A copy of the connection in a list of its own (the caller frees it) that
// reads the same connections file: it can be connected without touching the
// connection of the report (the designer may be opening its datasets)
function RpCopyDatabaseInfo(ADatabase: TRpDatabaseInfoItem): TRpDatabaseInfoList;

implementation

type
  TRpCatalogFamily = (rcfGeneric, rcfFirebird, rcfPostgreSQL, rcfMySQL,
    rcfSQLServer, rcfSQLite, rcfOracle);

  TRpCatColumn = class(TObject)
  public
    Name: string;
    DataType: string;
    DetectedType: string;
    Context: string;
    IsPrimaryKey: Boolean;
  end;

  TRpCatForeignKey = class(TObject)
  public
    ConstraintName: string;
    TargetTable: string;
    SourceColumns: TStringList;
    TargetColumns: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TRpCatTable = class(TObject)
  public
    Name: string;
    Context: string;
    Columns: TObjectList;
    ForeignKeys: TObjectList;
    constructor Create;
    destructor Destroy; override;
    function FindColumn(const AName: string): TRpCatColumn;
    function AddColumn(const AName: string): TRpCatColumn;
  end;

  // The tables of the catalog by name (sorted, case insensitive)
  TRpCatalog = class(TObject)
  private
    FList: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function Find(const AName: string): TRpCatTable;
    function Add(const AName: string): TRpCatTable;
    function ToJsonArray: TJSONArray;
    property List: TStringList read FList;
  end;

{ Helpers }

function JStr(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject.Values[AName];
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function JArr(AObject: TJSONObject; const AName: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  LValue := AObject.Values[AName];
  if (LValue <> nil) and (LValue is TJSONArray) then
    Result := TJSONArray(LValue);
end;

function JObj(AArray: TJSONArray; AIndex: Integer): TJSONObject;
begin
  Result := nil;
  if (AArray <> nil) and (AIndex >= 0) and (AIndex < AArray.Count) and
    (AArray.Items[AIndex] is TJSONObject) then
    Result := TJSONObject(AArray.Items[AIndex]);
end;

function FindByName(AArray: TJSONArray; const AProperty, AName: string): TJSONObject;
var
  I: Integer;
  LObject: TJSONObject;
begin
  Result := nil;
  if AArray = nil then
    Exit;
  for I := 0 to AArray.Count - 1 do
  begin
    LObject := JObj(AArray, I);
    if (LObject <> nil) and SameText(JStr(LObject, AProperty), AName) then
      Exit(LObject);
  end;
end;

// The value of a property, replaced (the JSON library has no SetValue)
procedure SetPair(AObject: TJSONObject; const AName: string; AValue: TJSONValue);
var
  LOld: TJSONPair;
begin
  LOld := AObject.RemovePair(AName);
  LOld.Free;
  AObject.AddPair(AName, AValue);
end;

// The properties of the old object the new one does not have (the ones
// someone added to the file: allowed values...), and its context when it was
// written
procedure KeepWritten(AOld, ANew: TJSONObject; const AContextName: string;
  const ASkip: array of string);
var
  I, J: Integer;
  LName: string;
  LPair: TJSONPair;
  LSkip: Boolean;
begin
  if (AOld = nil) or (ANew = nil) then
    Exit;
  if (AContextName <> '') and (Trim(JStr(AOld, AContextName)) <> '') then
    SetPair(ANew, AContextName, TJSONString.Create(JStr(AOld, AContextName)));
  for I := 0 to AOld.Count - 1 do
  begin
    LPair := AOld.Pairs[I];
    LName := LPair.JsonString.Value;
    LSkip := SameText(LName, AContextName);
    for J := Low(ASkip) to High(ASkip) do
      if SameText(LName, ASkip[J]) then
        LSkip := True;
    if LSkip or (ANew.Values[LName] <> nil) then
      Continue;
    ANew.AddPair(LName, TJSONValue(LPair.JsonValue.Clone));
  end;
end;

function ReadUtf8File(const AFileName: string): string;
var
  LBytes: TBytes;
  LStart: Integer;
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, LStream.Size);
    if Length(LBytes) > 0 then
      LStream.ReadBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
  LStart := 0;
  if (Length(LBytes) >= 3) and (LBytes[0] = $EF) and (LBytes[1] = $BB) and
    (LBytes[2] = $BF) then
    LStart := 3;
{$IFDEF FPC}
  // Lazarus strings are UTF-8
  SetLength(Result, Length(LBytes) - LStart);
  if Length(Result) > 0 then
    Move(LBytes[LStart], Result[1], Length(Result));
{$ELSE}
  Result := TEncoding.UTF8.GetString(LBytes, LStart, Length(LBytes) - LStart);
{$ENDIF}
end;

procedure WriteUtf8File(const AFileName, AText: string);
var
  LBytes: TBytes;
  LStream: TFileStream;
  LTemp: string;
begin
{$IFDEF FPC}
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], LBytes[0], Length(AText));
{$ELSE}
  LBytes := TEncoding.UTF8.GetBytes(AText);
{$ENDIF}
  // Written aside and renamed: a reader never sees half a file
  LTemp := AFileName + '.tmp';
  LStream := TFileStream.Create(LTemp, fmCreate);
  try
    if Length(LBytes) > 0 then
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
  if FileExists(AFileName) and not DeleteFile(AFileName) then
  begin
    DeleteFile(LTemp);
    raise Exception.Create('The schema file can not be written: ' + AFileName);
  end;
  if not RenameFile(LTemp, AFileName) then
    raise Exception.Create('The schema file can not be written: ' + AFileName);
end;

function NowUtcIso: string;
var
  LNow: TDateTime;
begin
{$IFDEF FPC}
  LNow := LocalTimeToUniversal(Now);
{$ELSE}
  LNow := TTimeZone.Local.ToUniversalTime(Now);
{$ENDIF}
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', LNow);
end;

function SafeFileName(const AAlias: string): string;
var
  I: Integer;
begin
  Result := UpperCase(Trim(AAlias));
  for I := 1 to Length(Result) do
    if CharInSet(Result[I], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      Result[I] := '_';
end;

{ TRpLocalSubSchema }

constructor TRpLocalSubSchema.Create;
begin
  inherited Create;
  FTables := TStringList.Create;
  FTables.CaseSensitive := False;
end;

destructor TRpLocalSubSchema.Destroy;
begin
  FTables.Free;
  inherited Destroy;
end;

{ TRpLocalSchemaFile }

constructor TRpLocalSchemaFile.Create;
begin
  inherited Create;
  FSchemas := TObjectList.Create(True);
  FTables := TJSONArray.Create;
end;

destructor TRpLocalSchemaFile.Destroy;
begin
  FSchemas.Free;
  FTables.Free;
  inherited Destroy;
end;

procedure TRpLocalSchemaFile.Clear;
begin
  FSchemas.Clear;
  FTables.Free;
  FTables := TJSONArray.Create;
  FAlias := '';
  FDialect := '';
  FGeneratedUtc := '';
end;

function TRpLocalSchemaFile.GetSchema(Index: Integer): TRpLocalSubSchema;
begin
  Result := TRpLocalSubSchema(FSchemas[Index]);
end;

function TRpLocalSchemaFile.GetSchemaCount: Integer;
begin
  Result := FSchemas.Count;
end;

procedure TRpLocalSchemaFile.LoadFromJson(const AText: string);
var
  I, J: Integer;
  LArray, LNames: TJSONArray;
  LRoot: TJSONValue;
  LObject: TJSONObject;
  LSchema: TRpLocalSubSchema;
begin
  Clear;
  LRoot := TJSONObject.ParseJSONValue(AText);
  try
    if not (LRoot is TJSONObject) then
      raise Exception.Create('The schema file is not a JSON object');
    LObject := TJSONObject(LRoot);
    FAlias := JStr(LObject, 'alias');
    FDialect := JStr(LObject, 'dialect');
    FGeneratedUtc := JStr(LObject, 'generatedUtc');
    LArray := JArr(LObject, 'tables');
    if LArray <> nil then
    begin
      FTables.Free;
      FTables := TJSONArray(LArray.Clone);
    end;
    LArray := JArr(LObject, 'schemas');
    if LArray <> nil then
      for I := 0 to LArray.Count - 1 do
      begin
        if JObj(LArray, I) = nil then
          Continue;
        LSchema := TRpLocalSubSchema.Create;
        FSchemas.Add(LSchema);
        LSchema.Name := JStr(JObj(LArray, I), 'name');
        LSchema.Description := JStr(JObj(LArray, I), 'description');
        LNames := JArr(JObj(LArray, I), 'tables');
        if LNames <> nil then
          for J := 0 to LNames.Count - 1 do
            if LNames.Items[J] <> nil then
              LSchema.Tables.Add(LNames.Items[J].Value);
      end;
  finally
    LRoot.Free;
  end;
end;

function TRpLocalSchemaFile.ToJsonText: string;
var
  I, J: Integer;
  LNames, LSchemas: TJSONArray;
  LRoot, LSchemaObject: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('version', TJSONNumber.Create(RP_LOCAL_SCHEMA_VERSION));
    LRoot.AddPair('alias', FAlias);
    LRoot.AddPair('dialect', FDialect);
    LRoot.AddPair('generatedUtc', FGeneratedUtc);
    LRoot.AddPair('tables', TJSONArray(FTables.Clone));
    LSchemas := TJSONArray.Create;
    LRoot.AddPair('schemas', LSchemas);
    for I := 0 to FSchemas.Count - 1 do
    begin
      LSchemaObject := TJSONObject.Create;
      LSchemas.AddElement(LSchemaObject);
      LSchemaObject.AddPair('name', Schemas[I].Name);
      LSchemaObject.AddPair('description', Schemas[I].Description);
      LNames := TJSONArray.Create;
      LSchemaObject.AddPair('tables', LNames);
      for J := 0 to Schemas[I].Tables.Count - 1 do
        LNames.Add(Schemas[I].Tables[J]);
    end;
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

function TRpLocalSchemaFile.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := FileExists(AFileName);
  if not Result then
    Exit;
  try
    LoadFromJson(ReadUtf8File(AFileName));
  except
    on E: Exception do
      raise Exception.Create(AFileName + ': ' + E.Message);
  end;
  FFileName := AFileName;
end;

procedure TRpLocalSchemaFile.SaveToFile(const AFileName: string);
var
  LFolder: string;
begin
  LFolder := ExtractFileDir(AFileName);
  if (LFolder <> '') and not DirectoryExists(LFolder) then
    if not ForceDirectories(LFolder) then
      raise Exception.Create('The folder can not be created: ' + LFolder);
  WriteUtf8File(AFileName, ToJsonText);
  FFileName := AFileName;
end;

procedure TRpLocalSchemaFile.SetCatalog(ATables: TJSONArray;
  const ADialect: string);
var
  I, J, K: Integer;
  LNewTable, LOldTable, LNewItem, LOldItem: TJSONObject;
  LNewItems, LOldItems: TJSONArray;
  LNames: TStringList;
begin
  if ATables = nil then
    ATables := TJSONArray.Create;
  try
    for I := 0 to ATables.Count - 1 do
    begin
      LNewTable := JObj(ATables, I);
      LOldTable := FindByName(FTables, 'name', JStr(LNewTable, 'name'));
      if (LNewTable = nil) or (LOldTable = nil) then
        Continue;
      KeepWritten(LOldTable, LNewTable, 'context', ['name', 'columns', 'foreignKeys']);
      LNewItems := JArr(LNewTable, 'columns');
      LOldItems := JArr(LOldTable, 'columns');
      if LNewItems <> nil then
        for J := 0 to LNewItems.Count - 1 do
        begin
          LNewItem := JObj(LNewItems, J);
          LOldItem := FindByName(LOldItems, 'name', JStr(LNewItem, 'name'));
          KeepWritten(LOldItem, LNewItem, 'context',
            ['name', 'dataType', 'isPrimaryKey', 'detectedType']);
        end;
      LNewItems := JArr(LNewTable, 'foreignKeys');
      LOldItems := JArr(LOldTable, 'foreignKeys');
      if LNewItems <> nil then
        for J := 0 to LNewItems.Count - 1 do
        begin
          LNewItem := JObj(LNewItems, J);
          LOldItem := FindByName(LOldItems, 'constraintName',
            JStr(LNewItem, 'constraintName'));
          KeepWritten(LOldItem, LNewItem, 'relationshipContext',
            ['constraintName', 'targetTable', 'sourceColumns', 'targetColumns']);
        end;
    end;
  except
    ATables.Free;
    raise;
  end;
  FTables.Free;
  FTables := ATables;
  if ADialect <> '' then
    FDialect := ADialect;
  FGeneratedUtc := NowUtcIso;
  // The subschemas keep the tables that still exist, as the catalog names them
  LNames := TStringList.Create;
  try
    GetTableNames(LNames);
    for I := 0 to FSchemas.Count - 1 do
      for J := Schemas[I].Tables.Count - 1 downto 0 do
      begin
        K := LNames.IndexOf(Schemas[I].Tables[J]);
        if K < 0 then
          Schemas[I].Tables.Delete(J)
        else
          Schemas[I].Tables[J] := LNames[K];
      end;
  finally
    LNames.Free;
  end;
end;

procedure TRpLocalSchemaFile.GetTableNames(AList: TStrings);
var
  I: Integer;
  LTable: TJSONObject;
begin
  AList.Clear;
  for I := 0 to FTables.Count - 1 do
  begin
    LTable := JObj(FTables, I);
    if (LTable <> nil) and (JStr(LTable, 'name') <> '') then
      AList.Add(JStr(LTable, 'name'));
  end;
end;

function TRpLocalSchemaFile.TableCount: Integer;
begin
  Result := FTables.Count;
end;

function TRpLocalSchemaFile.IndexOfSchema(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FSchemas.Count - 1 do
    if SameText(Schemas[I].Name, Trim(AName)) then
      Exit(I);
end;

function TRpLocalSchemaFile.AddSchema(const AName: string): TRpLocalSubSchema;
begin
  if Trim(AName) = '' then
    raise Exception.Create('A subschema needs a name');
  if IndexOfSchema(AName) >= 0 then
    raise Exception.Create('The subschema already exists: ' + AName);
  Result := TRpLocalSubSchema.Create;
  Result.Name := Trim(AName);
  FSchemas.Add(Result);
end;

procedure TRpLocalSchemaFile.DeleteSchema(AIndex: Integer);
begin
  FSchemas.Delete(AIndex);
end;

function TRpLocalSchemaFile.SchemaTablesJson(const ASchemaName: string): string;
var
  I, LIndex: Integer;
  LArray: TJSONArray;
  LTable: TJSONObject;
begin
  LIndex := -1;
  if Trim(ASchemaName) <> '' then
    LIndex := IndexOfSchema(ASchemaName);
  if LIndex < 0 then
  begin
    Result := FTables.ToJSON;
    Exit;
  end;
  LArray := TJSONArray.Create;
  try
    for I := 0 to FTables.Count - 1 do
    begin
      LTable := JObj(FTables, I);
      if (LTable <> nil) and
        (Schemas[LIndex].Tables.IndexOf(JStr(LTable, 'name')) >= 0) then
        LArray.AddElement(TJSONObject(LTable.Clone));
    end;
    Result := LArray.ToJSON;
  finally
    LArray.Free;
  end;
end;

{ Catalog model }

constructor TRpCatForeignKey.Create;
begin
  inherited Create;
  SourceColumns := TStringList.Create;
  TargetColumns := TStringList.Create;
end;

destructor TRpCatForeignKey.Destroy;
begin
  SourceColumns.Free;
  TargetColumns.Free;
  inherited Destroy;
end;

constructor TRpCatTable.Create;
begin
  inherited Create;
  Columns := TObjectList.Create(True);
  ForeignKeys := TObjectList.Create(True);
end;

destructor TRpCatTable.Destroy;
begin
  Columns.Free;
  ForeignKeys.Free;
  inherited Destroy;
end;

function TRpCatTable.FindColumn(const AName: string): TRpCatColumn;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Columns.Count - 1 do
    if SameText(TRpCatColumn(Columns[I]).Name, AName) then
      Exit(TRpCatColumn(Columns[I]));
end;

function TRpCatTable.AddColumn(const AName: string): TRpCatColumn;
begin
  Result := FindColumn(AName);
  if Result <> nil then
    Exit;
  Result := TRpCatColumn.Create;
  Result.Name := AName;
  Result.DataType := 'String';
  Columns.Add(Result);
end;

constructor TRpCatalog.Create;
begin
  inherited Create;
  FList := TStringList.Create;
  FList.CaseSensitive := False;
  FList.Sorted := True;
  FList.Duplicates := dupIgnore;
  FList.OwnsObjects := True;
end;

destructor TRpCatalog.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TRpCatalog.Find(const AName: string): TRpCatTable;
var
  LIndex: Integer;
begin
  Result := nil;
  if FList.Find(AName, LIndex) then
    Result := TRpCatTable(FList.Objects[LIndex]);
end;

function TRpCatalog.Add(const AName: string): TRpCatTable;
begin
  Result := Find(AName);
  if Result <> nil then
    Exit;
  Result := TRpCatTable.Create;
  Result.Name := AName;
  FList.AddObject(AName, Result);
end;

function TRpCatalog.ToJsonArray: TJSONArray;
var
  I, J, K: Integer;
  LColumn: TRpCatColumn;
  LColumns, LForeignKeys, LNames: TJSONArray;
  LForeignKey: TRpCatForeignKey;
  LItem, LTableObject: TJSONObject;
  LTable: TRpCatTable;
begin
  Result := TJSONArray.Create;
  for I := 0 to FList.Count - 1 do
  begin
    LTable := TRpCatTable(FList.Objects[I]);
    LTableObject := TJSONObject.Create;
    Result.AddElement(LTableObject);
    LTableObject.AddPair('name', LTable.Name);
    LTableObject.AddPair('context', LTable.Context);
    LColumns := TJSONArray.Create;
    LTableObject.AddPair('columns', LColumns);
    for J := 0 to LTable.Columns.Count - 1 do
    begin
      LColumn := TRpCatColumn(LTable.Columns[J]);
      LItem := TJSONObject.Create;
      LColumns.AddElement(LItem);
      LItem.AddPair('name', LColumn.Name);
      LItem.AddPair('dataType', LColumn.DataType);
      LItem.AddPair('context', LColumn.Context);
      LItem.AddPair('isPrimaryKey', TJSONBool.Create(LColumn.IsPrimaryKey));
      LItem.AddPair('detectedType', LColumn.DetectedType);
    end;
    LForeignKeys := TJSONArray.Create;
    LTableObject.AddPair('foreignKeys', LForeignKeys);
    for J := 0 to LTable.ForeignKeys.Count - 1 do
    begin
      LForeignKey := TRpCatForeignKey(LTable.ForeignKeys[J]);
      LItem := TJSONObject.Create;
      LForeignKeys.AddElement(LItem);
      LItem.AddPair('constraintName', LForeignKey.ConstraintName);
      LItem.AddPair('targetTable', LForeignKey.TargetTable);
      LNames := TJSONArray.Create;
      LItem.AddPair('sourceColumns', LNames);
      for K := 0 to LForeignKey.SourceColumns.Count - 1 do
        LNames.Add(LForeignKey.SourceColumns[K]);
      LNames := TJSONArray.Create;
      LItem.AddPair('targetColumns', LNames);
      for K := 0 to LForeignKey.TargetColumns.Count - 1 do
        LNames.Add(LForeignKey.TargetColumns[K]);
      LItem.AddPair('relationshipContext', '');
    end;
  end;
end;

{ Connection }

function RpIsLocalSqlDatabase(ADatabase: TRpDatabaseInfoItem): Boolean;
begin
  Result := (ADatabase <> nil) and (ADatabase.Driver in [rpdatadbexpress,
    rpdataibx, rpdatabde, rpdataado, rpdataibo, rpdatazeos, rpfiredac]);
end;

function RpLocalSchemaFileName(ADatabase: TRpDatabaseInfoItem): string;
var
  LFolder: string;
begin
  Result := '';
  if ADatabase = nil then
    Exit;
  if not Assigned(ADatabase.ConAdmin) then
    ADatabase.UpdateConAdmin;
  LFolder := ExtractFilePath(ExpandFileName(ADatabase.ConAdmin.configfilename));
  Result := IncludeTrailingPathDelimiter(LFolder + RP_LOCAL_SCHEMA_FOLDER) +
    SafeFileName(ADatabase.Alias) + '.json';
end;

procedure GetDatabaseParams(ADatabase: TRpDatabaseInfoItem; AParams: TStrings);
begin
  AParams.Clear;
  if ADatabase.LoadParams then
  begin
    try
      ADatabase.LoadConnectionParams(AParams);
    except
      AParams.Clear;
    end;
  end;
end;

function ParamValue(AParams: TStrings; const ANames: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(ANames) to High(ANames) do
  begin
    Result := Trim(AParams.Values[ANames[I]]);
    if Result <> '' then
      Exit;
  end;
end;

function Contains(const AText, APart: string): Boolean;
begin
  Result := Pos(LowerCase(APart), LowerCase(AText)) > 0;
end;

function FamilyOf(ADatabase: TRpDatabaseInfoItem): TRpCatalogFamily;
var
  LParams: TStringList;
  LText: string;
begin
  Result := rcfGeneric;
  if ADatabase = nil then
    Exit;
  LParams := TStringList.Create;
  try
    GetDatabaseParams(ADatabase, LParams);
    case ADatabase.Driver of
      rpdataibx, rpdataibo:
        Result := rcfFirebird;
      rpfiredac:
        begin
          LText := UpperCase(ParamValue(LParams, ['DriverID', 'DriverName']));
          if (LText = 'FB') or (LText = 'IB') or (LText = 'IBLITE') or
            (LText = 'FIREBIRD') or (LText = 'INTERBASE') then
            Result := rcfFirebird
          else if (LText = 'PG') or (LText = 'POSTGRESQL') then
            Result := rcfPostgreSQL
          else if (LText = 'MYSQL') or (LText = 'MARIADB') then
            Result := rcfMySQL
          else if (LText = 'MSSQL') then
            Result := rcfSQLServer
          else if (LText = 'SQLITE') then
            Result := rcfSQLite
          else if (LText = 'ORA') or (LText = 'ORACLE') then
            Result := rcfOracle;
        end;
      rpdatazeos:
        begin
          LText := ParamValue(LParams, ['Database Protocol', 'Protocol']);
          if Contains(LText, 'firebird') or Contains(LText, 'interbase') then
            Result := rcfFirebird
          else if Contains(LText, 'postgres') then
            Result := rcfPostgreSQL
          else if Contains(LText, 'mysql') or Contains(LText, 'mariadb') then
            Result := rcfMySQL
          else if Contains(LText, 'sqlite') then
            Result := rcfSQLite
          else if Contains(LText, 'mssql') or Contains(LText, 'freetds') then
            Result := rcfSQLServer
          else if Contains(LText, 'oracle') then
            Result := rcfOracle;
        end;
      rpdatadbexpress:
        begin
          LText := ParamValue(LParams, ['DriverName']);
          if Contains(LText, 'interbase') or Contains(LText, 'firebird') then
            Result := rcfFirebird
          else if Contains(LText, 'mssql') then
            Result := rcfSQLServer
          else if Contains(LText, 'mysql') then
            Result := rcfMySQL
          else if Contains(LText, 'oracle') then
            Result := rcfOracle
          else if Contains(LText, 'sqlite') then
            Result := rcfSQLite;
        end;
      rpdataado:
        begin
          LText := string(ADatabase.ADOConnectionString) + ';' +
            ParamValue(LParams, ['ConnectionString', 'ADOConnectionString']);
          if Contains(LText, 'sqloledb') or Contains(LText, 'msoledbsql') or
            Contains(LText, 'sqlncli') then
            Result := rcfSQLServer
          else if Contains(LText, 'oraoledb') or Contains(LText, 'msdaora') then
            Result := rcfOracle
          else if Contains(LText, 'ibprovider') or Contains(LText, 'firebird') then
            Result := rcfFirebird
          else if Contains(LText, 'mysql') then
            Result := rcfMySQL
          else if Contains(LText, 'postgres') then
            Result := rcfPostgreSQL;
        end;
    end;
  finally
    LParams.Free;
  end;
end;

function DialectOfFamily(AFamily: TRpCatalogFamily): string;
begin
  case AFamily of
    rcfFirebird:
      Result := 'Firebird5';
    rcfPostgreSQL:
      Result := 'PostgreSQL';
    rcfMySQL:
      Result := 'MySQL';
    rcfSQLServer:
      Result := 'SQLServer';
    rcfSQLite:
      Result := 'SQLite';
    rcfOracle:
      Result := 'Oracle';
  else
    Result := 'Default';
  end;
end;

function RpLocalDatabaseDialect(ADatabase: TRpDatabaseInfoItem): string;
begin
  Result := DialectOfFamily(FamilyOf(ADatabase));
end;

{ Catalog reading }

type
  TRpCatalogReader = class(TObject)
  private
    FCatalog: TRpCatalog;
    FDatabase: TRpDatabaseInfoItem;
    FFamily: TRpCatalogFamily;
    FParams: TRpParamList;
    function Open(const ASql: string): TDataSet;
    function FieldText(AData: TDataSet; AIndex: Integer): string;
    function FieldInt(AData: TDataSet; AIndex: Integer): Integer;
    procedure AddForeignKey(const ATable, AConstraint, ATarget, ASource,
      ATargetColumn: string);
    procedure SetPrimaryKey(const ATable, AColumn: string);
    function FirebirdDialect: string;
    procedure ReadFirebird;
    procedure ReadInformationSchema;
    procedure ReadSQLite;
    procedure ReadOracle;
    procedure ReadGeneric;
  public
    constructor Create(ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList);
    destructor Destroy; override;
    function Read(out ADialect: string): TJSONArray;
  end;

constructor TRpCatalogReader.Create(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList);
begin
  inherited Create;
  FDatabase := ADatabase;
  FParams := AParams;
  FCatalog := TRpCatalog.Create;
end;

destructor TRpCatalogReader.Destroy;
begin
  FCatalog.Free;
  inherited Destroy;
end;

function TRpCatalogReader.Open(const ASql: string): TDataSet;
begin
  Result := FDatabase.OpenDatasetFromSQL(ASql, nil, False, FParams);
end;

function TRpCatalogReader.FieldText(AData: TDataSet; AIndex: Integer): string;
begin
  Result := '';
  if (AIndex < AData.FieldCount) and not AData.Fields[AIndex].IsNull then
    Result := Trim(AData.Fields[AIndex].AsString);
end;

function TRpCatalogReader.FieldInt(AData: TDataSet; AIndex: Integer): Integer;
begin
  Result := StrToIntDef(FieldText(AData, AIndex), 0);
end;

procedure TRpCatalogReader.SetPrimaryKey(const ATable, AColumn: string);
var
  LColumn: TRpCatColumn;
  LTable: TRpCatTable;
begin
  LTable := FCatalog.Find(ATable);
  if LTable = nil then
    Exit;
  LColumn := LTable.FindColumn(AColumn);
  if LColumn <> nil then
    LColumn.IsPrimaryKey := True;
end;

procedure TRpCatalogReader.AddForeignKey(const ATable, AConstraint, ATarget,
  ASource, ATargetColumn: string);
var
  I: Integer;
  LForeignKey: TRpCatForeignKey;
  LTable: TRpCatTable;
begin
  LTable := FCatalog.Find(ATable);
  if LTable = nil then
    Exit;
  LForeignKey := nil;
  for I := 0 to LTable.ForeignKeys.Count - 1 do
    if SameText(TRpCatForeignKey(LTable.ForeignKeys[I]).ConstraintName, AConstraint) then
      LForeignKey := TRpCatForeignKey(LTable.ForeignKeys[I]);
  if LForeignKey = nil then
  begin
    LForeignKey := TRpCatForeignKey.Create;
    LForeignKey.ConstraintName := AConstraint;
    LForeignKey.TargetTable := ATarget;
    LTable.ForeignKeys.Add(LForeignKey);
  end;
  LForeignKey.SourceColumns.Add(ASource);
  LForeignKey.TargetColumns.Add(ATargetColumn);
end;

// The cloud's type of a SQL type name (information schema, Oracle, SQLite)
function CloudTypeOfSqlType(const ATypeName: string; AScale: Integer): string;
var
  LType: string;
begin
  LType := LowerCase(Trim(ATypeName));
  if (Pos('int', LType) > 0) or (LType = 'serial') or (LType = 'bigserial') or
    (LType = 'smallserial') then
    Result := 'Integer'
  else if (LType = 'number') then
  begin
    if AScale = 0 then
      Result := 'Integer'
    else
      Result := 'Numeric';
  end
  else if (Pos('money', LType) > 0) then
    Result := 'Currency'
  else if (Pos('numeric', LType) > 0) or (Pos('decimal', LType) > 0) or
    (Pos('float', LType) > 0) or (Pos('double', LType) > 0) or
    (Pos('real', LType) > 0) or (Pos('binary_', LType) > 0) then
    Result := 'Numeric'
  else if (LType = 'date') then
    Result := 'Date'
  else if (Pos('time', LType) > 0) or (Pos('datetime', LType) > 0) then
    Result := 'TimeStamp'
  else if (Pos('bool', LType) > 0) or (LType = 'bit') then
    Result := 'Boolean'
  else if (Pos('text', LType) > 0) or (Pos('clob', LType) > 0) then
    Result := 'TextLong'
  else
    Result := 'String';
end;

function SqlTypeText(const ATypeName: string; ALength, APrecision,
  AScale: Integer): string;
begin
  Result := UpperCase(ATypeName);
  if ALength > 0 then
    Result := Result + '(' + IntToStr(ALength) + ')'
  else if (APrecision > 0) and (AScale > 0) then
    Result := Result + '(' + IntToStr(APrecision) + ',' + IntToStr(AScale) + ')';
end;

function TRpCatalogReader.FirebirdDialect: string;
var
  LData: TDataSet;
  LVersion: string;
begin
  // "5.0.1": the major version, as the web designer (Firebird 3 has the
  // syntax of Firebird2 for the AI)
  Result := 'Firebird5';
  try
    LData := Open('SELECT RDB$GET_CONTEXT(''SYSTEM'', ''ENGINE_VERSION'') FROM RDB$DATABASE');
    try
      LVersion := FieldText(LData, 0);
    finally
      LData.Free;
    end;
  except
    // Before Firebird 2.1
    Exit('Firebird1');
  end;
  if LVersion = '' then
    Exit;
  case LVersion[1] of
    '1':
      Result := 'Firebird1';
    '2', '3':
      Result := 'Firebird2';
    '4':
      Result := 'Firebird4';
  else
    Result := 'Firebird5';
  end;
end;

// Firebird RDB$FIELD_TYPE codes
procedure FirebirdColumnType(AType, ASubType, ALength, APrecision, AScale,
  ACharLength: Integer; out ACloudType, ADetected: string);
begin
  ACloudType := 'String';
  case AType of
    7, 8, 16, 26:
      begin
        if AScale < 0 then
        begin
          ACloudType := 'Numeric';
          if ASubType = 2 then
            ADetected := 'DECIMAL'
          else
            ADetected := 'NUMERIC';
          ADetected := ADetected + '(' + IntToStr(APrecision) + ',' +
            IntToStr(-AScale) + ')';
        end
        else
        begin
          ACloudType := 'Integer';
          case AType of
            7: ADetected := 'SMALLINT';
            8: ADetected := 'INTEGER';
            26: ADetected := 'INT128';
          else
            ADetected := 'BIGINT';
          end;
        end;
      end;
    10:
      begin
        ACloudType := 'Numeric';
        ADetected := 'FLOAT';
      end;
    27:
      begin
        ACloudType := 'Numeric';
        ADetected := 'DOUBLE PRECISION';
      end;
    24, 25:
      begin
        ACloudType := 'Numeric';
        ADetected := 'DECFLOAT';
      end;
    12:
      begin
        ACloudType := 'Date';
        ADetected := 'DATE';
      end;
    13, 28:
      begin
        ACloudType := 'TimeStamp';
        ADetected := 'TIME';
      end;
    35, 29:
      begin
        ACloudType := 'TimeStamp';
        ADetected := 'TIMESTAMP';
      end;
    14:
      ADetected := 'CHAR(' + IntToStr(ACharLength) + ')';
    37:
      ADetected := 'VARCHAR(' + IntToStr(ACharLength) + ')';
    23:
      begin
        ACloudType := 'Boolean';
        ADetected := 'BOOLEAN';
      end;
    261:
      begin
        if ASubType = 1 then
        begin
          ACloudType := 'TextLong';
          ADetected := 'BLOB SUB_TYPE TEXT';
        end
        else
          ADetected := 'BLOB';
      end;
  else
    ADetected := 'TYPE ' + IntToStr(AType);
  end;
  if ((AType = 14) or (AType = 37)) and (ACharLength <= 0) then
    ADetected := Copy(ADetected, 1, Pos('(', ADetected) - 1) + '(' +
      IntToStr(ALength) + ')';
end;

procedure TRpCatalogReader.ReadFirebird;
var
  LColumn: TRpCatColumn;
  LCloudType, LDetected: string;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  LData := Open('SELECT TRIM(R.RDB$RELATION_NAME), R.RDB$DESCRIPTION ' +
    'FROM RDB$RELATIONS R WHERE COALESCE(R.RDB$SYSTEM_FLAG, 0) = 0 ' +
    'ORDER BY R.RDB$RELATION_NAME');
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0)).Context := FieldText(LData, 1);
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  LData := Open('SELECT TRIM(RF.RDB$RELATION_NAME), TRIM(RF.RDB$FIELD_NAME), ' +
    'F.RDB$FIELD_TYPE, F.RDB$FIELD_SUB_TYPE, F.RDB$FIELD_LENGTH, ' +
    'F.RDB$FIELD_PRECISION, F.RDB$FIELD_SCALE, F.RDB$CHARACTER_LENGTH, ' +
    'RF.RDB$DESCRIPTION ' +
    'FROM RDB$RELATION_FIELDS RF ' +
    'JOIN RDB$RELATIONS R ON R.RDB$RELATION_NAME = RF.RDB$RELATION_NAME ' +
    'JOIN RDB$FIELDS F ON F.RDB$FIELD_NAME = RF.RDB$FIELD_SOURCE ' +
    'WHERE COALESCE(R.RDB$SYSTEM_FLAG, 0) = 0 ' +
    'ORDER BY RF.RDB$RELATION_NAME, RF.RDB$FIELD_POSITION');
  try
    while not LData.Eof do
    begin
      LTable := FCatalog.Find(FieldText(LData, 0));
      if LTable <> nil then
      begin
        LColumn := LTable.AddColumn(FieldText(LData, 1));
        FirebirdColumnType(FieldInt(LData, 2), FieldInt(LData, 3),
          FieldInt(LData, 4), FieldInt(LData, 5), FieldInt(LData, 6),
          FieldInt(LData, 7), LCloudType, LDetected);
        LColumn.DataType := LCloudType;
        LColumn.DetectedType := LDetected;
        LColumn.Context := FieldText(LData, 8);
      end;
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  try
    LData := Open('SELECT TRIM(RC.RDB$RELATION_NAME), TRIM(S.RDB$FIELD_NAME) ' +
      'FROM RDB$RELATION_CONSTRAINTS RC ' +
      'JOIN RDB$INDEX_SEGMENTS S ON S.RDB$INDEX_NAME = RC.RDB$INDEX_NAME ' +
      'WHERE RC.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY''');
    try
      while not LData.Eof do
      begin
        SetPrimaryKey(FieldText(LData, 0), FieldText(LData, 1));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
    // Without keys the schema is still useful
  end;
  try
    LData := Open('SELECT TRIM(RC.RDB$CONSTRAINT_NAME), TRIM(RC.RDB$RELATION_NAME), ' +
      'TRIM(S.RDB$FIELD_NAME), TRIM(RC2.RDB$RELATION_NAME), TRIM(S2.RDB$FIELD_NAME) ' +
      'FROM RDB$RELATION_CONSTRAINTS RC ' +
      'JOIN RDB$REF_CONSTRAINTS REF ON REF.RDB$CONSTRAINT_NAME = RC.RDB$CONSTRAINT_NAME ' +
      'JOIN RDB$RELATION_CONSTRAINTS RC2 ON RC2.RDB$CONSTRAINT_NAME = REF.RDB$CONST_NAME_UQ ' +
      'JOIN RDB$INDEX_SEGMENTS S ON S.RDB$INDEX_NAME = RC.RDB$INDEX_NAME ' +
      'JOIN RDB$INDEX_SEGMENTS S2 ON S2.RDB$INDEX_NAME = RC2.RDB$INDEX_NAME ' +
      'AND S2.RDB$FIELD_POSITION = S.RDB$FIELD_POSITION ' +
      'WHERE RC.RDB$CONSTRAINT_TYPE = ''FOREIGN KEY'' ' +
      'ORDER BY RC.RDB$RELATION_NAME, RC.RDB$CONSTRAINT_NAME, S.RDB$FIELD_POSITION');
    try
      while not LData.Eof do
      begin
        AddForeignKey(FieldText(LData, 1), FieldText(LData, 0),
          FieldText(LData, 3), FieldText(LData, 2), FieldText(LData, 4));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
  end;
end;

procedure TRpCatalogReader.ReadInformationSchema;
var
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LFilter: string;
  LTable: TRpCatTable;
begin
  case FFamily of
    rcfMySQL:
      LFilter := 'TABLE_SCHEMA = DATABASE()';
    rcfSQLServer:
      LFilter := 'TABLE_SCHEMA NOT IN (''sys'', ''INFORMATION_SCHEMA'')';
  else
    LFilter := 'TABLE_SCHEMA NOT IN (''pg_catalog'', ''information_schema'')';
  end;
  if FFamily = rcfMySQL then
    LData := Open('SELECT TABLE_NAME, TABLE_COMMENT FROM INFORMATION_SCHEMA.TABLES ' +
      'WHERE ' + LFilter + ' ORDER BY TABLE_NAME')
  else
    LData := Open('SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ' +
      'WHERE ' + LFilter + ' ORDER BY TABLE_NAME');
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0)).Context := FieldText(LData, 1);
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  if FFamily = rcfMySQL then
    LData := Open('SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, ' +
      'CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_COMMENT ' +
      'FROM INFORMATION_SCHEMA.COLUMNS WHERE ' + LFilter +
      ' ORDER BY TABLE_NAME, ORDINAL_POSITION')
  else
    LData := Open('SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, ' +
      'CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE ' +
      'FROM INFORMATION_SCHEMA.COLUMNS WHERE ' + LFilter +
      ' ORDER BY TABLE_NAME, ORDINAL_POSITION');
  try
    while not LData.Eof do
    begin
      LTable := FCatalog.Find(FieldText(LData, 0));
      if LTable <> nil then
      begin
        LColumn := LTable.AddColumn(FieldText(LData, 1));
        LColumn.DataType := CloudTypeOfSqlType(FieldText(LData, 2), FieldInt(LData, 5));
        LColumn.DetectedType := SqlTypeText(FieldText(LData, 2), FieldInt(LData, 3),
          FieldInt(LData, 4), FieldInt(LData, 5));
        LColumn.Context := FieldText(LData, 6);
      end;
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  try
    LData := Open('SELECT kcu.TABLE_NAME, kcu.COLUMN_NAME ' +
      'FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ' +
      'JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME ' +
      'AND kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA AND kcu.TABLE_NAME = tc.TABLE_NAME ' +
      'WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''');
    try
      while not LData.Eof do
      begin
        SetPrimaryKey(FieldText(LData, 0), FieldText(LData, 1));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
  end;
  try
    LData := Open('SELECT rc.CONSTRAINT_NAME, kcu.TABLE_NAME, kcu.COLUMN_NAME, ' +
      'kcu2.TABLE_NAME, kcu2.COLUMN_NAME ' +
      'FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc ' +
      'JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME ' +
      'AND kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA ' +
      'JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu2 ON kcu2.CONSTRAINT_NAME = rc.UNIQUE_CONSTRAINT_NAME ' +
      'AND kcu2.CONSTRAINT_SCHEMA = rc.UNIQUE_CONSTRAINT_SCHEMA ' +
      'AND kcu2.ORDINAL_POSITION = kcu.ORDINAL_POSITION ' +
      'ORDER BY kcu.TABLE_NAME, rc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION');
    try
      while not LData.Eof do
      begin
        AddForeignKey(FieldText(LData, 1), FieldText(LData, 0),
          FieldText(LData, 3), FieldText(LData, 2), FieldText(LData, 4));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
  end;
end;

procedure TRpCatalogReader.ReadSQLite;
var
  I: Integer;
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LQuoted: string;
  LTable: TRpCatTable;
begin
  LData := Open('SELECT name FROM sqlite_master WHERE type IN (''table'', ''view'') ' +
    'AND name NOT LIKE ''sqlite_%'' ORDER BY name');
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0));
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  for I := 0 to FCatalog.List.Count - 1 do
  begin
    LTable := TRpCatTable(FCatalog.List.Objects[I]);
    LQuoted := '''' + StringReplace(LTable.Name, '''', '''''', [rfReplaceAll]) + '''';
    LData := Open('SELECT name, type, pk FROM pragma_table_info(' + LQuoted + ')');
    try
      while not LData.Eof do
      begin
        LColumn := LTable.AddColumn(FieldText(LData, 0));
        LColumn.DetectedType := UpperCase(FieldText(LData, 1));
        LColumn.DataType := CloudTypeOfSqlType(FieldText(LData, 1), -1);
        LColumn.IsPrimaryKey := FieldInt(LData, 2) > 0;
        LData.Next;
      end;
    finally
      LData.Free;
    end;
    try
      LData := Open('SELECT id, "table", "from", "to" FROM pragma_foreign_key_list(' +
        LQuoted + ') ORDER BY id, seq');
      try
        while not LData.Eof do
        begin
          AddForeignKey(LTable.Name, 'FK_' + LTable.Name + '_' + FieldText(LData, 0),
            FieldText(LData, 1), FieldText(LData, 2), FieldText(LData, 3));
          LData.Next;
        end;
      finally
        LData.Free;
      end;
    except
    end;
  end;
end;

procedure TRpCatalogReader.ReadOracle;
var
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  LData := Open('SELECT TABLE_NAME FROM USER_TABLES UNION ' +
    'SELECT VIEW_NAME FROM USER_VIEWS ORDER BY 1');
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0));
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  LData := Open('SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, ' +
    'DATA_PRECISION, DATA_SCALE FROM USER_TAB_COLUMNS ' +
    'ORDER BY TABLE_NAME, COLUMN_ID');
  try
    while not LData.Eof do
    begin
      LTable := FCatalog.Find(FieldText(LData, 0));
      if LTable <> nil then
      begin
        LColumn := LTable.AddColumn(FieldText(LData, 1));
        LColumn.DataType := CloudTypeOfSqlType(FieldText(LData, 2), FieldInt(LData, 5));
        if Pos('CHAR', UpperCase(FieldText(LData, 2))) > 0 then
          LColumn.DetectedType := SqlTypeText(FieldText(LData, 2), FieldInt(LData, 3), 0, 0)
        else
          LColumn.DetectedType := SqlTypeText(FieldText(LData, 2), 0,
            FieldInt(LData, 4), FieldInt(LData, 5));
      end;
      LData.Next;
    end;
  finally
    LData.Free;
  end;
  try
    LData := Open('SELECT CC.TABLE_NAME, CC.COLUMN_NAME FROM USER_CONSTRAINTS C ' +
      'JOIN USER_CONS_COLUMNS CC ON CC.CONSTRAINT_NAME = C.CONSTRAINT_NAME ' +
      'WHERE C.CONSTRAINT_TYPE = ''P''');
    try
      while not LData.Eof do
      begin
        SetPrimaryKey(FieldText(LData, 0), FieldText(LData, 1));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
  end;
  try
    LData := Open('SELECT C.CONSTRAINT_NAME, CC.TABLE_NAME, CC.COLUMN_NAME, ' +
      'RC.TABLE_NAME, RCC.COLUMN_NAME FROM USER_CONSTRAINTS C ' +
      'JOIN USER_CONS_COLUMNS CC ON CC.CONSTRAINT_NAME = C.CONSTRAINT_NAME ' +
      'JOIN USER_CONSTRAINTS RC ON RC.CONSTRAINT_NAME = C.R_CONSTRAINT_NAME ' +
      'JOIN USER_CONS_COLUMNS RCC ON RCC.CONSTRAINT_NAME = RC.CONSTRAINT_NAME ' +
      'AND RCC.POSITION = CC.POSITION ' +
      'WHERE C.CONSTRAINT_TYPE = ''R'' ORDER BY 2, 1, CC.POSITION');
    try
      while not LData.Eof do
      begin
        AddForeignKey(FieldText(LData, 1), FieldText(LData, 0),
          FieldText(LData, 3), FieldText(LData, 2), FieldText(LData, 4));
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
  end;
end;

// The cloud's type of a field of a dataset
function CloudTypeOfField(AField: TField): string;
begin
  case AField.DataType of
    ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint
{$IFNDEF FPC}, ftShortint, ftByte, ftLongWord{$ENDIF}:
      Result := 'Integer';
    ftCurrency:
      Result := 'Currency';
    ftFloat, ftBCD, ftFMTBcd{$IFNDEF FPC}, ftExtended, ftSingle{$ENDIF}:
      Result := 'Numeric';
    ftBoolean:
      Result := 'Boolean';
    ftDate:
      Result := 'Date';
    ftTime, ftDateTime, ftTimeStamp{$IFNDEF FPC}, ftTimeStampOffset{$ENDIF}:
      Result := 'TimeStamp';
    ftMemo, ftWideMemo, ftFmtMemo:
      Result := 'TextLong';
  else
    Result := 'String';
  end;
end;

procedure TRpCatalogReader.ReadGeneric;
var
  I, J: Integer;
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LNames: TStringList;
  LTable: TRpCatTable;
begin
  // The tables the driver lists, the columns of a query without rows
  LNames := TStringList.Create;
  try
    FDatabase.GetTableNames(LNames, FParams);
    for I := 0 to LNames.Count - 1 do
      if Trim(LNames[I]) <> '' then
        FCatalog.Add(Trim(LNames[I]));
  finally
    LNames.Free;
  end;
  for I := 0 to FCatalog.List.Count - 1 do
  begin
    LTable := TRpCatTable(FCatalog.List.Objects[I]);
    try
      LData := Open('SELECT * FROM ' + LTable.Name + ' WHERE 1 = 0');
      try
        for J := 0 to LData.FieldCount - 1 do
        begin
          LColumn := LTable.AddColumn(LData.Fields[J].FieldName);
          LColumn.DataType := CloudTypeOfField(LData.Fields[J]);
          LColumn.DetectedType := FieldTypeNames[LData.Fields[J].DataType];
        end;
      finally
        LData.Free;
      end;
    except
      // A table that can not be read is described without columns
    end;
  end;
end;

function TRpCatalogReader.Read(out ADialect: string): TJSONArray;
begin
  FFamily := FamilyOf(FDatabase);
  ADialect := DialectOfFamily(FFamily);
  FDatabase.Connect(FParams);
  try
    case FFamily of
      rcfFirebird:
        begin
          ADialect := FirebirdDialect;
          ReadFirebird;
        end;
      rcfPostgreSQL, rcfMySQL, rcfSQLServer:
        ReadInformationSchema;
      rcfSQLite:
        ReadSQLite;
      rcfOracle:
        ReadOracle;
    else
      ReadGeneric;
    end;
  except
    // A catalog that can not be read (permissions, an older server): the
    // tables the driver lists
    if FFamily = rcfGeneric then
      raise;
    FCatalog.List.Clear;
    ReadGeneric;
  end;
  Result := FCatalog.ToJsonArray;
end;

function RpReadLocalSchemaCatalog(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; out ADialect: string): TJSONArray;
var
  LReader: TRpCatalogReader;
begin
  if ADatabase = nil then
    raise Exception.Create('No connection');
  if not RpIsLocalSqlDatabase(ADatabase) then
    raise Exception.Create('The connection ' + ADatabase.Alias +
      ' does not run SQL on this computer');
  LReader := TRpCatalogReader.Create(ADatabase, AParams);
  try
    Result := LReader.Read(ADialect);
  finally
    LReader.Free;
  end;
end;

function RpLoadLocalSchema(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; AGenerate, ARefresh: Boolean): TRpLocalSchemaFile;
var
  LDialect, LFileName: string;
  LExists: Boolean;
  LTables: TJSONArray;
begin
  Result := nil;
  if ADatabase = nil then
    Exit;
  LFileName := RpLocalSchemaFileName(ADatabase);
  Result := TRpLocalSchemaFile.Create;
  try
    LExists := Result.LoadFromFile(LFileName);
    if (not LExists and not AGenerate) then
    begin
      FreeAndNil(Result);
      Exit;
    end;
    if ARefresh or not LExists then
    begin
      LTables := RpReadLocalSchemaCatalog(ADatabase, AParams, LDialect);
      Result.Alias := UpperCase(ADatabase.Alias);
      Result.SetCatalog(LTables, LDialect);
      Result.SaveToFile(LFileName);
    end;
    if Result.Alias = '' then
      Result.Alias := UpperCase(ADatabase.Alias);
    if Result.Dialect = '' then
      Result.Dialect := RpLocalDatabaseDialect(ADatabase);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function RpCopyDatabaseInfo(ADatabase: TRpDatabaseInfoItem): TRpDatabaseInfoList;
var
  LItem: TRpDatabaseInfoItem;
begin
  Result := TRpDatabaseInfoList.Create(nil);
  try
    LItem := Result.Add(ADatabase.Alias);
    LItem.Assign(ADatabase);
    if not Assigned(ADatabase.ConAdmin) then
      ADatabase.UpdateConAdmin;
    LItem.ConAdmin := TRpConnAdmin.Create;
    LItem.ConAdmin.DBXConnectionsOverride := ADatabase.ConAdmin.configfilename;
    if ADatabase.ConAdmin.driverfilename <> '' then
      LItem.ConAdmin.DBXDriversOverride := ADatabase.ConAdmin.driverfilename;
    LItem.ConAdmin.LoadConfig;
  except
    Result.Free;
    raise;
  end;
end;

procedure RpListLocalSubSchemas(ADatabase: TRpDatabaseInfoItem; AList: TStrings);
var
  I: Integer;
  LFile: TRpLocalSchemaFile;
begin
  AList.Clear;
  if not RpIsLocalSqlDatabase(ADatabase) then
    Exit;
  try
    LFile := RpLoadLocalSchema(ADatabase, nil, False, False);
  except
    // A file that can not be read lists no subschema
    LFile := nil;
  end;
  if LFile = nil then
    Exit;
  try
    for I := 0 to LFile.SchemaCount - 1 do
      AList.Add(LFile.Schemas[I].Name);
  finally
    LFile.Free;
  end;
end;

end.

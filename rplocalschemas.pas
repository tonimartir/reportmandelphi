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
    "version": 2, "alias": "FBEXAMPLE", "dialect": "Firebird5",
    "generatedUtc": "2026-10-08T01:00:00Z",
    "tables": [ { "name", "context", "columns": [ { "name", "dataType",
      "context", "isPrimaryKey", "detectedType",
      "allowedValues": [ { "value", "label" } ] } ], "foreignKeys": [
      { "constraintName", "targetTable", "sourceColumns", "targetColumns",
      "relationshipContext" } ] } ],
    "schemas": [ { "name": "Sales", "description": "", "tables": [...],
      "columns": { "SALES": ["SALEID", "TOTAL"] } } ]
  }

  - "tables" is the JSON of the SchemaTable of the Hub and the Desktop, so it
    travels as it is in the inline config of the cloud (schemaTables);
    dataType is one of the cloud's ColumnDataType names (Integer, Numeric,
    Currency, String, TextLong, Date, TimeStamp, Boolean).
  - "All" is not saved: it is every table. "schemas" are the subschemas the
    user defines (a name and a selection of tables and, from version 2, of
    their columns: a table missing from "columns", or with an empty list,
    goes with its primary key only; people choose the columns and describe
    them, docs/esquemas-locales-pantalla-plan.md 5.5.1).
  - "tables" is the dictionary: what is written of a table, a column or a
    relation (context, allowed values) is shared by every subschema. A
    relation the database does not declare has an empty constraintName.
  - Version 2 adds "allowedValues" (the values a column takes and what each
    one means) and "columns" of a subschema. Every reader keeps what it does
    not know (the properties of a newer version, at any level) and writes it
    back: saving with an older designer never loses them.
  - It is generated from the catalog the first time it is needed. A refresh
    reads the catalog again and keeps the context written for the tables,
    columns and foreign keys that still exist, the relations written by hand
    whose columns still exist, and the subschemas (without the tables and
    columns that are gone). The comments of the database are the starting
    context (Firebird, PostgreSQL, SQL Server, MySQL, Oracle).
  - The tables of a subschema sent to the AI carry the columns it chose (its
    primary key when it chose none) and the relations whose two ends
    travel. Without a subschema, everything. *)

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
  RP_LOCAL_SCHEMA_VERSION = 2;

type
  TRpLocalSubSchema = class(TObject)
  private
    // Table name to the columns it takes (version 2)
    FColumns: TJSONObject;
    FDescription: string;
    // What this version does not know, written back as it is
    FExtra: TJSONObject;
    FName: string;
    FTables: TStringList;
    function ColumnsJson: TJSONObject;
    procedure KeepColumnsOf(ACatalog: TJSONArray);
  public
    constructor Create;
    destructor Destroy; override;
    // The columns chosen of a table: False (and AList empty) when it chose
    // none (the table goes with its primary key)
    function GetColumns(const ATable: string; AList: TStrings): Boolean;
    // The columns chosen of a table; an empty list is its primary key again
    procedure SetColumns(const ATable: string; AColumns: TStrings);
    property Description: string read FDescription write FDescription;
    property Name: string read FName write FName;
    property Tables: TStringList read FTables;
  end;

  // A relation of the dictionary: the foreign key ForeignKey (an object of
  // the "foreignKeys" of the table SourceTable, not owned) as the screens
  // show it. It belongs to the tables of the file: one read again
  // (SetCatalog) leaves it pointing nowhere
  TRpLocalRelation = class(TObject)
  public
    SourceTable: string;
    ForeignKey: TJSONObject;
    function TargetTable: string;
    procedure GetSourceColumns(AList: TStrings);
    procedure GetTargetColumns(AList: TStrings);
    // 'A, B'
    function SourceColumnsText: string;
    function TargetColumnsText: string;
    // The database does not declare it (constraintName is empty)
    function IsManual: Boolean;
    function Context: string;
    procedure SetContext(const AText: string);
  end;

  TRpLocalSchemaFile = class(TObject)
  private
    FAlias: string;
    FDialect: string;
    // What this version does not know, written back as it is
    FExtra: TJSONObject;
    FFileName: string;
    FVersion: Integer;
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
    // all the tables), the schemaTables of the inline config: of each table
    // the columns it chose (its primary key when it chose none) and the
    // relations whose two ends travel
    function SchemaTablesJson(const ASchemaName: string): string;
    // What SchemaTablesJson sends, for the limits of the plan: its tables
    // and the columns of the widest one
    procedure GetSchemaSize(const ASchemaName: string; out ATables,
      AWidestColumns: Integer);
    // The dialect of the inline config ('Default' when not known)
    function CloudDialect: string;
    // The subschema as the file spells it; '' (all the tables) when it is
    // not in the file
    function SchemaNameOf(const ASchemaName: string): string;

    { The dictionary and the subschemas, for the local schema screens. A nil
      subschema is "all the tables" }
    // A table of the catalog (nil when it is not there)
    function FindTable(const AName: string): TJSONObject;
    // A column of a table of the catalog (nil when it is not there)
    function FindColumn(const ATable, AColumn: string): TJSONObject;
    // The columns of a table, in the order of the catalog
    procedure GetColumnNames(const ATable: string; AList: TStrings);
    // The columns of the primary key of a table
    procedure GetPrimaryKey(const ATable: string; AList: TStrings);
    // The columns of a table that travel, in the order of the catalog: all
    // of them without a subschema; in one, its list or the primary key
    procedure GetTravelingColumns(ASchema: TRpLocalSubSchema;
      const ATable: string; AList: TStrings);
    function ColumnTravels(ASchema: TRpLocalSubSchema;
      const ATable, AColumn: string): Boolean;
    // Chooses a column of a table of the subschema, or leaves it (the list
    // starts from what travels; an empty one is the primary key again)
    procedure SetColumnChosen(ASchema: TRpLocalSubSchema;
      const ATable, AColumn: string; AChosen: Boolean);
    // A table enters the subschema with its primary key (a list of columns
    // of its own); nothing when it is there
    procedure AddSchemaTable(ASchema: TRpLocalSubSchema; const ATable: string);
    procedure RemoveSchemaTable(ASchema: TRpLocalSubSchema; const ATable: string);
    // A copy of a subschema with another name, at the end
    function DuplicateSchema(AIndex: Integer;
      const ANewName: string): TRpLocalSubSchema;
    procedure RenameSchema(AIndex: Integer; const ANewName: string);
    // The other subschemas where the column travels ("Also in")
    procedure GetSchemasWithColumn(const ATable, AColumn: string;
      AExclude: TRpLocalSubSchema; AList: TStrings);
    procedure SetTableContext(const ATable, AText: string);
    procedure SetColumnContext(const ATable, AColumn, AText: string);
    // The allowed values of a column, two lists of the same length
    procedure GetAllowedValues(const ATable, AColumn: string;
      AValues, ALabels: TStrings);
    // The allowed values of a column (rows without value and label are left
    // out; a value that was there keeps what it had of a newer version)
    procedure SetAllowedValues(const ATable, AColumn: string;
      AValues, ALabels: TStrings);
    // A relation (a foreign key of ASourceTable) travels: its two ends do,
    // by table and by column (always without a subschema)
    function ForeignKeyTravels(ASchema: TRpLocalSubSchema;
      const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
    // The relations of the dictionary that travel in the subschema (all of
    // them without one), added to AList (TRpLocalRelation, owned by the list)
    procedure GetRelations(ASchema: TRpLocalSubSchema; AList: TObjectList);
    // The relations of the tables of the subschema that do not travel and
    // whose target is in the dictionary, even when both tables are chosen:
    // the suggestions ("Complete")
    procedure GetSuggestedRelations(ASchema: TRpLocalSubSchema;
      AList: TObjectList);
    // Makes a relation travel: the target table (with its primary key when
    // it enters) and the columns of both ends added to their lists (each
    // one starting from what travels)
    procedure CompleteRelation(ASchema: TRpLocalSubSchema;
      ARelation: TRpLocalRelation);
    // A relation the database does not declare, in the dictionary (an empty
    // constraintName); raises when a table or column is not there. One
    // that is there already (the same target and columns) is not added
    // twice: it is returned, with AContext when one is given
    function AddRelation(const ASourceTable, ATargetTable: string;
      ASourceColumns, ATargetColumns: TStrings;
      const AContext: string): TJSONObject;
    // Removes a relation written by hand (the ones of the database come
    // back when it is read again)
    procedure DeleteRelation(ARelation: TRpLocalRelation);
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
// The subschema ASchemaName of the file of the connection, as the file
// spells it; '' (all the tables) when it is not there or there is no file
function RpExistingLocalSubSchema(ADatabase: TRpDatabaseInfoItem;
  const ASchemaName: string): string;
// The schema selector of the AI chat for a direct connection: adds to
// AEntries 'ALIAS=' (all the tables) and 'ALIAS=<subschema>', and to ASizes
// the size of each one, '<tables>,<widest columns>' ('' while the file does
// not exist: it is not generated to list)
procedure RpListLocalSchemaEntries(ADatabase: TRpDatabaseInfoItem;
  AEntries, ASizes: TStrings);
// The tables of a JSON array of schemaTables (the inline config, a Hub
// schema) and the columns of the widest one
procedure RpSchemaTablesSize(ATables: TJSONArray; out ATableCount,
  AWidestColumns: Integer);
// The SQL of the first ARows rows of a table in a dialect of the cloud
// (Firebird, PostgreSQL, MySQL, SQL Server, SQLite, Oracle; a whole SELECT
// for the rest)
function RpLocalSchemaPreviewSql(const ADialect, ATable: string;
  ARows: Integer): string;
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

// The properties of AFrom that are not in AKnown, copied to ATo (what a newer
// version wrote, kept to be written back)
procedure CopyUnknown(AFrom, ATo: TJSONObject; const AKnown: array of string);
var
  I, J: Integer;
  LName: string;
  LKnown: Boolean;
begin
  if (AFrom = nil) or (ATo = nil) then
    Exit;
  for I := 0 to AFrom.Count - 1 do
  begin
    LName := AFrom.Pairs[I].JsonString.Value;
    LKnown := False;
    for J := Low(AKnown) to High(AKnown) do
      if SameText(LName, AKnown[J]) then
        LKnown := True;
    if not LKnown and (ATo.Values[LName] = nil) then
      ATo.AddPair(LName, TJSONValue(AFrom.Pairs[I].JsonValue.Clone));
  end;
end;

// The names of a JSON array of strings
procedure ArrayNames(AArray: TJSONArray; AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  if AArray = nil then
    Exit;
  for I := 0 to AArray.Count - 1 do
    if (AArray.Items[I] <> nil) and (Trim(AArray.Items[I].Value) <> '') then
      AList.Add(AArray.Items[I].Value);
end;

// The names of a list, added to a JSON array
procedure ArrayToNames(AList: TStrings; AArray: TJSONArray);
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
    AArray.Add(AList[I]);
end;

function JBool(AObject: TJSONObject; const AName: string): Boolean;
begin
  Result := SameText(JStr(AObject, AName), 'true');
end;

// The names of AColumns as the columns of ATable spell them; False when one
// is not there (or there are none)
function SpellColumns(ATable: TJSONObject; AColumns: TStrings;
  AResult: TJSONArray): Boolean;
var
  I: Integer;
  LColumn: TJSONObject;
begin
  Result := (ATable <> nil) and (AColumns.Count > 0);
  if not Result then
    Exit;
  for I := 0 to AColumns.Count - 1 do
  begin
    LColumn := FindByName(JArr(ATable, 'columns'), 'name', Trim(AColumns[I]));
    if LColumn = nil then
      Exit(False);
    AResult.Add(JStr(LColumn, 'name'));
  end;
end;

// Two JSON arrays of names are the same, ignoring case
function SameNames(A, B: TJSONArray): Boolean;
var
  I: Integer;
begin
  Result := (A <> nil) and (B <> nil) and (A.Count = B.Count);
  if Result then
    for I := 0 to A.Count - 1 do
      if (A.Items[I] = nil) or (B.Items[I] = nil) or
        not SameText(A.Items[I].Value, B.Items[I].Value) then
        Exit(False);
end;

// The relation of ATable to ATargetTable over the same source and target
// columns, ignoring case (nil when there is none)
function FindRelation(ATable: TJSONObject; const ATargetTable: string;
  ASource, ATarget: TJSONArray): TJSONObject;
var
  I: Integer;
  LForeignKeys: TJSONArray;
  LOther: TJSONObject;
begin
  Result := nil;
  LForeignKeys := JArr(ATable, 'foreignKeys');
  if LForeignKeys <> nil then
    for I := 0 to LForeignKeys.Count - 1 do
    begin
      LOther := JObj(LForeignKeys, I);
      if (LOther <> nil) and SameText(JStr(LOther, 'targetTable'), ATargetTable) and
        SameNames(JArr(LOther, 'sourceColumns'), ASource) and
        SameNames(JArr(LOther, 'targetColumns'), ATarget) then
        Exit(LOther);
    end;
end;

// A relation written by hand (empty constraintName) of the previous file,
// added to the table of the catalog read again when its columns and its
// target are still there, as the catalog spells them, unless the table has
// that relation already
procedure KeepManualRelation(ACatalog: TJSONArray; ANewTable,
  AOldRelation: TJSONObject);
var
  LNames: TStringList;
  LSource, LTarget: TJSONArray;
  LTargetTable, LRelation, LOther: TJSONObject;
  LForeignKeys: TJSONArray;
begin
  LTargetTable := FindByName(ACatalog, 'name', JStr(AOldRelation, 'targetTable'));
  if LTargetTable = nil then
    Exit;
  LNames := TStringList.Create;
  LSource := TJSONArray.Create;
  LTarget := TJSONArray.Create;
  try
    ArrayNames(JArr(AOldRelation, 'sourceColumns'), LNames);
    if not SpellColumns(ANewTable, LNames, LSource) then
      Exit;
    ArrayNames(JArr(AOldRelation, 'targetColumns'), LNames);
    if not SpellColumns(LTargetTable, LNames, LTarget) or
      (LSource.Count <> LTarget.Count) then
      Exit;
    // The database declares it now: it is its relation, with what the
    // person wrote when the database says nothing
    LOther := FindRelation(ANewTable, JStr(LTargetTable, 'name'), LSource, LTarget);
    if LOther <> nil then
    begin
      if (Trim(JStr(LOther, 'relationshipContext')) = '') and
        (Trim(JStr(AOldRelation, 'relationshipContext')) <> '') then
        SetPair(LOther, 'relationshipContext',
          TJSONString.Create(JStr(AOldRelation, 'relationshipContext')));
      Exit;
    end;
    LRelation := TJSONObject(AOldRelation.Clone);
    SetPair(LRelation, 'targetTable', TJSONString.Create(JStr(LTargetTable, 'name')));
    SetPair(LRelation, 'sourceColumns', LSource);
    LSource := nil;
    SetPair(LRelation, 'targetColumns', LTarget);
    LTarget := nil;
    LForeignKeys := JArr(ANewTable, 'foreignKeys');
    if LForeignKeys = nil then
    begin
      LForeignKeys := TJSONArray.Create;
      SetPair(ANewTable, 'foreignKeys', LForeignKeys);
    end;
    LForeignKeys.AddElement(LRelation);
  finally
    LTarget.Free;
    LSource.Free;
    LNames.Free;
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
  FColumns := TJSONObject.Create;
  FExtra := TJSONObject.Create;
end;

destructor TRpLocalSubSchema.Destroy;
begin
  FTables.Free;
  FColumns.Free;
  FExtra.Free;
  inherited Destroy;
end;

function TRpLocalSubSchema.GetColumns(const ATable: string;
  AList: TStrings): Boolean;
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to FColumns.Count - 1 do
    if SameText(FColumns.Pairs[I].JsonString.Value, ATable) and
      (FColumns.Pairs[I].JsonValue is TJSONArray) then
    begin
      ArrayNames(TJSONArray(FColumns.Pairs[I].JsonValue), AList);
      Break;
    end;
  Result := AList.Count > 0;
end;

procedure TRpLocalSubSchema.SetColumns(const ATable: string;
  AColumns: TStrings);
var
  I: Integer;
  LNames: TJSONArray;
begin
  for I := FColumns.Count - 1 downto 0 do
    if SameText(FColumns.Pairs[I].JsonString.Value, ATable) then
      FColumns.RemovePair(FColumns.Pairs[I].JsonString.Value).Free;
  if (AColumns = nil) or (AColumns.Count = 0) then
    Exit;
  LNames := TJSONArray.Create;
  for I := 0 to AColumns.Count - 1 do
    if Trim(AColumns[I]) <> '' then
      LNames.Add(AColumns[I]);
  FColumns.AddPair(ATable, LNames);
end;

// The columns to write: only tables of the subschema (as it spells them) with
// columns chosen; nil when every table goes whole
function TRpLocalSubSchema.ColumnsJson: TJSONObject;
var
  I: Integer;
  LArray: TJSONArray;
  LNames: TStringList;
begin
  Result := nil;
  LNames := TStringList.Create;
  try
    for I := 0 to FTables.Count - 1 do
      if GetColumns(FTables[I], LNames) then
      begin
        if Result = nil then
          Result := TJSONObject.Create;
        LArray := TJSONArray.Create;
        ArrayToNames(LNames, LArray);
        Result.AddPair(FTables[I], LArray);
      end;
  finally
    LNames.Free;
  end;
end;

// After reading the catalog again: the columns of the tables that are still
// in the subschema, that still exist, as the catalog spells them
procedure TRpLocalSubSchema.KeepColumnsOf(ACatalog: TJSONArray);
var
  I, J: Integer;
  LKept, LNames: TStringList;
  LColumn, LTable: TJSONObject;
  LOld: TJSONObject;
begin
  LOld := FColumns;
  FColumns := TJSONObject.Create;
  LNames := TStringList.Create;
  LKept := TStringList.Create;
  try
    for I := 0 to LOld.Count - 1 do
    begin
      if not (LOld.Pairs[I].JsonValue is TJSONArray) then
        Continue;
      LTable := FindByName(ACatalog, 'name', LOld.Pairs[I].JsonString.Value);
      if (LTable = nil) or (FTables.IndexOf(JStr(LTable, 'name')) < 0) then
        Continue;
      ArrayNames(TJSONArray(LOld.Pairs[I].JsonValue), LNames);
      LKept.Clear;
      for J := 0 to LNames.Count - 1 do
      begin
        LColumn := FindByName(JArr(LTable, 'columns'), 'name', LNames[J]);
        if (LColumn <> nil) and (LKept.IndexOf(JStr(LColumn, 'name')) < 0) then
          LKept.Add(JStr(LColumn, 'name'));
      end;
      SetColumns(JStr(LTable, 'name'), LKept);
    end;
  finally
    LKept.Free;
    LNames.Free;
    LOld.Free;
  end;
end;

{ TRpLocalSchemaFile }

constructor TRpLocalSchemaFile.Create;
begin
  inherited Create;
  FSchemas := TObjectList.Create(True);
  FTables := TJSONArray.Create;
  FExtra := TJSONObject.Create;
  FVersion := RP_LOCAL_SCHEMA_VERSION;
end;

destructor TRpLocalSchemaFile.Destroy;
begin
  FSchemas.Free;
  FTables.Free;
  FExtra.Free;
  inherited Destroy;
end;

procedure TRpLocalSchemaFile.Clear;
begin
  FSchemas.Clear;
  FTables.Free;
  FTables := TJSONArray.Create;
  FExtra.Free;
  FExtra := TJSONObject.Create;
  FVersion := RP_LOCAL_SCHEMA_VERSION;
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
    FVersion := StrToIntDef(JStr(LObject, 'version'), 1);
    FAlias := JStr(LObject, 'alias');
    FDialect := JStr(LObject, 'dialect');
    FGeneratedUtc := JStr(LObject, 'generatedUtc');
    CopyUnknown(LObject, FExtra, ['version', 'alias', 'dialect',
      'generatedUtc', 'tables', 'schemas']);
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
        if JObj(LArray, I).Values['columns'] is TJSONObject then
        begin
          LSchema.FColumns.Free;
          LSchema.FColumns := TJSONObject(JObj(LArray, I).Values['columns'].Clone);
        end;
        CopyUnknown(JObj(LArray, I), LSchema.FExtra, ['name', 'description',
          'tables', 'columns']);
      end;
  finally
    LRoot.Free;
  end;
end;

function TRpLocalSchemaFile.ToJsonText: string;
var
  I, J: Integer;
  LNames, LSchemas: TJSONArray;
  LColumns, LRoot, LSchemaObject: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    // A newer file keeps its own version
    if FVersion > RP_LOCAL_SCHEMA_VERSION then
      LRoot.AddPair('version', TJSONNumber.Create(FVersion))
    else
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
      LColumns := Schemas[I].ColumnsJson;
      if LColumns <> nil then
        LSchemaObject.AddPair('columns', LColumns);
      CopyUnknown(Schemas[I].FExtra, LSchemaObject, []);
    end;
    CopyUnknown(FExtra, LRoot, []);
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
          if Trim(JStr(LNewItem, 'constraintName')) = '' then
            Continue;
          LOldItem := FindByName(LOldItems, 'constraintName',
            JStr(LNewItem, 'constraintName'));
          KeepWritten(LOldItem, LNewItem, 'relationshipContext',
            ['constraintName', 'targetTable', 'sourceColumns', 'targetColumns']);
        end;
      // The relations written by hand whose columns are still there
      if LOldItems <> nil then
        for J := 0 to LOldItems.Count - 1 do
          if (JObj(LOldItems, J) <> nil) and
            (Trim(JStr(JObj(LOldItems, J), 'constraintName')) = '') then
            KeepManualRelation(ATables, LNewTable, JObj(LOldItems, J));
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
  for I := 0 to FSchemas.Count - 1 do
    Schemas[I].KeepColumnsOf(FTables);
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

// Whether a relation end travels: its table is in ATables and has all the
// columns
function EndTravels(ATables: TJSONArray; const ATable: string;
  AColumns: TJSONArray): Boolean;
var
  I: Integer;
  LTable: TJSONObject;
begin
  LTable := FindByName(ATables, 'name', ATable);
  Result := LTable <> nil;
  if not Result or (AColumns = nil) then
    Exit;
  for I := 0 to AColumns.Count - 1 do
    if (AColumns.Items[I] <> nil) and
      (FindByName(JArr(LTable, 'columns'), 'name', AColumns.Items[I].Value) = nil) then
      Exit(False);
end;

function TRpLocalSchemaFile.SchemaTablesJson(const ASchemaName: string): string;
var
  I, J, LIndex: Integer;
  LArray, LColumns, LForeignKeys, LKept: TJSONArray;
  LChosen: TStringList;
  LClone, LItem, LTable: TJSONObject;
  LHasList: Boolean;
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
  LChosen := TStringList.Create;
  try
    // The tables of the subschema, with the columns it chose of each one
    // and only the primary key when it chose none
    for I := 0 to FTables.Count - 1 do
    begin
      LTable := JObj(FTables, I);
      if (LTable = nil) or
        (Schemas[LIndex].Tables.IndexOf(JStr(LTable, 'name')) < 0) then
        Continue;
      LClone := TJSONObject(LTable.Clone);
      LArray.AddElement(LClone);
      LHasList := Schemas[LIndex].GetColumns(JStr(LTable, 'name'), LChosen);
      LColumns := JArr(LClone, 'columns');
      LKept := TJSONArray.Create;
      if LColumns <> nil then
        for J := 0 to LColumns.Count - 1 do
          if (JObj(LColumns, J) <> nil) and
            ((LHasList and (LChosen.IndexOf(JStr(JObj(LColumns, J), 'name')) >= 0)) or
            ((not LHasList) and JBool(JObj(LColumns, J), 'isPrimaryKey'))) then
            LKept.AddElement(TJSONValue(JObj(LColumns, J).Clone));
      SetPair(LClone, 'columns', LKept);
    end;
    // A relation travels when its two ends do: a column the AI does not see
    // is no use to it
    for I := 0 to LArray.Count - 1 do
    begin
      LClone := JObj(LArray, I);
      LForeignKeys := JArr(LClone, 'foreignKeys');
      if LForeignKeys = nil then
        Continue;
      LKept := TJSONArray.Create;
      for J := 0 to LForeignKeys.Count - 1 do
      begin
        LItem := JObj(LForeignKeys, J);
        if (LItem <> nil) and
          EndTravels(LArray, JStr(LClone, 'name'), JArr(LItem, 'sourceColumns')) and
          EndTravels(LArray, JStr(LItem, 'targetTable'), JArr(LItem, 'targetColumns')) then
          LKept.AddElement(TJSONValue(LItem.Clone));
      end;
      SetPair(LClone, 'foreignKeys', LKept);
    end;
    Result := LArray.ToJSON;
  finally
    LChosen.Free;
    LArray.Free;
  end;
end;

procedure TRpLocalSchemaFile.GetSchemaSize(const ASchemaName: string;
  out ATables, AWidestColumns: Integer);
var
  LValue: TJSONValue;
begin
  ATables := 0;
  AWidestColumns := 0;
  LValue := TJSONObject.ParseJSONValue(SchemaTablesJson(ASchemaName));
  try
    if LValue is TJSONArray then
      RpSchemaTablesSize(TJSONArray(LValue), ATables, AWidestColumns);
  finally
    LValue.Free;
  end;
end;

function TRpLocalSchemaFile.CloudDialect: string;
begin
  Result := FDialect;
  if Result = '' then
    Result := 'Default';
end;

function TRpLocalSchemaFile.SchemaNameOf(const ASchemaName: string): string;
var
  LIndex: Integer;
begin
  Result := '';
  if Trim(ASchemaName) = '' then
    Exit;
  LIndex := IndexOfSchema(ASchemaName);
  if LIndex >= 0 then
    Result := Schemas[LIndex].Name;
end;

{ The dictionary and the subschemas }

function TRpLocalSchemaFile.FindTable(const AName: string): TJSONObject;
begin
  Result := FindByName(FTables, 'name', AName);
end;

function TRpLocalSchemaFile.FindColumn(const ATable,
  AColumn: string): TJSONObject;
begin
  Result := FindByName(JArr(FindTable(ATable), 'columns'), 'name', AColumn);
end;

procedure TRpLocalSchemaFile.GetColumnNames(const ATable: string;
  AList: TStrings);
var
  I: Integer;
  LColumns: TJSONArray;
begin
  AList.Clear;
  LColumns := JArr(FindTable(ATable), 'columns');
  if LColumns <> nil then
    for I := 0 to LColumns.Count - 1 do
      if (JObj(LColumns, I) <> nil) and (JStr(JObj(LColumns, I), 'name') <> '') then
        AList.Add(JStr(JObj(LColumns, I), 'name'));
end;

procedure TRpLocalSchemaFile.GetPrimaryKey(const ATable: string;
  AList: TStrings);
var
  I: Integer;
  LColumns: TJSONArray;
begin
  AList.Clear;
  LColumns := JArr(FindTable(ATable), 'columns');
  if LColumns <> nil then
    for I := 0 to LColumns.Count - 1 do
      if (JObj(LColumns, I) <> nil) and JBool(JObj(LColumns, I), 'isPrimaryKey') then
        AList.Add(JStr(JObj(LColumns, I), 'name'));
end;

procedure TRpLocalSchemaFile.GetTravelingColumns(ASchema: TRpLocalSubSchema;
  const ATable: string; AList: TStrings);
var
  I: Integer;
  LChosen, LNames: TStringList;
begin
  AList.Clear;
  if ASchema = nil then
  begin
    GetColumnNames(ATable, AList);
    Exit;
  end;
  if ASchema.Tables.IndexOf(ATable) < 0 then
    Exit;
  LChosen := TStringList.Create;
  LNames := TStringList.Create;
  try
    if not ASchema.GetColumns(ATable, LChosen) then
      GetPrimaryKey(ATable, LChosen);
    GetColumnNames(ATable, LNames);
    for I := 0 to LNames.Count - 1 do
      if LChosen.IndexOf(LNames[I]) >= 0 then
        AList.Add(LNames[I]);
  finally
    LNames.Free;
    LChosen.Free;
  end;
end;

function TRpLocalSchemaFile.ColumnTravels(ASchema: TRpLocalSubSchema;
  const ATable, AColumn: string): Boolean;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    GetTravelingColumns(ASchema, ATable, LList);
    Result := LList.IndexOf(AColumn) >= 0;
  finally
    LList.Free;
  end;
end;

procedure TRpLocalSchemaFile.SetColumnChosen(ASchema: TRpLocalSubSchema;
  const ATable, AColumn: string; AChosen: Boolean);
var
  I: Integer;
  LChosen, LNames, LResult: TStringList;
begin
  if (ASchema = nil) or (ASchema.Tables.IndexOf(ATable) < 0) then
    Exit;
  LChosen := TStringList.Create;
  LNames := TStringList.Create;
  LResult := TStringList.Create;
  try
    GetTravelingColumns(ASchema, ATable, LChosen);
    if AChosen then
      LChosen.Add(AColumn)
    else
      while LChosen.IndexOf(AColumn) >= 0 do
        LChosen.Delete(LChosen.IndexOf(AColumn));
    // In the order of the catalog, as the catalog spells them
    GetColumnNames(ATable, LNames);
    for I := 0 to LNames.Count - 1 do
      if LChosen.IndexOf(LNames[I]) >= 0 then
        LResult.Add(LNames[I]);
    ASchema.SetColumns(ASchema.Tables[ASchema.Tables.IndexOf(ATable)], LResult);
  finally
    LResult.Free;
    LNames.Free;
    LChosen.Free;
  end;
end;

procedure TRpLocalSchemaFile.AddSchemaTable(ASchema: TRpLocalSubSchema;
  const ATable: string);
var
  LName: string;
  LKey: TStringList;
begin
  if (ASchema = nil) or (Trim(ATable) = '') or
    (ASchema.Tables.IndexOf(ATable) >= 0) then
    Exit;
  LName := JStr(FindTable(ATable), 'name');
  if LName = '' then
    LName := Trim(ATable);
  ASchema.Tables.Add(LName);
  LKey := TStringList.Create;
  try
    GetPrimaryKey(LName, LKey);
    ASchema.SetColumns(LName, LKey);
  finally
    LKey.Free;
  end;
end;

procedure TRpLocalSchemaFile.RemoveSchemaTable(ASchema: TRpLocalSubSchema;
  const ATable: string);
begin
  if ASchema = nil then
    Exit;
  while ASchema.Tables.IndexOf(ATable) >= 0 do
    ASchema.Tables.Delete(ASchema.Tables.IndexOf(ATable));
  ASchema.SetColumns(ATable, nil);
end;

function TRpLocalSchemaFile.DuplicateSchema(AIndex: Integer;
  const ANewName: string): TRpLocalSubSchema;
var
  LSource: TRpLocalSubSchema;
begin
  LSource := Schemas[AIndex];
  Result := AddSchema(ANewName);
  Result.Description := LSource.Description;
  Result.Tables.Assign(LSource.Tables);
  Result.FColumns.Free;
  Result.FColumns := TJSONObject(LSource.FColumns.Clone);
  Result.FExtra.Free;
  Result.FExtra := TJSONObject(LSource.FExtra.Clone);
end;

procedure TRpLocalSchemaFile.RenameSchema(AIndex: Integer;
  const ANewName: string);
var
  LOther: Integer;
begin
  if Trim(ANewName) = '' then
    raise Exception.Create('A subschema needs a name');
  LOther := IndexOfSchema(ANewName);
  if (LOther >= 0) and (LOther <> AIndex) then
    raise Exception.Create('The subschema already exists: ' + Trim(ANewName));
  Schemas[AIndex].Name := Trim(ANewName);
end;

procedure TRpLocalSchemaFile.GetSchemasWithColumn(const ATable,
  AColumn: string; AExclude: TRpLocalSubSchema; AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to SchemaCount - 1 do
    if (Schemas[I] <> AExclude) and ColumnTravels(Schemas[I], ATable, AColumn) then
      AList.Add(Schemas[I].Name);
end;

procedure TRpLocalSchemaFile.SetTableContext(const ATable, AText: string);
var
  LTable: TJSONObject;
begin
  LTable := FindTable(ATable);
  if LTable <> nil then
    SetPair(LTable, 'context', TJSONString.Create(AText));
end;

procedure TRpLocalSchemaFile.SetColumnContext(const ATable, AColumn,
  AText: string);
var
  LColumn: TJSONObject;
begin
  LColumn := FindColumn(ATable, AColumn);
  if LColumn <> nil then
    SetPair(LColumn, 'context', TJSONString.Create(AText));
end;

procedure TRpLocalSchemaFile.GetAllowedValues(const ATable, AColumn: string;
  AValues, ALabels: TStrings);
var
  I: Integer;
  LValues: TJSONArray;
begin
  AValues.Clear;
  ALabels.Clear;
  LValues := JArr(FindColumn(ATable, AColumn), 'allowedValues');
  if LValues <> nil then
    for I := 0 to LValues.Count - 1 do
      if JObj(LValues, I) <> nil then
      begin
        AValues.Add(JStr(JObj(LValues, I), 'value'));
        ALabels.Add(JStr(JObj(LValues, I), 'label'));
      end;
end;

procedure TRpLocalSchemaFile.SetAllowedValues(const ATable, AColumn: string;
  AValues, ALabels: TStrings);
var
  I, J: Integer;
  LColumn, LItem, LOldItem: TJSONObject;
  LLabel, LValue: string;
  LNew, LOld: TJSONArray;
begin
  LColumn := FindColumn(ATable, AColumn);
  if LColumn = nil then
    Exit;
  LOld := JArr(LColumn, 'allowedValues');
  LNew := TJSONArray.Create;
  try
    for I := 0 to AValues.Count - 1 do
    begin
      LValue := AValues[I];
      LLabel := '';
      if I < ALabels.Count then
        LLabel := ALabels[I];
      if (Trim(LValue) = '') and (Trim(LLabel) = '') then
        Continue;
      LOldItem := nil;
      if LOld <> nil then
        for J := 0 to LOld.Count - 1 do
          if (JObj(LOld, J) <> nil) and (JStr(JObj(LOld, J), 'value') = LValue) then
          begin
            LOldItem := JObj(LOld, J);
            Break;
          end;
      if LOldItem <> nil then
        LItem := TJSONObject(LOldItem.Clone)
      else
        LItem := TJSONObject.Create;
      SetPair(LItem, 'value', TJSONString.Create(LValue));
      SetPair(LItem, 'label', TJSONString.Create(LLabel));
      LNew.AddElement(LItem);
    end;
  except
    LNew.Free;
    raise;
  end;
  if LNew.Count = 0 then
  begin
    LNew.Free;
    LColumn.RemovePair('allowedValues').Free;
  end
  else
    SetPair(LColumn, 'allowedValues', LNew);
end;

function RelationEndTravels(AFile: TRpLocalSchemaFile;
  ASchema: TRpLocalSubSchema; const ATable: string; AColumns: TJSONArray): Boolean;
var
  I: Integer;
  LTraveling: TStringList;
begin
  LTraveling := TStringList.Create;
  try
    AFile.GetTravelingColumns(ASchema, ATable, LTraveling);
    Result := (AFile.FindTable(ATable) <> nil) and (AColumns <> nil) and
      (AColumns.Count > 0);
    if Result then
      for I := 0 to AColumns.Count - 1 do
        if (AColumns.Items[I] = nil) or
          (LTraveling.IndexOf(AColumns.Items[I].Value) < 0) then
          Exit(False);
  finally
    LTraveling.Free;
  end;
end;

function TRpLocalSchemaFile.ForeignKeyTravels(ASchema: TRpLocalSubSchema;
  const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
begin
  Result := (AForeignKey <> nil) and ((ASchema = nil) or (
    RelationEndTravels(Self, ASchema, ASourceTable, JArr(AForeignKey, 'sourceColumns')) and
    RelationEndTravels(Self, ASchema, JStr(AForeignKey, 'targetTable'),
    JArr(AForeignKey, 'targetColumns'))));
end;

procedure TRpLocalSchemaFile.GetRelations(ASchema: TRpLocalSubSchema;
  AList: TObjectList);
var
  I, J: Integer;
  LForeignKeys: TJSONArray;
  LItem, LTable: TJSONObject;
  LRelation: TRpLocalRelation;
begin
  for I := 0 to FTables.Count - 1 do
  begin
    LTable := JObj(FTables, I);
    if (LTable = nil) or ((ASchema <> nil) and
      (ASchema.Tables.IndexOf(JStr(LTable, 'name')) < 0)) then
      Continue;
    LForeignKeys := JArr(LTable, 'foreignKeys');
    if LForeignKeys = nil then
      Continue;
    for J := 0 to LForeignKeys.Count - 1 do
    begin
      LItem := JObj(LForeignKeys, J);
      if not ForeignKeyTravels(ASchema, JStr(LTable, 'name'), LItem) then
        Continue;
      LRelation := TRpLocalRelation.Create;
      LRelation.SourceTable := JStr(LTable, 'name');
      LRelation.ForeignKey := LItem;
      AList.Add(LRelation);
    end;
  end;
end;

procedure TRpLocalSchemaFile.GetSuggestedRelations(ASchema: TRpLocalSubSchema;
  AList: TObjectList);
var
  I, J: Integer;
  LForeignKeys: TJSONArray;
  LItem, LTable: TJSONObject;
  LRelation: TRpLocalRelation;
begin
  if ASchema = nil then
    Exit;
  for I := 0 to FTables.Count - 1 do
  begin
    LTable := JObj(FTables, I);
    if (LTable = nil) or (ASchema.Tables.IndexOf(JStr(LTable, 'name')) < 0) then
      Continue;
    LForeignKeys := JArr(LTable, 'foreignKeys');
    if LForeignKeys = nil then
      Continue;
    for J := 0 to LForeignKeys.Count - 1 do
    begin
      LItem := JObj(LForeignKeys, J);
      if (LItem = nil) or (FindTable(JStr(LItem, 'targetTable')) = nil) or
        ForeignKeyTravels(ASchema, JStr(LTable, 'name'), LItem) then
        Continue;
      LRelation := TRpLocalRelation.Create;
      LRelation.SourceTable := JStr(LTable, 'name');
      LRelation.ForeignKey := LItem;
      AList.Add(LRelation);
    end;
  end;
end;

procedure TRpLocalSchemaFile.CompleteRelation(ASchema: TRpLocalSubSchema;
  ARelation: TRpLocalRelation);
var
  I: Integer;
  LNames: TStringList;
  LTarget: string;
begin
  if (ASchema = nil) or (ARelation = nil) then
    Exit;
  LTarget := JStr(FindTable(ARelation.TargetTable), 'name');
  if LTarget = '' then
    Exit;
  AddSchemaTable(ASchema, ARelation.SourceTable);
  AddSchemaTable(ASchema, LTarget);
  LNames := TStringList.Create;
  try
    ARelation.GetTargetColumns(LNames);
    for I := 0 to LNames.Count - 1 do
      SetColumnChosen(ASchema, LTarget, LNames[I], True);
    ARelation.GetSourceColumns(LNames);
    for I := 0 to LNames.Count - 1 do
      SetColumnChosen(ASchema, ARelation.SourceTable, LNames[I], True);
  finally
    LNames.Free;
  end;
end;

function TRpLocalSchemaFile.AddRelation(const ASourceTable,
  ATargetTable: string; ASourceColumns, ATargetColumns: TStrings;
  const AContext: string): TJSONObject;
var
  LSourceTable, LTargetTable: TJSONObject;
  LSource, LTarget, LForeignKeys: TJSONArray;
begin
  LSourceTable := FindTable(ASourceTable);
  LTargetTable := FindTable(ATargetTable);
  if (LSourceTable = nil) or (LTargetTable = nil) then
    raise Exception.Create('The relation needs two tables of the catalog');
  if (ASourceColumns.Count = 0) or (ASourceColumns.Count <> ATargetColumns.Count) then
    raise Exception.Create('The relation needs pairs of columns');
  LSource := TJSONArray.Create;
  LTarget := TJSONArray.Create;
  try
    if not SpellColumns(LSourceTable, ASourceColumns, LSource) or
      not SpellColumns(LTargetTable, ATargetColumns, LTarget) then
      raise Exception.Create('A column of the relation is not in its table');
    // A relation that is there already is not written twice: what the
    // person wrote goes to it
    Result := FindRelation(LSourceTable, JStr(LTargetTable, 'name'), LSource, LTarget);
    if Result <> nil then
    begin
      if Trim(AContext) <> '' then
        SetPair(Result, 'relationshipContext', TJSONString.Create(AContext));
      Exit;
    end;
    Result := TJSONObject.Create;
    Result.AddPair('constraintName', '');
    Result.AddPair('targetTable', JStr(LTargetTable, 'name'));
    Result.AddPair('sourceColumns', LSource);
    LSource := nil;
    Result.AddPair('targetColumns', LTarget);
    LTarget := nil;
    Result.AddPair('relationshipContext', AContext);
  finally
    LTarget.Free;
    LSource.Free;
  end;
  LForeignKeys := JArr(LSourceTable, 'foreignKeys');
  if LForeignKeys = nil then
  begin
    LForeignKeys := TJSONArray.Create;
    SetPair(LSourceTable, 'foreignKeys', LForeignKeys);
  end;
  LForeignKeys.AddElement(Result);
end;

procedure TRpLocalSchemaFile.DeleteRelation(ARelation: TRpLocalRelation);
var
  I: Integer;
  LForeignKeys: TJSONArray;
begin
  if (ARelation = nil) or not ARelation.IsManual then
    Exit;
  LForeignKeys := JArr(FindTable(ARelation.SourceTable), 'foreignKeys');
  if LForeignKeys = nil then
    Exit;
  for I := 0 to LForeignKeys.Count - 1 do
    if LForeignKeys.Items[I] = ARelation.ForeignKey then
    begin
      LForeignKeys.Remove(I).Free;
      ARelation.ForeignKey := nil;
      Exit;
    end;
end;

{ TRpLocalRelation }

function TRpLocalRelation.TargetTable: string;
begin
  Result := JStr(ForeignKey, 'targetTable');
end;

procedure TRpLocalRelation.GetSourceColumns(AList: TStrings);
begin
  ArrayNames(JArr(ForeignKey, 'sourceColumns'), AList);
end;

procedure TRpLocalRelation.GetTargetColumns(AList: TStrings);
begin
  ArrayNames(JArr(ForeignKey, 'targetColumns'), AList);
end;

function JoinNames(AArray: TJSONArray): string;
var
  I: Integer;
begin
  Result := '';
  if AArray <> nil then
    for I := 0 to AArray.Count - 1 do
      if AArray.Items[I] <> nil then
      begin
        if Result <> '' then
          Result := Result + ', ';
        Result := Result + AArray.Items[I].Value;
      end;
end;

function TRpLocalRelation.SourceColumnsText: string;
begin
  Result := JoinNames(JArr(ForeignKey, 'sourceColumns'));
end;

function TRpLocalRelation.TargetColumnsText: string;
begin
  Result := JoinNames(JArr(ForeignKey, 'targetColumns'));
end;

function TRpLocalRelation.IsManual: Boolean;
begin
  Result := (ForeignKey <> nil) and (Trim(JStr(ForeignKey, 'constraintName')) = '');
end;

function TRpLocalRelation.Context: string;
begin
  Result := JStr(ForeignKey, 'relationshipContext');
end;

procedure TRpLocalRelation.SetContext(const AText: string);
begin
  if ForeignKey <> nil then
    SetPair(ForeignKey, 'relationshipContext', TJSONString.Create(AText));
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
    procedure ReadComments(const ATableSql, AColumnSql: string);
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

// The comments of the tables and columns that have no context yet (the
// starting description); a catalog that can not be read leaves them empty
procedure TRpCatalogReader.ReadComments(const ATableSql, AColumnSql: string);
var
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  try
    LData := Open(ATableSql);
    try
      while not LData.Eof do
      begin
        LTable := FCatalog.Find(FieldText(LData, 0));
        if (LTable <> nil) and (LTable.Context = '') then
          LTable.Context := FieldText(LData, 1);
        LData.Next;
      end;
    finally
      LData.Free;
    end;
  except
    // Without permission to read the comments the schema goes without them
  end;
  try
    LData := Open(AColumnSql);
    try
      while not LData.Eof do
      begin
        LTable := FCatalog.Find(FieldText(LData, 0));
        if LTable <> nil then
        begin
          LColumn := LTable.FindColumn(FieldText(LData, 1));
          if (LColumn <> nil) and (LColumn.Context = '') then
            LColumn.Context := FieldText(LData, 2);
        end;
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
  // MySQL gave its comments with the tables and columns
  case FFamily of
    rcfPostgreSQL:
      ReadComments('SELECT c.relname, obj_description(c.oid, ''pg_class'') ' +
        'FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace ' +
        'WHERE c.relkind IN (''r'', ''v'', ''m'', ''p'', ''f'') ' +
        'AND n.nspname NOT IN (''pg_catalog'', ''information_schema'') ' +
        'AND obj_description(c.oid, ''pg_class'') IS NOT NULL',
        'SELECT c.relname, a.attname, col_description(c.oid, a.attnum) ' +
        'FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace ' +
        'JOIN pg_attribute a ON a.attrelid = c.oid ' +
        'WHERE a.attnum > 0 AND NOT a.attisdropped ' +
        'AND n.nspname NOT IN (''pg_catalog'', ''information_schema'') ' +
        'AND col_description(c.oid, a.attnum) IS NOT NULL');
    rcfSQLServer:
      ReadComments('SELECT o.name, CAST(ep.value AS nvarchar(4000)) ' +
        'FROM sys.extended_properties ep JOIN sys.objects o ON o.object_id = ep.major_id ' +
        'WHERE ep.class = 1 AND ep.minor_id = 0 AND ep.name = ''MS_Description''',
        'SELECT o.name, c.name, CAST(ep.value AS nvarchar(4000)) ' +
        'FROM sys.extended_properties ep JOIN sys.objects o ON o.object_id = ep.major_id ' +
        'JOIN sys.columns c ON c.object_id = ep.major_id AND c.column_id = ep.minor_id ' +
        'WHERE ep.class = 1 AND ep.minor_id > 0 AND ep.name = ''MS_Description''');
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
  ReadComments('SELECT TABLE_NAME, COMMENTS FROM USER_TAB_COMMENTS ' +
    'WHERE COMMENTS IS NOT NULL',
    'SELECT TABLE_NAME, COLUMN_NAME, COMMENTS FROM USER_COL_COMMENTS ' +
    'WHERE COMMENTS IS NOT NULL');
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

function RpExistingLocalSubSchema(ADatabase: TRpDatabaseInfoItem;
  const ASchemaName: string): string;
var
  I: Integer;
  LNames: TStringList;
begin
  Result := '';
  if Trim(ASchemaName) = '' then
    Exit;
  LNames := TStringList.Create;
  try
    RpListLocalSubSchemas(ADatabase, LNames);
    for I := 0 to LNames.Count - 1 do
      if SameText(LNames[I], Trim(ASchemaName)) then
        Exit(LNames[I]);
  finally
    LNames.Free;
  end;
end;

procedure RpListLocalSchemaEntries(ADatabase: TRpDatabaseInfoItem;
  AEntries, ASizes: TStrings);

  procedure AddEntry(const ASchemaName, ASize: string);
  begin
    AEntries.Add(ADatabase.Alias + '=' + ASchemaName);
    if ASizes <> nil then
      ASizes.Add(ASize);
  end;

  function SizeText(AFile: TRpLocalSchemaFile; const ASchemaName: string): string;
  var
    LTables, LWidest: Integer;
  begin
    AFile.GetSchemaSize(ASchemaName, LTables, LWidest);
    Result := IntToStr(LTables) + ',' + IntToStr(LWidest);
  end;

var
  I: Integer;
  LFile: TRpLocalSchemaFile;
begin
  if not RpIsLocalSqlDatabase(ADatabase) then
    Exit;
  try
    LFile := RpLoadLocalSchema(ADatabase, nil, False, False);
  except
    // A file that can not be read lists all the tables only
    LFile := nil;
  end;
  if LFile = nil then
  begin
    AddEntry('', '');
    Exit;
  end;
  try
    AddEntry('', SizeText(LFile, ''));
    for I := 0 to LFile.SchemaCount - 1 do
      AddEntry(LFile.Schemas[I].Name, SizeText(LFile, LFile.Schemas[I].Name));
  finally
    LFile.Free;
  end;
end;

procedure RpSchemaTablesSize(ATables: TJSONArray; out ATableCount,
  AWidestColumns: Integer);
var
  I: Integer;
  LColumns: TJSONArray;
  LTable: TJSONObject;
begin
  ATableCount := 0;
  AWidestColumns := 0;
  if ATables = nil then
    Exit;
  for I := 0 to ATables.Count - 1 do
  begin
    LTable := JObj(ATables, I);
    if LTable = nil then
      Continue;
    Inc(ATableCount);
    LColumns := JArr(LTable, 'columns');
    if LColumns = nil then
      LColumns := JArr(LTable, 'Columns');
    if (LColumns <> nil) and (LColumns.Count > AWidestColumns) then
      AWidestColumns := LColumns.Count;
  end;
end;

function RpLocalSchemaPreviewSql(const ADialect, ATable: string;
  ARows: Integer): string;
var
  LDialect: string;
begin
  LDialect := LowerCase(ADialect);
  if Pos('firebird', LDialect) = 1 then
    Result := 'SELECT FIRST ' + IntToStr(ARows) + ' * FROM ' + ATable
  else if (LDialect = 'sqlserver') or (Pos('mssql', LDialect) = 1) then
    Result := 'SELECT TOP ' + IntToStr(ARows) + ' * FROM ' + ATable
  else if (LDialect = 'postgresql') or (LDialect = 'mysql') or
    (LDialect = 'sqlite') or (LDialect = 'mariadb') then
    Result := 'SELECT * FROM ' + ATable + ' LIMIT ' + IntToStr(ARows)
  else if LDialect = 'oracle' then
    Result := 'SELECT * FROM ' + ATable + ' WHERE ROWNUM <= ' + IntToStr(ARows)
  else
    Result := 'SELECT * FROM ' + ATable;
end;

end.

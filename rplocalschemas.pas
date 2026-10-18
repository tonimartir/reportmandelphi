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
      "columns": { "SALES": ["SALEID", "TOTAL"] },
      "excludedRelations": [ { "sourceTable", "sourceColumns",
        "targetTable", "targetColumns" } ] } ],
    "excludedRelations": [...]
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
  - "excludedRelations" (optional, still version 2, written only when it is
    not empty) are the relations the user deleted or discarded: in a
    subschema, the ones left out of it (the dictionary keeps them); at the
    root, the ones of the database left out of every subschema (deleted in
    "All the tables"). An entry is the two ends of a relation, compared
    ignoring case, the columns in the order of the foreign key. Adding the
    relation again takes it out of the list (of the subschema and of the
    root); a refresh keeps every entry one of whose tables is still there.
  - The tables of a subschema sent to the AI carry the columns it chose (its
    primary key when it chose none) and the relations whose two ends
    travel and are not excluded. Without a subschema, everything but the
    relations excluded at the root (an export of all the tables).
  - Only a subschema goes to the AI, never the whole dictionary (5.7, F8): a
    big database does not fit, and none is known to be small.
    RpSubSchemaTablesJson refuses an empty or unknown name.
  - Export and import with the Reportman AI web (5.6) use the file of its
    "Export" / "Import": { "name", "schemaTables" }, camelCase, indented.
    Exporting writes what travels of a subschema (SchemaTablesJson);
    importing makes a new subschema of what the file has that is in the
    catalog, and writes its descriptions, allowed values and relations in
    the dictionary (the old Desktop wrote PascalCase and numeric types: both
    are read). *)

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
    // The relations left out of the subschema ("excludedRelations")
    FExcluded: TJSONArray;
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
    // The relations left out of this subschema: objects { "sourceTable",
    // "sourceColumns", "targetTable", "targetColumns" }
    property ExcludedRelations: TJSONArray read FExcluded;
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
    // The relations of the database left out of every subschema (the
    // "excludedRelations" of the root)
    FExcluded: TJSONArray;
    // What this version does not know, written back as it is
    FExtra: TJSONObject;
    FFileName: string;
    FVersion: Integer;
    FGeneratedUtc: string;
    FSchemas: TObjectList;
    FTables: TJSONArray;
    // The tables by name (sorted, case insensitive), made when a table is
    // looked for: a catalog of 100.000 tables looked up one by one was
    // quadratic
    FIndex: TStringList;
    function GetSchema(Index: Integer): TRpLocalSubSchema;
    function GetSchemaCount: Integer;
    procedure TablesChanged;
    // The entries of the exclusion lists of a relation that is gone leave
    // every list (the root's and the subschemas')
    procedure ForgetExcluded(const ASourceTable: string; AForeignKey: TJSONObject);
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

    { A large catalog (more than RpLargeCatalogLimit tables): the columns of
      a table are read when it is used. A table not read yet has
      "columnsRead": false, and no columns or relations }
    // False for a table whose columns were not read (and for one that is
    // not there)
    function ColumnsRead(const ATable: string): Boolean;
    // The tables whose columns were not read
    function UnreadTableCount: Integer;
    // The tables of ANames whose columns were not read, as the file spells
    // them
    procedure GetUnreadTables(ANames, AUnread: TStrings);
    // The columns, primary key and relations read for some tables
    // (RpReadLocalSchemaColumns) go to the tables of the file that did not
    // have them, which keep their description; a table read already is not
    // touched
    procedure MergeColumns(ATables: TJSONArray);
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
    // A relation (a foreign key of ASourceTable) travels: it is not excluded
    // and its two ends do, by table and by column (always without a
    // subschema, unless the root excludes it)
    function ForeignKeyTravels(ASchema: TRpLocalSubSchema;
      const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
    // The relation is excluded: by the root (from every subschema and from
    // all the tables) or by the subschema
    function RelationExcluded(ASchema: TRpLocalSubSchema;
      const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
    // Leaves a relation out of the subschema (its excludedRelations; the
    // dictionary keeps it) or, without one, out of every subschema (the
    // excludedRelations of the root). Nothing when it is excluded already
    procedure ExcludeRelation(ASchema: TRpLocalSubSchema;
      ARelation: TRpLocalRelation);
    // An excluded relation comes back: its entries leave the list of the
    // subschema and the one of the root. True when one was there
    function IncludeRelation(ASchema: TRpLocalSubSchema;
      const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
    // The "Delete" of the relations of the screens: in a subschema the
    // relation is excluded from it; in all the tables (nil) a relation by
    // hand leaves the dictionary and one of the database is excluded from
    // every subschema
    procedure RemoveRelation(ASchema: TRpLocalSubSchema;
      ARelation: TRpLocalRelation);
    // The relations of the dictionary that travel in the subschema (all of
    // them without one, but the ones the root excludes), added to AList
    // (TRpLocalRelation, owned by the list)
    procedure GetRelations(ASchema: TRpLocalSubSchema; AList: TObjectList);
    // The relations of the tables of the subschema that do not travel, are
    // not excluded and whose target is in the dictionary, even when both
    // tables are chosen: the suggestions ("Complete")
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
    // twice: it is returned, with AContext when one is given. Added in the
    // subschema ASchema (nil: all the tables), an excluded relation with
    // those ends comes back (IncludeRelation) instead
    function AddRelation(const ASourceTable, ATargetTable: string;
      ASourceColumns, ATargetColumns: TStrings;
      const AContext: string; ASchema: TRpLocalSubSchema = nil): TJSONObject;
    // Changes a relation written by hand: its tables and its pairs of
    // columns (the ones of the database mirror it: only their description
    // changes); raises as AddRelation. It keeps its description and what it
    // had of a newer version, and the lists that excluded it exclude it with
    // its new ends. When another relation has those ends already, this one
    // leaves and the other one stays (with this description when it had
    // none). As AddRelation, an excluded relation with the new ends comes
    // back in ASchema. ARelation points to the result
    function UpdateRelation(ARelation: TRpLocalRelation;
      const ASourceTable, ATargetTable: string;
      ASourceColumns, ATargetColumns: TStrings;
      ASchema: TRpLocalSubSchema = nil): TJSONObject;
    // Removes a relation written by hand from the dictionary, and its
    // entries from the exclusion lists of the root and of every subschema
    // unless the table has another relation with the same ends (the ones of
    // the database can not be removed: they come back when it is read again)
    procedure DeleteRelation(ARelation: TRpLocalRelation);
    // The relations of the database left out of every subschema
    property ExcludedRelations: TJSONArray read FExcluded;
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
// connection, in the format of the file (connects the connection).
// With more than RpLargeCatalogLimit tables only their names (and their
// comments) are read, and the columns of the tables of AColumnsOf: the rest
// have "columnsRead": false
function RpReadLocalSchemaCatalog(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; out ADialect: string;
  AColumnsOf: TStrings = nil): TJSONArray;
// The tables whose columns a large catalog reads again: the ones of every
// subschema and the ones read already
procedure RpLocalSchemaKeepList(AFile: TRpLocalSchemaFile; AList: TStrings);
// The columns, primary keys and relations of some tables of the catalog
// (the ones it does not have are left out)
function RpReadLocalSchemaColumns(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; ATables: TStrings): TJSONArray;
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
// AEntries 'ALIAS=<subschema>' and to ASizes the size of each one,
// '<tables>,<widest columns>'. Never 'ALIAS=' (all the tables): only a
// subschema goes to the AI. Nothing while the file does not exist (it is
// not generated to list)
procedure RpListLocalSchemaEntries(ADatabase: TRpDatabaseInfoItem;
  AEntries, ASizes: TStrings);
// The message when a direct connection has no subschema for the AI (none
// chosen, or the one chosen is gone): choose one or make one (key 1984)
function RpSubSchemaRequiredMessage(const AAlias: string): string;
// What goes to the AI of the subschema ASchemaName of the file of the
// connection AAlias: its tables (SchemaTablesJson), and in ASpelledName its
// name as the file spells it. Raises RpSubSchemaRequiredMessage when the
// name is empty or not in the file: never the whole dictionary
function RpSubSchemaTablesJson(AFile: TRpLocalSchemaFile; const AAlias,
  ASchemaName: string; out ASpelledName: string): string;
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

{ Export and import with the Reportman AI web (docs/esquemas-locales-
  pantalla-plan.md 5.6): the file of "Export" and "Import" of a schema of
  the web, ( "name", "schemaTables": [...] ) }

// The name a subschema is exported with: the subschema as the file spells
// it; '' or an unknown one (all the tables), the alias
function RpExportSchemaName(AFile: TRpLocalSchemaFile;
  const ASchemaName: string): string;
// '<name>_Config.json', the file name the web gives to an export
function RpExportSchemaFileName(AFile: TRpLocalSchemaFile;
  const ASchemaName: string): string;
// The export of a subschema ('' or an unknown one: all the tables, named
// after the alias): what travels of it, as the copilot sends it
// (SchemaTablesJson), indented
function RpExportSchemaJson(AFile: TRpLocalSchemaFile;
  const ASchemaName: string): string;
procedure RpExportSchemaToFile(AFile: TRpLocalSchemaFile;
  const ASchemaName, AFileName: string);
// A schema exported by the web, by the old Desktop (PascalCase and numeric
// dataType: names are read whatever their case) or by a local schema
// screen, as a NEW subschema of AFile named after its "name" ("name 2",
// "name 3"... when it exists; without one, AFileName without its extension
// and its "_Config"):
// - the tables of the file that are in the catalog (as the catalog spells
//   them), each one with the columns of the file that are in the catalog as
//   its list (none left: its primary key); the type is the catalog's;
// - the descriptions and allowed values written in the file go to the
//   dictionary (shared by every subschema: the import wins);
// - a relation of the file whose two ends are in the catalog gives its
//   description to the one the dictionary has, or enters by hand; one
//   excluded at the root comes back (AddRelation).
// What is not in the catalog is added to ASkipped ('TABLE', 'TABLE.COLUMN').
// A table of the file is the one of the catalog with its name; else the one
// with the last part of a qualified name ('[{DB_NAME}].dbo.OINV': OINV);
// else, when that part is a template of the library ('{COMPANY_NAME}$Item',
// see RpImportPlaceholders), the one its placeholders give with the values
// of ATemplateValues ('COMPANY_NAME=CRONUS'), the first value of the catalog
// for those it does not have. When ATemplateValues is not nil it ends with
// the values used, those of the placeholders that gave some table.
// Returns the tables of the new subschema; 0, and nothing is created, when
// none of its tables is in the catalog (a schema of another database);
// -1, and nothing changes, when AJson is not a schema (not JSON or without
// schemaTables)
function RpImportSchemaJson(AFile: TRpLocalSchemaFile; const AJson,
  AFileName: string; out ANewName: string; ASkipped: TStrings;
  ATemplateValues: TStrings = nil): Integer;
function RpImportSchemaFile(AFile: TRpLocalSchemaFile;
  const AFileName: string; out ANewName: string; ASkipped: TStrings;
  ATemplateValues: TStrings = nil): Integer;
// The same import with another origin, a schema of the library of Reportman
// AI (5.7.1 C2, the fullSchema of GET api/schema/{id}): the new subschema is
// named after ALibraryName, the name of the schema in the library ("name 2"
// when it exists), not after the "name" of the JSON
function RpImportLibrarySchemaJson(AFile: TRpLocalSchemaFile; const AJson,
  ALibraryName: string; out ANewName: string; ASkipped: TStrings;
  ATemplateValues: TStrings = nil): Integer;
// The placeholders of the templates of a schema to import that tables of the
// catalog fill, in the order of the schema: the library names the tables of
// some systems with them ('[{COMPANY_NAME}$Customer]' in Dynamics BC, whose
// tables are 'CRONUS S_A_$Customer', one set per company). ANames gets their
// names ('COMPANY_NAME'); a placeholder only in a qualifier that the import
// drops ('{DB_NAME}' of '[{DB_NAME}].dbo.OINV') is not one of them
procedure RpImportPlaceholders(AFile: TRpLocalSchemaFile; const AJson: string;
  ANames: TStrings);
// The values of the catalog for one of them: the one that gives more tables
// of the schema first (then in the order they are found)
procedure RpImportPlaceholderValues(AFile: TRpLocalSchemaFile; const AJson,
  APlaceholder: string; AValues: TStrings);
// How many tables of a schema to import are in the catalog (as the import
// finds them, the templates with any value) of the ATotal it has
procedure RpImportCoverage(AFile: TRpLocalSchemaFile; const AJson: string;
  out AMatched, ATotal: Integer);
// A schema of the library with that coverage was written for this database:
// two tables at least (or its only one) and half of them
function RpImportCoverageDetected(AMatched, ATotal: Integer): Boolean;
// 'NAME=value' lines as the user reads them: '{NAME} = value, ...'
function RpTemplateValuesText(AValues: TStrings): string;
// The text of a file to import (UTF-8, with a BOM or without one)
function RpReadSchemaFile(const AFileName: string): string;
// The tables of the catalog an import would use (its tables and the
// targets of its relations, with the template values of ATemplateValues and
// the first value of the catalog for the others), as the catalog spells
// them: their columns are read before importing a large catalog
procedure RpImportTableNames(AFile: TRpLocalSchemaFile; const AJson: string;
  ATemplateValues, ANames: TStrings);

{ The filter of the lists of tables and columns: words of the name or of the
  description, in any order, without case or accents }

// A text as the filter compares it: lower case, and the accented latin
// letters (U+00C0-U+017F) as their base letter
function RpFoldText(const AText: string): string;
// The words of a filter, folded (none: everything matches)
procedure RpFilterWords(const AFilter: string; AWords: TStrings);
// Every word is in the name or in the description (both folded already)
function RpWordsMatch(AWords: TStrings; const AFoldedName,
  AFoldedContext: string): Boolean;
// The two at once, for a single item
function RpFilterMatches(const AFilter, AName, AContext: string): Boolean;

var
  // More tables than this make a large catalog
  RpLargeCatalogLimit: Integer = 5000;
// 'A, B, C, ...': the first AMax names of a list, an ellipsis for the rest
function RpShortNameList(AList: TStrings; AMax: Integer): string;

implementation

uses
  rpmdconsts, rpbasereport;

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
    // False in a large catalog for a table whose columns were not read
    ColumnsRead: Boolean;
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
    // The names of the tables of a catalog come in the order of the
    // database, not the one of the list: between these two they are only
    // added (no Find) and sorted once at the end. Inserted one by one in
    // their place, the 100.000 of a large catalog took seconds
    procedure BeginAdding;
    procedure EndAdding;
    // AOnlyWithColumns: without the tables that have no columns (the ones
    // asked for that the database does not have)
    function ToJsonArray(AOnlyWithColumns: Boolean = False): TJSONArray;
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

// A copy of an array, or an empty one
function CloneOrEmpty(AArray: TJSONArray): TJSONArray;
begin
  if AArray = nil then
    Result := TJSONArray.Create
  else
    Result := TJSONArray(AArray.Clone);
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

// The exclusion lists ("excludedRelations"): entries with "sourceTable",
// "sourceColumns", "targetTable" and "targetColumns"

// A new JSON array with the names of another one (empty without it)
function NamesArray(AArray: TJSONArray): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  if AArray <> nil then
    for I := 0 to AArray.Count - 1 do
      if AArray.Items[I] <> nil then
        Result.Add(AArray.Items[I].Value);
end;

// An entry of an exclusion list is the relation AForeignKey of ASourceTable:
// the same tables and the same columns, in order, ignoring case
function ExcludedEntryIs(AEntry: TJSONObject; const ASourceTable: string;
  AForeignKey: TJSONObject): Boolean;
begin
  Result := (AEntry <> nil) and (AForeignKey <> nil) and
    SameText(Trim(JStr(AEntry, 'sourceTable')), Trim(ASourceTable)) and
    SameText(Trim(JStr(AEntry, 'targetTable')), Trim(JStr(AForeignKey, 'targetTable'))) and
    SameNames(JArr(AEntry, 'sourceColumns'), JArr(AForeignKey, 'sourceColumns')) and
    SameNames(JArr(AEntry, 'targetColumns'), JArr(AForeignKey, 'targetColumns'));
end;

function IndexOfExcluded(AList: TJSONArray; const ASourceTable: string;
  AForeignKey: TJSONObject): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AList <> nil then
    for I := 0 to AList.Count - 1 do
      if ExcludedEntryIs(JObj(AList, I), ASourceTable, AForeignKey) then
        Exit(I);
end;

// The entries of a relation leave a list; True when one was there
function RemoveExcluded(AList: TJSONArray; const ASourceTable: string;
  AForeignKey: TJSONObject): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AList = nil then
    Exit;
  for I := AList.Count - 1 downto 0 do
    if ExcludedEntryIs(JObj(AList, I), ASourceTable, AForeignKey) then
    begin
      AList.Remove(I).Free;
      Result := True;
    end;
end;

// The ends of a relation written in AEntry (what else it has stays)
procedure SetExcludedEnds(AEntry: TJSONObject; const ASourceTable: string;
  AForeignKey: TJSONObject);
begin
  SetPair(AEntry, 'sourceTable', TJSONString.Create(ASourceTable));
  SetPair(AEntry, 'sourceColumns', NamesArray(JArr(AForeignKey, 'sourceColumns')));
  SetPair(AEntry, 'targetTable', TJSONString.Create(JStr(AForeignKey, 'targetTable')));
  SetPair(AEntry, 'targetColumns', NamesArray(JArr(AForeignKey, 'targetColumns')));
end;

// A relation changed its ends (AOldEnds has its old targetTable and
// columns): the list that excluded it excludes it with the new ones
procedure MoveExcluded(AList: TJSONArray; const AOldSource: string;
  AOldEnds: TJSONObject; const ANewSource: string; ANewForeignKey: TJSONObject);
var
  LIndex: Integer;
  LEntry: TJSONObject;
begin
  LIndex := IndexOfExcluded(AList, AOldSource, AOldEnds);
  if LIndex < 0 then
    Exit;
  // The first entry, with what it has of a newer version
  LEntry := TJSONObject(JObj(AList, LIndex).Clone);
  RemoveExcluded(AList, AOldSource, AOldEnds);
  if IndexOfExcluded(AList, ANewSource, ANewForeignKey) >= 0 then
  begin
    LEntry.Free;
    Exit;
  end;
  SetExcludedEnds(LEntry, ANewSource, ANewForeignKey);
  AList.AddElement(LEntry);
end;

// After reading the catalog again: the entries one of whose tables is still
// there stay (what is not an entry stays too)
procedure KeepExcludedOf(AList, ACatalog: TJSONArray);
var
  I: Integer;
  LEntry: TJSONObject;
begin
  for I := AList.Count - 1 downto 0 do
  begin
    LEntry := JObj(AList, I);
    if (LEntry <> nil) and
      (FindByName(ACatalog, 'name', Trim(JStr(LEntry, 'sourceTable'))) = nil) and
      (FindByName(ACatalog, 'name', Trim(JStr(LEntry, 'targetTable'))) = nil) then
      AList.Remove(I).Free;
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
  FExcluded := TJSONArray.Create;
  FExtra := TJSONObject.Create;
end;

destructor TRpLocalSubSchema.Destroy;
begin
  FTables.Free;
  FColumns.Free;
  FExcluded.Free;
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
  FExcluded := TJSONArray.Create;
  FExtra := TJSONObject.Create;
  FVersion := RP_LOCAL_SCHEMA_VERSION;
end;

destructor TRpLocalSchemaFile.Destroy;
begin
  FIndex.Free;
  FSchemas.Free;
  FTables.Free;
  FExcluded.Free;
  FExtra.Free;
  inherited Destroy;
end;

procedure TRpLocalSchemaFile.TablesChanged;
begin
  FreeAndNil(FIndex);
end;

procedure TRpLocalSchemaFile.Clear;
begin
  FSchemas.Clear;
  TablesChanged;
  FTables.Free;
  FTables := TJSONArray.Create;
  FExcluded.Free;
  FExcluded := TJSONArray.Create;
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
      'generatedUtc', 'tables', 'schemas', 'excludedRelations']);
    LArray := JArr(LObject, 'tables');
    if LArray <> nil then
    begin
      TablesChanged;
      FTables.Free;
      FTables := TJSONArray(LArray.Clone);
    end;
    LArray := JArr(LObject, 'excludedRelations');
    if LArray <> nil then
    begin
      FExcluded.Free;
      FExcluded := TJSONArray(LArray.Clone);
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
        LNames := JArr(JObj(LArray, I), 'excludedRelations');
        if LNames <> nil then
        begin
          LSchema.FExcluded.Free;
          LSchema.FExcluded := TJSONArray(LNames.Clone);
        end;
        CopyUnknown(JObj(LArray, I), LSchema.FExtra, ['name', 'description',
          'tables', 'columns', 'excludedRelations']);
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
      // Only when there are some (the readers of before do not need it)
      if Schemas[I].FExcluded.Count > 0 then
        LSchemaObject.AddPair('excludedRelations',
          TJSONArray(Schemas[I].FExcluded.Clone));
      CopyUnknown(Schemas[I].FExtra, LSchemaObject, []);
    end;
    if FExcluded.Count > 0 then
      LRoot.AddPair('excludedRelations', TJSONArray(FExcluded.Clone));
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
  I, J: Integer;
  LNewTable, LOldTable, LNewItem, LOldItem: TJSONObject;
  LNewItems, LOldItems: TJSONArray;
begin
  if ATables = nil then
    ATables := TJSONArray.Create;
  try
    for I := 0 to ATables.Count - 1 do
    begin
      LNewTable := JObj(ATables, I);
      if LNewTable = nil then
        Continue;
      LOldTable := FindTable(JStr(LNewTable, 'name'));
      if LOldTable = nil then
        Continue;
      // Read or not, as the catalog was read now
      KeepWritten(LOldTable, LNewTable, 'context', ['name', 'columns',
        'foreignKeys', 'columnsRead']);
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
  TablesChanged;
  FTables.Free;
  FTables := ATables;
  if ADialect <> '' then
    FDialect := ADialect;
  FGeneratedUtc := NowUtcIso;
  // The subschemas keep the tables that still exist, as the catalog names them
  for I := 0 to FSchemas.Count - 1 do
    for J := Schemas[I].Tables.Count - 1 downto 0 do
    begin
      LNewTable := FindTable(Schemas[I].Tables[J]);
      if LNewTable = nil then
        Schemas[I].Tables.Delete(J)
      else
        Schemas[I].Tables[J] := JStr(LNewTable, 'name');
    end;
  for I := 0 to FSchemas.Count - 1 do
    Schemas[I].KeepColumnsOf(FTables);
  // The relations deleted or discarded stay so while one of their tables is
  // there (a relation that comes back with the catalog stays out)
  KeepExcludedOf(FExcluded, FTables);
  for I := 0 to FSchemas.Count - 1 do
    KeepExcludedOf(Schemas[I].FExcluded, FTables);
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
    // All the tables, without the relations the root excludes
    if FExcluded.Count = 0 then
    begin
      Result := FTables.ToJSON;
      Exit;
    end;
    LArray := TJSONArray(FTables.Clone);
    try
      for I := 0 to LArray.Count - 1 do
      begin
        LForeignKeys := JArr(JObj(LArray, I), 'foreignKeys');
        if LForeignKeys <> nil then
          for J := LForeignKeys.Count - 1 downto 0 do
            if RelationExcluded(nil, JStr(JObj(LArray, I), 'name'),
              JObj(LForeignKeys, J)) then
              LForeignKeys.Remove(J).Free;
      end;
      Result := LArray.ToJSON;
    finally
      LArray.Free;
    end;
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
    // A relation travels when its two ends do (a column the AI does not see
    // is no use to it) and neither the subschema nor the root excludes it
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
          not RelationExcluded(Schemas[LIndex], JStr(LClone, 'name'), LItem) and
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
var
  I: Integer;
  LTable: TJSONObject;
begin
  Result := nil;
  if FIndex = nil then
  begin
    FIndex := TStringList.Create;
    FIndex.CaseSensitive := False;
    for I := 0 to FTables.Count - 1 do
    begin
      LTable := JObj(FTables, I);
      if (LTable <> nil) and (JStr(LTable, 'name') <> '') then
        FIndex.AddObject(JStr(LTable, 'name'), LTable);
    end;
    // The first of two with the same name, as FindByName found it
    FIndex.Sorted := True;
  end;
  I := FIndex.IndexOf(AName);
  if I >= 0 then
  begin
    // A sorted list with two equal names may give the second: the first
    // one in the file
    while (I > 0) and SameText(FIndex[I - 1], AName) do
      Dec(I);
    Result := TJSONObject(FIndex.Objects[I]);
    if not SameText(JStr(Result, 'name'), AName) then
      Result := FindByName(FTables, 'name', AName);
  end;
end;

function TRpLocalSchemaFile.ColumnsRead(const ATable: string): Boolean;
var
  LTable: TJSONObject;
  LValue: TJSONValue;
begin
  LTable := FindTable(ATable);
  Result := LTable <> nil;
  if not Result then
    Exit;
  LValue := LTable.Values['columnsRead'];
  Result := not ((LValue <> nil) and SameText(LValue.Value, 'false'));
end;

function TRpLocalSchemaFile.UnreadTableCount: Integer;
var
  I: Integer;
  LValue: TJSONValue;
begin
  Result := 0;
  for I := 0 to FTables.Count - 1 do
    if JObj(FTables, I) <> nil then
    begin
      LValue := JObj(FTables, I).Values['columnsRead'];
      if (LValue <> nil) and SameText(LValue.Value, 'false') then
        Inc(Result);
    end;
end;

procedure TRpLocalSchemaFile.GetUnreadTables(ANames, AUnread: TStrings);
var
  I: Integer;
  LName: string;
begin
  AUnread.Clear;
  for I := 0 to ANames.Count - 1 do
    if (FindTable(ANames[I]) <> nil) and not ColumnsRead(ANames[I]) then
    begin
      LName := JStr(FindTable(ANames[I]), 'name');
      if AUnread.IndexOf(LName) < 0 then
        AUnread.Add(LName);
    end;
end;

procedure TRpLocalSchemaFile.MergeColumns(ATables: TJSONArray);
var
  I: Integer;
  LRead, LTable: TJSONObject;
begin
  if ATables = nil then
    Exit;
  for I := 0 to ATables.Count - 1 do
  begin
    LRead := JObj(ATables, I);
    if LRead = nil then
      Continue;
    LTable := FindTable(JStr(LRead, 'name'));
    if (LTable = nil) or ColumnsRead(JStr(LTable, 'name')) then
      Continue;
    // Its description stays; a table not read has no relations by hand
    SetPair(LTable, 'columns', CloneOrEmpty(JArr(LRead, 'columns')));
    SetPair(LTable, 'foreignKeys', CloneOrEmpty(JArr(LRead, 'foreignKeys')));
    LTable.RemovePair('columnsRead').Free;
    if (Trim(JStr(LTable, 'context')) = '') and (Trim(JStr(LRead, 'context')) <> '') then
      SetPair(LTable, 'context', TJSONString.Create(JStr(LRead, 'context')));
  end;
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
  Result.FExcluded.Free;
  Result.FExcluded := TJSONArray(LSource.FExcluded.Clone);
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
  Result := (AForeignKey <> nil) and
    not RelationExcluded(ASchema, ASourceTable, AForeignKey) and ((ASchema = nil) or (
    RelationEndTravels(Self, ASchema, ASourceTable, JArr(AForeignKey, 'sourceColumns')) and
    RelationEndTravels(Self, ASchema, JStr(AForeignKey, 'targetTable'),
    JArr(AForeignKey, 'targetColumns'))));
end;

function TRpLocalSchemaFile.RelationExcluded(ASchema: TRpLocalSubSchema;
  const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
begin
  Result := (AForeignKey <> nil) and
    ((IndexOfExcluded(FExcluded, ASourceTable, AForeignKey) >= 0) or
    ((ASchema <> nil) and
    (IndexOfExcluded(ASchema.FExcluded, ASourceTable, AForeignKey) >= 0)));
end;

procedure TRpLocalSchemaFile.ExcludeRelation(ASchema: TRpLocalSubSchema;
  ARelation: TRpLocalRelation);
var
  LList: TJSONArray;
  LEntry: TJSONObject;
  LSource: string;
begin
  if (ARelation = nil) or (ARelation.ForeignKey = nil) then
    Exit;
  if ASchema <> nil then
    LList := ASchema.FExcluded
  else
    LList := FExcluded;
  // As the dictionary spells the table
  LSource := JStr(FindTable(ARelation.SourceTable), 'name');
  if LSource = '' then
    LSource := ARelation.SourceTable;
  if IndexOfExcluded(LList, LSource, ARelation.ForeignKey) >= 0 then
    Exit;
  LEntry := TJSONObject.Create;
  SetExcludedEnds(LEntry, LSource, ARelation.ForeignKey);
  LList.AddElement(LEntry);
end;

function TRpLocalSchemaFile.IncludeRelation(ASchema: TRpLocalSubSchema;
  const ASourceTable: string; AForeignKey: TJSONObject): Boolean;
begin
  Result := RemoveExcluded(FExcluded, ASourceTable, AForeignKey);
  if (ASchema <> nil) and RemoveExcluded(ASchema.FExcluded, ASourceTable,
    AForeignKey) then
    Result := True;
end;

procedure TRpLocalSchemaFile.ForgetExcluded(const ASourceTable: string;
  AForeignKey: TJSONObject);
var
  I: Integer;
begin
  RemoveExcluded(FExcluded, ASourceTable, AForeignKey);
  for I := 0 to SchemaCount - 1 do
    RemoveExcluded(Schemas[I].FExcluded, ASourceTable, AForeignKey);
end;

procedure TRpLocalSchemaFile.RemoveRelation(ASchema: TRpLocalSubSchema;
  ARelation: TRpLocalRelation);
begin
  if (ARelation = nil) or (ARelation.ForeignKey = nil) then
    Exit;
  // In a subschema it leaves the subschema: the dictionary keeps it for the
  // others. In all the tables one by hand is deleted; the database would
  // bring one of its own back with a refresh, so it is excluded everywhere
  if ASchema <> nil then
    ExcludeRelation(ASchema, ARelation)
  else if ARelation.IsManual then
    DeleteRelation(ARelation)
  else
    ExcludeRelation(nil, ARelation);
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
      // Not the ones deleted or discarded
      if (LItem = nil) or (FindTable(JStr(LItem, 'targetTable')) = nil) or
        RelationExcluded(ASchema, JStr(LTable, 'name'), LItem) or
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
  const AContext: string; ASchema: TRpLocalSubSchema): TJSONObject;
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
      // Deleted or discarded before: it comes back
      IncludeRelation(ASchema, JStr(LSourceTable, 'name'), Result);
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
  // An entry left of one with these ends (a relation of the database gone
  // with a refresh) does not exclude the new one
  IncludeRelation(ASchema, JStr(LSourceTable, 'name'), Result);
end;

function TRpLocalSchemaFile.UpdateRelation(ARelation: TRpLocalRelation;
  const ASourceTable, ATargetTable: string; ASourceColumns,
  ATargetColumns: TStrings; ASchema: TRpLocalSubSchema): TJSONObject;
var
  I: Integer;
  LNewSource, LOldSource: string;
  LOldEnds, LOther, LSourceTable, LTargetTable: TJSONObject;
  LForeignKeys, LSource, LTarget: TJSONArray;
begin
  if (ARelation = nil) or not ARelation.IsManual then
    raise Exception.Create('Only a relation written by hand can be changed');
  LSourceTable := FindTable(ASourceTable);
  LTargetTable := FindTable(ATargetTable);
  if (LSourceTable = nil) or (LTargetTable = nil) then
    raise Exception.Create('The relation needs two tables of the catalog');
  if (ASourceColumns.Count = 0) or (ASourceColumns.Count <> ATargetColumns.Count) then
    raise Exception.Create('The relation needs pairs of columns');
  LOldSource := ARelation.SourceTable;
  LNewSource := JStr(LSourceTable, 'name');
  LSource := TJSONArray.Create;
  LTarget := TJSONArray.Create;
  // Its old ends, for the exclusion lists
  LOldEnds := TJSONObject.Create;
  try
    if not SpellColumns(LSourceTable, ASourceColumns, LSource) or
      not SpellColumns(LTargetTable, ATargetColumns, LTarget) then
      raise Exception.Create('A column of the relation is not in its table');
    SetExcludedEnds(LOldEnds, LOldSource, ARelation.ForeignKey);
    LOther := FindRelation(LSourceTable, JStr(LTargetTable, 'name'), LSource, LTarget);
    if (LOther <> nil) and (LOther <> ARelation.ForeignKey) then
    begin
      // Another relation has those ends: it stays, with this description
      // when it has none, and this one leaves
      if (Trim(JStr(LOther, 'relationshipContext')) = '') and
        (Trim(ARelation.Context) <> '') then
        SetPair(LOther, 'relationshipContext', TJSONString.Create(ARelation.Context));
      DeleteRelation(ARelation);
      ARelation.SourceTable := LNewSource;
      ARelation.ForeignKey := LOther;
    end
    else if LOther = nil then
    begin
      // Another source table: the foreign key moves to it (not freed)
      if not SameText(LOldSource, LNewSource) then
      begin
        LForeignKeys := JArr(FindTable(LOldSource), 'foreignKeys');
        if LForeignKeys <> nil then
          for I := LForeignKeys.Count - 1 downto 0 do
            if LForeignKeys.Items[I] = ARelation.ForeignKey then
              LForeignKeys.Remove(I);
        LForeignKeys := JArr(LSourceTable, 'foreignKeys');
        if LForeignKeys = nil then
        begin
          LForeignKeys := TJSONArray.Create;
          SetPair(LSourceTable, 'foreignKeys', LForeignKeys);
        end;
        LForeignKeys.AddElement(ARelation.ForeignKey);
      end;
      SetPair(ARelation.ForeignKey, 'targetTable',
        TJSONString.Create(JStr(LTargetTable, 'name')));
      SetPair(ARelation.ForeignKey, 'sourceColumns', LSource);
      LSource := nil;
      SetPair(ARelation.ForeignKey, 'targetColumns', LTarget);
      LTarget := nil;
      ARelation.SourceTable := LNewSource;
      // Where it was excluded it stays excluded, with its new ends
      MoveExcluded(FExcluded, LOldSource, LOldEnds, LNewSource, ARelation.ForeignKey);
      for I := 0 to SchemaCount - 1 do
        MoveExcluded(Schemas[I].FExcluded, LOldSource, LOldEnds, LNewSource,
          ARelation.ForeignKey);
    end;
    // The same ends: nothing changes
    Result := ARelation.ForeignKey;
    // As adding it: excluded with those ends, it comes back where it is edited
    IncludeRelation(ASchema, ARelation.SourceTable, Result);
  finally
    LOldEnds.Free;
    LTarget.Free;
    LSource.Free;
  end;
end;

procedure TRpLocalSchemaFile.DeleteRelation(ARelation: TRpLocalRelation);
var
  I: Integer;
  LForeignKeys: TJSONArray;
  LTable: TJSONObject;
  LRemoved: TJSONValue;
begin
  if (ARelation = nil) or not ARelation.IsManual then
    Exit;
  LTable := FindTable(ARelation.SourceTable);
  LForeignKeys := JArr(LTable, 'foreignKeys');
  if LForeignKeys = nil then
    Exit;
  for I := 0 to LForeignKeys.Count - 1 do
    if LForeignKeys.Items[I] = ARelation.ForeignKey then
    begin
      LRemoved := LForeignKeys.Remove(I);
      try
        // Gone from the dictionary, gone from the lists that excluded it,
        // unless the table has another relation with the same ends
        if FindRelation(LTable, JStr(ARelation.ForeignKey, 'targetTable'),
          JArr(ARelation.ForeignKey, 'sourceColumns'),
          JArr(ARelation.ForeignKey, 'targetColumns')) = nil then
          ForgetExcluded(ARelation.SourceTable, ARelation.ForeignKey);
      finally
        LRemoved.Free;
      end;
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
  ColumnsRead := True;
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
  if FList.Sorted then
  begin
    Result := Find(AName);
    if Result <> nil then
      Exit;
  end;
  Result := TRpCatTable.Create;
  Result.Name := AName;
  FList.AddObject(AName, Result);
end;

procedure TRpCatalog.BeginAdding;
begin
  FList.Sorted := False;
end;

procedure TRpCatalog.EndAdding;
var
  I: Integer;
begin
  FList.Sorted := True;
  // A name twice (a table and a view of the same name): the first one
  for I := FList.Count - 1 downto 1 do
    if AnsiCompareText(FList[I], FList[I - 1]) = 0 then
      FList.Delete(I);
end;

function TRpCatalog.ToJsonArray(AOnlyWithColumns: Boolean): TJSONArray;
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
    if AOnlyWithColumns and (LTable.Columns.Count = 0) then
      Continue;
    LTableObject := TJSONObject.Create;
    Result.AddElement(LTableObject);
    LTableObject.AddPair('name', LTable.Name);
    LTableObject.AddPair('context', LTable.Context);
    if not LTable.ColumnsRead then
      LTableObject.AddPair('columnsRead', TJSONBool.Create(False));
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

// The parameters the connection opens with: those of the connections file
// (LoadParams), and over them the ones the report gives it,
// DBPARAM_<name> and <ALIAS>_DBPARAM_<name>, as TRpDatabaseInfoItem.Connect
// applies them. A connection that lives in the report (LoadParams False:
// the sample reports, DBPARAM_DRIVERID=SQLite) has only these.
procedure GetDatabaseParams(ADatabase: TRpDatabaseInfoItem; AParams: TStrings;
  AReportParams: TRpParamList = nil);
var
  I: Integer;
  LName, LPrefix: string;
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
  if (AReportParams = nil) and (ADatabase.Collection is TRpDatabaseInfoList) and
    (TRpDatabaseInfoList(ADatabase.Collection).Report is TRpBaseReport) then
    AReportParams := TRpBaseReport(TRpDatabaseInfoList(ADatabase.Collection).Report).Params;
  if AReportParams = nil then
    Exit;
  LPrefix := ADatabase.Alias + '_DBPARAM_';
  for I := 0 to AReportParams.Count - 1 do
  begin
    LName := AReportParams.Items[I].Name;
    if Copy(LName, 1, 8) = 'DBPARAM_' then
      AParams.Values[Copy(LName, 9, Length(LName))] := AReportParams.Items[I].AsString
    else if Copy(LName, 1, Length(LPrefix)) = LPrefix then
      AParams.Values[Copy(LName, Length(LPrefix) + 1, Length(LName))] :=
        AReportParams.Items[I].AsString;
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

function FamilyOf(ADatabase: TRpDatabaseInfoItem;
  AReportParams: TRpParamList = nil): TRpCatalogFamily;
var
  LParams: TStringList;
  LText: string;
begin
  Result := rcfGeneric;
  if ADatabase = nil then
    Exit;
  LParams := TStringList.Create;
  try
    GetDatabaseParams(ADatabase, LParams, AReportParams);
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
  // The catalog of a connection: the names of its tables first, then the
  // columns, keys and comments of all of them or (a large catalog, or the
  // columns asked for) of some, with queries filtered by those tables
  TRpCatalogReader = class(TObject)
  private
    FCatalog: TRpCatalog;
    FDatabase: TRpDatabaseInfoItem;
    FFamily: TRpCatalogFamily;
    FParams: TRpParamList;
    // ' IN (...)' of the tables whose columns are read now ('': all)
    FIn: string;
    function Open(const ASql: string): TDataSet;
    function FieldText(AData: TDataSet; AIndex: Integer): string;
    function FieldInt(AData: TDataSet; AIndex: Integer): Integer;
    function InFilter(const AColumn: string; AWhere: Boolean = False): string;
    procedure AddForeignKey(const ATable, AConstraint, ATarget, ASource,
      ATargetColumn: string);
    procedure SetPrimaryKey(const ATable, AColumn: string);
    function FirebirdDialect: string;
    procedure ReadFirebirdTables;
    procedure ReadFirebirdColumns;
    procedure ReadInformationSchemaTables;
    procedure ReadInformationSchemaColumns;
    procedure ReadSQLiteTables;
    procedure ReadSQLiteColumns(ANames: TStrings);
    function OpenSQLitePragma(const APragma, AQuotedTable, AColumns,
      AOrder: string): TDataSet;
    procedure ReadOracleTables;
    procedure ReadOracleColumns;
    procedure ReadGenericTables;
    procedure ReadGenericColumns(ANames: TStrings);
    procedure ReadTableComments(const ASql: string);
    procedure ReadColumnComments(const ASql: string);
    procedure ReadTables;
    procedure ReadColumns(ANames: TStrings);
    function ColumnsToRead(AColumnsOf: TStrings): TStringList;
    procedure Connect(out ADialect: string);
  public
    constructor Create(ADatabase: TRpDatabaseInfoItem; AParams: TRpParamList);
    destructor Destroy; override;
    function Read(out ADialect: string; AColumnsOf: TStrings): TJSONArray;
    function ReadColumnsOf(ATables: TStrings): TJSONArray;
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

// ' AND <column> IN (...)' (' WHERE ...' with AWhere) when only some tables
// are read; nothing when all are
function TRpCatalogReader.InFilter(const AColumn: string;
  AWhere: Boolean): string;
begin
  Result := '';
  if FIn = '' then
    Exit;
  if AWhere then
    Result := ' WHERE '
  else
    Result := ' AND ';
  Result := Result + AColumn + FIn;
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
  // A BLOB too, as the .NET reader (DatabaseCatalogReader.LooseType): the
  // same file read again by the other engine kept changing its type
  else if (Pos('text', LType) > 0) or (Pos('clob', LType) > 0) or
    (Pos('blob', LType) > 0) then
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

procedure TRpCatalogReader.ReadFirebirdTables;
var
  LData: TDataSet;
begin
  LData := Open('SELECT TRIM(R.RDB$RELATION_NAME), R.RDB$DESCRIPTION ' +
    'FROM RDB$RELATIONS R WHERE COALESCE(R.RDB$SYSTEM_FLAG, 0) = 0 ' +
    'ORDER BY R.RDB$RELATION_NAME');
  FCatalog.BeginAdding;
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0)).Context := FieldText(LData, 1);
      LData.Next;
    end;
  finally
    FCatalog.EndAdding;
    LData.Free;
  end;
end;

procedure TRpCatalogReader.ReadFirebirdColumns;
var
  LColumn: TRpCatColumn;
  LCloudType, LDetected: string;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  LData := Open('SELECT TRIM(RF.RDB$RELATION_NAME), TRIM(RF.RDB$FIELD_NAME), ' +
    'F.RDB$FIELD_TYPE, F.RDB$FIELD_SUB_TYPE, F.RDB$FIELD_LENGTH, ' +
    'F.RDB$FIELD_PRECISION, F.RDB$FIELD_SCALE, F.RDB$CHARACTER_LENGTH, ' +
    'RF.RDB$DESCRIPTION ' +
    'FROM RDB$RELATION_FIELDS RF ' +
    'JOIN RDB$RELATIONS R ON R.RDB$RELATION_NAME = RF.RDB$RELATION_NAME ' +
    'JOIN RDB$FIELDS F ON F.RDB$FIELD_NAME = RF.RDB$FIELD_SOURCE ' +
    'WHERE COALESCE(R.RDB$SYSTEM_FLAG, 0) = 0' +
    InFilter('TRIM(RF.RDB$RELATION_NAME)') + ' ' +
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
      'WHERE RC.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY''' +
      InFilter('TRIM(RC.RDB$RELATION_NAME)'));
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
      'WHERE RC.RDB$CONSTRAINT_TYPE = ''FOREIGN KEY''' +
      InFilter('TRIM(RC.RDB$RELATION_NAME)') + ' ' +
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

// The comments of the tables that have no context yet (the starting
// description); a catalog that can not be read leaves them empty
procedure TRpCatalogReader.ReadTableComments(const ASql: string);
var
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  try
    LData := Open(ASql);
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
end;

// The same with the columns read
procedure TRpCatalogReader.ReadColumnComments(const ASql: string);
var
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  try
    LData := Open(ASql);
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

function InformationSchemaFilter(AFamily: TRpCatalogFamily): string;
begin
  case AFamily of
    rcfMySQL:
      Result := 'TABLE_SCHEMA = DATABASE()';
    rcfSQLServer:
      Result := 'TABLE_SCHEMA NOT IN (''sys'', ''INFORMATION_SCHEMA'')';
  else
    Result := 'TABLE_SCHEMA NOT IN (''pg_catalog'', ''information_schema'')';
  end;
end;

procedure TRpCatalogReader.ReadInformationSchemaTables;
var
  LData: TDataSet;
  LFilter: string;
begin
  LFilter := InformationSchemaFilter(FFamily);
  if FFamily = rcfMySQL then
    LData := Open('SELECT TABLE_NAME, TABLE_COMMENT FROM INFORMATION_SCHEMA.TABLES ' +
      'WHERE ' + LFilter + ' ORDER BY TABLE_NAME')
  else
    LData := Open('SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ' +
      'WHERE ' + LFilter + ' ORDER BY TABLE_NAME');
  FCatalog.BeginAdding;
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0)).Context := FieldText(LData, 1);
      LData.Next;
    end;
  finally
    FCatalog.EndAdding;
    LData.Free;
  end;
  // MySQL gave its comments with the tables
  case FFamily of
    rcfPostgreSQL:
      ReadTableComments('SELECT c.relname, obj_description(c.oid, ''pg_class'') ' +
        'FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace ' +
        'WHERE c.relkind IN (''r'', ''v'', ''m'', ''p'', ''f'') ' +
        'AND n.nspname NOT IN (''pg_catalog'', ''information_schema'') ' +
        'AND obj_description(c.oid, ''pg_class'') IS NOT NULL');
    rcfSQLServer:
      ReadTableComments('SELECT o.name, CAST(ep.value AS nvarchar(4000)) ' +
        'FROM sys.extended_properties ep JOIN sys.objects o ON o.object_id = ep.major_id ' +
        'WHERE ep.class = 1 AND ep.minor_id = 0 AND ep.name = ''MS_Description''');
  end;
end;

procedure TRpCatalogReader.ReadInformationSchemaColumns;
var
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LFilter: string;
  LTable: TRpCatTable;
begin
  LFilter := InformationSchemaFilter(FFamily);
  if FFamily = rcfMySQL then
    LData := Open('SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, ' +
      'CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, COLUMN_COMMENT ' +
      'FROM INFORMATION_SCHEMA.COLUMNS WHERE ' + LFilter + InFilter('TABLE_NAME') +
      ' ORDER BY TABLE_NAME, ORDINAL_POSITION')
  else
    LData := Open('SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, ' +
      'CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE ' +
      'FROM INFORMATION_SCHEMA.COLUMNS WHERE ' + LFilter + InFilter('TABLE_NAME') +
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
      'WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''' + InFilter('kcu.TABLE_NAME'));
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
      'AND kcu2.ORDINAL_POSITION = kcu.ORDINAL_POSITION' +
      InFilter('kcu.TABLE_NAME', True) + ' ' +
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
  // MySQL gave its comments with the columns
  case FFamily of
    rcfPostgreSQL:
      ReadColumnComments('SELECT c.relname, a.attname, col_description(c.oid, a.attnum) ' +
        'FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace ' +
        'JOIN pg_attribute a ON a.attrelid = c.oid ' +
        'WHERE a.attnum > 0 AND NOT a.attisdropped ' +
        'AND n.nspname NOT IN (''pg_catalog'', ''information_schema'') ' +
        'AND col_description(c.oid, a.attnum) IS NOT NULL' + InFilter('c.relname'));
    rcfSQLServer:
      ReadColumnComments('SELECT o.name, c.name, CAST(ep.value AS nvarchar(4000)) ' +
        'FROM sys.extended_properties ep JOIN sys.objects o ON o.object_id = ep.major_id ' +
        'JOIN sys.columns c ON c.object_id = ep.major_id AND c.column_id = ep.minor_id ' +
        'WHERE ep.class = 1 AND ep.minor_id > 0 AND ep.name = ''MS_Description''' +
        InFilter('o.name'));
  end;
end;

procedure TRpCatalogReader.ReadSQLiteTables;
var
  LData: TDataSet;
begin
  LData := Open('SELECT name FROM sqlite_master WHERE type IN (''table'', ''view'') ' +
    'AND name NOT LIKE ''sqlite_%'' ORDER BY name');
  FCatalog.BeginAdding;
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0));
      LData.Next;
    end;
  finally
    FCatalog.EndAdding;
    LData.Free;
  end;
end;

// Table by table (all the tables when ANames is nil)
procedure TRpCatalogReader.ReadSQLiteColumns(ANames: TStrings);
var
  I, LCount: Integer;
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LQuoted: string;
  LTable: TRpCatTable;
begin
  if ANames = nil then
    LCount := FCatalog.List.Count
  else
    LCount := ANames.Count;
  for I := 0 to LCount - 1 do
  begin
    if ANames = nil then
      LTable := TRpCatTable(FCatalog.List.Objects[I])
    else
      LTable := FCatalog.Find(ANames[I]);
    if LTable = nil then
      Continue;
    LQuoted := '''' + StringReplace(LTable.Name, '''', '''''', [rfReplaceAll]) + '''';
    // cid, name, type, notnull, dflt_value, pk
    LData := OpenSQLitePragma('table_info', LQuoted,
      'cid, name, type, "notnull", dflt_value, pk', 'cid');
    try
      while not LData.Eof do
      begin
        LColumn := LTable.AddColumn(FieldText(LData, 1));
        LColumn.DetectedType := UpperCase(FieldText(LData, 2));
        LColumn.DataType := CloudTypeOfSqlType(FieldText(LData, 2), -1);
        LColumn.IsPrimaryKey := FieldInt(LData, 5) > 0;
        LData.Next;
      end;
    finally
      LData.Free;
    end;
    try
      // id, seq, table, from, to
      LData := OpenSQLitePragma('foreign_key_list', LQuoted,
        'id, seq, "table", "from", "to"', 'id, seq');
      try
        while not LData.Eof do
        begin
          AddForeignKey(LTable.Name, 'FK_' + LTable.Name + '_' + FieldText(LData, 0),
            FieldText(LData, 2), FieldText(LData, 3), FieldText(LData, 4));
          LData.Next;
        end;
      finally
        LData.Free;
      end;
    except
    end;
  end;
end;

// A PRAGMA of a table as rows. The statement first: the table-valued
// functions (pragma_table_info(...)) need SQLite 3.16, and the SQLite of
// FireDAC answered them with a syntax error, so the catalog of the sample
// database came out empty. The function form, with the columns in the order
// of the statement, for a driver that does not open a PRAGMA as a query.
function TRpCatalogReader.OpenSQLitePragma(const APragma, AQuotedTable,
  AColumns, AOrder: string): TDataSet;
begin
  try
    Result := Open('PRAGMA ' + APragma + '(' + AQuotedTable + ')');
  except
    Result := Open('SELECT ' + AColumns + ' FROM pragma_' + APragma + '(' +
      AQuotedTable + ') ORDER BY ' + AOrder);
  end;
end;

procedure TRpCatalogReader.ReadOracleTables;
var
  LData: TDataSet;
begin
  LData := Open('SELECT TABLE_NAME FROM USER_TABLES UNION ' +
    'SELECT VIEW_NAME FROM USER_VIEWS ORDER BY 1');
  FCatalog.BeginAdding;
  try
    while not LData.Eof do
    begin
      if FieldText(LData, 0) <> '' then
        FCatalog.Add(FieldText(LData, 0));
      LData.Next;
    end;
  finally
    FCatalog.EndAdding;
    LData.Free;
  end;
  ReadTableComments('SELECT TABLE_NAME, COMMENTS FROM USER_TAB_COMMENTS ' +
    'WHERE COMMENTS IS NOT NULL');
end;

procedure TRpCatalogReader.ReadOracleColumns;
var
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  LData := Open('SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, ' +
    'DATA_PRECISION, DATA_SCALE FROM USER_TAB_COLUMNS' +
    InFilter('TABLE_NAME', True) + ' ORDER BY TABLE_NAME, COLUMN_ID');
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
      'WHERE C.CONSTRAINT_TYPE = ''P''' + InFilter('CC.TABLE_NAME'));
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
      'WHERE C.CONSTRAINT_TYPE = ''R''' + InFilter('CC.TABLE_NAME') +
      ' ORDER BY 2, 1, CC.POSITION');
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
  ReadColumnComments('SELECT TABLE_NAME, COLUMN_NAME, COMMENTS FROM USER_COL_COMMENTS ' +
    'WHERE COMMENTS IS NOT NULL' + InFilter('TABLE_NAME'));
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

procedure TRpCatalogReader.ReadGenericTables;
var
  I: Integer;
  LNames: TStringList;
begin
  // The tables the driver lists
  LNames := TStringList.Create;
  FCatalog.BeginAdding;
  try
    FDatabase.GetTableNames(LNames, FParams);
    for I := 0 to LNames.Count - 1 do
      if Trim(LNames[I]) <> '' then
        FCatalog.Add(Trim(LNames[I]));
  finally
    FCatalog.EndAdding;
    LNames.Free;
  end;
end;

// The columns of a query without rows, table by table (all the tables when
// ANames is nil)
procedure TRpCatalogReader.ReadGenericColumns(ANames: TStrings);
var
  I, J, LCount: Integer;
  LColumn: TRpCatColumn;
  LData: TDataSet;
  LTable: TRpCatTable;
begin
  if ANames = nil then
    LCount := FCatalog.List.Count
  else
    LCount := ANames.Count;
  for I := 0 to LCount - 1 do
  begin
    if ANames = nil then
      LTable := TRpCatTable(FCatalog.List.Objects[I])
    else
      LTable := FCatalog.Find(ANames[I]);
    if LTable = nil then
      Continue;
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

procedure TRpCatalogReader.ReadTables;
begin
  case FFamily of
    rcfFirebird:
      ReadFirebirdTables;
    rcfPostgreSQL, rcfMySQL, rcfSQLServer:
      ReadInformationSchemaTables;
    rcfSQLite:
      ReadSQLiteTables;
    rcfOracle:
      ReadOracleTables;
  else
    ReadGenericTables;
  end;
end;

// The columns, keys and comments of the tables of ANames (catalog names),
// or of every table when it is nil; the queries of a catalog go by batches
// of names
procedure TRpCatalogReader.ReadColumns(ANames: TStrings);
const
  CBatch = 200;
var
  I, LFirst: Integer;
begin
  case FFamily of
    rcfSQLite:
      ReadSQLiteColumns(ANames);
    rcfFirebird, rcfPostgreSQL, rcfMySQL, rcfSQLServer, rcfOracle:
      begin
        LFirst := 0;
        repeat
          FIn := '';
          if ANames <> nil then
          begin
            if LFirst >= ANames.Count then
              Break;
            for I := LFirst to ANames.Count - 1 do
            begin
              if I >= LFirst + CBatch then
                Break;
              if FIn <> '' then
                FIn := FIn + ', ';
              FIn := FIn + QuotedStr(ANames[I]);
            end;
            FIn := ' IN (' + FIn + ')';
            Inc(LFirst, CBatch);
          end;
          case FFamily of
            rcfFirebird:
              ReadFirebirdColumns;
            rcfOracle:
              ReadOracleColumns;
          else
            ReadInformationSchemaColumns;
          end;
        until ANames = nil;
        FIn := '';
      end;
  else
    ReadGenericColumns(ANames);
  end;
end;

// nil (every table) for a normal catalog; with more than
// RpLargeCatalogLimit tables, the tables of AColumnsOf as the catalog spells
// them, and the rest marked as not read
function TRpCatalogReader.ColumnsToRead(AColumnsOf: TStrings): TStringList;
var
  I: Integer;
  LTable: TRpCatTable;
begin
  Result := nil;
  if FCatalog.List.Count <= RpLargeCatalogLimit then
    Exit;
  Result := TStringList.Create;
  for I := 0 to FCatalog.List.Count - 1 do
    TRpCatTable(FCatalog.List.Objects[I]).ColumnsRead := False;
  if AColumnsOf <> nil then
    for I := 0 to AColumnsOf.Count - 1 do
    begin
      LTable := FCatalog.Find(AColumnsOf[I]);
      if (LTable <> nil) and not LTable.ColumnsRead then
      begin
        LTable.ColumnsRead := True;
        Result.Add(LTable.Name);
      end;
    end;
end;

procedure TRpCatalogReader.Connect(out ADialect: string);
begin
  FFamily := FamilyOf(FDatabase, FParams);
  ADialect := DialectOfFamily(FFamily);
  FDatabase.Connect(FParams);
  if FFamily = rcfFirebird then
    ADialect := FirebirdDialect;
end;

function TRpCatalogReader.Read(out ADialect: string;
  AColumnsOf: TStrings): TJSONArray;
var
  LNames: TStringList;
begin
  Connect(ADialect);
  LNames := nil;
  try
    try
      ReadTables;
      LNames := ColumnsToRead(AColumnsOf);
      ReadColumns(LNames);
    except
      // A catalog that can not be read (permissions, an older server): the
      // tables the driver lists
      if FFamily = rcfGeneric then
        raise;
      FCatalog.List.Clear;
      FFamily := rcfGeneric;
      FreeAndNil(LNames);
      ReadTables;
      LNames := ColumnsToRead(AColumnsOf);
      ReadColumns(LNames);
    end;
    Result := FCatalog.ToJsonArray;
  finally
    LNames.Free;
  end;
end;

function TRpCatalogReader.ReadColumnsOf(ATables: TStrings): TJSONArray;
var
  I: Integer;
  LDialect: string;
  LNames: TStringList;
begin
  Connect(LDialect);
  LNames := TStringList.Create;
  try
    for I := 0 to ATables.Count - 1 do
      if (Trim(ATables[I]) <> '') and (FCatalog.Find(Trim(ATables[I])) = nil) then
        LNames.Add(FCatalog.Add(Trim(ATables[I])).Name);
    try
      ReadColumns(LNames);
    except
      if FFamily = rcfGeneric then
        raise;
      for I := 0 to FCatalog.List.Count - 1 do
      begin
        TRpCatTable(FCatalog.List.Objects[I]).Columns.Clear;
        TRpCatTable(FCatalog.List.Objects[I]).ForeignKeys.Clear;
      end;
      FFamily := rcfGeneric;
      ReadColumns(LNames);
    end;
    Result := FCatalog.ToJsonArray(True);
  finally
    LNames.Free;
  end;
end;

function RpReadLocalSchemaCatalog(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; out ADialect: string;
  AColumnsOf: TStrings): TJSONArray;
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
    Result := LReader.Read(ADialect, AColumnsOf);
  finally
    LReader.Free;
  end;
end;

function RpReadLocalSchemaColumns(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; ATables: TStrings): TJSONArray;
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
    Result := LReader.ReadColumnsOf(ATables);
  finally
    LReader.Free;
  end;
end;

procedure RpLocalSchemaKeepList(AFile: TRpLocalSchemaFile; AList: TStrings);
var
  I: Integer;
  LTable: TJSONObject;
  LValue: TJSONValue;
begin
  AList.Clear;
  for I := 0 to AFile.SchemaCount - 1 do
    AList.AddStrings(AFile.Schemas[I].Tables);
  for I := 0 to AFile.Tables.Count - 1 do
  begin
    LTable := JObj(AFile.Tables, I);
    if LTable = nil then
      Continue;
    LValue := LTable.Values['columnsRead'];
    if not ((LValue <> nil) and SameText(LValue.Value, 'false')) then
      AList.Add(JStr(LTable, 'name'));
  end;
end;

function RpLoadLocalSchema(ADatabase: TRpDatabaseInfoItem;
  AParams: TRpParamList; AGenerate, ARefresh: Boolean): TRpLocalSchemaFile;
var
  LDialect, LFileName: string;
  LExists: Boolean;
  LKeep: TStringList;
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
      // In a large catalog the columns of the tables of the subschemas and
      // of the ones read before are read again; the others, when they are
      // used
      LKeep := TStringList.Create;
      try
        RpLocalSchemaKeepList(Result, LKeep);
        LTables := RpReadLocalSchemaCatalog(ADatabase, AParams, LDialect, LKeep);
      finally
        LKeep.Free;
      end;
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
  LReport: TComponent;
begin
  // In the list of the same report: the copy opens what the connection opens
  // (a relative SQLite database next to the report, the ADO connection
  // string of the report); without it, samples.db of the sample reports was
  // looked for in the current folder and SQLite created an empty one there
  LReport := nil;
  if ADatabase.Collection is TRpDatabaseInfoList then
    LReport := TRpDatabaseInfoList(ADatabase.Collection).Report;
  Result := TRpDatabaseInfoList.Create(LReport);
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
    // A file that can not be read lists nothing
    LFile := nil;
  end;
  if LFile = nil then
    Exit;
  try
    for I := 0 to LFile.SchemaCount - 1 do
      AddEntry(LFile.Schemas[I].Name, SizeText(LFile, LFile.Schemas[I].Name));
  finally
    LFile.Free;
  end;
end;

function RpSubSchemaRequiredMessage(const AAlias: string): string;
begin
  // The resource has the guillemets of the plan; the default, plain quotes
  // (the units are ASCII)
  Result := Format(string(TranslateStr(1984, 'Choose a subschema of %s, or ' +
    'make one with "New local schema...": the AI only receives a subschema.')),
    [AAlias]);
end;

function RpSubSchemaTablesJson(AFile: TRpLocalSchemaFile; const AAlias,
  ASchemaName: string; out ASpelledName: string): string;
begin
  ASpelledName := '';
  if AFile <> nil then
    ASpelledName := AFile.SchemaNameOf(ASchemaName);
  // SchemaTablesJson sends every table for '' or an unknown name: that is
  // for an export, never for the AI
  if ASpelledName = '' then
    raise Exception.Create(RpSubSchemaRequiredMessage(AAlias));
  Result := AFile.SchemaTablesJson(ASpelledName);
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

{ Export and import with the Reportman AI web }

const
{$IFDEF FPC}
  // Lazarus strings are UTF-8
  CEllipsis = #$E2#$80#$A6;
{$ELSE}
  CEllipsis = #$2026;
{$ENDIF}

// A property of a file of another program, whatever the case of its name
// (the old Desktop wrote PascalCase)
function JValueCI(AObject: TJSONObject; const AName: string): TJSONValue;
var
  I: Integer;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  Result := AObject.Values[AName];
  if Result <> nil then
    Exit;
  for I := 0 to AObject.Count - 1 do
    if SameText(AObject.Pairs[I].JsonString.Value, AName) then
      Exit(AObject.Pairs[I].JsonValue);
end;

function JStrCI(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  LValue := JValueCI(AObject, AName);
  if (LValue <> nil) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function JArrCI(AObject: TJSONObject; const AName: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  Result := nil;
  LValue := JValueCI(AObject, AName);
  if LValue is TJSONArray then
    Result := TJSONArray(LValue);
end;

// The columns are all in the table (and there is one at least)
function ColumnsExist(ATable: TJSONObject; AColumns: TStrings): Boolean;
var
  LSpelled: TJSONArray;
begin
  LSpelled := TJSONArray.Create;
  try
    Result := SpellColumns(ATable, AColumns, LSpelled);
  finally
    LSpelled.Free;
  end;
end;

procedure AddSkipped(ASkipped: TStrings; const AName: string);
begin
  if (ASkipped <> nil) and (ASkipped.IndexOf(AName) < 0) then
    ASkipped.Add(AName);
end;

// The name of an imported subschema: the one of the file or, without one,
// the file name without its extension and its "_Config"; "name 2",
// "name 3"... when there is a subschema with it
function ImportedSchemaName(AFile: TRpLocalSchemaFile;
  const AName, AFileName: string): string;
const
  CConfig = '_Config';
var
  LBase: string;
  LNumber: Integer;
begin
  LBase := Trim(AName);
  if LBase = '' then
  begin
    LBase := ChangeFileExt(ExtractFileName(AFileName), '');
    if (Length(LBase) >= Length(CConfig)) and SameText(Copy(LBase,
      Length(LBase) - Length(CConfig) + 1, Length(CConfig)), CConfig) then
      LBase := Copy(LBase, 1, Length(LBase) - Length(CConfig));
    LBase := Trim(LBase);
  end;
  if LBase = '' then
    LBase := Trim(AFile.Alias);
  if LBase = '' then
    LBase := 'Schema';
  Result := LBase;
  LNumber := 1;
  while AFile.IndexOfSchema(Result) >= 0 do
  begin
    Inc(LNumber);
    Result := LBase + ' ' + IntToStr(LNumber);
  end;
end;

// The allowed values of a column of the file, when it has some
procedure ImportAllowedValues(AFile: TRpLocalSchemaFile;
  const ATable, AColumn: string; AItems: TJSONArray);
var
  I: Integer;
  LItem: TJSONObject;
  LLabel, LValue: string;
  LLabels, LValues: TStringList;
begin
  if (AItems = nil) or (AItems.Count = 0) then
    Exit;
  LValues := TStringList.Create;
  LLabels := TStringList.Create;
  try
    for I := 0 to AItems.Count - 1 do
    begin
      LItem := JObj(AItems, I);
      if LItem = nil then
        Continue;
      LValue := JStrCI(LItem, 'value');
      LLabel := JStrCI(LItem, 'label');
      if (Trim(LValue) = '') and (Trim(LLabel) = '') then
        Continue;
      LValues.Add(LValue);
      LLabels.Add(LLabel);
    end;
    if LValues.Count > 0 then
      AFile.SetAllowedValues(ATable, AColumn, LValues, LLabels);
  finally
    LLabels.Free;
    LValues.Free;
  end;
end;

function RpExportSchemaName(AFile: TRpLocalSchemaFile;
  const ASchemaName: string): string;
begin
  Result := AFile.SchemaNameOf(ASchemaName);
  if Result = '' then
    Result := Trim(AFile.Alias);
  if Result = '' then
    Result := 'schema';
end;

function RpExportSchemaFileName(AFile: TRpLocalSchemaFile;
  const ASchemaName: string): string;
var
  I: Integer;
begin
  Result := RpExportSchemaName(AFile, ASchemaName);
  for I := 1 to Length(Result) do
    if CharInSet(Result[I], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      Result[I] := '_';
  Result := Result + '_Config.json';
end;

function RpExportSchemaJson(AFile: TRpLocalSchemaFile;
  const ASchemaName: string): string;
var
  LRoot: TJSONObject;
  LTables: TJSONValue;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('name', RpExportSchemaName(AFile, ASchemaName));
    // What the copilot sends, not a rule of its own
    LTables := TJSONObject.ParseJSONValue(
      AFile.SchemaTablesJson(AFile.SchemaNameOf(ASchemaName)));
    if not (LTables is TJSONArray) then
    begin
      LTables.Free;
      LTables := TJSONArray.Create;
    end;
    LRoot.AddPair('schemaTables', LTables);
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

procedure RpExportSchemaToFile(AFile: TRpLocalSchemaFile;
  const ASchemaName, AFileName: string);
begin
  WriteUtf8File(AFileName, RpExportSchemaJson(AFile, ASchemaName));
end;

{ The templates of the library }

type
  // A part of a table name: a literal, or a placeholder ('{COMPANY_NAME}')
  // that takes one character at least
  TRpNameSegment = record
    Placeholder: Boolean;
    Text: string;
  end;
  TRpNameSegments = array of TRpNameSegment;

  // The tables of a schema to import as the catalog names them: its name;
  // the last part of a qualified one; a template whose placeholders take
  // the values of Values ('NAME=value') or, without one, the first table of
  // the catalog that fills it
  TRpImportResolver = class(TObject)
  private
    FFile: TRpLocalSchemaFile;
    FNames: TStringList;
  public
    Values: TStringList;
    constructor Create(AFile: TRpLocalSchemaFile);
    destructor Destroy; override;
    function Resolve(const AName: string): TJSONObject;
    function IsTemplate(const AName: string): Boolean;
    procedure GetCandidates(ATables: TJSONArray; APlaceholders: TStringList);
  end;

// The name of a table without its qualifiers ('[{DB_NAME}].dbo.OINV':
// OINV): the part after the last dot out of brackets and quotes, without
// the brackets or quotes around it
function LastNamePart(const AName: string): string;
var
  I, LStart: Integer;
  LClose: Char;
begin
  Result := Trim(AName);
  LStart := 1;
  LClose := #0;
  for I := 1 to Length(Result) do
    if LClose <> #0 then
    begin
      if Result[I] = LClose then
        LClose := #0;
    end
    else if Result[I] = '[' then
      LClose := ']'
    else if Result[I] = '"' then
      LClose := '"'
    else if Result[I] = '.' then
      LStart := I + 1;
  Result := Trim(Copy(Result, LStart, Length(Result)));
  if (Length(Result) >= 2) and (((Result[1] = '[') and
    (Result[Length(Result)] = ']')) or ((Result[1] = '"') and
    (Result[Length(Result)] = '"'))) then
    Result := Trim(Copy(Result, 2, Length(Result) - 2));
end;

// The literals and placeholders of a name; False when it has no placeholder
function NameSegments(const AName: string;
  out ASegments: TRpNameSegments): Boolean;
var
  I, J: Integer;
  LLiteral: string;

  procedure Add(APlaceholder: Boolean; const AText: string);
  begin
    SetLength(ASegments, Length(ASegments) + 1);
    ASegments[High(ASegments)].Placeholder := APlaceholder;
    ASegments[High(ASegments)].Text := AText;
  end;

begin
  ASegments := nil;
  Result := False;
  LLiteral := '';
  I := 1;
  while I <= Length(AName) do
  begin
    if AName[I] = '{' then
    begin
      J := I + 1;
      while (J <= Length(AName)) and CharInSet(AName[J],
        ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        Inc(J);
      if (J > I + 1) and (J <= Length(AName)) and (AName[J] = '}') then
      begin
        if LLiteral <> '' then
          Add(False, LLiteral);
        LLiteral := '';
        Add(True, Copy(AName, I + 1, J - I - 1));
        Result := True;
        I := J + 1;
        Continue;
      end;
    end;
    LLiteral := LLiteral + AName[I];
    Inc(I);
  end;
  if LLiteral <> '' then
    Add(False, LLiteral);
end;

// A name of the catalog fills the segments from ASegment on, at APos: the
// literals in order (case insensitive), a placeholder with one character at
// least, the shortest first. AValues ('NAME=value') gives the value of a
// placeholder it has, and gets the ones taken
function MatchSegments(const ASegments: TRpNameSegments; ASegment: Integer;
  const AName: string; APos: Integer; AValues: TStrings): Boolean;
var
  LIndex, LLength: Integer;
  LText: string;
begin
  if ASegment > High(ASegments) then
    Exit(APos = Length(AName) + 1);
  LText := ASegments[ASegment].Text;
  if ASegments[ASegment].Placeholder then
  begin
    LIndex := AValues.IndexOfName(LText);
    if LIndex >= 0 then
      LText := AValues.ValueFromIndex[LIndex]
    else
    begin
      for LLength := 1 to Length(AName) - APos + 1 do
      begin
        AValues.Add(LText + '=' + Copy(AName, APos, LLength));
        if MatchSegments(ASegments, ASegment + 1, AName, APos + LLength,
          AValues) then
          Exit(True);
        AValues.Delete(AValues.Count - 1);
      end;
      Exit(False);
    end;
  end;
  Result := (LText <> '') and SameText(Copy(AName, APos, Length(LText)), LText) and
    MatchSegments(ASegments, ASegment + 1, AName, APos + Length(LText), AValues);
end;

// The tables of a schema to import: schemaTables, or the bare array of a
// schema of the library
function ImportTables(AJson: TJSONValue): TJSONArray;
begin
  Result := nil;
  if AJson is TJSONArray then
    Result := TJSONArray(AJson)
  else if AJson is TJSONObject then
    Result := JArrCI(TJSONObject(AJson), 'schemaTables');
end;

constructor TRpImportResolver.Create(AFile: TRpLocalSchemaFile);
begin
  inherited Create;
  FFile := AFile;
  FNames := TStringList.Create;
  AFile.GetTableNames(FNames);
  Values := TStringList.Create;
end;

destructor TRpImportResolver.Destroy;
begin
  Values.Free;
  FNames.Free;
  inherited Destroy;
end;

function TRpImportResolver.IsTemplate(const AName: string): Boolean;
var
  LSegments: TRpNameSegments;
begin
  Result := (FFile.FindTable(Trim(AName)) = nil) and
    NameSegments(LastNamePart(AName), LSegments);
end;

function TRpImportResolver.Resolve(const AName: string): TJSONObject;
var
  I: Integer;
  LTaken: TStringList;
  LPart: string;
  LSegments: TRpNameSegments;
begin
  Result := FFile.FindTable(Trim(AName));
  if Result <> nil then
    Exit;
  LPart := LastNamePart(AName);
  if not NameSegments(LPart, LSegments) then
  begin
    if LPart <> '' then
      Result := FFile.FindTable(LPart);
    Exit;
  end;
  LTaken := TStringList.Create;
  try
    for I := 0 to FNames.Count - 1 do
    begin
      LTaken.Assign(Values);
      if MatchSegments(LSegments, 0, FNames[I], 1, LTaken) then
        Exit(FFile.FindTable(FNames[I]));
    end;
  finally
    LTaken.Free;
  end;
end;

// APlaceholders (owning its objects) gets the placeholders of the templates
// of ATables that the catalog fills, in the order of the schema, each one
// with the list of its values (owning, as objects, the tables of the schema
// each value gives): the one that gives more first, then in the order they
// are found (the tables of the schema, for each one the catalog)
procedure TRpImportResolver.GetCandidates(ATables: TJSONArray;
  APlaceholders: TStringList);
var
  I, J, K, LIndex: Integer;
  LKey, LName: string;
  LTaken, LValues, LTables: TStringList;
  LSegments: TRpNameSegments;
begin
  APlaceholders.Clear;
  APlaceholders.OwnsObjects := True;
  if ATables = nil then
    Exit;
  LTaken := TStringList.Create;
  try
    for I := 0 to ATables.Count - 1 do
    begin
      LName := Trim(JStrCI(JObj(ATables, I), 'name'));
      if (LName = '') or not IsTemplate(LName) then
        Continue;
      NameSegments(LastNamePart(LName), LSegments);
      LKey := UpperCase(LName);
      for J := 0 to FNames.Count - 1 do
      begin
        LTaken.Clear;
        if not MatchSegments(LSegments, 0, FNames[J], 1, LTaken) then
          Continue;
        for K := 0 to LTaken.Count - 1 do
        begin
          LIndex := APlaceholders.IndexOf(LTaken.Names[K]);
          if LIndex < 0 then
          begin
            LValues := TStringList.Create;
            LValues.OwnsObjects := True;
            LIndex := APlaceholders.AddObject(LTaken.Names[K], LValues);
          end;
          LValues := TStringList(APlaceholders.Objects[LIndex]);
          LIndex := LValues.IndexOf(LTaken.ValueFromIndex[K]);
          if LIndex < 0 then
            LIndex := LValues.AddObject(LTaken.ValueFromIndex[K],
              TStringList.Create);
          LTables := TStringList(LValues.Objects[LIndex]);
          if LTables.IndexOf(LKey) < 0 then
            LTables.Add(LKey);
        end;
      end;
    end;
  finally
    LTaken.Free;
  end;
  // The one that gives more tables first; a tie keeps the order found
  for I := 0 to APlaceholders.Count - 1 do
  begin
    LValues := TStringList(APlaceholders.Objects[I]);
    for J := 1 to LValues.Count - 1 do
    begin
      K := J;
      while (K > 0) and (TStringList(LValues.Objects[K - 1]).Count <
        TStringList(LValues.Objects[K]).Count) do
      begin
        LValues.Exchange(K - 1, K);
        Dec(K);
      end;
    end;
  end;
end;

// The values of the placeholders of AJson for an import: those of AGiven
// ('NAME=value'), the first of the catalog for the others
procedure ImportTemplateValues(AResolver: TRpImportResolver;
  ATables: TJSONArray; AGiven: TStrings);
var
  I, LIndex: Integer;
  LPlaceholders: TStringList;
begin
  AResolver.Values.Clear;
  LPlaceholders := TStringList.Create;
  try
    AResolver.GetCandidates(ATables, LPlaceholders);
    for I := 0 to LPlaceholders.Count - 1 do
    begin
      LIndex := -1;
      if AGiven <> nil then
        LIndex := AGiven.IndexOfName(LPlaceholders[I]);
      if LIndex >= 0 then
        AResolver.Values.Add(LPlaceholders[I] + '=' +
          AGiven.ValueFromIndex[LIndex])
      else if TStringList(LPlaceholders.Objects[I]).Count > 0 then
        AResolver.Values.Add(LPlaceholders[I] + '=' +
          TStringList(LPlaceholders.Objects[I])[0]);
    end;
  finally
    LPlaceholders.Free;
  end;
end;

// The placeholders of the template of a table resolved go to AUsed
procedure AddUsedPlaceholders(AResolver: TRpImportResolver;
  const AName: string; AUsed: TStrings);
var
  I: Integer;
  LSegments: TRpNameSegments;
begin
  if not AResolver.IsTemplate(AName) then
    Exit;
  NameSegments(LastNamePart(AName), LSegments);
  for I := 0 to High(LSegments) do
    if LSegments[I].Placeholder and (AUsed.IndexOf(LSegments[I].Text) < 0) then
      AUsed.Add(LSegments[I].Text);
end;

procedure RpImportPlaceholders(AFile: TRpLocalSchemaFile; const AJson: string;
  ANames: TStrings);
var
  LPlaceholders: TStringList;
  LResolver: TRpImportResolver;
  LRoot: TJSONValue;
begin
  ANames.Clear;
  try
    LRoot := TJSONObject.ParseJSONValue(AJson);
  except
    LRoot := nil;
  end;
  LResolver := TRpImportResolver.Create(AFile);
  LPlaceholders := TStringList.Create;
  try
    LResolver.GetCandidates(ImportTables(LRoot), LPlaceholders);
    ANames.Assign(LPlaceholders);
  finally
    LPlaceholders.Free;
    LResolver.Free;
    LRoot.Free;
  end;
end;

procedure RpImportPlaceholderValues(AFile: TRpLocalSchemaFile; const AJson,
  APlaceholder: string; AValues: TStrings);
var
  LIndex: Integer;
  LPlaceholders: TStringList;
  LResolver: TRpImportResolver;
  LRoot: TJSONValue;
begin
  AValues.Clear;
  try
    LRoot := TJSONObject.ParseJSONValue(AJson);
  except
    LRoot := nil;
  end;
  LResolver := TRpImportResolver.Create(AFile);
  LPlaceholders := TStringList.Create;
  try
    LResolver.GetCandidates(ImportTables(LRoot), LPlaceholders);
    LIndex := LPlaceholders.IndexOf(APlaceholder);
    if LIndex >= 0 then
      AValues.AddStrings(TStringList(LPlaceholders.Objects[LIndex]));
    // The tables of each value are owned by the list freed here
    for LIndex := 0 to AValues.Count - 1 do
      AValues.Objects[LIndex] := nil;
  finally
    LPlaceholders.Free;
    LResolver.Free;
    LRoot.Free;
  end;
end;

procedure RpImportCoverage(AFile: TRpLocalSchemaFile; const AJson: string;
  out AMatched, ATotal: Integer);
var
  I: Integer;
  LName: string;
  LNames: TStringList;
  LResolver: TRpImportResolver;
  LRoot: TJSONValue;
  LTables: TJSONArray;
begin
  AMatched := 0;
  ATotal := 0;
  try
    LRoot := TJSONObject.ParseJSONValue(AJson);
  except
    LRoot := nil;
  end;
  LResolver := TRpImportResolver.Create(AFile);
  LNames := TStringList.Create;
  try
    LTables := ImportTables(LRoot);
    if LTables = nil then
      Exit;
    for I := 0 to LTables.Count - 1 do
    begin
      LName := Trim(JStrCI(JObj(LTables, I), 'name'));
      if (LName = '') or (LNames.IndexOf(LName) >= 0) then
        Continue;
      LNames.Add(LName);
      Inc(ATotal);
      if LResolver.Resolve(LName) <> nil then
        Inc(AMatched);
    end;
  finally
    LNames.Free;
    LResolver.Free;
    LRoot.Free;
  end;
end;

function RpImportCoverageDetected(AMatched, ATotal: Integer): Boolean;
begin
  Result := ((AMatched >= 2) or ((AMatched = 1) and (ATotal = 1))) and
    (AMatched * 2 >= ATotal);
end;

function RpTemplateValuesText(AValues: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  if AValues <> nil then
    for I := 0 to AValues.Count - 1 do
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + '{' + AValues.Names[I] + '} = ' +
        AValues.ValueFromIndex[I];
    end;
end;

function RpReadSchemaFile(const AFileName: string): string;
begin
  Result := ReadUtf8File(AFileName);
end;

procedure RpImportTableNames(AFile: TRpLocalSchemaFile; const AJson: string;
  ATemplateValues, ANames: TStrings);
var
  I, J: Integer;
  LForeignKeys: TJSONArray;
  LResolver: TRpImportResolver;
  LRoot: TJSONValue;
  LTables: TJSONArray;
  LTable: TJSONObject;

  procedure AddTable(const AName: string);
  var
    LFound: TJSONObject;
  begin
    LFound := LResolver.Resolve(AName);
    if (LFound <> nil) and (ANames.IndexOf(JStr(LFound, 'name')) < 0) then
      ANames.Add(JStr(LFound, 'name'));
  end;

begin
  ANames.Clear;
  try
    LRoot := TJSONObject.ParseJSONValue(AJson);
  except
    LRoot := nil;
  end;
  LResolver := TRpImportResolver.Create(AFile);
  try
    LTables := ImportTables(LRoot);
    if LTables = nil then
      Exit;
    ImportTemplateValues(LResolver, LTables, ATemplateValues);
    for I := 0 to LTables.Count - 1 do
    begin
      LTable := JObj(LTables, I);
      if LTable = nil then
        Continue;
      AddTable(JStrCI(LTable, 'name'));
      LForeignKeys := JArrCI(LTable, 'foreignKeys');
      if LForeignKeys <> nil then
        for J := 0 to LForeignKeys.Count - 1 do
          if JObj(LForeignKeys, J) <> nil then
            AddTable(JStrCI(JObj(LForeignKeys, J), 'targetTable'));
    end;
  finally
    LResolver.Free;
    LRoot.Free;
  end;
end;

{ The filter }

const
  // U+00C0-U+017F: the base letter of each accented latin letter (its NFD
  // decomposition), '_' for the ones that stay as they are
  CFoldLatin: string =
    'aaaaaa_ceeeeiiii_nooooo__uuuuy__aaaaaa_ceeeeiiii' +
    '_nooooo__uuuuy_yaaaaaaccccccccdd__eeeeeeeeeegggg' +
    'gggghh__iiiiiiiii___jjkk_llllll____nnnnnn___oooo' +
    'oo__rrrrrrsssssssstttt__uuuuuuuuuuuuwwyyyzzzzzz_';

function RpFoldText(const AText: string): string;
var
  I: Integer;
  LCode: Integer;
  LText: UnicodeString;
begin
{$IFDEF FPC}
  LText := WideLowerCase(UTF8Decode(AText));
{$ELSE}
  LText := AnsiLowerCase(AText);
{$ENDIF}
  for I := 1 to Length(LText) do
  begin
    LCode := Ord(LText[I]);
    if (LCode >= $C0) and (LCode <= $17F) and
      (CFoldLatin[LCode - $C0 + 1] <> '_') then
      LText[I] := WideChar(CFoldLatin[LCode - $C0 + 1])
    else if (LCode >= Ord('A')) and (LCode <= Ord('Z')) then
      LText[I] := WideChar(LCode + 32);
  end;
{$IFDEF FPC}
  Result := UTF8Encode(LText);
{$ELSE}
  Result := LText;
{$ENDIF}
end;

procedure RpFilterWords(const AFilter: string; AWords: TStrings);
var
  I, LStart: Integer;
  LText: string;
begin
  AWords.Clear;
  LText := RpFoldText(AFilter) + ' ';
  LStart := 1;
  for I := 1 to Length(LText) do
    if CharInSet(LText[I], [' ', #9, #10, #13]) then
    begin
      if I > LStart then
        AWords.Add(Copy(LText, LStart, I - LStart));
      LStart := I + 1;
    end;
end;

function RpWordsMatch(AWords: TStrings; const AFoldedName,
  AFoldedContext: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to AWords.Count - 1 do
    if (Pos(AWords[I], AFoldedName) = 0) and
      (Pos(AWords[I], AFoldedContext) = 0) then
      Exit(False);
  Result := True;
end;

function RpFilterMatches(const AFilter, AName, AContext: string): Boolean;
var
  LWords: TStringList;
begin
  LWords := TStringList.Create;
  try
    RpFilterWords(AFilter, LWords);
    Result := (LWords.Count = 0) or
      RpWordsMatch(LWords, RpFoldText(AName), RpFoldText(AContext));
  finally
    LWords.Free;
  end;
end;

// The import of RpImportSchemaJson; AForcedName names the new subschema
// instead of the "name" of the JSON when it is not empty
function ImportSchemaJson(AFile: TRpLocalSchemaFile; const AJson,
  AFileName, AForcedName: string; out ANewName: string;
  ASkipped, ATemplateValues: TStrings): Integer;
var
  I, J: Integer;
  LRoot: TJSONValue;
  LColumns, LForeignKeys, LTables: TJSONArray;
  LCatalogColumn, LCatalogTable, LColumn, LItem, LTable: TJSONObject;
  LChosen, LNames, LOrdered, LSource, LTarget: TStringList;
  LSchema: TRpLocalSubSchema;
  LColumnName, LName, LTableName, LText: string;
  LResolver: TRpImportResolver;
  LTargetTable: TJSONObject;
  LUsed: TStringList;
begin
  Result := -1;
  ANewName := '';
  if ASkipped <> nil then
    ASkipped.Clear;
  try
    LRoot := TJSONObject.ParseJSONValue(AJson);
  except
    LRoot := nil;
  end;
  LChosen := TStringList.Create;
  LNames := TStringList.Create;
  LOrdered := TStringList.Create;
  LSource := TStringList.Create;
  LTarget := TStringList.Create;
  LResolver := TRpImportResolver.Create(AFile);
  LUsed := TStringList.Create;
  try
    if not (LRoot is TJSONObject) then
      Exit;
    LTables := JArrCI(TJSONObject(LRoot), 'schemaTables');
    if LTables = nil then
      Exit;
    // The templates of the library take the values given, the first of the
    // catalog for the others
    ImportTemplateValues(LResolver, LTables, ATemplateValues);
    LName := AForcedName;
    if Trim(LName) = '' then
      LName := JStrCI(TJSONObject(LRoot), 'name');
    ANewName := ImportedSchemaName(AFile, LName, AFileName);
    // None of its tables is in the catalog: it was written for another
    // database, and an empty subschema would be of no use. Nothing is created
    // (0); ANewName says which schema it was
    J := 0;
    for I := 0 to LTables.Count - 1 do
      if LResolver.Resolve(JStrCI(JObj(LTables, I), 'name')) <> nil then
        Inc(J);
    if J = 0 then
    begin
      Result := 0;
      Exit;
    end;
    LSchema := AFile.AddSchema(ANewName);
    // The tables and columns that are in the catalog, as it spells them,
    // and what the file says of them
    for I := 0 to LTables.Count - 1 do
    begin
      LTable := JObj(LTables, I);
      LTableName := Trim(JStrCI(LTable, 'name'));
      if LTableName = '' then
        Continue;
      LCatalogTable := LResolver.Resolve(LTableName);
      if LCatalogTable = nil then
      begin
        AddSkipped(ASkipped, LTableName);
        Continue;
      end;
      AddUsedPlaceholders(LResolver, LTableName, LUsed);
      LTableName := JStr(LCatalogTable, 'name');
      LText := JStrCI(LTable, 'context');
      if Trim(LText) <> '' then
        AFile.SetTableContext(LTableName, LText);
      // A table twice in the file joins its columns
      if LSchema.Tables.IndexOf(LTableName) >= 0 then
        LSchema.GetColumns(LTableName, LChosen)
      else
      begin
        LSchema.Tables.Add(LTableName);
        LChosen.Clear;
      end;
      LColumns := JArrCI(LTable, 'columns');
      if LColumns <> nil then
        for J := 0 to LColumns.Count - 1 do
        begin
          LColumn := JObj(LColumns, J);
          LColumnName := Trim(JStrCI(LColumn, 'name'));
          if LColumnName = '' then
            Continue;
          LCatalogColumn := AFile.FindColumn(LTableName, LColumnName);
          if LCatalogColumn = nil then
          begin
            AddSkipped(ASkipped, LTableName + '.' + LColumnName);
            Continue;
          end;
          LColumnName := JStr(LCatalogColumn, 'name');
          LChosen.Add(LColumnName);
          LText := JStrCI(LColumn, 'context');
          if Trim(LText) <> '' then
            AFile.SetColumnContext(LTableName, LColumnName, LText);
          ImportAllowedValues(AFile, LTableName, LColumnName,
            JArrCI(LColumn, 'allowedValues'));
        end;
      // In the order of the catalog; none left: its primary key
      AFile.GetColumnNames(LTableName, LNames);
      LOrdered.Clear;
      for J := 0 to LNames.Count - 1 do
        if LChosen.IndexOf(LNames[J]) >= 0 then
          LOrdered.Add(LNames[J]);
      if LOrdered.Count = 0 then
        AFile.GetPrimaryKey(LTableName, LOrdered);
      LSchema.SetColumns(LTableName, LOrdered);
    end;
    // The relations whose two ends are in the catalog, once every table is
    // known: the description goes to the one the dictionary has, a new one
    // enters by hand (AddRelation)
    for I := 0 to LTables.Count - 1 do
    begin
      LTable := JObj(LTables, I);
      LCatalogTable := LResolver.Resolve(JStrCI(LTable, 'name'));
      LForeignKeys := JArrCI(LTable, 'foreignKeys');
      if (LCatalogTable = nil) or (LForeignKeys = nil) then
        Continue;
      for J := 0 to LForeignKeys.Count - 1 do
      begin
        LItem := JObj(LForeignKeys, J);
        if LItem = nil then
          Continue;
        LTargetTable := LResolver.Resolve(JStrCI(LItem, 'targetTable'));
        if LTargetTable = nil then
          Continue;
        LText := JStr(LTargetTable, 'name');
        ArrayNames(JArrCI(LItem, 'sourceColumns'), LSource);
        ArrayNames(JArrCI(LItem, 'targetColumns'), LTarget);
        if (LSource.Count <> LTarget.Count) or
          not ColumnsExist(LCatalogTable, LSource) or
          not ColumnsExist(LTargetTable, LTarget) then
          Continue;
        // A relation the file brings comes back if it was excluded
        AFile.AddRelation(JStr(LCatalogTable, 'name'), LText, LSource, LTarget,
          JStrCI(LItem, 'relationshipContext'), LSchema);
      end;
    end;
    Result := LSchema.Tables.Count;
    // The values that gave some table
    if ATemplateValues <> nil then
    begin
      ATemplateValues.Clear;
      for I := 0 to LResolver.Values.Count - 1 do
        if LUsed.IndexOf(LResolver.Values.Names[I]) >= 0 then
          ATemplateValues.Add(LResolver.Values[I]);
    end;
  finally
    LUsed.Free;
    LResolver.Free;
    LTarget.Free;
    LSource.Free;
    LOrdered.Free;
    LNames.Free;
    LChosen.Free;
    LRoot.Free;
  end;
end;

function RpImportSchemaJson(AFile: TRpLocalSchemaFile; const AJson,
  AFileName: string; out ANewName: string; ASkipped: TStrings;
  ATemplateValues: TStrings): Integer;
begin
  Result := ImportSchemaJson(AFile, AJson, AFileName, '', ANewName, ASkipped,
    ATemplateValues);
end;

function RpImportSchemaFile(AFile: TRpLocalSchemaFile;
  const AFileName: string; out ANewName: string; ASkipped: TStrings;
  ATemplateValues: TStrings): Integer;
begin
  Result := RpImportSchemaJson(AFile, ReadUtf8File(AFileName), AFileName,
    ANewName, ASkipped, ATemplateValues);
end;

function RpImportLibrarySchemaJson(AFile: TRpLocalSchemaFile; const AJson,
  ALibraryName: string; out ANewName: string; ASkipped: TStrings;
  ATemplateValues: TStrings): Integer;
var
  LRoot: TJSONValue;
  LWrapped: TJSONObject;
begin
  // A library schema saved as the bare array of its tables is a schema too
  try
    LRoot := TJSONObject.ParseJSONValue(AJson);
  except
    LRoot := nil;
  end;
  try
    if LRoot is TJSONArray then
    begin
      LWrapped := TJSONObject.Create;
      try
        LWrapped.AddPair('schemaTables', TJSONArray(LRoot.Clone));
        Result := ImportSchemaJson(AFile, LWrapped.ToJSON, '', ALibraryName,
          ANewName, ASkipped, ATemplateValues);
      finally
        LWrapped.Free;
      end;
      Exit;
    end;
  finally
    LRoot.Free;
  end;
  Result := ImportSchemaJson(AFile, AJson, '', ALibraryName, ANewName,
    ASkipped, ATemplateValues);
end;

function RpShortNameList(AList: TStrings; AMax: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AList.Count - 1 do
  begin
    if (I >= AMax) and (I > 0) then
    begin
      Result := Result + ', ' + CEllipsis;
      Break;
    end;
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + AList[I];
  end;
end;

end.

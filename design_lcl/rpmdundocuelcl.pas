{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdundocuelcl.pas                              }
{       Undo/Redo Cue engine for LCL Designer           }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdundocuelcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Variants, DateUtils, fpjson, jsonparser,
  Generics.Collections,
  rptypes, rpreport, rpbasereport, rpsubreport, rpsection, rpsecutil, rpprintitem;

type
  TPropertyType = (
    ptInteger = 1,
    ptNumber = 2,
    ptString = 3,
    ptDate = 4,
    ptBinary = 5,
    ptBoolean = 6,
    ptVariant = 7,
    ptStringArray = 8
  );

  { TChangeOperationItem }

  TChangeOperationItem = class
  public
    propertyName: string;
    propertyType: TPropertyType;
    oldValue: Variant;
    newValue: Variant;
    constructor Create(const APropertyName: string; APropertyType: TPropertyType;
      const AOldValue, ANewValue: Variant);
    function ToJSON: TJSONObject;
    class function FromJSON(jObj: TJSONObject): TChangeOperationItem;
  end;

  { TChangeObjectOperation }

  TChangeObjectOperation = class
  public
    operation: TOperationType;
    groupId: Integer;
    componentName: string;
    componentClass: string;
    parentName: string;
    oldItemIndex: Integer;
    oldParentName: string;
    date: TDateTime;
    expandedProperties: Boolean;
    properties: TObjectList<TChangeOperationItem>;
    constructor Create(AOperation: TOperationType; AGroupId: Integer);
    destructor Destroy; override;
    procedure AddProperty(const propName: string; propType: TPropertyType;
      const oldValue, newValue: Variant);
    function ToJSON: TJSONObject;
    class function FromJSON(jObj: TJSONObject): TChangeObjectOperation;
  end;

  { TUndoCue }

  TUndoCue = class
  private
    FGroupId: Integer;
    FReport: TRpReport;
    FCleanOpIndex: Integer;
    FMaxOperations: Integer;
    // True when the report changed through a path that is not recorded in the
    // cue (dialogs, external loads...). Only MarkClean resets it.
    FExternalDirty: Boolean;
    FOnChange: TNotifyEvent;
    FUpdateCount: Integer;
    FChangePending: Boolean;
    procedure DoChange;
    procedure TrimHistory;
    procedure ApplySwapOperation(const className: string; down: Boolean;
      aOldIndex: Integer; const aParentName: string);
    procedure ApplySwap(operation: TChangeObjectOperation; isUndo: Boolean);
    procedure MoveComponentToIndex(operation: TChangeObjectOperation;
      const newIndex: Variant);
    procedure ApplyOperation(operation: TChangeObjectOperation; isUndo: Boolean);
    procedure RecreateItem(operation: TChangeObjectOperation; isUndo: Boolean);
    procedure DeleteRemovedItem(operation: TChangeObjectOperation);
    procedure DeleteAddedItem(operation: TChangeObjectOperation);
    procedure DiscardItem(target: TObject);
    procedure ApplyParentChange(operation: TChangeObjectOperation;
      target: TObject; isUndo: Boolean);
    procedure ApplyPropertiesToObject(operation: TChangeObjectOperation;
      target: TObject; isUndo: Boolean);
    function GetComponentByName(const name: string): TObject;
    procedure AssertReportCanModify(const AReason: string);
    procedure AssertReportNotBlocked(const AReason: string);
  public
    UndoOperations: TObjectList<TChangeObjectOperation>;
    RedoOperations: TObjectList<TChangeObjectOperation>;
    constructor Create(AReport: TRpReport);
    destructor Destroy; override;
    function GetGroupId: Integer;
    // Takes ownership of op, also when it raises (the op is then freed).
    // When MaxOperations is exceeded whole oldest groups are discarded; the
    // group of the op being added is never split.
    procedure AddOperation(op: TChangeObjectOperation);
    // Defers OnChange until the matching EndUpdate, for actions that record
    // many operations. Always pair them with try/finally.
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure AddAllComponentProperties(pitem: TRpCommonPosComponent; op: TChangeObjectOperation);
    procedure AddSectionProperties(sec: TRpSection; op: TChangeObjectOperation);
    procedure AddSubreportProperties(subrep: TRpSubReport; op: TChangeObjectOperation);
    // Undo/Redo apply a whole group. If an operation fails, the operations
    // already applied stay applied (moved to the other stack), the failing
    // one and the rest of the group stay where they were, and the error is
    // re-raised: the stacks always match the report. The returned list does
    // not own the operations; the caller frees it.
    function Undo: TObjectList<TChangeObjectOperation>;
    function Redo: TObjectList<TChangeObjectOperation>;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    procedure Clear;
    procedure MarkClean;
    // Marks the report as modified by a change that is not recorded as an
    // undo operation (e.g. a dialog accepted with OK). Survives Undo/Redo/Clear.
    procedure MarkExternalChange;
    // A component was renamed: the recorded operations (undo and redo) that
    // reference OldName as component or parent use NewName from now on
    procedure RenameInHistory(const OldName, NewName: string);
    // True when an operation of the history references AName
    function HistoryUsesName(const AName: string): Boolean;
    function IsDirty: Boolean;
    procedure TruncateHistory(MaxCount: Integer);
    function ToJSON: string;
    procedure FromJSON(const jsonStr: string);

    property GroupId: Integer read FGroupId;
    property Report: TRpReport read FReport write FReport;
    property MaxOperations: Integer read FMaxOperations write FMaxOperations;
    property CleanOpIndex: Integer read FCleanOpIndex;
    // Fired after any change of the history or of the dirty state
    // (AddOperation, Undo, Redo, Clear, MarkClean, MarkExternalChange,
    // TruncateHistory). The designer uses it to refresh status and history UI.
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

const
  // Property of a otSwapUp/otSwapDown operation that moves a component to an
  // arbitrary position of its section (bring to front / send to back):
  // oldValue is the index before the action, newValue the index after it.
  // Swap operations without it are adjacent swaps at oldItemIndex.
  UndoItemIndexProperty = 'itemIndex';

// Model name used to restore an undo property on target
function MapUndoPropertyName(target: TObject; const propName: string): string;
// Current model value of an undo property of target (as Undo/Redo restore it)
function ReadUndoPropertyValue(target: TObject; const propName: string): Variant;
// Undo cue of the report that owns AItem, nil when there is none
function FindItemUndoCue(AItem: TRpCommonComponent): TUndoCue;

implementation

uses
  TypInfo, rplabelitem, rpdrawitem, rpmdbarcode, rpmdchart, rpdatainfo, rpparams;

function NewComponentByClassName(const className: string; AOwner: TComponent): TComponent; forward;

// Helper function to search for a key in a TJSONObject case-insensitively
function GetJSONDataCaseInsensitive(jObj: TJSONObject; const name1, name2: string): TJSONData;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(jObj) then Exit;
  Result := jObj.Find(name1);
  if Assigned(Result) then Exit;
  if name2 <> '' then
  begin
    Result := jObj.Find(name2);
    if Assigned(Result) then Exit;
  end;
  // Case-insensitive fallback
  for i := 0 to jObj.Count - 1 do
  begin
    if SameText(jObj.Names[i], name1) or ((name2 <> '') and SameText(jObj.Names[i], name2)) then
    begin
      Result := jObj.Items[i];
      Exit;
    end;
  end;
end;

function JSONGetStr(jObj: TJSONObject; const key1, key2: string; const def: string = ''): string;
var
  d: TJSONData;
begin
  d := GetJSONDataCaseInsensitive(jObj, key1, key2);
  if Assigned(d) and not d.IsNull then
    Result := d.AsString
  else
    Result := def;
end;

function JSONGetInt(jObj: TJSONObject; const key1, key2: string; def: Integer = 0): Integer;
var
  d: TJSONData;
begin
  d := GetJSONDataCaseInsensitive(jObj, key1, key2);
  if Assigned(d) and not d.IsNull then
    Result := d.AsInteger
  else
    Result := def;
end;

function JSONGetBool(jObj: TJSONObject; const key1, key2: string; def: Boolean = False): Boolean;
var
  d: TJSONData;
begin
  d := GetJSONDataCaseInsensitive(jObj, key1, key2);
  if Assigned(d) and not d.IsNull then
    Result := d.AsBoolean
  else
    Result := def;
end;

function JSONGetArray(jObj: TJSONObject; const key1, key2: string): TJSONArray;
var
  d: TJSONData;
begin
  d := GetJSONDataCaseInsensitive(jObj, key1, key2);
  if Assigned(d) and (d is TJSONArray) then
    Result := TJSONArray(d)
  else
    Result := nil;
end;

function VariantIsStringArray(const value: Variant): Boolean;
begin
  Result := VarIsArray(value) and ((VarType(value) and varTypeMask) = varVariant);
end;

function VariantArrayToJSONValue(const value: Variant): TJSONData;
var
  arrayValue: Variant;
  lowBound, highBound, index: Integer;
  jsonArray: TJSONArray;
begin
  arrayValue := value;
  jsonArray := TJSONArray.Create;
  if VarArrayDimCount(arrayValue) = 0 then
    Exit(jsonArray);
  lowBound := VarArrayLowBound(arrayValue, 1);
  highBound := VarArrayHighBound(arrayValue, 1);
  if highBound < lowBound then
    Exit(jsonArray);
  for index := lowBound to highBound do
    jsonArray.Add(VarToStr(arrayValue[index]));
  Result := jsonArray;
end;

function StringsToVariantArray(strings: TStrings): Variant;
var
  index: Integer;
begin
  if strings.Count = 0 then
  begin
    Result := VarArrayCreate([0, -1], varVariant);
    Exit;
  end;
  Result := VarArrayCreate([0, strings.Count - 1], varVariant);
  for index := 0 to strings.Count - 1 do
    Result[index] := strings[index];
end;

procedure VariantArrayToStrings(const value: Variant; strings: TStrings);
var
  arrayValue: Variant;
  lowBound, highBound, index: Integer;
begin
  strings.Clear;
  if not VarIsArray(value) then
  begin
    if VarIsEmpty(value) then
      Exit;
    if not VarIsNull(value) then
      strings.Add(VarToStr(value));
    Exit;
  end;

  arrayValue := value;
  if VarArrayDimCount(arrayValue) = 0 then
    Exit;
  lowBound := VarArrayLowBound(arrayValue, 1);
  highBound := VarArrayHighBound(arrayValue, 1);
  if highBound < lowBound then
    Exit;
  for index := lowBound to highBound do
    strings.Add(VarToStr(arrayValue[index]));
end;

function JSONStringArrayToVariant(jData: TJSONData): Variant;
var
  jsonArray: TJSONArray;
  index: Integer;
begin
  if not (jData is TJSONArray) then
    Exit(Unassigned);

  jsonArray := TJSONArray(jData);
  if jsonArray.Count = 0 then
  begin
    Result := VarArrayCreate([0, -1], varVariant);
    Exit;
  end;
  Result := VarArrayCreate([0, jsonArray.Count - 1], varVariant);
  for index := 0 to jsonArray.Count - 1 do
    Result[index] := jsonArray.Items[index].AsString;
end;

function DateTimeToJavaScriptJSON(const value: TDateTime): string;
var
  utcValue: TDateTime;
begin
  utcValue := LocalTimeToUniversal(value);
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz"Z"', utcValue);
end;

function VariantTypeToJSONName(const value: Variant): string;
var
  variantType: Integer;
begin
  if VarIsNull(value) then
    Exit('Null');

  variantType := VarType(value) and varTypeMask;
  case variantType of
    varByte:
      Result := 'Byte';
    varBoolean:
      Result := 'Boolean';
    varShortInt, varSmallint, varInteger, varWord:
      Result := 'Integer';
    varLongWord, varInt64:
      Result := 'Long';
    varSingle, varDouble:
      Result := 'Double';
    varCurrency:
      Result := 'Decimal';
    varDate:
      Result := 'DateTime';
  else
    Result := 'String';
  end;
end;

function VariantToTypedJSONValue(const value: Variant): TJSONData;
var
  jsonObject: TJSONObject;
  typeName: string;
begin
  jsonObject := TJSONObject.Create;
  typeName := VariantTypeToJSONName(value);
  jsonObject.Add('type', typeName);
  if typeName = 'Null' then
    jsonObject.Add('value', TJSONNull.Create)
  else if typeName = 'Boolean' then
    jsonObject.Add('value', Boolean(value))
  else if (typeName = 'Integer') or (typeName = 'Byte') then
    jsonObject.Add('value', Integer(value))
  else if typeName = 'Long' then
    jsonObject.Add('value', Int64(value))
  else if typeName = 'Decimal' then
    jsonObject.Add('value', Double(VarAsType(value, varDouble)))
  else if typeName = 'Double' then
    jsonObject.Add('value', Double(VarAsType(value, varDouble)))
  else if typeName = 'DateTime' then
    jsonObject.Add('value', DateTimeToJavaScriptJSON(VarToDateTime(value)))
  else
    jsonObject.Add('value', VarToStr(value));
  Result := jsonObject;
end;

function JSONTypedValueToVariant(jData: TJSONData): Variant;
var
  jsonObject: TJSONObject;
  typeValue, valueNode: TJSONData;
  typeName, valueText: string;
  dateValue: TDateTime;
begin
  if jData = nil then
    Exit(Unassigned);
  if jData.IsNull then
    Exit(Null);

  if not (jData is TJSONObject) then
    Exit(Unassigned);

  jsonObject := TJSONObject(jData);
  typeValue := GetJSONDataCaseInsensitive(jsonObject, 'type', 'Type');
  valueNode := GetJSONDataCaseInsensitive(jsonObject, 'value', 'Value');
  if typeValue = nil then
    Exit(Unassigned);
  if valueNode = nil then
    Exit(Unassigned);

  typeName := typeValue.AsString;
  if SameText(typeName, 'Null') or valueNode.IsNull then
    Exit(Null);
  if SameText(typeName, 'Boolean') then
    Exit(valueNode.AsBoolean);
  if SameText(typeName, 'Byte') then
    Exit(Byte(valueNode.AsInteger));
  if SameText(typeName, 'Integer') then
    Exit(valueNode.AsInteger);
  if SameText(typeName, 'Long') then
    Exit(valueNode.AsInt64);
  if SameText(typeName, 'Decimal') then
    Exit(VarAsType(valueNode.AsFloat, varCurrency));
  if SameText(typeName, 'Double') then
    Exit(valueNode.AsFloat);
  if SameText(typeName, 'DateTime') then
  begin
    // Like the VCL cue: a value that is not ISO 8601 is kept as the raw text
    valueText := valueNode.AsString;
    if TryISO8601ToDate(valueText, dateValue, False) then
      Exit(dateValue);
    Exit(valueText);
  end;
  Exit(valueNode.AsString);
end;

function VariantToJSONValue(const value: Variant; propType: TPropertyType): TJSONData;
var
  variantType: Integer;
begin
  if (propType = ptStringArray) and VariantIsStringArray(value) then
    Exit(VariantArrayToJSONValue(value));

  if propType = ptVariant then
    Exit(VariantToTypedJSONValue(value));

  if VarIsNull(value) then
    Exit(TJSONNull.Create);

  variantType := VarType(value) and varTypeMask;
  case variantType of
    varShortInt, varSmallint, varInteger, varByte, varWord, varLongWord, varInt64:
      Result := TJSONInt64Number.Create(Int64(VarAsType(value, varInt64)));
    varSingle, varDouble, varCurrency:
      Result := TJSONFloatNumber.Create(Double(VarAsType(value, varDouble)));
    varBoolean:
      Result := TJSONBoolean.Create(Boolean(value));
    varDate:
      Result := TJSONString.Create(DateTimeToJavaScriptJSON(VarToDateTime(value)));
  else
    Result := TJSONString.Create(VarToStr(value));
  end;
end;

function JSONValueToVariant(jData: TJSONData; propType: TPropertyType): Variant;
var
  typedValue: Variant;
  dateValue: TDateTime;
begin
  if jData = nil then
    Exit(Unassigned);
  if jData.IsNull then
    Exit(Null);

  if propType = ptStringArray then
    Exit(JSONStringArrayToVariant(jData));

  if propType = ptVariant then
  begin
    typedValue := JSONTypedValueToVariant(jData);
    if not VarIsEmpty(typedValue) then
      Exit(typedValue);
  end;

  if jData.JSONType = jtBoolean then
    Exit(jData.AsBoolean);

  if jData.JSONType = jtNumber then
  begin
    if (jData is TJSONFloatNumber) then
      Exit(jData.AsFloat)
    else
      Exit(jData.AsInt64);
  end;

  if jData.JSONType = jtString then
  begin
    // Like the VCL cue: a date that is not ISO 8601 is kept as the raw text
    if (propType = ptDate) and TryISO8601ToDate(jData.AsString, dateValue, False) then
      Exit(dateValue);
    Exit(jData.AsString);
  end;

  Result := jData.AsJSON;
end;

function NormalizeUndoPropertyValue(propType: TPropertyType;
  const value: Variant): Variant;
begin
  if not VarIsNull(value) then
    Exit(value);

  case propType of
    ptInteger, ptBinary:
      Result := 0;
    ptNumber:
      Result := 0.0;
    ptString, ptDate:
      Result := '';
    ptBoolean:
      Result := False;
    ptStringArray:
      Result := VarArrayCreate([0, -1], varVariant);
  else
    Result := value;
  end;
end;

function MapUndoPropertyName(target: TObject; const propName: string): string;
begin
  Result := propName;

  if SameText(propName, 'posX') then Exit('PosX');
  if SameText(propName, 'posY') then Exit('PosY');
  if SameText(propName, 'width') then Exit('Width');
  if SameText(propName, 'height') then Exit('Height');
  if SameText(propName, 'align') then Exit('Align');
  if SameText(propName, 'annotationExpression') then Exit('AnnotationExpression');
  if SameText(propName, 'printCondition') then Exit('PrintCondition');
  if SameText(propName, 'doBeforePrint') then Exit('DoBeforePrint');
  if SameText(propName, 'doAfterPrint') then Exit('DoAfterPrint');
  if SameText(propName, 'visible') then Exit('Visible');
  if SameText(propName, 'wFontName') then Exit('WFontName');
  if SameText(propName, 'lFontName') then Exit('LFontName');
  if SameText(propName, 'fontSize') then Exit('FontSize');
  if SameText(propName, 'fontColor') then Exit('FontColor');
  if SameText(propName, 'fontStyle') then Exit('FontStyle');
  if SameText(propName, 'backColor') then Exit('BackColor');
  if SameText(propName, 'transparent') then Exit('Transparent');
  if SameText(propName, 'cutText') then Exit('CutText');
  if SameText(propName, 'wordWrap') then Exit('WordWrap');
  if SameText(propName, 'wordBreak') then Exit('WordBreak');
  if SameText(propName, 'singleLine') then Exit('SingleLine');
  if SameText(propName, 'alignment') then Exit('Alignment');
  if SameText(propName, 'vAlignment') then Exit('VAlignment');
  if SameText(propName, 'fontRotation') then Exit('FontRotation');
  if SameText(propName, 'type1Font') then Exit('Type1Font');
  if SameText(propName, 'printStep') then Exit('PrintStep');
  if SameText(propName, 'interLine') then Exit('InterLine');
  if SameText(propName, 'multiPage') then Exit('MultiPage');
  if SameText(propName, 'rightToLeft') then Exit('RightToLeft');
  if SameText(propName, 'isHtml') then Exit('IsHtml');
  if SameText(propName, 'allStrings') then Exit('Text');
  if SameText(propName, 'expression') then Exit('Expression');
  if SameText(propName, 'displayFormat') then Exit('DisplayFormat');
  if SameText(propName, 'dataType') then Exit('DataType');
  if SameText(propName, 'identifier') then Exit('Identifier');
  if SameText(propName, 'aggregate') then Exit('Aggregate');
  if SameText(propName, 'groupName') then Exit('GroupName');
  if SameText(propName, 'agType') then Exit('AgType');
  if SameText(propName, 'agIniValue') then Exit('AgIniValue');
  if SameText(propName, 'autoExpand') then Exit('AutoExpand');
  if SameText(propName, 'autoContract') then Exit('AutoContract');
  if SameText(propName, 'printOnlyOne') then Exit('PrintOnlyOne');
  if SameText(propName, 'printNulls') then Exit('PrintNulls');
  if SameText(propName, 'chartStyle') then Exit('ChartType');
  if SameText(propName, 'changeSerieBool') then Exit('ChangeSerieBool');
  if SameText(propName, 'clearExpressionBool') then Exit('ClearExpressionBool');
  if SameText(propName, 'driver') then Exit('Driver');
  if SameText(propName, 'view3d') then Exit('View3d');
  if SameText(propName, 'view3dWalls') then Exit('View3dWalls');
  if SameText(propName, 'perspective') then Exit('Perspective');
  if SameText(propName, 'elevation') then Exit('Elevation');
  if SameText(propName, 'rotation') then Exit('Rotation');
  if SameText(propName, 'zoom') then Exit('Zoom');
  if SameText(propName, 'horzOffset') then Exit('HorzOffset');
  if SameText(propName, 'vertOffset') then Exit('VertOffset');
  if SameText(propName, 'tilt') then Exit('Tilt');
  if SameText(propName, 'orthogonal') then Exit('Orthogonal');
  if SameText(propName, 'multiBar') then Exit('MultiBar');
  if SameText(propName, 'resolution') then Exit('Resolution');
  if SameText(propName, 'showLegend') then Exit('ShowLegend');
  if SameText(propName, 'showHint') then Exit('ShowHint');
  if SameText(propName, 'markStyle') then Exit('MarkStyle');
  if SameText(propName, 'horzFontSize') then Exit('HorzFontSize');
  if SameText(propName, 'vertFontSize') then Exit('VertFontSize');
  if SameText(propName, 'horzFontRotation') then Exit('HorzFontRotation');
  if SameText(propName, 'vertFontRotation') then Exit('VertFontRotation');
  if SameText(propName, 'brushStyle') then Exit('BrushStyle');
  if SameText(propName, 'brushColor') then Exit('BrushColor');
  if SameText(propName, 'penStyle') then Exit('PenStyle');
  if SameText(propName, 'penColor') then Exit('PenColor');
  if SameText(propName, 'shape') then Exit('Shape');
  if SameText(propName, 'penWidth') then Exit('PenWidth');
  if SameText(propName, 'dpiRes') then Exit('dpires');
  if SameText(propName, 'drawStyle') then Exit('DrawStyle');
  if SameText(propName, 'copyMode') then Exit('CopyMode');
  if SameText(propName, 'barType') then Exit('Typ');
  if SameText(propName, 'checksum') then Exit('Checksum');
  if SameText(propName, 'bColor') then Exit('BColor');
  if SameText(propName, 'numColumns') then Exit('NumColumns');
  if SameText(propName, 'numRows') then Exit('NumRows');
  if SameText(propName, 'eccLevel') then Exit('ECCLevel');
  if SameText(propName, 'truncated') then Exit('Truncated');
  if SameText(propName, 'alias') and (target is TRpParam) then Exit('Name');
  if SameText(propName, 'paramType') then Exit('ParamType');
  if SameText(propName, 'neverVisible') then Exit('NeverVisible');
  if SameText(propName, 'isReadOnly') then Exit('IsReadOnly');
  if SameText(propName, 'allowNulls') then Exit('AllowNulls');
  if SameText(propName, 'description') then Exit('Description');
  if SameText(propName, 'hint') then Exit('Hint');
  if SameText(propName, 'errorMessage') then Exit('ErrorMessage');
  if SameText(propName, 'lookupDataset') then Exit('LookupDataset');
  if SameText(propName, 'searchDataset') then Exit('SearchDataset');
  if SameText(propName, 'searchParam') then Exit('SearchParam');
  if SameText(propName, 'configFile') then Exit('ConfigFile');
  if SameText(propName, 'loginPrompt') then Exit('LoginPrompt');
  if SameText(propName, 'loadParams') then Exit('LoadParams');
  if SameText(propName, 'loadDriverParams') then Exit('LoadDriverParams');
  if SameText(propName, 'connectionString') then Exit('ADOConnectionString');
  if SameText(propName, 'providerFactory') then Exit('ProviderFactory');
  if SameText(propName, 'dotNetDriver') then Exit('DotNetDriver');
  if SameText(propName, 'databaseAlias') then Exit('DatabaseAlias');
  if SameText(propName, 'hubSchemaId') then Exit('HubSchemaId');
  if SameText(propName, 'sql') then Exit('SQL');
  if SameText(propName, 'dataSource') then Exit('DataSource');
  if SameText(propName, 'groupUnion') then Exit('GroupUnion');
  if SameText(propName, 'openOnStart') then Exit('OpenOnStart');
  if SameText(propName, 'parallelUnion') then Exit('ParallelUnion');
  if SameText(propName, 'dataUnions') then Exit('DataUnions');
end;

function ApplyStringArrayProperty(target: TObject; const propName: string;
  const value: Variant): Boolean;
var
  list: TStringList;
begin
  Result := True;
  list := TStringList.Create;
  try
    VariantArrayToStrings(value, list);
    if (target is TRpParam) then
    begin
      if SameText(propName, 'Items') then
        TRpParam(target).Items.Assign(list)
      else if SameText(propName, 'Values') then
        TRpParam(target).Values.Assign(list)
      else if SameText(propName, 'Datasets') then
        TRpParam(target).Datasets.Assign(list)
      else if SameText(propName, 'Selected') then
        TRpParam(target).Selected.Assign(list)
      else
        Result := False;
    end
    else if (target is TRpDataInfoItem) and SameText(propName, 'DataUnions') then
      TRpDataInfoItem(target).DataUnions.Assign(list)
    else
      Result := False;
  finally
    list.Free;
  end;
end;

function GetUndoPropertiesItem(target: TObject): IPropertiesItem;
begin
  if not Assigned(target) then
    raise Exception.Create('UndoCue: no target object to apply the properties');
  if (target is TRpCommonComponent) then
    Result := TRpCommonComponent(target)
  else if (target is TRpBaseReport) then
    Result := TRpBaseReport(target)
  else if (target is TRpParam) then
    Result := TRpParam(target)
  else if (target is TRpDataInfoItem) then
    Result := TRpDataInfoItem(target)
  else if (target is TRpDatabaseInfoItem) then
    Result := TRpDatabaseInfoItem(target)
  else if (target is TRpSubReport) then
    Result := TRpSubReport(target)
  else
    raise Exception.Create('Object does not support IPropertiesItem: ' + target.ClassName);
end;

function ReadUndoPropertyValue(target: TObject; const propName: string): Variant;
begin
  Result := GetUndoPropertiesItem(target).GetItemProperty(
    MapUndoPropertyName(target, propName));
end;

function FindItemUndoCue(AItem: TRpCommonComponent): TUndoCue;
begin
  Result := nil;
  if Assigned(AItem) and (AItem.Report is TRpBaseReport) and
     (TRpBaseReport(AItem.Report).UndoCue is TUndoCue) then
    Result := TUndoCue(TRpBaseReport(AItem.Report).UndoCue);
end;

function FindOperationProperty(operation: TChangeObjectOperation;
  const propName: string): TChangeOperationItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to operation.properties.Count - 1 do
  begin
    if SameText(operation.properties[i].propertyName, propName) then
    begin
      Result := operation.properties[i];
      Exit;
    end;
  end;
end;

function OperationDescription(operation: TChangeObjectOperation): string;
begin
  Result := GetEnumName(TypeInfo(TOperationType), Ord(operation.operation)) +
    ' ' + operation.componentClass + ' ' + operation.componentName;
end;

{ TChangeOperationItem }

constructor TChangeOperationItem.Create(const APropertyName: string;
  APropertyType: TPropertyType; const AOldValue, ANewValue: Variant);
begin
  inherited Create;
  propertyName := APropertyName;
  propertyType := APropertyType;
  oldValue := AOldValue;
  newValue := ANewValue;
end;

function TChangeOperationItem.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('propertyName', propertyName);
  Result.Add('propertyType', Ord(propertyType));
  if not VarIsEmpty(oldValue) then
    Result.Add('oldValue', VariantToJSONValue(oldValue, propertyType));
  if not VarIsEmpty(newValue) then
    Result.Add('newValue', VariantToJSONValue(newValue, propertyType));
end;

class function TChangeOperationItem.FromJSON(jObj: TJSONObject): TChangeOperationItem;
var
  propName: string;
  pt: TPropertyType;
  oldJson, newJson: TJSONData;
begin
  propName := JSONGetStr(jObj, 'propertyName', 'PropertyName');
  pt := TPropertyType(JSONGetInt(jObj, 'propertyType', 'PropertyType', 1));
  oldJson := GetJSONDataCaseInsensitive(jObj, 'oldValue', 'OldValue');
  newJson := GetJSONDataCaseInsensitive(jObj, 'newValue', 'NewValue');
  Result := TChangeOperationItem.Create(propName, pt,
    JSONValueToVariant(oldJson, pt), JSONValueToVariant(newJson, pt));
end;

{ TChangeObjectOperation }

constructor TChangeObjectOperation.Create(AOperation: TOperationType; AGroupId: Integer);
begin
  inherited Create;
  operation := AOperation;
  groupId := AGroupId;
  date := Now;
  oldItemIndex := -1;
  expandedProperties := True;
  properties := TObjectList<TChangeOperationItem>.Create(True);
end;

destructor TChangeObjectOperation.Destroy;
begin
  properties.Free;
  inherited Destroy;
end;

procedure TChangeObjectOperation.AddProperty(const propName: string;
  propType: TPropertyType; const oldValue, newValue: Variant);
var
  storedOldValue, storedNewValue: Variant;
begin
  storedOldValue := oldValue;
  storedNewValue := newValue;
  if (operation = otAdd) and VarIsNull(storedOldValue) then
    storedOldValue := Unassigned;
  if (operation = otRemove) and VarIsNull(storedNewValue) then
    storedNewValue := Unassigned;
  properties.Add(TChangeOperationItem.Create(propName, propType, storedOldValue, storedNewValue));
  if properties.Count > 5 then
    expandedProperties := False;
end;

function TChangeObjectOperation.ToJSON: TJSONObject;
var
  propsArr: TJSONArray;
  i: Integer;
begin
  Result := TJSONObject.Create;
  if componentName <> '' then
    Result.Add('componentName', componentName);
  if componentClass <> '' then
    Result.Add('componentClass', componentClass);
  if parentName <> '' then
    Result.Add('parentName', parentName);
  if oldItemIndex >= 0 then
    Result.Add('oldItemIndex', oldItemIndex);
  if oldParentName <> '' then
    Result.Add('oldParentName', oldParentName);
  Result.Add('date', DateTimeToJavaScriptJSON(date));
  propsArr := TJSONArray.Create;
  for i := 0 to properties.Count - 1 do
    propsArr.Add(properties[i].ToJSON);
  Result.Add('properties', propsArr);
  Result.Add('expandedProperties', expandedProperties);
  Result.Add('operation', Ord(operation));
  Result.Add('groupId', groupId);
end;

class function TChangeObjectOperation.FromJSON(jObj: TJSONObject): TChangeObjectOperation;
var
  propsArr: TJSONArray;
  i: Integer;
  propObj: TJSONObject;
  dateStr: string;
  opDate: TDateTime;
begin
  Result := TChangeObjectOperation.Create(
    TOperationType(JSONGetInt(jObj, 'operation', 'Operation', 0)),
    JSONGetInt(jObj, 'groupId', 'GroupId', 0)
  );
  Result.componentName := JSONGetStr(jObj, 'componentName', 'ComponentName');
  Result.componentClass := JSONGetStr(jObj, 'componentClass', 'ComponentClass');
  Result.parentName := JSONGetStr(jObj, 'parentName', 'ParentName');
  Result.oldItemIndex := JSONGetInt(jObj, 'oldItemIndex', 'OldItemIndex', -1);
  Result.oldParentName := JSONGetStr(jObj, 'oldParentName', 'OldParentName');
  Result.expandedProperties := JSONGetBool(jObj, 'expandedProperties', 'ExpandedProperties', True);
  // The operation date is only informative (history panel): like the VCL cue,
  // a missing or unparsable date becomes the load time
  dateStr := JSONGetStr(jObj, 'date', 'Date');
  if (dateStr <> '') and TryISO8601ToDate(dateStr, opDate, False) then
    Result.date := opDate
  else
    Result.date := Now;

  propsArr := JSONGetArray(jObj, 'properties', 'Properties');
  if Assigned(propsArr) then
  begin
    for i := 0 to propsArr.Count - 1 do
    begin
      if propsArr.Items[i] is TJSONObject then
      begin
        propObj := TJSONObject(propsArr.Items[i]);
        Result.properties.Add(TChangeOperationItem.FromJSON(propObj));
      end;
    end;
  end;
end;

{ TUndoCue }

constructor TUndoCue.Create(AReport: TRpReport);
begin
  inherited Create;
  FReport := AReport;
  FGroupId := 0;
  FCleanOpIndex := 0;
  // Unlimited by default, like the VCL undo cue; hosts may set a cap
  FMaxOperations := 0;
  UndoOperations := TObjectList<TChangeObjectOperation>.Create(True);
  RedoOperations := TObjectList<TChangeObjectOperation>.Create(True);
end;

destructor TUndoCue.Destroy;
begin
  UndoOperations.Free;
  RedoOperations.Free;
  inherited Destroy;
end;

procedure TUndoCue.AssertReportCanModify(const AReason: string);
begin
  if Assigned(FReport) then
    FReport.AssertCanModify('UndoCue.' + AReason);
end;

procedure TUndoCue.AssertReportNotBlocked(const AReason: string);
begin
  if Assigned(FReport) and FReport.BlockChanges then
    raise Exception.Create('UndoCue reached while report changes are blocked: ' + AReason);
end;

function TUndoCue.GetGroupId: Integer;
begin
  AssertReportCanModify('GetGroupId');
  if (UndoOperations.Count > 0) or ((RedoOperations.Count > 0) and (FGroupId = 0)) then
  begin
    if UndoOperations.Count > 0 then
      FGroupId := UndoOperations.Last.groupId;
    if RedoOperations.Count > 0 then
      if RedoOperations.First.groupId > FGroupId then
        FGroupId := RedoOperations.First.groupId;
  end;
  Inc(FGroupId);
  Result := FGroupId;
end;

procedure TUndoCue.AddOperation(op: TChangeObjectOperation);
var
  isPosComp: Boolean;
begin
  try
    AssertReportNotBlocked('AddOperation');
    if (op.operation = otAdd) or (op.operation = otRemove) then
    begin
      isPosComp := (op.componentClass = 'TRPLABEL') or (op.componentClass = 'TRPEXPRESSION') or
                   (op.componentClass = 'TRPSHAPE') or (op.componentClass = 'TRPIMAGE') or
                   (op.componentClass = 'TRPBARCODE') or (op.componentClass = 'TRPCHART');
      if isPosComp and (op.parentName = '') then
        raise Exception.Create('UndoCue: La sección del componente no tiene nombre');
    end;
  except
    // The cue owns the operation from the call on: do not leak it
    op.Free;
    raise;
  end;

  // The saved (clean) state lies in the redo branch that this new operation
  // discards: it can never be reached again.
  if FCleanOpIndex > UndoOperations.Count then
    FCleanOpIndex := -1;

  UndoOperations.Add(op);
  RedoOperations.Clear;
  TrimHistory;

  if Assigned(FReport) then
    FReport.Modified := IsDirty;
  DoChange;
end;

procedure TUndoCue.TrimHistory;
var
  oldestGroup, trimmed: Integer;
begin
  if FMaxOperations <= 0 then
    Exit;
  // Discard whole groups from the oldest end, so undo never restores half
  // an action. The newest group (the one being recorded) is never trimmed,
  // even when it alone exceeds the limit.
  while UndoOperations.Count > FMaxOperations do
  begin
    oldestGroup := UndoOperations.First.groupId;
    if oldestGroup = UndoOperations.Last.groupId then
      Break;
    trimmed := 0;
    while (UndoOperations.Count > 0) and (UndoOperations.First.groupId = oldestGroup) do
    begin
      UndoOperations.Delete(0);
      Inc(trimmed);
    end;
    // The clean point counts operations from the oldest one: shift it, or
    // forget it when it lay inside the discarded part
    if FCleanOpIndex >= trimmed then
      Dec(FCleanOpIndex, trimmed)
    else if FCleanOpIndex >= 0 then
      FCleanOpIndex := -1;
  end;
end;

procedure TUndoCue.DoChange;
begin
  if FUpdateCount > 0 then
  begin
    FChangePending := True;
    Exit;
  end;
  FChangePending := False;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TUndoCue.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TUndoCue.EndUpdate;
begin
  if FUpdateCount <= 0 then
    raise Exception.Create('UndoCue.EndUpdate without BeginUpdate');
  Dec(FUpdateCount);
  if (FUpdateCount = 0) and FChangePending then
    DoChange;
end;

procedure TUndoCue.Clear;
begin
  // Clearing the history must not hide unsaved changes: keep the dirty state
  // as an external change (MarkClean resets it after load/save).
  if IsDirty then
    FExternalDirty := True;
  UndoOperations.Clear;
  RedoOperations.Clear;
  FCleanOpIndex := 0;
  if Assigned(FReport) then
    FReport.Modified := IsDirty;
  DoChange;
end;

procedure TUndoCue.MarkClean;
begin
  FCleanOpIndex := UndoOperations.Count;
  FExternalDirty := False;
  if Assigned(FReport) then
    FReport.Modified := False;
  DoChange;
end;

procedure TUndoCue.MarkExternalChange;
begin
  FExternalDirty := True;
  if Assigned(FReport) then
    FReport.Modified := True;
  DoChange;
end;

procedure TUndoCue.RenameInHistory(const OldName, NewName: string);

  procedure RenameOps(ops: TObjectList<TChangeObjectOperation>);
  var
    i: Integer;
  begin
    for i := 0 to ops.Count - 1 do
    begin
      if SameText(ops[i].componentName, OldName) then
        ops[i].componentName := NewName;
      if SameText(ops[i].parentName, OldName) then
        ops[i].parentName := NewName;
      if SameText(ops[i].oldParentName, OldName) then
        ops[i].oldParentName := NewName;
    end;
  end;

begin
  if (OldName = '') or SameText(OldName, NewName) then
    Exit;
  RenameOps(UndoOperations);
  RenameOps(RedoOperations);
  DoChange;
end;

function TUndoCue.HistoryUsesName(const AName: string): Boolean;

  function UsedIn(ops: TObjectList<TChangeObjectOperation>): Boolean;
  var
    i: Integer;
  begin
    Result := False;
    for i := 0 to ops.Count - 1 do
      if SameText(ops[i].componentName, AName) or SameText(ops[i].parentName, AName) or
         SameText(ops[i].oldParentName, AName) then
        Exit(True);
  end;

begin
  Result := (AName <> '') and (UsedIn(UndoOperations) or UsedIn(RedoOperations));
end;

function TUndoCue.IsDirty: Boolean;
begin
  Result := FExternalDirty or (FCleanOpIndex < 0) or
    (UndoOperations.Count <> FCleanOpIndex);
end;

procedure TUndoCue.TruncateHistory(MaxCount: Integer);
begin
  if MaxCount <= 0 then Exit;
  FMaxOperations := MaxCount;
  TrimHistory;
  DoChange;
end;

function TUndoCue.CanUndo: Boolean;
begin
  Result := Assigned(UndoOperations) and (UndoOperations.Count > 0);
end;

function TUndoCue.CanRedo: Boolean;
begin
  Result := Assigned(RedoOperations) and (RedoOperations.Count > 0);
end;

function TUndoCue.Undo: TObjectList<TChangeObjectOperation>;
var
  op: TChangeObjectOperation;
  gId: Integer;
begin
  AssertReportNotBlocked('Undo');
  if UndoOperations.Count = 0 then
    Exit(nil);

  Result := TObjectList<TChangeObjectOperation>.Create(False);
  try
    try
      gId := UndoOperations.Last.groupId;
      while (UndoOperations.Count > 0) and (UndoOperations.Last.groupId = gId) do
      begin
        op := UndoOperations.ExtractIndex(UndoOperations.Count - 1);
        try
          ApplyOperation(op, True);
        except
          on E: Exception do
          begin
            // Not undone: it stays the next operation to undo
            UndoOperations.Add(op);
            raise Exception.Create('UndoCue: undo of ' + OperationDescription(op) +
              ' failed: ' + E.Message);
          end;
        end;
        RedoOperations.Add(op);
        Result.Add(op);
      end;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    // Also after a failure: the operations already undone changed the report
    if Assigned(FReport) then
      FReport.Modified := IsDirty;
    DoChange;
  end;
end;

function TUndoCue.Redo: TObjectList<TChangeObjectOperation>;
var
  op: TChangeObjectOperation;
  gId: Integer;
begin
  AssertReportNotBlocked('Redo');
  if RedoOperations.Count = 0 then
    Exit(nil);

  Result := TObjectList<TChangeObjectOperation>.Create(False);
  try
    try
      gId := RedoOperations.Last.groupId;
      while (RedoOperations.Count > 0) and (RedoOperations.Last.groupId = gId) do
      begin
        op := RedoOperations.ExtractIndex(RedoOperations.Count - 1);
        try
          ApplyOperation(op, False);
        except
          on E: Exception do
          begin
            // Not redone: it stays the next operation to redo
            RedoOperations.Add(op);
            raise Exception.Create('UndoCue: redo of ' + OperationDescription(op) +
              ' failed: ' + E.Message);
          end;
        end;
        UndoOperations.Add(op);
        Result.Add(op);
      end;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    // Also after a failure: the operations already redone changed the report
    if Assigned(FReport) then
      FReport.Modified := IsDirty;
    DoChange;
  end;
end;

function TUndoCue.GetComponentByName(const name: string): TObject;
var
  compo: TObject;
begin
  if UpperCase(name) = 'REPORT' then
    Result := FReport
  else
  begin
    compo := FReport.FindReporItemByName(name);
    if not Assigned(compo) then
      raise Exception.Create('Item not found at apply Operation undo/redo cue: ' + name);
    Result := compo;
  end;
end;

procedure TUndoCue.ApplySwapOperation(const className: string; down: Boolean;
  aOldIndex: Integer; const aParentName: string);
var
  increment: Integer;
  subreport: TRpSubReport;
  section: TRpSection;
  parentItem: TObject;

  procedure CheckSwapRange(ACount: Integer);
  begin
    if (aOldIndex < 0) or (aOldIndex >= ACount) or
       (aOldIndex + increment < 0) or (aOldIndex + increment >= ACount) then
      raise Exception.CreateFmt('UndoCue: swap of %s from %d to %d out of range (count %d)',
        [className, aOldIndex, aOldIndex + increment, ACount]);
  end;

begin
  if down then
    increment := 1
  else
    increment := -1;

  if className = 'TRPSUBREPORT' then
  begin
    CheckSwapRange(FReport.SubReports.Count);
    FReport.SubReports.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPSECTION' then
  begin
    if aParentName = '' then
      raise Exception.Create('Parent name required for TRPSECTION swap.');
    parentItem := GetComponentByName(aParentName);
    if not (parentItem is TRpSubReport) then
      raise Exception.Create('UndoCue: parent of a section swap is not a subreport: ' + aParentName);
    subreport := TRpSubReport(parentItem);
    CheckSwapRange(subreport.Sections.Count);
    subreport.Sections.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if (className = 'TRPLABEL') or (className = 'TRPEXPRESSION') or
          (className = 'TRPSHAPE') or (className = 'TRPIMAGE') or
          (className = 'TRPBARCODE') or (className = 'TRPCHART') then
  begin
    if aParentName = '' then
      raise Exception.Create('Parent name required for component swap.');
    parentItem := GetComponentByName(aParentName);
    if not (parentItem is TRpSection) then
      raise Exception.Create('UndoCue: parent of a component swap is not a section: ' + aParentName);
    section := TRpSection(parentItem);
    CheckSwapRange(section.Components.Count);
    section.Components.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPPARAM' then
  begin
    CheckSwapRange(FReport.Params.Count);
    FReport.Params.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPDATAINFOITEM' then
  begin
    CheckSwapRange(FReport.DataInfo.Count);
    FReport.DataInfo.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPDATABASEINFOITEM' then
  begin
    CheckSwapRange(FReport.DatabaseInfo.Count);
    FReport.DatabaseInfo.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else
    raise Exception.Create('Swap not supported for className: ' + className);
end;

procedure TUndoCue.ApplySwap(operation: TChangeObjectOperation; isUndo: Boolean);
var
  indexProp: TChangeOperationItem;
begin
  indexProp := FindOperationProperty(operation, UndoItemIndexProperty);
  if Assigned(indexProp) then
  begin
    // Bring to front / send to back: the component goes back to (undo) or
    // again to (redo) its recorded position
    if isUndo then
      MoveComponentToIndex(operation, indexProp.oldValue)
    else
      MoveComponentToIndex(operation, indexProp.newValue);
    Exit;
  end;

  // Adjacent swap: the item at oldItemIndex moved one position down/up
  if isUndo then
  begin
    if operation.operation = otSwapDown then
      ApplySwapOperation(operation.componentClass, False, operation.oldItemIndex + 1, operation.parentName)
    else
      ApplySwapOperation(operation.componentClass, True, operation.oldItemIndex - 1, operation.parentName);
  end
  else
  begin
    if operation.operation = otSwapDown then
      ApplySwapOperation(operation.componentClass, True, operation.oldItemIndex, operation.parentName)
    else
      ApplySwapOperation(operation.componentClass, False, operation.oldItemIndex, operation.parentName);
  end;
end;

procedure TUndoCue.MoveComponentToIndex(operation: TChangeObjectOperation;
  const newIndex: Variant);
var
  parentItem, target: TObject;
  section: TRpSection;
  currentIndex, targetIndex: Integer;
begin
  if VarIsNull(newIndex) or VarIsEmpty(newIndex) then
    raise Exception.Create('UndoCue: no position recorded for ' + OperationDescription(operation));
  targetIndex := newIndex;
  parentItem := GetComponentByName(operation.parentName);
  if not (parentItem is TRpSection) then
    raise Exception.Create('UndoCue: parent of a component move is not a section: ' +
      operation.parentName);
  section := TRpSection(parentItem);
  target := GetComponentByName(operation.componentName);
  if not (target is TRpCommonComponent) then
    raise Exception.Create('UndoCue: ' + operation.componentName + ' is not a section component');
  currentIndex := section.ReportComponents.IndexOf(TRpCommonComponent(target));
  if currentIndex < 0 then
    raise Exception.Create('UndoCue: ' + operation.componentName + ' not found in section ' +
      operation.parentName);
  if (targetIndex < 0) or (targetIndex >= section.ReportComponents.Count) then
    raise Exception.CreateFmt('UndoCue: position %d out of range for %s (count %d)',
      [targetIndex, operation.componentName, section.ReportComponents.Count]);
  section.ReportComponents.Items[currentIndex].Index := targetIndex;
end;

procedure TUndoCue.ApplyOperation(operation: TChangeObjectOperation; isUndo: Boolean);
var
  target: TObject;
begin
  case operation.operation of
    otSwapDown, otSwapUp:
      begin
        ApplySwap(operation, isUndo);
        Exit;
      end;

    otRename:
      begin
        if isUndo then
          target := GetComponentByName(operation.componentName)
        else
          target := GetComponentByName(operation.oldParentName);
        if not (target is TComponent) then
          raise Exception.Create('UndoCue: rename not supported for ' + target.ClassName);
        if isUndo then
          TComponent(target).Name := operation.oldParentName
        else
          TComponent(target).Name := operation.componentName;
        Exit;
      end;

    otRemove:
      begin
        if isUndo then
          // Undo remove = re-create the element
          RecreateItem(operation, True)
        else
          // Redo remove = delete again
          DeleteRemovedItem(operation);
        Exit;
      end;

    otAdd:
      begin
        if isUndo then
          // Undo add = remove the element
          DeleteAddedItem(operation)
        else
          // Redo add = re-create the element
          RecreateItem(operation, False);
        Exit;
      end;
  end;

  target := GetComponentByName(operation.componentName);
  ApplyParentChange(operation, target, isUndo);
  ApplyPropertiesToObject(operation, target, isUndo);
end;

procedure TUndoCue.RecreateItem(operation: TChangeObjectOperation; isUndo: Boolean);
var
  target, parentItem: TObject;
  itemIndex: Integer;
  parentSection: TRpSection;
  parentSubreport: TRpSubReport;
  compItem: TRpCommonListItem;
  secItem: TRpSectionListItem;
  subrepItem: TRpSubReportListItem;
  dinfo: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
  param: TRpParam;
begin
  target := nil;
  itemIndex := operation.oldItemIndex;
  try
    if operation.parentName <> '' then
    begin
      parentItem := GetComponentByName(operation.parentName);
      if parentItem is TRpSection then
      begin
        parentSection := TRpSection(parentItem);
        // Components of an external section are owned by the section, as
        // when the designer creates them (TRpSectionInterface.CreateNewComponent)
        if parentSection.IsExternal then
          target := NewComponentByClassName(operation.componentClass, parentSection)
        else
          target := NewComponentByClassName(operation.componentClass, FReport);
        if not (target is TRpCommonPosComponent) then
          raise Exception.Create('UndoCue: ' + operation.componentClass +
            ' can not be placed in section ' + operation.parentName);
        TComponent(target).Name := operation.componentName;
        if (itemIndex >= 0) and (itemIndex <= parentSection.ReportComponents.Count) then
          compItem := parentSection.ReportComponents.Insert(itemIndex)
        else
          compItem := parentSection.ReportComponents.Add;
        compItem.Component := TRpCommonPosComponent(target);
      end
      else if parentItem is TRpSubReport then
      begin
        parentSubreport := TRpSubReport(parentItem);
        target := NewComponentByClassName(operation.componentClass, FReport);
        if not (target is TRpSection) then
          raise Exception.Create('UndoCue: ' + operation.componentClass +
            ' can not be placed in subreport ' + operation.parentName);
        TComponent(target).Name := operation.componentName;
        if (itemIndex >= 0) and (itemIndex <= parentSubreport.Sections.Count) then
          secItem := TRpSectionListItem(parentSubreport.Sections.Insert(itemIndex))
        else
          secItem := TRpSectionListItem(parentSubreport.Sections.Add);
        secItem.Section := TRpSection(target);
        TRpSection(target).SubReport := parentSubreport;
      end
      else
        raise Exception.Create('UndoCue: parent ' + operation.parentName +
          ' is not a section or a subreport');
    end
    else if operation.componentClass = 'TRPSUBREPORT' then
    begin
      if isUndo then
      begin
        // Undo of a remove: its sections come back through their own
        // operations of the same group
        target := TRpSubReport.Create(FReport);
        TRpSubReport(target).Name := operation.componentName;
        subrepItem := FReport.SubReports.Add;
        subrepItem.SubReport := TRpSubReport(target);
      end
      else
      begin
        // Redo of an add: recreate it as the designer does, AddSubReport
        // also creates its detail section
        target := FReport.AddSubReport;
        TRpSubReport(target).Name := operation.componentName;
        subrepItem := FReport.SubReports.Items[FReport.SubReports.Count - 1];
      end;
      if (itemIndex >= 0) and (itemIndex < FReport.SubReports.Count) then
        subrepItem.Index := itemIndex;
    end
    else if operation.componentClass = 'TRPDATAINFOITEM' then
    begin
      dinfo := FReport.DataInfo.Add('');
      target := dinfo;
      dinfo.Name := operation.componentName;
      if (itemIndex >= 0) and (itemIndex < FReport.DataInfo.Count) then
        dinfo.Index := itemIndex;
    end
    else if operation.componentClass = 'TRPDATABASEINFOITEM' then
    begin
      dbinfo := FReport.DatabaseInfo.Add('');
      target := dbinfo;
      dbinfo.Name := operation.componentName;
      if (itemIndex >= 0) and (itemIndex < FReport.DatabaseInfo.Count) then
        dbinfo.Index := itemIndex;
    end
    else if operation.componentClass = 'TRPPARAM' then
    begin
      param := FReport.Params.Add('');
      target := param;
      param.IntName := operation.componentName;
      if (itemIndex >= 0) and (itemIndex < FReport.Params.Count) then
        param.Index := itemIndex;
    end
    else
      raise Exception.Create('Class not found: ' + operation.componentClass);

    ApplyPropertiesToObject(operation, target, isUndo);
  except
    // Leave the report as it was before this operation
    if Assigned(target) then
      DiscardItem(target);
    raise;
  end;
end;

procedure TUndoCue.DeleteRemovedItem(operation: TChangeObjectOperation);
var
  target: TObject;
begin
  target := GetComponentByName(operation.componentName);
  if not ((target is TRpCommonPosComponent) or (target is TRpSection) or
     (target is TRpSubReport) or (target is TRpDataInfoItem) or
     (target is TRpDatabaseInfoItem) or (target is TRpParam)) then
    raise Exception.Create('UndoCue: can not delete ' + operation.componentName +
      ' (' + target.ClassName + ')');
  DiscardItem(target);
end;

procedure TUndoCue.DeleteAddedItem(operation: TChangeObjectOperation);
var
  parentItem: TObject;
  parentSection: TRpSection;
  parentSubreport: TRpSubReport;
  comp: TRpCommonComponent;
  sec: TRpSection;
  i: Integer;
begin
  parentSection := nil;
  parentSubreport := nil;
  if operation.parentName <> '' then
  begin
    parentItem := GetComponentByName(operation.parentName);
    if parentItem is TRpSection then
      parentSection := TRpSection(parentItem)
    else if parentItem is TRpSubReport then
      parentSubreport := TRpSubReport(parentItem);
  end;

  // The item is searched by name in its parent: it may have been removed by
  // a previous operation of the same group, then there is nothing to do
  if parentSection <> nil then
  begin
    for i := 0 to parentSection.Components.Count - 1 do
    begin
      comp := parentSection.Components.Items[i].Component;
      if Assigned(comp) and SameText(comp.Name, operation.componentName) then
      begin
        operation.oldItemIndex := i;
        parentSection.Components.Items[i].Component := nil;
        parentSection.Components.Delete(i);
        comp.Free;
        Exit;
      end;
    end;
  end
  else if parentSubreport <> nil then
  begin
    for i := 0 to parentSubreport.Sections.Count - 1 do
    begin
      sec := TRpSection(parentSubreport.Sections.Items[i].Section);
      if Assigned(sec) and SameText(sec.Name, operation.componentName) then
      begin
        operation.oldItemIndex := i;
        parentSubreport.Sections.Items[i].Section := nil;
        parentSubreport.Sections.Delete(i);
        sec.FreeComponents;
        sec.Free;
        Exit;
      end;
    end;
  end
  else if operation.componentClass = 'TRPSUBREPORT' then
  begin
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      if SameText(FReport.SubReports.Items[i].SubReport.Name, operation.componentName) then
      begin
        operation.oldItemIndex := i;
        FReport.DeleteSubReport(FReport.SubReports.Items[i].SubReport);
        Exit;
      end;
    end;
  end
  else if operation.componentClass = 'TRPDATAINFOITEM' then
  begin
    for i := 0 to FReport.DataInfo.Count - 1 do
    begin
      if SameText(FReport.DataInfo.Items[i].Name, operation.componentName) then
      begin
        operation.oldItemIndex := i;
        FReport.DataInfo.Delete(i);
        Exit;
      end;
    end;
  end
  else if operation.componentClass = 'TRPDATABASEINFOITEM' then
  begin
    for i := 0 to FReport.DatabaseInfo.Count - 1 do
    begin
      if SameText(FReport.DatabaseInfo.Items[i].Name, operation.componentName) then
      begin
        operation.oldItemIndex := i;
        FReport.DatabaseInfo.Delete(i);
        Exit;
      end;
    end;
  end
  else if operation.componentClass = 'TRPPARAM' then
  begin
    for i := 0 to FReport.Params.Count - 1 do
    begin
      if SameText(FReport.Params.Items[i].IntName, operation.componentName) then
      begin
        operation.oldItemIndex := i;
        FReport.Params.Delete(i);
        Exit;
      end;
    end;
  end;
end;

procedure TUndoCue.DiscardItem(target: TObject);
var
  i, j, index: Integer;
  subrep: TRpSubReport;
  sec: TRpSection;
begin
  if target is TRpCommonPosComponent then
  begin
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      subrep := FReport.SubReports.Items[i].SubReport;
      for j := 0 to subrep.Sections.Count - 1 do
      begin
        sec := subrep.Sections.Items[j].Section;
        if not Assigned(sec) then
          Continue;
        index := sec.ReportComponents.IndexOf(TRpCommonPosComponent(target));
        if index >= 0 then
        begin
          sec.ReportComponents.Items[index].Component := nil;
          sec.ReportComponents.Delete(index);
        end;
      end;
    end;
    target.Free;
  end
  else if target is TRpSection then
  begin
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      subrep := FReport.SubReports.Items[i].SubReport;
      for j := subrep.Sections.Count - 1 downto 0 do
      begin
        if subrep.Sections.Items[j].Section = target then
        begin
          // Nil the slot first: FreeSection would also free the group pair
          subrep.Sections.Items[j].Section := nil;
          subrep.Sections.Delete(j);
        end;
      end;
    end;
    TRpSection(target).FreeComponents;
    target.Free;
  end
  else if target is TRpSubReport then
  begin
    if FReport.SubReports.IndexOf(TRpSubReport(target)) >= 0 then
      FReport.DeleteSubReport(TRpSubReport(target))
    else
      target.Free;
  end
  else
    // Data info, database info and parameters are collection items: freeing
    // them removes them from their collection
    target.Free;
end;

procedure TUndoCue.ApplyParentChange(operation: TChangeObjectOperation;
  target: TObject; isUndo: Boolean);
var
  fromName, toName: string;
  fromItem, toItem: TObject;
  fromSection, toSection: TRpSection;
  indexOld: Integer;
  compItem: TRpCommonListItem;
begin
  // A component moved from section oldParentName to section parentName
  if (operation.parentName = '') or (operation.oldParentName = '') or
     SameText(operation.parentName, operation.oldParentName) then
    Exit;
  if isUndo then
  begin
    fromName := operation.parentName;
    toName := operation.oldParentName;
  end
  else
  begin
    fromName := operation.oldParentName;
    toName := operation.parentName;
  end;
  fromItem := GetComponentByName(fromName);
  toItem := GetComponentByName(toName);
  if not (fromItem is TRpSection) or not (toItem is TRpSection) then
    raise Exception.Create('UndoCue: parent change of ' + operation.componentName +
      ' requires two sections: ' + fromName + ', ' + toName);
  if not (target is TRpCommonPosComponent) then
    raise Exception.Create('UndoCue: parent change not supported for ' + operation.componentName);
  fromSection := TRpSection(fromItem);
  toSection := TRpSection(toItem);
  indexOld := fromSection.ReportComponents.IndexOf(TRpCommonPosComponent(target));
  if indexOld < 0 then
    raise Exception.Create('UndoCue: component ' + operation.componentName +
      ' not found in section ' + fromName + ' for parent change');
  fromSection.ReportComponents.Items[indexOld].Component := nil;
  fromSection.ReportComponents.Delete(indexOld);
  // Undo returns it to its recorded position in the old section
  if isUndo and (operation.oldItemIndex >= 0) and
     (operation.oldItemIndex <= toSection.ReportComponents.Count) then
    compItem := toSection.ReportComponents.Insert(operation.oldItemIndex)
  else
    compItem := toSection.ReportComponents.Add;
  compItem.Component := TRpCommonPosComponent(target);
end;

procedure TUndoCue.ApplyPropertiesToObject(operation: TChangeObjectOperation;
  target: TObject; isUndo: Boolean);
var
  prop: TChangeOperationItem;
  nvalue: Variant;
  propsItem: IPropertiesItem;
  mappedPropName: string;
  i: Integer;
begin
  if operation.properties.Count = 0 then
    Exit;
  propsItem := GetUndoPropertiesItem(target);

  for i := 0 to operation.properties.Count - 1 do
  begin
    prop := operation.properties[i];
    if (isUndo) and (operation.operation <> otRemove) then
      nvalue := prop.oldValue
    else
      nvalue := prop.newValue;
    // Removals recorded before the params/data dialogs stored their values in
    // newValue (e.g. histories saved in reports) only carry oldValue
    if (operation.operation = otRemove) and (VarIsEmpty(nvalue) or VarIsNull(nvalue)) then
      nvalue := prop.oldValue;
    nvalue := NormalizeUndoPropertyValue(prop.propertyType, nvalue);
    mappedPropName := MapUndoPropertyName(target, prop.propertyName);
    if (prop.propertyType = ptStringArray) and ApplyStringArrayProperty(target, mappedPropName, nvalue) then
      Continue;
    propsItem.SetItemProperty(mappedPropName, nvalue);
  end;
end;

function NewComponentByClassName(const className: string; AOwner: TComponent): TComponent;
begin
  if className = 'TRPLABEL' then
    Result := TRpLabel.Create(AOwner)
  else if className = 'TRPEXPRESSION' then
    Result := TRpExpression.Create(AOwner)
  else if className = 'TRPSHAPE' then
    Result := TRpShape.Create(AOwner)
  else if className = 'TRPIMAGE' then
    Result := TRpImage.Create(AOwner)
  else if className = 'TRPBARCODE' then
    Result := TRpBarcode.Create(AOwner)
  else if className = 'TRPCHART' then
    Result := TRpChart.Create(AOwner)
  else if className = 'TRPSECTION' then
    Result := TRpSection.Create(AOwner)
  else if className = 'TRPSUBREPORT' then
    Result := TRpSubReport.Create(AOwner)
  else
    raise Exception.Create('Unknown component class: ' + className);
end;

{ TUndoCue JSON serialization }

function TUndoCue.ToJSON: string;
var
  root: TJSONObject;
  undoArr, redoArr: TJSONArray;
  i: Integer;
begin
  root := TJSONObject.Create;
  try
    root.Add('groupId', FGroupId);
    undoArr := TJSONArray.Create;
    for i := 0 to UndoOperations.Count - 1 do
      undoArr.Add(UndoOperations[i].ToJSON);
    root.Add('undoOperations', undoArr);

    redoArr := TJSONArray.Create;
    for i := 0 to RedoOperations.Count - 1 do
      redoArr.Add(RedoOperations[i].ToJSON);
    root.Add('redoOperations', redoArr);

    Result := root.AsJSON;
  finally
    root.Free;
  end;
end;

procedure TUndoCue.AddAllComponentProperties(pitem: TRpCommonPosComponent; op: TChangeObjectOperation);
begin
  // Common positional properties
  op.AddProperty('posX', ptInteger, Null, pitem.GetItemProperty('PosX'));
  op.AddProperty('posY', ptInteger, Null, pitem.GetItemProperty('PosY'));
  op.AddProperty('width', ptInteger, Null, pitem.GetItemProperty('Width'));
  op.AddProperty('height', ptInteger, Null, pitem.GetItemProperty('Height'));
  op.AddProperty('align', ptInteger, Null, pitem.GetItemProperty('Align'));
  op.AddProperty('annotationExpression', ptString, Null, pitem.GetItemProperty('AnnotationExpression'));
  op.AddProperty('printCondition', ptString, Null, pitem.GetItemProperty('PrintCondition'));
  op.AddProperty('doBeforePrint', ptString, Null, pitem.GetItemProperty('DoBeforePrint'));
  op.AddProperty('doAfterPrint', ptString, Null, pitem.GetItemProperty('DoAfterPrint'));
  op.AddProperty('visible', ptBoolean, Null, pitem.GetItemProperty('Visible'));

  // Text component properties (TRpLabel, TRpExpression, TRpChart)
  if pitem is TRpGenTextComponent then
  begin
    op.AddProperty('wFontName', ptString, Null, pitem.GetItemProperty('WFontName'));
    op.AddProperty('lFontName', ptString, Null, pitem.GetItemProperty('LFontName'));
    op.AddProperty('fontSize', ptInteger, Null, pitem.GetItemProperty('FontSize'));
    op.AddProperty('fontColor', ptInteger, Null, pitem.GetItemProperty('FontColor'));
    op.AddProperty('fontStyle', ptInteger, Null, pitem.GetItemProperty('FontStyle'));
    op.AddProperty('backColor', ptInteger, Null, pitem.GetItemProperty('BackColor'));
    op.AddProperty('transparent', ptBoolean, Null, pitem.GetItemProperty('Transparent'));
    op.AddProperty('cutText', ptBoolean, Null, pitem.GetItemProperty('CutText'));
    op.AddProperty('wordWrap', ptBoolean, Null, pitem.GetItemProperty('WordWrap'));
    op.AddProperty('wordBreak', ptBoolean, Null, pitem.GetItemProperty('WordBreak'));
    op.AddProperty('singleLine', ptBoolean, Null, pitem.GetItemProperty('SingleLine'));
    op.AddProperty('alignment', ptInteger, Null, pitem.GetItemProperty('Alignment'));
    op.AddProperty('vAlignment', ptInteger, Null, pitem.GetItemProperty('VAlignment'));
    op.AddProperty('fontRotation', ptInteger, Null, pitem.GetItemProperty('FontRotation'));
    op.AddProperty('type1Font', ptInteger, Null, pitem.GetItemProperty('Type1Font'));
    op.AddProperty('printStep', ptInteger, Null, pitem.GetItemProperty('PrintStep'));
    op.AddProperty('interLine', ptInteger, Null, pitem.GetItemProperty('InterLine'));
    op.AddProperty('multiPage', ptBoolean, Null, pitem.GetItemProperty('MultiPage'));
    op.AddProperty('rightToLeft', ptBoolean, Null, pitem.GetItemProperty('RightToLeft'));
    // After rightToLeft: restores every language (and BidiFull), which
    // rightToLeft alone cannot express
    op.AddProperty('bidiModes', ptString, Null, pitem.GetItemProperty('BidiModes'));
    op.AddProperty('isHtml', ptBoolean, Null, pitem.GetItemProperty('IsHtml'));
    if pitem is TRpLabel then
    begin
      op.AddProperty('allStrings', ptString, Null, pitem.GetItemProperty('Text'));
    end
    else if pitem is TRpExpression then
    begin
      op.AddProperty('expression', ptString, Null, pitem.GetItemProperty('Expression'));
      op.AddProperty('displayFormat', ptString, Null, pitem.GetItemProperty('DisplayFormat'));
      op.AddProperty('dataType', ptInteger, Null, pitem.GetItemProperty('DataType'));
      op.AddProperty('identifier', ptString, Null, pitem.GetItemProperty('Identifier'));
      op.AddProperty('aggregate', ptInteger, Null, pitem.GetItemProperty('Aggregate'));
      op.AddProperty('groupName', ptString, Null, pitem.GetItemProperty('GroupName'));
      op.AddProperty('agType', ptInteger, Null, pitem.GetItemProperty('AgType'));
      op.AddProperty('agIniValue', ptString, Null, pitem.GetItemProperty('AgIniValue'));
      op.AddProperty('autoExpand', ptBoolean, Null, pitem.GetItemProperty('AutoExpand'));
      op.AddProperty('autoContract', ptBoolean, Null, pitem.GetItemProperty('AutoContract'));
      op.AddProperty('printOnlyOne', ptBoolean, Null, pitem.GetItemProperty('PrintOnlyOne'));
      op.AddProperty('printNulls', ptBoolean, Null, pitem.GetItemProperty('PrintNulls'));
      op.AddProperty('exportDisplayFormat', ptString, Null, pitem.GetItemProperty('ExportDisplayFormat'));
      op.AddProperty('exportExpression', ptString, Null, pitem.GetItemProperty('ExportExpression'));
      op.AddProperty('exportLine', ptInteger, Null, pitem.GetItemProperty('ExportLine'));
      op.AddProperty('exportPosition', ptInteger, Null, pitem.GetItemProperty('ExportPosition'));
      op.AddProperty('exportSize', ptInteger, Null, pitem.GetItemProperty('ExportSize'));
      op.AddProperty('exportDoNewLine', ptBoolean, Null, pitem.GetItemProperty('ExportDoNewLine'));
    end
    else if pitem is TRpChart then
    begin
      op.AddProperty('chartStyle', ptInteger, Null, pitem.GetItemProperty('ChartType'));
      op.AddProperty('identifier', ptString, Null, pitem.GetItemProperty('Identifier'));
      op.AddProperty('changeSerieBool', ptBoolean, Null, pitem.GetItemProperty('ChangeSerieBool'));
      op.AddProperty('clearExpressionBool', ptBoolean, Null, pitem.GetItemProperty('ClearExpressionBool'));
      op.AddProperty('driver', ptInteger, Null, pitem.GetItemProperty('Driver'));
      op.AddProperty('view3d', ptBoolean, Null, pitem.GetItemProperty('View3d'));
      op.AddProperty('view3dWalls', ptBoolean, Null, pitem.GetItemProperty('View3dWalls'));
      op.AddProperty('perspective', ptNumber, Null, pitem.GetItemProperty('Perspective'));
      op.AddProperty('elevation', ptNumber, Null, pitem.GetItemProperty('Elevation'));
      op.AddProperty('rotation', ptInteger, Null, pitem.GetItemProperty('Rotation'));
      op.AddProperty('zoom', ptInteger, Null, pitem.GetItemProperty('Zoom'));
      op.AddProperty('horzOffset', ptNumber, Null, pitem.GetItemProperty('HorzOffset'));
      op.AddProperty('vertOffset', ptNumber, Null, pitem.GetItemProperty('VertOffset'));
      op.AddProperty('tilt', ptNumber, Null, pitem.GetItemProperty('Tilt'));
      op.AddProperty('orthogonal', ptBoolean, Null, pitem.GetItemProperty('Orthogonal'));
      op.AddProperty('multiBar', ptInteger, Null, pitem.GetItemProperty('MultiBar'));
      op.AddProperty('resolution', ptInteger, Null, pitem.GetItemProperty('Resolution'));
      op.AddProperty('showLegend', ptBoolean, Null, pitem.GetItemProperty('ShowLegend'));
      op.AddProperty('showHint', ptBoolean, Null, pitem.GetItemProperty('ShowHint'));
      op.AddProperty('markStyle', ptInteger, Null, pitem.GetItemProperty('MarkStyle'));
      op.AddProperty('horzFontSize', ptInteger, Null, pitem.GetItemProperty('HorzFontSize'));
      op.AddProperty('vertFontSize', ptInteger, Null, pitem.GetItemProperty('VertFontSize'));
      op.AddProperty('horzFontRotation', ptInteger, Null, pitem.GetItemProperty('HorzFontRotation'));
      op.AddProperty('vertFontRotation', ptInteger, Null, pitem.GetItemProperty('VertFontRotation'));
      op.AddProperty('getValueCondition', ptString, Null, pitem.GetItemProperty('GetValueCondition'));
      op.AddProperty('valueExpression', ptString, Null, pitem.GetItemProperty('ValueExpression'));
      op.AddProperty('valueXExpression', ptString, Null, pitem.GetItemProperty('ValueXExpression'));
      op.AddProperty('changeSerieExpression', ptString, Null, pitem.GetItemProperty('ChangeSerieExpression'));
      op.AddProperty('captionExpression', ptString, Null, pitem.GetItemProperty('CaptionExpression'));
      op.AddProperty('serieCaption', ptString, Null, pitem.GetItemProperty('SerieCaption'));
      op.AddProperty('clearExpression', ptString, Null, pitem.GetItemProperty('ClearExpression'));
      op.AddProperty('colorExpression', ptString, Null, pitem.GetItemProperty('ColorExpression'));
      op.AddProperty('serieColorExpression', ptString, Null, pitem.GetItemProperty('SerieColorExpression'));
      op.AddProperty('seriesColors', ptString, Null, pitem.GetItemProperty('SeriesColors'));
    end;
  end
  else if pitem is TRpShape then
  begin
    op.AddProperty('brushStyle', ptInteger, Null, pitem.GetItemProperty('BrushStyle'));
    op.AddProperty('brushColor', ptInteger, Null, pitem.GetItemProperty('BrushColor'));
    op.AddProperty('penStyle', ptInteger, Null, pitem.GetItemProperty('PenStyle'));
    op.AddProperty('penColor', ptInteger, Null, pitem.GetItemProperty('PenColor'));
    op.AddProperty('shape', ptInteger, Null, pitem.GetItemProperty('Shape'));
    op.AddProperty('penWidth', ptInteger, Null, pitem.GetItemProperty('PenWidth'));
  end
  else if pitem is TRpImage then
  begin
    op.AddProperty('expression', ptString, Null, pitem.GetItemProperty('Expression'));
    op.AddProperty('rotation', ptInteger, Null, pitem.GetItemProperty('Rotation'));
    op.AddProperty('drawStyle', ptInteger, Null, pitem.GetItemProperty('DrawStyle'));
    op.AddProperty('dpiRes', ptInteger, Null, pitem.GetItemProperty('dpires'));
    op.AddProperty('copyMode', ptInteger, Null, pitem.GetItemProperty('CopyMode'));
    op.AddProperty('sharedImage', ptInteger, Null, pitem.GetItemProperty('sharedImage'));
    op.AddProperty('streamBase64', ptString, Null, pitem.GetItemProperty('streamBase64'));
  end
  else if pitem is TRpBarcode then
  begin
    op.AddProperty('expression', ptString, Null, pitem.GetItemProperty('Expression'));
    op.AddProperty('modul', ptInteger, Null, pitem.GetItemProperty('Modul'));
    op.AddProperty('ratio', ptNumber, Null, pitem.GetItemProperty('Ratio'));
    op.AddProperty('barType', ptInteger, Null, pitem.GetItemProperty('Typ'));
    op.AddProperty('checksum', ptBoolean, Null, pitem.GetItemProperty('Checksum'));
    op.AddProperty('displayFormat', ptString, Null, pitem.GetItemProperty('DisplayFormat'));
    op.AddProperty('rotation', ptInteger, Null, pitem.GetItemProperty('Rotation'));
    op.AddProperty('bColor', ptInteger, Null, pitem.GetItemProperty('BColor'));
    op.AddProperty('backColor', ptInteger, Null, pitem.GetItemProperty('BackColor'));
    op.AddProperty('transparent', ptBoolean, Null, pitem.GetItemProperty('Transparent'));
    op.AddProperty('numColumns', ptInteger, Null, pitem.GetItemProperty('NumColumns'));
    op.AddProperty('numRows', ptInteger, Null, pitem.GetItemProperty('NumRows'));
    op.AddProperty('eccLevel', ptInteger, Null, pitem.GetItemProperty('ECCLevel'));
    op.AddProperty('truncated', ptBoolean, Null, pitem.GetItemProperty('Truncated'));
  end;
end;

procedure TUndoCue.AddSectionProperties(sec: TRpSection;
  op: TChangeObjectOperation);
begin
  op.AddProperty('printCondition', ptString, Null, sec.GetItemProperty('PrintCondition'));
  op.AddProperty('alignBottom', ptBoolean, Null, sec.GetItemProperty('AlignBottom'));
  op.AddProperty('autoContract', ptBoolean, Null, sec.GetItemProperty('AutoContract'));
  op.AddProperty('autoExpand', ptBoolean, Null, sec.GetItemProperty('AutoExpand'));
  op.AddProperty('backExpression', ptString, Null, sec.GetItemProperty('BackExpression'));
  op.AddProperty('backStyle', ptInteger, Null, sec.GetItemProperty('BackStyle'));
  op.AddProperty('beginPageExpression', ptString, Null, sec.GetItemProperty('BeginPageExpression'));
  op.AddProperty('childSubreportName', ptString, Null, sec.GetItemProperty('ChildSubReportName'));
  op.AddProperty('doAfterPrint', ptString, Null, sec.GetItemProperty('DoAfterPrint'));
  op.AddProperty('doBeforePrint', ptString, Null, sec.GetItemProperty('DoBeforePrint'));
  op.AddProperty('dpiRes', ptInteger, Null, sec.GetItemProperty('dpires'));
  op.AddProperty('drawStyle', ptInteger, Null, sec.GetItemProperty('DrawStyle'));
  op.AddProperty('forcePrint', ptBoolean, Null, sec.GetItemProperty('ForcePrint'));
  op.AddProperty('global', ptBoolean, Null, sec.GetItemProperty('Global'));
  op.AddProperty('height', ptInteger, Null, sec.GetItemProperty('Height'));
  op.AddProperty('width', ptInteger, Null, sec.GetItemProperty('Width'));
  op.AddProperty('horzDesp', ptBoolean, Null, sec.GetItemProperty('HorzDesp'));
  op.AddProperty('iniNumPage', ptBoolean, Null, sec.GetItemProperty('IniNumPage'));
  op.AddProperty('pageRepeat', ptBoolean, Null, sec.GetItemProperty('PageRepeat'));
  op.AddProperty('sectionType', ptInteger, Null, sec.GetItemProperty('SectionType'));
  op.AddProperty('sharedImage', ptInteger, Null, sec.GetItemProperty('sharedImage'));
  op.AddProperty('skipExpreH', ptString, Null, sec.GetItemProperty('SkipExpreH'));
  op.AddProperty('skipExpreV', ptString, Null, sec.GetItemProperty('SkipExpreV'));
  op.AddProperty('skipPage', ptBoolean, Null, sec.GetItemProperty('SkipPage'));
  op.AddProperty('skipRelativeH', ptBoolean, Null, sec.GetItemProperty('SkipRelativeH'));
  op.AddProperty('skipRelativeV', ptBoolean, Null, sec.GetItemProperty('SkipRelativeV'));
  op.AddProperty('skipToPageExpre', ptString, Null, sec.GetItemProperty('SkipToPageExpre'));
  op.AddProperty('skipType', ptInteger, Null, sec.GetItemProperty('SkipType'));
  op.AddProperty('streamBase64', ptString, Null, sec.GetItemProperty('streamBase64'));
  op.AddProperty('subReportName', ptString, Null, sec.GetItemProperty('SubReportName'));
  op.AddProperty('streamFormat', ptInteger, Null, sec.GetItemProperty('StreamFormat'));
  op.AddProperty('vertDesp', ptBoolean, Null, sec.GetItemProperty('VertDesp'));
  op.AddProperty('groupName', ptString, Null, sec.GetItemProperty('GroupName'));
  op.AddProperty('changeExpression', ptString, Null, sec.GetItemProperty('ChangeExpression'));
  op.AddProperty('changeBool', ptBoolean, Null, sec.GetItemProperty('ChangeBool'));
  op.AddProperty('beginPage', ptBoolean, Null, sec.GetItemProperty('BeginPage'));
  op.AddProperty('externalFilename', ptString, Null, sec.GetItemProperty('ExternalFilename'));
  op.AddProperty('externalConnection', ptString, Null, sec.GetItemProperty('ExternalConnection'));
  op.AddProperty('externalTable', ptString, Null, sec.GetItemProperty('ExternalTable'));
  op.AddProperty('externalField', ptString, Null, sec.GetItemProperty('ExternalField'));
  op.AddProperty('externalSearchField', ptString, Null, sec.GetItemProperty('ExternalSearchField'));
  op.AddProperty('externalSearchValue', ptString, Null, sec.GetItemProperty('ExternalSearchValue'));
end;

procedure TUndoCue.AddSubreportProperties(subrep: TRpSubReport;
  op: TChangeObjectOperation);
begin
  op.AddProperty('alias', ptString, Null, subrep.GetItemProperty('Alias'));
  op.AddProperty('printOnlyIfDataAvailable', ptBoolean, Null, subrep.GetItemProperty('PrintOnlyIfDataAvailable'));
  op.AddProperty('reOpenOnPrint', ptBoolean, Null, subrep.GetItemProperty('ReOpenOnPrint'));
end;

procedure TUndoCue.FromJSON(const jsonStr: string);
var
  jData: TJSONData;
  root: TJSONObject;
  undoArr, redoArr: TJSONArray;
  i: Integer;
  opObj: TJSONObject;
begin
  UndoOperations.Clear;
  RedoOperations.Clear;
  try
    if Trim(jsonStr) = '' then Exit;

    try
      jData := GetJSON(jsonStr);
    except
      jData := nil;
    end;

    if (jData = nil) or not (jData is TJSONObject) then
    begin
      jData.Free;
      Exit;
    end;

    root := TJSONObject(jData);
    try
      FGroupId := JSONGetInt(root, 'groupId', 'GroupId', 0);
      undoArr := JSONGetArray(root, 'undoOperations', 'UndoOperations');
      if Assigned(undoArr) then
      begin
        for i := 0 to undoArr.Count - 1 do
        begin
          if undoArr.Items[i] is TJSONObject then
          begin
            opObj := TJSONObject(undoArr.Items[i]);
            UndoOperations.Add(TChangeObjectOperation.FromJSON(opObj));
          end;
        end;
      end;

      redoArr := JSONGetArray(root, 'redoOperations', 'RedoOperations');
      if Assigned(redoArr) then
      begin
        for i := 0 to redoArr.Count - 1 do
        begin
          if redoArr.Items[i] is TJSONObject then
          begin
            opObj := TJSONObject(redoArr.Items[i]);
            RedoOperations.Add(TChangeObjectOperation.FromJSON(opObj));
          end;
        end;
      end;
    finally
      root.Free;
    end;
  finally
    // The history was replaced: refresh listeners (history panel, status)
    DoChange;
  end;
end;

end.

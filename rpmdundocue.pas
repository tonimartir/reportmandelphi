unit rpmdundocue;

{$I rpconf.inc}

interface

uses
  System.SysUtils, System.Generics.Collections, System.DateUtils,
  System.Classes, System.JSON, System.Variants,rpprintitem,
  rpreport, rpbasereport, rpsubreport, rpsection, rpsecutil,rptypes;

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

type
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

  TUndoCue = class
  private
    FGroupId: Integer;
    FReport: TRpReport;
    procedure ApplySwapOperation(const className: string; down: Boolean;
      aOldIndex: Integer; const aParentName: string);
    procedure ApplyOperation(operation: TChangeObjectOperation; isUndo: Boolean);
    procedure ApplyPropertiesToObject(operation: TChangeObjectOperation;
      target: TObject; isUndo: Boolean);
    function GetComponentByName(const name: string): TObject;
  public
    UndoOperations: TObjectList<TChangeObjectOperation>;
    RedoOperations: TObjectList<TChangeObjectOperation>;
    constructor Create(AReport: TRpReport);
    destructor Destroy; override;
    function GetGroupId: Integer;
    procedure AddOperation(op: TChangeObjectOperation);
    procedure AddAllComponentProperties(pitem: TRpCommonPosComponent; op: TChangeObjectOperation);
    procedure AddSectionProperties(sec: TRpSection; op: TChangeObjectOperation);
    procedure AddSubreportProperties(subrep: TRpSubReport; op: TChangeObjectOperation);
    function Undo: TObjectList<TChangeObjectOperation>;
    function Redo: TObjectList<TChangeObjectOperation>;
    procedure Clear;
    function ToJSON: string;
    procedure FromJSON(const jsonStr: string);

    property GroupId: Integer read FGroupId;
    property Report: TRpReport read FReport write FReport;
  end;

implementation

uses rplabelitem, rpdrawitem, rpmdbarcode, rpmdchart, rpdatainfo, rpparams;

function NewComponentByClassName(const className: string; AOwner: TComponent): TComponent; forward;

function GetJSONValueCaseInsensitive(jObj: TJSONObject; const camelName,
  pascalName: string): TJSONValue;
begin
  Result := jObj.Values[camelName];
  if (Result = nil) and (pascalName <> '') then
    Result := jObj.Values[pascalName];
end;

function VariantIsStringArray(const value: Variant): Boolean;
begin
  Result := VarIsArray(value) and ((VarType(value) and varTypeMask) = varVariant);
end;

function VariantArrayToJSONValue(const value: Variant): TJSONValue;
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

function JSONStringArrayToVariant(jValue: TJSONValue): Variant;
var
  jsonArray: TJSONArray;
  index: Integer;
begin
  if not (jValue is TJSONArray) then
    Exit(Unassigned);

  jsonArray := TJSONArray(jValue);
  if jsonArray.Count = 0 then
  begin
    Result := VarArrayCreate([0, -1], varVariant);
    Exit;
  end;
  Result := VarArrayCreate([0, jsonArray.Count - 1], varVariant);
  for index := 0 to jsonArray.Count - 1 do
    Result[index] := jsonArray.Items[index].Value;
end;

function DateTimeToJavaScriptJSON(const value: TDateTime): string;
var
  utcValue: TDateTime;
  formatSettings: TFormatSettings;
begin
  utcValue := TTimeZone.Local.ToUniversalTime(value);
  formatSettings := TFormatSettings.Create;
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz"Z"',
    utcValue, formatSettings);
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

function VariantToTypedJSONValue(const value: Variant): TJSONValue;
var
  jsonObject: TJSONObject;
  typeName: string;
begin
  jsonObject := TJSONObject.Create;
  typeName := VariantTypeToJSONName(value);
  jsonObject.AddPair('type', typeName);
  if typeName = 'Null' then
    jsonObject.AddPair('value', TJSONNull.Create)
  else if typeName = 'Boolean' then
    jsonObject.AddPair('value', TJSONBool.Create(Boolean(value)))
  else if (typeName = 'Integer') or (typeName = 'Byte') then
    jsonObject.AddPair('value', TJSONNumber.Create(Integer(value)))
  else if typeName = 'Long' then
    jsonObject.AddPair('value', TJSONNumber.Create(Int64(value)))
  else if typeName = 'Decimal' then
    jsonObject.AddPair('value', TJSONNumber.Create(Double(VarAsType(value, varDouble))))
  else if typeName = 'Double' then
    jsonObject.AddPair('value', TJSONNumber.Create(Double(VarAsType(value, varDouble))))
  else if typeName = 'DateTime' then
    jsonObject.AddPair('value', TJSONString.Create(DateTimeToJavaScriptJSON(VarToDateTime(value))))
  else
    jsonObject.AddPair('value', TJSONString.Create(VarToStr(value)));
  Result := jsonObject;
end;

function JSONTypedValueToVariant(jValue: TJSONValue): Variant;
var
  jsonObject: TJSONObject;
  typeValue, valueNode: TJSONValue;
  typeName, valueText: string;
begin
  if jValue = nil then
    Exit(Unassigned);
  if jValue is TJSONNull then
    Exit(Null);

  if not (jValue is TJSONObject) then
    Exit(Unassigned);

  jsonObject := TJSONObject(jValue);
  typeValue := GetJSONValueCaseInsensitive(jsonObject, 'type', 'Type');
  valueNode := GetJSONValueCaseInsensitive(jsonObject, 'value', 'Value');
  if typeValue = nil then
    Exit(Unassigned);
  if valueNode = nil then
    Exit(Unassigned);

  typeName := typeValue.Value;
  if SameText(typeName, 'Null') or (valueNode is TJSONNull) then
    Exit(Null);
  if SameText(typeName, 'Boolean') then
  begin
    if valueNode is TJSONTrue then
      Exit(True);
    Exit(False);
  end;
  if SameText(typeName, 'Byte') then
    Exit(Byte(StrToIntDef(valueNode.Value, 0)));
  if SameText(typeName, 'Integer') then
    Exit(StrToIntDef(valueNode.Value, 0));
  if SameText(typeName, 'Long') then
    Exit(StrToInt64Def(valueNode.Value, 0));
  if SameText(typeName, 'Decimal') then
  begin
    if valueNode is TJSONNumber then
      Exit(VarAsType(TJSONNumber(valueNode).AsDouble, varCurrency));
    Exit(VarAsType(StrToFloatDef(valueNode.Value, 0), varCurrency));
  end;
  if SameText(typeName, 'Double') then
  begin
    if valueNode is TJSONNumber then
      Exit(TJSONNumber(valueNode).AsDouble);
    Exit(StrToFloatDef(valueNode.Value, 0));
  end;
  if SameText(typeName, 'DateTime') then
  begin
    valueText := valueNode.Value;
    try
      Exit(ISO8601ToDate(valueText, False));
    except
      Exit(valueText);
    end;
  end;
  Exit(valueNode.Value);
end;

function VariantToJSONValue(const value: Variant; propType: TPropertyType): TJSONValue;
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
      Result := TJSONNumber.Create(Int64(VarAsType(value, varInt64)));
    varSingle, varDouble, varCurrency:
      Result := TJSONNumber.Create(Double(VarAsType(value, varDouble)));
    varBoolean:
      Result := TJSONBool.Create(value);
    varDate:
      Result := TJSONString.Create(DateTimeToJavaScriptJSON(VarToDateTime(value)));
  else
    Result := TJSONString.Create(VarToStr(value));
  end;
end;

function JSONValueToVariant(jValue: TJSONValue; propType: TPropertyType): Variant;
var
  numberText: string;
  intValue: Int64;
  floatValue: Double;
  typedValue: Variant;
begin
  if jValue = nil then
    Exit(Unassigned);
  if jValue is TJSONNull then
    Exit(Null);

  if propType = ptStringArray then
    Exit(JSONStringArrayToVariant(jValue));

  if propType = ptVariant then
  begin
    typedValue := JSONTypedValueToVariant(jValue);
    if not VarIsEmpty(typedValue) then
      Exit(typedValue);
  end;

  if jValue is TJSONTrue then
    Exit(True);
  if jValue is TJSONFalse then
    Exit(False);

  if jValue is TJSONNumber then
  begin
    numberText := jValue.Value;
    if (Pos('.', numberText) > 0) or (Pos('e', LowerCase(numberText)) > 0) then
    begin
      floatValue := TJSONNumber(jValue).AsDouble;
      Exit(floatValue);
    end;

    intValue := StrToInt64Def(numberText, 0);
    Exit(intValue);
  end;

  if jValue is TJSONString then
  begin
    if propType = ptDate then
    begin
      try
        Exit(ISO8601ToDate(TJSONString(jValue).Value, False));
      except
        Exit(TJSONString(jValue).Value);
      end;
    end;
    Exit(TJSONString(jValue).Value);
  end;

  Result := jValue.ToJSON;
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
  Result.AddPair('propertyName', propertyName);
  Result.AddPair('propertyType', TJSONNumber.Create(Ord(propertyType)));
  if not VarIsEmpty(oldValue) then
    Result.AddPair('oldValue', VariantToJSONValue(oldValue, propertyType));
  if not VarIsEmpty(newValue) then
    Result.AddPair('newValue', VariantToJSONValue(newValue, propertyType));
end;

class function TChangeOperationItem.FromJSON(jObj: TJSONObject): TChangeOperationItem;
var
  propName: string;
  pt: TPropertyType;
  oldJson, newJson: TJSONValue;
begin
  propName := jObj.GetValue<string>('propertyName', jObj.GetValue<string>('PropertyName', ''));
  pt := TPropertyType(jObj.GetValue<Integer>('propertyType', jObj.GetValue<Integer>('PropertyType', 1)));
  oldJson := GetJSONValueCaseInsensitive(jObj, 'oldValue', 'OldValue');
  newJson := GetJSONValueCaseInsensitive(jObj, 'newValue', 'NewValue');
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
  inherited;
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
    Result.AddPair('componentName', componentName);
  if componentClass <> '' then
    Result.AddPair('componentClass', componentClass);
  if parentName <> '' then
    Result.AddPair('parentName', parentName);
  if oldItemIndex >= 0 then
    Result.AddPair('oldItemIndex', TJSONNumber.Create(oldItemIndex));
  if oldParentName <> '' then
    Result.AddPair('oldParentName', oldParentName);
  Result.AddPair('date', DateTimeToJavaScriptJSON(date));
  propsArr := TJSONArray.Create;
  for i := 0 to properties.Count - 1 do
    propsArr.AddElement(properties[i].ToJSON);
  Result.AddPair('properties', propsArr);
  Result.AddPair('expandedProperties', TJSONBool.Create(expandedProperties));
  Result.AddPair('operation', TJSONNumber.Create(Ord(operation)));
  Result.AddPair('groupId', TJSONNumber.Create(groupId));
end;

class function TChangeObjectOperation.FromJSON(jObj: TJSONObject): TChangeObjectOperation;
var
  propsArr: TJSONArray;
  i: Integer;
  propObj: TJSONObject;
  dateStr: string;
begin
  Result := TChangeObjectOperation.Create(
    TOperationType(jObj.GetValue<Integer>('operation', jObj.GetValue<Integer>('Operation', 0))),
    jObj.GetValue<Integer>('groupId', jObj.GetValue<Integer>('GroupId', 0))
  );
  Result.componentName := jObj.GetValue<string>('componentName', jObj.GetValue<string>('ComponentName', ''));
  Result.componentClass := jObj.GetValue<string>('componentClass', jObj.GetValue<string>('ComponentClass', ''));
  Result.parentName := jObj.GetValue<string>('parentName', jObj.GetValue<string>('ParentName', ''));
  Result.oldItemIndex := jObj.GetValue<Integer>('oldItemIndex', jObj.GetValue<Integer>('OldItemIndex', -1));
  Result.oldParentName := jObj.GetValue<string>('oldParentName', jObj.GetValue<string>('OldParentName', ''));
  Result.expandedProperties := jObj.GetValue<Boolean>('expandedProperties', jObj.GetValue<Boolean>('ExpandedProperties', True));
  if jObj.TryGetValue<string>('date', dateStr) or jObj.TryGetValue<string>('Date', dateStr) then
  begin
    try
      Result.date := ISO8601ToDate(dateStr, False);
    except
      Result.date := Now;
    end;
  end;
  propsArr := nil;
  if (not jObj.TryGetValue<TJSONArray>('properties', propsArr)) then
    jObj.TryGetValue<TJSONArray>('Properties', propsArr);
  if Assigned(propsArr) then
  begin
    for i := 0 to propsArr.Count - 1 do
    begin
      propObj := propsArr.Items[i] as TJSONObject;
      Result.properties.Add(TChangeOperationItem.FromJSON(propObj));
    end;
  end;
end;

{ TUndoCue }

constructor TUndoCue.Create(AReport: TRpReport);
begin
  inherited Create;
  FReport := AReport;
  FGroupId := 0;
  UndoOperations := TObjectList<TChangeObjectOperation>.Create(True);
  RedoOperations := TObjectList<TChangeObjectOperation>.Create(True);
end;

destructor TUndoCue.Destroy;
begin
  UndoOperations.Free;
  RedoOperations.Free;
  inherited;
end;

function TUndoCue.GetGroupId: Integer;
begin
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
  if (op.operation = otAdd) or (op.operation = otRemove) then
  begin
    isPosComp := (op.componentClass = 'TRPLABEL') or (op.componentClass = 'TRPEXPRESSION') or
                 (op.componentClass = 'TRPSHAPE') or (op.componentClass = 'TRPIMAGE') or
                 (op.componentClass = 'TRPBARCODE') or (op.componentClass = 'TRPCHART');
    if isPosComp and (op.parentName = '') then
      raise Exception.Create('UndoCue: La sección del componente no tiene nombre');
  end;
  UndoOperations.Add(op);
  // se pierde el redo al hacer una nueva operación
  RedoOperations.Clear;
end;

procedure TUndoCue.Clear;
begin
  UndoOperations.Clear;
  RedoOperations.Clear;
end;

function TUndoCue.Undo: TObjectList<TChangeObjectOperation>;
var
  op: TChangeObjectOperation;
  gId, newGroupId: Integer;
begin
  if UndoOperations.Count = 0 then
    Exit(nil);

  Result := TObjectList<TChangeObjectOperation>.Create(False); // no ownership
  gId := UndoOperations.Last.groupId;
  newGroupId := gId;

  while newGroupId = gId do
  begin
    if UndoOperations.Count = 0 then
      Break;
    op := UndoOperations.Last;
    // Extract without freeing (move to redo)
    UndoOperations.OwnsObjects := False;
    UndoOperations.Delete(UndoOperations.Count - 1);
    UndoOperations.OwnsObjects := True;

    Result.Add(op);
    ApplyOperation(op, True);
    RedoOperations.Add(op);

    if UndoOperations.Count = 0 then
      Break;
    newGroupId := UndoOperations.Last.groupId;
  end;
end;

function TUndoCue.Redo: TObjectList<TChangeObjectOperation>;
var
  op: TChangeObjectOperation;
  gId, newGroupId: Integer;
begin
  if RedoOperations.Count = 0 then
    Exit(nil);

  Result := TObjectList<TChangeObjectOperation>.Create(False);
  gId := RedoOperations.Last.groupId;
  newGroupId := gId;

  while newGroupId = gId do
  begin
    if RedoOperations.Count = 0 then
      Break;
    op := RedoOperations.Last;
    RedoOperations.OwnsObjects := False;
    RedoOperations.Delete(RedoOperations.Count - 1);
    RedoOperations.OwnsObjects := True;

    Result.Add(op);
    ApplyOperation(op, False);
    UndoOperations.Add(op);

    if RedoOperations.Count = 0 then
      Break;
    newGroupId := RedoOperations.Last.groupId;
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
  temp: TCollectionItem;
begin
  if down then
    increment := 1
  else
    increment := -1;

  if className = 'TRPSUBREPORT' then
  begin
    FReport.SubReports.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPSECTION' then
  begin
    if aParentName = '' then
      raise Exception.Create('Parent name required for TRPSECTION swap.');
    subreport := TRpSubReport(GetComponentByName(aParentName));
    subreport.Sections.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPPARAM' then
  begin
    FReport.Params.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPDATAINFOITEM' then
  begin
    FReport.DataInfo.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else if className = 'TRPDATABASEINFOITEM' then
  begin
    FReport.DatabaseInfo.Items[aOldIndex].Index := aOldIndex + increment;
  end
  else
    raise Exception.Create('Swap not supported for className: ' + className);
end;

procedure TUndoCue.ApplyOperation(operation: TChangeObjectOperation; isUndo: Boolean);
var
  target: TObject;
  loadTarget: Boolean;
  parentSection: TRpSection;
  parentSubreport: TRpSubReport;
  parentItem: TObject;
  newParentName, sOldParentName: string;
  oldParentSection, newParentSection: TRpSection;
  indexOld, i: Integer;
  comp: TRpCommonPosComponent;
  compItem: TRpCommonListItem;
  sec: TRpSection;
  secItem: TRpSectionListItem;
  subrepItem: TRpSubReportListItem;
  dinfo: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
  param: TRpParam;
begin
  target := nil;
  loadTarget := True;

  case operation.operation of
    otSwapDown, otSwapUp:
      begin
        ApplySwapOperation(
          operation.componentClass,
          operation.operation = otSwapDown,
          operation.oldItemIndex,
          operation.parentName
        );
        Exit;
      end;

    otRename:
      begin
        if isUndo then
        begin
          target := GetComponentByName(operation.componentName);
          TComponent(target).Name := operation.oldParentName;
        end
        else
        begin
          target := GetComponentByName(operation.oldParentName);
          TComponent(target).Name := operation.componentName;
        end;
        Exit;
      end;

    otRemove:
      begin
        if isUndo then
        begin
          // Undo remove = re-create the element
          if operation.parentName <> '' then
          begin
            target := NewComponentByClassName(operation.componentClass, FReport);
            TComponent(target).Name := operation.componentName;
            parentItem := GetComponentByName(operation.parentName);
            if parentItem is TRpSection then
            begin
              parentSection := TRpSection(parentItem);
              compItem := parentSection.ReportComponents.Insert(operation.oldItemIndex);
              compItem.Component := TRpCommonPosComponent(target);
            end
            else if parentItem is TRpSubReport then
            begin
              secItem := TRpSectionListItem(
                TRpSubReport(parentItem).Sections.Insert(operation.oldItemIndex));
              secItem.Section := TRpSection(target);
              // Set SubReport reference so the section works correctly
              TRpSection(target).SubReport := TRpSubReport(parentItem);
            end;
          end
          else
          begin
            // Report-level items: collection items and subreports
            if operation.componentClass = 'TRPDATAINFOITEM' then
            begin
              dinfo := FReport.DataInfo.Add('');
              dinfo.Name := operation.componentName;
              if operation.oldItemIndex >= 0 then
                dinfo.Index := operation.oldItemIndex;
              target := dinfo;
            end
            else if operation.componentClass = 'TRPDATABASEINFOITEM' then
            begin
              dbinfo := FReport.DatabaseInfo.Add('');
              dbinfo.Name := operation.componentName;
              if operation.oldItemIndex >= 0 then
                dbinfo.Index := operation.oldItemIndex;
              target := dbinfo;
            end
            else if operation.componentClass = 'TRPPARAM' then
            begin
              param := FReport.Params.Add('');
              param.IntName := operation.componentName;
              if operation.oldItemIndex >= 0 then
                param.Index := operation.oldItemIndex;
              target := param;
            end
            else if operation.componentClass = 'TRPSUBREPORT' then
            begin
              target := TRpSubReport.Create(FReport);
              TRpSubReport(target).Name := operation.componentName;
              subrepItem := FReport.SubReports.Add;
              subrepItem.SubReport := TRpSubReport(target);
              if operation.oldItemIndex >= 0 then
                subrepItem.Index := operation.oldItemIndex;
            end;
          end;
        end
        else
        begin
          // Redo remove = delete again
          target := GetComponentByName(operation.componentName);
          if target is TRpCommonPosComponent then
          begin
            comp := TRpCommonPosComponent(target);
            if operation.parentName <> '' then
            begin
              parentSection := TRpSection(GetComponentByName(operation.parentName));
              indexOld := parentSection.Components.IndexOf(comp);
              if indexOld >= 0 then
              begin
                parentSection.Components.Items[indexOld].Component := nil;
                parentSection.Components.Delete(indexOld);
              end;
            end;
            comp.Free;
          end
          else if target is TRpSection then
          begin
            sec := TRpSection(target);
            if operation.parentName <> '' then
            begin
              parentSubreport := TRpSubReport(GetComponentByName(operation.parentName));
              for i := 0 to parentSubreport.Sections.Count - 1 do
              begin
                if SameText(parentSubreport.Sections.Items[i].Section.Name, sec.Name) then
                begin
                  // Remove the section from the list but nil slot first
                  // (do NOT call FreeSection - that would delete the group pair)
                  parentSubreport.Sections.Items[i].Section := nil;
                  parentSubreport.Sections.Delete(i);
                  Break;
                end;
              end;
            end;
            // Free subcomponents then the section itself
            sec.FreeComponents;
            sec.Free;
          end
          else if target is TRpSubReport then
          begin
            FReport.DeleteSubReport(TRpSubReport(target));
          end
          else if target is TRpDataInfoItem then
          begin
            for i := 0 to FReport.DataInfo.Count - 1 do
            begin
              if SameText(FReport.DataInfo.Items[i].Name, operation.componentName) then
              begin
                FReport.DataInfo.Delete(i);
                Break;
              end;
            end;
          end
          else if target is TRpDatabaseInfoItem then
          begin
            for i := 0 to FReport.DatabaseInfo.Count - 1 do
            begin
              if SameText(FReport.DatabaseInfo.Items[i].Name, operation.componentName) then
              begin
                FReport.DatabaseInfo.Delete(i);
                Break;
              end;
            end;
          end
          else if target is TRpParam then
          begin
            for i := 0 to FReport.Params.Count - 1 do
            begin
              if SameText(FReport.Params.Items[i].IntName, operation.componentName) then
              begin
                FReport.Params.Delete(i);
                Break;
              end;
            end;
          end;
          Exit;
        end;
      end;

    otAdd:
      begin
        if not isUndo then
          loadTarget := False;
      end;
  else
    loadTarget := True;
  end;

  // For otAdd with isUndo=False, we don't need target (we create it)
  // For other operations or otAdd with isUndo=True, get the target
  if loadTarget then
    target := GetComponentByName(operation.componentName);

  parentSection := nil;
  parentSubreport := nil;

  if operation.operation = otAdd then
  begin
    // Get parent info BEFORE checking isUndo, following TypeScript pattern
    if operation.parentName <> '' then
    begin
      parentItem := GetComponentByName(operation.parentName);
      if parentItem is TRpSection then
        parentSection := TRpSection(parentItem)
      else if parentItem is TRpSubReport then
        parentSubreport := TRpSubReport(parentItem);
    end;

    if isUndo then
    begin
      // Undo add = remove the component - FOLLOW TYPESCRIPT EXACTLY
      // TypeScript searches in parent array by comparing names, not using getComponentByName
      // This way it works even if previous operations already removed components
      
      if parentSection <> nil then
      begin
        // Search for component in section by name (like TypeScript)
        for i := 0 to parentSection.Components.Count - 1 do
        begin
          comp := TrpCommonPosComponent(parentSection.Components.Items[i].Component);
          if SameText(comp.Name, operation.componentName) then
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
        // Search for section in subreport by name (like TypeScript)
        for i := 0 to parentSubreport.Sections.Count - 1 do
        begin
          if SameText(parentSubreport.Sections.Items[i].Section.Name, operation.componentName) then
          begin
            operation.oldItemIndex := i;
            sec := parentSubreport.Sections.Items[i].Section;
            parentSubreport.Sections.Items[i].Section := nil;
            parentSubreport.Sections.Delete(i);
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
      
      // Component not found - it may have been removed by a previous operation in the same group
      Exit;
    end
    else
    begin
      // Redo add = re-create
      if parentSection <> nil then
      begin
        target := NewComponentByClassName(operation.componentClass, FReport);
        TComponent(target).Name := operation.componentName;
        compItem := parentSection.ReportComponents.Insert(operation.oldItemIndex);
        compItem.Component := TRpCommonPosComponent(target);
      end
      else if parentSubreport <> nil then
      begin
        target := NewComponentByClassName(operation.componentClass, FReport);
        TComponent(target).Name := operation.componentName;
        secItem := TRpSectionListItem(
          parentSubreport.Sections.Insert(operation.oldItemIndex));
        secItem.Section := TRpSection(target);
        // Set SubReport reference so the section works correctly
        TRpSection(target).SubReport := parentSubreport;
      end
      else
      begin
        if operation.componentClass = 'TRPPARAM' then
        begin
          param := FReport.Params.Add('');
          param.IntName := operation.componentName;
          if operation.oldItemIndex >= 0 then
            param.Index := operation.oldItemIndex;
          target := param;
        end
        else if operation.componentClass = 'TRPDATAINFOITEM' then
        begin
          dinfo := FReport.DataInfo.Add('');
          dinfo.Name := operation.componentName;
          if operation.oldItemIndex >= 0 then
            dinfo.Index := operation.oldItemIndex;
          target := dinfo;
        end
        else if operation.componentClass = 'TRPDATABASEINFOITEM' then
        begin
          dbinfo := FReport.DatabaseInfo.Add('');
          dbinfo.Name := operation.componentName;
          if operation.oldItemIndex >= 0 then
            dbinfo.Index := operation.oldItemIndex;
          target := dbinfo;
        end
        else if operation.componentClass = 'TRPSUBREPORT' then
        begin
          target := FReport.AddSubReport;
          TRpSubReport(target).Name := operation.componentName;
        end
        else
          raise Exception.Create('Class not found: ' + operation.componentClass);
      end;
    end;
  end;

  // Handle parent change (move between sections)
  if (operation.parentName <> '') and (operation.oldParentName <> '') then
  begin
    if isUndo then
    begin
      newParentName := operation.oldParentName;
      sOldParentName := operation.parentName;
    end
    else
    begin
      newParentName := operation.parentName;
      sOldParentName := operation.oldParentName;
    end;
    oldParentSection := TRpSection(GetComponentByName(sOldParentName));
    newParentSection := TRpSection(GetComponentByName(newParentName));
    if (oldParentSection = nil) or (newParentSection = nil) then
      raise Exception.Create('Can not undo/redo parent change');
    indexOld := oldParentSection.ReportComponents.IndexOf(TRpCommonPosComponent(target));
    if indexOld < 0 then
      raise Exception.Create('Component not found for parent change');
    // Move component: remove from old, add to new
    oldParentSection.ReportComponents.Items[indexOld].Component := nil;
    oldParentSection.ReportComponents.Delete(indexOld);
    compItem := newParentSection.ReportComponents.Add;
    compItem.Component := TRpCommonPosComponent(target);
  end;

  ApplyPropertiesToObject(operation, target, isUndo);
end;

procedure TUndoCue.ApplyPropertiesToObject(operation: TChangeObjectOperation;
  target: TObject; isUndo: Boolean);
var
  prop: TChangeOperationItem;
  nvalue: Variant;
  propsItem: IPropertiesItem;
  mappedPropName: string;
begin
  if operation.properties.Count = 0 then
    Exit;
  if (Target is TRpCommonComponent) then
  begin
   propsItem:=TRpCommonComponent(target);
  end
  else
   if (target is TrpBasereport) then
    propsItem:=TrpBaseReport(target)
  else
   if (target is TRpParam) then
    propsItem:=TRpParam(target)
  else
   if (target is TRpDataInfoItem) then
    propsItem:=TRpDataInfoItem(target)
  else
   if (target is TRpDatabaseInfoItem) then
    propsItem:=TRpDatabaseInfoItem(target)
  else
   if (target is TRpSubReport) then
    propsItem:=TRpSubReport(target)
  else
    raise Exception.Create('Object does not support IPropertiesItem: ' + target.ClassName);
  for prop in operation.properties do
  begin
    if (isUndo) and (operation.operation <> otRemove) then
      nvalue := prop.oldValue
    else
      nvalue := prop.newValue;
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
    root.AddPair('groupId', TJSONNumber.Create(FGroupId));
    undoArr := TJSONArray.Create;
    for i := 0 to UndoOperations.Count - 1 do
      undoArr.AddElement(UndoOperations[i].ToJSON);
    root.AddPair('undoOperations', undoArr);

    redoArr := TJSONArray.Create;
    for i := 0 to RedoOperations.Count - 1 do
      redoArr.AddElement(RedoOperations[i].ToJSON);
    root.AddPair('redoOperations', redoArr);

    Result := root.ToJSON;
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
  op.AddProperty('printCondition', ptString, Null, sec.GetItemProperty('PrintCondition'));
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
  root: TJSONObject;
  undoArr, redoArr: TJSONArray;
  i: Integer;
  opObj: TJSONObject;
begin
  UndoOperations.Clear;
  RedoOperations.Clear;
  root := TJSONObject.ParseJSONValue(jsonStr) as TJSONObject;
  if root = nil then
    Exit;
  try
    FGroupId := root.GetValue<Integer>('groupId', root.GetValue<Integer>('GroupId', 0));
    undoArr := nil;
    if (not root.TryGetValue<TJSONArray>('undoOperations', undoArr)) then
      root.TryGetValue<TJSONArray>('UndoOperations', undoArr);
    if Assigned(undoArr) then
    begin
      for i := 0 to undoArr.Count - 1 do
      begin
        opObj := undoArr.Items[i] as TJSONObject;
        UndoOperations.Add(TChangeObjectOperation.FromJSON(opObj));
      end;
    end;
    redoArr := nil;
    if (not root.TryGetValue<TJSONArray>('redoOperations', redoArr)) then
      root.TryGetValue<TJSONArray>('RedoOperations', redoArr);
    if Assigned(redoArr) then
    begin
      for i := 0 to redoArr.Count - 1 do
      begin
        opObj := redoArr.Items[i] as TJSONObject;
        RedoOperations.Add(TChangeObjectOperation.FromJSON(opObj));
      end;
    end;
  finally
    root.Free;
  end;
end;

end.

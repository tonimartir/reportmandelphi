unit rpmdundocue;

{$I rpconf.inc}

interface

uses
  System.SysUtils, System.Generics.Collections, System.DateUtils,
  System.Classes, System.JSON, System.Variants,
  rpreport, rpbasereport, rpsubreport, rpsection, rpsecutil,
  rpprintitem, rpdatainfo, rpparams;

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

  TOperationType = (
    otAdd,
    otModify,
    otRemove,
    otSwapDown,
    otSwapUp,
    otRename
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
    function Undo: TObjectList<TChangeObjectOperation>;
    function Redo: TObjectList<TChangeObjectOperation>;
    procedure Clear;
    function ToJSON: string;
    procedure FromJSON(const jsonStr: string);

    property GroupId: Integer read FGroupId;
    property Report: TRpReport read FReport write FReport;
  end;

implementation

uses rplabelitem, rpdrawitem, rpmdbarcode, rpmdchart;

function NewComponentByClassName(const className: string; AOwner: TComponent): TComponent; forward;

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
  Result.AddPair('PropertyName', propertyName);
  Result.AddPair('PropertyType', TJSONNumber.Create(Ord(propertyType)));
  Result.AddPair('OldValue', VarToStr(oldValue));
  Result.AddPair('NewValue', VarToStr(newValue));
end;

class function TChangeOperationItem.FromJSON(jObj: TJSONObject): TChangeOperationItem;
var
  propName, sOld, sNew: string;
  pt: TPropertyType;
begin
  propName := jObj.GetValue<string>('PropertyName', '');
  pt := TPropertyType(jObj.GetValue<Integer>('PropertyType', 1));
  sOld := jObj.GetValue<string>('OldValue', '');
  sNew := jObj.GetValue<string>('NewValue', '');
  Result := TChangeOperationItem.Create(propName, pt, sOld, sNew);
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
begin
  properties.Add(TChangeOperationItem.Create(propName, propType, oldValue, newValue));
  if properties.Count > 5 then
    expandedProperties := False;
end;

function TChangeObjectOperation.ToJSON: TJSONObject;
var
  propsArr: TJSONArray;
  i: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Operation', TJSONNumber.Create(Ord(operation)));
  Result.AddPair('GroupId', TJSONNumber.Create(groupId));
  Result.AddPair('ComponentName', componentName);
  Result.AddPair('ComponentClass', componentClass);
  Result.AddPair('ParentName', parentName);
  Result.AddPair('OldItemIndex', TJSONNumber.Create(oldItemIndex));
  Result.AddPair('OldParentName', oldParentName);
  Result.AddPair('Date', DateToISO8601(date, False));
  Result.AddPair('ExpandedProperties', TJSONBool.Create(expandedProperties));
  propsArr := TJSONArray.Create;
  for i := 0 to properties.Count - 1 do
    propsArr.AddElement(properties[i].ToJSON);
  Result.AddPair('Properties', propsArr);
end;

class function TChangeObjectOperation.FromJSON(jObj: TJSONObject): TChangeObjectOperation;
var
  propsArr: TJSONArray;
  i: Integer;
  propObj: TJSONObject;
begin
  Result := TChangeObjectOperation.Create(
    TOperationType(jObj.GetValue<Integer>('Operation', 0)),
    jObj.GetValue<Integer>('GroupId', 0)
  );
  Result.componentName := jObj.GetValue<string>('ComponentName', '');
  Result.componentClass := jObj.GetValue<string>('ComponentClass', '');
  Result.parentName := jObj.GetValue<string>('ParentName', '');
  Result.oldItemIndex := jObj.GetValue<Integer>('OldItemIndex', -1);
  Result.oldParentName := jObj.GetValue<string>('OldParentName', '');
  Result.expandedProperties := jObj.GetValue<Boolean>('ExpandedProperties', True);
  if jObj.TryGetValue<string>('Date', Result.componentName) then
  begin
    try
      Result.date := ISO8601ToDate(jObj.GetValue<string>('Date', ''), False);
    except
      Result.date := Now;
    end;
  end;
  propsArr := nil;
  if jObj.TryGetValue<TJSONArray>('Properties', propsArr) then
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
  Inc(FGroupId);
  Result := FGroupId;
end;

procedure TUndoCue.AddOperation(op: TChangeObjectOperation);
begin
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
  targetReportItem: TObject;
  newParentName, sOldParentName: string;
  oldParentSection, newParentSection: TRpSection;
  indexOld, i: Integer;
  comp: TRpCommonPosComponent;
  compItem: TRpCommonListItem;
  sec: TRpSection;
  secItem: TRpSectionListItem;
  subItem: TRpSubReportListItem;
  dinfo: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
  param: TRpParam;
begin
  target := nil;
  loadTarget := True;

  case operation.operation of
    otAdd:
      begin
        if not isUndo then
          loadTarget := False;
      end;

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
        // For rename: componentName = new name, oldParentName = old name
        // When undoing, we switch from componentName back to oldParentName
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
          loadTarget := False;
          // Undo remove = re-create the element
          target := NewComponentByClassName(operation.componentClass, FReport);
          TComponent(target).Name := operation.componentName;
          if operation.parentName <> '' then
          begin
            parentItem := GetComponentByName(operation.parentName);
            if parentItem is TRpSection then
            begin
              parentSection := TRpSection(parentItem);
              compItem := parentSection.ReportComponents.Insert(operation.oldItemIndex);
              compItem.Component := TRpCommonPosComponent(target);
            end
            else if parentItem is TRpSubReport then
            begin
              // Insert section into subreport
              secItem := TRpSectionListItem(
                TRpSubReport(parentItem).Sections.Insert(operation.oldItemIndex));
              secItem.Section := TRpSection(target);
            end;
          end
          else
          begin
            // Add to report-level collection
            if operation.componentClass = 'TRPDATAINFOITEM' then
            begin
              dinfo := FReport.DataInfo.Add('');
              dinfo.Name := operation.componentName;
            end
            else if operation.componentClass = 'TRPDATABASEINFOITEM' then
            begin
              dbinfo := FReport.DatabaseInfo.Add('');
              dbinfo.Name := operation.componentName;
            end
            else if operation.componentClass = 'TRPPARAM' then
            begin
              param := FReport.Params.Add('');
              param.Name := operation.componentName;
            end
            else if operation.componentClass = 'TRPSUBREPORT' then
            begin
              FReport.AddSubReport.Name := operation.componentName;
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
            // Find parent section and remove
            if operation.parentName <> '' then
            begin
              parentSection := TRpSection(GetComponentByName(operation.parentName));
              indexOld := parentSection.ReportComponents.IndexOf(comp);
              if indexOld >= 0 then
              begin
                parentSection.ReportComponents.Items[indexOld].Component := nil;
                parentSection.ReportComponents.Delete(indexOld);
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
                if parentSubreport.Sections.Items[i].Section = sec then
                begin
                  parentSubreport.Sections.Items[i].Section := nil;
                  parentSubreport.Sections.Delete(i);
                  Break;
                end;
              end;
            end;
            sec.Free;
          end
          else if target is TRpSubReport then
          begin
            FReport.DeleteSubReport(TRpSubReport(target));
          end;
          Exit;
        end;
      end;
  else
    loadTarget := True;
  end;

  if loadTarget then
    target := GetComponentByName(operation.componentName);

  parentSection := nil;
  parentSubreport := nil;

  if operation.operation = otAdd then
  begin
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
      // Undo add = remove the component
      if target = nil then
        Exit;
      if parentSection <> nil then
      begin
        indexOld := parentSection.ReportComponents.IndexOf(TRpCommonPosComponent(target));
        if indexOld >= 0 then
        begin
          operation.oldItemIndex := indexOld;
          parentSection.ReportComponents.Items[indexOld].Component := nil;
          parentSection.ReportComponents.Delete(indexOld);
        end;
        TRpCommonPosComponent(target).Free;
        Exit;
      end
      else
      begin
        if target is TRpSection then
        begin
          if parentSubreport = nil then
            raise Exception.Create('No parentSubreport');
          for i := 0 to parentSubreport.Sections.Count - 1 do
          begin
            if parentSubreport.Sections.Items[i].Section = TRpSection(target) then
            begin
              operation.oldItemIndex := i;
              parentSubreport.Sections.Items[i].Section := nil;
              parentSubreport.Sections.Delete(i);
              TRpSection(target).Free;
              Exit;
            end;
          end;
          raise Exception.Create('Section not found');
        end
        else if target is TRpSubReport then
        begin
          for i := 0 to FReport.SubReports.Count - 1 do
          begin
            if FReport.SubReports.Items[i].SubReport = TRpSubReport(target) then
            begin
              operation.oldItemIndex := i;
              FReport.DeleteSubReport(TRpSubReport(target));
              Exit;
            end;
          end;
          raise Exception.Create('Subreport not found');
        end
        else if target is TRpDataInfoItem then
        begin
          for i := 0 to FReport.DataInfo.Count - 1 do
          begin
            if FReport.DataInfo.Items[i].Name = operation.componentName then
            begin
              operation.oldItemIndex := i;
              FReport.DataInfo.Delete(i);
              Exit;
            end;
          end;
        end
        else if target is TRpDatabaseInfoItem then
        begin
          for i := 0 to FReport.DatabaseInfo.Count - 1 do
          begin
            if FReport.DatabaseInfo.Items[i].Name = operation.componentName then
            begin
              operation.oldItemIndex := i;
              FReport.DatabaseInfo.Delete(i);
              Exit;
            end;
          end;
        end
        else if target is TRpParam then
        begin
          for i := 0 to FReport.Params.Count - 1 do
          begin
            if FReport.Params.Items[i].Name = operation.componentName then
            begin
              operation.oldItemIndex := i;
              FReport.Params.Delete(i);
              Exit;
            end;
          end;
        end;
      end;
    end
    else
    begin
      // Redo add = re-create
      target := NewComponentByClassName(operation.componentClass, FReport);
      TComponent(target).Name := operation.componentName;
      if parentSection <> nil then
      begin
        compItem := parentSection.ReportComponents.Insert(operation.oldItemIndex);
        compItem.Component := TRpCommonPosComponent(target);
      end
      else if parentSubreport <> nil then
      begin
        secItem := TRpSectionListItem(
          parentSubreport.Sections.Insert(operation.oldItemIndex));
        secItem.Section := TRpSection(target);
      end
      else
      begin
        if operation.componentClass = 'TRPPARAM' then
        begin
          param := FReport.Params.Add('');
          param.Name := operation.componentName;
          target := param;
        end
        else if operation.componentClass = 'TRPDATAINFOITEM' then
        begin
          dinfo := FReport.DataInfo.Add('');
          dinfo.Name := operation.componentName;
          target := dinfo;
        end
        else if operation.componentClass = 'TRPDATABASEINFOITEM' then
        begin
          dbinfo := FReport.DatabaseInfo.Add('');
          dbinfo.Name := operation.componentName;
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
begin
  if (Target is TRpCommonComponent) then
  begin
   propsItem:=TRpCommonComponent(target);
  end
  else
   if (target is TrpBasereport) then
    propsItem:=TrpBaseReport(propsItem)
  else
    raise Exception.Create('Object does not support IPropertiesItem: ' + target.ClassName);
  for prop in operation.properties do
  begin
    if (isUndo) and (operation.operation <> otRemove) then
      nvalue := prop.oldValue
    else
      nvalue := prop.newValue;
    propsItem.SetItemProperty(prop.propertyName, nvalue);
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
    root.AddPair('GroupId', TJSONNumber.Create(FGroupId));
    undoArr := TJSONArray.Create;
    for i := 0 to UndoOperations.Count - 1 do
      undoArr.AddElement(UndoOperations[i].ToJSON);
    root.AddPair('UndoOperations', undoArr);

    redoArr := TJSONArray.Create;
    for i := 0 to RedoOperations.Count - 1 do
      redoArr.AddElement(RedoOperations[i].ToJSON);
    root.AddPair('RedoOperations', redoArr);

    Result := root.ToJSON;
  finally
    root.Free;
  end;
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
    FGroupId := root.GetValue<Integer>('GroupId', 0);
    undoArr := nil;
    if root.TryGetValue<TJSONArray>('UndoOperations', undoArr) then
    begin
      for i := 0 to undoArr.Count - 1 do
      begin
        opObj := undoArr.Items[i] as TJSONObject;
        UndoOperations.Add(TChangeObjectOperation.FromJSON(opObj));
      end;
    end;
    redoArr := nil;
    if root.TryGetValue<TJSONArray>('RedoOperations', redoArr) then
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

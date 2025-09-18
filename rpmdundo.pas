unit rpmdundo;

interface

uses
  System.SysUtils, System.Generics.Collections, System.DateUtils, rpreport,
  rpsection;

type
  TPropertyType = (ptInteger, ptNumber, ptString, ptDate, ptBinary);
  TOperationType = (otAdd, otModify, otRemove);

type
  TChangeOperationItem = class
  public
    propertyName: string;
    propertyType: TPropertyType;
    oldValue: Variant;
    newValue: Variant;
    constructor Create(const APropertyName: string; APropertyType: TPropertyType;
      const AOldValue, ANewValue: Variant);
  end;

  TChangeObjectOperation = class
  public
    operation: TOperationType;
    componentName: string;
    componentClass: string;
    parentName: string;
    oldParentName: string;
    date: TDateTime;
    properties: TObjectList<TChangeOperationItem>;
    constructor Create(AOperation: TOperationType);
    destructor Destroy; override;
    procedure AddProperty(const propName: string; propType: TPropertyType;
      const oldValue, newValue: Variant);
  end;


  TUndoCue = class
  private
    FReport: TRpReport;
    undoOperations: TObjectList<TChangeObjectOperation>;
    redoOperations: TObjectList<TChangeObjectOperation>;
    function GetComponentByName(const name: string): TObject;
    procedure ApplyOperation(operation: TChangeObjectOperation; isUndo: Boolean);
  public
    constructor Create(AReport: TRpReport);
    destructor Destroy; override;
    procedure AddOperation(op: TChangeObjectOperation);
    function Undo: TChangeObjectOperation;
    function Redo: TChangeObjectOperation;
  end;

implementation

{ TChangeOperationItem }

constructor TChangeOperationItem.Create(const APropertyName: string;
  APropertyType: TPropertyType; const AOldValue, ANewValue: Variant);
begin
  propertyName := APropertyName;
  propertyType := APropertyType;
  oldValue := AOldValue;
  newValue := ANewValue;
end;

{ TChangeObjectOperation }

constructor TChangeObjectOperation.Create(AOperation: TOperationType);
begin
  operation := AOperation;
  date := Now;
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
end;

{ TUndoCue }

constructor TUndoCue.Create(AReport: TRpReport);
begin
  FReport := AReport;
  undoOperations := TObjectList<TChangeObjectOperation>.Create(True);
  redoOperations := TObjectList<TChangeObjectOperation>.Create(True);
end;

destructor TUndoCue.Destroy;
begin
  undoOperations.Free;
  redoOperations.Free;
  inherited;
end;

procedure TUndoCue.AddOperation(op: TChangeObjectOperation);
begin
  undoOperations.Add(op);
  redoOperations.Clear;
end;

function TUndoCue.Undo: TChangeObjectOperation;
var
  op: TChangeObjectOperation;
begin
  if undoOperations.Count = 0 then
    Exit(nil);

  op := undoOperations.Last;
  undoOperations.Delete(undoOperations.Count - 1);

  ApplyOperation(op, True);
  redoOperations.Add(op);
  Result := op;
end;

function TUndoCue.Redo: TChangeObjectOperation;
var
  op: TChangeObjectOperation;
begin
  if redoOperations.Count = 0 then
    Exit(nil);

  op := redoOperations.Last;
  redoOperations.Delete(redoOperations.Count - 1);

  ApplyOperation(op, False);
  undoOperations.Add(op);
  Result := op;
end;

function TUndoCue.GetComponentByName(const name: string): TObject;
begin
  if name = 'REPORT' then
    Result := FReport
  else
  begin
    if not FReport.components.TryGetValue(name, Result) then
      raise Exception.Create('Item not found at apply Operation undo/redo cue: ' + name);
  end;
end;

procedure TUndoCue.ApplyOperation(operation: TChangeObjectOperation; isUndo: Boolean);
var
  target: TObject;
  newParentName, oldParentName: string;
  oldParentSection, newParentSection: TRpSection;
  indexOld: Integer;
  prop: TChangeOperationItem;
  nvalue: Variant;
begin
  target := GetComponentByName(operation.componentName);
  if target = nil then
    Exit;

  if (operation.parentName <> '') and (operation.oldParentName <> '') then
  begin
    if isUndo then
    begin
      newParentName := operation.oldParentName;
      oldParentName := operation.parentName;
    end
    else
    begin
      newParentName := operation.parentName;
      oldParentName := operation.oldParentName;
    end;
    oldParentSection := TRpSection(GetComponentByName(oldParentName));
    newParentSection := TRpSection(GetComponentByName(newParentName));

    if (oldParentSection = nil) or (newParentSection = nil) then
      raise Exception.Create('Can not undo/redo');

    indexOld := oldParentSection.components.IndexOf(target);
    if indexOld < 0 then
      raise Exception.Create('Component not found');

    oldParentSection.components.Delete(indexOld);
    newParentSection.components.Add(target);
  end;

  for prop in operation.properties do
  begin
    if (isUndo) then
    begin
      nvalue:=prop.oldValue;
    end
    else
    begin
      nvalue:=prop.newValue;
    end;

    SetPropValue(target, prop.propertyName,
      nvalue);
  end;
end;

end.

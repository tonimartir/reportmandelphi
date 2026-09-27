{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfparamslcl                                  }
{       Parameter definition dialog (LCL version)       }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfparamslcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Forms, Dialogs, ComCtrls,
  Buttons, ExtCtrls, Controls, StdCtrls, CheckLst,
  DB, Variants,
  rpmdconsts, rpdatainfo, rpreport, rpparams, rptypes, rpmaskedit,
  rpbasereport, rpgraphutilslcl, rpxmlstream, rpmdundocuelcl;

type
  { TFRpParamsLCL }

  TFRpParamsLCL = class(TForm)
  private
    FReport: TRpReport;
    FParams: TRpParamList;
    FDataInfo: TRpDataInfoList;
    FDoOk: Boolean;
    FUpdating: Boolean;

    procedure BuildControls;
    procedure LParamsClick(Sender: TObject);
    procedure UpdateValue(param: TRpParam);
    procedure EValueExit(Sender: TObject);
    procedure PropChange(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BRenameClick(Sender: TObject);
    procedure BUpClick(Sender: TObject);
    procedure BDownClick(Sender: TObject);
    procedure BAddDataClick(Sender: TObject);
    procedure BDeleteDataClick(Sender: TObject);
    procedure ComboSearchParamDropDown(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    function IsDotNet: Boolean;
  public
    // Left panel: parameters list and management
    PLeft: TPanel;
    PToolbar: TPanel;
    BAdd: TButton;
    BDelete: TButton;
    BUp: TButton;
    BDown: TButton;
    BRename: TButton;
    LParams: TListBox;

    // Bottom panel
    PBottom: TPanel;
    BOK: TButton;
    BCancel: TButton;

    // Center PageControl
    PClient: TPanel;
    PageControl1: TPageControl;
    TabGeneral: TTabSheet;
    TabDataSets: TTabSheet;
    TabValuesSearch: TTabSheet;

    // General tab controls
    LDescription: TLabel;
    EDescription: TEdit;
    LDataType: TLabel;
    ComboDataType: TComboBox;
    LValue: TLabel;
    EValue: TRpMaskEdit;
    CheckNull: TCheckBox;
    CheckVisible: TCheckBox;
    CheckNeverVisible: TCheckBox;
    CheckReadOnly: TCheckBox;
    CheckAllowNulls: TCheckBox;
    LHint: TLabel;
    EHint: TEdit;
    LValidation: TLabel;
    EValidation: TEdit;
    LErrorMessage: TLabel;
    EErrorMessage: TEdit;

    // Datasets tab controls
    LAssign: TLabel;
    ComboDatasets: TComboBox;
    BAddData: TButton;
    BDeleteData: TButton;
    LDatasets: TListBox;

    // Values & Search tab controls
    GValues: TGroupBox;
    LItems: TLabel;
    MItems: TMemo;
    LValues: TLabel;
    MValues: TMemo;
    ECheckList: TCheckListBox;

    GSearch: TGroupBox;
    LLookup: TLabel;
    ComboLookup: TComboBox;
    LSearchDataset: TLabel;
    ComboSearchDataset: TComboBox;
    LSearchParam: TLabel;
    ComboSearchParam: TComboBox;
    LSearch: TLabel;
    ESearch: TEdit;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure FillParamList;

    property Report: TRpReport read FReport write FReport;
    property Params: TRpParamList read FParams;
    property DataInfo: TRpDataInfoList read FDataInfo write FDataInfo;
    property DoOk: Boolean read FDoOk;
  end;

// Variant comparison used to detect changed values: Null/Empty are equal,
// values of incompatible types are compared as strings instead of raising.
function ParamValuesEqual(const AValue, BValue: Variant): Boolean;
// Records in the report undo cue the differences between origParams and
// newParams (removed, added and modified parameters), all in one group.
// Port of rpfparamsvcl.RecordParamUndoChanges.
procedure RecordParamUndoChanges(origParams, newParams: TRpParamList; report: TRpReport;
  groupId: Integer = -1);
procedure ShowParamDef(params: TRpParamList; datainfo: TRpDataInfoList; report: TRpReport;
  deferUndoUntilAccept: Boolean = False);

implementation

function ParamStringListToVariant(strings: TStrings): Variant;
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

function ParamValuesEqual(const AValue, BValue: Variant): Boolean;
begin
  if VarIsEmpty(AValue) or VarIsNull(AValue) then
  begin
    Result := VarIsEmpty(BValue) or VarIsNull(BValue);
    Exit;
  end;
  if VarIsEmpty(BValue) or VarIsNull(BValue) then
  begin
    Result := False;
    Exit;
  end;
  if VarIsArray(AValue) or VarIsArray(BValue) then
  begin
    Result := False;
    Exit;
  end;
  try
    Result := VarSameValue(AValue, BValue);
  except
    on EVariantError do
      // Not comparable as values (e.g. string against number)
      Result := VarToStr(AValue) = VarToStr(BValue);
  end;
end;

function SameParamStringLists(list1, list2: TStrings): Boolean;
begin
  Result := list1.Text = list2.Text;
end;

function GetParamOperationName(param: TRpParam): string;
begin
  if not Assigned(param) then
    raise Exception.Create('GetParamOperationName: parameter is nil');
  if Trim(param.IntName) = '' then
    raise Exception.Create('GetParamOperationName: parameter ' + param.Name + ' has empty IntName');
  Result := param.IntName;
end;

procedure RecordParamUndoChanges(origParams, newParams: TRpParamList; report: TRpReport;
  groupId: Integer = -1);
var
  undoCue: TUndoCue;
  i: Integer;
  origParam, newParam: TRpParam;
  op: TChangeObjectOperation;
begin
  if not Assigned(report) then
    Exit;
  if not Assigned(report.UndoCue) then
    report.UndoCue := TUndoCue.Create(report);
  undoCue := TUndoCue(report.UndoCue);
  if groupId < 0 then
    groupId := undoCue.GetGroupId;
  // Removed params (in the original list but not in the new one)
  for i := 0 to origParams.Count - 1 do
  begin
    origParam := origParams.Items[i];
    if newParams.FindParamByIntName(GetParamOperationName(origParam)) = nil then
    begin
      op := TChangeObjectOperation.Create(otRemove, groupId);
      op.componentName := GetParamOperationName(origParam);
      op.componentClass := 'TRPPARAM';
      op.oldItemIndex := i;
      // otRemove: TUndoCue.ApplyPropertiesToObject recreates the item from
      // newValue on undo (same convention as DeleteSelection)
      op.AddProperty('alias', ptString, Null, origParam.Name);
      op.AddProperty('description', ptString, Null, origParam.Description);
      op.AddProperty('hint', ptString, Null, origParam.Hint);
      op.AddProperty('validation', ptString, Null, origParam.Validation);
      op.AddProperty('errorMessage', ptString, Null, origParam.ErrorMessage);
      op.AddProperty('visible', ptBoolean, Null, origParam.Visible);
      op.AddProperty('neverVisible', ptBoolean, Null, origParam.NeverVisible);
      op.AddProperty('isReadOnly', ptBoolean, Null, origParam.IsReadOnly);
      op.AddProperty('allowNulls', ptBoolean, Null, origParam.AllowNulls);
      op.AddProperty('paramType', ptInteger, Null, Integer(origParam.ParamType));
      op.AddProperty('lookupDataset', ptString, Null, origParam.LookupDataset);
      op.AddProperty('searchDataset', ptString, Null, origParam.SearchDataset);
      op.AddProperty('searchParam', ptString, Null, origParam.SearchParam);
      op.AddProperty('value', ptVariant, Null, origParam.Value);
      op.AddProperty('datasets', ptStringArray, Null, ParamStringListToVariant(origParam.Datasets));
      op.AddProperty('items', ptStringArray, Null, ParamStringListToVariant(origParam.Items));
      op.AddProperty('values', ptStringArray, Null, ParamStringListToVariant(origParam.Values));
      op.AddProperty('selected', ptStringArray, Null, ParamStringListToVariant(origParam.Selected));
      undoCue.AddOperation(op);
    end;
  end;
  // Added params (in the new list but not in the original one)
  for i := 0 to newParams.Count - 1 do
  begin
    newParam := newParams.Items[i];
    if origParams.FindParamByIntName(GetParamOperationName(newParam)) = nil then
    begin
      op := TChangeObjectOperation.Create(otAdd, groupId);
      op.componentName := GetParamOperationName(newParam);
      op.componentClass := 'TRPPARAM';
      op.oldItemIndex := i;
      op.AddProperty('alias', ptString, Null, newParam.Name);
      op.AddProperty('description', ptString, Null, newParam.Description);
      op.AddProperty('hint', ptString, Null, newParam.Hint);
      op.AddProperty('validation', ptString, Null, newParam.Validation);
      op.AddProperty('errorMessage', ptString, Null, newParam.ErrorMessage);
      op.AddProperty('visible', ptBoolean, Null, newParam.Visible);
      op.AddProperty('neverVisible', ptBoolean, Null, newParam.NeverVisible);
      op.AddProperty('isReadOnly', ptBoolean, Null, newParam.IsReadOnly);
      op.AddProperty('allowNulls', ptBoolean, Null, newParam.AllowNulls);
      op.AddProperty('paramType', ptInteger, Null, Integer(newParam.ParamType));
      op.AddProperty('lookupDataset', ptString, Null, newParam.LookupDataset);
      op.AddProperty('searchDataset', ptString, Null, newParam.SearchDataset);
      op.AddProperty('searchParam', ptString, Null, newParam.SearchParam);
      op.AddProperty('value', ptVariant, Null, newParam.Value);
      op.AddProperty('datasets', ptStringArray, Null, ParamStringListToVariant(newParam.Datasets));
      op.AddProperty('items', ptStringArray, Null, ParamStringListToVariant(newParam.Items));
      op.AddProperty('values', ptStringArray, Null, ParamStringListToVariant(newParam.Values));
      op.AddProperty('selected', ptStringArray, Null, ParamStringListToVariant(newParam.Selected));
      undoCue.AddOperation(op);
    end;
  end;
  // Modified params
  for i := 0 to newParams.Count - 1 do
  begin
    newParam := newParams.Items[i];
    origParam := origParams.FindParamByIntName(GetParamOperationName(newParam));
    if Assigned(origParam) then
    begin
      op := TChangeObjectOperation.Create(otModify, groupId);
      op.componentName := GetParamOperationName(newParam);
      op.componentClass := 'TRPPARAM';
      if origParam.Name <> newParam.Name then
        op.AddProperty('alias', ptString, origParam.Name, newParam.Name);
      if origParam.Description <> newParam.Description then
        op.AddProperty('description', ptString, origParam.Description, newParam.Description);
      if origParam.Hint <> newParam.Hint then
        op.AddProperty('hint', ptString, origParam.Hint, newParam.Hint);
      if origParam.Validation <> newParam.Validation then
        op.AddProperty('validation', ptString, origParam.Validation, newParam.Validation);
      if origParam.ErrorMessage <> newParam.ErrorMessage then
        op.AddProperty('errorMessage', ptString, origParam.ErrorMessage, newParam.ErrorMessage);
      if origParam.Visible <> newParam.Visible then
        op.AddProperty('visible', ptBoolean, origParam.Visible, newParam.Visible);
      if origParam.NeverVisible <> newParam.NeverVisible then
        op.AddProperty('neverVisible', ptBoolean, origParam.NeverVisible, newParam.NeverVisible);
      if origParam.IsReadOnly <> newParam.IsReadOnly then
        op.AddProperty('isReadOnly', ptBoolean, origParam.IsReadOnly, newParam.IsReadOnly);
      if origParam.AllowNulls <> newParam.AllowNulls then
        op.AddProperty('allowNulls', ptBoolean, origParam.AllowNulls, newParam.AllowNulls);
      if Integer(origParam.ParamType) <> Integer(newParam.ParamType) then
        op.AddProperty('paramType', ptInteger, Integer(origParam.ParamType), Integer(newParam.ParamType));
      if origParam.LookupDataset <> newParam.LookupDataset then
        op.AddProperty('lookupDataset', ptString, origParam.LookupDataset, newParam.LookupDataset);
      if origParam.SearchDataset <> newParam.SearchDataset then
        op.AddProperty('searchDataset', ptString, origParam.SearchDataset, newParam.SearchDataset);
      if origParam.SearchParam <> newParam.SearchParam then
        op.AddProperty('searchParam', ptString, origParam.SearchParam, newParam.SearchParam);
      if (Integer(origParam.ParamType) <> Integer(newParam.ParamType)) or
        (not ParamValuesEqual(origParam.Value, newParam.Value)) then
        op.AddProperty('value', ptVariant, origParam.Value, newParam.Value);
      if not SameParamStringLists(origParam.Datasets, newParam.Datasets) then
        op.AddProperty('datasets', ptStringArray, ParamStringListToVariant(origParam.Datasets),
          ParamStringListToVariant(newParam.Datasets));
      if not SameParamStringLists(origParam.Items, newParam.Items) then
        op.AddProperty('items', ptStringArray, ParamStringListToVariant(origParam.Items),
          ParamStringListToVariant(newParam.Items));
      if not SameParamStringLists(origParam.Values, newParam.Values) then
        op.AddProperty('values', ptStringArray, ParamStringListToVariant(origParam.Values),
          ParamStringListToVariant(newParam.Values));
      if not SameParamStringLists(origParam.Selected, newParam.Selected) then
        op.AddProperty('selected', ptStringArray, ParamStringListToVariant(origParam.Selected),
          ParamStringListToVariant(newParam.Selected));
      if op.properties.Count > 0 then
        undoCue.AddOperation(op)
      else
        op.Free;
    end;
  end;
end;

procedure ShowParamDef(params: TRpParamList; datainfo: TRpDataInfoList; report: TRpReport;
  deferUndoUntilAccept: Boolean = False);
var
  dia: TFRpParamsLCL;
  i: Integer;
begin
  if not Assigned(params) then Exit;
  params.RestoreInitialValues;

  dia := TFRpParamsLCL.Create(Application);
  try
    dia.Report := report;
    dia.Params.Assign(params);
    dia.DataInfo := datainfo;

    // Fill the combos before the parameter list so the first selected
    // parameter shows its lookup/search values (VCL FormShow order)
    if Assigned(datainfo) then
    begin
      dia.ComboLookup.Items.Clear;
      dia.ComboLookup.Items.Add('');
      dia.ComboSearchDataset.Items.Clear;
      dia.ComboSearchDataset.Items.Add('');
      dia.ComboDatasets.Items.Clear;
      for i := 0 to datainfo.Count - 1 do
      begin
        dia.ComboDatasets.Items.Add(datainfo.Items[i].Alias);
        dia.ComboLookup.Items.Add(datainfo.Items[i].Alias);
        dia.ComboSearchDataset.Items.Add(datainfo.Items[i].Alias);
      end;
      dia.ComboSearchParam.Items.Clear;
      dia.ComboSearchParam.Items.Add('');
      for i := 0 to dia.Params.Count - 1 do
        dia.ComboSearchParam.Items.Add(dia.Params.Items[i].Name);
      if dia.ComboDatasets.Items.Count > 0 then
        dia.ComboDatasets.ItemIndex := 0;
    end;
    dia.FillParamList;

    dia.ShowModal;
    if dia.DoOk then
    begin
      if not deferUndoUntilAccept then
        RecordParamUndoChanges(params, dia.Params, report);
      params.Assign(dia.Params);
    end;
  finally
    dia.Free;
  end;
end;

{ TFRpParamsLCL }

constructor TFRpParamsLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := TranslateStr(199, 'Parameter definition');
  Position := poScreenCenter;
  Width := 760;
  Height := 520;

  FParams := TRpParamList.Create(Self);
  BuildControls;
end;

destructor TFRpParamsLCL.Destroy;
begin
  FParams.Free;
  inherited Destroy;
end;

procedure TFRpParamsLCL.BuildControls;
begin
  // Bottom button panel
  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := 44;
  PBottom.BevelOuter := bvNone;

  BOK := TButton.Create(Self);
  BOK.Parent := PBottom;
  BOK.Left := Width - 190;
  BOK.Top := 9;
  BOK.Width := 85;
  BOK.Height := 27;
  BOK.Caption := TranslateStr(93, 'OK');
  BOK.Default := True;
  BOK.Anchors := [akTop, akRight];
  BOK.OnClick := BOKClick;

  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.Left := Width - 95;
  BCancel.Top := 9;
  BCancel.Width := 85;
  BCancel.Height := 27;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.Cancel := True;
  BCancel.Anchors := [akTop, akRight];
  BCancel.OnClick := BCancelClick;

  // Left parameter list panel
  PLeft := TPanel.Create(Self);
  PLeft.Parent := Self;
  PLeft.Align := alLeft;
  PLeft.Width := 200;
  PLeft.BevelOuter := bvNone;

  PToolbar := TPanel.Create(Self);
  PToolbar.Parent := PLeft;
  PToolbar.Align := alTop;
  PToolbar.Height := 34;
  PToolbar.BevelOuter := bvNone;

  BAdd := TButton.Create(Self);
  BAdd.Parent := PToolbar;
  BAdd.Left := 4;
  BAdd.Top := 4;
  BAdd.Width := 34;
  BAdd.Height := 26;
  BAdd.Caption := '+';
  BAdd.Hint := TranslateStr(187, 'Adds a new parameter');
  BAdd.ShowHint := True;
  BAdd.OnClick := BAddClick;

  BDelete := TButton.Create(Self);
  BDelete.Parent := PToolbar;
  BDelete.Left := 42;
  BDelete.Top := 4;
  BDelete.Width := 34;
  BDelete.Height := 26;
  BDelete.Caption := '-';
  BDelete.Hint := TranslateStr(189, 'Deletes the selected parameter');
  BDelete.ShowHint := True;
  BDelete.OnClick := BDeleteClick;

  BUp := TButton.Create(Self);
  BUp.Parent := PToolbar;
  BUp.Left := 80;
  BUp.Top := 4;
  BUp.Width := 34;
  BUp.Height := 26;
  BUp.Caption := '▲';
  BUp.Hint := TranslateStr(190, 'Moves the selected parameter up');
  BUp.ShowHint := True;
  BUp.OnClick := BUpClick;

  BDown := TButton.Create(Self);
  BDown.Parent := PToolbar;
  BDown.Left := 118;
  BDown.Top := 4;
  BDown.Width := 34;
  BDown.Height := 26;
  BDown.Caption := '▼';
  BDown.Hint := TranslateStr(191, 'Moves the selected parameter down');
  BDown.ShowHint := True;
  BDown.OnClick := BDownClick;

  BRename := TButton.Create(Self);
  BRename.Parent := PToolbar;
  BRename.Left := 156;
  BRename.Top := 4;
  BRename.Width := 38;
  BRename.Height := 26;
  // Narrow button: a language independent symbol, the hint has the text
  BRename.Caption := '✎';
  BRename.Hint := TranslateStr(192, 'Renames the selected parameter');
  BRename.ShowHint := True;
  BRename.OnClick := BRenameClick;

  LParams := TListBox.Create(Self);
  LParams.Parent := PLeft;
  LParams.Align := alClient;
  LParams.OnClick := LParamsClick;

  // Center client area
  PClient := TPanel.Create(Self);
  PClient.Parent := Self;
  PClient.Align := alClient;
  PClient.BevelOuter := bvNone;

  PageControl1 := TPageControl.Create(Self);
  PageControl1.Parent := PClient;
  PageControl1.Align := alClient;

  // Tab 1: General
  TabGeneral := PageControl1.AddTabSheet;
  TabGeneral.Caption := SRpGeneral;

  LDescription := TLabel.Create(Self);
  LDescription.Parent := TabGeneral;
  LDescription.Left := 16;
  LDescription.Top := 16;
  LDescription.Caption := TranslateStr(197, 'Description') + ':';

  EDescription := TEdit.Create(Self);
  EDescription.Parent := TabGeneral;
  EDescription.Left := 16;
  EDescription.Top := 34;
  EDescription.Width := 300;
  EDescription.OnChange := PropChange;

  LDataType := TLabel.Create(Self);
  LDataType.Parent := TabGeneral;
  LDataType.Left := 330;
  LDataType.Top := 16;
  LDataType.Caption := TranslateStr(193, 'Data type') + ':';

  ComboDataType := TComboBox.Create(Self);
  ComboDataType.Parent := TabGeneral;
  ComboDataType.Left := 330;
  ComboDataType.Top := 34;
  ComboDataType.Width := 180;
  ComboDataType.Style := csDropDownList;
  GetPossibleDataTypesDesignA(ComboDataType.Items);
  ComboDataType.OnChange := PropChange;

  LValue := TLabel.Create(Self);
  LValue.Parent := TabGeneral;
  LValue.Left := 16;
  LValue.Top := 72;
  LValue.Caption := TranslateStr(194, 'Value') + ':';

  EValue := TRpMaskEdit.Create(Self);
  EValue.Parent := TabGeneral;
  EValue.Left := 16;
  EValue.Top := 90;
  EValue.Width := 300;
  EValue.OnExit := EValueExit;

  CheckNull := TCheckBox.Create(Self);
  CheckNull.Parent := TabGeneral;
  CheckNull.Left := 330;
  CheckNull.Top := 92;
  CheckNull.Caption := TranslateStr(196, 'Null Value');
  CheckNull.OnClick := PropChange;

  CheckVisible := TCheckBox.Create(Self);
  CheckVisible.Parent := TabGeneral;
  CheckVisible.Left := 16;
  CheckVisible.Top := 130;
  CheckVisible.Caption := TranslateStr(195, 'User visible');
  CheckVisible.OnClick := PropChange;

  CheckNeverVisible := TCheckBox.Create(Self);
  CheckNeverVisible.Parent := TabGeneral;
  CheckNeverVisible.Left := 200;
  CheckNeverVisible.Top := 130;
  CheckNeverVisible.Caption := TranslateStr(1381, 'Never visible');
  CheckNeverVisible.OnClick := PropChange;

  CheckReadOnly := TCheckBox.Create(Self);
  CheckReadOnly.Parent := TabGeneral;
  CheckReadOnly.Left := 330;
  CheckReadOnly.Top := 130;
  CheckReadOnly.Caption := TranslateStr(1379, 'Read only');
  CheckReadOnly.OnClick := PropChange;

  CheckAllowNulls := TCheckBox.Create(Self);
  CheckAllowNulls.Parent := TabGeneral;
  CheckAllowNulls.Left := 16;
  CheckAllowNulls.Top := 158;
  CheckAllowNulls.Caption := SRpAllowNulls;
  CheckAllowNulls.OnClick := PropChange;

  LHint := TLabel.Create(Self);
  LHint.Parent := TabGeneral;
  LHint.Left := 16;
  LHint.Top := 194;
  LHint.Caption := TranslateStr(1382, 'Hint') + ':';

  EHint := TEdit.Create(Self);
  EHint.Parent := TabGeneral;
  EHint.Left := 16;
  EHint.Top := 212;
  EHint.Width := 494;
  EHint.OnChange := PropChange;

  LValidation := TLabel.Create(Self);
  LValidation.Parent := TabGeneral;
  LValidation.Left := 16;
  LValidation.Top := 248;
  LValidation.Caption := TranslateStr(1401, 'Validation') + ':';

  EValidation := TEdit.Create(Self);
  EValidation.Parent := TabGeneral;
  EValidation.Left := 16;
  EValidation.Top := 266;
  EValidation.Width := 494;
  EValidation.OnChange := PropChange;

  LErrorMessage := TLabel.Create(Self);
  LErrorMessage.Parent := TabGeneral;
  LErrorMessage.Left := 16;
  LErrorMessage.Top := 302;
  LErrorMessage.Caption := TranslateStr(1403, 'Error message') + ':';

  EErrorMessage := TEdit.Create(Self);
  EErrorMessage.Parent := TabGeneral;
  EErrorMessage.Left := 16;
  EErrorMessage.Top := 320;
  EErrorMessage.Width := 494;
  EErrorMessage.OnChange := PropChange;

  // Tab 2: Datasets
  TabDataSets := PageControl1.AddTabSheet;
  TabDataSets.Caption := TranslateStr(198, 'Assign to datasets');

  LAssign := TLabel.Create(Self);
  LAssign.Parent := TabDataSets;
  LAssign.Left := 16;
  LAssign.Top := 16;
  LAssign.Caption := SRpDataset + ':';

  ComboDatasets := TComboBox.Create(Self);
  ComboDatasets.Parent := TabDataSets;
  ComboDatasets.Left := 16;
  ComboDatasets.Top := 34;
  ComboDatasets.Width := 250;
  ComboDatasets.Style := csDropDownList;

  BAddData := TButton.Create(Self);
  BAddData.Parent := TabDataSets;
  BAddData.Left := 280;
  BAddData.Top := 32;
  BAddData.Width := 80;
  BAddData.Height := 27;
  BAddData.Caption := SRpAdd;
  BAddData.OnClick := BAddDataClick;

  BDeleteData := TButton.Create(Self);
  BDeleteData.Parent := TabDataSets;
  BDeleteData.Left := 370;
  BDeleteData.Top := 32;
  BDeleteData.Width := 80;
  BDeleteData.Height := 27;
  BDeleteData.Caption := SRpDelete;
  BDeleteData.OnClick := BDeleteDataClick;

  LDatasets := TListBox.Create(Self);
  LDatasets.Parent := TabDataSets;
  LDatasets.Left := 16;
  LDatasets.Top := 72;
  LDatasets.Width := 434;
  LDatasets.Height := 280;

  // Tab 3: Values & Search
  TabValuesSearch := PageControl1.AddTabSheet;
  TabValuesSearch.Caption := TranslateStr(961, 'Value list') + ' / ' + TranslateStr(1375, 'Search');

  GValues := TGroupBox.Create(Self);
  GValues.Parent := TabValuesSearch;
  GValues.Left := 10;
  GValues.Top := 10;
  GValues.Width := 500;
  GValues.Height := 200;
  GValues.Caption := SRpSParamListDesc;

  LItems := TLabel.Create(Self);
  LItems.Parent := GValues;
  LItems.Left := 10;
  LItems.Top := 18;
  LItems.Caption := TranslateStr(197, 'Description') + ':';

  MItems := TMemo.Create(Self);
  MItems.Parent := GValues;
  MItems.Left := 10;
  MItems.Top := 36;
  MItems.Width := 230;
  MItems.Height := 140;
  MItems.OnChange := PropChange;

  LValues := TLabel.Create(Self);
  LValues.Parent := GValues;
  LValues.Left := 255;
  LValues.Top := 18;
  LValues.Caption := TranslateStr(194, 'Value') + ':';

  MValues := TMemo.Create(Self);
  MValues.Parent := GValues;
  MValues.Left := 255;
  MValues.Top := 36;
  MValues.Width := 230;
  MValues.Height := 140;
  MValues.OnChange := PropChange;

  ECheckList := TCheckListBox.Create(Self);
  ECheckList.Parent := GValues;
  ECheckList.Left := 10;
  ECheckList.Top := 36;
  ECheckList.Width := 475;
  ECheckList.Height := 140;
  ECheckList.Visible := False;
  ECheckList.OnClickCheck := PropChange;

  GSearch := TGroupBox.Create(Self);
  GSearch.Parent := TabValuesSearch;
  GSearch.Left := 10;
  GSearch.Top := 220;
  GSearch.Width := 500;
  GSearch.Height := 150;
  GSearch.Caption := SRpValueSearch;

  LLookup := TLabel.Create(Self);
  LLookup.Parent := GSearch;
  LLookup.Left := 10;
  LLookup.Top := 20;
  LLookup.Caption := SrpLookupDataset + ':';

  ComboLookup := TComboBox.Create(Self);
  ComboLookup.Parent := GSearch;
  ComboLookup.Left := 10;
  ComboLookup.Top := 38;
  ComboLookup.Width := 230;
  ComboLookup.Style := csDropDownList;
  ComboLookup.OnChange := PropChange;

  LSearchDataset := TLabel.Create(Self);
  LSearchDataset.Parent := GSearch;
  LSearchDataset.Left := 255;
  LSearchDataset.Top := 20;
  LSearchDataset.Caption := SrpSearchDataset + ':';

  ComboSearchDataset := TComboBox.Create(Self);
  ComboSearchDataset.Parent := GSearch;
  ComboSearchDataset.Left := 255;
  ComboSearchDataset.Top := 38;
  ComboSearchDataset.Width := 230;
  ComboSearchDataset.Style := csDropDownList;
  ComboSearchDataset.OnChange := PropChange;

  LSearchParam := TLabel.Create(Self);
  LSearchParam.Parent := GSearch;
  LSearchParam.Left := 10;
  LSearchParam.Top := 74;
  LSearchParam.Caption := TranslateStr(1380, 'Search parameter') + ':';

  ComboSearchParam := TComboBox.Create(Self);
  ComboSearchParam.Parent := GSearch;
  ComboSearchParam.Left := 10;
  ComboSearchParam.Top := 92;
  ComboSearchParam.Width := 230;
  ComboSearchParam.Style := csDropDownList;
  ComboSearchParam.OnDropDown := ComboSearchParamDropDown;
  ComboSearchParam.OnChange := PropChange;

  LSearch := TLabel.Create(Self);
  LSearch.Parent := GSearch;
  LSearch.Left := 255;
  LSearch.Top := 74;
  LSearch.Caption := TranslateStr(946, 'Search for string') + ':';

  ESearch := TEdit.Create(Self);
  ESearch.Parent := GSearch;
  ESearch.Left := 255;
  ESearch.Top := 92;
  ESearch.Width := 230;
  ESearch.OnChange := PropChange;
end;

procedure TFRpParamsLCL.FillParamList;
var
  i: Integer;
begin
  LParams.Clear;
  for i := 0 to FParams.Count - 1 do
    LParams.Items.Add(FParams.Items[i].Name);

  if LParams.Items.Count > 0 then
    LParams.ItemIndex := 0;
  // Always refresh: with an empty list the property panel must be hidden
  LParamsClick(Self);
end;

procedure TFRpParamsLCL.LParamsClick(Sender: TObject);
var
  param: TRpParam;
begin
  if LParams.Items.Count < 1 then
  begin
    // Nothing to edit: hide the property pages (VCL hides GProperties)
    PageControl1.Visible := False;
    BDelete.Enabled := False;
    BRename.Enabled := False;
    BUp.Enabled := False;
    BDown.Enabled := False;
    Exit;
  end;
  PageControl1.Visible := True;
  BDelete.Enabled := True;
  BRename.Enabled := True;
  BUp.Enabled := True;
  BDown.Enabled := True;

  FUpdating := True;
  try
    if LParams.ItemIndex < 0 then
      LParams.ItemIndex := 0;

    param := FParams.ParamByName(LParams.Items[LParams.ItemIndex]);
    CheckVisible.Checked := param.Visible;
    CheckNeverVisible.Checked := param.NeverVisible;
    CheckReadOnly.Checked := param.IsReadOnly;
    CheckAllowNulls.Checked := param.AllowNulls;
    CheckNull.Checked := (param.Value = Null);
    EDescription.Text := param.Description;
    EValidation.Text := param.Validation;
    EErrorMessage.Text := param.ErrorMessage;
    EHint.Text := param.Hint;
    ESearch.Text := param.Search;
    MValues.Lines.Assign(param.Values);
    MItems.Lines.Assign(param.Items);

    LDatasets.Clear;
    LDatasets.Items.Assign(param.Datasets);
    if LDatasets.Items.Count > 0 then
      LDatasets.ItemIndex := 0;

    ComboLookup.ItemIndex := ComboLookup.Items.IndexOf(param.LookupDataset);
    ComboSearchDataset.ItemIndex := ComboSearchDataset.Items.IndexOf(param.SearchDataset);
    ComboSearchParam.ItemIndex := ComboSearchParam.Items.IndexOf(param.SearchParam);

    ComboDataType.ItemIndex := ComboDataType.Items.IndexOf(ParamTypeToString(param.ParamType));
    EValue.EditType := teGeneral;
    EValue.Text := '';

    if param.Value <> Null then
    begin
      case param.ParamType of
        rpParamString, rpParamExpreA, rpParamExpreB, rpParamSubst, rpParamSubstE,
        rpParamInitialExpression, rpParamUnknown:
          EValue.Text := param.AsString;
        rpParamSubstList, rpParamList:
          EValue.Text := VarToStr(param.Value);
        rpParamInteger:
        begin
          EValue.Text := IntToStr(param.Value);
          EValue.EditType := teInteger;
        end;
        rpParamDouble:
        begin
          EValue.Text := FloatToStr(param.Value);
          EValue.EditType := teFloat;
        end;
        rpParamCurrency:
        begin
          EValue.Text := CurrToStr(param.Value);
          EValue.EditType := teCurrency;
        end;
        rpParamDate:
          EValue.Text := DateToStr(param.Value);
        rpParamTime:
          EValue.Text := TimeToStr(param.Value);
        rpParamDateTime:
          EValue.Text := DateTimeToStr(param.Value);
        rpParamBool:
          EValue.Text := BoolToStr(param.Value, True);
      end;
    end;
  finally
    FUpdating := False;
  end;

  // Same as VCL: EDescriptionChange(CheckNull)
  PropChange(CheckNull);
end;

function TFRpParamsLCL.IsDotNet: Boolean;
begin
  Result := False;
  if Assigned(FReport) and (FReport.DatabaseInfo.Count > 0) then
    Result := (FReport.DatabaseInfo[0].Driver in [rpdatadriver, rpdotnet2driver]);
end;

procedure TFRpParamsLCL.UpdateValue(param: TRpParam);
var
  i, idx: Integer;
begin
  ESearch.Visible := param.ParamType in [rpParamSubst, rpParamSubstE, rpParamSubstList, rpParamMultiple];
  LSearch.Visible := ESearch.Visible;

  GValues.Visible := param.ParamType in [rpParamList, rpParamSubstList, rpParamMultiple];
  GSearch.Visible := not GValues.Visible;

  CheckNull.Visible := param.ParamType <> rpParamMultiple;
  CheckAllowNulls.Visible := CheckNull.Visible;
  EValue.Visible := CheckNull.Visible and (not CheckNull.Checked);

  ECheckList.Visible := (param.ParamType = rpParamMultiple);
  MItems.Visible := not ECheckList.Visible;
  MValues.Visible := not ECheckList.Visible;
  LItems.Visible := not ECheckList.Visible;
  LValues.Visible := not ECheckList.Visible;

  if param.ParamType = rpParamMultiple then
  begin
    ECheckList.Items.Assign(param.Items);
    for i := 0 to ECheckList.Items.Count - 1 do
      ECheckList.Checked[i] := False;

    for i := 0 to param.Selected.Count - 1 do
    begin
      if IsDotNet then
        idx := param.Values.IndexOf(param.Selected[i])
      else
        idx := StrToIntDef(param.Selected[i], -1);

      if (idx >= 0) and (idx < ECheckList.Items.Count) then
        ECheckList.Checked[idx] := True;
    end;
  end
  else
  begin
    // Port of TFRpParamsVCL.UpdateValue: an empty text gets the default for
    // the data type, then the text is converted into the parameter value.
    // Conversion errors are raised (they block OK and are shown to the user).
    case param.ParamType of
      rpParamInteger:
        EValue.EditType := teInteger;
      rpParamDouble:
        EValue.EditType := teFloat;
      rpParamCurrency:
        EValue.EditType := teCurrency;
    else
      EValue.EditType := teGeneral;
    end;
    if EValue.Text = '' then
    begin
      case param.ParamType of
        rpParamString, rpParamExpreA, rpParamExpreB, rpParamSubst, rpParamSubstE,
        rpParamList, rpParamSubstList, rpParamInitialExpression, rpParamUnknown:
          EValue.Text := '';
        rpParamInteger:
          EValue.Text := IntToStr(0);
        rpParamDouble:
          EValue.Text := FloatToStr(0.0);
        rpParamCurrency:
          EValue.Text := CurrToStr(0.0);
        rpParamDate:
          EValue.Text := DateToStr(Date);
        rpParamTime:
          EValue.Text := TimeToStr(Time);
        rpParamDateTime:
          EValue.Text := DateTimeToStr(Now);
        rpParamBool:
          EValue.Text := BoolToStr(False);
      end;
    end;
    if CheckNull.Checked then
    begin
      param.Value := Null;
      EValue.Visible := False;
    end
    else
    begin
      EValue.Visible := True;
      case param.ParamType of
        rpParamString, rpParamExpreA, rpParamExpreB, rpParamSubst, rpParamSubstE,
        rpParamList, rpParamSubstList, rpParamInitialExpression, rpParamUnknown:
          param.Value := EValue.Text;
        rpParamInteger:
          param.Value := StrToInt(EValue.Text);
        rpParamDouble:
          param.Value := StrToFloat(EValue.Text);
        rpParamCurrency:
          param.Value := StrToCurr(EValue.Text);
        rpParamDate:
          param.Value := StrToDate(EValue.Text);
        rpParamTime:
          param.Value := StrToTime(EValue.Text);
        rpParamDateTime:
          param.Value := StrToDateTime(EValue.Text);
        rpParamBool:
          param.Value := StrToBool(EValue.Text);
      end;
    end;
  end;
end;

procedure TFRpParamsLCL.EValueExit(Sender: TObject);
var
  param: TRpParam;
begin
  if (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count) then Exit;
  param := FParams.ParamByName(LParams.Items[LParams.ItemIndex]);
  // Raises on invalid input, like VCL (the value is not silently dropped)
  UpdateValue(param);
end;

procedure TFRpParamsLCL.PropChange(Sender: TObject);
var
  param: TRpParam;
  i: Integer;
begin
  if FUpdating or (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count) then Exit;
  param := FParams.ParamByName(LParams.Items[LParams.ItemIndex]);

  if Sender = EDescription then
    param.Description := EDescription.Text
  else if Sender = EErrorMessage then
    param.ErrorMessage := EErrorMessage.Text
  else if Sender = EValidation then
    param.Validation := EValidation.Text
  else if Sender = EHint then
    param.Hint := EHint.Text
  else if Sender = ESearch then
    param.Search := ESearch.Text
  else if Sender = MItems then
  begin
    param.Items := MItems.Lines;
    UpdateValue(param);
  end
  else if Sender = MValues then
    param.Values := MValues.Lines
  else if Sender = CheckVisible then
    param.Visible := CheckVisible.Checked
  else if Sender = CheckNeverVisible then
    param.NeverVisible := CheckNeverVisible.Checked
  else if Sender = CheckReadOnly then
    param.IsReadOnly := CheckReadOnly.Checked
  else if Sender = CheckAllowNulls then
    param.AllowNulls := CheckAllowNulls.Checked
  else if Sender = CheckNull then
  begin
    UpdateValue(param);
    if CheckNull.Checked then
      param.Value := Null;
  end
  else if Sender = ComboDataType then
  begin
    if param.ParamType = StringToParamType(ComboDataType.Text) then
      Exit;
    // Changing the type resets the value to the default of the new type
    param.ParamType := StringToParamType(ComboDataType.Text);
    EValue.Text := '';
    UpdateValue(param);
  end
  else if Sender = ECheckList then
  begin
    param.Selected.Clear;
    for i := 0 to ECheckList.Items.Count - 1 do
    begin
      if ECheckList.Checked[i] then
      begin
        if IsDotNet and (i < param.Values.Count) then
          param.Selected.Add(param.Values[i])
        else
          param.Selected.Add(IntToStr(i));
      end;
    end;
  end
  else if Sender = ComboLookup then
    param.LookupDataset := ComboLookup.Text
  else if Sender = ComboSearchDataset then
    param.SearchDataset := ComboSearchDataset.Text
  else if Sender = ComboSearchParam then
    param.SearchParam := ComboSearchParam.Text;
end;

procedure TFRpParamsLCL.BAddClick(Sender: TObject);
var
  paramname: string;
  aparam: TRpParam;
begin
  paramname := RpInputBox(SRpNewParam, SRpParamName, '');
  paramname := AnsiUpperCase(Trim(paramname));
  if Length(paramname) < 1 then Exit;

  if FParams.IndexOf(paramname) >= 0 then
    raise Exception.Create(SRpParamNameExists);

  aparam := FParams.Add(paramname);
  if Assigned(FReport) then
    EnsureParamName(TRpBaseReport(FReport), aparam);
  aparam.AllowNulls := False;
  aparam.Value := '';

  FillParamList;
  LParams.ItemIndex := LParams.Items.Count - 1;
  LParamsClick(Self);
end;

procedure TFRpParamsLCL.BDeleteClick(Sender: TObject);
var
  idx: Integer;
begin
  if (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count) then Exit;
  idx := FParams.IndexOf(LParams.Items[LParams.ItemIndex]);
  if idx >= 0 then
  begin
    FParams.Delete(idx);
    FillParamList;
  end;
end;

procedure TFRpParamsLCL.BRenameClick(Sender: TObject);
var
  oldname, newname: string;
  param: TRpParam;
begin
  if (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count) then Exit;
  oldname := LParams.Items[LParams.ItemIndex];
  param := FParams.ParamByName(oldname);

  newname := RpInputBox(SRpRenameParam, SRpParamName, param.Name);
  newname := AnsiUpperCase(Trim(newname));
  if (Length(newname) = 0) or (newname = oldname) then Exit;

  if FParams.IndexOf(newname) >= 0 then
    raise Exception.Create(SRpParamNameExists);

  param.Name := newname;
  LParams.Items[LParams.ItemIndex] := newname;
end;

procedure TFRpParamsLCL.BUpClick(Sender: TObject);
var
  idx: Integer;
  temp: TRpParamList;
  name: string;
begin
  if (LParams.ItemIndex <= 0) or (FParams.Count < 2) then Exit;
  idx := LParams.ItemIndex;
  name := LParams.Items[idx];

  temp := TRpParamList.Create(Self);
  try
    temp.Assign(FParams);
    temp.Items[idx - 1].Assign(FParams.Items[idx]);
    temp.Items[idx].Assign(FParams.Items[idx - 1]);
    FParams.Assign(temp);
  finally
    temp.Free;
  end;

  FillParamList;
  LParams.ItemIndex := LParams.Items.IndexOf(name);
  LParamsClick(Self);
end;

procedure TFRpParamsLCL.BDownClick(Sender: TObject);
var
  idx: Integer;
  temp: TRpParamList;
  name: string;
begin
  if (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count - 1) or (FParams.Count < 2) then Exit;
  idx := LParams.ItemIndex;
  name := LParams.Items[idx];

  temp := TRpParamList.Create(Self);
  try
    temp.Assign(FParams);
    temp.Items[idx + 1].Assign(FParams.Items[idx]);
    temp.Items[idx].Assign(FParams.Items[idx + 1]);
    FParams.Assign(temp);
  finally
    temp.Free;
  end;

  FillParamList;
  LParams.ItemIndex := LParams.Items.IndexOf(name);
  LParamsClick(Self);
end;

procedure TFRpParamsLCL.BAddDataClick(Sender: TObject);
var
  param: TRpParam;
begin
  if (ComboDatasets.ItemIndex < 0) or (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count) then Exit;
  param := FParams.ParamByName(LParams.Items[LParams.ItemIndex]);

  if LDatasets.Items.IndexOf(ComboDatasets.Text) < 0 then
  begin
    LDatasets.Items.Add(ComboDatasets.Text);
    param.Datasets.Assign(LDatasets.Items);
  end;
end;

procedure TFRpParamsLCL.BDeleteDataClick(Sender: TObject);
var
  param: TRpParam;
begin
  if (LDatasets.ItemIndex < 0) or (LParams.ItemIndex < 0) or (LParams.ItemIndex >= FParams.Count) then Exit;
  param := FParams.ParamByName(LParams.Items[LParams.ItemIndex]);

  LDatasets.Items.Delete(LDatasets.ItemIndex);
  param.Datasets.Assign(LDatasets.Items);
end;

procedure TFRpParamsLCL.ComboSearchParamDropDown(Sender: TObject);
var
  oldval: string;
begin
  oldval := ComboSearchParam.Text;
  ComboSearchParam.Items.Assign(LParams.Items);
  ComboSearchParam.ItemIndex := ComboSearchParam.Items.IndexOf(oldval);
end;

procedure TFRpParamsLCL.BOKClick(Sender: TObject);
begin
  // A conversion error raises here and keeps the dialog open
  if EValue.Visible and PageControl1.Visible then
    EValueExit(Self);
  FDoOk := True;
  ModalResult := mrOk;
end;

procedure TFRpParamsLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfselectfieldslcl                            }
{       Dataset and fields selection panel for wizard   }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfselectfieldslcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, CheckLst, ExtCtrls, Buttons,
  rpreport, rpdatainfo, rpmdconsts;

type
  { TFRpSelectFieldsLCL }

  TFRpSelectFieldsLCL = class(TPanel)
  private
    FReport: TRpReport;
    FLabelDataset: TLabel;
    FComboDataset: TComboBox;
    FLabelAvailable: TLabel;
    FLAvailable: TListBox;
    FBAddData: TButton;
    FBDeleteData: TButton;
    FLabelSelected: TLabel;
    FLSelected: TCheckListBox;
    FCheckProportional: TCheckBox;

    procedure ComboDatasetChange(Sender: TObject);
    procedure BAddDataClick(Sender: TObject);
    procedure BDeleteDataClick(Sender: TObject);
    procedure BuildControls;
  public
    fieldlist: TStringList;
    fieldtypes: TStringList;
    fieldsizes: TStringList;
    fieldlabels: TStringList;
    widths: TStringList;
    ftypes: TStringList;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function GetFieldWidth(index: Integer): Integer;
    procedure UpdateDatasets;

    property Report: TRpReport read FReport write FReport;
    property CheckProportional: TCheckBox read FCheckProportional;
    property LSelected: TCheckListBox read FLSelected;
    property ComboDataset: TComboBox read FComboDataset;
  end;

implementation

{ TFRpSelectFieldsLCL }

constructor TFRpSelectFieldsLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  Align := alClient;

  fieldlabels := TStringList.Create;
  widths := TStringList.Create;
  ftypes := TStringList.Create;
  fieldlist := TStringList.Create;
  fieldtypes := TStringList.Create;
  fieldsizes := TStringList.Create;

  BuildControls;
end;

destructor TFRpSelectFieldsLCL.Destroy;
begin
  fieldlist.Free;
  fieldtypes.Free;
  fieldsizes.Free;
  fieldlabels.Free;
  widths.Free;
  ftypes.Free;
  inherited Destroy;
end;

procedure TFRpSelectFieldsLCL.BuildControls;
begin
  // Dataset selector
  FLabelDataset := TLabel.Create(Self);
  FLabelDataset.Parent := Self;
  FLabelDataset.Caption := SRpDataset + ':';
  FLabelDataset.Left := 16;
  FLabelDataset.Top := 12;

  FComboDataset := TComboBox.Create(Self);
  FComboDataset.Parent := Self;
  FComboDataset.Style := csDropDownList;
  FComboDataset.Left := 16;
  FComboDataset.Top := 30;
  FComboDataset.Width := 250;
  FComboDataset.OnChange := ComboDatasetChange;

  FCheckProportional := TCheckBox.Create(Self);
  FCheckProportional.Parent := Self;
  FCheckProportional.Caption := TranslateStr(1488, 'Proportional column widths');
  FCheckProportional.Checked := True;
  FCheckProportional.Left := 280;
  FCheckProportional.Top := 32;

  // Available fields list
  FLabelAvailable := TLabel.Create(Self);
  FLabelAvailable.Parent := Self;
  FLabelAvailable.Caption := TranslateStr(1100, 'Available') + ':';
  FLabelAvailable.Left := 16;
  FLabelAvailable.Top := 64;

  FLAvailable := TListBox.Create(Self);
  FLAvailable.Parent := Self;
  FLAvailable.Left := 16;
  FLAvailable.Top := 84;
  FLAvailable.Width := 210;
  FLAvailable.Height := 240;
  FLAvailable.Anchors := [akLeft, akTop, akBottom];
  FLAvailable.OnDblClick := BAddDataClick;

  // Buttons
  FBAddData := TButton.Create(Self);
  FBAddData.Parent := Self;
  FBAddData.Caption := '>';
  FBAddData.Left := 236;
  FBAddData.Top := 140;
  FBAddData.Width := 36;
  FBAddData.Height := 30;
  FBAddData.OnClick := BAddDataClick;

  FBDeleteData := TButton.Create(Self);
  FBDeleteData.Parent := Self;
  FBDeleteData.Caption := '<';
  FBDeleteData.Left := 236;
  FBDeleteData.Top := 180;
  FBDeleteData.Width := 36;
  FBDeleteData.Height := 30;
  FBDeleteData.OnClick := BDeleteDataClick;

  // Selected fields checklistbox
  FLabelSelected := TLabel.Create(Self);
  FLabelSelected.Parent := Self;
  FLabelSelected.Caption := TranslateStr(1489, 'Selected fields (check to sum)') + ':';
  FLabelSelected.Left := 282;
  FLabelSelected.Top := 64;

  FLSelected := TCheckListBox.Create(Self);
  FLSelected.Parent := Self;
  FLSelected.Left := 282;
  FLSelected.Top := 84;
  FLSelected.Width := 270;
  FLSelected.Height := 240;
  FLSelected.Anchors := [akLeft, akTop, akRight, akBottom];
end;

procedure TFRpSelectFieldsLCL.UpdateDatasets;
var
  i: Integer;
begin
  FComboDataset.Items.Clear;
  if not Assigned(FReport) then Exit;

  for i := 0 to FReport.DataInfo.Count - 1 do
    FComboDataset.Items.Add(FReport.DataInfo.Items[i].Alias);

  if FComboDataset.Items.Count > 0 then
    FComboDataset.ItemIndex := 0;

  ComboDatasetChange(Self);
end;

procedure TFRpSelectFieldsLCL.ComboDatasetChange(Sender: TObject);
var
  i: Integer;
  fieldname: string;
begin
  FLAvailable.Items.Clear;
  if (FComboDataset.ItemIndex < 0) or not Assigned(FReport) then
    Exit;

  if FComboDataset.ItemIndex < FReport.DataInfo.Count then
  begin
    FReport.DataInfo.Items[FComboDataset.ItemIndex].GetFieldNames(fieldlist, fieldtypes, fieldsizes);
    for i := 0 to fieldlist.Count - 1 do
    begin
      fieldname := fieldlist.Strings[i];
      if Pos(' ', fieldname) > 0 then
        fieldname := '[' + fieldname + ']';
      if i < fieldtypes.Count then
        fieldname := fieldname + ' ' + fieldtypes.Strings[i];
      if (i < fieldsizes.Count) and (Length(fieldsizes.Strings[i]) > 0) then
        fieldname := fieldname + '(' + fieldsizes.Strings[i] + ')';
      FLAvailable.Items.Add(fieldname);
    end;
    if FLAvailable.Items.Count > 0 then
      FLAvailable.ItemIndex := 0;
  end;
end;

procedure TFRpSelectFieldsLCL.BAddDataClick(Sender: TObject);
var
  fieldname: string;
  idx: Integer;
begin
  if FLAvailable.ItemIndex < 0 then Exit;

  fieldname := FLAvailable.Items.Strings[FLAvailable.ItemIndex];
  if Length(fieldname) = 0 then Exit;

  if fieldname[1] = '[' then
  begin
    idx := Pos(']', fieldname);
    fieldlabels.Add(Copy(fieldname, 2, idx - 2));
    widths.Add(IntToStr(GetFieldWidth(FLAvailable.ItemIndex)));
    if FLAvailable.ItemIndex < fieldtypes.Count then
      ftypes.Add(fieldtypes.Strings[FLAvailable.ItemIndex])
    else
      ftypes.Add('');
    fieldname := '[' + FComboDataset.Text + '.' + Copy(fieldname, 2, idx - 2) + ']';
  end
  else
  begin
    idx := Pos(' ', fieldname);
    if idx <= 0 then idx := Length(fieldname) + 1;
    fieldlabels.Add(Copy(fieldname, 1, idx - 1));
    widths.Add(IntToStr(GetFieldWidth(FLAvailable.ItemIndex)));
    if FLAvailable.ItemIndex < fieldtypes.Count then
      ftypes.Add(fieldtypes.Strings[FLAvailable.ItemIndex])
    else
      ftypes.Add('');
    fieldname := FComboDataset.Text + '.' + Copy(fieldname, 1, idx - 1);
  end;

  FLSelected.Items.Add(fieldname);
  if FLAvailable.ItemIndex < FLAvailable.Items.Count - 1 then
    FLAvailable.ItemIndex := FLAvailable.ItemIndex + 1;
end;

function TFRpSelectFieldsLCL.GetFieldWidth(index: Integer): Integer;
begin
  Result := 10;
  if (index >= 0) and (index < fieldsizes.Count) and (Length(fieldsizes[index]) > 0) then
    Result := StrToIntDef(fieldsizes[index], 10);
end;

procedure TFRpSelectFieldsLCL.BDeleteDataClick(Sender: TObject);
begin
  if FLSelected.ItemIndex < 0 then Exit;

  fieldlabels.Delete(FLSelected.ItemIndex);
  widths.Delete(FLSelected.ItemIndex);
  ftypes.Delete(FLSelected.ItemIndex);
  FLSelected.Items.Delete(FLSelected.ItemIndex);
end;

end.

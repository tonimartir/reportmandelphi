{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfextseclcl                                  }
{       External section properties form for LCL        }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfextseclcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Dialogs, DB, Variants,
  rpmdconsts, rpdatainfo, rpreport, rpsection, rptypes, rpgraphutilslcl,
  rpmdundocuelcl;

type
  { TFRpExtSectionLCL }

  TFRpExtSectionLCL = class(TForm)
  private
    FReport: TRpReport;
    FSection: TRpSection;
    FDoOk: Boolean;

    LConnection: TLabel;
    ComboConnections: TComboBox;
    LTable: TLabel;
    ComboTable: TComboBox;
    LReportField: TLabel;
    ComboReportField: TComboBox;
    LSearchField: TLabel;
    ComboSearchField: TComboBox;
    LSearchValue: TLabel;
    ComboSearchValue: TComboBox;
    LPreferedFormat: TLabel;
    ComboFormat: TComboBox;

    PBottom: TPanel;
    BOk: TButton;
    BCancel: TButton;

    procedure BuildControls;
    procedure LayoutControls;
    procedure BOkClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure ComboTableDropDown(Sender: TObject);
    procedure ComboReportFieldDropDown(Sender: TObject);
    procedure ComboSearchValueDropDown(Sender: TObject);
    procedure UpdateCombos;
    function ValidateRecord: Boolean;
  public
    constructor Create(AOwner: TComponent); override;

    property Report: TRpReport read FReport write FReport;
    property Section: TRpSection read FSection write FSection;
    property DoOk: Boolean read FDoOk write FDoOk;
  end;

function ChangeExternalSectionProps(report: TRpReport; section: TRpSection): Boolean;

implementation

uses
  Math, rplcllayout;

const
  EXTSECTION_PROPS: array[0..6] of string = ('ExternalFilename',
    'ExternalConnection', 'ExternalTable', 'ExternalField',
    'ExternalSearchField', 'ExternalSearchValue', 'StreamFormat');

function ChangeExternalSectionProps(report: TRpReport; section: TRpSection): Boolean;
var
  dia: TFRpExtSectionLCL;
  oldValues: array[0..High(EXTSECTION_PROPS)] of Variant;
  newValue: Variant;
  i: Integer;
  loaded: Boolean;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  Result := False;
  if not Assigned(section) then Exit;
  if (not Assigned(report)) and (section.Report is TRpReport) then
    report := TRpReport(section.Report);

  dia := TFRpExtSectionLCL.Create(Application);
  try
    dia.Report := report;
    dia.Section := section;
    dia.UpdateCombos;
    dia.ShowModal;
    if dia.DoOk then
    begin
      if Assigned(report) then
        report.AssertCanModify('External section');
      for i := 0 to High(EXTSECTION_PROPS) do
        oldValues[i] := section.GetItemProperty(EXTSECTION_PROPS[i]);

      section.ExternalConnection := Trim(dia.ComboConnections.Text);
      section.ExternalTable := Trim(dia.ComboTable.Text);
      section.ExternalField := Trim(dia.ComboReportField.Text);
      section.ExternalSearchField := Trim(dia.ComboSearchField.Text);
      section.ExternalSearchValue := Trim(dia.ComboSearchValue.Text);
      if dia.ComboFormat.ItemIndex >= 0 then
        section.StreamFormat := TRpStreamFormat(dia.ComboFormat.ItemIndex);

      loaded := False;
      if Length(section.GetExternalDataDescription) > 0 then
      begin
        section.ExternalFilename := '';
        loaded := dia.ValidateRecord;
      end;

      if Assigned(report) then
      begin
        if not Assigned(report.UndoCue) then
          report.UndoCue := TUndoCue.Create(report);
        cue := TUndoCue(report.UndoCue);
        if loaded then
        begin
          // The section contents were replaced from the database: the
          // history may reference components that no longer exist
          cue.Clear;
          cue.MarkExternalChange;
        end
        else
        begin
          op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
          op.componentName := section.Name;
          op.componentClass := 'TRPSECTION';
          for i := 0 to High(EXTSECTION_PROPS) do
          begin
            newValue := section.GetItemProperty(EXTSECTION_PROPS[i]);
            if VarToStr(oldValues[i]) <> VarToStr(newValue) then
            begin
              if EXTSECTION_PROPS[i] = 'StreamFormat' then
                op.AddProperty(EXTSECTION_PROPS[i], ptInteger, oldValues[i], newValue)
              else
                op.AddProperty(EXTSECTION_PROPS[i], ptString, oldValues[i], newValue);
            end;
          end;
          if op.properties.Count > 0 then
            cue.AddOperation(op)
          else
            op.Free;
        end;
      end;
      Result := True;
    end;
  finally
    dia.Free;
  end;
end;

{ TFRpExtSectionLCL }

constructor TFRpExtSectionLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := TranslateStr(860, 'External Section Properties');
  Width := 420;
  Height := 340;
  Position := poScreenCenter;
  BorderStyle := bsDialog;

  FDoOk := False;

  BuildControls;
end;

procedure TFRpExtSectionLCL.BuildControls;
begin
  // Bottom Panel
  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := 48;
  PBottom.BevelOuter := bvNone;

  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.Caption := TranslateStr(94, 'Cancel');
  BCancel.Left := PBottom.Width - 90;
  BCancel.Top := 10;
  BCancel.Width := 80;
  BCancel.Height := 28;
  BCancel.Anchors := [akTop, akRight];
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;

  BOk := TButton.Create(Self);
  BOk.Parent := PBottom;
  BOk.Caption := TranslateStr(93, 'OK');
  BOk.Left := PBottom.Width - 180;
  BOk.Top := 10;
  BOk.Width := 80;
  BOk.Height := 28;
  BOk.Anchors := [akTop, akRight];
  BOk.Default := True;
  BOk.OnClick := BOkClick;

  // Connection
  LConnection := TLabel.Create(Self);
  LConnection.Parent := Self;
  LConnection.Caption := TranslateStr(154, 'Connection:');
  LConnection.Left := 20;
  LConnection.Top := 16;

  ComboConnections := TComboBox.Create(Self);
  ComboConnections.Parent := Self;
  ComboConnections.Style := csDropDownList;
  ComboConnections.Left := 160;
  ComboConnections.Top := 12;
  ComboConnections.Width := 230;

  // Table
  LTable := TLabel.Create(Self);
  LTable.Parent := Self;
  LTable.Caption := TranslateStr(862, 'Table:');
  LTable.Left := 20;
  LTable.Top := 50;

  ComboTable := TComboBox.Create(Self);
  ComboTable.Parent := Self;
  ComboTable.Left := 160;
  ComboTable.Top := 46;
  ComboTable.Width := 230;
  ComboTable.OnDropDown := ComboTableDropDown;

  // Report Field
  LReportField := TLabel.Create(Self);
  LReportField.Parent := Self;
  LReportField.Caption := TranslateStr(863, 'Report Field:');
  LReportField.Left := 20;
  LReportField.Top := 84;

  ComboReportField := TComboBox.Create(Self);
  ComboReportField.Parent := Self;
  ComboReportField.Left := 160;
  ComboReportField.Top := 80;
  ComboReportField.Width := 230;
  ComboReportField.OnDropDown := ComboReportFieldDropDown;

  // Search Field
  LSearchField := TLabel.Create(Self);
  LSearchField.Parent := Self;
  LSearchField.Caption := TranslateStr(864, 'Search Field:');
  LSearchField.Left := 20;
  LSearchField.Top := 118;

  ComboSearchField := TComboBox.Create(Self);
  ComboSearchField.Parent := Self;
  ComboSearchField.Left := 160;
  ComboSearchField.Top := 114;
  ComboSearchField.Width := 230;
  ComboSearchField.OnDropDown := ComboReportFieldDropDown;

  // Search Value
  LSearchValue := TLabel.Create(Self);
  LSearchValue.Parent := Self;
  LSearchValue.Caption := TranslateStr(865, 'Search Value:');
  LSearchValue.Left := 20;
  LSearchValue.Top := 152;

  ComboSearchValue := TComboBox.Create(Self);
  ComboSearchValue.Parent := Self;
  ComboSearchValue.Left := 160;
  ComboSearchValue.Top := 148;
  ComboSearchValue.Width := 230;
  ComboSearchValue.OnDropDown := ComboSearchValueDropDown;

  // Format
  LPreferedFormat := TLabel.Create(Self);
  LPreferedFormat.Parent := Self;
  LPreferedFormat.Caption := SRpPreferedFormat;
  LPreferedFormat.Left := 20;
  LPreferedFormat.Top := 186;

  ComboFormat := TComboBox.Create(Self);
  ComboFormat.Parent := Self;
  ComboFormat.Style := csDropDownList;
  ComboFormat.Left := 160;
  ComboFormat.Top := 182;
  ComboFormat.Width := 230;
  ComboFormat.Items.Add(SRpStreamZLib);
  ComboFormat.Items.Add(SRpStreamText);
  ComboFormat.Items.Add(SRpStreamBinary);
  ComboFormat.Items.Add(SRpStreamXML);
  ComboFormat.Items.Add(SRpStreamXMLComp);

  LayoutControls;
end;

// A label and its combo box in each row, anchored one below the other: the
// fixed label column cut the longer labels (GTK2) and the fixed rows did not
// follow the heights of the combo boxes
procedure TFRpExtSectionLCL.LayoutControls;
var
  M, S, lw, i: Integer;
  LLabels: array[0..5] of TLabel;
  LCombos: array[0..5] of TComboBox;
begin
  M := Scale96ToScreen(12);
  S := Scale96ToScreen(8);
  LLabels[0] := LConnection;
  LLabels[1] := LTable;
  LLabels[2] := LReportField;
  LLabels[3] := LSearchField;
  LLabels[4] := LSearchValue;
  LLabels[5] := LPreferedFormat;
  LCombos[0] := ComboConnections;
  LCombos[1] := ComboTable;
  LCombos[2] := ComboReportField;
  LCombos[3] := ComboSearchField;
  LCombos[4] := ComboSearchValue;
  LCombos[5] := ComboFormat;
  lw := 0;
  for i := 0 to High(LLabels) do
    lw := Max(lw, RpMaxTextWidth(Font, [LLabels[i].Caption]));
  Inc(lw, Scale96ToScreen(8));
  for i := 0 to High(LCombos) do
  begin
    if i = 0 then
      RpPlaceAt(LCombos[i], M + lw, nil, M)
    else
      RpPlaceAt(LCombos[i], M + lw, LCombos[i - 1], S);
    RpToParentRight(LCombos[i], M);
    RpLabelFor(LLabels[i], M, LCombos[i]);
  end;
end;

procedure TFRpExtSectionLCL.UpdateCombos;
var
  i: Integer;
begin
  ComboConnections.Items.Clear;
  if Assigned(FReport) then
  begin
    for i := 0 to FReport.DatabaseInfo.Count - 1 do
      ComboConnections.Items.Add(FReport.DatabaseInfo.Items[i].Alias);
  end;

  if Assigned(FSection) then
  begin
    ComboConnections.Text := FSection.ExternalConnection;
    ComboTable.Text := FSection.ExternalTable;
    ComboReportField.Text := FSection.ExternalField;
    ComboSearchField.Text := FSection.ExternalSearchField;
    ComboSearchValue.Text := FSection.ExternalSearchValue;
    ComboFormat.ItemIndex := Integer(FSection.StreamFormat);
  end;
end;

procedure TFRpExtSectionLCL.ComboTableDropDown(Sender: TObject);
var
  idx: Integer;
begin
  ComboTable.Items.Clear;
  ComboTable.Items.Add(' ');
  if not Assigned(FReport) then Exit;

  idx := FReport.DatabaseInfo.IndexOf(ComboConnections.Text);
  if idx >= 0 then
  begin
    FReport.DatabaseInfo.Items[idx].GetTableNames(ComboTable.Items, FReport.Params);
    if ComboTable.Items.Count < 1 then
      ComboTable.Items.Add(' ');
  end;
end;

procedure TFRpExtSectionLCL.ComboReportFieldDropDown(Sender: TObject);
var
  idx: Integer;
  sql: string;
  adata: TDataSet;
begin
  TComboBox(Sender).Items.Clear;
  TComboBox(Sender).Items.Add(' ');
  if not Assigned(FReport) then Exit;

  idx := FReport.DatabaseInfo.IndexOf(ComboConnections.Text);
  if (idx < 0) or (Length(Trim(ComboTable.Text)) < 1) then Exit;

  sql := 'SELECT * FROM ' + ComboTable.Text;
  // SQL errors are raised and shown, like rpmdfextsecvcl
  adata := FReport.DatabaseInfo.Items[idx].OpenDatasetFromSQL(sql, nil, False, FReport.Params);
  try
    adata.GetFieldNames(TComboBox(Sender).Items);
  finally
    adata.Free;
  end;

  if TComboBox(Sender).Items.Count < 1 then
    TComboBox(Sender).Items.Add(' ');
end;

procedure TFRpExtSectionLCL.ComboSearchValueDropDown(Sender: TObject);
var
  idx: Integer;
  sql: string;
  adata: TDataSet;
begin
  TComboBox(Sender).Items.Clear;
  TComboBox(Sender).Items.Add(' ');
  if not Assigned(FReport) then Exit;

  idx := FReport.DatabaseInfo.IndexOf(ComboConnections.Text);
  if (idx < 0) or (Length(Trim(ComboTable.Text)) < 1) or
     (Length(Trim(ComboSearchField.Text)) < 1) then Exit;

  sql := 'SELECT ' + ComboSearchField.Text + ' FROM ' + ComboTable.Text +
         ' ORDER BY ' + ComboSearchField.Text;
  // SQL errors are raised and shown, like rpmdfextsecvcl
  adata := FReport.DatabaseInfo.Items[idx].OpenDatasetFromSQL(sql, nil, False, FReport.Params);
  try
    TComboBox(Sender).Items.Clear;
    while not adata.Eof do
    begin
      TComboBox(Sender).Items.Add(adata.Fields[0].AsString);
      adata.Next;
    end;
  finally
    adata.Free;
  end;

  if TComboBox(Sender).Items.Count < 1 then
    TComboBox(Sender).Items.Add(' ');
end;

function TFRpExtSectionLCL.ValidateRecord: Boolean;
var
  idx: Integer;
  sql: string;
  adata: TDataSet;
  aparam: TRpParamObject;
  alist: TStringList;
begin
  // Returns True when the section was loaded from the external database
  Result := False;
  if not Assigned(FReport) or not Assigned(FSection) then Exit;

  idx := FReport.DatabaseInfo.IndexOf(ComboConnections.Text);
  if (idx < 0) or (Length(Trim(ComboTable.Text)) < 1) or
     (Length(Trim(ComboSearchField.Text)) < 1) then Exit;

  sql := 'SELECT ' + ComboSearchField.Text + ' FROM ' + ComboTable.Text +
         ' WHERE ' + ComboSearchField.Text + '=:' + ComboSearchField.Text;
  alist := TStringList.Create;
  try
    aparam := TRpParamObject.Create;
    try
      aparam.Value := ComboSearchValue.Text;
      alist.AddObject(ComboSearchField.Text, aparam);
      adata := FReport.DatabaseInfo.Items[idx].OpenDatasetFromSQL(sql, alist, False, FReport.Params);
      try
        if adata.Eof then
        begin
          // Ask if create record
          if RpMessageBox(SRpRecordnotExists, SRpWarning,
             [smbYes, smbNo], smsWarning, smbYes, smbNo) = smbYes then
          begin
            sql := 'INSERT INTO ' + ComboTable.Text + '(' +
                   ComboSearchField.Text + ') VALUES (:' +
                   ComboSearchField.Text + ')';
            FReport.DatabaseInfo.Items[idx].OpenDatasetFromSQL(sql, alist, True, FReport.Params);
            FSection.SaveExternal;
          end;
        end
        else
        begin
          if RpMessageBox(SRpLoadSection, SRpWarning,
             [smbYes, smbNo], smsWarning, smbYes, smbNo) = smbYes then
          begin
            FSection.LoadExternal;
            Result := True;
          end;
        end;
      finally
        adata.Free;
      end;
    finally
      aparam.Free;
    end;
  finally
    alist.Free;
  end;
end;

procedure TFRpExtSectionLCL.BOkClick(Sender: TObject);
begin
  FDoOk := True;
  ModalResult := mrOk;
  Close;
end;

procedure TFRpExtSectionLCL.BCancelClick(Sender: TObject);
begin
  FDoOk := False;
  ModalResult := mrCancel;
  Close;
end;

end.

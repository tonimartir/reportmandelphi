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
  Buttons, ExtCtrls, Dialogs, DB,
  rpmdconsts, rpdatainfo, rpreport, rpsection, rptypes;

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
    procedure BOkClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure ComboTableDropDown(Sender: TObject);
    procedure ComboReportFieldDropDown(Sender: TObject);
    procedure ComboSearchValueDropDown(Sender: TObject);
    procedure UpdateCombos;
    procedure ValidateRecord;
  public
    constructor Create(AOwner: TComponent); override;

    property Report: TRpReport read FReport write FReport;
    property Section: TRpSection read FSection write FSection;
    property DoOk: Boolean read FDoOk write FDoOk;
  end;

function ChangeExternalSectionProps(report: TRpReport; section: TRpSection): Boolean;

implementation

function ChangeExternalSectionProps(report: TRpReport; section: TRpSection): Boolean;
var
  dia: TFRpExtSectionLCL;
begin
  Result := False;
  if not Assigned(section) then Exit;

  dia := TFRpExtSectionLCL.Create(Application);
  try
    dia.Report := report;
    dia.Section := section;
    dia.UpdateCombos;
    dia.ShowModal;
    if dia.DoOk then
    begin
      section.ExternalConnection := Trim(dia.ComboConnections.Text);
      section.ExternalTable := Trim(dia.ComboTable.Text);
      section.ExternalField := Trim(dia.ComboReportField.Text);
      section.ExternalSearchField := Trim(dia.ComboSearchField.Text);
      section.ExternalSearchValue := Trim(dia.ComboSearchValue.Text);
      if dia.ComboFormat.ItemIndex >= 0 then
        section.StreamFormat := TRpStreamFormat(dia.ComboFormat.ItemIndex);

      if Length(section.GetExternalDataDescription) > 0 then
      begin
        section.ExternalFilename := '';
        dia.ValidateRecord;
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
  try
    adata := FReport.DatabaseInfo.Items[idx].OpenDatasetFromSQL(sql, nil, False, FReport.Params);
    if Assigned(adata) then
    begin
      try
        adata.GetFieldNames(TComboBox(Sender).Items);
      finally
        adata.Free;
      end;
    end;
  except
    // ignore query errors on metadata lookup
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
  try
    adata := FReport.DatabaseInfo.Items[idx].OpenDatasetFromSQL(sql, nil, False, FReport.Params);
    if Assigned(adata) then
    begin
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
    end;
  except
    // ignore query errors on metadata lookup
  end;

  if TComboBox(Sender).Items.Count < 1 then
    TComboBox(Sender).Items.Add(' ');
end;

procedure TFRpExtSectionLCL.ValidateRecord;
var
  idx: Integer;
  sql: string;
  adata: TDataSet;
  aparam: TRpParamObject;
  alist: TStringList;
begin
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
      if Assigned(adata) then
      begin
        try
          if adata.Eof then
          begin
            if MessageDlg(TranslateStr(268, 'Record does not exist. Create new record?'),
               mtConfirmation, [mbYes, mbNo], 0) = mrYes then
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
            if MessageDlg(TranslateStr(269, 'Load section from external database?'),
               mtConfirmation, [mbYes, mbNo], 0) = mrYes then
              FSection.LoadExternal;
          end;
        finally
          adata.Free;
        end;
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

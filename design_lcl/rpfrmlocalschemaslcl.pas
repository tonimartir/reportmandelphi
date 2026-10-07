{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmlocalschemaslcl                            }
{                                                       }
{       The local schema of a direct connection for     }
{       the AI: refresh it from the database and        }
{       define its subschemas                           }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmlocalschemaslcl;

{$mode delphi}

{ The utility of the AI chat for the schema file of a direct connection
  (rplocalschemas, dbxschemas/<ALIAS>.json): the tables come from the
  catalog ("Refresh from the database" reads it again and keeps what was
  written for what still exists); a subschema is a name and a selection of
  tables, and the chat sends only those to the AI. Built in code, no form
  file; rpfrmlocalschemasvcl is the VCL twin. Nothing is saved until
  Save. }

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, CheckLst,
  Dialogs, rpjsonfpc, rpreport, rpdatainfo, rplocalschemas;

// The local schema of the connection AAlias of the report. ASchemaName is
// the subschema to show and, after a Save, the one selected. True when the
// file was saved
function RpShowLocalSchemasDialog(AReport: TRpReport; const AAlias: string;
  var ASchemaName: string): Boolean;

implementation

type
  TFRpLocalSchemasLCL = class(TForm)
  private
    FDatabase: TRpDatabaseInfoItem;
    FDatabases: TRpDatabaseInfoList;
    FFile: TRpLocalSchemaFile;
    FFileName: string;
    FReport: TRpReport;
    FUpdating: Boolean;
    LInfo: TLabel;
    BRefresh: TButton;
    ListSchemas: TListBox;
    BAdd: TButton;
    BRename: TButton;
    BDelete: TButton;
    EDescription: TEdit;
    CheckTables: TCheckListBox;
    BAll: TButton;
    BNone: TButton;
    BSave: TButton;
    BCancel: TButton;
    function S(AValue: Integer): Integer;
    procedure BuildControls;
    procedure BottomResize(Sender: TObject);
    procedure LoadFile(ARefresh: Boolean);
    procedure ShowInfo;
    procedure FillSchemas(const ASelected: string);
    procedure FillTables;
    function SelectedSchema: TRpLocalSubSchema;
    procedure BRefreshClick(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BRenameClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BAllClick(Sender: TObject);
    procedure BSaveClick(Sender: TObject);
    procedure ListSchemasClick(Sender: TObject);
    procedure CheckTablesClickCheck(Sender: TObject);
    procedure EDescriptionChange(Sender: TObject);
  public
    constructor CreateFor(AOwner: TComponent; AReport: TRpReport;
      const AAlias: string);
    destructor Destroy; override;
  end;

function TFRpLocalSchemasLCL.S(AValue: Integer): Integer;
begin
  Result := (AValue * Screen.PixelsPerInch) div 96;
end;

constructor TFRpLocalSchemasLCL.CreateFor(AOwner: TComponent;
  AReport: TRpReport; const AAlias: string);
var
  LIndex: Integer;
begin
  inherited CreateNew(AOwner);
  FReport := AReport;
  FFile := TRpLocalSchemaFile.Create;
  LIndex := AReport.DatabaseInfo.IndexOf(AAlias);
  if LIndex < 0 then
    raise Exception.Create('The report has no connection ' + AAlias);
  // A copy: the designer may be opening the datasets of the report
  FDatabases := RpCopyDatabaseInfo(AReport.DatabaseInfo.Items[LIndex]);
  FDatabase := FDatabases.Items[0];
  FFileName := RpLocalSchemaFileName(FDatabase);
  Caption := 'Local schema of ' + FDatabase.Alias;
  Position := poScreenCenter;
  BorderIcons := [biSystemMenu];
  Width := S(720);
  Height := S(520);
  BuildControls;
end;

destructor TFRpLocalSchemasLCL.Destroy;
begin
  FFile.Free;
  FDatabases.Free;
  inherited Destroy;
end;

procedure TFRpLocalSchemasLCL.BuildControls;
var
  LPanel, LLeft, LRight, LButtons, LBottom: TPanel;
  LLabel: TLabel;

  function NewButton(AParent: TWinControl; const ACaption: string;
    AOnClick: TNotifyEvent; AWidth: Integer): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.OnClick := AOnClick;
    Result.Width := S(AWidth);
    Result.Height := S(26);
  end;

begin
  LPanel := TPanel.Create(Self);
  LPanel.Parent := Self;
  LPanel.Align := alTop;
  LPanel.BevelOuter := bvNone;
  LPanel.Height := S(84);
  LInfo := TLabel.Create(Self);
  LInfo.Parent := LPanel;
  LInfo.Left := S(8);
  LInfo.Top := S(8);
  LInfo.AutoSize := True;
  BRefresh := NewButton(LPanel, 'Refresh from the database', BRefreshClick, 190);
  BRefresh.Left := S(8);
  BRefresh.Top := S(50);

  LBottom := TPanel.Create(Self);
  LBottom.Parent := Self;
  LBottom.Align := alBottom;
  LBottom.BevelOuter := bvNone;
  LBottom.Height := S(40);
  LBottom.OnResize := BottomResize;
  BCancel := NewButton(LBottom, 'Cancel', nil, 90);
  BCancel.Top := S(7);
  BCancel.ModalResult := mrCancel;
  BCancel.Cancel := True;
  BSave := NewButton(LBottom, 'Save', BSaveClick, 90);
  BSave.Top := S(7);
  BSave.Default := True;
  BottomResize(LBottom);

  LLeft := TPanel.Create(Self);
  LLeft.Parent := Self;
  LLeft.Align := alLeft;
  LLeft.BevelOuter := bvNone;
  LLeft.Width := S(240);
  LLeft.BorderWidth := S(6);
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LLeft;
  LLabel.Align := alTop;
  LLabel.Caption := 'Subschemas';
  LLabel.WordWrap := True;
  LButtons := TPanel.Create(Self);
  LButtons.Parent := LLeft;
  LButtons.Align := alBottom;
  LButtons.BevelOuter := bvNone;
  LButtons.Height := S(34);
  BAdd := NewButton(LButtons, 'Add...', BAddClick, 72);
  BAdd.Left := 0;
  BAdd.Top := S(6);
  BRename := NewButton(LButtons, 'Rename...', BRenameClick, 76);
  BRename.Left := S(76);
  BRename.Top := S(6);
  BDelete := NewButton(LButtons, 'Delete', BDeleteClick, 72);
  BDelete.Left := S(156);
  BDelete.Top := S(6);
  ListSchemas := TListBox.Create(Self);
  ListSchemas.Parent := LLeft;
  ListSchemas.Align := alClient;
  ListSchemas.OnClick := ListSchemasClick;

  LRight := TPanel.Create(Self);
  LRight.Parent := Self;
  LRight.Align := alClient;
  LRight.BevelOuter := bvNone;
  LRight.BorderWidth := S(6);
  // alTop in this order: each one below the previous one
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LRight;
  LLabel.Top := 0;
  LLabel.Align := alTop;
  LLabel.Caption := 'Description';
  EDescription := TEdit.Create(Self);
  EDescription.Parent := LRight;
  EDescription.Top := S(100);
  EDescription.Align := alTop;
  EDescription.OnChange := EDescriptionChange;
  LLabel := TLabel.Create(Self);
  LLabel.Parent := LRight;
  LLabel.Top := S(200);
  LLabel.Align := alTop;
  LLabel.Caption := 'Tables of the subschema (the chat sends only these)';
  LButtons := TPanel.Create(Self);
  LButtons.Parent := LRight;
  LButtons.Align := alBottom;
  LButtons.BevelOuter := bvNone;
  LButtons.Height := S(34);
  BAll := NewButton(LButtons, 'Check all', BAllClick, 90);
  BAll.Left := 0;
  BAll.Top := S(6);
  BNone := NewButton(LButtons, 'Uncheck all', BAllClick, 90);
  BNone.Left := S(96);
  BNone.Top := S(6);
  CheckTables := TCheckListBox.Create(Self);
  CheckTables.Parent := LRight;
  CheckTables.Align := alClient;
  CheckTables.OnClickCheck := CheckTablesClickCheck;
end;

procedure TFRpLocalSchemasLCL.LoadFile(ARefresh: Boolean);
var
  LCursor: TCursor;
  LDialect: string;
  LLoaded: TRpLocalSchemaFile;
  LTables: TJSONArray;
begin
  LCursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    try
      if ARefresh then
      begin
        // In memory, with the subschemas being edited: Save writes it
        LTables := RpReadLocalSchemaCatalog(FDatabase, FReport.Params, LDialect);
        FFile.SetCatalog(LTables, LDialect);
        if FFile.Alias = '' then
          FFile.Alias := UpperCase(FDatabase.Alias);
      end
      else
      begin
        // Generated (and saved) the first time
        LLoaded := RpLoadLocalSchema(FDatabase, FReport.Params, True, False);
        FFile.Free;
        FFile := LLoaded;
      end;
    finally
      FDatabase.DisConnect;
    end;
  finally
    Screen.Cursor := LCursor;
  end;
  ShowInfo;
end;

procedure TFRpLocalSchemasLCL.BottomResize(Sender: TObject);
var
  LWidth: Integer;
begin
  if (BCancel = nil) or (BSave = nil) then
    Exit;
  LWidth := TControl(Sender).Width;
  BCancel.Left := LWidth - BCancel.Width - S(8);
  BSave.Left := BCancel.Left - BSave.Width - S(8);
end;

procedure TFRpLocalSchemasLCL.ShowInfo;
var
  LText: string;
begin
  LText := FDatabase.Alias + ' - ' + IntToStr(FFile.TableCount) + ' tables';
  if FFile.Dialect <> '' then
    LText := LText + ' - ' + FFile.Dialect;
  if FFile.GeneratedUtc <> '' then
    LText := LText + ' - read from the database ' + FFile.GeneratedUtc;
  LInfo.Caption := LText + sLineBreak + FFileName;
end;

function TFRpLocalSchemasLCL.SelectedSchema: TRpLocalSubSchema;
begin
  Result := nil;
  if (ListSchemas.ItemIndex >= 0) and (ListSchemas.ItemIndex < FFile.SchemaCount) then
    Result := FFile.Schemas[ListSchemas.ItemIndex];
end;

procedure TFRpLocalSchemasLCL.FillSchemas(const ASelected: string);
var
  I: Integer;
begin
  ListSchemas.Items.BeginUpdate;
  try
    ListSchemas.Items.Clear;
    for I := 0 to FFile.SchemaCount - 1 do
      ListSchemas.Items.Add(FFile.Schemas[I].Name);
  finally
    ListSchemas.Items.EndUpdate;
  end;
  ListSchemas.ItemIndex := FFile.IndexOfSchema(ASelected);
  if (ListSchemas.ItemIndex < 0) and (ListSchemas.Items.Count > 0) then
    ListSchemas.ItemIndex := 0;
  FillTables;
end;

procedure TFRpLocalSchemasLCL.FillTables;
var
  I: Integer;
  LSchema: TRpLocalSubSchema;
  LNames: TStringList;
begin
  FUpdating := True;
  LNames := TStringList.Create;
  try
    LSchema := SelectedSchema;
    FFile.GetTableNames(LNames);
    CheckTables.Items.BeginUpdate;
    try
      CheckTables.Items.Assign(LNames);
      for I := 0 to CheckTables.Items.Count - 1 do
        CheckTables.Checked[I] := (LSchema <> nil) and
          (LSchema.Tables.IndexOf(CheckTables.Items[I]) >= 0);
    finally
      CheckTables.Items.EndUpdate;
    end;
    CheckTables.Enabled := LSchema <> nil;
    EDescription.Enabled := LSchema <> nil;
    BAll.Enabled := LSchema <> nil;
    BNone.Enabled := LSchema <> nil;
    BRename.Enabled := LSchema <> nil;
    BDelete.Enabled := LSchema <> nil;
    if LSchema <> nil then
      EDescription.Text := LSchema.Description
    else
      EDescription.Text := '';
  finally
    LNames.Free;
    FUpdating := False;
  end;
end;

procedure TFRpLocalSchemasLCL.ListSchemasClick(Sender: TObject);
begin
  FillTables;
end;

procedure TFRpLocalSchemasLCL.CheckTablesClickCheck(Sender: TObject);
var
  I: Integer;
  LSchema: TRpLocalSubSchema;
begin
  LSchema := SelectedSchema;
  if FUpdating or (LSchema = nil) then
    Exit;
  LSchema.Tables.Clear;
  for I := 0 to CheckTables.Items.Count - 1 do
    if CheckTables.Checked[I] then
      LSchema.Tables.Add(CheckTables.Items[I]);
end;

procedure TFRpLocalSchemasLCL.BAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to CheckTables.Items.Count - 1 do
    CheckTables.Checked[I] := Sender = BAll;
  CheckTablesClickCheck(CheckTables);
end;

procedure TFRpLocalSchemasLCL.EDescriptionChange(Sender: TObject);
begin
  if (not FUpdating) and (SelectedSchema <> nil) then
    SelectedSchema.Description := EDescription.Text;
end;

procedure TFRpLocalSchemasLCL.BAddClick(Sender: TObject);
var
  LName: string;
begin
  LName := '';
  if not InputQuery('New subschema', 'Name', LName) then
    Exit;
  LName := Trim(LName);
  if LName = '' then
    Exit;
  FFile.AddSchema(LName);
  FillSchemas(LName);
end;

procedure TFRpLocalSchemasLCL.BRenameClick(Sender: TObject);
var
  LName: string;
  LSchema: TRpLocalSubSchema;
begin
  LSchema := SelectedSchema;
  if LSchema = nil then
    Exit;
  LName := LSchema.Name;
  if not InputQuery('Rename subschema', 'Name', LName) then
    Exit;
  LName := Trim(LName);
  if (LName = '') or (LName = LSchema.Name) then
    Exit;
  if (FFile.IndexOfSchema(LName) >= 0) and
    (FFile.IndexOfSchema(LName) <> ListSchemas.ItemIndex) then
    raise Exception.Create('The subschema already exists: ' + LName);
  LSchema.Name := LName;
  FillSchemas(LName);
end;

procedure TFRpLocalSchemasLCL.BDeleteClick(Sender: TObject);
begin
  if SelectedSchema = nil then
    Exit;
  if MessageDlg('Delete the subschema ' + SelectedSchema.Name + '?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FFile.DeleteSchema(ListSchemas.ItemIndex);
  FillSchemas('');
end;

procedure TFRpLocalSchemasLCL.BRefreshClick(Sender: TObject);
var
  LSelected: string;
begin
  LSelected := '';
  if SelectedSchema <> nil then
    LSelected := SelectedSchema.Name;
  LoadFile(True);
  FillSchemas(LSelected);
end;

procedure TFRpLocalSchemasLCL.BSaveClick(Sender: TObject);
begin
  if FFile.Alias = '' then
    FFile.Alias := UpperCase(FDatabase.Alias);
  FFile.SaveToFile(FFileName);
  ModalResult := mrOk;
end;

function RpShowLocalSchemasDialog(AReport: TRpReport; const AAlias: string;
  var ASchemaName: string): Boolean;
var
  LForm: TFRpLocalSchemasLCL;
begin
  Result := False;
  LForm := TFRpLocalSchemasLCL.CreateFor(Application, AReport, AAlias);
  try
    LForm.LoadFile(False);
    LForm.FillSchemas(ASchemaName);
    if LForm.ShowModal = mrOk then
    begin
      Result := True;
      if LForm.SelectedSchema <> nil then
        ASchemaName := LForm.SelectedSchema.Name
      else
        ASchemaName := '';
    end;
  finally
    LForm.Free;
  end;
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpeditconnlcl                                   }
{       Report library connections editor               }
{                                                       }
{       Port of rpeditconnvcl (TFRpEditConVCL)          }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpeditconnlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  Dialogs, Math,
  rpmdconsts, rpdatainfo, rpgraphutilslcl, rpmdimageslcl, rpmdftreelcl,
  rpmdfopenliblcl;

type
  { TFRpEditConLCL }

  // Edits a working copy of the library connections (Connections): new,
  // delete and rename, driver, parameters and library tables of each one,
  // connection test, creation of the library tables and the library tree.
  // The methods without questions (NewConnection, DeleteConnection,
  // RenameConnection, TestConnection, CreateLibrary) are what the toolbar
  // and the buttons do after asking the user.
  TFRpEditConLCL = class(TForm)
  private
    FConnections: TRpDatabaseInfoList;
    FUpdating: Boolean;

    procedure BuildControls;
    procedure UpdateConList;
    function SelectedItem: TRpDatabaseInfoItem;
    procedure ANewConnExecute(Sender: TObject);
    procedure ADeleteExecute(Sender: TObject);
    procedure ARenameExecute(Sender: TObject);
    procedure BConfigClick(Sender: TObject);
    procedure BTestClick(Sender: TObject);
    procedure BCreateLibClick(Sender: TObject);
    procedure BBrowseClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure LConnectionsSelectionChange(Sender: TObject; User: Boolean);
  public
    ImageList1: TImageList;
    ToolBar1: TToolBar;
    BNewConn: TToolButton;
    BDeleteConn: TToolButton;
    BRenameConn: TToolButton;
    PBottom: TPanel;
    BOK: TButton;
    BCancel: TButton;
    PConnections: TPanel;
    LConnections: TListBox;
    Splitter2: TSplitter;
    PCon2: TScrollBox;
    CheckLoadParams: TCheckBox;
    CheckLoadDriverParams: TCheckBox;
    CheckLoginPrompt: TCheckBox;
    LDriver: TLabel;
    ComboDriver: TComboBox;
    LReportTable: TLabel;
    EReportTable: TEdit;
    LReportField: TLabel;
    EReportField: TEdit;
    LRSearchField: TLabel;
    EReportSearchField: TEdit;
    LGroupsTable: TLabel;
    EReportGroupsTable: TEdit;
    LAdoConnection: TLabel;
    EAdoConnection: TEdit;
    BConfig: TButton;
    BCreateLib: TButton;
    BTest: TButton;
    BBrowse: TButton;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Copies the connections to edit (the working copy)
    procedure LoadConnections(AConnections: TRpDatabaseInfoList);
    // Shows the selected connection in the editors (VCL LAliasesClick)
    procedure LAliasesClick(Sender: TObject);
    // An editor changed: stores it in the selected connection
    // (VCL EReportTableChange)
    procedure EReportTableChange(Sender: TObject);

    procedure NewConnection(const AName: string);
    procedure DeleteConnection;
    procedure RenameConnection(const ANewName: string);
    // Connects and disconnects the selected connection (raises on error)
    procedure TestConnection;
    // Creates the library tables in the selected connection
    procedure CreateLibrary;
    procedure SelectConnection(const AAlias: string);

    // The working copy
    property Connections: TRpDatabaseInfoList read FConnections;
  end;

// Edits the library connections; True when accepted (Connections changed)
function ShowModifyConnections(Connections: TRpDatabaseInfoList): Boolean;

implementation

function ShowModifyConnections(Connections: TRpDatabaseInfoList): Boolean;
var
  dia: TFRpEditConLCL;
begin
  Result := False;
  dia := TFRpEditConLCL.Create(Application);
  try
    dia.LoadConnections(Connections);
    if dia.ShowModal = mrOk then
    begin
      Result := True;
      Connections.Assign(dia.Connections);
    end;
  finally
    dia.Free;
  end;
end;

{ TFRpEditConLCL }

constructor TFRpEditConLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := TranslateStr(1122, 'Edit connections');
  Position := poScreenCenter;
  ShowHint := True;
  // Fits a 800x600 screen; the editors scroll when it is smaller
  Width := Scale96ToScreen(640);
  Height := Scale96ToScreen(460);
  Constraints.MinWidth := Scale96ToScreen(420);
  Constraints.MinHeight := Scale96ToScreen(300);
  FConnections := TRpDatabaseInfoList.Create(nil);
  BuildControls;
  OnShow := FormShow;
end;

destructor TFRpEditConLCL.Destroy;
begin
  // Also closes the connections opened by the dialog
  FreeAndNil(FConnections);
  inherited Destroy;
end;

procedure TFRpEditConLCL.BuildControls;
var
  y, rowh, editleft: Integer;
  bw: Integer;

  function TextWidthOf(const ACaptions: array of string): Integer;
  var
    bmp: TBitmap;
    i: Integer;
  begin
    Result := 0;
    bmp := TBitmap.Create;
    try
      bmp.Canvas.Font := Font;
      for i := 0 to High(ACaptions) do
        Result := Max(Result, bmp.Canvas.TextWidth(ACaptions[i]));
    finally
      bmp.Free;
    end;
  end;

  function NewToolButton(AImage: Integer; const ACaption, AHint: string;
    ALeft: Integer; AClick: TNotifyEvent): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := ToolBar1;
    Result.Left := ALeft;
    Result.ImageIndex := AImage;
    Result.Caption := ACaption;
    Result.Hint := AHint;
    Result.OnClick := AClick;
  end;

  function NewCheck(const ACaption: string): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := PCon2;
    Result.Caption := ACaption;
    Result.SetBounds(Scale96ToScreen(10), y, Scale96ToScreen(300), Scale96ToScreen(22));
    Result.OnChange := EReportTableChange;
    Inc(y, Scale96ToScreen(24));
  end;

  function NewLabel(const ACaption: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := PCon2;
    Result.Caption := ACaption;
    Result.SetBounds(Scale96ToScreen(10), y + Scale96ToScreen(4), editleft - Scale96ToScreen(14),
      Scale96ToScreen(20));
  end;

  // Editors from the label column to the right side of the scroll box
  procedure AnchorRight(AControl: TControl);
  begin
    AControl.AnchorSideRight.Control := PCon2;
    AControl.AnchorSideRight.Side := asrRight;
    AControl.BorderSpacing.Right := Scale96ToScreen(10);
    AControl.Anchors := [akLeft, akTop, akRight];
  end;

  function NewEdit: TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := PCon2;
    Result.SetBounds(editleft, y, PCon2.ClientWidth - editleft - Scale96ToScreen(10),
      Scale96ToScreen(24));
    AnchorRight(Result);
    Result.OnChange := EReportTableChange;
    Inc(y, rowh);
  end;

  function NewButton(const ACaption: string; ALeft, AWidth: Integer;
    AClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := PCon2;
    Result.Caption := ACaption;
    Result.SetBounds(ALeft, y, AWidth, Scale96ToScreen(28));
    Result.OnClick := AClick;
  end;

begin
  ImageList1 := TImageList.Create(Self);
  ImageList1.Width := 19;
  ImageList1.Height := 19;
  // New, delete and rename icons of the data configuration dialog
  LoadDataConfigImageList(ImageList1);

  ToolBar1 := TToolBar.Create(Self);
  ToolBar1.Parent := Self;
  ToolBar1.Align := alTop;
  ToolBar1.Height := Scale96ToScreen(30);
  ToolBar1.ButtonWidth := Scale96ToScreen(26);
  ToolBar1.ButtonHeight := Scale96ToScreen(26);
  ToolBar1.Images := ImageList1;
  ToolBar1.Flat := True;
  ToolBar1.ShowHint := True;
  BNewConn := NewToolButton(IMG_DC_NEW, TranslateStr(1102, 'New connection'),
    TranslateStr(1103, 'Adds a new connection'), 100, ANewConnExecute);
  BDeleteConn := NewToolButton(IMG_DC_DELETE, TranslateStr(1104, 'Delete connection'),
    TranslateStr(1105, 'Deletes the selected connection'), 200, ADeleteExecute);
  BRenameConn := NewToolButton(IMG_DC_RENAME, TranslateStr(151, 'Rename'),
    TranslateStr(512, 'Rename the database configuration alias'), 300, ARenameExecute);

  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := Scale96ToScreen(44);
  PBottom.BevelOuter := bvNone;

  // Fixed size buttons (AutoSize buttons aligned to the sides may not fit)
  bw := Max(Scale96ToScreen(90), TextWidthOf([SRpOk, SRpCancel]) + Scale96ToScreen(24));
  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.SetBounds(10000, 0, bw, Scale96ToScreen(27));
  BCancel.BorderSpacing.Around := Scale96ToScreen(8);
  BCancel.Align := alRight;
  BCancel.Caption := SRpCancel;
  BCancel.Cancel := True;
  BCancel.ModalResult := mrCancel;

  BOK := TButton.Create(Self);
  BOK.Parent := PBottom;
  BOK.SetBounds(9000, 0, bw, Scale96ToScreen(27));
  BOK.BorderSpacing.Around := Scale96ToScreen(8);
  BOK.Align := alRight;
  BOK.Caption := SRpOk;
  BOK.Default := True;
  BOK.ModalResult := mrOk;

  PConnections := TPanel.Create(Self);
  PConnections.Parent := Self;
  PConnections.Align := alClient;
  PConnections.BevelOuter := bvNone;
  PConnections.BorderSpacing.Around := Scale96ToScreen(4);

  LConnections := TListBox.Create(Self);
  LConnections.Parent := PConnections;
  LConnections.Align := alLeft;
  LConnections.Width := Scale96ToScreen(170);
  LConnections.OnClick := LAliasesClick;
  LConnections.OnSelectionChange := LConnectionsSelectionChange;

  Splitter2 := TSplitter.Create(Self);
  Splitter2.Parent := PConnections;
  Splitter2.Align := alLeft;
  Splitter2.Left := LConnections.Width + 1;
  Splitter2.Width := Scale96ToScreen(5);

  PCon2 := TScrollBox.Create(Self);
  PCon2.Parent := PConnections;
  PCon2.Align := alClient;
  PCon2.BorderStyle := bsNone;
  PCon2.HorzScrollBar.Visible := False;
  // The editors are laid out for this width, anchored to the right
  PCon2.Width := Scale96ToScreen(440);

  rowh := Scale96ToScreen(30);
  editleft := Scale96ToScreen(24) + TextWidthOf([TranslateStr(147, 'Driver'),
    TranslateStr(1115, 'Reports table'), TranslateStr(1116, 'Report field'),
    TranslateStr(1117, 'R.search field'), TranslateStr(1118, 'Groups table'),
    TranslateStr(1119, 'ADO Conn.String')]);
  editleft := Max(editleft, Scale96ToScreen(120));

  y := Scale96ToScreen(4);
  CheckLoadParams := NewCheck(TranslateStr(145, 'Load params'));
  CheckLoadDriverParams := NewCheck(TranslateStr(146, 'Load driver params'));
  CheckLoginPrompt := NewCheck(TranslateStr(144, 'Login prompt'));
  Inc(y, Scale96ToScreen(4));

  LDriver := NewLabel(TranslateStr(147, 'Driver'));
  ComboDriver := TComboBox.Create(Self);
  ComboDriver.Parent := PCon2;
  ComboDriver.Style := csDropDownList;
  ComboDriver.SetBounds(editleft, y, PCon2.ClientWidth - editleft - Scale96ToScreen(10),
    Scale96ToScreen(24));
  AnchorRight(ComboDriver);
  ComboDriver.OnChange := EReportTableChange;
  GetRpDatabaseDrivers(ComboDriver.Items);
  Inc(y, rowh);

  LReportTable := NewLabel(TranslateStr(1115, 'Reports table'));
  EReportTable := NewEdit;
  LReportField := NewLabel(TranslateStr(1116, 'Report field'));
  EReportField := NewEdit;
  LRSearchField := NewLabel(TranslateStr(1117, 'R.search field'));
  EReportSearchField := NewEdit;
  LGroupsTable := NewLabel(TranslateStr(1118, 'Groups table'));
  EReportGroupsTable := NewEdit;
  LAdoConnection := NewLabel(TranslateStr(1119, 'ADO Conn.String'));
  EAdoConnection := NewEdit;
  // ADO is Windows/Delphi only: the string (password masked, as the VCL
  // shows it) is kept and shown, not edited
  EAdoConnection.ReadOnly := True;
  EAdoConnection.OnChange := nil;
  Inc(y, Scale96ToScreen(6));

  bw := Max(Scale96ToScreen(170), TextWidthOf([TranslateStr(143, 'Configure'),
    TranslateStr(1120, 'Create library'), TranslateStr(748, 'Check connection'),
    TranslateStr(1121, 'Browse library')]) + Scale96ToScreen(24));
  BConfig := NewButton(TranslateStr(143, 'Configure'), Scale96ToScreen(10), bw, BConfigClick);
  BCreateLib := NewButton(TranslateStr(1120, 'Create library'), Scale96ToScreen(20) + bw, bw,
    BCreateLibClick);
  Inc(y, Scale96ToScreen(34));
  BTest := NewButton(TranslateStr(748, 'Check connection'), Scale96ToScreen(10), bw, BTestClick);
  BBrowse := NewButton(TranslateStr(1121, 'Browse library'), Scale96ToScreen(20) + bw, bw,
    BBrowseClick);
end;

procedure TFRpEditConLCL.LoadConnections(AConnections: TRpDatabaseInfoList);
begin
  FConnections.Assign(AConnections);
  UpdateConList;
  if LConnections.Items.Count > 0 then
    LConnections.ItemIndex := 0
  else
    LConnections.ItemIndex := -1;
  LAliasesClick(Self);
end;

procedure TFRpEditConLCL.FormShow(Sender: TObject);
begin
  PConnections.Visible := True;
  LAliasesClick(Self);
end;

procedure TFRpEditConLCL.LConnectionsSelectionChange(Sender: TObject; User: Boolean);
begin
  // Also the keyboard selection
  if User then
    LAliasesClick(Sender);
end;

procedure TFRpEditConLCL.UpdateConList;
var
  i: Integer;
begin
  LConnections.Items.BeginUpdate;
  try
    LConnections.Clear;
    for i := 0 to FConnections.Count - 1 do
      LConnections.Items.Add(FConnections.Items[i].Alias);
  finally
    LConnections.Items.EndUpdate;
  end;
end;

function TFRpEditConLCL.SelectedItem: TRpDatabaseInfoItem;
begin
  Result := nil;
  if (LConnections.ItemIndex >= 0) and (LConnections.ItemIndex < FConnections.Count) then
    Result := FConnections.Items[LConnections.ItemIndex];
end;

procedure TFRpEditConLCL.SelectConnection(const AAlias: string);
begin
  LConnections.ItemIndex := LConnections.Items.IndexOf(AnsiUpperCase(AAlias));
  LAliasesClick(Self);
end;

procedure TFRpEditConLCL.LAliasesClick(Sender: TObject);
var
  dbitem: TRpDatabaseInfoItem;
begin
  dbitem := SelectedItem;
  if not Assigned(dbitem) then
  begin
    PCon2.Visible := False;
    BDeleteConn.Enabled := False;
    BRenameConn.Enabled := False;
    Exit;
  end;
  FUpdating := True;
  try
    if Integer(dbitem.Driver) < ComboDriver.Items.Count then
      ComboDriver.ItemIndex := Integer(dbitem.Driver)
    else
      ComboDriver.ItemIndex := -1;
    CheckLoadParams.Checked := dbitem.LoadParams;
    CheckLoadDriverParams.Checked := dbitem.LoadDriverParams;
    CheckLoginPrompt.Checked := dbitem.LoginPrompt;
    EReportTable.Text := dbitem.ReportTable;
    EReportField.Text := dbitem.ReportField;
    EReportSearchField.Text := dbitem.ReportSearchField;
    EReportGroupsTable.Text := dbitem.ReportGroupsTable;
    EAdoConnection.Text := EncodeADOPassword(dbitem.ADOConnectionString);
  finally
    FUpdating := False;
  end;
  BDeleteConn.Enabled := True;
  BRenameConn.Enabled := True;
  PCon2.Visible := True;
end;

procedure TFRpEditConLCL.EReportTableChange(Sender: TObject);
var
  dbitem: TRpDatabaseInfoItem;
begin
  if FUpdating then
    Exit;
  // Change any data
  dbitem := SelectedItem;
  if not Assigned(dbitem) then
    Exit;
  if Sender = CheckLoadParams then
    dbitem.LoadParams := CheckLoadParams.Checked
  else
  if Sender = CheckLoadDriverParams then
    dbitem.LoadDriverParams := CheckLoadDriverParams.Checked
  else
  if Sender = CheckLoginPrompt then
    dbitem.LoginPrompt := CheckLoginPrompt.Checked
  else
  if Sender = ComboDriver then
  begin
    if ComboDriver.ItemIndex >= 0 then
    begin
      // A new driver: the next connection uses it
      dbitem.DisConnect;
      dbitem.Driver := TRpDbDriver(ComboDriver.ItemIndex);
    end;
  end
  else
  if Sender = EReportTable then
    dbitem.ReportTable := EReportTable.Text
  else
  if Sender = EReportField then
    dbitem.ReportField := EReportField.Text
  else
  if Sender = EReportSearchField then
    dbitem.ReportSearchField := EReportSearchField.Text
  else
  if Sender = EReportGroupsTable then
    dbitem.ReportGroupsTable := EReportGroupsTable.Text;
end;

procedure TFRpEditConLCL.NewConnection(const AName: string);
var
  newname: string;
begin
  newname := Trim(AnsiUpperCase(AName));
  if Length(newname) < 1 then
    Exit;
  // TRpDatabaseInfoList.Add also raises for an existing name
  if FConnections.IndexOf(newname) >= 0 then
    Raise Exception.Create(SRpAliasExists + newname);
  FConnections.Add(newname);
  UpdateConList;
  LConnections.ItemIndex := LConnections.Items.Count - 1;
  LAliasesClick(Self);
end;

procedure TFRpEditConLCL.DeleteConnection;
var
  oldindex: Integer;
begin
  if not Assigned(SelectedItem) then
  begin
    PCon2.Visible := False;
    Exit;
  end;
  oldindex := LConnections.ItemIndex;
  FConnections.Items[oldindex].Free;
  UpdateConList;
  Dec(oldindex);
  if oldindex < 0 then
    oldindex := 0;
  if LConnections.Items.Count > 0 then
    LConnections.ItemIndex := oldindex
  else
    LConnections.ItemIndex := -1;
  LAliasesClick(Self);
end;

procedure TFRpEditConLCL.RenameConnection(const ANewName: string);
var
  newname: string;
  dbitem: TRpDatabaseInfoItem;
  i: Integer;
begin
  dbitem := SelectedItem;
  if not Assigned(dbitem) then
    Exit;
  newname := Trim(AnsiUpperCase(ANewName));
  if Length(newname) < 1 then
    Exit;
  i := FConnections.IndexOf(newname);
  if (i >= 0) and (i <> LConnections.ItemIndex) then
    Raise Exception.Create(SRpAliasExists + newname);
  dbitem.Alias := newname;
  UpdateConList;
  LConnections.ItemIndex := LConnections.Items.IndexOf(newname);
  LAliasesClick(Self);
end;

procedure TFRpEditConLCL.TestConnection;
var
  dbitem: TRpDatabaseInfoItem;
begin
  dbitem := SelectedItem;
  if not Assigned(dbitem) then
    Raise Exception.Create(SRpSelectAddConnection);
  dbitem.Connect(nil);
  dbitem.DisConnect;
end;

procedure TFRpEditConLCL.CreateLibrary;
var
  dbitem: TRpDatabaseInfoItem;
begin
  dbitem := SelectedItem;
  if not Assigned(dbitem) then
    Raise Exception.Create(SRpSelectAddConnection);
  RpCheckLibraryDriver(dbitem);
  dbitem.CreateLibrary(dbitem.ReportTable, dbitem.ReportField, dbitem.ReportSearchField,
    dbitem.ReportGroupsTable, nil);
  // The tables stay when the dialog frees its connections
  RpLibraryCommit(dbitem);
end;

procedure TFRpEditConLCL.ANewConnExecute(Sender: TObject);
var
  aname: string;
begin
  aname := RpInputBox(TranslateStr(1102, 'New connection'), SRpConnectionName, '');
  NewConnection(aname);
end;

procedure TFRpEditConLCL.ADeleteExecute(Sender: TObject);
begin
  DeleteConnection;
end;

procedure TFRpEditConLCL.ARenameExecute(Sender: TObject);
var
  aname: string;
  dbitem: TRpDatabaseInfoItem;
begin
  dbitem := SelectedItem;
  if not Assigned(dbitem) then
    Exit;
  aname := RpInputBox(TranslateStr(151, 'Rename'), SRpConnectionName, dbitem.Alias);
  RenameConnection(aname);
end;

procedure TFRpEditConLCL.BConfigClick(Sender: TObject);
begin
  // Wired to rpdbxconfiglcl.ShowDBXConfig when merged
end;

procedure TFRpEditConLCL.BTestClick(Sender: TObject);
begin
  TestConnection;
  RpShowMessage(SRpConnectionOk);
end;

procedure TFRpEditConLCL.BCreateLibClick(Sender: TObject);
begin
  if not Assigned(SelectedItem) then
    Exit;
  CreateLibrary;
end;

procedure TFRpEditConLCL.BBrowseClick(Sender: TObject);
var
  alibrary: string;
begin
  if not Assigned(SelectedItem) then
    Exit;
  alibrary := SelectedItem.Alias;
  SelectReportFromLibrary(FConnections, alibrary);
end;

end.

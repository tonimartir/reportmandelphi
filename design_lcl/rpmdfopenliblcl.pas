{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfopenliblcl                                 }
{       Dialog for selecting reports from library table }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfopenliblcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, ComCtrls, Dialogs, DB,
  rpmdconsts, rpdatainfo, rpreport, rptypes, rpgraphutilslcl;

type
  { TRpLibNodeInfo }

  // Data attached to every node of the library tree (VCL TRpNodeInfo)
  TRpLibNodeInfo = class(TObject)
  public
    ReportName: WideString;
    GroupCode: Integer;
    ParentGroup: Integer;
  end;

  { TFRpOpenLibLCL }

  TFRpOpenLibLCL = class(TForm)
  private
    dbinfo: TRpDatabaseInfoList;
    FDoOk: Boolean;
    FSelectedReport: WideString;
    FNodeInfos: TList;
    // Library contents read by EditTree
    FGroupCodes: array of Integer;
    FGroupNames: array of string;
    FGroupParents: array of Integer;
    FGroupVisited: array of Boolean;
    FReportNames: array of string;
    FReportGroups: array of Integer;

    procedure BuildControls;
    procedure ClearTree;
    function NewNodeInfo(const AReportName: WideString; AGroupCode,
      AParentGroup: Integer): TRpLibNodeInfo;
    function IndexOfGroup(ACode: Integer): Integer;
    procedure AddReportNodes(AParentNode: TTreeNode; AGroupCode: Integer);
    procedure AddGroupNodes(AParentNode: TTreeNode; AParentCode: Integer);
    procedure GenerateTree(const ARootCaption: string);
    procedure ComboLibraryClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure ATreeDblClick(Sender: TObject);
  public
    PTop: TPanel;
    LLibrary: TLabel;
    ComboLibrary: TComboBox;
    PBottom: TPanel;
    BOK: TButton;
    BCancel: TButton;
    ATree: TTreeView;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Port of TFRpDBTreeVCL.EditTree (read only): reads the report library
    // (ReportTable / ReportSearchField / ReportGroupsTable) of the connection
    // and builds the group hierarchy with its reports. Errors are raised.
    procedure EditTree(dbitem: TRpDatabaseInfoItem);
    // Report name of the selected node, '' for a group node
    function SelectedNodeReportName: WideString;

    property SelectedReport: WideString read FSelectedReport write FSelectedReport;
    property DoOk: Boolean read FDoOk;
  end;

// Shows the library selection dialog for the library connections (the
// designer global connections, not the report ones). Returns the selected
// report name ('' if cancelled) and the selected library in alibrary.
function SelectReportFromLibrary(dbinfo: TRpDatabaseInfoList; var alibrary: string): WideString;

implementation

function SelectReportFromLibrary(dbinfo: TRpDatabaseInfoList; var alibrary: string): WideString;
var
  dia: TFRpOpenLibLCL;
  i: Integer;
begin
  Result := '';
  if not Assigned(dbinfo) or (dbinfo.Count < 1) then
    Raise Exception.Create(SRPDabaseAliasNotFound);

  dia := TFRpOpenLibLCL.Create(Application);
  try
    dia.dbinfo := dbinfo;
    dia.ComboLibrary.OnChange := nil;
    dia.ComboLibrary.Items.Clear;
    for i := 0 to dbinfo.Count - 1 do
      dia.ComboLibrary.Items.Add(dbinfo.Items[i].Alias);

    dia.ComboLibrary.ItemIndex := 0;
    if Length(alibrary) > 0 then
    begin
      i := dbinfo.IndexOf(alibrary);
      if i >= 0 then
        dia.ComboLibrary.ItemIndex := i;
    end;
    dia.ComboLibrary.OnChange := dia.ComboLibraryClick;

    // Same as VCL: a library that can not be read is reported, the user can
    // still select another one
    try
      dia.ComboLibraryClick(dia.ComboLibrary);
    except
      on E: Exception do
        RpMessageBox(E.Message, SRpError, [smbOK], smsCritical, smbOK, smbOK);
    end;
    dia.ShowModal;

    if dia.DoOk then
    begin
      alibrary := dia.ComboLibrary.Text;
      Result := dia.SelectedReport;
    end;
  finally
    dia.Free;
  end;
end;

{ TFRpOpenLibLCL }

constructor TFRpOpenLibLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := TranslateStr(1123, 'Library reports');
  Position := poScreenCenter;
  Width := 500;
  Height := 450;

  FNodeInfos := TList.Create;
  BuildControls;
end;

destructor TFRpOpenLibLCL.Destroy;
begin
  ClearTree;
  FNodeInfos.Free;
  inherited Destroy;
end;

procedure TFRpOpenLibLCL.BuildControls;
begin
  PTop := TPanel.Create(Self);
  PTop.Parent := Self;
  PTop.Align := alTop;
  PTop.Height := 44;
  PTop.BevelOuter := bvNone;

  LLibrary := TLabel.Create(Self);
  LLibrary.Parent := PTop;
  LLibrary.Left := 12;
  LLibrary.Top := 14;
  LLibrary.Caption := SRpLibSelection;

  ComboLibrary := TComboBox.Create(Self);
  ComboLibrary.Parent := PTop;
  ComboLibrary.Left := 130;
  ComboLibrary.Top := 10;
  ComboLibrary.Width := 340;
  ComboLibrary.Anchors := [akLeft, akTop, akRight];
  ComboLibrary.Style := csDropDownList;
  ComboLibrary.OnChange := ComboLibraryClick;

  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := 44;
  PBottom.BevelOuter := bvNone;

  BOK := TButton.Create(Self);
  BOK.Parent := PBottom;
  BOK.Left := 300;
  BOK.Top := 9;
  BOK.Width := 85;
  BOK.Height := 27;
  BOK.Anchors := [akTop, akRight];
  BOK.Caption := SRpOk;
  BOK.Default := True;
  BOK.OnClick := BOKClick;

  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.Left := 395;
  BCancel.Top := 9;
  BCancel.Width := 85;
  BCancel.Height := 27;
  BCancel.Anchors := [akTop, akRight];
  BCancel.Caption := SRpCancel;
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;

  ATree := TTreeView.Create(Self);
  ATree.Parent := Self;
  ATree.Align := alClient;
  ATree.ReadOnly := True;
  ATree.OnDblClick := ATreeDblClick;
end;

procedure TFRpOpenLibLCL.ClearTree;
var
  i: Integer;
begin
  ATree.Items.Clear;
  for i := 0 to FNodeInfos.Count - 1 do
    TObject(FNodeInfos[i]).Free;
  FNodeInfos.Clear;
end;

function TFRpOpenLibLCL.NewNodeInfo(const AReportName: WideString; AGroupCode,
  AParentGroup: Integer): TRpLibNodeInfo;
begin
  Result := TRpLibNodeInfo.Create;
  FNodeInfos.Add(Result);
  Result.ReportName := AReportName;
  Result.GroupCode := AGroupCode;
  Result.ParentGroup := AParentGroup;
end;

function TFRpOpenLibLCL.IndexOfGroup(ACode: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FGroupCodes) do
  begin
    if FGroupCodes[i] = ACode then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TFRpOpenLibLCL.AddReportNodes(AParentNode: TTreeNode; AGroupCode: Integer);
var
  names: TStringList;
  i: Integer;
  node: TTreeNode;
begin
  names := TStringList.Create;
  try
    for i := 0 to High(FReportNames) do
    begin
      if FReportGroups[i] = AGroupCode then
        names.Add(FReportNames[i]);
    end;
    names.Sort;
    for i := 0 to names.Count - 1 do
    begin
      node := ATree.Items.AddChild(AParentNode, names[i]);
      node.Data := NewNodeInfo(names[i], AGroupCode, 0);
    end;
  finally
    names.Free;
  end;
end;

procedure TFRpOpenLibLCL.AddGroupNodes(AParentNode: TTreeNode; AParentCode: Integer);
var
  i: Integer;
  node: TTreeNode;
begin
  for i := 0 to High(FGroupCodes) do
  begin
    if FGroupVisited[i] then
      Continue;
    if (FGroupParents[i] <> AParentCode) or (FGroupCodes[i] = AParentCode) then
      Continue;
    // A malformed hierarchy (cycles) must not recurse forever
    FGroupVisited[i] := True;
    node := ATree.Items.AddChild(AParentNode, FGroupNames[i]);
    node.Data := NewNodeInfo('', FGroupCodes[i], FGroupParents[i]);
    AddGroupNodes(node, FGroupCodes[i]);
    AddReportNodes(node, FGroupCodes[i]);
  end;
end;

procedure TFRpOpenLibLCL.GenerateTree(const ARootCaption: string);
var
  rootNode: TTreeNode;
  i: Integer;
begin
  SetLength(FGroupVisited, Length(FGroupCodes));
  for i := 0 to High(FGroupVisited) do
    FGroupVisited[i] := False;
  ATree.Items.BeginUpdate;
  try
    rootNode := ATree.Items.AddChild(nil, ARootCaption);
    rootNode.Data := NewNodeInfo('', 0, 0);
    // Top level groups (PARENT_GROUP=0) and reports without group
    AddGroupNodes(rootNode, 0);
    AddReportNodes(rootNode, 0);
  finally
    ATree.Items.EndUpdate;
  end;
  rootNode.Expand(False);
end;

procedure TFRpOpenLibLCL.EditTree(dbitem: TRpDatabaseInfoItem);
var
  sqltext: string;
  adatareports, adatagroups: TDataSet;
  hasGroups: Boolean;
  groupField, nameField: TField;
  n, groupCode: Integer;
begin
  ClearTree;
  SetLength(FGroupCodes, 0);
  SetLength(FGroupNames, 0);
  SetLength(FGroupParents, 0);
  SetLength(FReportNames, 0);
  SetLength(FReportGroups, 0);
  if not Assigned(dbitem) then
    Exit;

  dbitem.Connect(nil);
  hasGroups := Length(dbitem.ReportGroupsTable) > 0;
  sqltext := 'SELECT ' + dbitem.ReportSearchField;
  // Do not read the report blobs
  if hasGroups then
  begin
    if dbitem.ReportGroupsTable = 'GINFORME' then
      sqltext := sqltext + ',GRUPO AS REPORT_GROUP'
    else
      sqltext := sqltext + ',REPORT_GROUP';
  end;
  sqltext := sqltext + ' FROM ' + dbitem.ReportTable;
  adatareports := dbitem.OpenDatasetFromSQL(sqltext, nil, False, nil);
  try
    if hasGroups then
    begin
      if dbitem.ReportGroupsTable = 'GINFORME' then
        adatagroups := dbitem.OpenDatasetFromSQL('SELECT CODIGO AS GROUP_CODE,NOMBRE AS GROUP_NAME,' +
          ' GRUPO AS PARENT_GROUP FROM ' + dbitem.ReportGroupsTable, nil, False, nil)
      else
        adatagroups := dbitem.OpenDatasetFromSQL('SELECT GROUP_CODE,GROUP_NAME,' +
          ' PARENT_GROUP FROM ' + dbitem.ReportGroupsTable, nil, False, nil);
      try
        n := 0;
        while not adatagroups.Eof do
        begin
          SetLength(FGroupCodes, n + 1);
          SetLength(FGroupNames, n + 1);
          SetLength(FGroupParents, n + 1);
          FGroupCodes[n] := adatagroups.FieldByName('GROUP_CODE').AsInteger;
          FGroupNames[n] := adatagroups.FieldByName('GROUP_NAME').AsString;
          FGroupParents[n] := adatagroups.FieldByName('PARENT_GROUP').AsInteger;
          if FGroupParents[n] < 0 then
            FGroupParents[n] := 0;
          Inc(n);
          adatagroups.Next;
        end;
      finally
        adatagroups.Free;
      end;
    end;

    nameField := adatareports.FieldByName(dbitem.ReportSearchField);
    groupField := nil;
    if hasGroups then
      groupField := adatareports.FindField('REPORT_GROUP');
    n := 0;
    while not adatareports.Eof do
    begin
      groupCode := 0;
      if Assigned(groupField) and (not groupField.IsNull) then
      begin
        groupCode := groupField.AsInteger;
        // Reports of unknown groups go to the root (VCL behaviour)
        if IndexOfGroup(groupCode) < 0 then
          groupCode := 0;
      end;
      SetLength(FReportNames, n + 1);
      SetLength(FReportGroups, n + 1);
      FReportNames[n] := nameField.AsString;
      FReportGroups[n] := groupCode;
      Inc(n);
      adatareports.Next;
    end;
  finally
    adatareports.Free;
  end;

  GenerateTree(dbitem.Alias);
end;

function TFRpOpenLibLCL.SelectedNodeReportName: WideString;
begin
  Result := '';
  if Assigned(ATree.Selected) and Assigned(ATree.Selected.Data) then
    Result := TRpLibNodeInfo(ATree.Selected.Data).ReportName;
end;

procedure TFRpOpenLibLCL.ComboLibraryClick(Sender: TObject);
var
  i: Integer;
begin
  if not Assigned(dbinfo) then Exit;
  ClearTree;
  i := dbinfo.IndexOf(ComboLibrary.Text);
  if i < 0 then
    Exit;
  EditTree(dbinfo.Items[i]);
end;

procedure TFRpOpenLibLCL.BOKClick(Sender: TObject);
begin
  // Is there a report selected?
  FSelectedReport := SelectedNodeReportName;
  if Length(FSelectedReport) < 1 then
    Raise Exception.Create(SRpSelectReport);
  FDoOk := True;
  ModalResult := mrOk;
end;

procedure TFRpOpenLibLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFRpOpenLibLCL.ATreeDblClick(Sender: TObject);
begin
  // Double click on a report opens it, on a group just expands/collapses
  if Length(SelectedNodeReportName) > 0 then
    BOKClick(BOK);
end;

end.

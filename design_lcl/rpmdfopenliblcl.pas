{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfopenliblcl                                 }
{       Dialog for selecting reports from library table }
{       and maintaining the library (add/delete...)     }
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
  rpmdconsts, rpdatainfo, rpreport, rptypes, rpgraphutilslcl, rpmdftreelcl;

type
  // Data of the library tree nodes (declared in rpmdftreelcl)
  TRpLibNodeInfo = rpmdftreelcl.TRpLibNodeInfo;

  { TFRpOpenLibLCL }

  // Port of TFRpOpenLibVCL: library selection and the library tree
  // (TFRpDBTreeLCL, the TFRpDBTreeVCL frame) with its maintenance actions
  TFRpOpenLibLCL = class(TForm)
  private
    dbinfo: TRpDatabaseInfoList;
    FDoOk: Boolean;
    FSelectedReport: WideString;
    FTree: TFRpDBTreeLCL;

    procedure BuildControls;
    function GetTree: TTreeView;
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

    constructor Create(AOwner: TComponent); override;

    // Reads the report library of the connection in the tree, editable as
    // in the VCL (TFRpDBTreeVCL.EditTree(dbitem,false)). Errors are raised.
    procedure EditTree(dbitem: TRpDatabaseInfoItem);
    // Report name of the selected node, '' for a group node
    function SelectedNodeReportName: WideString;
    // Selects the library of the combo and reads it (as choosing it)
    procedure SelectLibrary(const AAlias: string);
    // Accepts the selected report (the OK button); raises without one
    procedure AcceptSelection;

    property ATree: TTreeView read GetTree;
    property Tree: TFRpDBTreeLCL read FTree;
    property SelectedReport: WideString read FSelectedReport write FSelectedReport;
    property DoOk: Boolean read FDoOk;
  end;

// Shows the library dialog for the library connections (the designer global
// connections, not the report ones). Returns the selected report name ('' if
// cancelled) and the selected library in alibrary.
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
  // Fits a 800x600 screen
  Width := Scale96ToScreen(520);
  Height := Scale96ToScreen(450);
  Constraints.MinWidth := Scale96ToScreen(420);
  Constraints.MinHeight := Scale96ToScreen(300);

  BuildControls;
end;

procedure TFRpOpenLibLCL.BuildControls;
begin
  PTop := TPanel.Create(Self);
  PTop.Parent := Self;
  PTop.Align := alTop;
  PTop.Height := Scale96ToScreen(44);
  PTop.BevelOuter := bvNone;

  LLibrary := TLabel.Create(Self);
  LLibrary.Parent := PTop;
  LLibrary.Left := Scale96ToScreen(12);
  LLibrary.Top := Scale96ToScreen(14);
  LLibrary.Caption := SRpLibSelection;

  // From the end of the (translated) caption to the right side
  ComboLibrary := TComboBox.Create(Self);
  ComboLibrary.Parent := PTop;
  ComboLibrary.Top := Scale96ToScreen(10);
  ComboLibrary.AnchorSideLeft.Control := LLibrary;
  ComboLibrary.AnchorSideLeft.Side := asrRight;
  ComboLibrary.BorderSpacing.Left := Scale96ToScreen(10);
  ComboLibrary.AnchorSideRight.Control := PTop;
  ComboLibrary.AnchorSideRight.Side := asrRight;
  ComboLibrary.BorderSpacing.Right := Scale96ToScreen(12);
  ComboLibrary.Anchors := [akLeft, akTop, akRight];
  ComboLibrary.Style := csDropDownList;
  ComboLibrary.OnChange := ComboLibraryClick;

  PBottom := TPanel.Create(Self);
  PBottom.Parent := Self;
  PBottom.Align := alBottom;
  PBottom.Height := Scale96ToScreen(44);
  PBottom.BevelOuter := bvNone;

  // Fixed size buttons aligned to the right (no AutoSize: they would fight
  // the alignment on a small screen)
  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.SetBounds(10000, 0, Scale96ToScreen(90), Scale96ToScreen(27));
  BCancel.BorderSpacing.Around := Scale96ToScreen(8);
  BCancel.Align := alRight;
  BCancel.Caption := SRpCancel;
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;

  BOK := TButton.Create(Self);
  BOK.Parent := PBottom;
  BOK.SetBounds(9000, 0, Scale96ToScreen(90), Scale96ToScreen(27));
  BOK.BorderSpacing.Around := Scale96ToScreen(8);
  BOK.Align := alRight;
  BOK.Caption := SRpOk;
  BOK.Default := True;
  BOK.OnClick := BOKClick;

  FTree := TFRpDBTreeLCL.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.ATree.OnDblClick := ATreeDblClick;
end;

function TFRpOpenLibLCL.GetTree: TTreeView;
begin
  Result := FTree.ATree;
end;

procedure TFRpOpenLibLCL.EditTree(dbitem: TRpDatabaseInfoItem);
begin
  FTree.EditTree(dbitem, False);
end;

function TFRpOpenLibLCL.SelectedNodeReportName: WideString;
begin
  Result := FTree.SelectedReportName;
end;

procedure TFRpOpenLibLCL.ComboLibraryClick(Sender: TObject);
var
  i: Integer;
begin
  if not Assigned(dbinfo) then Exit;
  i := dbinfo.IndexOf(ComboLibrary.Text);
  if i < 0 then
  begin
    FTree.EditTree(nil, False);
    Exit;
  end;
  // Open and fill the selected
  EditTree(dbinfo.Items[i]);
end;

procedure TFRpOpenLibLCL.SelectLibrary(const AAlias: string);
var
  i: Integer;
begin
  i := ComboLibrary.Items.IndexOf(AnsiUpperCase(AAlias));
  if i < 0 then
    Raise Exception.Create(SRPDabaseAliasNotFound + ':' + AAlias);
  ComboLibrary.ItemIndex := i;
  ComboLibraryClick(ComboLibrary);
end;

procedure TFRpOpenLibLCL.AcceptSelection;
begin
  // Is there a report selected?
  FSelectedReport := SelectedNodeReportName;
  if Length(FSelectedReport) < 1 then
    Raise Exception.Create(SRpSelectReport);
  FDoOk := True;
  ModalResult := mrOk;
end;

procedure TFRpOpenLibLCL.BOKClick(Sender: TObject);
begin
  AcceptSelection;
end;

procedure TFRpOpenLibLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFRpOpenLibLCL.ATreeDblClick(Sender: TObject);
begin
  // Double click on a report opens it, on a group just expands/collapses
  if Length(SelectedNodeReportName) > 0 then
    AcceptSelection;
end;

end.

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
  rpmdconsts, rpdatainfo, rpreport, rptypes;

type
  { TFRpOpenLibLCL }

  TFRpOpenLibLCL = class(TForm)
  private
    dbinfo: TRpDatabaseInfoList;
    FDoOk: Boolean;
    FSelectedReport: WideString;

    procedure BuildControls;
    procedure ComboLibraryClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure ATreeDblClick(Sender: TObject);
    procedure RefreshTreeForDatabase(dbitem: TRpDatabaseInfoItem);
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

    property SelectedReport: WideString read FSelectedReport write FSelectedReport;
    property DoOk: Boolean read FDoOk;
  end;

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

    dia.ComboLibraryClick(dia.ComboLibrary);
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

  Caption := TranslateStr(1123, 'Abrir informe desde librería');
  Position := poScreenCenter;
  Width := 500;
  Height := 450;

  BuildControls;
end;

destructor TFRpOpenLibLCL.Destroy;
begin
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
  LLibrary.Caption := TranslateStr(24, 'Librería') + ':';

  ComboLibrary := TComboBox.Create(Self);
  ComboLibrary.Parent := PTop;
  ComboLibrary.Left := 90;
  ComboLibrary.Top := 10;
  ComboLibrary.Width := 380;
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
  BOK.Caption := TranslateStr(93, 'Aceptar');
  BOK.Default := True;
  BOK.OnClick := BOKClick;

  BCancel := TButton.Create(Self);
  BCancel.Parent := PBottom;
  BCancel.Left := 395;
  BCancel.Top := 9;
  BCancel.Width := 85;
  BCancel.Height := 27;
  BCancel.Caption := TranslateStr(94, 'Cancelar');
  BCancel.Cancel := True;
  BCancel.OnClick := BCancelClick;

  ATree := TTreeView.Create(Self);
  ATree.Parent := Self;
  ATree.Align := alClient;
  ATree.ReadOnly := True;
  ATree.OnDblClick := ATreeDblClick;
end;

procedure TFRpOpenLibLCL.RefreshTreeForDatabase(dbitem: TRpDatabaseInfoItem);
var
  ds: TDataSet;
  fldName: TField;
  node: TTreeNode;
begin
  ATree.Items.Clear;
  if not Assigned(dbitem) then Exit;

  try
    // Try opening REPMANDBM standard reports table
    ds := dbitem.OpenDatasetFromSQL('SELECT REPORT_NAME, GROUP_NAME FROM REPMANDBM ORDER BY GROUP_NAME, REPORT_NAME', nil, False, nil);
    if Assigned(ds) then
    begin
      try
        if not ds.Active then ds.Open;
        fldName := ds.FindField('REPORT_NAME');
        while not ds.EOF do
        begin
          if Assigned(fldName) and (Length(fldName.AsString) > 0) then
          begin
            node := ATree.Items.Add(nil, fldName.AsString);
            node.ImageIndex := 0;
          end;
          ds.Next;
        end;
      finally
        ds.Free;
      end;
    end;
  except
    // If table doesn't exist, leave tree empty
  end;
end;

procedure TFRpOpenLibLCL.ComboLibraryClick(Sender: TObject);
var
  i: Integer;
begin
  if not Assigned(dbinfo) then Exit;
  i := dbinfo.IndexOf(ComboLibrary.Text);
  if (i >= 0) and (i < dbinfo.Count) then
    RefreshTreeForDatabase(dbinfo.Items[i]);
end;

procedure TFRpOpenLibLCL.BOKClick(Sender: TObject);
begin
  if Assigned(ATree.Selected) and (Length(ATree.Selected.Text) > 0) then
  begin
    FSelectedReport := ATree.Selected.Text;
    FDoOk := True;
    ModalResult := mrOk;
  end
  else
  begin
    ShowMessage(TranslateStr(25, 'Seleccione un informe'));
  end;
end;

procedure TFRpOpenLibLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFRpOpenLibLCL.ATreeDblClick(Sender: TObject);
begin
  if Assigned(ATree.Selected) then
    BOKClick(BOK);
end;

end.

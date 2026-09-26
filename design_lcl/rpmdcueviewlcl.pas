{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdcueviewlcl.pas                              }
{       Undo/Redo Cue visual panel for LCL designer     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdcueviewlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Controls, Forms, ComCtrls, StdCtrls, ExtCtrls,
  Buttons, Dialogs, Graphics, Variants, Generics.Collections,
  rpreport, rptypes, rpmdundocuelcl, rpmdconsts, rpgraphutilslcl;

type
  TOnUndoRedoEvent = procedure(Sender: TObject) of object;

  { TFRpCueViewLCL }

  TFRpCueViewLCL = class(TPanel)
  private
    FReport: TRpReport;
    FOnUndoRedo: TOnUndoRedoEvent;

    procedure SetReport(Value: TRpReport);
    function GetUndoCue: TUndoCue;
    procedure BuildControls;
  public
    PanelTop: TPanel;
    BUndo: TSpeedButton;
    BRedo: TSpeedButton;
    BClear: TSpeedButton;
    LTitle: TLabel;
    ListViewCue: TListView;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure RefreshList;
    procedure UpdateButtons;

    procedure BUndoClick(Sender: TObject);
    procedure BRedoClick(Sender: TObject);
    procedure BClearClick(Sender: TObject);
    procedure ListViewCueDblClick(Sender: TObject);

    property Report: TRpReport read FReport write SetReport;
    property OnUndoRedo: TOnUndoRedoEvent read FOnUndoRedo write FOnUndoRedo;
  end;

function OperationTypeToText(op: TOperationType): string;

implementation

function OperationTypeToText(op: TOperationType): string;
begin
  case op of
    otAdd:      Result := '+';
    otModify:   Result := 'M';
    otRemove:   Result := 'X';
    otSwapDown: Result := '▼';
    otSwapUp:   Result := '▲';
    otRename:   Result := 'R';
  else
    Result := '?';
  end;
end;

{ TFRpCueViewLCL }

constructor TFRpCueViewLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  Caption := '';

  BuildControls;
end;

destructor TFRpCueViewLCL.Destroy;
begin
  inherited Destroy;
end;

procedure TFRpCueViewLCL.BuildControls;
var
  col: TListColumn;
begin
  // Top toolbar panel
  PanelTop := TPanel.Create(Self);
  PanelTop.Parent := Self;
  PanelTop.Align := alTop;
  PanelTop.Height := 34;
  PanelTop.BevelOuter := bvNone;

  BUndo := TSpeedButton.Create(PanelTop);
  BUndo.Parent := PanelTop;
  BUndo.Left := 4;
  BUndo.Top := 4;
  BUndo.Width := 30;
  BUndo.Height := 26;
  BUndo.Caption := '↩';
  BUndo.Hint := TranslateStr(287, 'Deshacer');
  BUndo.ShowHint := True;
  BUndo.OnClick := BUndoClick;

  BRedo := TSpeedButton.Create(PanelTop);
  BRedo.Parent := PanelTop;
  BRedo.Left := 38;
  BRedo.Top := 4;
  BRedo.Width := 30;
  BRedo.Height := 26;
  BRedo.Caption := '↪';
  BRedo.Hint := TranslateStr(288, 'Rehacer');
  BRedo.ShowHint := True;
  BRedo.OnClick := BRedoClick;

  BClear := TSpeedButton.Create(PanelTop);
  BClear.Parent := PanelTop;
  BClear.Left := 72;
  BClear.Top := 4;
  BClear.Width := 30;
  BClear.Height := 26;
  BClear.Caption := '✖';
  BClear.Hint := TranslateStr(289, 'Limpiar historial');
  BClear.ShowHint := True;
  BClear.OnClick := BClearClick;

  LTitle := TLabel.Create(PanelTop);
  LTitle.Parent := PanelTop;
  LTitle.Left := 110;
  LTitle.Top := 9;
  LTitle.Caption := TranslateStr(290, 'Historial');

  // ListView for Cue items
  ListViewCue := TListView.Create(Self);
  ListViewCue.Parent := Self;
  ListViewCue.Align := alClient;
  ListViewCue.ViewStyle := vsReport;
  ListViewCue.GridLines := True;
  ListViewCue.RowSelect := True;
  ListViewCue.ReadOnly := True;
  ListViewCue.OnDblClick := ListViewCueDblClick;

  col := ListViewCue.Columns.Add;
  col.Caption := 'Op';
  col.Width := 40;

  col := ListViewCue.Columns.Add;
  col.Caption := TranslateStr(64, 'Componente');
  col.Width := 110;

  col := ListViewCue.Columns.Add;
  col.Caption := TranslateStr(65, 'Clase');
  col.Width := 110;

  col := ListViewCue.Columns.Add;
  col.Caption := TranslateStr(291, 'Fecha/Hora');
  col.Width := 130;
end;

function TFRpCueViewLCL.GetUndoCue: TUndoCue;
begin
  if Assigned(FReport) and Assigned(FReport.UndoCue) and (FReport.UndoCue is TUndoCue) then
    Result := TUndoCue(FReport.UndoCue)
  else
    Result := nil;
end;

procedure TFRpCueViewLCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  RefreshList;
  UpdateButtons;
end;

procedure TFRpCueViewLCL.UpdateButtons;
var
  cue: TUndoCue;
begin
  cue := GetUndoCue;
  BUndo.Enabled := Assigned(cue) and (cue.UndoOperations.Count > 0);
  BRedo.Enabled := Assigned(cue) and (cue.RedoOperations.Count > 0);
  BClear.Enabled := Assigned(cue) and
    ((cue.UndoOperations.Count > 0) or (cue.RedoOperations.Count > 0));
end;

procedure TFRpCueViewLCL.RefreshList;
var
  cue: TUndoCue;
  i: Integer;
  op: TChangeObjectOperation;
  item: TListItem;
begin
  ListViewCue.Items.BeginUpdate;
  try
    ListViewCue.Items.Clear;
    cue := GetUndoCue;
    if cue = nil then
      Exit;

    // Show undo operations in reverse order (most recent first)
    for i := cue.UndoOperations.Count - 1 downto 0 do
    begin
      op := cue.UndoOperations[i];
      item := ListViewCue.Items.Add;
      item.Caption := OperationTypeToText(op.operation);
      item.SubItems.Add(op.componentName);
      item.SubItems.Add(op.componentClass);
      item.SubItems.Add(FormatDateTime('dd/mm hh:nn:ss', op.date));
      item.Data := op;
    end;

    // Separator between UNDO and REDO
    if (cue.UndoOperations.Count > 0) and (cue.RedoOperations.Count > 0) then
    begin
      item := ListViewCue.Items.Add;
      item.Caption := '---';
      item.SubItems.Add('--- REDO ---');
      item.SubItems.Add('');
      item.SubItems.Add('');
      item.Data := nil;
    end;

    // Show redo operations
    for i := cue.RedoOperations.Count - 1 downto 0 do
    begin
      op := cue.RedoOperations[i];
      item := ListViewCue.Items.Add;
      item.Caption := OperationTypeToText(op.operation);
      item.SubItems.Add(op.componentName);
      item.SubItems.Add(op.componentClass);
      item.SubItems.Add(FormatDateTime('dd/mm hh:nn:ss', op.date));
      item.Data := op;
    end;
  finally
    ListViewCue.Items.EndUpdate;
  end;
  UpdateButtons;
end;

procedure TFRpCueViewLCL.BUndoClick(Sender: TObject);
var
  cue: TUndoCue;
  ops: TObjectList<TChangeObjectOperation>;
begin
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  ops := cue.Undo;
  if Assigned(ops) then
  begin
    ops.Free;
    RefreshList;
    if Assigned(FOnUndoRedo) then
      FOnUndoRedo(Self);
  end;
end;

procedure TFRpCueViewLCL.BRedoClick(Sender: TObject);
var
  cue: TUndoCue;
  ops: TObjectList<TChangeObjectOperation>;
begin
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  ops := cue.Redo;
  if Assigned(ops) then
  begin
    ops.Free;
    RefreshList;
    if Assigned(FOnUndoRedo) then
      FOnUndoRedo(Self);
  end;
end;

procedure TFRpCueViewLCL.BClearClick(Sender: TObject);
var
  cue: TUndoCue;
begin
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  cue.Clear;
  RefreshList;
end;

procedure TFRpCueViewLCL.ListViewCueDblClick(Sender: TObject);
var
  op: TChangeObjectOperation;
  msg: string;
  i: Integer;
  prop: TChangeOperationItem;
begin
  if ListViewCue.Selected = nil then
    Exit;
  if ListViewCue.Selected.Data = nil then
    Exit;
  op := TChangeObjectOperation(ListViewCue.Selected.Data);
  msg := 'Operación: ' + OperationTypeToText(op.operation) + LineEnding +
    'Componente: ' + op.componentName + LineEnding +
    'Clase: ' + op.componentClass + LineEnding +
    'Padre: ' + op.parentName + LineEnding +
    'GroupId: ' + IntToStr(op.groupId) + LineEnding;
  if op.properties.Count > 0 then
  begin
    msg := msg + LineEnding + 'Propiedades:' + LineEnding;
    for i := 0 to op.properties.Count - 1 do
    begin
      prop := op.properties[i];
      msg := msg + '  ' + prop.propertyName +
        ': ' + VarToStr(prop.oldValue) + ' -> ' + VarToStr(prop.newValue) + LineEnding;
    end;
  end;
  ShowMessage(msg);
end;

end.

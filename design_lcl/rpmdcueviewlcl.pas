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
  Buttons, Dialogs, Graphics, Variants, Generics.Collections, LazUTF8,
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
    function IsLiveOperation(op: TObject): Boolean;
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
    // Clears the history without asking (BClearClick asks first)
    procedure ClearHistory;

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
  BUndo.Hint := TranslateStr(1481, 'Undo');
  BUndo.ShowHint := True;
  BUndo.OnClick := BUndoClick;

  BRedo := TSpeedButton.Create(PanelTop);
  BRedo.Parent := PanelTop;
  BRedo.Left := 38;
  BRedo.Top := 4;
  BRedo.Width := 30;
  BRedo.Height := 26;
  BRedo.Caption := '↪';
  BRedo.Hint := TranslateStr(1482, 'Redo');
  BRedo.ShowHint := True;
  BRedo.OnClick := BRedoClick;

  BClear := TSpeedButton.Create(PanelTop);
  BClear.Parent := PanelTop;
  BClear.Left := 72;
  BClear.Top := 4;
  BClear.Width := 30;
  BClear.Height := 26;
  BClear.Caption := '✖';
  BClear.Hint := TranslateStr(1484, 'Clear the undo history');
  BClear.ShowHint := True;
  BClear.OnClick := BClearClick;

  LTitle := TLabel.Create(PanelTop);
  LTitle.Parent := PanelTop;
  LTitle.Left := 110;
  LTitle.Top := 9;
  LTitle.Caption := TranslateStr(1483, 'History');

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
  col.Caption := TranslateStr(242, 'Operation');
  col.Width := 70;

  col := ListViewCue.Columns.Add;
  col.Caption := TranslateStr(544, 'Name');
  col.Width := 110;

  col := ListViewCue.Columns.Add;
  col.Caption := TranslateStr(1485, 'Class');
  col.Width := 110;

  col := ListViewCue.Columns.Add;
  col.Caption := TranslateStr(889, 'Date Time');
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
      item.SubItems.Add('--- ' + TranslateStr(1482, 'Redo') + ' ---');
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
  if (cue = nil) or not cue.CanUndo then
    Exit;
  // During an AI inference the report asks whether to cancel it (as the
  // Undo of the designer), instead of the undo cue failing
  FReport.AssertCanModify('Undo');
  ops := nil;
  try
    ops := cue.Undo;
  finally
    // Refresh also when the undo failed midway: part of the group may have
    // been undone and the design surface may reference removed items
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
  if (cue = nil) or not cue.CanRedo then
    Exit;
  FReport.AssertCanModify('Redo');
  ops := nil;
  try
    ops := cue.Redo;
  finally
    // Refresh also when the redo failed midway (see BUndoClick)
    ops.Free;
    RefreshList;
    if Assigned(FOnUndoRedo) then
      FOnUndoRedo(Self);
  end;
end;

procedure TFRpCueViewLCL.BClearClick(Sender: TObject);
begin
  // Same confirmation as the VCL designer (rpmdcueviewvcl)
  if RpMessageBox(TranslateStr(1484, 'Clear the undo history'), '',
    [smbYes, smbNo], smsWarning, smbYes, smbNo) <> smbYes then
    Exit;
  ClearHistory;
end;

procedure TFRpCueViewLCL.ClearHistory;
var
  cue: TUndoCue;
  hadHistory: Boolean;
begin
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  hadHistory := (cue.UndoOperations.Count > 0) or (cue.RedoOperations.Count > 0);
  cue.Clear;
  // The history is saved inside the report: emptying it is a change to save
  if hadHistory then
    cue.MarkExternalChange;
  RefreshList;
end;

function TFRpCueViewLCL.IsLiveOperation(op: TObject): Boolean;
var
  cue: TUndoCue;
begin
  // A row can outlive its operation when the list was not refreshed after
  // the cue discarded it (redo branch dropped, history trimmed)
  cue := GetUndoCue;
  Result := Assigned(cue) and Assigned(op) and
    ((cue.UndoOperations.IndexOf(TChangeObjectOperation(op)) >= 0) or
     (cue.RedoOperations.IndexOf(TChangeObjectOperation(op)) >= 0));
end;

procedure TFRpCueViewLCL.ListViewCueDblClick(Sender: TObject);
var
  op: TChangeObjectOperation;
  msg: string;
  i: Integer;
  prop: TChangeOperationItem;

  // Long values (the embedded files of the page setup carry their content)
  // are cut: the message must fit the screen
  function ShortValue(const AValue: Variant): string;
  const
    MAX_VALUE_LENGTH = 200;
  begin
    Result := VarToStr(AValue);
    if UTF8Length(Result) > MAX_VALUE_LENGTH then
      Result := UTF8Copy(Result, 1, MAX_VALUE_LENGTH) + '...';
  end;

begin
  if ListViewCue.Selected = nil then
    Exit;
  if ListViewCue.Selected.Data = nil then
    Exit;
  if not IsLiveOperation(TObject(ListViewCue.Selected.Data)) then
  begin
    RefreshList;
    Exit;
  end;
  op := TChangeObjectOperation(ListViewCue.Selected.Data);
  msg := TranslateStr(242, 'Operation') + ': ' + OperationTypeToText(op.operation) + LineEnding +
    TranslateStr(544, 'Name') + ': ' + op.componentName + LineEnding +
    TranslateStr(1485, 'Class') + ': ' + op.componentClass + LineEnding +
    TranslateStr(1486, 'Parent') + ': ' + op.parentName + LineEnding +
    'GroupId: ' + IntToStr(op.groupId) + LineEnding;
  if op.properties.Count > 0 then
  begin
    msg := msg + LineEnding + TranslateStr(1487, 'Properties') + ':' + LineEnding;
    for i := 0 to op.properties.Count - 1 do
    begin
      prop := op.properties[i];
      msg := msg + '  ' + prop.propertyName +
        ': ' + ShortValue(prop.oldValue) + ' -> ' + ShortValue(prop.newValue) + LineEnding;
    end;
  end;
  ShowMessage(msg);
end;

end.

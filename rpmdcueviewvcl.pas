{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmdcueviewvcl                                  }
{       Undo/Redo cue visual panel for VCL designer     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmdcueviewvcl;

{$I rpconf.inc}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Dialogs, Vcl.Graphics,
  rpreport, rptypes, rpmdundocue, Variants, rpgraphutilsvcl, rpmdconsts;

type
  TOnUndoRedoEvent = procedure(Sender: TObject) of object;

  TFRpCueViewVCL = class(TFrame)
    PanelTop: TPanel;
    BUndo: TSpeedButton;
    BRedo: TSpeedButton;
    BClear: TSpeedButton;
    LTitle: TLabel;
    ListViewCue: TListView;
    procedure BUndoClick(Sender: TObject);
    procedure BRedoClick(Sender: TObject);
    procedure BClearClick(Sender: TObject);
    procedure ListViewCueDblClick(Sender: TObject);
  private
    FReport: TRpReport;
    FOnUndoRedo: TOnUndoRedoEvent;
    procedure SetReport(Value: TRpReport);
    function GetUndoCue: TUndoCue;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshList;
    procedure UpdateButtons;
    property Report: TRpReport read FReport write SetReport;
    property OnUndoRedo: TOnUndoRedoEvent read FOnUndoRedo write FOnUndoRedo;
  end;

implementation

{$R *.dfm}

constructor TFRpCueViewVCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BUndo.Caption := #$21A9; // ↩
  BRedo.Caption := #$21AA; // ↪
  BClear.Caption := #$2716; // ✖
  // Texts of the LCL view (rpmdcueviewlcl)
  BUndo.Hint := TranslateStr(1481, 'Undo') + ' (Ctrl+Z)';
  BRedo.Hint := TranslateStr(1482, 'Redo') + ' (Ctrl+Y)';
  BClear.Hint := TranslateStr(1484, 'Clear the undo history');
  LTitle.Caption := TranslateStr(1483, 'History');
  ListViewCue.Columns[1].Caption := TranslateStr(544, 'Name');
  ListViewCue.Columns[2].Caption := TranslateStr(1485, 'Class');
  ListViewCue.Columns[3].Caption := TranslateStr(889, 'Date Time');
end;

function TFRpCueViewVCL.GetUndoCue: TUndoCue;
begin
  if Assigned(FReport) and Assigned(FReport.UndoCue) then
    Result := TUndoCue(FReport.UndoCue)
  else
    Result := nil;
end;

procedure TFRpCueViewVCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  RefreshList;
  UpdateButtons;
end;

procedure TFRpCueViewVCL.UpdateButtons;
var
  cue: TUndoCue;
begin
  cue := GetUndoCue;
  BUndo.Enabled := Assigned(cue) and (cue.UndoOperations.Count > 0);
  BRedo.Enabled := Assigned(cue) and (cue.RedoOperations.Count > 0);
  BClear.Enabled := Assigned(cue) and
    ((cue.UndoOperations.Count > 0) or (cue.RedoOperations.Count > 0));
end;

function OperationTypeToText(op: TOperationType): string;
begin
  case op of
    otAdd:      Result := '+';
    otModify:   Result := 'M';
    otRemove:   Result := 'X';
    otSwapDown: Result := #$25BC; // ▼
    otSwapUp:   Result := #$25B2; // ▲
    otRename:   Result := 'R';
  else
    Result := '?';
  end;
end;

procedure TFRpCueViewVCL.RefreshList;
var
  cue: TUndoCue;
  i: Integer;
  op: TChangeObjectOperation;
  item: TListItem;
  lastGroupId: Integer;
  useAltColor: Boolean;
begin
  ListViewCue.Items.BeginUpdate;
  try
    ListViewCue.Items.Clear;
    cue := GetUndoCue;
    if cue = nil then
      Exit;

    lastGroupId := -1;
    useAltColor := False;

    // Show undo operations in reverse order (most recent first)
    for i := cue.UndoOperations.Count - 1 downto 0 do
    begin
      op := cue.UndoOperations[i];
      if op.groupId <> lastGroupId then
      begin
        useAltColor := not useAltColor;
        lastGroupId := op.groupId;
      end;
      item := ListViewCue.Items.Add;
      item.Caption := OperationTypeToText(op.operation);
      item.SubItems.Add(op.componentName);
      item.SubItems.Add(op.componentClass);
      item.SubItems.Add(FormatDateTime('dd/mm hh:nn:ss', op.date));
      item.Data := op;
    end;

    // Separator
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

procedure TFRpCueViewVCL.BUndoClick(Sender: TObject);
var
  cue: TUndoCue;
  ops: TObjectList<TChangeObjectOperation>;
begin
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  ops := nil;
  try
    ops := cue.Undo;
  finally
    // Free the non-owning list (operations are owned by cue lists) and
    // rebuild the display even if an operation failed midway
    ops.Free;
    RefreshList;
    if Assigned(FOnUndoRedo) then
      FOnUndoRedo(Self);
  end;
end;

procedure TFRpCueViewVCL.BRedoClick(Sender: TObject);
var
  cue: TUndoCue;
  ops: TObjectList<TChangeObjectOperation>;
begin
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  ops := nil;
  try
    ops := cue.Redo;
  finally
    ops.Free;
    RefreshList;
    if Assigned(FOnUndoRedo) then
      FOnUndoRedo(Self);
  end;
end;

procedure TFRpCueViewVCL.BClearClick(Sender: TObject);
var
  cue: TUndoCue;
  cleared: Boolean;
begin
  if RpMessageBox(TranslateStr(1484, 'Clear the undo history'), '',
    [smbYes, smbNo], smsWarning, smbYes, smbNo) <> smbYes then
    Exit;
  cue := GetUndoCue;
  if cue = nil then
    Exit;
  cleared := (cue.UndoOperations.Count > 0) or (cue.RedoOperations.Count > 0);
  cue.Clear;
  // The undo history is saved inside the report (BINCUE): it changed
  if cleared and Assigned(FReport) then
    FReport.Modified := True;
  RefreshList;
end;

procedure TFRpCueViewVCL.ListViewCueDblClick(Sender: TObject);
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
  msg := TranslateStr(242, 'Operation') + ': ' + OperationTypeToText(op.operation) + #13#10 +
    TranslateStr(544, 'Name') + ': ' + op.componentName + #13#10 +
    TranslateStr(1485, 'Class') + ': ' + op.componentClass + #13#10 +
    TranslateStr(1486, 'Parent') + ': ' + op.parentName + #13#10 +
    'GroupId: ' + IntToStr(op.groupId) + #13#10;
  if op.properties.Count > 0 then
  begin
    msg := msg + #13#10 + TranslateStr(1487, 'Properties') + ':' + #13#10;
    for i := 0 to op.properties.Count - 1 do
    begin
      prop := op.properties[i];
      msg := msg + '  ' + prop.propertyName +
        ': ' + VarToStr(prop.oldValue) + ' -> ' + VarToStr(prop.newValue) + #13#10;
    end;
  end;
  RpMessageBox(msg, '', [smbOK], smsInformation, smbOK, smbOK,
    True);
end;

end.

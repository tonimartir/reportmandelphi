{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfgridlcl                                    }
{       Grid options dialog for LCL designer            }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfgridlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Buttons,
  rptypes, rpmdconsts, rpmunits, rpreport, rpmaskedit, rpmdundocuelcl;

type
  { TFRpGridOptionsLCL }

  TFRpGridOptionsLCL = class(TForm)
  private
    FReport: TRpReport;
    FBOK: TButton;
    FBCancel: TButton;
    FLHorizontal: TLabel;
    FEGridX: TRpMaskEdit;
    FLVertical: TLabel;
    FEGridY: TRpMaskEdit;
    FLGridColor: TLabel;
    FColorDialog: TColorDialog;
    FGridColor: TShape;
    FCheckEnabled: TCheckBox;
    FCheckVisible: TCheckBox;
    FCheckLines: TCheckBox;
    FLUnits1: TLabel;
    FLUnits2: TLabel;

    procedure SetReport(Value: TRpReport);
    procedure GridColorMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BOKClick(Sender: TObject);
    procedure BCancelClick(Sender: TObject);
    procedure BuildControls;
  public
    constructor Create(AOwner: TComponent); override;

    property Report: TRpReport read FReport write SetReport;
  end;

procedure ModifyGridProperties(report: TRpReport);

implementation

procedure ModifyGridProperties(report: TRpReport);
var
  dia: TFRpGridOptionsLCL;
begin
  dia := TFRpGridOptionsLCL.Create(Application);
  try
    dia.Report := report;
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

{ TFRpGridOptionsLCL }

constructor TFRpGridOptionsLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := TranslateStr(179, 'Grid Options');
  Width := 340;
  Height := 280;
  Position := poScreenCenter;
  BorderStyle := bsDialog;

  BuildControls;
end;

procedure TFRpGridOptionsLCL.BuildControls;
begin
  FColorDialog := TColorDialog.Create(Self);

  // Snap to grid
  FCheckEnabled := TCheckBox.Create(Self);
  FCheckEnabled.Parent := Self;
  FCheckEnabled.Caption := TranslateStr(182, 'Enable grid');
  FCheckEnabled.Left := 20;
  FCheckEnabled.Top := 16;
  FCheckEnabled.Width := 280;

  // Show grid
  FCheckVisible := TCheckBox.Create(Self);
  FCheckVisible.Parent := Self;
  FCheckVisible.Caption := TranslateStr(183, 'Visible');
  FCheckVisible.Left := 20;
  FCheckVisible.Top := 42;
  FCheckVisible.Width := 280;

  // Grid lines
  FCheckLines := TCheckBox.Create(Self);
  FCheckLines.Parent := Self;
  FCheckLines.Caption := TranslateStr(184, 'Draw lines');
  FCheckLines.Left := 20;
  FCheckLines.Top := 68;
  FCheckLines.Width := 280;

  // Horizontal spacing
  FLHorizontal := TLabel.Create(Self);
  FLHorizontal.Parent := Self;
  FLHorizontal.Caption := TranslateStr(180, 'Horizontal spacing');
  FLHorizontal.Left := 20;
  FLHorizontal.Top := 102;

  FEGridX := TRpMaskEdit.Create(Self);
  FEGridX.Parent := Self;
  FEGridX.Left := 115;
  FEGridX.Top := 98;
  FEGridX.Width := 85;

  FLUnits1 := TLabel.Create(Self);
  FLUnits1.Parent := Self;
  FLUnits1.Left := 210;
  FLUnits1.Top := 102;

  // Vertical spacing
  FLVertical := TLabel.Create(Self);
  FLVertical.Parent := Self;
  FLVertical.Caption := TranslateStr(181, 'Vertical spacing');
  FLVertical.Left := 20;
  FLVertical.Top := 134;

  FEGridY := TRpMaskEdit.Create(Self);
  FEGridY.Parent := Self;
  FEGridY.Left := 115;
  FEGridY.Top := 130;
  FEGridY.Width := 85;

  FLUnits2 := TLabel.Create(Self);
  FLUnits2.Parent := Self;
  FLUnits2.Left := 210;
  FLUnits2.Top := 134;

  // Grid Color
  FLGridColor := TLabel.Create(Self);
  FLGridColor.Parent := Self;
  FLGridColor.Caption := TranslateStr(185, 'Grid Color');
  FLGridColor.Left := 20;
  FLGridColor.Top := 168;

  FGridColor := TShape.Create(Self);
  FGridColor.Parent := Self;
  FGridColor.Shape := stRectangle;
  FGridColor.Left := 115;
  FGridColor.Top := 164;
  FGridColor.Width := 50;
  FGridColor.Height := 22;
  FGridColor.Cursor := crHandPoint;
  FGridColor.OnMouseDown := GridColorMouseDown;

  // Buttons
  FBOK := TButton.Create(Self);
  FBOK.Parent := Self;
  FBOK.Caption := TranslateStr(93, 'OK');
  FBOK.Left := 140;
  FBOK.Top := 208;
  FBOK.Width := 80;
  FBOK.Height := 28;
  FBOK.Default := True;
  FBOK.OnClick := BOKClick;

  FBCancel := TButton.Create(Self);
  FBCancel.Parent := Self;
  FBCancel.Caption := TranslateStr(94, 'Cancel');
  FBCancel.Left := 230;
  FBCancel.Top := 208;
  FBCancel.Width := 80;
  FBCancel.Height := 28;
  FBCancel.Cancel := True;
  FBCancel.OnClick := BCancelClick;
end;

procedure TFRpGridOptionsLCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  if not Assigned(FReport) then Exit;

  FLUnits1.Caption := getdefaultunitstring;
  FLUnits2.Caption := FLUnits1.Caption;
  FEGridX.Text := rpmunits.gettextfromtwips(FReport.GridWidth);
  FEGridY.Text := rpmunits.gettextfromtwips(FReport.GridHeight);
  FCheckEnabled.Checked := FReport.GridEnabled;
  FCheckVisible.Checked := FReport.GridVisible;
  FCheckLines.Checked := FReport.GridLines;
  FGridColor.Brush.Color := FReport.GridColor;
end;

procedure TFRpGridOptionsLCL.GridColorMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FColorDialog.Color := FGridColor.Brush.Color;
  if FColorDialog.Execute then
    FGridColor.Brush.Color := FColorDialog.Color;
end;

procedure TFRpGridOptionsLCL.BOKClick(Sender: TObject);
var
  cue: TUndoCue;
  op: TChangeObjectOperation;
  newGridWidth, newGridHeight: Integer;
  oldGridWidth, oldGridHeight, oldGridColor: Integer;
  oldGridEnabled, oldGridVisible, oldGridLines: Boolean;
begin
  if not Assigned(FReport) then
  begin
    Close;
    Exit;
  end;

  // Convert first: an invalid value keeps the dialog open and the report intact
  newGridWidth := rpmunits.gettwipsfromtext(FEGridX.Text);
  newGridHeight := rpmunits.gettwipsfromtext(FEGridY.Text);
  FReport.AssertCanModify('Grid options');

  oldGridWidth := FReport.GridWidth;
  oldGridHeight := FReport.GridHeight;
  oldGridEnabled := FReport.GridEnabled;
  oldGridVisible := FReport.GridVisible;
  oldGridLines := FReport.GridLines;
  oldGridColor := FReport.GridColor;

  FReport.GridWidth := newGridWidth;
  FReport.GridHeight := newGridHeight;
  FReport.GridEnabled := FCheckEnabled.Checked;
  FReport.GridVisible := FCheckVisible.Checked;
  FReport.GridLines := FCheckLines.Checked;
  FReport.GridColor := FGridColor.Brush.Color;

  // Same undo operation as rpmdfgridvcl
  if not Assigned(FReport.UndoCue) then
    FReport.UndoCue := TUndoCue.Create(FReport);
  cue := TUndoCue(FReport.UndoCue);
  op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
  op.componentName := 'REPORT';
  op.componentClass := 'TRPREPORT';
  op.parentName := '';
  if oldGridWidth <> FReport.GridWidth then
    op.AddProperty('gridWidth', ptInteger, oldGridWidth, FReport.GridWidth);
  if oldGridHeight <> FReport.GridHeight then
    op.AddProperty('gridHeight', ptInteger, oldGridHeight, FReport.GridHeight);
  if oldGridEnabled <> FReport.GridEnabled then
    op.AddProperty('gridEnabled', ptBoolean, oldGridEnabled, FReport.GridEnabled);
  if oldGridVisible <> FReport.GridVisible then
    op.AddProperty('gridVisible', ptBoolean, oldGridVisible, FReport.GridVisible);
  if oldGridLines <> FReport.GridLines then
    op.AddProperty('gridLines', ptBoolean, oldGridLines, FReport.GridLines);
  if oldGridColor <> FReport.GridColor then
    op.AddProperty('gridColor', ptInteger, oldGridColor, FReport.GridColor);
  if op.properties.Count > 0 then
    cue.AddOperation(op)
  else
    op.Free;

  ModalResult := mrOk;
  Close;
end;

procedure TFRpGridOptionsLCL.BCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
  Close;
end;

end.

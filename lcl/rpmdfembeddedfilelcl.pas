{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmdfembeddedfilelcl                            }
{       Properties of a file embedded in the PDF        }
{       (LCL port of rpmdfembeddedfile)                 }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rpmdfembeddedfilelcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Math, Graphics, Controls, Forms, StdCtrls,
  rpmdconsts, rptypes;

type
  { TFRpEmbeddedFileLCL: built in code (no form resource), with fixed
    button widths so that it fits small screens }

  TFRpEmbeddedFileLCL = class(TForm)
  private
    procedure BuildControls;
  public
    labelDescription: TLabel;
    textDescription: TEdit;
    labelFilename: TLabel;
    textFilename: TEdit;
    labelMimeType: TLabel;
    ComboMimeType: TComboBox;
    labelRelationShip: TLabel;
    ComboRelationShip: TComboBox;
    labelCreationDate: TLabel;
    textCreationDate: TEdit;
    labelModificationDate: TLabel;
    textModificationDate: TEdit;
    BOK: TButton;
    BCancel: TButton;
    constructor Create(AOwner: TComponent); override;
  end;

// Edits the properties of embeddedFile (not its content); True on OK
function AskEmbeddedFileData(embeddedFile: TEmbeddedFile): Boolean;

// Name of an AF relationship as the PDF writes it (/Unspecified, /Data...)
function RpAFRelationShipName(AValue: TPDFAFRelationShip): string;

implementation

function RpAFRelationShipName(AValue: TPDFAFRelationShip): string;
begin
  case AValue of
    PDF_AF_Alternative: Result := 'Alternative';
    PDF_AF_Data: Result := 'Data';
    PDF_AF_Source: Result := 'Source';
    PDF_AF_Supplement: Result := 'Supplement';
  else
    Result := 'Unspecified';
  end;
end;

constructor TFRpEmbeddedFileLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := SRpEmbeddedFile;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  BuildControls;
end;

procedure TFRpEmbeddedFileLCL.BuildControls;
var
  LLabels: array[0..5] of TLabel;
  LEditors: array[0..5] of TWinControl;
  LBitmap: TBitmap;
  LMargin, LLabelWidth, LEditLeft, LEditWidth, LRowHeight, LTop: Integer;
  LButtonWidth, I: Integer;
  LRelation: TPDFAFRelationShip;
  LMimes: TStringList;

  function NewLabel(const ACaption: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.Caption := ACaption;
  end;

  function NewEdit: TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Self;
  end;

  function NewCombo(AStyle: TComboBoxStyle): TComboBox;
  begin
    Result := TComboBox.Create(Self);
    Result.Parent := Self;
    Result.Style := AStyle;
  end;

begin
  labelDescription := NewLabel(SRpDescription);
  textDescription := NewEdit;
  labelFilename := NewLabel(SRpFilename);
  textFilename := NewEdit;
  labelMimeType := NewLabel(SRpMimetype);
  ComboMimeType := NewCombo(csDropDown);
  labelRelationShip := NewLabel(SRpRelationShip);
  ComboRelationShip := NewCombo(csDropDownList);
  labelCreationDate := NewLabel(SRpCreationDateISO);
  textCreationDate := NewEdit;
  labelModificationDate := NewLabel(SRpModificationDateISO);
  textModificationDate := NewEdit;

  LMimes := TStringList.Create;
  try
    GetCommonMimeTypes(LMimes);
    ComboMimeType.Items.Assign(LMimes);
  finally
    LMimes.Free;
  end;
  for LRelation := Low(TPDFAFRelationShip) to High(TPDFAFRelationShip) do
    ComboRelationShip.Items.Add(RpAFRelationShipName(LRelation));
  ComboRelationShip.ItemIndex := 0;

  BOK := TButton.Create(Self);
  BOK.Parent := Self;
  BOK.Caption := SRpOk;
  BOK.Default := True;
  BOK.ModalResult := mrOk;
  BCancel := TButton.Create(Self);
  BCancel.Parent := Self;
  BCancel.Caption := SRpCancel;
  BCancel.Cancel := True;
  BCancel.ModalResult := mrCancel;

  LLabels[0] := labelDescription;
  LLabels[1] := labelFilename;
  LLabels[2] := labelMimeType;
  LLabels[3] := labelRelationShip;
  LLabels[4] := labelCreationDate;
  LLabels[5] := labelModificationDate;
  LEditors[0] := textDescription;
  LEditors[1] := textFilename;
  LEditors[2] := ComboMimeType;
  LEditors[3] := ComboRelationShip;
  LEditors[4] := textCreationDate;
  LEditors[5] := textModificationDate;

  // Fixed layout from the text widths: no AutoSize control fights an
  // alignment when the window is small
  LMargin := Scale96ToScreen(12);
  LRowHeight := Scale96ToScreen(36);
  LEditWidth := Scale96ToScreen(360);
  LLabelWidth := 0;
  LBitmap := TBitmap.Create;
  try
    LBitmap.Canvas.Font := Font;
    for I := 0 to High(LLabels) do
      LLabelWidth := Max(LLabelWidth, LBitmap.Canvas.TextWidth(LLabels[I].Caption));
    LButtonWidth := Max(Scale96ToScreen(90),
      Max(LBitmap.Canvas.TextWidth(BOK.Caption), LBitmap.Canvas.TextWidth(BCancel.Caption)) +
      Scale96ToScreen(24));
  finally
    LBitmap.Free;
  end;
  LLabelWidth := LLabelWidth + Scale96ToScreen(8);
  LEditLeft := LMargin + LLabelWidth + LMargin;
  // Never wider than the screen (800x600 included)
  if LEditLeft + LEditWidth + LMargin > Screen.WorkAreaWidth - Scale96ToScreen(40) then
    LEditWidth := Max(Scale96ToScreen(200),
      Screen.WorkAreaWidth - Scale96ToScreen(40) - LEditLeft - LMargin);
  ClientWidth := LEditLeft + LEditWidth + LMargin;

  LTop := LMargin;
  for I := 0 to High(LLabels) do
  begin
    LLabels[I].SetBounds(LMargin, LTop + Scale96ToScreen(4), LLabelWidth, Scale96ToScreen(20));
    LEditors[I].SetBounds(LEditLeft, LTop, LEditWidth, LEditors[I].Height);
    LEditors[I].Anchors := [akLeft, akTop, akRight];
    LEditors[I].TabOrder := I;
    Inc(LTop, LRowHeight);
  end;
  Inc(LTop, Scale96ToScreen(8));
  // The final size first: controls anchored to the bottom or the right move
  // with later size changes
  ClientHeight := LTop + Scale96ToScreen(30) + LMargin;
  BOK.SetBounds(LMargin, LTop, LButtonWidth, Scale96ToScreen(30));
  BOK.Anchors := [akLeft, akBottom];
  BOK.TabOrder := Length(LEditors);
  BCancel.SetBounds(ClientWidth - LMargin - LButtonWidth, LTop, LButtonWidth,
    Scale96ToScreen(30));
  BCancel.Anchors := [akRight, akBottom];
  BCancel.TabOrder := Length(LEditors) + 1;
  ActiveControl := textDescription;
end;

function AskEmbeddedFileData(embeddedFile: TEmbeddedFile): Boolean;
var
  dia: TFRpEmbeddedFileLCL;
begin
  Result := False;
  dia := TFRpEmbeddedFileLCL.Create(nil);
  try
    dia.textDescription.Text := embeddedFile.Description;
    dia.ComboMimeType.Text := embeddedFile.MimeType;
    dia.textFilename.Text := embeddedFile.FileName;
    dia.ComboRelationShip.ItemIndex := Integer(embeddedFile.AFRelationShip);
    dia.textCreationDate.Text := embeddedFile.CreationDate;
    dia.textModificationDate.Text := embeddedFile.ModificationDate;
    if dia.ShowModal = mrOk then
    begin
      embeddedFile.Description := dia.textDescription.Text;
      embeddedFile.MimeType := dia.ComboMimeType.Text;
      embeddedFile.FileName := dia.textFilename.Text;
      if dia.ComboRelationShip.ItemIndex >= 0 then
        embeddedFile.AFRelationShip := TPDFAFRelationShip(dia.ComboRelationShip.ItemIndex);
      embeddedFile.CreationDate := dia.textCreationDate.Text;
      embeddedFile.ModificationDate := dia.textModificationDate.Text;
      Result := True;
    end;
  finally
    dia.Free;
  end;
end;

end.

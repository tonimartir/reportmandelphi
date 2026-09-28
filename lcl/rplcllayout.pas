{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rplcllayout                                     }
{       Anchor helpers for the LCL dialogs              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{*******************************************************}

unit rplcllayout;

{ The positions of several lfm files were made for the fonts of other
  widgetsets: controls were cut by their groups or covered each other with
  GTK2, Qt6 and the translated texts. The dialogs placed in code anchor each
  control to a side of its parent or of a sibling, so the real heights of the
  widgetset place them (Qt6 gives the final ones only after showing the
  form), and the label columns come from the widths of the texts. }

{$mode delphi}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms;

// The LCL scales a new form (or frame) from its PixelsPerInch (96, or that of
// its lfm) to the ppi of its monitor after the constructor and OnCreate
// (TCustomForm.AfterConstruction; a frame when it gets its parent). A form
// built in code in pixels of the screen (Scale96ToScreen, widths of texts)
// calls this before creating its controls, or all its sizes were scaled
// twice (50% bigger at 144 ppi); its fixed sizes use Scale96ToScreen too
procedure RpBuiltInScreenPixels(AControl: TCustomDesignControl);
// Forgets the anchors of the lfm: left and top at the current position
procedure RpResetAnchors(AControl: TControl);
// Left at ALeft of the left side of the parent; top at ASpace below ABelow,
// or of the top of the parent when ABelow is nil
procedure RpPlaceAt(AControl: TControl; ALeft: Integer; ABelow: TControl;
  ASpace: Integer);
// Left at ASpace after ALeftOf (the top is placed apart)
procedure RpPlaceRightOf(AControl, ALeftOf: TControl; ASpace: Integer);
// The right side at ASpace of the right side of the parent: the width
// follows the parent
procedure RpToParentRight(AControl: TControl; ASpace: Integer);
// A label at ALeft of its parent, centered on the height of AEditor
procedure RpLabelFor(ALabel: TControl; ALeft: Integer; AEditor: TControl);
// A label just above its editor (same parent): its bottom on the top of the
// editor, so a label taller than the room left by fixed positions (bigger
// fonts, 120 ppi) grows upwards instead of covering the editor
procedure RpLabelAbove(ALabel, AEditor: TControl);
// A label (units) after its editor, centered on its height
procedure RpUnitsFor(ALabel: TControl; AEditor: TControl; ASpace: Integer);
// Width of the widest of the texts with AFont (no handle needed)
function RpMaxTextWidth(AFont: TFont; const ATexts: array of string): Integer;

implementation

procedure RpBuiltInScreenPixels(AControl: TCustomDesignControl);
begin
  AControl.PixelsPerInch := Screen.PixelsPerInch;
  AControl.Font.PixelsPerInch := Screen.PixelsPerInch;
end;

procedure RpResetAnchors(AControl: TControl);
var
  k: TAnchorKind;
begin
  for k := Low(TAnchorKind) to High(TAnchorKind) do
    AControl.AnchorSide[k].Control := nil;
  AControl.Anchors := [akLeft, akTop];
  AControl.BorderSpacing.Around := 0;
end;

procedure RpPlaceAt(AControl: TControl; ALeft: Integer; ABelow: TControl;
  ASpace: Integer);
begin
  RpResetAnchors(AControl);
  AControl.AnchorParallel(akLeft, ALeft, AControl.Parent);
  if ABelow = nil then
    AControl.AnchorParallel(akTop, ASpace, AControl.Parent)
  else
    AControl.AnchorToNeighbour(akTop, ASpace, ABelow);
end;

procedure RpPlaceRightOf(AControl, ALeftOf: TControl; ASpace: Integer);
begin
  RpResetAnchors(AControl);
  AControl.AnchorToNeighbour(akLeft, ASpace, ALeftOf);
end;

procedure RpToParentRight(AControl: TControl; ASpace: Integer);
begin
  AControl.AnchorParallel(akRight, ASpace, AControl.Parent);
end;

procedure RpLabelFor(ALabel: TControl; ALeft: Integer; AEditor: TControl);
begin
  RpResetAnchors(ALabel);
  ALabel.AutoSize := True;
  ALabel.AnchorParallel(akLeft, ALeft, ALabel.Parent);
  ALabel.AnchorVerticalCenterTo(AEditor);
end;

procedure RpLabelAbove(ALabel, AEditor: TControl);
begin
  ALabel.AnchorSide[akBottom].Control := AEditor;
  ALabel.AnchorSide[akBottom].Side := asrTop;
  ALabel.Anchors := ALabel.Anchors - [akTop] + [akBottom];
end;

procedure RpUnitsFor(ALabel: TControl; AEditor: TControl; ASpace: Integer);
begin
  RpPlaceRightOf(ALabel, AEditor, ASpace);
  ALabel.AutoSize := True;
  ALabel.AnchorVerticalCenterTo(AEditor);
end;

function RpMaxTextWidth(AFont: TFont; const ATexts: array of string): Integer;
var
  LBitmap: TBitmap;
  i: Integer;
begin
  Result := 0;
  LBitmap := TBitmap.Create;
  try
    LBitmap.Canvas.Font := AFont;
    for i := 0 to High(ATexts) do
      if LBitmap.Canvas.TextWidth(ATexts[i]) > Result then
        Result := LBitmap.Canvas.TextWidth(ATexts[i]);
  finally
    LBitmap.Free;
  end;
end;

end.

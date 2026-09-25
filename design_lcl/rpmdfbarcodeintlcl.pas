{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfbarcodeintlcl                              }
{       Barcode designer interface for LCL              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfbarcodeintlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Types,
  Graphics, Forms, Controls,
  rpprintitem, rpmdbarcode, rpmdobinsintlcl, rpmdconsts,
  rpgraphutilslcl, rptypes;

type
  TRpBarcodeInterface = class(TRpSizePosInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
  end;

implementation

constructor TRpBarcodeInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if not (pritem is TRpBarcode) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

class procedure TRpBarcodeInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpBarcodeInterface');
end;

procedure TRpBarcodeInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  abar: TRpBarcode;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  abar := TRpBarcode(printitem);
  lnames.Add(SrpSExpression);
  ltypes.Add(SRpSExpression);
  lhints.Add('refbarcode.html');
  lcat.Add(SRpBarcode);
  if Assigned(lvalues) then lvalues.Add(abar.Expression);
end;

procedure TRpBarcodeInterface.SetProperty(pname: string; value: WideString);
var
  abar: TRpBarcode;
begin
  abar := TRpBarcode(printitem);
  if pname = SrpSExpression then
  begin
    abar.Expression := value;
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpBarcodeInterface.GetProperty(pname: string): WideString;
var
  abar: TRpBarcode;
begin
  abar := TRpBarcode(printitem);
  if pname = SrpSExpression then Result := abar.Expression
  else Result := inherited GetProperty(pname);
end;

procedure TRpBarcodeInterface.Paint;
var
  abar: TRpBarcode;
  sText: string;
begin
  abar := TRpBarcode(printitem);
  if not Assigned(abar) or (csDestroying in abar.ComponentState) then
    Exit;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Size := 8;
  Canvas.Font.Color := clBlack;
  sText := abar.Expression;
  if Length(sText) = 0 then
    sText := '[Barcode]';
  Canvas.TextOut(4, 2, sText);

  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psDashDotDot;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);

  DrawSelected;
end;

end.

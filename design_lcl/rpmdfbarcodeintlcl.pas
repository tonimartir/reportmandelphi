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
  rpgraphutilslcl, rpmunits, rptypes;

type
  TRpBarcodeInterface = class(TRpSizePosInterface)
  protected
    procedure Paint; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: WideString; value: WideString); override;
    function GetProperty(pname: WideString): WideString; override;
    procedure GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings); override;
  end;

implementation

constructor TRpBarcodeInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if Assigned(pritem) and not (pritem is TRpBarcode) then
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

  procedure AddProp(const AName, AType: WideString);
  begin
    lnames.Add(AName);
    ltypes.Add(AType);
    lhints.Add('refbarcode.html');
    lcat.Add(SRpBarcode);
    if Assigned(lvalues) and Assigned(abar) then
      lvalues.Add(GetProperty(AName));
  end;

begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  abar := TRpBarcode(printitem);
  // Same order and types as the VCL designer
  AddProp(SRpSBarcodeType, SRpSList);
  AddProp(SRpSChecksum, SRpSBool);
  AddProp(SrpSModul, SRpSCurrency);
  AddProp(SrpSRatio, SRpSCurrency);
  AddProp(SrpSExpression, SRpSExpression);
  AddProp(SrpSDisplayFormat, SRpSString);
  // Rotation in degrees
  AddProp(SRpSRotation, SrpSList);
  // Bar color
  AddProp(SrpSColor, SRpSColor);
  AddProp(SrpSBackColor, SRpSColor);
  AddProp(SrpSTransparent, SRpSBool);
  // PDF417
  AddProp(SRpECCLevel, SRpSList);
  AddProp(SRpNumRows, SRpInteger);
  AddProp(SRpNumCols, SRpInteger);
  AddProp(SRpTruncatedPDF417, SRpSBool);
end;

procedure TRpBarcodeInterface.SetProperty(pname: WideString; value: WideString);
var
  abar: TRpBarcode;
  cvalue: Currency;
begin
  abar := TRpBarcode(printitem);
  if not Assigned(abar) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;
  // Numbers and booleans being typed keep the current value until valid
  if pname = SRpSBarcodeType then
  begin
    abar.Typ := StringBarcodeToBarCodeType(AnsiString(value));
    Invalidate;
    Exit;
  end;
  if pname = SRpSChecksum then
  begin
    abar.Checksum := StrToBoolDef(value, abar.Checksum);
    Invalidate;
    Exit;
  end;
  if pname = SrpSTransparent then
  begin
    abar.Transparent := StrToBoolDef(value, abar.Transparent);
    Invalidate;
    Exit;
  end;
  if pname = SRpSModul then
  begin
    abar.Modul := gettwipsfromtext(value);
    Invalidate;
    Exit;
  end;
  if pname = SRpSRatio then
  begin
    if TryStrToCurr(value, cvalue) then
      abar.Ratio := cvalue;
    Invalidate;
    Exit;
  end;
  if pname = SrpSExpression then
  begin
    abar.Expression := value;
    Invalidate;
    Exit;
  end;
  if pname = SrpSDisplayFormat then
  begin
    abar.DisplayFormat := value;
    Invalidate;
    Exit;
  end;
  if pname = SRpSRotation then
  begin
    if TryStrToCurr(value, cvalue) then
      abar.Rotation := Round(cvalue * 10);
    Exit;
  end;
  if pname = SRpSColor then
  begin
    abar.BColor := StrToIntDef(value, abar.BColor);
    Invalidate;
    Exit;
  end;
  if pname = SRpSBackColor then
  begin
    abar.BackColor := StrToIntDef(value, abar.BackColor);
    Invalidate;
    Exit;
  end;
  if pname = SRpTruncatedPDF417 then
  begin
    abar.Truncated := StrToBoolDef(value, abar.Truncated);
    Invalidate;
    Exit;
  end;
  if pname = SRpNumCols then
  begin
    abar.NumColumns := StrToIntDef(value, abar.NumColumns);
    Invalidate;
    Exit;
  end;
  if pname = SRpNumRows then
  begin
    abar.NumRows := StrToIntDef(value, abar.NumRows);
    Invalidate;
    Exit;
  end;
  if pname = SRpECCLevel then
  begin
    abar.ECCLevel := StringECCToInteger(AnsiString(value));
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpBarcodeInterface.GetProperty(pname: WideString): WideString;
var
  abar: TRpBarcode;
begin
  abar := TRpBarcode(printitem);
  if not Assigned(abar) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;
  if pname = SrpSBarcodeType then Result := BarcodeTypeStrings[abar.Typ]
  else if pname = SrpSChecksum then Result := BoolToStr(abar.Checksum, True)
  else if pname = SrpSTransparent then Result := BoolToStr(abar.Transparent, True)
  else if pname = SrpSModul then Result := gettextfromtwips(abar.Modul)
  else if pname = SrpSRatio then Result := FormatCurr('#####0.00', abar.Ratio)
  else if pname = SrpSExpression then Result := abar.Expression
  else if pname = SrpSDisplayFormat then Result := abar.DisplayFormat
  else if pname = SRpSRotation then Result := FormatCurr('#####0.0', abar.Rotation / 10)
  else if pname = SrpSColor then Result := IntToStr(abar.BColor)
  else if pname = SrpSBackColor then Result := IntToStr(abar.BackColor)
  else if pname = SRpTruncatedPDF417 then Result := BoolToStr(abar.Truncated, True)
  else if pname = SRpNumRows then Result := IntToStr(abar.NumRows)
  else if pname = SRpNumCols then Result := IntToStr(abar.NumColumns)
  else if pname = SRpECCLevel then Result := WideString(ECCToString(abar.ECCLevel))
  else Result := inherited GetProperty(pname);
end;

procedure TRpBarcodeInterface.GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings);
var
  it: TRpBarCodeType;
begin
  if pname = SRpSBarcodeType then
  begin
    lpossiblevalues.Clear;
    for it := bcCode_2_5_interleaved to bcCodeQr do
      lpossiblevalues.Add(BarcodeTypeStrings[it]);
    Exit;
  end;
  if pname = SRpSRotation then
  begin
    lpossiblevalues.Clear;
    lpossiblevalues.Add(FormatCurr('##0.0', 0));
    lpossiblevalues.Add(FormatCurr('##0.0', 90));
    lpossiblevalues.Add(FormatCurr('##0.0', 180));
    lpossiblevalues.Add(FormatCurr('##0.0', 270));
    Exit;
  end;
  if pname = SRpECCLevel then
  begin
    lpossiblevalues.Clear;
    FillECCValues(lpossiblevalues);
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

procedure TRpBarcodeInterface.Paint;
var
  abar: TRpBarcode;
begin
  abar := TRpBarcode(printitem);
  if not Assigned(abar) or (csDestroying in abar.ComponentState) then
    Exit;

  // Draws the expression (as the VCL designer)
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(0, 0, abar.Expression);
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psDashDotDot;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  DrawSelected;
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfsectionintlcl                              }
{       Section designer interface for LCL              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfsectionintlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Types,
  Graphics, Forms, Controls, ExtCtrls, Dialogs,
  rpmdobinsintlcl, rpprintitem, rpdrawitem, rplabelitem,
  rpmdbarcode, rpmdchart, rpsection, rpreport, rptypes,
  rpmdflabelintlcl, rpmdfdrawintlcl, rpmdfbarcodeintlcl, rpmdfchartintlcl,
  rpmdconsts, rpgraphutilslcl, rpmunits;

type
  TRpSectionInterface = class;

  // The custom control hosting the section canvas and its child items
  TRpSectionIntf = class(TCustomControl)
  private
    secint: TRpSectionInterface;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    OnPosChange: TNotifyEvent;
    procedure ExecuteMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ExecuteMouseMove(Shift: TShiftState; X, Y: Integer);
    procedure ExecuteMouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    constructor Create(AOwner: TComponent); override;
  end;

  // The section interface managing child controls, layout, grid, and selection
  TRpSectionInterface = class(TRpSizeInterface)
  private
    FOnDestroy: TNotifyEvent;
    FInterface: TRpSectionIntf;
    FOnPosChange: TNotifyEvent;
    FXOrigin, FYOrigin: Integer;
    FRectangle: TRpRectangle;
    FRectangle2: TRpRectangle;
    FRectangle3: TRpRectangle;
    FRectangle4: TRpRectangle;
    procedure ClearRectangles;
    procedure SetOnPosChange(AValue: TNotifyEvent);
    procedure CalcNewCoords(var NewLeft, NewTop, NewWidth, NewHeight, X, Y: Integer);
    function DoSelectControls(NewLeft, NewTop, NewWidth, NewHeight: Integer): Boolean;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure SetScale(nscale: Double); override;
  public
    BackBitmap: TBitmap;
    childlist: TList;
    freportstructure: TComponent;
    procedure UpdateBack;
    procedure UpdatePos; override;
    property SectionControl: TRpSectionIntf read FInterface;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    destructor Destroy; override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
    function CreateChild(compo: TRpCommonPosComponent): TRpSizePosInterface;
    procedure CreateChilds;
    procedure DeleteChild(achild: TRpSizePosInterface);
    property OnPosChange: TNotifyEvent read FOnPosChange write SetOnPosChange;
    procedure ExecuteMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ExecuteMouseMove(Shift: TShiftState; X, Y: Integer);
    procedure ExecuteMouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;

implementation

{ TRpSectionIntf }

constructor TRpSectionIntf.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := clWhite;
end;

procedure TRpSectionIntf.Paint;
var
  rec: TRect;
  rep: TRpReport;
begin
  rec.Left := 0;
  rec.Top := 0;
  rec.Right := Width;
  rec.Bottom := Height;

  Canvas.Brush.Color := clWhite;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(rec);

  if Assigned(secint) and Assigned(secint.printitem) and Assigned(secint.printitem.Report) then
  begin
    rep := TRpReport(secint.printitem.Report);
    if rep.GridVisible then
    begin
      DrawGrid(Canvas, rep.GridWidth, rep.GridHeight, Width, Height,
        rep.GridColor, rep.GridLines, 0, 0, secint.Scale);
    end;
  end;
end;

procedure TRpSectionIntf.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Assigned(secint) then
    secint.MouseDown(Button, Shift, X, Y);
end;

procedure TRpSectionIntf.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if MouseCapture and Assigned(secint) then
    secint.MouseMove(Shift, X, Y);
end;

procedure TRpSectionIntf.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Assigned(secint) then
    secint.MouseUp(Button, Shift, X, Y);
end;

procedure TRpSectionIntf.ExecuteMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseDown(Button, Shift, X, Y);
end;

procedure TRpSectionIntf.ExecuteMouseMove(Shift: TShiftState; X, Y: Integer);
begin
  MouseMove(Shift, X, Y);
end;

procedure TRpSectionIntf.ExecuteMouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseUp(Button, Shift, X, Y);
end;

{ TRpSectionInterface }

constructor TRpSectionInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
var
  opts: TControlStyle;
begin
  if not (pritem is TRpSection) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);

  opts := ControlStyle;
  Include(opts, csCaptureMouse);
  ControlStyle := opts;

  childlist := TList.Create;
  FInterface := TRpSectionIntf.Create(Self);
  FInterface.secint := Self;
  Visible := False;
end;

destructor TRpSectionInterface.Destroy;
var
  i: Integer;
begin
  if Assigned(FOnDestroy) then
    FOnDestroy(Self);

  ClearRectangles;
  FreeAndNil(BackBitmap);

  for i := 0 to childlist.Count - 1 do
    TObject(childlist[i]).Free;
  FreeAndNil(childlist);

  inherited Destroy;
end;

procedure TRpSectionInterface.ClearRectangles;
begin
  FreeAndNil(FRectangle);
  FreeAndNil(FRectangle2);
  FreeAndNil(FRectangle3);
  FreeAndNil(FRectangle4);
end;

procedure TRpSectionInterface.SetOnPosChange(AValue: TNotifyEvent);
begin
  FOnPosChange := AValue;
  if Assigned(FInterface) then
    FInterface.OnPosChange := AValue;
end;

procedure TRpSectionInterface.SetScale(nscale: Double);
var
  i: Integer;
begin
  inherited SetScale(nscale);
  for i := 0 to childlist.Count - 1 do
    TRpSizePosInterface(childlist[i]).Scale := nscale;
  if Assigned(FInterface) then
    FInterface.Invalidate;
end;

procedure TRpSectionInterface.UpdateBack;
begin
  FreeAndNil(BackBitmap);
  if Assigned(FInterface) then
    FInterface.Invalidate;
end;

procedure TRpSectionInterface.UpdatePos;
var
  NewWidth, NewHeight: Integer;
begin
  inherited UpdatePos;
  if Assigned(FInterface) then
  begin
    NewWidth := twipstopixels(fprintitem.Width, Scale);
    NewHeight := twipstopixels(fprintitem.Height, Scale);
    if Parent <> FInterface.Parent then
      FInterface.Parent := Parent;
    FInterface.SetBounds(Left, Top, NewWidth, NewHeight);
    FInterface.Invalidate;
  end;
end;

function TRpSectionInterface.CreateChild(compo: TRpCommonPosComponent): TRpSizePosInterface;
var
  labelint: TRpSizePosInterface;
begin
  labelint := nil;
  if compo is TRpLabel then
    labelint := TRpLabelInterface.Create(Self, compo)
  else if compo is TRpExpression then
    labelint := TRpExpressionInterface.Create(Self, compo)
  else if compo is TRpShape then
    labelint := TRpDrawInterface.Create(Self, compo)
  else if compo is TRpImage then
    labelint := TRpImageInterface.Create(Self, compo)
  else if compo is TRpBarcode then
    labelint := TRpBarcodeInterface.Create(Self, compo)
  else if compo is TRpChart then
    labelint := TRpChartInterface.Create(Self, compo);

  if Assigned(labelint) then
  begin
    labelint.Parent := FInterface;
    labelint.Scale := Scale;
    labelint.SectionInt := Self;
    labelint.Visible := compo.Visible;
    labelint.fobjinsp := fobjinsp;
    labelint.UpdatePos;
    childlist.Add(labelint);
  end;
  Result := labelint;
end;

procedure TRpSectionInterface.CreateChilds;
var
  sec: TRpSection;
  i: Integer;
  compo: TRpCommonPosComponent;
begin
  sec := TRpSection(printitem);
  for i := 0 to sec.ReportComponents.Count - 1 do
  begin
    if sec.ReportComponents.Items[i].Component is TRpCommonPosComponent then
    begin
      compo := TRpCommonPosComponent(sec.ReportComponents.Items[i].Component);
      CreateChild(compo);
    end;
  end;
end;

procedure TRpSectionInterface.DeleteChild(achild: TRpSizePosInterface);
var
  idx: Integer;
begin
  idx := childlist.IndexOf(achild);
  if idx >= 0 then
  begin
    TObject(childlist[idx]).Free;
    childlist.Delete(idx);
  end;
end;

procedure TRpSectionInterface.CalcNewCoords(var NewLeft, NewTop, NewWidth, NewHeight, X, Y: Integer);
begin
  if X >= FXOrigin then
  begin
    NewLeft := FXOrigin;
    NewWidth := X - FXOrigin;
  end
  else
  begin
    NewLeft := X;
    NewWidth := FXOrigin - X;
  end;

  if Y >= FYOrigin then
  begin
    NewTop := FYOrigin;
    NewHeight := Y - FYOrigin;
  end
  else
  begin
    NewTop := Y;
    NewHeight := FYOrigin - Y;
  end;

  if NewLeft < 0 then NewLeft := 0;
  if NewTop < 0 then NewTop := 0;
  if Assigned(FInterface) then
  begin
    if NewLeft + NewWidth > FInterface.Width then
      NewWidth := FInterface.Width - NewLeft;
    if NewTop + NewHeight > FInterface.Height then
      NewHeight := FInterface.Height - NewTop;
  end;
  if NewHeight < CONS_MINHEIGHT then NewHeight := CONS_MINHEIGHT;
  if NewWidth < CONS_MINWIDTH then NewWidth := CONS_MINWIDTH;
end;

procedure TRpSectionInterface.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  FXOrigin := X;
  FYOrigin := Y;
  ClearRectangles;
end;

procedure TRpSectionInterface.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewLeft, NewTop, NewWidth, NewHeight: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if not (ssLeft in Shift) then Exit;
  if not Assigned(FInterface) then Exit;

  if not Assigned(FRectangle) then
  begin
    if (Abs(X - FXOrigin) < CONS_MINIMUMMOVE) and (Abs(Y - FYOrigin) < CONS_MINIMUMMOVE) then
      Exit;

    FRectangle := TRpRectangle.Create(Self);
    FRectangle2 := TRpRectangle.Create(Self);
    FRectangle3 := TRpRectangle.Create(Self);
    FRectangle4 := TRpRectangle.Create(Self);
    FRectangle.Parent := FInterface;
    FRectangle2.Parent := FInterface;
    FRectangle3.Parent := FInterface;
    FRectangle4.Parent := FInterface;
  end;

  CalcNewCoords(NewLeft, NewTop, NewWidth, NewHeight, X, Y);
  FRectangle.SetBounds(NewLeft, NewTop, NewWidth, 1);
  FRectangle2.SetBounds(NewLeft, NewTop + NewHeight, NewWidth, 1);
  FRectangle3.SetBounds(NewLeft, NewTop, 1, NewHeight);
  FRectangle4.SetBounds(NewLeft + NewWidth, NewTop, 1, NewHeight);
  if Assigned(FRectangle.Parent) then
    FRectangle.Parent.Update;
end;

procedure TRpSectionInterface.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  NewLeft, NewTop, NewWidth, NewHeight: Integer;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  if Assigned(FRectangle) then
  begin
    ClearRectangles;
    CalcNewCoords(NewLeft, NewTop, NewWidth, NewHeight, X, Y);
    DoSelectControls(NewLeft, NewTop, NewWidth, NewHeight);
  end;
end;

function TRpSectionInterface.DoSelectControls(NewLeft, NewTop, NewWidth, NewHeight: Integer): Boolean;
var
  i: Integer;
  aitem: TRpSizePosInterface;
  rec1, rec2, arec: TRect;
begin
  Result := False;
  rec1.Left := NewLeft;
  rec1.Top := NewTop;
  rec1.Right := NewLeft + NewWidth;
  rec1.Bottom := NewTop + NewHeight;

  for i := 0 to childlist.Count - 1 do
  begin
    aitem := TRpSizePosInterface(childlist[i]);
    if aitem.Visible then
    begin
      rec2.Left := aitem.Left;
      rec2.Top := aitem.Top;
      rec2.Right := aitem.Left + aitem.Width;
      rec2.Bottom := aitem.Top + aitem.Height;
      if IntersectRect(arec, rec1, rec2) then
      begin
        aitem.Selected := True;
        Result := True;
      end
      else
        aitem.Selected := False;
    end;
  end;
end;

procedure TRpSectionInterface.ExecuteMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseDown(Button, Shift, X, Y);
end;

procedure TRpSectionInterface.ExecuteMouseMove(Shift: TShiftState; X, Y: Integer);
begin
  MouseMove(Shift, X, Y);
end;

procedure TRpSectionInterface.ExecuteMouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseUp(Button, Shift, X, Y);
end;

procedure TRpSectionInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  sec: TRpSection;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  sec := TRpSection(printitem);
  lnames.Add(SrpSGroupName);
  ltypes.Add(SRpSString);
  lhints.Add('refsection.html');
  lcat.Add(SRpSection);
  if Assigned(lvalues) then lvalues.Add(sec.GroupName);
end;

procedure TRpSectionInterface.SetProperty(pname: string; value: WideString);
var
  sec: TRpSection;
begin
  sec := TRpSection(printitem);
  if pname = SrpSGroupName then
  begin
    sec.GroupName := value;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpSectionInterface.GetProperty(pname: string): WideString;
var
  sec: TRpSection;
begin
  sec := TRpSection(printitem);
  if pname = SrpSGroupName then Result := sec.GroupName
  else Result := inherited GetProperty(pname);
end;

end.

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
  rpmdconsts, rpgraphutilslcl, rpmunits, LCLType;

type
  TRpSectionInterface = class;

  // Tools for inserting components into sections
  TRpDesignTool = (dtArrow, dtLabel, dtExpression, dtShape, dtImage, dtBarcode, dtChart);

  // The custom control hosting the section canvas and its child items
  TRpSectionIntf = class(TCustomControl)
  private
    secint: TRpSectionInterface;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
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
    FDesignFrame: TObject;
    FActiveTool: TRpDesignTool;
    FOnToolDone: TNotifyEvent;
    FOnKeyDown: TKeyEvent;
    FOnPosChange: TNotifyEvent;
    FOnClearSelection: TNotifyEvent;
    FXOrigin, FYOrigin: Integer;
    FRectangle: TRpRectangle;
    FRectangle2: TRpRectangle;
    FRectangle3: TRpRectangle;
    FRectangle4: TRpRectangle;
    procedure ClearRectangles;
    procedure SetActiveTool(Value: TRpDesignTool);
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
    property DesignFrame: TObject read FDesignFrame write FDesignFrame;
    property ActiveTool: TRpDesignTool read FActiveTool write SetActiveTool;
    property OnToolDone: TNotifyEvent read FOnToolDone write FOnToolDone;
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    destructor Destroy; override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
    procedure GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings); override;
    function CreateChild(compo: TRpCommonPosComponent): TRpSizePosInterface;
    function CreateNewComponent(ATool: TRpDesignTool; ALeft, ATop, AWidth, AHeight: Integer): TRpSizePosInterface;
    procedure CreateChilds;
    procedure SyncChilds;
    procedure DeleteChild(achild: TRpSizePosInterface);
    property OnPosChange: TNotifyEvent read FOnPosChange write SetOnPosChange;
    property OnClearSelection: TNotifyEvent read FOnClearSelection write FOnClearSelection;
    procedure ExecuteMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ExecuteMouseMove(Shift: TShiftState; X, Y: Integer);
    procedure ExecuteMouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;

implementation

uses
  rpmdundocuelcl, rpmdfstruclcl;

{ TRpSectionIntf }

constructor TRpSectionIntf.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := clWhite;
  TabStop := True;
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
  if CanFocus then
    SetFocus;
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

procedure TRpSectionIntf.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Assigned(secint) and Assigned(secint.FOnKeyDown) then
    secint.FOnKeyDown(Self, Key, Shift);
end;

{ TRpSectionInterface }

constructor TRpSectionInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
var
  opts: TControlStyle;
begin
  if Assigned(pritem) and not (pritem is TRpSection) then
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
    labelint.OnSelectComponent := OnSelectComponent;
    labelint.OnMoveComponent := OnMoveComponent;
    labelint.OnGetSelectedList := OnGetSelectedList;
    if Assigned(FInterface) and Assigned(FInterface.PopupMenu) then
      labelint.PopupMenu := FInterface.PopupMenu;
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

procedure TRpSectionInterface.SyncChilds;
var
  sec: TRpSection;
  i, j: Integer;
  compo: TRpCommonPosComponent;
  found: Boolean;
  child: TRpSizePosInterface;
begin
  sec := TRpSection(printitem);
  if not Assigned(sec) then Exit;

  // 1. Remove visual children whose model component is no longer in sec.ReportComponents
  for i := childlist.Count - 1 downto 0 do
  begin
    child := TRpSizePosInterface(childlist[i]);
    found := False;
    for j := 0 to sec.ReportComponents.Count - 1 do
    begin
      if sec.ReportComponents.Items[j].Component = child.printitem then
      begin
        found := True;
        Break;
      end;
    end;
    if not found then
    begin
      child.Parent := nil;
      child.Free;
      childlist.Delete(i);
    end;
  end;

  // 2. Add visual children that are in sec.ReportComponents but not yet in childlist
  for i := 0 to sec.ReportComponents.Count - 1 do
  begin
    if sec.ReportComponents.Items[i].Component is TRpCommonPosComponent then
    begin
      compo := TRpCommonPosComponent(sec.ReportComponents.Items[i].Component);
      found := False;
      for j := 0 to childlist.Count - 1 do
      begin
        if TRpSizePosInterface(childlist[j]).printitem = compo then
        begin
          found := True;
          Break;
        end;
      end;
      if not found then
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

procedure TRpSectionInterface.SetActiveTool(Value: TRpDesignTool);
begin
  FActiveTool := Value;
  if Assigned(FInterface) then
  begin
    if FActiveTool = dtArrow then
      FInterface.Cursor := crDefault
    else
      FInterface.Cursor := crCross;
  end;
end;

function TRpSectionInterface.CreateNewComponent(ATool: TRpDesignTool; ALeft, ATop, AWidth, AHeight: Integer): TRpSizePosInterface;
var
  theowner: TComponent;
  compo: TRpCommonPosComponent;
  asizeposint: TRpSizePosInterface;
  aitem: TRpCommonListItem;
  sec: TRpSection;
  posx, posy, w, h: Integer;
  cue: TUndoCue;
  undoop: TChangeObjectOperation;
begin
  Result := nil;
  if not Assigned(printitem) or not (printitem is TRpSection) then
    Exit;
  sec := TRpSection(printitem);

  if sec.IsExternal then
    theowner := sec
  else if Assigned(sec.Report) then
    theowner := sec.Report
  else
    theowner := Self;

  if (AWidth < 15) or (AHeight < 10) then
  begin
    case ATool of
      dtLabel, dtExpression:
        begin
          w := 1500;
          h := 350;
        end;
      dtShape:
        begin
          w := 1500;
          h := 500;
        end;
      dtImage:
        begin
          w := 1500;
          h := 1500;
        end;
      dtBarcode:
        begin
          w := 2000;
          h := 800;
        end;
      dtChart:
        begin
          w := 3000;
          h := 2000;
        end;
      else
        begin
          w := 1500;
          h := 350;
        end;
    end;
  end
  else
  begin
    w := pixelstotwips(AWidth, Scale);
    h := pixelstotwips(AHeight, Scale);
  end;

  posx := pixelstotwips(ALeft, Scale);
  posy := pixelstotwips(ATop, Scale);
  if posx < 0 then posx := 0;
  if posy < 0 then posy := 0;

  compo := nil;
  case ATool of
    dtLabel:
      begin
        compo := TRpLabel.Create(theowner);
        TRpLabel(compo).Text := SRpSampleTextToLabels;
      end;
    dtExpression:
      begin
        compo := TRpExpression.Create(theowner);
        TRpExpression(compo).Expression := QuotedStr('Texto');
      end;
    dtShape:
      begin
        compo := TRpShape.Create(theowner);
        TRpShape(compo).Shape := rpsRectangle;
      end;
    dtImage:
      begin
        compo := TRpImage.Create(theowner);
      end;
    dtBarcode:
      begin
        compo := TRpBarcode.Create(theowner);
        TRpBarcode(compo).Expression := QuotedStr(SRpSampleBarCode);
      end;
    dtChart:
      begin
        compo := TRpChart.Create(theowner);
        TRpChart(compo).ValueExpression := '10';
      end;
  end;

  if not Assigned(compo) then
    Exit;

  if (compo is TRpGenTextComponent) and Assigned(sec.Report) then
    TRpReport(sec.Report).AssignDefaultFontTo(TRpGenTextComponent(compo));

  compo.PosX := posx;
  compo.PosY := posy;
  compo.Width := w;
  compo.Height := h;
  GenerateNewName(compo);

  aitem := sec.ReportComponents.Add;
  aitem.Component := compo;

  asizeposint := CreateChild(compo);
  if Assigned(asizeposint) then
  begin
    if Assigned(FOnSelectComponent) then
      FOnSelectComponent(asizeposint, False);
  end;

  // Record Undo otAdd
  if Assigned(sec.Report) and (sec.Report is TRpReport) and Assigned(TRpReport(sec.Report).UndoCue) then
  begin
    cue := TUndoCue(TRpReport(sec.Report).UndoCue);
    undoop := TChangeObjectOperation.Create(otAdd, cue.GetGroupId);
    undoop.componentName := compo.Name;
    undoop.componentClass := UpperCase(compo.ClassName);
    undoop.parentName := sec.Name;
    cue.AddAllComponentProperties(compo, undoop);
    cue.AddOperation(undoop);
    if Assigned(freportstructure) and (freportstructure is TFRpStructureLCL) then
      if Assigned(TFRpStructureLCL(freportstructure).cueview) then
        TFRpStructureLCL(freportstructure).cueview.RefreshList;
  end;

  Result := asizeposint;
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

  if FActiveTool <> dtArrow then
  begin
    ClearRectangles;
    CalcNewCoords(NewLeft, NewTop, NewWidth, NewHeight, X, Y);
    CreateNewComponent(FActiveTool, NewLeft, NewTop, NewWidth, NewHeight);
    if not (ssShift in Shift) then
    begin
      SetActiveTool(dtArrow);
      if Assigned(FOnToolDone) then
        FOnToolDone(Self);
    end;
    Exit;
  end;

  if Assigned(FRectangle) then
  begin
    ClearRectangles;
    CalcNewCoords(NewLeft, NewTop, NewWidth, NewHeight, X, Y);
    DoSelectControls(NewLeft, NewTop, NewWidth, NewHeight);
  end
  else
  begin
    // Simple click on section background -> deselect items if not Shift
    if not ((ssShift in Shift) or (ssCtrl in Shift)) then
    begin
      if Assigned(FOnClearSelection) then
        FOnClearSelection(Self);
    end;
  end;
end;

function TRpSectionInterface.DoSelectControls(NewLeft, NewTop, NewWidth, NewHeight: Integer): Boolean;
var
  i: Integer;
  aitem: TRpSizePosInterface;
  rec1, rec2, arec: TRect;
  selectedList: TList;
begin
  Result := False;
  rec1.Left := NewLeft;
  rec1.Top := NewTop;
  rec1.Right := NewLeft + NewWidth;
  rec1.Bottom := NewTop + NewHeight;

  selectedList := TList.Create;
  try
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
          selectedList.Add(aitem);
      end;
    end;

    if selectedList.Count = 0 then
    begin
      if Assigned(FOnClearSelection) then
        FOnClearSelection(Self);
    end
    else if selectedList.Count = 1 then
    begin
      Result := True;
      if Assigned(OnSelectComponent) then
        OnSelectComponent(TRpSizePosInterface(selectedList[0]), False);
    end
    else
    begin
      Result := True;
      if Assigned(FOnClearSelection) then
        FOnClearSelection(Self);
      for i := 0 to selectedList.Count - 1 do
      begin
        if Assigned(OnSelectComponent) then
          OnSelectComponent(TRpSizePosInterface(selectedList[i]), True);
      end;
    end;
  finally
    selectedList.Free;
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
  if not Assigned(sec) then Exit;

  if sec.SectionType in [rpsecpfooter, rpsecpheader, rpsecgheader, rpsecgfooter] then
  begin
    lnames.Add(SRpGeneralPageHeader);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.Global, True));
  end;

  if sec.SectionType <> rpsecpfooter then
  begin
    lnames.Add(SRpSAutoExpand);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.AutoExpand, True));

    lnames.Add(SRpSAutoContract);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.AutoContract, True));
  end;

  if sec.SectionType in [rpsecgheader, rpsecgfooter] then
  begin
    lnames.Add(SRpIniNumPage);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.IniNumPage, True));

    lnames.Add(SRpSGroupName);
    ltypes.Add(SRpSString);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(sec.GroupName);

    lnames.Add(SRpSGroupExpression);
    ltypes.Add(SRpSExpression);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(sec.ChangeExpression);

    lnames.Add(SRpSChangeBool);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.ChangeBool, True));

    if sec.SectionType = rpsecgheader then
    begin
      lnames.Add(SRpSPageRepeat);
      ltypes.Add(SRpSBool);
      lhints.Add('refsection.html');
      lcat.Add(SRpSection);
      if Assigned(lvalues) then
        lvalues.Add(BoolToStr(sec.PageRepeat, True));

      lnames.Add(SRpSForcePrint);
      ltypes.Add(SRpSBool);
      lhints.Add('refsection.html');
      lcat.Add(SRpSection);
      if Assigned(lvalues) then
        lvalues.Add(BoolToStr(sec.FooterAtReportEnd, True));
    end;
  end;

  if sec.SectionType in [rpsecgheader, rpsecgfooter, rpsecdetail] then
  begin
    lnames.Add(SRpSBeginPage);
    ltypes.Add(SRpSExpression);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(sec.BeginPageExpression);

    lnames.Add(SRpSkipPage);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.SkipPage, True));

    lnames.Add(SRPAlignBottom);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.AlignBottom, True));

    lnames.Add(SRPHorzDesp);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.HorzDesp, True));

    lnames.Add(SRPVertDesp);
    ltypes.Add(SRpSBool);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(BoolToStr(sec.VertDesp, True));

    lnames.Add(SRpSSkipType);
    ltypes.Add(SRpSList);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(RpSkipTypeToText(sec.SkipType));

    lnames.Add(SRpSSkipToPage);
    ltypes.Add(SRpSExpression);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(sec.SkipToPageExpre);

    lnames.Add(SRpChildSubRep);
    ltypes.Add(SRpSList);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(sec.GetChildSubReportName);
  end;
end;

procedure TRpSectionInterface.SetProperty(pname: string; value: WideString);
var
  sec: TRpSection;
begin
  sec := TRpSection(printitem);
  if not Assigned(sec) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;

  if pname = SRpGeneralPageHeader then
  begin
    sec.Global := StrToBool(value);
    Exit;
  end;
  if pname = SRpSAutoExpand then
  begin
    sec.AutoExpand := StrToBool(value);
    Exit;
  end;
  if pname = SRpSAutoContract then
  begin
    sec.AutoContract := StrToBool(value);
    Exit;
  end;
  if pname = SRpIniNumPage then
  begin
    sec.IniNumPage := StrToBool(value);
    Exit;
  end;
  if pname = SRpSGroupName then
  begin
    sec.GroupName := value;
    Exit;
  end;
  if pname = SRpSGroupExpression then
  begin
    sec.ChangeExpression := value;
    Exit;
  end;
  if pname = SRpSChangeBool then
  begin
    sec.ChangeBool := StrToBool(value);
    Exit;
  end;
  if pname = SRpSPageRepeat then
  begin
    sec.PageRepeat := StrToBool(value);
    Exit;
  end;
  if pname = SRpSForcePrint then
  begin
    sec.FooterAtReportEnd := StrToBool(value);
    Exit;
  end;
  if pname = SRpSBeginPage then
  begin
    sec.BeginPageExpression := value;
    Exit;
  end;
  if pname = SRpSkipPage then
  begin
    sec.SkipPage := StrToBool(value);
    Exit;
  end;
  if pname = SRPAlignBottom then
  begin
    sec.AlignBottom := StrToBool(value);
    Exit;
  end;
  if pname = SRpHorzDesp then
  begin
    sec.HorzDesp := StrToBool(value);
    Exit;
  end;
  if pname = SRPVertDesp then
  begin
    sec.VertDesp := StrToBool(value);
    Exit;
  end;
  if pname = SRpSSkipType then
  begin
    sec.SkipType := StringToRpSkipType(value);
    Exit;
  end;
  if pname = SRpSSkipToPage then
  begin
    sec.SkipToPageExpre := value;
    Exit;
  end;
  if pname = SRpChildSubRep then
  begin
    sec.SetChildSubReportByName(value);
    Exit;
  end;

  inherited SetProperty(pname, value);
end;

function TRpSectionInterface.GetProperty(pname: string): WideString;
var
  sec: TRpSection;
begin
  sec := TRpSection(printitem);
  if not Assigned(sec) then
  begin
    Result := inherited GetProperty(pname);
    Exit;
  end;

  if pname = SRpGeneralPageHeader then Result := BoolToStr(sec.Global, True)
  else if pname = SRpSAutoExpand then Result := BoolToStr(sec.AutoExpand, True)
  else if pname = SRpSAutoContract then Result := BoolToStr(sec.AutoContract, True)
  else if pname = SRpIniNumPage then Result := BoolToStr(sec.IniNumPage, True)
  else if pname = SRpSGroupName then Result := sec.GroupName
  else if pname = SRpSGroupExpression then Result := sec.ChangeExpression
  else if pname = SRpSChangeBool then Result := BoolToStr(sec.ChangeBool, True)
  else if pname = SRpSPageRepeat then Result := BoolToStr(sec.PageRepeat, True)
  else if pname = SRpSForcePrint then Result := BoolToStr(sec.FooterAtReportEnd, True)
  else if pname = SRpSBeginPage then Result := sec.BeginPageExpression
  else if pname = SRpSkipPage then Result := BoolToStr(sec.SkipPage, True)
  else if pname = SRPAlignBottom then Result := BoolToStr(sec.AlignBottom, True)
  else if pname = SRpHorzDesp then Result := BoolToStr(sec.HorzDesp, True)
  else if pname = SRPVertDesp then Result := BoolToStr(sec.VertDesp, True)
  else if pname = SRpSSkipType then Result := RpSkipTypeToText(sec.SkipType)
  else if pname = SRpSSkipToPage then Result := sec.SkipToPageExpre
  else if pname = SRpChildSubRep then Result := sec.GetChildSubReportName
  else Result := inherited GetProperty(pname);
end;

procedure TRpSectionInterface.GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings);
var
  sec: TRpSection;
begin
  inherited GetPropertyValues(pname, lpossiblevalues);
  sec := TRpSection(printitem);
  if not Assigned(sec) then Exit;

  if pname = SRpSSkipType then
  begin
    GetSkipTypePossibleValues(lpossiblevalues);
    Exit;
  end;
  if pname = SRpChildSubRep then
  begin
    sec.GetChildSubReportPossibleValues(lpossiblevalues);
    Exit;
  end;
end;

end.

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
    procedure SetProperty(pname: WideString; value: WideString); overload; override;
    function GetProperty(pname: WideString): WideString; overload; override;
    procedure SetProperty(pname: WideString; stream: TMemoryStream); overload; override;
    procedure GetProperty(pname: WideString; var Stream: TMemoryStream); overload; override;
    procedure GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings); override;
    // Draws the section background (image and grid) as the design surface
    procedure DrawBackground(ACanvas: TCanvas; AWidth, AHeight: Integer);
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
begin
  if Assigned(secint) then
    secint.DrawBackground(Canvas, Width, Height)
  else
  begin
    rec := Rect(0, 0, Width, Height);
    Canvas.Brush.Color := clWhite;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(rec);
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
    // The item keeps its own context menu (component actions and the
    // designer commands, executed by the design frame)
    labelint.OnDesignCommand := OnDesignCommand;
    labelint.OnDesignCommandEnabled := OnDesignCommandEnabled;
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
        TRpExpression(compo).Expression := QuotedStr(SRpSampleTextToLabels);
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

  procedure AddProp(const AName, AType: WideString);
  begin
    lnames.Add(AName);
    ltypes.Add(AType);
    lhints.Add('refsection.html');
    lcat.Add(SRpSection);
    if Assigned(lvalues) then
      lvalues.Add(GetProperty(AName));
  end;

begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  sec := TRpSection(printitem);
  if not Assigned(sec) then Exit;

  // Same order, types and section types as the VCL designer
  if sec.SectionType in [rpsecpfooter, rpsecpheader, rpsecgheader, rpsecgfooter] then
    AddProp(SRpGeneralPageHeader, SRpSBool);

  if sec.SectionType <> rpsecpfooter then
  begin
    AddProp(SRpSAutoExpand, SRpSBool);
    AddProp(SRpSAutoContract, SRpSBool);
  end;

  if sec.SectionType in [rpsecgheader, rpsecgfooter] then
  begin
    AddProp(SRpIniNumPage, SRpSBool);
    AddProp(SRpSGroupName, SRpSString);
    AddProp(SRpSGroupExpression, SRpSExpression);
    AddProp(SRpSChangeBool, SRpSBool);
    if sec.SectionType = rpsecgheader then
    begin
      AddProp(SRpSPageRepeat, SRpSBool);
      AddProp(SRpSForcePrint, SRpSBool);
    end;
  end;

  if sec.SectionType in [rpsecgheader, rpsecgfooter, rpsecdetail] then
  begin
    AddProp(SRpSBeginPage, SRpSExpression);
    AddProp(SRpSkipPage, SRpSBool);
    AddProp(SRPAlignBottom, SRpSBool);
    AddProp(SRPHorzDesp, SRpSBool);
    AddProp(SRPVertDesp, SRpSBool);
    // Skip page expression
    AddProp(SRpSSkipType, SRpSList);
    AddProp(SRpSSkipToPage, SRpSExpression);
    AddProp(SRpSHSkipExpre, SRpSExpression);
    AddProp(SRpSHRelativeSkip, SRpSBool);
    AddProp(SRpSVSkipExpre, SRpSExpression);
    AddProp(SRpSVRelativeSkip, SRpSBool);
    // Child Subreport
    AddProp(SRpChildSubRep, SRpSList);
  end;

  if sec.SectionType = rpsecpfooter then
    AddProp(SRpSForcePrint, SRpSBool);

  // External section
  AddProp(SRpSExternalPath, SRpSExternalPath);
  AddProp(SRpSExternalData, SRpSExternalData);
  // Background
  AddProp(SrpSBackExpression, SRpSExpression);
  AddProp(SrpSImage, SRpSImage);
  AddProp(SRpDPIRes, SRpSString);
  AddProp(SRpSBackStyle, SRpSList);
  AddProp(SRpDrawStyle, SRpSList);
  AddProp(SRpCached, SRpSList);
end;

procedure TRpSectionInterface.SetProperty(pname: WideString; value: WideString);
var
  sec: TRpSection;
begin
  sec := TRpSection(printitem);
  if not Assigned(sec) then
  begin
    inherited SetProperty(pname, value);
    Exit;
  end;

  if (pname = SRpSWidth) or (pname = SRpSHeight) then
    UpdateBack;
  if pname = SRpGeneralPageHeader then
  begin
    sec.Global := StrToBoolDef(value, sec.Global);
    Exit;
  end;
  if pname = SRpSExternalData then
    Exit;
  if pname = SRpSAutoExpand then
  begin
    sec.AutoExpand := StrToBoolDef(value, sec.AutoExpand);
    Exit;
  end;
  if pname = SRpSAutoContract then
  begin
    sec.AutoContract := StrToBoolDef(value, sec.AutoContract);
    Exit;
  end;
  if pname = SRpIniNumPage then
  begin
    sec.IniNumPage := StrToBoolDef(value, sec.IniNumPage);
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
    sec.ChangeBool := StrToBoolDef(value, sec.ChangeBool);
    Exit;
  end;
  if pname = SRpSPageRepeat then
  begin
    sec.PageRepeat := StrToBoolDef(value, sec.PageRepeat);
    Exit;
  end;
  if pname = SRpSForcePrint then
  begin
    sec.FooterAtReportEnd := StrToBoolDef(value, sec.FooterAtReportEnd);
    Exit;
  end;
  if pname = SRpSBeginPage then
  begin
    sec.BeginPageExpression := value;
    Exit;
  end;
  if pname = SRpSkipPage then
  begin
    sec.SkipPage := StrToBoolDef(value, sec.SkipPage);
    Exit;
  end;
  if pname = SRPAlignBottom then
  begin
    sec.AlignBottom := StrToBoolDef(value, sec.AlignBottom);
    Exit;
  end;
  if pname = SRpHorzDesp then
  begin
    sec.HorzDesp := StrToBoolDef(value, sec.HorzDesp);
    Exit;
  end;
  if pname = SRPVertDesp then
  begin
    sec.VertDesp := StrToBoolDef(value, sec.VertDesp);
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
  if pname = SRpSHSkipExpre then
  begin
    sec.SkipExpreH := value;
    Exit;
  end;
  if pname = SRpSHRelativeSkip then
  begin
    sec.SkipRelativeH := StrToBoolDef(value, sec.SkipRelativeH);
    Exit;
  end;
  if pname = SRpSVSkipExpre then
  begin
    sec.SkipExpreV := value;
    Exit;
  end;
  if pname = SRpSVRelativeSkip then
  begin
    sec.SkipRelativeV := StrToBoolDef(value, sec.SkipRelativeV);
    Exit;
  end;
  if pname = SRpChildSubRep then
  begin
    sec.SetChildSubReportByName(value);
    Exit;
  end;
  if pname = SRpSExternalPath then
  begin
    sec.ExternalFilename := Trim(value);
    Exit;
  end;
  if pname = SRpSBackExpression then
  begin
    sec.BackExpression := value;
    // A background expression replaces the stored image
    if Length(Trim(value)) > 0 then
      sec.Stream.SetSize(0);
    UpdateBack;
    Exit;
  end;
  if pname = SRpDPIRes then
  begin
    sec.DPIRes := StrToIntDef(value, sec.DPIRes);
    if sec.DPIRes <= 0 then
      sec.DPIRes := 100;
    UpdateBack;
    Exit;
  end;
  if pname = SRpSBackStyle then
  begin
    sec.BackStyle := StrToBackStyle(value);
    Exit;
  end;
  if pname = SRpDrawStyle then
  begin
    sec.DrawStyle := StringDrawStyleToDrawStyle(value);
    UpdateBack;
    Exit;
  end;
  if pname = SRpCached then
  begin
    sec.CachedImage := StringCachedImageToCachedImage(value);
    UpdateBack;
    Exit;
  end;

  inherited SetProperty(pname, value);
end;

function TRpSectionInterface.GetProperty(pname: WideString): WideString;
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
  else if pname = SRpSHSkipExpre then Result := sec.SkipExpreH
  else if pname = SRpSHRelativeSkip then Result := BoolToStr(sec.SkipRelativeH, True)
  else if pname = SRpSVSkipExpre then Result := sec.SkipExpreV
  else if pname = SRpSVRelativeSkip then Result := BoolToStr(sec.SkipRelativeV, True)
  else if pname = SRpChildSubRep then Result := sec.GetChildSubReportName
  else if pname = SRpSExternalPath then Result := sec.ExternalFilename
  else if pname = SRpSExternalData then Result := sec.GetExternalDataDescription
  else if pname = SrpSBackExpression then Result := sec.BackExpression
  else if pname = SRpDPIRes then Result := IntToStr(sec.DPIRes)
  else if pname = SrpSImage then
    Result := '[' + FormatFloat('###,###0.00', sec.Stream.Size / 1024) + SRpKbytes + ']'
  else if pname = SRpSBackStyle then Result := BackStyleToStr(sec.BackStyle)
  else if pname = SRpDrawStyle then Result := RpDrawStyleToString(sec.DrawStyle)
  else if pname = SRpCached then Result := RpCachedImageToString(sec.CachedImage)
  else Result := inherited GetProperty(pname);
end;

procedure TRpSectionInterface.SetProperty(pname: WideString; stream: TMemoryStream);
var
  sec: TRpSection;
begin
  sec := TRpSection(printitem);
  if Assigned(sec) and (pname = SrpSImage) then
  begin
    sec.Stream := stream;
    if sec.Stream.Size > 0 then
      sec.BackExpression := '';
    UpdateBack;
    Exit;
  end;
  inherited SetProperty(pname, stream);
end;

procedure TRpSectionInterface.GetProperty(pname: WideString; var Stream: TMemoryStream);
begin
  if Assigned(printitem) and (pname = SrpSImage) then
  begin
    Stream := TRpSection(printitem).Stream;
    Exit;
  end;
  inherited GetProperty(pname, Stream);
end;

procedure TRpSectionInterface.GetPropertyValues(pname: WideString; lpossiblevalues: TRpWideStrings);
var
  sec: TRpSection;
begin
  if pname = SRpCached then
  begin
    lpossiblevalues.Clear;
    GetCachedImageDescriptions(lpossiblevalues);
    Exit;
  end;
  if pname = SRpSSkipType then
  begin
    lpossiblevalues.Clear;
    GetSkipTypePossibleValues(lpossiblevalues);
    Exit;
  end;
  if pname = SRpSBackStyle then
  begin
    lpossiblevalues.Clear;
    GetBackStyleDescriptions(lpossiblevalues);
    Exit;
  end;
  if pname = SRpDrawStyle then
  begin
    lpossiblevalues.Clear;
    GetDrawStyleDescriptions(lpossiblevalues);
    Exit;
  end;
  if pname = SRpChildSubRep then
  begin
    sec := TRpSection(printitem);
    if Assigned(sec) then
      sec.GetChildSubReportPossibleValues(lpossiblevalues);
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

procedure TRpSectionInterface.DrawBackground(ACanvas: TCanvas; AWidth, AHeight: Integer);
var
  rep: TRpReport;
  sec: TRpSection;
  rec, recsrc: TRect;
  abitmap: TBitmap;
  astream: TMemoryStream;
  dpi: Integer;
  dodrawgrid: Boolean;
  errormessage: string;
begin
  errormessage := '';
  rec := Rect(0, 0, AWidth, AHeight);
  ACanvas.Brush.Color := clWhite;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.FillRect(rec);
  sec := TRpSection(printitem);
  if not Assigned(sec) or not Assigned(sec.Report) then
    Exit;
  rep := TRpReport(sec.Report);
  dodrawgrid := rep.GridVisible;
  // Background image of the section (stream or expression), drawn once in
  // BackBitmap with the grid (as the VCL designer)
  if Assigned(BackBitmap) and ((BackBitmap.Width <> AWidth) or (BackBitmap.Height <> AHeight)) then
    FreeAndNil(BackBitmap);
  if not Assigned(BackBitmap) and
     ((sec.Stream.Size > 0) or (Length(Trim(sec.BackExpression)) > 0)) then
  begin
    BackBitmap := TBitmap.Create;
    try
      BackBitmap.SetSize(AWidth, AHeight);
      BackBitmap.Canvas.Brush.Color := clWhite;
      BackBitmap.Canvas.Brush.Style := bsSolid;
      BackBitmap.Canvas.FillRect(rec);
      astream := sec.GetStream;
      abitmap := TBitmap.Create;
      try
        if Assigned(astream) and DecodeImageStream(astream, abitmap) then
        begin
          rec := Rect(0, 0, AWidth - 1, AHeight - 1);
          dpi := Round(Screen.PixelsPerInch * Scale);
          case sec.DrawStyle of
            rpDrawFull:
              begin
                rec.Bottom := Round(abitmap.Height / sec.dpires * dpi) - 1;
                rec.Right := Round(abitmap.Width / sec.dpires * dpi) - 1;
                BackBitmap.Canvas.StretchDraw(rec, abitmap);
              end;
            rpDrawStretch:
              begin
                recsrc := Rect(0, 0, abitmap.Width, abitmap.Height);
                DrawBitmap(BackBitmap.Canvas, abitmap, rec, recsrc);
              end;
            rpDrawCrop:
              begin
                recsrc := Rect(0, 0, rec.Right - rec.Left, rec.Bottom - rec.Top);
                DrawBitmap(BackBitmap.Canvas, abitmap, rec, recsrc);
              end;
            rpDrawTile, rpDrawTiledpi:
              DrawStyledBitmap(BackBitmap.Canvas, abitmap, rec, sec.DrawStyle,
                sec.dpires, Scale);
          end;
        end;
      finally
        abitmap.Free;
      end;
      if dodrawgrid then
        DrawGrid(BackBitmap.Canvas, rep.GridWidth, rep.GridHeight,
          BackBitmap.Width, BackBitmap.Height, rep.GridColor, rep.GridLines, 0, 0, Scale);
    except
      on E: Exception do
      begin
        FreeAndNil(BackBitmap);
        errormessage := SrpSInvBackImage + '-' + E.Message;
      end;
    end;
  end;
  if Assigned(BackBitmap) then
    ACanvas.Draw(0, 0, BackBitmap)
  else if dodrawgrid then
    DrawGrid(ACanvas, rep.GridWidth, rep.GridHeight, AWidth, AHeight,
      rep.GridColor, rep.GridLines, 0, 0, Scale);
  if Length(errormessage) > 0 then
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.TextOut(0, 0, errormessage);
  end;
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfdesignlcl                                  }
{       Design frame of the Main form for LCL           }
{       Used by a subreport                             }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfdesignlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Types,
  Graphics, Controls, Forms, Dialogs, Menus, ExtCtrls, LMessages, LCLType,
  rprulerlcl, rpmdobinsintlcl, rpmdfsectionintlcl,
  rpgraphutilslcl, rpsubreport, rpsection, rpreport, rpmunits, rptypes, rpcompobase, rpprintitem,
  rpmdconsts;

type
  TFRpDesignFrameLCL = class;
  TRpPaintEventPanel = class;

  // A ScrollBox for sections with continuous scroll tracking
  TRpScrollBox = class(TScrollBox)
  private
    FOnScroll: TNotifyEvent;
  protected
    procedure WMVScroll(var Message: TLMScroll); message LM_VSCROLL;
    procedure WMHScroll(var Message: TLMScroll); message LM_HSCROLL;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
  end;

  // Right edge panel for adjusting section width
  TRpPanelRight = class(TPanel)
  private
    FFrame: TFRpDesignFrameLCL;
    FRectangle: TRpRectangle;
    FRectangle2: TRpRectangle;
    FRectangle3: TRpRectangle;
    FRectangle4: TRpRectangle;
    FXOrigin, FYOrigin: Integer;
    FBlocked: Boolean;
    procedure ClearRectangles;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    Section: TRpSection;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  // Section title bar panel (draggable vertically to resize section height)
  TRpPaintEventPanel = class(TPanel)
  private
    FOnPaint: TNotifyEvent;
    Updating: Boolean;
    FOnPosChange: TNotifyEvent;
    FFrame: TFRpDesignFrameLCL;
    FRectangle: TRpRectangle;
    FRectangle2: TRpRectangle;
    FRectangle3: TRpRectangle;
    FRectangle4: TRpRectangle;
    FXOrigin, FYOrigin: Integer;
    FBlocked: Boolean;
    allowselect: Boolean;
    procedure ClearRectangles;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    CaptionText: WideString;
    Section: TRpSection;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;
    property OnPosChange: TNotifyEvent read FOnPosChange write FOnPosChange;
  end;

  // The main Visual Designer Frame
  TFRpDesignFrameLCL = class(TFrame)
    PTop: TPanel;
    PLeft: TPanel;
  private
    panelheight: Integer;
    PSection: TRpPaintEventPanel;
    FReport: TRpReport;
    FObjInsp: TComponent;
    FSubReport: TRpSubreport;
    FScale: Double;
    CONS_RULER_LEFT: Integer;
    CONS_RIGHTPWIDTH: Integer;
    FSizeModifier: TRpSizeModifier;
    FSelectedItems: TList;
    FUpdatingSubreport: Boolean;
    FActiveTool: TRpDesignTool;
    FOnToolChange: TNotifyEvent;
    FPopupMenu: TPopupMenu;
    MDelete: TMenuItem;
    MBringToFront: TMenuItem;
    MSendToBack: TMenuItem;
    MSelectAll: TMenuItem;
    procedure SetReport(Value: TRpReport);
    procedure SetObjInsp(Value: TComponent);
    procedure SecPosChange(Sender: TObject);
    procedure SetScale(nvalue: Double);
    procedure SetActiveTool(Value: TRpDesignTool);
    procedure SectionToolDone(Sender: TObject);
    procedure SizeModifierChange(Sender: TObject);
    procedure ClearSelectionEvent(Sender: TObject);
    procedure PopupMenuPopup(Sender: TObject);
    procedure PopupDeleteClick(Sender: TObject);
    procedure PopupBringToFrontClick(Sender: TObject);
    procedure PopupSendToBackClick(Sender: TObject);
    procedure PopupSelectAllClick(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Resize; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    freportstructure: TComponent;
    SectionScrollBox: TRpScrollBox;
    secinterfaces: TList;
    leftrulers: TList;
    toptitles: TList;
    righttitles: TList;
    TopRuler: TRpRulerLCL;
    procedure SectionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure InvalidateCaptions;
    procedure UpdateInterface(refreshobjinsp: Boolean);
    procedure ShowAllHidden;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure UpdateSelection(force: Boolean);
    procedure SelectDataItem(data: TObject);
    procedure SelectSubReport(subreport: TRpSubReport);
    procedure SelectComponent(AComp: TRpSizeInterface; AddToSelection: Boolean);
    procedure ClearSelection;
    function GetSelectedItemsList: TList;
    procedure MoveSelectedComponents(ALeader: TRpSizeInterface; ADeltaXTwips, ADeltaYTwips: Integer);
    procedure DeleteSelection;
    procedure BringSelectionToFront;
    procedure SendSelectionToBack;
    procedure SelectAll;
    property Report: TRpReport read FReport write SetReport;
    property ObjInsp: TComponent read FObjInsp write SetObjInsp;
    property Scale: Double read FScale write SetScale;
    property CurrentSubreport: TRpSubReport read FSubReport;
    property SubReport: TRpSubReport read FSubReport;
    property SizeModifier: TRpSizeModifier read FSizeModifier;
    property SelectedItems: TList read FSelectedItems;
    property ActiveTool: TRpDesignTool read FActiveTool write SetActiveTool;
    property OnToolChange: TNotifyEvent read FOnToolChange write FOnToolChange;
    property DesignPopupMenu: TPopupMenu read FPopupMenu;
  end;

implementation

uses
  rpmdobjinsplcl, rpmdfstruclcl, rpmdundocuelcl;

{$R *.lfm}

{ TRpScrollBox }

procedure TRpScrollBox.WMVScroll(var Message: TLMScroll);
begin
  inherited WMVScroll(Message);
  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

procedure TRpScrollBox.WMHScroll(var Message: TLMScroll);
begin
  inherited WMHScroll(Message);
  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

function TRpScrollBox.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

procedure TRpScrollBox.ScrollBy(DeltaX, DeltaY: Integer);
begin
  inherited ScrollBy(DeltaX, DeltaY);
  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

{ TRpPaintEventPanel }

constructor TRpPaintEventPanel.Create(AOwner: TComponent);
var
  opts: TControlStyle;
begin
  inherited Create(AOwner);
  BevelInner := bvNone;
  BevelOuter := bvNone;
  BorderStyle := bsNone;
  allowselect := True;
  opts := ControlStyle;
  Include(opts, csCaptureMouse);
  ControlStyle := opts;
  Color := clBtnFace;
end;

destructor TRpPaintEventPanel.Destroy;
begin
  ClearRectangles;
  inherited Destroy;
end;

procedure TRpPaintEventPanel.ClearRectangles;
begin
  FreeAndNil(FRectangle);
  FreeAndNil(FRectangle2);
  FreeAndNil(FRectangle3);
  FreeAndNil(FRectangle4);
end;

procedure TRpPaintEventPanel.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
  if Assigned(FOnPosChange) then
    FOnPosChange(Self);
end;

procedure TRpPaintEventPanel.Paint;
var
  rec: TRect;
begin
  inherited Paint;

  if not Updating and Assigned(FOnPaint) then
    FOnPaint(Self);

  if not Assigned(Parent) then
    Exit;

  rec := ClientRect;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(rec);

  Canvas.Pen.Color := clBtnShadow;
  Canvas.MoveTo(0, Height - 1);
  Canvas.LineTo(Width, Height - 1);

  if Assigned(Parent) and (Parent.Parent is TScrollBox) then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := clBtnText;
    Canvas.Font.Style := [fsBold];
    Canvas.TextOut(TScrollBox(Parent.Parent).HorzScrollBar.Position + 6, (Height - Canvas.TextHeight('Wg')) div 2, CaptionText);
  end
  else
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := clBtnText;
    Canvas.Font.Style := [fsBold];
    Canvas.TextOut(6, (Height - Canvas.TextHeight('Wg')) div 2, CaptionText);
  end;
end;

procedure TRpPaintEventPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Assigned(FFrame) then
  begin
    FFrame.ClearSelection;
    if Assigned(Section) then
      FFrame.SelectDataItem(Section);
  end;

  if (Cursor <> crSizeNS) or (Button <> mbLeft) then
    Exit;

  ClearRectangles;
  if Assigned(Parent) then
  begin
    FRectangle := TRpRectangle.Create(Self);
    FRectangle2 := TRpRectangle.Create(Self);
    FRectangle3 := TRpRectangle.Create(Self);
    FRectangle4 := TRpRectangle.Create(Self);
    FRectangle.Parent := Parent;
    FRectangle2.Parent := Parent;
    FRectangle3.Parent := Parent;
    FRectangle4.Parent := Parent;
    FRectangle.SetBounds(0, Top, Parent.Width, 1);
    FRectangle2.SetBounds(0, Top + Height, Parent.Width, 1);
    FRectangle3.SetBounds(0, Top, 1, Height);
    FRectangle4.SetBounds(Parent.Width - 1, Top, 1, Height);
  end;

  FXOrigin := X;
  FYOrigin := Y;
  FBlocked := True;
end;

procedure TRpPaintEventPanel.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewTop, MaxY: Integer;
  i: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if MouseCapture and Assigned(FRectangle) and Assigned(Parent) and Assigned(FFrame) then
  begin
    // Find preceding title panel
    i := 0;
    while i < FFrame.toptitles.Count do
    begin
      if FFrame.toptitles[i] = Self then
      begin
        Dec(i);
        break;
      end;
      Inc(i);
    end;

    MaxY := 0;
    if (i >= 0) and (i < FFrame.toptitles.Count) then
      MaxY := TRpPaintEventPanel(FFrame.toptitles[i]).Top + TRpPaintEventPanel(FFrame.toptitles[i]).Height;

    NewTop := Top - FYOrigin + Y;
    if NewTop < MaxY then NewTop := MaxY;
    if NewTop + Height > Parent.Height then NewTop := Parent.Height - Height;

    FRectangle.SetBounds(0, NewTop, Parent.Width, 1);
    FRectangle2.SetBounds(0, NewTop + Height, Parent.Width, 1);
    FRectangle3.SetBounds(0, NewTop, 1, Height);
    FRectangle4.SetBounds(Parent.Width - 1, NewTop, 1, Height);
    Parent.Update;
  end;
end;

procedure TRpPaintEventPanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  NewTop, MaxY, i, oldHeight: Integer;
  asection: TRpSection;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Assigned(FRectangle) and Assigned(FFrame) then
  begin
    ClearRectangles;

    i := 0;
    while i < FFrame.toptitles.Count do
    begin
      if FFrame.toptitles[i] = Self then
      begin
        Dec(i);
        break;
      end;
      Inc(i);
    end;

    MaxY := 0;
    asection := nil;
    if (i >= 0) and (i < FFrame.toptitles.Count) then
    begin
      MaxY := TRpPaintEventPanel(FFrame.toptitles[i]).Top + TRpPaintEventPanel(FFrame.toptitles[i]).Height;
      asection := TRpPaintEventPanel(FFrame.toptitles[i]).Section;
    end;

    NewTop := Top - FYOrigin + Y;
    if NewTop < MaxY then NewTop := MaxY;
    if Assigned(Parent) and (NewTop + Height > Parent.Height) then
      NewTop := Parent.Height - Height;

    if (NewTop <> Top) and Assigned(asection) then
    begin
      oldHeight := asection.Height;
      asection.Height := pixelstotwips(NewTop - MaxY, FFrame.Scale);
      if asection.Height < 0 then asection.Height := 0;

      if Assigned(FFrame.Report) and Assigned(FFrame.Report.UndoCue) and (oldHeight <> asection.Height) then
      begin
        cue := TUndoCue(FFrame.Report.UndoCue);
        op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
        op.componentName := asection.Name;
        op.componentClass := UpperCase(asection.ClassName);
        op.AddProperty('height', ptInteger, oldHeight, asection.Height);
        cue.AddOperation(op);
        if Assigned(FFrame.freportstructure) and (FFrame.freportstructure is TFRpStructureLCL) then
          if Assigned(TFRpStructureLCL(FFrame.freportstructure).cueview) then
            TFRpStructureLCL(FFrame.freportstructure).cueview.RefreshList;
      end;

      FFrame.UpdateInterface(True);
    end;
  end;
end;

{ TRpPanelRight }

constructor TRpPanelRight.Create(AOwner: TComponent);
var
  opts: TControlStyle;
begin
  inherited Create(AOwner);
  BevelInner := bvNone;
  BevelOuter := bvNone;
  BorderStyle := bsNone;
  Cursor := crSizeWE;
  Color := clBtnShadow;
  opts := ControlStyle;
  Include(opts, csCaptureMouse);
  ControlStyle := opts;
end;

destructor TRpPanelRight.Destroy;
begin
  ClearRectangles;
  inherited Destroy;
end;

procedure TRpPanelRight.ClearRectangles;
begin
  FreeAndNil(FRectangle);
  FreeAndNil(FRectangle2);
  FreeAndNil(FRectangle3);
  FreeAndNil(FRectangle4);
end;

procedure TRpPanelRight.Paint;
var
  rec: TRect;
begin
  inherited Paint;
  rec := ClientRect;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(rec);
end;

procedure TRpPanelRight.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  ClearRectangles;
  if Assigned(Parent) then
  begin
    FRectangle := TRpRectangle.Create(Self);
    FRectangle2 := TRpRectangle.Create(Self);
    FRectangle3 := TRpRectangle.Create(Self);
    FRectangle4 := TRpRectangle.Create(Self);
    FRectangle.Parent := Parent;
    FRectangle2.Parent := Parent;
    FRectangle3.Parent := Parent;
    FRectangle4.Parent := Parent;
    FRectangle.SetBounds(Left, Top, Width, 1);
    FRectangle2.SetBounds(Left, Top + Height, Width, 1);
    FRectangle3.SetBounds(Left, Top, 1, Height);
    FRectangle4.SetBounds(Left + Width, Top, 1, Height);
  end;

  FXOrigin := X;
  FYOrigin := Y;
  FBlocked := True;
end;

procedure TRpPanelRight.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewLeft: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if MouseCapture and Assigned(FRectangle) and Assigned(Parent) then
  begin
    if (Abs(X - FXOrigin) > CONS_MINIMUMMOVE) or (Abs(Y - FYOrigin) > CONS_MINIMUMMOVE) then
      FBlocked := False;

    if not FBlocked then
    begin
      NewLeft := Left - FXOrigin + X;
      if NewLeft < 0 then NewLeft := 0;
      FRectangle.SetBounds(NewLeft, Top, Width, 1);
      FRectangle2.SetBounds(NewLeft, Top + Height, Width, 1);
      FRectangle3.SetBounds(NewLeft, Top, 1, Height);
      FRectangle4.SetBounds(NewLeft + Width, Top, 1, Height);
      Parent.Update;
    end;
  end;
end;

procedure TRpPanelRight.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  NewLeft, oldWidth: Integer;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Assigned(FRectangle) then
  begin
    ClearRectangles;
    NewLeft := Left - FXOrigin + X;
    if NewLeft < 0 then NewLeft := 0;

    if Assigned(Section) and Assigned(FFrame) then
    begin
      oldWidth := Section.Width;
      Section.Width := pixelstotwips(NewLeft, FFrame.Scale);

      if Assigned(FFrame.Report) and Assigned(FFrame.Report.UndoCue) and (oldWidth <> Section.Width) then
      begin
        cue := TUndoCue(FFrame.Report.UndoCue);
        op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
        op.componentName := Section.Name;
        op.componentClass := UpperCase(Section.ClassName);
        op.AddProperty('width', ptInteger, oldWidth, Section.Width);
        cue.AddOperation(op);
        if Assigned(FFrame.freportstructure) and (FFrame.freportstructure is TFRpStructureLCL) then
          if Assigned(TFRpStructureLCL(FFrame.freportstructure).cueview) then
            TFRpStructureLCL(FFrame.freportstructure).cueview.RefreshList;
      end;

      FFrame.UpdateInterface(True);
    end;
  end;
end;

{ TFRpDesignFrameLCL }

constructor TFRpDesignFrameLCL.Create(AOwner: TComponent);
var
  itemSep: TMenuItem;
begin
  inherited Create(AOwner);

  FScale := 1.0;
  CONS_RIGHTPWIDTH := ScaleDPI(5);
  PLeft.Width := ScaleDpi(20);
  PTop.Height := ScaleDpi(20);
  CONS_RULER_LEFT := PLeft.Width;

  PTop.DoubleBuffered := True;
  PTop.ParentColor := False;
  PTop.Color := clBtnFace;
  PLeft.DoubleBuffered := True;
  PLeft.ParentColor := False;
  PLeft.Color := clBtnFace;

  TopRuler := TRpRulerLCL.Create(Self);
  TopRuler.RType := rHorizontal;
  TopRuler.Left := CONS_RULER_LEFT;
  TopRuler.Width := ScaleDpi(389);
  TopRuler.Height := PTop.Height;
  TopRuler.Top := 0;
  TopRuler.Parent := PTop;
  TopRuler.Scale := FScale;

  panelheight := ScaleDPI(22);

  SectionScrollBox := TRpScrollBox.Create(Self);
  SectionScrollBox.BorderStyle := bsNone;
  SectionScrollBox.Color := clAppWorkSpace;
  SectionScrollBox.Align := alClient;
  SectionScrollBox.HorzScrollBar.Tracking := True;
  SectionScrollBox.VertScrollBar.Tracking := True;
  SectionScrollBox.OnScroll := SecPosChange;
  SectionScrollBox.Parent := Self;

  leftrulers := TList.Create;
  toptitles := TList.Create;
  righttitles := TList.Create;
  secinterfaces := TList.Create;

  FSizeModifier := TRpSizeModifier.Create(Self);
  FSizeModifier.OnSizeChange := SizeModifierChange;
  FSelectedItems := TList.Create;

  FActiveTool := dtArrow;

  // Create context popup menu
  FPopupMenu := TPopupMenu.Create(Self);
  FPopupMenu.OnPopup := PopupMenuPopup;

  MDelete := TMenuItem.Create(FPopupMenu);
  MDelete.Caption := SRpDelete;
  MDelete.ShortCut := ShortCut(VK_DELETE, []);
  MDelete.OnClick := PopupDeleteClick;
  FPopupMenu.Items.Add(MDelete);

  itemSep := TMenuItem.Create(FPopupMenu);
  itemSep.Caption := '-';
  FPopupMenu.Items.Add(itemSep);

  MBringToFront := TMenuItem.Create(FPopupMenu);
  MBringToFront.Caption := SRpBringToFront;
  MBringToFront.OnClick := PopupBringToFrontClick;
  FPopupMenu.Items.Add(MBringToFront);

  MSendToBack := TMenuItem.Create(FPopupMenu);
  MSendToBack.Caption := SRpSendToBack;
  MSendToBack.OnClick := PopupSendToBackClick;
  FPopupMenu.Items.Add(MSendToBack);

  itemSep := TMenuItem.Create(FPopupMenu);
  itemSep.Caption := '-';
  FPopupMenu.Items.Add(itemSep);

  MSelectAll := TMenuItem.Create(FPopupMenu);
  MSelectAll.Caption := SRpSelectAll;
  MSelectAll.ShortCut := ShortCut(Ord('A'), [ssCtrl]);
  MSelectAll.OnClick := PopupSelectAllClick;
  FPopupMenu.Items.Add(MSelectAll);

  PSection := TRpPaintEventPanel.Create(Self);
  PSection.allowselect := False;
  PSection.FFrame := Self;
  PSection.Color := clAppWorkSpace;
  PSection.Parent := SectionScrollBox;
  PSection.PopupMenu := FPopupMenu;
  PSection.OnPosChange := SecPosChange;
end;

destructor TFRpDesignFrameLCL.Destroy;
begin
  FUpdatingSubreport := True;
  if Assigned(FObjInsp) then
  begin
    FObjInsp.RemoveFreeNotification(Self);
    FObjInsp := nil;
  end;
  ClearSelection;
  SelectSubReport(nil);
  FreeAndNil(leftrulers);
  FreeAndNil(toptitles);
  FreeAndNil(righttitles);
  FreeAndNil(secinterfaces);
  if Assigned(FSizeModifier) then
  begin
    FSizeModifier.Control := nil;
    FreeAndNil(FSizeModifier);
  end;
  FreeAndNil(FSelectedItems);
  inherited Destroy;
end;

procedure TFRpDesignFrameLCL.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FObjInsp) then
    FObjInsp := nil;
end;

procedure TFRpDesignFrameLCL.Resize;
begin
  inherited Resize;
  if not FUpdatingSubreport then
    SecPosChange(Self);
end;

procedure TFRpDesignFrameLCL.SetScale(nvalue: Double);
var
  i: Integer;
  subrep: TRpSubReport;
begin
  if FScale = nvalue then
    Exit;
  FScale := nvalue;
  TopRuler.Scale := FScale;
  for i := 0 to leftrulers.Count - 1 do
    TRpRulerLCL(leftrulers[i]).Scale := FScale;

  if Assigned(FReport) and Assigned(FSubReport) then
  begin
    subrep := FSubReport;
    SelectSubReport(nil);
    SelectSubReport(subrep);
  end;
end;

procedure TFRpDesignFrameLCL.SetReport(Value: TRpReport);
begin
  SelectSubReport(nil);
  FReport := Value;
  if not Assigned(FReport) then
    Exit;
  if FReport.SubReports.Count > 0 then
    SelectSubReport(FReport.SubReports[0].SubReport);
end;

procedure TFRpDesignFrameLCL.SetObjInsp(Value: TComponent);
var
  i: Integer;
begin
  if FObjInsp <> Value then
  begin
    if Assigned(FObjInsp) then
      FObjInsp.RemoveFreeNotification(Self);
    FObjInsp := Value;
    if Assigned(FObjInsp) then
      FObjInsp.FreeNotification(Self);
    if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
      TFRpObjInspLCL(FObjInsp).DesignFrame := Self;
    if Assigned(secinterfaces) then
    begin
      for i := 0 to secinterfaces.Count - 1 do
        TRpSectionInterface(secinterfaces[i]).fobjinsp := FObjInsp;
    end;
  end;
end;

procedure TFRpDesignFrameLCL.SelectSubReport(subreport: TRpSubReport);
var
  i: Integer;
  asecint: TRpSectionInterface;
  apanel: TRpPaintEventPanel;
  rpanel: TRpPanelRight;
  aruler: TRpRulerLCL;
  posx: Integer;
  maxwidth: Integer;
  oldsection: TRpSection;
  sec: TRpSection;
begin
  if (FSubReport = subreport) and Assigned(subreport) then
    Exit;

  FUpdatingSubreport := True;
  try
    // Clear existing items
    ClearSelection;
    // Clear inspector CompItem references BEFORE freeing section interfaces
    // to prevent dangling pointers in cached property panels
    if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
    begin
      TFRpObjInspLCL(FObjInsp).ClearCompItemRefs;
      TFRpObjInspLCL(FObjInsp).AddCompItem(nil, True);
    end;

    // First detach parents to avoid cascaded resize/paint events during destroy
    for i := 0 to secinterfaces.Count - 1 do
    begin
      if Assigned(secinterfaces[i]) then
        TControl(secinterfaces[i]).Parent := nil;
      if Assigned(toptitles[i]) then
        TControl(toptitles[i]).Parent := nil;
      if Assigned(righttitles[i]) then
        TControl(righttitles[i]).Parent := nil;
      if Assigned(leftrulers[i]) then
        TControl(leftrulers[i]).Parent := nil;
    end;
    if toptitles.Count > secinterfaces.Count then
    begin
      if Assigned(toptitles[secinterfaces.Count]) then
        TControl(toptitles[secinterfaces.Count]).Parent := nil;
    end;

    for i := 0 to secinterfaces.Count - 1 do
    begin
      TObject(secinterfaces[i]).Free;
      TObject(toptitles[i]).Free;
      TObject(righttitles[i]).Free;
      TObject(leftrulers[i]).Free;
    end;
    if toptitles.Count > secinterfaces.Count then
      TObject(toptitles[secinterfaces.Count]).Free;

    secinterfaces.Clear;
    toptitles.Clear;
    righttitles.Clear;
    leftrulers.Clear;

    FSubReport := subreport;
    if not Assigned(FSubReport) then
      Exit;

  maxwidth := 0;
  posx := 0;
  oldsection := nil;

  for i := 0 to FSubReport.Sections.Count - 1 do
  begin
    sec := FSubReport.Sections[i].Section;

    // 1. Title bar panel
    apanel := TRpPaintEventPanel.Create(Self);
    apanel.Parent := PSection;
    apanel.FFrame := Self;
    if i = 0 then
      apanel.Cursor := crArrow
    else
      apanel.Cursor := crSizeNS;
    apanel.OnPaint := SecPosChange;
    apanel.Height := panelheight;
    apanel.CaptionText := ' ' + sec.SectionCaption(False);
    apanel.Alignment := taLeftJustify;
    apanel.Top := posx;
    apanel.Section := sec;
    oldsection := sec;
    posx := posx + apanel.Height;
    toptitles.Add(apanel);

    // 2. Section interface (canvas + child items)
    asecint := TRpSectionInterface.Create(Self, sec);
    asecint.fobjinsp := FObjInsp;
    asecint.freportstructure := freportstructure;
    asecint.DesignFrame := Self;
    asecint.ActiveTool := FActiveTool;
    asecint.OnToolDone := SectionToolDone;
    asecint.OnKeyDown := SectionKeyDown;
    asecint.Parent := PSection;
    asecint.SectionControl.PopupMenu := FPopupMenu;
    asecint.Scale := Scale;
    asecint.Left := 0;
    asecint.Top := posx;
    asecint.OnSelectComponent := SelectComponent;
    asecint.OnClearSelection := ClearSelectionEvent;
    asecint.OnMoveComponent := MoveSelectedComponents;
    asecint.OnGetSelectedList := GetSelectedItemsList;
    asecint.CreateChilds;
    asecint.UpdatePos;
    asecint.OnPosChange := SecPosChange;
    secinterfaces.Add(asecint);

    apanel.Width := asecint.Width;

    // 3. Right width-resize handle
    rpanel := TRpPanelRight.Create(Self);
    rpanel.Parent := PSection;
    rpanel.FFrame := Self;
    rpanel.Height := asecint.Height;
    rpanel.Left := asecint.Width;
    rpanel.Top := posx;
    rpanel.Width := CONS_RIGHTPWIDTH;
    rpanel.Section := sec;
    righttitles.Add(rpanel);

    // 4. Vertical left ruler
    aruler := TRpRulerLCL.Create(Self);
    aruler.RType := rVertical;
    aruler.Parent := PLeft;
    aruler.Width := ScaleDpi(20);
    aruler.Left := 0;
    aruler.Scale := Scale;
    aruler.Top := posx;
    aruler.Height := asecint.Height;
    if rpmunits.defaultunit = rpUnitCms then
      aruler.Metrics := rCms
    else
      aruler.Metrics := rInchess;
    leftrulers.Add(aruler);

    if maxwidth < asecint.Width then
      maxwidth := asecint.Width;
    posx := posx + asecint.Height;
  end;

  // Last resizing bottom panel
  if Assigned(oldsection) then
  begin
    apanel := TRpPaintEventPanel.Create(Self);
    apanel.Parent := PSection;
    apanel.allowselect := False;
    apanel.FFrame := Self;
    apanel.Cursor := crSizeNS;
    apanel.OnPaint := SecPosChange;
    apanel.Height := panelheight div 3;
    apanel.CaptionText := '';
    apanel.Top := posx;
    apanel.Width := oldsection.Width;
    apanel.Section := oldsection;
    posx := posx + apanel.Height;
    toptitles.Add(apanel);
  end;

  TopRuler.Width := maxwidth * 2 + CONS_RIGHTPWIDTH;
  if rpmunits.defaultunit = rpUnitCms then
    TopRuler.Metrics := rCms
  else
    TopRuler.Metrics := rInchess;

  PSection.Height := posx + Height;
  PSection.Width := maxwidth * 2 + CONS_RIGHTPWIDTH;

  SectionScrollBox.VertScrollBar.Position := 0;
  SectionScrollBox.HorzScrollBar.Position := 0;
  finally
    FUpdatingSubreport := False;
  end;
  SecPosChange(Self);
end;

procedure TFRpDesignFrameLCL.UpdateInterface(refreshobjinsp: Boolean);
var
  i, j: Integer;
  asecint: TRpSectionInterface;
  apanel: TRpPaintEventPanel;
  rpanel: TRpPanelRight;
  aruler: TRpRulerLCL;
  posx, maxwidth: Integer;
begin
  if not Assigned(FSubReport) then
    Exit;

  maxwidth := 0;
  posx := 0;

  for i := 0 to secinterfaces.Count - 1 do
  begin
    apanel := TRpPaintEventPanel(toptitles[i]);
    asecint := TRpSectionInterface(secinterfaces[i]);
    asecint.SyncChilds;
    asecint.UpdateBack;
    rpanel := TRpPanelRight(righttitles[i]);

    apanel.Width := asecint.Width;
    apanel.CaptionText := ' ' + FSubReport.Sections[i].Section.SectionCaption(False);
    apanel.Top := posx;
    posx := posx + apanel.Height;

    asecint.Top := posx;
    asecint.UpdatePos;
    for j := 0 to asecint.childlist.Count - 1 do
      TRpSizePosInterface(asecint.childlist[j]).UpdatePos;

    rpanel.Top := posx;
    rpanel.Height := asecint.Height;
    rpanel.Left := asecint.Width;

    aruler := TRpRulerLCL(leftrulers[i]);
    aruler.Top := posx;
    aruler.Height := asecint.Height;

    if maxwidth < asecint.Width then
      maxwidth := asecint.Width;
    posx := posx + asecint.Height;
  end;

  if toptitles.Count > secinterfaces.Count then
  begin
    apanel := TRpPaintEventPanel(toptitles[secinterfaces.Count]);
    apanel.Top := posx;
    if Assigned(apanel.Section) then
      apanel.Width := twipstopixels(apanel.Section.Width, Scale);
    posx := posx + apanel.Height;
  end;

  TopRuler.Width := maxwidth * 2 + CONS_RIGHTPWIDTH;
  PSection.Height := posx + Height;
  PSection.Width := maxwidth * 2 + CONS_RIGHTPWIDTH;

  SecPosChange(Self);
end;

procedure TFRpDesignFrameLCL.SecPosChange(Sender: TObject);
var
  i, despy: Integer;
  aruler: TRpRulerLCL;
begin
  if FUpdatingSubreport then
    Exit;
  if not Assigned(TopRuler) or not Assigned(SectionScrollBox) or not Assigned(leftrulers) or not Assigned(secinterfaces) then
    Exit;

  TopRuler.Left := CONS_RULER_LEFT - SectionScrollBox.HorzScrollBar.Position;
  despy := SectionScrollBox.VertScrollBar.Position;

  for i := 0 to leftrulers.Count - 1 do
  begin
    aruler := TRpRulerLCL(leftrulers[i]);
    if (i < secinterfaces.Count) and Assigned(aruler) and Assigned(secinterfaces[i]) then
      aruler.Top := TRpSectionInterface(secinterfaces[i]).Top - despy;
  end;
end;

procedure TFRpDesignFrameLCL.InvalidateCaptions;
var
  i: Integer;
  apanel: TRpPaintEventPanel;
begin
  if not Assigned(FSubReport) then Exit;
  for i := 0 to toptitles.Count - 1 do
  begin
    apanel := TRpPaintEventPanel(toptitles[i]);
    if i < FSubReport.Sections.Count then
      apanel.CaptionText := ' ' + FSubReport.Sections[i].Section.SectionCaption(False);
    apanel.Invalidate;
  end;
end;

procedure TFRpDesignFrameLCL.ShowAllHidden;
begin
  UpdateInterface(True);
end;

procedure TFRpDesignFrameLCL.SizeModifierChange(Sender: TObject);
begin
  if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
    TFRpObjInspLCL(FObjInsp).UpdatePosValues;
end;

procedure TFRpDesignFrameLCL.ClearSelectionEvent(Sender: TObject);
begin
  ClearSelection;
end;

procedure TFRpDesignFrameLCL.ClearSelection;
var
  i: Integer;
  item: TRpSizePosInterface;
begin
  if Assigned(FSizeModifier) then
    FSizeModifier.Control := nil;

  if Assigned(FSelectedItems) then
  begin
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      item := TRpSizePosInterface(FSelectedItems[i]);
      if item.Selected then
      begin
        item.Selected := False;
        item.Invalidate;
      end;
    end;
    FSelectedItems.Clear;
  end;

  if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
    TFRpObjInspLCL(FObjInsp).ClearMultiSelect;
end;

procedure TFRpDesignFrameLCL.SelectComponent(AComp: TRpSizeInterface; AddToSelection: Boolean);
var
  i, idx: Integer;
  posComp: TRpSizePosInterface;
  item: TRpSizePosInterface;
begin
  if not Assigned(AComp) or not (AComp is TRpSizePosInterface) then
  begin
    ClearSelection;
    if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
      TFRpObjInspLCL(FObjInsp).AddCompItem(nil, True);
    Exit;
  end;

  posComp := TRpSizePosInterface(AComp);
  posComp.PopupMenu := FPopupMenu;

  if not AddToSelection then
  begin
    ClearSelection;
    FSelectedItems.Add(posComp);
    posComp.Selected := False; // Single selection uses black handles, not grey squares
    posComp.Invalidate;

    if Assigned(FReport) then
    begin
      FSizeModifier.GridEnabled := FReport.GridEnabled;
      FSizeModifier.GridX := FReport.GridWidth;
      FSizeModifier.GridY := FReport.GridHeight;
    end;
    FSizeModifier.Control := posComp;
    FSizeModifier.UpdatePos;
  end
  else
  begin
    idx := FSelectedItems.IndexOf(posComp);
    if idx >= 0 then
    begin
      // Toggle off
      FSelectedItems.Delete(idx);
      posComp.Selected := False;
      posComp.Invalidate;

      if FSelectedItems.Count = 1 then
      begin
        item := TRpSizePosInterface(FSelectedItems[0]);
        item.Selected := False;
        item.Invalidate;
        if Assigned(FReport) then
        begin
          FSizeModifier.GridEnabled := FReport.GridEnabled;
          FSizeModifier.GridX := FReport.GridWidth;
          FSizeModifier.GridY := FReport.GridHeight;
        end;
        FSizeModifier.Control := item;
        FSizeModifier.UpdatePos;
      end
      else if FSelectedItems.Count = 0 then
      begin
        FSizeModifier.Control := nil;
      end;
    end
    else
    begin
      // Add to multi-selection
      FSelectedItems.Add(posComp);
      if FSelectedItems.Count = 1 then
      begin
        posComp.Selected := False;
        posComp.Invalidate;
        if Assigned(FReport) then
        begin
          FSizeModifier.GridEnabled := FReport.GridEnabled;
          FSizeModifier.GridX := FReport.GridWidth;
          FSizeModifier.GridY := FReport.GridHeight;
        end;
        FSizeModifier.Control := posComp;
        FSizeModifier.UpdatePos;
      end
      else
      begin
        // Multi-selection: remove black handles, paint grey selection squares on all
        FSizeModifier.Control := nil;
        for i := 0 to FSelectedItems.Count - 1 do
        begin
          item := TRpSizePosInterface(FSelectedItems[i]);
          if not item.Selected then
          begin
            item.Selected := True;
            item.Invalidate;
          end;
        end;
      end;
    end;
  end;

  if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
    TFRpObjInspLCL(FObjInsp).AddCompItem(posComp, not AddToSelection);
end;

procedure TFRpDesignFrameLCL.UpdateSelection(force: Boolean);
var
  struct: TFRpStructureLCL;
  dataobj: TObject;
  asubreport: TRpSubReport;
  i: Integer;
  FSectionInterface: TRpSectionInterface;
begin
  if Assigned(FSizeModifier) then
    FSizeModifier.UpdatePos;

  if not Assigned(freportstructure) then Exit;
  if not (freportstructure is TFRpStructureLCL) then Exit;
  struct := TFRpStructureLCL(freportstructure);
  if not Assigned(struct.RView.Selected) then Exit;
  if not Assigned(struct.RView.Selected.Data) then Exit;

  if force then
    SelectSubReport(nil);

  dataobj := TObject(struct.RView.Selected.Data);
  asubreport := struct.FindSelectedSubreport;
  if asubreport <> FSubReport then
    SelectSubReport(asubreport);

  if dataobj is TRpSubReport then
  begin
    if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
      TFRpObjInspLCL(FObjInsp).AddCompItem(nil, True);
    Exit;
  end;

  if dataobj is TRpSection then
  begin
    i := 0;
    FSectionInterface := nil;
    while i < secinterfaces.Count do
    begin
      if TRpSectionInterface(secinterfaces[i]).printitem = dataobj then
      begin
        FSectionInterface := TRpSectionInterface(secinterfaces[i]);
        break;
      end;
      Inc(i);
    end;
    if Assigned(FSectionInterface) and Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
      TFRpObjInspLCL(FObjInsp).AddCompItem(FSectionInterface, True);
  end;
end;

procedure TFRpDesignFrameLCL.SelectDataItem(data: TObject);
begin
  if Assigned(freportstructure) and (freportstructure is TFRpStructureLCL) then
    TFRpStructureLCL(freportstructure).SelectDataItem(data);
end;

function TFRpDesignFrameLCL.GetSelectedItemsList: TList;
begin
  Result := FSelectedItems;
end;

procedure TFRpDesignFrameLCL.MoveSelectedComponents(ALeader: TRpSizeInterface; ADeltaXTwips, ADeltaYTwips: Integer);
var
  i: Integer;
  item: TRpSizePosInterface;
  positem: TRpCommonPosComponent;
  newX, newY, minX, minY: Integer;
  oldPosXArr, oldPosYArr: array of Integer;
  cue: TUndoCue;
  gid: Integer;
  op: TChangeObjectOperation;
begin
  if not Assigned(FSelectedItems) or (FSelectedItems.Count = 0) then
    Exit;

  // Prevent any component from moving past (0, 0)
  minX := MaxInt;
  minY := MaxInt;
  for i := 0 to FSelectedItems.Count - 1 do
  begin
    item := TRpSizePosInterface(FSelectedItems[i]);
    if Assigned(item.printitem) and (item.printitem is TRpCommonPosComponent) then
    begin
      positem := TRpCommonPosComponent(item.printitem);
      if positem.PosX < minX then minX := positem.PosX;
      if positem.PosY < minY then minY := positem.PosY;
    end;
  end;

  if (ADeltaXTwips < 0) and (-ADeltaXTwips > minX) then
    ADeltaXTwips := -minX;
  if (ADeltaYTwips < 0) and (-ADeltaYTwips > minY) then
    ADeltaYTwips := -minY;

  if (ADeltaXTwips = 0) and (ADeltaYTwips = 0) then
    Exit;

  SetLength(oldPosXArr, FSelectedItems.Count);
  SetLength(oldPosYArr, FSelectedItems.Count);

  for i := 0 to FSelectedItems.Count - 1 do
  begin
    item := TRpSizePosInterface(FSelectedItems[i]);
    if Assigned(item.printitem) and (item.printitem is TRpCommonPosComponent) then
    begin
      positem := TRpCommonPosComponent(item.printitem);
      oldPosXArr[i] := positem.PosX;
      oldPosYArr[i] := positem.PosY;
      newX := positem.PosX + ADeltaXTwips;
      if newX < 0 then newX := 0;
      newY := positem.PosY + ADeltaYTwips;
      if newY < 0 then newY := 0;
      positem.PosX := newX;
      positem.PosY := newY;
      item.UpdatePos;
    end;
  end;

  if Assigned(FReport) and Assigned(FReport.UndoCue) then
  begin
    cue := TUndoCue(FReport.UndoCue);
    gid := cue.GetGroupId;
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      item := TRpSizePosInterface(FSelectedItems[i]);
      if Assigned(item.printitem) and (item.printitem is TRpCommonPosComponent) then
      begin
        positem := TRpCommonPosComponent(item.printitem);
        op := TChangeObjectOperation.Create(otModify, gid);
        op.componentName := positem.Name;
        op.componentClass := UpperCase(positem.ClassName);
        if Assigned(item.SectionInt) and Assigned(item.SectionInt.PrintItem) then
          op.parentName := TRpSection(item.SectionInt.PrintItem).Name;
        op.AddProperty('posX', ptInteger, oldPosXArr[i], positem.PosX);
        op.AddProperty('posY', ptInteger, oldPosYArr[i], positem.PosY);
        cue.AddOperation(op);
      end;
    end;
    if Assigned(freportstructure) and (freportstructure is TFRpStructureLCL) then
      if Assigned(TFRpStructureLCL(freportstructure).cueview) then
        TFRpStructureLCL(freportstructure).cueview.RefreshList;
  end;

  if Assigned(FSizeModifier) and (FSelectedItems.Count = 1) then
    FSizeModifier.UpdatePos;

  if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
    TFRpObjInspLCL(FObjInsp).UpdatePosValues;
end;

procedure TFRpDesignFrameLCL.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = VK_DELETE then
  begin
    DeleteSelection;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    ActiveTool := dtArrow;
    Key := 0;
  end;
end;

procedure TFRpDesignFrameLCL.SetActiveTool(Value: TRpDesignTool);
var
  i: Integer;
begin
  if FActiveTool <> Value then
  begin
    FActiveTool := Value;
    if Assigned(secinterfaces) then
    begin
      for i := 0 to secinterfaces.Count - 1 do
      begin
        if Assigned(secinterfaces[i]) then
          TRpSectionInterface(secinterfaces[i]).ActiveTool := FActiveTool;
      end;
    end;
    if Assigned(FOnToolChange) then
      FOnToolChange(Self);
  end;
end;

procedure TFRpDesignFrameLCL.SectionToolDone(Sender: TObject);
begin
  ActiveTool := dtArrow;
end;

procedure TFRpDesignFrameLCL.SectionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_DELETE then
  begin
    DeleteSelection;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    ActiveTool := dtArrow;
    Key := 0;
  end;
end;

procedure TFRpDesignFrameLCL.PopupMenuPopup(Sender: TObject);
var
  hasSel: Boolean;
begin
  hasSel := Assigned(FSelectedItems) and (FSelectedItems.Count > 0);
  if Assigned(MDelete) then
    MDelete.Enabled := hasSel;
  if Assigned(MBringToFront) then
    MBringToFront.Enabled := hasSel;
  if Assigned(MSendToBack) then
    MSendToBack.Enabled := hasSel;
end;

procedure TFRpDesignFrameLCL.PopupDeleteClick(Sender: TObject);
begin
  DeleteSelection;
end;

procedure TFRpDesignFrameLCL.PopupBringToFrontClick(Sender: TObject);
begin
  BringSelectionToFront;
end;

procedure TFRpDesignFrameLCL.PopupSendToBackClick(Sender: TObject);
begin
  SendSelectionToBack;
end;

procedure TFRpDesignFrameLCL.PopupSelectAllClick(Sender: TObject);
begin
  SelectAll;
end;

procedure TFRpDesignFrameLCL.DeleteSelection;
var
  i: Integer;
  item: TRpSizePosInterface;
  secint: TRpSectionInterface;
  pitem: TRpCommonPosComponent;
  selectedList: TList;
  cue: TUndoCue;
  gid: Integer;
  op: TChangeObjectOperation;
begin
  if not Assigned(FSelectedItems) or (FSelectedItems.Count = 0) then
    Exit;

  selectedList := TList.Create;
  try
    for i := 0 to FSelectedItems.Count - 1 do
      selectedList.Add(FSelectedItems[i]);

    ClearSelection;

    // Record Undo otRemove before deleting
    if Assigned(FReport) and Assigned(FReport.UndoCue) then
    begin
      cue := TUndoCue(FReport.UndoCue);
      gid := cue.GetGroupId;
      for i := 0 to selectedList.Count - 1 do
      begin
        item := TRpSizePosInterface(selectedList[i]);
        secint := TRpSectionInterface(item.SectionInt);
        pitem := TRpCommonPosComponent(item.PrintItem);
        if Assigned(secint) and Assigned(secint.PrintItem) and Assigned(pitem) then
        begin
          op := TChangeObjectOperation.Create(otRemove, gid);
          op.componentName := pitem.Name;
          op.componentClass := UpperCase(pitem.ClassName);
          op.parentName := TRpSection(secint.PrintItem).Name;
          op.oldItemIndex := TRpSection(secint.PrintItem).ReportComponents.IndexOf(pitem);
          cue.AddAllComponentProperties(pitem, op);
          cue.AddOperation(op);
        end;
      end;
      if Assigned(freportstructure) and (freportstructure is TFRpStructureLCL) then
        if Assigned(TFRpStructureLCL(freportstructure).cueview) then
          TFRpStructureLCL(freportstructure).cueview.RefreshList;
    end;

    for i := 0 to selectedList.Count - 1 do
    begin
      item := TRpSizePosInterface(selectedList[i]);
      secint := TRpSectionInterface(item.SectionInt);
      pitem := TRpCommonPosComponent(item.PrintItem);
      if Assigned(secint) and Assigned(secint.PrintItem) and Assigned(pitem) then
      begin
        TRpSection(secint.PrintItem).DeleteComponent(pitem);
        secint.DeleteChild(item);
      end;
    end;
  finally
    selectedList.Free;
  end;

  if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
  begin
    TFRpObjInspLCL(FObjInsp).ClearCompItemRefs;
    TFRpObjInspLCL(FObjInsp).AddCompItem(nil, True);
  end;
end;

procedure TFRpDesignFrameLCL.BringSelectionToFront;
var
  i, idx, gid: Integer;
  item: TRpSizePosInterface;
  sec: TRpSection;
  pitem: TRpCommonComponent;
  citem: TRpCommonListItem;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  if not Assigned(FSelectedItems) or (FSelectedItems.Count = 0) then Exit;
  for i := 0 to FSelectedItems.Count - 1 do
  begin
    item := TRpSizePosInterface(FSelectedItems[i]);
    item.BringToFront;
    pitem := item.PrintItem;
    if Assigned(item.SectionInt) and Assigned(item.SectionInt.PrintItem) and (item.SectionInt.PrintItem is TRpSection) then
    begin
      sec := TRpSection(item.SectionInt.PrintItem);
      idx := sec.ReportComponents.IndexOf(pitem);
      if (idx >= 0) and (idx < sec.ReportComponents.Count - 1) then
      begin
        sec.ReportComponents.Delete(idx);
        citem := sec.ReportComponents.Add;
        citem.Component := pitem;
      end;
    end;
  end;
  if Assigned(FReport) and Assigned(FReport.UndoCue) then
  begin
    cue := TUndoCue(FReport.UndoCue);
    gid := cue.GetGroupId;
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      item := TRpSizePosInterface(FSelectedItems[i]);
      if Assigned(item.SectionInt) and Assigned(item.SectionInt.PrintItem) and (item.SectionInt.PrintItem is TRpSection) then
      begin
        op := TChangeObjectOperation.Create(otSwapUp, gid);
        op.componentName := item.PrintItem.Name;
        op.componentClass := UpperCase(item.PrintItem.ClassName);
        op.parentName := TRpSection(item.SectionInt.PrintItem).Name;
        cue.AddOperation(op);
      end;
    end;
    if Assigned(freportstructure) and (freportstructure is TFRpStructureLCL) then
      if Assigned(TFRpStructureLCL(freportstructure).cueview) then
        TFRpStructureLCL(freportstructure).cueview.RefreshList;
  end;
  if Assigned(FSizeModifier) and Assigned(FSizeModifier.Control) then
    FSizeModifier.UpdatePos;
end;

procedure TFRpDesignFrameLCL.SendSelectionToBack;
var
  i, idx, gid: Integer;
  item: TRpSizePosInterface;
  sec: TRpSection;
  pitem: TRpCommonComponent;
  citem: TRpCommonListItem;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  if not Assigned(FSelectedItems) or (FSelectedItems.Count = 0) then Exit;
  for i := 0 to FSelectedItems.Count - 1 do
  begin
    item := TRpSizePosInterface(FSelectedItems[i]);
    item.SendToBack;
    pitem := item.PrintItem;
    if Assigned(item.SectionInt) and Assigned(item.SectionInt.PrintItem) and (item.SectionInt.PrintItem is TRpSection) then
    begin
      sec := TRpSection(item.SectionInt.PrintItem);
      idx := sec.ReportComponents.IndexOf(pitem);
      if idx > 0 then
      begin
        sec.ReportComponents.Delete(idx);
        citem := sec.ReportComponents.Insert(0);
        citem.Component := pitem;
      end;
    end;
  end;
  if Assigned(FReport) and Assigned(FReport.UndoCue) then
  begin
    cue := TUndoCue(FReport.UndoCue);
    gid := cue.GetGroupId;
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      item := TRpSizePosInterface(FSelectedItems[i]);
      if Assigned(item.SectionInt) and Assigned(item.SectionInt.PrintItem) and (item.SectionInt.PrintItem is TRpSection) then
      begin
        op := TChangeObjectOperation.Create(otSwapDown, gid);
        op.componentName := item.PrintItem.Name;
        op.componentClass := UpperCase(item.PrintItem.ClassName);
        op.parentName := TRpSection(item.SectionInt.PrintItem).Name;
        cue.AddOperation(op);
      end;
    end;
    if Assigned(freportstructure) and (freportstructure is TFRpStructureLCL) then
      if Assigned(TFRpStructureLCL(freportstructure).cueview) then
        TFRpStructureLCL(freportstructure).cueview.RefreshList;
  end;
  if Assigned(FSizeModifier) and Assigned(FSizeModifier.Control) then
    FSizeModifier.UpdatePos;
end;

procedure TFRpDesignFrameLCL.SelectAll;
var
  i, j: Integer;
  secint: TRpSectionInterface;
  item: TRpSizePosInterface;
begin
  ClearSelection;
  if not Assigned(secinterfaces) then Exit;
  for i := 0 to secinterfaces.Count - 1 do
  begin
    secint := TRpSectionInterface(secinterfaces[i]);
    if Assigned(secint) and Assigned(secint.childlist) then
    begin
      for j := 0 to secint.childlist.Count - 1 do
      begin
        item := TRpSizePosInterface(secint.childlist[j]);
        if item.Visible then
        begin
          item.Selected := True;
          item.Invalidate;
          FSelectedItems.Add(item);
        end;
      end;
    end;
  end;
  if Assigned(FSizeModifier) then
    FSizeModifier.Control := nil;
  if Assigned(FObjInsp) and (FObjInsp is TFRpObjInspLCL) then
  begin
    TFRpObjInspLCL(FObjInsp).ClearMultiSelect;
    for i := 0 to FSelectedItems.Count - 1 do
      TFRpObjInspLCL(FObjInsp).AddCompItem(TRpSizeInterface(FSelectedItems[i]), False);
  end;
end;

end.

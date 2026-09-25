{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdobinsintlcl                                 }
{                                                       }
{       Basic properties editor, size, position         }
{       Controls to modify basic properties for LCL     }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdobinsintlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Types,
  Graphics, Forms, Controls, Dialogs, Menus,
  rpmdconsts, rpmunits, rpprintitem, rpgraphutilslcl,
  rpsection, rpreport, rptypes;

const
  CONS_MODIWIDTH = 7;
  CONS_MINIMUMMOVE = 2;
  CONS_SELWIDTH = 7;
  CONS_MINWIDTH = 5;
  CONS_MINHEIGHT = 5;
  MAX_CHeight = 144000;
  MAX_CWidth = 144000;

  AlignmentFlags_SingleLine = 64;
  AlignmentFlags_AlignHCenter = 4;
  AlignmentFlags_AlignHJustify = 1024;
  AlignmentFlags_AlignTop = 8;
  AlignmentFlags_AlignBottom = 16;
  AlignmentFlags_AlignVCenter = 32;
  AlignmentFlags_AlignLeft = 1;
  AlignmentFlags_AlignRight = 2;

type
  TRpPropertytype = (rppinteger, rppcurrency, rppstring, rpplist, rpcustom);

  TRpSizeInterface = class;
  TRpSizePosInterface = class;
  TRpSizePosInterfaceClass = class of TRpSizePosInterface;

  TRpSelectCompEvent = procedure(AComp: TRpSizeInterface; AddToSelection: Boolean) of object;
  TRpMoveCompEvent = procedure(ALeader: TRpSizeInterface; ADeltaXTwips, ADeltaYTwips: Integer) of object;
  TRpGetSelectedListEvent = function: TList of object;

  // The base visual interface for size (width/height)
  TRpSizeInterface = class(TGraphicControl)
  private
    FSelected: Boolean;
    FScale: Double;
    procedure SetSelected(Value: Boolean);
  protected
    fprintitem: TRpCommonComponent;
    FOnSelectComponent: TRpSelectCompEvent;
    FOnMoveComponent: TRpMoveCompEvent;
    FOnGetSelectedList: TRpGetSelectedListEvent;
    procedure Paint; override;
    procedure DrawSelected; virtual;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure SetScale(nscale: Double); virtual;
  public
    fobjinsp: TComponent;
    procedure UpdatePos; virtual;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); virtual;
    procedure GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings); overload; virtual;
    procedure GetPropertyValues(pname: string; lpossiblevalues: TStrings); overload;
    procedure SetProperty(pname: string; value: WideString); overload; virtual;
    procedure SetProperty(pname: string; stream: TMemoryStream); overload; virtual;
    procedure GetProperty(pname: string; var Stream: TMemoryStream); overload; virtual;
    function GetProperty(pname: string): WideString; overload; virtual;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); reintroduce; overload; virtual;
    property printitem: TRpCommonComponent read fprintitem;
    property Selected: Boolean read FSelected write SetSelected;
    property Scale: Double read FScale write SetScale;
    property OnSelectComponent: TRpSelectCompEvent read FOnSelectComponent write FOnSelectComponent;
    property OnMoveComponent: TRpMoveCompEvent read FOnMoveComponent write FOnMoveComponent;
    property OnGetSelectedList: TRpGetSelectedListEvent read FOnGetSelectedList write FOnGetSelectedList;
  end;

  // Dragging / sizing outline box
  TRpRectangle = class(TGraphicControl)
  protected
    procedure Paint; override;
  public
    Solid: Boolean;
    constructor Create(AOwner: TComponent); override;
  end;

  // The visual interface for size and position
  TRpSizePosInterface = class(TRpSizeInterface)
  private
    FRectangle: TRpRectangle;
    FRectangle2: TRpRectangle;
    FRectangle3: TRpRectangle;
    FRectangle4: TRpRectangle;
    insertingelement: Boolean;
  protected
    FXOrigin, FYOrigin: Integer;
    FBlocked: Boolean;
    FContextMenu: TPopupMenu;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
    procedure InitPopUpMenu; virtual;
    procedure PopUpContextMenu; virtual;
  public
    SectionInt: TRpSizeInterface;
    procedure ClearRectangles;
    procedure InitRectangles;
    procedure DoSelect;
    procedure UpdatePos; override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
    procedure GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings); override;
    class procedure FillAncestors(alist: TStrings); virtual;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    destructor Destroy; override;
  end;

  // Base interface for text-based controls (labels, expressions)
  TRpGenTextInterface = class(TRpSizePosInterface)
  protected
    procedure InitPopUpMenu; override;
  public
    class procedure FillAncestors(alist: TStrings); override;
    constructor Create(AOwner: TComponent; pritem: TRpCommonComponent); override;
    procedure GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings); override;
    procedure SetProperty(pname: string; value: WideString); override;
    function GetProperty(pname: string): WideString; override;
    procedure GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings); override;
  end;

  // Black handle box for resizing
  TRpBlackControl = class(TGraphicControl)
  private
    FXOrigin, FYOrigin: Integer;
    FRectangle: TRpRectangle;
    FRectangle2: TRpRectangle;
    FRectangle3: TRpRectangle;
    FRectangle4: TRpRectangle;
    FControl: TControl;
    FAllowOverSize: Boolean;
    procedure CalcNewCoords(var NewLeft, NewTop, NewWidth, NewHeight, X, Y: Integer);
    procedure ClearRectangles;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Control: TControl read FControl write FControl;
  end;

  // Manager of 4 corner resize handles
  TRpSizeModifier = class(TComponent)
  private
    FOnSizeChange: TNotifyEvent;
    FAllowOverSize: Boolean;
    FBlacks: array[0..3] of TRpBlackControl;
    FControl: TControl;
    FOnlysize: Boolean;
    FGridEnabled: Boolean;
    FGridX, FGridY: Integer;
    procedure SetControl(Value: TControl);
    procedure SetOnlySize(Value: Boolean);
    procedure SetAllowOversize(Value: Boolean);
  public
    procedure UpdatePos;
    constructor Create(AOwner: TComponent); override;
  published
    property Control: TControl read FControl write SetControl;
    property OnSizeChange: TNotifyEvent read FOnSizeChange write FOnSizeChange;
    property OnlySize: Boolean read FOnlysize write SetOnlySize default False;
    property AllowOverSize: Boolean read FAllowOverSize write SetAllowOversize default False;
    property GridEnabled: Boolean read FGridEnabled write FGridEnabled;
    property GridX: Integer read FGridX write FGridX;
    property GridY: Integer read FGridY write FGridY;
  end;

function StringHAlignmentToInt(Value: WideString): Integer;
function StringVAlignmentToInt(Value: WideString): Integer;
function HAlignmentToText(Value: Integer): string;
function VAlignmentToText(Value: Integer): string;

implementation

function StringHAlignmentToInt(Value: WideString): Integer;
begin
  Result := 0;
  if Value = SrpSAlignLeft then Result := AlignmentFlags_AlignLeft
  else if Value = SrpSAlignRight then Result := AlignmentFlags_AlignRight
  else if Value = SrpSAlignCenter then Result := AlignmentFlags_AlignHCenter
  else if Value = SrpSAlignJustify then Result := AlignmentFlags_AlignHJustify;
end;

function StringVAlignmentToInt(Value: WideString): Integer;
begin
  Result := 0;
  if Value = SrpSAlignTop then Result := AlignmentFlags_AlignTop
  else if Value = SrpSAlignBottom then Result := AlignmentFlags_AlignBottom
  else if Value = SrpSAlignCenter then Result := AlignmentFlags_AlignVCenter;
end;

function HAlignmentToText(Value: Integer): string;
begin
  Result := SRpSAlignNone;
  if Value = AlignmentFlags_AlignLeft then Result := SRpSAlignLeft
  else if Value = AlignmentFlags_AlignRight then Result := SRpSAlignRight
  else if Value = AlignmentFlags_AlignHCenter then Result := SRpSAlignCenter
  else if Value = AlignmentFlags_AlignHJustify then Result := SRpSAlignJustify;
end;

function VAlignmentToText(Value: Integer): string;
begin
  Result := SRpSAlignNone;
  if Value = AlignmentFlags_AlignTop then Result := SRpSAlignTop
  else if Value = AlignmentFlags_AlignBottom then Result := SRpSAlignBottom
  else if Value = AlignmentFlags_AlignVCenter then Result := SRpSAlignCenter;
end;

{ TRpSizeInterface }

constructor TRpSizeInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  inherited Create(AOwner);
  fprintitem := pritem;
  FScale := 1.0;
end;

procedure TRpSizeInterface.SetScale(nscale: Double);
begin
  FScale := nscale;
  UpdatePos;
end;

procedure TRpSizeInterface.SetSelected(Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Invalidate;
  end;
end;

procedure TRpSizeInterface.UpdatePos;
var
  NewWidth, NewHeight: Integer;
begin
  if Assigned(fprintitem) then
  begin
    NewWidth := twipstopixels(fprintitem.Width, Scale);
    NewHeight := twipstopixels(fprintitem.Height, Scale);
    SetBounds(Left, Top, NewWidth, NewHeight);
  end;
end;

procedure TRpSizeInterface.Paint;
begin
  inherited Paint;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWhite;
  Canvas.Pen.Style := psDashDot;
  Canvas.Rectangle(0, 0, Width, Height);
  Canvas.TextOut(0, 0, SRpUndefinedPaintInterface);
  DrawSelected;
end;

procedure TRpSizeInterface.DrawSelected;
begin
  if not Selected then
    Exit;
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := clBtnFace;
  Canvas.Brush.Color := clBtnFace;
  Canvas.Rectangle(0, 0, CONS_SELWIDTH, CONS_SELWIDTH);
  Canvas.Rectangle(0, Height - CONS_SELWIDTH, CONS_SELWIDTH, Height);
  Canvas.Rectangle(Width - CONS_SELWIDTH, Height - CONS_SELWIDTH, Width, Height);
  Canvas.Rectangle(Width - CONS_SELWIDTH, 0, Width, CONS_SELWIDTH);
end;

procedure TRpSizeInterface.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TRpSizeInterface.DblClick;
begin
  inherited DblClick;
end;

procedure TRpSizeInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
begin
  lnames.Clear;
  ltypes.Clear;
  if Assigned(lvalues) then lvalues.Clear;
  lnames.Add(SrpSPrintCondition);
  ltypes.Add(SRpSExpression);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then
    lvalues.Add(fprintitem.PrintCondition);
  lnames.Add(SrpSBeforePrint);
  ltypes.Add(SRpSExpression);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then
    lvalues.Add(fprintitem.DoBeforePrint);
  lnames.Add(SrpSAfterPrint);
  ltypes.Add(SRpSExpression);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then
    lvalues.Add(fprintitem.DoAfterPrint);
  lnames.Add(SrpSWidth);
  ltypes.Add(SRpSCurrency);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then
    lvalues.Add(gettextfromtwips(fprintitem.Width));
  lnames.Add(SrpSHeight);
  ltypes.Add(SRpSCurrency);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then
    lvalues.Add(gettextfromtwips(fprintitem.Height));
end;

procedure TRpSizeInterface.GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings);
begin
  // Override in descendants
end;

procedure TRpSizeInterface.GetPropertyValues(pname: string; lpossiblevalues: TStrings);
var
  list: TRpWideStrings;
  i: Integer;
begin
  list := TRpWideStrings.Create;
  try
    GetPropertyValues(pname, list);
    lpossiblevalues.Clear;
    for i := 0 to list.Count - 1 do
      lpossiblevalues.Add(list.Strings[i]);
  finally
    list.Free;
  end;
end;

procedure TRpSizeInterface.SetProperty(pname: string; value: WideString);
begin
  if pname = SrpSPrintCondition then
  begin
    fprintitem.PrintCondition := value;
    Exit;
  end;
  if pname = SrpSBeforePrint then
  begin
    fprintitem.DoBeforePrint := value;
    Exit;
  end;
  if pname = SrpSAfterPrint then
  begin
    fprintitem.DoAfterPrint := value;
    Exit;
  end;
  if pname = SrpSWidth then
  begin
    fprintitem.Width := gettwipsfromtext(value);
    UpdatePos;
    Exit;
  end;
  if pname = SrpSHeight then
  begin
    fprintitem.Height := gettwipsfromtext(value);
    UpdatePos;
    Exit;
  end;
end;

procedure TRpSizeInterface.SetProperty(pname: string; stream: TMemoryStream);
begin
end;

procedure TRpSizeInterface.GetProperty(pname: string; var Stream: TMemoryStream);
begin
end;

function TRpSizeInterface.GetProperty(pname: string): WideString;
begin
  Result := '';
  if pname = SrpSPrintCondition then Result := fprintitem.PrintCondition
  else if pname = SrpSBeforePrint then Result := fprintitem.DoBeforePrint
  else if pname = SrpSAfterPrint then Result := fprintitem.DoAfterPrint
  else if pname = SrpSWidth then Result := gettextfromtwips(fprintitem.Width)
  else if pname = SrpSHeight then Result := gettextfromtwips(fprintitem.Height);
end;

{ TRpRectangle }

constructor TRpRectangle.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Solid := False;
end;

procedure TRpRectangle.Paint;
begin
  Canvas.Brush.Color := clBlack;
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psSolid;
  Canvas.Rectangle(0, 0, Width, Height);
end;

{ TRpSizePosInterface }

constructor TRpSizePosInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
var
  opts: TControlStyle;
begin
  if not (pritem is TRpCommonPosComponent) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
  opts := ControlStyle;
  Include(opts, csCaptureMouse);
  ControlStyle := opts;
  InitPopUpMenu;
end;

destructor TRpSizePosInterface.Destroy;
begin
  ClearRectangles;
  inherited Destroy;
end;

procedure TRpSizePosInterface.ClearRectangles;
begin
  FreeAndNil(FRectangle);
  FreeAndNil(FRectangle2);
  FreeAndNil(FRectangle3);
  FreeAndNil(FRectangle4);
end;

procedure TRpSizePosInterface.InitRectangles;
begin
  if not Assigned(FRectangle) and Assigned(Parent) then
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
end;

procedure TRpSizePosInterface.InitPopUpMenu;
begin
  // Context menu stub
end;

procedure TRpSizePosInterface.PopUpContextMenu;
begin
  if Assigned(FContextMenu) then
    FContextMenu.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

class procedure TRpSizePosInterface.FillAncestors(alist: TStrings);
begin
  alist.Add('TRpSizePosInterface');
end;

procedure TRpSizePosInterface.DoSelect;
begin
  if Assigned(OnSelectComponent) then
    OnSelectComponent(Self, False)
  else if Assigned(SectionInt) and Assigned(SectionInt.OnSelectComponent) then
    SectionInt.OnSelectComponent(Self, False);
end;

procedure TRpSizePosInterface.UpdatePos;
var
  NewWidth, NewHeight, NewLeft, NewTop: Integer;
  positem: TRpCommonPosComponent;
begin
  if Assigned(fprintitem) and (fprintitem is TRpCommonPosComponent) then
  begin
    positem := TRpCommonPosComponent(fprintitem);
    NewWidth := twipstopixels(positem.Width, Scale);
    NewHeight := twipstopixels(positem.Height, Scale);
    NewLeft := twipstopixels(positem.PosX, Scale);
    NewTop := twipstopixels(positem.PosY, Scale);
    SetBounds(NewLeft, NewTop, NewWidth, NewHeight);
    Invalidate;
  end;
end;

procedure TRpSizePosInterface.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  selList: TList;
  i: Integer;
  item: TRpSizePosInterface;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then
    Exit;

  FXOrigin := X;
  FYOrigin := Y;
  FBlocked := True;

  selList := nil;
  if Assigned(OnGetSelectedList) then
    selList := OnGetSelectedList()
  else if Assigned(SectionInt) and Assigned(SectionInt.OnGetSelectedList) then
    selList := SectionInt.OnGetSelectedList();

  // If this item is NOT in the current selection, and Shift/Ctrl is NOT pressed:
  if Assigned(selList) and (selList.IndexOf(Self) < 0) and
     not ((ssShift in Shift) or (ssCtrl in Shift)) then
  begin
    if Assigned(OnSelectComponent) then
      OnSelectComponent(Self, False)
    else if Assigned(SectionInt) and Assigned(SectionInt.OnSelectComponent) then
      SectionInt.OnSelectComponent(Self, False);

    if Assigned(OnGetSelectedList) then
      selList := OnGetSelectedList()
    else if Assigned(SectionInt) and Assigned(SectionInt.OnGetSelectedList) then
      selList := SectionInt.OnGetSelectedList();
  end;

  // Initialize drag outline rectangles
  if Assigned(selList) and (selList.IndexOf(Self) >= 0) and (selList.Count > 1) then
  begin
    for i := 0 to selList.Count - 1 do
    begin
      item := TRpSizePosInterface(selList[i]);
      item.InitRectangles;
    end;
  end
  else
    InitRectangles;
end;

procedure TRpSizePosInterface.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewLeft, NewTop, deltaX, deltaY: Integer;
  selList: TList;
  i: Integer;
  item: TRpSizePosInterface;
begin
  inherited MouseMove(Shift, X, Y);
  if MouseCapture and Assigned(Parent) then
  begin
    if (Abs(X - FXOrigin) > CONS_MINIMUMMOVE) or (Abs(Y - FYOrigin) > CONS_MINIMUMMOVE) then
      FBlocked := False;

    if Assigned(FRectangle) and (not FBlocked) then
    begin
      NewLeft := Left - FXOrigin + X;
      NewTop := Top - FYOrigin + Y;
      if NewLeft < 0 then NewLeft := 0;
      if NewTop < 0 then NewTop := 0;
      if Assigned(Parent) then
      begin
        if NewLeft + Width > Parent.Width then NewLeft := Parent.Width - Width;
        if NewTop + Height > Parent.Height then NewTop := Parent.Height - Height;
      end;
      if NewLeft < 0 then NewLeft := 0;
      if NewTop < 0 then NewTop := 0;

      if Assigned(printitem) and Assigned(printitem.Report) and
        TRpReport(printitem.Report).GridEnabled then
      begin
        NewLeft := AlignToGridPixels(NewLeft, TRpReport(printitem.Report).GridWidth, Scale);
        NewTop := AlignToGridPixels(NewTop, TRpReport(printitem.Report).GridHeight, Scale);
      end;

      deltaX := NewLeft - Left;
      deltaY := NewTop - Top;

      selList := nil;
      if Assigned(OnGetSelectedList) then
        selList := OnGetSelectedList()
      else if Assigned(SectionInt) and Assigned(SectionInt.OnGetSelectedList) then
        selList := SectionInt.OnGetSelectedList();

      if Assigned(selList) and (selList.IndexOf(Self) >= 0) and (selList.Count > 1) then
      begin
        for i := 0 to selList.Count - 1 do
        begin
          item := TRpSizePosInterface(selList[i]);
          if Assigned(item.FRectangle) then
          begin
            item.FRectangle.SetBounds(item.Left + deltaX, item.Top + deltaY, item.Width, 1);
            item.FRectangle2.SetBounds(item.Left + deltaX, item.Top + deltaY + item.Height, item.Width, 1);
            item.FRectangle3.SetBounds(item.Left + deltaX, item.Top + deltaY, 1, item.Height);
            item.FRectangle4.SetBounds(item.Left + deltaX + item.Width, item.Top + deltaY, 1, item.Height);
            if Assigned(item.Parent) then item.Parent.Update;
          end;
        end;
      end
      else
      begin
        FRectangle.SetBounds(NewLeft, NewTop, Width, 1);
        FRectangle2.SetBounds(NewLeft, NewTop + Height, Width, 1);
        FRectangle3.SetBounds(NewLeft, NewTop, 1, Height);
        FRectangle4.SetBounds(NewLeft + Width, NewTop, 1, Height);
        Parent.Update;
      end;
    end;
  end;
end;

procedure TRpSizePosInterface.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  NewLeft, NewTop, deltaTwipsX, deltaTwipsY: Integer;
  positem: TRpCommonPosComponent;
  selList: TList;
  i: Integer;
  item: TRpSizePosInterface;
  wasMulti: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then
    Exit;

  selList := nil;
  if Assigned(OnGetSelectedList) then
    selList := OnGetSelectedList()
  else if Assigned(SectionInt) and Assigned(SectionInt.OnGetSelectedList) then
    selList := SectionInt.OnGetSelectedList();

  wasMulti := Assigned(selList) and (selList.Count > 1) and (selList.IndexOf(Self) >= 0);

  // Clear outline rectangles for all items
  if Assigned(selList) and (selList.IndexOf(Self) >= 0) and (selList.Count > 1) then
  begin
    for i := 0 to selList.Count - 1 do
    begin
      item := TRpSizePosInterface(selList[i]);
      item.ClearRectangles;
    end;
  end
  else
    ClearRectangles;

  if not FBlocked then
  begin
    // Item(s) were dragged!
    NewLeft := Left - FXOrigin + X;
    NewTop := Top - FYOrigin + Y;
    if NewLeft < 0 then NewLeft := 0;
    if NewTop < 0 then NewTop := 0;
    if Assigned(Parent) then
    begin
      if NewLeft + Width > Parent.Width then NewLeft := Parent.Width - Width;
      if NewTop + Height > Parent.Height then NewTop := Parent.Height - Height;
    end;
    if NewLeft < 0 then NewLeft := 0;
    if NewTop < 0 then NewTop := 0;

    if Assigned(printitem) and Assigned(printitem.Report) and
      (printitem.Report is TRpReport) and
      TRpReport(printitem.Report).GridEnabled then
    begin
      NewLeft := AlignToGridPixels(NewLeft, TRpReport(printitem.Report).GridWidth, Scale);
      NewTop := AlignToGridPixels(NewTop, TRpReport(printitem.Report).GridHeight, Scale);
    end;

    if fprintitem is TRpCommonPosComponent then
    begin
      positem := TRpCommonPosComponent(fprintitem);
      deltaTwipsX := pixelstotwips(NewLeft, Scale) - positem.PosX;
      deltaTwipsY := pixelstotwips(NewTop, Scale) - positem.PosY;

      if wasMulti then
      begin
        if Assigned(OnMoveComponent) then
          OnMoveComponent(Self, deltaTwipsX, deltaTwipsY)
        else if Assigned(SectionInt) and Assigned(SectionInt.OnMoveComponent) then
          SectionInt.OnMoveComponent(Self, deltaTwipsX, deltaTwipsY);

        // If Shift/Ctrl is held, toggle Self out of selection
        if (ssShift in Shift) or (ssCtrl in Shift) then
        begin
          if Assigned(OnSelectComponent) then
            OnSelectComponent(Self, True)
          else if Assigned(SectionInt) and Assigned(SectionInt.OnSelectComponent) then
            SectionInt.OnSelectComponent(Self, True);
        end;
        // If Shift/Ctrl is NOT held, multi-selection remains intact!
      end
      else
      begin
        // Single item move
        positem.PosX := pixelstotwips(NewLeft, Scale);
        positem.PosY := pixelstotwips(NewTop, Scale);
        UpdatePos;

        if Assigned(OnSelectComponent) then
          OnSelectComponent(Self, (ssShift in Shift) or (ssCtrl in Shift))
        else if Assigned(SectionInt) and Assigned(SectionInt.OnSelectComponent) then
          SectionInt.OnSelectComponent(Self, (ssShift in Shift) or (ssCtrl in Shift));
      end;
    end;
  end
  else
  begin
    // Simple click without move
    if Assigned(OnSelectComponent) then
      OnSelectComponent(Self, (ssShift in Shift) or (ssCtrl in Shift))
    else if Assigned(SectionInt) and Assigned(SectionInt.OnSelectComponent) then
      SectionInt.OnSelectComponent(Self, (ssShift in Shift) or (ssCtrl in Shift));
  end;
end;

procedure TRpSizePosInterface.Paint;
begin
  inherited Paint;
end;

procedure TRpSizePosInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  positem: TRpCommonPosComponent;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  positem := TRpCommonPosComponent(printitem);
  lnames.Add(SrpSTop);
  ltypes.Add(SRpSCurrency);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then lvalues.Add(gettextfromtwips(positem.PosY));
  lnames.Add(SrpSLeft);
  ltypes.Add(SRpSCurrency);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then lvalues.Add(gettextfromtwips(positem.PosX));
  lnames.Add(SRPAlign);
  ltypes.Add(SRpSList);
  lhints.Add('refcommon.html');
  lcat.Add(SRpPosition);
  if Assigned(lvalues) then lvalues.Add(AlignToStr(positem.Align));
end;

procedure TRpSizePosInterface.SetProperty(pname: string; value: WideString);
var
  positem: TRpCommonPosComponent;
begin
  positem := TRpCommonPosComponent(printitem);
  if pname = SrpSTop then
  begin
    positem.PosY := gettwipsfromtext(value);
    UpdatePos;
    Exit;
  end;
  if pname = SrpSLeft then
  begin
    positem.PosX := gettwipsfromtext(value);
    UpdatePos;
    Exit;
  end;
  if pname = SRPAlign then
  begin
    positem.Align := StrToAlign(value);
    UpdatePos;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpSizePosInterface.GetProperty(pname: string): WideString;
var
  positem: TRpCommonPosComponent;
begin
  positem := TRpCommonPosComponent(printitem);
  if pname = SrpSTop then Result := gettextfromtwips(positem.PosY)
  else if pname = SrpSLeft then Result := gettextfromtwips(positem.PosX)
  else if pname = SRPAlign then Result := AlignToStr(positem.Align)
  else Result := inherited GetProperty(pname);
end;

procedure TRpSizePosInterface.GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings);
begin
  if pname = SRPAlign then
  begin
    lpossiblevalues.Clear;
    lpossiblevalues.Add(SRpNone);
    lpossiblevalues.Add(SRpBottom);
    lpossiblevalues.Add(SRpSRight);
    lpossiblevalues.Add(SRPBottom + '/' + SRpSRight);
    lpossiblevalues.Add(SRPLeftRight);
    lpossiblevalues.Add(SRPTopBottom);
    lpossiblevalues.Add(SRPAllClient);
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

{ TRpGenTextInterface }

constructor TRpGenTextInterface.Create(AOwner: TComponent; pritem: TRpCommonComponent);
begin
  if not (pritem is TRpGenTextComponent) then
    raise Exception.Create(SRpIncorrectComponentForInterface);
  inherited Create(AOwner, pritem);
end;

class procedure TRpGenTextInterface.FillAncestors(alist: TStrings);
begin
  inherited FillAncestors(alist);
  alist.Add('TRpGenTextInterface');
end;

procedure TRpGenTextInterface.InitPopUpMenu;
begin
  inherited InitPopUpMenu;
end;

procedure TRpGenTextInterface.GetProperties(lnames, ltypes, lvalues, lhints, lcat: TRpWideStrings);
var
  titem: TRpGenTextComponent;
begin
  inherited GetProperties(lnames, ltypes, lvalues, lhints, lcat);
  titem := TRpGenTextComponent(printitem);

  lnames.Add(SrpSAlignment);
  ltypes.Add(SRpSList);
  lhints.Add('refcommontext.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) then lvalues.Add(HAlignmentToText(titem.Alignment));

  lnames.Add(SrpSWFontName);
  ltypes.Add(SRpSWFontName);
  lhints.Add('refcommontext.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) then lvalues.Add(titem.WFontName);

  lnames.Add(SrpSFontSize);
  ltypes.Add(SRpSFontSize);
  lhints.Add('refcommontext.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) then lvalues.Add(IntToStr(titem.FontSize));

  lnames.Add(SrpSFontColor);
  ltypes.Add(SRpSColor);
  lhints.Add('refcommontext.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) then lvalues.Add(IntToStr(titem.FontColor));

  lnames.Add(SrpSTransparent);
  ltypes.Add(SRpSBool);
  lhints.Add('refcommontext.html');
  lcat.Add(SRpText);
  if Assigned(lvalues) then lvalues.Add(BoolToStr(titem.Transparent, True));
end;

procedure TRpGenTextInterface.SetProperty(pname: string; value: WideString);
var
  titem: TRpGenTextComponent;
begin
  titem := TRpGenTextComponent(printitem);
  if pname = SrpSAlignment then
  begin
    titem.Alignment := StringHAlignmentToInt(value);
    Invalidate;
    Exit;
  end;
  if pname = SrpSWFontName then
  begin
    titem.WFontName := value;
    Invalidate;
    Exit;
  end;
  if pname = SrpSFontSize then
  begin
    titem.FontSize := StrToIntDef(value, 10);
    Invalidate;
    Exit;
  end;
  if pname = SrpSFontColor then
  begin
    titem.FontColor := StrToIntDef(value, 0);
    Invalidate;
    Exit;
  end;
  if pname = SrpSTransparent then
  begin
    titem.Transparent := StrToBoolDef(value, True);
    Invalidate;
    Exit;
  end;
  inherited SetProperty(pname, value);
end;

function TRpGenTextInterface.GetProperty(pname: string): WideString;
var
  titem: TRpGenTextComponent;
begin
  titem := TRpGenTextComponent(printitem);
  if pname = SrpSWFontName then Result := titem.WFontName
  else if pname = SrpSFontSize then Result := IntToStr(titem.FontSize)
  else if pname = SrpSFontColor then Result := IntToStr(titem.FontColor)
  else if pname = SrpSTransparent then Result := BoolToStr(titem.Transparent, True)
  else Result := inherited GetProperty(pname);
end;

procedure TRpGenTextInterface.GetPropertyValues(pname: string; lpossiblevalues: TRpWideStrings);
begin
  if pname = SrpSAlignment then
  begin
    lpossiblevalues.Clear;
    lpossiblevalues.Add(SrpSAlignLeft);
    lpossiblevalues.Add(SrpSAlignRight);
    lpossiblevalues.Add(SrpSAlignCenter);
    lpossiblevalues.Add(SrpSAlignJustify);
    Exit;
  end;
  inherited GetPropertyValues(pname, lpossiblevalues);
end;

{ TRpBlackControl }

constructor TRpBlackControl.Create(AOwner: TComponent);
var
  opts: TControlStyle;
begin
  inherited Create(AOwner);
  Width := CONS_MODIWIDTH;
  Height := CONS_MODIWIDTH;
  opts := ControlStyle;
  Include(opts, csCaptureMouse);
  ControlStyle := opts;
end;

destructor TRpBlackControl.Destroy;
begin
  ClearRectangles;
  inherited Destroy;
end;

procedure TRpBlackControl.ClearRectangles;
begin
  FreeAndNil(FRectangle);
  FreeAndNil(FRectangle2);
  FreeAndNil(FRectangle3);
  FreeAndNil(FRectangle4);
end;

procedure TRpBlackControl.Paint;
begin
  Canvas.Brush.Color := clBlack;
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Style := psSolid;
  Canvas.Rectangle(0, 0, Width, Height);
end;

procedure TRpBlackControl.CalcNewCoords(var NewLeft, NewTop, NewWidth, NewHeight, X, Y: Integer);
var
  gridX, gridY: Integer;
  gridOn: Boolean;
  cScale: Double;
begin
  if not Assigned(Control) then Exit;
  NewLeft := Control.Left;
  NewTop := Control.Top;
  NewWidth := Control.Width;
  NewHeight := Control.Height;

  gridOn := False;
  gridX := 1;
  gridY := 1;
  cScale := 1.0;
  if Assigned(Owner) and (Owner is TRpSizeModifier) then
  begin
    gridOn := TRpSizeModifier(Owner).GridEnabled;
    gridX := TRpSizeModifier(Owner).GridX;
    gridY := TRpSizeModifier(Owner).GridY;
  end;
  if Assigned(Control) and (Control is TRpSizeInterface) then
    cScale := TRpSizeInterface(Control).Scale;

  case Tag of
    0: // Top-Left
    begin
      NewLeft := Control.Left - FXOrigin + X;
      NewTop := Control.Top - FYOrigin + Y;
      if gridOn then
      begin
        NewLeft := AlignToGridPixels(NewLeft, gridX, cScale);
        NewTop := AlignToGridPixels(NewTop, gridY, cScale);
      end;
      if NewLeft < 0 then NewLeft := 0;
      if NewTop < 0 then NewTop := 0;
      NewWidth := Control.Width + (Control.Left - NewLeft);
      NewHeight := Control.Height + (Control.Top - NewTop);
    end;
    1: // Top-Right
    begin
      NewTop := Control.Top - FYOrigin + Y;
      NewWidth := Control.Width - FXOrigin + X;
      if gridOn then
      begin
        NewWidth := AlignToGridPixels(NewLeft + NewWidth, gridX, cScale) - NewLeft;
        NewTop := AlignToGridPixels(NewTop, gridY, cScale);
      end;
      if NewTop < 0 then NewTop := 0;
      NewHeight := Control.Height + (Control.Top - NewTop);
    end;
    2: // Bottom-Left
    begin
      NewLeft := Control.Left - FXOrigin + X;
      NewHeight := Control.Height - FYOrigin + Y;
      if gridOn then
      begin
        NewLeft := AlignToGridPixels(NewLeft, gridX, cScale);
        NewHeight := AlignToGridPixels(NewTop + NewHeight, gridY, cScale) - NewTop;
      end;
      if NewLeft < 0 then NewLeft := 0;
      NewWidth := Control.Width + (Control.Left - NewLeft);
    end;
    3: // Bottom-Right
    begin
      NewWidth := Control.Width - FXOrigin + X;
      NewHeight := Control.Height - FYOrigin + Y;
      if gridOn then
      begin
        NewWidth := AlignToGridPixels(NewLeft + NewWidth, gridX, cScale) - NewLeft;
        NewHeight := AlignToGridPixels(NewTop + NewHeight, gridY, cScale) - NewTop;
      end;
    end;
  end;

  if Assigned(Control) and Assigned(Control.Parent) then
  begin
    if NewLeft + NewWidth > Control.Parent.Width then
      NewWidth := Control.Parent.Width - NewLeft;
    if NewTop + NewHeight > Control.Parent.Height then
      NewHeight := Control.Parent.Height - NewTop;
  end;

  if NewWidth < CONS_MINWIDTH then NewWidth := CONS_MINWIDTH;
  if NewHeight < CONS_MINHEIGHT then NewHeight := CONS_MINHEIGHT;
end;

procedure TRpBlackControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Assigned(FControl) or not Assigned(FControl.Parent) then
    Exit;

  ClearRectangles;
  FRectangle := TRpRectangle.Create(Self);
  FRectangle2 := TRpRectangle.Create(Self);
  FRectangle3 := TRpRectangle.Create(Self);
  FRectangle4 := TRpRectangle.Create(Self);
  FRectangle.Parent := FControl.Parent;
  FRectangle2.Parent := FControl.Parent;
  FRectangle3.Parent := FControl.Parent;
  FRectangle4.Parent := FControl.Parent;

  FRectangle.SetBounds(FControl.Left, FControl.Top, FControl.Width, 1);
  FRectangle2.SetBounds(FControl.Left, FControl.Top + FControl.Height, FControl.Width, 1);
  FRectangle3.SetBounds(FControl.Left, FControl.Top, 1, FControl.Height);
  FRectangle4.SetBounds(FControl.Left + FControl.Width, FControl.Top, 1, FControl.Height);

  FXOrigin := X;
  FYOrigin := Y;
end;

procedure TRpBlackControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewLeft, NewTop, NewWidth, NewHeight: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if MouseCapture and Assigned(FControl) and Assigned(FRectangle) then
  begin
    CalcNewCoords(NewLeft, NewTop, NewWidth, NewHeight, X, Y);
    FRectangle.SetBounds(NewLeft, NewTop, NewWidth, 1);
    FRectangle2.SetBounds(NewLeft, NewTop + NewHeight, NewWidth, 1);
    FRectangle3.SetBounds(NewLeft, NewTop, 1, NewHeight);
    FRectangle4.SetBounds(NewLeft + NewWidth, NewTop, 1, NewHeight);
    if Assigned(FRectangle.Parent) then
      FRectangle.Parent.Update;
  end;
end;

procedure TRpBlackControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  NewLeft, NewTop, NewWidth, NewHeight: Integer;
  sint: TRpSizeInterface;
  positem: TRpCommonPosComponent;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Assigned(FRectangle) then
  begin
    ClearRectangles;
    CalcNewCoords(NewLeft, NewTop, NewWidth, NewHeight, X, Y);

    if Assigned(FControl) and (FControl is TRpSizeInterface) then
    begin
      sint := TRpSizeInterface(FControl);
      if Assigned(sint.printitem) and (sint.printitem is TRpCommonPosComponent) then
      begin
        positem := TRpCommonPosComponent(sint.printitem);
        positem.PosX := pixelstotwips(NewLeft, sint.Scale);
        positem.PosY := pixelstotwips(NewTop, sint.Scale);
        positem.Width := pixelstotwips(NewWidth, sint.Scale);
        positem.Height := pixelstotwips(NewHeight, sint.Scale);
        sint.UpdatePos;
      end;
    end;

    if Assigned(Owner) and (Owner is TRpSizeModifier) then
    begin
      TRpSizeModifier(Owner).UpdatePos;
      if Assigned(TRpSizeModifier(Owner).OnSizeChange) then
        TRpSizeModifier(Owner).OnSizeChange(Owner);
    end;
  end;
end;

{ TRpSizeModifier }

constructor TRpSizeModifier.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited Create(AOwner);
  for i := 0 to 3 do
  begin
    FBlacks[i] := TRpBlackControl.Create(Self);
    FBlacks[i].Tag := i;
    FBlacks[i].Visible := False;
  end;
  FBlacks[0].Cursor := crSizeNWSE;
  FBlacks[1].Cursor := crSizeNESW;
  FBlacks[2].Cursor := crSizeNESW;
  FBlacks[3].Cursor := crSizeNWSE;
end;

procedure TRpSizeModifier.SetControl(Value: TControl);
var
  i: Integer;
begin
  FControl := Value;
  for i := 0 to 3 do
    FBlacks[i].Control := FControl;
  UpdatePos;
end;

procedure TRpSizeModifier.SetOnlySize(Value: Boolean);
begin
  FOnlysize := Value;
  UpdatePos;
end;

procedure TRpSizeModifier.SetAllowOversize(Value: Boolean);
var
  i: Integer;
begin
  FAllowOverSize := Value;
  for i := 0 to 3 do
    FBlacks[i].FAllowOverSize := Value;
end;

procedure TRpSizeModifier.UpdatePos;
var
  i: Integer;
  w: Integer;
begin
  if not Assigned(FControl) or not Assigned(FControl.Parent) then
  begin
    for i := 0 to 3 do
      FBlacks[i].Parent := nil;
    Exit;
  end;

  for i := 0 to 3 do
    FBlacks[i].Parent := FControl.Parent;

  w := ScaleDpi(CONS_MODIWIDTH);
  FBlacks[0].SetBounds(FControl.Left - w div 2, FControl.Top - w div 2, w, w);
  FBlacks[1].SetBounds(FControl.Left + FControl.Width - w div 2, FControl.Top - w div 2, w, w);
  FBlacks[2].SetBounds(FControl.Left - w div 2, FControl.Top + FControl.Height - w div 2, w, w);
  FBlacks[3].SetBounds(FControl.Left + FControl.Width - w div 2, FControl.Top + FControl.Height - w div 2, w, w);

  if FOnlysize then
  begin
    FBlacks[0].Visible := False;
    FBlacks[1].Visible := False;
    FBlacks[2].Visible := False;
    FBlacks[3].Visible := True;
    FBlacks[3].BringToFront;
  end
  else
  begin
    for i := 0 to 3 do
    begin
      FBlacks[i].Visible := True;
      FBlacks[i].BringToFront;
    end;
  end;
end;

end.

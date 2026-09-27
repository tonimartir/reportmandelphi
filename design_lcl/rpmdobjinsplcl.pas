{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdobjinsplcl                                  }
{                                                       }
{       Object inspector frame for LCL                  }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdobjinsplcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Types,
  Graphics, Forms, Controls, Dialogs, Menus, ExtCtrls, StdCtrls, ComCtrls,
  rpmdconsts, rpmunits, rpprintitem, rpgraphutilslcl,
  rpsection, rpreport, rpsubreport, rptypes,
  rpmdobinsintlcl, rpmdflabelintlcl, rpmdfdrawintlcl, rpmdfbarcodeintlcl,
  rpmdfchartintlcl, rpmdfsectionintlcl;

const
  CONS_LEFTGAP = 3;
  CONS_CONTROLPOS = 90;
  CONS_LABELTOPGAP = 2;
  CONS_RIGHTBARGAP = 4;
  CONS_MINWIDTH = 160;

type
  TRpPanelObjLCL = class;

  { TFRpObjInspLCL }

  TFRpObjInspLCL = class(TFrame)
    ColorDialog1: TColorDialog;
    FontDialog1: TFontDialog;
    OpenDialog1: TOpenDialog;
    PopUpSection: TPopupMenu;
    MLoadExternal: TMenuItem;
    MSaveExternal: TMenuItem;
    procedure MLoadExternalClick(Sender: TObject);
    procedure MSaveExternalClick(Sender: TObject);
  private
    FPropPanels: TStringList;
    FDesignFrame: TObject;
    FSelectedItems: TStringList;
    FCommonObject: TRpSizePosInterface;
    FClasses: TStringList;
    FClassAncestors: TStringList;
    procedure AddCompItemPos(aitem: TRpSizePosInterface; onlyone: Boolean);
    procedure SetCompItem(Value: TRpSizeInterface);
    function CreatePanel(acompo: TRpSizeInterface): TRpPanelObjLCL;
    function GetComboBox: TComboBox;
    function GetCompItem: TRpSizeInterface;
    function GetCurrentPanel: TRpPanelObjLCL;
    function GetCommonClassName: string;
    function FindCommonClass(baseclass, newclass: string): string;
    procedure RecordSelectionPositions(const oldPosX, oldPosY: array of Integer);
    procedure DoAlignSelected(direction: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FindPanelForClass(acompo: TRpSizeInterface): TRpPanelObjLCL;
    procedure ClearMultiSelect;
    procedure ClearCompItemRefs;
    procedure InvalidatePanels;
    procedure SelectProperty(propname: string);
    procedure SelectAllClass(classname: string);
    procedure AddCompItem(aitem: TRpSizeInterface; onlyone: Boolean);
    procedure AlignSelected(direction: Integer);
    procedure MoveSelected(direction: Integer; fast: Boolean);
    procedure UpdatePosValues;
    property CompItem: TRpSizeInterface read GetCompItem;
    property CurrentPanel: TRpPanelObjLCL read GetCurrentPanel;
    property DesignFrame: TObject read FDesignFrame write FDesignFrame;
    property Combo: TComboBox read GetComboBox;
    property SelectedItems: TStringList read FSelectedItems;
  end;

  { TRpPageObjLCL }

  TRpPageObjLCL = class(TTabSheet)
  public
    PRight, PLeft, PParent: TPanel;
    AScrollBox: TScrollBox;
    PosY: Integer;
  end;

  { TRpPanelObjLCL }

  TRpPanelObjLCL = class(TPanel)
  private
    FCompItem: TRpSizeInterface;
    FSelectedItems: TStringList;
    subrep: TRpSubreport;
    LNames: TRpWideStrings;
    LTypes: TRpWideStrings;
    LValues: TRpWideStrings;
    LHints: TRpWideStrings;
    LCat: TRpWideStrings;
    FCombo: TComboBox;
    LLabels: TList;
    LControls: TStringList;
    LControls2: TStringList;
    AList: TStringList;
    comboalias: TComboBox;
    comboprintonly: TComboBox;
    FPControl: TPageControl;
    FUpdatingValues: Boolean;
    procedure ComboObjectChange(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure ShapeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FontClick(Sender: TObject);
    procedure ExpressionClick(Sender: TObject);
    procedure ExtClick(Sender: TObject);
    procedure ImageClick(Sender: TObject);
    procedure ImageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ComboAliasChange(Sender: TObject);
    procedure ComboPrintOnlyChange(Sender: TObject);
    procedure UpdatePosValues;
    procedure CreateControlsSubReport;
    procedure DupValue(Sender: TControl);
    procedure RefreshCueView;
    function GetTargetItems: TList;
    procedure ApplyPropertyValues(items: TList; const propnames: array of string;
      const values: array of WideString; stream: TMemoryStream = nil);
    procedure SendToBackClick(Sender: TObject);
    procedure BringToFrontClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateControls(acompo: TRpSizeInterface);
    procedure AssignPropertyValues;
    procedure SelectProperty(propname: string);
    procedure SetPropertyFull(propname: string; value: WideString); overload;
    procedure SetPropertyFull(propname: string; stream: TMemoryStream); overload;
    property CompItem: TRpSizeInterface read FCompItem write FCompItem;
    property SubReport: TRpSubreport read subrep write subrep;
    property Combo: TComboBox read FCombo;
    property ControlsList: TStringList read LControls;
  end;

function FindClassName(acompo: TRpSizeInterface): string;

implementation

{$R *.lfm}

uses
  rpmdfdesignlcl, rpmdfstruclcl, rpexpredlglcl, rpmdfextseclcl, rpmdundocuelcl;

function FindClassName(acompo: TRpSizeInterface): string;
var
  asec: TRpSection;
begin
  if not Assigned(acompo) then
  begin
    Result := 'TRpSubReport';
    Exit;
  end;
  if acompo is TRpSectionInterface then
  begin
    asec := TRpSection(TRpSectionInterface(acompo).printitem);
    if Assigned(asec) then
    begin
      case asec.SectionType of
        rpsecgheader: Result := 'TRpSectionGroupHeader';
        rpsecgfooter: Result := 'TRpSectionGroupFooter';
        rpsecdetail:  Result := 'TRpSectionDetail';
        rpsecpheader: Result := 'TRpSectionPageHeader';
        rpsecpfooter: Result := 'TRpSectionPageFooter';
      else
        Result := 'TRpSectionInterface';
      end;
    end
    else
      Result := 'TRpSectionInterface';
  end
  else
    Result := acompo.ClassName;
end;

function GetFalseBoolStr: string;
begin
  if Length(FalseBoolStrs) > 0 then
    Result := FalseBoolStrs[0]
  else
    Result := 'False';
end;

function GetTrueBoolStr: string;
begin
  if Length(TrueBoolStrs) > 0 then
    Result := TrueBoolStrs[0]
  else
    Result := 'True';
end;

// InspectorUndoProperty (inspector name -> model undo property) lives in
// rpmdobinsintlcl, shared with the design items (context menu actions)

{ TRpPanelObjLCL }

constructor TRpPanelObjLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Align := alClient;
  BorderStyle := bsNone;
  BevelInner := bvNone;
  BevelOuter := bvNone;

  LNames := TRpWideStrings.Create;
  LTypes := TRpWideStrings.Create;
  LValues := TRpWideStrings.Create;
  LHints := TRpWideStrings.Create;
  LCat := TRpWideStrings.Create;
  LLabels := TList.Create;
  LControls := TStringList.Create;
  LControls2 := TStringList.Create;
  AList := TStringList.Create;
  FUpdatingValues := False;
end;

destructor TRpPanelObjLCL.Destroy;
begin
  LNames.Free;
  LTypes.Free;
  LValues.Free;
  LHints.Free;
  LCat.Free;
  LLabels.Free;
  LControls.Free;
  LControls2.Free;
  AList.Free;
  inherited Destroy;
end;

procedure TRpPanelObjLCL.CreateControlsSubReport;
var
  posy, aheight: Integer;
  AScrollBox: TScrollBox;
  PParent, PLeft, PRight: TPanel;
  Psplit: TSplitter;
  ALabel: TLabel;
begin
  posy := 0;
  aheight := 24;

  AScrollBox := TScrollBox.Create(Self);
  AScrollBox.Align := alClient;
  AScrollBox.BorderStyle := bsNone;
  AScrollBox.Parent := Self;

  PParent := TPanel.Create(Self);
  PParent.Align := alTop;
  PParent.BorderStyle := bsNone;
  PParent.BevelInner := bvNone;
  PParent.BevelOuter := bvNone;
  PParent.Height := 200;
  PParent.Parent := AScrollBox;

  PLeft := TPanel.Create(Self);
  PLeft.Width := CONS_CONTROLPOS;
  PLeft.BorderStyle := bsNone;
  PLeft.BevelInner := bvNone;
  PLeft.BevelOuter := bvNone;
  PLeft.Align := alLeft;
  PLeft.Parent := PParent;

  Psplit := TSplitter.Create(Self);
  Psplit.ResizeStyle := rsUpdate;
  Psplit.Cursor := crHSplit;
  Psplit.MinSize := 10;
  Psplit.Width := 4;
  Psplit.Align := alLeft;
  Psplit.Parent := PParent;

  PRight := TPanel.Create(Self);
  PRight.BorderStyle := bsNone;
  PRight.BevelInner := bvNone;
  PRight.BevelOuter := bvNone;
  PRight.Align := alClient;
  PRight.Parent := PParent;

  // Main dataset
  ALabel := TLabel.Create(Self);
  LLabels.Add(ALabel);
  ALabel.Caption := SRpMainDataset;
  ALabel.Left := CONS_LEFTGAP;
  ALabel.Top := posy + CONS_LABELTOPGAP;
  ALabel.Parent := PLeft;

  ComboAlias := TComboBox.Create(Self);
  ComboAlias.Style := csDropDownList;
  ComboAlias.Top := posy;
  ComboAlias.Left := CONS_LEFTGAP;
  ComboAlias.Width := PRight.Width - CONS_LEFTGAP - CONS_RIGHTBARGAP;
  ComboAlias.Anchors := [akLeft, akTop, akRight];
  ComboAlias.OnChange := ComboAliasChange;
  ComboAlias.Parent := PRight;

  posy := posy + aheight + 2;

  // Print only if data available
  ALabel := TLabel.Create(Self);
  LLabels.Add(ALabel);
  ALabel.Caption := SRpSPOnlyData;
  ALabel.Left := CONS_LEFTGAP;
  ALabel.Top := posy + CONS_LABELTOPGAP;
  ALabel.Parent := PLeft;

  ComboPrintOnly := TComboBox.Create(Self);
  ComboPrintOnly.Style := csDropDownList;
  ComboPrintOnly.Items.Add(GetFalseBoolStr);
  ComboPrintOnly.Items.Add(GetTrueBoolStr);
  ComboPrintOnly.Top := posy;
  ComboPrintOnly.Left := CONS_LEFTGAP;
  ComboPrintOnly.Width := PRight.Width - CONS_LEFTGAP - CONS_RIGHTBARGAP;
  ComboPrintOnly.Anchors := [akLeft, akTop, akRight];
  ComboPrintOnly.OnChange := ComboPrintOnlyChange;
  ComboPrintOnly.Parent := PRight;

  posy := posy + aheight + 2;
  PParent.Height := posy;
end;

procedure TRpPanelObjLCL.CreateControls(acompo: TRpSizeInterface);
var
  posy, aheight, i, j: Integer;
  ALabel: TLabel;
  control, NControl: TControl;
  typename: string;
  btn1, btn2: TButton;
  APanelTop, APanelBottom: TPanel;
  APControl: TPageControl;
  pageall, apage: TRpPageObjLCL;
  AScrollBox, NScrollBox: TScrollBox;
  PParent, PLeft, PRight: TPanel;
  Psplit: TSplitter;
  createpage: Boolean;
begin
  apage := nil;
  FCompItem := acompo;
  aheight := 24;

  // Top combobox container
  APanelTop := TPanel.Create(Self);
  APanelTop.BevelInner := bvNone;
  APanelTop.BevelOuter := bvNone;
  APanelTop.Align := alTop;
  APanelTop.Height := aheight + 2;
  APanelTop.Parent := Self;

  FCombo := TComboBox.Create(Self);
  FCombo.Align := alClient;
  FCombo.Style := csDropDownList;
  FCombo.OnChange := ComboObjectChange;
  FCombo.Parent := APanelTop;

  // PageControl for categories
  APControl := TPageControl.Create(Self);
  APControl.Align := alClient;
  APControl.Parent := Self;
  FPControl := APControl;

  // "All" Tab
  pageall := TRpPageObjLCL.Create(Self);
  pageall.Caption := SRpAllProps;
  pageall.PageControl := APControl;
  APControl.ActivePageIndex := 0;

  AScrollBox := TScrollBox.Create(Self);
  AScrollBox.Align := alClient;
  AScrollBox.BorderStyle := bsNone;
  AScrollBox.Parent := pageall;
  pageall.AScrollBox := AScrollBox;

  PParent := TPanel.Create(Self);
  PParent.Align := alTop;
  PParent.BorderStyle := bsNone;
  PParent.BevelInner := bvNone;
  PParent.BevelOuter := bvNone;
  PParent.Parent := AScrollBox;
  pageall.PParent := PParent;

  PLeft := TPanel.Create(Self);
  PLeft.Width := CONS_CONTROLPOS;
  PLeft.BorderStyle := bsNone;
  PLeft.BevelInner := bvNone;
  PLeft.BevelOuter := bvNone;
  PLeft.Align := alLeft;
  PLeft.Parent := PParent;

  Psplit := TSplitter.Create(Self);
  Psplit.ResizeStyle := rsUpdate;
  Psplit.Cursor := crHSplit;
  Psplit.MinSize := 10;
  Psplit.Width := 4;
  Psplit.Align := alLeft;
  Psplit.Parent := PParent;

  PRight := TPanel.Create(Self);
  PRight.BorderStyle := bsNone;
  PRight.BevelInner := bvNone;
  PRight.BevelOuter := bvNone;
  PRight.Align := alClient;
  PRight.Parent := PParent;

  posy := 0;
  FCompItem.GetProperties(LNames, LTypes, nil, LHints, LCat);

  for i := 0 to LNames.Count - 1 do
  begin
    // Check or create category tab
    createpage := False;
    if not Assigned(apage) or (apage.Caption <> LCat.Strings[i]) then
      createpage := True;

    if createpage then
    begin
      for j := 0 to APControl.PageCount - 1 do
      begin
        if APControl.Pages[j].Caption = LCat.Strings[i] then
        begin
          createpage := False;
          apage := TRpPageObjLCL(APControl.Pages[j]);
          Break;
        end;
      end;
    end;

    if createpage then
    begin
      apage := TRpPageObjLCL.Create(Self);
      apage.Caption := LCat.Strings[i];
      apage.PageControl := APControl;
      apage.PosY := 0;

      NScrollBox := TScrollBox.Create(Self);
      NScrollBox.Align := alClient;
      NScrollBox.BorderStyle := bsNone;
      NScrollBox.Parent := apage;
      apage.AScrollBox := NScrollBox;

      apage.PParent := TPanel.Create(Self);
      apage.PParent.Align := alTop;
      apage.PParent.BorderStyle := bsNone;
      apage.PParent.BevelInner := bvNone;
      apage.PParent.BevelOuter := bvNone;
      apage.PParent.Parent := NScrollBox;

      apage.PLeft := TPanel.Create(Self);
      apage.PLeft.Width := CONS_CONTROLPOS;
      apage.PLeft.BorderStyle := bsNone;
      apage.PLeft.BevelInner := bvNone;
      apage.PLeft.BevelOuter := bvNone;
      apage.PLeft.Align := alLeft;
      apage.PLeft.Parent := apage.PParent;

      Psplit := TSplitter.Create(Self);
      Psplit.ResizeStyle := rsUpdate;
      Psplit.Cursor := crHSplit;
      Psplit.MinSize := 10;
      Psplit.Width := 4;
      Psplit.Align := alLeft;
      Psplit.Parent := apage.PParent;

      apage.PRight := TPanel.Create(Self);
      apage.PRight.BorderStyle := bsNone;
      apage.PRight.BevelInner := bvNone;
      apage.PRight.BevelOuter := bvNone;
      apage.PRight.Align := alClient;
      apage.PRight.Parent := apage.PParent;
    end;

    // Label for PageAll
    ALabel := TLabel.Create(Self);
    LLabels.Add(ALabel);
    ALabel.Caption := LNames.Strings[i];
    ALabel.Left := CONS_LEFTGAP;
    ALabel.Top := posy + CONS_LABELTOPGAP;
    ALabel.Parent := PLeft;

    // Label for Category page
    ALabel := TLabel.Create(Self);
    LLabels.Add(ALabel);
    ALabel.Caption := LNames.Strings[i];
    ALabel.Left := CONS_LEFTGAP;
    ALabel.Top := apage.PosY + CONS_LABELTOPGAP;
    ALabel.Parent := apage.PLeft;

    typename := LTypes.Strings[i];

    if typename = SRpSBool then
    begin
      control := TComboBox.Create(Self);
      TComboBox(control).Items.Add(GetFalseBoolStr);
      TComboBox(control).Items.Add(GetTrueBoolStr);
      TComboBox(control).Style := csDropDownList;
      TComboBox(control).OnChange := EditChange;

      NControl := TComboBox.Create(Self);
      TComboBox(NControl).Items.Add(GetFalseBoolStr);
      TComboBox(NControl).Items.Add(GetTrueBoolStr);
      TComboBox(NControl).Style := csDropDownList;
      TComboBox(NControl).OnChange := EditChange;
    end
    else if typename = SRpSList then
    begin
      control := TComboBox.Create(Self);
      FCompItem.GetPropertyValues(LNames.Strings[i], TComboBox(control).Items);
      TComboBox(control).Style := csDropDownList;
      TComboBox(control).OnChange := EditChange;

      NControl := TComboBox.Create(Self);
      FCompItem.GetPropertyValues(LNames.Strings[i], TComboBox(NControl).Items);
      TComboBox(NControl).Style := csDropDownList;
      TComboBox(NControl).OnChange := EditChange;
    end
    else if typename = SRpSColor then
    begin
      control := TShape.Create(Self);
      control.Height := aheight - 2;
      TShape(control).Shape := stRectangle;
      TShape(control).OnMouseUp := ShapeMouseUp;

      NControl := TShape.Create(Self);
      NControl.Height := aheight - 2;
      TShape(NControl).Shape := stRectangle;
      TShape(NControl).OnMouseUp := ShapeMouseUp;
    end
    else if typename = SRpSImage then
    begin
      control := TEdit.Create(Self);
      TEdit(control).ReadOnly := True;
      TEdit(control).Color := clInfoBk;
      TEdit(control).OnClick := ImageClick;
      TEdit(control).OnKeyDown := ImageKeyDown;

      NControl := TEdit.Create(Self);
      TEdit(NControl).ReadOnly := True;
      TEdit(NControl).Color := clInfoBk;
      TEdit(NControl).OnClick := ImageClick;
      TEdit(NControl).OnKeyDown := ImageKeyDown;
    end
    else if typename = SRpGroup then
    begin
      control := TComboBox.Create(Self);
      TComboBox(control).Style := csDropDownList;
      TComboBox(control).OnChange := EditChange;

      NControl := TComboBox.Create(Self);
      TComboBox(NControl).Style := csDropDownList;
      TComboBox(NControl).OnChange := EditChange;
    end
    // The font dialog sets the (Windows) font name, size, color and style;
    // the Linux font name is typed (a plain edit, as the VCL inspector)
    else if (typename = SRpSWFontName) or (typename = SRpSFontStyle) then
    begin
      control := TEdit.Create(Self);
      TEdit(control).ReadOnly := True;
      TEdit(control).Color := clInfoBk;
      TEdit(control).OnClick := FontClick;
      TEdit(control).OnDblClick := FontClick;

      NControl := TEdit.Create(Self);
      TEdit(NControl).ReadOnly := True;
      TEdit(NControl).Color := clInfoBk;
      TEdit(NControl).OnClick := FontClick;
      TEdit(NControl).OnDblClick := FontClick;
    end
    else if typename = SRpSExpression then
    begin
      control := TEdit.Create(Self);
      TEdit(control).OnChange := EditChange;
      TEdit(control).OnDblClick := ExpressionClick;

      NControl := TEdit.Create(Self);
      TEdit(NControl).OnChange := EditChange;
      TEdit(NControl).OnDblClick := ExpressionClick;
    end
    else if typename = SRpSExternalData then
    begin
      control := TEdit.Create(Self);
      TEdit(control).ReadOnly := True;
      TEdit(control).Color := clInfoBk;
      TEdit(control).OnClick := ExtClick;
      TEdit(control).OnDblClick := ExtClick;
      TEdit(control).PopupMenu := TFRpObjInspLCL(Owner).PopUpSection;

      NControl := TEdit.Create(Self);
      TEdit(NControl).ReadOnly := True;
      TEdit(NControl).Color := clInfoBk;
      TEdit(NControl).OnClick := ExtClick;
      TEdit(NControl).OnDblClick := ExtClick;
      TEdit(NControl).PopupMenu := TFRpObjInspLCL(Owner).PopUpSection;
    end
    else
    begin
      control := TEdit.Create(Self);
      TEdit(control).OnChange := EditChange;

      NControl := TEdit.Create(Self);
      TEdit(NControl).OnChange := EditChange;
      // Load/save of the external section file (as the VCL inspector)
      if typename = SRpSExternalpath then
      begin
        TEdit(control).PopupMenu := TFRpObjInspLCL(Owner).PopUpSection;
        TEdit(NControl).PopupMenu := TFRpObjInspLCL(Owner).PopUpSection;
      end;
    end;

    control.Top := posy;
    control.Left := CONS_LEFTGAP;
    control.Width := PRight.Width - CONS_LEFTGAP - CONS_RIGHTBARGAP;
    control.Anchors := [akLeft, akTop, akRight];
    control.Parent := PRight;

    NControl.Top := apage.PosY;
    NControl.Left := CONS_LEFTGAP;
    NControl.Width := apage.PRight.Width - CONS_LEFTGAP - CONS_RIGHTBARGAP;
    NControl.Anchors := [akLeft, akTop, akRight];
    NControl.Parent := apage.PRight;

    if typename = SRpSExpression then
    begin
      control.Width := control.Width - 26;
      NControl.Width := NControl.Width - 26;

      btn1 := TButton.Create(Self);
      btn1.Parent := PRight;
      btn1.Width := 24;
      btn1.Height := control.Height;
      btn1.Top := posy;
      btn1.Left := PRight.Width - CONS_RIGHTBARGAP - 24;
      btn1.Caption := '...';
      btn1.Tag := i;
      btn1.OnClick := ExpressionClick;
      btn1.Anchors := [akTop, akRight];

      btn2 := TButton.Create(Self);
      btn2.Parent := apage.PRight;
      btn2.Width := 24;
      btn2.Height := NControl.Height;
      btn2.Top := apage.PosY;
      btn2.Left := apage.PRight.Width - CONS_RIGHTBARGAP - 24;
      btn2.Caption := '...';
      btn2.Tag := i;
      btn2.OnClick := ExpressionClick;
      btn2.Anchors := [akTop, akRight];
    end;

    control.Tag := i;
    NControl.Tag := i;
    LControls.AddObject(LNames.Strings[i], control);
    LControls2.AddObject(LNames.Strings[i], NControl);

    posy := posy + aheight + 2;
    apage.PosY := apage.PosY + aheight + 2;
  end;

  pageall.PParent.Height := posy;
  for i := 1 to APControl.PageCount - 1 do
    TRpPageObjLCL(APControl.Pages[i]).PParent.Height := TRpPageObjLCL(APControl.Pages[i]).PosY;

  // Send to back and bring to front buttons (as the VCL inspector)
  if FCompItem is TRpSizePosInterface then
  begin
    APanelBottom := TPanel.Create(Self);
    APanelBottom.BevelInner := bvNone;
    APanelBottom.BevelOuter := bvNone;
    APanelBottom.Height := aheight;
    APanelBottom.Align := alBottom;
    APanelBottom.Parent := Self;
    btn1 := TButton.Create(Self);
    btn1.Caption := SRpSendToBack;
    btn1.OnClick := SendToBackClick;
    btn1.Width := ScaleDpi(70);
    btn1.Align := alLeft;
    btn1.Parent := APanelBottom;
    btn2 := TButton.Create(Self);
    btn2.Caption := SRpBringToFront;
    btn2.OnClick := BringToFrontClick;
    btn2.Align := alClient;
    btn2.Parent := APanelBottom;
  end;
end;

procedure TRpPanelObjLCL.AssignPropertyValues;
var
  i, j, k: Integer;
  aitem: TRpSizeInterface;
  typename: string;
  Control, Control2: TControl;
  secint: TRpSectionInterface;
  asecitem: TRpSizePosInterface;
  rep: TRpReport;
begin
  if FUpdatingValues then
    Exit;
  FUpdatingValues := True;
  try
    if not Assigned(FCompItem) then
    begin
      if not Assigned(subrep) then Exit;
      if Assigned(comboalias) then
      begin
        comboalias.OnChange := nil;
        comboalias.Clear;
        if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
           (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) and
           Assigned(TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).Report) then
        begin
          rep := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).Report;
          for i := 0 to rep.DataInfo.Count - 1 do
            comboalias.Items.Add(rep.DataInfo[i].Alias);
        end;
        comboalias.ItemIndex := comboalias.Items.IndexOf(subrep.Alias);
        comboalias.OnChange := ComboAliasChange;
      end;
      if Assigned(comboprintonly) then
      begin
        comboprintonly.OnChange := nil;
        if subrep.PrintOnlyIfDataAvailable then
          comboprintonly.ItemIndex := 1
        else
          comboprintonly.ItemIndex := 0;
        comboprintonly.OnChange := ComboPrintOnlyChange;
      end;
      Exit;
    end;

    // Fill top Combo with components in current section
    if Assigned(FCombo) then
    begin
      FCombo.OnChange := nil;
      AList.Clear;
      AList.Add('');
      secint := nil;
      if FCompItem is TRpSizePosInterface then
        secint := TRpSectionInterface(TRpSizePosInterface(FCompItem).SectionInt)
      else if FCompItem is TRpSectionInterface then
        secint := TRpSectionInterface(FCompItem);

      if Assigned(secint) and Assigned(secint.childlist) then
      begin
        for i := 0 to secint.childlist.Count - 1 do
        begin
          asecitem := TRpSizePosInterface(secint.childlist[i]);
          if Assigned(asecitem.PrintItem) then
            AList.AddObject(asecitem.PrintItem.Name, asecitem);
        end;
      end;
      FCombo.Items.Assign(AList);
      if FSelectedItems.Count > 1 then
        FCombo.ItemIndex := -1
      else if (FCompItem is TRpSizePosInterface) and Assigned(FCompItem.PrintItem) then
        FCombo.ItemIndex := AList.IndexOf(FCompItem.PrintItem.Name)
      else
        FCombo.ItemIndex := -1;
      FCombo.OnChange := ComboObjectChange;
    end;

    // Read properties from component
    FCompItem.GetProperties(LNames, LTypes, nil, LHints, LCat);
    LValues.Clear;
    for j := 0 to LNames.Count - 1 do
      LValues.Add(FCompItem.GetProperty(LNames.Strings[j]));

    for i := 0 to LNames.Count - 1 do
    begin
      if (i >= LControls.Count) or (i >= LControls2.Count) then
        Continue;
      Control := TControl(LControls.Objects[i]);
      Control2 := TControl(LControls2.Objects[i]);
      typename := LTypes.Strings[i];

      if typename = SRpSBool then
      begin
        TComboBox(Control).OnChange := nil;
        TComboBox(Control).ItemIndex := TComboBox(Control).Items.IndexOf(LValues.Strings[i]);
        TComboBox(Control).OnChange := EditChange;

        TComboBox(Control2).OnChange := nil;
        TComboBox(Control2).ItemIndex := TComboBox(Control2).Items.IndexOf(LValues.Strings[i]);
        TComboBox(Control2).OnChange := EditChange;
      end
      else if typename = SRpSList then
      begin
        TComboBox(Control).OnChange := nil;
        TComboBox(Control).ItemIndex := TComboBox(Control).Items.IndexOf(LValues.Strings[i]);
        TComboBox(Control).OnChange := EditChange;

        TComboBox(Control2).OnChange := nil;
        TComboBox(Control2).ItemIndex := TComboBox(Control2).Items.IndexOf(LValues.Strings[i]);
        TComboBox(Control2).OnChange := EditChange;
      end
      else if typename = SRpSColor then
      begin
        if Length(LValues.Strings[i]) > 0 then
        begin
          TShape(Control).Brush.Color := StrToIntDef(LValues.Strings[i], clBlack);
          TShape(Control2).Brush.Color := StrToIntDef(LValues.Strings[i], clBlack);
        end;
      end
      else if typename = SRpSFontStyle then
      begin
        if Length(LValues.Strings[i]) > 0 then
        begin
          TEdit(Control).Text := IntegerFontStyleToString(StrToIntDef(LValues.Strings[i], 0));
          TEdit(Control2).Text := IntegerFontStyleToString(StrToIntDef(LValues.Strings[i], 0));
        end
        else
        begin
          TEdit(Control).Text := '';
          TEdit(Control2).Text := '';
        end;
      end
      else if typename = SRpGroup then
      begin
        TComboBox(Control).OnChange := nil;
        TComboBox(Control).Clear;
        TComboBox(Control2).OnChange := nil;
        TComboBox(Control2).Clear;
        if Assigned(subrep) then
        begin
          subrep.GetGroupNames(TComboBox(Control).Items);
          subrep.GetGroupNames(TComboBox(Control2).Items);
        end;
        TComboBox(Control).Items.Insert(0, '');
        TComboBox(Control2).Items.Insert(0, '');
        TComboBox(Control).ItemIndex := TComboBox(Control).Items.IndexOf(LValues.Strings[i]);
        TComboBox(Control2).ItemIndex := TComboBox(Control2).Items.IndexOf(LValues.Strings[i]);
        TComboBox(Control).OnChange := EditChange;
        TComboBox(Control2).OnChange := EditChange;
      end
      else
      begin
        TEdit(Control).OnChange := nil;
        TEdit(Control).Text := LValues.Strings[i];
        TEdit(Control).OnChange := EditChange;

        TEdit(Control2).OnChange := nil;
        TEdit(Control2).Text := LValues.Strings[i];
        TEdit(Control2).OnChange := EditChange;
      end;
    end;

    // Blank differing values across multi-selected items
    if FSelectedItems.Count > 1 then
    begin
      for k := 1 to FSelectedItems.Count - 1 do
      begin
        aitem := TRpSizeInterface(FSelectedItems.Objects[k]);
        for i := 0 to LNames.Count - 1 do
        begin
          if (i >= LControls.Count) or (i >= LControls2.Count) then
            Continue;
          Control := TControl(LControls.Objects[i]);
          Control2 := TControl(LControls2.Objects[i]);
          if aitem.GetProperty(LNames.Strings[i]) <> LValues.Strings[i] then
          begin
            if Control is TEdit then
            begin
              TEdit(Control).OnChange := nil;
              TEdit(Control).Text := '';
              TEdit(Control).OnChange := EditChange;
              TEdit(Control2).OnChange := nil;
              TEdit(Control2).Text := '';
              TEdit(Control2).OnChange := EditChange;
            end
            else if Control is TComboBox then
            begin
              TComboBox(Control).OnChange := nil;
              TComboBox(Control).ItemIndex := -1;
              TComboBox(Control).OnChange := EditChange;
              TComboBox(Control2).OnChange := nil;
              TComboBox(Control2).ItemIndex := -1;
              TComboBox(Control2).OnChange := EditChange;
            end;
          end;
        end;
      end;
    end;
  finally
    FUpdatingValues := False;
  end;
end;

procedure TRpPanelObjLCL.DupValue(Sender: TControl);
var
  acontrol: TControl;
  oldonchange: TNotifyEvent;
begin
  if (Sender.Tag < 0) or (Sender.Tag >= LControls.Count) or (Sender.Tag >= LControls2.Count) then
    Exit;

  acontrol := TControl(LControls.Objects[Sender.Tag]);
  if acontrol = Sender then
    acontrol := TControl(LControls2.Objects[Sender.Tag]);
  if acontrol = Sender then
    Exit;

  if acontrol is TEdit then
  begin
    oldonchange := TEdit(acontrol).OnChange;
    TEdit(acontrol).OnChange := nil;
    TEdit(acontrol).Text := TEdit(Sender).Text;
    TEdit(acontrol).OnChange := oldonchange;
  end
  else if acontrol is TComboBox then
  begin
    oldonchange := TComboBox(acontrol).OnChange;
    TComboBox(acontrol).OnChange := nil;
    if TComboBox(acontrol).Style = csDropDownList then
      TComboBox(acontrol).ItemIndex := TComboBox(Sender).ItemIndex
    else
      TComboBox(acontrol).Text := TComboBox(Sender).Text;
    TComboBox(acontrol).OnChange := oldonchange;
  end
  else if acontrol is TShape then
  begin
    TShape(acontrol).Brush.Color := TShape(Sender).Brush.Color;
  end;
end;

procedure TRpPanelObjLCL.EditChange(Sender: TObject);
var
  index: Integer;
  aname, avalue: string;
  desframe: TFRpDesignFrameLCL;
  items: TList;
begin
  if FUpdatingValues then Exit;
  DupValue(TControl(Sender));
  index := TControl(Sender).Tag;
  if (index < 0) or (index >= LNames.Count) then Exit;
  aname := LNames.Strings[index];

  if Sender is TComboBox then
    avalue := TComboBox(Sender).Text
  else if Sender is TEdit then
    avalue := TEdit(Sender).Text
  else
    Exit;

  // One path for single and multiple selection: applies the text and
  // records the model values (real types) for undo
  items := GetTargetItems;
  try
    ApplyPropertyValues(items, [aname], [WideString(avalue)]);
  finally
    items.Free;
  end;

  if FSelectedItems.Count < 2 then
  begin
    if Assigned(FCompItem) then
    begin
      if FCompItem is TRpSectionInterface then
      begin
        if (aname = SRpSWidth) or (aname = SRpSHeight) then
        begin
          if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
             (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
            TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).UpdateInterface(False);
        end
        else if (aname = SRpSGroupName) then
        begin
          if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
             (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
          begin
            desframe := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame);
            desframe.InvalidateCaptions;
            if Assigned(desframe.freportstructure) and (desframe.freportstructure is TFRpStructureLCL) then
              TFRpStructureLCL(desframe.freportstructure).UpdateCaptions;
          end;
        end;
      end;
      FCompItem.Invalidate;
    end;
  end;

  if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
     (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
  begin
    desframe := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame);
    if Assigned(desframe.SizeModifier) and Assigned(desframe.SizeModifier.Control) then
      desframe.SizeModifier.UpdatePos;
  end;
end;

procedure TRpPanelObjLCL.ShapeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  AShape: TShape;
  propName: string;
  insp: TFRpObjInspLCL;
begin
  AShape := TShape(Sender);
  insp := TFRpObjInspLCL(Owner);
  if (AShape.Tag >= 0) and (AShape.Tag < LValues.Count) then
    insp.ColorDialog1.Color := StrToIntDef(LValues.Strings[AShape.Tag], clBlack);

  if insp.ColorDialog1.Execute then
  begin
    AShape.Brush.Color := insp.ColorDialog1.Color;
    propName := LNames.Strings[AShape.Tag];
    SetPropertyFull(propName, IntToStr(insp.ColorDialog1.Color));
    DupValue(TControl(Sender));
    if Assigned(FCompItem) then
      FCompItem.Invalidate;
  end;
end;

procedure TRpPanelObjLCL.FontClick(Sender: TObject);
var
  insp: TFRpObjInspLCL;
  aitem: TRpSizeInterface;
  index: Integer;
  newFontName, newFontSize, newFontColor, newFontStyle: WideString;
  items: TList;
begin
  insp := TFRpObjInspLCL(Owner);
  if FSelectedItems.Count < 2 then
    aitem := FCompItem
  else
    aitem := TRpSizeInterface(FSelectedItems.Objects[0]);

  if not Assigned(aitem) then Exit;

  insp.FontDialog1.Font.Name := aitem.GetProperty(SRpSWFontName);
  insp.FontDialog1.Font.Size := StrToIntDef(aitem.GetProperty(SRpSFontSize), 10);
  insp.FontDialog1.Font.Color := StrToIntDef(aitem.GetProperty(SRpSFontColor), clBlack);
  insp.FontDialog1.Font.Style := CLXIntegerToFontStyle(StrToIntDef(aitem.GetProperty(SRpSFontStyle), 0));

  if insp.FontDialog1.Execute then
  begin
    newFontName := insp.FontDialog1.Font.Name;
    newFontSize := IntToStr(insp.FontDialog1.Font.Size);
    newFontColor := IntToStr(insp.FontDialog1.Font.Color);
    newFontStyle := IntToStr(FontStyleToCLXInteger(insp.FontDialog1.Font.Style));

    // Update UI controls; the font size edit would otherwise apply and
    // record its value on its own (EditChange), outside the font group
    FUpdatingValues := True;
    try
      index := LNames.IndexOf(SRpSWFontName);
      if index >= 0 then
      begin
        TEdit(LControls.Objects[index]).Text := newFontName;
        TEdit(LControls2.Objects[index]).Text := newFontName;
      end;
      index := LNames.IndexOf(SRpSFontSize);
      if index >= 0 then
      begin
        TEdit(LControls.Objects[index]).Text := newFontSize;
        TEdit(LControls2.Objects[index]).Text := newFontSize;
      end;
      index := LNames.IndexOf(SRpSFontColor);
      if index >= 0 then
      begin
        TShape(LControls.Objects[index]).Brush.Color := insp.FontDialog1.Font.Color;
        TShape(LControls2.Objects[index]).Brush.Color := insp.FontDialog1.Font.Color;
      end;
      index := LNames.IndexOf(SRpSFontStyle);
      if index >= 0 then
      begin
        TEdit(LControls.Objects[index]).Text := IntegerFontStyleToString(FontStyleToCLXInteger(insp.FontDialog1.Font.Style));
        TEdit(LControls2.Objects[index]).Text := IntegerFontStyleToString(FontStyleToCLXInteger(insp.FontDialog1.Font.Style));
      end;
    finally
      FUpdatingValues := False;
    end;

    // Apply to every selected item (like the VCL SetPropertyFull) and record
    // one undo group with the model values
    items := GetTargetItems;
    try
      ApplyPropertyValues(items, [string(SRpSWFontName), string(SRpSFontSize),
        string(SRpSFontColor), string(SRpSFontStyle)],
        [newFontName, newFontSize, newFontColor, newFontStyle]);
    finally
      items.Free;
    end;

    if Assigned(FCompItem) then
      FCompItem.Invalidate;
  end;
end;

procedure TRpPanelObjLCL.ExpressionClick(Sender: TObject);
var
  expredia: TRpExpreDialogLCL;
  ed1, ed2: TEdit;
  tagIdx: Integer;
  areport: TRpReport;
begin
  tagIdx := TComponent(Sender).Tag;
  areport := nil;
  if Assigned(FCompItem) and Assigned(FCompItem.PrintItem) and (FCompItem.PrintItem.Report is TRpReport) then
    areport := TRpReport(FCompItem.PrintItem.Report)
  else if Assigned(Owner) and (Owner is TFRpObjInspLCL) and Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
          (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    areport := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).Report;

  expredia := TRpExpreDialogLCL.Create(Application);
  try
    // As the VCL inspector: with the report the dialog opens its datasets
    // for the fields and the AI assistant (RpAlias would be filled with
    // them, so the external AliasList of the report is not passed)
    if Assigned(areport) then
      expredia.Report := areport;
    if (tagIdx >= 0) and (tagIdx < LControls.Count) then
    begin
      ed1 := TEdit(LControls.Objects[tagIdx]);
      expredia.Expression.Text := ed1.Text;
      if expredia.Execute then
      begin
        ed1.Text := Trim(expredia.Expression.Text);
        if tagIdx < LControls2.Count then
        begin
          ed2 := TEdit(LControls2.Objects[tagIdx]);
          if Assigned(ed2) then
            ed2.Text := ed1.Text;
        end;
        EditChange(ed1);
      end;
    end;
  finally
    expredia.Free;
  end;
end;

procedure TRpPanelObjLCL.ExtClick(Sender: TObject);
var
  areport: TRpReport;
  sec: TRpSection;
  desframe: TFRpDesignFrameLCL;
begin
  if not Assigned(FCompItem) or not Assigned(FCompItem.PrintItem) or
     not (FCompItem.PrintItem is TRpSection) then Exit;

  sec := TRpSection(FCompItem.PrintItem);
  areport := nil;
  if Assigned(sec.Report) and (sec.Report is TRpReport) then
    areport := TRpReport(sec.Report)
  else if Assigned(Owner) and (Owner is TFRpObjInspLCL) and Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
          (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    areport := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).Report;

  // ChangeExternalSectionProps records the change itself (or clears the
  // history and marks the report modified after a database load)
  if ChangeExternalSectionProps(areport, sec) then
  begin
    TEdit(Sender).Text := sec.GetExternalDataDescription;
    DupValue(TControl(Sender));
    if Assigned(Owner) and (Owner is TFRpObjInspLCL) and Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
       (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    begin
      desframe := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame);
      if Assigned(desframe.freportstructure) and (desframe.freportstructure is TFRpStructureLCL) then
      begin
        TFRpStructureLCL(desframe.freportstructure).CreateInterface;
        TFRpStructureLCL(desframe.freportstructure).SelectDataItem(sec);
      end;
      // The section components may have been reloaded: rebuild the design
      // surface instead of refreshing interfaces of freed components
      desframe.UpdateSelection(True);
    end;
  end;
end;

procedure TRpPanelObjLCL.ImageClick(Sender: TObject);
var
  insp: TFRpObjInspLCL;
  stream: TMemoryStream;
begin
  insp := TFRpObjInspLCL(Owner);
  insp.OpenDialog1.Filter := ImageFileFilter;
  if insp.OpenDialog1.Execute then
  begin
    stream := TMemoryStream.Create;
    try
      // Bitmaps, JPEG and PNG as they are, other formats as JPEG
      LoadImageFileToStream(insp.OpenDialog1.FileName, stream);
      SetPropertyFull(LNames.Strings[TComponent(Sender).Tag], stream);
    finally
      stream.Free;
    end;
    if Assigned(FCompItem) then
      FCompItem.Invalidate;
  end;
end;

procedure TRpPanelObjLCL.ImageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  stream: TMemoryStream;
begin
  if (Key = 8) or (Key = 46) then // Backspace or Delete
  begin
    stream := TMemoryStream.Create;
    try
      SetPropertyFull(LNames.Strings[TComponent(Sender).Tag], stream);
    finally
      stream.Free;
    end;
    if Assigned(FCompItem) then
      FCompItem.Invalidate;
  end;
end;

procedure TRpPanelObjLCL.ComboAliasChange(Sender: TObject);
var
  desframe: TFRpDesignFrameLCL;
  oldVal: string;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  if Assigned(subrep) and Assigned(comboalias) then
  begin
    oldVal := subrep.Alias;
    subrep.Alias := comboalias.Text;

    if (oldVal <> subrep.Alias) and Assigned(subrep.Owner) and
       (subrep.Owner is TRpReport) and Assigned(TRpReport(subrep.Owner).UndoCue) then
    begin
      cue := TUndoCue(TRpReport(subrep.Owner).UndoCue);
      op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
      op.componentName := subrep.Name;
      op.componentClass := 'TRPSUBREPORT';
      op.AddProperty('alias', ptString, oldVal, subrep.Alias);
      cue.AddOperation(op);
      RefreshCueView;
    end;

    if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
       (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    begin
      desframe := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame);
      desframe.InvalidateCaptions;
      if Assigned(desframe.freportstructure) and (desframe.freportstructure is TFRpStructureLCL) then
        TFRpStructureLCL(desframe.freportstructure).UpdateCaptions;
    end;
  end;
end;

procedure TRpPanelObjLCL.ComboPrintOnlyChange(Sender: TObject);
var
  oldVal, newVal: Boolean;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  if Assigned(subrep) and Assigned(comboprintonly) then
  begin
    oldVal := subrep.PrintOnlyIfDataAvailable;
    if comboprintonly.ItemIndex = 0 then
      newVal := False
    else
      newVal := True;

    subrep.PrintOnlyIfDataAvailable := newVal;

    if (oldVal <> newVal) and Assigned(subrep.Owner) and
       (subrep.Owner is TRpReport) and Assigned(TRpReport(subrep.Owner).UndoCue) then
    begin
      cue := TUndoCue(TRpReport(subrep.Owner).UndoCue);
      op := TChangeObjectOperation.Create(otModify, cue.GetGroupId);
      op.componentName := subrep.Name;
      op.componentClass := 'TRPSUBREPORT';
      op.AddProperty('printOnlyIfDataAvailable', ptBoolean, oldVal, newVal);
      cue.AddOperation(op);
      RefreshCueView;
    end;
  end;
end;

procedure TRpPanelObjLCL.ComboObjectChange(Sender: TObject);
var
  idx: Integer;
  obj: TObject;
begin
  idx := TComboBox(Sender).ItemIndex;
  if idx >= 0 then
  begin
    obj := TComboBox(Sender).Items.Objects[idx];
    if Assigned(obj) and (obj is TRpSizeInterface) then
    begin
      TFRpObjInspLCL(Owner).AddCompItem(TRpSizeInterface(obj), True);
      if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
         (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
      begin
        TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).SelectComponent(TRpSizeInterface(obj), False);
      end;
    end;
  end;
end;

procedure TRpPanelObjLCL.UpdatePosValues;
var
  index: Integer;
  sizeposint: TRpSizePosInterface;
  desframe: TFRpDesignFrameLCL;
  valStr: string;
  ctrl, ctrl2: TControl;
begin
  if not Assigned(TFRpObjInspLCL(Owner).DesignFrame) or
     not (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    Exit;
  desframe := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame);
  if not Assigned(desframe.SizeModifier) or not Assigned(desframe.SizeModifier.Control) then
    Exit;
  if not (desframe.SizeModifier.Control is TRpSizePosInterface) then
    Exit;

  sizeposint := TRpSizePosInterface(desframe.SizeModifier.Control);

  FUpdatingValues := True;
  try
    index := LNames.IndexOf(SRpSLeft);
    if (index >= 0) and (index < LControls.Count) then
    begin
      valStr := gettextfromtwips(pixelstotwips(sizeposint.Left, sizeposint.Scale));
      ctrl := TControl(LControls.Objects[index]);
      ctrl2 := TControl(LControls2.Objects[index]);
      if ctrl is TEdit then TEdit(ctrl).Text := valStr;
      if ctrl2 is TEdit then TEdit(ctrl2).Text := valStr;
      if LValues.Count > index then LValues.Strings[index] := valStr;
    end;

    index := LNames.IndexOf(SRpSTop);
    if (index >= 0) and (index < LControls.Count) then
    begin
      valStr := gettextfromtwips(pixelstotwips(sizeposint.Top, sizeposint.Scale));
      ctrl := TControl(LControls.Objects[index]);
      ctrl2 := TControl(LControls2.Objects[index]);
      if ctrl is TEdit then TEdit(ctrl).Text := valStr;
      if ctrl2 is TEdit then TEdit(ctrl2).Text := valStr;
      if LValues.Count > index then LValues.Strings[index] := valStr;
    end;

    index := LNames.IndexOf(SRpSWidth);
    if (index >= 0) and (index < LControls.Count) then
    begin
      valStr := gettextfromtwips(pixelstotwips(sizeposint.Width, sizeposint.Scale));
      ctrl := TControl(LControls.Objects[index]);
      ctrl2 := TControl(LControls2.Objects[index]);
      if ctrl is TEdit then TEdit(ctrl).Text := valStr;
      if ctrl2 is TEdit then TEdit(ctrl2).Text := valStr;
      if LValues.Count > index then LValues.Strings[index] := valStr;
    end;

    index := LNames.IndexOf(SRpSHeight);
    if (index >= 0) and (index < LControls.Count) then
    begin
      valStr := gettextfromtwips(pixelstotwips(sizeposint.Height, sizeposint.Scale));
      ctrl := TControl(LControls.Objects[index]);
      ctrl2 := TControl(LControls2.Objects[index]);
      if ctrl is TEdit then TEdit(ctrl).Text := valStr;
      if ctrl2 is TEdit then TEdit(ctrl2).Text := valStr;
      if LValues.Count > index then LValues.Strings[index] := valStr;
    end;
  finally
    FUpdatingValues := False;
  end;
end;

procedure TRpPanelObjLCL.SelectProperty(propname: string);
var
  index: Integer;
  AControl: TWinControl;
begin
  if Assigned(FPControl) then
    FPControl.ActivePageIndex := 0;
  index := LControls.IndexOf(propname);
  if index >= 0 then
  begin
    AControl := TWinControl(LControls.Objects[index]);
    if AControl.CanFocus then
      AControl.SetFocus;
  end;
end;

procedure TRpPanelObjLCL.RefreshCueView;
var
  desframe: TFRpDesignFrameLCL;
begin
  if Assigned(Owner) and (Owner is TFRpObjInspLCL) and
     Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
     (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
  begin
    desframe := TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame);
    if Assigned(desframe.freportstructure) and (desframe.freportstructure is TFRpStructureLCL) then
      if Assigned(TFRpStructureLCL(desframe.freportstructure).cueview) then
        TFRpStructureLCL(desframe.freportstructure).cueview.RefreshList;
  end;
end;

function TRpPanelObjLCL.GetTargetItems: TList;
var
  i: Integer;
begin
  // Items an inspector edit applies to: the whole multiple selection, else
  // the displayed item. The caller frees the list.
  Result := TList.Create;
  if FSelectedItems.Count > 1 then
  begin
    for i := 0 to FSelectedItems.Count - 1 do
      Result.Add(FSelectedItems.Objects[i]);
  end
  else if Assigned(FCompItem) then
    Result.Add(FCompItem)
  else if FSelectedItems.Count = 1 then
    Result.Add(FSelectedItems.Objects[0]);
end;

procedure TRpPanelObjLCL.ApplyPropertyValues(items: TList;
  const propnames: array of string; const values: array of WideString;
  stream: TMemoryStream);
begin
  // Applies inspector (display) values (or the stream) to the items and
  // records one undo group with the model values before and after, read
  // from the print item with their real types: Undo/Redo restore them with
  // SetItemProperty. A change with no model equivalent only marks the
  // report as modified.
  if Assigned(ApplyDesignPropertyValues(items, propnames, values, stream)) then
    RefreshCueView;
end;

procedure TRpPanelObjLCL.SetPropertyFull(propname: string; value: WideString);
var
  items: TList;
begin
  items := GetTargetItems;
  try
    ApplyPropertyValues(items, [propname], [value]);
  finally
    items.Free;
  end;
end;

procedure TRpPanelObjLCL.SetPropertyFull(propname: string; stream: TMemoryStream);
var
  items: TList;
begin
  // Images (item and section background) are recorded as streamBase64
  items := GetTargetItems;
  try
    ApplyPropertyValues(items, [propname], [''], stream);
  finally
    items.Free;
  end;
  // Shows the new image size
  AssignPropertyValues;
end;

procedure TRpPanelObjLCL.SendToBackClick(Sender: TObject);
begin
  if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
     (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).SendSelectionToBack;
end;

procedure TRpPanelObjLCL.BringToFrontClick(Sender: TObject);
begin
  if Assigned(TFRpObjInspLCL(Owner).DesignFrame) and
     (TFRpObjInspLCL(Owner).DesignFrame is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(TFRpObjInspLCL(Owner).DesignFrame).BringSelectionToFront;
end;

{ TFRpObjInspLCL }

constructor TFRpObjInspLCL.Create(AOwner: TComponent);
var
  alist: TStringList;
begin
  inherited Create(AOwner);
  // External section menu (captions of the .lfm), as TFRpObjInspVCL
  MLoadExternal.Caption := TranslateStr(835, 'Load section');
  MSaveExternal.Caption := TranslateStr(836, 'Save section');
  FPropPanels := TStringList.Create;
  FSelectedItems := TStringList.Create;
  FClasses := TStringList.Create;
  FClassAncestors := TStringList.Create;

  // Register common classes
  FClasses.AddObject('TRpExpressionInterface', TRpExpressionInterface.Create(Self, nil));
  FClasses.AddObject('TRpBarcodeInterface', TRpBarcodeInterface.Create(Self, nil));
  FClasses.AddObject('TRpChartInterface', TRpChartInterface.Create(Self, nil));
  FClasses.AddObject('TRpLabelInterface', TRpLabelInterface.Create(Self, nil));
  FClasses.AddObject('TRpSizePosInterface', TRpSizePosInterface.Create(Self, nil));
  FClasses.AddObject('TRpDrawInterface', TRpDrawInterface.Create(Self, nil));
  FClasses.AddObject('TRpGenTextInterface', TRpGenTextInterface.Create(Self, nil));
  FClasses.AddObject('TRpImageInterface', TRpImageInterface.Create(Self, nil));

  // Register ancestor trees for multi-select common base discovery
  alist := TStringList.Create;
  TRpExpressionInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpExpressionInterface', alist);

  alist := TStringList.Create;
  TRpBarcodeInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpBarcodeInterface', alist);

  alist := TStringList.Create;
  TRpChartInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpChartInterface', alist);

  alist := TStringList.Create;
  TRpGenTextInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpGenTextInterface', alist);

  alist := TStringList.Create;
  TRpLabelInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpLabelInterface', alist);

  alist := TStringList.Create;
  TRpDrawInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpDrawInterface', alist);

  alist := TStringList.Create;
  TRpImageInterface.FillAncestors(alist);
  FClassAncestors.AddObject('TRpImageInterface', alist);
end;

destructor TFRpObjInspLCL.Destroy;
var
  i: Integer;
begin
  for i := 0 to FPropPanels.Count - 1 do
    FPropPanels.Objects[i].Free;
  FPropPanels.Free;

  FSelectedItems.Free;

  for i := 0 to FClasses.Count - 1 do
    FClasses.Objects[i].Free;
  FClasses.Free;

  for i := 0 to FClassAncestors.Count - 1 do
    FClassAncestors.Objects[i].Free;
  FClassAncestors.Free;

  inherited Destroy;
end;

function TFRpObjInspLCL.FindCommonClass(baseclass, newclass: string): string;
var
  indexnew, indexbase, i, j: Integer;
  aorigin, adestination: TStrings;
  found: Boolean;
begin
  Result := 'TRpSizePosInterface';
  indexnew := FClassAncestors.IndexOf(newclass);
  indexbase := FClassAncestors.IndexOf(baseclass);
  if (indexnew < 0) or (indexbase < 0) then
    Exit;
  aorigin := TStrings(FClassAncestors.Objects[indexbase]);
  adestination := TStrings(FClassAncestors.Objects[indexnew]);
  found := False;
  for i := adestination.Count - 1 downto 0 do
  begin
    for j := aorigin.Count - 1 downto 0 do
    begin
      if adestination.Strings[i] = aorigin.Strings[j] then
      begin
        Result := adestination.Strings[i];
        found := True;
        Break;
      end;
    end;
    if found then Break;
  end;
end;

function TFRpObjInspLCL.GetCommonClassName: string;
var
  baseclass, newclass: string;
  i: Integer;
begin
  if FSelectedItems.Count = 0 then
  begin
    Result := 'TRpSizePosInterface';
    Exit;
  end;
  baseclass := FSelectedItems.Objects[0].ClassName;
  for i := 1 to FSelectedItems.Count - 1 do
  begin
    newclass := FSelectedItems.Objects[i].ClassName;
    if newclass <> baseclass then
      baseclass := FindCommonClass(baseclass, newclass);
    if baseclass = 'TRpSizePosInterface' then
      Break;
  end;
  Result := baseclass;
end;

function TFRpObjInspLCL.FindPanelForClass(acompo: TRpSizeInterface): TRpPanelObjLCL;
var
  newclassname: string;
  i, index: Integer;
begin
  newclassname := FindClassName(acompo);
  index := FPropPanels.IndexOf(newclassname);
  if index >= 0 then
    Result := TRpPanelObjLCL(FPropPanels.Objects[index])
  else
  begin
    Result := CreatePanel(acompo);
    FPropPanels.AddObject(newclassname, Result);
  end;

  for i := 0 to FPropPanels.Count - 1 do
  begin
    if FPropPanels.Objects[i] <> Result then
      TRpPanelObjLCL(FPropPanels.Objects[i]).Visible := False;
  end;
  Result.Visible := True;
end;

function TFRpObjInspLCL.CreatePanel(acompo: TRpSizeInterface): TRpPanelObjLCL;
var
  apanel: TRpPanelObjLCL;
begin
  apanel := TRpPanelObjLCL.Create(Self);
  apanel.Visible := False;
  apanel.Parent := Self;
  apanel.FSelectedItems := FSelectedItems;
  if not Assigned(acompo) then
    apanel.CreateControlsSubReport
  else
    apanel.CreateControls(acompo);
  Result := apanel;
end;

function TFRpObjInspLCL.GetComboBox: TComboBox;
var
  p: TRpPanelObjLCL;
begin
  p := GetCurrentPanel;
  if Assigned(p) then
    Result := p.Combo
  else
    Result := nil;
end;

function TFRpObjInspLCL.GetCompItem: TRpSizeInterface;
var
  p: TRpPanelObjLCL;
begin
  p := GetCurrentPanel;
  if Assigned(p) then
    Result := p.CompItem
  else
    Result := nil;
end;

function TFRpObjInspLCL.GetCurrentPanel: TRpPanelObjLCL;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FPropPanels.Count - 1 do
  begin
    if TRpPanelObjLCL(FPropPanels.Objects[i]).Visible then
    begin
      Result := TRpPanelObjLCL(FPropPanels.Objects[i]);
      Break;
    end;
  end;
end;

procedure TFRpObjInspLCL.ClearMultiSelect;
var
  i: Integer;
  tempitem: TRpSizePosInterface;
begin
  if FSelectedItems.Count > 0 then
  begin
    if FSelectedItems.Objects[0] is TRpSizePosInterface then
    begin
      for i := 0 to FSelectedItems.Count - 1 do
      begin
        tempitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
        if tempitem.Selected then
        begin
          tempitem.Selected := False;
          tempitem.Invalidate;
        end;
      end;
    end;
  end;
  FSelectedItems.Clear;
end;

procedure TFRpObjInspLCL.ClearCompItemRefs;
var
  i: Integer;
  panel: TRpPanelObjLCL;
begin
  for i := 0 to FPropPanels.Count - 1 do
  begin
    panel := TRpPanelObjLCL(FPropPanels.Objects[i]);
    panel.CompItem := nil;
    if Assigned(panel.Combo) then
    begin
      panel.Combo.OnChange := nil;
      panel.Combo.Clear;
    end;
  end;
end;

procedure TFRpObjInspLCL.InvalidatePanels;
var
  i: Integer;
begin
  for i := 0 to FPropPanels.Count - 1 do
    FPropPanels.Objects[i].Free;
  FPropPanels.Clear;
end;

procedure TFRpObjInspLCL.SetCompItem(Value: TRpSizeInterface);
var
  FCurrentPanel: TRpPanelObjLCL;
begin
  FCurrentPanel := FindPanelForClass(Value);
  FCurrentPanel.CompItem := Value;
  if Assigned(FDesignFrame) and (FDesignFrame is TFRpDesignFrameLCL) then
  begin
    TFRpDesignFrameLCL(FDesignFrame).InvalidateCaptions;
    FCurrentPanel.SubReport := TFRpDesignFrameLCL(FDesignFrame).SubReport;
  end;
  FCurrentPanel.AssignPropertyValues;
end;

procedure TFRpObjInspLCL.AddCompItem(aitem: TRpSizeInterface; onlyone: Boolean);
var
  i: Integer;
  tempitem: TRpSizePosInterface;
  desframe: TFRpDesignFrameLCL;
begin
  if not Assigned(aitem) then
  begin
    ClearMultiSelect;
    SetCompItem(nil);
    Exit;
  end;

  if aitem is TRpSizePosInterface then
  begin
    if onlyone then
      ClearMultiSelect;
    if FSelectedItems.Count = 1 then
      if not (FSelectedItems.Objects[0] is TRpSizePosInterface) then
        ClearMultiSelect;

    AddCompItemPos(TRpSizePosInterface(aitem), onlyone);

    if Assigned(FDesignFrame) and (FDesignFrame is TFRpDesignFrameLCL) then
    begin
      desframe := TFRpDesignFrameLCL(FDesignFrame);
      if FSelectedItems.Count = 1 then
      begin
        tempitem := TRpSizePosInterface(FSelectedItems.Objects[0]);
        if Assigned(desframe.SizeModifier) then
        begin
          if Assigned(desframe.Report) then
          begin
            desframe.SizeModifier.GridEnabled := desframe.Report.GridEnabled;
            desframe.SizeModifier.GridX := desframe.Report.GridWidth;
            desframe.SizeModifier.GridY := desframe.Report.GridHeight;
          end;
          desframe.SizeModifier.Control := tempitem;
          desframe.SizeModifier.UpdatePos;
        end;
      end
      else if FSelectedItems.Count > 1 then
      begin
        if Assigned(desframe.SizeModifier) then
          desframe.SizeModifier.Control := nil;
        for i := 0 to FSelectedItems.Count - 1 do
        begin
          tempitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
          if not tempitem.Selected then
          begin
            tempitem.Selected := True;
            tempitem.Invalidate;
          end;
        end;
      end;
    end;
  end
  else
  begin
    ClearMultiSelect;
    FSelectedItems.AddObject(aitem.ClassName, aitem);
    SetCompItem(aitem);
  end;
end;

procedure TFRpObjInspLCL.AddCompItemPos(aitem: TRpSizePosInterface; onlyone: Boolean);
var
  parentclassname: string;
  i, index: Integer;
  found: Boolean;
begin
  if onlyone then
    FSelectedItems.Clear;

  i := FSelectedItems.IndexOfObject(aitem);
  found := i >= 0;
  if found then
  begin
    if onlyone then Exit;
    if FSelectedItems.Count < 2 then Exit;
    FSelectedItems.Delete(i);
    aitem.Selected := False;
    if FSelectedItems.Count = 1 then
      TRpSizePosInterface(FSelectedItems.Objects[0]).Selected := False;
  end
  else
    FSelectedItems.AddObject(aitem.ClassName, aitem);

  if FSelectedItems.Count = 1 then
  begin
    SetCompItem(TRpSizeInterface(FSelectedItems.Objects[0]));
    Exit;
  end;

  if FSelectedItems.Count = 0 then
  begin
    SetCompItem(nil);
    Exit;
  end;

  parentclassname := GetCommonClassName;
  if Assigned(FCommonObject) then
  begin
    if FCommonObject.ClassName <> parentclassname then
      FCommonObject := nil;
  end;
  if not Assigned(FCommonObject) then
  begin
    index := FClasses.IndexOf(parentclassname);
    if index < 0 then
      FCommonObject := TRpSizePosInterface(FClasses.Objects[FClasses.IndexOf('TRpSizePosInterface')])
    else
      FCommonObject := TRpSizePosInterface(FClasses.Objects[index]);
  end;
  if Assigned(FCommonObject) then
  begin
    FCommonObject.SectionInt := aitem.SectionInt;
    SetCompItem(FCommonObject);
  end;
end;

procedure TFRpObjInspLCL.SelectProperty(propname: string);
var
  p: TRpPanelObjLCL;
begin
  p := GetCurrentPanel;
  if Assigned(p) then
    p.SelectProperty(propname);
end;

procedure TFRpObjInspLCL.UpdatePosValues;
var
  p: TRpPanelObjLCL;
begin
  p := GetCurrentPanel;
  if Assigned(p) then
    p.UpdatePosValues;
end;

procedure TFRpObjInspLCL.SelectAllClass(classname: string);
var
  i, j, index: Integer;
  compo: TRpSizePosInterface;
  sec: TRpSectionInterface;
  desframe: TFRpDesignFrameLCL;
  alist: TStringList;
begin
  if not Assigned(FDesignFrame) or not (FDesignFrame is TFRpDesignFrameLCL) then
    Exit;
  desframe := TFRpDesignFrameLCL(FDesignFrame);
  ClearMultiSelect;

  for i := 0 to desframe.secinterfaces.Count - 1 do
  begin
    sec := TRpSectionInterface(desframe.secinterfaces[i]);
    for j := 0 to sec.childlist.Count - 1 do
    begin
      compo := TRpSizePosInterface(sec.childlist[j]);
      index := FClassAncestors.IndexOf(compo.ClassName);
      if index >= 0 then
      begin
        alist := TStringList(FClassAncestors.Objects[index]);
        if (alist.IndexOf(classname) >= 0) or (compo.ClassName = classname) then
          FSelectedItems.AddObject(compo.ClassName, compo);
      end;
    end;
  end;

  if FSelectedItems.Count > 0 then
  begin
    compo := TRpSizePosInterface(FSelectedItems.Objects[FSelectedItems.Count - 1]);
    FSelectedItems.Delete(FSelectedItems.Count - 1);
    AddCompItem(compo, False);
  end;
end;

procedure TFRpObjInspLCL.RecordSelectionPositions(const oldPosX, oldPosY: array of Integer);
var
  i, gid: Integer;
  aitem: TRpSizePosInterface;
  pitem: TRpCommonPosComponent;
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
  // One undo group with the position changes of the selected items
  cue := nil;
  gid := 0;
  try
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
      pitem := TRpCommonPosComponent(aitem.printitem);
      if (pitem.PosX = oldPosX[i]) and (pitem.PosY = oldPosY[i]) then
        Continue;
      if not Assigned(cue) then
      begin
        cue := FindItemUndoCue(pitem);
        if not Assigned(cue) then
          Exit;
        cue.BeginUpdate;
        gid := cue.GetGroupId;
      end;
      op := TChangeObjectOperation.Create(otModify, gid);
      op.componentName := pitem.Name;
      op.componentClass := UpperCase(pitem.ClassName);
      if Assigned(aitem.SectionInt) and Assigned(aitem.SectionInt.PrintItem) then
        op.parentName := aitem.SectionInt.PrintItem.Name;
      if pitem.PosX <> oldPosX[i] then
        op.AddProperty('posX', ptInteger, oldPosX[i], pitem.PosX);
      if pitem.PosY <> oldPosY[i] then
        op.AddProperty('posY', ptInteger, oldPosY[i], pitem.PosY);
      cue.AddOperation(op);
    end;
  finally
    if Assigned(cue) then
      cue.EndUpdate;
  end;
end;

procedure TFRpObjInspLCL.AlignSelected(direction: Integer);
var
  i: Integer;
  aitem: TRpSizePosInterface;
  oldPosX, oldPosY: array of Integer;
begin
  if FSelectedItems.Count < 2 then Exit;
  SetLength(oldPosX, FSelectedItems.Count);
  SetLength(oldPosY, FSelectedItems.Count);
  for i := 0 to FSelectedItems.Count - 1 do
  begin
    aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
    oldPosX[i] := TRpCommonPosComponent(aitem.printitem).PosX;
    oldPosY[i] := TRpCommonPosComponent(aitem.printitem).PosY;
  end;
  try
    DoAlignSelected(direction);
  finally
    RecordSelectionPositions(oldPosX, oldPosY);
  end;
end;

procedure TFRpObjInspLCL.DoAlignSelected(direction: Integer);
var
  i, newpos, actualpos, minpos, maxpos, newminpos, newmaxpos, sumwidth, distance: Integer;
  aitem: TRpSizePosInterface;
  pitem: TRpCommonPosComponent;
  fselitems: TStringList;
begin
  // 1-Left, 2-Right, 3-Up, 4-Down, 5-HorzSpacing, 6-VertSpacing
  if FSelectedItems.Count < 2 then Exit;

  if direction in [1..4] then
  begin
    if direction in [1, 3] then
      actualpos := MaxInt
    else
      actualpos := -MaxInt;

    for i := 0 to FSelectedItems.Count - 1 do
    begin
      aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
      pitem := TRpCommonPosComponent(aitem.printitem);
      case direction of
        1: newpos := pitem.PosX;
        2: newpos := pitem.PosX + pitem.Width;
        3: newpos := pitem.PosY;
        4: newpos := pitem.PosY + pitem.Height;
      end;
      if direction in [1, 3] then
      begin
        if newpos < actualpos then
          actualpos := newpos;
      end
      else
      begin
        if newpos > actualpos then
          actualpos := newpos;
      end;
    end;

    for i := 0 to FSelectedItems.Count - 1 do
    begin
      aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
      pitem := TRpCommonPosComponent(aitem.printitem);
      case direction of
        1: pitem.PosX := actualpos;
        2: pitem.PosX := actualpos - pitem.Width;
        3: pitem.PosY := actualpos;
        4: pitem.PosY := actualpos - pitem.Height;
      end;
      aitem.UpdatePos;
    end;
    UpdatePosValues;
    Exit;
  end;

  // Spacing (5=Horz, 6=Vert)
  minpos := MaxInt;
  maxpos := -MaxInt;
  sumwidth := 0;
  for i := 0 to FSelectedItems.Count - 1 do
  begin
    aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
    pitem := TRpCommonPosComponent(aitem.printitem);
    if direction = 5 then
    begin
      newminpos := pitem.PosX;
      newmaxpos := pitem.PosX + pitem.Width;
      sumwidth := sumwidth + pitem.Width;
    end
    else
    begin
      newminpos := pitem.PosY;
      newmaxpos := pitem.PosY + pitem.Height;
      sumwidth := sumwidth + pitem.Height;
    end;
    if newminpos < minpos then minpos := newminpos;
    if newmaxpos > maxpos then maxpos := newmaxpos;
  end;

  fselitems := TStringList.Create;
  try
    fselitems.Sorted := True;
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
      pitem := TRpCommonPosComponent(aitem.printitem);
      if direction = 5 then
        fselitems.AddObject(FormatFloat('00000000000', pitem.PosX), aitem)
      else
        fselitems.AddObject(FormatFloat('00000000000', pitem.PosY), aitem);
    end;
    distance := ((maxpos - minpos) - sumwidth) div (FSelectedItems.Count - 1);
    for i := 0 to fselitems.Count - 2 do
    begin
      aitem := TRpSizePosInterface(fselitems.Objects[i]);
      pitem := TRpCommonPosComponent(aitem.printitem);
      if direction = 5 then
      begin
        pitem.PosX := minpos;
        minpos := minpos + pitem.Width + distance;
      end
      else
      begin
        pitem.PosY := minpos;
        minpos := minpos + pitem.Height + distance;
      end;
      aitem.UpdatePos;
    end;
  finally
    fselitems.Free;
  end;
  UpdatePosValues;
end;

procedure TFRpObjInspLCL.MoveSelected(direction: Integer; fast: Boolean);
var
  i, unitsize: Integer;
  aitem: TRpSizePosInterface;
  pitem: TRpCommonPosComponent;
  desframe: TFRpDesignFrameLCL;
  oldPosX, oldPosY: array of Integer;
begin
  if FSelectedItems.Count < 1 then Exit;
  if not (FSelectedItems.Objects[0] is TRpSizePosInterface) then Exit;
  if not Assigned(FDesignFrame) or not (FDesignFrame is TFRpDesignFrameLCL) then Exit;
  SetLength(oldPosX, FSelectedItems.Count);
  SetLength(oldPosY, FSelectedItems.Count);
  for i := 0 to FSelectedItems.Count - 1 do
  begin
    aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
    oldPosX[i] := TRpCommonPosComponent(aitem.printitem).PosX;
    oldPosY[i] := TRpCommonPosComponent(aitem.printitem).PosY;
  end;

  desframe := TFRpDesignFrameLCL(FDesignFrame);
  if Assigned(desframe.Report) and desframe.Report.GridEnabled then
  begin
    if direction in [1, 2] then
      unitsize := desframe.Report.GridWidth
    else
      unitsize := desframe.Report.GridHeight;
  end
  else
    unitsize := pixelstotwips(1, TRpSizePosInterface(FSelectedItems.Objects[0]).Scale);

  if direction in [1, 3] then
    unitsize := -unitsize;
  if fast then
    unitsize := unitsize * 5;

  try
    for i := 0 to FSelectedItems.Count - 1 do
    begin
      aitem := TRpSizePosInterface(FSelectedItems.Objects[i]);
      pitem := TRpCommonPosComponent(aitem.printitem);
      if direction in [1, 2] then
        pitem.PosX := pitem.PosX + unitsize
      else
        pitem.PosY := pitem.PosY + unitsize;
      aitem.UpdatePos;
    end;
  finally
    RecordSelectionPositions(oldPosX, oldPosY);
  end;

  if Assigned(desframe.SizeModifier) and Assigned(desframe.SizeModifier.Control) then
    desframe.SizeModifier.UpdatePos;

  UpdatePosValues;
end;

procedure TFRpObjInspLCL.MLoadExternalClick(Sender: TObject);
var
  sec: TRpSection;
  cue: TUndoCue;
begin
  if not (CompItem is TRpSectionInterface) then Exit;
  if Assigned(TRpSectionInterface(CompItem).printitem) then
  begin
    sec := TRpSection(TRpSectionInterface(CompItem).printitem);
    sec.LoadExternal;
    // Not recorded in the undo cue, but the report changed
    cue := FindItemUndoCue(sec);
    if Assigned(cue) then
      cue.MarkExternalChange;
    // The section components were replaced: rebuild the design surface
    // instead of refreshing interfaces of freed components
    if Assigned(FDesignFrame) and (FDesignFrame is TFRpDesignFrameLCL) then
      TFRpDesignFrameLCL(FDesignFrame).UpdateSelection(True);
  end;
end;

procedure TFRpObjInspLCL.MSaveExternalClick(Sender: TObject);
begin
  if not (CompItem is TRpSectionInterface) then Exit;
  if Assigned(TRpSectionInterface(CompItem).printitem) then
    TRpSection(TRpSectionInterface(CompItem).printitem).SaveExternal;
end;

end.

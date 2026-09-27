{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfstruclcl                                   }
{       Shows the report structure and allows to edit it}
{                                                       }
{*******************************************************}

unit rpmdfstruclcl;

{$I rpconf.inc}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, Menus, ImgList, Buttons, ExtCtrls,
  rpreport, rpsubreport, rpmdconsts, rpdbbrowserlcl, rpgraphutilslcl,
  rpsection, rpmdobjinsplcl, rpprintitem, rptypes, rpmdimageslcl,
  rpmdcueviewlcl, rpmdundocuelcl;

type
  TFRpStructureLCL = class(TFrame)
    PControl: TPageControl;
    TabStructure: TTabSheet;
    TabData: TTabSheet;
    TabHistory: TTabSheet;
    Panel1: TToolBar;
    BNew: TToolButton;
    BDelete: TToolButton;
    BUp: TToolButton;
    BDown: TToolButton;
    BDataConfig: TToolButton;
    RView: TTreeView;
    PopupMenu1: TPopupMenu;
    MDetail: TMenuItem;
    MPHeader: TMenuItem;
    MPFooter: TMenuItem;
    MGHeader: TMenuItem;
    MSubReport: TMenuItem;
    ImageList1: TImageList;
    procedure RViewClick(Sender: TObject);
    procedure RViewChange(Sender: TObject; Node: TTreeNode);
    procedure BUpClick(Sender: TObject);
    procedure BDownClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BNewClick(Sender: TObject);
    procedure BDataConfigClick(Sender: TObject);
    procedure MNewSectionClick(Sender: TObject);
  private
    FReport: TRpReport;
    FObjInsp: TFRpObjInspLCL;
    FOnUndoRedo: TNotifyEvent;
    procedure SetReport(Value: TRpReport);
    procedure DisableRView;
    procedure EnableRView;
    function FindSectionIndex(ASubReport: TRpSubReport; ASection: TRpSection): Integer;
    function FindGroupSection(ASubReport: TRpSubReport; const AGroupName: string;
      ASectionType: TRpSectionType): TRpSection;
    function CountDetails(ASubReport: TRpSubReport): Integer;
    procedure ReleaseDesignSurface;
    procedure DeleteSectionComponentsWithUndo(ASection: TRpSection;
      cue: TUndoCue; gid: Integer);
    procedure DeleteSubReportWithUndo(ASubReport: TRpSubReport;
      cue: TUndoCue; gid: Integer);
    procedure DeleteSectionWithUndo(ASection: TRpSection;
      ASubReport: TRpSubReport; cue: TUndoCue; gid: Integer);
  public
    designframe: TControl;
    browser: TFRpBrowserLCL;
    cueview: TFRpCueViewLCL;
    function MoveSection(ASection: TRpSection; MoveUp, SecondStep: Boolean;
      AGroupId: Integer): Boolean;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateInterface;
    procedure UpdateCaptions;
    function FindSelectedSubreport: TRpSubReport;
    function FindSelectedObject: TObject;
    procedure DeleteSelectedNode;
    procedure SelectDataItem(data: TObject);
    procedure RefreshInterface;
    procedure CueUndoRedo(Sender: TObject);
    property Report: TRpReport read FReport write SetReport;
    property ObjInsp: TFRpObjInspLCL read FObjInsp write FObjInsp;
    property OnUndoRedo: TNotifyEvent read FOnUndoRedo write FOnUndoRedo;
  end;

function FindDataInTree(nodes: TTreeNodes; data: TObject): TTreeNode;

implementation

{$R *.lfm}

uses
  rpmdfdesignlcl, rpmdfdinfolcl;

function FindDataInTree(nodes: TTreeNodes; data: TObject): TTreeNode;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(nodes) then Exit;
  for i := 0 to nodes.Count - 1 do
  begin
    if nodes.Item[i].Data = data then
    begin
      Result := nodes.Item[i];
      Exit;
    end;
  end;
end;

constructor TFRpStructureLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // Setup ImageList with toolbar icons
  ImageList1 := TImageList.Create(Self);
  LoadDesignerImageList(ImageList1);

  // PageControl
  PControl := TPageControl.Create(Self);
  PControl.Align := alClient;
  PControl.Parent := Self;

  // Structure Tab
  TabStructure := TTabSheet.Create(PControl);
  TabStructure.PageControl := PControl;
  TabStructure.Caption := SRpStructure;

  // Toolbar
  Panel1 := TToolBar.Create(TabStructure);
  Panel1.Align := alTop;
  Panel1.AutoSize := True;
  Panel1.Images := ImageList1;
  Panel1.ShowCaptions := False;
  Panel1.Parent := TabStructure;

  // Popup Menu for New Section
  PopupMenu1 := TPopupMenu.Create(Self);

  MSubReport := TMenuItem.Create(PopupMenu1);
  MSubReport.Caption := TranslateStr(125, 'Subreport');
  MSubReport.Hint := TranslateStr(126, 'Insert a new subreport');
  MSubReport.OnClick := MNewSectionClick;
  PopupMenu1.Items.Add(MSubReport);

  MPHeader := TMenuItem.Create(PopupMenu1);
  MPHeader.Caption := TranslateStr(119, 'Page header');
  MPHeader.Hint := TranslateStr(120, 'Inserts a page header in the selected subreport');
  MPHeader.OnClick := MNewSectionClick;
  PopupMenu1.Items.Add(MPHeader);

  MGHeader := TMenuItem.Create(PopupMenu1);
  MGHeader.Caption := TranslateStr(123, 'Group header and footer');
  MGHeader.Hint := TranslateStr(124, 'Insert a group header and footer');
  MGHeader.OnClick := MNewSectionClick;
  PopupMenu1.Items.Add(MGHeader);

  MDetail := TMenuItem.Create(PopupMenu1);
  MDetail.Caption := TranslateStr(129, 'Detail');
  MDetail.Hint := TranslateStr(130, 'Inserts a detail section in the selected subreport');
  MDetail.OnClick := MNewSectionClick;
  PopupMenu1.Items.Add(MDetail);

  MPFooter := TMenuItem.Create(PopupMenu1);
  MPFooter.Caption := TranslateStr(121, 'Page footer');
  MPFooter.Hint := TranslateStr(122, 'Inserts a page footer in the selected subreport');
  MPFooter.OnClick := MNewSectionClick;
  PopupMenu1.Items.Add(MPFooter);

  // Toolbar Buttons
  BNew := TToolButton.Create(Panel1);
  BNew.Parent := Panel1;
  BNew.ImageIndex := IMG_NEW;
  BNew.Style := tbsDropDown;
  BNew.DropdownMenu := PopupMenu1;
  BNew.Hint := TranslateStr(734, 'Adds a section to the selected subreport');
  BNew.OnClick := BNewClick;

  BDelete := TToolButton.Create(Panel1);
  BDelete.Parent := Panel1;
  BDelete.ImageIndex := IMG_DELETE;
  BDelete.Hint := TranslateStr(138, 'Delete the selected section');
  BDelete.OnClick := BDeleteClick;

  BUp := TToolButton.Create(Panel1);
  BUp.Parent := Panel1;
  BUp.ImageIndex := IMG_NAV_UP;
  BUp.Hint := TranslateStr(139, 'Moves the section up');
  BUp.OnClick := BUpClick;

  BDown := TToolButton.Create(Panel1);
  BDown.Parent := Panel1;
  BDown.ImageIndex := IMG_NAV_DOWN;
  BDown.Hint := TranslateStr(140, 'Moves the section down');
  BDown.OnClick := BDownClick;

  BDataConfig := TToolButton.Create(Panel1);
  BDataConfig.Parent := Panel1;
  BDataConfig.ImageIndex := IMG_DATACONFIG;
  BDataConfig.Hint := TranslateStr(132, 'Modifies data access information');
  BDataConfig.OnClick := BDataConfigClick;

  // TreeView
  RView := TTreeView.Create(TabStructure);
  RView.Align := alClient;
  RView.ReadOnly := True;
  RView.HideSelection := False;
  RView.Parent := TabStructure;
  RView.OnChange := RViewChange;
  RView.OnClick := RViewClick;

  // Data Tab
  TabData := TTabSheet.Create(PControl);
  TabData.PageControl := PControl;
  TabData.Caption := SRpData;

  browser := TFRpBrowserLCL.Create(Self);
  browser.ShowDatabases := False;
  browser.Align := alClient;
  browser.Parent := TabData;

  // History Tab
  TabHistory := TTabSheet.Create(PControl);
  TabHistory.PageControl := PControl;
  TabHistory.Caption := 'Historial';

  cueview := TFRpCueViewLCL.Create(Self);
  cueview.Align := alClient;
  cueview.Parent := TabHistory;
  cueview.OnUndoRedo := CueUndoRedo;

  PControl.ActivePageIndex := 0;
end;

destructor TFRpStructureLCL.Destroy;
begin
  inherited Destroy;
end;

procedure TFRpStructureLCL.CueUndoRedo(Sender: TObject);
var
  subrep: TRpSubReport;
begin
  CreateInterface;
  RView.FullExpand;
  if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
  begin
    subrep := nil;
    try
      subrep := FindSelectedSubreport;
    except
      subrep := nil;
    end;
    TFRpDesignFrameLCL(designframe).SelectSubReport(nil);
    if Assigned(subrep) then
      TFRpDesignFrameLCL(designframe).SelectSubReport(subrep);
    TFRpDesignFrameLCL(designframe).UpdateSelection(True);
  end;
  if Assigned(FObjInsp) then
    FObjInsp.AddCompItem(nil, True);

  if Assigned(FOnUndoRedo) then
    FOnUndoRedo(Self);
end;

procedure TFRpStructureLCL.SetReport(Value: TRpReport);
begin
  FReport := Value;
  if not Assigned(FReport) then
  begin
    RView.Items.Clear;
    browser.Report := nil;
    if Assigned(cueview) then
      cueview.Report := nil;
    Exit;
  end;

  CreateInterface;
  RView.FullExpand;
  browser.Report := FReport;
  if Assigned(cueview) then
    cueview.Report := FReport;
  if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(designframe).UpdateSelection(True);
end;

procedure TFRpStructureLCL.DisableRView;
begin
  RView.Items.BeginUpdate;
  RView.OnChange := nil;
  RView.OnClick := nil;
end;

procedure TFRpStructureLCL.EnableRView;
begin
  RView.OnChange := RViewChange;
  RView.OnClick := RViewClick;
  RView.Items.EndUpdate;
end;

procedure TFRpStructureLCL.CreateInterface;
var
  anew, child: TTreeNode;
  i, j: Integer;
  subr: TRpSubReport;
begin
  if not Assigned(FReport) then Exit;
  DisableRView;
  try
    RView.Items.Clear;
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      subr := FReport.SubReports.Items[i].SubReport;
      anew := RView.Items.Add(nil, subr.GetDisplayName(True));
      anew.Data := subr;
      for j := 0 to subr.Sections.Count - 1 do
      begin
        child := RView.Items.AddChild(anew, subr.Sections.Items[j].Section.SectionCaption(True));
        child.Data := subr.Sections.Items[j].Section;
      end;
    end;
  finally
    EnableRView;
  end;
  if not Assigned(RView.Selected) then
    RView.Selected := RView.TopItem;
end;

procedure TFRpStructureLCL.UpdateCaptions;
var
  i: Integer;
  aobj: TObject;
begin
  for i := 0 to RView.Items.Count - 1 do
  begin
    if Assigned(RView.Items[i].Data) then
    begin
      aobj := TObject(RView.Items[i].Data);
      if aobj is TRpSection then
        RView.Items[i].Text := TRpSection(aobj).SectionCaption(True)
      else if aobj is TRpSubReport then
        RView.Items[i].Text := TRpSubReport(aobj).GetDisplayName(True);
    end;
  end;
end;

function TFRpStructureLCL.FindSelectedSubreport: TRpSubReport;
var
  selectednode: TTreeNode;
begin
  Result := nil;
  selectednode := RView.Selected;
  if not Assigned(selectednode) and (RView.Items.Count > 0) then
    selectednode := RView.Items[0];

  if not Assigned(selectednode) then
  begin
    if Assigned(FReport) and (FReport.SubReports.Count > 0) then
    begin
      Result := FReport.SubReports.Items[0].SubReport;
      Exit;
    end;
    Raise Exception.Create(SRPNoSelectedSubreport);
  end;

  if TObject(selectednode.Data) is TRpSubReport then
  begin
    Result := TRpSubReport(selectednode.Data);
    Exit;
  end;

  selectednode := selectednode.Parent;
  if Assigned(selectednode) and (TObject(selectednode.Data) is TRpSubReport) then
  begin
    Result := TRpSubReport(selectednode.Data);
    Exit;
  end;

  if Assigned(FReport) and (FReport.SubReports.Count > 0) then
    Result := FReport.SubReports.Items[0].SubReport
  else
    Raise Exception.Create(SRPNoSelectedSubreport);
end;

function TFRpStructureLCL.FindSelectedObject: TObject;
var
  selectednode: TTreeNode;
begin
  selectednode := RView.Selected;
  if not Assigned(selectednode) and (RView.Items.Count > 0) then
    selectednode := RView.Items[0];
  if not Assigned(selectednode) then
    Raise Exception.Create(SRPNoSelectedSubreport);
  Result := TObject(selectednode.Data);
end;

procedure TFRpStructureLCL.SelectDataItem(data: TObject);
var
  anode: TTreeNode;
begin
  if not Assigned(data) then Exit;
  anode := FindDataInTree(RView.Items, data);
  if Assigned(anode) then
  begin
    RView.Selected := anode;
    anode.MakeVisible;
    RViewClick(Self);
  end;
end;

procedure TFRpStructureLCL.RefreshInterface;
begin
  CreateInterface;
  if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(designframe).UpdateSelection(False);
end;

function TFRpStructureLCL.FindSectionIndex(ASubReport: TRpSubReport;
  ASection: TRpSection): Integer;
var
  i: Integer;
begin
  Result := -1;
  if (not Assigned(ASubReport)) or (not Assigned(ASection)) then Exit;
  for i := 0 to ASubReport.Sections.Count - 1 do
  begin
    if ASubReport.Sections.Items[i].Section = ASection then
    begin
      Result := i;
      break;
    end;
  end;
end;

function TFRpStructureLCL.FindGroupSection(ASubReport: TRpSubReport;
  const AGroupName: string; ASectionType: TRpSectionType): TRpSection;
var
  i: Integer;
  asec: TRpSection;
begin
  Result := nil;
  if not Assigned(ASubReport) then Exit;
  for i := 0 to ASubReport.Sections.Count - 1 do
  begin
    asec := ASubReport.Sections.Items[i].Section;
    if Assigned(asec) and (asec.SectionType = ASectionType) and
       SameText(asec.GroupName, AGroupName) then
    begin
      Result := asec;
      break;
    end;
  end;
end;

function TFRpStructureLCL.MoveSection(ASection: TRpSection; MoveUp,
  SecondStep: Boolean; AGroupId: Integer): Boolean;
var
  subrep: TRpSubReport;
  oldIndex, newIndex: Integer;
  swapSection, otherSection, asec: TRpSection;
  canSwap: Boolean;
  op: TChangeObjectOperation;
begin
  Result := False;
  if not Assigned(ASection) then Exit;
  subrep := TRpSubReport(ASection.SubReport);
  if not Assigned(subrep) then Exit;
  oldIndex := FindSectionIndex(subrep, ASection);
  if oldIndex < 0 then Exit;

  if MoveUp then
    newIndex := oldIndex - 1
  else
    newIndex := oldIndex + 1;

  if (newIndex < 0) or (newIndex >= subrep.Sections.Count) then Exit;
  swapSection := subrep.Sections.Items[newIndex].Section;
  if not Assigned(swapSection) then Exit;

  // A group header and its footer move together: the nested call for the
  // pair must record into the same undo group
  if (AGroupId <= 0) and Assigned(FReport) and Assigned(FReport.UndoCue) then
    AGroupId := TUndoCue(FReport.UndoCue).GetGroupId;

  canSwap := True;
  case ASection.SectionType of
    rpsecdetail, rpsecpheader, rpsecpfooter:
      if swapSection.SectionType <> ASection.SectionType then
        canSwap := False;
    rpsecgheader:
      begin
        if swapSection.SectionType <> rpsecgheader then
          canSwap := False
        else if not SecondStep then
        begin
          otherSection := FindGroupSection(subrep, ASection.GroupName, rpsecgfooter);
          if Assigned(otherSection) then
            canSwap := MoveSection(otherSection, not MoveUp, True, AGroupId)
          else
            canSwap := False;
        end;
      end;
    rpsecgfooter:
      begin
        if swapSection.SectionType <> rpsecgfooter then
          canSwap := False
        else if not SecondStep then
        begin
          otherSection := FindGroupSection(subrep, ASection.GroupName, rpsecgheader);
          if Assigned(otherSection) then
            canSwap := MoveSection(otherSection, not MoveUp, True, AGroupId)
          else
            canSwap := False;
        end;
      end;
  else
    canSwap := False;
  end;

  if not canSwap then Exit;
  asec := subrep.Sections.Items[newIndex].Section;
  subrep.Sections.Items[newIndex].Section := subrep.Sections.Items[oldIndex].Section;
  subrep.Sections.Items[oldIndex].Section := asec;

  if Assigned(FReport) and Assigned(FReport.UndoCue) then
  begin
    if MoveUp then
      op := TChangeObjectOperation.Create(otSwapUp, AGroupId)
    else
      op := TChangeObjectOperation.Create(otSwapDown, AGroupId);
    op.componentName := ASection.Name;
    op.componentClass := 'TRPSECTION';
    op.parentName := subrep.Name;
    op.oldItemIndex := oldIndex;
    TUndoCue(FReport.UndoCue).AddOperation(op);
    if Assigned(cueview) then
      cueview.RefreshList;
  end;

  Result := True;
end;

procedure TFRpStructureLCL.BUpClick(Sender: TObject);
var
  subrep, arep: TRpSubReport;
  aobject: TObject;
  changesubrep, i: Integer;
  swapped: Boolean;
  op: TChangeObjectOperation;
begin
  swapped := False;
  aobject := FindSelectedObject;
  if (aobject is TRpSubReport) then
  begin
    subrep := TRpSubReport(aobject);
    changesubrep := -1;
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      if FReport.SubReports.Items[i].SubReport = subrep then
      begin
        if changesubrep < 0 then break;
        arep := FReport.SubReports.Items[changesubrep].SubReport;
        FReport.SubReports.Items[changesubrep].SubReport := subrep;
        FReport.SubReports.Items[i].SubReport := arep;
        swapped := True;
        if Assigned(FReport) and Assigned(FReport.UndoCue) then
        begin
          op := TChangeObjectOperation.Create(otSwapUp, TUndoCue(FReport.UndoCue).GetGroupId);
          op.componentName := subrep.Name;
          op.componentClass := 'TRPSUBREPORT';
          op.oldItemIndex := i;
          TUndoCue(FReport.UndoCue).AddOperation(op);
          if Assigned(cueview) then
            cueview.RefreshList;
        end;
        break;
      end;
      changesubrep := i;
    end;
    if swapped then
    begin
      CreateInterface;
      SelectDataItem(subrep);
      if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
        TFRpDesignFrameLCL(designframe).UpdateInterface(True);
    end;
  end
  else if (aobject is TRpSection) then
  begin
    swapped := MoveSection(TRpSection(aobject), True, False, -1);
    if swapped then
    begin
      CreateInterface;
      SelectDataItem(TRpSection(aobject));
      if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
        TFRpDesignFrameLCL(designframe).UpdateInterface(True);
    end;
  end;
end;

procedure TFRpStructureLCL.BDownClick(Sender: TObject);
var
  subrep, arep: TRpSubReport;
  aobject: TObject;
  changesubrep, i: Integer;
  swapped: Boolean;
  op: TChangeObjectOperation;
begin
  swapped := False;
  aobject := FindSelectedObject;
  if (aobject is TRpSubReport) then
  begin
    subrep := TRpSubReport(aobject);
    changesubrep := -1;
    for i := 0 to FReport.SubReports.Count - 1 do
    begin
      if FReport.SubReports.Items[i].SubReport = subrep then
        changesubrep := i
      else if changesubrep >= 0 then
      begin
        arep := FReport.SubReports.Items[i].SubReport;
        FReport.SubReports.Items[i].SubReport := subrep;
        FReport.SubReports.Items[changesubrep].SubReport := arep;
        swapped := True;
        if Assigned(FReport) and Assigned(FReport.UndoCue) then
        begin
          op := TChangeObjectOperation.Create(otSwapDown, TUndoCue(FReport.UndoCue).GetGroupId);
          op.componentName := subrep.Name;
          op.componentClass := 'TRPSUBREPORT';
          op.oldItemIndex := changesubrep;
          TUndoCue(FReport.UndoCue).AddOperation(op);
          if Assigned(cueview) then
            cueview.RefreshList;
        end;
        break;
      end;
    end;
    if swapped then
    begin
      CreateInterface;
      SelectDataItem(subrep);
      if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
        TFRpDesignFrameLCL(designframe).UpdateInterface(True);
    end;
  end
  else if (aobject is TRpSection) then
  begin
    swapped := MoveSection(TRpSection(aobject), False, False, -1);
    if swapped then
    begin
      CreateInterface;
      SelectDataItem(TRpSection(aobject));
      if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
        TFRpDesignFrameLCL(designframe).UpdateInterface(True);
    end;
  end;
end;

procedure TFRpStructureLCL.BDeleteClick(Sender: TObject);
begin
  DeleteSelectedNode;
end;

procedure TFRpStructureLCL.ReleaseDesignSurface;
begin
  // The design frame and the inspector reference the sections/components
  // displayed; drop them before any of them is freed
  if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(designframe).SelectSubReport(nil);
end;

function TFRpStructureLCL.CountDetails(ASubReport: TRpSubReport): Integer;
var
  i: Integer;
begin
  Result := 0;
  if not Assigned(ASubReport) then Exit;
  for i := 0 to ASubReport.Sections.Count - 1 do
  begin
    if Assigned(ASubReport.Sections.Items[i].Section) and
       (ASubReport.Sections.Items[i].Section.SectionType = rpsecdetail) then
      Inc(Result);
  end;
end;

procedure TFRpStructureLCL.DeleteSelectedNode;
var
  secorsub: TObject;
  selsubreport, nextselection: TRpSubReport;
  cue: TUndoCue;
  gid: Integer;
begin
  if not Assigned(FReport) then Exit;
  secorsub := FindSelectedObject;
  if not Assigned(secorsub) then Exit;

  if RpMessageBox(SRpSureDeleteSection, SRpWarning, [smbOk, smbCancel], smsWarning, smbCancel) <> smbOk then
    Exit;

  // Validate before recording or deleting anything: a refused deletion must
  // not leave half of it done and recorded
  selsubreport := nil;
  if (secorsub is TRpSubReport) then
  begin
    if FReport.SubReports.Count <= 1 then
    begin
      RpShowMessage('Cannot delete the only subreport');
      Exit;
    end;
  end
  else if (secorsub is TRpSection) then
  begin
    selsubreport := FindSelectedSubreport;
    if not Assigned(selsubreport) then Exit;
    if (TRpSection(secorsub).SectionType = rpsecdetail) and (CountDetails(selsubreport) < 2) then
    begin
      RpShowMessage(SRpAtLeastOneDetail);
      Exit;
    end;
  end
  else
    Exit;

  ReleaseDesignSurface;
  nextselection := selsubreport;
  cue := nil;
  gid := 0;
  if Assigned(FReport.UndoCue) then
  begin
    cue := TUndoCue(FReport.UndoCue);
    gid := cue.GetGroupId;
    cue.BeginUpdate;
  end;
  try
    if (secorsub is TRpSubReport) then
      DeleteSubReportWithUndo(TRpSubReport(secorsub), cue, gid)
    else
      DeleteSectionWithUndo(TRpSection(secorsub), selsubreport, cue, gid);
  finally
    if Assigned(cue) then
      cue.EndUpdate;
    // Rebuild the tree and the design surface from the report, also when
    // the deletion failed midway
    CreateInterface;
    if Assigned(nextselection) then
      SelectDataItem(nextselection);
    if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
      TFRpDesignFrameLCL(designframe).UpdateSelection(True);
    if Assigned(cue) and Assigned(cueview) then
      cueview.RefreshList;
  end;
end;

procedure TFRpStructureLCL.DeleteSectionComponentsWithUndo(ASection: TRpSection;
  cue: TUndoCue; gid: Integer);
var
  cp: TRpCommonPosComponent;
  cop: TChangeObjectOperation;
begin
  // Components are removed from the first position, each recorded with
  // index 0: undo re-inserts them newest first at 0, restoring the order.
  // No oldParentName: this is not a parent change (undo would move every
  // restored component to the end of the section).
  while ASection.ReportComponents.Count > 0 do
  begin
    cp := TRpCommonPosComponent(ASection.ReportComponents.Items[0].Component);
    cop := TChangeObjectOperation.Create(otRemove, gid);
    try
      cop.componentName := cp.Name;
      cop.componentClass := UpperCase(cp.ClassName);
      cop.parentName := ASection.Name;
      cop.oldItemIndex := 0;
      cue.AddAllComponentProperties(cp, cop);
    except
      cop.Free;
      raise;
    end;
    cue.AddOperation(cop);
    ASection.DeleteComponent(cp);
  end;
end;

procedure TFRpStructureLCL.DeleteSubReportWithUndo(ASubReport: TRpSubReport;
  cue: TUndoCue; gid: Integer);
var
  op: TChangeObjectOperation;
  i, j, subrepIndex: Integer;
  asec, refSection: TRpSection;
  refSubrep: TRpSubReport;
begin
  subrepIndex := -1;
  for i := 0 to FReport.SubReports.Count - 1 do
  begin
    if FReport.SubReports.Items[i].SubReport = ASubReport then
    begin
      subrepIndex := i;
      Break;
    end;
  end;

  // Sections of other subreports that use it as child subreport
  for i := 0 to FReport.SubReports.Count - 1 do
  begin
    refSubrep := FReport.SubReports.Items[i].SubReport;
    for j := 0 to refSubrep.Sections.Count - 1 do
    begin
      refSection := refSubrep.Sections.Items[j].Section;
      if Assigned(refSection) and (refSection.ChildSubReport = ASubReport) then
      begin
        if Assigned(cue) then
        begin
          op := TChangeObjectOperation.Create(otModify, gid);
          op.componentName := refSection.Name;
          op.componentClass := 'TRPSECTION';
          op.AddProperty('childSubreportName', ptString, ASubReport.Name, '');
          cue.AddOperation(op);
        end;
        refSection.ChildSubReport := nil;
      end;
    end;
  end;

  if Assigned(cue) then
  begin
    // Sections are recorded with index 0 and not removed until the end:
    // undo re-inserts them newest first at 0, restoring the order
    for i := 0 to ASubReport.Sections.Count - 1 do
    begin
      asec := ASubReport.Sections.Items[i].Section;
      if not Assigned(asec) then Continue;
      DeleteSectionComponentsWithUndo(asec, cue, gid);
      op := TChangeObjectOperation.Create(otRemove, gid);
      try
        op.componentName := asec.Name;
        op.componentClass := 'TRPSECTION';
        op.parentName := ASubReport.Name;
        op.oldItemIndex := 0;
        cue.AddSectionProperties(asec, op);
      except
        op.Free;
        raise;
      end;
      cue.AddOperation(op);
    end;

    op := TChangeObjectOperation.Create(otRemove, gid);
    try
      op.componentName := ASubReport.Name;
      op.componentClass := 'TRPSUBREPORT';
      op.oldItemIndex := subrepIndex;
      cue.AddSubreportProperties(ASubReport, op);
    except
      op.Free;
      raise;
    end;
    cue.AddOperation(op);
  end;

  FReport.DeleteSubreport(ASubReport);
end;

procedure TFRpStructureLCL.DeleteSectionWithUndo(ASection: TRpSection;
  ASubReport: TRpSubReport; cue: TUndoCue; gid: Integer);
var
  op: TChangeObjectOperation;
  i, j, sectionIndex, removedSections: Integer;
  asec: TRpSection;
  secToDelete: TList;

  procedure RecordSectionRemove(ADeleted: TRpSection; AIndex: Integer);
  begin
    DeleteSectionComponentsWithUndo(ADeleted, cue, gid);
    op := TChangeObjectOperation.Create(otRemove, gid);
    try
      op.componentName := ADeleted.Name;
      op.componentClass := 'TRPSECTION';
      op.parentName := ASubReport.Name;
      op.oldItemIndex := AIndex;
      cue.AddSectionProperties(ADeleted, op);
    except
      op.Free;
      raise;
    end;
    cue.AddOperation(op);
  end;

begin
  if Assigned(cue) then
  begin
    if ASection.SectionType in [rpsecgheader, rpsecgfooter] then
    begin
      // FreeSection removes the header and the footer of the group
      secToDelete := TList.Create;
      try
        for i := 0 to ASubReport.Sections.Count - 1 do
        begin
          asec := ASubReport.Sections.Items[i].Section;
          if Assigned(asec) and SameText(asec.GroupName, ASection.GroupName) and
             (asec.SectionType in [rpsecgheader, rpsecgfooter]) then
            secToDelete.Add(asec);
        end;
        // Index each one as it will be after the previous removals, the
        // order undo re-inserts them in reverse
        removedSections := 0;
        for i := 0 to secToDelete.Count - 1 do
        begin
          sectionIndex := -1;
          for j := 0 to ASubReport.Sections.Count - 1 do
          begin
            if ASubReport.Sections.Items[j].Section = secToDelete[i] then
            begin
              sectionIndex := j - removedSections;
              Break;
            end;
          end;
          if sectionIndex < 0 then Continue;
          RecordSectionRemove(TRpSection(secToDelete[i]), sectionIndex);
          Inc(removedSections);
        end;
      finally
        secToDelete.Free;
      end;
    end
    else
    begin
      for i := 0 to ASubReport.Sections.Count - 1 do
      begin
        if ASubReport.Sections.Items[i].Section = ASection then
        begin
          RecordSectionRemove(ASection, i);
          Break;
        end;
      end;
    end;
  end;
  ASubReport.FreeSection(ASection);
end;

procedure TFRpStructureLCL.BNewClick(Sender: TObject);
var
  apoint: TPoint;
begin
  apoint.x := BNew.Left;
  apoint.y := BNew.Top + BNew.Height;
  apoint := Panel1.ClientToScreen(apoint);
  PopupMenu1.Popup(apoint.x, apoint.y);
end;

procedure TFRpStructureLCL.BDataConfigClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  // True when the dialog applied changes (it records them in the undo cue)
  if not ShowDataConfig(FReport) then Exit;
  if Assigned(browser) then
    browser.Report := FReport;
  // Subreport captions show their main dataset
  UpdateCaptions;
  if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(designframe).UpdateSelection(False);
end;

procedure TFRpStructureLCL.MNewSectionClick(Sender: TObject);
var
  subrep: TRpSubReport;
  asection, footersec: TRpSection;
  newgroupname: string;
  cue: TUndoCue;
  op: TChangeObjectOperation;
  gid, i, headerIndex, footerIndex: Integer;
begin
  if not Assigned(FReport) then Exit;
  subrep := FindSelectedSubreport;
  if not Assigned(subrep) then Exit;

  asection := nil;
  if Sender = MSubReport then
  begin
    subrep := FReport.AddSubReport;
    if Assigned(FReport.UndoCue) then
    begin
      cue := TUndoCue(FReport.UndoCue);
      op := TChangeObjectOperation.Create(otAdd, cue.GetGroupId);
      op.componentName := subrep.Name;
      op.componentClass := 'TRPSUBREPORT';
      cue.AddSubreportProperties(subrep, op);
      cue.AddOperation(op);
      if Assigned(cueview) then
        cueview.RefreshList;
    end;
    CreateInterface;
    SelectDataItem(subrep);
    if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
    begin
      TFRpDesignFrameLCL(designframe).SelectSubReport(subrep);
      TFRpDesignFrameLCL(designframe).UpdateInterface(True);
    end;
    Exit;
  end
  else if Sender = MPHeader then
    asection := subrep.AddPageHeader
  else if Sender = MPFooter then
    asection := subrep.AddPageFooter
  else if Sender = MDetail then
    asection := subrep.AddDetail
  else if Sender = MGHeader then
  begin
    newgroupname := UpperCase(Trim(RpInputBox(SRpNewGroup, SRpSGroupName, '')));
    if Length(newgroupname) > 0 then
    begin
      asection := subrep.AddGroup(newgroupname);
      headerIndex := -1;
      footerIndex := -1;
      footersec := nil;
      for i := 0 to subrep.Sections.Count - 1 do
      begin
        if (subrep.Sections.Items[i].Section.SectionType = rpsecgheader) and
           SameText(subrep.Sections.Items[i].Section.GroupName, newgroupname) then
        begin
          headerIndex := i;
          asection := subrep.Sections.Items[i].Section;
        end;
        if (subrep.Sections.Items[i].Section.SectionType = rpsecgfooter) and
           SameText(subrep.Sections.Items[i].Section.GroupName, newgroupname) then
        begin
          footerIndex := i;
          footersec := subrep.Sections.Items[i].Section;
        end;
      end;
      if Assigned(FReport.UndoCue) then
      begin
        cue := TUndoCue(FReport.UndoCue);
        gid := cue.GetGroupId;
        if (headerIndex >= 0) and Assigned(asection) then
        begin
          op := TChangeObjectOperation.Create(otAdd, gid);
          op.componentName := asection.Name;
          op.componentClass := 'TRPSECTION';
          op.parentName := subrep.Name;
          op.oldItemIndex := headerIndex;
          cue.AddSectionProperties(asection, op);
          cue.AddOperation(op);
        end;
        if (footerIndex >= 0) and Assigned(footersec) then
        begin
          op := TChangeObjectOperation.Create(otAdd, gid);
          op.componentName := footersec.Name;
          op.componentClass := 'TRPSECTION';
          op.parentName := subrep.Name;
          op.oldItemIndex := footerIndex;
          cue.AddSectionProperties(footersec, op);
          cue.AddOperation(op);
        end;
        if Assigned(cueview) then
          cueview.RefreshList;
      end;
    end;
  end;

  if Assigned(asection) and (Sender <> MGHeader) then
  begin
    if Assigned(FReport.UndoCue) then
    begin
      cue := TUndoCue(FReport.UndoCue);
      op := TChangeObjectOperation.Create(otAdd, cue.GetGroupId);
      op.componentName := asection.Name;
      op.componentClass := 'TRPSECTION';
      op.parentName := subrep.Name;
      op.oldItemIndex := subrep.Sections.IndexOf(asection);
      cue.AddSectionProperties(asection, op);
      cue.AddOperation(op);
      if Assigned(cueview) then
        cueview.RefreshList;
    end;
  end;

  if Assigned(asection) then
  begin
    CreateInterface;
    SelectDataItem(asection);
    if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
      TFRpDesignFrameLCL(designframe).UpdateInterface(True);
  end;
end;

procedure TFRpStructureLCL.RViewClick(Sender: TObject);
var
  aobject: TObject;
begin
  if Assigned(designframe) and (designframe is TFRpDesignFrameLCL) then
    TFRpDesignFrameLCL(designframe).UpdateSelection(False);

  aobject := FindSelectedObject;
  BUp.Enabled := Assigned(aobject);
  BDown.Enabled := Assigned(aobject);
  BDelete.Enabled := Assigned(aobject);
end;

procedure TFRpStructureLCL.RViewChange(Sender: TObject; Node: TTreeNode);
begin
  RViewClick(Self);
end;

end.

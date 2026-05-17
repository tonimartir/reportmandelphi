{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmdfstrucvcl                                   }
{       Shows the report structure and allow to alter it}
{                                                       }
{                                                       }
{       Copyright (c) 1994-2019 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}

unit rpmdfstrucvcl;

interface

{$I rpconf.inc}

uses
  SysUtils,Windows,
{$IFDEF USEVARIANTS}
  Types,
{$ENDIF}
{$IFDEF DELPHI2009UP}
 //System.Actions,
{$ENDIF}
  Classes,
  Graphics, Controls, Forms, Dialogs,
  ComCtrls,Menus, ActnList, ImgList, Buttons, ExtCtrls,
  rpreport,rpsubreport,rpmdconsts,rpdbbrowservcl,rpgraphutilsvcl,
  rpsection,rpmdobjinspvcl,rpprintitem,rptypes, ToolWin, System.Actions,
  System.ImageList, Vcl.VirtualImageList, Vcl.BaseImageCollection,
  Vcl.ImageCollection;

type
  TFRpStructureVCL = class(TFrame)
    ActionList1: TActionList;
    ImageList1: TImageList;
    AUp: TAction;
    ADown: TAction;
    ADelete: TAction;
    PopupMenu1: TPopupMenu;
    MDetail: TMenuItem;
    MPHeader: TMenuItem;
    MPFooter: TMenuItem;
    MGHeader: TMenuItem;
    MSubReport: TMenuItem;
    PControl: TPageControl;
    TabStructure: TTabSheet;
    RView: TTreeView;
    Panel1: TToolBar;
    BNew: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    TabData: TTabSheet;
    ImageCollection1: TImageCollection;
    VirtualImageList1: TVirtualImageList;
    procedure Expand1Click(Sender: TObject);
    procedure RViewClick(Sender: TObject);
    procedure AUpExecute(Sender: TObject);
    procedure ADownExecute(Sender: TObject);
    procedure ADeleteExecute(Sender: TObject);
    procedure BNewClick(Sender: TObject);
    procedure MPHeaderClick(Sender: TObject);
    procedure RViewChange(Sender: TObject; Node: TTreeNode);
    procedure TabStructureResize(Sender: TObject);
  private
    { Private declarations }
    oldappidle:TIdleEvent;
    AAction:TAction;
    FReport:TRpReport;
    FObjInsp:TFRpObjInspVCL;
    procedure ActionIdle(Sender:TObject;var done:boolean);
    procedure SetReport(Value:TRpReport);
    procedure CreateInterface;
    procedure DisableRView;
    procedure EnableRView;
    function FindSectionIndex(ASubReport: TRpSubReport; ASection: TRpSection): Integer;
    function FindGroupSection(ASubReport: TRpSubReport; const AGroupName: string;
      ASectionType: TRpSectionType): TRpSection;
    procedure AddSectionSwapUndo(ASection: TRpSection; const AParentName: string;
      AOldItemIndex: Integer; AOperation: TOperationType; AGroupId: Integer);
    function MoveSection(ASection: TRpSection; MoveUp, SecondStep: Boolean;
      AGroupId: Integer): Boolean;
  public
    { Public declarations }
    designframe:TControl;
    browser:TFRpBrowserVCL;
    procedure UpdateCaptions;
    function FindSelectedSubreport:TRpSubreport;
    function FindSelectedObject:TObject;
    constructor Create(AOwner:TComponent);override;
    destructor Destroy;override;
    procedure DeleteSelectedNode;
    property Report:TRpReport read FReport write SetReport;
    property ObjInsp:TFRpObjInspVCL read FObjInsp write FObjInsp;
    procedure RefreshInterface;
    procedure SelectDataItem(data:TObject);
  end;

implementation

{$R *.dfm}

uses rpmdfdesignvcl, rpmdfmainvcl, rpmdundocue;




constructor TFRpStructureVCL.Create(AOwner:TComponent);
begin
 inherited Create(AOwner);

 // ScaleToolBar(Panel1);

 MPHeader.Caption:=TranslateStr(119,MPHeader.Caption);
 MPHeader.Hint:=TranslateStr(120,MPHeader.Hint);
 MPFooter.Caption:=TranslateStr(121,MPFooter.Caption);
 MPFooter.Hint:=TranslateStr(122,MPFooter.Hint);
 MGHeader.Caption:=TranslateStr(123,MGHeader.Caption);
 MGHeader.Hint:=TranslateStr(124,MGHeader.Hint);
 MSubReport.Caption:=TranslateStr(125,MSubreport.Caption);
 MSubReport.Hint:=TranslateStr(126,MSubreport.Hint);
 MDetail.Caption:=TranslateStr(129,MDetail.Caption);
 MDetail.Hint:=TranslateStr(130,MDetail.Hint);

 ADelete.Caption:=TranslateStr(137,ADelete.Caption);
 ADelete.Hint:=TranslateStr(138,ADelete.Hint);

 AUp.Hint:=TranslateStr(139,AUp.Hint);
 ADown.Hint:=TranslateStr(140,ADown.Hint);
 BNew.Hint:=TranslateStr(734,BNew.Hint);

 TabStructure.Caption:=SRpStructure;
 TabData.Caption:=SRpData;
 browser:=TFRpBrowserVCL.Create(Self);
 browser.ShowDatabases:=false;
 browser.Parent:=TabData;
 PControl.ActivePageIndex:=0;

 RView.Align := alClient;
end;

destructor TFRpStructureVCL.Destroy;
begin
 browser.FreeFieldsInfo;
 inherited Destroy;
end;


procedure TFRpStructureVCL.SetReport(Value:TRpReport);
begin
 FReport:=Value;
 if Not Assigned(FReport) then
  exit;
 // Creates the interface
 CreateInterface;
 RView.FullExpand;
 Browser.Report:=FReport;
 if Assigned(designframe) then
 begin
  TFRpDesignFrameVCL(designframe).UpdateSelection(true);
 end;
end;

procedure TFRpStructureVCL.TabStructureResize(Sender: TObject);
begin
 panel1.ButtonWidth:=ScaleDpi(26);
 panel1.ButtonHeight:=ScaleDpi(26);
end;

procedure TFRpStructureVCL.ActionIdle(Sender:TObject;var done:boolean);
var
 FRpMainF:TFRpMainFVCL;
begin
 FRpMainF:=TFRpMainFVCL(Owner);
 Application.OnIdle:=oldappidle;
 done:=false;
 if Assigned(AAction) then
  AAction.Execute
 else
 begin
  FRpMainF.RefreshInterface(Self);
 end;
end;

function TFRpStructureVCL.FindSelectedSubreport:TRpSubreport;
var
 selectednode:TTreeNode;
begin
 Result:=nil;
 selectednode:=RView.Selected;
 if Not Assigned(selectednode) then
 begin
  selectednode:=RView.Items[0];
 end;
 if Not Assigned(selectednode) then
  Raise Exception.Create(SRPNoSelectedSubreport);
 Assert(selectednode.data<>nil,'Node without data assertion error');
 if (TObject(selectednode.data) is TRpSubReport) then
 begin
  Result:=TRpSubReport(selectednode.data);
  exit;
 end;
 selectednode:=selectednode.Parent;
 Assert(selectednode.data<>nil,'Expected subreport');
 if (TObject(selectednode.data) is TRpSubReport) then
 begin
  Result:=TRpSubReport(selectednode.data);
  exit;
 end;
 Assert(selectednode.data<>nil,'Expected subreport');
end;


function TFRpStructureVCL.FindSelectedObject:TObject;
var
 selectednode:TTreeNode;
begin
 selectednode:=RView.Selected;
 if Not Assigned(selectednode) then
 begin
  selectednode:=RView.Items[0];
 end;
 if Not Assigned(selectednode) then
  Raise Exception.Create(SRPNoSelectedSubreport);
 Assert(selectednode.data<>nil,'Node without data assertion error');
 Assert(selectednode.data<>nil,'Expected data with a value');
 Result:=TObject(selectednode.data);
end;

procedure TFRpStructureVCL.UpdateCaptions;
var
 i:integer;
 aobj:TObject;
begin
 for i:=0 to RView.Items.Count-1 do
 begin
  if assigned(RView.Items[i].Data) then
  begin
   aobj:=TObject(RView.Items[i].Data);
   if aobj is TRpSection then
   begin
    RView.Items[i].Text:=TRpSection(RView.Items[i].Data).SectionCaption(true);
   end;
  end;
 end;
end;


procedure TFRpStructureVCL.DisableRView;
begin
 RView.Items.BeginUpdate;
 RView.OnChange:=nil;
 RView.OnClick:=nil;
end;

procedure TFRpStructureVCL.EnableRView;
begin
 RView.OnChange:=RViewChange;
 RView.OnClick:=RViewClick;
 RView.Items.EndUpdate;
end;

procedure TFRpStructureVCL.CreateInterface;
var
 anew:TTreeNode;
 i,j:integer;
 subr:TRpSubreport;
 child:TTreeNode;
begin
 DisableRView;
 try
   RView.Items.Clear;

   // Adds the items
   for i:=0 to Report.SubReports.Count-1 do
   begin
    subr:=Report.SubReports.Items[i].SubReport;
    anew:=RView.Items.Add(nil,subr.GetDisplayName(true));
    anew.data:=Report.SubReports.Items[i].SubReport;
    for j:=0 to subr.Sections.Count-1 do
    begin
     child:=RView.Items.AddChild(anew,subr.Sections.Items[j].Section.SectionCaption(true));
     child.data:=subr.Sections.Items[j].Section;
    end;
   end;
 finally
  EnableRView;
 end;
 if Not Assigned(RView.Selected) then
  RView.Selected:=RView.TopItem
end;


procedure TFRpStructureVCL.Expand1Click(Sender: TObject);
begin
 RView.FullExpand;
end;

procedure TFRpStructureVCL.DeleteSelectedNode;
var
 secorsub:TObject;
 selsubreport:TRpSubReport;
begin
 secorsub:=FindSelectedObject;
 if (secorsub is TRpSubReport) then
  freport.DeleteSubreport(TRpSubReport(secorsub))
 else
 begin
  if (Not (secorsub is TRpSection)) then
   Raise Exception.Create(SRPNoSelectedSection);
  selsubreport:=FindSelectedSubreport;
  selsubreport.FreeSection(TRpSection(secorsub));
 end;
end;

procedure TFRpStructureVCL.RViewClick(Sender: TObject);
var
 aobject:TObject;
begin
 TFRpDesignFrameVCL(designframe).UpdateSelection(false);
 aobject:=FindSelectedObject;
 if Assigned(aobject) then
 begin
  AUp.Enabled:=True;
  ADown.Enabled:=True;
 end
 else
 begin
  AUp.Enabled:=False;
  ADown.Enabled:=False;
 end;
end;

function FindDataInTree(nodes:TTreeNodes;data:TObject):TTreeNode;
var
 i:integer;
begin
 Result:=nil;
 i:=0;
 while i<nodes.Count do
 begin
  if nodes.item[i].data=Data then
  begin
   Result:=nodes.item[i];
   break;
  end;
  inc(i);
 end;
end;

procedure TFRpStructureVCL.SelectDataItem(data:TObject);
var
 anode:TTreeNode;
begin
 anode:=FindDataInTree(RView.Items,data);
 if Assigned(anode) then
 begin
  RView.Selected:=anode;
  RViewClick(Self);
 end;
end;

function TFRpStructureVCL.FindSectionIndex(ASubReport: TRpSubReport;
  ASection: TRpSection): Integer;
var
  i: Integer;
begin
 Result:=-1;
 if (not Assigned(ASubReport)) or (not Assigned(ASection)) then
  exit;
 for i:=0 to ASubReport.Sections.Count-1 do
 begin
  if ASubReport.Sections.Items[i].Section=ASection then
  begin
   Result:=i;
   break;
  end;
 end;
end;

function TFRpStructureVCL.FindGroupSection(ASubReport: TRpSubReport;
  const AGroupName: string; ASectionType: TRpSectionType): TRpSection;
var
  i: Integer;
  asec: TRpSection;
begin
 Result:=nil;
 if not Assigned(ASubReport) then
  exit;
 for i:=0 to ASubReport.Sections.Count-1 do
 begin
  asec:=ASubReport.Sections.Items[i].Section;
  if Assigned(asec) and (asec.SectionType=ASectionType) and
    SameText(asec.GroupName,AGroupName) then
  begin
   Result:=asec;
   break;
  end;
 end;
end;

procedure TFRpStructureVCL.AddSectionSwapUndo(ASection: TRpSection;
  const AParentName: string; AOldItemIndex: Integer; AOperation: TOperationType;
  AGroupId: Integer);
var
  cue: TUndoCue;
  op: TChangeObjectOperation;
begin
 if (AOldItemIndex<0) or (not Assigned(ASection)) or (not Assigned(Report)) or
   (not Assigned(Report.UndoCue)) then
  exit;
 cue:=TUndoCue(Report.UndoCue);
 op:=TChangeObjectOperation.Create(AOperation,AGroupId);
 op.componentName:=ASection.Name;
 op.componentClass:='TRPSECTION';
 op.parentName:=AParentName;
 op.oldItemIndex:=AOldItemIndex;
 cue.AddOperation(op);
end;

function TFRpStructureVCL.MoveSection(ASection: TRpSection; MoveUp,
  SecondStep: Boolean; AGroupId: Integer): Boolean;
var
  subrep: TRpSubReport;
  oldIndex,newIndex: Integer;
  swapSection: TRpSection;
  otherSection: TRpSection;
  canSwap: Boolean;
  asec: TRpSection;
  operation: TOperationType;
begin
 Result:=false;
 if not Assigned(ASection) then
  exit;
 subrep:=TrpSubReport(ASection.SubReport);
 if not Assigned(subrep) then
  exit;
 oldIndex:=FindSectionIndex(subrep,ASection);
 if oldIndex<0 then
  exit;
 if MoveUp then
  newIndex:=oldIndex-1
 else
  newIndex:=oldIndex+1;
 if (newIndex<0) or (newIndex>=subrep.Sections.Count) then
  exit;
 swapSection:=subrep.Sections.Items[newIndex].Section;
 if not Assigned(swapSection) then
  exit;
 canSwap:=true;
 case ASection.SectionType of
  rpsecdetail,rpsecpheader,rpsecpfooter:
   if swapSection.SectionType<>ASection.SectionType then
    canSwap:=false;
  rpsecgheader:
   begin
    if swapSection.SectionType<>rpsecgheader then
     canSwap:=false
    else
    if not SecondStep then
    begin
     otherSection:=FindGroupSection(subrep,ASection.GroupName,rpsecgfooter);
     if Assigned(otherSection) then
      canSwap:=MoveSection(otherSection,not MoveUp,true,AGroupId)
     else
      canSwap:=false;
    end;
   end;
  rpsecgfooter:
   begin
    if swapSection.SectionType<>rpsecgfooter then
     canSwap:=false
    else
    if not SecondStep then
    begin
     otherSection:=FindGroupSection(subrep,ASection.GroupName,rpsecgheader);
     if Assigned(otherSection) then
      canSwap:=MoveSection(otherSection,not MoveUp,true,AGroupId)
     else
      canSwap:=false;
    end;
   end;
 else
  canSwap:=false;
 end;
 if not canSwap then
  exit;
 asec:=subrep.Sections.Items[newIndex].Section;
 subrep.Sections.Items[newIndex].Section:=subrep.Sections.Items[oldIndex].Section;
 subrep.Sections.Items[oldIndex].Section:=asec;
 if MoveUp then
  operation:=otSwapUp
 else
  operation:=otSwapDown;
 AddSectionSwapUndo(ASection,subrep.Name,oldIndex,operation,AGroupId);
 Result:=true;
end;


procedure TFRpStructureVCL.AUpExecute(Sender: TObject);
var
 subrep:TRpSubreport;
 arep:TRpSubReport;
 aobject:TObject;
 changesubrep:integer;
 i:integer;
 swapped:boolean;
 cue:TUndoCue;
 op:TChangeObjectOperation;
 oldItemIndex:integer;
 groupId:Integer;
begin
 // Goes up
 swapped:=false;
 oldItemIndex:=-1;
 groupId:=-1;
 aobject:=FindSelectedObject;
 if (aobject is TRpSubReport) then
 begin
  subrep:=TRpSubReport(FindSelectedObject);
  i:=0;
  changesubrep:=-1;
  while i<report.SubReports.Count do
  begin
   if report.SubReports.Items[i].SubReport=subrep then
   begin
    if changesubrep<0 then
     break;
     oldItemIndex:=i;
     arep:=report.SubReports.Items[changesubrep].SubReport;
     report.SubReports.Items[changesubrep].SubReport:=subrep;
     report.SubReports.Items[i].SubReport:=arep;
     swapped:=true;
     SetReport(FReport);
     SelectDataItem(subrep);
     break;
    end;
    changesubrep:=i;
    inc(i);
   end;
  end
  else
  if (aobject is TRpSection) then
  begin
   if Assigned(Report) and Assigned(Report.UndoCue) then
    groupId:=TUndoCue(Report.UndoCue).GetGroupId;
   swapped:=MoveSection(TRpSection(aobject),true,false,groupId);
   if swapped then
   begin
    SetReport(FReport);
    SelectDataItem(TRpSection(aobject));
    TFRpMainFVCL(Owner).RefreshCueView;
   end;
  end;
  if swapped and (aobject is TRpSubReport) and Assigned(Report) and Assigned(Report.UndoCue) then
  begin
   cue:=TUndoCue(Report.UndoCue);
   op:=TChangeObjectOperation.Create(otSwapUp, cue.GetGroupId);
   op.componentName:=TRpSubReport(aobject).Name;
   op.componentClass:='TRPSUBREPORT';
   op.oldItemIndex:=oldItemIndex;
   cue.AddOperation(op);
   TFRpMainFVCL(Owner).RefreshCueView;
  end;
 end;

procedure TFRpStructureVCL.ADownExecute(Sender: TObject);
var
 subrep:TRpSubreport;
 arep:TRpSubReport;
 changesubrep:integer;
 i:integer;
 aobject:TObject;
 swapped:boolean;
 cue:TUndoCue;
 op:TChangeObjectOperation;
 oldItemIndex:integer;
 groupId:Integer;
begin
 // Goes down
 swapped:=false;
 oldItemIndex:=-1;
 groupId:=-1;
 aobject:=FindSelectedObject;
 if (aobject is TRpSubReport) then
 begin
  subrep:=TRpSubReport(FindSelectedObject);
  i:=0;
  changesubrep:=-1;
  while i<report.SubReports.Count do
  begin
   if report.SubReports.Items[i].SubReport=subrep then
   begin
    changesubrep:=i;
   end
   else
   begin
    if changesubrep>=0 then
    begin
       oldItemIndex:=changesubrep;
     arep:=report.SubReports.Items[i].SubReport;
     report.SubReports.Items[i].SubReport:=subrep;
     report.SubReports.Items[changesubrep].SubReport:=arep;

     swapped:=true;
     SetReport(FReport);
     SelectDataItem(subrep);
     break;
    end;
   end;
   inc(i);
  end;
 end
 else
 if (aobject is TRpSection) then
 begin
  if Assigned(Report) and Assigned(Report.UndoCue) then
   groupId:=TUndoCue(Report.UndoCue).GetGroupId;
  swapped:=MoveSection(TRpSection(aobject),false,false,groupId);
  if swapped then
  begin
   SetReport(FReport);
   SelectDataItem(TRpSection(aobject));
   TFRpMainFVCL(Owner).RefreshCueView;
  end;
 end;
 if swapped and (aobject is TRpSubReport) and Assigned(Report) and Assigned(Report.UndoCue) then
 begin
  cue:=TUndoCue(Report.UndoCue);
  op:=TChangeObjectOperation.Create(otSwapDown, cue.GetGroupId);
  op.componentName:=TRpSubReport(aobject).Name;
  op.componentClass:='TRPSUBREPORT';
  op.oldItemIndex:=oldItemIndex;
  cue.AddOperation(op);
  TFRpMainFVCL(Owner).RefreshCueView;
 end;
end;

procedure TFRpStructureVCL.ADeleteExecute(Sender: TObject);
var
 FRpMainF:TFRpMainFVCL;
begin
 FRpMainF:=TFRpMainFVCL(Owner);
 AAction:=FRpMainf.ADeleteSelection;
 oldappidle:=Application.Onidle;
 Application.OnIdle:=ActionIdle;
end;

procedure TFRpStructureVCL.BNewClick(Sender: TObject);
var
 apoint:TPoint;
begin
 apoint.x:=BNew.Left;
 apoint.y:=BNew.Top+BNew.Height;
 apoint:=BNew.Parent.ClientToScreen(apoint);
 BNew.DropDownMenu.Popup(apoint.x,apoint.y);
end;

procedure TFRpStructureVCL.MPHeaderClick(Sender: TObject);
var
 FRpMainF:TFRpMainFVCL;
begin
 if Sender=MPHeader then
 begin
  FRpMainF:=TFRpMainFVCL(Owner);
  AAction:=FRpMainf.ANewPageHeader;
  oldappidle:=Application.Onidle;
  Application.OnIdle:=ActionIdle;
  exit;
 end;
 if Sender=MPFooter then
 begin
  FRpMainF:=TFRpMainFVCL(Owner);
  AAction:=FRpMainf.ANewPageFooter;
  oldappidle:=Application.Onidle;
  Application.OnIdle:=ActionIdle;
  exit;
 end;
 if Sender=MGHeader then
 begin
  FRpMainF:=TFRpMainFVCL(Owner);
  AAction:=FRpMainf.ANewGroup;
  oldappidle:=Application.Onidle;
  Application.OnIdle:=ActionIdle;
  exit;
 end;
 if Sender=MSubReport then
 begin
  FRpMainF:=TFRpMainFVCL(Owner);
  AAction:=FRpMainf.ANewSubreport;
  oldappidle:=Application.Onidle;
  Application.OnIdle:=ActionIdle;
  exit;
 end;
 if Sender=MDetail then
 begin
  FRpMainF:=TFRpMainFVCL(Owner);
  AAction:=FRpMainf.ANewDetail;
  oldappidle:=Application.Onidle;
  Application.OnIdle:=ActionIdle;
  exit;
 end;
end;

procedure TFRpStructureVCL.RefreshInterface;
begin
 AAction:=nil;
 oldappidle:=Application.Onidle;
 Application.OnIdle:=ActionIdle;
end;

procedure TFRpStructureVCL.RViewChange(Sender: TObject; Node: TTreeNode);
begin
 RViewClick(Self);
end;

end.

{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       Rpfparamsvcl                                    }
{                                                       }
{       Parameter definition form                       }
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

unit rpfparamsvcl;

interface

{$I rpconf.inc}

uses SysUtils, Classes,
  Graphics, Forms,Dialogs, ActnList, ImgList, ComCtrls,
  Buttons, ExtCtrls, Controls, StdCtrls,Mask,
  rpdatainfo,rpreport,
  Variants,
  DB,rpmdconsts,rpparams,rpmdundocue,
  rpgraphutilsvcl, ToolWin,rptypes, rpmaskedit, CheckLst, Vcl.VirtualImageList,
  Vcl.BaseImageCollection, Vcl.ImageCollection, System.Actions, System.ImageList,
  rpxmlstream, rpbasereport;

type
  TFRpParamsVCL = class(TForm)
    Panel1: TPanel;
    GProperties: TGroupBox;
    LDescription: TLabel;
    EDescription: TEdit;
    LDataType: TLabel;
    ComboDataType: TComboBox;
    LValue: TLabel;
    EValue: TRpMaskEdit;
    CheckVisible: TCheckBox;
    CheckNull: TCheckBox;
    LAssign: TLabel;
    ComboDatasets: TComboBox;
    BAdddata: TButton;
    BDeleteData: TButton;
    LDatasets: TListBox;
    Panel2: TPanel;
    LParams: TListBox;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    ImageList1: TImageList;
    ActionList1: TActionList;
    ANewParam: TAction;
    ADelete: TAction;
    AUp: TAction;
    ADown: TAction;
    ARename: TAction;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    ToolButton6: TToolButton;
    ToolButton7: TToolButton;
    Panel3: TPanel;
    BCancel: TButton;
    BOK: TButton;
    ESearch: TEdit;
    LSearch: TLabel;
    GValues: TGroupBox;
    CheckAllowNulls: TCheckBox;
    EHint: TEdit;
    LHint: TLabel;
    CheckNeverVisible: TCheckBox;
    CheckReadOnly: TCheckBox;
    ECheckList: TCheckListBox;
    Panel4: TPanel;
    MItems: TMemo;
    MValues: TMemo;
    LLookup: TLabel;
    ComboLookup: TComboBox;
    GSearch: TGroupBox;
    LSearchDataset: TLabel;
    ComboSearchDataset: TComboBox;
    Label1: TLabel;
    ComboSearchParam: TComboBox;
    EValidation: TEdit;
    EErrorMessage: TEdit;
    LErrorMessage: TLabel;
    LValidation: TLabel;
    ImageCollection1: TImageCollection;
    VirtualImageList1: TVirtualImageList;
    procedure FormCreate(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure LParamsClick(Sender: TObject);
    procedure EValueExit(Sender: TObject);
    procedure EDescriptionChange(Sender: TObject);
    procedure BAdddataClick(Sender: TObject);
    procedure BDeleteDataClick(Sender: TObject);
    procedure BAddClick(Sender: TObject);
    procedure BDeleteClick(Sender: TObject);
    procedure BRenameClick(Sender: TObject);
    procedure BUpClick(Sender: TObject);
    procedure BDownClick(Sender: TObject);
    procedure ComboSearchParamDropDown(Sender: TObject);
  private
    { Private declarations }
    updating:boolean;
    params:TRpParamList;
    datainfo:TRpDatainfoList;
    dook:boolean;
    report:TRpReport;
    procedure FillParamList;
    procedure UpdateValue(param:TRpParam);
    function IsDotNet:boolean;
  public
    { Public declarations }
  end;


procedure RecordParamUndoChanges(origParams,newParams:TRpParamList;report:TRpReport;
  groupId:integer=-1);
procedure ShowParamDef(params:TRpParamList;datainfo:TRpDatainfoList;report:TRpReport;
  deferUndoUntilAccept:boolean=False);

implementation

{$R *.dfm}

function ParamStringListToVariant(strings: TStrings): Variant;
var
 index: Integer;
begin
 if strings.Count=0 then
 begin
  Result:=VarArrayCreate([0,-1],varVariant);
  Exit;
 end;
 Result:=VarArrayCreate([0,strings.Count-1],varVariant);
 for index:=0 to strings.Count-1 do
  Result[index]:=strings[index];
end;

function SameStringLists(list1,list2:TStrings):Boolean;
begin
 Result:=list1.Text=list2.Text;
end;

function GetParamOperationName(param: TRpParam): string;
begin
 if not Assigned(param) then
  raise Exception.Create('GetParamOperationName: parameter is nil');
 if Trim(param.IntName)='' then
  raise Exception.Create('GetParamOperationName: parameter '+param.Name+' has empty IntName');
 Result:=param.IntName;
end;

procedure RecordParamUndoChanges(origParams,newParams:TRpParamList;report:TRpReport;
  groupId:integer=-1);
var
 undoCue:TUndoCue;
 i:integer;
 origParam,newParam:TRpParam;
 op:TChangeObjectOperation;
begin
 if not Assigned(report) then
  Exit;
 if not Assigned(report.UndoCue) then
  report.UndoCue:=TUndoCue.Create(report);
 undoCue:=TUndoCue(report.UndoCue);
 if groupId<0 then
  groupId:=undoCue.GetGroupId;
 // Detect removed params (in original but not in new list)
 for i:=0 to origParams.Count-1 do
 begin
  origParam:=origParams.Items[i];
    if newParams.FindParamByIntName(GetParamOperationName(origParam))=nil then
  begin
   op:=TChangeObjectOperation.Create(otRemove,groupId);
     op.componentName:=GetParamOperationName(origParam);
   op.componentClass:='TRPPARAM';
   op.oldItemIndex:=i;
     op.AddProperty('alias',ptString,origParam.Name,Null);
   op.AddProperty('description',ptString,origParam.Description,Null);
   op.AddProperty('hint',ptString,origParam.Hint,Null);
   op.AddProperty('validation',ptString,origParam.Validation,Null);
   op.AddProperty('errorMessage',ptString,origParam.ErrorMessage,Null);
   op.AddProperty('visible',ptBoolean,origParam.Visible,Null);
   op.AddProperty('neverVisible',ptBoolean,origParam.NeverVisible,Null);
   op.AddProperty('isReadOnly',ptBoolean,origParam.IsReadOnly,Null);
   op.AddProperty('allowNulls',ptBoolean,origParam.AllowNulls,Null);
   op.AddProperty('paramType',ptInteger,Integer(origParam.ParamType),Null);
   op.AddProperty('lookupDataset',ptString,origParam.LookupDataset,Null);
   op.AddProperty('searchDataset',ptString,origParam.SearchDataset,Null);
   op.AddProperty('searchParam',ptString,origParam.SearchParam,Null);
   op.AddProperty('value',ptVariant,origParam.Value,Null);
   op.AddProperty('datasets',ptStringArray,ParamStringListToVariant(origParam.Datasets),Null);
   op.AddProperty('items',ptStringArray,ParamStringListToVariant(origParam.Items),Null);
   op.AddProperty('values',ptStringArray,ParamStringListToVariant(origParam.Values),Null);
   op.AddProperty('selected',ptStringArray,ParamStringListToVariant(origParam.Selected),Null);
   undoCue.AddOperation(op);
  end;
 end;
 // Detect added params (in new list but not in original)
 for i:=0 to newParams.Count-1 do
 begin
  newParam:=newParams.Items[i];
    if origParams.FindParamByIntName(GetParamOperationName(newParam))=nil then
  begin
   op:=TChangeObjectOperation.Create(otAdd,groupId);
     op.componentName:=GetParamOperationName(newParam);
   op.componentClass:='TRPPARAM';
   op.oldItemIndex:=i;
     op.AddProperty('alias',ptString,Null,newParam.Name);
   op.AddProperty('description',ptString,Null,newParam.Description);
   op.AddProperty('hint',ptString,Null,newParam.Hint);
   op.AddProperty('validation',ptString,Null,newParam.Validation);
   op.AddProperty('errorMessage',ptString,Null,newParam.ErrorMessage);
   op.AddProperty('visible',ptBoolean,Null,newParam.Visible);
   op.AddProperty('neverVisible',ptBoolean,Null,newParam.NeverVisible);
   op.AddProperty('isReadOnly',ptBoolean,Null,newParam.IsReadOnly);
   op.AddProperty('allowNulls',ptBoolean,Null,newParam.AllowNulls);
   op.AddProperty('paramType',ptInteger,Null,Integer(newParam.ParamType));
   op.AddProperty('lookupDataset',ptString,Null,newParam.LookupDataset);
   op.AddProperty('searchDataset',ptString,Null,newParam.SearchDataset);
   op.AddProperty('searchParam',ptString,Null,newParam.SearchParam);
   op.AddProperty('value',ptVariant,Null,newParam.Value);
   op.AddProperty('datasets',ptStringArray,Null,ParamStringListToVariant(newParam.Datasets));
   op.AddProperty('items',ptStringArray,Null,ParamStringListToVariant(newParam.Items));
   op.AddProperty('values',ptStringArray,Null,ParamStringListToVariant(newParam.Values));
   op.AddProperty('selected',ptStringArray,Null,ParamStringListToVariant(newParam.Selected));
   undoCue.AddOperation(op);
  end;
 end;
 // Detect modified params
 for i:=0 to newParams.Count-1 do
 begin
  newParam:=newParams.Items[i];
    origParam:=origParams.FindParamByIntName(GetParamOperationName(newParam));
  if Assigned(origParam) then
  begin
   op:=TChangeObjectOperation.Create(otModify,groupId);
     op.componentName:=GetParamOperationName(newParam);
   op.componentClass:='TRPPARAM';
     if origParam.Name<>newParam.Name then
      op.AddProperty('alias',ptString,origParam.Name,newParam.Name);
   if origParam.Description<>newParam.Description then
    op.AddProperty('description',ptString,origParam.Description,newParam.Description);
   if origParam.Hint<>newParam.Hint then
    op.AddProperty('hint',ptString,origParam.Hint,newParam.Hint);
   if origParam.Validation<>newParam.Validation then
    op.AddProperty('validation',ptString,origParam.Validation,newParam.Validation);
   if origParam.ErrorMessage<>newParam.ErrorMessage then
    op.AddProperty('errorMessage',ptString,origParam.ErrorMessage,newParam.ErrorMessage);
   if origParam.Visible<>newParam.Visible then
    op.AddProperty('visible',ptBoolean,origParam.Visible,newParam.Visible);
   if origParam.NeverVisible<>newParam.NeverVisible then
    op.AddProperty('neverVisible',ptBoolean,origParam.NeverVisible,newParam.NeverVisible);
   if origParam.IsReadOnly<>newParam.IsReadOnly then
    op.AddProperty('isReadOnly',ptBoolean,origParam.IsReadOnly,newParam.IsReadOnly);
   if origParam.AllowNulls<>newParam.AllowNulls then
    op.AddProperty('allowNulls',ptBoolean,origParam.AllowNulls,newParam.AllowNulls);
  if Integer(origParam.ParamType)<>Integer(newParam.ParamType) then
    op.AddProperty('paramType',ptInteger,Integer(origParam.ParamType),Integer(newParam.ParamType));
   if origParam.LookupDataset<>newParam.LookupDataset then
    op.AddProperty('lookupDataset',ptString,origParam.LookupDataset,newParam.LookupDataset);
   if origParam.SearchDataset<>newParam.SearchDataset then
    op.AddProperty('searchDataset',ptString,origParam.SearchDataset,newParam.SearchDataset);
   if origParam.SearchParam<>newParam.SearchParam then
    op.AddProperty('searchParam',ptString,origParam.SearchParam,newParam.SearchParam);
   if (Integer(origParam.ParamType)<>Integer(newParam.ParamType)) or
     (not VarSameValue(origParam.Value,newParam.Value)) then
    op.AddProperty('value',ptVariant,origParam.Value,newParam.Value);
   if not SameStringLists(origParam.Datasets,newParam.Datasets) then
    op.AddProperty('datasets',ptStringArray,ParamStringListToVariant(origParam.Datasets),ParamStringListToVariant(newParam.Datasets));
   if not SameStringLists(origParam.Items,newParam.Items) then
    op.AddProperty('items',ptStringArray,ParamStringListToVariant(origParam.Items),ParamStringListToVariant(newParam.Items));
   if not SameStringLists(origParam.Values,newParam.Values) then
    op.AddProperty('values',ptStringArray,ParamStringListToVariant(origParam.Values),ParamStringListToVariant(newParam.Values));
   if not SameStringLists(origParam.Selected,newParam.Selected) then
    op.AddProperty('selected',ptStringArray,ParamStringListToVariant(origParam.Selected),ParamStringListToVariant(newParam.Selected));
   if op.properties.Count>0 then
    undoCue.AddOperation(op)
   else
    op.Free;
  end;
 end;
end;

procedure ShowParamDef(params:TRpParamList;datainfo:TRpDatainfoList;report:TRpReport;
  deferUndoUntilAccept:boolean=False);
var
 dia:TFRpParamsVCL;
begin
 params.RestoreInitialValues;
 dia:=TFRpParamsVCL.Create(Application);
 try
  dia.report:=report;
  dia.params.Assign(params);
  dia.datainfo:=datainfo;
  dia.ShowModal;
  if dia.dook then
  begin
   if not deferUndoUntilAccept then
    RecordParamUndoChanges(params,dia.params,report);
   params.assign(dia.params);
  end;
 finally
  dia.free;
 end;
end;

procedure TFRpParamsVCL.FormCreate(Sender: TObject);
begin
 //ScaleToolBar(toolbar1);
 params:=TRpParamList.Create(Self);

 BOK.Caption:=TranslateStr(93,BOK.Caption);
 BCancel.Caption:=TranslateStr(94,BCancel.Caption);

 CheckReadOnly.Caption:=TranslateStr(1379,CheckReadOnly.Caption);
 CheckNeverVisible.Caption:=TranslateStr(1381,CheckNeverVisible.Caption);
 Label1.Caption:=TranslateStr(1380,Label1.Caption);
 LHint.Caption:=TranslateStr(1382,LHint.Caption);

 ANewParam.Caption:=TranslateStr(186,ANewParam.Caption);
 ANewParam.Hint:=TranslateStr(187,ANewParam.Hint);
 ADelete.Caption:=TranslateStr(188,ADelete.Caption);
 ADelete.Hint:=TranslateStr(189,ADelete.Hint);
 AUp.Hint:=TranslateStr(190,AUp.Hint);
 ADown.Hint:=TranslateStr(191,ADown.Hint);
 ARename.Hint:=TranslateStr(192,ARename.Hint);
 LDataType.Caption:=TranslateStr(193,LDatatype.Caption);
 LValue.Caption:=TranslateStr(194,LValue.Caption);
 CheckVisible.Caption:=TranslateStr(195,CheckVisible.Caption);
 CheckVisible.Hint:=TranslateStr(952,CheckVisible.Caption);
 CheckAllowNulls.Caption:=SRpAllowNulls;
 CheckAllowNulls.Hint:=SRpAllowNullsHint;
 CheckNull.Caption:=TranslateStr(196,CheckNull.Caption);
 LDescription.Caption:=TranslateStr(197,LDescription.Caption);
 LAssign.Caption:=TranslateStr(198,LAssign.Caption);
 LLookup.Caption:=SrpLookupDataset;
 Caption:=TranslateStr(199,Caption);
 GetPossibleDataTypesDesignA(ComboDataType.Items);
 ComboDataType.Hint:=TranslateStr(944,ComboDataType.Hint);
 CheckNull.Hint:=TranslateStr(945,CheckNull.Hint);
 LSearch.Caption:=TranslateStr(946,CheckNull.Hint);
 ComboDatasets.Hint:=TranslateStr(947,ComboDatasets.Hint);
 BAddData.Hint:=TranslateStr(948,BAddData.Hint);
 BDeleteData.Hint:=TranslateStr(949,BDeleteData.Hint);
 LDatasets.Hint:=TranslateStr(950,LDatasets.Hint);
 GValues.Caption:=SRpSParamListDesc;
 GSearch.Caption:=SRpValueSearch;
 LSearchDataset.Caption:=SrpSearchDataset;
 LValidation.Caption:=TranslateStr(1401,LValidation.Caption);
 EValidation.Hint:=TranslateStr(1402,EValidation.Hint);
 LErrorMessage.Caption:=TranslateStr(1403,LErrorMessage.Caption);
 EErrorMessage.Hint:=TranslateStr(1404,EErrorMessage.Hint);
 EDescription.Hint:=TranslateStr(1418,EDescription.Hint);
 EHint.Hint:=TranslateStr(1419,EDescription.Hint);
end;

procedure TFRpParamsVCL.BOKClick(Sender: TObject);
begin
 if EValue.Visible then
 begin
  if GProperties.Visible then
   EValueExit(Self);
 end;
 dook:=true;
 close;
end;

procedure TFRpParamsVCL.FormShow(Sender: TObject);
var
 i:integer;
begin
 if Assigned(datainfo) then
 begin
  ComboLookup.Clear;
  ComboLookup.Items.Add('');
  ComboSearchDataset.Clear;
  ComboSearchDataset.items.Add('');
  for i:=0 to datainfo.count-1 do
  begin
   ComboDatasets.Items.Add(datainfo.items[i].Alias);
   ComboLookup.Items.Add(datainfo.items[i].Alias);
   ComboSearchDataset.Items.Add(datainfo.items[i].Alias);
  end;
  ComboSearchParam.Clear;
  ComboSearchParam.Items.Add('');
  for i:=0 to params.Count-1 do
  begin
   ComboSearchParam.Items.Add(params.Items[i].Name);
  end;


  if ComboDatasets.Items.Count>0 then
   ComboDatasets.ItemIndex:=0;
 end;
 FillParamList;
end;

procedure TFRpParamsVCL.FillParamList;
var
 i:integer;
begin
 LParams.Clear;
 for i:=0 to params.Count-1 do
 begin
  LParams.Items.Add(params.items[i].Name);
 end;
 LParamsClick(Self);
end;


procedure TFRpParamsVCL.LParamsClick(Sender: TObject);
var
 param:TRpParam;
begin
 if (LParams.Items.Count<1) then
 begin
  GProperties.Visible:=false;
  exit;
 end;
 updating:=true;
 try
  if LParams.Itemindex<0 then
   LParams.ItemIndex:=0;
  GProperties.Visible:=True;
  param:=params.ParamByName(LParams.Items.Strings[LParams.Itemindex]);
  CheckVisible.Checked:=param.Visible;
  CheckNeverVisible.Checked:=param.NeverVisible;
  CheckReadOnly.Checked:=param.IsReadOnly;
  CheckAllowNulls.Checked:=param.AllowNulls;
   CheckNull.Checked:=param.Value=Null;
  EDescription.Text:=param.Description;
  EValidation.Text:=param.Validation;
  EErrorMessage.Text:=param.ErrorMessage;
  EHint.Text:=param.Hint;
  ESearch.Text:=param.Search;
  MValues.Lines.Assign(param.Values);
  MItems.Lines.Assign(param.Items);
  LDatasets.Clear;
  LDatasets.items.Assign(param.Datasets);
  if LDatasets.items.count>0 then
   LDatasets.ItemIndex:=0;
  ComboLookup.ItemIndex:=ComboLookup.Items.IndexOf(param.LookupDataset);
  ComboSearchDataset.ItemIndex:=ComboSearchDataset.Items.IndexOf(param.SearchDataset);
  ComboSearchParam.ItemIndex:=ComboSearchParam.Items.IndexOf(param.SearchParam);

  ComboDataType.ItemIndex:=
   ComboDataType.Items.IndexOf(ParamTypeToString(param.ParamType));
  EValue.EditType:=teGeneral;
  EValue.Text:='';
  if (param.Value<>Null) then
  begin
   case param.ParamType of
    rpParamString,rpParamExpreA,rpParamExpreB,rpParamSubst,rpParamSubstE,rpparamInitialExpression,rpParamUnknown:
     EValue.Text:=param.AsString;
    rpParamSubstList,rpParamList:
     EValue.Text:=param.Value;
    rpParamInteger:
     begin
      EValue.Text:=IntToStr(param.Value);
      EValue.EditType:=teInteger;
     end;
    rpParamDouble:
     begin
      EValue.Text:=FloatToStr(param.Value);
      EValue.EditType:=teFloat;
     end;
    rpParamCurrency:
     begin
      EValue.Text:=CurrToStr(param.Value);
      EValue.EditType:=teCurrency;
     end;
    rpParamDate:
     EValue.Text:=DateToStr(param.Value);
    rpParamTime:
     EValue.Text:=TimeToStr(param.Value);
    rpParamDateTime:
     EValue.Text:=DateTimeToStr(param.Value);
    rpParamBool:
     EValue.Text:=BoolToStr(param.Value,true);
   end;
  end;
 finally
  updating:=false;
 end;
 EDescriptionChange(CheckNull);
end;

procedure TFRpParamsVCL.EValueExit(Sender: TObject);
var
 param:TRpParam;
begin
 // Validate the input value
 if (LParams.Itemindex<0) then
  exit;
 param:=params.ParamByName(LParams.items.strings[LParams.ItemIndex]);
 UpdateValue(param);
end;

function TFRpParamsVCL.IsDotNet:boolean;
begin
 Result:=false;
 if report.databaseinfo.Count>0 then
 begin
  if (report.databaseinfo[0].Driver in [rpdatadriver,rpdotnet2driver]) then
   Result:=true;
 end;
end;

procedure TFRpParamsVCL.UpdateValue(param:TRpParam);
var
 i,index:integer;
begin
 ESearch.Visible:=param.ParamType in [rpParamSubst,rpParamSubstE,rpParamSubstList,rpParamMultiple];
 GValues.Visible:=param.ParamType in [rpParamList,rpParamSubstList,rpParamMultiple];
 GSearch.Visible:=Not GValues.Visible;
 LSearch.Visible:=ESearch.Visible;
 CheckNull.Visible:=param.ParamType<>rpParamMultiple;
 CheckAllowNulls.Visible:=CheckNull.Visible;
 EValue.Visible:=CheckNull.Visible;
 ECheckList.Visible:=Not CheckNull.Visible;
 if param.ParamType=rpParamMultiple then
 begin
  ECheckList.Items.Assign(param.Items);
  for i:=0 to ECheckList.Items.Count-1 do
  begin
   ECheckList.Checked[i]:=False;
  end;
  if (IsDotnet) then
  begin
   for i:=0 to param.Selected.Count-1 do
   begin
    index:=param.Values.IndexOf(param.Selected.Strings[i]);
    if index>=0 then
     ECheckList.Checked[index]:=True;
   end;
  end
  else
  begin
   for i:=0 to param.Selected.Count-1 do
   begin
    index:=StrToInt(param.Selected.Strings[i]);
    if param.Items.Count>index then
     ECheckList.Checked[index]:=True;
   end;
  end;
 end
 else
 begin
  if (EValue.Text='') then
  begin
   case param.ParamType of
    rpParamString,rpParamExpreA,rpParamExpreB,rpParamSubst,rpParamSubstE,rpParamList,rpParamSubstList,rpParamInitialExpression,rpParamUnknown:
     EValue.Text:='';
    rpParamInteger:
     EValue.Text:=IntToStr(0);
    rpParamDouble:
     EValue.Text:=FloatToStr(0.0);
    rpParamCurrency:
     EValue.Text:=CurrToStr(0.0);
    rpParamDate:
     EValue.Text:=DateToStr(Date);
    rpParamTime:
     EValue.Text:=TimeToStr(Time);
    rpParamDateTime:
     EValue.Text:=DateTimeToStr(Now);
    rpParamBool:
     EValue.Text:=BoolToStr(False);
   end;
  end;
  if CheckNull.Checked then
  begin
   param.Value:=null;
   EValue.Visible:=false;
  end
  else
  begin
    EValue.Visible:=true;
    case param.ParamType of
     rpParamString,rpParamExpreA,rpParamExpreB,rpParamSubst,rpParamSubstE,rpParamList,rpParamSubstList,rpParamInitialExpression,rpParamUnknown:
      param.Value:=EValue.Text;
     rpParamInteger:
      param.Value:=StrToInt(EValue.Text);
     rpParamDouble:
      param.Value:=StrToFloat(EValue.Text);
     rpParamCurrency:
      param.Value:=StrToCurr(EValue.Text);
     rpParamDate:
      param.Value:=StrToDate(EValue.Text);
     rpParamTime:
      param.Value:=StrToTime(EValue.Text);
     rpParamDateTime:
      param.Value:=StrToDateTime(EValue.Text);
     rpParamBool:
      param.Value:=StrToBool(EValue.Text);
    end;
  end;
 end;
end;

procedure TFRpParamsVCL.EDescriptionChange(Sender: TObject);
var
 param:TRpParam;
 i:integer;
begin
 if updating then
  exit;
 // Validate the input value
 if (LParams.Itemindex<0) then
  exit;
 param:=params.ParamByName(LParams.items.strings[LParams.ItemIndex]);
 if Sender=EDescription then
  param.Description:=EDescription.Text
 else
 if Sender=EErrorMessage then
  param.ErrorMessage:=EErrorMessage.Text
 else
 if Sender=EValidation then
  param.Validation:=EValidation.Text
 else
 if Sender=EHint then
  param.Hint:=EHint.Text
 else
 if Sender=ESearch then
  param.Search:=ESearch.Text
 else
 if Sender=MItems then
 begin
  param.Items:=MItems.Lines;
  UpdateValue(param);
 end
 else
 if Sender=MValues then
  param.Values:=MValues.Lines
 else
  if (Sender=CheckVisible) then
   param.Visible:=CheckVisible.Checked
  else
  if (Sender=CheckNeverVisible) then
   param.NeverVisible:=CheckneverVisible.Checked
  else
  if (Sender=CheckReadOnly) then
   param.IsReadOnly:=CheckReadOnly.Checked
  else
  if (Sender=CheckAllowNulls) then
   param.AllowNulls:=CheckAllowNulls.Checked
  else
   if (Sender=CheckNull) then
   begin
    UpdateValue(param);
    if CheckNull.Checked then
     param.Value:=null;
   end
   else
    if (Sender=ComboDataType) then
    begin
     if (param.ParamType=StringToParamType(COmboDataType.Text)) then
      exit;
     param.ParamType:=StringToParamType(COmboDataType.Text);
     EValue.Text:='';
     UpdateValue(param);
    end
   else
    if (Sender=ECheckList) then
    begin
     param.Selected.Clear;
     for i:=0 to ECheckList.Items.Count-1 do
     begin
      if ECheckList.Checked[i] then
      begin
       if IsDotNet then
       begin
        param.Selected.Add(param.Values[i]);
       end
       else
        param.Selected.Add(IntToStr(i));
      end;
     end;
    end
   else
    if (Sender=ComboLookup) then
    begin
     param.LookupDataset:=ComboLookup.Text;
    end
   else
    if (Sender=ComboSearchDataset) then
    begin
     param.SearchDataset:=ComboSearchDataset.Text;
    end
   else
    if (Sender=ComboSearchParam) then
    begin
     param.SearchParam:=ComboSearchParam.Text;
    end;

end;

procedure TFRpParamsVCL.BAdddataClick(Sender: TObject);
var
 index:integer;
 param:TRpParam;
begin
 if ComboDatasets.ItemIndex<0 then
  exit;
 param:=params.ParamByName(LParams.items.strings[LParams.ItemIndex]);
 index:=LDatasets.Items.IndexOf(ComboDatasets.Text);
 if index>=0 then
  exit;
 LDatasets.items.Add(COmboDatasets.Text);
 if LDatasets.itemindex<0 then
  LDatasets.ItemIndex:=0;
 param.Datasets.Assign(LDatasets.Items);
end;

procedure TFRpParamsVCL.BDeleteDataClick(Sender: TObject);
var
 param:TRpParam;
begin
 if LDatasets.itemindex<0 then
  exit;
 param:=params.ParamByName(LParams.items.strings[LParams.ItemIndex]);
 LDatasets.Items.Delete(LDatasets.ItemIndex);
 if LDatasets.items.count>0 then
  LDatasets.ItemIndex:=0;
 param.Datasets.Assign(LDatasets.Items);
end;

procedure TFRpParamsVCL.BAddClick(Sender: TObject);
var
 paramname:string;
 aparam:TRpParam;
begin
 paramname:=RpInputBox(SRpNewParam,SRpParamName,'');
 paramname:=AnsiUpperCase(Trim(paramname));
 if Length(paramname)<1 then
  exit;

 // Adds a param
 aparam:=params.Add(paramname);
 if Assigned(report) then
  EnsureParamName(TRpBaseReport(report), aparam);
 aparam.AllowNulls:=false;
 aparam.Value:='';

 FillParamList;
 LParams.ItemIndex:=LParams.Items.Count-1;
 LParamsClick(Self);
end;

procedure TFRpParamsVCL.BDeleteClick(Sender: TObject);
var
 index:integer;
begin
 if LParams.itemindex<0 then
  exit;
 index:=params.IndexOf(LParams.Items.strings[LParams.Itemindex]);
 params.Delete(index);
 FillParamList;
end;

procedure TFRpParamsVCL.BRenameClick(Sender: TObject);
var
 paramname:string;
 index:integer;
 param:TRpParam;
begin
 if LParams.itemindex<0 then
  exit;
 param:=params.ParamByName(LParams.Items.strings[LParams.Itemindex]);
 paramname:=RpInputBox(SRpRenameParam,SRpParamName,param.Name);
 paramname:=AnsiUpperCase(Trim(paramname));
 if Length(paramname)=0 then
  exit;

 index:=params.IndexOf(paramname);
 if ( (index>=0) or (Length(paramname)=0) ) then
   Raise Exception.Create(SRpParamNameExists);
 param.Name:=paramname;
 LParams.Items.strings[LParams.Itemindex]:=paramname;
end;

procedure TFRpParamsVCL.BUpClick(Sender: TObject);
var
 index:integer;
 reftemp:TRpParamList;
 aname:string;
begin
 if LParams.ItemIndex<0 then
  exit;
 if LParams.Items.count<2 then
  exit;
 index:=LParams.itemindex;
 if index<1 then
  exit;
 aname:=LParams.items.Strings[index];
 reftemp:=TRpParamList.create(Self);
 try
  reftemp.assign(params);
  // intercanviem
  reftemp.Items[index-1].assign(params.items[index]);
  reftemp.items[index].Assign(params.items[index-1]);
  params.Assign(reftemp);
 finally
  reftemp.free;
 end;
 FillParamList;
 index:=LParams.Items.IndexOf(aname);
 if index>=0 then
 begin
  LParams.itemindex:=index;
  LParamsclick(self);
 end;
end;


procedure TFRpParamsVCL.ComboSearchParamDropDown(Sender: TObject);
var
 oldvalue:string;
begin
 oldvalue:=ComboSearchParam.Text;
 ComboSearchParam.Items.Assign(lparams.Items);
 ComboSearchParam.ItemIndex := ComboSearchParam.Items.IndexOf(oldvalue);
end;

procedure TFRpParamsVCL.BDownClick(Sender: TObject);
var
 index:integer;
 reftemp:TRpParamList;
 aname:string;
begin
 if LParams.ItemIndex<0 then
  exit;
 if LParams.Items.count<2 then
  exit;
 index:=LParams.itemindex;
 if (index>=LParams.items.count-1) then
  exit;
 aname:=LParams.items.Strings[index];
 reftemp:=TRpParamList.create(Self);
 try
  reftemp.assign(params);
  // interchange
  reftemp.Items[index+1].assign(params.items[index]);
  reftemp.items[index].Assign(params.items[index+1]);
  params.Assign(reftemp);
 finally
  reftemp.free;
 end;
 FillParamList;
 index:=LParams.Items.IndexOf(aname);
 if index>=0 then
 begin
  LParams.itemindex:=index;
  LParamsclick(self);
 end;
end;

end.

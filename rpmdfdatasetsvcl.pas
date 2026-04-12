{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpmdfdatasetsvcl                                }
{                                                       }
{       Datasets definition frame                       }
{                                                       }
{       Copyright (c) 1994-2013 Toni Martir             }
{       toni@reportman.es                                   }
{                                                       }
{       This file is under the MPL license              }
{       If you enhace this file you must provide        }
{       source code                                     }
{                                                       }
{                                                       }
{*******************************************************}

unit rpmdfdatasetsvcl;

interface

{$I rpconf.inc}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, ToolWin, ImgList,rpmdconsts,rpgraphutilsvcl,
  rpdatahttp,
{$IFDEF USEBDE}
  DBTables,
{$ENDIF}

  rptypes,rpdatainfo,rpreport,rpfparamsvcl,rpmdfsampledatavcl, ActnList,
  rpparams, System.Actions, System.ImageList,
  Vcl.VirtualImageList, Vcl.BaseImageCollection, Vcl.ImageCollection,
  rpfrmmonacoeditorvcl, rpfrmchatvcl, rpauthmanager;

type
  TRpDatasetChatStreamContext = class(TObject)
  public
    RequestVersion: Integer;
  end;

  TFRpDatasetsVCL = class(TFrame)
    ImageList1: TImageList;
    PTop: TPanel;
    ToolBar1: TToolBar;
    OpenDialog1: TOpenDialog;
    ActionList1: TActionList;
    ANew: TAction;
    ADelete: TAction;
    ARename: TAction;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    ToolButton6: TToolButton;
    BParams: TButton;
    PTop1: TPanel;
    LDatasets: TListBox;
    PanelBasic: TPanel;
    LMasterDataset: TLabel;
    LConnection: TLabel;
    ComboDataSource: TComboBox;
    ComboConnection: TComboBox;
    BShowData: TButton;
    Splitter1: TSplitter;
    PBottom: TPanel;
    PControl: TPageControl;
    TabSQL: TTabSheet;
    MSQL: TMemo;
    TabBDEType: TTabSheet;
    RBDEType: TRadioGroup;
    Panel4: TPanel;
    PBDEFilter: TPanel;
    MBDEFilter: TMemo;
    TabBDETable: TTabSheet;
    LBDEIndexFields: TLabel;
    LIndexName: TLabel;
    LTable: TLabel;
    LMasterFields: TLabel;
    LNote: TLabel;
    LFirstRange: TLabel;
    LLastRange: TLabel;
    LRange: TLabel;
    EBDEIndexFields: TComboBox;
    EBDEIndexName: TComboBox;
    EBDETable: TComboBox;
    EBDEMasterFields: TEdit;
    EBDEFirstRange: TMemo;
    EBDELastRange: TMemo;
    TabMyBase: TTabSheet;
    LIndexFields: TLabel;
    LMyBase: TLabel;
    LFields: TLabel;
    EMyBase: TEdit;
    EIndexFields: TEdit;
    BMyBase: TButton;
    BSearchFieldsFile: TButton;
    GUnions: TGroupBox;
    LabelUnions: TLabel;
    ComboUnions: TComboBox;
    CheckGroupUnion: TCheckBox;
    BAddUnions: TButton;
    BDelUnions: TButton;
    LUnions: TListBox;
    EMybasedefs: TEdit;
    BModify: TButton;
    PMonacoHost: TPanel;
    PChatHost: TPanel;
    Splitter2: TSplitter;
    EMasterFields: TEdit;
    LMasterfi: TLabel;
    CheckOpen: TCheckBox;
    CheckParallelUnion: TCheckBox;
    ImageCollection1: TImageCollection;
    VirtualImageList1: TVirtualImageList;
    AUp: TAction;
    ADown: TAction;
    ToolButton7: TToolButton;
    ToolButton8: TToolButton;
    procedure BParamsClick(Sender: TObject);
    procedure LDatasetsClick(Sender: TObject);
    procedure MSQLChange(Sender: TObject);
    procedure BMyBaseClick(Sender: TObject);
    procedure BShowDataClick(Sender: TObject);
    procedure ANewExecute(Sender: TObject);
    procedure ADeleteExecute(Sender: TObject);
    procedure ARenameExecute(Sender: TObject);
    procedure BAddUnionsClick(Sender: TObject);
    procedure BDelUnionsClick(Sender: TObject);
    procedure EBDETableDropDown(Sender: TObject);
    procedure EBDEIndexNameDropDown(Sender: TObject);
    procedure EBDEIndexFieldsDropDown(Sender: TObject);
    procedure BModifyClick(Sender: TObject);
    procedure LRangeClick(Sender: TObject);
    procedure FrameResize(Sender: TObject);
    procedure AUpExecute(Sender: TObject);
    procedure ADownExecute(Sender: TObject);
    procedure MonacoAuditSql(Sender: TObject);
  private
    { Private declarations }
    FChat: TFRpChatFrame;
    FChatRequestVersion: Integer;
    FMonaco: TFRpMonacoEditorVCL;
    FSyncingSchemaContext: Boolean;
    Report:TRpReport;
    procedure ApplyActiveDataInfoContext(ASyncSqlFromDataInfo: Boolean = True;
      const ASchemaApiKeyOverride: string = '');
    procedure SyncActiveSchemaContext(AHubDatabaseId, AHubSchemaId: Int64;
      const ASchemaApiKey: string = '');
    procedure ChatApplySuggestion(Sender: TObject; const AExpression: string);
    procedure ChatSchemaChange(Sender: TObject);
    procedure ChatSendPrompt(Sender: TObject; const APrompt,
      AExpression: string);
    procedure ChatStopRequest(Sender: TObject);
    function ChatTranslateCancelRequested(Sender: TObject): Boolean;
    procedure ChatTranslateProgress(Sender: TObject; const AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
    procedure SetDataInfo(Value:TRpDataInfoList);
    procedure SetDatabaseInfo(Value:TRpDatabaseInfoList);
    procedure SetParams(Value:TRpParamList);
    function GetParams:TRpParamList;
    function GetDatabaseInfo:TRpDatabaseInfoList;
    function GetDataInfo:TRpDataInfoList;
//    function FindDatabaseInfoItem:TRpDatabaseInfoItem;
    function FindDataInfoItem:TRpDataInfoItem;
    function GetChatPrefillPercent(const AStage, AChunkType: string): Integer;
    function GetUserLanguageCode: string;
    procedure MonacoInferenceLog(Sender: TObject; const ASource,
      AText: string; AAppendLineBreak: Boolean);
    procedure MonacoAuditProgress(Sender: TObject; const AStage,
      AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
    procedure MonacoSchemaChange(Sender: TObject);
    procedure  Removedependences(oldalias:string);
  public
    { Public declarations }
    constructor Create(AOwner:TComponent);override;
    destructor Destroy; override;
    procedure FillDatasets;
    property Datainfo:TRpDataInfoList read GetDatainfo
     write SetDataInfo;
    property Databaseinfo:TRpDatabaseInfoList read GetDatabaseinfo
     write SetDatabaseInfo;
    property Params:TRpParamList read GetParams
     write SetParams;
  end;


implementation

uses System.JSON, rpmdfdatatextvcl, rpxmlstream, rpbasereport;

{$R *.DFM}

destructor TFRpDatasetsVCL.Destroy;
begin
  inherited Destroy;
end;


function TFRpDatasetsVCL.GetParams:TRpParamList;
begin
 result:=report.params;
end;

procedure TFRpDatasetsVCL.SetParams(Value:TRpParamList);
begin
 report.params.assign(value);
end;

constructor TFRpDatasetsVCL.Create(AOwner:TComponent);
begin
 inherited Create(AOwner);

 //ScaleToolBar(toolbar1);
  //Align := AlClient;
 Report:=TRpReport.Create(Self);
 report.CreateNew;
 Report.InitEvaluator;
 BParams.Caption:=TranslateStr(152,BParams.Caption);
 LConnection.Caption:=TranslateStr(154,LConnection.Caption);
 LMasterDataset.Caption:=TranslateStr(155,LMasterDataset.Caption);
 BShowData.Caption:=TranslateStr(156,BShowData.Caption);
 TAbBDEType.Caption:=TranslateStr(157,TabBDEType.Caption);
 TAbBDETable.Caption:=TranslateStr(158,TabBDETable.Caption);
 RBDEType.Items.Strings[0]:=TranslateStr(159,RBDEType.Items.Strings[0]);
 RBDEType.Items.Strings[1]:=TranslateStr(160,RBDEType.Items.Strings[1]);
 PBDEFilter.Caption:=TranslateStr(161,PBDEFilter.Caption);
 LTable.Caption:=TranslateStr(162,LTable.Caption);
 LIndexName.Caption:=TranslateStr(163,LIndexName.Caption);
 LBDEIndexFields.Caption:=TranslateStr(164,LBDEIndexFields.Caption);
 LMasterFields.Caption:=TranslateStr(165,LMasterFi.Caption);
 LMasterFi.Caption:=TranslateStr(165,LMasterFields.Caption);
 LNote.Caption:=TranslateStr(166,LNote.Caption);
 LMyBase.Caption:=TranslateStr(167,LMyBase.Caption);
 LIndexFields.Caption:=TranslateStr(164,LIndexFields.Caption);
 BMyBase.Caption:=TranslateStr(168,BMyBase.Caption);
 BSearchFieldsFile.Caption:=TranslateStr(168,BSearchFieldsFile.Caption);
 Caption:=TranslateStr(178,Caption);
 LFirstRange.Caption:=TranslateStr(831,LFirstRange.Caption);
 LLastRange.Caption:=TranslateStr(832,LLastRange.Caption);
 LRange.Caption:=TranslateStr(833,LRange.Caption);
 GUnions.Caption:=TranslateStr(1082,GUnions.Caption);
 LabelUnions.Caption:=TranslateStr(1083,LabelUnions.Caption);
 CheckGroupUnion.Caption:=TranslateStr(1084,CheckGroupUnion.Caption);
 CheckParallelUnion.Caption:=TranslateStr(1440,CheckParallelUnion.Caption);
 CheckParallelUnion.Hint:=TranslateStr(1441,CheckParallelUnion.Hint);
 LFields.Caption:=TranslateStr(1085,LFields.Caption);
 BModify.Caption:=TranslateStr(1086,BModify.Caption);
 CheckOpen.Caption:=SRpOpenOnStart;

 ANew.Caption:=TranslateStr(539,ANew.Caption);
 ANew.Hint:=Anew.Caption;
 ARename.Caption:=TranslateStr(540,ARename.Caption);
 ARename.Hint:=ARename.Caption;
 ADelete.Caption:=TranslateStr(150,ADelete.Caption);
 ADelete.Hint:=ARename.Caption;
 BParams.Hint:=TranslateStr(152,BParams.Hint);
 AUp.Hint:=TranslateStr(190,AUp.Hint);
 ADown.Hint:=TranslateStr(191,ADown.Hint);


 PBottom.Height:=250;
  MSQL.Visible := False;

  FMonaco := TFRpMonacoEditorVCL.Create(Self);
  FMonaco.Parent := PMonacoHost;
  FMonaco.Align := alClient;
  FMonaco.OnContentChanged := MSQLChange;
  FMonaco.OnSchemaChanged := MonacoSchemaChange;
  FMonaco.OnInferenceLog := MonacoInferenceLog;
  FMonaco.OnAuditSql := MonacoAuditSql;

  FChat := TFRpChatFrame.Create(Self);
  FChat.Parent := PChatHost;
  FChat.Align := alClient;
  FChat.Initialize('', 'Describe the SQL you want for the active dataset and apply the generated SQL when it looks correct.');
  FChat.OnApplySuggestion := ChatApplySuggestion;
  FChat.OnSchemaChanged := ChatSchemaChange;
  FChat.OnSendPrompt := ChatSendPrompt;
  FChat.OnStopRequest := ChatStopRequest;
  FChat.StartOnlineInitialization;
end;

procedure TFRpDatasetsVCL.SetDatabaseInfo(Value:TRpDatabaseInfoList);
begin
 ComboConnection.Width:=PanelBasic.Width-ComboConnection.Left-10;
 ComboDataSource.Width:=PanelBasic.Width-ComboDataSource.Left-10;
 ComboConnection.Anchors:=[akLeft,akTop,akRight];
 ComboDataSource.Anchors:=[akLeft,akTop,akRight];

 report.DatabaseInfo.Assign(Value);
 FillDatasets;

end;

procedure TFRpDatasetsVCL.ApplyActiveDataInfoContext(
  ASyncSqlFromDataInfo: Boolean; const ASchemaApiKeyOverride: string);
var
  LDataInfo: TRpDataInfoItem;
  LDatabaseInfo: TRpDatabaseInfoItem;
  LParams: TStringList;
  LHubDatabaseId: Int64;
  LSchemaApiKey: string;
begin
  LDataInfo := FindDataInfoItem;
  if LDataInfo = nil then
    Exit;

  LHubDatabaseId := 0;
  LSchemaApiKey := '';
  LDatabaseInfo := Report.DatabaseInfo.ItemByName(LDataInfo.DatabaseAlias);
  if LDatabaseInfo <> nil then
  begin
    LParams := TStringList.Create;
    try
      LDatabaseInfo.UpdateConAdmin;
      LDatabaseInfo.ConAdmin.GetConnectionParams(LDatabaseInfo.Alias, LParams);
      LHubDatabaseId := StrToInt64Def(LParams.Values['HubDatabaseId'], 0);
      LSchemaApiKey := Trim(LParams.Values['ApiKey']);
    finally
      LParams.Free;
    end;
  end;

  if ASchemaApiKeyOverride <> '' then
    LSchemaApiKey := ASchemaApiKeyOverride;

  FMonaco.SetHubContext(LHubDatabaseId, LDataInfo.HubSchemaId);
  if ASyncSqlFromDataInfo then
  begin
    FMonaco.SQL := WideStringToDOS(LDataInfo.SQL);
    FMonaco.AuditText := WideStringToDOS(LDataInfo.SQLExplanation);
  end;

  if FChat <> nil then
  begin
    FChat.SetCurrentExpression(WideStringToDOS(LDataInfo.SQL));
    FChat.SetHubContext(LHubDatabaseId, LDataInfo.HubSchemaId, LSchemaApiKey);
  end;
end;

procedure TFRpDatasetsVCL.SetDataInfo(Value:TRpDataInfoList);
begin
 report.DataInfo.Assign(Value);
end;

procedure TFRpDatasetsVCL.FillDatasets;
var
 i:integer;
begin
 LDatasets.Clear;
 for i:=0 to datainfo.Count-1 do
 begin
  LDatasets.Items.Add(datainfo.Items[i].Alias)
 end;
 if LDatasets.items.Count>0 then
  LDatasets.ItemIndex:=0;
 ComboConnection.Clear;
 for i:=0 to databaseinfo.Count-1 do
 begin
  ComboConnection.Items.Add(databaseinfo.items[i].Alias);
 end;
 ComboConnection.Items.Add(' ');
 LDatasetsClick(Self);
end;

function TFRpDatasetsVCL.GetDatabaseInfo:TRpDatabaseInfoList;
begin
 Result:=Report.DatabaseInfo;
end;

function TFRpDatasetsVCL.GetDataInfo:TRpDataInfoList;
begin
 Result:=Report.DataInfo;
end;

procedure TFRpDatasetsVCL.BParamsClick(Sender: TObject);
begin
 ShowParamDef(report.params,report.datainfo,report,True);
end;

procedure TFRpDatasetsVCL.LDatasetsClick(Sender: TObject);
var
  dinfo: TRpDataInfoItem;
  dbinfo: TRpDatabaseInfoItem;
  LParams: TStringList;
  index: Integer;
begin
  // Fils the info of the current dataset
  dinfo := FindDataInfoItem;
  if dinfo = nil then
  begin
    PControl.Visible := False;
    PanelBasic.Visible := False;
    Exit;
  end;
  CheckOpen.Checked := dinfo.OpenOnStart;
  PControl.Visible := True;
  PanelBasic.Visible := True;
  ApplyActiveDataInfoContext(True);

  EMyBase.Text := dinfo.MyBaseFilename;
  EMyBaseDefs.Text := dinfo.MyBaseFields;
  EIndexFields.Text := dinfo.MyBaseIndexFields;
  LUnions.Items.Assign(dinfo.DataUnions);
  CheckGroupUnion.Checked := dinfo.GroupUnion;
  CheckParallelUnion.Checked := dinfo.ParallelUnion;
  EBDEIndexFields.Text := dinfo.BDEIndexFields;
  MBDEFilter.Text := dinfo.BDEFilter;
  EBDEIndexName.Text := dinfo.BDEIndexName;
  EBDEFirstRange.Text := dinfo.BDEFirstRange;
  EBDELastRange.Text := dinfo.BDELastRange;
  EBDETable.Text := dinfo.BDETable;
  EBDEMasterFields.Text := dinfo.BDEMasterFields;
  EMasterFields.Text := dinfo.MyBaseMasterFields;
  RBDEType.ItemIndex := Integer(dinfo.BDEType);
  index := ComboConnection.Items.IndexOf(dinfo.DatabaseAlias);
  if index < 0 then
    dinfo.DatabaseAlias := '';
  ComboConnection.ItemIndex := index;

  ComboDataSource.Items.Assign(LDatasets.Items);
  index := ComboDataSource.Items.IndexOf(dinfo.alias);
  if index >= 0 then
    ComboDataSource.Items.Delete(index);

  index := ComboDataSource.Items.IndexOf(dinfo.DataSource);
  if index < 0 then
  begin
    dinfo.DataSource := '';
  end;
  ComboDataSource.Items.Insert(0, ' ');
  Inc(index);
  ComboDataSource.ItemIndex := index;
  ComboUnions.Items.Assign(LDatasets.Items);
  ComboUnions.Items.Delete(LDatasets.ItemIndex);
  if ComboUnions.Items.Count < 1 then
    ComboUnions.ItemIndex := -1
  else
    ComboUnions.ItemIndex := 0;
  MSQLChange(ComboConnection);
end;

procedure TFRpDatasetsVCL.LRangeClick(Sender: TObject);
begin

end;

{function TFRpDatasetsVCL.FindDatabaseInfoItem:TRpDatabaseInfoItem;
var
 index:integer;
 dinfo:TRpDataInfoItem;
begin
 Result:=nil;
 dinfo:=FindDataInfoItem;
 if not assigned(dinfo) then
  exit;
 index:=report.databaseinfo.IndexOf(dinfo.DatabaseAlias);
 if index>=0 then
  Result:=databaseinfo.items[index];
end;
}

function TFRpDatasetsVCL.FindDataInfoItem:TRpDataInfoItem;
var
 index:integer;
begin
 Result:=nil;
 if LDatasets.ItemIndex<0 then
  exit;
 index:=datainfo.IndexOf(LDatasets.Items.Strings[LDatasets.itemindex]);
 if index>=0 then
  Result:=datainfo.items[index];
end;



procedure TFRpDatasetsVCL.FrameResize(Sender: TObject);
begin
 toolbar1.ButtonWidth:=ScaleDpi(26);
 toolbar1.ButtonHeight:=ScaleDpi(26);
end;

procedure TFRpDatasetsVCL.MSQLChange(Sender: TObject);
var
 dinfo:TRpDatainfoItem;
 index:integer;
 LPreviousDatabaseAlias: string;
begin
 // Fils the info of the current dataset
 dinfo:=FindDataInfoItem;
 if dinfo=nil then
 begin
  TabSQL.TabVisible:=false;
  TabBDETable.TabVisible:=false;
  TabMyBase.TabVisible:=false;
  TabBDEType.TabVisible:=false;
  exit;
 end;
 if Sender=BAddUnions then
  dinfo.DataUnions:=LUnions.Items
 else
 if Sender=CheckGroupUnion then
  dinfo.GroupUnion:=CheckGroupUnion.Checked
 else
 if Sender=CheckParallelUnion then
  dinfo.ParallelUnion:=CheckParallelUnion.Checked
 else
 if Sender=FMonaco then
 begin
  dinfo.SQL:=FMonaco.SQL;
  if FChat <> nil then
    FChat.SetCurrentExpression(FMonaco.SQL);
  FMonaco.AuditText := WideStringToDOS(dinfo.SQLExplanation);
 end
 else
 if Sender=ComboConnection then
 begin
  LPreviousDatabaseAlias:=dinfo.DatabaseAlias;
  dinfo.DatabaseAlias:=COmboConnection.Text;
  if not SameText(LPreviousDatabaseAlias,dinfo.DatabaseAlias) then
   dinfo.HubSchemaId:=0;
  // Finds the driver
  index:=databaseinfo.IndexOf(dinfo.DatabaseAlias);
  if index<0 then
  begin
   TabSQL.TabVisible:=false;
   TabBDETable.TabVisible:=false;
   TabMyBase.TabVisible:=false;
   TabBDEType.TabVisible:=false;
   FMonaco.HubDatabaseId:=0;
   FMonaco.HubSchemaId:=0;
  if FChat <> nil then
    FChat.SetHubContext(0, 0);
   exit;
  end;
  ApplyActiveDataInfoContext(False);
  if databaseinfo.items[index].Driver=rpdatamybase then
  begin
   TabSQL.TabVisible:=false;
   TabBDETable.TabVisible:=false;
   TabMyBase.TabVisible:=True;
   TabBDEType.TabVisible:=false;
   PControl.ActivePage:=TabMyBase;
  end
  else
  begin
   if databaseinfo.items[index].Driver=rpdatabde then
   begin
    TabBDEType.TabVisible:=True;
    if (dinfo.BDEType=rpdtable) then
    begin
     TabSQL.TabVisible:=False;
     TabBDETable.TabVisible:=True;
     TabMyBase.TabVisible:=False;
     PControl.ActivePage:=TabBDETable;
    end
    else
    begin
     TabSQL.TabVisible:=True;
     TabBDETable.TabVisible:=False;
     TabMyBase.TabVisible:=False;
     PControl.ActivePage:=TabSQL;
    end;
   end
   else
   begin
    TabSQL.TabVisible:=True;
    TabBDETable.TabVisible:=false;
    TabMyBase.TabVisible:=False;
    TabBDEType.TabVisible:=false;
   end;
  end;
 end
 else
 if Sender=ComboDataSource then
 begin
  dinfo.DataSource:=ComboDataSource.Text;
 end
 else
 if Sender=EMyBase then
 begin
  dinfo.MyBaseFilename:=EMyBase.Text;
 end
 else
 if Sender=EMyBaseDefs then
 begin
  dinfo.MyBaseFields:=EMyBaseDefs.Text;
 end
 else
 if Sender=EIndexFields then
 begin
  dinfo.MyBaseIndexFields:=EIndexFields.Text;
 end
 else
 if Sender=RBDEType then
 begin
  dinfo.BDEType:=TRpDatasetType(RBDEType.ItemIndex);
  if dinfo.BDEType=rpdQuery then
  begin
   TabSQL.TabVisible:=true;
   TabBDETable.TabVisible:=false;
  end
  else
  begin
   TabSQL.TabVisible:=False;
   TabBDETable.TabVisible:=True;
  end;
 end
 else
 if Sender=EBDEIndexFields then
 begin
  dinfo.BDEIndexFields:=Trim(EBDEIndexFields.Text);
  if length(dinfo.BDEIndexFields)>0 then
   EBDEIndexName.Text:='';
 end
 else
 if Sender=EBDEIndexName then
 begin
  dinfo.BDEIndexName:=Trim(EBDEIndexName.Text);
  if length(dinfo.BDEIndexName)>0 then
   EBDEIndexFields.Text:='';
 end
 else
 if Sender=EBDETable then
 begin
  dinfo.BDETable:=EBDETable.Text;
 end
 else
 if Sender=MBDEFilter then
 begin
  dinfo.BDEFilter:=MBDEFilter.Text;
 end
 else
 if Sender=EBDEMasterFields then
 begin
  dinfo.BDEMasterFields:=EBDEMasterFields.Text;
 end
 else
 if Sender=EMasterFields then
 begin
  dinfo.MyBaseMasterFields:=EMasterFields.Text;
 end
 else
 if Sender=EBDEFirstRange then
 begin
  dinfo.BDEFirstRange:=EBDEFirstRange.Text;
 end
 else
 if Sender=EBDELastRange then
 begin
  dinfo.BDELastRange:=EBDELastRange.Text;
 end
 else
 if Sender=CheckOpen then
 begin
  dinfo.OpenOnStart:=CheckOpen.Checked;
 end;
end;

procedure TFRpDatasetsVCL.MonacoSchemaChange(Sender: TObject);
begin
 if FSyncingSchemaContext or (FMonaco = nil) then
  Exit;
 SyncActiveSchemaContext(FMonaco.HubDatabaseId, FMonaco.HubSchemaId);
end;

procedure TFRpDatasetsVCL.ChatSchemaChange(Sender: TObject);
begin
  if FSyncingSchemaContext or (FChat = nil) then
    Exit;
  SyncActiveSchemaContext(FChat.GetHubDatabaseId, FChat.GetHubSchemaId,
    FChat.GetSchemaApiKey);
end;

procedure TFRpDatasetsVCL.SyncActiveSchemaContext(AHubDatabaseId,
  AHubSchemaId: Int64; const ASchemaApiKey: string = '');
var
  LDataInfo: TRpDataInfoItem;
begin
  LDataInfo := FindDataInfoItem;
  if LDataInfo = nil then
    Exit;

  FSyncingSchemaContext := True;
  try
    LDataInfo.HubSchemaId := AHubSchemaId;
    ApplyActiveDataInfoContext(False, ASchemaApiKey);
  finally
    FSyncingSchemaContext := False;
  end;
end;

procedure TFRpDatasetsVCL.MonacoInferenceLog(Sender: TObject; const ASource,
  AText: string; AAppendLineBreak: Boolean);
begin
  if FChat = nil then
    Exit;

  if ASource <> '' then
    FChat.AppendLogLine('[' + ASource + '] ' + AText)
  else
    FChat.AppendLogChunk(AText, AAppendLineBreak);
end;

function TFRpDatasetsVCL.GetChatPrefillPercent(const AStage,
  AChunkType: string): Integer;
begin
  if SameText(AStage, 'PreparingContext') then
    Result := 15
  else if SameText(AStage, 'SendingRequest') then
    Result := 45
  else if SameText(AStage, 'ReceivingResponse') then
  begin
    if SameText(AChunkType, 'Start') then
      Result := 70
    else
      Result := 100;
  end
  else
    Result := 100;
end;

procedure TFRpDatasetsVCL.ChatTranslateProgress(Sender: TObject; const AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
var
  LStage: string;
  LChunkType: string;
  LChunk: string;
  LInputTokens: Integer;
  LOutputTokens: Integer;
  LQueueProc: TThreadProcedure;
begin
  LStage := AStage;
  LChunkType := AChunkType;
  LChunk := AChunk;
  LInputTokens := AInputTokens;
  LOutputTokens := AOutputTokens;

  LQueueProc :=
    procedure
    begin
      if FChat = nil then
        Exit;

      FChat.UpdateStreamingTokens(LInputTokens, LOutputTokens);
      if SameText(LStage, 'ReceivingResponse') then
      begin
        if LChunk <> '' then
          FChat.UpdateStreamingResponse(LChunk,
            GetChatPrefillPercent(LStage, LChunkType));
      end
      else if LChunk <> '' then
        FChat.AppendLogLine('[' + LStage + '] ' + LChunk);
    end;
  TThread.Queue(nil, LQueueProc);
end;

function TFRpDatasetsVCL.ChatTranslateCancelRequested(Sender: TObject): Boolean;
begin
  Result := False;
  if Sender is TRpDatasetChatStreamContext then
    Result := TRpDatasetChatStreamContext(Sender).RequestVersion <> FChatRequestVersion;
end;

procedure TFRpDatasetsVCL.ChatStopRequest(Sender: TObject);
begin
  Inc(FChatRequestVersion);
  if FChat <> nil then
  begin
    FChat.FinishStreamingResponse;
    FChat.AddAssistantMessage('Generation stopped.');
  end;
end;

procedure TFRpDatasetsVCL.ChatApplySuggestion(Sender: TObject;
  const AExpression: string);
begin
  FMonaco.SQL := AExpression;
  MSQLChange(FMonaco);
  if FChat <> nil then
    FChat.AddAssistantMessage('SQL applied to the editor.');
end;

procedure TFRpDatasetsVCL.ChatSendPrompt(Sender: TObject; const APrompt,
  AExpression: string);
var
  LAITier: string;
  LAIMode: string;
  LAgentSecret: string;
  LPrompt: string;
  LRequestVersion: Integer;
  LHubDatabaseId: Int64;
  LHubSchemaId: Int64;
  LAgentAiId: Int64;
  LSchemaApiKey: string;
  LSqlToRefine: string;
  LUserLanguage: string;
  LWorker: TThread;
begin
  if FChat = nil then
    Exit;

  LPrompt := Trim(APrompt);
  if LPrompt = '' then
    Exit;

  Inc(FChatRequestVersion);
  LRequestVersion := FChatRequestVersion;
  LHubDatabaseId := FChat.GetHubDatabaseId;
  LHubSchemaId := FChat.GetHubSchemaId;
  LAITier := FChat.GetAITier;
  LAIMode := FChat.GetAIMode;
  LAgentSecret := FChat.GetAgentSecret;
  LAgentAiId := FChat.GetAgentAiId;
  LSchemaApiKey := FChat.GetSchemaApiKey;
  LUserLanguage := GetUserLanguageCode;
  LSqlToRefine := Trim(AExpression);
  if LSqlToRefine = '' then
    LSqlToRefine := Trim(FMonaco.SQL);

  FChat.BeginStreamingResponse;
  if LSqlToRefine <> '' then
    FChat.AppendLogLine('[Chat] Starting SQL refine request...')
  else
    FChat.AppendLogLine('[Chat] Starting NLToSQL request...');

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LHttp: TRpDatabaseHttp;
      LResponse: TJSONObject;
      LResult: TJSONObject;
      LUserProfile: TJSONObject;
      LStreamContext: TRpDatasetChatStreamContext;
      LErrorMessage: string;
      LExplanation: string;
      LGeneratedSql: string;
      LVal: TJSONValue;
      LQueueProc: TThreadProcedure;
    begin
      LHttp := TRpDatabaseHttp.Create;
      LResponse := nil;
      LUserProfile := nil;
      LStreamContext := TRpDatasetChatStreamContext.Create;
      LStreamContext.RequestVersion := LRequestVersion;
      LErrorMessage := '';
      LExplanation := '';
      LGeneratedSql := '';
      try
        try
          LHttp.Token := TRpAuthManager.Instance.Token;
          LHttp.InstallId := TRpAuthManager.Instance.InstallId;
          LHttp.HubDatabaseId := LHubDatabaseId;
          LHttp.HubSchemaId := LHubSchemaId;
          LHttp.AITier := LAITier;
          LHttp.AgentSecret := LAgentSecret;
          LHttp.AgentAiId := LAgentAiId;
          LHttp.ApiKey := LSchemaApiKey;

          LResponse := LHttp.TranslateToSql(LPrompt, LSqlToRefine,
            LAIMode, LUserLanguage,
            LStreamContext, ChatTranslateProgress, ChatTranslateCancelRequested);

          if LRequestVersion <> FChatRequestVersion then
            Exit;

          if LResponse <> nil then
          begin
            LVal := LResponse.Values['errorMessage'];
            if LVal <> nil then
              LErrorMessage := Trim(LVal.Value);

            if Trim(LErrorMessage) = '' then
            begin
              LVal := LResponse.Values['result'];
              if (LVal <> nil) and (LVal is TJSONObject) then
              begin
                LResult := TJSONObject(LVal);
                if LResult.Values['errorMessage'] <> nil then
                  LErrorMessage := Trim(LResult.Values['errorMessage'].Value);
                if LResult.Values['sql'] <> nil then
                  LGeneratedSql := LResult.Values['sql'].Value;
                if LResult.Values['explanation'] <> nil then
                  LExplanation := LResult.Values['explanation'].Value;
              end;
            end;

            LVal := LResponse.Values['userProfile'];
            if (LVal <> nil) and (LVal is TJSONObject) then
              LUserProfile := TJSONObject(LVal.Clone);
          end;
        except
          on E: Exception do
            LErrorMessage := E.Message;
        end;

        LQueueProc :=
          procedure
          begin
            try
              if LRequestVersion <> FChatRequestVersion then
                Exit;

              if LUserProfile <> nil then
                FChat.UpdateUserProfile(LUserProfile);

              if Trim(LErrorMessage) <> '' then
              begin
                FChat.FinishStreamingResponse;
                FChat.AddAssistantMessage(LErrorMessage);
                Exit;
              end;

              if Trim(LGeneratedSql) = '' then
              begin
                FChat.FinishStreamingResponse;
                FChat.AddAssistantMessage('No SQL was returned by the service.');
                Exit;
              end;

              FChat.SetSuggestedContent(LGeneratedSql, LExplanation,
                'Suggested SQL');
            finally
              LUserProfile.Free;
            end;
          end;
        TThread.Queue(nil, LQueueProc);
      finally
        LStreamContext.Free;
        LResponse.Free;
        LHttp.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

function TFRpDatasetsVCL.GetUserLanguageCode: string;
begin
  Result := TRpAuthManager.Instance.AILanguage;
end;

procedure TFRpDatasetsVCL.MonacoAuditProgress(Sender: TObject; const AStage,
  AChunkType, AChunk: string; AInputTokens, AOutputTokens: Integer);
var
  LQueueProc: TThreadProcedure;
begin
  LQueueProc :=
    procedure
    begin
      FMonaco.UpdateAITokens(AInputTokens, AOutputTokens);
      if SameText(AStage, 'ReceivingResponse') and (AChunk <> '') then
        FMonaco.AppendLog(AChunk)
      else if AChunk <> '' then
        FMonaco.AppendLog('[' + AStage + '] ' + AChunk);
    end;
  TThread.Queue(nil, LQueueProc);
end;

procedure TFRpDatasetsVCL.MonacoAuditSql(Sender: TObject);
var
  LDataInfo: TRpDataInfoItem;
  LWorker: TThread;
  LSql: string;
  LHubDatabaseId: Int64;
  LHubSchemaId: Int64;
  LAITier: string;
  LAIMode: string;
  LAgentSecret: string;
  LAgentAiId: Int64;
  LLanguage: string;
begin
  LDataInfo := FindDataInfoItem;
  if LDataInfo = nil then
    Exit;

  LSql := FMonaco.SQL;
  if Trim(LSql) = '' then
  begin
    FMonaco.ActivateAuditTab;
    FMonaco.AppendLog('Audit SQL skipped: SQL is empty.');
    Exit;
  end;

  LHubDatabaseId := FMonaco.HubDatabaseId;
  LHubSchemaId := FMonaco.HubSchemaId;
  LAITier := FMonaco.AITier;
  LAIMode := FMonaco.AIMode;
  LAgentSecret := FMonaco.AgentSecret;
  LAgentAiId := FMonaco.AgentAiId;
  LLanguage := GetUserLanguageCode;

  FMonaco.ActivateAuditTab;
  FMonaco.SetAuditBusy(True);
  FMonaco.ClearLog;
  FMonaco.AppendLog('Starting SQL audit...');

  LWorker := TThread.CreateAnonymousThread(
    procedure
    var
      LHttp: TRpDatabaseHttp;
      LResponse: TJSONObject;
      LResult: TJSONObject;
      LUserProfile: TJSONObject;
      LErrorMessage: string;
      LExplanation: string;
      LResponseData: TJSONObject;
      LInputTokens: Integer;
      LOutputTokens: Integer;
      LTokenUsage: TJSONObject;
      LVal: TJSONValue;
      LSyncProc: TThreadProcedure;
    begin
      LHttp := TRpDatabaseHttp.Create;
      LResponse := nil;
      LUserProfile := nil;
      LErrorMessage := '';
      LExplanation := '';
      LInputTokens := 0;
      LOutputTokens := 0;
      try
        try
          LHttp.Token := TRpAuthManager.Instance.Token;
          LHttp.InstallId := TRpAuthManager.Instance.InstallId;
          LHttp.HubDatabaseId := LHubDatabaseId;
          LHttp.HubSchemaId := LHubSchemaId;
          LHttp.AITier := LAITier;
          LHttp.AgentSecret := LAgentSecret;
          LHttp.AgentAiId := LAgentAiId;

          LResponse := LHttp.ExplainSql(LSql, LAIMode, LLanguage, Self,
            MonacoAuditProgress, nil);

          if LResponse <> nil then
          begin
            LVal := LResponse.Values['errorMessage'];
            if LVal <> nil then
              LErrorMessage := LVal.Value;

            if Trim(LErrorMessage) = '' then
            begin
              LVal := LResponse.Values['result'];
              if (LVal <> nil) and (LVal is TJSONObject) then
              begin
                LResult := TJSONObject(LVal);
                LExplanation := '';
                if LResult.Values['explanation'] <> nil then
                  LExplanation := LResult.Values['explanation'].Value;

                LResponseData := LResult;
                LVal := LResponseData.Values['tokenUsage'];
                if (LVal <> nil) and (LVal is TJSONObject) then
                begin
                  LTokenUsage := TJSONObject(LVal);
                  if LTokenUsage.Values['inputTokens'] <> nil then
                    LInputTokens := StrToIntDef(LTokenUsage.Values['inputTokens'].Value, 0);
                  if LTokenUsage.Values['outputTokens'] <> nil then
                    LOutputTokens := StrToIntDef(LTokenUsage.Values['outputTokens'].Value, 0);
                end;
              end;
            end;

            LVal := LResponse.Values['userProfile'];
            if (LVal <> nil) and (LVal is TJSONObject) then
              LUserProfile := TJSONObject(LVal.Clone);
          end;
        except
          on E: Exception do
            LErrorMessage := E.Message;
        end;

        LSyncProc :=
          procedure
          begin
            try
              LDataInfo := FindDataInfoItem;
              if LDataInfo <> nil then
              begin
                if Trim(LErrorMessage) = '' then
                begin
                  LDataInfo.SQLExplanation := LExplanation;
                  LDataInfo.SQLExplanationError := '';
                  FMonaco.AuditText := LExplanation;
                  if LInputTokens > 0 then
                    FMonaco.AppendLog('Audit SQL complete. Input Tokens: ' +
                      IntToStr(LInputTokens) + ' Output Tokens: ' + IntToStr(LOutputTokens))
                  else
                    FMonaco.AppendLog('Audit SQL complete.');
                end
                else
                begin
                  LDataInfo.SQLExplanation := '';
                  LDataInfo.SQLExplanationError := LErrorMessage;
                  FMonaco.AuditText := '';
                  FMonaco.AppendLog('Audit SQL error: ' + LErrorMessage);
                end;
              end;

              if LUserProfile <> nil then
                TRpAuthManager.Instance.UpdateProfileFromJson(LUserProfile);
            finally
              FMonaco.SetAuditBusy(False);
            end;
          end;
        TThread.Synchronize(nil, LSyncProc);
      finally
        LUserProfile.Free;
        LResponse.Free;
        LHttp.Free;
      end;
    end);
  LWorker.FreeOnTerminate := True;
  LWorker.Start;
end;

procedure TFRpDatasetsVCL.BMyBaseClick(Sender: TObject);
begin
 if Sender=BMyBase then
 begin
  OpenDialog1.DefaultExt:='cds';
  OpenDialog1.FilterIndex:=0;
 end
 else
 begin
  OpenDialog1.DefaultExt:='ini';
  OpenDialog1.FilterIndex:=3;
 end;
 if OpenDialog1.Execute then
 begin
  if Sender=BMyBase then
   EMyBase.Text:=OpenDialog1.FileName
  else
   EMyBaseDefs.Text:=OpenDialog1.FileName
 end;
end;

procedure TFRpDatasetsVCL.BShowDataClick(Sender: TObject);
var
 dinfo:TRpDatainfoitem;
 i:integer;
 startinfo:TStartupinfo;
 linecount:string;
 FExename,FCommandLine:string;
 procesinfo:TProcessInformation;
 astring:string;
begin
 // Opens the dataset and show the data
 dinfo:=FindDataInfoItem;
 if dinfo=nil then
  exit;
 // See if is dot net
 i:=report.DatabaseInfo.IndexOf(dinfo.DatabaseAlias);
 if i>=0 then
 begin
  if report.DatabaseInfo.Items[i].Driver in [rpdatadriver,rpdotnet2driver] then
  begin
    linecount:='';
    with startinfo do
    begin
     cb:=sizeof(startinfo);
     lpReserved:=nil;
     lpDesktop:=nil;
     lpTitle:=PChar('Report manager');
     dwX:=0;
     dwY:=0;
     dwXSize:=400;
     dwYSize:=400;
     dwXCountChars:=80;
     dwYCountChars:=25;
     dwFillAttribute:=FOREGROUND_RED or BACKGROUND_RED or BACKGROUND_GREEN or BACKGROUND_BLUe;
     dwFlags:=STARTF_USECOUNTCHARS or STARTF_USESHOWWINDOW;
     cbReserved2:=0;
     lpreserved2:=nil;
    end;
    if report.DatabaseInfo.Items[i].Driver=rpdatadriver then
     FExename:=ExtractFilePath(Application.exename)+'net\printreport.exe'
    else
     FExename:=ExtractFilePath(Application.exename)+'net2\printreport.exe';
    if (not FileExists(Fexename)) then
    begin
     raise Exception.Create('File not found '+FExename);
    end;


    astring:=RpTempFileName;
    report.StreamFormat:=rpStreamXML;
    report.SaveToFile(astring);
    FCommandLine:=' -SHOWDATA '+dinfo.Alias+' -deletereport "'+astring+'"';

    if Not CreateProcess(Pchar(FExename),Pchar(Fcommandline),nil,nil,True,NORMAL_PRIORITY_CLASS or CREATE_NEW_PROCESS_GROUP,nil,nil,
    startinfo,procesinfo) then
     RaiseLastOSError;
   exit;
  end;
 end;

 for i:=0 to Datainfo.Count-1 do
 begin
  Datainfo.Items[i].Disconnect;
 end;
 report.InitEvaluator;
 report.AddReportItemsToEvaluator(report.Evaluator);
 Report.PrepareParamsBeforeOpen;
 dinfo.Connect(databaseinfo,report.params);
 try
  ShowDataset(dinfo.Dataset);
 finally
  // Left the dataset open for testing relations ...
//  dinfo.Disconnect;
 end;
end;

procedure TFRpDatasetsVCL.ADownExecute(Sender: TObject);
var
 dinfo:TRpDatainfoitem;
 index:integer;
 alias: string;
begin
 // Up
 dinfo:=FindDataInfoItem;
 alias:=dinfo.Alias;
 index:=datainfo.IndexOf(Alias);
 if index<0 then
  Raise Exception.Create(SRPAliasNotExists);
 if (index >= datainfo.Count-1) then
 begin
   exit;
 end;
 datainfo.Swap(index, index + 1);
 FillDatasets;
 LDataSets.Selected[index+1]:=true;
 LDatasetsClick(Self);
end;

procedure TFRpDatasetsVCL.ANewExecute(Sender: TObject);
var
 aliasname:string;
 aitem:TRpDataInfoItem;
 index:integer;
begin
 aliasname:=Trim(RpInputBox(SrpNewDataset,SRpAliasName,''));
 if Length(aliasname)<1 then
  exit;
 aitem:=datainfo.Add(aliasname);
 EnsureDataInfoItemName(TRpBaseReport(report), aitem);
  if databaseinfo.Count>0 then
    aitem.DatabaseAlias:=databaseinfo.Items[0].Alias;
  if aitem.DatabaseAlias <> '' then
  begin
    for index := 0 to datainfo.Count - 1 do
    begin
      if (datainfo.Items[index] <> aitem) and
         SameText(datainfo.Items[index].DatabaseAlias, aitem.DatabaseAlias) and
         (datainfo.Items[index].HubSchemaId > 0) then
      begin
        aitem.HubSchemaId := datainfo.Items[index].HubSchemaId;
        Break;
      end;
    end;
  end;
 FillDatasets;
 index:=LDatasets.items.indexof(AnsiUppercase(aliasname));
 if index>=0 then
 begin
  LDatasets.ItemIndex:=index;
  LDatasetsClick(Self);
 end;
end;

procedure TFRpDatasetsVCL.ADeleteExecute(Sender: TObject);
var
 index:integer;
 oldalias:string;
begin
 if LDatasets.itemindex<0 then
  exit;
 index:=datainfo.IndexOf(LDatasets.Items.strings[Ldatasets.itemindex]);
 if index>=0 then
 begin
  oldalias:=datainfo.items[index].Alias;
  datainfo.Delete(index);
  Removedependences(oldalias);
 end;
 FillDatasets;
end;

procedure TFRpDatasetsVCL.ARenameExecute(Sender: TObject);
var
 dinfo:TRpDatainfoitem;
 aliasname:string;
 index:integer;
begin
 dinfo:=FindDataInfoItem;
 aliasname:=Trim(RpInputBox(SrpRenameDataset,SRpAliasName,dinfo.Alias));
 index:=datainfo.IndexOf(aliasname);
 if index>=0 then
  Raise Exception.Create(SRpAliasExists);
 if Length(aliasname)<1 then
  exit;
 if Not Assigned(dinfo) then
  exit;
 dinfo.Alias:=aliasname;
 FillDatasets;
end;

procedure TFRpDatasetsVCL.AUpExecute(Sender: TObject);
var
 dinfo:TRpDatainfoitem;
 index:integer;
 alias: string;
begin
 // Up
 dinfo:=FindDataInfoItem;
 alias:=dinfo.Alias;
 index:=datainfo.IndexOf(dinfo.Alias);
 if index<0 then
  Raise Exception.Create(SRPAliasNotExists);
 if (index = 0) then
 begin
   exit;
 end;
 datainfo.Swap(index, index - 1);
 FillDatasets;
 LDataSets.Selected[index-1]:=true;
 LDatasetsClick(Self);
end;

procedure  TFRpDatasetsVCL.Removedependences(oldalias:string);
var
 i:integer;
begin
 for i:=0 to datainfo.count-1 do
 begin
  if AnsiUpperCase(oldalias)=AnsiUpperCase(datainfo.items[i].datasource) then
   datainfo.items[i].datasource:='';
 end;
end;

procedure TFRpDatasetsVCL.BAddUnionsClick(Sender: TObject);
var
 index:integer;
 alist:TStringList;
 i:integer;
 datasetname:string;
 commonfields:string;
begin
 if ComboUnions.Items.Count<1 then
  exit;
 if ComboUnions.ItemIndex<0 then
  exit;
 alist:=TStringList.Create;
 try
  for i:=0 to LUnions.Items.Count-1 do
  begin
   datasetname:=LUnions.Items.Strings[i];
   ExtractUnionFields(datasetname,alist);
   if datasetname=ComboUnions.Text then
   begin
    break;
   end;
  end;
  index:=LUnions.Items.IndexOf(ComboUnions.Text);
  if index<0 then
  begin
   datasetname:=ComboUnions.Text;
   if CheckParallelUnion.Checked then
   begin
    commonfields:=Trim(RpInputBox(datasetname,SRpCommonFields,''));
    if Length(commonfields)>0 then
     datasetname:=datasetname+'-'+commonfields;
   end;
   LUnions.Items.Add(datasetname);
   MSQLChange(BAddUnions);
  end;
 finally
  alist.free;
 end;
end;

procedure TFRpDatasetsVCL.BDelUnionsClick(Sender: TObject);
begin
 if LUnions.Items.Count<1 then
  exit;
 if LUnions.ItemIndex<0 then
  exit;
 LUnions.Items.Delete(LUnions.ItemIndex);
 MSQLChange(BAddUnions);
end;

procedure TFRpDatasetsVCL.EBDETableDropDown(Sender: TObject);
{$IFDEF USEBDE}
var
 dinfo:TRpDatainfoItem;
{$ENDIF}
begin
{$IFDEF USEBDE}
 // Fils the info of the current dataset
 dinfo:=FindDataInfoItem;
 if dinfo=nil then
  exit;
 // Fills with tablenames, without extensions,
 // no system tables
 try
  Session.GetTableNames(dinfo.DatabaseAlias,'',True,False,EBDETable.Items);
 finally
  EBDETable.Items.Insert(0,' ');
 end;
{$ENDIF}
end;

procedure TFRpDatasetsVCL.EBDEIndexNameDropDown(Sender: TObject);
{$IFDEF USEBDE}
var
 dinfo:TRpDatainfoItem;
 atable:TTable;
 i:integer;
{$ENDIF}
begin
{$IFDEF USEBDE}
 // Fils the info of the current dataset
 dinfo:=FindDataInfoItem;
 if dinfo=nil then
  exit;
 atable:=TTable.Create(Self);
 try
  EBDEIndexName.Items.Clear;
  atable.DatabaseName:=dinfo.DatabaseAlias;
  atable.TableName:=dinfo.BDETable;
  atable.IndexDefs.Update;
  EBDEIndexName.Items.Clear;
  for i:=0 to atable.IndexDefs.Count-1 do
  begin
   EBDEIndexName.Items.Add(atable.IndexDefs.Items[i].Name);
  end;
 finally
  atable.free;
  EBDEIndexName.Items.Insert(0,' ');
 end;
{$ENDIF}
end;

{$IFDEF USEBDE}
procedure GetIndexFieldNames(atable:TTable;Items:TStrings);
var
 i:integer;
begin
 atable.IndexDefs.Update;
 items.Clear;
 for i:=0 to atable.IndexDefs.Count-1 do
 begin
  if Length(atable.IndexDefs.Items[i].Fields)>0 then
   items.Add(atable.IndexDefs.Items[i].Fields);
 end;
end;
{$ENDIF}

procedure TFRpDatasetsVCL.EBDEIndexFieldsDropDown(Sender: TObject);
{$IFDEF USEBDE}
var
 dinfo:TRpDatainfoItem;
 atable:TTable;
{$ENDIF}
begin
{$IFDEF USEBDE}
 // Fils the info of the current dataset
 dinfo:=FindDataInfoItem;
 if dinfo=nil then
  exit;
 atable:=TTable.Create(Self);
 try
  EBDEIndexFields.Items.Clear;
  atable.DatabaseName:=dinfo.DatabaseAlias;
  atable.TableName:=dinfo.BDETable;
  GetIndexFieldNames(atable,EBDEIndexFields.Items);
 finally
  atable.free;
  EBDEIndexFields.Items.Insert(0,' ');
 end;
{$ENDIF}
end;

procedure TFRpDatasetsVCL.BModifyClick(Sender: TObject);
var
 dinfo:TRpDatainfoItem;
 dbinfo:TRpDatabaseInfoItem;
 index:Integer;
begin
 dinfo:=FindDataInfoItem;
 if dinfo=nil then
  exit;
 index:=databaseinfo.IndexOf(dinfo.DatabaseAlias);
 if index<0 then
  exit;
 dbinfo:=databaseinfo.items[index];
 dbinfo.Connect(Params);
 ShowDataTextConfig(dbinfo.MyBasePath+EMyBaseDefs.Text,dbinfo.MyBasePath+EMyBase.Text);
end;

end.

